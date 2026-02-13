/*
#############################################################################
  FINOPS - Module 08: Automation Tasks
  CONSOLIDATED WORKSHEET — Snowsight / VS Code Ready
#############################################################################
  SNOWBRIX ACADEMY — Enterprise FinOps Dashboard for Snowflake

  This worksheet contains:
    - 01_task_definitions.sql
    - 02_task_monitoring.sql
    

  INSTRUCTIONS:
    - Run each section sequentially (top to bottom)
    - Requires Module 07 to be completed first (if applicable)
    - Estimated time: ~20 minutes

  PREREQUISITES:
    - Modules 01-07 completed
    - FINOPS_ADMIN_ROLE access
#############################################################################
*/


USE ROLE FINOPS_ADMIN_ROLE;
USE DATABASE FINOPS_CONTROL_DB;
USE SCHEMA PROCEDURES;
USE WAREHOUSE FINOPS_WH_ETL;

-- =========================================================================
-- STEP 1: CREATE TASK WAREHOUSE (if not exists)
-- Use dedicated warehouse for tasks to isolate cost
-- =========================================================================
-- Assuming FINOPS_WH_ETL already exists from Module 01

-- =========================================================================
-- STEP 2: ENABLE TASK EXECUTION (Account-level setting)
-- Required for tasks to run
-- =========================================================================
-- This must be run by ACCOUNTADMIN
-- ALTER ACCOUNT SET TASK_AUTO_RETRY_ATTEMPTS = 3;


-- =========================================================================
-- ROOT TASK: FINOPS_TASK_COLLECT_WAREHOUSE_COSTS
-- Runs hourly to collect warehouse costs
-- =========================================================================
CREATE OR REPLACE TASK FINOPS_TASK_COLLECT_WAREHOUSE_COSTS
    WAREHOUSE = FINOPS_WH_ETL
    SCHEDULE = 'USING CRON 0 * * * * UTC'  -- Every hour at minute 0
    COMMENT = 'Collects warehouse credit consumption from WAREHOUSE_METERING_HISTORY (hourly)'
AS
    CALL FINOPS_CONTROL_DB.PROCEDURES.SP_COLLECT_WAREHOUSE_COSTS(2, TRUE);


-- =========================================================================
-- TASK: FINOPS_TASK_COLLECT_QUERY_COSTS
-- Runs hourly, 5 minutes after warehouse cost collection
-- =========================================================================
CREATE OR REPLACE TASK FINOPS_TASK_COLLECT_QUERY_COSTS
    WAREHOUSE = FINOPS_WH_ETL
    SCHEDULE = 'USING CRON 5 * * * * UTC'  -- Every hour at minute 5
    COMMENT = 'Collects query-level costs from QUERY_HISTORY (hourly)'
AS
    CALL FINOPS_CONTROL_DB.PROCEDURES.SP_COLLECT_QUERY_COSTS(2, TRUE);


-- =========================================================================
-- TASK: FINOPS_TASK_COLLECT_STORAGE_COSTS
-- Runs daily at 1 AM UTC
-- =========================================================================
CREATE OR REPLACE TASK FINOPS_TASK_COLLECT_STORAGE_COSTS
    WAREHOUSE = FINOPS_WH_ETL
    SCHEDULE = 'USING CRON 0 1 * * * UTC'  -- Daily at 1 AM UTC
    COMMENT = 'Collects storage costs from DATABASE_STORAGE_USAGE_HISTORY (daily)'
AS
    CALL FINOPS_CONTROL_DB.PROCEDURES.SP_COLLECT_STORAGE_COSTS(
        DATEADD(DAY, -2, CURRENT_DATE()),
        CURRENT_DATE()
    );


-- =========================================================================
-- TASK: FINOPS_TASK_CALCULATE_CHARGEBACK
-- Runs daily at 2 AM UTC (after storage collection)
-- =========================================================================
CREATE OR REPLACE TASK FINOPS_TASK_CALCULATE_CHARGEBACK
    WAREHOUSE = FINOPS_WH_ETL
    AFTER FINOPS_TASK_COLLECT_STORAGE_COSTS
    COMMENT = 'Calculates chargeback attribution for previous day (daily)'
AS
    CALL FINOPS_CONTROL_DB.PROCEDURES.SP_CALCULATE_CHARGEBACK(
        DATEADD(DAY, -1, CURRENT_DATE()),
        CURRENT_DATE(),
        FALSE
    );


