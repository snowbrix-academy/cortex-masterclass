/*
=============================================================================
  MODULE 02 : COST COLLECTION
  SCRIPT 01 : Cost Tables & Global Configuration
=============================================================================
  SNOWBRIX ACADEMY — Enterprise FinOps Dashboard for Snowflake

  LEARNING OBJECTIVES:
    1. Create fact tables for warehouse, query, storage, and serverless costs
    2. Understand cost data grain and partitioning strategy
    3. Configure global settings (credit pricing, collection frequency)
    4. Design for scalability (millions of rows, fast queries)

  PREREQUISITES:
    - Module 01 completed (databases, warehouses, roles created)
    - Understanding of Snowflake cost model:
      * Compute credits (warehouse consumption)
      * Storage costs (active + time-travel + failsafe)
      * Cloud services credits (free up to 10% of daily compute)
      * Serverless features (tasks, Snowpipe, materialized views)

  COST DATA ARCHITECTURE:
  ┌──────────────────────────────────────────────────────────────┐
  │  Snowflake Account Usage Views (Source)                      │
  │  ├── WAREHOUSE_METERING_HISTORY (warehouse credits)          │
  │  ├── QUERY_HISTORY (query execution costs)                   │
  │  ├── DATABASE_STORAGE_USAGE_HISTORY (storage GB)             │
  │  ├── TASK_HISTORY (serverless task costs)                    │
  │  ├── PIPE_USAGE_HISTORY (Snowpipe costs)                     │
  │  └── MATERIALIZED_VIEW_REFRESH_HISTORY (MV costs)            │
  └──────────────────────────────────────────────────────────────┘
                            │
                            │ Collected by stored procedures
                            ▼
  ┌──────────────────────────────────────────────────────────────┐
  │  FINOPS_CONTROL_DB.COST_DATA Schema (Fact Tables)            │
  │  ├── FACT_WAREHOUSE_COST_HISTORY                             │
  │  │   Grain: Per warehouse per minute                         │
  │  │   Partition: By USAGE_DATE                                │
  │  │                                                            │
  │  ├── FACT_QUERY_COST_HISTORY                                 │
  │  │   Grain: Per query                                        │
  │  │   Partition: By QUERY_DATE                                │
  │  │                                                            │
  │  ├── FACT_STORAGE_COST_HISTORY                               │
  │  │   Grain: Per database per day                             │
  │  │   Partition: By USAGE_DATE                                │
  │  │                                                            │
  │  └── FACT_SERVERLESS_COST_HISTORY                            │
  │      Grain: Per serverless feature per execution             │
  │      Partition: By USAGE_DATE                                │
  └──────────────────────────────────────────────────────────────┘

=============================================================================
*/

USE ROLE FINOPS_ADMIN_ROLE;
USE WAREHOUSE FINOPS_WH_ADMIN;
USE SCHEMA FINOPS_CONTROL_DB.CONFIG;

-- =========================================================================
-- STEP 1: CREATE GLOBAL_SETTINGS TABLE
-- Stores framework-wide configuration parameters
-- =========================================================================

CREATE TABLE IF NOT EXISTS FINOPS_CONTROL_DB.CONFIG.GLOBAL_SETTINGS (
    SETTING_NAME VARCHAR(100) NOT NULL,
    SETTING_VALUE VARCHAR(500) NOT NULL,
    SETTING_DESCRIPTION VARCHAR(1000),
    DATA_TYPE VARCHAR(20) DEFAULT 'STRING',  -- STRING, NUMERIC, BOOLEAN, DATE
    LAST_UPDATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_BY VARCHAR(100) DEFAULT CURRENT_USER(),
    CONSTRAINT PK_GLOBAL_SETTINGS PRIMARY KEY (SETTING_NAME)
)
COMMENT = 'Global configuration settings for FinOps framework';

