/*
=============================================================================
  MODULE 03 : CONFIG TABLES & METADATA DESIGN
  SCRIPT 01 : Ingestion Config Table (The Heart of the Framework)
=============================================================================
  SNOWBRIX ACADEMY — Metadata-Driven Ingestion Framework (MDF)

  LEARNING OBJECTIVES:
    1. Design the master ingestion config table
    2. Understand why metadata-driven > hardcoded
    3. Learn each config field and when to use it
    4. Insert sample configurations for different source types

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

  The INGESTION_CONFIG table is the single source of truth for:
    - What to load (source files)
    - Where to load it (target tables)
    - How to load it (file format, copy options)
    - When to load it (schedule, frequency)
    - Whether to load it (is_active flag)
=============================================================================
*/

USE ROLE MDF_ADMIN;
USE DATABASE MDF_CONTROL_DB;
USE SCHEMA CONFIG;
USE WAREHOUSE MDF_ADMIN_WH;

-- =========================================================================
-- THE MASTER INGESTION CONFIG TABLE
-- Every data source that the framework ingests has exactly one row here.
-- =========================================================================
CREATE OR REPLACE TABLE INGESTION_CONFIG (
    -- Primary key
    CONFIG_ID               NUMBER AUTOINCREMENT PRIMARY KEY,

    -- Source identification
    SOURCE_NAME             VARCHAR(200)    NOT NULL,       -- Unique name: 'CLIENT_A_SALES_CSV'
    SOURCE_DESCRIPTION      VARCHAR(1000),                  -- Human-readable description
    CLIENT_NAME             VARCHAR(100)    NOT NULL,       -- Client identifier: 'CLIENT_A'
    SOURCE_SYSTEM           VARCHAR(100),                   -- Origin system: 'SAP', 'SALESFORCE', 'API'
    SOURCE_TYPE             VARCHAR(50)     NOT NULL,       -- 'CSV', 'JSON', 'PARQUET', 'AVRO', 'ORC'

    -- Stage configuration
    STAGE_NAME              VARCHAR(500)    NOT NULL,       -- Full stage path: '@MDF_CONTROL_DB.CONFIG.MDF_STG_INTERNAL_CSV'
    FILE_PATTERN            VARCHAR(500),                   -- Regex pattern: '.*sales.*[.]csv'
    SUB_DIRECTORY           VARCHAR(500),                   -- Sub-folder in stage: 'client_a/sales/'

    -- File format
    FILE_FORMAT_NAME        VARCHAR(500)    NOT NULL,       -- Full FF name: 'MDF_CONTROL_DB.CONFIG.MDF_FF_CSV_STANDARD'

    -- Target configuration
    TARGET_DATABASE         VARCHAR(200)    NOT NULL,       -- 'MDF_RAW_DB'
    TARGET_SCHEMA           VARCHAR(200)    NOT NULL,       -- 'CLIENT_A_SALES'
    TARGET_TABLE            VARCHAR(200)    NOT NULL,       -- 'SALES_TRANSACTIONS'
    AUTO_CREATE_TARGET      BOOLEAN         DEFAULT TRUE,   -- Auto-create schema/table if not exists

    -- Load behavior
    LOAD_TYPE               VARCHAR(50)     DEFAULT 'APPEND',  -- 'APPEND', 'TRUNCATE_RELOAD', 'MERGE'
    ON_ERROR                VARCHAR(100)    DEFAULT 'CONTINUE', -- 'CONTINUE', 'SKIP_FILE', 'ABORT_STATEMENT'
    SIZE_LIMIT              NUMBER,                         -- Max bytes to load per execution (NULL = no limit)
    PURGE_FILES             BOOLEAN         DEFAULT FALSE,  -- Delete files from stage after successful load
    FORCE_RELOAD            BOOLEAN         DEFAULT FALSE,  -- Re-load files even if already loaded
    MATCH_BY_COLUMN_NAME    VARCHAR(20)     DEFAULT 'NONE', -- 'NONE', 'CASE_INSENSITIVE', 'CASE_SENSITIVE'

    -- Copy options (JSON for flexibility)
    COPY_OPTIONS            VARIANT,                        -- Additional COPY INTO options as JSON

    -- Semi-structured specific
    FLATTEN_PATH            VARCHAR(500),                   -- JSONPath for nested data: 'data.records'
    FLATTEN_OUTER           BOOLEAN         DEFAULT FALSE,  -- OUTER => TRUE for LATERAL FLATTEN

    -- Scheduling
    IS_ACTIVE               BOOLEAN         DEFAULT TRUE,   -- Master on/off switch
    LOAD_FREQUENCY          VARCHAR(50)     DEFAULT 'DAILY',-- 'HOURLY', 'DAILY', 'WEEKLY', 'MONTHLY', 'ON_DEMAND'
    CRON_EXPRESSION         VARCHAR(100),                   -- Cron schedule: 'USING CRON 0 6 * * * America/New_York'
    LOAD_PRIORITY           NUMBER          DEFAULT 100,    -- Lower number = higher priority (1-999)

    -- Data quality
    ENABLE_VALIDATION       BOOLEAN         DEFAULT TRUE,   -- Run post-load validation
    ROW_COUNT_THRESHOLD     NUMBER,                         -- Alert if rows < threshold
    NULL_CHECK_COLUMNS      VARCHAR(2000),                  -- Comma-separated columns that should never be NULL

    -- Schema evolution
    ENABLE_SCHEMA_EVOLUTION BOOLEAN         DEFAULT FALSE,  -- Allow schema changes automatically
    SCHEMA_EVOLUTION_MODE   VARCHAR(50)     DEFAULT 'ADD_COLUMNS', -- 'ADD_COLUMNS', 'FULL_EVOLUTION'

    -- Notification
    NOTIFY_ON_SUCCESS       BOOLEAN         DEFAULT FALSE,
    NOTIFY_ON_FAILURE       BOOLEAN         DEFAULT TRUE,
    NOTIFICATION_CHANNEL    VARCHAR(200),                   -- Email, Slack webhook, etc.

    -- Metadata
    TAGS                    VARIANT,                        -- Custom tags as JSON: {"domain":"sales","tier":"gold"}
    CREATED_BY              VARCHAR(200)    DEFAULT CURRENT_USER(),
    CREATED_AT              TIMESTAMP_LTZ   DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_BY              VARCHAR(200),
    UPDATED_AT              TIMESTAMP_LTZ,

    -- Constraints
    CONSTRAINT UQ_SOURCE_NAME UNIQUE (SOURCE_NAME)
);

