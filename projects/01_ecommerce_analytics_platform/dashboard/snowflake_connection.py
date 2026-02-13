"""
Snowbrix E-Commerce Platform — Dashboard Snowflake Connection

Provides a cached Snowflake connection for the Streamlit dashboard.
Uses @st.cache_resource to maintain a single connection across page reruns.
Connects with ECOMMERCE_ANALYST role (read-only access to ANALYTICS database).
"""

import os
import logging
from pathlib import Path

import streamlit as st
import snowflake.connector
import pandas as pd
from dotenv import load_dotenv

# Load environment variables
PROJECT_ROOT = Path(__file__).parent.parent
load_dotenv(PROJECT_ROOT / ".env")

logger = logging.getLogger(__name__)


@st.cache_resource
def get_connection():
    """
    Create and cache a Snowflake connection.

    Uses ECOMMERCE_ANALYST role with REPORTING_WH warehouse.
    Connection persists across Streamlit reruns for performance.

    Returns:
        snowflake.connector.Connection
    """
    try:
        conn = snowflake.connector.connect(
            account=os.getenv("SNOWFLAKE_ACCOUNT"),
            user=os.getenv("SNOWFLAKE_USER"),
            password=os.getenv("SNOWFLAKE_PASSWORD"),
            role=os.getenv("SNOWFLAKE_ROLE", "ECOMMERCE_ANALYST"),
            warehouse=os.getenv("STREAMLIT_SNOWFLAKE_WAREHOUSE", "REPORTING_WH"),
            database=os.getenv("STREAMLIT_SNOWFLAKE_DATABASE", "ECOMMERCE_ANALYTICS"),
            schema=os.getenv("STREAMLIT_SNOWFLAKE_SCHEMA", "MARTS"),
        )
        logger.info("Snowflake connection established for dashboard.")
        return conn
    except Exception as e:
        logger.error("Failed to connect to Snowflake: %s", e)
        st.error(
            "Could not connect to Snowflake. "
            "Check your .env file and ensure the account is accessible."
        )
        raise


def run_query(sql, params=None):
    """
    Execute a SQL query and return results as a Pandas DataFrame.

    Uses the cached connection. If the connection is stale, it will
    attempt to reconnect.

    Args:
        sql: SQL query string.
        params: Optional dict of query parameters.

    Returns:
        pd.DataFrame with query results.
    """
    conn = get_connection()
    try:
        return pd.read_sql(sql, conn, params=params)
    except snowflake.connector.errors.ProgrammingError as e:
        if "connection is closed" in str(e).lower():
            # Clear cache and retry
            get_connection.clear()
            conn = get_connection()
            return pd.read_sql(sql, conn, params=params)
        raise


def load_sql_file(filename):
    """
    Load a SQL query from the queries/ directory.

    Args:
        filename: Name of the SQL file (e.g., "revenue.sql")

    Returns:
        SQL string
    """
    query_path = Path(__file__).parent / "queries" / filename
    if not query_path.exists():
        raise FileNotFoundError(f"Query file not found: {query_path}")
    return query_path.read_text(encoding="utf-8")
