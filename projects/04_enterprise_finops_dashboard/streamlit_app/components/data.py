"""
Data access layer for Snowflake connection and query execution
"""

import streamlit as st
import snowflake.connector
from snowflake.connector import SnowflakeConnection
from typing import Optional, Dict, Any
import pandas as pd
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()


def get_snowflake_connection() -> SnowflakeConnection:
    """
    Establish Snowflake connection using Streamlit secrets or environment variables.

    Priority:
    1. Streamlit secrets (st.secrets) - Production deployment
    2. Environment variables (.env file) - Local development
    3. Manual configuration - Fallback

    Returns:
        SnowflakeConnection: Active Snowflake connection

    Raises:
        Exception: If connection fails
    """
    try:
        # Try Streamlit secrets first (production)
        if "snowflake" in st.secrets:
            conn = snowflake.connector.connect(
                account=st.secrets["snowflake"]["account"],
                user=st.secrets["snowflake"]["user"],
                password=st.secrets["snowflake"]["password"],
                role=st.secrets["snowflake"].get("role", "FINOPS_ANALYST_ROLE"),
                warehouse=st.secrets["snowflake"].get("warehouse", "FINOPS_WH_REPORTING"),
                database=st.secrets["snowflake"].get("database", "FINOPS_CONTROL_DB"),
                schema=st.secrets["snowflake"].get("schema", "MONITORING")
            )
        # Try environment variables (local development)
        elif os.getenv("SNOWFLAKE_ACCOUNT"):
            conn = snowflake.connector.connect(
                account=os.getenv("SNOWFLAKE_ACCOUNT"),
                user=os.getenv("SNOWFLAKE_USER"),
                password=os.getenv("SNOWFLAKE_PASSWORD"),
                role=os.getenv("SNOWFLAKE_ROLE", "FINOPS_ANALYST_ROLE"),
                warehouse=os.getenv("SNOWFLAKE_WAREHOUSE", "FINOPS_WH_REPORTING"),
                database=os.getenv("SNOWFLAKE_DATABASE", "FINOPS_CONTROL_DB"),
                schema=os.getenv("SNOWFLAKE_SCHEMA", "MONITORING")
            )
        else:
            raise Exception("Snowflake connection configuration not found. Configure via Streamlit secrets or .env file.")

        return conn

    except Exception as e:
        raise Exception(f"Failed to connect to Snowflake: {str(e)}")


@st.cache_data(ttl=300)  # Cache for 5 minutes
def execute_query(_conn: SnowflakeConnection, query: str, params: Optional[Dict[str, Any]] = None) -> pd.DataFrame:
    """
    Execute a SQL query and return results as a DataFrame.

    Args:
        _conn: Snowflake connection (underscore prefix to exclude from hashing)
        query: SQL query string
        params: Optional query parameters (for parameterized queries)

    Returns:
        pd.DataFrame: Query results

    Note: Function is cached with 5-minute TTL. Use st.cache_data.clear() to force refresh.
    """
    try:
        cursor = _conn.cursor()

        if params:
            cursor.execute(query, params)
        else:
            cursor.execute(query)

        # Fetch results and column names
        results = cursor.fetchall()
        columns = [desc[0] for desc in cursor.description]

        # Convert to DataFrame
        df = pd.DataFrame(results, columns=columns)

        cursor.close()
        return df

    except Exception as e:
        st.error(f"Query execution failed: {str(e)}")
        return pd.DataFrame()  # Return empty DataFrame on error


def get_executive_summary(conn: SnowflakeConnection, start_date: str, end_date: str) -> pd.DataFrame:
    """
    Fetch executive summary KPIs.

    Args:
        conn: Snowflake connection
        start_date: Start date (YYYY-MM-DD)
        end_date: End date (YYYY-MM-DD)

    Returns:
        pd.DataFrame with columns: METRIC_NAME, METRIC_VALUE, METRIC_CHANGE_PCT
    """
    query = """
        SELECT
            'Total Spend' AS METRIC_NAME,
            SUM(TOTAL_COST_USD) AS METRIC_VALUE,
            ((SUM(TOTAL_COST_USD) - LAG(SUM(TOTAL_COST_USD)) OVER (ORDER BY DATE_TRUNC('month', COST_DATE)))
             / LAG(SUM(TOTAL_COST_USD)) OVER (ORDER BY DATE_TRUNC('month', COST_DATE))) * 100 AS METRIC_CHANGE_PCT
        FROM FINOPS_CONTROL_DB.MONITORING.VW_EXECUTIVE_SUMMARY
        WHERE COST_DATE BETWEEN %(start_date)s AND %(end_date)s
        GROUP BY DATE_TRUNC('month', COST_DATE)
        ORDER BY DATE_TRUNC('month', COST_DATE) DESC
        LIMIT 1
    """
    return execute_query(conn, query, {"start_date": start_date, "end_date": end_date})


