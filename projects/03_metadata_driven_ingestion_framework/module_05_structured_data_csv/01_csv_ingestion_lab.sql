/*
=============================================================================
  MODULE 05 : STRUCTURED DATA INGESTION (CSV)
  SCRIPT 01 : Hands-On Lab — End-to-End CSV Ingestion
=============================================================================
  SNOWBRIX ACADEMY — Metadata-Driven Ingestion Framework (MDF)

  LEARNING OBJECTIVES:
    1. Upload CSV files to an internal stage
    2. Create target tables for CSV data
    3. Run the MDF framework to ingest CSV data
    4. Verify ingestion results using audit logs
    5. Query the loaded data

  LAB DURATION: ~30 minutes

  PREREQUISITES:
    - Modules 01-04 completed (all objects created)
    - Sample CSV files from /sample_data/csv/
    - SnowSQL or Snowsight worksheet access

  LAB SCENARIO:
    You are onboarding a new client "DEMO" with three data sources:
      1. Customer master data (customers.csv)
      2. Sales orders (orders.csv)
      3. Product catalog (products.csv)
    All are CSV files that need to be loaded into the RAW layer.
=============================================================================
*/

-- =========================================================================
-- LAB STEP 1: SET YOUR CONTEXT
-- =========================================================================
USE ROLE MDF_ADMIN;
USE DATABASE MDF_CONTROL_DB;
USE WAREHOUSE MDF_INGESTION_WH;


-- =========================================================================
-- LAB STEP 2: CREATE TARGET TABLES FOR CSV DATA
-- For CSV ingestion, we define the target table schema explicitly.
-- This gives us type safety from the start.
-- =========================================================================

-- Create the target schema
CREATE SCHEMA IF NOT EXISTS MDF_RAW_DB.DEMO_ERP
    COMMENT = 'Raw data schema for DEMO client ERP system';

