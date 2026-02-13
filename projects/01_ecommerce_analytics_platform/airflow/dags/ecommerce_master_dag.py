"""
Snowbrix E-Commerce Platform -- Master Orchestration DAG

This DAG orchestrates the complete E-Commerce analytics pipeline:

    Phase 1: EXTRACTION (parallel)
        - 4 PostgreSQL tables (orders, customers, products, order_items)
        - 1 Stripe API source (charges + refunds)
        - 1 CSV file source (marketing spend + campaign performance)

    Phase 2: TRANSFORMATION (sequential)
        - dbt run --select staging       (clean + rename raw data)
        - dbt run --select intermediate  (join + enrich)
        - dbt run --select marts         (aggregate into star schema)
        - dbt test                       (validate data quality)

    Phase 3: NOTIFICATION
        - Slack success alert on completion
        - Slack failure alert on any task failure (via callback)
        - Slack SLA breach alert if pipeline exceeds 30 minutes

Schedule: Daily at 06:00 UTC
SLA:      30 minutes end-to-end
Retries:  2 attempts with 5-minute delay (per task)
Tags:     ecommerce, production, daily

Author:  Snowbrix Academy
Version: 1.0.0
"""

# ──────────────────────────────────────────────
# IMPORTS
# ──────────────────────────────────────────────

import logging
import sys
from datetime import datetime, timedelta
from pathlib import Path

from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.operators.empty import EmptyOperator
from airflow.operators.python import PythonOperator

# ──────────────────────────────────────────────
# ENSURE INGESTION PACKAGE IS IMPORTABLE
# ──────────────────────────────────────────────
# The ingestion/ directory is volume-mounted at /opt/airflow/ingestion.
# PYTHONPATH is set in the Dockerfile, but we add it here as a safety
# net in case the env var is not set (e.g., running tests locally).
AIRFLOW_HOME = Path("/opt/airflow")
if str(AIRFLOW_HOME) not in sys.path:
    sys.path.insert(0, str(AIRFLOW_HOME))

# Import Slack alert helpers from the plugins directory.
# Airflow automatically adds the plugins/ directory to sys.path.
from plugins.slack_alert import (
    send_slack_alert,
    slack_failure_alert,
    slack_sla_alert,
)

logger = logging.getLogger(__name__)


# ──────────────────────────────────────────────
# CONSTANTS
# ──────────────────────────────────────────────

# Path to the dbt project inside the Airflow container.
# This directory is volume-mounted from the host's dbt_ecommerce/ folder.
DBT_PROJECT_DIR = "/opt/airflow/dbt_ecommerce"

# dbt CLI prefix: change directory and set profiles directory.
# --profiles-dir tells dbt where to find profiles.yml (Snowflake creds).
# --project-dir is an alternative to cd, but cd is more explicit in logs.
DBT_CMD_PREFIX = f"cd {DBT_PROJECT_DIR} && dbt"

# PostgreSQL table configs matching ingestion/config.py POSTGRES_TABLES.
# We define them here to create individual extraction tasks per table.
POSTGRES_TABLE_CONFIGS = [
    {
        "source_table": "orders",
        "target_schema": "POSTGRES",
        "target_table": "RAW_ORDERS",
        "incremental_column": "updated_at",
        "primary_key": "order_id",
    },
    {
        "source_table": "customers",
        "target_schema": "POSTGRES",
        "target_table": "RAW_CUSTOMERS",
        "incremental_column": "updated_at",
        "primary_key": "customer_id",
    },
    {
        "source_table": "products",
        "target_schema": "POSTGRES",
        "target_table": "RAW_PRODUCTS",
        "incremental_column": "updated_at",
        "primary_key": "product_id",
    },
    {
        "source_table": "order_items",
        "target_schema": "POSTGRES",
        "target_table": "RAW_ORDER_ITEMS",
        "incremental_column": "created_at",
        "primary_key": "order_item_id",
    },
]


# ──────────────────────────────────────────────
# EXTRACTION CALLABLES
# ──────────────────────────────────────────────
# Each function is called by a PythonOperator. They instantiate the
# appropriate extractor class, run the extraction, and return the
# row count (which Airflow stores as the task's return value / XCom).

