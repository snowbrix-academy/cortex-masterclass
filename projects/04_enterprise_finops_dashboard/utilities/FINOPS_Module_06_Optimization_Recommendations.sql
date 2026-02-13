/*
#############################################################################
  FINOPS - Module 06: Optimization Recommendations
  CONSOLIDATED WORKSHEET — Snowsight / VS Code Ready
#############################################################################
  SNOWBRIX ACADEMY — Enterprise FinOps Dashboard for Snowflake

  This worksheet contains:
    - 01_optimization_tables.sql
    - 02_optimization_procedures.sql
    - 03_optimization_views.sql
    

  INSTRUCTIONS:
    - Run each section sequentially (top to bottom)
    - Requires Module 05 to be completed first (if applicable)
    - Estimated time: ~30 minutes

  PREREQUISITES:
    - Module 02 completed
    - FINOPS_ADMIN_ROLE access
#############################################################################
*/


USE ROLE FINOPS_ADMIN_ROLE;
USE DATABASE FINOPS_CONTROL_DB;
USE SCHEMA OPTIMIZATION;
USE WAREHOUSE FINOPS_WH_ADMIN;

-- =========================================================================
-- DIMENSION: DIM_OPTIMIZATION_RULES
-- Pre-defined optimization detection rules
-- =========================================================================
CREATE TABLE IF NOT EXISTS DIM_OPTIMIZATION_RULES (
    RULE_ID                     NUMBER AUTOINCREMENT PRIMARY KEY,
    RULE_NAME                   VARCHAR(200) NOT NULL,
    CATEGORY                    VARCHAR(50) NOT NULL,
    DESCRIPTION                 VARCHAR(1000),

    -- Detection Logic
    DETECTION_SQL               VARCHAR(10000) COMMENT 'SQL query to detect issues',

    -- Recommendation Template
    RECOMMENDATION_TEMPLATE     VARCHAR(2000) COMMENT 'Template for recommendation text',

    -- Savings Calculation
    SAVINGS_FORMULA             VARCHAR(1000) COMMENT 'Formula to estimate savings',
    TYPICAL_SAVINGS_PCT         NUMBER(5, 2) COMMENT 'Typical % savings if implemented',

    -- Implementation Difficulty
    FEASIBILITY_SCORE           NUMBER(3, 1) COMMENT '1-10 scale, 10=easiest',
    EFFORT_ESTIMATE_HOURS       NUMBER COMMENT 'Estimated implementation effort',

    -- Status
    IS_ACTIVE                   BOOLEAN DEFAULT TRUE,
    PRIORITY                    NUMBER DEFAULT 100 COMMENT 'Lower = higher priority',
    CREATED_AT                  TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),

    CONSTRAINT chk_opt_category CHECK (
        CATEGORY IN ('IDLE_WAREHOUSE', 'AUTO_SUSPEND', 'WAREHOUSE_SIZING',
                     'QUERY_OPTIMIZATION', 'STORAGE_WASTE', 'CLUSTERING', 'MULTI_CLUSTER')
    ),
    CONSTRAINT chk_feasibility CHECK (FEASIBILITY_SCORE BETWEEN 1 AND 10)
)
COMMENT = 'Dimension: Optimization rules with detection logic and savings formulas';


