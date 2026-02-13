/*
=============================================================================
  MODULE 02 : FILE FORMATS & STAGES
  SCRIPT 02 : Internal & External Stages
=============================================================================
  SNOWBRIX ACADEMY — Metadata-Driven Ingestion Framework (MDF)

  LEARNING OBJECTIVES:
    1. Create internal stages for development/testing
    2. Create external stage templates for S3, Azure Blob, GCS
    3. Understand stage naming conventions
    4. Configure directory tables for file listing

  NAMING CONVENTION:
    MDF_STG_{INTERNAL/EXT}_{PROVIDER}_{PURPOSE}
    Examples:
      MDF_STG_INTERNAL_DEV      → Internal stage for development
      MDF_STG_EXT_S3_SALES      → External S3 stage for sales data
      MDF_STG_EXT_AZURE_HR      → External Azure stage for HR data

  STAGE TYPES:
  ┌──────────────────────────────────────────────────────────────┐
  │  INTERNAL STAGES                                             │
  │  ├── User Stage (@~)       → Per-user, auto-created          │
  │  ├── Table Stage (@%table) → Per-table, auto-created         │
  │  └── Named Stage (@stage)  → Explicit, shareable, reusable   │
  │                                                              │
  │  EXTERNAL STAGES                                             │
  │  ├── AWS S3                → s3://bucket/path/               │
  │  ├── Azure Blob/ADLS       → azure://account.blob/container/ │
  │  └── Google Cloud Storage  → gcs://bucket/path/              │
  └──────────────────────────────────────────────────────────────┘
=============================================================================
*/

USE ROLE MDF_ADMIN;
USE DATABASE MDF_CONTROL_DB;
USE SCHEMA CONFIG;

-- =========================================================================
-- INTERNAL STAGES (For Development and Testing)
-- =========================================================================

-- General-purpose internal stage for development/testing
CREATE OR REPLACE STAGE MDF_STG_INTERNAL_DEV
    FILE_FORMAT   = MDF_FF_CSV_STANDARD
    DIRECTORY     = (ENABLE = TRUE)              -- Enable directory table
    COMMENT       = 'Internal stage for development and testing file uploads';

-- Internal stage for CSV files
CREATE OR REPLACE STAGE MDF_STG_INTERNAL_CSV
    FILE_FORMAT   = MDF_FF_CSV_STANDARD
    DIRECTORY     = (ENABLE = TRUE)
    COMMENT       = 'Internal stage for CSV file ingestion';

-- Internal stage for JSON files
CREATE OR REPLACE STAGE MDF_STG_INTERNAL_JSON
    FILE_FORMAT   = MDF_FF_JSON_STANDARD
    DIRECTORY     = (ENABLE = TRUE)
    COMMENT       = 'Internal stage for JSON file ingestion';

-- Internal stage for Parquet files
CREATE OR REPLACE STAGE MDF_STG_INTERNAL_PARQUET
    FILE_FORMAT   = MDF_FF_PARQUET_STANDARD
    DIRECTORY     = (ENABLE = TRUE)
    COMMENT       = 'Internal stage for Parquet file ingestion';


-- =========================================================================
-- EXTERNAL STAGE TEMPLATES
-- Uncomment and modify based on your cloud provider
-- =========================================================================