def get_warehouse_costs(conn: SnowflakeConnection, start_date: str, end_date: str) -> pd.DataFrame:
    """
    Fetch warehouse costs for the specified date range.

    Args:
        conn: Snowflake connection
        start_date: Start date (YYYY-MM-DD)
        end_date: End date (YYYY-MM-DD)

    Returns:
        pd.DataFrame with columns: WAREHOUSE_NAME, TOTAL_COST_USD, TOTAL_CREDITS, UTILIZATION_PCT, IDLE_TIME_PCT
    """
    query = """
        SELECT
            WAREHOUSE_NAME,
            SUM(COST_USD) AS TOTAL_COST_USD,
            SUM(CREDITS_USED) AS TOTAL_CREDITS,
            AVG(UTILIZATION_PCT) AS AVG_UTILIZATION_PCT,
            AVG(IDLE_TIME_PCT) AS AVG_IDLE_TIME_PCT
        FROM FINOPS_CONTROL_DB.MONITORING.VW_WAREHOUSE_ANALYTICS
        WHERE USAGE_DATE BETWEEN %(start_date)s AND %(end_date)s
        GROUP BY WAREHOUSE_NAME
        ORDER BY TOTAL_COST_USD DESC
    """
    return execute_query(conn, query, {"start_date": start_date, "end_date": end_date})


def get_chargeback_report(conn: SnowflakeConnection, start_date: str, end_date: str,
                           dimension: str = 'DEPARTMENT') -> pd.DataFrame:
    """
    Fetch chargeback report by specified dimension.

    Args:
        conn: Snowflake connection
        start_date: Start date (YYYY-MM-DD)
        end_date: End date (YYYY-MM-DD)
        dimension: Dimension to group by (DEPARTMENT, TEAM, PROJECT, COST_CENTER)

    Returns:
        pd.DataFrame with costs grouped by dimension
    """
    query = f"""
        SELECT
            {dimension},
            SUM(TOTAL_COST_USD) AS TOTAL_COST_USD,
            SUM(COMPUTE_COST_USD) AS COMPUTE_COST_USD,
            SUM(STORAGE_COST_USD) AS STORAGE_COST_USD,
            COUNT(DISTINCT WAREHOUSE_NAME) AS WAREHOUSE_COUNT
        FROM FINOPS_CONTROL_DB.MONITORING.VW_CHARGEBACK_REPORT
        WHERE REPORT_DATE BETWEEN %(start_date)s AND %(end_date)s
        GROUP BY {dimension}
        ORDER BY TOTAL_COST_USD DESC
    """
    return execute_query(conn, query, {"start_date": start_date, "end_date": end_date})


def get_budget_status(conn: SnowflakeConnection) -> pd.DataFrame:
    """
    Fetch current budget status for all entities.

    Returns:
        pd.DataFrame with columns: ENTITY_NAME, BUDGET_AMOUNT, ACTUAL_SPEND, PCT_CONSUMED, STATUS
    """
    query = """
        SELECT
            ENTITY_NAME,
            ENTITY_TYPE,
            BUDGET_AMOUNT_USD,
            ACTUAL_SPEND_USD,
            PCT_CONSUMED,
            BUDGET_STATUS,
            DAYS_REMAINING,
            FORECAST_MONTH_END_USD
        FROM FINOPS_CONTROL_DB.MONITORING.VW_BUDGET_VS_ACTUAL
        WHERE BUDGET_PERIOD = 'MONTHLY'
            AND BUDGET_MONTH = DATE_TRUNC('month', CURRENT_DATE())
        ORDER BY PCT_CONSUMED DESC
    """
    return execute_query(conn, query)