-- Insert default settings
INSERT INTO FINOPS_CONTROL_DB.CONFIG.GLOBAL_SETTINGS (
    SETTING_NAME, SETTING_VALUE, SETTING_DESCRIPTION, DATA_TYPE
) VALUES
    ('CREDIT_PRICE_USD', '3.00', 'Snowflake credit price in USD (update based on your contract)', 'NUMERIC'),
    ('STORAGE_PRICE_USD_PER_TB_MONTH', '23.00', 'Snowflake storage price per TB per month for on-demand (adjust by region)', 'NUMERIC'),
    ('CLOUD_SERVICES_FREE_THRESHOLD_PCT', '0.10', 'Cloud services credits free up to this % of daily compute credits', 'NUMERIC'),
    ('COST_COLLECTION_FREQUENCY_HOURS', '1', 'How often to collect warehouse and query costs (hours)', 'NUMERIC'),
    ('STORAGE_COLLECTION_FREQUENCY_DAYS', '1', 'How often to collect storage costs (days)', 'NUMERIC'),
    ('BUDGET_CHECK_FREQUENCY_HOURS', '24', 'How often to check budgets and trigger alerts (hours)', 'NUMERIC'),
    ('RECOMMENDATION_FREQUENCY_DAYS', '7', 'How often to generate optimization recommendations (days)', 'NUMERIC'),
    ('IDLE_WAREHOUSE_THRESHOLD_PCT', '0.50', 'Warehouse idle time % to flag as optimization candidate', 'NUMERIC'),
    ('EXPENSIVE_QUERY_THRESHOLD_USD', '10.00', 'Query cost threshold to flag as expensive', 'NUMERIC'),
    ('ANOMALY_DETECTION_SIGMA', '2.0', 'Z-score threshold for anomaly detection (2.0 = 2 standard deviations)', 'NUMERIC'),
    ('UNALLOCATED_COST_GOAL_PCT', '0.05', 'Target % of costs that remain unallocated (goal: <5%)', 'NUMERIC'),
    ('FRAMEWORK_TIMEZONE', 'America/New_York', 'Timezone for reporting and task scheduling', 'STRING')
;

-- =========================================================================
-- STEP 2: CREATE FACT_WAREHOUSE_COST_HISTORY
-- Stores per-minute warehouse credit consumption from WAREHOUSE_METERING_HISTORY
-- =========================================================================

USE SCHEMA FINOPS_CONTROL_DB.COST_DATA;

CREATE TABLE IF NOT EXISTS FACT_WAREHOUSE_COST_HISTORY (
    -- Grain: Per warehouse per minute
    WAREHOUSE_NAME VARCHAR(255) NOT NULL,
    START_TIME TIMESTAMP_NTZ NOT NULL,
    END_TIME TIMESTAMP_NTZ NOT NULL,
    USAGE_DATE DATE NOT NULL,           -- Partition key for performance

    -- Credit metrics
    CREDITS_USED NUMBER(38, 9) NOT NULL,
    CREDITS_USED_COMPUTE NUMBER(38, 9),
    CREDITS_USED_CLOUD_SERVICES NUMBER(38, 9),

    -- Cost metrics (calculated using configurable pricing)
    COST_USD NUMBER(38, 4),
    COST_COMPUTE_USD NUMBER(38, 4),
    COST_CLOUD_SERVICES_USD NUMBER(38, 4),

    -- Metadata
    COLLECTED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    COLLECTED_BY VARCHAR(100) DEFAULT CURRENT_USER(),

    -- Constraints
    CONSTRAINT PK_WAREHOUSE_COST PRIMARY KEY (WAREHOUSE_NAME, START_TIME)
)
PARTITION BY (USAGE_DATE)
COMMENT = 'Fact table: Per-minute warehouse credit consumption and cost';

-- Add clustering for common query patterns
ALTER TABLE FACT_WAREHOUSE_COST_HISTORY CLUSTER BY (USAGE_DATE, WAREHOUSE_NAME);


-- =========================================================================
-- STEP 3: CREATE FACT_QUERY_COST_HISTORY
-- Stores per-query cost attribution with user, role, warehouse, tags
-- =========================================================================

