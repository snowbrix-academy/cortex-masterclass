/*
#############################################################################
  FINOPS - Module 02: Cost Collection
  CONSOLIDATED WORKSHEET — Snowsight / VS Code Ready
#############################################################################
  SNOWBRIX ACADEMY — Enterprise FinOps Dashboard for Snowflake

  This worksheet contains:
    - 01_cost_tables.sql
    - 02_sp_collect_warehouse_costs.sql
    - 03_sp_collect_query_costs.sql
    - 04_sp_collect_storage_costs.sql
    

  INSTRUCTIONS:
    - Run each section sequentially (top to bottom)
    - Requires Module 01 to be completed first (if applicable)
    - Estimated time: ~30 minutes

  PREREQUISITES:
    - Module 01 completed
    - FINOPS_ADMIN_ROLE access
#############################################################################
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

-- ===========================================================================
-- ===========================================================================
-- 02_SP_COLLECT_WAREHOUSE_COSTS
-- ===========================================================================
-- ===========================================================================


USE ROLE FINOPS_ADMIN_ROLE;
USE DATABASE FINOPS_CONTROL_DB;
USE SCHEMA PROCEDURES;
USE WAREHOUSE FINOPS_WH_ADMIN;

-- =========================================================================
-- PROCEDURE: SP_COLLECT_WAREHOUSE_COSTS
-- Collects warehouse credit consumption from ACCOUNT_USAGE and calculates USD costs
-- =========================================================================
CREATE OR REPLACE PROCEDURE SP_COLLECT_WAREHOUSE_COSTS(
    P_LOOKBACK_HOURS    NUMBER DEFAULT 24,      -- How many hours back to collect
    P_INCREMENTAL       BOOLEAN DEFAULT TRUE    -- Only collect new data since last run
)
RETURNS VARIANT
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER
AS
$$
    // =====================================================================
    // HELPER FUNCTIONS
    // =====================================================================

    /**
     * Execute a SQL statement and return the result set
     */
    function executeSql(sqlText, binds) {
        try {
            var stmt = snowflake.createStatement({
                sqlText: sqlText,
                binds: binds || []
            });
            return stmt.execute();
        } catch (err) {
            throw new Error('SQL Error: ' + err.message + ' | SQL: ' + sqlText.substring(0, 200));
        }
    }

    /**
     * Execute SQL and return scalar value
     */
    function executeScalar(sqlText, binds) {
        var rs = executeSql(sqlText, binds);
        if (rs.next()) {
            return rs.getColumnValue(1);
        }
        return null;
    }

    /**
     * Log execution to audit table
     */
    function logExecution(execId, procName, status, startTime, endTime, rowsInserted, rowsUpdated, errorMsg, params) {
        try {
            var durationSeconds = (endTime - startTime) / 1000;
            executeSql(
                `INSERT INTO FINOPS_CONTROL_DB.AUDIT.PROCEDURE_EXECUTION_LOG
                (EXECUTION_ID, PROCEDURE_NAME, EXECUTION_STATUS, START_TIME, END_TIME,
                 DURATION_SECONDS, ROWS_INSERTED, ROWS_UPDATED, ERROR_MESSAGE, EXECUTION_PARAMETERS)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, PARSE_JSON(?))`,
                [execId, procName, status, startTime, endTime, durationSeconds,
                 rowsInserted, rowsUpdated, errorMsg, JSON.stringify(params)]
            );
        } catch (err) {
            // Audit logging failure should not break the procedure
            return;
        }
    }

    // =====================================================================
    // MAIN EXECUTION LOGIC
    // =====================================================================

    var executionId = executeScalar("SELECT UUID_STRING()");
    var procedureName = 'SP_COLLECT_WAREHOUSE_COSTS';
    var startTimestamp = new Date();
    var rowsInserted = 0;
    var rowsUpdated = 0;

    // Result object to return
    var result = {
        execution_id: executionId,
        procedure_name: procedureName,
        status: 'INITIALIZING',
        start_time: startTimestamp.toISOString(),
        parameters: {
            lookback_hours: P_LOOKBACK_HOURS,
            incremental: P_INCREMENTAL
        }
    };

    try {
        // =================================================================
        // STEP 1: GET CONFIGURATION
        // =================================================================

        var creditPrice = parseFloat(executeScalar(
            "SELECT SETTING_VALUE FROM FINOPS_CONTROL_DB.CONFIG.GLOBAL_SETTINGS WHERE SETTING_NAME = 'CREDIT_PRICE_USD'"
        ));

        if (!creditPrice || creditPrice <= 0) {
            throw new Error('Invalid credit price configuration. Check GLOBAL_SETTINGS table.');
        }

        result.credit_price_usd = creditPrice;

        // =================================================================
        // STEP 2: DETERMINE COLLECTION WINDOW
        // =================================================================

        var collectionStartTime;
        var collectionEndTime = new Date();

        if (P_INCREMENTAL) {
            // Get the last successful collection timestamp (watermark)
            var lastCollectionTime = executeScalar(`
                SELECT MAX(END_TIME)
                FROM FINOPS_CONTROL_DB.COST_DATA.FACT_WAREHOUSE_COST_HISTORY
            `);

            if (lastCollectionTime) {
                // Start from last collection, with 5-minute overlap to handle late-arriving data
                collectionStartTime = new Date(lastCollectionTime);
                collectionStartTime.setMinutes(collectionStartTime.getMinutes() - 5);
            } else {
                // First run - collect based on lookback hours
                collectionStartTime = new Date();
                collectionStartTime.setHours(collectionStartTime.getHours() - P_LOOKBACK_HOURS);
            }
        } else {
            // Full collection based on lookback hours
            collectionStartTime = new Date();
            collectionStartTime.setHours(collectionStartTime.getHours() - P_LOOKBACK_HOURS);
        }

        // Account for ACCOUNT_USAGE latency: don't collect data newer than 1 hour ago
        var maxEndTime = new Date();
        maxEndTime.setHours(maxEndTime.getHours() - 1);

        if (collectionEndTime > maxEndTime) {
            collectionEndTime = maxEndTime;
        }

        result.collection_window = {
            start_time: collectionStartTime.toISOString(),
            end_time: collectionEndTime.toISOString(),
            hours: ((collectionEndTime - collectionStartTime) / (1000 * 60 * 60)).toFixed(2)
        };

        // =================================================================
        // STEP 3: COLLECT WAREHOUSE METERING DATA
        // =================================================================

        result.status = 'COLLECTING_DATA';

        // Use MERGE for idempotent collection (safe to re-run)
        var mergeSql = `
        MERGE INTO FINOPS_CONTROL_DB.COST_DATA.FACT_WAREHOUSE_COST_HISTORY AS target
        USING (
            SELECT
                WAREHOUSE_NAME,
                START_TIME,
                END_TIME,
                DATE(START_TIME) AS USAGE_DATE,

                -- Credit metrics
                CREDITS_USED,
                CREDITS_USED_COMPUTE,
                CREDITS_USED_CLOUD_SERVICES,

                -- Cost calculations
                CREDITS_USED * ? AS COST_USD,
                CREDITS_USED_COMPUTE * ? AS COST_COMPUTE_USD,
                CREDITS_USED_CLOUD_SERVICES * ? AS COST_CLOUD_SERVICES_USD

            FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
            WHERE START_TIME >= ?
              AND START_TIME < ?
              AND WAREHOUSE_NAME IS NOT NULL
              AND CREDITS_USED > 0  -- Exclude zero-credit entries
        ) AS source
        ON target.WAREHOUSE_NAME = source.WAREHOUSE_NAME
           AND target.START_TIME = source.START_TIME
        WHEN MATCHED THEN
            UPDATE SET
                target.END_TIME = source.END_TIME,
                target.USAGE_DATE = source.USAGE_DATE,
                target.CREDITS_USED = source.CREDITS_USED,
                target.CREDITS_USED_COMPUTE = source.CREDITS_USED_COMPUTE,
                target.CREDITS_USED_CLOUD_SERVICES = source.CREDITS_USED_CLOUD_SERVICES,
                target.COST_USD = source.COST_USD,
                target.COST_COMPUTE_USD = source.COST_COMPUTE_USD,
                target.COST_CLOUD_SERVICES_USD = source.COST_CLOUD_SERVICES_USD,
                target.COLLECTED_AT = CURRENT_TIMESTAMP()
        WHEN NOT MATCHED THEN
            INSERT (
                WAREHOUSE_NAME, START_TIME, END_TIME, USAGE_DATE,
                CREDITS_USED, CREDITS_USED_COMPUTE, CREDITS_USED_CLOUD_SERVICES,
                COST_USD, COST_COMPUTE_USD, COST_CLOUD_SERVICES_USD,
                COLLECTED_AT, COLLECTED_BY
            )
            VALUES (
                source.WAREHOUSE_NAME, source.START_TIME, source.END_TIME, source.USAGE_DATE,
                source.CREDITS_USED, source.CREDITS_USED_COMPUTE, source.CREDITS_USED_CLOUD_SERVICES,
                source.COST_USD, source.COST_COMPUTE_USD, source.COST_CLOUD_SERVICES_USD,
                CURRENT_TIMESTAMP(), CURRENT_USER()
            )
        `;

        var mergeStmt = snowflake.createStatement({
            sqlText: mergeSql,
            binds: [
                creditPrice, creditPrice, creditPrice,
                collectionStartTime.toISOString().substring(0, 19).replace('T', ' '),
                collectionEndTime.toISOString().substring(0, 19).replace('T', ' ')
            ]
        });

        var mergeResult = mergeStmt.execute();
        mergeResult.next();

        rowsInserted = mergeResult.getColumnValue('number of rows inserted');
        rowsUpdated = mergeResult.getColumnValue('number of rows updated');

        result.rows_inserted = rowsInserted;
        result.rows_updated = rowsUpdated;
        result.rows_affected = rowsInserted + rowsUpdated;

        // =================================================================
        // STEP 4: GENERATE COLLECTION SUMMARY
        // =================================================================

        result.status = 'GENERATING_SUMMARY';

        // Get summary statistics for collected data
        var summaryRs = executeSql(`
            SELECT
                COUNT(DISTINCT WAREHOUSE_NAME) AS warehouse_count,
                COUNT(*) AS record_count,
                SUM(CREDITS_USED) AS total_credits,
                SUM(COST_USD) AS total_cost_usd,
                MIN(START_TIME) AS earliest_record,
                MAX(END_TIME) AS latest_record
            FROM FINOPS_CONTROL_DB.COST_DATA.FACT_WAREHOUSE_COST_HISTORY
            WHERE START_TIME >= ?
              AND START_TIME < ?
        `, [
            collectionStartTime.toISOString().substring(0, 19).replace('T', ' '),
            collectionEndTime.toISOString().substring(0, 19).replace('T', ' ')
        ]);

        if (summaryRs.next()) {
            result.summary = {
                warehouses_processed: summaryRs.getColumnValue('WAREHOUSE_COUNT'),
                total_records: summaryRs.getColumnValue('RECORD_COUNT'),
                total_credits: parseFloat(summaryRs.getColumnValue('TOTAL_CREDITS')).toFixed(4),
                total_cost_usd: parseFloat(summaryRs.getColumnValue('TOTAL_COST_USD')).toFixed(2),
                earliest_record: summaryRs.getColumnValue('EARLIEST_RECORD'),
                latest_record: summaryRs.getColumnValue('LATEST_RECORD')
            };
        }

        // Get top 5 most expensive warehouses in this collection window
        var top5Rs = executeSql(`
            SELECT
                WAREHOUSE_NAME,
                SUM(CREDITS_USED) AS TOTAL_CREDITS,
                SUM(COST_USD) AS TOTAL_COST_USD,
                COUNT(*) AS MINUTE_RECORDS
            FROM FINOPS_CONTROL_DB.COST_DATA.FACT_WAREHOUSE_COST_HISTORY
            WHERE START_TIME >= ?
              AND START_TIME < ?
            GROUP BY WAREHOUSE_NAME
            ORDER BY TOTAL_COST_USD DESC
            LIMIT 5
        `, [
            collectionStartTime.toISOString().substring(0, 19).replace('T', ' '),
            collectionEndTime.toISOString().substring(0, 19).replace('T', ' ')
        ]);

        var top5Warehouses = [];
        while (top5Rs.next()) {
            top5Warehouses.push({
                warehouse_name: top5Rs.getColumnValue('WAREHOUSE_NAME'),
                total_credits: parseFloat(top5Rs.getColumnValue('TOTAL_CREDITS')).toFixed(4),
                total_cost_usd: parseFloat(top5Rs.getColumnValue('TOTAL_COST_USD')).toFixed(2),
                minute_records: top5Rs.getColumnValue('MINUTE_RECORDS')
            });
        }

        result.top_5_warehouses = top5Warehouses;

        // =================================================================
        // STEP 5: FINALIZE
        // =================================================================

        result.status = 'SUCCESS';
        result.end_time = new Date().toISOString();
        result.duration_seconds = ((new Date() - startTimestamp) / 1000).toFixed(2);

        // Log to audit table
        logExecution(executionId, procedureName, 'SUCCESS', startTimestamp, new Date(),
                     rowsInserted, rowsUpdated, null, result.parameters);

        return result;

    } catch (err) {
        // Error handling
        result.status = 'ERROR';
        result.error_message = err.message;
        result.error_stack = err.stack;
        result.end_time = new Date().toISOString();

        // Log error to audit table
        logExecution(executionId, procedureName, 'ERROR', startTimestamp, new Date(),
                     rowsInserted, rowsUpdated, err.message, result.parameters);

        return result;
    }
