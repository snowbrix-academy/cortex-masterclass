/*
=============================================================================
  MODULE 07 : MONITORING VIEWS
  SCRIPT 01 : Executive Summary Views
=============================================================================
  SNOWBRIX ACADEMY — Enterprise FinOps Dashboard for Snowflake

  LEARNING OBJECTIVES:
    1. Create executive-level KPI views
    2. Build daily/weekly/monthly trend views
    3. Implement top-N analysis views
    4. Design for Power BI/Tableau consumption

  PREREQUISITES:
    - All previous modules completed
    - Cost data collected and attributed

  ESTIMATED TIME: 15 minutes

=============================================================================
*/

USE ROLE FINOPS_ADMIN_ROLE;
USE DATABASE FINOPS_CONTROL_DB;
USE SCHEMA MONITORING;
USE WAREHOUSE FINOPS_WH_ADMIN;

-- =========================================================================
-- VIEW: VW_EXECUTIVE_SUMMARY
-- High-level KPIs for executive dashboard
-- =========================================================================
CREATE OR REPLACE VIEW VW_EXECUTIVE_SUMMARY AS
WITH current_period AS (
    SELECT
        SUM(COST_USD) AS MTD_COST,
        SUM(CREDITS_CONSUMED) AS MTD_CREDITS,
        COUNT(DISTINCT ENTITY_ID) AS ACTIVE_ENTITIES,
        COUNT(DISTINCT CHARGEBACK_DATE) AS DAYS_IN_PERIOD
    FROM FINOPS_CONTROL_DB.CHARGEBACK.FACT_CHARGEBACK_DAILY
    WHERE CHARGEBACK_DATE >= DATE_TRUNC('MONTH', CURRENT_DATE())
      AND CHARGEBACK_DATE <= CURRENT_DATE()
),
prior_period AS (
    SELECT
        SUM(COST_USD) AS PRIOR_MTD_COST
    FROM FINOPS_CONTROL_DB.CHARGEBACK.FACT_CHARGEBACK_DAILY
    WHERE CHARGEBACK_DATE >= DATE_TRUNC('MONTH', DATEADD(MONTH, -1, CURRENT_DATE()))
      AND CHARGEBACK_DATE <= DATEADD(MONTH, -1, CURRENT_DATE())
),
ytd AS (
    SELECT SUM(COST_USD) AS YTD_COST
    FROM FINOPS_CONTROL_DB.CHARGEBACK.FACT_CHARGEBACK_DAILY
    WHERE CHARGEBACK_DATE >= DATE_TRUNC('YEAR', CURRENT_DATE())
),
top_spender AS (
    SELECT ENTITY_NAME, SUM(COST_USD) AS COST
    FROM FINOPS_CONTROL_DB.CHARGEBACK.FACT_CHARGEBACK_DAILY
    WHERE CHARGEBACK_DATE >= DATE_TRUNC('MONTH', CURRENT_DATE())
    GROUP BY ENTITY_NAME
    ORDER BY COST DESC LIMIT 1
),
unallocated AS (
    SELECT SUM(COST_USD) AS UNALLOCATED_COST
    FROM FINOPS_CONTROL_DB.CHARGEBACK.FACT_CHARGEBACK_DAILY
    WHERE CHARGEBACK_DATE >= DATE_TRUNC('MONTH', CURRENT_DATE())
      AND ATTRIBUTION_METHOD = 'UNALLOCATED'
)
SELECT
    -- Current Period Metrics
    ROUND(cp.MTD_COST, 2) AS MTD_COST_USD,
    ROUND(cp.MTD_CREDITS, 2) AS MTD_CREDITS,
    cp.ACTIVE_ENTITIES,
    cp.DAYS_IN_PERIOD,
    ROUND(cp.MTD_COST / NULLIF(cp.DAYS_IN_PERIOD, 0), 2) AS AVG_DAILY_COST,

    -- YTD Metrics
    ROUND(ytd.YTD_COST, 2) AS YTD_COST_USD,

    -- Trends
    ROUND(((cp.MTD_COST - pp.PRIOR_MTD_COST) / NULLIF(pp.PRIOR_MTD_COST, 0)) * 100, 2) AS MTD_COST_CHANGE_PCT,

    -- Top Spender
    ts.ENTITY_NAME AS TOP_SPENDER_ENTITY,
    ROUND(ts.COST, 2) AS TOP_SPENDER_COST,

    -- Unallocated
    ROUND(ua.UNALLOCATED_COST, 2) AS UNALLOCATED_COST_USD,
    ROUND((ua.UNALLOCATED_COST / NULLIF(cp.MTD_COST, 0)) * 100, 2) AS UNALLOCATED_PCT,

    -- Targets
    CASE WHEN ua.UNALLOCATED_COST / NULLIF(cp.MTD_COST, 0) * 100 < 5 THEN TRUE ELSE FALSE END AS UNALLOCATED_ON_TARGET,

    CURRENT_TIMESTAMP() AS REFRESHED_AT

