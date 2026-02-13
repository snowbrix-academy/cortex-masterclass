/*
#############################################################################
  MDF - Module 06: Semi-Structured Data (JSON / Parquet)
  CONSOLIDATED WORKSHEET — Snowsight / VS Code Ready
#############################################################################
  SNOWBRIX ACADEMY — Metadata-Driven Ingestion Framework (MDF)

  This worksheet contains the complete JSON Ingestion & Flattening Lab.

  KEY CONCEPT: SCHEMA-ON-READ
  ┌──────────────────────────────────────────────────────────────┐
  │  SCHEMA-ON-WRITE (CSV)         SCHEMA-ON-READ (JSON)        │
  │  ─────────────────────         ────────────────────────      │
  │  Define columns first     →    Load as VARIANT first         │
  │  Schema must match file   →    Schema is flexible            │
  │  Fail on new columns      →    New fields auto-captured      │
  │  Type conversion at load  →    Type conversion at query      │
  └──────────────────────────────────────────────────────────────┘

  INSTRUCTIONS:
    - Run each step sequentially (top to bottom)
    - Requires Modules 01-04 to be completed first
    - Upload JSON files BEFORE running Step 4
    - Estimated time: ~45 minutes

  PREREQUISITES:
    - Modules 01-04 completed
    - Sample JSON files from /sample_data/json/
    - MDF_ADMIN role access
#############################################################################
*/

USE ROLE MDF_ADMIN;
USE DATABASE MDF_CONTROL_DB;
USE WAREHOUSE MDF_INGESTION_WH;


-- ===========================================================================
-- STEP 1: CREATE TARGET TABLE FOR JSON DATA
-- ===========================================================================

CREATE SCHEMA IF NOT EXISTS MDF_RAW_DB.DEMO_WEB
    COMMENT = 'Raw data schema for DEMO client web analytics';

CREATE OR REPLACE TABLE MDF_RAW_DB.DEMO_WEB.RAW_EVENTS (
    RAW_DATA            VARIANT,
    _MDF_FILE_NAME      VARCHAR     DEFAULT METADATA$FILENAME,
    _MDF_FILE_ROW       NUMBER      DEFAULT METADATA$FILE_ROW_NUMBER,
    _MDF_LOADED_AT      TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
);


-- ===========================================================================
-- STEP 2: UPLOAD JSON FILE TO STAGE
-- ===========================================================================

/*
  Use SnowSQL:
    PUT file://C:/path/to/sample_data/json/events.json @MDF_CONTROL_DB.CONFIG.MDF_STG_INTERNAL_JSON/demo/events/ AUTO_COMPRESS=TRUE;
*/

LIST @MDF_CONTROL_DB.CONFIG.MDF_STG_INTERNAL_JSON;


-- ===========================================================================
-- STEP 3: PREVIEW RAW JSON DATA
-- ===========================================================================

SELECT $1
FROM @MDF_CONTROL_DB.CONFIG.MDF_STG_INTERNAL_JSON/demo/events/
(FILE_FORMAT => 'MDF_CONTROL_DB.CONFIG.MDF_FF_JSON_STANDARD')
LIMIT 3;


-- ===========================================================================
-- STEP 4: RUN INGESTION VIA MDF FRAMEWORK
-- ===========================================================================

CALL MDF_CONTROL_DB.PROCEDURES.SP_GENERIC_INGESTION('DEMO_EVENTS_JSON', FALSE);

SELECT
    SOURCE_NAME, RUN_STATUS, FILES_PROCESSED, ROWS_LOADED, DURATION_SECONDS
FROM MDF_CONTROL_DB.AUDIT.INGESTION_AUDIT_LOG
WHERE SOURCE_NAME = 'DEMO_EVENTS_JSON'
ORDER BY CREATED_AT DESC
LIMIT 1;


-- ===========================================================================
-- STEP 5: QUERY RAW JSON DATA
-- ===========================================================================

-- View raw data
SELECT RAW_DATA
FROM MDF_RAW_DB.DEMO_WEB.RAW_EVENTS
LIMIT 3;