$$;

-- =========================================================================
-- GRANT EXECUTE PERMISSIONS
-- =========================================================================
GRANT USAGE ON PROCEDURE SP_COLLECT_WAREHOUSE_COSTS(NUMBER, BOOLEAN)
    TO ROLE FINOPS_ANALYST_ROLE;


-- =========================================================================
-- VERIFICATION QUERIES
-- =========================================================================

/*
-- Test 1: Initial collection (last 24 hours)
CALL FINOPS_CONTROL_DB.PROCEDURES.SP_COLLECT_WAREHOUSE_COSTS(24, TRUE);

-- Test 2: Force re-collection (last 12 hours, non-incremental)
CALL FINOPS_CONTROL_DB.PROCEDURES.SP_COLLECT_WAREHOUSE_COSTS(12, FALSE);

-- Test 3: Incremental collection (only new data since last run)
CALL FINOPS_CONTROL_DB.PROCEDURES.SP_COLLECT_WAREHOUSE_COSTS(24, TRUE);


-- Verify: Check collected data by hour
SELECT
    WAREHOUSE_NAME,
    DATE_TRUNC('HOUR', START_TIME) AS HOUR,
    SUM(CREDITS_USED) AS TOTAL_CREDITS,
    SUM(COST_USD) AS TOTAL_COST_USD,
    COUNT(*) AS MINUTE_RECORDS
FROM FINOPS_CONTROL_DB.COST_DATA.FACT_WAREHOUSE_COST_HISTORY
WHERE START_TIME >= DATEADD(HOUR, -24, CURRENT_TIMESTAMP())
GROUP BY WAREHOUSE_NAME, DATE_TRUNC('HOUR', START_TIME)
ORDER BY HOUR DESC, TOTAL_COST_USD DESC;


-- Verify: Top 10 most expensive warehouses (last 7 days)
SELECT
    WAREHOUSE_NAME,
    SUM(COST_USD) AS TOTAL_COST_7D,
    SUM(CREDITS_USED) AS TOTAL_CREDITS,
    COUNT(*) AS MINUTE_RECORDS,
    MIN(START_TIME) AS FIRST_SEEN,
    MAX(END_TIME) AS LAST_SEEN,
    DATEDIFF(DAY, MIN(START_TIME), MAX(END_TIME)) AS DAYS_ACTIVE
FROM FINOPS_CONTROL_DB.COST_DATA.FACT_WAREHOUSE_COST_HISTORY
WHERE START_TIME >= DATEADD(DAY, -7, CURRENT_TIMESTAMP())
GROUP BY WAREHOUSE_NAME
ORDER BY TOTAL_COST_7D DESC
LIMIT 10;


-- Verify: Daily cost trend (last 7 days)
SELECT
    USAGE_DATE,
    COUNT(DISTINCT WAREHOUSE_NAME) AS ACTIVE_WAREHOUSES,
    SUM(CREDITS_USED) AS TOTAL_CREDITS,
    SUM(COST_USD) AS TOTAL_COST_USD,
    ROUND(AVG(COST_USD), 4) AS AVG_COST_PER_MINUTE
FROM FINOPS_CONTROL_DB.COST_DATA.FACT_WAREHOUSE_COST_HISTORY
WHERE USAGE_DATE >= DATEADD(DAY, -7, CURRENT_DATE())
GROUP BY USAGE_DATE
ORDER BY USAGE_DATE DESC;


-- Verify: Warehouse cost breakdown (compute vs cloud services)
SELECT
    WAREHOUSE_NAME,
    SUM(COST_COMPUTE_USD) AS COMPUTE_COST,
    SUM(COST_CLOUD_SERVICES_USD) AS CLOUD_SERVICES_COST,
    SUM(COST_USD) AS TOTAL_COST,
    ROUND(SUM(COST_CLOUD_SERVICES_USD) / NULLIF(SUM(COST_USD), 0) * 100, 2) AS CLOUD_SERVICES_PCT
FROM FINOPS_CONTROL_DB.COST_DATA.FACT_WAREHOUSE_COST_HISTORY
WHERE START_TIME >= DATEADD(DAY, -7, CURRENT_TIMESTAMP())
GROUP BY WAREHOUSE_NAME
ORDER BY TOTAL_COST DESC
LIMIT 10;


-- Verify: Check procedure execution log
SELECT
    EXECUTION_ID,
    PROCEDURE_NAME,
    EXECUTION_STATUS,
    START_TIME,
    DURATION_SECONDS,
    ROWS_INSERTED,
    ROWS_UPDATED,
    EXECUTION_PARAMETERS:lookback_hours AS LOOKBACK_HOURS,
    EXECUTION_PARAMETERS:incremental AS INCREMENTAL
FROM FINOPS_CONTROL_DB.AUDIT.PROCEDURE_EXECUTION_LOG
WHERE PROCEDURE_NAME = 'SP_COLLECT_WAREHOUSE_COSTS'
ORDER BY START_TIME DESC
LIMIT 10;


-- Analytics: Hourly cost pattern (identify peak usage hours)
SELECT
    EXTRACT(HOUR FROM START_TIME) AS HOUR_OF_DAY,
    COUNT(*) AS RECORDS,
    SUM(CREDITS_USED) AS TOTAL_CREDITS,
    SUM(COST_USD) AS TOTAL_COST_USD,
    ROUND(AVG(COST_USD), 4) AS AVG_COST_PER_MINUTE
FROM FINOPS_CONTROL_DB.COST_DATA.FACT_WAREHOUSE_COST_HISTORY
WHERE START_TIME >= DATEADD(DAY, -7, CURRENT_TIMESTAMP())
GROUP BY EXTRACT(HOUR FROM START_TIME)
ORDER BY HOUR_OF_DAY;


-- Analytics: Warehouse utilization by day of week
SELECT
    DAYNAME(USAGE_DATE) AS DAY_OF_WEEK,
    DAYOFWEEK(USAGE_DATE) AS DAY_NUM,
    COUNT(DISTINCT WAREHOUSE_NAME) AS ACTIVE_WAREHOUSES,
    SUM(COST_USD) AS TOTAL_COST_USD,
    ROUND(AVG(COST_USD), 4) AS AVG_COST_PER_MINUTE
FROM FINOPS_CONTROL_DB.COST_DATA.FACT_WAREHOUSE_COST_HISTORY
WHERE USAGE_DATE >= DATEADD(DAY, -30, CURRENT_DATE())
GROUP BY DAYNAME(USAGE_DATE), DAYOFWEEK(USAGE_DATE)
ORDER BY DAY_NUM;
*/


-- =========================================================================
-- BEST PRACTICES & DESIGN NOTES
-- =========================================================================

/*
BEST PRACTICES:

1. INCREMENTAL COLLECTION:
   - Always use incremental mode (P_INCREMENTAL=TRUE) in production
   - The procedure tracks last collection timestamp automatically
   - 5-minute overlap handles late-arriving data from ACCOUNT_USAGE

2. ACCOUNT_USAGE LATENCY:
   - WAREHOUSE_METERING_HISTORY has 45 minutes to 3 hours latency
   - Never collect data newer than 1 hour ago
   - Schedule this procedure to run hourly via Snowflake Tasks

3. IDEMPOTENT DESIGN:
   - Uses MERGE statement to avoid duplicates
   - Safe to re-run for same time range (updates existing records)
   - Critical for recovery from failures

4. COST CALCULATION:
   - Credits are multiplied by configurable credit price
   - Cost per second enables query-level attribution
   - Cloud services costs are included (will be adjusted later by 10% rule)

5. SCHEDULING RECOMMENDATION:
   - Run hourly: SCHEDULE = 'USING CRON 0 * * * * UTC'
   - Collect last 2 hours of data: P_LOOKBACK_HOURS=2
   - Use incremental mode: P_INCREMENTAL=TRUE

6. MONITORING:
   - Check PROCEDURE_EXECUTION_LOG for failures
   - Monitor for gaps in USAGE_DATE (indicates missed collections)
   - Alert if total_cost_usd spikes above threshold

7. PERFORMANCE OPTIMIZATION:
   - FACT_WAREHOUSE_COST_HISTORY is partitioned by USAGE_DATE
   - Clustered by (USAGE_DATE, WAREHOUSE_NAME) for fast queries
   - Per-minute grain balances granularity and storage cost

EDGE CASES HANDLED:

1. NULL WAREHOUSE_NAME: Filtered out (should not happen in practice)
2. ZERO CREDITS_USED: Filtered out (no cost to track)
3. OVERLAPPING TIME RANGES: MERGE handles duplicates gracefully
4. FIRST RUN (no watermark): Falls back to P_LOOKBACK_HOURS
5. LATE-ARRIVING DATA: 5-minute overlap ensures no missed records
6. CREDIT PRICE CHANGES: Uses current price from GLOBAL_SETTINGS
7. WAREHOUSE RENAMES: START_TIME remains unique, no duplicates


CLOUD SERVICES COST ADJUSTMENT:

Note: This procedure collects ALL cloud services costs. Snowflake provides
cloud services credits FREE up to 10% of daily compute credits.

A separate procedure (SP_ADJUST_CLOUD_SERVICES_COSTS) runs daily to:
1. Calculate daily compute credits per account
2. Calculate 10% threshold
3. Zero out cloud services costs below threshold
4. Only charge for cloud services costs ABOVE 10% threshold

This separation keeps collection simple and adjustment transparent.


OBJECTS CREATED:
  - FINOPS_CONTROL_DB.PROCEDURES.SP_COLLECT_WAREHOUSE_COSTS

NEXT STEPS:
  - Create SP_COLLECT_QUERY_COSTS (query-level attribution)
  - Create SP_COLLECT_STORAGE_COSTS (daily storage costs)
  - Create Task to automate hourly collection
  - Build analytics views for warehouse cost reporting
*/

-- ===========================================================================
-- ===========================================================================
-- 03_SP_COLLECT_QUERY_COSTS
-- ===========================================================================
-- ===========================================================================


USE ROLE FINOPS_ADMIN_ROLE;
USE DATABASE FINOPS_CONTROL_DB;
USE SCHEMA PROCEDURES;
USE WAREHOUSE FINOPS_WH_ADMIN;