-- =========================================================================
-- FACT TABLE: FACT_OPTIMIZATION_RECOMMENDATIONS
-- Active optimization recommendations with savings estimates
-- =========================================================================
CREATE TABLE IF NOT EXISTS FACT_OPTIMIZATION_RECOMMENDATIONS (
    RECOMMENDATION_ID           NUMBER AUTOINCREMENT PRIMARY KEY,
    RULE_ID                     NUMBER COMMENT 'FK to DIM_OPTIMIZATION_RULES',
    CATEGORY                    VARCHAR(50) NOT NULL,

    -- Target Object
    TARGET_OBJECT_TYPE          VARCHAR(50) COMMENT 'WAREHOUSE, QUERY, TABLE, DATABASE',
    TARGET_OBJECT_NAME          VARCHAR(500),
    ENTITY_ID                   NUMBER COMMENT 'FK to DIM_CHARGEBACK_ENTITY (owning team)',

    -- Issue Description
    ISSUE_DESCRIPTION           VARCHAR(2000),
    CURRENT_STATE               VARCHAR(1000) COMMENT 'Current configuration/behavior',
    RECOMMENDED_STATE           VARCHAR(1000) COMMENT 'Recommended configuration/behavior',

    -- Savings Estimate
    ESTIMATED_SAVINGS_USD_MONTHLY NUMBER(18, 2) COMMENT 'Estimated monthly savings',
    CONFIDENCE_LEVEL            VARCHAR(20) DEFAULT 'MEDIUM' COMMENT 'LOW, MEDIUM, HIGH',

    -- Prioritization
    PRIORITY_SCORE              NUMBER(10, 2) COMMENT 'savings × feasibility × confidence',
    FEASIBILITY_SCORE           NUMBER(3, 1),

    -- Implementation Status
    STATUS                      VARCHAR(20) DEFAULT 'NEW',
    CREATED_AT                  TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    IMPLEMENTED_AT              TIMESTAMP_NTZ,
    IMPLEMENTED_BY              VARCHAR(200),

    -- Validation
    ACTUAL_SAVINGS_USD_MONTHLY  NUMBER(18, 2) COMMENT 'Actual savings after implementation',
    VALIDATION_DATE             DATE,

    CONSTRAINT chk_rec_status CHECK (
        STATUS IN ('NEW', 'IN_PROGRESS', 'IMPLEMENTED', 'REJECTED', 'EXPIRED')
    ),
    CONSTRAINT chk_confidence CHECK (
        CONFIDENCE_LEVEL IN ('LOW', 'MEDIUM', 'HIGH')
    ),
    CONSTRAINT fk_rec_rule FOREIGN KEY (RULE_ID) REFERENCES DIM_OPTIMIZATION_RULES(RULE_ID)
)
COMMENT = 'Fact: Optimization recommendations with savings estimates and implementation tracking';

CREATE INDEX IF NOT EXISTS idx_rec_status ON FACT_OPTIMIZATION_RECOMMENDATIONS(STATUS, PRIORITY_SCORE DESC);
CREATE INDEX IF NOT EXISTS idx_rec_entity ON FACT_OPTIMIZATION_RECOMMENDATIONS(ENTITY_ID, STATUS);


-- =========================================================================
-- POPULATE OPTIMIZATION RULES
-- =========================================================================

INSERT INTO DIM_OPTIMIZATION_RULES (
    RULE_NAME, CATEGORY, DESCRIPTION, TYPICAL_SAVINGS_PCT,
    FEASIBILITY_SCORE, EFFORT_ESTIMATE_HOURS, PRIORITY
) VALUES
    -- Idle Warehouse Rules
    ('High Idle Time Warehouse', 'IDLE_WAREHOUSE',
     'Warehouse with >60% idle time in last 7 days',
     40.0, 9.0, 1, 10),

    ('Excessive Auto-Suspend Timeout', 'AUTO_SUSPEND',
     'Warehouse auto-suspend timeout >10 minutes with infrequent queries',
     15.0, 10.0, 0.25, 20),

    -- Warehouse Sizing Rules
    ('Over-Provisioned Warehouse', 'WAREHOUSE_SIZING',
     'Warehouse with consistently low queue time and <50% credit utilization',
     30.0, 8.0, 1, 30),

    ('Under-Provisioned Warehouse', 'WAREHOUSE_SIZING',
     'Warehouse with frequent queuing and >90% credit utilization',
     NULL, 7.0, 2, 40),

    -- Query Optimization Rules
    ('Expensive Query Without Clustering', 'QUERY_OPTIMIZATION',
     'High-cost query scanning >100GB without clustering key',
     25.0, 5.0, 8, 50),

    ('Query with Excessive Spilling', 'QUERY_OPTIMIZATION',
     'Query spilling to disk (>1GB spilled bytes)',
     20.0, 6.0, 4, 60),

    ('Inefficient SELECT * Query', 'QUERY_OPTIMIZATION',
     'Expensive query using SELECT * on wide tables',
     15.0, 9.0, 2, 70),

    -- Storage Optimization Rules
    ('Unused Table with High Storage Cost', 'STORAGE_WASTE',
     'Table not queried in 90+ days with >1TB storage',
     80.0, 10.0, 0.5, 15),

    ('Excessive Time-Travel Retention', 'STORAGE_WASTE',
     'Database with time-travel >7 days for non-prod data',
     10.0, 10.0, 0.25, 80),

    -- Clustering Rules
    ('High Reclustering Cost', 'CLUSTERING',
     'Table with automatic clustering consuming >$500/month',
     50.0, 6.0, 4, 90),

    ('Missing Clustering Key', 'CLUSTERING',
     'Large table (>1TB) frequently filtered without clustering key',
     30.0, 5.0, 6, 100);


-- =========================================================================
-- VERIFICATION QUERIES
-- =========================================================================

