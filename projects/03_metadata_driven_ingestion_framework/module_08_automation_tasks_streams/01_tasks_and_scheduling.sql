/*
=============================================================================
  MODULE 08 : AUTOMATION WITH TASKS & STREAMS
  SCRIPT 01 : Scheduled Tasks & Task Trees
=============================================================================
  SNOWBRIX ACADEMY — Metadata-Driven Ingestion Framework (MDF)

  LEARNING OBJECTIVES:
    1. Create Snowflake Tasks for scheduled ingestion
    2. Build task trees (parent → child dependencies)
    3. Use CRON expressions for flexible scheduling
    4. Monitor task execution history
    5. Understand Streams for CDC (Change Data Capture)

  AUTOMATION ARCHITECTURE:
  ┌──────────────────────────────────────────────────────────────┐
  │                                                              │
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
  │                                                              │
  └──────────────────────────────────────────────────────────────┘

  CRON EXPRESSION REFERENCE:
    ┌────── minute (0-59)
    │ ┌──── hour (0-23)
    │ │ ┌── day of month (1-31)
    │ │ │ ┌ month (1-12)
    │ │ │ │ ┌ day of week (0-6, 0=Sun)
    │ │ │ │ │
    * * * * *

    Examples:
    0 6 * * *        → Every day at 6:00 AM
    0 */2 * * *      → Every 2 hours
    0 6 * * 1-5      → Weekdays at 6:00 AM
    0 0 1 * *        → First day of every month at midnight
=============================================================================
*/

USE ROLE MDF_ADMIN;
USE DATABASE MDF_CONTROL_DB;
USE SCHEMA PROCEDURES;
USE WAREHOUSE MDF_ADMIN_WH;


-- =========================================================================
-- STEP 1: ROOT TASK (The Scheduler)
-- This is the parent task that triggers on a schedule.
-- It doesn't do any work itself — it just starts the chain.
-- =========================================================================
CREATE OR REPLACE TASK MDF_CONTROL_DB.PROCEDURES.MDF_TASK_ROOT
    WAREHOUSE = MDF_ADMIN_WH
    SCHEDULE  = 'USING CRON 0 6 * * * America/New_York'   -- Daily at 6 AM ET
    COMMENT   = 'MDF Root Task: Triggers daily ingestion pipeline'
AS
    -- Root task just logs that a run was initiated
    SELECT 'MDF Ingestion Pipeline Started at ' || CURRENT_TIMESTAMP()::VARCHAR AS STATUS;


-- =========================================================================
-- STEP 2: CSV INGESTION TASK (Child of Root)
-- Processes ALL active CSV sources.
-- =========================================================================
CREATE OR REPLACE TASK MDF_CONTROL_DB.PROCEDURES.MDF_TASK_INGEST_CSV
    WAREHOUSE = MDF_INGESTION_WH
    AFTER MDF_CONTROL_DB.PROCEDURES.MDF_TASK_ROOT
    COMMENT   = 'MDF: Ingest all active CSV sources'
AS
    CALL MDF_CONTROL_DB.PROCEDURES.SP_GENERIC_INGESTION('ALL', FALSE);


-- =========================================================================
-- STEP 3: JSON INGESTION TASK (Child of Root)
-- Runs in parallel with CSV task (both are children of root).
-- =========================================================================
CREATE OR REPLACE TASK MDF_CONTROL_DB.PROCEDURES.MDF_TASK_INGEST_JSON
    WAREHOUSE = MDF_INGESTION_WH
    AFTER MDF_CONTROL_DB.PROCEDURES.MDF_TASK_ROOT
    COMMENT   = 'MDF: Ingest all active JSON sources'
AS
    CALL MDF_CONTROL_DB.PROCEDURES.SP_GENERIC_INGESTION('ALL', FALSE);


-- =========================================================================
-- STEP 4: RETRY FAILED LOADS TASK
-- Runs after ingestion tasks complete. Retries any failures.
-- =========================================================================
CREATE OR REPLACE TASK MDF_CONTROL_DB.PROCEDURES.MDF_TASK_RETRY
    WAREHOUSE = MDF_ADMIN_WH
    AFTER MDF_CONTROL_DB.PROCEDURES.MDF_TASK_INGEST_CSV,
          MDF_CONTROL_DB.PROCEDURES.MDF_TASK_INGEST_JSON
    COMMENT   = 'MDF: Retry any failed loads from this run'
AS
    CALL MDF_CONTROL_DB.PROCEDURES.SP_RETRY_FAILED_LOADS(2, 3);


-- =========================================================================
-- STEP 5: HOURLY TASK (For High-Frequency Sources)
-- Some sources (e.g., event streams) need hourly loading.
-- =========================================================================
CREATE OR REPLACE TASK MDF_CONTROL_DB.PROCEDURES.MDF_TASK_HOURLY_INGEST
    WAREHOUSE = MDF_INGESTION_WH
    SCHEDULE  = 'USING CRON 0 * * * * America/New_York'    -- Every hour
    COMMENT   = 'MDF: Hourly ingestion for high-frequency sources'
    -- Only run if there are active hourly sources
    WHEN SYSTEM$STREAM_HAS_DATA('MDF_CONTROL_DB.CONFIG.MDF_CONFIG_STREAM') -- or use a condition
AS
    -- Process only HOURLY frequency sources
    -- This is a simplified version — in production, filter by LOAD_FREQUENCY
    SELECT 'Hourly ingestion check at ' || CURRENT_TIMESTAMP()::VARCHAR AS STATUS;


