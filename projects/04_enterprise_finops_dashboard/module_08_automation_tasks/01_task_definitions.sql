/*
=============================================================================
  MODULE 08 : AUTOMATION WITH TASKS
  SCRIPT 01 : Task Definitions and Scheduling
=============================================================================
  SNOWBRIX ACADEMY — Enterprise FinOps Dashboard for Snowflake

  LEARNING OBJECTIVES:
    1. Create Snowflake Tasks for automated cost collection
    2. Build task dependency chains (DAGs)
    3. Schedule tasks for optimal execution
    4. Implement error handling and monitoring

  TASK EXECUTION FLOW:
  ┌──────────────────────────────────────────────────────────────┐
  │  ROOT TASK: FINOPS_TASK_ROOT (Daily at 2 AM UTC)            │
  │    ├── Collect warehouse costs (hourly)                      │
  │    ├── Collect query costs (hourly)                          │
  │    ├── Collect storage costs (daily)                         │
  │    ├── Calculate chargeback (daily, after cost collection)   │
  │    ├── Check budgets (daily, after chargeback)               │
  │    ├── Classify BI tools (daily)                             │
  │    ├── Generate recommendations (weekly)                      │
  │    └── Send alert notifications (daily)                      │
  └──────────────────────────────────────────────────────────────┘

  PREREQUISITES:
    - All previous modules completed
    - All stored procedures created and tested

  ESTIMATED TIME: 20 minutes

=============================================================================
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