-- =========================================================================
-- TASK: FINOPS_TASK_CHECK_BUDGETS
-- Runs daily at 3 AM UTC (after chargeback calculation)
-- =========================================================================
CREATE OR REPLACE TASK FINOPS_TASK_CHECK_BUDGETS
    WAREHOUSE = FINOPS_WH_ETL
    AFTER FINOPS_TASK_CALCULATE_CHARGEBACK
    COMMENT = 'Checks budget vs actual and creates alerts (daily)'
AS
BEGIN
    CALL FINOPS_CONTROL_DB.PROCEDURES.SP_CHECK_BUDGETS(CURRENT_DATE());
    CALL FINOPS_CONTROL_DB.PROCEDURES.SP_DETECT_ANOMALIES(CURRENT_DATE());
END;


-- =========================================================================
-- TASK: FINOPS_TASK_CLASSIFY_BI_TOOLS
-- Runs daily at 3:30 AM UTC
-- =========================================================================
CREATE OR REPLACE TASK FINOPS_TASK_CLASSIFY_BI_TOOLS
    WAREHOUSE = FINOPS_WH_ETL
    AFTER FINOPS_TASK_CALCULATE_CHARGEBACK
    COMMENT = 'Classifies queries by BI tool (daily)'
AS
    CALL FINOPS_CONTROL_DB.PROCEDURES.SP_CLASSIFY_BI_TOOLS(
        DATEADD(DAY, -1, CURRENT_DATE()),
        CURRENT_DATE()
    );


-- =========================================================================
-- TASK: FINOPS_TASK_GENERATE_RECOMMENDATIONS
-- Runs weekly on Sunday at 4 AM UTC
-- =========================================================================
CREATE OR REPLACE TASK FINOPS_TASK_GENERATE_RECOMMENDATIONS
    WAREHOUSE = FINOPS_WH_ETL
    SCHEDULE = 'USING CRON 0 4 * * SUN UTC'  -- Sunday at 4 AM UTC
    COMMENT = 'Generates cost optimization recommendations (weekly)'
AS
    CALL FINOPS_CONTROL_DB.PROCEDURES.SP_GENERATE_RECOMMENDATIONS(7, 10.00);


-- =========================================================================
-- TASK: FINOPS_TASK_SEND_NOTIFICATIONS
-- Runs daily at 5 AM UTC (after all processing complete)
-- =========================================================================
CREATE OR REPLACE TASK FINOPS_TASK_SEND_NOTIFICATIONS
    WAREHOUSE = FINOPS_WH_ETL
    AFTER FINOPS_TASK_CHECK_BUDGETS
    COMMENT = 'Sends pending alert notifications (daily)'
AS
    CALL FINOPS_CONTROL_DB.PROCEDURES.SP_SEND_ALERT_NOTIFICATIONS();


-- =========================================================================
-- STEP 3: RESUME TASKS (Start execution)
-- Tasks are created in SUSPENDED state. Resume to enable.
-- =========================================================================

-- Resume root tasks (independent schedulers)
ALTER TASK FINOPS_TASK_COLLECT_WAREHOUSE_COSTS RESUME;
ALTER TASK FINOPS_TASK_COLLECT_QUERY_COSTS RESUME;
ALTER TASK FINOPS_TASK_COLLECT_STORAGE_COSTS RESUME;
ALTER TASK FINOPS_TASK_GENERATE_RECOMMENDATIONS RESUME;

-- Note: Child tasks (AFTER dependencies) auto-resume when parent executes
-- But we can explicitly resume them as well for clarity
-- ALTER TASK FINOPS_TASK_CALCULATE_CHARGEBACK RESUME;
-- ALTER TASK FINOPS_TASK_CHECK_BUDGETS RESUME;
-- ALTER TASK FINOPS_TASK_CLASSIFY_BI_TOOLS RESUME;
-- ALTER TASK FINOPS_TASK_SEND_NOTIFICATIONS RESUME;


-- =========================================================================
-- VERIFICATION QUERIES
-- =========================================================================

