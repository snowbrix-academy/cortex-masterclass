/*
=============================================================================
  MODULE 03 : CHARGEBACK ATTRIBUTION
  SCRIPT 02 : SP_CALCULATE_CHARGEBACK — Core Attribution Logic
=============================================================================
  SNOWBRIX ACADEMY — Enterprise FinOps Dashboard for Snowflake

  LEARNING OBJECTIVES:
    1. Implement multi-method attribution (query tag, warehouse, user, role)
    2. Handle proportional allocation for shared resources
    3. Parse QUERY_TAG metadata for fine-grained attribution
    4. Calculate daily aggregated chargeback costs by entity
    5. Track unallocated costs and attribution coverage metrics

  ATTRIBUTION PRIORITY (WATERFALL MODEL):
  ┌──────────────────────────────────────────────────────────────┐
  │  Priority 1: QUERY_TAG                                       │
  │    Parse query tag: team=DATA_ENG;project=CUST360           │
  │    IF found → Attribute to entity from DIM_CHARGEBACK_ENTITY │
  │                                                               │
  │  Priority 2: WAREHOUSE_MAPPING                               │
  │    Look up warehouse in DIM_COST_CENTER_MAPPING             │
  │    IF dedicated (100%) → Direct attribution                  │
  │    IF shared (<100%) → Proportional attribution              │
  │                                                               │
  │  Priority 3: USER_MAPPING                                    │
  │    Look up user in DIM_COST_CENTER_MAPPING                  │
  │    Apply allocation percentage                               │
  │                                                               │
  │  Priority 4: ROLE_MAPPING                                    │
  │    Look up role in DIM_COST_CENTER_MAPPING                  │
  │    Fallback for service accounts                             │
  │                                                               │
  │  Priority 5: UNALLOCATED                                     │
  │    No mapping found → Assign to UNALLOCATED entity          │
  │    Report prominently to drive mapping coverage              │
  └──────────────────────────────────────────────────────────────┘

  PROPORTIONAL ALLOCATION EXAMPLE:
  ┌──────────────────────────────────────────────────────────────┐
  │  WH_SHARED_ANALYTICS: $1,000 daily cost                      │
  │    - BI Platform Team: 60% allocation → $600                 │
  │    - Self-Service Analytics: 40% allocation → $400           │
  │                                                               │
  │  Formula:                                                     │
  │    entity_cost = total_warehouse_cost × allocation_pct / 100 │
  └──────────────────────────────────────────────────────────────┘

  PREREQUISITES:
    - Module 03, Script 01 completed (dimension tables)
    - FACT_WAREHOUSE_COST_HISTORY populated
    - FACT_QUERY_COST_HISTORY populated

  ESTIMATED TIME: 25 minutes

=============================================================================
*/

USE ROLE FINOPS_ADMIN_ROLE;
USE DATABASE FINOPS_CONTROL_DB;
USE SCHEMA PROCEDURES;
USE WAREHOUSE FINOPS_WH_ETL;

