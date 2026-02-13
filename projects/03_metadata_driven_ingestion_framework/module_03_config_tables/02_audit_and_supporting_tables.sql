/*
=============================================================================
  MODULE 03 : CONFIG TABLES & METADATA DESIGN
  SCRIPT 02 : Audit Log & Supporting Config Tables
=============================================================================
  SNOWBRIX ACADEMY — Metadata-Driven Ingestion Framework (MDF)

  LEARNING OBJECTIVES:
    1. Design the ingestion audit log table (the "black box recorder")
    2. Create the file format registry for dynamic format lookup
    3. Create the stage registry for dynamic stage management
    4. Create the notification config table
    5. Understand how these tables work together

  HOW THE TABLES RELATE:
  ┌─────────────────────────────────────────────────────────────┐
  │                                                             │
  │  INGESTION_CONFIG ──→ drives ──→ SP_GENERIC_INGESTION       │
  │       │                              │                      │
  │       ├── references ──→ FILE_FORMAT_REGISTRY               │
  │       ├── references ──→ STAGE_REGISTRY                     │
  │       └── references ──→ NOTIFICATION_CONFIG                │
  │                                                             │
  │  SP_GENERIC_INGESTION ──→ writes ──→ INGESTION_AUDIT_LOG    │
  │                                                             │
  └─────────────────────────────────────────────────────────────┘
=============================================================================
*/

USE ROLE MDF_ADMIN;
USE DATABASE MDF_CONTROL_DB;
USE SCHEMA AUDIT;
USE WAREHOUSE MDF_ADMIN_WH;

-- =========================================================================
-- TABLE 1: INGESTION AUDIT LOG
-- Every single ingestion run creates a record here.
-- This is your "black box recorder" — when something goes wrong (and it
-- will), this table tells you exactly what happened and when.
-- =========================================================================
CREATE OR REPLACE TABLE INGESTION_AUDIT_LOG (
    -- Identifiers
    AUDIT_ID                NUMBER AUTOINCREMENT PRIMARY KEY,
    BATCH_ID                VARCHAR(100)    NOT NULL,       -- UUID for this run: groups related loads
    CONFIG_ID               NUMBER          NOT NULL,       -- FK to INGESTION_CONFIG
    SOURCE_NAME             VARCHAR(200)    NOT NULL,       -- Denormalized for easy querying

    -- Execution details
    RUN_STATUS              VARCHAR(50)     NOT NULL,       -- 'STARTED', 'SUCCESS', 'PARTIAL_SUCCESS', 'FAILED', 'SKIPPED'
    START_TIME              TIMESTAMP_LTZ   NOT NULL,
    END_TIME                TIMESTAMP_LTZ,
    DURATION_SECONDS        NUMBER,                         -- Computed: END_TIME - START_TIME

    -- Load metrics
    FILES_PROCESSED         NUMBER          DEFAULT 0,
    FILES_SKIPPED           NUMBER          DEFAULT 0,
    FILES_FAILED            NUMBER          DEFAULT 0,
    ROWS_LOADED             NUMBER          DEFAULT 0,
    ROWS_FAILED             NUMBER          DEFAULT 0,
    BYTES_LOADED            NUMBER          DEFAULT 0,

    -- Error details
    ERROR_CODE              VARCHAR(50),
    ERROR_MESSAGE           VARCHAR(10000),
    ERROR_DETAILS           VARIANT,                        -- Full error context as JSON

    -- Copy command details
    COPY_COMMAND_EXECUTED   VARCHAR(10000),                  -- The actual COPY INTO statement
    COPY_RESULT             VARIANT,                        -- Full COPY INTO result as JSON

    -- File details
    FILES_LIST              VARIANT,                        -- Array of file names processed

    -- Validation results
    VALIDATION_STATUS       VARCHAR(50),                    -- 'PASSED', 'FAILED', 'SKIPPED'
    VALIDATION_DETAILS      VARIANT,                        -- Validation check results

    -- Environment
    WAREHOUSE_USED          VARCHAR(200),
    WAREHOUSE_SIZE          VARCHAR(20),
    EXECUTED_BY             VARCHAR(200)    DEFAULT CURRENT_USER(),
    SESSION_ID              NUMBER          DEFAULT CURRENT_SESSION(),

    -- Metadata
    CREATED_AT              TIMESTAMP_LTZ   DEFAULT CURRENT_TIMESTAMP()
);

