/*
=============================================================================
  MODULE 06 : OPTIMIZATION RECOMMENDATIONS
  SCRIPT 02 : Recommendation Generation Procedures
=============================================================================
  SNOWBRIX ACADEMY — Enterprise FinOps Dashboard for Snowflake

  LEARNING OBJECTIVES:
    1. Implement automated recommendation detection
    2. Calculate potential savings for each recommendation
    3. Prioritize recommendations by ROI
    4. Generate actionable optimization suggestions

  PREREQUISITES:
    - Module 06, Script 01 completed

  ESTIMATED TIME: 20 minutes

=============================================================================
*/

USE ROLE FINOPS_ADMIN_ROLE;
USE DATABASE FINOPS_CONTROL_DB;
USE SCHEMA PROCEDURES;
USE WAREHOUSE FINOPS_WH_ETL;

-- =========================================================================
-- PROCEDURE: SP_GENERATE_RECOMMENDATIONS
-- Generates optimization recommendations across all categories
-- =========================================================================
CREATE OR REPLACE PROCEDURE SP_GENERATE_RECOMMENDATIONS(
    P_LOOKBACK_DAYS NUMBER DEFAULT 7,
    P_MIN_SAVINGS_USD NUMBER DEFAULT 10.00
)
RETURNS VARIANT
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER
AS
$$
    function executeSql(sqlText, binds) {
        var stmt = snowflake.createStatement({sqlText: sqlText, binds: binds || []});
        return stmt.execute();
    }

    function executeScalar(sqlText, binds) {
        var rs = executeSql(sqlText, binds);
        return rs.next() ? rs.getColumnValue(1) : null;
    }

    var result = {
        procedure: 'SP_GENERATE_RECOMMENDATIONS',
        status: 'INITIALIZING',
        lookback_days: P_LOOKBACK_DAYS,
        min_savings_usd: P_MIN_SAVINGS_USD
    };

    try {
        var recommendationsCreated = 0;
        var cutoffDate = new Date();
        cutoffDate.setDate(cutoffDate.getDate() - P_LOOKBACK_DAYS);

        // ================================================================
        // CATEGORY 1: IDLE WAREHOUSES
        // ================================================================
        var idleWarehouseSql = `
        INSERT INTO FINOPS_CONTROL_DB.OPTIMIZATION.FACT_OPTIMIZATION_RECOMMENDATIONS (
            RULE_ID, CATEGORY, TARGET_OBJECT_TYPE, TARGET_OBJECT_NAME, ENTITY_ID,
            ISSUE_DESCRIPTION, CURRENT_STATE, RECOMMENDED_STATE,
            ESTIMATED_SAVINGS_USD_MONTHLY, CONFIDENCE_LEVEL, PRIORITY_SCORE, FEASIBILITY_SCORE, STATUS
        )
        SELECT
            r.RULE_ID,
            'IDLE_WAREHOUSE',
            'WAREHOUSE',
            wh_stats.WAREHOUSE_NAME,
            m.ENTITY_ID,
            CONCAT('Warehouse ', wh_stats.WAREHOUSE_NAME, ' has ', ROUND(wh_stats.IDLE_PCT, 1),
                   '% idle time over last ', ?, ' days'),
            CONCAT('Monthly cost: $', ROUND(wh_stats.TOTAL_COST, 2), ', Idle time: ', ROUND(wh_stats.IDLE_PCT, 1), '%'),
            'Reduce auto-suspend timeout or consolidate workloads to fewer warehouses',
            ROUND(wh_stats.TOTAL_COST * (wh_stats.IDLE_PCT / 100.0) * 0.6, 2) AS ESTIMATED_SAVINGS,
            CASE WHEN wh_stats.IDLE_PCT > 80 THEN 'HIGH' WHEN wh_stats.IDLE_PCT > 60 THEN 'MEDIUM' ELSE 'LOW' END,
            ROUND(wh_stats.TOTAL_COST * (wh_stats.IDLE_PCT / 100.0) * 0.6 * r.FEASIBILITY_SCORE, 2),
            r.FEASIBILITY_SCORE,
            'NEW'
        FROM (
            SELECT
                WAREHOUSE_NAME,
                SUM(COST_USD) AS TOTAL_COST,
                (SUM(CASE WHEN CREDITS_USED = 0 THEN DATEDIFF(SECOND, START_TIME, END_TIME) ELSE 0 END) * 100.0 /
                 NULLIF(SUM(DATEDIFF(SECOND, START_TIME, END_TIME)), 0)) AS IDLE_PCT
            FROM FINOPS_CONTROL_DB.COST_DATA.FACT_WAREHOUSE_COST_HISTORY
            WHERE USAGE_DATE >= DATEADD(DAY, -?, CURRENT_DATE())
            GROUP BY WAREHOUSE_NAME
            HAVING IDLE_PCT > 50 AND TOTAL_COST > ?
        ) wh_stats
        CROSS JOIN (SELECT * FROM FINOPS_CONTROL_DB.OPTIMIZATION.DIM_OPTIMIZATION_RULES
                    WHERE RULE_NAME = 'High Idle Time Warehouse') r
        LEFT JOIN FINOPS_CONTROL_DB.CHARGEBACK.DIM_COST_CENTER_MAPPING m
            ON m.SOURCE_TYPE = 'WAREHOUSE' AND m.SOURCE_VALUE = wh_stats.WAREHOUSE_NAME AND m.IS_CURRENT = TRUE
        WHERE NOT EXISTS (
            SELECT 1 FROM FINOPS_CONTROL_DB.OPTIMIZATION.FACT_OPTIMIZATION_RECOMMENDATIONS rec
            WHERE rec.TARGET_OBJECT_NAME = wh_stats.WAREHOUSE_NAME
              AND rec.CATEGORY = 'IDLE_WAREHOUSE'
              AND rec.STATUS IN ('NEW', 'IN_PROGRESS')
              AND rec.CREATED_AT >= DATEADD(DAY, -30, CURRENT_TIMESTAMP())
        )`;

        var idleStmt = snowflake.createStatement({
            sqlText: idleWarehouseSql,
            binds: [P_LOOKBACK_DAYS, P_LOOKBACK_DAYS, P_MIN_SAVINGS_USD]
        });
        var idleResult = idleStmt.execute();
        idleResult.next();
        var idleCount = idleResult.getColumnValue(1);
        recommendationsCreated += idleCount;

        // ================================================================
        // CATEGORY 2: EXPENSIVE QUERIES
        // ================================================================
        var expensiveQuerySql = `
        INSERT INTO FINOPS_CONTROL_DB.OPTIMIZATION.FACT_OPTIMIZATION_RECOMMENDATIONS (
            RULE_ID, CATEGORY, TARGET_OBJECT_TYPE, TARGET_OBJECT_NAME, ENTITY_ID,
            ISSUE_DESCRIPTION, CURRENT_STATE, RECOMMENDED_STATE,
            ESTIMATED_SAVINGS_USD_MONTHLY, CONFIDENCE_LEVEL, PRIORITY_SCORE, FEASIBILITY_SCORE, STATUS
        )
        SELECT
            r.RULE_ID,
            'QUERY_OPTIMIZATION',
            'QUERY',
            q.QUERY_ID,
            m.ENTITY_ID,
            CONCAT('Query executed ', q.EXECUTION_COUNT, ' times in last ', ?, ' days, costing $',
                   ROUND(q.TOTAL_COST, 2)),
            CONCAT('Avg execution time: ', ROUND(q.AVG_EXECUTION_TIME_MS / 1000.0, 1), 's, ',
                   'Avg bytes scanned: ', ROUND(q.AVG_BYTES_SCANNED / 1099511627776.0, 2), ' TB'),
            'Optimize query: add filters, use incremental models, or add clustering keys',
            ROUND(q.TOTAL_COST * 0.30, 2) AS ESTIMATED_SAVINGS,
            'MEDIUM',
            ROUND(q.TOTAL_COST * 0.30 * r.FEASIBILITY_SCORE, 2),
            r.FEASIBILITY_SCORE,
            'NEW'
        FROM (
            SELECT
                QUERY_ID,
                USER_NAME,
                COUNT(*) AS EXECUTION_COUNT,
                SUM(TOTAL_COST_USD) AS TOTAL_COST,
                AVG(EXECUTION_TIME_MS) AS AVG_EXECUTION_TIME_MS,
                AVG(BYTES_SCANNED) AS AVG_BYTES_SCANNED
            FROM FINOPS_CONTROL_DB.COST_DATA.FACT_QUERY_COST_HISTORY
            WHERE QUERY_DATE >= DATEADD(DAY, -?, CURRENT_DATE())
            GROUP BY QUERY_ID, USER_NAME
            HAVING TOTAL_COST > ? AND AVG_EXECUTION_TIME_MS > 60000
        ) q
        CROSS JOIN (SELECT * FROM FINOPS_CONTROL_DB.OPTIMIZATION.DIM_OPTIMIZATION_RULES
                    WHERE RULE_NAME = 'Expensive Query Without Clustering') r
        LEFT JOIN FINOPS_CONTROL_DB.CHARGEBACK.DIM_COST_CENTER_MAPPING m
            ON m.SOURCE_TYPE = 'USER' AND m.SOURCE_VALUE = q.USER_NAME AND m.IS_CURRENT = TRUE
        WHERE NOT EXISTS (
            SELECT 1 FROM FINOPS_CONTROL_DB.OPTIMIZATION.FACT_OPTIMIZATION_RECOMMENDATIONS rec
            WHERE rec.TARGET_OBJECT_NAME = q.QUERY_ID
              AND rec.CATEGORY = 'QUERY_OPTIMIZATION'
              AND rec.STATUS IN ('NEW', 'IN_PROGRESS')
        )
        LIMIT 20`;

        var queryStmt = snowflake.createStatement({
            sqlText: expensiveQuerySql,
            binds: [P_LOOKBACK_DAYS, P_LOOKBACK_DAYS, P_MIN_SAVINGS_USD]
        });
        var queryResult = queryStmt.execute();
        queryResult.next();
        var queryCount = queryResult.getColumnValue(1);
        recommendationsCreated += queryCount;

        // ================================================================
        // CATEGORY 3: STORAGE WASTE
        // ================================================================
        var storageWasteSql = `
        INSERT INTO FINOPS_CONTROL_DB.OPTIMIZATION.FACT_OPTIMIZATION_RECOMMENDATIONS (
            RULE_ID, CATEGORY, TARGET_OBJECT_TYPE, TARGET_OBJECT_NAME,
            ISSUE_DESCRIPTION, CURRENT_STATE, RECOMMENDED_STATE,
            ESTIMATED_SAVINGS_USD_MONTHLY, CONFIDENCE_LEVEL, PRIORITY_SCORE, FEASIBILITY_SCORE, STATUS
        )
        SELECT
            r.RULE_ID,
            'STORAGE_WASTE',
            'TABLE',
            CONCAT(s.TABLE_SCHEMA, '.', s.TABLE_NAME),
            CONCAT('Table not queried in 90+ days, storage: ', ROUND(s.STORAGE_TB, 2), ' TB'),
            CONCAT('Monthly storage cost: $', ROUND(s.MONTHLY_STORAGE_COST, 2)),
            'Archive to lower-cost storage or drop if no longer needed',
            ROUND(s.MONTHLY_STORAGE_COST * 0.80, 2) AS ESTIMATED_SAVINGS,
            'HIGH',
            ROUND(s.MONTHLY_STORAGE_COST * 0.80 * r.FEASIBILITY_SCORE, 2),
            r.FEASIBILITY_SCORE,
            'NEW'
        FROM (
            SELECT
                s.TABLE_SCHEMA,
                s.TABLE_NAME,
                (s.ACTIVE_BYTES + s.TIME_TRAVEL_BYTES) / 1099511627776.0 AS STORAGE_TB,
                ((s.ACTIVE_BYTES + s.TIME_TRAVEL_BYTES) / 1099511627776.0) * 23 AS MONTHLY_STORAGE_COST,
                s.USAGE_DATE
            FROM FINOPS_CONTROL_DB.COST_DATA.FACT_STORAGE_COST_HISTORY s
            WHERE s.USAGE_DATE = (SELECT MAX(USAGE_DATE) FROM FINOPS_CONTROL_DB.COST_DATA.FACT_STORAGE_COST_HISTORY)
              AND (s.ACTIVE_BYTES + s.TIME_TRAVEL_BYTES) > 1099511627776  -- >1TB
              AND NOT EXISTS (
                  SELECT 1 FROM FINOPS_CONTROL_DB.COST_DATA.FACT_QUERY_COST_HISTORY q
                  WHERE q.QUERY_DATE >= DATEADD(DAY, -90, CURRENT_DATE())
                    AND (UPPER(q.QUERY_TEXT) LIKE '%' || UPPER(s.TABLE_NAME) || '%')
              )
        ) s
        CROSS JOIN (SELECT * FROM FINOPS_CONTROL_DB.OPTIMIZATION.DIM_OPTIMIZATION_RULES
                    WHERE RULE_NAME = 'Unused Table with High Storage Cost') r
        WHERE NOT EXISTS (
            SELECT 1 FROM FINOPS_CONTROL_DB.OPTIMIZATION.FACT_OPTIMIZATION_RECOMMENDATIONS rec
            WHERE rec.TARGET_OBJECT_NAME = CONCAT(s.TABLE_SCHEMA, '.', s.TABLE_NAME)
              AND rec.CATEGORY = 'STORAGE_WASTE'
              AND rec.STATUS IN ('NEW', 'IN_PROGRESS')
        )
        LIMIT 10`;

        var storageStmt = snowflake.createStatement({sqlText: storageWasteSql});
        var storageResult = storageStmt.execute();
        storageResult.next();
        var storageCount = storageResult.getColumnValue(1);
        recommendationsCreated += storageCount;

        // ================================================================
        // CALCULATE SUMMARY
        // ================================================================
        var summarySql = `
        SELECT
            COUNT(*) AS TOTAL_RECOMMENDATIONS,
            SUM(ESTIMATED_SAVINGS_USD_MONTHLY) AS TOTAL_ESTIMATED_SAVINGS,
            AVG(PRIORITY_SCORE) AS AVG_PRIORITY_SCORE
        FROM FINOPS_CONTROL_DB.OPTIMIZATION.FACT_OPTIMIZATION_RECOMMENDATIONS
        WHERE STATUS = 'NEW'
          AND CREATED_AT >= ?`;

        var summaryRs = executeSql(summarySql, [cutoffDate.toISOString().substring(0, 19).replace('T', ' ')]);
        if (summaryRs.next()) {
            result.summary = {
                total_new_recommendations: summaryRs.getColumnValue('TOTAL_RECOMMENDATIONS'),
                total_estimated_savings: summaryRs.getColumnValue('TOTAL_ESTIMATED_SAVINGS'),
                avg_priority_score: summaryRs.getColumnValue('AVG_PRIORITY_SCORE')
            };
        }

        result.recommendations_by_category = {
            idle_warehouses: idleCount,
            expensive_queries: queryCount,
            storage_waste: storageCount
        };

        result.status = 'SUCCESS';
        return result;

    } catch (err) {
        result.status = 'ERROR';
        result.error_message = err.message;
        return result;
    }
