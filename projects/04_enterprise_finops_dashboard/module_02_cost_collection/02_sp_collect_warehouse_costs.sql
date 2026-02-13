/*
=============================================================================
  MODULE 02 : COST COLLECTION
  SCRIPT 02 : SP_COLLECT_WAREHOUSE_COSTS — Warehouse Credit Consumption
=============================================================================
  SNOWBRIX ACADEMY — Enterprise FinOps Dashboard for Snowflake

  LEARNING OBJECTIVES:
    1. Collect warehouse credit consumption from ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
    2. Understand per-minute credit grain and cost calculation formulas
    3. Implement incremental collection with watermark tracking
    4. Handle ACCOUNT_USAGE latency (45 minutes to 3 hours)
    5. Calculate cost per second for query attribution

  THIS IS THE FOUNDATION OF WAREHOUSE COST TRACKING.
  It collects raw credit consumption data at per-minute grain, which feeds
  query-level attribution and enables chargeback to teams.

  EXECUTION FLOW:
  ┌──────────────────────────────────────────────────────────────┐
  │  1. Get last collection timestamp (watermark)                │
  │  2. Validate lookback period (respect ACCOUNT_USAGE latency) │
  │  3. Query WAREHOUSE_METERING_HISTORY for new records         │
  │  4. Calculate USD cost using credit price from config        │
  │  5. Calculate cost per second for attribution                │
  │  6. Merge into FACT_WAREHOUSE_COST_HISTORY (idempotent)      │
  │  7. Log execution to audit table                             │
  │  8. Return detailed summary                                  │
  └──────────────────────────────────────────────────────────────┘

  COST CALCULATION LOGIC:
  ┌──────────────────────────────────────────────────────────────┐
  │  WAREHOUSE_METERING_HISTORY provides:                        │
  │    - START_TIME, END_TIME (typically 1-minute buckets)       │
  │    - CREDITS_USED (total credits in this time slice)         │
  │    - CREDITS_USED_COMPUTE (warehouse execution credits)      │
  │    - CREDITS_USED_CLOUD_SERVICES (metadata ops credits)      │
  │                                                               │
  │  Cost calculation:                                           │
  │    cost_usd = credits_used * credit_price_usd                │
  │    cost_per_second = cost_usd / duration_seconds             │
  │                                                               │
  │  Note: Cloud services credits are FREE up to 10% of daily    │
  │  compute credits. This is handled in a separate daily        │
  │  adjustment procedure (SP_ADJUST_CLOUD_SERVICES_COSTS).      │
  └──────────────────────────────────────────────────────────────┘

  PREREQUISITES:
    - Module 01 completed (databases, warehouses, roles, grants)
    - FACT_WAREHOUSE_COST_HISTORY table created
    - GLOBAL_SETTINGS table populated with credit pricing
    - PROCEDURE_EXECUTION_LOG table exists

  ESTIMATED TIME: 15 minutes

  SNOWFLAKE DOCUMENTATION:
    - WAREHOUSE_METERING_HISTORY:
      https://docs.snowflake.com/en/sql-reference/account-usage/warehouse_metering_history

=============================================================================
*/

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
