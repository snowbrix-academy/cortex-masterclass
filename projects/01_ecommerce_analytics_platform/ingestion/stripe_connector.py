"""
Snowbrix E-Commerce Platform — Stripe API to Snowflake Connector

Fetches payment and refund data from the Stripe API and loads into
Snowflake's ECOMMERCE_RAW.STRIPE schema.

Handles:
- Cursor-based pagination (starting_after)
- Rate limit handling (HTTP 429 with Retry-After)
- Full JSON preservation (VARIANT column for auditing)
- Incremental loading (created[gte] filter)

Usage:
    python ingestion/stripe_connector.py --full-load
    python ingestion/stripe_connector.py  # incremental
"""

import argparse
import json
import logging
import time
from datetime import datetime
from pathlib import Path

import requests

from ingestion.config import IngestionConfig
from ingestion.utils.snowflake_client import SnowflakeClient
from ingestion.utils.retry_handler import retry_on_rate_limit

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("stripe_connector")


class StripeConnector:
    """Fetches data from Stripe API and loads into Snowflake."""

    def __init__(self, config: IngestionConfig):
        self.config = config
        self.api_key = config.stripe.api_key
        self.base_url = config.stripe.base_url
        self.temp_dir = Path(config.temp_dir)
        self.temp_dir.mkdir(parents=True, exist_ok=True)

        self.session = requests.Session()
        self.session.headers.update({
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/x-www-form-urlencoded",
        })

    @retry_on_rate_limit(max_attempts=5, base_wait=2)
    def _api_request(self, endpoint, params=None):
        """Make an authenticated GET request to Stripe API."""
        url = f"{self.base_url}/{endpoint}"
        response = self.session.get(url, params=params)

        if response.status_code == 429:
            error = type("RateLimitError", (Exception,), {
                "http_status": 429,
                "headers": response.headers,
            })()
            raise error

        response.raise_for_status()
        return response.json()

    def fetch_all_charges(self, created_gte=None):
        """
        Fetch all charges from Stripe with cursor-based pagination.

        Args:
            created_gte: Unix timestamp. Only fetch charges created after this.

        Yields:
            Individual charge objects (dicts).
        """
        params = {"limit": 100}
        if created_gte:
            params["created[gte]"] = int(created_gte)

        total_fetched = 0

        while True:
            data = self._api_request("charges", params=params)
            charges = data.get("data", [])

            for charge in charges:
                total_fetched += 1
                yield charge

            if not data.get("has_more", False):
                break

            # Set cursor for next page
            params["starting_after"] = charges[-1]["id"]
            logger.info("Fetched %d charges so far...", total_fetched)

        logger.info("Total charges fetched: %d", total_fetched)

    def fetch_all_refunds(self, created_gte=None):
        """
        Fetch all refunds from Stripe with cursor-based pagination.

        Args:
            created_gte: Unix timestamp. Only fetch refunds created after this.

        Yields:
            Individual refund objects (dicts).
        """
        params = {"limit": 100}
        if created_gte:
            params["created[gte]"] = int(created_gte)

        total_fetched = 0

        while True:
            data = self._api_request("refunds", params=params)
            refunds = data.get("data", [])

            for refund in refunds:
                total_fetched += 1
                yield refund

            if not data.get("has_more", False):
                break

            params["starting_after"] = refunds[-1]["id"]

        logger.info("Total refunds fetched: %d", total_fetched)

    def _transform_charge(self, charge):
        """
        Transform a raw Stripe charge into a flat row for Snowflake.
        Preserves the full JSON in _raw_json for audit.
        """
        # Extract order_id from metadata (assumes it's stored there)
        order_id = charge.get("metadata", {}).get("order_id")

        return {
            "payment_id": charge["id"],
            "order_id": int(order_id) if order_id else None,
            "amount": charge["amount"] / 100,  # Cents to dollars
            "currency": charge["currency"].upper(),
            "status": charge["status"],
            "payment_method": charge.get("payment_method_details", {}).get("type"),
            "stripe_charge_id": charge["id"],
            "created_at": datetime.utcfromtimestamp(charge["created"]).isoformat(),
            "_raw_json": json.dumps(charge),
        }

    def _transform_refund(self, refund):
        """Transform a raw Stripe refund into a flat row for Snowflake."""
        return {
            "refund_id": refund["id"],
            "payment_id": refund["charge"],
            "amount": refund["amount"] / 100,
            "reason": refund.get("reason"),
            "status": refund["status"],
            "created_at": datetime.utcfromtimestamp(refund["created"]).isoformat(),
            "_raw_json": json.dumps(refund),
        }

    def load_charges(self, full_load=False):
        """Extract charges from Stripe and load into Snowflake."""
        logger.info("=" * 60)
        logger.info("Loading Stripe charges (mode=%s)", "FULL" if full_load else "INCREMENTAL")

        # Determine incremental boundary
        created_gte = None
        if not full_load:
            with SnowflakeClient(
                config=self.config.snowflake,
                schema="STRIPE",
            ) as sf:
                result = sf.execute_query(
                    "SELECT MAX(EXTRACT(EPOCH FROM created_at)) AS max_ts FROM STRIPE.RAW_PAYMENTS"
                )
                if result and result[0]["MAX_TS"]:
                    created_gte = int(result[0]["MAX_TS"])
                    logger.info("Incremental from: %s", datetime.utcfromtimestamp(created_gte))
                else:
                    logger.info("No previous data. Running full load.")

        # Fetch and transform
        rows = []
        for charge in self.fetch_all_charges(created_gte=created_gte):
            rows.append(self._transform_charge(charge))

        if not rows:
            logger.info("No new charges to load.")
            return 0

        # Write to NDJSON temp file
        ndjson_path = self.temp_dir / "stripe_charges.json"
        with open(ndjson_path, "w") as f:
            for row in rows:
                f.write(json.dumps(row) + "\n")

        # Load into Snowflake
        with SnowflakeClient(
            config=self.config.snowflake,
            schema="STRIPE",
        ) as sf:
            if full_load:
                sf.truncate_table("STRIPE.RAW_PAYMENTS")

            sf.upload_to_stage(str(ndjson_path), "@STRIPE.JSON_STAGE")
            sf.copy_into_table(
                table_name="STRIPE.RAW_PAYMENTS",
                stage_name="@STRIPE.JSON_STAGE",
                pattern=".*stripe_charges.*",
            )

        ndjson_path.unlink(missing_ok=True)
        logger.info("Loaded %d charges into RAW_PAYMENTS", len(rows))
        return len(rows)

    def load_refunds(self, full_load=False):
        """Extract refunds from Stripe and load into Snowflake."""
        logger.info("=" * 60)
        logger.info("Loading Stripe refunds (mode=%s)", "FULL" if full_load else "INCREMENTAL")

        created_gte = None
        if not full_load:
            with SnowflakeClient(
                config=self.config.snowflake,
                schema="STRIPE",
            ) as sf:
                result = sf.execute_query(
                    "SELECT MAX(EXTRACT(EPOCH FROM created_at)) AS max_ts FROM STRIPE.RAW_REFUNDS"
                )
                if result and result[0]["MAX_TS"]:
                    created_gte = int(result[0]["MAX_TS"])

        rows = []
        for refund in self.fetch_all_refunds(created_gte=created_gte):
            rows.append(self._transform_refund(refund))

        if not rows:
            logger.info("No new refunds to load.")
            return 0

        ndjson_path = self.temp_dir / "stripe_refunds.json"
        with open(ndjson_path, "w") as f:
            for row in rows:
                f.write(json.dumps(row) + "\n")

        with SnowflakeClient(
            config=self.config.snowflake,
            schema="STRIPE",
        ) as sf:
            if full_load:
                sf.truncate_table("STRIPE.RAW_REFUNDS")

            sf.upload_to_stage(str(ndjson_path), "@STRIPE.JSON_STAGE")
            sf.copy_into_table(
                table_name="STRIPE.RAW_REFUNDS",
                stage_name="@STRIPE.JSON_STAGE",
                pattern=".*stripe_refunds.*",
            )

        ndjson_path.unlink(missing_ok=True)
        logger.info("Loaded %d refunds into RAW_REFUNDS", len(rows))
        return len(rows)

    def run(self, full_load=False):
        """Run full Stripe extraction pipeline."""
        start = time.time()
        charges = self.load_charges(full_load=full_load)
        refunds = self.load_refunds(full_load=full_load)
        elapsed = time.time() - start

        logger.info("=" * 60)
        logger.info(
            "COMPLETE: %d charges + %d refunds in %.2fs",
            charges, refunds, elapsed,
        )
        return charges + refunds


def main():
    parser = argparse.ArgumentParser(
        description="Extract data from Stripe API to Snowflake RAW layer"
    )
    parser.add_argument("--full-load", action="store_true")
    parser.add_argument("--log-level", default="INFO")
    args = parser.parse_args()

    logging.getLogger().setLevel(getattr(logging, args.log_level))

    config = IngestionConfig()
    config.snowflake.validate()

    if not config.stripe.api_key:
        logger.error("STRIPE_API_KEY not set. Check .env file.")
        sys.exit(1)

    connector = StripeConnector(config)
    connector.run(full_load=args.full_load)


if __name__ == "__main__":
    main()
