/*
=============================================================================
  MODULE 06 : SEMI-STRUCTURED DATA INGESTION (JSON / Parquet)
  SCRIPT 01 : Hands-On Lab — JSON Ingestion & Flattening
=============================================================================
  SNOWBRIX ACADEMY — Metadata-Driven Ingestion Framework (MDF)

  LEARNING OBJECTIVES:
    1. Understand how Snowflake handles semi-structured data (VARIANT)
    2. Load JSON data using the MDF framework
    3. Query nested JSON using dot notation and LATERAL FLATTEN
    4. Create flattened views for downstream consumption
    5. Handle schema-on-read vs schema-on-write patterns

  LAB DURATION: ~45 minutes

  KEY CONCEPT: SCHEMA-ON-READ
  ┌──────────────────────────────────────────────────────────────┐
  │  SCHEMA-ON-WRITE (CSV)         SCHEMA-ON-READ (JSON)        │
  │  ─────────────────────         ────────────────────────      │
  │  Define columns first     →    Load as VARIANT first         │
  │  Schema must match file   →    Schema is flexible            │
  │  Fail on new columns      →    New fields auto-captured      │
  │  Type conversion at load  →    Type conversion at query      │
  │                                                              │
  │  The MDF framework supports BOTH approaches.                 │
  │  JSON uses Schema-on-Read → Load raw, flatten later.         │
  └──────────────────────────────────────────────────────────────┘
=============================================================================
*/

USE ROLE MDF_ADMIN;
USE DATABASE MDF_CONTROL_DB;
USE WAREHOUSE MDF_INGESTION_WH;


-- =========================================================================
-- LAB STEP 1: CREATE TARGET TABLE FOR JSON DATA
-- JSON data loads into a single VARIANT column.
-- This is the "Schema-on-Read" approach.
-- =========================================================================

CREATE SCHEMA IF NOT EXISTS MDF_RAW_DB.DEMO_WEB
    COMMENT = 'Raw data schema for DEMO client web analytics';

CREATE OR REPLACE TABLE MDF_RAW_DB.DEMO_WEB.RAW_EVENTS (
    RAW_DATA            VARIANT,
    _MDF_FILE_NAME      VARCHAR     DEFAULT METADATA$FILENAME,
    _MDF_FILE_ROW       NUMBER      DEFAULT METADATA$FILE_ROW_NUMBER,
    _MDF_LOADED_AT      TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
);


-- =========================================================================
-- LAB STEP 2: UPLOAD JSON FILE TO STAGE
-- Use SnowSQL:
--   PUT file://C:/path/to/sample_data/json/events.json @MDF_CONTROL_DB.CONFIG.MDF_STG_INTERNAL_JSON/demo/events/ AUTO_COMPRESS=TRUE;
-- =========================================================================

-- Verify file is in stage
LIST @MDF_CONTROL_DB.CONFIG.MDF_STG_INTERNAL_JSON;


-- =========================================================================
-- LAB STEP 3: PREVIEW RAW JSON DATA
-- =========================================================================

SELECT $1
FROM @MDF_CONTROL_DB.CONFIG.MDF_STG_INTERNAL_JSON/demo/events/
(FILE_FORMAT => 'MDF_CONTROL_DB.CONFIG.MDF_FF_JSON_STANDARD')
LIMIT 3;


-- =========================================================================
-- LAB STEP 4: RUN INGESTION VIA MDF FRAMEWORK
-- =========================================================================

-- Ingest the JSON events
CALL MDF_CONTROL_DB.PROCEDURES.SP_GENERIC_INGESTION('DEMO_EVENTS_JSON', FALSE);

-- Check results
SELECT
    SOURCE_NAME,
    RUN_STATUS,
    FILES_PROCESSED,
    ROWS_LOADED,
    DURATION_SECONDS
FROM MDF_CONTROL_DB.AUDIT.INGESTION_AUDIT_LOG
WHERE SOURCE_NAME = 'DEMO_EVENTS_JSON'
ORDER BY CREATED_AT DESC
LIMIT 1;


-- =========================================================================
-- LAB STEP 5: QUERY RAW JSON DATA
-- Snowflake lets you query VARIANT columns using dot notation
-- and bracket notation.
-- =========================================================================

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
    -- These fields only exist for certain event types
    RAW_DATA:video_title::VARCHAR                AS VIDEO_TITLE,
    RAW_DATA:watch_time_seconds::NUMBER          AS WATCH_TIME_SECONDS,
    RAW_DATA:form_data.company_size::VARCHAR     AS COMPANY_SIZE,
    RAW_DATA:total_amount::NUMBER(12,2)          AS PURCHASE_AMOUNT,
    RAW_DATA:metadata.campaign::VARCHAR          AS CAMPAIGN
FROM MDF_RAW_DB.DEMO_WEB.RAW_EVENTS;


-- =========================================================================
-- LAB STEP 6: LATERAL FLATTEN — Explode Nested Arrays
-- The PURCHASE event has an "items" array. FLATTEN turns each array
-- element into its own row.
-- =========================================================================

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