-- Indexes for common query patterns
-- (Snowflake uses micro-partitions, but clustering keys help with pruning)
ALTER TABLE INGESTION_AUDIT_LOG CLUSTER BY (CREATED_AT, SOURCE_NAME);

COMMENT ON TABLE INGESTION_AUDIT_LOG IS
    'Audit trail for all ingestion runs. Every execution of the framework logs here. This is the primary debugging and monitoring table.';


-- =========================================================================
-- TABLE 2: INGESTION ERROR LOG
-- Detailed error records for individual file/row failures.
-- Separate from audit log to avoid bloating the main audit table.
-- =========================================================================
CREATE OR REPLACE TABLE INGESTION_ERROR_LOG (
    ERROR_LOG_ID            NUMBER AUTOINCREMENT PRIMARY KEY,
    BATCH_ID                VARCHAR(100)    NOT NULL,       -- Links to INGESTION_AUDIT_LOG
    CONFIG_ID               NUMBER          NOT NULL,
    SOURCE_NAME             VARCHAR(200)    NOT NULL,

    -- Error context
    FILE_NAME               VARCHAR(1000),
    ROW_NUMBER              NUMBER,
    COLUMN_NAME             VARCHAR(200),

    -- Error details
    ERROR_CODE              VARCHAR(50),
    ERROR_MESSAGE           VARCHAR(10000),
    REJECTED_RECORD         VARCHAR(10000),                 -- The actual bad row (for debugging)

    -- Metadata
    CREATED_AT              TIMESTAMP_LTZ   DEFAULT CURRENT_TIMESTAMP()
);

ALTER TABLE INGESTION_ERROR_LOG CLUSTER BY (CREATED_AT, SOURCE_NAME);

COMMENT ON TABLE INGESTION_ERROR_LOG IS
    'Detailed error log for individual row/file failures. Use this for debugging specific data quality issues.';


-- =========================================================================
-- Now switch to CONFIG schema for registry tables
-- =========================================================================
USE SCHEMA CONFIG;

-- =========================================================================
-- TABLE 3: FILE FORMAT REGISTRY
-- A metadata layer on top of Snowflake file format objects.
-- This lets you query file format info without SHOW commands.
-- =========================================================================
CREATE OR REPLACE TABLE FILE_FORMAT_REGISTRY (
    FORMAT_ID               NUMBER AUTOINCREMENT PRIMARY KEY,
    FORMAT_NAME             VARCHAR(200)    NOT NULL,       -- Matches the Snowflake file format name
    FORMAT_FULL_NAME        VARCHAR(500)    NOT NULL,       -- Fully qualified: DB.SCHEMA.FF_NAME
    FORMAT_TYPE             VARCHAR(50)     NOT NULL,       -- 'CSV', 'JSON', 'PARQUET', 'AVRO', 'ORC'
    FORMAT_DESCRIPTION      VARCHAR(1000),
    FORMAT_OPTIONS          VARIANT,                        -- Key options as JSON for reference
    IS_ACTIVE               BOOLEAN         DEFAULT TRUE,
    CREATED_BY              VARCHAR(200)    DEFAULT CURRENT_USER(),
    CREATED_AT              TIMESTAMP_LTZ   DEFAULT CURRENT_TIMESTAMP(),

    CONSTRAINT UQ_FORMAT_NAME UNIQUE (FORMAT_NAME)
);