/*
-- Verify: Optimization rules
SELECT
    RULE_ID,
    RULE_NAME,
    CATEGORY,
    TYPICAL_SAVINGS_PCT,
    FEASIBILITY_SCORE,
    EFFORT_ESTIMATE_HOURS,
    PRIORITY,
    IS_ACTIVE
FROM DIM_OPTIMIZATION_RULES
WHERE IS_ACTIVE = TRUE
ORDER BY PRIORITY;


-- Verify: Rule distribution by category
SELECT
    CATEGORY,
    COUNT(*) AS RULE_COUNT,
    AVG(TYPICAL_SAVINGS_PCT) AS AVG_SAVINGS_PCT,
    AVG(FEASIBILITY_SCORE) AS AVG_FEASIBILITY
FROM DIM_OPTIMIZATION_RULES
WHERE IS_ACTIVE = TRUE
GROUP BY CATEGORY
ORDER BY CATEGORY;
*/

/*
=============================================================================
  OBJECTS CREATED:
    - DIM_OPTIMIZATION_RULES
    - FACT_OPTIMIZATION_RECOMMENDATIONS

  NEXT STEPS:
    → Script 02: SP_GENERATE_RECOMMENDATIONS (detection procedures)
    → Script 03: Optimization analysis views
=============================================================================
*/

-- ===========================================================================
-- ===========================================================================
-- 02_OPTIMIZATION_PROCEDURES
-- ===========================================================================
-- ===========================================================================


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

-- ===========================================================================
-- ===========================================================================
-- 03_OPTIMIZATION_VIEWS
-- ===========================================================================
-- ===========================================================================


USE ROLE FINOPS_ADMIN_ROLE;
USE DATABASE FINOPS_CONTROL_DB;
USE SCHEMA MONITORING;
USE WAREHOUSE FINOPS_WH_ADMIN;

-- =========================================================================
-- VIEW: VW_OPTIMIZATION_SUMMARY
-- Summary of all recommendations by category
-- =========================================================================
CREATE OR REPLACE VIEW VW_OPTIMIZATION_SUMMARY AS
SELECT
    r.CATEGORY,
    COUNT(*) AS RECOMMENDATION_COUNT,
    SUM(r.ESTIMATED_SAVINGS_USD_MONTHLY) AS TOTAL_ESTIMATED_SAVINGS,
    AVG(r.PRIORITY_SCORE) AS AVG_PRIORITY_SCORE,
    AVG(r.FEASIBILITY_SCORE) AS AVG_FEASIBILITY_SCORE,
    COUNT(CASE WHEN r.STATUS = 'NEW' THEN 1 END) AS NEW_COUNT,
    COUNT(CASE WHEN r.STATUS = 'IN_PROGRESS' THEN 1 END) AS IN_PROGRESS_COUNT,
    COUNT(CASE WHEN r.STATUS = 'IMPLEMENTED' THEN 1 END) AS IMPLEMENTED_COUNT,
    SUM(CASE WHEN r.STATUS = 'IMPLEMENTED' THEN r.ACTUAL_SAVINGS_USD_MONTHLY ELSE 0 END) AS ACTUAL_SAVINGS_REALIZED
FROM FINOPS_CONTROL_DB.OPTIMIZATION.FACT_OPTIMIZATION_RECOMMENDATIONS r
WHERE r.STATUS IN ('NEW', 'IN_PROGRESS', 'IMPLEMENTED')
  AND r.CREATED_AT >= DATEADD(DAY, -90, CURRENT_TIMESTAMP())
GROUP BY r.CATEGORY
ORDER BY TOTAL_ESTIMATED_SAVINGS DESC;

COMMENT ON VIEW VW_OPTIMIZATION_SUMMARY IS 'Summary of optimization recommendations by category';


-- =========================================================================
-- VIEW: VW_TOP_OPTIMIZATION_OPPORTUNITIES
-- Top 50 recommendations by potential savings
-- =========================================================================
CREATE OR REPLACE VIEW VW_TOP_OPTIMIZATION_OPPORTUNITIES AS
SELECT
    r.RECOMMENDATION_ID,
    r.CATEGORY,
    r.TARGET_OBJECT_TYPE,
    r.TARGET_OBJECT_NAME,
    e.ENTITY_NAME AS OWNING_ENTITY,
    r.ISSUE_DESCRIPTION,
    r.RECOMMENDED_STATE,
    r.ESTIMATED_SAVINGS_USD_MONTHLY,
    r.CONFIDENCE_LEVEL,
    r.PRIORITY_SCORE,
    r.FEASIBILITY_SCORE,
    r.STATUS,
    r.CREATED_AT,
    DATEDIFF(DAY, r.CREATED_AT, CURRENT_TIMESTAMP()) AS DAYS_OPEN
