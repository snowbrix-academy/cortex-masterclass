/*
=============================================================================
  MODULE 05 : BI TOOL DETECTION
  SCRIPT 02 : BI Tool Analysis Views
=============================================================================
  SNOWBRIX ACADEMY — Enterprise FinOps Dashboard for Snowflake

  LEARNING OBJECTIVES:
    1. Create analytical views for BI tool cost analysis
    2. Identify expensive reports and dashboards
    3. Track BI tool adoption and usage trends
    4. Support BI tool optimization decisions

  PREREQUISITES:
    - Module 05, Script 01 completed

  ESTIMATED TIME: 10 minutes

=============================================================================
*/

USE ROLE FINOPS_ADMIN_ROLE;
USE DATABASE FINOPS_CONTROL_DB;
USE SCHEMA MONITORING;
USE WAREHOUSE FINOPS_WH_ADMIN;

-- =========================================================================
-- VIEW: VW_BI_TOOL_COST_ANALYSIS
-- Cost breakdown by BI tool with trends
-- =========================================================================
CREATE OR REPLACE VIEW VW_BI_TOOL_COST_ANALYSIS AS
SELECT
    t.TOOL_NAME,
    t.TOOL_CATEGORY,
    t.VENDOR_NAME,

    -- Current Period (Last 30 days)
    SUM(CASE WHEN u.USAGE_DATE >= DATEADD(DAY, -30, CURRENT_DATE()) THEN u.COST_USD ELSE 0 END) AS COST_30D,
    SUM(CASE WHEN u.USAGE_DATE >= DATEADD(DAY, -7, CURRENT_DATE()) THEN u.COST_USD ELSE 0 END) AS COST_7D,

    -- Usage Metrics
    SUM(CASE WHEN u.USAGE_DATE >= DATEADD(DAY, -30, CURRENT_DATE()) THEN u.QUERY_COUNT ELSE 0 END) AS QUERY_COUNT_30D,
    AVG(CASE WHEN u.USAGE_DATE >= DATEADD(DAY, -30, CURRENT_DATE()) THEN u.UNIQUE_USERS END) AS AVG_DAILY_USERS,

    -- Cost Efficiency
    AVG(CASE WHEN u.USAGE_DATE >= DATEADD(DAY, -30, CURRENT_DATE()) THEN u.AVG_QUERY_COST_USD END) AS AVG_QUERY_COST,
    MAX(CASE WHEN u.USAGE_DATE >= DATEADD(DAY, -30, CURRENT_DATE()) THEN u.MAX_QUERY_COST_USD END) AS MAX_QUERY_COST,

    -- Trend (% change vs prior 30 days)
    ROUND(
        (SUM(CASE WHEN u.USAGE_DATE >= DATEADD(DAY, -30, CURRENT_DATE()) THEN u.COST_USD ELSE 0 END) -
         SUM(CASE WHEN u.USAGE_DATE >= DATEADD(DAY, -60, CURRENT_DATE())
                  AND u.USAGE_DATE < DATEADD(DAY, -30, CURRENT_DATE()) THEN u.COST_USD ELSE 0 END)) /
        NULLIF(SUM(CASE WHEN u.USAGE_DATE >= DATEADD(DAY, -60, CURRENT_DATE())
                        AND u.USAGE_DATE < DATEADD(DAY, -30, CURRENT_DATE()) THEN u.COST_USD ELSE 0 END), 0) * 100,
    2) AS PCT_CHANGE_VS_PRIOR_PERIOD

FROM FINOPS_CONTROL_DB.CHARGEBACK.DIM_BI_TOOL_REGISTRY t
LEFT JOIN FINOPS_CONTROL_DB.CHARGEBACK.FACT_BI_TOOL_USAGE u
    ON t.TOOL_NAME = u.TOOL_NAME
WHERE t.IS_ACTIVE = TRUE
GROUP BY t.TOOL_NAME, t.TOOL_CATEGORY, t.VENDOR_NAME
HAVING COST_30D > 0
ORDER BY COST_30D DESC;

COMMENT ON VIEW VW_BI_TOOL_COST_ANALYSIS IS 'BI tool cost analysis with 30-day trends';


