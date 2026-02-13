/*
=============================================================================
  UTILITIES : CLEANUP & TEARDOWN
  Removes all MDF framework objects. Use for lab reset or environment cleanup.
  WARNING: This DROPS all databases, warehouses, and roles.
=============================================================================
*/

-- =========================================================================
-- STEP 1: SUSPEND ALL TASKS (Must be done before dropping)
-- =========================================================================
USE ROLE MDF_ADMIN;

ALTER TASK IF EXISTS MDF_CONTROL_DB.PROCEDURES.MDF_TASK_ROOT SUSPEND;
ALTER TASK IF EXISTS MDF_CONTROL_DB.PROCEDURES.MDF_TASK_INGEST_CSV SUSPEND;
ALTER TASK IF EXISTS MDF_CONTROL_DB.PROCEDURES.MDF_TASK_INGEST_JSON SUSPEND;
ALTER TASK IF EXISTS MDF_CONTROL_DB.PROCEDURES.MDF_TASK_RETRY SUSPEND;
ALTER TASK IF EXISTS MDF_CONTROL_DB.PROCEDURES.MDF_TASK_HOURLY_INGEST SUSPEND;
ALTER TASK IF EXISTS MDF_CONTROL_DB.PROCEDURES.MDF_TASK_PROCESS_CONFIG_CHANGES SUSPEND;

-- =========================================================================
-- STEP 2: DROP DATABASES (Cascades to all objects within)
-- =========================================================================
USE ROLE ACCOUNTADMIN;

DROP DATABASE IF EXISTS MDF_CONTROL_DB;
DROP DATABASE IF EXISTS MDF_RAW_DB;
DROP DATABASE IF EXISTS MDF_STAGING_DB;
DROP DATABASE IF EXISTS MDF_CURATED_DB;

-- =========================================================================
-- STEP 3: DROP WAREHOUSES
-- =========================================================================
DROP WAREHOUSE IF EXISTS MDF_INGESTION_WH;
DROP WAREHOUSE IF EXISTS MDF_TRANSFORM_WH;
DROP WAREHOUSE IF EXISTS MDF_MONITORING_WH;
DROP WAREHOUSE IF EXISTS MDF_ADMIN_WH;

-- =========================================================================
-- STEP 4: DROP RESOURCE MONITORS
-- =========================================================================
DROP RESOURCE MONITOR IF EXISTS MDF_INGESTION_MONITOR;
DROP RESOURCE MONITOR IF EXISTS MDF_TRANSFORM_MONITOR;

-- =========================================================================
-- STEP 5: DROP ROLES
-- =========================================================================
USE ROLE SECURITYADMIN;

DROP ROLE IF EXISTS MDF_READER;
DROP ROLE IF EXISTS MDF_LOADER;
DROP ROLE IF EXISTS MDF_TRANSFORMER;
DROP ROLE IF EXISTS MDF_DEVELOPER;
DROP ROLE IF EXISTS MDF_ADMIN;

-- =========================================================================
-- VERIFICATION
-- =========================================================================
SHOW DATABASES LIKE 'MDF_%';
SHOW WAREHOUSES LIKE 'MDF_%';
SHOW ROLES LIKE 'MDF_%';