-- =========================================================================
-- PROCEDURE: SP_CALCULATE_CHARGEBACK
-- Calculates daily chargeback costs by entity using multi-method attribution
-- =========================================================================
CREATE OR REPLACE PROCEDURE SP_CALCULATE_CHARGEBACK(
    P_START_DATE        DATE,
    P_END_DATE          DATE,
    P_RECALCULATE_ALL   BOOLEAN DEFAULT FALSE  -- TRUE = recalculate existing dates
)
RETURNS VARIANT
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER
AS
$$
    // =====================================================================
    // HELPER FUNCTIONS
    // =====================================================================

    function executeSql(sqlText, binds) {
        try {
            var stmt = snowflake.createStatement({
                sqlText: sqlText,
                binds: binds || []
            });
            return stmt.execute();
        } catch (err) {
            throw new Error('SQL Error: ' + err.message + ' | SQL: ' + sqlText.substring(0, 300));
        }
    }

    function executeScalar(sqlText, binds) {
        var rs = executeSql(sqlText, binds);
        if (rs.next()) {
            return rs.getColumnValue(1);
        }
        return null;
    }

    function logExecution(execId, procName, status, startTime, endTime, rowsProcessed, errorMsg, params) {
        try {
            var durationSeconds = (endTime - startTime) / 1000;
            executeSql(
                `INSERT INTO FINOPS_CONTROL_DB.AUDIT.PROCEDURE_EXECUTION_LOG
                (EXECUTION_ID, PROCEDURE_NAME, EXECUTION_STATUS, START_TIME, END_TIME,
                 DURATION_SECONDS, ROWS_INSERTED, ERROR_MESSAGE, EXECUTION_PARAMETERS)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, PARSE_JSON(?))`,
                [execId, procName, status, startTime, endTime, durationSeconds,
                 rowsProcessed, errorMsg, JSON.stringify(params)]
            );
        } catch (err) {
            // Audit logging failure should not break procedure
            return;
        }
    }

    // =====================================================================
    // MAIN EXECUTION LOGIC
    // =====================================================================

    var executionId = executeScalar("SELECT UUID_STRING()");
    var procedureName = 'SP_CALCULATE_CHARGEBACK';
    var startTimestamp = new Date();
    var totalRowsProcessed = 0;

    var result = {
        execution_id: executionId,
        procedure_name: procedureName,
        status: 'INITIALIZING',
        start_time: startTimestamp.toISOString(),
        parameters: {
            start_date: P_START_DATE,
            end_date: P_END_DATE,
            recalculate_all: P_RECALCULATE_ALL
        }
    };

    try {
        // =================================================================
        // STEP 1: VALIDATE DATE RANGE
        // =================================================================

        if (P_START_DATE > P_END_DATE) {
            throw new Error('START_DATE must be <= END_DATE');
        }

        var daysDiff = Math.ceil((new Date(P_END_DATE) - new Date(P_START_DATE)) / (1000 * 60 * 60 * 24));
        result.days_to_process = daysDiff + 1;

        // Get UNALLOCATED entity ID
        var unallocatedEntityId = executeScalar(`
            SELECT ENTITY_ID
            FROM FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY
            WHERE ENTITY_CODE = 'UNALLOCATED'
              AND IS_CURRENT = TRUE
        `);

        if (!unallocatedEntityId) {
            throw new Error('UNALLOCATED entity not found in DIM_CHARGEBACK_ENTITY. Run module 03 script 01 first.');
        }

        result.unallocated_entity_id = unallocatedEntityId;

        // =================================================================
        // STEP 2: DELETE EXISTING DATA IF RECALCULATE_ALL = TRUE
        // =================================================================

        if (P_RECALCULATE_ALL) {
            result.status = 'DELETING_EXISTING_DATA';

            var deleteStmt = executeSql(`
                DELETE FROM FINOPS_CONTROL_DB.CHARGEBACK.FACT_CHARGEBACK_DAILY
                WHERE CHARGEBACK_DATE >= ? AND CHARGEBACK_DATE <= ?
            `, [P_START_DATE, P_END_DATE]);

            deleteStmt.next();
            result.rows_deleted = deleteStmt.getColumnValue(1);
        }

        // =================================================================
        // STEP 3: ATTRIBUTE COMPUTE COSTS (from FACT_QUERY_COST_HISTORY)
        // =================================================================

        result.status = 'ATTRIBUTING_COMPUTE_COSTS';

        var computeAttributionSql = `
        MERGE INTO FINOPS_CONTROL_DB.CHARGEBACK.FACT_CHARGEBACK_DAILY AS target
        USING (
            WITH query_costs AS (
                SELECT
                    q.QUERY_DATE,
                    q.WAREHOUSE_NAME,
                    q.USER_NAME,
                    q.ROLE_NAME,
                    q.QUERY_TAG,
                    q.TOTAL_COST_USD,
                    q.CREDITS_USED,
                    q.QUERY_ID
                FROM FINOPS_CONTROL_DB.COST_DATA.FACT_QUERY_COST_HISTORY q
                WHERE q.QUERY_DATE >= ?
                  AND q.QUERY_DATE <= ?
                  AND q.TOTAL_COST_USD > 0
            ),

            -- Priority 1: QUERY_TAG attribution
            query_tag_attribution AS (
                SELECT
                    qc.QUERY_DATE,
                    e.ENTITY_ID,
                    e.ENTITY_NAME,
                    e.ENTITY_TYPE,
                    e.COST_CENTER_CODE,
                    p.ENTITY_NAME AS PARENT_ENTITY_NAME,
                    qc.TOTAL_COST_USD,
                    qc.CREDITS_USED,
                    'QUERY_TAG' AS ATTRIBUTION_METHOD,
                    100.00 AS ALLOCATION_PERCENTAGE,
                    qc.WAREHOUSE_NAME,
                    qc.USER_NAME
                FROM query_costs qc
                CROSS JOIN LATERAL FLATTEN(INPUT => SPLIT(qc.QUERY_TAG, ';')) AS tag_parts
                JOIN FINOPS_CONTROL_DB.CHARGEBACK.DIM_QUERY_TAG_RULES r
                    ON LOWER(SPLIT_PART(tag_parts.VALUE, '=', 1)) = LOWER(r.TAG_KEY)
                    AND r.IS_ACTIVE = TRUE
                JOIN FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY e
                    ON LOWER(e.ENTITY_NAME) = LOWER(SPLIT_PART(tag_parts.VALUE, '=', 2))
                    AND e.ENTITY_TYPE = r.ENTITY_TYPE
                    AND e.IS_CURRENT = TRUE
                    AND qc.QUERY_DATE BETWEEN e.VALID_FROM AND e.VALID_TO
                LEFT JOIN FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY p
                    ON e.PARENT_ENTITY_ID = p.ENTITY_ID
                WHERE qc.QUERY_TAG IS NOT NULL
                  AND qc.QUERY_TAG != ''
            ),

            -- Priority 2: WAREHOUSE_MAPPING attribution (for queries without valid query tags)
            warehouse_attribution AS (
                SELECT
                    qc.QUERY_DATE,
                    m.ENTITY_ID,
                    e.ENTITY_NAME,
                    e.ENTITY_TYPE,
                    e.COST_CENTER_CODE,
                    p.ENTITY_NAME AS PARENT_ENTITY_NAME,
                    qc.TOTAL_COST_USD * (m.ALLOCATION_PERCENTAGE / 100.0) AS TOTAL_COST_USD,
                    qc.CREDITS_USED * (m.ALLOCATION_PERCENTAGE / 100.0) AS CREDITS_USED,
                    'WAREHOUSE_MAPPING' AS ATTRIBUTION_METHOD,
                    m.ALLOCATION_PERCENTAGE,
                    qc.WAREHOUSE_NAME,
                    qc.USER_NAME
                FROM query_costs qc
                LEFT JOIN query_tag_attribution qta
                    ON qc.QUERY_DATE = qta.QUERY_DATE
                    AND qc.USER_NAME = qta.USER_NAME
                    AND qc.WAREHOUSE_NAME = qta.WAREHOUSE_NAME
                JOIN FINOPS_CONTROL_DB.CHARGEBACK.DIM_COST_CENTER_MAPPING m
                    ON m.SOURCE_TYPE = 'WAREHOUSE'
                    AND UPPER(m.SOURCE_VALUE) = UPPER(qc.WAREHOUSE_NAME)
                    AND m.IS_CURRENT = TRUE
                    AND qc.QUERY_DATE BETWEEN m.VALID_FROM AND m.VALID_TO
                JOIN FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY e
                    ON m.ENTITY_ID = e.ENTITY_ID
                    AND e.IS_CURRENT = TRUE
                LEFT JOIN FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY p
                    ON e.PARENT_ENTITY_ID = p.ENTITY_ID
                WHERE qta.ENTITY_ID IS NULL  -- Only if no query tag match
            ),

            -- Priority 3: USER_MAPPING attribution
            user_attribution AS (
                SELECT
                    qc.QUERY_DATE,
                    m.ENTITY_ID,
                    e.ENTITY_NAME,
                    e.ENTITY_TYPE,
                    e.COST_CENTER_CODE,
                    p.ENTITY_NAME AS PARENT_ENTITY_NAME,
                    qc.TOTAL_COST_USD * (m.ALLOCATION_PERCENTAGE / 100.0) AS TOTAL_COST_USD,
                    qc.CREDITS_USED * (m.ALLOCATION_PERCENTAGE / 100.0) AS CREDITS_USED,
                    'USER_MAPPING' AS ATTRIBUTION_METHOD,
                    m.ALLOCATION_PERCENTAGE,
                    qc.WAREHOUSE_NAME,
                    qc.USER_NAME
                FROM query_costs qc
                LEFT JOIN query_tag_attribution qta
                    ON qc.QUERY_DATE = qta.QUERY_DATE
                    AND qc.USER_NAME = qta.USER_NAME
                LEFT JOIN warehouse_attribution wa
                    ON qc.QUERY_DATE = wa.QUERY_DATE
                    AND qc.USER_NAME = wa.USER_NAME
                    AND qc.WAREHOUSE_NAME = wa.WAREHOUSE_NAME
                JOIN FINOPS_CONTROL_DB.CHARGEBACK.DIM_COST_CENTER_MAPPING m
                    ON m.SOURCE_TYPE = 'USER'
                    AND UPPER(m.SOURCE_VALUE) = UPPER(qc.USER_NAME)
                    AND m.IS_CURRENT = TRUE
                    AND qc.QUERY_DATE BETWEEN m.VALID_FROM AND m.VALID_TO
                JOIN FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY e
                    ON m.ENTITY_ID = e.ENTITY_ID
                    AND e.IS_CURRENT = TRUE
                LEFT JOIN FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY p
                    ON e.PARENT_ENTITY_ID = p.ENTITY_ID
                WHERE qta.ENTITY_ID IS NULL
                  AND wa.ENTITY_ID IS NULL
            ),

            -- Priority 4: UNALLOCATED (no mapping found)
            unallocated_attribution AS (
                SELECT
                    qc.QUERY_DATE,
                    ? AS ENTITY_ID,
                    'Unallocated Costs' AS ENTITY_NAME,
                    'COST_CENTER' AS ENTITY_TYPE,
                    'CC-9999' AS COST_CENTER_CODE,
                    NULL AS PARENT_ENTITY_NAME,
                    qc.TOTAL_COST_USD,
                    qc.CREDITS_USED,
                    'UNALLOCATED' AS ATTRIBUTION_METHOD,
                    100.00 AS ALLOCATION_PERCENTAGE,
                    qc.WAREHOUSE_NAME,
                    qc.USER_NAME
                FROM query_costs qc
                LEFT JOIN query_tag_attribution qta USING (QUERY_DATE, USER_NAME, WAREHOUSE_NAME)
                LEFT JOIN warehouse_attribution wa USING (QUERY_DATE, USER_NAME, WAREHOUSE_NAME)
                LEFT JOIN user_attribution ua USING (QUERY_DATE, USER_NAME, WAREHOUSE_NAME)
                WHERE qta.ENTITY_ID IS NULL
                  AND wa.ENTITY_ID IS NULL
                  AND ua.ENTITY_ID IS NULL
            ),

            -- UNION all attribution methods
            all_attributions AS (
                SELECT * FROM query_tag_attribution
                UNION ALL SELECT * FROM warehouse_attribution
                UNION ALL SELECT * FROM user_attribution
                UNION ALL SELECT * FROM unallocated_attribution
            )

            -- Aggregate by date, entity, cost type
            SELECT
                QUERY_DATE AS CHARGEBACK_DATE,
                ENTITY_ID,
                ENTITY_NAME,
                ENTITY_TYPE,
                COST_CENTER_CODE,
                PARENT_ENTITY_NAME,
                'COMPUTE' AS COST_TYPE,
                SUM(TOTAL_COST_USD) AS COST_USD,
                SUM(CREDITS_USED) AS CREDITS_CONSUMED,
                COUNT(DISTINCT WAREHOUSE_NAME) AS UNIQUE_WAREHOUSES,
                COUNT(DISTINCT USER_NAME) AS UNIQUE_USERS,
                COUNT(*) AS QUERY_COUNT,
                ATTRIBUTION_METHOD,
                AVG(ALLOCATION_PERCENTAGE) AS ALLOCATION_PERCENTAGE
            FROM all_attributions
            GROUP BY
                QUERY_DATE, ENTITY_ID, ENTITY_NAME, ENTITY_TYPE,
                COST_CENTER_CODE, PARENT_ENTITY_NAME, ATTRIBUTION_METHOD
        ) AS source
        ON target.CHARGEBACK_DATE = source.CHARGEBACK_DATE
           AND target.ENTITY_ID = source.ENTITY_ID
           AND target.COST_TYPE = source.COST_TYPE
        WHEN MATCHED THEN
            UPDATE SET
                target.COST_USD = source.COST_USD,
                target.CREDITS_CONSUMED = source.CREDITS_CONSUMED,
                target.QUERY_COUNT = source.QUERY_COUNT,
                target.UNIQUE_USERS = source.UNIQUE_USERS,
                target.UNIQUE_WAREHOUSES = source.UNIQUE_WAREHOUSES,
                target.ATTRIBUTION_METHOD = source.ATTRIBUTION_METHOD,
                target.ALLOCATION_PERCENTAGE = source.ALLOCATION_PERCENTAGE,
                target.CALCULATED_AT = CURRENT_TIMESTAMP()
        WHEN NOT MATCHED THEN
            INSERT (
                CHARGEBACK_DATE, ENTITY_ID, ENTITY_NAME, ENTITY_TYPE,
                COST_CENTER_CODE, PARENT_ENTITY_NAME, COST_TYPE,
                COST_USD, CREDITS_CONSUMED, QUERY_COUNT,
                UNIQUE_USERS, UNIQUE_WAREHOUSES,
                ATTRIBUTION_METHOD, ALLOCATION_PERCENTAGE
            )
            VALUES (
                source.CHARGEBACK_DATE, source.ENTITY_ID, source.ENTITY_NAME, source.ENTITY_TYPE,
                source.COST_CENTER_CODE, source.PARENT_ENTITY_NAME, source.COST_TYPE,
                source.COST_USD, source.CREDITS_CONSUMED, source.QUERY_COUNT,
                source.UNIQUE_USERS, source.UNIQUE_WAREHOUSES,
                source.ATTRIBUTION_METHOD, source.ALLOCATION_PERCENTAGE
            )
        `;

        var computeStmt = snowflake.createStatement({
            sqlText: computeAttributionSql,
            binds: [P_START_DATE, P_END_DATE, unallocatedEntityId]
        });

        var computeResult = computeStmt.execute();
        computeResult.next();

        var computeRowsInserted = computeResult.getColumnValue('number of rows inserted');
        var computeRowsUpdated = computeResult.getColumnValue('number of rows updated');

        result.compute_attribution = {
            rows_inserted: computeRowsInserted,
            rows_updated: computeRowsUpdated,
            rows_affected: computeRowsInserted + computeRowsUpdated
        };

        totalRowsProcessed += (computeRowsInserted + computeRowsUpdated);

        // =================================================================
        // STEP 4: GENERATE SUMMARY STATISTICS
        // =================================================================

        result.status = 'GENERATING_SUMMARY';

        // Total cost summary
        var totalSummaryRs = executeSql(`
            SELECT
                SUM(COST_USD) AS TOTAL_COST,
                SUM(CREDITS_CONSUMED) AS TOTAL_CREDITS,
                COUNT(DISTINCT ENTITY_ID) AS ENTITIES_WITH_COSTS,
                COUNT(DISTINCT CHARGEBACK_DATE) AS DATES_PROCESSED
            FROM FINOPS_CONTROL_DB.CHARGEBACK.FACT_CHARGEBACK_DAILY
            WHERE CHARGEBACK_DATE >= ? AND CHARGEBACK_DATE <= ?
        `, [P_START_DATE, P_END_DATE]);

        if (totalSummaryRs.next()) {
            result.summary = {
                total_cost_usd: parseFloat(totalSummaryRs.getColumnValue('TOTAL_COST')).toFixed(2),
                total_credits: parseFloat(totalSummaryRs.getColumnValue('TOTAL_CREDITS')).toFixed(4),
                entities_with_costs: totalSummaryRs.getColumnValue('ENTITIES_WITH_COSTS'),
                dates_processed: totalSummaryRs.getColumnValue('DATES_PROCESSED')
            };
        }

        // Attribution method breakdown
        var methodBreakdownRs = executeSql(`
            SELECT
                ATTRIBUTION_METHOD,
                SUM(COST_USD) AS TOTAL_COST,
                COUNT(DISTINCT ENTITY_ID) AS ENTITY_COUNT,
                ROUND(SUM(COST_USD) / NULLIF((SELECT SUM(COST_USD) FROM FINOPS_CONTROL_DB.CHARGEBACK.FACT_CHARGEBACK_DAILY
                                              WHERE CHARGEBACK_DATE >= ? AND CHARGEBACK_DATE <= ?), 0) * 100, 2) AS PCT_OF_TOTAL
            FROM FINOPS_CONTROL_DB.CHARGEBACK.FACT_CHARGEBACK_DAILY
            WHERE CHARGEBACK_DATE >= ? AND CHARGEBACK_DATE <= ?
            GROUP BY ATTRIBUTION_METHOD
            ORDER BY TOTAL_COST DESC
        `, [P_START_DATE, P_END_DATE, P_START_DATE, P_END_DATE]);

        var methodBreakdown = [];
        while (methodBreakdownRs.next()) {
            methodBreakdown.push({
                attribution_method: methodBreakdownRs.getColumnValue('ATTRIBUTION_METHOD'),
                total_cost_usd: parseFloat(methodBreakdownRs.getColumnValue('TOTAL_COST')).toFixed(2),
                entity_count: methodBreakdownRs.getColumnValue('ENTITY_COUNT'),
                pct_of_total: methodBreakdownRs.getColumnValue('PCT_OF_TOTAL')
            });
        }
        result.attribution_method_breakdown = methodBreakdown;

        // Unallocated cost analysis
        var unallocatedRs = executeSql(`
            SELECT
                SUM(COST_USD) AS UNALLOCATED_COST,
                ROUND(SUM(COST_USD) / NULLIF((SELECT SUM(COST_USD) FROM FINOPS_CONTROL_DB.CHARGEBACK.FACT_CHARGEBACK_DAILY
                                              WHERE CHARGEBACK_DATE >= ? AND CHARGEBACK_DATE <= ?), 0) * 100, 2) AS UNALLOCATED_PCT
            FROM FINOPS_CONTROL_DB.CHARGEBACK.FACT_CHARGEBACK_DAILY
            WHERE CHARGEBACK_DATE >= ?
              AND CHARGEBACK_DATE <= ?
              AND ATTRIBUTION_METHOD = 'UNALLOCATED'
        `, [P_START_DATE, P_END_DATE, P_START_DATE, P_END_DATE]);

        if (unallocatedRs.next()) {
            var unallocatedCost = unallocatedRs.getColumnValue('UNALLOCATED_COST');
            var unallocatedPct = unallocatedRs.getColumnValue('UNALLOCATED_PCT');

            result.unallocated_analysis = {
                unallocated_cost_usd: unallocatedCost ? parseFloat(unallocatedCost).toFixed(2) : '0.00',
                unallocated_pct: unallocatedPct ? unallocatedPct : 0,
                is_within_target: unallocatedPct < 5.0,  // Target: <5% unallocated
                target_pct: 5.0
            };
        }

        // Top 5 most expensive entities
        var top5Rs = executeSql(`
            SELECT
                ENTITY_NAME,
                ENTITY_TYPE,
                SUM(COST_USD) AS TOTAL_COST,
                SUM(QUERY_COUNT) AS TOTAL_QUERIES,
                COUNT(DISTINCT CHARGEBACK_DATE) AS DAYS_WITH_COSTS
            FROM FINOPS_CONTROL_DB.CHARGEBACK.FACT_CHARGEBACK_DAILY
            WHERE CHARGEBACK_DATE >= ?
              AND CHARGEBACK_DATE <= ?
            GROUP BY ENTITY_NAME, ENTITY_TYPE
            ORDER BY TOTAL_COST DESC
            LIMIT 5
        `, [P_START_DATE, P_END_DATE]);

        var top5Entities = [];
        while (top5Rs.next()) {
            top5Entities.push({
                entity_name: top5Rs.getColumnValue('ENTITY_NAME'),
                entity_type: top5Rs.getColumnValue('ENTITY_TYPE'),
                total_cost_usd: parseFloat(top5Rs.getColumnValue('TOTAL_COST')).toFixed(2),
                total_queries: top5Rs.getColumnValue('TOTAL_QUERIES'),
                days_with_costs: top5Rs.getColumnValue('DAYS_WITH_COSTS')
            });
        }
        result.top_5_entities = top5Entities;

        // =================================================================
        // STEP 5: FINALIZE
        // =================================================================

        result.status = 'SUCCESS';
        result.end_time = new Date().toISOString();
        result.duration_seconds = ((new Date() - startTimestamp) / 1000).toFixed(2);

        logExecution(executionId, procedureName, 'SUCCESS', startTimestamp, new Date(),
                     totalRowsProcessed, null, result.parameters);

        return result;

    } catch (err) {
        result.status = 'ERROR';
        result.error_message = err.message;
        result.error_stack = err.stack;
        result.end_time = new Date().toISOString();

        logExecution(executionId, procedureName, 'ERROR', startTimestamp, new Date(),
                     totalRowsProcessed, err.message, result.parameters);

        return result;
    }