-- =========================================================================
-- VIEW: VW_TOP_BI_REPORTS
-- Most expensive queries/reports per BI tool
-- =========================================================================
CREATE OR REPLACE VIEW VW_TOP_BI_REPORTS AS
WITH bi_tool_queries AS (
    SELECT
        q.QUERY_ID,
        q.QUERY_DATE,
        t.TOOL_NAME,
        t.TOOL_CATEGORY,
        q.USER_NAME,
        q.WAREHOUSE_NAME,
        q.TOTAL_COST_USD,
        q.EXECUTION_TIME_MS,
        q.BYTES_SCANNED,
        q.QUERY_TEXT,
        -- Extract report/dashboard name from query tag or query text
        COALESCE(
            REGEXP_SUBSTR(q.QUERY_TAG, 'report=([^;]+)', 1, 1, 'e'),
            REGEXP_SUBSTR(q.QUERY_TEXT, 'VIEW\\s+(\\w+)', 1, 1, 'e'),
            'Unknown Report'
        ) AS REPORT_NAME,
        ROW_NUMBER() OVER (PARTITION BY t.TOOL_NAME ORDER BY q.TOTAL_COST_USD DESC) AS COST_RANK
    FROM FINOPS_CONTROL_DB.COST_DATA.FACT_QUERY_COST_HISTORY q
    JOIN FINOPS_CONTROL_DB.CHARGEBACK.DIM_BI_TOOL_REGISTRY t
        ON REGEXP_LIKE(q.APPLICATION_NAME, t.APPLICATION_NAME_PATTERN, 'i')
        OR REGEXP_LIKE(q.USER_NAME, t.SERVICE_ACCOUNT_PATTERN, 'i')
    WHERE q.QUERY_DATE >= DATEADD(DAY, -30, CURRENT_DATE())
      AND q.TOTAL_COST_USD > 0.01  -- Filter trivial costs
)
SELECT
    TOOL_NAME,
    TOOL_CATEGORY,
    REPORT_NAME,
    USER_NAME,
    WAREHOUSE_NAME,
    COUNT(*) AS EXECUTION_COUNT,
    SUM(TOTAL_COST_USD) AS TOTAL_COST_USD,
    AVG(TOTAL_COST_USD) AS AVG_COST_PER_EXECUTION,
    AVG(EXECUTION_TIME_MS) AS AVG_EXECUTION_TIME_MS,
    SUM(BYTES_SCANNED) AS TOTAL_BYTES_SCANNED,
    MAX(QUERY_DATE) AS LAST_EXECUTION_DATE
FROM bi_tool_queries
WHERE COST_RANK <= 100  -- Top 100 per tool
GROUP BY TOOL_NAME, TOOL_CATEGORY, REPORT_NAME, USER_NAME, WAREHOUSE_NAME
HAVING TOTAL_COST_USD > 1.00
ORDER BY TOTAL_COST_USD DESC
LIMIT 50;

COMMENT ON VIEW VW_TOP_BI_REPORTS IS 'Top 50 most expensive BI reports/dashboards (last 30 days)';


-- =========================================================================
-- VIEW: VW_BI_TOOL_ADOPTION
-- BI tool adoption trends over time
-- =========================================================================
CREATE OR REPLACE VIEW VW_BI_TOOL_ADOPTION AS
SELECT
    DATE_TRUNC('WEEK', USAGE_DATE) AS WEEK_START,
    TOOL_NAME,
    TOOL_CATEGORY,
    SUM(QUERY_COUNT) AS TOTAL_QUERIES,
    SUM(COST_USD) AS TOTAL_COST_USD,
    AVG(UNIQUE_USERS) AS AVG_DAILY_ACTIVE_USERS,
    COUNT(DISTINCT USAGE_DATE) AS DAYS_ACTIVE
FROM FINOPS_CONTROL_DB.CHARGEBACK.FACT_BI_TOOL_USAGE
WHERE USAGE_DATE >= DATEADD(DAY, -90, CURRENT_DATE())
GROUP BY DATE_TRUNC('WEEK', USAGE_DATE), TOOL_NAME, TOOL_CATEGORY
ORDER BY WEEK_START DESC, TOTAL_COST_USD DESC;

COMMENT ON VIEW VW_BI_TOOL_ADOPTION IS 'Weekly BI tool adoption and usage trends';


-- =========================================================================
-- GRANT PERMISSIONS
-- =========================================================================
GRANT SELECT ON VIEW VW_BI_TOOL_COST_ANALYSIS TO ROLE FINOPS_ANALYST_ROLE;
GRANT SELECT ON VIEW VW_TOP_BI_REPORTS TO ROLE FINOPS_ANALYST_ROLE;
GRANT SELECT ON VIEW VW_BI_TOOL_ADOPTION TO ROLE FINOPS_ANALYST_ROLE;


-- =========================================================================
-- VERIFICATION QUERIES
-- =========================================================================

/*
-- Verify: BI tool cost analysis
SELECT * FROM VW_BI_TOOL_COST_ANALYSIS
ORDER BY COST_30D DESC;

-- Verify: Top expensive reports
SELECT * FROM VW_TOP_BI_REPORTS
LIMIT 20;

-- Verify: BI tool adoption trends
SELECT * FROM VW_BI_TOOL_ADOPTION
WHERE TOOL_NAME IN ('Power BI', 'Tableau', 'dbt')
ORDER BY WEEK_START DESC;
*/

/*
=============================================================================
  OBJECTS CREATED:
    - VW_BI_TOOL_COST_ANALYSIS
    - VW_TOP_BI_REPORTS
    - VW_BI_TOOL_ADOPTION

  NEXT STEPS:
    → Module 06: Optimization Recommendations
=============================================================================
*/