-- =========================================================================
-- LAB STEP 7: CREATE FLATTENED VIEW FOR DOWNSTREAM USE
-- Best practice: Keep raw VARIANT data in RAW layer.
-- Create typed/flattened views in STAGING layer.
-- =========================================================================

CREATE SCHEMA IF NOT EXISTS MDF_STAGING_DB.DEMO_WEB
    COMMENT = 'Staging schema for DEMO web analytics (flattened views)';

-- Flattened events view
CREATE OR REPLACE VIEW MDF_STAGING_DB.DEMO_WEB.VW_EVENTS_FLATTENED AS
SELECT
    RAW_DATA:event_id::VARCHAR               AS EVENT_ID,
    RAW_DATA:event_type::VARCHAR             AS EVENT_TYPE,
    RAW_DATA:user_id::VARCHAR                AS USER_ID,
    RAW_DATA:session_id::VARCHAR             AS SESSION_ID,
    RAW_DATA:timestamp::TIMESTAMP_TZ         AS EVENT_TIMESTAMP,
    RAW_DATA:page_url::VARCHAR               AS PAGE_URL,
    RAW_DATA:referrer::VARCHAR               AS REFERRER,
    -- Device info
    RAW_DATA:device.type::VARCHAR            AS DEVICE_TYPE,
    RAW_DATA:device.os::VARCHAR              AS DEVICE_OS,
    RAW_DATA:device.browser::VARCHAR         AS DEVICE_BROWSER,
    -- Geo info
    RAW_DATA:geo.country::VARCHAR            AS COUNTRY,
    RAW_DATA:geo.state::VARCHAR              AS STATE,
    RAW_DATA:geo.city::VARCHAR               AS CITY,
    -- Campaign info (optional)
    RAW_DATA:metadata.campaign::VARCHAR      AS CAMPAIGN,
    RAW_DATA:metadata.medium::VARCHAR        AS MEDIUM,
    -- Event-specific fields
    RAW_DATA:element_id::VARCHAR             AS ELEMENT_ID,
    RAW_DATA:video_id::VARCHAR               AS VIDEO_ID,
    RAW_DATA:video_title::VARCHAR            AS VIDEO_TITLE,
    RAW_DATA:watch_time_seconds::NUMBER      AS WATCH_TIME_SECONDS,
    RAW_DATA:completion_rate::FLOAT          AS COMPLETION_RATE,
    RAW_DATA:order_id::VARCHAR               AS ORDER_ID,
    RAW_DATA:total_amount::NUMBER(12,2)      AS TOTAL_AMOUNT,
    RAW_DATA:status_code::NUMBER             AS API_STATUS_CODE,
    RAW_DATA:response_time_ms::NUMBER        AS API_RESPONSE_TIME_MS,
    -- MDF metadata
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
    DEVICE_TYPE,
    DEVICE_OS,
    COUNT(*) AS EVENT_COUNT
FROM MDF_STAGING_DB.DEMO_WEB.VW_EVENTS_FLATTENED
GROUP BY DEVICE_TYPE, DEVICE_OS
ORDER BY EVENT_COUNT DESC;


-- =========================================================================
-- LAB STEP 8: PARQUET INGESTION (Bonus)
-- Parquet is self-describing — Snowflake can infer the schema.
-- If you have sample Parquet files, the same framework handles them.
-- =========================================================================

/*
-- Register a Parquet source (already done in Module 03)
-- The config entry DEMO_SENSORS_PARQUET handles Parquet files automatically.

-- Upload Parquet file:
-- PUT file://path/to/sensors.parquet @MDF_CONTROL_DB.CONFIG.MDF_STG_INTERNAL_PARQUET/demo/sensors/;

-- Run ingestion:
-- CALL MDF_CONTROL_DB.PROCEDURES.SP_GENERIC_INGESTION('DEMO_SENSORS_PARQUET', FALSE);

-- Parquet columns are auto-detected using INFER_SCHEMA.
-- The framework creates the table structure automatically.
*/


/*
=============================================================================
  LAB EXERCISES:

  EXERCISE 1: Create a view that shows only video-related events
    Filter for VIDEO_PLAY and VIDEO_COMPLETE events, showing video_title,
    watch_time, and completion_rate.

  EXERCISE 2: Campaign attribution
    Write a query showing events per campaign and medium, only for events
    that have campaign metadata.

  EXERCISE 3: Flatten form submissions
    For FORM_SUBMIT events, extract all form_data fields into columns.

  EXERCISE 4: Register an NDJSON source
    Use SP_REGISTER_SOURCE to add a new JSON source using the
    MDF_FF_JSON_NDJSON file format.

  KEY TAKEAWAYS:
  - JSON loads into VARIANT, giving you schema flexibility
  - Use dot notation for simple access, FLATTEN for arrays
  - Create typed views in STAGING for downstream consumers
  - The same MDF framework handles CSV and JSON with zero code changes

  MODULE 06 COMPLETE!
  → Next: Module 07 — Error Handling & Audit Logging
=============================================================================
*/
