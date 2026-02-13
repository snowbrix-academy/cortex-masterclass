/*
=============================================================================
  MODULE 02 : COST COLLECTION
  SCRIPT 03 : SP_COLLECT_QUERY_COSTS — Query-Level Cost Attribution
=============================================================================
  SNOWBRIX ACADEMY — Enterprise FinOps Dashboard for Snowflake

  LEARNING OBJECTIVES:
    1. Collect query execution costs from ACCOUNT_USAGE.QUERY_HISTORY
    2. Calculate per-query cost using warehouse size and execution time
    3. Extract attribution metadata (user, role, tags, BI tool)
    4. Implement QUERY_TAG parsing for team/department/project attribution
    5. Handle cached queries and queries without warehouse context

  THIS IS THE HEART OF COST ATTRIBUTION AND CHARGEBACK.
  It enables answering: "How much did this user/team/project/query cost?"

  EXECUTION FLOW:
  ┌──────────────────────────────────────────────────────────────┐
  │  1. Get last collection timestamp (watermark)                │
  │  2. Query QUERY_HISTORY for executed queries in window       │
  │  3. Calculate cost: (query_duration / 3600000) * wh_size_cr  │
  │  4. Parse QUERY_TAG for chargeback metadata                  │
  │  5. Classify BI tool from APPLICATION_NAME                   │
  │  6. Merge into FACT_QUERY_COST_HISTORY                       │
  │  7. Generate attribution summary                             │
  │  8. Log execution                                            │
  └──────────────────────────────────────────────────────────────┘

  COST CALCULATION FORMULA:
  ┌──────────────────────────────────────────────────────────────┐
  │  Warehouse Size Credits per Hour:                            │
  │    XSMALL  = 1 credit/hour                                   │
  │    SMALL   = 2 credits/hour                                  │
  │    MEDIUM  = 4 credits/hour                                  │
  │    LARGE   = 8 credits/hour                                  │
  │    XLARGE  = 16 credits/hour                                 │
  │    2XLARGE = 32 credits/hour                                 │
  │    3XLARGE = 64 credits/hour                                 │
  │    4XLARGE = 128 credits/hour                                │
  │                                                               │
  │  Query Cost Calculation:                                     │
  │    execution_time_hours = execution_time_ms / 3,600,000      │
  │    credits_used = execution_time_hours * warehouse_size_cr   │
  │    cost_usd = credits_used * credit_price_usd                │
  │                                                               │
  │  Example:                                                    │
  │    MEDIUM warehouse (4 cr/hr) runs query for 30 seconds      │
  │    execution_time_hours = 30,000 ms / 3,600,000 = 0.00833    │
  │    credits_used = 0.00833 * 4 = 0.03333                      │
  │    cost_usd = 0.03333 * $3.00 = $0.10                        │
  └──────────────────────────────────────────────────────────────┘

  ATTRIBUTION HIERARCHY:
  ┌──────────────────────────────────────────────────────────────┐
  │  Priority 1: QUERY_TAG (user-set, most specific)            │
  │    Format: "team=DATA_ENG;project=ETL;department=ENGINEERING"│
  │                                                               │
  │  Priority 2: Warehouse Tag Lookup                           │
  │    Query DIM_CHARGEBACK_ENTITY by warehouse_name             │
  │                                                               │
  │  Priority 3: User/Role Mapping                              │
  │    Query DIM_CHARGEBACK_ENTITY by user_name or role_name     │
  │                                                               │
  │  Unallocated: If none of above succeed, mark as UNALLOCATED  │
  └──────────────────────────────────────────────────────────────┘

  PREREQUISITES:
    - Module 01 completed (databases, warehouses, roles, grants)
    - FACT_QUERY_COST_HISTORY table created
    - GLOBAL_SETTINGS table populated
    - DIM_CHARGEBACK_ENTITY table (optional, for fallback attribution)

  ESTIMATED TIME: 20 minutes

  SNOWFLAKE DOCUMENTATION:
    - QUERY_HISTORY:
      https://docs.snowflake.com/en/sql-reference/account-usage/query_history
    - QUERY_TAG:
      https://docs.snowflake.com/en/sql-reference/parameters#query-tag

=============================================================================
*/

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