-- =========================================================================
-- PROCEDURE: SP_COLLECT_QUERY_COSTS
-- Collects query execution costs from ACCOUNT_USAGE with attribution metadata
-- =========================================================================
CREATE OR REPLACE PROCEDURE SP_COLLECT_QUERY_COSTS(
    P_LOOKBACK_HOURS            NUMBER DEFAULT 24,      -- How many hours back to collect
    P_INCREMENTAL               BOOLEAN DEFAULT TRUE,   -- Only collect new queries since last run
    P_MIN_EXECUTION_TIME_MS     NUMBER DEFAULT 100      -- Ignore trivial queries below this threshold
)
RETURNS VARIANT
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER
AS
$$
    // =====================================================================
    // HELPER FUNCTIONS
    // =====================================================================

    /**
     * Execute a SQL statement and return the result set
     */
    function executeSql(sqlText, binds) {
        try {
            var stmt = snowflake.createStatement({
                sqlText: sqlText,
                binds: binds || []
            });
            return stmt.execute();
        } catch (err) {
            throw new Error('SQL Error: ' + err.message + ' | SQL: ' + sqlText.substring(0, 200));
        }
    }

    /**
     * Execute SQL and return scalar value
     */
    function executeScalar(sqlText, binds) {
        var rs = executeSql(sqlText, binds);
        if (rs.next()) {
            return rs.getColumnValue(1);
        }
        return null;
    }

    /**
     * Map warehouse size to credits per hour
     */
    function getWarehouseSizeCredits(warehouseSize) {
        var sizeMap = {
            'X-SMALL': 1,
            'XSMALL': 1,
            'SMALL': 2,
            'MEDIUM': 4,
            'LARGE': 8,
            'X-LARGE': 16,
            'XLARGE': 16,
            '2X-LARGE': 32,
            '2XLARGE': 32,
            '3X-LARGE': 64,
            '3XLARGE': 64,
            '4X-LARGE': 128,
            '4XLARGE': 128,
            '5X-LARGE': 256,
            '5XLARGE': 256,
            '6X-LARGE': 512,
            '6XLARGE': 512
        };

        if (!warehouseSize) {
            return 0; // Cached query or no warehouse
        }

        var normalizedSize = warehouseSize.toUpperCase().replace(/-/g, '');
        return sizeMap[normalizedSize] || 0;
    }

    /**
     * Parse QUERY_TAG for attribution metadata
     * Expected format: "team=DATA_ENG;project=ETL_PIPELINE;department=ENGINEERING"
     * Returns object: {team, project, department}
     */
    function parseQueryTag(queryTag) {
        var parsed = {
            team: null,
            project: null,
            department: null
        };

        if (!queryTag) {
            return parsed;
        }

        var parts = queryTag.split(';');
        for (var i = 0; i < parts.length; i++) {
            var kv = parts[i].split('=');
            if (kv.length === 2) {
                var key = kv[0].trim().toLowerCase();
                var value = kv[1].trim();

                if (key === 'team') parsed.team = value;
                if (key === 'project') parsed.project = value;
                if (key === 'department') parsed.department = value;
            }
        }

        return parsed;
    }

    /**
     * Classify BI tool from APPLICATION_NAME
     */
    function classifyBiTool(applicationName) {
        if (!applicationName) {
            return null;
        }

        var appLower = applicationName.toLowerCase();

        if (appLower.indexOf('powerbi') >= 0 || appLower.indexOf('microsoft.mashup') >= 0) {
            return 'Power BI';
        }
        if (appLower.indexOf('tableau') >= 0) {
            return 'Tableau';
        }
        if (appLower.indexOf('looker') >= 0) {
            return 'Looker';
        }
        if (appLower.indexOf('dbt') >= 0) {
            return 'dbt';
        }
        if (appLower.indexOf('streamlit') >= 0) {
            return 'Streamlit';
        }
        if (appLower.indexOf('airflow') >= 0) {
            return 'Airflow';
        }
        if (appLower.indexOf('fivetran') >= 0) {
            return 'Fivetran';
        }
        if (appLower.indexOf('talend') >= 0) {
            return 'Talend';
        }
        if (appLower.indexOf('matillion') >= 0) {
            return 'Matillion';
        }

        return null;
    }

    /**
     * Log execution to audit table
     */
    function logExecution(execId, procName, status, startTime, endTime, rowsInserted, rowsUpdated, errorMsg, params) {
        try {
            var durationSeconds = (endTime - startTime) / 1000;
            executeSql(
                `INSERT INTO FINOPS_CONTROL_DB.AUDIT.PROCEDURE_EXECUTION_LOG
                (EXECUTION_ID, PROCEDURE_NAME, EXECUTION_STATUS, START_TIME, END_TIME,
                 DURATION_SECONDS, ROWS_INSERTED, ROWS_UPDATED, ERROR_MESSAGE, EXECUTION_PARAMETERS)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, PARSE_JSON(?))`,
                [execId, procName, status, startTime, endTime, durationSeconds,
                 rowsInserted, rowsUpdated, errorMsg, JSON.stringify(params)]
            );
        } catch (err) {
            // Audit logging failure should not break the procedure
            return;
        }
    }

    // =====================================================================
    // MAIN EXECUTION LOGIC
    // =====================================================================

    var executionId = executeScalar("SELECT UUID_STRING()");
    var procedureName = 'SP_COLLECT_QUERY_COSTS';
    var startTimestamp = new Date();
    var rowsInserted = 0;
    var rowsUpdated = 0;

    // Result object to return
    var result = {
        execution_id: executionId,
        procedure_name: procedureName,
        status: 'INITIALIZING',
        start_time: startTimestamp.toISOString(),
        parameters: {
            lookback_hours: P_LOOKBACK_HOURS,
            incremental: P_INCREMENTAL,
            min_execution_time_ms: P_MIN_EXECUTION_TIME_MS
        }
    };

    try {
        // =================================================================
        // STEP 1: GET CONFIGURATION
        // =================================================================

        var creditPrice = parseFloat(executeScalar(
            "SELECT SETTING_VALUE FROM FINOPS_CONTROL_DB.CONFIG.GLOBAL_SETTINGS WHERE SETTING_NAME = 'CREDIT_PRICE_USD'"
        ));

        if (!creditPrice || creditPrice <= 0) {
            throw new Error('Invalid credit price configuration. Check GLOBAL_SETTINGS table.');
        }

        result.credit_price_usd = creditPrice;

        // =================================================================
        // STEP 2: DETERMINE COLLECTION WINDOW
        // =================================================================

        var collectionStartTime;
        var collectionEndTime = new Date();

        if (P_INCREMENTAL) {
            // Get the last successful collection timestamp (watermark)
            var lastCollectionTime = executeScalar(`
                SELECT MAX(END_TIME)
                FROM FINOPS_CONTROL_DB.COST_DATA.FACT_QUERY_COST_HISTORY
            `);

            if (lastCollectionTime) {
                // Start from last collection, with 5-minute overlap to handle late-arriving data
                collectionStartTime = new Date(lastCollectionTime);
                collectionStartTime.setMinutes(collectionStartTime.getMinutes() - 5);
            } else {
                // First run - collect based on lookback hours
                collectionStartTime = new Date();
                collectionStartTime.setHours(collectionStartTime.getHours() - P_LOOKBACK_HOURS);
            }
        } else {
            // Full collection based on lookback hours
            collectionStartTime = new Date();
            collectionStartTime.setHours(collectionStartTime.getHours() - P_LOOKBACK_HOURS);
        }

        // Account for ACCOUNT_USAGE latency: don't collect data newer than 1 hour ago
        var maxEndTime = new Date();
        maxEndTime.setHours(maxEndTime.getHours() - 1);

        if (collectionEndTime > maxEndTime) {
            collectionEndTime = maxEndTime;
        }

        result.collection_window = {
            start_time: collectionStartTime.toISOString(),
            end_time: collectionEndTime.toISOString(),
            hours: ((collectionEndTime - collectionStartTime) / (1000 * 60 * 60)).toFixed(2)
        };

        // =================================================================
        // STEP 3: COLLECT QUERY HISTORY DATA
        // =================================================================

        result.status = 'COLLECTING_DATA';

        // Use MERGE for idempotent collection
        var mergeSql = `
        MERGE INTO FINOPS_CONTROL_DB.COST_DATA.FACT_QUERY_COST_HISTORY AS target
        USING (
            SELECT
                QUERY_ID,
                DATE(START_TIME) AS QUERY_DATE,

                -- Query metadata
                LEFT(QUERY_TEXT, 10000) AS QUERY_TEXT,  -- Truncate to save storage
                QUERY_TYPE,
                WAREHOUSE_NAME,
                DATABASE_NAME,
                SCHEMA_NAME,

                -- User and role attribution
                USER_NAME,
                ROLE_NAME,
                SESSION_ID,

                -- Execution metrics
                START_TIME,
                END_TIME,
                TOTAL_ELAPSED_TIME AS EXECUTION_TIME_MS,
                QUEUED_PROVISIONING_TIME + QUEUED_REPAIR_TIME + QUEUED_OVERLOAD_TIME AS QUEUED_TIME_MS,
                COMPILATION_TIME AS COMPILATION_TIME_MS,

                -- Data scanned
                BYTES_SCANNED,
                ROWS_PRODUCED,
                PARTITIONS_SCANNED,
                PARTITIONS_TOTAL,

                -- Warehouse size and cost calculation
                WAREHOUSE_SIZE,
                CASE
                    WHEN WAREHOUSE_SIZE IS NULL THEN 0  -- Cached query
                    ELSE
                        CASE UPPER(WAREHOUSE_SIZE)
                            WHEN 'X-SMALL' THEN 1
                            WHEN 'XSMALL' THEN 1
                            WHEN 'SMALL' THEN 2
                            WHEN 'MEDIUM' THEN 4
                            WHEN 'LARGE' THEN 8
                            WHEN 'X-LARGE' THEN 16
                            WHEN 'XLARGE' THEN 16
                            WHEN '2X-LARGE' THEN 32
                            WHEN '2XLARGE' THEN 32
                            WHEN '3X-LARGE' THEN 64
                            WHEN '3XLARGE' THEN 64
                            WHEN '4X-LARGE' THEN 128
                            WHEN '4XLARGE' THEN 128
                            WHEN '5X-LARGE' THEN 256
                            WHEN '5XLARGE' THEN 256
                            WHEN '6X-LARGE' THEN 512
                            WHEN '6XLARGE' THEN 512
                            ELSE 0
                        END
                END AS WAREHOUSE_SIZE_CREDITS,

                -- Cost calculations
                (TOTAL_ELAPSED_TIME / 3600000.0) AS EXECUTION_TIME_HOURS,

                (TOTAL_ELAPSED_TIME / 3600000.0) *
                    CASE
                        WHEN WAREHOUSE_SIZE IS NULL THEN 0
                        ELSE
                            CASE UPPER(WAREHOUSE_SIZE)
                                WHEN 'X-SMALL' THEN 1
                                WHEN 'XSMALL' THEN 1
                                WHEN 'SMALL' THEN 2
                                WHEN 'MEDIUM' THEN 4
                                WHEN 'LARGE' THEN 8
                                WHEN 'X-LARGE' THEN 16
                                WHEN 'XLARGE' THEN 16
                                WHEN '2X-LARGE' THEN 32
                                WHEN '2XLARGE' THEN 32
                                WHEN '3X-LARGE' THEN 64
                                WHEN '3XLARGE' THEN 64
                                WHEN '4X-LARGE' THEN 128
                                WHEN '4XLARGE' THEN 128
                                WHEN '5X-LARGE' THEN 256
                                WHEN '5XLARGE' THEN 256
                                WHEN '6X-LARGE' THEN 512
                                WHEN '6XLARGE' THEN 512
                                ELSE 0
                            END
                    END AS CREDITS_USED,

                (TOTAL_ELAPSED_TIME / 3600000.0) *
                    CASE
                        WHEN WAREHOUSE_SIZE IS NULL THEN 0
                        ELSE
                            CASE UPPER(WAREHOUSE_SIZE)
                                WHEN 'X-SMALL' THEN 1
                                WHEN 'XSMALL' THEN 1
                                WHEN 'SMALL' THEN 2
                                WHEN 'MEDIUM' THEN 4
                                WHEN 'LARGE' THEN 8
                                WHEN 'X-LARGE' THEN 16
                                WHEN 'XLARGE' THEN 16
                                WHEN '2X-LARGE' THEN 32
                                WHEN '2XLARGE' THEN 32
                                WHEN '3X-LARGE' THEN 64
                                WHEN '3XLARGE' THEN 64
                                WHEN '4X-LARGE' THEN 128
                                WHEN '4XLARGE' THEN 128
                                WHEN '5X-LARGE' THEN 256
                                WHEN '5XLARGE' THEN 256
                                WHEN '6X-LARGE' THEN 512
                                WHEN '6XLARGE' THEN 512
                                ELSE 0
                            END
                    END * ? AS COST_USD,

                -- Tags for attribution
                QUERY_TAG,
                CASE
                    WHEN LOWER(EXECUTION_STATUS) IN ('success', 'running') THEN NULL
                    ELSE ERROR_CODE
                END AS ERROR_CODE,
                CASE
                    WHEN LOWER(EXECUTION_STATUS) IN ('success', 'running') THEN NULL
                    ELSE ERROR_MESSAGE
                END AS ERROR_MESSAGE

            FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
            WHERE START_TIME >= ?
              AND START_TIME < ?
              AND TOTAL_ELAPSED_TIME >= ?  -- Filter out trivial queries
              AND QUERY_TYPE IS NOT NULL
              AND QUERY_TYPE NOT IN ('SHOW', 'DESCRIBE', 'USE')  -- Exclude metadata queries
        ) AS source
        ON target.QUERY_ID = source.QUERY_ID
        WHEN MATCHED THEN
            UPDATE SET
                target.QUERY_TEXT = source.QUERY_TEXT,
                target.QUERY_TYPE = source.QUERY_TYPE,
                target.WAREHOUSE_NAME = source.WAREHOUSE_NAME,
                target.DATABASE_NAME = source.DATABASE_NAME,
                target.SCHEMA_NAME = source.SCHEMA_NAME,
                target.USER_NAME = source.USER_NAME,
                target.ROLE_NAME = source.ROLE_NAME,
                target.SESSION_ID = source.SESSION_ID,
                target.START_TIME = source.START_TIME,
                target.END_TIME = source.END_TIME,
                target.EXECUTION_TIME_MS = source.EXECUTION_TIME_MS,
                target.QUEUED_TIME_MS = source.QUEUED_TIME_MS,
                target.COMPILATION_TIME_MS = source.COMPILATION_TIME_MS,
                target.BYTES_SCANNED = source.BYTES_SCANNED,
                target.ROWS_PRODUCED = source.ROWS_PRODUCED,
                target.PARTITIONS_SCANNED = source.PARTITIONS_SCANNED,
                target.PARTITIONS_TOTAL = source.PARTITIONS_TOTAL,
                target.WAREHOUSE_SIZE = source.WAREHOUSE_SIZE,
                target.WAREHOUSE_SIZE_CREDITS = source.WAREHOUSE_SIZE_CREDITS,
                target.EXECUTION_TIME_HOURS = source.EXECUTION_TIME_HOURS,
                target.CREDITS_USED = source.CREDITS_USED,
                target.COST_USD = source.COST_USD,
                target.QUERY_TAG = source.QUERY_TAG,
                target.ERROR_CODE = source.ERROR_CODE,
                target.ERROR_MESSAGE = source.ERROR_MESSAGE,
                target.COLLECTED_AT = CURRENT_TIMESTAMP()
        WHEN NOT MATCHED THEN
            INSERT (
                QUERY_ID, QUERY_DATE, QUERY_TEXT, QUERY_TYPE, WAREHOUSE_NAME,
                DATABASE_NAME, SCHEMA_NAME, USER_NAME, ROLE_NAME, SESSION_ID,
                START_TIME, END_TIME, EXECUTION_TIME_MS, QUEUED_TIME_MS, COMPILATION_TIME_MS,
                BYTES_SCANNED, ROWS_PRODUCED, PARTITIONS_SCANNED, PARTITIONS_TOTAL,
                WAREHOUSE_SIZE, WAREHOUSE_SIZE_CREDITS, EXECUTION_TIME_HOURS,
                CREDITS_USED, COST_USD, QUERY_TAG, ERROR_CODE, ERROR_MESSAGE,
                COLLECTED_AT, COLLECTED_BY
            )
            VALUES (
                source.QUERY_ID, source.QUERY_DATE, source.QUERY_TEXT, source.QUERY_TYPE, source.WAREHOUSE_NAME,
                source.DATABASE_NAME, source.SCHEMA_NAME, source.USER_NAME, source.ROLE_NAME, source.SESSION_ID,
                source.START_TIME, source.END_TIME, source.EXECUTION_TIME_MS, source.QUEUED_TIME_MS, source.COMPILATION_TIME_MS,
                source.BYTES_SCANNED, source.ROWS_PRODUCED, source.PARTITIONS_SCANNED, source.PARTITIONS_TOTAL,
                source.WAREHOUSE_SIZE, source.WAREHOUSE_SIZE_CREDITS, source.EXECUTION_TIME_HOURS,
                source.CREDITS_USED, source.COST_USD, source.QUERY_TAG, source.ERROR_CODE, source.ERROR_MESSAGE,
                CURRENT_TIMESTAMP(), CURRENT_USER()
            )
        `;

        var mergeStmt = snowflake.createStatement({
            sqlText: mergeSql,
            binds: [
                creditPrice,
                collectionStartTime.toISOString().substring(0, 19).replace('T', ' '),
                collectionEndTime.toISOString().substring(0, 19).replace('T', ' '),
                P_MIN_EXECUTION_TIME_MS
            ]
        });

        var mergeResult = mergeStmt.execute();
        mergeResult.next();

        rowsInserted = mergeResult.getColumnValue('number of rows inserted');
        rowsUpdated = mergeResult.getColumnValue('number of rows updated');

        result.rows_inserted = rowsInserted;
        result.rows_updated = rowsUpdated;
        result.rows_affected = rowsInserted + rowsUpdated;

        // =================================================================
        // STEP 4: UPDATE APPLICATION_NAME AND BI_TOOL_NAME
        // =================================================================

        result.status = 'UPDATING_BI_TOOLS';

        // Update APPLICATION_NAME from QUERY_HISTORY (separate query to avoid complexity in MERGE)
        var updateAppSql = `
        UPDATE FINOPS_CONTROL_DB.COST_DATA.FACT_QUERY_COST_HISTORY AS target
        SET
            target.APPLICATION_NAME = source.CLIENT_APPLICATION_ID,
            target.BI_TOOL_NAME = CASE
                WHEN LOWER(source.CLIENT_APPLICATION_ID) LIKE '%powerbi%' THEN 'Power BI'
                WHEN LOWER(source.CLIENT_APPLICATION_ID) LIKE '%microsoft.mashup%' THEN 'Power BI'
                WHEN LOWER(source.CLIENT_APPLICATION_ID) LIKE '%tableau%' THEN 'Tableau'
                WHEN LOWER(source.CLIENT_APPLICATION_ID) LIKE '%looker%' THEN 'Looker'
                WHEN LOWER(source.CLIENT_APPLICATION_ID) LIKE '%dbt%' THEN 'dbt'
                WHEN LOWER(source.CLIENT_APPLICATION_ID) LIKE '%streamlit%' THEN 'Streamlit'
                WHEN LOWER(source.CLIENT_APPLICATION_ID) LIKE '%airflow%' THEN 'Airflow'
                WHEN LOWER(source.CLIENT_APPLICATION_ID) LIKE '%fivetran%' THEN 'Fivetran'
                WHEN LOWER(source.CLIENT_APPLICATION_ID) LIKE '%talend%' THEN 'Talend'
                WHEN LOWER(source.CLIENT_APPLICATION_ID) LIKE '%matillion%' THEN 'Matillion'
                ELSE NULL
            END
        FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY AS source
        WHERE target.QUERY_ID = source.QUERY_ID
          AND target.START_TIME >= ?
          AND target.START_TIME < ?
          AND target.APPLICATION_NAME IS NULL
        `;

        executeSql(updateAppSql, [
            collectionStartTime.toISOString().substring(0, 19).replace('T', ' '),
            collectionEndTime.toISOString().substring(0, 19).replace('T', ' ')
        ]);

        // =================================================================
        // STEP 5: GENERATE COLLECTION SUMMARY
        // =================================================================

        result.status = 'GENERATING_SUMMARY';

        // Overall summary
        var summaryRs = executeSql(`
            SELECT
                COUNT(*) AS query_count,
                COUNT(DISTINCT USER_NAME) AS unique_users,
                COUNT(DISTINCT WAREHOUSE_NAME) AS unique_warehouses,
                SUM(CREDITS_USED) AS total_credits,
                SUM(COST_USD) AS total_cost_usd,
                AVG(COST_USD) AS avg_cost_per_query,
                MAX(COST_USD) AS max_cost,
                SUM(CASE WHEN WAREHOUSE_NAME IS NULL THEN 1 ELSE 0 END) AS cached_queries,
                SUM(CASE WHEN ERROR_CODE IS NOT NULL THEN 1 ELSE 0 END) AS failed_queries
            FROM FINOPS_CONTROL_DB.COST_DATA.FACT_QUERY_COST_HISTORY
            WHERE START_TIME >= ?
              AND START_TIME < ?
        `, [
            collectionStartTime.toISOString().substring(0, 19).replace('T', ' '),
            collectionEndTime.toISOString().substring(0, 19).replace('T', ' ')
        ]);

        if (summaryRs.next()) {
            result.summary = {
                queries_processed: summaryRs.getColumnValue('QUERY_COUNT'),
                unique_users: summaryRs.getColumnValue('UNIQUE_USERS'),
                unique_warehouses: summaryRs.getColumnValue('UNIQUE_WAREHOUSES'),
                total_credits: parseFloat(summaryRs.getColumnValue('TOTAL_CREDITS')).toFixed(4),
                total_cost_usd: parseFloat(summaryRs.getColumnValue('TOTAL_COST_USD')).toFixed(2),
                avg_cost_per_query: parseFloat(summaryRs.getColumnValue('AVG_COST_PER_QUERY')).toFixed(4),
                max_query_cost: parseFloat(summaryRs.getColumnValue('MAX_COST')).toFixed(2),
                cached_queries: summaryRs.getColumnValue('CACHED_QUERIES'),
                failed_queries: summaryRs.getColumnValue('FAILED_QUERIES')
            };
        }

        // Top 5 most expensive queries
        var top5Rs = executeSql(`
            SELECT
                QUERY_ID,
                USER_NAME,
                WAREHOUSE_NAME,
                QUERY_TYPE,
                COST_USD,
                EXECUTION_TIME_MS,
                LEFT(QUERY_TEXT, 100) AS QUERY_SNIPPET
            FROM FINOPS_CONTROL_DB.COST_DATA.FACT_QUERY_COST_HISTORY
            WHERE START_TIME >= ?
              AND START_TIME < ?
            ORDER BY COST_USD DESC
            LIMIT 5
        `, [
            collectionStartTime.toISOString().substring(0, 19).replace('T', ' '),
            collectionEndTime.toISOString().substring(0, 19).replace('T', ' ')
        ]);

        var top5Queries = [];
        while (top5Rs.next()) {
            top5Queries.push({
                query_id: top5Rs.getColumnValue('QUERY_ID'),
                user_name: top5Rs.getColumnValue('USER_NAME'),
                warehouse_name: top5Rs.getColumnValue('WAREHOUSE_NAME'),
                query_type: top5Rs.getColumnValue('QUERY_TYPE'),
                cost_usd: parseFloat(top5Rs.getColumnValue('COST_USD')).toFixed(4),
                execution_time_ms: top5Rs.getColumnValue('EXECUTION_TIME_MS'),
                query_snippet: top5Rs.getColumnValue('QUERY_SNIPPET')
            });
        }

        result.top_5_expensive_queries = top5Queries;

        // Cost by user (top 10)
        var userCostRs = executeSql(`
            SELECT
                USER_NAME,
                COUNT(*) AS QUERY_COUNT,
                SUM(COST_USD) AS TOTAL_COST_USD,
                AVG(COST_USD) AS AVG_COST_USD
            FROM FINOPS_CONTROL_DB.COST_DATA.FACT_QUERY_COST_HISTORY
            WHERE START_TIME >= ?
              AND START_TIME < ?
            GROUP BY USER_NAME
            ORDER BY TOTAL_COST_USD DESC
            LIMIT 10
        `, [
            collectionStartTime.toISOString().substring(0, 19).replace('T', ' '),
            collectionEndTime.toISOString().substring(0, 19).replace('T', ' ')
        ]);

        var userCosts = [];
        while (userCostRs.next()) {
            userCosts.push({
                user_name: userCostRs.getColumnValue('USER_NAME'),
                query_count: userCostRs.getColumnValue('QUERY_COUNT'),
                total_cost_usd: parseFloat(userCostRs.getColumnValue('TOTAL_COST_USD')).toFixed(2),
                avg_cost_usd: parseFloat(userCostRs.getColumnValue('AVG_COST_USD')).toFixed(4)
            });
        }

        result.top_10_users_by_cost = userCosts;

        // =================================================================
        // STEP 6: FINALIZE
        // =================================================================

        result.status = 'SUCCESS';
        result.end_time = new Date().toISOString();
        result.duration_seconds = ((new Date() - startTimestamp) / 1000).toFixed(2);

        // Log to audit table
        logExecution(executionId, procedureName, 'SUCCESS', startTimestamp, new Date(),
                     rowsInserted, rowsUpdated, null, result.parameters);

        return result;

    } catch (err) {
        // Error handling
        result.status = 'ERROR';
        result.error_message = err.message;
        result.error_stack = err.stack;
        result.end_time = new Date().toISOString();

        // Log error to audit table
        logExecution(executionId, procedureName, 'ERROR', startTimestamp, new Date(),
                     rowsInserted, rowsUpdated, err.message, result.parameters);

        return result;
    }
