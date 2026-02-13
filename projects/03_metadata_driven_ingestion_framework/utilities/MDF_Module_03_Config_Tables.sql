/*
#############################################################################
  MDF - Module 03: Config Tables & Metadata Design
  CONSOLIDATED WORKSHEET — Snowsight / VS Code Ready
#############################################################################
  SNOWBRIX ACADEMY — Metadata-Driven Ingestion Framework (MDF)

  This worksheet combines ALL Module 03 scripts into a single file:
    Part 1: INGESTION_CONFIG Table (The Heart of the Framework)
    Part 2: Audit Log & Supporting Config Tables

  INSTRUCTIONS:
    - Run each section sequentially (top to bottom)
    - Requires Modules 01-02 to be completed first
    - Estimated time: ~15 minutes

  PREREQUISITES:
    - Modules 01-02 completed
    - MDF_ADMIN role access
#############################################################################
*/


-- ===========================================================================
-- ███████████████████████████████████████████████████████████████████████████
-- PART 1 OF 2: INGESTION CONFIG TABLE
-- ███████████████████████████████████████████████████████████████████████████
-- ===========================================================================

/*
  WHY METADATA-DRIVEN:
  ┌──────────────────────────────────────────────────────────────┐
  │  TRADITIONAL APPROACH          METADATA-DRIVEN APPROACH      │
  │  ─────────────────────         ─────────────────────────     │
  │  1 script per source     →    1 generic procedure            │
  │  100 sources = 100 files →    100 sources = 100 config rows  │
  │  Change = edit code      →    Change = update a row          │
  │  Risk = code deployment  →    Risk = config change only      │
  │  New source = new code   →    New source = INSERT statement  │
  └──────────────────────────────────────────────────────────────┘
*/

USE ROLE MDF_ADMIN;
USE DATABASE MDF_CONTROL_DB;
USE SCHEMA CONFIG;
USE WAREHOUSE MDF_ADMIN_WH;

-- THE MASTER INGESTION CONFIG TABLE
CREATE OR REPLACE TABLE INGESTION_CONFIG (
    -- Primary key
    CONFIG_ID               NUMBER AUTOINCREMENT PRIMARY KEY,

    -- Source identification
    SOURCE_NAME             VARCHAR(200)    NOT NULL,
    SOURCE_DESCRIPTION      VARCHAR(1000),
    CLIENT_NAME             VARCHAR(100)    NOT NULL,
    SOURCE_SYSTEM           VARCHAR(100),
    SOURCE_TYPE             VARCHAR(50)     NOT NULL,

    -- Stage configuration
    STAGE_NAME              VARCHAR(500)    NOT NULL,
    FILE_PATTERN            VARCHAR(500),
    SUB_DIRECTORY           VARCHAR(500),

    -- File format
    FILE_FORMAT_NAME        VARCHAR(500)    NOT NULL,

    -- Target configuration
    TARGET_DATABASE         VARCHAR(200)    NOT NULL,
    TARGET_SCHEMA           VARCHAR(200)    NOT NULL,
    TARGET_TABLE            VARCHAR(200)    NOT NULL,
    AUTO_CREATE_TARGET      BOOLEAN         DEFAULT TRUE,

    -- Load behavior
    LOAD_TYPE               VARCHAR(50)     DEFAULT 'APPEND',
    ON_ERROR                VARCHAR(100)    DEFAULT 'CONTINUE',
    SIZE_LIMIT              NUMBER,
    PURGE_FILES             BOOLEAN         DEFAULT FALSE,
    FORCE_RELOAD            BOOLEAN         DEFAULT FALSE,
    MATCH_BY_COLUMN_NAME    VARCHAR(20)     DEFAULT 'NONE',

    -- Copy options (JSON for flexibility)
    COPY_OPTIONS            VARIANT,

    -- Semi-structured specific
    FLATTEN_PATH            VARCHAR(500),
    FLATTEN_OUTER           BOOLEAN         DEFAULT FALSE,

    -- Scheduling
    IS_ACTIVE               BOOLEAN         DEFAULT TRUE,
    LOAD_FREQUENCY          VARCHAR(50)     DEFAULT 'DAILY',
    CRON_EXPRESSION         VARCHAR(100),
    LOAD_PRIORITY           NUMBER          DEFAULT 100,

    -- Data quality
    ENABLE_VALIDATION       BOOLEAN         DEFAULT TRUE,
    ROW_COUNT_THRESHOLD     NUMBER,
    NULL_CHECK_COLUMNS      VARCHAR(2000),

    -- Schema evolution
    ENABLE_SCHEMA_EVOLUTION BOOLEAN         DEFAULT FALSE,
    SCHEMA_EVOLUTION_MODE   VARCHAR(50)     DEFAULT 'ADD_COLUMNS',

    -- Notification
    NOTIFY_ON_SUCCESS       BOOLEAN         DEFAULT FALSE,
    NOTIFY_ON_FAILURE       BOOLEAN         DEFAULT TRUE,
    NOTIFICATION_CHANNEL    VARCHAR(200),

    -- Metadata
    TAGS                    VARIANT,
    CREATED_BY              VARCHAR(200)    DEFAULT CURRENT_USER(),
    CREATED_AT              TIMESTAMP_LTZ   DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_BY              VARCHAR(200),
    UPDATED_AT              TIMESTAMP_LTZ,

    -- Constraints
    CONSTRAINT UQ_SOURCE_NAME UNIQUE (SOURCE_NAME)
);

