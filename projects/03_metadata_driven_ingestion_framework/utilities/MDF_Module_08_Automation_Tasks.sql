/*
#############################################################################
  MDF - Module 08: Automation with Tasks & Streams
  CONSOLIDATED WORKSHEET — Snowsight / VS Code Ready
#############################################################################
  SNOWBRIX ACADEMY — Metadata-Driven Ingestion Framework (MDF)

  This worksheet contains:
    - Task tree creation (root → child → grandchild)
    - CRON scheduling for daily and hourly ingestion
    - Streams for CDC (Change Data Capture)
    - Task management commands (resume, suspend, execute)

  AUTOMATION ARCHITECTURE:
  ┌──────────────────────────────────────────────────────────────┐
  │  MDF_TASK_ROOT (Parent - Cron Schedule)                      │
  │       │                                                      │
  │       ├── MDF_TASK_INGEST_CSV  (Child - CSV Sources)         │
  │       │       │                                              │
  │       │       └── MDF_TASK_VALIDATE_CSV (Grandchild)         │
  │       │                                                      │
  │       ├── MDF_TASK_INGEST_JSON (Child - JSON Sources)        │
  │       │       │                                              │
  │       │       └── MDF_TASK_VALIDATE_JSON (Grandchild)        │
  │       │                                                      │
  │       └── MDF_TASK_CLEANUP (Child - Post-load cleanup)       │
  └──────────────────────────────────────────────────────────────┘

  CRON EXPRESSION REFERENCE:
    ┌────── minute (0-59)
    │ ┌──── hour (0-23)
    │ │ ┌── day of month (1-31)
    │ │ │ ┌ month (1-12)
    │ │ │ │ ┌ day of week (0-6, 0=Sun)
    * * * * *

  INSTRUCTIONS:
    - Requires Modules 01-07 to be completed first
    - Tasks are created SUSPENDED — resume when ready
    - Estimated time: ~15 minutes

  PREREQUISITES:
    - Modules 01-07 completed
    - MDF_ADMIN role access
#############################################################################
*/

USE ROLE MDF_ADMIN;
USE DATABASE MDF_CONTROL_DB;
USE SCHEMA PROCEDURES;
USE WAREHOUSE MDF_ADMIN_WH;


-- ===========================================================================
-- STEP 1: ROOT TASK (The Scheduler)
-- ===========================================================================

CREATE OR REPLACE TASK MDF_CONTROL_DB.PROCEDURES.MDF_TASK_ROOT
    WAREHOUSE = MDF_ADMIN_WH
    SCHEDULE  = 'USING CRON 0 6 * * * America/New_York'
    COMMENT   = 'MDF Root Task: Triggers daily ingestion pipeline'
AS
    SELECT 'MDF Ingestion Pipeline Started at ' || CURRENT_TIMESTAMP()::VARCHAR AS STATUS;


-- ===========================================================================
-- STEP 2: CSV INGESTION TASK (Child of Root)
-- ===========================================================================

CREATE OR REPLACE TASK MDF_CONTROL_DB.PROCEDURES.MDF_TASK_INGEST_CSV
    WAREHOUSE = MDF_INGESTION_WH
    AFTER MDF_CONTROL_DB.PROCEDURES.MDF_TASK_ROOT
    COMMENT   = 'MDF: Ingest all active CSV sources'
AS
    CALL MDF_CONTROL_DB.PROCEDURES.SP_GENERIC_INGESTION('ALL', FALSE);


-- ===========================================================================
-- STEP 3: JSON INGESTION TASK (Child of Root — parallel with CSV)
-- ===========================================================================

CREATE OR REPLACE TASK MDF_CONTROL_DB.PROCEDURES.MDF_TASK_INGEST_JSON
    WAREHOUSE = MDF_INGESTION_WH
    AFTER MDF_CONTROL_DB.PROCEDURES.MDF_TASK_ROOT
    COMMENT   = 'MDF: Ingest all active JSON sources'
AS
    CALL MDF_CONTROL_DB.PROCEDURES.SP_GENERIC_INGESTION('ALL', FALSE);


-- ===========================================================================
-- STEP 4: RETRY FAILED LOADS TASK
-- ===========================================================================

CREATE OR REPLACE TASK MDF_CONTROL_DB.PROCEDURES.MDF_TASK_RETRY
    WAREHOUSE = MDF_ADMIN_WH
    AFTER MDF_CONTROL_DB.PROCEDURES.MDF_TASK_INGEST_CSV,
          MDF_CONTROL_DB.PROCEDURES.MDF_TASK_INGEST_JSON
    COMMENT   = 'MDF: Retry any failed loads from this run'
AS
    CALL MDF_CONTROL_DB.PROCEDURES.SP_RETRY_FAILED_LOADS(2, 3);


-- ===========================================================================
-- STEP 5: HOURLY TASK (For High-Frequency Sources)
-- ===========================================================================

CREATE OR REPLACE TASK MDF_CONTROL_DB.PROCEDURES.MDF_TASK_HOURLY_INGEST
    WAREHOUSE = MDF_INGESTION_WH
    SCHEDULE  = 'USING CRON 0 * * * * America/New_York'
    COMMENT   = 'MDF: Hourly ingestion for high-frequency sources'
    WHEN SYSTEM$STREAM_HAS_DATA('MDF_CONTROL_DB.CONFIG.MDF_CONFIG_STREAM')