-- Add a useful comment
COMMENT ON TABLE INGESTION_CONFIG IS
    'Master config table for the MDF ingestion framework. One row per data source. All ingestion behavior is driven by this table.';


-- =========================================================================
-- SAMPLE CONFIGURATIONS
-- These are example entries showing different source types.
-- =========================================================================

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
    'DEMO',
    'ERP',
    'CSV',
    '@MDF_CONTROL_DB.CONFIG.MDF_STG_INTERNAL_CSV',
    '.*customers.*[.]csv',
    'demo/customers/',
    'MDF_CONTROL_DB.CONFIG.MDF_FF_CSV_STANDARD',
    'MDF_RAW_DB',
    'DEMO_ERP',
    'RAW_CUSTOMERS',
    'APPEND',
    'CONTINUE',
    'DAILY',
    10,
    TRUE,
    'CUSTOMER_ID,CUSTOMER_NAME',
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
    'DEMO',
    'ERP',
    'CSV',
    '@MDF_CONTROL_DB.CONFIG.MDF_STG_INTERNAL_CSV',
    '.*orders.*[.]csv',
    'demo/orders/',
    'MDF_CONTROL_DB.CONFIG.MDF_FF_CSV_STANDARD',
    'MDF_RAW_DB',
    'DEMO_ERP',
    'RAW_ORDERS',
    'APPEND',
    'CONTINUE',
    'DAILY',
    20,
    TRUE,
    100,
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
    'DEMO',
    'ERP',
    'CSV',
    '@MDF_CONTROL_DB.CONFIG.MDF_STG_INTERNAL_CSV',
    '.*products.*[.]csv',
    'demo/products/',
    'MDF_CONTROL_DB.CONFIG.MDF_FF_CSV_STANDARD',
    'MDF_RAW_DB',
    'DEMO_ERP',
    'RAW_PRODUCTS',
    'TRUNCATE_RELOAD',
    'CONTINUE',
    'WEEKLY',
    50,
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
    'DEMO',
    'WEB_ANALYTICS',
    'JSON',
    '@MDF_CONTROL_DB.CONFIG.MDF_STG_INTERNAL_JSON',
    '.*events.*[.]json',
    'demo/events/',
    'MDF_CONTROL_DB.CONFIG.MDF_FF_JSON_STANDARD',
    'MDF_RAW_DB',
    'DEMO_WEB',
    'RAW_EVENTS',
    'APPEND',
    'SKIP_FILE',
    'HOURLY',
    5,
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
    'DEMO',
    'IOT_PLATFORM',
    'PARQUET',
    '@MDF_CONTROL_DB.CONFIG.MDF_STG_INTERNAL_PARQUET',
    '.*sensors.*[.]parquet',
    'demo/sensors/',
    'MDF_CONTROL_DB.CONFIG.MDF_FF_PARQUET_STANDARD',
    'MDF_RAW_DB',
    'DEMO_IOT',
    'RAW_SENSOR_READINGS',
    'APPEND',
    'CONTINUE',
    'HOURLY',
    15,
    'CASE_INSENSITIVE',
    TRUE,
    PARSE_JSON('{"domain":"iot","tier":"bronze","volume":"very_high"}')
);


