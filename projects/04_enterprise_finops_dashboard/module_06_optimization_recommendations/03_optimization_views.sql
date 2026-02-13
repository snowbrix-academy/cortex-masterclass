/*
=============================================================================
  MODULE 06 : OPTIMIZATION RECOMMENDATIONS
  SCRIPT 03 : Optimization Analysis Views
=============================================================================
  SNOWBRIX ACADEMY — Enterprise FinOps Dashboard for Snowflake

  LEARNING OBJECTIVES:
    1. Create views for optimization dashboard
    2. Track implementation status and actual savings
    3. Calculate ROI for implemented recommendations

  PREREQUISITES:
    - Module 06, Scripts 01-02 completed

  ESTIMATED TIME: 10 minutes

=============================================================================
*/

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