$$;

-- =========================================================================
-- GRANT EXECUTE PERMISSIONS
-- =========================================================================
GRANT USAGE ON PROCEDURE SP_COLLECT_QUERY_COSTS(NUMBER, BOOLEAN, NUMBER)
    TO ROLE FINOPS_ANALYST_ROLE;


-- =========================================================================
-- VERIFICATION QUERIES
-- =========================================================================

/*
-- Test 1: Initial collection (last 24 hours)
CALL FINOPS_CONTROL_DB.PROCEDURES.SP_COLLECT_QUERY_COSTS(24, TRUE, 100);

-- Test 2: Collect only longer queries (> 1 second)
CALL FINOPS_CONTROL_DB.PROCEDURES.SP_COLLECT_QUERY_COSTS(12, FALSE, 1000);

-- Test 3: Incremental collection (only new queries since last run)
CALL FINOPS_CONTROL_DB.PROCEDURES.SP_COLLECT_QUERY_COSTS(24, TRUE, 100);


-- Verify: Check collected query data
SELECT
    QUERY_DATE,
    QUERY_TYPE,
    COUNT(*) AS QUERY_COUNT,
    SUM(COST_USD) AS TOTAL_COST,
    AVG(COST_USD) AS AVG_COST,
    MAX(COST_USD) AS MAX_COST
FROM FINOPS_CONTROL_DB.COST_DATA.FACT_QUERY_COST_HISTORY
WHERE QUERY_DATE >= DATEADD(DAY, -7, CURRENT_DATE())
GROUP BY QUERY_DATE, QUERY_TYPE
ORDER BY QUERY_DATE DESC, TOTAL_COST DESC;


-- Verify: Top 10 most expensive queries (last 7 days)
SELECT
    QUERY_ID,
    QUERY_DATE,
    USER_NAME,
    WAREHOUSE_NAME,
    WAREHOUSE_SIZE,
    QUERY_TYPE,
    EXECUTION_TIME_MS,
    CREDITS_USED,
    COST_USD,
    LEFT(QUERY_TEXT, 200) AS QUERY_SNIPPET
FROM FINOPS_CONTROL_DB.COST_DATA.FACT_QUERY_COST_HISTORY
WHERE QUERY_DATE >= DATEADD(DAY, -7, CURRENT_DATE())
ORDER BY COST_USD DESC
LIMIT 10;


-- Verify: Cost by user (last 7 days)
SELECT
    USER_NAME,
    COUNT(*) AS QUERY_COUNT,
    SUM(COST_USD) AS TOTAL_COST_USD,
    AVG(COST_USD) AS AVG_COST_PER_QUERY,
    MAX(COST_USD) AS MAX_QUERY_COST,
    SUM(EXECUTION_TIME_MS) / 1000 / 60 AS TOTAL_EXECUTION_MINUTES
FROM FINOPS_CONTROL_DB.COST_DATA.FACT_QUERY_COST_HISTORY
WHERE QUERY_DATE >= DATEADD(DAY, -7, CURRENT_DATE())
GROUP BY USER_NAME
ORDER BY TOTAL_COST_USD DESC
LIMIT 20;


-- Verify: Cost by warehouse (last 7 days)
SELECT
    WAREHOUSE_NAME,
    WAREHOUSE_SIZE,
    COUNT(*) AS QUERY_COUNT,
    SUM(COST_USD) AS TOTAL_COST_USD,
    AVG(COST_USD) AS AVG_COST_PER_QUERY,
    SUM(EXECUTION_TIME_MS) / 1000 / 60 AS TOTAL_EXECUTION_MINUTES
FROM FINOPS_CONTROL_DB.COST_DATA.FACT_QUERY_COST_HISTORY
WHERE QUERY_DATE >= DATEADD(DAY, -7, CURRENT_DATE())
  AND WAREHOUSE_NAME IS NOT NULL
GROUP BY WAREHOUSE_NAME, WAREHOUSE_SIZE
ORDER BY TOTAL_COST_USD DESC;


-- Verify: BI tool cost breakdown
SELECT
    COALESCE(BI_TOOL_NAME, 'OTHER') AS BI_TOOL,
    COUNT(*) AS QUERY_COUNT,
    SUM(COST_USD) AS TOTAL_COST_USD,
    AVG(EXECUTION_TIME_MS) AS AVG_EXECUTION_MS
FROM FINOPS_CONTROL_DB.COST_DATA.FACT_QUERY_COST_HISTORY
WHERE QUERY_DATE >= DATEADD(DAY, -7, CURRENT_DATE())
GROUP BY BI_TOOL
ORDER BY TOTAL_COST_USD DESC;


-- Verify: Cached queries (no cost)
SELECT
    QUERY_DATE,
    COUNT(*) AS CACHED_QUERY_COUNT,
    COUNT(DISTINCT USER_NAME) AS USERS_BENEFITING
FROM FINOPS_CONTROL_DB.COST_DATA.FACT_QUERY_COST_HISTORY
WHERE QUERY_DATE >= DATEADD(DAY, -7, CURRENT_DATE())
  AND WAREHOUSE_NAME IS NULL
GROUP BY QUERY_DATE
ORDER BY QUERY_DATE DESC;


-- Verify: Failed queries (still consume credits)
SELECT
    QUERY_DATE,
    ERROR_CODE,
    COUNT(*) AS FAILED_COUNT,
    SUM(COST_USD) AS WASTED_COST_USD
FROM FINOPS_CONTROL_DB.COST_DATA.FACT_QUERY_COST_HISTORY
WHERE QUERY_DATE >= DATEADD(DAY, -7, CURRENT_DATE())
  AND ERROR_CODE IS NOT NULL
GROUP BY QUERY_DATE, ERROR_CODE
ORDER BY QUERY_DATE DESC, WASTED_COST_USD DESC;


-- Analytics: Query cost distribution (histogram)
SELECT
    CASE
        WHEN COST_USD < 0.01 THEN '< $0.01'
        WHEN COST_USD < 0.10 THEN '$0.01 - $0.10'
        WHEN COST_USD < 1.00 THEN '$0.10 - $1.00'
        WHEN COST_USD < 10.00 THEN '$1.00 - $10.00'
        ELSE '> $10.00'
    END AS COST_BUCKET,
    COUNT(*) AS QUERY_COUNT,
    SUM(COST_USD) AS TOTAL_COST_USD
FROM FINOPS_CONTROL_DB.COST_DATA.FACT_QUERY_COST_HISTORY
WHERE QUERY_DATE >= DATEADD(DAY, -7, CURRENT_DATE())
GROUP BY COST_BUCKET
ORDER BY
    CASE COST_BUCKET
        WHEN '< $0.01' THEN 1
        WHEN '$0.01 - $0.10' THEN 2
        WHEN '$0.10 - $1.00' THEN 3
        WHEN '$1.00 - $10.00' THEN 4
        WHEN '> $10.00' THEN 5
    END;


-- Analytics: Queries with QUERY_TAG set (for chargeback)
SELECT
    QUERY_DATE,
    COUNT(*) AS TOTAL_QUERIES,
    SUM(CASE WHEN QUERY_TAG IS NOT NULL THEN 1 ELSE 0 END) AS TAGGED_QUERIES,
    ROUND(SUM(CASE WHEN QUERY_TAG IS NOT NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS TAG_ADOPTION_PCT
FROM FINOPS_CONTROL_DB.COST_DATA.FACT_QUERY_COST_HISTORY
WHERE QUERY_DATE >= DATEADD(DAY, -30, CURRENT_DATE())
GROUP BY QUERY_DATE
ORDER BY QUERY_DATE DESC;
*/