-- =========================================================================
-- VERIFICATION QUERIES
-- =========================================================================

-- View all configured sources
SELECT
    CONFIG_ID,
    SOURCE_NAME,
    CLIENT_NAME,
    SOURCE_TYPE,
    TARGET_DATABASE || '.' || TARGET_SCHEMA || '.' || TARGET_TABLE AS TARGET_PATH,
    LOAD_TYPE,
    LOAD_FREQUENCY,
    IS_ACTIVE,
    LOAD_PRIORITY
FROM INGESTION_CONFIG
ORDER BY LOAD_PRIORITY;

-- View sources by client
SELECT
    CLIENT_NAME,
    COUNT(*) AS SOURCE_COUNT,
    LISTAGG(DISTINCT SOURCE_TYPE, ', ') AS DATA_TYPES,
    LISTAGG(DISTINCT LOAD_FREQUENCY, ', ') AS FREQUENCIES
FROM INGESTION_CONFIG
GROUP BY CLIENT_NAME;

-- View active sources ready for ingestion
SELECT SOURCE_NAME, SOURCE_TYPE, LOAD_FREQUENCY
FROM INGESTION_CONFIG
WHERE IS_ACTIVE = TRUE
ORDER BY LOAD_PRIORITY;


/*
=============================================================================
  BEST PRACTICES & TIPS:

  1. SOURCE_NAME IS YOUR PRIMARY KEY (logically): Make it descriptive
     and follow a pattern: {CLIENT}_{ENTITY}_{FORMAT}
     e.g., ACME_SALES_CSV, ACME_EVENTS_JSON

  2. LOAD_TYPE MATTERS:
     - APPEND: New files add to existing data (most common for incremental)
     - TRUNCATE_RELOAD: Wipe and reload (for small dimension tables)
     - MERGE: Upsert based on key columns (advanced, Module 10)

  3. ON_ERROR STRATEGY:
     - CONTINUE: Skip bad rows, load good rows (best for large files)
     - SKIP_FILE: Skip the entire file if ANY row fails
     - ABORT_STATEMENT: Stop everything on first error (strictest)

  4. COPY_OPTIONS AS VARIANT: This JSON field allows source-specific COPY
     options without adding new columns. Example:
     {"RETURN_FAILED_ONLY": true, "ENFORCE_LENGTH": false}

  5. TAGS FOR GOVERNANCE: The TAGS VARIANT column lets you tag sources
     with arbitrary metadata (domain, tier, PII flag, etc.) that can be
     used for filtering, reporting, and access control.

  WHAT'S NEXT:
  → Module 03, Script 02: Audit Log & Supporting Tables
=============================================================================
*/