COMMENT ON TABLE INGESTION_CONFIG IS
    'Master config table for the MDF ingestion framework. One row per data source. All ingestion behavior is driven by this table.';

-- ─── SAMPLE CONFIGURATIONS ────────────────────────────────────────────────

-- Example 1: Standard CSV file (Customers)
INSERT INTO INGESTION_CONFIG (
    SOURCE_NAME, SOURCE_DESCRIPTION, CLIENT_NAME, SOURCE_SYSTEM, SOURCE_TYPE,
    STAGE_NAME, FILE_PATTERN, SUB_DIRECTORY,
    FILE_FORMAT_NAME,
    TARGET_DATABASE, TARGET_SCHEMA, TARGET_TABLE,
    LOAD_TYPE, ON_ERROR, LOAD_FREQUENCY, LOAD_PRIORITY,
    ENABLE_VALIDATION, NULL_CHECK_COLUMNS,
    TAGS
) VALUES (
    'DEMO_CUSTOMERS_CSV',
    'Customer master data from demo ERP system',
    'DEMO', 'ERP', 'CSV',
    '@MDF_CONTROL_DB.CONFIG.MDF_STG_INTERNAL_CSV',
    '.*customers.*[.]csv', 'demo/customers/',
    'MDF_CONTROL_DB.CONFIG.MDF_FF_CSV_STANDARD',
    'MDF_RAW_DB', 'DEMO_ERP', 'RAW_CUSTOMERS',
    'APPEND', 'CONTINUE', 'DAILY', 10,
    TRUE, 'CUSTOMER_ID,CUSTOMER_NAME',
    PARSE_JSON('{"domain":"master_data","tier":"gold","pii":true}')
);

-- Example 2: Standard CSV file (Orders)
INSERT INTO INGESTION_CONFIG (
    SOURCE_NAME, SOURCE_DESCRIPTION, CLIENT_NAME, SOURCE_SYSTEM, SOURCE_TYPE,
    STAGE_NAME, FILE_PATTERN, SUB_DIRECTORY,
    FILE_FORMAT_NAME,
    TARGET_DATABASE, TARGET_SCHEMA, TARGET_TABLE,
    LOAD_TYPE, ON_ERROR, LOAD_FREQUENCY, LOAD_PRIORITY,
    ENABLE_VALIDATION, ROW_COUNT_THRESHOLD,
    TAGS
) VALUES (
    'DEMO_ORDERS_CSV',
    'Sales order transactions from demo ERP system',
    'DEMO', 'ERP', 'CSV',
    '@MDF_CONTROL_DB.CONFIG.MDF_STG_INTERNAL_CSV',
    '.*orders.*[.]csv', 'demo/orders/',
    'MDF_CONTROL_DB.CONFIG.MDF_FF_CSV_STANDARD',
    'MDF_RAW_DB', 'DEMO_ERP', 'RAW_ORDERS',
    'APPEND', 'CONTINUE', 'DAILY', 20,
    TRUE, 100,
    PARSE_JSON('{"domain":"transactions","tier":"gold"}')
);