-- =========================================================================
-- BEST PRACTICES & DESIGN NOTES
-- =========================================================================

/*
BEST PRACTICES:

1. QUERY COST CALCULATION:
   - Based on warehouse size (credits/hour) and execution time
   - Formula: (execution_time_ms / 3,600,000) * warehouse_size_credits * credit_price
   - Cached queries (WAREHOUSE_NAME IS NULL) have zero cost

2. ATTRIBUTION STRATEGY:
   - Priority 1: Parse QUERY_TAG for team/project/department
   - Priority 2: Lookup warehouse tags from DIM_CHARGEBACK_ENTITY
   - Priority 3: Lookup user/role mapping from DIM_CHARGEBACK_ENTITY
   - Unallocated: Track separately, goal is <5% of total cost

3. BI TOOL DETECTION:
   - Uses APPLICATION_NAME from QUERY_HISTORY
   - Maps to standard tool names (Power BI, Tableau, etc.)
   - Enables dedicated BI cost reporting and optimization

4. TRIVIAL QUERY FILTERING:
   - P_MIN_EXECUTION_TIME_MS filters out metadata queries
   - Default 100ms eliminates SHOW, DESCRIBE, USE commands
   - Reduces data volume by 50%+ without losing cost visibility

5. INCREMENTAL COLLECTION:
   - Tracks watermark (max END_TIME) automatically
   - 5-minute overlap handles late-arriving queries
   - Safe to run hourly without gaps or duplicates

6. SCHEDULING RECOMMENDATION:
   - Run hourly: SCHEDULE = 'USING CRON 0 * * * * UTC'
   - Collect last 2 hours: P_LOOKBACK_HOURS=2
   - Use incremental mode: P_INCREMENTAL=TRUE
   - Filter trivial queries: P_MIN_EXECUTION_TIME_MS=100

7. EXPENSIVE QUERY ALERTS:
   - Use EXPENSIVE_QUERY_THRESHOLD_USD from GLOBAL_SETTINGS
   - Flag queries exceeding threshold for review
   - Identify optimization candidates (missing filters, full scans)

8. FAILED QUERY TRACKING:
   - Failed queries still consume credits (warehouse was running)
   - Track ERROR_CODE and ERROR_MESSAGE
   - Sum wasted cost to identify problematic users/queries


EDGE CASES HANDLED:

1. CACHED QUERIES: WAREHOUSE_NAME IS NULL, zero cost
2. QUERIES WITHOUT WAREHOUSE: Result cache or metadata queries
3. FAILED QUERIES: Still consumed credits, tracked separately
4. VERY SHORT QUERIES: Filtered by P_MIN_EXECUTION_TIME_MS
5. METADATA QUERIES: Excluded (SHOW, DESCRIBE, USE)
6. NULL QUERY_TAG: Fallback to warehouse/user/role mapping
7. OVERLAPPING COLLECTIONS: MERGE handles duplicates
8. WAREHOUSE SIZE VARIANTS: Handles X-LARGE, XLARGE, 2X-LARGE, 2XLARGE


QUERY_TAG BEST PRACTICES:

Recommended format for chargeback:
  SET QUERY_TAG = 'team=DATA_ENG;project=ETL_PIPELINE;department=ENGINEERING';

Enforcement options:
  1. Wrapper stored procedures that set QUERY_TAG automatically
  2. Session policies that require QUERY_TAG for production warehouses
  3. Pre-execution hooks in BI tools (Power BI, Tableau)
  4. dbt macro that sets QUERY_TAG from dbt_project.yml metadata


OBJECTS CREATED:
  - FINOPS_CONTROL_DB.PROCEDURES.SP_COLLECT_QUERY_COSTS

NEXT STEPS:
  - Create SP_COLLECT_STORAGE_COSTS (daily storage costs)
  - Create SP_ATTRIBUTE_QUERY_COSTS (parse QUERY_TAG, lookup mappings)
  - Create Task to automate hourly collection
  - Build views for query cost analytics and optimization
*/

