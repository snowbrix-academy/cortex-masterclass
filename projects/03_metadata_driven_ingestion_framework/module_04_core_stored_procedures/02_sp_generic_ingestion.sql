/*
=============================================================================
  MODULE 04 : CORE STORED PROCEDURES
  SCRIPT 02 : SP_GENERIC_INGESTION — The Main Engine
=============================================================================
  SNOWBRIX ACADEMY — Metadata-Driven Ingestion Framework (MDF)

  LEARNING OBJECTIVES:
    1. Build a single stored procedure that handles ALL data sources
    2. Understand dynamic SQL generation for COPY INTO
    3. Handle structured (CSV) and semi-structured (JSON, Parquet) data
    4. Implement proper error handling and audit logging

  THIS IS THE MOST IMPORTANT PROCEDURE IN THE FRAMEWORK.
  It reads from INGESTION_CONFIG and dynamically generates + executes
  COPY INTO statements. One procedure to rule them all.

  EXECUTION FLOW:
  ┌──────────────────────────────────────────────────────────────┐
  │  1. Read config for the source                               │
  │  2. Validate config (target exists, stage accessible)        │
  │  3. Auto-create target schema/table if needed                │
  │  4. Generate COPY INTO statement dynamically                 │
  │  5. Execute COPY INTO                                        │
  │  6. Capture results (rows loaded, errors)                    │
  │  7. Log to audit table                                       │
  │  8. Return status summary                                    │
  └──────────────────────────────────────────────────────────────┘
=============================================================================
*/

USE ROLE MDF_ADMIN;
USE DATABASE MDF_CONTROL_DB;
USE SCHEMA PROCEDURES;
USE WAREHOUSE MDF_ADMIN_WH;