-- Example 3: Standard CSV file (Products)
INSERT INTO INGESTION_CONFIG (
    SOURCE_NAME, SOURCE_DESCRIPTION, CLIENT_NAME, SOURCE_SYSTEM, SOURCE_TYPE,
    STAGE_NAME, FILE_PATTERN, SUB_DIRECTORY,
    FILE_FORMAT_NAME,
    TARGET_DATABASE, TARGET_SCHEMA, TARGET_TABLE,
    LOAD_TYPE, ON_ERROR, LOAD_FREQUENCY, LOAD_PRIORITY,
    TAGS
) VALUES (
    'DEMO_PRODUCTS_CSV',
    'Product catalog from demo ERP system',
    'DEMO', 'ERP', 'CSV',
    '@MDF_CONTROL_DB.CONFIG.MDF_STG_INTERNAL_CSV',
    '.*products.*[.]csv', 'demo/products/',
    'MDF_CONTROL_DB.CONFIG.MDF_FF_CSV_STANDARD',
    'MDF_RAW_DB', 'DEMO_ERP', 'RAW_PRODUCTS',
    'TRUNCATE_RELOAD', 'CONTINUE', 'WEEKLY', 50,
    PARSE_JSON('{"domain":"master_data","tier":"silver"}')
);

-- Example 4: JSON events data
INSERT INTO INGESTION_CONFIG (
    SOURCE_NAME, SOURCE_DESCRIPTION, CLIENT_NAME, SOURCE_SYSTEM, SOURCE_TYPE,
    STAGE_NAME, FILE_PATTERN, SUB_DIRECTORY,
    FILE_FORMAT_NAME,
    TARGET_DATABASE, TARGET_SCHEMA, TARGET_TABLE,
    LOAD_TYPE, ON_ERROR, LOAD_FREQUENCY, LOAD_PRIORITY,
    FLATTEN_PATH,
    TAGS
) VALUES (
    'DEMO_EVENTS_JSON',
    'Clickstream events from web analytics API',
    'DEMO', 'WEB_ANALYTICS', 'JSON',
    '@MDF_CONTROL_DB.CONFIG.MDF_STG_INTERNAL_JSON',
    '.*events.*[.]json', 'demo/events/',
    'MDF_CONTROL_DB.CONFIG.MDF_FF_JSON_STANDARD',
    'MDF_RAW_DB', 'DEMO_WEB', 'RAW_EVENTS',
    'APPEND', 'SKIP_FILE', 'HOURLY', 5,
    'events',
    PARSE_JSON('{"domain":"clickstream","tier":"bronze","volume":"high"}')
);

-- Example 5: Parquet file (IoT sensor data)
INSERT INTO INGESTION_CONFIG (
    SOURCE_NAME, SOURCE_DESCRIPTION, CLIENT_NAME, SOURCE_SYSTEM, SOURCE_TYPE,
    STAGE_NAME, FILE_PATTERN, SUB_DIRECTORY,
    FILE_FORMAT_NAME,
    TARGET_DATABASE, TARGET_SCHEMA, TARGET_TABLE,
    LOAD_TYPE, ON_ERROR, LOAD_FREQUENCY, LOAD_PRIORITY,
    MATCH_BY_COLUMN_NAME,
    ENABLE_SCHEMA_EVOLUTION,
    TAGS
) VALUES (
    'DEMO_SENSORS_PARQUET',
    'IoT sensor readings in Parquet format',
    'DEMO', 'IOT_PLATFORM', 'PARQUET',
    '@MDF_CONTROL_DB.CONFIG.MDF_STG_INTERNAL_PARQUET',
    '.*sensors.*[.]parquet', 'demo/sensors/',
    'MDF_CONTROL_DB.CONFIG.MDF_FF_PARQUET_STANDARD',
    'MDF_RAW_DB', 'DEMO_IOT', 'RAW_SENSOR_READINGS',
    'APPEND', 'CONTINUE', 'HOURLY', 15,
    'CASE_INSENSITIVE',
    TRUE,
    PARSE_JSON('{"domain":"iot","tier":"bronze","volume":"very_high"}')
);

-- VERIFICATION: Config Table
SELECT
    CONFIG_ID, SOURCE_NAME, CLIENT_NAME, SOURCE_TYPE,
    TARGET_DATABASE || '.' || TARGET_SCHEMA || '.' || TARGET_TABLE AS TARGET_PATH,
    LOAD_TYPE, LOAD_FREQUENCY, IS_ACTIVE, LOAD_PRIORITY
