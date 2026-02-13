/*
=============================================================================
  MODULE 07 : MONITORING VIEWS
  SCRIPT 02 : Warehouse and Query Analytics Views
=============================================================================
  SNOWBRIX ACADEMY — Enterprise FinOps Dashboard for Snowflake

  LEARNING OBJECTIVES:
    1. Create warehouse utilization and cost views
    2. Build query cost analysis views
    3. Identify optimization candidates

  PREREQUISITES:
    - Module 07, Script 01 completed

  ESTIMATED TIME: 10 minutes

=============================================================================
*/

USE ROLE FINOPS_ADMIN_ROLE;
USE DATABASE FINOPS_CONTROL_DB;
USE SCHEMA MONITORING;
USE WAREHOUSE FINOPS_WH_ADMIN;

-- =========================================================================
-- VIEW: VW_WAREHOUSE_ANALYTICS
-- Comprehensive warehouse cost and utilization metrics
-- =========================================================================
CREATE OR REPLACE VIEW VW_WAREHOUSE_ANALYTICS AS
WITH warehouse_costs AS (
    SELECT
        WAREHOUSE_NAME,
        SUM(CASE WHEN USAGE_DATE >= DATEADD(DAY, -7, CURRENT_DATE())
                 THEN COST_USD ELSE 0 END) AS COST_7D,
        SUM(CASE WHEN USAGE_DATE >= DATEADD(DAY, -30, CURRENT_DATE())
                 THEN COST_USD ELSE 0 END) AS COST_30D,
        SUM(CASE WHEN USAGE_DATE >= DATE_TRUNC('MONTH', CURRENT_DATE())
                 THEN COST_USD ELSE 0 END) AS COST_MTD,
        AVG(CREDITS_USED) AS AVG_CREDITS_PER_INTERVAL
    FROM FINOPS_CONTROL_DB.COST_DATA.FACT_WAREHOUSE_COST_HISTORY
    WHERE USAGE_DATE >= DATEADD(DAY, -30, CURRENT_DATE())
    GROUP BY WAREHOUSE_NAME
),
warehouse_queries AS (
    SELECT
        WAREHOUSE_NAME,
        COUNT(*) AS QUERY_COUNT_30D,
        COUNT(DISTINCT USER_NAME) AS UNIQUE_USERS,
        AVG(TOTAL_COST_USD) AS AVG_QUERY_COST
    FROM FINOPS_CONTROL_DB.COST_DATA.FACT_QUERY_COST_HISTORY
    WHERE QUERY_DATE >= DATEADD(DAY, -30, CURRENT_DATE())
    GROUP BY WAREHOUSE_NAME
)
SELECT
    wc.WAREHOUSE_NAME,
    m.ENTITY_ID,
    e.ENTITY_NAME,
    wc.COST_MTD,
    wc.COST_7D,
    wc.COST_30D,
    ROUND((wc.COST_7D - LAG(wc.COST_7D) OVER (PARTITION BY wc.WAREHOUSE_NAME ORDER BY CURRENT_DATE())) /
          NULLIF(LAG(wc.COST_7D) OVER (PARTITION BY wc.WAREHOUSE_NAME ORDER BY CURRENT_DATE()), 0) * 100, 2) AS TREND_7D_PCT,
    wq.QUERY_COUNT_30D,
    wq.UNIQUE_USERS,
    wq.AVG_QUERY_COST,
    ROUND(wc.COST_30D / NULLIF(wq.QUERY_COUNT_30D, 0), 4) AS COST_PER_QUERY
FROM warehouse_costs wc
LEFT JOIN warehouse_queries wq ON wc.WAREHOUSE_NAME = wq.WAREHOUSE_NAME
LEFT JOIN FINOPS_CONTROL_DB.CHARGEBACK.DIM_COST_CENTER_MAPPING m
    ON m.SOURCE_TYPE = 'WAREHOUSE'
    AND m.SOURCE_VALUE = wc.WAREHOUSE_NAME
    AND m.IS_CURRENT = TRUE
LEFT JOIN FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY e
    ON m.ENTITY_ID = e.ENTITY_ID
ORDER BY wc.COST_30D DESC;

COMMENT ON VIEW VW_WAREHOUSE_ANALYTICS IS 'Warehouse cost and utilization metrics with trends';


