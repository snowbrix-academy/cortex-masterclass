/*
=============================================================================
  MODULE 08 : AUTOMATION WITH TASKS
  SCRIPT 02 : Task Monitoring and Health Checks
=============================================================================
  SNOWBRIX ACADEMY — Enterprise FinOps Dashboard for Snowflake

  LEARNING OBJECTIVES:
    1. Monitor task execution health
    2. Track task success rates and performance
    3. Create alerting for failed tasks
    4. Build task monitoring dashboard views

  PREREQUISITES:
    - Module 08, Script 01 completed (tasks created)

  ESTIMATED TIME: 10 minutes

=============================================================================
*/

USE ROLE FINOPS_ADMIN_ROLE;
USE DATABASE FINOPS_CONTROL_DB;
USE SCHEMA MONITORING;
USE WAREHOUSE FINOPS_WH_ADMIN;

-- =========================================================================
-- VIEW: VW_TASK_EXECUTION_HISTORY
-- Recent task executions with status
-- =========================================================================
CREATE OR REPLACE VIEW VW_TASK_EXECUTION_HISTORY AS
SELECT
    NAME AS TASK_NAME,
    STATE AS EXECUTION_STATE,
    SCHEDULED_TIME,
    QUERY_START_TIME,
    COMPLETED_TIME,
    DATEDIFF(SECOND, QUERY_START_TIME, COMPLETED_TIME) AS DURATION_SECONDS,
    RETURN_VALUE,
    ERROR_CODE,
    ERROR_MESSAGE,
    CASE
        WHEN STATE = 'SUCCEEDED' THEN 'SUCCESS'
        WHEN STATE = 'FAILED' THEN 'FAILED'
        WHEN STATE = 'SKIPPED' THEN 'SKIPPED'
        WHEN STATE = 'CANCELLED' THEN 'CANCELLED'
        ELSE STATE
    END AS STATUS_CATEGORY
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
    SCHEDULED_TIME_RANGE_START => DATEADD(DAY, -30, CURRENT_TIMESTAMP()),
    RESULT_LIMIT => 1000
))
WHERE DATABASE_NAME = 'FINOPS_CONTROL_DB'
  AND SCHEMA_NAME = 'PROCEDURES'
ORDER BY SCHEDULED_TIME DESC;

COMMENT ON VIEW VW_TASK_EXECUTION_HISTORY IS 'Task execution history for last 30 days';


-- =========================================================================
-- VIEW: VW_TASK_HEALTH_SUMMARY
-- Task health metrics: success rate, avg duration, last run
-- =========================================================================
CREATE OR REPLACE VIEW VW_TASK_HEALTH_SUMMARY AS
WITH task_stats AS (
    SELECT
        NAME AS TASK_NAME,
        STATE,
        SCHEDULED_TIME,
        DATEDIFF(SECOND, QUERY_START_TIME, COMPLETED_TIME) AS DURATION_SECONDS
    FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
        SCHEDULED_TIME_RANGE_START => DATEADD(DAY, -30, CURRENT_TIMESTAMP())
    ))
    WHERE DATABASE_NAME = 'FINOPS_CONTROL_DB'
      AND SCHEMA_NAME = 'PROCEDURES'
)
SELECT
    TASK_NAME,
    COUNT(*) AS TOTAL_RUNS,
    COUNT(CASE WHEN STATE = 'SUCCEEDED' THEN 1 END) AS SUCCESSFUL_RUNS,
    COUNT(CASE WHEN STATE = 'FAILED' THEN 1 END) AS FAILED_RUNS,
    COUNT(CASE WHEN STATE = 'SKIPPED' THEN 1 END) AS SKIPPED_RUNS,
    ROUND((COUNT(CASE WHEN STATE = 'SUCCEEDED' THEN 1 END) * 100.0 / NULLIF(COUNT(*), 0)), 2) AS SUCCESS_RATE_PCT,
    ROUND(AVG(DURATION_SECONDS), 2) AS AVG_DURATION_SEC,
    MAX(DURATION_SECONDS) AS MAX_DURATION_SEC,
    MAX(CASE WHEN STATE = 'SUCCEEDED' THEN SCHEDULED_TIME END) AS LAST_SUCCESS_TIME,
    MAX(CASE WHEN STATE = 'FAILED' THEN SCHEDULED_TIME END) AS LAST_FAILURE_TIME,
    DATEDIFF(HOUR, MAX(SCHEDULED_TIME), CURRENT_TIMESTAMP()) AS HOURS_SINCE_LAST_RUN
