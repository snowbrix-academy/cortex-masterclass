/*
=============================================================================
  MODULE 04 : CORE STORED PROCEDURES
  SCRIPT 01 : SP_LOG_INGESTION — Audit Logging Procedure
=============================================================================
  SNOWBRIX ACADEMY — Metadata-Driven Ingestion Framework (MDF)

  LEARNING OBJECTIVES:
    1. Create a reusable logging procedure
    2. Understand how to write JavaScript stored procedures in Snowflake
    3. Handle both start and end logging in a single procedure
    4. Generate unique batch IDs for run tracking

  This is the FIRST procedure we create because all other procedures
  depend on it for logging.
=============================================================================
*/

USE ROLE MDF_ADMIN;
USE DATABASE MDF_CONTROL_DB;
USE SCHEMA PROCEDURES;
USE WAREHOUSE MDF_ADMIN_WH;

-- =========================================================================
-- PROCEDURE: SP_LOG_INGESTION
-- Logs ingestion events to the INGESTION_AUDIT_LOG table.
-- Called at the START and END of every ingestion run.
-- =========================================================================
CREATE OR REPLACE PROCEDURE SP_LOG_INGESTION(
    P_ACTION            VARCHAR,    -- 'START' or 'END'
    P_BATCH_ID          VARCHAR,    -- UUID for this run
    P_CONFIG_ID         NUMBER,     -- FK to INGESTION_CONFIG
    P_SOURCE_NAME       VARCHAR,    -- Source name for quick reference
    P_STATUS            VARCHAR,    -- 'STARTED','SUCCESS','PARTIAL_SUCCESS','FAILED','SKIPPED'
    P_FILES_PROCESSED   NUMBER,     -- Number of files processed
    P_FILES_SKIPPED     NUMBER,     -- Number of files skipped
    P_FILES_FAILED      NUMBER,     -- Number of files failed
    P_ROWS_LOADED       NUMBER,     -- Total rows loaded
    P_ROWS_FAILED       NUMBER,     -- Total rows failed
    P_BYTES_LOADED      NUMBER,     -- Total bytes loaded
    P_ERROR_CODE        VARCHAR,    -- Error code (if any)
    P_ERROR_MESSAGE     VARCHAR,    -- Error message (if any)
    P_COPY_COMMAND      VARCHAR,    -- The COPY INTO command executed
    P_COPY_RESULT       VARCHAR,    -- JSON string of COPY result
    P_FILES_LIST        VARCHAR,    -- JSON array of files processed
    P_WAREHOUSE_USED    VARCHAR     -- Warehouse name
)
RETURNS VARCHAR
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER
AS
$$
    try {
        if (P_ACTION === 'START') {
            // Log the start of an ingestion run
            var sql = `
                INSERT INTO MDF_CONTROL_DB.AUDIT.INGESTION_AUDIT_LOG (
                    BATCH_ID, CONFIG_ID, SOURCE_NAME, RUN_STATUS,
                    START_TIME, WAREHOUSE_USED, EXECUTED_BY
                ) VALUES (
                    :1, :2, :3, :4,
                    CURRENT_TIMESTAMP(), :5, CURRENT_USER()
                )
            `;
            snowflake.execute({
                sqlText: sql,
                binds: [P_BATCH_ID, P_CONFIG_ID, P_SOURCE_NAME, 'STARTED', P_WAREHOUSE_USED]
            });
            return 'AUDIT_LOG: Start record created for batch ' + P_BATCH_ID;

        } else if (P_ACTION === 'END') {
            // Update the existing record with results
            var sql = `
                UPDATE MDF_CONTROL_DB.AUDIT.INGESTION_AUDIT_LOG
                SET
                    RUN_STATUS          = :1,
                    END_TIME            = CURRENT_TIMESTAMP(),
                    DURATION_SECONDS    = DATEDIFF('SECOND', START_TIME, CURRENT_TIMESTAMP()),
                    FILES_PROCESSED     = :2,
                    FILES_SKIPPED       = :3,
                    FILES_FAILED        = :4,
                    ROWS_LOADED         = :5,
                    ROWS_FAILED         = :6,
                    BYTES_LOADED        = :7,
                    ERROR_CODE          = :8,
                    ERROR_MESSAGE       = :9,
                    COPY_COMMAND_EXECUTED = :10,
                    COPY_RESULT         = PARSE_JSON(:11),
                    FILES_LIST          = TRY_PARSE_JSON(:12)
                WHERE BATCH_ID = :13
                  AND SOURCE_NAME = :14
            `;
            snowflake.execute({
                sqlText: sql,
                binds: [
                    P_STATUS, P_FILES_PROCESSED, P_FILES_SKIPPED, P_FILES_FAILED,
                    P_ROWS_LOADED, P_ROWS_FAILED, P_BYTES_LOADED,
                    P_ERROR_CODE, P_ERROR_MESSAGE, P_COPY_COMMAND,
                    P_COPY_RESULT || '{}', P_FILES_LIST || '[]',
                    P_BATCH_ID, P_SOURCE_NAME
                ]
            });
            return 'AUDIT_LOG: End record updated for batch ' + P_BATCH_ID + ' with status ' + P_STATUS;
        } else {
            return 'AUDIT_LOG: Invalid action: ' + P_ACTION + '. Use START or END.';
        }
    } catch (err) {
        return 'AUDIT_LOG ERROR: ' + err.message;
    }