-- Populate with our file formats
INSERT INTO FILE_FORMAT_REGISTRY (FORMAT_NAME, FORMAT_FULL_NAME, FORMAT_TYPE, FORMAT_DESCRIPTION, FORMAT_OPTIONS) VALUES
    ('MDF_FF_CSV_STANDARD',    'MDF_CONTROL_DB.CONFIG.MDF_FF_CSV_STANDARD',    'CSV',     'Standard CSV with headers, comma-delimited',    PARSE_JSON('{"delimiter":",","skip_header":1,"enclosed_by":"\\\""}') ),
    ('MDF_FF_CSV_PIPE',        'MDF_CONTROL_DB.CONFIG.MDF_FF_CSV_PIPE',        'CSV',     'Pipe-delimited CSV with headers',                PARSE_JSON('{"delimiter":"|","skip_header":1}') ),
    ('MDF_FF_CSV_TAB',         'MDF_CONTROL_DB.CONFIG.MDF_FF_CSV_TAB',         'CSV',     'Tab-delimited CSV (TSV)',                        PARSE_JSON('{"delimiter":"\\t","skip_header":1}') ),
    ('MDF_FF_CSV_NO_HEADER',   'MDF_CONTROL_DB.CONFIG.MDF_FF_CSV_NO_HEADER',   'CSV',     'CSV without header row',                         PARSE_JSON('{"delimiter":",","skip_header":0}') ),
    ('MDF_FF_JSON_STANDARD',   'MDF_CONTROL_DB.CONFIG.MDF_FF_JSON_STANDARD',   'JSON',    'Standard JSON with outer array stripping',        PARSE_JSON('{"strip_outer_array":true}') ),
    ('MDF_FF_JSON_NDJSON',     'MDF_CONTROL_DB.CONFIG.MDF_FF_JSON_NDJSON',     'JSON',    'Newline-delimited JSON',                         PARSE_JSON('{"strip_outer_array":false}') ),
    ('MDF_FF_JSON_COMPACT',    'MDF_CONTROL_DB.CONFIG.MDF_FF_JSON_COMPACT',    'JSON',    'Compact JSON with null stripping',                PARSE_JSON('{"strip_outer_array":true,"strip_null_values":true}') ),
    ('MDF_FF_PARQUET_STANDARD','MDF_CONTROL_DB.CONFIG.MDF_FF_PARQUET_STANDARD','PARQUET', 'Standard Parquet with Snappy compression',        PARSE_JSON('{"snappy_compression":true}') ),
    ('MDF_FF_AVRO_STANDARD',   'MDF_CONTROL_DB.CONFIG.MDF_FF_AVRO_STANDARD',   'AVRO',    'Standard Avro format',                           PARSE_JSON('{"compression":"auto"}') ),
    ('MDF_FF_ORC_STANDARD',    'MDF_CONTROL_DB.CONFIG.MDF_FF_ORC_STANDARD',    'ORC',     'Standard ORC format',                            PARSE_JSON('{}') );


-- =========================================================================
-- TABLE 4: STAGE REGISTRY
-- Tracks all stages used by the framework.
-- =========================================================================
CREATE OR REPLACE TABLE STAGE_REGISTRY (
    STAGE_ID                NUMBER AUTOINCREMENT PRIMARY KEY,
    STAGE_NAME              VARCHAR(200)    NOT NULL,       -- Short name
    STAGE_FULL_NAME         VARCHAR(500)    NOT NULL,       -- Fully qualified with @
    STAGE_TYPE              VARCHAR(50)     NOT NULL,       -- 'INTERNAL', 'EXTERNAL_S3', 'EXTERNAL_AZURE', 'EXTERNAL_GCS'
    CLOUD_PROVIDER          VARCHAR(50),                    -- 'AWS', 'AZURE', 'GCP', NULL for internal
    STORAGE_INTEGRATION     VARCHAR(200),                   -- Storage integration name (external only)
    BASE_URL                VARCHAR(1000),                  -- Cloud storage URL (external only)
    STAGE_DESCRIPTION       VARCHAR(1000),
    IS_ACTIVE               BOOLEAN         DEFAULT TRUE,
    CREATED_BY              VARCHAR(200)    DEFAULT CURRENT_USER(),
    CREATED_AT              TIMESTAMP_LTZ   DEFAULT CURRENT_TIMESTAMP(),

    CONSTRAINT UQ_STAGE_NAME UNIQUE (STAGE_NAME)
);

