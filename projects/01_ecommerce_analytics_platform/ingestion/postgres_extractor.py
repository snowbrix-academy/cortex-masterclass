"""
Snowbrix E-Commerce Platform — PostgreSQL to Snowflake Extractor

Extracts data from the source PostgreSQL database and loads into
Snowflake's ECOMMERCE_RAW.POSTGRES schema.

Supports two modes:
- Full load: Truncate target, extract all rows, load.
- Incremental: Extract only rows changed since last load.

Usage:
    python ingestion/postgres_extractor.py --full-load
    python ingestion/postgres_extractor.py --table orders
    python ingestion/postgres_extractor.py  # incremental, all tables
"""

import argparse
import logging
import os
import sys
import tempfile
import time
from datetime import datetime
from pathlib import Path

import pandas as pd
import psycopg2
import psycopg2.extras

from ingestion.config import IngestionConfig, POSTGRES_TABLES
from ingestion.utils.snowflake_client import SnowflakeClient
from ingestion.utils.retry_handler import with_retry

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("postgres_extractor")


class PostgresExtractor:
    """Extracts data from PostgreSQL and loads into Snowflake RAW layer."""

    def __init__(self, config: IngestionConfig):
        self.config = config
        self.temp_dir = Path(config.temp_dir)
        self.temp_dir.mkdir(parents=True, exist_ok=True)

    @with_retry(max_attempts=3, min_wait=2)
    def _connect_postgres(self):
        """Create a connection to the source PostgreSQL database."""
        pg = self.config.postgres
        return psycopg2.connect(
            host=pg.host,
            port=pg.port,
            dbname=pg.database,
            user=pg.user,
            password=pg.password,
        )

    def extract_table(self, table_config: dict, full_load: bool = False):
        """
        Extract a single table from PostgreSQL and load into Snowflake.

        Args:
            table_config: Dict with source_table, target_table, etc.
            full_load: If True, truncate target and extract all rows.
        """
        source_table = table_config["source_table"]
        target_schema = table_config["target_schema"]
        target_table = table_config["target_table"]
        incremental_col = table_config["incremental_column"]
        target_full = f"{target_schema}.{target_table}"

        logger.info("=" * 60)
        logger.info("Extracting: %s → %s (mode=%s)",
                     source_table, target_full,
                     "FULL" if full_load else "INCREMENTAL")

        # Step 1: Determine extraction bounds
        last_loaded_at = None
        if not full_load:
            with SnowflakeClient(config=self.config.snowflake) as sf:
                last_loaded_at = sf.get_max_loaded_at(target_full)
                if last_loaded_at:
                    logger.info("Last loaded at: %s", last_loaded_at)
                else:
                    logger.info("No previous load found. Running full extract.")
                    full_load = True

        # Step 2: Extract from PostgreSQL
        start_time = time.time()
        pg_conn = self._connect_postgres()

        try:
            if full_load:
                query = f"SELECT * FROM {source_table}"
                params = None
            else:
                query = f"SELECT * FROM {source_table} WHERE {incremental_col} > %s"
                params = (last_loaded_at,)

            logger.info("Executing: %s", query)
            df = pd.read_sql(query, pg_conn, params=params)
            extract_time = time.time() - start_time
            logger.info(
                "Extracted %d rows from %s in %.2fs",
                len(df), source_table, extract_time,
            )
        finally:
            pg_conn.close()

        if df.empty:
            logger.info("No new rows to load. Skipping.")
            return 0

        # Step 3: Write to Parquet temp file
        parquet_path = self.temp_dir / f"{source_table}.parquet"
        df.to_parquet(parquet_path, index=False, engine="pyarrow")
        file_size_mb = parquet_path.stat().st_size / (1024 * 1024)
        logger.info("Wrote %s (%.2f MB)", parquet_path.name, file_size_mb)

        # Step 4: Upload to Snowflake stage and COPY INTO target
        with SnowflakeClient(config=self.config.snowflake) as sf:
            if full_load:
                sf.truncate_table(target_full)

            stage = f"@{target_schema}.PARQUET_STAGE"
            sf.upload_to_stage(str(parquet_path), stage)
            sf.copy_into_table(
                table_name=target_full,
                stage_name=stage,
                file_format="TYPE = PARQUET",
                pattern=f".*{source_table}.*",
            )

        # Step 5: Cleanup temp file
        parquet_path.unlink(missing_ok=True)

        total_time = time.time() - start_time
        logger.info(
            "Loaded %d rows into %s in %.2fs (%.0f rows/sec)",
            len(df), target_full, total_time, len(df) / total_time,
        )
        return len(df)

    def run(self, full_load: bool = False, table_filter: str = None):
        """
        Run extraction for all configured tables.

        Args:
            full_load: If True, truncate and reload all tables.
            table_filter: If set, only extract this table name.
        """
        tables = POSTGRES_TABLES
        if table_filter:
            tables = [t for t in tables if t["source_table"] == table_filter]
            if not tables:
                logger.error("Table '%s' not found in config.", table_filter)
                sys.exit(1)

        total_rows = 0
        start = time.time()

        for table_config in tables:
            try:
                rows = self.extract_table(table_config, full_load=full_load)
                total_rows += rows
            except Exception:
                logger.exception(
                    "Failed to extract %s", table_config["source_table"]
                )
                raise

        elapsed = time.time() - start
        logger.info("=" * 60)
        logger.info(
            "COMPLETE: %d total rows across %d tables in %.2fs",
            total_rows, len(tables), elapsed,
        )
        return total_rows


def main():
    parser = argparse.ArgumentParser(
        description="Extract data from PostgreSQL to Snowflake RAW layer"
    )
    parser.add_argument(
        "--full-load",
        action="store_true",
        help="Truncate target tables and reload all data",
    )
    parser.add_argument(
        "--table",
        type=str,
        default=None,
        help="Extract a single table (e.g., 'orders')",
    )
    parser.add_argument(
        "--log-level",
        type=str,
        default="INFO",
        choices=["DEBUG", "INFO", "WARNING", "ERROR"],
        help="Logging level",
    )
    args = parser.parse_args()

    logging.getLogger().setLevel(getattr(logging, args.log_level))

    config = IngestionConfig()
    config.snowflake.validate()

    extractor = PostgresExtractor(config)
    extractor.run(full_load=args.full_load, table_filter=args.table)


if __name__ == "__main__":
    main()