FROM INGESTION_CONFIG
ORDER BY LOAD_PRIORITY;


-- ===========================================================================
-- ███████████████████████████████████████████████████████████████████████████
-- PART 2 OF 2: AUDIT LOG & SUPPORTING CONFIG TABLES
-- ███████████████████████████████████████████████████████████████████████████
-- ===========================================================================

/*
  HOW THE TABLES RELATE:
  ┌─────────────────────────────────────────────────────────────┐
  │  INGESTION_CONFIG ──→ drives ──→ SP_GENERIC_INGESTION       │
  │       │                              │                      │
  │       ├── references ──→ FILE_FORMAT_REGISTRY               │
  │       ├── references ──→ STAGE_REGISTRY                     │
  │       └── references ──→ NOTIFICATION_CONFIG                │
  │                                                             │
  │  SP_GENERIC_INGESTION ──→ writes ──→ INGESTION_AUDIT_LOG    │
  └─────────────────────────────────────────────────────────────┘
*/

USE SCHEMA AUDIT;

-- TABLE 1: INGESTION AUDIT LOG
CREATE OR REPLACE TABLE INGESTION_AUDIT_LOG (
    AUDIT_ID                NUMBER AUTOINCREMENT PRIMARY KEY,
    BATCH_ID                VARCHAR(100)    NOT NULL,
    CONFIG_ID               NUMBER          NOT NULL,
    SOURCE_NAME             VARCHAR(200)    NOT NULL,
    RUN_STATUS              VARCHAR(50)     NOT NULL,
    START_TIME              TIMESTAMP_LTZ   NOT NULL,
    END_TIME                TIMESTAMP_LTZ,
    DURATION_SECONDS        NUMBER,
    FILES_PROCESSED         NUMBER          DEFAULT 0,
    FILES_SKIPPED           NUMBER          DEFAULT 0,
    FILES_FAILED            NUMBER          DEFAULT 0,
    ROWS_LOADED             NUMBER          DEFAULT 0,
    ROWS_FAILED             NUMBER          DEFAULT 0,
    BYTES_LOADED            NUMBER          DEFAULT 0,
    ERROR_CODE              VARCHAR(50),
    ERROR_MESSAGE           VARCHAR(10000),
    ERROR_DETAILS           VARIANT,
    COPY_COMMAND_EXECUTED   VARCHAR(10000),
    COPY_RESULT             VARIANT,
    FILES_LIST              VARIANT,
    VALIDATION_STATUS       VARCHAR(50),
    VALIDATION_DETAILS      VARIANT,
    WAREHOUSE_USED          VARCHAR(200),
    WAREHOUSE_SIZE          VARCHAR(20),
    EXECUTED_BY             VARCHAR(200)    DEFAULT CURRENT_USER(),
    SESSION_ID              NUMBER          DEFAULT CURRENT_SESSION(),
    CREATED_AT              TIMESTAMP_LTZ   DEFAULT CURRENT_TIMESTAMP()
);

ALTER TABLE INGESTION_AUDIT_LOG CLUSTER BY (CREATED_AT, SOURCE_NAME);

COMMENT ON TABLE INGESTION_AUDIT_LOG IS
    'Audit trail for all ingestion runs. Every execution of the framework logs here. This is the primary debugging and monitoring table.';

-- TABLE 2: INGESTION ERROR LOG
CREATE OR REPLACE TABLE INGESTION_ERROR_LOG (
    ERROR_LOG_ID            NUMBER AUTOINCREMENT PRIMARY KEY,
    BATCH_ID                VARCHAR(100)    NOT NULL,
    CONFIG_ID               NUMBER          NOT NULL,
    SOURCE_NAME             VARCHAR(200)    NOT NULL,
    FILE_NAME               VARCHAR(1000),
    ROW_NUMBER              NUMBER,
    COLUMN_NAME             VARCHAR(200),
    ERROR_CODE              VARCHAR(50),
    ERROR_MESSAGE           VARCHAR(10000),
    REJECTED_RECORD         VARCHAR(10000),
    CREATED_AT              TIMESTAMP_LTZ   DEFAULT CURRENT_TIMESTAMP()
);

ALTER TABLE INGESTION_ERROR_LOG CLUSTER BY (CREATED_AT, SOURCE_NAME);