AS
    SELECT 'Hourly ingestion check at ' || CURRENT_TIMESTAMP()::VARCHAR AS STATUS;


-- ===========================================================================
-- STEP 6: STREAMS FOR CHANGE DATA CAPTURE (CDC)
-- ===========================================================================

CREATE OR REPLACE STREAM MDF_CONTROL_DB.CONFIG.MDF_CONFIG_STREAM
    ON TABLE MDF_CONTROL_DB.CONFIG.INGESTION_CONFIG
    SHOW_INITIAL_ROWS = FALSE
    COMMENT = 'Stream to detect new/modified ingestion configurations';

CREATE OR REPLACE STREAM MDF_CONTROL_DB.AUDIT.MDF_AUDIT_STREAM
    ON TABLE MDF_CONTROL_DB.AUDIT.INGESTION_AUDIT_LOG
    SHOW_INITIAL_ROWS = FALSE
    COMMENT = 'Stream to detect new audit log entries for alerting';


-- ===========================================================================
-- STEP 7: TASK TO PROCESS CONFIG CHANGES
-- ===========================================================================

CREATE OR REPLACE TASK MDF_CONTROL_DB.PROCEDURES.MDF_TASK_PROCESS_CONFIG_CHANGES
    WAREHOUSE = MDF_ADMIN_WH
    SCHEDULE  = '5 MINUTE'
    COMMENT   = 'MDF: Process new/modified ingestion configurations'
    WHEN SYSTEM$STREAM_HAS_DATA('MDF_CONTROL_DB.CONFIG.MDF_CONFIG_STREAM')
AS
    INSERT INTO MDF_CONTROL_DB.AUDIT.INGESTION_AUDIT_LOG (
        BATCH_ID, CONFIG_ID, SOURCE_NAME, RUN_STATUS, START_TIME
    )
    SELECT
        UUID_STRING(),
        CONFIG_ID,
        SOURCE_NAME,
        'CONFIG_CHANGE_DETECTED',
        CURRENT_TIMESTAMP()
    FROM MDF_CONTROL_DB.CONFIG.MDF_CONFIG_STREAM
    WHERE METADATA$ACTION = 'INSERT';


-- ===========================================================================
-- TASK MANAGEMENT: RESUME
-- ===========================================================================

-- Resume the entire task tree (leaf tasks first, then parent)
ALTER TASK MDF_CONTROL_DB.PROCEDURES.MDF_TASK_RETRY RESUME;
ALTER TASK MDF_CONTROL_DB.PROCEDURES.MDF_TASK_INGEST_CSV RESUME;
ALTER TASK MDF_CONTROL_DB.PROCEDURES.MDF_TASK_INGEST_JSON RESUME;
ALTER TASK MDF_CONTROL_DB.PROCEDURES.MDF_TASK_ROOT RESUME;

-- SUSPEND: (start from root, then children)
-- ALTER TASK MDF_CONTROL_DB.PROCEDURES.MDF_TASK_ROOT SUSPEND;
-- ALTER TASK MDF_CONTROL_DB.PROCEDURES.MDF_TASK_INGEST_CSV SUSPEND;
-- ALTER TASK MDF_CONTROL_DB.PROCEDURES.MDF_TASK_INGEST_JSON SUSPEND;
-- ALTER TASK MDF_CONTROL_DB.PROCEDURES.MDF_TASK_RETRY SUSPEND;

-- Manual trigger (for testing)
-- EXECUTE TASK MDF_CONTROL_DB.PROCEDURES.MDF_TASK_ROOT;


-- ===========================================================================
-- MONITORING TASKS
-- ===========================================================================

SHOW TASKS IN SCHEMA MDF_CONTROL_DB.PROCEDURES;

-- Task execution history (last 24 hours)
SELECT
    NAME, STATE, SCHEDULED_TIME, COMPLETED_TIME,
    DATEDIFF('SECOND', SCHEDULED_TIME, COMPLETED_TIME) AS DURATION_SECONDS,
    ERROR_CODE, ERROR_MESSAGE
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
    SCHEDULED_TIME_RANGE_START => DATEADD(HOUR, -24, CURRENT_TIMESTAMP()),
    RESULT_LIMIT => 50
))
WHERE NAME LIKE 'MDF_%'
ORDER BY SCHEDULED_TIME DESC;

-- Stream data check
SELECT SYSTEM$STREAM_HAS_DATA('MDF_CONTROL_DB.CONFIG.MDF_CONFIG_STREAM') AS HAS_NEW_CONFIGS;


/*
#############################################################################
  MODULE 08 COMPLETE!

  Objects Created:
    - MDF_TASK_ROOT (daily at 6 AM ET)
    - MDF_TASK_INGEST_CSV (child of root)
    - MDF_TASK_INGEST_JSON (child of root, parallel with CSV)
    - MDF_TASK_RETRY (runs after both ingestion tasks)
    - MDF_TASK_HOURLY_INGEST (hourly, stream-triggered)
    - MDF_TASK_PROCESS_CONFIG_CHANGES (5-min, stream-triggered)
    - MDF_CONFIG_STREAM (CDC on INGESTION_CONFIG)
    - MDF_AUDIT_STREAM (CDC on INGESTION_AUDIT_LOG)

  Next: MDF - Module 09 (Monitoring & Dashboards)
#############################################################################
*/
