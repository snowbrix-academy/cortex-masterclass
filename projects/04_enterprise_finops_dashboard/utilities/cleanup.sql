/*
=============================================================================
  UTILITIES : CLEANUP — Remove All FinOps Framework Objects
=============================================================================
  SNOWBRIX ACADEMY — Enterprise FinOps Dashboard for Snowflake

  ⚠️  WARNING: This script will DROP ALL FinOps framework objects from your
               Snowflake account. This action is IRREVERSIBLE.

  What will be dropped:
    - Databases: FINOPS_CONTROL_DB, FINOPS_ANALYTICS_DB
    - Warehouses: FINOPS_WH_ADMIN, FINOPS_WH_ETL, FINOPS_WH_REPORTING
    - Roles: FINOPS_ADMIN_ROLE, FINOPS_ANALYST_ROLE, FINOPS_TEAM_LEAD_ROLE,
             FINOPS_EXECUTIVE_ROLE
    - Resource Monitor: FINOPS_FRAMEWORK_MONITOR

  BEFORE RUNNING:
    1. Backup any custom configuration or data if needed
    2. Ensure you have ACCOUNTADMIN role access
    3. Review the list of objects to be dropped below

  EXECUTION TIME: ~2 minutes

=============================================================================
*/

USE ROLE ACCOUNTADMIN;

-- =============================================
-- STEP 1: CONFIRM CLEANUP
-- =============================================
SELECT '⚠️  WARNING: You are about to DROP ALL FinOps framework objects' AS WARNING;
SELECT 'This action is IRREVERSIBLE. Press Ctrl+C to cancel.' AS INSTRUCTION;
SELECT 'Wait 10 seconds, then proceed if you are sure.' AS DELAY;


-- =============================================
-- STEP 2: SUSPEND ALL TASKS (Prevent execution during cleanup)
-- =============================================
SELECT '⏸️  Suspending all tasks...' AS STATUS;

ALTER TASK IF EXISTS FINOPS_CONTROL_DB.PROCEDURES.TASK_COLLECT_WAREHOUSE_COSTS SUSPEND;
ALTER TASK IF EXISTS FINOPS_CONTROL_DB.PROCEDURES.TASK_COLLECT_QUERY_COSTS SUSPEND;
ALTER TASK IF EXISTS FINOPS_CONTROL_DB.PROCEDURES.TASK_COLLECT_STORAGE_COSTS SUSPEND;
ALTER TASK IF EXISTS FINOPS_CONTROL_DB.PROCEDURES.TASK_CALCULATE_CHARGEBACK SUSPEND;
ALTER TASK IF EXISTS FINOPS_CONTROL_DB.PROCEDURES.TASK_CHECK_BUDGETS SUSPEND;
ALTER TASK IF EXISTS FINOPS_CONTROL_DB.PROCEDURES.TASK_DETECT_ANOMALIES SUSPEND;
ALTER TASK IF EXISTS FINOPS_CONTROL_DB.PROCEDURES.TASK_GENERATE_RECOMMENDATIONS SUSPEND;

SELECT 'Tasks suspended' AS STATUS;


-- =============================================
-- STEP 3: DROP DATABASES
-- =============================================
SELECT '🗑️  Dropping databases...' AS STATUS;

DROP DATABASE IF EXISTS FINOPS_CONTROL_DB CASCADE;
DROP DATABASE IF EXISTS FINOPS_ANALYTICS_DB CASCADE;

SELECT 'Databases dropped' AS STATUS;


-- =============================================
-- STEP 4: DROP WAREHOUSES
-- =============================================
SELECT '🗑️  Dropping warehouses...' AS STATUS;

DROP WAREHOUSE IF EXISTS FINOPS_WH_ADMIN;
DROP WAREHOUSE IF EXISTS FINOPS_WH_ETL;
DROP WAREHOUSE IF EXISTS FINOPS_WH_REPORTING;

SELECT 'Warehouses dropped' AS STATUS;


-- =============================================
-- STEP 5: DROP RESOURCE MONITOR
-- =============================================
SELECT '🗑️  Dropping resource monitor...' AS STATUS;