$$;


-- =========================================================================
-- GRANT PERMISSIONS
-- =========================================================================
GRANT USAGE ON PROCEDURE SP_GENERATE_RECOMMENDATIONS(NUMBER, NUMBER) TO ROLE FINOPS_ANALYST_ROLE;


-- =========================================================================
-- VERIFICATION QUERIES
-- =========================================================================

/*
-- Test: Generate recommendations
CALL SP_GENERATE_RECOMMENDATIONS(7, 10.00);

-- Verify: Recent recommendations
SELECT
    RECOMMENDATION_ID,
    CATEGORY,
    TARGET_OBJECT_TYPE,
    TARGET_OBJECT_NAME,
    ISSUE_DESCRIPTION,
    ESTIMATED_SAVINGS_USD_MONTHLY,
    PRIORITY_SCORE,
    STATUS,
    CREATED_AT
FROM FINOPS_CONTROL_DB.OPTIMIZATION.FACT_OPTIMIZATION_RECOMMENDATIONS
WHERE STATUS = 'NEW'
ORDER BY PRIORITY_SCORE DESC
LIMIT 20;

-- Verify: Savings summary by category
SELECT
    CATEGORY,
    COUNT(*) AS RECOMMENDATION_COUNT,
    SUM(ESTIMATED_SAVINGS_USD_MONTHLY) AS TOTAL_ESTIMATED_SAVINGS,
    AVG(PRIORITY_SCORE) AS AVG_PRIORITY
FROM FINOPS_CONTROL_DB.OPTIMIZATION.FACT_OPTIMIZATION_RECOMMENDATIONS
WHERE STATUS IN ('NEW', 'IN_PROGRESS')
GROUP BY CATEGORY
ORDER BY TOTAL_ESTIMATED_SAVINGS DESC;
*/

/*
=============================================================================
  OBJECTS CREATED:
    - SP_GENERATE_RECOMMENDATIONS

  NEXT STEPS:
    → Script 03: Optimization analysis views
=============================================================================
*/
