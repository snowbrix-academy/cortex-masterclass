/*
=============================================================================
  MODULE 02 : FILE FORMATS & STAGES
  SCRIPT 01 : File Format Definitions
=============================================================================
  SNOWBRIX ACADEMY — Metadata-Driven Ingestion Framework (MDF)

  LEARNING OBJECTIVES:
    1. Create reusable file format objects for CSV, JSON, Parquet, Avro, ORC
    2. Understand key file format options and when to use them
    3. Design a naming convention for file formats
    4. Handle common file format gotchas (BOM, date formats, null strings)

  NAMING CONVENTION:
    MDF_FF_{TYPE}_{VARIANT}
    Examples:
      MDF_FF_CSV_STANDARD     → Standard CSV with headers
      MDF_FF_CSV_PIPE         → Pipe-delimited CSV
      MDF_FF_JSON_STANDARD    → Standard JSON
      MDF_FF_PARQUET_STANDARD → Standard Parquet
=============================================================================
*/

USE ROLE MDF_ADMIN;
USE DATABASE MDF_CONTROL_DB;
USE SCHEMA CONFIG;

-- =========================================================================
-- CSV FILE FORMATS
-- =========================================================================

-- Standard CSV: comma-delimited, with headers, double-quote enclosed
CREATE OR REPLACE FILE FORMAT MDF_FF_CSV_STANDARD
    TYPE                    = 'CSV'
    FIELD_DELIMITER         = ','
    RECORD_DELIMITER        = '\n'
    SKIP_HEADER             = 1                  -- Skip the header row
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'           -- Handle quoted fields
    NULL_IF                 = ('NULL', 'null', '', 'N/A', 'NA', '#N/A')
    EMPTY_FIELD_AS_NULL     = TRUE
    TRIM_SPACE              = TRUE               -- Remove leading/trailing spaces
    ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE       -- Allow flexible column count
    DATE_FORMAT             = 'AUTO'
    TIMESTAMP_FORMAT        = 'AUTO'
    ENCODING                = 'UTF8'
    COMPRESSION             = 'AUTO'             -- Auto-detect compression
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
    SKIP_HEADER             = 0                  -- No header to skip
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    NULL_IF                 = ('NULL', 'null', '')
    EMPTY_FIELD_AS_NULL     = TRUE
    TRIM_SPACE              = TRUE
    ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
    COMPRESSION             = 'AUTO'
    COMMENT                 = 'CSV without header row: column mapping by position';

-- =========================================================================
-- JSON FILE FORMATS
-- =========================================================================

-- Standard JSON: auto-detect arrays, strip outer array
CREATE OR REPLACE FILE FORMAT MDF_FF_JSON_STANDARD
    TYPE                    = 'JSON'
    STRIP_OUTER_ARRAY       = TRUE               -- Unwrap JSON arrays into rows
    STRIP_NULL_VALUES       = FALSE              -- Keep nulls for schema awareness
    IGNORE_UTF8_ERRORS      = TRUE               -- Don't fail on bad encoding
    ALLOW_DUPLICATE         = FALSE              -- Reject duplicate keys
    ENABLE_OCTAL            = FALSE
    DATE_FORMAT             = 'AUTO'
    TIMESTAMP_FORMAT        = 'AUTO'
    COMPRESSION             = 'AUTO'
    COMMENT                 = 'Standard JSON: strips outer array, preserves nulls';

-- NDJSON (Newline-delimited JSON, one JSON object per line)
CREATE OR REPLACE FILE FORMAT MDF_FF_JSON_NDJSON
    TYPE                    = 'JSON'
    STRIP_OUTER_ARRAY       = FALSE              -- Each line is already one object
    STRIP_NULL_VALUES       = FALSE
    IGNORE_UTF8_ERRORS      = TRUE
    COMPRESSION             = 'AUTO'
    COMMENT                 = 'NDJSON: newline-delimited JSON, one object per line';

-- JSON with null stripping (for compact storage)
CREATE OR REPLACE FILE FORMAT MDF_FF_JSON_COMPACT
    TYPE                    = 'JSON'
    STRIP_OUTER_ARRAY       = TRUE
    STRIP_NULL_VALUES       = TRUE               -- Remove null keys for storage savings
    IGNORE_UTF8_ERRORS      = TRUE
    COMPRESSION             = 'AUTO'
    COMMENT                 = 'Compact JSON: strips nulls for storage optimization';

-- =========================================================================
-- PARQUET FILE FORMAT
-- =========================================================================

-- Standard Parquet (Parquet is self-describing, minimal config needed)
CREATE OR REPLACE FILE FORMAT MDF_FF_PARQUET_STANDARD
    TYPE                    = 'PARQUET'
    SNAPPY_COMPRESSION      = TRUE               -- Most Parquet files use Snappy
    BINARY_AS_TEXT          = TRUE                -- Convert binary fields to text
    COMMENT                 = 'Standard Parquet: Snappy compression, binary-as-text';

-- =========================================================================
-- AVRO FILE FORMAT
-- =========================================================================

-- Standard Avro
CREATE OR REPLACE FILE FORMAT MDF_FF_AVRO_STANDARD
    TYPE                    = 'AVRO'
    COMPRESSION             = 'AUTO'
    TRIM_SPACE              = TRUE
    COMMENT                 = 'Standard Avro format';

-- =========================================================================
-- ORC FILE FORMAT
-- =========================================================================

-- Standard ORC
CREATE OR REPLACE FILE FORMAT MDF_FF_ORC_STANDARD
    TYPE                    = 'ORC'
    TRIM_SPACE              = TRUE
    COMMENT                 = 'Standard ORC format';


-- =========================================================================
-- VERIFICATION QUERIES
-- =========================================================================

-- List all MDF file formats
SHOW FILE FORMATS IN SCHEMA MDF_CONTROL_DB.CONFIG;

-- Describe a specific file format
DESCRIBE FILE FORMAT MDF_FF_CSV_STANDARD;
DESCRIBE FILE FORMAT MDF_FF_JSON_STANDARD;
DESCRIBE FILE FORMAT MDF_FF_PARQUET_STANDARD;


/*
=============================================================================
  BEST PRACTICES & TIPS:

  1. CENTRALIZE FILE FORMATS: Keep all file formats in MDF_CONTROL_DB.CONFIG.
     Don't create file formats in individual data schemas — that leads to
     duplication and inconsistency.

  2. NULL_IF IS YOUR FRIEND: Different source systems represent nulls
     differently. Configure NULL_IF broadly in the file format so your
     downstream tables have consistent NULL values instead of 'NULL' strings.

  3. ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE: This is critical for files
     where columns may be added over time. Without this, a single extra
     column in the source file will fail the entire load.

  4. COMPRESSION = AUTO: Let Snowflake detect compression automatically.
     It handles gzip, bzip2, deflate, raw_deflate, zstd, and none.

  5. STRIP_OUTER_ARRAY FOR JSON: If your JSON file is a single array
     like [{"a":1},{"a":2}], STRIP_OUTER_ARRAY splits it into rows.
     Without this, you get one row containing the entire array.

  WHAT'S NEXT:
  → Module 02, Script 02: Internal and External Stages
=============================================================================
*/