-- Extract top-level fields using dot notation
SELECT
    RAW_DATA:event_id::VARCHAR       AS EVENT_ID,
    RAW_DATA:event_type::VARCHAR     AS EVENT_TYPE,
    RAW_DATA:user_id::VARCHAR        AS USER_ID,
    RAW_DATA:timestamp::TIMESTAMP    AS EVENT_TIMESTAMP,
    RAW_DATA:page_url::VARCHAR       AS PAGE_URL
FROM MDF_RAW_DB.DEMO_WEB.RAW_EVENTS
LIMIT 10;

-- Extract nested fields (device, geo)
SELECT
    RAW_DATA:event_id::VARCHAR           AS EVENT_ID,
    RAW_DATA:event_type::VARCHAR         AS EVENT_TYPE,
    RAW_DATA:device.type::VARCHAR        AS DEVICE_TYPE,
    RAW_DATA:device.os::VARCHAR          AS DEVICE_OS,
    RAW_DATA:device.browser::VARCHAR     AS DEVICE_BROWSER,
    RAW_DATA:geo.country::VARCHAR        AS COUNTRY,
    RAW_DATA:geo.state::VARCHAR          AS STATE,
    RAW_DATA:geo.city::VARCHAR           AS CITY
FROM MDF_RAW_DB.DEMO_WEB.RAW_EVENTS;

-- Extract optional/conditional fields
SELECT
    RAW_DATA:event_id::VARCHAR                   AS EVENT_ID,
    RAW_DATA:event_type::VARCHAR                 AS EVENT_TYPE,
    RAW_DATA:video_title::VARCHAR                AS VIDEO_TITLE,
    RAW_DATA:watch_time_seconds::NUMBER          AS WATCH_TIME_SECONDS,
    RAW_DATA:form_data.company_size::VARCHAR     AS COMPANY_SIZE,
    RAW_DATA:total_amount::NUMBER(12,2)          AS PURCHASE_AMOUNT,
    RAW_DATA:metadata.campaign::VARCHAR          AS CAMPAIGN
FROM MDF_RAW_DB.DEMO_WEB.RAW_EVENTS;


-- ===========================================================================
-- STEP 6: LATERAL FLATTEN — Explode Nested Arrays
-- ===========================================================================

-- Find events with nested arrays
SELECT
    RAW_DATA:event_id::VARCHAR   AS EVENT_ID,
    RAW_DATA:event_type::VARCHAR AS EVENT_TYPE,
    RAW_DATA:items               AS ITEMS_ARRAY
FROM MDF_RAW_DB.DEMO_WEB.RAW_EVENTS
WHERE RAW_DATA:items IS NOT NULL;

-- Flatten the items array
SELECT
    e.RAW_DATA:event_id::VARCHAR         AS EVENT_ID,
    e.RAW_DATA:order_id::VARCHAR         AS ORDER_ID,
    e.RAW_DATA:user_id::VARCHAR          AS USER_ID,
    f.VALUE:product_id::VARCHAR          AS PRODUCT_ID,
    f.VALUE:quantity::NUMBER             AS QUANTITY,
    f.VALUE:price::NUMBER(12,2)          AS UNIT_PRICE,
    f.VALUE:quantity::NUMBER * f.VALUE:price::NUMBER(12,2) AS LINE_TOTAL
FROM MDF_RAW_DB.DEMO_WEB.RAW_EVENTS e,
     LATERAL FLATTEN(INPUT => e.RAW_DATA:items) f
WHERE e.RAW_DATA:items IS NOT NULL;


-- ===========================================================================
-- STEP 7: CREATE FLATTENED VIEW FOR DOWNSTREAM USE
-- ===========================================================================

CREATE SCHEMA IF NOT EXISTS MDF_STAGING_DB.DEMO_WEB
    COMMENT = 'Staging schema for DEMO web analytics (flattened views)';