-- Populate with our stages
INSERT INTO STAGE_REGISTRY (STAGE_NAME, STAGE_FULL_NAME, STAGE_TYPE, STAGE_DESCRIPTION) VALUES
    ('MDF_STG_INTERNAL_DEV',     '@MDF_CONTROL_DB.CONFIG.MDF_STG_INTERNAL_DEV',     'INTERNAL', 'Development/testing internal stage'),
    ('MDF_STG_INTERNAL_CSV',     '@MDF_CONTROL_DB.CONFIG.MDF_STG_INTERNAL_CSV',     'INTERNAL', 'Internal stage for CSV files'),
    ('MDF_STG_INTERNAL_JSON',    '@MDF_CONTROL_DB.CONFIG.MDF_STG_INTERNAL_JSON',    'INTERNAL', 'Internal stage for JSON files'),
    ('MDF_STG_INTERNAL_PARQUET', '@MDF_CONTROL_DB.CONFIG.MDF_STG_INTERNAL_PARQUET', 'INTERNAL', 'Internal stage for Parquet files');


-- =========================================================================
-- TABLE 5: NOTIFICATION CONFIG
-- Configures alerting for ingestion events.
-- =========================================================================
CREATE OR REPLACE TABLE NOTIFICATION_CONFIG (
    NOTIFICATION_ID         NUMBER AUTOINCREMENT PRIMARY KEY,
    NOTIFICATION_NAME       VARCHAR(200)    NOT NULL,
    NOTIFICATION_TYPE       VARCHAR(50)     NOT NULL,       -- 'EMAIL', 'SLACK_WEBHOOK', 'TEAMS_WEBHOOK', 'SNOWFLAKE_ALERT'
    NOTIFICATION_TARGET     VARCHAR(1000)   NOT NULL,       -- Email address or webhook URL
    NOTIFICATION_DESCRIPTION VARCHAR(500),
    IS_ACTIVE               BOOLEAN         DEFAULT TRUE,
    NOTIFY_ON_SUCCESS       BOOLEAN         DEFAULT FALSE,
    NOTIFY_ON_FAILURE       BOOLEAN         DEFAULT TRUE,
    NOTIFY_ON_WARNING       BOOLEAN         DEFAULT TRUE,
    MIN_SEVERITY            VARCHAR(20)     DEFAULT 'WARNING', -- 'INFO', 'WARNING', 'ERROR', 'CRITICAL'
    CREATED_BY              VARCHAR(200)    DEFAULT CURRENT_USER(),
    CREATED_AT              TIMESTAMP_LTZ   DEFAULT CURRENT_TIMESTAMP()
);

-- Sample notification configs
INSERT INTO NOTIFICATION_CONFIG (
    NOTIFICATION_NAME, NOTIFICATION_TYPE, NOTIFICATION_TARGET,
    NOTIFICATION_DESCRIPTION, NOTIFY_ON_SUCCESS, NOTIFY_ON_FAILURE
) VALUES
    ('MDF_ADMIN_EMAIL', 'EMAIL', 'admin@example.com',
     'Admin email for critical alerts', FALSE, TRUE),
    ('MDF_SLACK_ALERTS', 'SLACK_WEBHOOK', 'https://hooks.slack.com/services/xxx/yyy/zzz',
     'Slack channel for ingestion alerts', FALSE, TRUE);