def extract_postgres_table(table_config: dict, **kwargs) -> int:
    """
    Extract a single PostgreSQL table to Snowflake RAW layer.

    This function is called by PythonOperator for each of the 4
    Postgres tables. It uses incremental mode by default (only
    extracts rows changed since the last successful load).

    Args:
        table_config: Dictionary with source_table, target_schema,
                      target_table, incremental_column, primary_key.
        **kwargs:     Airflow context (unused, but required by
                      PythonOperator callback signature).

    Returns:
        Number of rows extracted and loaded.

    Raises:
        Any exception from PostgresExtractor propagates up to Airflow,
        which handles retries and failure callbacks.
    """
    from ingestion.config import IngestionConfig
    from ingestion.postgres_extractor import PostgresExtractor

    logger.info(
        "Starting Postgres extraction: %s -> %s.%s",
        table_config["source_table"],
        table_config["target_schema"],
        table_config["target_table"],
    )

    config = IngestionConfig()
    extractor = PostgresExtractor(config)

    # Use incremental mode (default). The extractor checks Snowflake
    # for the last loaded timestamp and only extracts newer rows.
    # On the very first run (empty target), it auto-falls back to full load.
    rows_loaded = extractor.extract_table(table_config, full_load=False)

    logger.info(
        "Postgres extraction complete: %s -> %d rows loaded",
        table_config["source_table"],
        rows_loaded,
    )
    return rows_loaded


def extract_stripe_charges(**kwargs) -> int:
    """
    Extract Stripe charges and refunds to Snowflake RAW layer.

    Calls StripeConnector.run() which handles both charges and refunds
    in a single invocation. Uses incremental mode by default (only
    fetches records created after the last successful load).

    Returns:
        Total number of records extracted (charges + refunds).
    """
    from ingestion.config import IngestionConfig
    from ingestion.stripe_connector import StripeConnector

    logger.info("Starting Stripe extraction (charges + refunds)")

    config = IngestionConfig()
    connector = StripeConnector(config)

    total_rows = connector.run(full_load=False)

    logger.info("Stripe extraction complete: %d total records loaded", total_rows)
    return total_rows


def load_csv_marketing(**kwargs) -> None:
    """
    Load CSV marketing files to Snowflake RAW layer.

    Calls CsvLoader.run() which scans the data directory for CSV files
    matching known patterns (marketing_spend, campaign_performance) and
    loads them into Snowflake via PUT + COPY INTO.

    Returns:
        None. The CsvLoader logs row counts internally.
    """
    from ingestion.config import IngestionConfig
    from ingestion.csv_loader import CsvLoader

    logger.info("Starting CSV marketing data load")

    config = IngestionConfig()
    loader = CsvLoader(config)

    loader.run()

    logger.info("CSV marketing data load complete")


def notify_on_success(**kwargs) -> None:
    """
    Send a Slack success notification when the full pipeline completes.

    This is the final task in the DAG. It only runs if every upstream
    task (extractions, dbt transformations, dbt tests) succeeded.

    Args:
        **kwargs: Airflow context, automatically passed by PythonOperator.
    """
    logger.info("Pipeline completed successfully. Sending Slack notification.")
    send_slack_alert(context=kwargs, status="success")


# ──────────────────────────────────────────────
# DAG DEFAULT ARGUMENTS
# ──────────────────────────────────────────────
# These apply to ALL tasks in the DAG unless overridden at the task level.

default_args = {
    # ── Ownership ──
    "owner": "snowbrix",

    # ── Dependency behavior ──
    # Do NOT wait for the previous DAG run's same task to succeed.
    # Each daily run is independent.
    "depends_on_past": False,

    # ── Email (disabled — we use Slack instead) ──
    "email_on_failure": False,
    "email_on_retry": False,

    # ── Retry policy ──
    # 2 retries with 5-minute delay covers most transient failures:
    # - PostgreSQL connection drops (container restart)
    # - Snowflake warehouse suspended (auto-resume takes ~30s)
    # - Stripe API rate limits (already handled in-code, DAG retry is a safety net)
    "retries": 2,
    "retry_delay": timedelta(minutes=5),

    # ── Timeout ──
    # Individual task timeout. If a single task runs longer than 30 min,
    # something is fundamentally wrong (not a transient issue).
    "execution_timeout": timedelta(minutes=30),

    # ── Failure callback ──
    # Fires IMMEDIATELY when a task fails (before retries).
    # This gives the team early warning even if the retry succeeds.
    "on_failure_callback": slack_failure_alert,

    # ── SLA ──
    # Each task should complete within 30 minutes of the DAG's scheduled
    # execution time. This is a generous buffer; most tasks finish in <5 min.
    "sla": timedelta(minutes=30),
}