-- ===========================================================================
-- ===========================================================================
-- 04_SP_COLLECT_STORAGE_COSTS
-- ===========================================================================
-- ===========================================================================


USE ROLE FINOPS_ADMIN_ROLE;
USE DATABASE FINOPS_CONTROL_DB;
USE SCHEMA PROCEDURES;
USE WAREHOUSE FINOPS_WH_ADMIN;

-- =========================================================================
-- PROCEDURE: SP_COLLECT_STORAGE_COSTS
-- Collects daily database storage costs from ACCOUNT_USAGE
-- =========================================================================
CREATE OR REPLACE PROCEDURE SP_COLLECT_STORAGE_COSTS(
    P_LOOKBACK_DAYS     NUMBER DEFAULT 7,       -- How many days back to collect
    P_INCREMENTAL       BOOLEAN DEFAULT TRUE    -- Only collect new data since last run
)
RETURNS VARIANT
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER
AS
$$
    // =====================================================================
    // HELPER FUNCTIONS
    // =====================================================================

    /**
     * Execute a SQL statement and return the result set
     */
    function executeSql(sqlText, binds) {
        try {
            var stmt = snowflake.createStatement({
                sqlText: sqlText,
                binds: binds || []
            });
            return stmt.execute();
        } catch (err) {
            throw new Error('SQL Error: ' + err.message + ' | SQL: ' + sqlText.substring(0, 200));
        }
    }

    /**
     * Execute SQL and return scalar value
     */
    function executeScalar(sqlText, binds) {
        var rs = executeSql(sqlText, binds);
        if (rs.next()) {
            return rs.getColumnValue(1);
        }
        return null;
    }

    /**
     * Convert bytes to terabytes
     */
    function bytesToTB(bytes) {
        if (!bytes || bytes === 0) return 0;
        return bytes / (1024 * 1024 * 1024 * 1024);  // 1 TB = 1,099,511,627,776 bytes
    }

    /**
     * Log execution to audit table
     */
    function logExecution(execId, procName, status, startTime, endTime, rowsInserted, rowsUpdated, errorMsg, params) {
        try {
            var durationSeconds = (endTime - startTime) / 1000;
            executeSql(
                `INSERT INTO FINOPS_CONTROL_DB.AUDIT.PROCEDURE_EXECUTION_LOG
                (EXECUTION_ID, PROCEDURE_NAME, EXECUTION_STATUS, START_TIME, END_TIME,
                 DURATION_SECONDS, ROWS_INSERTED, ROWS_UPDATED, ERROR_MESSAGE, EXECUTION_PARAMETERS)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, PARSE_JSON(?))`,
                [execId, procName, status, startTime, endTime, durationSeconds,
                 rowsInserted, rowsUpdated, errorMsg, JSON.stringify(params)]
            );
        } catch (err) {
            // Audit logging failure should not break the procedure
            return;
        }
    }

    // =====================================================================
    // MAIN EXECUTION LOGIC
    // =====================================================================

    var executionId = executeScalar("SELECT UUID_STRING()");
    var procedureName = 'SP_COLLECT_STORAGE_COSTS';
    var startTimestamp = new Date();
    var rowsInserted = 0;
    var rowsUpdated = 0;

    // Result object to return
    var result = {
        execution_id: executionId,
        procedure_name: procedureName,
        status: 'INITIALIZING',
        start_time: startTimestamp.toISOString(),
        parameters: {
            lookback_days: P_LOOKBACK_DAYS,
            incremental: P_INCREMENTAL
        }
    };

    try {
        // =================================================================
        // STEP 1: GET CONFIGURATION
        // =================================================================

        var storagePricePerTBMonth = parseFloat(executeScalar(
            "SELECT SETTING_VALUE FROM FINOPS_CONTROL_DB.CONFIG.GLOBAL_SETTINGS WHERE SETTING_NAME = 'STORAGE_PRICE_USD_PER_TB_MONTH'"
        ));

        if (!storagePricePerTBMonth || storagePricePerTBMonth <= 0) {
            throw new Error('Invalid storage price configuration. Check GLOBAL_SETTINGS table.');
        }

        // Convert monthly price to daily price (assume 30.42 days per month on average)
        var storagePricePerTBDay = storagePricePerTBMonth / 30.42;

        result.storage_price_per_tb_month = storagePricePerTBMonth;
        result.storage_price_per_tb_day = parseFloat(storagePricePerTBDay.toFixed(6));

        // =================================================================
        // STEP 2: DETERMINE COLLECTION WINDOW
        // =================================================================

        var collectionStartDate;
        var collectionEndDate = new Date();
        collectionEndDate.setDate(collectionEndDate.getDate() - 2);  // Account for 24-48 hour latency

        if (P_INCREMENTAL) {
            // Get the last successful collection date (watermark)
            var lastCollectionDate = executeScalar(`
                SELECT MAX(USAGE_DATE)
                FROM FINOPS_CONTROL_DB.COST_DATA.FACT_STORAGE_COST_HISTORY
            `);

            if (lastCollectionDate) {
                // Start from day after last collection
                collectionStartDate = new Date(lastCollectionDate);
                collectionStartDate.setDate(collectionStartDate.getDate() + 1);
            } else {
                // First run - collect based on lookback days
                collectionStartDate = new Date();
                collectionStartDate.setDate(collectionStartDate.getDate() - P_LOOKBACK_DAYS);
            }
        } else {
            // Full collection based on lookback days
            collectionStartDate = new Date();
            collectionStartDate.setDate(collectionStartDate.getDate() - P_LOOKBACK_DAYS);
        }

        // Ensure we don't collect future dates
        if (collectionStartDate > collectionEndDate) {
            result.status = 'NO_NEW_DATA';
            result.message = 'No new storage data available (accounting for ACCOUNT_USAGE latency)';
            result.end_time = new Date().toISOString();
            return result;
        }

        result.collection_window = {
            start_date: collectionStartDate.toISOString().substring(0, 10),
            end_date: collectionEndDate.toISOString().substring(0, 10),
            days: Math.ceil((collectionEndDate - collectionStartDate) / (1000 * 60 * 60 * 24))
        };

        // =================================================================
        // STEP 3: COLLECT STORAGE DATA
        // =================================================================

        result.status = 'COLLECTING_DATA';

        // Use MERGE for idempotent collection
        var mergeSql = `
        MERGE INTO FINOPS_CONTROL_DB.COST_DATA.FACT_STORAGE_COST_HISTORY AS target
        USING (
            SELECT
                DATABASE_NAME,
                USAGE_DATE,

                -- Storage metrics (in bytes)
                AVERAGE_DATABASE_BYTES AS ACTIVE_BYTES,
                -- Time-travel calculation: Total storage - Active - Failsafe
                GREATEST(0, AVERAGE_DATABASE_BYTES + AVERAGE_FAILSAFE_BYTES - AVERAGE_DATABASE_BYTES) AS TIME_TRAVEL_BYTES,
                AVERAGE_FAILSAFE_BYTES AS FAILSAFE_BYTES,
                AVERAGE_DATABASE_BYTES + AVERAGE_FAILSAFE_BYTES AS TOTAL_BYTES,

                -- Storage metrics (converted to TB)
                AVERAGE_DATABASE_BYTES / 1099511627776.0 AS ACTIVE_TB,
                GREATEST(0, AVERAGE_DATABASE_BYTES + AVERAGE_FAILSAFE_BYTES - AVERAGE_DATABASE_BYTES) / 1099511627776.0 AS TIME_TRAVEL_TB,
                AVERAGE_FAILSAFE_BYTES / 1099511627776.0 AS FAILSAFE_TB,
                (AVERAGE_DATABASE_BYTES + AVERAGE_FAILSAFE_BYTES) / 1099511627776.0 AS TOTAL_TB,

                -- Cost calculations (all storage types charged at same rate)
                (AVERAGE_DATABASE_BYTES / 1099511627776.0) * ? AS COST_ACTIVE_USD,
                GREATEST(0, (AVERAGE_DATABASE_BYTES + AVERAGE_FAILSAFE_BYTES - AVERAGE_DATABASE_BYTES) / 1099511627776.0) * ? AS COST_TIME_TRAVEL_USD,
                (AVERAGE_FAILSAFE_BYTES / 1099511627776.0) * ? AS COST_FAILSAFE_USD,
                ((AVERAGE_DATABASE_BYTES + AVERAGE_FAILSAFE_BYTES) / 1099511627776.0) * ? AS COST_TOTAL_USD

            FROM SNOWFLAKE.ACCOUNT_USAGE.DATABASE_STORAGE_USAGE_HISTORY
            WHERE USAGE_DATE >= ?
              AND USAGE_DATE <= ?
              AND DATABASE_NAME IS NOT NULL
        ) AS source
        ON target.DATABASE_NAME = source.DATABASE_NAME
           AND target.USAGE_DATE = source.USAGE_DATE
        WHEN MATCHED THEN
            UPDATE SET
                target.ACTIVE_BYTES = source.ACTIVE_BYTES,
                target.TIME_TRAVEL_BYTES = source.TIME_TRAVEL_BYTES,
                target.FAILSAFE_BYTES = source.FAILSAFE_BYTES,
                target.TOTAL_BYTES = source.TOTAL_BYTES,
                target.ACTIVE_TB = source.ACTIVE_TB,
                target.TIME_TRAVEL_TB = source.TIME_TRAVEL_TB,
                target.FAILSAFE_TB = source.FAILSAFE_TB,
                target.TOTAL_TB = source.TOTAL_TB,
                target.COST_ACTIVE_USD = source.COST_ACTIVE_USD,
                target.COST_TIME_TRAVEL_USD = source.COST_TIME_TRAVEL_USD,
                target.COST_FAILSAFE_USD = source.COST_FAILSAFE_USD,
                target.COST_TOTAL_USD = source.COST_TOTAL_USD,
                target.COLLECTED_AT = CURRENT_TIMESTAMP()
        WHEN NOT MATCHED THEN
            INSERT (
                DATABASE_NAME, USAGE_DATE,
                ACTIVE_BYTES, TIME_TRAVEL_BYTES, FAILSAFE_BYTES, TOTAL_BYTES,
                ACTIVE_TB, TIME_TRAVEL_TB, FAILSAFE_TB, TOTAL_TB,
                COST_ACTIVE_USD, COST_TIME_TRAVEL_USD, COST_FAILSAFE_USD, COST_TOTAL_USD,
                COLLECTED_AT, COLLECTED_BY
            )
            VALUES (
                source.DATABASE_NAME, source.USAGE_DATE,
                source.ACTIVE_BYTES, source.TIME_TRAVEL_BYTES, source.FAILSAFE_BYTES, source.TOTAL_BYTES,
                source.ACTIVE_TB, source.TIME_TRAVEL_TB, source.FAILSAFE_TB, source.TOTAL_TB,
                source.COST_ACTIVE_USD, source.COST_TIME_TRAVEL_USD, source.COST_FAILSAFE_USD, source.COST_TOTAL_USD,
                CURRENT_TIMESTAMP(), CURRENT_USER()
            )
        `;

        var mergeStmt = snowflake.createStatement({
            sqlText: mergeSql,
            binds: [
                storagePricePerTBDay, storagePricePerTBDay, storagePricePerTBDay, storagePricePerTBDay,
                collectionStartDate.toISOString().substring(0, 10),
                collectionEndDate.toISOString().substring(0, 10)
            ]
        });

        var mergeResult = mergeStmt.execute();
        mergeResult.next();

        rowsInserted = mergeResult.getColumnValue('number of rows inserted');
        rowsUpdated = mergeResult.getColumnValue('number of rows updated');

        result.rows_inserted = rowsInserted;
        result.rows_updated = rowsUpdated;
        result.rows_affected = rowsInserted + rowsUpdated;

        // =================================================================
        // STEP 4: GENERATE COLLECTION SUMMARY
        // =================================================================

        result.status = 'GENERATING_SUMMARY';

        // Overall summary
        var summaryRs = executeSql(`
            SELECT
                COUNT(DISTINCT DATABASE_NAME) AS database_count,
                COUNT(DISTINCT USAGE_DATE) AS days_collected,
                SUM(TOTAL_TB) AS total_storage_tb,
                SUM(ACTIVE_TB) AS active_storage_tb,
                SUM(TIME_TRAVEL_TB) AS time_travel_tb,
                SUM(FAILSAFE_TB) AS failsafe_tb,
                SUM(COST_TOTAL_USD) AS total_cost_usd,
                AVG(COST_TOTAL_USD) AS avg_daily_cost_usd
            FROM FINOPS_CONTROL_DB.COST_DATA.FACT_STORAGE_COST_HISTORY
            WHERE USAGE_DATE >= ?
              AND USAGE_DATE <= ?
        `, [
            collectionStartDate.toISOString().substring(0, 10),
            collectionEndDate.toISOString().substring(0, 10)
        ]);

        if (summaryRs.next()) {
            result.summary = {
                databases_tracked: summaryRs.getColumnValue('DATABASE_COUNT'),
                days_collected: summaryRs.getColumnValue('DAYS_COLLECTED'),
                total_storage_tb: parseFloat(summaryRs.getColumnValue('TOTAL_STORAGE_TB')).toFixed(3),
                active_storage_tb: parseFloat(summaryRs.getColumnValue('ACTIVE_STORAGE_TB')).toFixed(3),
                time_travel_tb: parseFloat(summaryRs.getColumnValue('TIME_TRAVEL_TB')).toFixed(3),
                failsafe_tb: parseFloat(summaryRs.getColumnValue('FAILSAFE_TB')).toFixed(3),
                total_cost_usd: parseFloat(summaryRs.getColumnValue('TOTAL_COST_USD')).toFixed(2),
                avg_daily_cost_usd: parseFloat(summaryRs.getColumnValue('AVG_DAILY_COST_USD')).toFixed(2)
            };
        }

        // Top 5 databases by storage cost (latest date)
        var latestDate = executeScalar(`
            SELECT MAX(USAGE_DATE)
            FROM FINOPS_CONTROL_DB.COST_DATA.FACT_STORAGE_COST_HISTORY
            WHERE USAGE_DATE >= ?
              AND USAGE_DATE <= ?
        `, [
            collectionStartDate.toISOString().substring(0, 10),
            collectionEndDate.toISOString().substring(0, 10)
        ]);

        var top5Rs = executeSql(`
            SELECT
                DATABASE_NAME,
                TOTAL_TB,
                ACTIVE_TB,
                TIME_TRAVEL_TB,
                FAILSAFE_TB,
                COST_TOTAL_USD,
                ROUND((TIME_TRAVEL_TB + FAILSAFE_TB) / NULLIF(TOTAL_TB, 0) * 100, 2) AS OVERHEAD_PCT
            FROM FINOPS_CONTROL_DB.COST_DATA.FACT_STORAGE_COST_HISTORY
            WHERE USAGE_DATE = ?
            ORDER BY COST_TOTAL_USD DESC
            LIMIT 5
        `, [latestDate]);

        var top5Databases = [];
        while (top5Rs.next()) {
            top5Databases.push({
                database_name: top5Rs.getColumnValue('DATABASE_NAME'),
                total_tb: parseFloat(top5Rs.getColumnValue('TOTAL_TB')).toFixed(3),
                active_tb: parseFloat(top5Rs.getColumnValue('ACTIVE_TB')).toFixed(3),
                time_travel_tb: parseFloat(top5Rs.getColumnValue('TIME_TRAVEL_TB')).toFixed(3),
                failsafe_tb: parseFloat(top5Rs.getColumnValue('FAILSAFE_TB')).toFixed(3),
                daily_cost_usd: parseFloat(top5Rs.getColumnValue('COST_TOTAL_USD')).toFixed(2),
                overhead_pct: top5Rs.getColumnValue('OVERHEAD_PCT')
            });
        }

        result.top_5_databases_by_storage = top5Databases;

        // Storage growth analysis (comparing first and last day in collection window)
        var growthRs = executeSql(`
            WITH first_day AS (
                SELECT
                    DATABASE_NAME,
                    TOTAL_TB AS FIRST_DAY_TB
                FROM FINOPS_CONTROL_DB.COST_DATA.FACT_STORAGE_COST_HISTORY
                WHERE USAGE_DATE = ?
            ),
            last_day AS (
                SELECT
                    DATABASE_NAME,
                    TOTAL_TB AS LAST_DAY_TB
                FROM FINOPS_CONTROL_DB.COST_DATA.FACT_STORAGE_COST_HISTORY
                WHERE USAGE_DATE = ?
            )
            SELECT
                l.DATABASE_NAME,
                COALESCE(f.FIRST_DAY_TB, 0) AS FIRST_DAY_TB,
                l.LAST_DAY_TB,
                l.LAST_DAY_TB - COALESCE(f.FIRST_DAY_TB, 0) AS GROWTH_TB,
                CASE
                    WHEN COALESCE(f.FIRST_DAY_TB, 0) > 0
                    THEN ROUND((l.LAST_DAY_TB - f.FIRST_DAY_TB) / f.FIRST_DAY_TB * 100, 2)
                    ELSE NULL
                END AS GROWTH_PCT
            FROM last_day l
            LEFT JOIN first_day f ON l.DATABASE_NAME = f.DATABASE_NAME
            WHERE l.LAST_DAY_TB - COALESCE(f.FIRST_DAY_TB, 0) > 0.1  -- Growth > 0.1 TB
            ORDER BY GROWTH_TB DESC
            LIMIT 5
        `, [
            collectionStartDate.toISOString().substring(0, 10),
            collectionEndDate.toISOString().substring(0, 10)
        ]);

        var fastestGrowth = [];
        while (growthRs.next()) {
            fastestGrowth.push({
                database_name: growthRs.getColumnValue('DATABASE_NAME'),
                first_day_tb: parseFloat(growthRs.getColumnValue('FIRST_DAY_TB')).toFixed(3),
                last_day_tb: parseFloat(growthRs.getColumnValue('LAST_DAY_TB')).toFixed(3),
                growth_tb: parseFloat(growthRs.getColumnValue('GROWTH_TB')).toFixed(3),
                growth_pct: growthRs.getColumnValue('GROWTH_PCT')
            });
        }

        result.fastest_growing_databases = fastestGrowth;

        // =================================================================
        // STEP 5: FINALIZE
        // =================================================================

        result.status = 'SUCCESS';
        result.end_time = new Date().toISOString();
        result.duration_seconds = ((new Date() - startTimestamp) / 1000).toFixed(2);

        // Log to audit table
        logExecution(executionId, procedureName, 'SUCCESS', startTimestamp, new Date(),
                     rowsInserted, rowsUpdated, null, result.parameters);

        return result;

    } catch (err) {
        // Error handling
        result.status = 'ERROR';
        result.error_message = err.message;
        result.error_stack = err.stack;
        result.end_time = new Date().toISOString();

        // Log error to audit table
        logExecution(executionId, procedureName, 'ERROR', startTimestamp, new Date(),
                     rowsInserted, rowsUpdated, err.message, result.parameters);

        return result;
    }