CREATE OR REPLACE VIEW MDF_STAGING_DB.DEMO_WEB.VW_EVENTS_FLATTENED AS
SELECT
    RAW_DATA:event_id::VARCHAR               AS EVENT_ID,
    RAW_DATA:event_type::VARCHAR             AS EVENT_TYPE,
    RAW_DATA:user_id::VARCHAR                AS USER_ID,
    RAW_DATA:session_id::VARCHAR             AS SESSION_ID,
    RAW_DATA:timestamp::TIMESTAMP_TZ         AS EVENT_TIMESTAMP,
    RAW_DATA:page_url::VARCHAR               AS PAGE_URL,
    RAW_DATA:referrer::VARCHAR               AS REFERRER,
    RAW_DATA:device.type::VARCHAR            AS DEVICE_TYPE,
    RAW_DATA:device.os::VARCHAR              AS DEVICE_OS,
    RAW_DATA:device.browser::VARCHAR         AS DEVICE_BROWSER,
    RAW_DATA:geo.country::VARCHAR            AS COUNTRY,
    RAW_DATA:geo.state::VARCHAR              AS STATE,
    RAW_DATA:geo.city::VARCHAR               AS CITY,
    RAW_DATA:metadata.campaign::VARCHAR      AS CAMPAIGN,
    RAW_DATA:metadata.medium::VARCHAR        AS MEDIUM,
    RAW_DATA:element_id::VARCHAR             AS ELEMENT_ID,
    RAW_DATA:video_id::VARCHAR               AS VIDEO_ID,
    RAW_DATA:video_title::VARCHAR            AS VIDEO_TITLE,
    RAW_DATA:watch_time_seconds::NUMBER      AS WATCH_TIME_SECONDS,
    RAW_DATA:completion_rate::FLOAT          AS COMPLETION_RATE,
    RAW_DATA:order_id::VARCHAR               AS ORDER_ID,
    RAW_DATA:total_amount::NUMBER(12,2)      AS TOTAL_AMOUNT,
    RAW_DATA:status_code::NUMBER             AS API_STATUS_CODE,
    RAW_DATA:response_time_ms::NUMBER        AS API_RESPONSE_TIME_MS,
    _MDF_FILE_NAME,
    _MDF_LOADED_AT
FROM MDF_RAW_DB.DEMO_WEB.RAW_EVENTS;

-- Query the flattened view
SELECT
    EVENT_TYPE,
    COUNT(*)                                 AS EVENT_COUNT,
    COUNT(DISTINCT USER_ID)                  AS UNIQUE_USERS,
    COUNT(DISTINCT SESSION_ID)               AS UNIQUE_SESSIONS
FROM MDF_STAGING_DB.DEMO_WEB.VW_EVENTS_FLATTENED
GROUP BY EVENT_TYPE
ORDER BY EVENT_COUNT DESC;

-- Events by country
SELECT
    COUNTRY,
    COUNT(*) AS EVENT_COUNT,
    COUNT(DISTINCT USER_ID) AS UNIQUE_USERS
FROM MDF_STAGING_DB.DEMO_WEB.VW_EVENTS_FLATTENED
GROUP BY COUNTRY
ORDER BY EVENT_COUNT DESC;

-- Device breakdown
SELECT
    DEVICE_TYPE, DEVICE_OS,
    COUNT(*) AS EVENT_COUNT
FROM MDF_STAGING_DB.DEMO_WEB.VW_EVENTS_FLATTENED
GROUP BY DEVICE_TYPE, DEVICE_OS
ORDER BY EVENT_COUNT DESC;


-- ===========================================================================
-- STEP 8: PARQUET INGESTION (Bonus)
-- ===========================================================================

/*
  Parquet is self-describing — Snowflake can infer the schema.
  The config entry DEMO_SENSORS_PARQUET handles Parquet files automatically.

  -- Upload Parquet file:
  PUT file://path/to/sensors.parquet @MDF_CONTROL_DB.CONFIG.MDF_STG_INTERNAL_PARQUET/demo/sensors/;

  -- Run ingestion:
  CALL MDF_CONTROL_DB.PROCEDURES.SP_GENERIC_INGESTION('DEMO_SENSORS_PARQUET', FALSE);
*/


/*
#############################################################################
  MODULE 06 COMPLETE!

  What You Did:
    - Loaded JSON data into VARIANT column (Schema-on-Read)
    - Queried nested JSON with dot notation
    - Used LATERAL FLATTEN to explode arrays
    - Created typed/flattened view in STAGING layer
    - Ran analytics queries on flattened data

  Next: MDF - Module 07 (Error Handling & Audit)
#############################################################################
*/