CREATE TABLE IF NOT EXISTS FACT_QUERY_COST_HISTORY (
    -- Grain: Per query
    QUERY_ID VARCHAR(100) NOT NULL,
    QUERY_DATE DATE NOT NULL,           -- Partition key

    -- Query metadata
    QUERY_TEXT VARCHAR(10000),          -- Truncated for storage efficiency
    QUERY_TYPE VARCHAR(50),             -- SELECT, INSERT, UPDATE, DELETE, MERGE, DDL, etc.
    WAREHOUSE_NAME VARCHAR(255),
    DATABASE_NAME VARCHAR(255),
    SCHEMA_NAME VARCHAR(255),

    -- User and role attribution
    USER_NAME VARCHAR(255),
    ROLE_NAME VARCHAR(255),
    SESSION_ID NUMBER(38, 0),

    -- Execution metrics
    START_TIME TIMESTAMP_NTZ,
    END_TIME TIMESTAMP_NTZ,
    EXECUTION_TIME_MS NUMBER(38, 0),
    QUEUED_TIME_MS NUMBER(38, 0),
    COMPILATION_TIME_MS NUMBER(38, 0),

    -- Data scanned
    BYTES_SCANNED NUMBER(38, 0),
    ROWS_PRODUCED NUMBER(38, 0),
    PARTITIONS_SCANNED NUMBER(38, 0),
    PARTITIONS_TOTAL NUMBER(38, 0),

    -- Cost calculation
    WAREHOUSE_SIZE VARCHAR(20),         -- XSMALL, SMALL, MEDIUM, etc.
    WAREHOUSE_SIZE_CREDITS NUMBER(38, 4), -- Credits per hour for this warehouse size
    EXECUTION_TIME_HOURS NUMBER(38, 9), -- execution_time_ms / 3600000
    CREDITS_USED NUMBER(38, 9),         -- execution_time_hours * warehouse_size_credits
    COST_USD NUMBER(38, 4),             -- credits_used * credit_price

    -- Tags for attribution
    QUERY_TAG VARCHAR(2000),            -- User-set query tag for attribution
    APPLICATION_NAME VARCHAR(255),      -- Detected application (Power BI, Tableau, dbt)
    BI_TOOL_NAME VARCHAR(100),          -- Classified BI tool (set by SP_CLASSIFY_BI_CHANNELS)

    -- Error handling
    ERROR_CODE VARCHAR(10),
    ERROR_MESSAGE VARCHAR(1000),

    -- Metadata
    COLLECTED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    COLLECTED_BY VARCHAR(100) DEFAULT CURRENT_USER(),

    -- Constraints
    CONSTRAINT PK_QUERY_COST PRIMARY KEY (QUERY_ID)
)
PARTITION BY (QUERY_DATE)
COMMENT = 'Fact table: Per-query cost attribution with user, role, warehouse, and tags';

-- Add clustering
ALTER TABLE FACT_QUERY_COST_HISTORY CLUSTER BY (QUERY_DATE, WAREHOUSE_NAME, USER_NAME);


-- =========================================================================
-- STEP 4: CREATE FACT_STORAGE_COST_HISTORY
-- Stores daily storage costs by database (active + time-travel + failsafe)
-- =========================================================================