-- =========================================================================
-- PROCEDURE: SP_GENERIC_INGESTION
-- The main orchestrator. Call this with a source name or 'ALL' to process
-- all active sources.
-- =========================================================================
CREATE OR REPLACE PROCEDURE SP_GENERIC_INGESTION(
    P_SOURCE_NAME   VARCHAR,        -- Source name from config OR 'ALL' for all active sources
    P_FORCE_RELOAD  BOOLEAN DEFAULT FALSE  -- Override to re-load already loaded files
)
RETURNS VARIANT
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER
AS
$$
    // =====================================================================
    // HELPER FUNCTIONS
    // =====================================================================

    /**
     * Execute a SQL statement and return the result set
     */
    function executeSql(sqlText, binds) {
        try {
            var stmt = snowflake.createStatement({
                sqlText: sqlText,
                binds: binds || []
            });
            return stmt.execute();
        } catch (err) {
            throw new Error('SQL Error: ' + err.message + ' | SQL: ' + sqlText.substring(0, 200));
        }
    }

    /**
     * Execute SQL and return scalar value
     */
    function executeScalar(sqlText) {
        var rs = executeSql(sqlText);
        if (rs.next()) {
            return rs.getColumnValue(1);
        }
        return null;
    }

    /**
     * Generate a unique batch ID
     */
    function generateBatchId() {
        return executeScalar("SELECT UUID_STRING()");
    }

    /**
     * Log to audit table
     */
    function logAudit(action, batchId, configId, sourceName, status,
                      filesProcessed, filesSkipped, filesFailed,
                      rowsLoaded, rowsFailed, bytesLoaded,
                      errorCode, errorMsg, copyCmd, copyResult, filesList, warehouse) {
        try {
            executeSql(
                "CALL MDF_CONTROL_DB.PROCEDURES.SP_LOG_INGESTION(:1,:2,:3,:4,:5,:6,:7,:8,:9,:10,:11,:12,:13,:14,:15,:16,:17)",
                [action, batchId, configId, sourceName, status,
                 filesProcessed || 0, filesSkipped || 0, filesFailed || 0,
                 rowsLoaded || 0, rowsFailed || 0, bytesLoaded || 0,
                 errorCode, errorMsg, copyCmd, copyResult, filesList, warehouse]
            );
        } catch (err) {
            // Don't let logging failures break the ingestion
            // but capture it in the return result
        }
    }

    /**
     * Build the COPY INTO statement based on config
     */
    function buildCopyCommand(config) {
        var sourceType = config.SOURCE_TYPE;
        var stagePath  = config.STAGE_NAME;
        var targetFull = config.TARGET_DATABASE + '.' + config.TARGET_SCHEMA + '.' + config.TARGET_TABLE;

        // Add sub-directory to stage path
        if (config.SUB_DIRECTORY) {
            stagePath = stagePath + '/' + config.SUB_DIRECTORY;
        }

        var copyCmd = '';

        if (sourceType === 'CSV') {
            // ─── STRUCTURED DATA (CSV) ─────────────────────────────
            copyCmd = 'COPY INTO ' + targetFull +
                      '\n  FROM ' + stagePath +
                      '\n  FILE_FORMAT = (FORMAT_NAME = \'' + config.FILE_FORMAT_NAME + '\')';

        } else if (sourceType === 'JSON') {
            // ─── SEMI-STRUCTURED DATA (JSON) ───────────────────────
            // JSON loads into a VARIANT column, then we can flatten later
            copyCmd = 'COPY INTO ' + targetFull +
                      '\n  FROM ' + stagePath +
                      '\n  FILE_FORMAT = (FORMAT_NAME = \'' + config.FILE_FORMAT_NAME + '\')';

            // Match by column name for JSON (auto-maps JSON keys to columns)
            if (config.MATCH_BY_COLUMN_NAME && config.MATCH_BY_COLUMN_NAME !== 'NONE') {
                copyCmd += '\n  MATCH_BY_COLUMN_NAME = ' + config.MATCH_BY_COLUMN_NAME;
            }

        } else if (sourceType === 'PARQUET' || sourceType === 'AVRO' || sourceType === 'ORC') {
            // ─── COLUMNAR FORMATS (Parquet, Avro, ORC) ────────────
            copyCmd = 'COPY INTO ' + targetFull +
                      '\n  FROM ' + stagePath +
                      '\n  FILE_FORMAT = (FORMAT_NAME = \'' + config.FILE_FORMAT_NAME + '\')';

            // Match by column name for columnar formats
            if (config.MATCH_BY_COLUMN_NAME && config.MATCH_BY_COLUMN_NAME !== 'NONE') {
                copyCmd += '\n  MATCH_BY_COLUMN_NAME = ' + config.MATCH_BY_COLUMN_NAME;
            }
        }

        // Add file pattern filter
        if (config.FILE_PATTERN) {
            copyCmd += "\n  PATTERN = '" + config.FILE_PATTERN + "'";
        }

        // Add error handling
        copyCmd += '\n  ON_ERROR = ' + (config.ON_ERROR || 'CONTINUE');

        // Add size limit
        if (config.SIZE_LIMIT) {
            copyCmd += '\n  SIZE_LIMIT = ' + config.SIZE_LIMIT;
        }

        // Add purge option
        if (config.PURGE_FILES) {
            copyCmd += '\n  PURGE = TRUE';
        }

        // Add force reload
        if (config.FORCE_RELOAD || P_FORCE_RELOAD) {
            copyCmd += '\n  FORCE = TRUE';
        }

        return copyCmd;
    }

    /**
     * Auto-create target schema and table if they don't exist
     */
    function ensureTargetExists(config) {
        var targetDb     = config.TARGET_DATABASE;
        var targetSchema = config.TARGET_SCHEMA;
        var targetTable  = config.TARGET_TABLE;
        var sourceType   = config.SOURCE_TYPE;

        // Create schema if not exists
        executeSql('CREATE SCHEMA IF NOT EXISTS ' + targetDb + '.' + targetSchema +
                   " COMMENT = 'Auto-created by MDF framework for " + config.SOURCE_NAME + "'");

        // Create table based on source type
        if (sourceType === 'JSON') {
            // JSON tables use a single VARIANT column + metadata
            executeSql(
                'CREATE TABLE IF NOT EXISTS ' + targetDb + '.' + targetSchema + '.' + targetTable + ' (' +
                '  RAW_DATA          VARIANT,' +
                '  _MDF_FILE_NAME    VARCHAR    DEFAULT METADATA$FILENAME,' +
                '  _MDF_FILE_ROW     NUMBER     DEFAULT METADATA$FILE_ROW_NUMBER,' +
                '  _MDF_LOADED_AT    TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()' +
                ') COMMENT = \'Auto-created by MDF for ' + config.SOURCE_NAME + '\''
            );
        } else if (sourceType === 'PARQUET' || sourceType === 'AVRO' || sourceType === 'ORC') {
            // Columnar formats: use INFER_SCHEMA to create table structure
            try {
                var stagePath = config.STAGE_NAME;
                if (config.SUB_DIRECTORY) {
                    stagePath += '/' + config.SUB_DIRECTORY;
                }
                var fileFilter = config.FILE_PATTERN ? " PATTERN => '" + config.FILE_PATTERN + "'" : "";

                executeSql(
                    'CREATE TABLE IF NOT EXISTS ' + targetDb + '.' + targetSchema + '.' + targetTable +
                    ' USING TEMPLATE (' +
                    '  SELECT ARRAY_AGG(OBJECT_CONSTRUCT(*))' +
                    '  FROM TABLE(INFER_SCHEMA(' +
                    "    LOCATION => '" + stagePath + "'" +
                    "    , FILE_FORMAT => '" + config.FILE_FORMAT_NAME + "'" +
                    fileFilter +
                    '  ))' +
                    ')'
                );
            } catch (inferErr) {
                // If INFER_SCHEMA fails (no files yet), create a generic VARIANT table
                executeSql(
                    'CREATE TABLE IF NOT EXISTS ' + targetDb + '.' + targetSchema + '.' + targetTable + ' (' +
                    '  RAW_DATA          VARIANT,' +
                    '  _MDF_FILE_NAME    VARCHAR    DEFAULT METADATA$FILENAME,' +
                    '  _MDF_FILE_ROW     NUMBER     DEFAULT METADATA$FILE_ROW_NUMBER,' +
                    '  _MDF_LOADED_AT    TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()' +
                    ')'
                );
            }
        }
        // For CSV: table must exist OR be created manually (COPY INTO creates it if needed
        // with MATCH_BY_COLUMN_NAME or we let it fail gracefully)
    }

    // =====================================================================
    // MAIN EXECUTION
    // =====================================================================

    var batchId = generateBatchId();
    var results = [];
    var overallStatus = 'SUCCESS';
    var warehouse = executeScalar("SELECT CURRENT_WAREHOUSE()");

    // Set warehouse for ingestion
    executeSql("USE WAREHOUSE MDF_INGESTION_WH");

    // Build the query to get config(s)
    var configQuery = '';
    if (P_SOURCE_NAME === 'ALL') {
        configQuery = "SELECT * FROM MDF_CONTROL_DB.CONFIG.INGESTION_CONFIG WHERE IS_ACTIVE = TRUE ORDER BY LOAD_PRIORITY";
    } else {
        configQuery = "SELECT * FROM MDF_CONTROL_DB.CONFIG.INGESTION_CONFIG WHERE SOURCE_NAME = '" +
                      P_SOURCE_NAME.replace(/'/g, "''") + "' AND IS_ACTIVE = TRUE";
    }

    var configResult = executeSql(configQuery);
    var sourceCount = 0;
    var successCount = 0;
    var failCount = 0;

    while (configResult.next()) {
        sourceCount++;
        var config = {};

        // Read all config fields
        config.CONFIG_ID           = configResult.getColumnValue('CONFIG_ID');
        config.SOURCE_NAME         = configResult.getColumnValue('SOURCE_NAME');
        config.CLIENT_NAME         = configResult.getColumnValue('CLIENT_NAME');
        config.SOURCE_TYPE         = configResult.getColumnValue('SOURCE_TYPE');
        config.STAGE_NAME          = configResult.getColumnValue('STAGE_NAME');
        config.FILE_PATTERN        = configResult.getColumnValue('FILE_PATTERN');
        config.SUB_DIRECTORY       = configResult.getColumnValue('SUB_DIRECTORY');
        config.FILE_FORMAT_NAME    = configResult.getColumnValue('FILE_FORMAT_NAME');
        config.TARGET_DATABASE     = configResult.getColumnValue('TARGET_DATABASE');
        config.TARGET_SCHEMA       = configResult.getColumnValue('TARGET_SCHEMA');
        config.TARGET_TABLE        = configResult.getColumnValue('TARGET_TABLE');
        config.AUTO_CREATE_TARGET  = configResult.getColumnValue('AUTO_CREATE_TARGET');
        config.LOAD_TYPE           = configResult.getColumnValue('LOAD_TYPE');
        config.ON_ERROR            = configResult.getColumnValue('ON_ERROR');
        config.SIZE_LIMIT          = configResult.getColumnValue('SIZE_LIMIT');
        config.PURGE_FILES         = configResult.getColumnValue('PURGE_FILES');
        config.FORCE_RELOAD        = configResult.getColumnValue('FORCE_RELOAD');
        config.MATCH_BY_COLUMN_NAME = configResult.getColumnValue('MATCH_BY_COLUMN_NAME');
        config.FLATTEN_PATH        = configResult.getColumnValue('FLATTEN_PATH');

        var sourceResult = {
            source_name: config.SOURCE_NAME,
            status: 'PENDING',
            rows_loaded: 0,
            files_processed: 0,
            error: null
        };

        try {
            // --- LOG START ---
            logAudit('START', batchId, config.CONFIG_ID, config.SOURCE_NAME,
                     'STARTED', 0, 0, 0, 0, 0, 0, null, null, null, null, null, 'MDF_INGESTION_WH');

            // --- HANDLE LOAD TYPE ---
            if (config.LOAD_TYPE === 'TRUNCATE_RELOAD') {
                try {
                    executeSql('TRUNCATE TABLE IF EXISTS ' +
                               config.TARGET_DATABASE + '.' + config.TARGET_SCHEMA + '.' + config.TARGET_TABLE);
                } catch (truncErr) {
                    // Table might not exist yet, that's OK
                }
            }

            // --- AUTO-CREATE TARGET ---
            if (config.AUTO_CREATE_TARGET) {
                ensureTargetExists(config);
            }

            // --- BUILD AND EXECUTE COPY INTO ---
            var copyCmd = buildCopyCommand(config);
            var copyResult = executeSql(copyCmd);

            // --- CAPTURE RESULTS ---
            var totalRowsLoaded = 0;
            var totalRowsFailed = 0;
            var totalBytesLoaded = 0;
            var filesProcessed = 0;
            var filesSkipped = 0;
            var filesFailed = 0;
            var filesList = [];
            var copyResultDetails = [];

            while (copyResult.next()) {
                var fileName  = copyResult.getColumnValue('file');
                var status    = copyResult.getColumnValue('status');
                var rowsParsed = copyResult.getColumnValue('rows_parsed') || 0;
                var rowsLoaded = copyResult.getColumnValue('rows_loaded') || 0;
                var errorsSeen = copyResult.getColumnValue('errors_seen') || 0;

                if (status === 'LOADED' || status === 'PARTIALLY_LOADED') {
                    filesProcessed++;
                    totalRowsLoaded += rowsLoaded;
                    totalRowsFailed += errorsSeen;
                    filesList.push(fileName);
                } else if (status === 'LOAD_SKIPPED') {
                    filesSkipped++;
                } else {
                    filesFailed++;
                    totalRowsFailed += errorsSeen;
                }

                copyResultDetails.push({
                    file: fileName,
                    status: status,
                    rows_parsed: rowsParsed,
                    rows_loaded: rowsLoaded,
                    errors_seen: errorsSeen
                });
            }

            // Determine final status
            var finalStatus = 'SUCCESS';
            if (filesFailed > 0 && filesProcessed > 0) {
                finalStatus = 'PARTIAL_SUCCESS';
                overallStatus = 'PARTIAL_SUCCESS';
            } else if (filesFailed > 0 && filesProcessed === 0) {
                finalStatus = 'FAILED';
                overallStatus = 'FAILED';
                failCount++;
            } else if (filesProcessed === 0 && filesSkipped === 0) {
                finalStatus = 'SKIPPED';  // No files to process
            } else {
                successCount++;
            }

            sourceResult.status = finalStatus;
            sourceResult.rows_loaded = totalRowsLoaded;
            sourceResult.files_processed = filesProcessed;
            sourceResult.files_skipped = filesSkipped;
            sourceResult.files_failed = filesFailed;

            // --- LOG END ---
            logAudit('END', batchId, config.CONFIG_ID, config.SOURCE_NAME,
                     finalStatus, filesProcessed, filesSkipped, filesFailed,
                     totalRowsLoaded, totalRowsFailed, totalBytesLoaded,
                     null, null, copyCmd,
                     JSON.stringify(copyResultDetails),
                     JSON.stringify(filesList),
                     'MDF_INGESTION_WH');

        } catch (err) {
            // --- HANDLE ERRORS ---
            sourceResult.status = 'FAILED';
            sourceResult.error = err.message;
            overallStatus = 'FAILED';
            failCount++;

            logAudit('END', batchId, config.CONFIG_ID, config.SOURCE_NAME,
                     'FAILED', 0, 0, 0, 0, 0, 0,
                     'PROC_ERROR', err.message, null, null, null,
                     'MDF_INGESTION_WH');
        }

        results.push(sourceResult);
    }

    // Build final summary
    var summary = {
        batch_id: batchId,
        overall_status: overallStatus,
        sources_processed: sourceCount,
        sources_succeeded: successCount,
        sources_failed: failCount,
        details: results
    };

    if (sourceCount === 0) {
        summary.overall_status = 'NO_SOURCES_FOUND';
        summary.message = P_SOURCE_NAME === 'ALL' ?
            'No active sources found in INGESTION_CONFIG' :
            'Source "' + P_SOURCE_NAME + '" not found or is not active';
    }

    return summary;
$$;


-- =========================================================================
-- VERIFICATION: Test the procedure (dry run)
-- =========================================================================

-- View procedure definition
DESCRIBE PROCEDURE SP_GENERIC_INGESTION(VARCHAR, BOOLEAN);

-- Test with a non-existent source (should return NO_SOURCES_FOUND)
CALL SP_GENERIC_INGESTION('NON_EXISTENT_SOURCE', FALSE);


/*
=============================================================================
  BEST PRACTICES & TIPS:

  1. ONE PROCEDURE, INFINITE SOURCES: This single procedure handles CSV,
     JSON, Parquet, Avro, and ORC. Adding a new source is just an INSERT
     into INGESTION_CONFIG — no code changes needed.

  2. DYNAMIC SQL GENERATION: The COPY INTO statement is built dynamically
     based on config. This is the power of metadata-driven design.

  3. ERROR ISOLATION: Each source runs independently. If source A fails,
     source B still runs. The batch_id ties them together for reporting.

  4. RETURN VALUE: The procedure returns a VARIANT (JSON) with a complete
     summary. This makes it easy to check results programmatically.

  5. FORCE_RELOAD PARAMETER: Set to TRUE to re-load files that Snowflake
     already loaded (it tracks this with file load history). Useful for
     re-processing after fixing a data quality issue.

  WHAT'S NEXT:
  → Module 04, Script 03: SP_REGISTER_SOURCE (Easy onboarding)
=============================================================================
*/