$$;


-- =========================================================================
-- PROCEDURE: SP_LOG_ERROR
-- Logs individual row/file errors to the INGESTION_ERROR_LOG table.
-- =========================================================================
CREATE OR REPLACE PROCEDURE SP_LOG_ERROR(
    P_BATCH_ID          VARCHAR,
    P_CONFIG_ID         NUMBER,
    P_SOURCE_NAME       VARCHAR,
    P_FILE_NAME         VARCHAR,
    P_ROW_NUMBER        NUMBER,
    P_COLUMN_NAME       VARCHAR,
    P_ERROR_CODE        VARCHAR,
    P_ERROR_MESSAGE     VARCHAR,
    P_REJECTED_RECORD   VARCHAR
)
RETURNS VARCHAR
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER
AS
$$
    try {
        var sql = `
            INSERT INTO MDF_CONTROL_DB.AUDIT.INGESTION_ERROR_LOG (
                BATCH_ID, CONFIG_ID, SOURCE_NAME,
                FILE_NAME, ROW_NUMBER, COLUMN_NAME,
                ERROR_CODE, ERROR_MESSAGE, REJECTED_RECORD
            ) VALUES (
                :1, :2, :3, :4, :5, :6, :7, :8, :9
            )
        `;
        snowflake.execute({
            sqlText: sql,
            binds: [
                P_BATCH_ID, P_CONFIG_ID, P_SOURCE_NAME,
                P_FILE_NAME, P_ROW_NUMBER, P_COLUMN_NAME,
                P_ERROR_CODE, P_ERROR_MESSAGE, P_REJECTED_RECORD
            ]
        });
        return 'ERROR_LOG: Record created for ' + P_SOURCE_NAME + ' in batch ' + P_BATCH_ID;
    } catch (err) {
        return 'ERROR_LOG ERROR: ' + err.message;
    }
$$;


-- =========================================================================
-- HELPER: SP_GENERATE_BATCH_ID
-- Generates a unique batch identifier for each ingestion run.
-- =========================================================================
CREATE OR REPLACE PROCEDURE SP_GENERATE_BATCH_ID()
RETURNS VARCHAR
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER
AS
$$
    var result = snowflake.execute({
        sqlText: "SELECT UUID_STRING() AS BATCH_ID"
    });
    result.next();
    return result.getColumnValue('BATCH_ID');
$$;


-- =========================================================================
-- VERIFICATION
-- =========================================================================

-- Test batch ID generation
CALL SP_GENERATE_BATCH_ID();

-- Test start logging
CALL SP_LOG_INGESTION(
    'START',                          -- P_ACTION
    'test-batch-001',                 -- P_BATCH_ID
    1,                                -- P_CONFIG_ID
    'TEST_SOURCE',                    -- P_SOURCE_NAME
    'STARTED',                        -- P_STATUS
    0, 0, 0, 0, 0, 0,               -- Metrics (all zeros for start)
    NULL, NULL, NULL, NULL, NULL,     -- Error/command fields (null for start)
    'MDF_INGESTION_WH'               -- P_WAREHOUSE_USED
);

-- Verify the start record
SELECT * FROM MDF_CONTROL_DB.AUDIT.INGESTION_AUDIT_LOG
WHERE BATCH_ID = 'test-batch-001';

-- Test end logging
CALL SP_LOG_INGESTION(
    'END',                            -- P_ACTION
    'test-batch-001',                 -- P_BATCH_ID
    1,                                -- P_CONFIG_ID
    'TEST_SOURCE',                    -- P_SOURCE_NAME
    'SUCCESS',                        -- P_STATUS
    5, 0, 0, 1000, 0, 50000,        -- 5 files, 1000 rows, 50KB
    NULL, NULL,                       -- No errors
    'COPY INTO test_table FROM @stage',
    '{"status":"LOADED"}',
    '["file1.csv","file2.csv"]',
    'MDF_INGESTION_WH'
);

-- Verify the end record
SELECT
    BATCH_ID, SOURCE_NAME, RUN_STATUS,
    DURATION_SECONDS, FILES_PROCESSED, ROWS_LOADED, BYTES_LOADED
FROM MDF_CONTROL_DB.AUDIT.INGESTION_AUDIT_LOG
WHERE BATCH_ID = 'test-batch-001';

-- Clean up test data
DELETE FROM MDF_CONTROL_DB.AUDIT.INGESTION_AUDIT_LOG WHERE BATCH_ID = 'test-batch-001';


/*
=============================================================================
  BEST PRACTICES & TIPS:

  1. BATCH_ID IS YOUR CORRELATION KEY: Every log entry, error record,
     and validation result shares the same batch_id. This lets you trace
     an entire run from start to finish across all tables.

  2. JAVASCRIPT PROCEDURES: We use JavaScript (not SQL Script) for
     complex procedures because it offers better error handling with
     try/catch and cleaner variable management.

  3. EXECUTE AS CALLER: This means the procedure runs with the
     permissions of whoever calls it, not the procedure owner.
     This respects the RBAC model we set up in Module 01.

  4. BIND VARIABLES: Always use :1, :2 syntax (bind variables) instead
     of string concatenation to prevent SQL injection.

  WHAT'S NEXT:
  → Module 04, Script 02: SP_GENERIC_INGESTION (The Main Engine)
=============================================================================
*/