CREATE TABLE IF NOT EXISTS FACT_STORAGE_COST_HISTORY (
    -- Grain: Per database per day
    DATABASE_NAME VARCHAR(255) NOT NULL,
    USAGE_DATE DATE NOT NULL,           -- Partition key

    -- Storage metrics (in bytes)
    ACTIVE_BYTES NUMBER(38, 0),
    TIME_TRAVEL_BYTES NUMBER(38, 0),
    FAILSAFE_BYTES NUMBER(38, 0),
    TOTAL_BYTES NUMBER(38, 0),

    -- Storage metrics (converted to TB)
    ACTIVE_TB NUMBER(38, 6),            -- active_bytes / 1099511627776
    TIME_TRAVEL_TB NUMBER(38, 6),
    FAILSAFE_TB NUMBER(38, 6),
    TOTAL_TB NUMBER(38, 6),

    -- Cost metrics
    COST_ACTIVE_USD NUMBER(38, 4),      -- active_TB * daily_storage_rate
    COST_TIME_TRAVEL_USD NUMBER(38, 4),
    COST_FAILSAFE_USD NUMBER(38, 4),
    COST_TOTAL_USD NUMBER(38, 4),

    -- Metadata
    COLLECTED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    COLLECTED_BY VARCHAR(100) DEFAULT CURRENT_USER(),

    -- Constraints
    CONSTRAINT PK_STORAGE_COST PRIMARY KEY (DATABASE_NAME, USAGE_DATE)
)
PARTITION BY (USAGE_DATE)
COMMENT = 'Fact table: Daily storage costs by database (active, time-travel, failsafe)';


-- =========================================================================
-- STEP 5: CREATE FACT_SERVERLESS_COST_HISTORY
-- Stores costs for serverless features (tasks, Snowpipe, materialized views)
-- =========================================================================

CREATE TABLE IF NOT EXISTS FACT_SERVERLESS_COST_HISTORY (
    -- Grain: Per serverless execution
    FEATURE_TYPE VARCHAR(50) NOT NULL,  -- TASK, SNOWPIPE, MATERIALIZED_VIEW, SEARCH_OPTIMIZATION, AUTO_CLUSTERING
    OBJECT_NAME VARCHAR(500) NOT NULL,
    EXECUTION_ID VARCHAR(100),
    USAGE_DATE DATE NOT NULL,           -- Partition key

    -- Execution metadata
    START_TIME TIMESTAMP_NTZ,
    END_TIME TIMESTAMP_NTZ,
    DATABASE_NAME VARCHAR(255),
    SCHEMA_NAME VARCHAR(255),

    -- Cost metrics
    CREDITS_USED NUMBER(38, 9),
    COST_USD NUMBER(38, 4),

    -- Metadata
    COLLECTED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    COLLECTED_BY VARCHAR(100) DEFAULT CURRENT_USER(),

    -- Constraints
    CONSTRAINT PK_SERVERLESS_COST PRIMARY KEY (FEATURE_TYPE, OBJECT_NAME, USAGE_DATE, EXECUTION_ID)
)
PARTITION BY (USAGE_DATE)
COMMENT = 'Fact table: Serverless feature costs (tasks, Snowpipe, materialized views, etc.)';


-- =========================================================================
-- STEP 6: CREATE PROCEDURE_EXECUTION_LOG (For Audit Trail)
-- Logs execution of all FinOps stored procedures
-- =========================================================================

USE SCHEMA FINOPS_CONTROL_DB.AUDIT;

CREATE TABLE IF NOT EXISTS PROCEDURE_EXECUTION_LOG (
    EXECUTION_ID VARCHAR(100) NOT NULL DEFAULT UUID_STRING(),
    PROCEDURE_NAME VARCHAR(255) NOT NULL,
    EXECUTION_STATUS VARCHAR(20) NOT NULL,  -- SUCCESS, ERROR
    START_TIME TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    END_TIME TIMESTAMP_NTZ,
    DURATION_SECONDS NUMBER(38, 2),
    ROWS_INSERTED NUMBER(38, 0),
    ROWS_UPDATED NUMBER(38, 0),
    ROWS_DELETED NUMBER(38, 0),
    ERROR_MESSAGE VARCHAR(5000),
    EXECUTION_PARAMETERS VARIANT,       -- JSON of input parameters
    EXECUTED_BY VARCHAR(100) DEFAULT CURRENT_USER(),

    CONSTRAINT PK_PROC_EXEC_LOG PRIMARY KEY (EXECUTION_ID)
)
COMMENT = 'Audit log: Execution history of all FinOps stored procedures';