-- =========================================================================
-- STEP 6: STREAMS FOR CHANGE DATA CAPTURE (CDC)
-- Streams track changes to a table, enabling event-driven processing.
-- =========================================================================

-- Create a stream on the config table to detect new source registrations
CREATE OR REPLACE STREAM MDF_CONTROL_DB.CONFIG.MDF_CONFIG_STREAM
    ON TABLE MDF_CONTROL_DB.CONFIG.INGESTION_CONFIG
    SHOW_INITIAL_ROWS = FALSE
    COMMENT = 'Stream to detect new/modified ingestion configurations';

-- Create a stream on audit log to detect failures for alerting
CREATE OR REPLACE STREAM MDF_CONTROL_DB.AUDIT.MDF_AUDIT_STREAM
    ON TABLE MDF_CONTROL_DB.AUDIT.INGESTION_AUDIT_LOG
    SHOW_INITIAL_ROWS = FALSE
    COMMENT = 'Stream to detect new audit log entries for alerting';


-- =========================================================================
-- STEP 7: TASK TO PROCESS CONFIG CHANGES
-- When someone registers a new source via SP_REGISTER_SOURCE,
-- this task detects the change and can auto-create target objects.
-- =========================================================================
CREATE OR REPLACE TASK MDF_CONTROL_DB.PROCEDURES.MDF_TASK_PROCESS_CONFIG_CHANGES
    WAREHOUSE = MDF_ADMIN_WH
    SCHEDULE  = '5 MINUTE'               -- Check every 5 minutes
    COMMENT   = 'MDF: Process new/modified ingestion configurations'
    WHEN SYSTEM$STREAM_HAS_DATA('MDF_CONTROL_DB.CONFIG.MDF_CONFIG_STREAM')
AS
    -- Consume the stream (any SELECT from it advances the offset)
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


-- =========================================================================
-- TASK MANAGEMENT COMMANDS
-- =========================================================================

-- IMPORTANT: Tasks are created in SUSPENDED state by default.
-- You must explicitly resume them to start scheduling.

-- Resume the entire task tree (start from leaf tasks, then parent)
ALTER TASK MDF_CONTROL_DB.PROCEDURES.MDF_TASK_RETRY RESUME;
ALTER TASK MDF_CONTROL_DB.PROCEDURES.MDF_TASK_INGEST_CSV RESUME;
ALTER TASK MDF_CONTROL_DB.PROCEDURES.MDF_TASK_INGEST_JSON RESUME;
ALTER TASK MDF_CONTROL_DB.PROCEDURES.MDF_TASK_ROOT RESUME;

-- PAUSE: Suspend the task tree (start from root, then children)
-- ALTER TASK MDF_CONTROL_DB.PROCEDURES.MDF_TASK_ROOT SUSPEND;
-- ALTER TASK MDF_CONTROL_DB.PROCEDURES.MDF_TASK_INGEST_CSV SUSPEND;
-- ALTER TASK MDF_CONTROL_DB.PROCEDURES.MDF_TASK_INGEST_JSON SUSPEND;
-- ALTER TASK MDF_CONTROL_DB.PROCEDURES.MDF_TASK_RETRY SUSPEND;

-- Manual trigger (for testing — runs the root task immediately)
-- EXECUTE TASK MDF_CONTROL_DB.PROCEDURES.MDF_TASK_ROOT;


-- =========================================================================
-- MONITORING TASKS
-- =========================================================================

-- View all MDF tasks and their state
SHOW TASKS IN SCHEMA MDF_CONTROL_DB.PROCEDURES;

-- Task execution history (last 24 hours)
SELECT
    NAME,
    STATE,
    SCHEDULED_TIME,
    COMPLETED_TIME,
    DATEDIFF('SECOND', SCHEDULED_TIME, COMPLETED_TIME) AS DURATION_SECONDS,
    ERROR_CODE,
    ERROR_MESSAGE
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
    SCHEDULED_TIME_RANGE_START => DATEADD(HOUR, -24, CURRENT_TIMESTAMP()),
    RESULT_LIMIT => 50
))
WHERE NAME LIKE 'MDF_%'
ORDER BY SCHEDULED_TIME DESC;

-- Task dependency tree
SELECT
    NAME,
    SCHEDULE,
    PREDECESSORS,
    STATE,
    COMMENT
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
WHERE NAME LIKE 'MDF_%';

-- Stream data check
SELECT SYSTEM$STREAM_HAS_DATA('MDF_CONTROL_DB.CONFIG.MDF_CONFIG_STREAM') AS HAS_NEW_CONFIGS;


/*
=============================================================================
  BEST PRACTICES & TIPS:

  1. TASK TREE ORDER: When resuming, start with LEAF tasks first, then
     move to parents. When suspending, start with ROOT first.

  2. SERVERLESS TASKS: Consider using serverless tasks (no warehouse)
     for lightweight operations. They scale automatically and can be
     more cost-effective for simple SQL tasks.

  3. STREAM CONSUMPTION: Reading from a stream advances its offset.
     Once consumed, those rows won't appear again. Make sure your
     consuming logic handles all rows or you'll lose change events.

  4. TASK TIMEOUTS: By default, tasks timeout at 60 minutes. For large
     ingestion jobs, set USER_TASK_TIMEOUT_MS higher.

  5. CRON vs INTERVAL: Use CRON for fixed schedules (6 AM daily).
     Use interval (e.g., '60 MINUTE') for relative schedules.
     CRON is better for production because it's timezone-aware.

  MODULE 08 COMPLETE!
  → Next: Module 09 — Monitoring & Dashboard Views
=============================================================================
*/
