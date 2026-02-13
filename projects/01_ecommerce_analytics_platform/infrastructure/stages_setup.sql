-- ============================================================
-- SNOWBRIX E-COMMERCE PLATFORM
-- Internal Stages for File Loading
-- ============================================================

USE ROLE SYSADMIN;

-- ============================================================
-- CSV STAGE (for Google Sheets exports + manual uploads)
-- ============================================================

CREATE STAGE IF NOT EXISTS ECOMMERCE_RAW.CSV_UPLOADS.CSV_STAGE
    FILE_FORMAT = (
        TYPE = CSV
        SKIP_HEADER = 1
        FIELD_OPTIONALLY_ENCLOSED_BY = '"'
        NULL_IF = ('', 'NULL', 'null', 'N/A', 'n/a')
        TRIM_SPACE = TRUE
        ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
        ENCODING = 'UTF8'
    )
    COMMENT = 'Internal stage for CSV file uploads from Google Sheets and manual sources';

-- ============================================================
-- PARQUET STAGE (for bulk Postgres extracts)
-- ============================================================

CREATE STAGE IF NOT EXISTS ECOMMERCE_RAW.POSTGRES.PARQUET_STAGE
    FILE_FORMAT = (
        TYPE = PARQUET
        SNAPPY_COMPRESSION = TRUE
    )
    COMMENT = 'Internal stage for Parquet file bulk loads from PostgreSQL';

-- ============================================================
-- JSON STAGE (for Stripe API raw responses)
-- ============================================================

CREATE STAGE IF NOT EXISTS ECOMMERCE_RAW.STRIPE.JSON_STAGE
    FILE_FORMAT = (
        TYPE = JSON
        STRIP_OUTER_ARRAY = TRUE
        IGNORE_UTF8_ERRORS = TRUE
    )
    COMMENT = 'Internal stage for JSON data from Stripe API';

-- ============================================================
-- VERIFICATION
-- ============================================================

SHOW STAGES IN DATABASE ECOMMERCE_RAW;