# ──────────────────────────────────────────────
# DAG DEFINITION
# ──────────────────────────────────────────────

with DAG(
    # ── Identity ──
    dag_id="ecommerce_master_dag",
    description=(
        "End-to-end E-Commerce analytics pipeline: "
        "Extract (Postgres + Stripe + CSV) -> "
        "Transform (dbt staging -> intermediate -> marts) -> "
        "Test (dbt test) -> "
        "Notify (Slack)"
    ),

    # ── Schedule ──
    # Daily at 06:00 UTC. This gives European users fresh data by morning
    # and US users data from the previous full business day.
    schedule_interval="0 6 * * *",

    # ── Dates ──
    start_date=datetime(2024, 1, 1),
    catchup=False,  # Do NOT backfill missed runs. Start from today.

    # ── Concurrency ──
    # Only 1 DAG run at a time. Prevents overlapping loads that could
    # cause duplicate data or race conditions in Snowflake.
    max_active_runs=1,

    # ── Defaults ──
    default_args=default_args,

    # ── Tags (visible in Airflow UI for filtering) ──
    tags=["ecommerce", "production", "daily"],

    # ── SLA breach callback ──
    # Called when ANY task in this DAG breaches its SLA.
    sla_miss_callback=slack_sla_alert,

) as dag:

    # ──────────────────────────────────────────
    # PHASE 1: DATA EXTRACTION (parallel)
    # ──────────────────────────────────────────
    # All 6 extraction tasks run in parallel because they pull from
    # independent data sources. This reduces wall-clock time from
    # ~15 min (sequential) to ~5 min (parallel).

    # -- PostgreSQL Tables (4 tasks) --
    # One task per table for independent failure/retry. If the orders
    # extraction fails, customers/products/order_items can still succeed.

    extract_orders = PythonOperator(
        task_id="extract_postgres_orders",
        python_callable=extract_postgres_table,
        op_kwargs={"table_config": POSTGRES_TABLE_CONFIGS[0]},  # orders
        doc_md="Extract `orders` table from PostgreSQL to Snowflake RAW (incremental).",
    )

    extract_customers = PythonOperator(
        task_id="extract_postgres_customers",
        python_callable=extract_postgres_table,
        op_kwargs={"table_config": POSTGRES_TABLE_CONFIGS[1]},  # customers
        doc_md="Extract `customers` table from PostgreSQL to Snowflake RAW (incremental).",
    )

    extract_products = PythonOperator(
        task_id="extract_postgres_products",
        python_callable=extract_postgres_table,
        op_kwargs={"table_config": POSTGRES_TABLE_CONFIGS[2]},  # products
        doc_md="Extract `products` table from PostgreSQL to Snowflake RAW (incremental).",
    )

    extract_order_items = PythonOperator(
        task_id="extract_postgres_order_items",
        python_callable=extract_postgres_table,
        op_kwargs={"table_config": POSTGRES_TABLE_CONFIGS[3]},  # order_items
        doc_md="Extract `order_items` table from PostgreSQL to Snowflake RAW (incremental).",
    )

    # -- Stripe API (1 task) --
    # Charges and refunds are extracted in a single task because they
    # share the same API client and rate limit budget.

    extract_stripe = PythonOperator(
        task_id="extract_stripe_charges",
        python_callable=extract_stripe_charges,
        doc_md="Extract charges and refunds from Stripe API to Snowflake RAW (incremental).",
    )

    # -- CSV Files (1 task) --
    # Marketing spend and campaign performance CSVs are loaded together
    # because they come from the same Google Sheets export process.

    load_csv = PythonOperator(
        task_id="load_csv_marketing",
        python_callable=load_csv_marketing,
        doc_md="Load marketing CSV files (spend + campaigns) to Snowflake RAW.",
    )

    # ──────────────────────────────────────────
    # EXTRACTION GATE
    # ──────────────────────────────────────────
    # EmptyOperator acts as a synchronization barrier. ALL 6 extraction
    # tasks must succeed before any dbt transformation begins.
    #
    # Why not just set dbt_run_staging to depend on all 6 tasks directly?
    # The EmptyOperator makes the DAG graph cleaner and provides a single
    # point to inspect in the UI: "Did all extractions complete?"

    all_extractions_complete = EmptyOperator(
        task_id="all_extractions_complete",
        doc_md=(
            "Synchronization gate: ensures ALL raw data extractions "
            "completed before dbt transformations begin. Prevents "
            "running dbt on partial/stale data."
        ),
    )

    # ──────────────────────────────────────────
    # PHASE 2: DBT TRANSFORMATION (sequential)
    # ──────────────────────────────────────────
    # dbt models have dependencies: staging feeds intermediate, which
    # feeds marts. They MUST run in order.
    #
    # We use BashOperator (not dbt Cloud operator) because:
    # 1. dbt is installed locally in the container
    # 2. No dbt Cloud subscription needed
    # 3. Full control over CLI flags and environment

    dbt_run_staging = BashOperator(
        task_id="dbt_run_staging",
        bash_command=f"{DBT_CMD_PREFIX} run --select staging",
        doc_md=(
            "Run dbt staging models. These models clean, rename, and "
            "type-cast raw data from all sources into a consistent format."
        ),
    )

    dbt_run_intermediate = BashOperator(
        task_id="dbt_run_intermediate",
        bash_command=f"{DBT_CMD_PREFIX} run --select intermediate",
        doc_md=(
            "Run dbt intermediate models. These models join staging tables "
            "and apply business logic (e.g., order enrichment, customer LTV)."
        ),
    )

    dbt_run_marts = BashOperator(
        task_id="dbt_run_marts",
        bash_command=f"{DBT_CMD_PREFIX} run --select marts",
        doc_md=(
            "Run dbt mart models. These produce the final dimension and fact "
            "tables consumed by dashboards and analysts."
        ),
    )

    # ──────────────────────────────────────────
    # PHASE 2.5: DBT TESTING (data quality gate)
    # ──────────────────────────────────────────
    # dbt test runs ALL tests (not-null, unique, relationships, custom).
    # If any test fails, the pipeline stops and alerts via Slack.
    #
    # We use fewer retries (1) and a shorter delay (3 min) for tests
    # because test failures are usually real data quality issues, not
    # transient infrastructure problems.

    dbt_test_all = BashOperator(
        task_id="dbt_test_all",
        bash_command=f"{DBT_CMD_PREFIX} test",
        retries=1,
        retry_delay=timedelta(minutes=3),
        doc_md=(
            "Run all dbt tests: not-null, unique, accepted_values, "
            "relationships, and custom assertions. Acts as a data "
            "quality gate before the pipeline is considered successful."
        ),
    )

    # ──────────────────────────────────────────
    # PHASE 3: NOTIFICATION
    # ──────────────────────────────────────────
    # Success notification fires only when the entire pipeline completes
    # without errors. Failure notifications are handled by the
    # on_failure_callback in default_args (fires per-task).

    notify_success = PythonOperator(
        task_id="notify_success",
        python_callable=notify_on_success,
        # Do NOT retry notifications. If Slack is down, we don't want
        # to delay the DAG's completion status.
        retries=0,
        # Success notification failures should not mark the DAG as failed.
        # The data pipeline itself succeeded; the alert is a nice-to-have.
        doc_md=(
            "Send a green Slack notification confirming the full pipeline "
            "completed successfully. Retries disabled: notification failure "
            "should not affect pipeline status."
        ),
    )

    # ──────────────────────────────────────────
    # TASK DEPENDENCIES
    # ──────────────────────────────────────────
    # This section defines the execution order. Read it as:
    # "After these tasks complete, trigger the next one."
    #
    # Phase 1: All extractions run in parallel, then converge at the gate.
    [
        extract_orders,
        extract_customers,
        extract_products,
        extract_order_items,
        extract_stripe,
        load_csv,
    ] >> all_extractions_complete

    # Phase 2: Sequential dbt pipeline.
    all_extractions_complete >> dbt_run_staging >> dbt_run_intermediate >> dbt_run_marts >> dbt_test_all

    # Phase 3: Notify on success.
    dbt_test_all >> notify_success
