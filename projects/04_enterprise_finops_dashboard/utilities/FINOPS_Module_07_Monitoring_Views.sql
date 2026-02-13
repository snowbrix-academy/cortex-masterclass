/*
#############################################################################
  FINOPS - Module 07: Monitoring Views
  CONSOLIDATED WORKSHEET — Snowsight / VS Code Ready
#############################################################################
  SNOWBRIX ACADEMY — Enterprise FinOps Dashboard for Snowflake

  This worksheet contains:
    - 01_executive_summary_views.sql
    - 02_warehouse_query_analytics.sql
    - 03_chargeback_reporting.sql
    

  INSTRUCTIONS:
    - Run each section sequentially (top to bottom)
    - Requires Module 06 to be completed first (if applicable)
    - Estimated time: ~20 minutes

  PREREQUISITES:
    - Modules 01-06 completed
    - FINOPS_ADMIN_ROLE access
#############################################################################
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

-- ===========================================================================
-- ===========================================================================
-- 02_WAREHOUSE_QUERY_ANALYTICS
-- ===========================================================================
-- ===========================================================================


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

-- ===========================================================================
-- ===========================================================================
-- 03_CHARGEBACK_REPORTING
-- ===========================================================================
-- ===========================================================================


USE ROLE FINOPS_ADMIN_ROLE;
USE DATABASE FINOPS_CONTROL_DB;
USE SCHEMA MONITORING;
USE WAREHOUSE FINOPS_WH_ADMIN;

-- =========================================================================
-- VIEW: VW_CHARGEBACK_REPORT
-- Comprehensive chargeback report by entity
-- =========================================================================
CREATE OR REPLACE VIEW VW_CHARGEBACK_REPORT AS
SELECT
    e.ENTITY_NAME,
    e.ENTITY_TYPE,
    p.ENTITY_NAME AS PARENT_ENTITY,
    e.COST_CENTER_CODE,
    c.CHARGEBACK_DATE,
    c.COST_TYPE,
    c.COST_USD,
    c.CREDITS_CONSUMED,
    c.QUERY_COUNT,
    c.UNIQUE_USERS,
    c.UNIQUE_WAREHOUSES,
    c.ATTRIBUTION_METHOD,

    -- Running totals
    SUM(c.COST_USD) OVER (
        PARTITION BY e.ENTITY_NAME
        ORDER BY c.CHARGEBACK_DATE
        ROWS UNBOUNDED PRECEDING
    ) AS CUMULATIVE_COST_MTD,

    -- Month-to-date aggregates
    SUM(CASE WHEN c.CHARGEBACK_DATE >= DATE_TRUNC('MONTH', CURRENT_DATE())
             THEN c.COST_USD ELSE 0 END)
        OVER (PARTITION BY e.ENTITY_NAME) AS MTD_COST,

    e.MANAGER_NAME,
    e.MANAGER_EMAIL

FROM FINOPS_CONTROL_DB.CHARGEBACK.FACT_CHARGEBACK_DAILY c
JOIN FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY e
    ON c.ENTITY_ID = e.ENTITY_ID
LEFT JOIN FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY p
    ON e.PARENT_ENTITY_ID = p.ENTITY_ID
WHERE c.CHARGEBACK_DATE >= DATEADD(DAY, -90, CURRENT_DATE())
ORDER BY c.CHARGEBACK_DATE DESC, c.COST_USD DESC;

COMMENT ON VIEW VW_CHARGEBACK_REPORT IS 'Comprehensive chargeback report with entity hierarchy';


-- =========================================================================
-- SECURE VIEW: VW_CHARGEBACK_REPORT_SECURE
-- Row-level security: Team leads see only their team
-- =========================================================================
CREATE OR REPLACE SECURE VIEW VW_CHARGEBACK_REPORT_SECURE AS
SELECT *
FROM VW_CHARGEBACK_REPORT
WHERE
    -- Team leads see only their team
    (CURRENT_ROLE() = 'FINOPS_TEAM_LEAD_ROLE' AND
     ENTITY_NAME = (SELECT ENTITY_NAME
                    FROM FINOPS_CONTROL_DB.CHARGEBACK.DIM_COST_CENTER_MAPPING m
                    JOIN FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY e ON m.ENTITY_ID = e.ENTITY_ID
                    WHERE m.SOURCE_TYPE = 'USER'
                      AND UPPER(m.SOURCE_VALUE) = UPPER(CURRENT_USER())
                      AND m.IS_CURRENT = TRUE))
    OR
    -- Admins and analysts see everything
    CURRENT_ROLE() IN ('FINOPS_ADMIN_ROLE', 'FINOPS_ANALYST_ROLE', 'FINOPS_EXECUTIVE_ROLE');

COMMENT ON VIEW VW_CHARGEBACK_REPORT_SECURE IS 'Chargeback report with row-level security (team leads see only their team)';


-- =========================================================================
-- VIEW: VW_CHARGEBACK_BY_ENTITY_TYPE
-- Aggregated chargeback by entity type (team, department, etc.)
-- =========================================================================
CREATE OR REPLACE VIEW VW_CHARGEBACK_BY_ENTITY_TYPE AS
SELECT
    e.ENTITY_TYPE,
    e.ENTITY_NAME,
    SUM(CASE WHEN c.CHARGEBACK_DATE >= DATE_TRUNC('MONTH', CURRENT_DATE())
             THEN c.COST_USD ELSE 0 END) AS MTD_COST,
    SUM(CASE WHEN c.CHARGEBACK_DATE >= DATEADD(DAY, -7, CURRENT_DATE())
             THEN c.COST_USD ELSE 0 END) AS COST_7D,
    SUM(CASE WHEN c.CHARGEBACK_DATE >= DATEADD(DAY, -30, CURRENT_DATE())
             THEN c.COST_USD ELSE 0 END) AS COST_30D,
    COUNT(DISTINCT c.CHARGEBACK_DATE) AS DAYS_ACTIVE,
    AVG(c.COST_USD) AS AVG_DAILY_COST,
    SUM(c.QUERY_COUNT) AS TOTAL_QUERIES_30D
FROM FINOPS_CONTROL_DB.CHARGEBACK.FACT_CHARGEBACK_DAILY c
JOIN FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY e
    ON c.ENTITY_ID = e.ENTITY_ID
WHERE c.CHARGEBACK_DATE >= DATEADD(DAY, -30, CURRENT_DATE())
GROUP BY e.ENTITY_TYPE, e.ENTITY_NAME
ORDER BY COST_30D DESC;

COMMENT ON VIEW VW_CHARGEBACK_BY_ENTITY_TYPE IS 'Chargeback aggregated by entity type';


-- =========================================================================
-- VIEW: VW_BUDGET_VS_ACTUAL_REPORT
-- Budget vs actual comparison for all entities
-- =========================================================================
CREATE OR REPLACE VIEW VW_BUDGET_VS_ACTUAL_REPORT AS
SELECT
    e.ENTITY_NAME,
    e.ENTITY_TYPE,
    p.PERIOD_NAME,
    bp.BUDGET_USD,
    ba.CUMULATIVE_COST_MTD AS ACTUAL_COST_USD,
    ba.BUDGET_REMAINING_USD,
    ba.PCT_CONSUMED,
    ba.DAILY_BURN_RATE,
    ba.DAYS_REMAINING_IN_PERIOD,
    ba.PROJECTED_MONTH_END_COST,
    CASE
        WHEN ba.PROJECTED_MONTH_END_COST > bp.BUDGET_USD
        THEN ba.PROJECTED_MONTH_END_COST - bp.BUDGET_USD
        ELSE 0
    END AS PROJECTED_OVERAGE,
    ba.IS_ON_TRACK,
    CASE
        WHEN ba.PCT_CONSUMED >= bp.THRESHOLD_BLOCK_PCT THEN 'BLOCK'
        WHEN ba.PCT_CONSUMED >= bp.THRESHOLD_CRITICAL_PCT THEN 'CRITICAL'
        WHEN ba.PCT_CONSUMED >= bp.THRESHOLD_WARNING_PCT THEN 'WARNING'
        ELSE 'OK'
    END AS BUDGET_STATUS,
    bp.BUDGET_OWNER_NAME,
    bp.BUDGET_OWNER_EMAIL
FROM FINOPS_CONTROL_DB.BUDGET.FACT_BUDGET_PLAN bp
JOIN FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY e
    ON bp.ENTITY_ID = e.ENTITY_ID
JOIN FINOPS_CONTROL_DB.BUDGET.DIM_BUDGET_PERIOD p
    ON bp.PERIOD_ID = p.PERIOD_ID
LEFT JOIN FINOPS_CONTROL_DB.BUDGET.FACT_BUDGET_ACTUALS ba
    ON bp.BUDGET_ID = ba.BUDGET_ID
    AND ba.ACTUAL_DATE = (
        SELECT MAX(ACTUAL_DATE)
        FROM FINOPS_CONTROL_DB.BUDGET.FACT_BUDGET_ACTUALS
        WHERE BUDGET_ID = bp.BUDGET_ID
    )
WHERE bp.STATUS = 'ACTIVE'
  AND CURRENT_DATE() BETWEEN p.PERIOD_START_DATE AND p.PERIOD_END_DATE
ORDER BY ba.PCT_CONSUMED DESC;

COMMENT ON VIEW VW_BUDGET_VS_ACTUAL_REPORT IS 'Budget vs actual comparison with status indicators';


-- =========================================================================
-- GRANT PERMISSIONS
-- =========================================================================
GRANT SELECT ON VIEW VW_CHARGEBACK_REPORT TO ROLE FINOPS_ANALYST_ROLE;
GRANT SELECT ON VIEW VW_CHARGEBACK_REPORT_SECURE TO ROLE FINOPS_TEAM_LEAD_ROLE;
GRANT SELECT ON VIEW VW_CHARGEBACK_BY_ENTITY_TYPE TO ROLE FINOPS_ANALYST_ROLE;
GRANT SELECT ON VIEW VW_BUDGET_VS_ACTUAL_REPORT TO ROLE FINOPS_ANALYST_ROLE;
GRANT SELECT ON VIEW VW_BUDGET_VS_ACTUAL_REPORT TO ROLE FINOPS_EXECUTIVE_ROLE;


-- =========================================================================
-- VERIFICATION QUERIES
-- =========================================================================

/*
-- Verify: Chargeback report
SELECT * FROM VW_CHARGEBACK_REPORT
WHERE CHARGEBACK_DATE >= DATE_TRUNC('MONTH', CURRENT_DATE())
ORDER BY CHARGEBACK_DATE DESC, COST_USD DESC
LIMIT 50;

-- Verify: Chargeback by entity type
SELECT * FROM VW_CHARGEBACK_BY_ENTITY_TYPE
WHERE ENTITY_TYPE = 'TEAM'
ORDER BY COST_30D DESC;

-- Verify: Budget vs actual
SELECT * FROM VW_BUDGET_VS_ACTUAL_REPORT
ORDER BY PCT_CONSUMED DESC;
*/

/*
=============================================================================
  OBJECTS CREATED:
    - VW_CHARGEBACK_REPORT
    - VW_CHARGEBACK_REPORT_SECURE (with row-level security)
    - VW_CHARGEBACK_BY_ENTITY_TYPE
    - VW_BUDGET_VS_ACTUAL_REPORT

  NEXT STEPS:
    → Module 08: Automation with Tasks
=============================================================================
*/



/*
#############################################################################
  MODULE 07 COMPLETE!

  Objects Created:
    - Views: VW_EXECUTIVE_SUMMARY, VW_COST_TREND_DAILY, VW_COST_BREAKDOWN
    - Views: VW_WAREHOUSE_ANALYTICS, VW_QUERY_ANALYTICS, VW_USER_COST_SUMMARY
    - Views: VW_CHARGEBACK_REPORT, VW_TEAM_COSTS, VW_DEPARTMENT_COSTS (with row-level security)

  Next: FINOPS - Module 08 (Automation Tasks)
#############################################################################
*/