$$;

-- =========================================================================
-- GRANT EXECUTE PERMISSIONS
-- =========================================================================
GRANT USAGE ON PROCEDURE SP_COLLECT_STORAGE_COSTS(NUMBER, BOOLEAN)
    TO ROLE FINOPS_ANALYST_ROLE;


-- =========================================================================
-- VERIFICATION QUERIES
-- =========================================================================

/*
-- Test 1: Initial collection (last 7 days)
CALL FINOPS_CONTROL_DB.PROCEDURES.SP_COLLECT_STORAGE_COSTS(7, TRUE);

-- Test 2: Force re-collection (last 30 days, non-incremental)
CALL FINOPS_CONTROL_DB.PROCEDURES.SP_COLLECT_STORAGE_COSTS(30, FALSE);

-- Test 3: Incremental collection (only new data since last run)
CALL FINOPS_CONTROL_DB.PROCEDURES.SP_COLLECT_STORAGE_COSTS(7, TRUE);


-- Verify: Check collected storage data
SELECT
    USAGE_DATE,
    COUNT(DISTINCT DATABASE_NAME) AS DATABASE_COUNT,
    SUM(TOTAL_TB) AS TOTAL_STORAGE_TB,
    SUM(ACTIVE_TB) AS ACTIVE_TB,
    SUM(TIME_TRAVEL_TB) AS TIME_TRAVEL_TB,
    SUM(FAILSAFE_TB) AS FAILSAFE_TB,
    SUM(COST_TOTAL_USD) AS TOTAL_DAILY_COST,
    ROUND(SUM(TIME_TRAVEL_TB + FAILSAFE_TB) / NULLIF(SUM(TOTAL_TB), 0) * 100, 2) AS OVERHEAD_PCT
FROM FINOPS_CONTROL_DB.COST_DATA.FACT_STORAGE_COST_HISTORY
WHERE USAGE_DATE >= DATEADD(DAY, -30, CURRENT_DATE())
GROUP BY USAGE_DATE
ORDER BY USAGE_DATE DESC;


-- Verify: Top 10 databases by storage cost (latest date)
SELECT
    DATABASE_NAME,
    USAGE_DATE,
    TOTAL_TB,
    ACTIVE_TB,
    TIME_TRAVEL_TB,
    FAILSAFE_TB,
    COST_TOTAL_USD AS DAILY_COST_USD,
    COST_TOTAL_USD * 30.42 AS ESTIMATED_MONTHLY_COST,
    ROUND((TIME_TRAVEL_TB + FAILSAFE_TB) / NULLIF(TOTAL_TB, 0) * 100, 2) AS OVERHEAD_PCT
FROM FINOPS_CONTROL_DB.COST_DATA.FACT_STORAGE_COST_HISTORY
WHERE USAGE_DATE = (SELECT MAX(USAGE_DATE) FROM FINOPS_CONTROL_DB.COST_DATA.FACT_STORAGE_COST_HISTORY)
ORDER BY COST_TOTAL_USD DESC
LIMIT 10;


-- Verify: Storage growth trend (30-day comparison)
WITH earliest AS (
    SELECT
        DATABASE_NAME,
        TOTAL_TB AS EARLIEST_TB,
        USAGE_DATE AS EARLIEST_DATE
    FROM FINOPS_CONTROL_DB.COST_DATA.FACT_STORAGE_COST_HISTORY
    WHERE USAGE_DATE = (
        SELECT MIN(USAGE_DATE)
        FROM FINOPS_CONTROL_DB.COST_DATA.FACT_STORAGE_COST_HISTORY
        WHERE USAGE_DATE >= DATEADD(DAY, -30, CURRENT_DATE())
    )
),
latest AS (
    SELECT
        DATABASE_NAME,
        TOTAL_TB AS LATEST_TB,
        USAGE_DATE AS LATEST_DATE
    FROM FINOPS_CONTROL_DB.COST_DATA.FACT_STORAGE_COST_HISTORY
    WHERE USAGE_DATE = (SELECT MAX(USAGE_DATE) FROM FINOPS_CONTROL_DB.COST_DATA.FACT_STORAGE_COST_HISTORY)
)
SELECT
    l.DATABASE_NAME,
    e.EARLIEST_DATE,
    l.LATEST_DATE,
    COALESCE(e.EARLIEST_TB, 0) AS EARLIEST_TB,
    l.LATEST_TB,
    l.LATEST_TB - COALESCE(e.EARLIEST_TB, 0) AS GROWTH_TB,
    CASE
        WHEN COALESCE(e.EARLIEST_TB, 0) > 0
        THEN ROUND((l.LATEST_TB - e.EARLIEST_TB) / e.EARLIEST_TB * 100, 2)
        ELSE NULL
    END AS GROWTH_PCT,
    DATEDIFF(DAY, e.EARLIEST_DATE, l.LATEST_DATE) AS DAYS_ELAPSED
FROM latest l
LEFT JOIN earliest e ON l.DATABASE_NAME = e.DATABASE_NAME
ORDER BY GROWTH_TB DESC;


-- Verify: Storage cost breakdown by database (last 30 days total)
SELECT
    DATABASE_NAME,
    SUM(COST_ACTIVE_USD) AS ACTIVE_COST_30D,
    SUM(COST_TIME_TRAVEL_USD) AS TIME_TRAVEL_COST_30D,
    SUM(COST_FAILSAFE_USD) AS FAILSAFE_COST_30D,
    SUM(COST_TOTAL_USD) AS TOTAL_COST_30D,
    ROUND(SUM(COST_TIME_TRAVEL_USD + COST_FAILSAFE_USD) / NULLIF(SUM(COST_TOTAL_USD), 0) * 100, 2) AS OVERHEAD_COST_PCT
FROM FINOPS_CONTROL_DB.COST_DATA.FACT_STORAGE_COST_HISTORY
WHERE USAGE_DATE >= DATEADD(DAY, -30, CURRENT_DATE())
GROUP BY DATABASE_NAME
ORDER BY TOTAL_COST_30D DESC;


-- Verify: Daily storage cost trend (30-day trend)
SELECT
    USAGE_DATE,
    SUM(COST_TOTAL_USD) AS DAILY_COST,
    SUM(TOTAL_TB) AS TOTAL_TB,
    ROUND(SUM(COST_TOTAL_USD) / NULLIF(SUM(TOTAL_TB), 0), 4) AS COST_PER_TB
FROM FINOPS_CONTROL_DB.COST_DATA.FACT_STORAGE_COST_HISTORY
WHERE USAGE_DATE >= DATEADD(DAY, -30, CURRENT_DATE())
GROUP BY USAGE_DATE
ORDER BY USAGE_DATE DESC;


-- Verify: Check procedure execution log
SELECT
    EXECUTION_ID,
    PROCEDURE_NAME,
    EXECUTION_STATUS,
    START_TIME,
    DURATION_SECONDS,
    ROWS_INSERTED,
    ROWS_UPDATED,
    EXECUTION_PARAMETERS:lookback_days AS LOOKBACK_DAYS,
    EXECUTION_PARAMETERS:incremental AS INCREMENTAL
FROM FINOPS_CONTROL_DB.AUDIT.PROCEDURE_EXECUTION_LOG
WHERE PROCEDURE_NAME = 'SP_COLLECT_STORAGE_COSTS'
ORDER BY START_TIME DESC
LIMIT 10;


-- Analytics: Databases with excessive time-travel/failsafe overhead
SELECT
    DATABASE_NAME,
    USAGE_DATE,
    TOTAL_TB,
    ACTIVE_TB,
    TIME_TRAVEL_TB + FAILSAFE_TB AS OVERHEAD_TB,
    ROUND((TIME_TRAVEL_TB + FAILSAFE_TB) / NULLIF(TOTAL_TB, 0) * 100, 2) AS OVERHEAD_PCT,
    COST_TIME_TRAVEL_USD + COST_FAILSAFE_USD AS WASTED_COST_USD,
    CASE
        WHEN (TIME_TRAVEL_TB + FAILSAFE_TB) / NULLIF(TOTAL_TB, 0) > 0.50 THEN 'CRITICAL'
        WHEN (TIME_TRAVEL_TB + FAILSAFE_TB) / NULLIF(TOTAL_TB, 0) > 0.30 THEN 'HIGH'
        WHEN (TIME_TRAVEL_TB + FAILSAFE_TB) / NULLIF(TOTAL_TB, 0) > 0.15 THEN 'MEDIUM'
        ELSE 'LOW'
    END AS RISK_LEVEL
FROM FINOPS_CONTROL_DB.COST_DATA.FACT_STORAGE_COST_HISTORY
WHERE USAGE_DATE = (SELECT MAX(USAGE_DATE) FROM FINOPS_CONTROL_DB.COST_DATA.FACT_STORAGE_COST_HISTORY)
  AND (TIME_TRAVEL_TB + FAILSAFE_TB) / NULLIF(TOTAL_TB, 0) > 0.15  -- Overhead > 15%
ORDER BY OVERHEAD_PCT DESC;


-- Analytics: Month-over-month storage growth
WITH monthly_storage AS (
    SELECT
        DATABASE_NAME,
        DATE_TRUNC('MONTH', USAGE_DATE) AS MONTH,
        AVG(TOTAL_TB) AS AVG_MONTHLY_TB,
        AVG(COST_TOTAL_USD) AS AVG_DAILY_COST,
        AVG(COST_TOTAL_USD) * 30.42 AS ESTIMATED_MONTHLY_COST
    FROM FINOPS_CONTROL_DB.COST_DATA.FACT_STORAGE_COST_HISTORY
    WHERE USAGE_DATE >= DATEADD(MONTH, -3, CURRENT_DATE())
    GROUP BY DATABASE_NAME, DATE_TRUNC('MONTH', USAGE_DATE)
)
SELECT
    curr.DATABASE_NAME,
    curr.MONTH AS CURRENT_MONTH,
    prev.MONTH AS PREVIOUS_MONTH,
    curr.AVG_MONTHLY_TB AS CURRENT_AVG_TB,
    prev.AVG_MONTHLY_TB AS PREVIOUS_AVG_TB,
    curr.AVG_MONTHLY_TB - COALESCE(prev.AVG_MONTHLY_TB, 0) AS MOM_GROWTH_TB,
    CASE
        WHEN COALESCE(prev.AVG_MONTHLY_TB, 0) > 0
        THEN ROUND((curr.AVG_MONTHLY_TB - prev.AVG_MONTHLY_TB) / prev.AVG_MONTHLY_TB * 100, 2)
        ELSE NULL
    END AS MOM_GROWTH_PCT,
    curr.ESTIMATED_MONTHLY_COST AS CURRENT_MONTHLY_COST,
    prev.ESTIMATED_MONTHLY_COST AS PREVIOUS_MONTHLY_COST
FROM monthly_storage curr
LEFT JOIN monthly_storage prev
    ON curr.DATABASE_NAME = prev.DATABASE_NAME
    AND curr.MONTH = DATEADD(MONTH, 1, prev.MONTH)
WHERE curr.MONTH = DATE_TRUNC('MONTH', CURRENT_DATE())
ORDER BY MOM_GROWTH_TB DESC;
*/