DROP RESOURCE MONITOR IF EXISTS FINOPS_FRAMEWORK_MONITOR;

SELECT 'Resource monitor dropped' AS STATUS;


-- =============================================
-- STEP 6: DROP ROLES
-- Note: Must drop in reverse hierarchy order (child roles first)
-- =============================================
SELECT '🗑️  Dropping roles...' AS STATUS;

-- Revoke role grants first
REVOKE ROLE FINOPS_ANALYST_ROLE FROM ROLE FINOPS_ADMIN_ROLE;
REVOKE ROLE FINOPS_TEAM_LEAD_ROLE FROM ROLE FINOPS_ADMIN_ROLE;
REVOKE ROLE FINOPS_EXECUTIVE_ROLE FROM ROLE FINOPS_ADMIN_ROLE;
REVOKE ROLE FINOPS_ADMIN_ROLE FROM ROLE SYSADMIN;

-- Drop roles
DROP ROLE IF EXISTS FINOPS_ANALYST_ROLE;
DROP ROLE IF EXISTS FINOPS_TEAM_LEAD_ROLE;
DROP ROLE IF EXISTS FINOPS_EXECUTIVE_ROLE;
DROP ROLE IF EXISTS FINOPS_ADMIN_ROLE;

SELECT 'Roles dropped' AS STATUS;


-- =============================================
-- STEP 7: VERIFY CLEANUP
-- =============================================
SELECT '✅ Verifying cleanup...' AS STATUS;

-- Check databases
SELECT 'Remaining FinOps Databases:' AS CHECK_TYPE,
       COUNT(*) AS COUNT
FROM SNOWFLAKE.INFORMATION_SCHEMA.DATABASES
WHERE DATABASE_NAME LIKE 'FINOPS_%';

-- Check warehouses
SELECT 'Remaining FinOps Warehouses:' AS CHECK_TYPE,
       COUNT(*) AS COUNT
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSES
WHERE NAME LIKE 'FINOPS_%'
    AND DELETED IS NULL;

-- Check roles
SELECT 'Remaining FinOps Roles:' AS CHECK_TYPE,
       COUNT(*) AS COUNT
FROM SNOWFLAKE.ACCOUNT_USAGE.ROLES
WHERE NAME LIKE 'FINOPS_%'
    AND DELETED_ON IS NULL;

-- Check resource monitors
SELECT 'Remaining FinOps Resource Monitors:' AS CHECK_TYPE,
       COUNT(*) AS COUNT
FROM SNOWFLAKE.ACCOUNT_USAGE.RESOURCE_MONITORS
WHERE NAME LIKE 'FINOPS_%'
    AND END_TIME IS NULL;


-- =============================================
-- CLEANUP COMPLETE
-- =============================================
SELECT '✅ CLEANUP COMPLETE' AS STATUS;
SELECT 'All FinOps framework objects have been removed' AS MESSAGE;

SELECT 'To reinstall the framework, run: utilities/quick_start.sql' AS REINSTALL_INFO;


/*
=============================================================================
  POST-CLEANUP NOTES:

  1. If any objects show COUNT > 0 in verification queries:
     - Wait 1-2 minutes for metadata cache to refresh
     - Re-run verification queries
     - If still present, manually drop using appropriate DROP command

  2. Costs from before cleanup remain in your Snowflake account history:
     - ACCOUNT_USAGE views (WAREHOUSE_METERING_HISTORY, QUERY_HISTORY, etc.)
     - Snowflake invoice
     - These are not affected by this cleanup

  3. If you need to preserve cost data before cleanup:
     - Export tables from FINOPS_CONTROL_DB.COST_DATA to CSV
     - Store in external location (S3, Azure Blob, etc.)
     - Can reimport after framework reinstall

  4. Cleanup does NOT affect:
     - Your production warehouses (non-FINOPS_WH_*)
     - Your production databases
     - Your user accounts
     - Your existing roles (except FINOPS_* roles)

=============================================================================
*/