-- =========================================================================
-- TABLE 6: SCHEMA EVOLUTION CONFIG
-- Rules for handling schema changes per source.
-- =========================================================================
CREATE OR REPLACE TABLE SCHEMA_EVOLUTION_CONFIG (
    EVOLUTION_ID            NUMBER AUTOINCREMENT PRIMARY KEY,
    CONFIG_ID               NUMBER          NOT NULL,       -- FK to INGESTION_CONFIG
    SOURCE_NAME             VARCHAR(200)    NOT NULL,
    EVOLUTION_MODE          VARCHAR(50)     NOT NULL DEFAULT 'ADD_COLUMNS',
    -- 'ADD_COLUMNS'       → Only add new columns, never remove
    -- 'FULL_EVOLUTION'    → Add/modify columns (dangerous in prod)
    -- 'SNAPSHOT'          → Keep old schema, create new version
    AUTO_APPLY              BOOLEAN         DEFAULT FALSE,  -- Auto-apply or require approval
    NOTIFY_ON_CHANGE        BOOLEAN         DEFAULT TRUE,
    MAX_NEW_COLUMNS         NUMBER          DEFAULT 10,     -- Safety: max columns to add in one run
    ALLOWED_TYPE_CHANGES    VARIANT,                        -- JSON: {"NUMBER":"VARCHAR","DATE":"TIMESTAMP"}
    LAST_SCHEMA_HASH        VARCHAR(500),                   -- Hash of last known schema
    LAST_CHECKED_AT         TIMESTAMP_LTZ,
    CREATED_AT              TIMESTAMP_LTZ   DEFAULT CURRENT_TIMESTAMP()
);


-- =========================================================================
-- VERIFICATION QUERIES
-- =========================================================================

-- Audit log structure
DESCRIBE TABLE MDF_CONTROL_DB.AUDIT.INGESTION_AUDIT_LOG;

-- Config table record count
SELECT 'INGESTION_CONFIG'      AS TABLE_NAME, COUNT(*) AS ROWS FROM MDF_CONTROL_DB.CONFIG.INGESTION_CONFIG
UNION ALL
SELECT 'FILE_FORMAT_REGISTRY', COUNT(*) FROM MDF_CONTROL_DB.CONFIG.FILE_FORMAT_REGISTRY
UNION ALL
SELECT 'STAGE_REGISTRY',       COUNT(*) FROM MDF_CONTROL_DB.CONFIG.STAGE_REGISTRY
UNION ALL
SELECT 'NOTIFICATION_CONFIG',  COUNT(*) FROM MDF_CONTROL_DB.CONFIG.NOTIFICATION_CONFIG;

-- View all source configs with their file format and stage details
SELECT
    ic.SOURCE_NAME,
    ic.CLIENT_NAME,
    ic.SOURCE_TYPE,
    ffr.FORMAT_DESCRIPTION,
    sr.STAGE_TYPE,
    ic.TARGET_DATABASE || '.' || ic.TARGET_SCHEMA || '.' || ic.TARGET_TABLE AS TARGET,
    ic.LOAD_FREQUENCY,
    ic.IS_ACTIVE
FROM MDF_CONTROL_DB.CONFIG.INGESTION_CONFIG ic
LEFT JOIN MDF_CONTROL_DB.CONFIG.FILE_FORMAT_REGISTRY ffr
    ON ic.FILE_FORMAT_NAME = ffr.FORMAT_FULL_NAME
LEFT JOIN MDF_CONTROL_DB.CONFIG.STAGE_REGISTRY sr
    ON ic.STAGE_NAME = sr.STAGE_FULL_NAME
ORDER BY ic.LOAD_PRIORITY;


/*
=============================================================================
  BEST PRACTICES & TIPS:

  1. AUDIT LOG IS APPEND-ONLY: Never delete or update audit records.
     This is your compliance and debugging trail.

  2. CLUSTERING KEY ON AUDIT LOG: Clustering by (CREATED_AT, SOURCE_NAME)
     optimizes the most common query patterns: "Show me recent failures"
     and "Show me all runs for source X."

  3. SEPARATE AUDIT AND ERROR LOGS: The audit log has one row per run.
     The error log has one row per error. Keeping them separate prevents
     the audit log from growing uncontrollably when a source has bad data.

  4. REGISTRY TABLES: These seem redundant (we already have file format
     objects), but they enable SQL-based lookups. You can't easily join
     SHOW FILE FORMATS output with other tables.

  5. SCHEMA EVOLUTION CONFIG: Start with AUTO_APPLY = FALSE in production.
     Review proposed schema changes before applying them automatically.

  MODULE 03 COMPLETE!
  → Next: Module 04 — Core Ingestion Stored Procedures
=============================================================================
*/