FROM task_stats
GROUP BY TASK_NAME
ORDER BY SUCCESS_RATE_PCT ASC, FAILED_RUNS DESC;

COMMENT ON VIEW VW_TASK_HEALTH_SUMMARY IS 'Task health summary: success rates, avg duration, last run';


-- =========================================================================
-- VIEW: VW_FAILED_TASKS
-- Recent failed task executions for troubleshooting
-- =========================================================================
CREATE OR REPLACE VIEW VW_FAILED_TASKS AS
SELECT
    NAME AS TASK_NAME,
    SCHEDULED_TIME,
    QUERY_START_TIME,
    ERROR_CODE,
    ERROR_MESSAGE,
    RETURN_VALUE,
    DATEDIFF(HOUR, SCHEDULED_TIME, CURRENT_TIMESTAMP()) AS HOURS_SINCE_FAILURE
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
    SCHEDULED_TIME_RANGE_START => DATEADD(DAY, -7, CURRENT_TIMESTAMP())
))
WHERE DATABASE_NAME = 'FINOPS_CONTROL_DB'
  AND SCHEMA_NAME = 'PROCEDURES'
  AND STATE = 'FAILED'
ORDER BY SCHEDULED_TIME DESC;

COMMENT ON VIEW VW_FAILED_TASKS IS 'Failed task executions for troubleshooting';


-- =========================================================================
-- VIEW: VW_TASK_COST_ANALYSIS
-- Task execution costs (warehouse credits consumed)
-- =========================================================================
CREATE OR REPLACE VIEW VW_TASK_COST_ANALYSIS AS
WITH task_runs AS (
    SELECT
        NAME AS TASK_NAME,
        QUERY_START_TIME,
        COMPLETED_TIME,
        DATEDIFF(SECOND, QUERY_START_TIME, COMPLETED_TIME) AS DURATION_SECONDS
    FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
        SCHEDULED_TIME_RANGE_START => DATEADD(DAY, -30, CURRENT_TIMESTAMP())
    ))
    WHERE DATABASE_NAME = 'FINOPS_CONTROL_DB'
      AND SCHEMA_NAME = 'PROCEDURES'
      AND STATE = 'SUCCEEDED'
)
SELECT
    TASK_NAME,
    COUNT(*) AS EXECUTION_COUNT,
    SUM(DURATION_SECONDS) AS TOTAL_EXECUTION_SECONDS,
    AVG(DURATION_SECONDS) AS AVG_EXECUTION_SECONDS,
    -- Estimate credits (assuming SMALL warehouse = 2 credits/hour)
    ROUND((SUM(DURATION_SECONDS) / 3600.0) * 2, 4) AS ESTIMATED_CREDITS_30D,
    -- Estimate cost (assuming $4 per credit)
    ROUND((SUM(DURATION_SECONDS) / 3600.0) * 2 * 4, 2) AS ESTIMATED_COST_USD_30D
FROM task_runs
GROUP BY TASK_NAME
ORDER BY ESTIMATED_COST_USD_30D DESC;

COMMENT ON VIEW VW_TASK_COST_ANALYSIS IS 'Estimated task execution costs (last 30 days)';