/*
-- -------------------------------------------------------------------------
-- TEMPLATE: AWS S3 External Stage
-- Prerequisites:
--   1. Create a Storage Integration (recommended over direct credentials)
--   2. Create an IAM role with S3 read access
-- -------------------------------------------------------------------------

-- Step 1: Create Storage Integration (run as ACCOUNTADMIN)
CREATE OR REPLACE STORAGE INTEGRATION MDF_S3_INTEGRATION
    TYPE                    = EXTERNAL_STAGE
    STORAGE_PROVIDER        = 'S3'
    ENABLED                 = TRUE
    STORAGE_AWS_ROLE_ARN    = 'arn:aws:iam::123456789012:role/snowflake-mdf-role'
    STORAGE_ALLOWED_LOCATIONS = (
        's3://your-bucket/mdf-data/',
        's3://your-bucket/mdf-archive/'
    );

-- Step 2: Get the AWS IAM user ARN and External ID for trust policy
DESC STORAGE INTEGRATION MDF_S3_INTEGRATION;

-- Step 3: Create the external stage
CREATE OR REPLACE STAGE MDF_STG_EXT_S3_DATA
    STORAGE_INTEGRATION = MDF_S3_INTEGRATION
    URL                 = 's3://your-bucket/mdf-data/'
    FILE_FORMAT         = MDF_FF_CSV_STANDARD
    DIRECTORY           = (ENABLE = TRUE)
    COMMENT             = 'External S3 stage for production data ingestion';


-- -------------------------------------------------------------------------
-- TEMPLATE: Azure Blob / ADLS Gen2 External Stage
-- -------------------------------------------------------------------------

CREATE OR REPLACE STORAGE INTEGRATION MDF_AZURE_INTEGRATION
    TYPE                    = EXTERNAL_STAGE
    STORAGE_PROVIDER        = 'AZURE'
    ENABLED                 = TRUE
    AZURE_TENANT_ID         = 'your-tenant-id'
    STORAGE_ALLOWED_LOCATIONS = (
        'azure://youraccount.blob.core.windows.net/mdf-container/'
    );

CREATE OR REPLACE STAGE MDF_STG_EXT_AZURE_DATA
    STORAGE_INTEGRATION = MDF_AZURE_INTEGRATION
    URL                 = 'azure://youraccount.blob.core.windows.net/mdf-container/'
    FILE_FORMAT         = MDF_FF_CSV_STANDARD
    DIRECTORY           = (ENABLE = TRUE)
    COMMENT             = 'External Azure Blob stage for production data ingestion';


-- -------------------------------------------------------------------------
-- TEMPLATE: Google Cloud Storage External Stage
-- -------------------------------------------------------------------------

CREATE OR REPLACE STORAGE INTEGRATION MDF_GCS_INTEGRATION
    TYPE                    = EXTERNAL_STAGE
    STORAGE_PROVIDER        = 'GCS'
    ENABLED                 = TRUE
    STORAGE_ALLOWED_LOCATIONS = (
        'gcs://your-bucket/mdf-data/'
    );

CREATE OR REPLACE STAGE MDF_STG_EXT_GCS_DATA
    STORAGE_INTEGRATION = MDF_GCS_INTEGRATION
    URL                 = 'gcs://your-bucket/mdf-data/'
    FILE_FORMAT         = MDF_FF_CSV_STANDARD
    DIRECTORY           = (ENABLE = TRUE)
    COMMENT             = 'External GCS stage for production data ingestion';
*/


-- =========================================================================
-- HELPER: LIST FILES IN A STAGE
-- These queries are useful for verifying file uploads and debugging.
-- =========================================================================

-- List files in internal dev stage
-- LIST @MDF_STG_INTERNAL_DEV;

-- List files using directory table (richer metadata)
-- SELECT * FROM DIRECTORY(@MDF_STG_INTERNAL_DEV);

-- List files matching a pattern
-- LIST @MDF_STG_INTERNAL_CSV PATTERN = '.*customers.*[.]csv';


-- =========================================================================
-- VERIFICATION QUERIES
-- =========================================================================

-- List all MDF stages
SHOW STAGES IN SCHEMA MDF_CONTROL_DB.CONFIG;

-- Describe a stage to see its configuration
DESCRIBE STAGE MDF_STG_INTERNAL_DEV;
DESCRIBE STAGE MDF_STG_INTERNAL_CSV;


/*
=============================================================================
  BEST PRACTICES & TIPS:

  1. USE STORAGE INTEGRATIONS: Never hardcode AWS keys, Azure SAS tokens,
     or GCS credentials in stage definitions. Storage Integrations use
     IAM roles — more secure, easier to rotate, auditable.

  2. ENABLE DIRECTORY TABLES: Directory tables let you query file metadata
     (name, size, last_modified) using standard SQL. This is how the MDF
     framework detects new files to process.

  3. ONE STAGE PER PURPOSE: Don't dump all file types into one stage.
     Separate stages by file type or data source for cleaner management.

  4. STORAGE_ALLOWED_LOCATIONS: In storage integrations, always specify
     the most restrictive paths possible. Don't allow 's3://bucket/' when
     you only need 's3://bucket/mdf-data/'.

  5. FOR THIS LAB: We use internal stages for simplicity. In production,
     you'll use external stages connected to S3/Azure/GCS.

  MODULE 02 COMPLETE!
  → Next: Module 03 — Config Tables & Metadata Design
=============================================================================
*/