COMMENT ON TABLE INGESTION_ERROR_LOG IS
    'Detailed error log for individual row/file failures. Use this for debugging specific data quality issues.';

-- Switch to CONFIG schema for registry tables
USE SCHEMA CONFIG;

-- TABLE 3: FILE FORMAT REGISTRY
CREATE OR REPLACE TABLE FILE_FORMAT_REGISTRY (
    FORMAT_ID               NUMBER AUTOINCREMENT PRIMARY KEY,
    FORMAT_NAME             VARCHAR(200)    NOT NULL,
    FORMAT_FULL_NAME        VARCHAR(500)    NOT NULL,
    FORMAT_TYPE             VARCHAR(50)     NOT NULL,
    FORMAT_DESCRIPTION      VARCHAR(1000),
    FORMAT_OPTIONS          VARIANT,
    IS_ACTIVE               BOOLEAN         DEFAULT TRUE,
    CREATED_BY              VARCHAR(200)    DEFAULT CURRENT_USER(),
    CREATED_AT              TIMESTAMP_LTZ   DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT UQ_FORMAT_NAME UNIQUE (FORMAT_NAME)
);

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

-- TABLE 4: STAGE REGISTRY
CREATE OR REPLACE TABLE STAGE_REGISTRY (
    STAGE_ID                NUMBER AUTOINCREMENT PRIMARY KEY,
    STAGE_NAME              VARCHAR(200)    NOT NULL,
    STAGE_FULL_NAME         VARCHAR(500)    NOT NULL,
    STAGE_TYPE              VARCHAR(50)     NOT NULL,
    CLOUD_PROVIDER          VARCHAR(50),
    STORAGE_INTEGRATION     VARCHAR(200),
    BASE_URL                VARCHAR(1000),
    STAGE_DESCRIPTION       VARCHAR(1000),
    IS_ACTIVE               BOOLEAN         DEFAULT TRUE,
    CREATED_BY              VARCHAR(200)    DEFAULT CURRENT_USER(),
    CREATED_AT              TIMESTAMP_LTZ   DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT UQ_STAGE_NAME UNIQUE (STAGE_NAME)
);

INSERT INTO STAGE_REGISTRY (STAGE_NAME, STAGE_FULL_NAME, STAGE_TYPE, STAGE_DESCRIPTION) VALUES
    ('MDF_STG_INTERNAL_DEV',     '@MDF_CONTROL_DB.CONFIG.MDF_STG_INTERNAL_DEV',     'INTERNAL', 'Development/testing internal stage'),
    ('MDF_STG_INTERNAL_CSV',     '@MDF_CONTROL_DB.CONFIG.MDF_STG_INTERNAL_CSV',     'INTERNAL', 'Internal stage for CSV files'),
    ('MDF_STG_INTERNAL_JSON',    '@MDF_CONTROL_DB.CONFIG.MDF_STG_INTERNAL_JSON',    'INTERNAL', 'Internal stage for JSON files'),
    ('MDF_STG_INTERNAL_PARQUET', '@MDF_CONTROL_DB.CONFIG.MDF_STG_INTERNAL_PARQUET', 'INTERNAL', 'Internal stage for Parquet files');

-- TABLE 5: NOTIFICATION CONFIG
CREATE OR REPLACE TABLE NOTIFICATION_CONFIG (
    NOTIFICATION_ID         NUMBER AUTOINCREMENT PRIMARY KEY,
    NOTIFICATION_NAME       VARCHAR(200)    NOT NULL,
    NOTIFICATION_TYPE       VARCHAR(50)     NOT NULL,
    NOTIFICATION_TARGET     VARCHAR(1000)   NOT NULL,
    NOTIFICATION_DESCRIPTION VARCHAR(500),
    IS_ACTIVE               BOOLEAN         DEFAULT TRUE,
    NOTIFY_ON_SUCCESS       BOOLEAN         DEFAULT FALSE,
    NOTIFY_ON_FAILURE       BOOLEAN         DEFAULT TRUE,
    NOTIFY_ON_WARNING       BOOLEAN         DEFAULT TRUE,
    MIN_SEVERITY            VARCHAR(20)     DEFAULT 'WARNING',
    CREATED_BY              VARCHAR(200)    DEFAULT CURRENT_USER(),
    CREATED_AT              TIMESTAMP_LTZ   DEFAULT CURRENT_TIMESTAMP()
);