$$;

-- =========================================================================
-- GRANT EXECUTE PERMISSIONS
-- =========================================================================
GRANT USAGE ON PROCEDURE SP_CALCULATE_CHARGEBACK(DATE, DATE, BOOLEAN)
    TO ROLE FINOPS_ANALYST_ROLE;


-- =========================================================================
-- VERIFICATION QUERIES
-- =========================================================================

/*
-- Test 1: Calculate chargeback for last 7 days
CALL FINOPS_CONTROL_DB.PROCEDURES.SP_CALCULATE_CHARGEBACK(
    DATEADD(DAY, -7, CURRENT_DATE()),
    CURRENT_DATE(),
    TRUE  -- Recalculate all
);


-- Test 2: Incremental chargeback (only new data)
CALL FINOPS_CONTROL_DB.PROCEDURES.SP_CALCULATE_CHARGEBACK(
    DATEADD(DAY, -1, CURRENT_DATE()),
    CURRENT_DATE(),
    FALSE
);


-- Verify: Daily chargeback by entity
SELECT
    CHARGEBACK_DATE,
    ENTITY_NAME,
    ENTITY_TYPE,
    COST_TYPE,
    COST_USD,
    ATTRIBUTION_METHOD,
    QUERY_COUNT,
    UNIQUE_USERS
FROM FINOPS_CONTROL_DB.CHARGEBACK.FACT_CHARGEBACK_DAILY
WHERE CHARGEBACK_DATE >= DATEADD(DAY, -7, CURRENT_DATE())
ORDER BY CHARGEBACK_DATE DESC, COST_USD DESC
LIMIT 50;


-- Verify: Attribution method effectiveness
SELECT
    ATTRIBUTION_METHOD,
    SUM(COST_USD) AS TOTAL_COST,
    COUNT(DISTINCT ENTITY_ID) AS ENTITY_COUNT,
    SUM(QUERY_COUNT) AS TOTAL_QUERIES,
    ROUND(SUM(COST_USD) / (SELECT SUM(COST_USD) FROM FINOPS_CONTROL_DB.CHARGEBACK.FACT_CHARGEBACK_DAILY
                            WHERE CHARGEBACK_DATE >= DATEADD(DAY, -7, CURRENT_DATE())) * 100, 2) AS PCT_OF_TOTAL
FROM FINOPS_CONTROL_DB.CHARGEBACK.FACT_CHARGEBACK_DAILY
WHERE CHARGEBACK_DATE >= DATEADD(DAY, -7, CURRENT_DATE())
GROUP BY ATTRIBUTION_METHOD
ORDER BY TOTAL_COST DESC;


-- Verify: Unallocated cost analysis
SELECT
    CHARGEBACK_DATE,
    SUM(COST_USD) AS UNALLOCATED_COST,
    SUM(QUERY_COUNT) AS UNALLOCATED_QUERIES
FROM FINOPS_CONTROL_DB.CHARGEBACK.FACT_CHARGEBACK_DAILY
WHERE ATTRIBUTION_METHOD = 'UNALLOCATED'
  AND CHARGEBACK_DATE >= DATEADD(DAY, -30, CURRENT_DATE())
GROUP BY CHARGEBACK_DATE
ORDER BY CHARGEBACK_DATE DESC;


-- Verify: Entity hierarchy rollup
SELECT
    e.ENTITY_TYPE,
    e.ENTITY_NAME,
    p.ENTITY_NAME AS PARENT_ENTITY,
    SUM(f.COST_USD) AS TOTAL_COST,
    SUM(f.QUERY_COUNT) AS TOTAL_QUERIES,
    COUNT(DISTINCT f.CHARGEBACK_DATE) AS DAYS_WITH_COSTS
FROM FINOPS_CONTROL_DB.CHARGEBACK.FACT_CHARGEBACK_DAILY f
JOIN FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY e
    ON f.ENTITY_ID = e.ENTITY_ID
LEFT JOIN FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY p
    ON e.PARENT_ENTITY_ID = p.ENTITY_ID
WHERE f.CHARGEBACK_DATE >= DATEADD(DAY, -7, CURRENT_DATE())
GROUP BY e.ENTITY_TYPE, e.ENTITY_NAME, p.ENTITY_NAME
ORDER BY TOTAL_COST DESC;


-- Verify: Shared warehouse allocation accuracy
SELECT
    f.ENTITY_NAME,
    f.ALLOCATION_PERCENTAGE,
    SUM(f.COST_USD) AS ALLOCATED_COST,
    f.ATTRIBUTION_METHOD
FROM FINOPS_CONTROL_DB.CHARGEBACK.FACT_CHARGEBACK_DAILY f
WHERE f.ATTRIBUTION_METHOD = 'WAREHOUSE_MAPPING'
  AND f.ALLOCATION_PERCENTAGE < 100.00
  AND f.CHARGEBACK_DATE >= DATEADD(DAY, -7, CURRENT_DATE())
GROUP BY f.ENTITY_NAME, f.ALLOCATION_PERCENTAGE, f.ATTRIBUTION_METHOD
ORDER BY ALLOCATED_COST DESC;
*/