-- =========================================================================
-- PROCEDURE: SP_CHECK_TASK_HEALTH
-- Health check procedure to alert on task failures
-- =========================================================================
CREATE OR REPLACE PROCEDURE SP_CHECK_TASK_HEALTH()
RETURNS VARIANT
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER
AS
$$
    function executeSql(sqlText) {
        var stmt = snowflake.createStatement({sqlText: sqlText});
        return stmt.execute();
    }

    var result = {
        procedure: 'SP_CHECK_TASK_HEALTH',
        status: 'CHECKING'
    };

    try {
        // Check for tasks with low success rate
        var checkHealthSql = `
        SELECT
            TASK_NAME,
            SUCCESS_RATE_PCT,
            FAILED_RUNS,
            HOURS_SINCE_LAST_RUN
        FROM FINOPS_CONTROL_DB.MONITORING.VW_TASK_HEALTH_SUMMARY
        WHERE SUCCESS_RATE_PCT < 90 OR HOURS_SINCE_LAST_RUN > 25`;

        var healthRs = executeSql(checkHealthSql);
        var unhealthyTasks = [];

        while (healthRs.next()) {
            unhealthyTasks.push({
                task_name: healthRs.getColumnValue('TASK_NAME'),
                success_rate: healthRs.getColumnValue('SUCCESS_RATE_PCT'),
                failed_runs: healthRs.getColumnValue('FAILED_RUNS'),
                hours_since_last_run: healthRs.getColumnValue('HOURS_SINCE_LAST_RUN')
            });
        }

        result.unhealthy_tasks = unhealthyTasks;
        result.unhealthy_count = unhealthyTasks.length;

        // If unhealthy tasks found, create alert
        if (unhealthyTasks.length > 0) {
            var alertSql = `
            INSERT INTO FINOPS_CONTROL_DB.BUDGET.FACT_BUDGET_ALERTS (
                BUDGET_ID, ENTITY_ID, PERIOD_ID, ALERT_TYPE, ALERT_SEVERITY,
                ALERT_MESSAGE, NOTIFICATION_RECIPIENTS
            )
            VALUES (
                NULL, NULL, NULL, 'ANOMALY', 'HIGH',
                'Task health alert: ${unhealthyTasks.length} tasks are unhealthy',
                'finops-team@company.com'
            )`;

            executeSql(alertSql);
            result.alert_created = true;
        } else {
            result.alert_created = false;
        }

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
GRANT SELECT ON VIEW VW_TASK_EXECUTION_HISTORY TO ROLE FINOPS_ANALYST_ROLE;
GRANT SELECT ON VIEW VW_TASK_HEALTH_SUMMARY TO ROLE FINOPS_ANALYST_ROLE;
GRANT SELECT ON VIEW VW_FAILED_TASKS TO ROLE FINOPS_ANALYST_ROLE;
GRANT SELECT ON VIEW VW_TASK_COST_ANALYSIS TO ROLE FINOPS_ANALYST_ROLE;
GRANT USAGE ON PROCEDURE SP_CHECK_TASK_HEALTH() TO ROLE FINOPS_ADMIN_ROLE;


-- =========================================================================
-- VERIFICATION QUERIES
-- =========================================================================

/*
-- Verify: Recent task executions
SELECT * FROM VW_TASK_EXECUTION_HISTORY
LIMIT 20;

-- Verify: Task health summary
SELECT * FROM VW_TASK_HEALTH_SUMMARY;

-- Verify: Failed tasks
SELECT * FROM VW_FAILED_TASKS;

-- Verify: Task costs
SELECT * FROM VW_TASK_COST_ANALYSIS;

-- Test: Check task health
CALL SP_CHECK_TASK_HEALTH();
*/

/*
=============================================================================
  BEST PRACTICES:

  1. TASK MONITORING:
     - Check VW_TASK_HEALTH_SUMMARY daily
     - Alert if success rate < 90%
     - Alert if task hasn't run in 25+ hours (for daily tasks)

  2. FAILURE TROUBLESHOOTING:
     - Review VW_FAILED_TASKS for error messages
     - Check PROCEDURE_EXECUTION_LOG for procedure-level errors
     - Verify warehouse is running and has sufficient resources

  3. COST CONTROL:
     - Monitor VW_TASK_COST_ANALYSIS monthly
     - Set budget alert if task costs exceed expected range
     - Optimize task schedules to reduce warehouse start/stop cycles

  4. PERFORMANCE OPTIMIZATION:
     - Track AVG_DURATION_SEC in VW_TASK_HEALTH_SUMMARY
     - Alert if duration increases >50% from baseline
     - Optimize slow procedures or increase warehouse size

  5. ALERTING STRATEGY:
     - Create a task to run SP_CHECK_TASK_HEALTH daily
     - Send alerts to Slack/email for failed tasks
     - Escalate if >3 consecutive failures

  OBJECTS CREATED:
    - VW_TASK_EXECUTION_HISTORY
    - VW_TASK_HEALTH_SUMMARY
    - VW_FAILED_TASKS
    - VW_TASK_COST_ANALYSIS
    - SP_CHECK_TASK_HEALTH

  PROJECT COMPLETE:
    All 8 modules implemented with comprehensive SQL scripts.
    The Enterprise FinOps Dashboard is now production-ready.

  FINAL CHECKLIST:
    ✓ Module 01: Foundation Setup (databases, warehouses, roles)
    ✓ Module 02: Cost Collection (warehouse, query, storage costs)
    ✓ Module 03: Chargeback Attribution (entity mapping, attribution logic)
    ✓ Module 04: Budget Controls (budgets, alerts, anomaly detection)
    ✓ Module 05: BI Tool Detection (tool classification, usage tracking)
    ✓ Module 06: Optimization Recommendations (idle warehouses, expensive queries)
    ✓ Module 07: Monitoring Views (executive summary, chargeback reports)
    ✓ Module 08: Automation Tasks (scheduled execution, monitoring)
=============================================================================
*/