-- Customers table
CREATE OR REPLACE TABLE MDF_RAW_DB.DEMO_ERP.RAW_CUSTOMERS (
    CUSTOMER_ID         NUMBER,
    CUSTOMER_NAME       VARCHAR(200),
    EMAIL               VARCHAR(300),
    PHONE               VARCHAR(50),
    ADDRESS             VARCHAR(500),
    CITY                VARCHAR(100),
    STATE               VARCHAR(50),
    COUNTRY             VARCHAR(50),
    POSTAL_CODE         VARCHAR(20),
    CUSTOMER_SEGMENT    VARCHAR(50),
    REGISTRATION_DATE   DATE,
    IS_ACTIVE           BOOLEAN,
    -- MDF metadata columns (added to every raw table)
    _MDF_FILE_NAME      VARCHAR     DEFAULT METADATA$FILENAME,
    _MDF_FILE_ROW       NUMBER      DEFAULT METADATA$FILE_ROW_NUMBER,
    _MDF_LOADED_AT      TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Orders table
CREATE OR REPLACE TABLE MDF_RAW_DB.DEMO_ERP.RAW_ORDERS (
    ORDER_ID            VARCHAR(50),
    CUSTOMER_ID         NUMBER,
    ORDER_DATE          DATE,
    ORDER_STATUS        VARCHAR(50),
    TOTAL_AMOUNT        NUMBER(12,2),
    CURRENCY            VARCHAR(10),
    SHIPPING_METHOD     VARCHAR(50),
    PAYMENT_METHOD      VARCHAR(50),
    DISCOUNT_AMOUNT     NUMBER(12,2),
    TAX_AMOUNT          NUMBER(12,2),
    CREATED_AT          TIMESTAMP_NTZ,
    -- MDF metadata columns
    _MDF_FILE_NAME      VARCHAR     DEFAULT METADATA$FILENAME,
    _MDF_FILE_ROW       NUMBER      DEFAULT METADATA$FILE_ROW_NUMBER,
    _MDF_LOADED_AT      TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Products table
CREATE OR REPLACE TABLE MDF_RAW_DB.DEMO_ERP.RAW_PRODUCTS (
    PRODUCT_ID          VARCHAR(50),
    PRODUCT_NAME        VARCHAR(300),
    CATEGORY            VARCHAR(100),
    SUB_CATEGORY        VARCHAR(100),
    UNIT_PRICE          NUMBER(12,2),
    COST_PRICE          NUMBER(12,2),
    SUPPLIER_NAME       VARCHAR(200),
    STOCK_QUANTITY       NUMBER,
    WEIGHT_KG           NUMBER(10,2),
    IS_ACTIVE           BOOLEAN,
    CREATED_DATE        DATE,
    -- MDF metadata columns
    _MDF_FILE_NAME      VARCHAR     DEFAULT METADATA$FILENAME,
    _MDF_FILE_ROW       NUMBER      DEFAULT METADATA$FILE_ROW_NUMBER,
    _MDF_LOADED_AT      TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Verify tables
SHOW TABLES IN SCHEMA MDF_RAW_DB.DEMO_ERP;


-- =========================================================================
-- LAB STEP 3: UPLOAD CSV FILES TO THE INTERNAL STAGE
-- In production, files would land in S3/Azure/GCS.
-- For this lab, we use PUT to upload to an internal stage.
--
-- RUN THESE IN SnowSQL (not Snowsight worksheet):
--   PUT file://C:/path/to/sample_data/csv/customers.csv @MDF_CONTROL_DB.CONFIG.MDF_STG_INTERNAL_CSV/demo/customers/ AUTO_COMPRESS=TRUE;
--   PUT file://C:/path/to/sample_data/csv/orders.csv @MDF_CONTROL_DB.CONFIG.MDF_STG_INTERNAL_CSV/demo/orders/ AUTO_COMPRESS=TRUE;
--   PUT file://C:/path/to/sample_data/csv/products.csv @MDF_CONTROL_DB.CONFIG.MDF_STG_INTERNAL_CSV/demo/products/ AUTO_COMPRESS=TRUE;
--
-- Alternatively, upload via Snowsight:
--   1. Go to Data → Databases → MDF_CONTROL_DB → CONFIG → Stages
--   2. Click on MDF_STG_INTERNAL_CSV
--   3. Click "+ Files" and upload each CSV
-- =========================================================================

-- After uploading, verify files are in the stage
LIST @MDF_CONTROL_DB.CONFIG.MDF_STG_INTERNAL_CSV;

-- Check specific subdirectories
-- LIST @MDF_CONTROL_DB.CONFIG.MDF_STG_INTERNAL_CSV/demo/customers/;
-- LIST @MDF_CONTROL_DB.CONFIG.MDF_STG_INTERNAL_CSV/demo/orders/;
-- LIST @MDF_CONTROL_DB.CONFIG.MDF_STG_INTERNAL_CSV/demo/products/;


-- =========================================================================
-- LAB STEP 4: PREVIEW DATA BEFORE LOADING
-- Always preview your data before running a full load.
-- This catches schema mismatches early.
-- =========================================================================

-- Preview customers data
SELECT $1, $2, $3, $4, $5
FROM @MDF_CONTROL_DB.CONFIG.MDF_STG_INTERNAL_CSV/demo/customers/
(FILE_FORMAT => 'MDF_CONTROL_DB.CONFIG.MDF_FF_CSV_STANDARD')
LIMIT 5;

-- Preview orders data
SELECT $1, $2, $3, $4, $5
FROM @MDF_CONTROL_DB.CONFIG.MDF_STG_INTERNAL_CSV/demo/orders/
(FILE_FORMAT => 'MDF_CONTROL_DB.CONFIG.MDF_FF_CSV_STANDARD')
LIMIT 5;


-- =========================================================================
-- LAB STEP 5: VERIFY CONFIG ENTRIES EXIST
-- The sample configs were inserted in Module 03.
-- =========================================================================

SELECT
    CONFIG_ID,
    SOURCE_NAME,
    SOURCE_TYPE,
    TARGET_DATABASE || '.' || TARGET_SCHEMA || '.' || TARGET_TABLE AS TARGET,
    IS_ACTIVE,
    LOAD_TYPE
FROM MDF_CONTROL_DB.CONFIG.INGESTION_CONFIG
WHERE CLIENT_NAME = 'DEMO'
  AND SOURCE_TYPE = 'CSV'
ORDER BY LOAD_PRIORITY;


-- =========================================================================
-- LAB STEP 6: RUN THE INGESTION!
-- This is the moment of truth. One call processes ALL three CSV sources.
-- =========================================================================

-- Option A: Process a single source
CALL MDF_CONTROL_DB.PROCEDURES.SP_GENERIC_INGESTION('DEMO_CUSTOMERS_CSV', FALSE);

-- Option B: Process all active DEMO sources at once
-- CALL MDF_CONTROL_DB.PROCEDURES.SP_GENERIC_INGESTION('ALL', FALSE);


-- =========================================================================
-- LAB STEP 7: CHECK INGESTION RESULTS
-- =========================================================================

-- View the latest audit log entries
SELECT
    BATCH_ID,
    SOURCE_NAME,
    RUN_STATUS,
    FILES_PROCESSED,
    ROWS_LOADED,
    ROWS_FAILED,
    DURATION_SECONDS,
    ERROR_MESSAGE,
    CREATED_AT
FROM MDF_CONTROL_DB.AUDIT.INGESTION_AUDIT_LOG
ORDER BY CREATED_AT DESC
LIMIT 10;

-- Detailed view for a specific source
SELECT
    BATCH_ID,
    SOURCE_NAME,
    RUN_STATUS,
    FILES_PROCESSED,
    FILES_SKIPPED,
    ROWS_LOADED,
    ROWS_FAILED,
    BYTES_LOADED,
    COPY_COMMAND_EXECUTED,
    COPY_RESULT,
    FILES_LIST
FROM MDF_CONTROL_DB.AUDIT.INGESTION_AUDIT_LOG
WHERE SOURCE_NAME = 'DEMO_CUSTOMERS_CSV'
ORDER BY CREATED_AT DESC
LIMIT 1;


-- =========================================================================
-- LAB STEP 8: VERIFY LOADED DATA
-- =========================================================================

-- Count rows in each table
SELECT 'RAW_CUSTOMERS' AS TABLE_NAME, COUNT(*) AS ROW_COUNT FROM MDF_RAW_DB.DEMO_ERP.RAW_CUSTOMERS
UNION ALL
SELECT 'RAW_ORDERS',    COUNT(*) FROM MDF_RAW_DB.DEMO_ERP.RAW_ORDERS
UNION ALL
SELECT 'RAW_PRODUCTS',  COUNT(*) FROM MDF_RAW_DB.DEMO_ERP.RAW_PRODUCTS;

-- Sample customer data with MDF metadata
SELECT
    CUSTOMER_ID,
    CUSTOMER_NAME,
    CUSTOMER_SEGMENT,
    _MDF_FILE_NAME,
    _MDF_FILE_ROW,
    _MDF_LOADED_AT
FROM MDF_RAW_DB.DEMO_ERP.RAW_CUSTOMERS
LIMIT 5;

-- Sample order data
SELECT
    ORDER_ID,
    CUSTOMER_ID,
    ORDER_DATE,
    TOTAL_AMOUNT,
    ORDER_STATUS,
    _MDF_LOADED_AT
FROM MDF_RAW_DB.DEMO_ERP.RAW_ORDERS
ORDER BY ORDER_DATE DESC
LIMIT 10;

-- Quick data quality check: any NULL customer IDs in orders?
SELECT COUNT(*) AS NULL_CUSTOMER_IDS
FROM MDF_RAW_DB.DEMO_ERP.RAW_ORDERS
WHERE CUSTOMER_ID IS NULL;


-- =========================================================================
-- LAB STEP 9: RE-RUN INGESTION (Idempotency Test)
-- Run the same source again. Snowflake's COPY INTO tracks loaded files
-- and skips them automatically (unless FORCE=TRUE).
-- =========================================================================

-- Run again — should show 0 files processed (already loaded)
CALL MDF_CONTROL_DB.PROCEDURES.SP_GENERIC_INGESTION('DEMO_CUSTOMERS_CSV', FALSE);

-- Check audit log — should show SKIPPED status
SELECT
    SOURCE_NAME,
    RUN_STATUS,
    FILES_PROCESSED,
    FILES_SKIPPED,
    ROWS_LOADED
FROM MDF_CONTROL_DB.AUDIT.INGESTION_AUDIT_LOG
WHERE SOURCE_NAME = 'DEMO_CUSTOMERS_CSV'
ORDER BY CREATED_AT DESC
LIMIT 2;

-- Now force reload — this re-loads even previously loaded files
-- CALL MDF_CONTROL_DB.PROCEDURES.SP_GENERIC_INGESTION('DEMO_CUSTOMERS_CSV', TRUE);


/*
=============================================================================
  LAB EXERCISES (Try These on Your Own):

  EXERCISE 1: Register a new CSV source
    Call SP_REGISTER_SOURCE to add a new CSV source for "DEMO_INVENTORY_CSV"
    with a pipe-delimited file format.

  EXERCISE 2: Upload a bad CSV file
    Create a CSV with a column count mismatch and observe how ON_ERROR=CONTINUE
    handles it vs. ABORT_STATEMENT.

  EXERCISE 3: Truncate and reload
    Change the LOAD_TYPE for DEMO_PRODUCTS_CSV to 'TRUNCATE_RELOAD',
    upload a new products.csv with updated prices, and run ingestion.

  EXERCISE 4: Check the MDF metadata columns
    Write a query that shows which file each row came from, using
    _MDF_FILE_NAME and _MDF_FILE_ROW columns.

  MODULE 05 COMPLETE!
  → Next: Module 06 — Semi-Structured Data Ingestion (JSON/Parquet)
=============================================================================
*/