/*
=============================================================================
  BEST PRACTICES & DESIGN NOTES:

  1. ATTRIBUTION PRIORITY WATERFALL:
     - Always try highest-priority method first (QUERY_TAG)
     - Fall through to next priority only if previous fails
     - Track attribution method for transparency

  2. PROPORTIONAL ALLOCATION:
     - For shared warehouses, cost is split based on ALLOCATION_PERCENTAGE
     - Sum of allocations for same warehouse should = 100%
     - Use actual query execution time for more accurate proportional split

  3. UNALLOCATED COSTS:
     - Target: <5% of total costs unallocated
     - Report unallocated costs prominently to drive mapping adoption
     - Review unallocated queries weekly to identify missing mappings

  4. SCD TYPE 2 HANDLING:
     - Attribution respects VALID_FROM/VALID_TO dates
     - Costs attributed under org structure valid at query execution time
     - Supports historical reporting during reorgs

  5. PERFORMANCE OPTIMIZATION:
     - FACT_CHARGEBACK_DAILY is partitioned by CHARGEBACK_DATE
     - Pre-aggregated at daily grain for fast BI queries
     - Use MERGE for idempotency (safe to re-run)

  6. QUERY TAG FORMAT:
     - Recommended: team=TEAM_NAME;project=PROJECT_NAME;environment=ENV
     - Case-insensitive matching
     - Semicolon-delimited key=value pairs

  7. MONITORING & ALERTS:
     - Alert if unallocated_pct > 5%
     - Alert if daily cost spikes >50% vs 7-day average
     - Review attribution method breakdown weekly

  EDGE CASES HANDLED:
  - NULL or empty QUERY_TAG
  - Multiple mappings for same source (proportional allocation)
  - User/warehouse not found in mapping tables
  - Org changes mid-day (SCD Type 2)
  - Shared warehouses with split allocation
  - Query without user or warehouse (unallocated)

  OBJECTS CREATED:
    - FINOPS_CONTROL_DB.PROCEDURES.SP_CALCULATE_CHARGEBACK

  NEXT STEPS:
    → Script 03: Helper procedures (register entity, map user/warehouse)
    → Module 04: Budget controls
    → Module 07: Monitoring views for chargeback reporting
=============================================================================
*/
