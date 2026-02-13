-- ============================================================
-- SNOWBRIX E-COMMERCE PLATFORM
-- Snowflake Environment Setup
-- ============================================================
-- Run this script as SYSADMIN in a Snowflake worksheet.
-- Idempotent: safe to re-run.
-- ============================================================

USE ROLE SYSADMIN;

-- ============================================================
-- SECTION 1: DATABASES & SCHEMAS
-- ============================================================

-- RAW: Landing zone for all ingested data. No transformations.
-- 90-day time travel for recovery from ingestion bugs.
CREATE DATABASE IF NOT EXISTS ECOMMERCE_RAW
    DATA_RETENTION_TIME_IN_DAYS = 90
    COMMENT = 'Raw ingested data from all source systems. No transformations applied.';

-- One schema per source system for clear lineage
CREATE SCHEMA IF NOT EXISTS ECOMMERCE_RAW.POSTGRES
    COMMENT = 'Data extracted from the source PostgreSQL database';
CREATE SCHEMA IF NOT EXISTS ECOMMERCE_RAW.STRIPE
    COMMENT = 'Data extracted from the Stripe payments API';
CREATE SCHEMA IF NOT EXISTS ECOMMERCE_RAW.CSV_UPLOADS
    COMMENT = 'Data loaded from CSV files (Google Sheets, manual uploads)';

-- STAGING: dbt staging layer. Views over raw data.
-- 1-day retention — these are views, minimal storage.
CREATE DATABASE IF NOT EXISTS ECOMMERCE_STAGING
    DATA_RETENTION_TIME_IN_DAYS = 1
    COMMENT = 'dbt staging layer. Cleaned and typed views over raw data.';

CREATE SCHEMA IF NOT EXISTS ECOMMERCE_STAGING.STAGING
    COMMENT = 'All dbt staging models (stg_*)';

-- ANALYTICS: Production models consumed by dashboards and analysts.
-- 30-day retention for rollback safety on transform logic changes.
CREATE DATABASE IF NOT EXISTS ECOMMERCE_ANALYTICS
    DATA_RETENTION_TIME_IN_DAYS = 30
    COMMENT = 'Production analytics layer. Star schema: dimensions, facts, aggregates.';

CREATE SCHEMA IF NOT EXISTS ECOMMERCE_ANALYTICS.INTERMEDIATE
    COMMENT = 'dbt intermediate models (int_*). Business logic joins.';
CREATE SCHEMA IF NOT EXISTS ECOMMERCE_ANALYTICS.MARTS
    COMMENT = 'dbt mart models (dim_*, fct_*). Final consumption layer.';


-- ============================================================
-- SECTION 2: WAREHOUSES
-- ============================================================

-- LOADING: Small, fast auto-suspend. Ingestion is I/O-bound.
CREATE WAREHOUSE IF NOT EXISTS LOADING_WH
    WITH WAREHOUSE_SIZE = 'SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    MIN_CLUSTER_COUNT = 1
    MAX_CLUSTER_COUNT = 1
    SCALING_POLICY = 'STANDARD'
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Data ingestion workloads. Small size, 60s auto-suspend.';

-- TRANSFORMING: Medium for JOIN-heavy dbt runs. 120s suspend avoids
-- restart cycles between dbt models (5-15s gaps between queries).
CREATE WAREHOUSE IF NOT EXISTS TRANSFORMING_WH
    WITH WAREHOUSE_SIZE = 'MEDIUM'
    AUTO_SUSPEND = 120
    AUTO_RESUME = TRUE
    MIN_CLUSTER_COUNT = 1
    MAX_CLUSTER_COUNT = 1
    SCALING_POLICY = 'STANDARD'
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'dbt transformation workloads. Medium for complex JOINs.';

-- REPORTING: Small with scale-out for concurrent dashboard users.
CREATE WAREHOUSE IF NOT EXISTS REPORTING_WH
    WITH WAREHOUSE_SIZE = 'SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    MIN_CLUSTER_COUNT = 1
    MAX_CLUSTER_COUNT = 2
    SCALING_POLICY = 'STANDARD'
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Dashboard queries and analyst ad-hoc. Scale-out for concurrency.';


-- ============================================================
-- VERIFICATION
-- ============================================================

SHOW DATABASES LIKE 'ECOMMERCE%';
SHOW WAREHOUSES LIKE '%_WH';