FROM current_period cp
CROSS JOIN prior_period pp
CROSS JOIN ytd
CROSS JOIN top_spender ts
CROSS JOIN unallocated ua;

COMMENT ON VIEW VW_EXECUTIVE_SUMMARY IS 'Executive dashboard KPIs: MTD, YTD, trends, top spenders';


-- =========================================================================
-- VIEW: VW_DAILY_SPEND_TREND
-- Daily cost trends for last 90 days
-- =========================================================================
CREATE OR REPLACE VIEW VW_DAILY_SPEND_TREND AS
SELECT
    CHARGEBACK_DATE,
    DAYNAME(CHARGEBACK_DATE) AS DAY_OF_WEEK,
    SUM(COST_USD) AS DAILY_COST_USD,
    SUM(CREDITS_CONSUMED) AS DAILY_CREDITS,
    COUNT(DISTINCT ENTITY_ID) AS ACTIVE_ENTITIES,
    SUM(QUERY_COUNT) AS TOTAL_QUERIES,

    -- 7-day moving average
    AVG(SUM(COST_USD)) OVER (
        ORDER BY CHARGEBACK_DATE
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS MA_7DAY_COST,

    -- Week-over-week change
    LAG(SUM(COST_USD), 7) OVER (ORDER BY CHARGEBACK_DATE) AS COST_7D_AGO,
    ROUND(
        ((SUM(COST_USD) - LAG(SUM(COST_USD), 7) OVER (ORDER BY CHARGEBACK_DATE)) /
         NULLIF(LAG(SUM(COST_USD), 7) OVER (ORDER BY CHARGEBACK_DATE), 0)) * 100,
    2) AS WOW_CHANGE_PCT

FROM FINOPS_CONTROL_DB.CHARGEBACK.FACT_CHARGEBACK_DAILY
WHERE CHARGEBACK_DATE >= DATEADD(DAY, -90, CURRENT_DATE())
GROUP BY CHARGEBACK_DATE
ORDER BY CHARGEBACK_DATE DESC;

COMMENT ON VIEW VW_DAILY_SPEND_TREND IS 'Daily cost trends with 7-day moving average and week-over-week change';


-- =========================================================================
-- VIEW: VW_TOP_10_SPENDERS
-- Top 10 entities by cost (current month)
-- =========================================================================
CREATE OR REPLACE VIEW VW_TOP_10_SPENDERS AS
SELECT
    e.ENTITY_NAME,
    e.ENTITY_TYPE,
    p.ENTITY_NAME AS PARENT_ENTITY,
    SUM(c.COST_USD) AS MTD_COST_USD,
    SUM(c.CREDITS_CONSUMED) AS MTD_CREDITS,
    SUM(c.QUERY_COUNT) AS MTD_QUERIES,
    AVG(c.UNIQUE_USERS) AS AVG_DAILY_USERS,
    ROUND(SUM(c.COST_USD) / (SELECT SUM(COST_USD)
                              FROM FINOPS_CONTROL_DB.CHARGEBACK.FACT_CHARGEBACK_DAILY
                              WHERE CHARGEBACK_DATE >= DATE_TRUNC('MONTH', CURRENT_DATE())) * 100, 2) AS PCT_OF_TOTAL
FROM FINOPS_CONTROL_DB.CHARGEBACK.FACT_CHARGEBACK_DAILY c
JOIN FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY e
    ON c.ENTITY_ID = e.ENTITY_ID
LEFT JOIN FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY p
    ON e.PARENT_ENTITY_ID = p.ENTITY_ID
WHERE c.CHARGEBACK_DATE >= DATE_TRUNC('MONTH', CURRENT_DATE())
GROUP BY e.ENTITY_NAME, e.ENTITY_TYPE, p.ENTITY_NAME
ORDER BY MTD_COST_USD DESC
LIMIT 10;

COMMENT ON VIEW VW_TOP_10_SPENDERS IS 'Top 10 entities by MTD cost with percentage of total';


-- =========================================================================
-- VIEW: VW_COST_BY_TYPE
-- Cost breakdown by type (compute, storage, cloud services, serverless)
-- =========================================================================
CREATE OR REPLACE VIEW VW_COST_BY_TYPE AS
SELECT
    COST_TYPE,
    SUM(CASE WHEN CHARGEBACK_DATE >= DATE_TRUNC('MONTH', CURRENT_DATE())
             THEN COST_USD ELSE 0 END) AS MTD_COST,
    SUM(CASE WHEN CHARGEBACK_DATE >= DATEADD(DAY, -7, CURRENT_DATE())
             THEN COST_USD ELSE 0 END) AS COST_7D,
    SUM(CASE WHEN CHARGEBACK_DATE >= DATEADD(DAY, -30, CURRENT_DATE())
             THEN COST_USD ELSE 0 END) AS COST_30D,
    ROUND(
        SUM(CASE WHEN CHARGEBACK_DATE >= DATE_TRUNC('MONTH', CURRENT_DATE())
                 THEN COST_USD ELSE 0 END) /
        (SELECT SUM(COST_USD) FROM FINOPS_CONTROL_DB.CHARGEBACK.FACT_CHARGEBACK_DAILY
         WHERE CHARGEBACK_DATE >= DATE_TRUNC('MONTH', CURRENT_DATE())) * 100,
    2) AS PCT_OF_MTD_TOTAL
FROM FINOPS_CONTROL_DB.CHARGEBACK.FACT_CHARGEBACK_DAILY
WHERE CHARGEBACK_DATE >= DATEADD(DAY, -90, CURRENT_DATE())
GROUP BY COST_TYPE
ORDER BY MTD_COST DESC;

COMMENT ON VIEW VW_COST_BY_TYPE IS 'Cost breakdown by type: compute, storage, cloud services, serverless';


-- =========================================================================
-- GRANT PERMISSIONS
-- =========================================================================
GRANT SELECT ON VIEW VW_EXECUTIVE_SUMMARY TO ROLE FINOPS_ANALYST_ROLE;
GRANT SELECT ON VIEW VW_DAILY_SPEND_TREND TO ROLE FINOPS_ANALYST_ROLE;
GRANT SELECT ON VIEW VW_TOP_10_SPENDERS TO ROLE FINOPS_ANALYST_ROLE;
GRANT SELECT ON VIEW VW_COST_BY_TYPE TO ROLE FINOPS_ANALYST_ROLE;

GRANT SELECT ON VIEW VW_EXECUTIVE_SUMMARY TO ROLE FINOPS_EXECUTIVE_ROLE;
GRANT SELECT ON VIEW VW_DAILY_SPEND_TREND TO ROLE FINOPS_EXECUTIVE_ROLE;
GRANT SELECT ON VIEW VW_TOP_10_SPENDERS TO ROLE FINOPS_EXECUTIVE_ROLE;


-- =========================================================================
-- VERIFICATION QUERIES
-- =========================================================================

/*
-- Verify: Executive summary
SELECT * FROM VW_EXECUTIVE_SUMMARY;

-- Verify: Daily spend trend
SELECT * FROM VW_DAILY_SPEND_TREND
ORDER BY CHARGEBACK_DATE DESC
LIMIT 30;

-- Verify: Top spenders
SELECT * FROM VW_TOP_10_SPENDERS;

-- Verify: Cost by type
SELECT * FROM VW_COST_BY_TYPE;
*/

/*
=============================================================================
  OBJECTS CREATED:
    - VW_EXECUTIVE_SUMMARY
    - VW_DAILY_SPEND_TREND
    - VW_TOP_10_SPENDERS
    - VW_COST_BY_TYPE

  NEXT STEPS:
    → Script 02: Warehouse and query analytics views
    → Script 03: Chargeback and budget reporting views
=============================================================================
*/
