/*
=============================================================================
  MODULE 02 : COST COLLECTION
  SCRIPT 04 : SP_COLLECT_STORAGE_COSTS — Daily Storage Cost Tracking
=============================================================================
  SNOWBRIX ACADEMY — Enterprise FinOps Dashboard for Snowflake

  LEARNING OBJECTIVES:
    1. Collect daily storage costs from ACCOUNT_USAGE.DATABASE_STORAGE_USAGE_HISTORY
    2. Understand storage cost components: active, time-travel, failsafe
    3. Convert bytes to TB and calculate daily storage costs
    4. Handle regional and cloud-specific pricing differences
    5. Track storage growth trends over time

  STORAGE IS OFTEN THE SECOND-LARGEST COST AFTER COMPUTE.
  This procedure tracks all storage costs and enables identification of
  databases consuming excessive storage or growing unexpectedly.

  EXECUTION FLOW:
  ┌──────────────────────────────────────────────────────────────┐
  │  1. Get last collection date (watermark)                     │
  │  2. Query DATABASE_STORAGE_USAGE_HISTORY for new records     │
  │  3. Convert bytes to TB (divide by 1,099,511,627,776)        │
  │  4. Calculate daily costs using storage rate from config     │
  │  5. Separate: active, time-travel, failsafe costs            │
  │  6. Merge into FACT_STORAGE_COST_HISTORY                     │
  │  7. Generate storage summary and growth analysis             │
  │  8. Log execution                                            │
  └──────────────────────────────────────────────────────────────┘

  STORAGE COST CALCULATION:
  ┌──────────────────────────────────────────────────────────────┐
  │  Snowflake Storage Pricing (varies by region/cloud):         │
  │    - On-Demand: ~$23/TB/month (~$0.766/TB/day)               │
  │    - Pre-Purchased: ~$20/TB/month (~$0.666/TB/day)           │
  │                                                               │
  │  Storage Types:                                              │
  │    1. ACTIVE_BYTES: Current data in tables                   │
  │    2. TIME_TRAVEL_BYTES: Historical data (1-90 days)         │
  │    3. FAILSAFE_BYTES: Disaster recovery (7 days)             │
  │                                                               │
  │  Cost Formula:                                               │
  │    storage_tb = storage_bytes / 1,099,511,627,776            │
  │    daily_cost = storage_tb * storage_price_per_tb_per_day    │
  │                                                               │
  │  Note: Time-travel and failsafe are charged at same rate     │
  │  as active storage.                                          │
  └──────────────────────────────────────────────────────────────┘

  STORAGE USAGE DATA GRAIN:
  ┌──────────────────────────────────────────────────────────────┐
  │  DATABASE_STORAGE_USAGE_HISTORY provides:                    │
  │    - One row per database per day                            │
  │    - USAGE_DATE: The date of the snapshot                    │
  │    - AVERAGE_DATABASE_BYTES: Daily average active storage    │
  │    - AVERAGE_FAILSAFE_BYTES: Daily average failsafe storage  │
  │                                                               │
  │  Note: Storage is measured and averaged throughout the day.  │
  │  Data is available with ~24-hour latency.                    │
  └──────────────────────────────────────────────────────────────┘

  PREREQUISITES:
    - Module 01 completed (databases, warehouses, roles, grants)
    - FACT_STORAGE_COST_HISTORY table created
    - GLOBAL_SETTINGS table populated with storage pricing
    - PROCEDURE_EXECUTION_LOG table exists

  ESTIMATED TIME: 15 minutes

  SNOWFLAKE DOCUMENTATION:
    - DATABASE_STORAGE_USAGE_HISTORY:
      https://docs.snowflake.com/en/sql-reference/account-usage/database_storage_usage_history
    - Storage Pricing:
      https://www.snowflake.com/pricing/

=============================================================================
*/

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
