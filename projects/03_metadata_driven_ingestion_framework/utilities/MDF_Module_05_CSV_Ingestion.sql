/*
#############################################################################
  MDF - Module 05: Structured Data Ingestion (CSV)
  CONSOLIDATED WORKSHEET — Snowsight / VS Code Ready
#############################################################################
  SNOWBRIX ACADEMY — Metadata-Driven Ingestion Framework (MDF)

  This worksheet contains the complete CSV Ingestion Lab.

  LAB SCENARIO:
    You are onboarding a new client "DEMO" with three data sources:
      1. Customer master data (customers.csv)
      2. Sales orders (orders.csv)
      3. Product catalog (products.csv)

  INSTRUCTIONS:
    - Run each step sequentially (top to bottom)
    - Requires Modules 01-04 to be completed first
    - Upload CSV files BEFORE running Step 6
    - Estimated time: ~30 minutes

  PREREQUISITES:
    - Modules 01-04 completed
    - Sample CSV files from /sample_data/csv/
    - MDF_ADMIN role access
#############################################################################
*/

USE ROLE MDF_ADMIN;
USE DATABASE MDF_CONTROL_DB;
USE WAREHOUSE MDF_INGESTION_WH;


-- ===========================================================================
-- STEP 1: CREATE TARGET TABLES FOR CSV DATA
-- ===========================================================================

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
    _MDF_FILE_NAME      VARCHAR     DEFAULT METADATA$FILENAME,
    _MDF_FILE_ROW       NUMBER      DEFAULT METADATA$FILE_ROW_NUMBER,
    _MDF_LOADED_AT      TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
);

SHOW TABLES IN SCHEMA MDF_RAW_DB.DEMO_ERP;


-- ===========================================================================
-- STEP 2: UPLOAD CSV FILES TO THE INTERNAL STAGE
-- ===========================================================================

/*
  RUN THESE IN SnowSQL (not Snowsight worksheet):
    PUT file://C:/path/to/sample_data/csv/customers.csv @MDF_CONTROL_DB.CONFIG.MDF_STG_INTERNAL_CSV/demo/customers/ AUTO_COMPRESS=TRUE;
    PUT file://C:/path/to/sample_data/csv/orders.csv @MDF_CONTROL_DB.CONFIG.MDF_STG_INTERNAL_CSV/demo/orders/ AUTO_COMPRESS=TRUE;
    PUT file://C:/path/to/sample_data/csv/products.csv @MDF_CONTROL_DB.CONFIG.MDF_STG_INTERNAL_CSV/demo/products/ AUTO_COMPRESS=TRUE;

  Alternatively, upload via Snowsight:
    1. Go to Data > Databases > MDF_CONTROL_DB > CONFIG > Stages
    2. Click on MDF_STG_INTERNAL_CSV
    3. Click "+ Files" and upload each CSV
*/

-- Verify files are in the stage
LIST @MDF_CONTROL_DB.CONFIG.MDF_STG_INTERNAL_CSV;


-- ===========================================================================
-- STEP 3: PREVIEW DATA BEFORE LOADING
-- ===========================================================================

SELECT $1, $2, $3, $4, $5
FROM @MDF_CONTROL_DB.CONFIG.MDF_STG_INTERNAL_CSV/demo/customers/
(FILE_FORMAT => 'MDF_CONTROL_DB.CONFIG.MDF_FF_CSV_STANDARD')
LIMIT 5;

SELECT $1, $2, $3, $4, $5
FROM @MDF_CONTROL_DB.CONFIG.MDF_STG_INTERNAL_CSV/demo/orders/
(FILE_FORMAT => 'MDF_CONTROL_DB.CONFIG.MDF_FF_CSV_STANDARD')
LIMIT 5;


-- ===========================================================================
-- STEP 4: VERIFY CONFIG ENTRIES EXIST
-- ===========================================================================

SELECT
    CONFIG_ID, SOURCE_NAME, SOURCE_TYPE,
    TARGET_DATABASE || '.' || TARGET_SCHEMA || '.' || TARGET_TABLE AS TARGET,
    IS_ACTIVE, LOAD_TYPE
FROM MDF_CONTROL_DB.CONFIG.INGESTION_CONFIG
WHERE CLIENT_NAME = 'DEMO'
  AND SOURCE_TYPE = 'CSV'
ORDER BY LOAD_PRIORITY;


-- ===========================================================================
-- STEP 5: RUN THE INGESTION!
-- ===========================================================================