-- =========================================================================
-- VIEW: VW_QUERY_COST_ANALYSIS
-- Top expensive queries with optimization potential
-- =========================================================================
CREATE OR REPLACE VIEW VW_QUERY_COST_ANALYSIS AS
SELECT
    q.QUERY_ID,
    q.QUERY_DATE,
    q.USER_NAME,
    q.WAREHOUSE_NAME,
    e.ENTITY_NAME,
    q.TOTAL_COST_USD,
    q.EXECUTION_TIME_MS,
    ROUND(q.EXECUTION_TIME_MS / 1000.0, 2) AS EXECUTION_TIME_SEC,
    ROUND(q.BYTES_SCANNED / 1099511627776.0, 2) AS TB_SCANNED,
    q.QUERY_TYPE,

    -- Cost efficiency metrics
    ROUND(q.TOTAL_COST_USD / (q.EXECUTION_TIME_MS / 1000.0), 6) AS COST_PER_SECOND,
    ROUND(q.BYTES_SCANNED / NULLIF(q.EXECUTION_TIME_MS, 0), 2) AS BYTES_PER_MS,

    -- Optimization flags
    CASE WHEN q.EXECUTION_TIME_MS > 300000 THEN TRUE ELSE FALSE END AS IS_LONG_RUNNING,
    CASE WHEN q.BYTES_SCANNED > 1099511627776 THEN TRUE ELSE FALSE END AS IS_LARGE_SCAN,
    CASE WHEN q.TOTAL_COST_USD > 10 THEN TRUE ELSE FALSE END AS IS_HIGH_COST,

    LEFT(q.QUERY_TEXT, 500) AS QUERY_TEXT_PREVIEW

FROM FINOPS_CONTROL_DB.COST_DATA.FACT_QUERY_COST_HISTORY q
LEFT JOIN FINOPS_CONTROL_DB.CHARGEBACK.DIM_COST_CENTER_MAPPING m
    ON m.SOURCE_TYPE = 'USER'
    AND UPPER(m.SOURCE_VALUE) = UPPER(q.USER_NAME)
    AND m.IS_CURRENT = TRUE
LEFT JOIN FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY e
    ON m.ENTITY_ID = e.ENTITY_ID
WHERE q.QUERY_DATE >= DATEADD(DAY, -30, CURRENT_DATE())
  AND q.TOTAL_COST_USD > 0.10
ORDER BY q.TOTAL_COST_USD DESC
LIMIT 1000;

COMMENT ON VIEW VW_QUERY_COST_ANALYSIS IS 'Top 1000 expensive queries with optimization flags';


-- =========================================================================
-- VIEW: VW_WAREHOUSE_UTILIZATION_TREND
-- Daily warehouse utilization trends
-- =========================================================================
CREATE OR REPLACE VIEW VW_WAREHOUSE_UTILIZATION_TREND AS
SELECT
    WAREHOUSE_NAME,
    USAGE_DATE,
    SUM(COST_USD) AS DAILY_COST,
    SUM(CREDITS_USED) AS DAILY_CREDITS,
    COUNT(*) AS INTERVALS_ACTIVE,
    -- Estimate idle percentage (intervals with 0 credits)
    ROUND((COUNT(CASE WHEN CREDITS_USED = 0 THEN 1 END) * 100.0 / COUNT(*)), 2) AS IDLE_PCT
FROM FINOPS_CONTROL_DB.COST_DATA.FACT_WAREHOUSE_COST_HISTORY
WHERE USAGE_DATE >= DATEADD(DAY, -30, CURRENT_DATE())
GROUP BY WAREHOUSE_NAME, USAGE_DATE
ORDER BY USAGE_DATE DESC, DAILY_COST DESC;

COMMENT ON VIEW VW_WAREHOUSE_UTILIZATION_TREND IS 'Daily warehouse utilization with idle percentage';


-- =========================================================================
-- GRANT PERMISSIONS
-- =========================================================================
GRANT SELECT ON VIEW VW_WAREHOUSE_ANALYTICS TO ROLE FINOPS_ANALYST_ROLE;
GRANT SELECT ON VIEW VW_QUERY_COST_ANALYSIS TO ROLE FINOPS_ANALYST_ROLE;
GRANT SELECT ON VIEW VW_WAREHOUSE_UTILIZATION_TREND TO ROLE FINOPS_ANALYST_ROLE;


-- =========================================================================
-- VERIFICATION QUERIES
-- =========================================================================

/*
-- Verify: Warehouse analytics
SELECT * FROM VW_WAREHOUSE_ANALYTICS
ORDER BY COST_30D DESC
LIMIT 10;

-- Verify: Top expensive queries
SELECT * FROM VW_QUERY_COST_ANALYSIS
WHERE IS_HIGH_COST = TRUE OR IS_LONG_RUNNING = TRUE
LIMIT 20;

-- Verify: Warehouse utilization trend
SELECT * FROM VW_WAREHOUSE_UTILIZATION_TREND
WHERE WAREHOUSE_NAME IN (SELECT WAREHOUSE_NAME FROM VW_WAREHOUSE_ANALYTICS ORDER BY COST_30D DESC LIMIT 5)
ORDER BY USAGE_DATE DESC
LIMIT 50;
*/

/*
=============================================================================
  OBJECTS CREATED:
    - VW_WAREHOUSE_ANALYTICS
    - VW_QUERY_COST_ANALYSIS
    - VW_WAREHOUSE_UTILIZATION_TREND

  NEXT STEPS:
    → Script 03: Chargeback reporting views
=============================================================================
*/