def get_optimization_recommendations(conn: SnowflakeConnection, limit: int = 20) -> pd.DataFrame:
    """
    Fetch top optimization recommendations by potential savings.

    Args:
        conn: Snowflake connection
        limit: Maximum number of recommendations to return

    Returns:
        pd.DataFrame with top recommendations
    """
    query = """
        SELECT
            RECOMMENDATION_CATEGORY,
            RECOMMENDATION_TEXT,
            POTENTIAL_SAVINGS_USD,
            PRIORITY,
            CREATED_DATE,
            STATUS
        FROM FINOPS_CONTROL_DB.OPTIMIZATION.OPTIMIZATION_RECOMMENDATIONS
        WHERE STATUS = 'OPEN'
        ORDER BY POTENTIAL_SAVINGS_USD DESC
        LIMIT %(limit)s
    """
    return execute_query(conn, query, {"limit": limit})


def get_daily_spend_trend(conn: SnowflakeConnection, days: int = 30) -> pd.DataFrame:
    """
    Fetch daily spend trend for the last N days.

    Args:
        conn: Snowflake connection
        days: Number of days to fetch

    Returns:
        pd.DataFrame with columns: COST_DATE, TOTAL_COST_USD
    """
    query = """
        SELECT
            COST_DATE,
            SUM(TOTAL_COST_USD) AS TOTAL_COST_USD
        FROM FINOPS_CONTROL_DB.MONITORING.VW_DAILY_SPEND_TREND
        WHERE COST_DATE >= DATEADD(day, -(%(days)s), CURRENT_DATE())
        GROUP BY COST_DATE
        ORDER BY COST_DATE
    """
    return execute_query(conn, query, {"days": days})


def get_top_expensive_queries(conn: SnowflakeConnection, start_date: str, end_date: str, limit: int = 20) -> pd.DataFrame:
    """
    Fetch top expensive queries by cost.

    Args:
        conn: Snowflake connection
        start_date: Start date (YYYY-MM-DD)
        end_date: End date (YYYY-MM-DD)
        limit: Maximum number of queries to return

    Returns:
        pd.DataFrame with top expensive queries
    """
    query = """
        SELECT
            QUERY_ID,
            QUERY_TYPE,
            USER_NAME,
            WAREHOUSE_NAME,
            EXECUTION_TIME_MS,
            COST_USD,
            LEFT(QUERY_TEXT, 100) AS QUERY_TEXT_PREVIEW,
            START_TIME
        FROM FINOPS_CONTROL_DB.COST_DATA.FACT_QUERY_COST_HISTORY
        WHERE QUERY_DATE BETWEEN %(start_date)s AND %(end_date)s
        ORDER BY COST_USD DESC
        LIMIT %(limit)s
    """
    return execute_query(conn, query, {"start_date": start_date, "end_date": end_date, "limit": limit})


# Configuration helper functions
def get_global_setting(conn: SnowflakeConnection, setting_name: str) -> Any:
    """
    Fetch a global setting value.

    Args:
        conn: Snowflake connection
        setting_name: Name of the setting

    Returns:
        Setting value (type depends on DATA_TYPE)
    """
    query = """
        SELECT SETTING_VALUE, DATA_TYPE
        FROM FINOPS_CONTROL_DB.CONFIG.GLOBAL_SETTINGS
        WHERE SETTING_NAME = %(setting_name)s
    """
    df = execute_query(conn, query, {"setting_name": setting_name})

    if df.empty:
        return None

    value = df.iloc[0]['SETTING_VALUE']
    data_type = df.iloc[0]['DATA_TYPE']

    # Convert to appropriate type
    if data_type == 'NUMERIC':
        return float(value)
    elif data_type == 'BOOLEAN':
        return value.lower() in ('true', '1', 'yes')
    elif data_type == 'DATE':
        return pd.to_datetime(value).date()
    else:
        return value


def update_global_setting(conn: SnowflakeConnection, setting_name: str, setting_value: str) -> bool:
    """
    Update a global setting value.

    Args:
        conn: Snowflake connection
        setting_name: Name of the setting
        setting_value: New value (as string)

    Returns:
        True if successful, False otherwise
    """
    try:
        query = """
            UPDATE FINOPS_CONTROL_DB.CONFIG.GLOBAL_SETTINGS
            SET SETTING_VALUE = %(setting_value)s,
                LAST_UPDATED_AT = CURRENT_TIMESTAMP(),
                UPDATED_BY = CURRENT_USER()
            WHERE SETTING_NAME = %(setting_name)s
        """
        cursor = conn.cursor()
        cursor.execute(query, {"setting_name": setting_name, "setting_value": setting_value})
        conn.commit()
        cursor.close()
        return True
    except Exception as e:
        st.error(f"Failed to update setting: {str(e)}")
        return False
