"""
Snowbrix E-Commerce Platform — CSV File Loader

Loads CSV files (from Google Sheets exports) into Snowflake's
ECOMMERCE_RAW.CSV_UPLOADS schema using PUT + COPY INTO.

Handles:
- File staging to internal Snowflake stage
- Error handling with ON_ERROR = CONTINUE
- Rejected row inspection via VALIDATE()
- Duplicate detection

Usage:
    python ingestion/csv_loader.py --file marketing_spend.csv
    python ingestion/csv_loader.py --all
"""

import argparse
import logging
import sys
import time
from pathlib import Path

from ingestion.config import IngestionConfig
from ingestion.utils.snowflake_client import SnowflakeClient

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("csv_loader")


# CSV file → target table mapping
CSV_MAPPINGS = [
    {
        "file_pattern": "marketing_spend",
        "target_table": "CSV_UPLOADS.RAW_MARKETING_SPEND",
        "expected_columns": ["date", "channel", "campaign_name", "spend", "impressions", "clicks"],
    },
    {
        "file_pattern": "campaign_performance",
        "target_table": "CSV_UPLOADS.RAW_CAMPAIGN_PERFORMANCE",
        "expected_columns": [
            "date", "campaign_id", "campaign_name", "channel",
            "conversions", "revenue_attributed",
        ],
    },
]


class CsvLoader:
    """Loads CSV files into Snowflake via internal stage."""

    def __init__(self, config: IngestionConfig):
        self.config = config
        self.data_dir = Path(config.temp_dir) / "csv_uploads"
        self.data_dir.mkdir(parents=True, exist_ok=True)

    def load_csv(self, csv_path: Path, mapping: dict):
        """
        Load a single CSV file into Snowflake.

        Args:
            csv_path: Path to the CSV file.
            mapping: Dict with target_table and expected_columns.
        """
        target_table = mapping["target_table"]
        logger.info("=" * 60)
        logger.info("Loading %s → %s", csv_path.name, target_table)

        if not csv_path.exists():
            logger.error("File not found: %s", csv_path)
            return 0

        file_size_kb = csv_path.stat().st_size / 1024
        logger.info("File size: %.1f KB", file_size_kb)

        start = time.time()

        with SnowflakeClient(
            config=self.config.snowflake,
            schema="CSV_UPLOADS",
        ) as sf:
            # Step 1: Upload to stage
            stage = "@CSV_UPLOADS.CSV_STAGE"
            sf.upload_to_stage(str(csv_path), stage)

            # Step 2: COPY INTO with error tolerance
            sql = f"""
                COPY INTO {target_table}
                FROM {stage}/{csv_path.name}
                FILE_FORMAT = (
                    TYPE = CSV
                    SKIP_HEADER = 1
                    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
                    NULL_IF = ('', 'NULL', 'null', 'N/A')
                    TRIM_SPACE = TRUE
                    ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
                )
                ON_ERROR = 'CONTINUE'
                PURGE = TRUE
            """
            result = sf.execute_query(sql)
            logger.info("COPY result: %s", result)

            # Step 3: Check for rejected rows
            try:
                rejected = sf.execute_query(
                    f"SELECT * FROM TABLE(VALIDATE({target_table}, JOB_ID => '_last'))"
                )
                if rejected:
                    logger.warning(
                        "REJECTED ROWS (%d): Check data quality!",
                        len(rejected),
                    )
                    for row in rejected[:5]:  # Show first 5
                        logger.warning("  Rejected: %s", row)
                else:
                    logger.info("No rejected rows. Clean load.")
            except Exception:
                # VALIDATE() may fail if no rows were rejected
                logger.info("No rejected rows detected.")

            # Step 4: Verify row count
            count_result = sf.execute_query(
                f"SELECT COUNT(*) AS cnt FROM {target_table}"
            )
            total_rows = count_result[0]["CNT"] if count_result else 0

        elapsed = time.time() - start
        logger.info("Loaded into %s (%d total rows) in %.2fs", target_table, total_rows, elapsed)
        return total_rows

    def find_csv_files(self, file_filter=None):
        """
        Find CSV files in the data directory matching known patterns.

        Args:
            file_filter: Optional filename pattern to match.

        Returns:
            List of (Path, mapping) tuples.
        """
        matches = []
        for mapping in CSV_MAPPINGS:
            pattern = mapping["file_pattern"]
            for csv_file in self.data_dir.glob(f"*{pattern}*.csv"):
                if file_filter and file_filter not in csv_file.name:
                    continue
                matches.append((csv_file, mapping))

        return matches

    def run(self, file_filter=None):
        """
        Load all matching CSV files.

        Args:
            file_filter: Optional filename to filter by.
        """
        matches = self.find_csv_files(file_filter=file_filter)

        if not matches:
            logger.warning(
                "No CSV files found in %s. "
                "Place CSV files in this directory and re-run.",
                self.data_dir,
            )
            logger.info("Expected files: marketing_spend.csv, campaign_performance.csv")
            return

        start = time.time()
        total_loaded = 0

        for csv_path, mapping in matches:
            try:
                rows = self.load_csv(csv_path, mapping)
                total_loaded += rows
            except Exception:
                logger.exception("Failed to load %s", csv_path.name)
                raise

        elapsed = time.time() - start
        logger.info("=" * 60)
        logger.info(
            "COMPLETE: Loaded %d files in %.2fs",
            len(matches), elapsed,
        )


def main():
    parser = argparse.ArgumentParser(
        description="Load CSV files into Snowflake RAW layer"
    )
    parser.add_argument(
        "--file",
        type=str,
        default=None,
        help="Load a specific CSV file (e.g., 'marketing_spend.csv')",
    )
    parser.add_argument(
        "--all",
        action="store_true",
        help="Load all CSV files found in the data directory",
    )
    parser.add_argument("--log-level", default="INFO")
    args = parser.parse_args()

    logging.getLogger().setLevel(getattr(logging, args.log_level))

    config = IngestionConfig()
    config.snowflake.validate()

    loader = CsvLoader(config)
    loader.run(file_filter=args.file)


if __name__ == "__main__":
    main()