-- Process a single source
CALL MDF_CONTROL_DB.PROCEDURES.SP_GENERIC_INGESTION('DEMO_CUSTOMERS_CSV', FALSE);

-- Or process all active sources at once:
-- CALL MDF_CONTROL_DB.PROCEDURES.SP_GENERIC_INGESTION('ALL', FALSE);


-- ===========================================================================
-- STEP 6: CHECK INGESTION RESULTS
-- ===========================================================================

SELECT
    BATCH_ID, SOURCE_NAME, RUN_STATUS,
    FILES_PROCESSED, ROWS_LOADED, ROWS_FAILED,
    DURATION_SECONDS, ERROR_MESSAGE, CREATED_AT
FROM MDF_CONTROL_DB.AUDIT.INGESTION_AUDIT_LOG
ORDER BY CREATED_AT DESC
LIMIT 10;

-- Detailed view for a specific source
SELECT
    BATCH_ID, SOURCE_NAME, RUN_STATUS,
    FILES_PROCESSED, FILES_SKIPPED,
    ROWS_LOADED, ROWS_FAILED, BYTES_LOADED,
    COPY_COMMAND_EXECUTED, COPY_RESULT, FILES_LIST
FROM MDF_CONTROL_DB.AUDIT.INGESTION_AUDIT_LOG
WHERE SOURCE_NAME = 'DEMO_CUSTOMERS_CSV'
ORDER BY CREATED_AT DESC
LIMIT 1;


-- ===========================================================================
-- STEP 7: VERIFY LOADED DATA
-- ===========================================================================

SELECT 'RAW_CUSTOMERS' AS TABLE_NAME, COUNT(*) AS ROW_COUNT FROM MDF_RAW_DB.DEMO_ERP.RAW_CUSTOMERS
UNION ALL
SELECT 'RAW_ORDERS',    COUNT(*) FROM MDF_RAW_DB.DEMO_ERP.RAW_ORDERS
UNION ALL
SELECT 'RAW_PRODUCTS',  COUNT(*) FROM MDF_RAW_DB.DEMO_ERP.RAW_PRODUCTS;

SELECT
    CUSTOMER_ID, CUSTOMER_NAME, CUSTOMER_SEGMENT,
    _MDF_FILE_NAME, _MDF_FILE_ROW, _MDF_LOADED_AT
FROM MDF_RAW_DB.DEMO_ERP.RAW_CUSTOMERS
LIMIT 5;

SELECT
    ORDER_ID, CUSTOMER_ID, ORDER_DATE, TOTAL_AMOUNT, ORDER_STATUS, _MDF_LOADED_AT
FROM MDF_RAW_DB.DEMO_ERP.RAW_ORDERS
ORDER BY ORDER_DATE DESC
LIMIT 10;

-- Data quality check: any NULL customer IDs in orders?
SELECT COUNT(*) AS NULL_CUSTOMER_IDS
FROM MDF_RAW_DB.DEMO_ERP.RAW_ORDERS
WHERE CUSTOMER_ID IS NULL;


-- ===========================================================================
-- STEP 8: RE-RUN INGESTION (IDEMPOTENCY TEST)
-- ===========================================================================

-- Run again — should show 0 files processed (already loaded)
CALL MDF_CONTROL_DB.PROCEDURES.SP_GENERIC_INGESTION('DEMO_CUSTOMERS_CSV', FALSE);

-- Check audit log — should show SKIPPED status
SELECT
    SOURCE_NAME, RUN_STATUS, FILES_PROCESSED, FILES_SKIPPED, ROWS_LOADED
FROM MDF_CONTROL_DB.AUDIT.INGESTION_AUDIT_LOG
WHERE SOURCE_NAME = 'DEMO_CUSTOMERS_CSV'
ORDER BY CREATED_AT DESC
LIMIT 2;

-- Force reload (re-loads even previously loaded files)
-- CALL MDF_CONTROL_DB.PROCEDURES.SP_GENERIC_INGESTION('DEMO_CUSTOMERS_CSV', TRUE);


/*
#############################################################################
  MODULE 05 COMPLETE!

  What You Did:
    - Created 3 target tables with MDF metadata columns
    - Uploaded CSV files to internal stage
    - Ran ingestion via SP_GENERIC_INGESTION
    - Verified results through audit log
    - Tested idempotency (re-run skips loaded files)

  Next: MDF - Module 06 (Semi-Structured Data — JSON / Parquet)
#############################################################################
*/