/*
-- Verify: Task definitions
SHOW TASKS IN SCHEMA FINOPS_CONTROL_DB.PROCEDURES;

-- Verify: Task status and schedule
SELECT
    NAME,
    STATE,
    SCHEDULE,
    WAREHOUSE,
    PREDECESSOR,
    CONDITION,
    CREATED_ON,
    LAST_COMMITTED_ON
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
    SCHEDULED_TIME_RANGE_START => DATEADD(DAY, -7, CURRENT_TIMESTAMP()),
    RESULT_LIMIT => 100
))
ORDER BY SCHEDULED_TIME DESC;

-- Verify: Task execution history
SELECT
    NAME,
    STATE,
    SCHEDULED_TIME,
    COMPLETED_TIME,
    QUERY_START_TIME,
    RETURN_VALUE,
    ERROR_CODE,
    ERROR_MESSAGE
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
    TASK_NAME => 'FINOPS_TASK_COLLECT_WAREHOUSE_COSTS',
    SCHEDULED_TIME_RANGE_START => DATEADD(DAY, -1, CURRENT_TIMESTAMP())
))
ORDER BY SCHEDULED_TIME DESC;

-- Verify: Task graph (dependencies)
SELECT
    NAME,
    STATE,
    SCHEDULE,
    PREDECESSOR
FROM FINOPS_CONTROL_DB.INFORMATION_SCHEMA.TASKS
WHERE DATABASE_NAME = 'FINOPS_CONTROL_DB'
  AND SCHEMA_NAME = 'PROCEDURES'
ORDER BY PREDECESSOR NULLS FIRST, NAME;
*/


-- =========================================================================
-- TASK MANAGEMENT COMMANDS (for reference)
-- =========================================================================

/*
-- Suspend a task (stop execution)
ALTER TASK FINOPS_TASK_COLLECT_WAREHOUSE_COSTS SUSPEND;

-- Resume a task (start execution)
ALTER TASK FINOPS_TASK_COLLECT_WAREHOUSE_COSTS RESUME;

-- Execute a task immediately (for testing)
EXECUTE TASK FINOPS_TASK_COLLECT_WAREHOUSE_COSTS;

-- View task runs
SELECT * FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY())
WHERE NAME = 'FINOPS_TASK_COLLECT_WAREHOUSE_COSTS'
ORDER BY SCHEDULED_TIME DESC
LIMIT 10;

-- Drop a task
DROP TASK IF EXISTS FINOPS_TASK_COLLECT_WAREHOUSE_COSTS;
*/


/*
=============================================================================
  BEST PRACTICES:

  1. TASK SCHEDULING:
     - Schedule tasks during low-usage hours (e.g., 1-5 AM)
     - Stagger tasks to avoid warehouse contention
     - Use AFTER dependencies for sequential operations

  2. ERROR HANDLING:
     - Set TASK_AUTO_RETRY_ATTEMPTS = 3 at account level
     - Monitor TASK_HISTORY for failures
     - Set up alerts for failed tasks

  3. WAREHOUSE SIZING:
     - Use dedicated warehouse for tasks (FINOPS_WH_ETL)
     - Size based on data volume: SMALL for most tasks
     - Enable auto-suspend (5 minutes)

  4. COST OPTIMIZATION:
     - Group tasks to minimize warehouse start/stop cycles
     - Use AFTER dependencies instead of fixed schedules when possible
     - Monitor task execution costs in WAREHOUSE_METERING_HISTORY

  5. MONITORING:
     - Check TASK_HISTORY daily for failures
     - Review execution times to optimize schedules
     - Set up budget alerts for task warehouse costs

  OBJECTS CREATED:
    - FINOPS_TASK_COLLECT_WAREHOUSE_COSTS (hourly)
    - FINOPS_TASK_COLLECT_QUERY_COSTS (hourly)
    - FINOPS_TASK_COLLECT_STORAGE_COSTS (daily)
    - FINOPS_TASK_CALCULATE_CHARGEBACK (daily)
    - FINOPS_TASK_CHECK_BUDGETS (daily)
    - FINOPS_TASK_CLASSIFY_BI_TOOLS (daily)
    - FINOPS_TASK_GENERATE_RECOMMENDATIONS (weekly)
    - FINOPS_TASK_SEND_NOTIFICATIONS (daily)

  NEXT STEPS:
    → Script 02: Task monitoring views and health checks
    → Test end-to-end execution: cost collection → attribution → alerts
=============================================================================
*/

-- ===========================================================================
-- ===========================================================================
-- 02_TASK_MONITORING
-- ===========================================================================
-- ===========================================================================


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



/*
#############################################################################
  MODULE 08 COMPLETE!

  Objects Created:
    - Tasks: TASK_COLLECT_WAREHOUSE_COSTS, TASK_COLLECT_QUERY_COSTS, TASK_COLLECT_STORAGE_COSTS
    - Tasks: TASK_CHECK_BUDGETS, TASK_GENERATE_RECOMMENDATIONS
    - Views: VW_TASK_EXECUTION_HISTORY, VW_TASK_ERRORS

  Next: FINOPS - Module 09 (COMPLETE - ALL MODULES DONE!)
#############################################################################
*/