-- =========================================================================
-- BEST PRACTICES & DESIGN NOTES
-- =========================================================================

/*
BEST PRACTICES:

1. STORAGE DATA LATENCY:
   - DATABASE_STORAGE_USAGE_HISTORY has 24-48 hour latency
   - Always collect data at least 2 days old
   - Run this procedure daily, not hourly (storage changes slowly)

2. PRICING CALCULATION:
   - Storage pricing varies by region and cloud provider (AWS, Azure, GCP)
   - On-Demand: ~$23/TB/month (~$0.766/TB/day)
   - Pre-Purchased: ~$20/TB/month (~$0.666/TB/day)
   - Update GLOBAL_SETTINGS to match your contract pricing

3. STORAGE TYPES:
   - ACTIVE_BYTES: Current data in tables
   - TIME_TRAVEL_BYTES: Historical data (retention period: 1-90 days)
   - FAILSAFE_BYTES: Disaster recovery (always 7 days, non-configurable)
   - All three are charged at the same rate

4. OVERHEAD OPTIMIZATION:
   - Time-travel + failsafe typically 30-50% of total storage
   - Reduce time-travel period for non-critical tables (ALTER TABLE ... DATA_RETENTION_TIME_IN_DAYS = 1)
   - Drop unused tables to eliminate failsafe costs (7-day delay)
   - Use TRANSIENT tables for staging data (no failsafe)
   - Use TEMPORARY tables for session data (no failsafe, no time-travel)

5. SCHEDULING RECOMMENDATION:
   - Run daily: SCHEDULE = 'USING CRON 0 2 * * * UTC'  (2 AM UTC)
   - Collect last 7 days: P_LOOKBACK_DAYS=7
   - Use incremental mode: P_INCREMENTAL=TRUE

6. GROWTH MONITORING:
   - Track month-over-month growth by database
   - Alert if growth exceeds threshold (e.g., >50% MoM)
   - Identify databases with excessive time-travel/failsafe overhead

7. CHARGEBACK STRATEGY:
   - Storage costs are typically allocated by database ownership
   - Join FACT_STORAGE_COST_HISTORY with DIM_CHARGEBACK_ENTITY on database_name
   - Consider amortizing storage costs (e.g., monthly average, not daily spikes)


EDGE CASES HANDLED:

1. NULL DATABASE_NAME: Filtered out (should not happen)
2. FIRST RUN (no watermark): Falls back to P_LOOKBACK_DAYS
3. NO NEW DATA: Returns early if collection window is empty
4. NEGATIVE TIME_TRAVEL_BYTES: Use GREATEST(0, ...) to avoid negative values
5. STORAGE PRICE CHANGES: Uses current price from GLOBAL_SETTINGS
6. DATABASE DELETIONS: Historical data remains in FACT_STORAGE_COST_HISTORY
7. OVERLAPPING COLLECTIONS: MERGE handles duplicates gracefully


STORAGE COST REDUCTION STRATEGIES:

1. REDUCE TIME-TRAVEL RETENTION:
   -- For non-production databases
   ALTER DATABASE STAGING_DB SET DATA_RETENTION_TIME_IN_DAYS = 1;

   -- For specific tables
   ALTER TABLE TEMP_PROCESSING_TABLE SET DATA_RETENTION_TIME_IN_DAYS = 0;

2. USE TRANSIENT TABLES FOR STAGING:
   CREATE TRANSIENT TABLE staging.temp_load (...);
   -- No failsafe, saves ~20-30% storage cost

3. USE TEMPORARY TABLES FOR SESSION DATA:
   CREATE TEMPORARY TABLE session_data (...);
   -- No failsafe, no time-travel, no persistent storage

4. DROP UNUSED TABLES PROMPTLY:
   -- Failsafe persists for 7 days after DROP
   -- Storage costs continue for those 7 days

5. ENABLE CLUSTERING CAREFULLY:
   -- Clustering improves query performance but increases storage
   -- Monitor re-clustering costs vs query performance gains

6. COMPRESS DATA EFFICIENTLY:
   -- Snowflake compresses automatically, but schema design matters
   -- Use appropriate data types (INT vs VARCHAR(1000))
   -- Avoid storing JSON as VARCHAR (use VARIANT)


MONITORING AND ALERTING:

1. Alert on storage growth >50% month-over-month
2. Alert on overhead (time-travel + failsafe) >50% of total
3. Alert on monthly storage cost exceeding budget
4. Dashboard: Daily storage cost trend (30-day rolling)
5. Dashboard: Storage cost breakdown by database
6. Dashboard: Top 10 databases by storage cost
7. Dashboard: Databases with excessive overhead


OBJECTS CREATED:
  - FINOPS_CONTROL_DB.PROCEDURES.SP_COLLECT_STORAGE_COSTS

NEXT STEPS:
  - Create Task to automate daily collection
  - Create view for storage cost analytics
  - Create stored procedure for storage optimization recommendations
  - Integrate with budget alerting system
*/



/*
#############################################################################
  MODULE 02 COMPLETE!

  Objects Created:
    - Tables: FACT_WAREHOUSE_COST_HISTORY, FACT_QUERY_COST_HISTORY, FACT_STORAGE_COST_HISTORY
    - Table: FACT_SERVERLESS_COST_HISTORY, GLOBAL_SETTINGS, PROCEDURE_EXECUTION_LOG
    - Procedures: SP_COLLECT_WAREHOUSE_COSTS, SP_COLLECT_QUERY_COSTS, SP_COLLECT_STORAGE_COSTS

  Next: FINOPS - Module 03 (Chargeback Attribution)
#############################################################################
*/