-- =========================================================================
-- VERIFICATION QUERIES
-- =========================================================================

-- Verify global settings
SELECT * FROM FINOPS_CONTROL_DB.CONFIG.GLOBAL_SETTINGS
ORDER BY SETTING_NAME;

-- List all cost tables
SHOW TABLES IN SCHEMA FINOPS_CONTROL_DB.COST_DATA;

-- Verify table structures
DESC TABLE FINOPS_CONTROL_DB.COST_DATA.FACT_WAREHOUSE_COST_HISTORY;
DESC TABLE FINOPS_CONTROL_DB.COST_DATA.FACT_QUERY_COST_HISTORY;
DESC TABLE FINOPS_CONTROL_DB.COST_DATA.FACT_STORAGE_COST_HISTORY;
DESC TABLE FINOPS_CONTROL_DB.COST_DATA.FACT_SERVERLESS_COST_HISTORY;

-- Verify audit table
DESC TABLE FINOPS_CONTROL_DB.AUDIT.PROCEDURE_EXECUTION_LOG;


/*
=============================================================================
  BEST PRACTICES & TIPS:

  1. PARTITIONING STRATEGY:
     - Partition by date for cost tables (USAGE_DATE, QUERY_DATE)
     - Snowflake automatically prunes partitions for date-range queries
     - Significant performance improvement for large datasets (millions of rows)

  2. CLUSTERING:
     - Cluster by (date, warehouse_name) for typical query patterns
     - Improves performance for queries filtering by warehouse or time range
     - Auto-maintained by Snowflake (uses micro-partitions)

  3. GRAIN SELECTION:
     - Warehouse costs: Per minute (matches WAREHOUSE_METERING_HISTORY grain)
     - Query costs: Per query (one row per query execution)
     - Storage costs: Per day (storage doesn't change minute-by-minute)
     - Serverless costs: Per execution (one row per task run, pipe load, etc.)

  4. IDEMPOTENCY:
     - Use PRIMARY KEY constraints to prevent duplicates
     - Cost collection procedures will use MERGE statements to upsert
     - Safe to re-run collection for the same date range

  5. CONFIGURABLE PRICING:
     - Never hard-code credit price or storage price
     - Store in GLOBAL_SETTINGS for easy updates
     - Credit price varies by: contract, edition, cloud provider, region
     - Storage price varies by: region, cloud provider

  6. COST CALCULATION FORMULA:
     - Warehouse cost: credits_used * credit_price_usd
     - Query cost: (execution_time_ms / 3600000) * warehouse_size_credits * credit_price
     - Storage cost: (total_bytes / 1099511627776) * storage_price_per_tb_month / 30
     - Cloud services: Only charge if >10% of daily compute credits

  7. CLOUD SERVICES 10% THRESHOLD:
     - Snowflake provides cloud services credits free up to 10% of daily compute
     - Only charge for cloud services credits ABOVE this threshold
     - Must calculate daily aggregate, then apply threshold
     - Will be handled in SP_COLLECT_WAREHOUSE_COSTS

  8. QUERY_TEXT TRUNCATION:
     - Store only first 10,000 characters of query text
     - Prevents table bloat from very long queries
     - Sufficient for cost analysis and optimization

  9. AUDIT TRAIL:
     - PROCEDURE_EXECUTION_LOG tracks every procedure run
     - Enables troubleshooting and performance monitoring
     - Stores input parameters as JSON for reproducibility

  10. TIME ZONE HANDLING:
     - All timestamps stored as TIMESTAMP_NTZ (no time zone)
     - Snowflake ACCOUNT_USAGE views use UTC
     - Reporting views will convert to local time zone (from GLOBAL_SETTINGS)

  WHAT'S NEXT:
  → Module 02, Script 02: SP_COLLECT_WAREHOUSE_COSTS (collect warehouse costs)
  → Module 02, Script 03: SP_COLLECT_QUERY_COSTS (collect query costs)
=============================================================================
*/