FROM FINOPS_CONTROL_DB.OPTIMIZATION.FACT_OPTIMIZATION_RECOMMENDATIONS r
LEFT JOIN FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY e
    ON r.ENTITY_ID = e.ENTITY_ID
WHERE r.STATUS IN ('NEW', 'IN_PROGRESS')
ORDER BY r.PRIORITY_SCORE DESC
LIMIT 50;

COMMENT ON VIEW VW_TOP_OPTIMIZATION_OPPORTUNITIES IS 'Top 50 optimization opportunities by priority';


-- =========================================================================
-- VIEW: VW_IMPLEMENTED_SAVINGS
-- Track actual savings from implemented recommendations
-- =========================================================================
CREATE OR REPLACE VIEW VW_IMPLEMENTED_SAVINGS AS
SELECT
    r.RECOMMENDATION_ID,
    r.CATEGORY,
    r.TARGET_OBJECT_TYPE,
    r.TARGET_OBJECT_NAME,
    e.ENTITY_NAME,
    r.ESTIMATED_SAVINGS_USD_MONTHLY,
    r.ACTUAL_SAVINGS_USD_MONTHLY,
    ROUND((r.ACTUAL_SAVINGS_USD_MONTHLY / NULLIF(r.ESTIMATED_SAVINGS_USD_MONTHLY, 0)) * 100, 1) AS SAVINGS_ACCURACY_PCT,
    r.IMPLEMENTED_AT,
    r.IMPLEMENTED_BY,
    r.VALIDATION_DATE,
    DATEDIFF(DAY, r.CREATED_AT, r.IMPLEMENTED_AT) AS DAYS_TO_IMPLEMENT
FROM FINOPS_CONTROL_DB.OPTIMIZATION.FACT_OPTIMIZATION_RECOMMENDATIONS r
LEFT JOIN FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY e
    ON r.ENTITY_ID = e.ENTITY_ID
WHERE r.STATUS = 'IMPLEMENTED'
  AND r.IMPLEMENTED_AT >= DATEADD(DAY, -180, CURRENT_TIMESTAMP())
ORDER BY r.IMPLEMENTED_AT DESC;

COMMENT ON VIEW VW_IMPLEMENTED_SAVINGS IS 'Tracking of implemented recommendations and actual savings';


-- =========================================================================
-- GRANT PERMISSIONS
-- =========================================================================
GRANT SELECT ON VIEW VW_OPTIMIZATION_SUMMARY TO ROLE FINOPS_ANALYST_ROLE;
GRANT SELECT ON VIEW VW_TOP_OPTIMIZATION_OPPORTUNITIES TO ROLE FINOPS_ANALYST_ROLE;
GRANT SELECT ON VIEW VW_IMPLEMENTED_SAVINGS TO ROLE FINOPS_ANALYST_ROLE;


-- =========================================================================
-- VERIFICATION QUERIES
-- =========================================================================

/*
-- Verify: Optimization summary
SELECT * FROM VW_OPTIMIZATION_SUMMARY;

-- Verify: Top opportunities
SELECT * FROM VW_TOP_OPTIMIZATION_OPPORTUNITIES LIMIT 10;

-- Verify: Implemented savings
SELECT * FROM VW_IMPLEMENTED_SAVINGS LIMIT 10;
*/

/*
=============================================================================
  OBJECTS CREATED:
    - VW_OPTIMIZATION_SUMMARY
    - VW_TOP_OPTIMIZATION_OPPORTUNITIES
    - VW_IMPLEMENTED_SAVINGS

  NEXT STEPS:
    → Module 07: Monitoring Views (comprehensive reporting layer)
=============================================================================
*/



/*
#############################################################################
  MODULE 06 COMPLETE!

  Objects Created:
    - Tables: OPTIMIZATION_RECOMMENDATIONS, IDLE_WAREHOUSE_LOG, EXPENSIVE_QUERY_LOG
    - Procedures: SP_GENERATE_RECOMMENDATIONS, SP_ANALYZE_IDLE_WAREHOUSES, SP_IDENTIFY_EXPENSIVE_QUERIES
    - Views: VW_OPTIMIZATION_DASHBOARD, VW_COST_SAVING_OPPORTUNITIES

  Next: FINOPS - Module 07 (Monitoring Views)
#############################################################################
*/
