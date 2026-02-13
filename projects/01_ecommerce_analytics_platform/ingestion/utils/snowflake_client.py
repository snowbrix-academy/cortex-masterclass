"""
Snowbrix E-Commerce Platform — Reusable Snowflake Connection Manager

Usage:
    with SnowflakeClient(warehouse="LOADING_WH") as sf:
        results = sf.execute_query("SELECT COUNT(*) FROM RAW_ORDERS")
        sf.upload_to_stage("/tmp/data.parquet", "@POSTGRES.PARQUET_STAGE")
        sf.copy_into_table("POSTGRES.RAW_ORDERS", "@POSTGRES.PARQUET_STAGE")
"""

import logging
import time
from pathlib import Path

import snowflake.connector

logger = logging.getLogger(__name__)


class SnowflakeClient:
    """Context-managed Snowflake connection with helper methods."""

    def __init__(self, config=None, warehouse=None, database=None, schema=None):
        """
        Initialize Snowflake client.

        Args:
            config: SnowflakeConfig object. If None, loads from IngestionConfig.
            warehouse: Override default warehouse.
            database: Override default database.
            schema: Override default schema.
        """
        if config is None:
            from ingestion.config import IngestionConfig
            config = IngestionConfig().snowflake
            config.validate()

        self._config = config
        self._warehouse = warehouse or config.warehouse
        self._database = database or config.database
        self._schema = schema or config.schema
        self._conn = None

    def __enter__(self):
        """Open connection."""
        logger.info(
            "Connecting to Snowflake: %s (warehouse=%s, database=%s)",
            self._config.account,
            self._warehouse,
            self._database,
        )
        self._conn = snowflake.connector.connect(
            account=self._config.account,
            user=self._config.user,
            password=self._config.password,
            role=self._config.role,
            warehouse=self._warehouse,
            database=self._database,
            schema=self._schema,
        )
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        """Close connection. Log any exception."""
        if self._conn:
            if exc_type:
                logger.error("Exception during Snowflake session: %s", exc_val)
            self._conn.close()
            logger.info("Snowflake connection closed.")
        return False  # Don't suppress exceptions

    def execute_query(self, sql, params=None):
        """
        Execute a SQL query and return results as list of dicts.

        Args:
            sql: SQL string to execute.
            params: Optional parameters for parameterized queries.

        Returns:
            List of dicts (column_name -> value) for SELECT queries.
            Empty list for non-SELECT queries.
        """
        start = time.time()
        cursor = self._conn.cursor()
        try:
            cursor.execute(sql, params)
            if cursor.description:
                columns = [col[0] for col in cursor.description]
                results = [dict(zip(columns, row)) for row in cursor.fetchall()]
            else:
                results = []
            elapsed = time.time() - start
            logger.debug("Query executed in %.2fs: %s", elapsed, sql[:100])
            return results
        finally:
            cursor.close()

    def execute_many(self, sql, data):
        """
        Batch insert using executemany for performance.

        Args:
            sql: INSERT statement with %s placeholders.
            data: List of tuples matching placeholder count.
        """
        start = time.time()
        cursor = self._conn.cursor()
        try:
            cursor.executemany(sql, data)
            elapsed = time.time() - start
            logger.info("Batch insert: %d rows in %.2fs", len(data), elapsed)
        finally:
            cursor.close()

    def upload_to_stage(self, local_path, stage_name):
        """
        PUT a local file to a Snowflake internal stage.

        Args:
            local_path: Path to local file.
            stage_name: Snowflake stage (e.g., "@POSTGRES.PARQUET_STAGE")
        """
        local_path = str(Path(local_path).resolve())
        # Snowflake PUT requires forward slashes even on Windows
        local_path_normalized = local_path.replace("\\", "/")
        sql = f"PUT 'file://{local_path_normalized}' {stage_name} AUTO_COMPRESS=TRUE OVERWRITE=TRUE"
        logger.info("Uploading %s to %s", local_path, stage_name)
        start = time.time()
        cursor = self._conn.cursor()
        try:
            cursor.execute(sql)
            result = cursor.fetchall()
            elapsed = time.time() - start
            logger.info("Upload complete in %.2fs: %s", elapsed, result)
            return result
        finally:
            cursor.close()

    def copy_into_table(self, table_name, stage_name, file_format=None, pattern=None):
        """
        COPY INTO a table from a stage.

        Args:
            table_name: Target table (e.g., "POSTGRES.RAW_ORDERS")
            stage_name: Source stage (e.g., "@POSTGRES.PARQUET_STAGE")
            file_format: Optional format override.
            pattern: Optional file pattern to match.
        """
        sql = f"COPY INTO {table_name} FROM {stage_name}"
        if file_format:
            sql += f" FILE_FORMAT = ({file_format})"
        if pattern:
            sql += f" PATTERN = '{pattern}'"
        sql += " ON_ERROR = 'CONTINUE'"

        logger.info("COPY INTO %s from %s", table_name, stage_name)
        start = time.time()
        cursor = self._conn.cursor()
        try:
            cursor.execute(sql)
            result = cursor.fetchall()
            elapsed = time.time() - start
            logger.info("COPY complete in %.2fs: %s", elapsed, result)
            return result
        finally:
            cursor.close()

    def get_max_loaded_at(self, schema_table):
        """
        Get the latest _loaded_at timestamp for incremental logic.

        Args:
            schema_table: "SCHEMA.TABLE_NAME"

        Returns:
            datetime or None if table is empty.
        """
        sql = f"SELECT MAX(_loaded_at) AS max_ts FROM {schema_table}"
        result = self.execute_query(sql)
        if result and result[0]["MAX_TS"]:
            return result[0]["MAX_TS"]
        return None

    def truncate_table(self, schema_table):
        """Truncate a table (used for full-load mode)."""
        sql = f"TRUNCATE TABLE IF EXISTS {schema_table}"
        logger.warning("Truncating table: %s", schema_table)
        self.execute_query(sql)