INSERT INTO NOTIFICATION_CONFIG (
    NOTIFICATION_NAME, NOTIFICATION_TYPE, NOTIFICATION_TARGET,
    NOTIFICATION_DESCRIPTION, NOTIFY_ON_SUCCESS, NOTIFY_ON_FAILURE
) VALUES
    ('MDF_ADMIN_EMAIL', 'EMAIL', 'admin@example.com',
     'Admin email for critical alerts', FALSE, TRUE),
    ('MDF_SLACK_ALERTS', 'SLACK_WEBHOOK', 'https://hooks.slack.com/services/xxx/yyy/zzz',
     'Slack channel for ingestion alerts', FALSE, TRUE);

-- TABLE 6: SCHEMA EVOLUTION CONFIG
CREATE OR REPLACE TABLE SCHEMA_EVOLUTION_CONFIG (
    EVOLUTION_ID            NUMBER AUTOINCREMENT PRIMARY KEY,
    CONFIG_ID               NUMBER          NOT NULL,
    SOURCE_NAME             VARCHAR(200)    NOT NULL,
    EVOLUTION_MODE          VARCHAR(50)     NOT NULL DEFAULT 'ADD_COLUMNS',
    AUTO_APPLY              BOOLEAN         DEFAULT FALSE,
    NOTIFY_ON_CHANGE        BOOLEAN         DEFAULT TRUE,
    MAX_NEW_COLUMNS         NUMBER          DEFAULT 10,
    ALLOWED_TYPE_CHANGES    VARIANT,
    LAST_SCHEMA_HASH        VARCHAR(500),
    LAST_CHECKED_AT         TIMESTAMP_LTZ,
    CREATED_AT              TIMESTAMP_LTZ   DEFAULT CURRENT_TIMESTAMP()
);

-- VERIFICATION: All Tables
DESCRIBE TABLE MDF_CONTROL_DB.AUDIT.INGESTION_AUDIT_LOG;

SELECT 'INGESTION_CONFIG'      AS TABLE_NAME, COUNT(*) AS ROWS FROM MDF_CONTROL_DB.CONFIG.INGESTION_CONFIG
UNION ALL
SELECT 'FILE_FORMAT_REGISTRY', COUNT(*) FROM MDF_CONTROL_DB.CONFIG.FILE_FORMAT_REGISTRY
UNION ALL
SELECT 'STAGE_REGISTRY',       COUNT(*) FROM MDF_CONTROL_DB.CONFIG.STAGE_REGISTRY
UNION ALL
SELECT 'NOTIFICATION_CONFIG',  COUNT(*) FROM MDF_CONTROL_DB.CONFIG.NOTIFICATION_CONFIG;

SELECT
    ic.SOURCE_NAME, ic.CLIENT_NAME, ic.SOURCE_TYPE,
    ffr.FORMAT_DESCRIPTION, sr.STAGE_TYPE,
    ic.TARGET_DATABASE || '.' || ic.TARGET_SCHEMA || '.' || ic.TARGET_TABLE AS TARGET,
    ic.LOAD_FREQUENCY, ic.IS_ACTIVE
FROM MDF_CONTROL_DB.CONFIG.INGESTION_CONFIG ic
LEFT JOIN MDF_CONTROL_DB.CONFIG.FILE_FORMAT_REGISTRY ffr
    ON ic.FILE_FORMAT_NAME = ffr.FORMAT_FULL_NAME
LEFT JOIN MDF_CONTROL_DB.CONFIG.STAGE_REGISTRY sr
    ON ic.STAGE_NAME = sr.STAGE_FULL_NAME
ORDER BY ic.LOAD_PRIORITY;


/*
#############################################################################
  MODULE 03 COMPLETE!

  Objects Created:
    - INGESTION_CONFIG table (30+ columns, 5 sample rows)
    - INGESTION_AUDIT_LOG table (clustered by date + source)
    - INGESTION_ERROR_LOG table (clustered by date + source)
    - FILE_FORMAT_REGISTRY table (10 entries)
    - STAGE_REGISTRY table (4 entries)
    - NOTIFICATION_CONFIG table (2 sample entries)
    - SCHEMA_EVOLUTION_CONFIG table

  Next: MDF - Module 04 (Core Stored Procedures)
#############################################################################
*/
