/*
#############################################################################
  MDF - Module 02: File Formats & Stages
  CONSOLIDATED WORKSHEET — Snowsight / VS Code Ready
#############################################################################
  SNOWBRIX ACADEMY — Metadata-Driven Ingestion Framework (MDF)

  This worksheet combines ALL Module 02 scripts into a single file:
    Part 1: File Format Definitions (10 formats)
    Part 2: Internal & External Stages (4 internal + templates)

  INSTRUCTIONS:
    - Run each section sequentially (top to bottom)
    - Requires Module 01 to be completed first
    - Estimated time: ~10 minutes

  PREREQUISITES:
    - Module 01 completed (databases, warehouses, roles exist)
    - MDF_ADMIN role access
#############################################################################
*/


-- ===========================================================================
-- ███████████████████████████████████████████████████████████████████████████
-- PART 1 OF 2: FILE FORMAT DEFINITIONS
-- ███████████████████████████████████████████████████████████████████████████
-- ===========================================================================

/*
  NAMING CONVENTION:
    MDF_FF_{TYPE}_{VARIANT}
    Examples: MDF_FF_CSV_STANDARD, MDF_FF_JSON_NDJSON, MDF_FF_PARQUET_STANDARD
*/

USE ROLE MDF_ADMIN;
USE DATABASE MDF_CONTROL_DB;
USE SCHEMA CONFIG;

-- ─── CSV FILE FORMATS ─────────────────────────────────────────────────────

-- Standard CSV: comma-delimited, with headers, double-quote enclosed
CREATE OR REPLACE FILE FORMAT MDF_FF_CSV_STANDARD
    TYPE                    = 'CSV'
    FIELD_DELIMITER         = ','
    RECORD_DELIMITER        = '\n'
    SKIP_HEADER             = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    NULL_IF                 = ('NULL', 'null', '', 'N/A', 'NA', '#N/A')
    EMPTY_FIELD_AS_NULL     = TRUE
    TRIM_SPACE              = TRUE
    ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
    DATE_FORMAT             = 'AUTO'
    TIMESTAMP_FORMAT        = 'AUTO'
    ENCODING                = 'UTF8'
    COMPRESSION             = 'AUTO'
    COMMENT                 = 'Standard CSV: comma-delimited, header row, double-quote enclosed';

-- Pipe-delimited CSV (common in legacy systems)
CREATE OR REPLACE FILE FORMAT MDF_FF_CSV_PIPE
    TYPE                    = 'CSV'
    FIELD_DELIMITER         = '|'
    RECORD_DELIMITER        = '\n'
    SKIP_HEADER             = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    NULL_IF                 = ('NULL', 'null', '', 'N/A')
    EMPTY_FIELD_AS_NULL     = TRUE
    TRIM_SPACE              = TRUE
    ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
    COMPRESSION             = 'AUTO'
    COMMENT                 = 'Pipe-delimited CSV: common in legacy/mainframe extracts';

-- Tab-delimited (TSV)
CREATE OR REPLACE FILE FORMAT MDF_FF_CSV_TAB
    TYPE                    = 'CSV'
    FIELD_DELIMITER         = '\t'
    RECORD_DELIMITER        = '\n'
    SKIP_HEADER             = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    NULL_IF                 = ('NULL', 'null', '')
    EMPTY_FIELD_AS_NULL     = TRUE
    TRIM_SPACE              = TRUE
    ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
    COMPRESSION             = 'AUTO'
    COMMENT                 = 'Tab-delimited CSV (TSV)';

-- No-header CSV (for files without column headers)
CREATE OR REPLACE FILE FORMAT MDF_FF_CSV_NO_HEADER
    TYPE                    = 'CSV'
    FIELD_DELIMITER         = ','
    RECORD_DELIMITER        = '\n'
    SKIP_HEADER             = 0
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    NULL_IF                 = ('NULL', 'null', '')
    EMPTY_FIELD_AS_NULL     = TRUE
    TRIM_SPACE              = TRUE
    ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
    COMPRESSION             = 'AUTO'
    COMMENT                 = 'CSV without header row: column mapping by position';

-- ─── JSON FILE FORMATS ────────────────────────────────────────────────────

-- Standard JSON: auto-detect arrays, strip outer array
CREATE OR REPLACE FILE FORMAT MDF_FF_JSON_STANDARD
    TYPE                    = 'JSON'
    STRIP_OUTER_ARRAY       = TRUE
    STRIP_NULL_VALUES       = FALSE
    IGNORE_UTF8_ERRORS      = TRUE
    ALLOW_DUPLICATE         = FALSE
    ENABLE_OCTAL            = FALSE
    DATE_FORMAT             = 'AUTO'
    TIMESTAMP_FORMAT        = 'AUTO'
    COMPRESSION             = 'AUTO'
    COMMENT                 = 'Standard JSON: strips outer array, preserves nulls';

-- NDJSON (Newline-delimited JSON, one JSON object per line)
CREATE OR REPLACE FILE FORMAT MDF_FF_JSON_NDJSON
    TYPE                    = 'JSON'
    STRIP_OUTER_ARRAY       = FALSE
    STRIP_NULL_VALUES       = FALSE
    IGNORE_UTF8_ERRORS      = TRUE
    COMPRESSION             = 'AUTO'
    COMMENT                 = 'NDJSON: newline-delimited JSON, one object per line';

