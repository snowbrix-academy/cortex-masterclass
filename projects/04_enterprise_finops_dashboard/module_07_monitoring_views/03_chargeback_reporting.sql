/*
=============================================================================
  MODULE 07 : MONITORING VIEWS
  SCRIPT 03 : Chargeback Reporting Views
=============================================================================
  SNOWBRIX ACADEMY — Enterprise FinOps Dashboard for Snowflake

  LEARNING OBJECTIVES:
    1. Create chargeback reporting views for teams and departments
    2. Implement row-level security for team leads
    3. Build budget vs actual views

  PREREQUISITES:
    - All previous modules completed

  ESTIMATED TIME: 10 minutes

=============================================================================
*/

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