-- JSON with null stripping (for compact storage)
CREATE OR REPLACE FILE FORMAT MDF_FF_JSON_COMPACT
    TYPE                    = 'JSON'
    STRIP_OUTER_ARRAY       = TRUE
    STRIP_NULL_VALUES       = TRUE
    IGNORE_UTF8_ERRORS      = TRUE
    COMPRESSION             = 'AUTO'
    COMMENT                 = 'Compact JSON: strips nulls for storage optimization';

-- ─── PARQUET FILE FORMAT ──────────────────────────────────────────────────

CREATE OR REPLACE FILE FORMAT MDF_FF_PARQUET_STANDARD
    TYPE                    = 'PARQUET'
    SNAPPY_COMPRESSION      = TRUE
    BINARY_AS_TEXT          = TRUE
    COMMENT                 = 'Standard Parquet: Snappy compression, binary-as-text';

-- ─── AVRO FILE FORMAT ─────────────────────────────────────────────────────

CREATE OR REPLACE FILE FORMAT MDF_FF_AVRO_STANDARD
    TYPE                    = 'AVRO'
    COMPRESSION             = 'AUTO'
    TRIM_SPACE              = TRUE
    COMMENT                 = 'Standard Avro format';

-- ─── ORC FILE FORMAT ──────────────────────────────────────────────────────

CREATE OR REPLACE FILE FORMAT MDF_FF_ORC_STANDARD
    TYPE                    = 'ORC'
    TRIM_SPACE              = TRUE
    COMMENT                 = 'Standard ORC format';

-- VERIFICATION: File Formats
SHOW FILE FORMATS IN SCHEMA MDF_CONTROL_DB.CONFIG;
DESCRIBE FILE FORMAT MDF_FF_CSV_STANDARD;
DESCRIBE FILE FORMAT MDF_FF_JSON_STANDARD;
DESCRIBE FILE FORMAT MDF_FF_PARQUET_STANDARD;


-- ===========================================================================
-- ███████████████████████████████████████████████████████████████████████████
-- PART 2 OF 2: INTERNAL & EXTERNAL STAGES
-- ███████████████████████████████████████████████████████████████████████████
-- ===========================================================================

/*
  NAMING CONVENTION:
    MDF_STG_{INTERNAL/EXT}_{PROVIDER}_{PURPOSE}

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
*/

USE ROLE MDF_ADMIN;
USE DATABASE MDF_CONTROL_DB;
USE SCHEMA CONFIG;

-- ─── INTERNAL STAGES ──────────────────────────────────────────────────────

CREATE OR REPLACE STAGE MDF_STG_INTERNAL_DEV
    FILE_FORMAT   = MDF_FF_CSV_STANDARD
    DIRECTORY     = (ENABLE = TRUE)
    COMMENT       = 'Internal stage for development and testing file uploads';

CREATE OR REPLACE STAGE MDF_STG_INTERNAL_CSV
    FILE_FORMAT   = MDF_FF_CSV_STANDARD
    DIRECTORY     = (ENABLE = TRUE)
    COMMENT       = 'Internal stage for CSV file ingestion';

CREATE OR REPLACE STAGE MDF_STG_INTERNAL_JSON
    FILE_FORMAT   = MDF_FF_JSON_STANDARD
    DIRECTORY     = (ENABLE = TRUE)
    COMMENT       = 'Internal stage for JSON file ingestion';

CREATE OR REPLACE STAGE MDF_STG_INTERNAL_PARQUET
    FILE_FORMAT   = MDF_FF_PARQUET_STANDARD
    DIRECTORY     = (ENABLE = TRUE)
    COMMENT       = 'Internal stage for Parquet file ingestion';

-- ─── EXTERNAL STAGE TEMPLATES (Uncomment for your cloud provider) ─────────

/*
-- AWS S3 External Stage
CREATE OR REPLACE STORAGE INTEGRATION MDF_S3_INTEGRATION
    TYPE                    = EXTERNAL_STAGE
    STORAGE_PROVIDER        = 'S3'
    ENABLED                 = TRUE
    STORAGE_AWS_ROLE_ARN    = 'arn:aws:iam::123456789012:role/snowflake-mdf-role'
    STORAGE_ALLOWED_LOCATIONS = (
        's3://your-bucket/mdf-data/',
        's3://your-bucket/mdf-archive/'
    );

DESC STORAGE INTEGRATION MDF_S3_INTEGRATION;

CREATE OR REPLACE STAGE MDF_STG_EXT_S3_DATA
    STORAGE_INTEGRATION = MDF_S3_INTEGRATION
    URL                 = 's3://your-bucket/mdf-data/'
    FILE_FORMAT         = MDF_FF_CSV_STANDARD
    DIRECTORY           = (ENABLE = TRUE)
    COMMENT             = 'External S3 stage for production data ingestion';

-- Azure Blob / ADLS Gen2 External Stage
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

-- Google Cloud Storage External Stage
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

-- VERIFICATION: Stages
SHOW STAGES IN SCHEMA MDF_CONTROL_DB.CONFIG;
DESCRIBE STAGE MDF_STG_INTERNAL_DEV;
DESCRIBE STAGE MDF_STG_INTERNAL_CSV;


/*
#############################################################################
  MODULE 02 COMPLETE!

  Objects Created:
    - 10 file formats: 4 CSV, 3 JSON, 1 Parquet, 1 Avro, 1 ORC
    - 4 internal stages with directory tables enabled
    - External stage templates for S3, Azure, GCS (commented)

  Next: MDF - Module 03 (Config Tables)
#############################################################################
*/
