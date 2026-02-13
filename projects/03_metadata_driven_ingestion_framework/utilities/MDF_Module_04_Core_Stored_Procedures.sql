/*
#############################################################################
  MDF - Module 04: Core Stored Procedures
  CONSOLIDATED WORKSHEET — Snowsight / VS Code Ready
#############################################################################
  SNOWBRIX ACADEMY — Metadata-Driven Ingestion Framework (MDF)

  This worksheet combines ALL Module 04 scripts into a single file:
    Part 1: SP_LOG_INGESTION — Audit Logging Procedure
    Part 2: SP_GENERIC_INGESTION — The Main Engine
    Part 3: SP_REGISTER_SOURCE — Easy Source Onboarding

  INSTRUCTIONS:
    - Run each section sequentially (top to bottom)
    - Requires Modules 01-03 to be completed first
    - Estimated time: ~20 minutes

  PREREQUISITES:
    - Modules 01-03 completed
    - MDF_ADMIN role access
#############################################################################
*/


-- ===========================================================================
-- ███████████████████████████████████████████████████████████████████████████
-- PART 1 OF 3: SP_LOG_INGESTION — AUDIT LOGGING
-- ███████████████████████████████████████████████████████████████████████████
-- ===========================================================================

USE ROLE MDF_ADMIN;
USE DATABASE MDF_CONTROL_DB;
USE SCHEMA PROCEDURES;
USE WAREHOUSE MDF_ADMIN_WH;

-- SP_LOG_INGESTION: Logs ingestion events to the audit log
CREATE OR REPLACE PROCEDURE SP_LOG_INGESTION(
    P_ACTION            VARCHAR,
    P_BATCH_ID          VARCHAR,
    P_CONFIG_ID         NUMBER,
    P_SOURCE_NAME       VARCHAR,
    P_STATUS            VARCHAR,
    P_FILES_PROCESSED   NUMBER,
    P_FILES_SKIPPED     NUMBER,
    P_FILES_FAILED      NUMBER,
    P_ROWS_LOADED       NUMBER,
    P_ROWS_FAILED       NUMBER,
    P_BYTES_LOADED      NUMBER,
    P_ERROR_CODE        VARCHAR,
    P_ERROR_MESSAGE     VARCHAR,
    P_COPY_COMMAND      VARCHAR,
    P_COPY_RESULT       VARCHAR,
    P_FILES_LIST        VARCHAR,
    P_WAREHOUSE_USED    VARCHAR
)
RETURNS VARCHAR
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER
AS
$$
    try {
        if (P_ACTION === 'START') {
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

-- SP_LOG_ERROR: Logs individual row/file errors
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

-- SP_GENERATE_BATCH_ID: Generates a unique batch identifier
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

-- VERIFICATION: Audit Logging
CALL SP_GENERATE_BATCH_ID();

CALL SP_LOG_INGESTION(
    'START', 'test-batch-001', 1, 'TEST_SOURCE', 'STARTED',
    0, 0, 0, 0, 0, 0,
    NULL, NULL, NULL, NULL, NULL,
    'MDF_INGESTION_WH'
);

SELECT * FROM MDF_CONTROL_DB.AUDIT.INGESTION_AUDIT_LOG WHERE BATCH_ID = 'test-batch-001';

CALL SP_LOG_INGESTION(
    'END', 'test-batch-001', 1, 'TEST_SOURCE', 'SUCCESS',
    5, 0, 0, 1000, 0, 50000,
    NULL, NULL,
    'COPY INTO test_table FROM @stage',
    '{"status":"LOADED"}',
    '["file1.csv","file2.csv"]',
    'MDF_INGESTION_WH'
);

SELECT BATCH_ID, SOURCE_NAME, RUN_STATUS, DURATION_SECONDS, FILES_PROCESSED, ROWS_LOADED, BYTES_LOADED
FROM MDF_CONTROL_DB.AUDIT.INGESTION_AUDIT_LOG
WHERE BATCH_ID = 'test-batch-001';

-- Clean up test data
DELETE FROM MDF_CONTROL_DB.AUDIT.INGESTION_AUDIT_LOG WHERE BATCH_ID = 'test-batch-001';


-- ===========================================================================
-- ███████████████████████████████████████████████████████████████████████████
-- PART 2 OF 3: SP_GENERIC_INGESTION — THE MAIN ENGINE
-- ███████████████████████████████████████████████████████████████████████████
-- ===========================================================================

/*
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
*/

USE ROLE MDF_ADMIN;
USE DATABASE MDF_CONTROL_DB;
USE SCHEMA PROCEDURES;
USE WAREHOUSE MDF_ADMIN_WH;

CREATE OR REPLACE PROCEDURE SP_GENERIC_INGESTION(
    P_SOURCE_NAME   VARCHAR,
    P_FORCE_RELOAD  BOOLEAN DEFAULT FALSE
)
RETURNS VARIANT
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER
AS
$$
    // HELPER FUNCTIONS
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

    function executeScalar(sqlText) {
        var rs = executeSql(sqlText);
        if (rs.next()) {
            return rs.getColumnValue(1);
        }
        return null;
    }

    function generateBatchId() {
        return executeScalar("SELECT UUID_STRING()");
    }

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
        }
    }

    function buildCopyCommand(config) {
        var sourceType = config.SOURCE_TYPE;
        var stagePath  = config.STAGE_NAME;
        var targetFull = config.TARGET_DATABASE + '.' + config.TARGET_SCHEMA + '.' + config.TARGET_TABLE;

        if (config.SUB_DIRECTORY) {
            stagePath = stagePath + '/' + config.SUB_DIRECTORY;
        }

        var copyCmd = '';

        if (sourceType === 'CSV') {
            copyCmd = 'COPY INTO ' + targetFull +
                      '\n  FROM ' + stagePath +
                      '\n  FILE_FORMAT = (FORMAT_NAME = \'' + config.FILE_FORMAT_NAME + '\')';

        } else if (sourceType === 'JSON') {
            copyCmd = 'COPY INTO ' + targetFull +
                      '\n  FROM ' + stagePath +
                      '\n  FILE_FORMAT = (FORMAT_NAME = \'' + config.FILE_FORMAT_NAME + '\')';

            if (config.MATCH_BY_COLUMN_NAME && config.MATCH_BY_COLUMN_NAME !== 'NONE') {
                copyCmd += '\n  MATCH_BY_COLUMN_NAME = ' + config.MATCH_BY_COLUMN_NAME;
            }

        } else if (sourceType === 'PARQUET' || sourceType === 'AVRO' || sourceType === 'ORC') {
            copyCmd = 'COPY INTO ' + targetFull +
                      '\n  FROM ' + stagePath +
                      '\n  FILE_FORMAT = (FORMAT_NAME = \'' + config.FILE_FORMAT_NAME + '\')';

            if (config.MATCH_BY_COLUMN_NAME && config.MATCH_BY_COLUMN_NAME !== 'NONE') {
                copyCmd += '\n  MATCH_BY_COLUMN_NAME = ' + config.MATCH_BY_COLUMN_NAME;
            }
        }

        if (config.FILE_PATTERN) {
            copyCmd += "\n  PATTERN = '" + config.FILE_PATTERN + "'";
        }
        copyCmd += '\n  ON_ERROR = ' + (config.ON_ERROR || 'CONTINUE');
        if (config.SIZE_LIMIT) {
            copyCmd += '\n  SIZE_LIMIT = ' + config.SIZE_LIMIT;
        }
        if (config.PURGE_FILES) {
            copyCmd += '\n  PURGE = TRUE';
        }
        if (config.FORCE_RELOAD || P_FORCE_RELOAD) {
            copyCmd += '\n  FORCE = TRUE';
        }

        return copyCmd;
    }

    function ensureTargetExists(config) {
        var targetDb     = config.TARGET_DATABASE;
        var targetSchema = config.TARGET_SCHEMA;
        var targetTable  = config.TARGET_TABLE;
        var sourceType   = config.SOURCE_TYPE;

        executeSql('CREATE SCHEMA IF NOT EXISTS ' + targetDb + '.' + targetSchema +
                   " COMMENT = 'Auto-created by MDF framework for " + config.SOURCE_NAME + "'");

        if (sourceType === 'JSON') {
            executeSql(
                'CREATE TABLE IF NOT EXISTS ' + targetDb + '.' + targetSchema + '.' + targetTable + ' (' +
                '  RAW_DATA          VARIANT,' +
                '  _MDF_FILE_NAME    VARCHAR    DEFAULT METADATA$FILENAME,' +
                '  _MDF_FILE_ROW     NUMBER     DEFAULT METADATA$FILE_ROW_NUMBER,' +
                '  _MDF_LOADED_AT    TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()' +
                ') COMMENT = \'Auto-created by MDF for ' + config.SOURCE_NAME + '\''
            );
        } else if (sourceType === 'PARQUET' || sourceType === 'AVRO' || sourceType === 'ORC') {
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
    }

    // MAIN EXECUTION
    var batchId = generateBatchId();
    var results = [];
    var overallStatus = 'SUCCESS';
    var warehouse = executeScalar("SELECT CURRENT_WAREHOUSE()");

    executeSql("USE WAREHOUSE MDF_INGESTION_WH");

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
            logAudit('START', batchId, config.CONFIG_ID, config.SOURCE_NAME,
                     'STARTED', 0, 0, 0, 0, 0, 0, null, null, null, null, null, 'MDF_INGESTION_WH');

            if (config.LOAD_TYPE === 'TRUNCATE_RELOAD') {
                try {
                    executeSql('TRUNCATE TABLE IF EXISTS ' +
                               config.TARGET_DATABASE + '.' + config.TARGET_SCHEMA + '.' + config.TARGET_TABLE);
                } catch (truncErr) { }
            }

            if (config.AUTO_CREATE_TARGET) {
                ensureTargetExists(config);
            }

            var copyCmd = buildCopyCommand(config);
            var copyResult = executeSql(copyCmd);

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
                    file: fileName, status: status,
                    rows_parsed: rowsParsed, rows_loaded: rowsLoaded,
                    errors_seen: errorsSeen
                });
            }

            var finalStatus = 'SUCCESS';
            if (filesFailed > 0 && filesProcessed > 0) {
                finalStatus = 'PARTIAL_SUCCESS';
                overallStatus = 'PARTIAL_SUCCESS';
            } else if (filesFailed > 0 && filesProcessed === 0) {
                finalStatus = 'FAILED';
                overallStatus = 'FAILED';
                failCount++;
            } else if (filesProcessed === 0 && filesSkipped === 0) {
                finalStatus = 'SKIPPED';
            } else {
                successCount++;
            }

            sourceResult.status = finalStatus;
            sourceResult.rows_loaded = totalRowsLoaded;
            sourceResult.files_processed = filesProcessed;
            sourceResult.files_skipped = filesSkipped;
            sourceResult.files_failed = filesFailed;

            logAudit('END', batchId, config.CONFIG_ID, config.SOURCE_NAME,
                     finalStatus, filesProcessed, filesSkipped, filesFailed,
                     totalRowsLoaded, totalRowsFailed, totalBytesLoaded,
                     null, null, copyCmd,
                     JSON.stringify(copyResultDetails),
                     JSON.stringify(filesList),
                     'MDF_INGESTION_WH');

        } catch (err) {
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

-- VERIFICATION: SP_GENERIC_INGESTION
DESCRIBE PROCEDURE SP_GENERIC_INGESTION(VARCHAR, BOOLEAN);
CALL SP_GENERIC_INGESTION('NON_EXISTENT_SOURCE', FALSE);


-- ===========================================================================
-- ███████████████████████████████████████████████████████████████████████████
-- PART 3 OF 3: SP_REGISTER_SOURCE — EASY ONBOARDING
-- ███████████████████████████████████████████████████████████████████████████
-- ===========================================================================

USE ROLE MDF_ADMIN;
USE DATABASE MDF_CONTROL_DB;
USE SCHEMA PROCEDURES;
USE WAREHOUSE MDF_ADMIN_WH;

CREATE OR REPLACE PROCEDURE SP_REGISTER_SOURCE(
    P_SOURCE_NAME       VARCHAR,
    P_CLIENT_NAME       VARCHAR,
    P_SOURCE_TYPE       VARCHAR,
    P_TARGET_TABLE      VARCHAR,
    P_FILE_PATTERN      VARCHAR,
    P_SUB_DIRECTORY     VARCHAR DEFAULT NULL,
    P_LOAD_TYPE         VARCHAR DEFAULT 'APPEND',
    P_LOAD_FREQUENCY    VARCHAR DEFAULT 'DAILY',
    P_SOURCE_SYSTEM     VARCHAR DEFAULT NULL,
    P_DESCRIPTION       VARCHAR DEFAULT NULL
)
RETURNS VARCHAR
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER
AS
$$
    var errors = [];

    if (!P_SOURCE_NAME || P_SOURCE_NAME.trim() === '') {
        errors.push('SOURCE_NAME is required');
    }
    if (!P_CLIENT_NAME || P_CLIENT_NAME.trim() === '') {
        errors.push('CLIENT_NAME is required');
    }

    var validTypes = ['CSV', 'JSON', 'PARQUET', 'AVRO', 'ORC'];
    P_SOURCE_TYPE = (P_SOURCE_TYPE || '').toUpperCase().trim();
    if (validTypes.indexOf(P_SOURCE_TYPE) === -1) {
        errors.push('SOURCE_TYPE must be one of: ' + validTypes.join(', '));
    }

    var validLoadTypes = ['APPEND', 'TRUNCATE_RELOAD', 'MERGE'];
    P_LOAD_TYPE = (P_LOAD_TYPE || 'APPEND').toUpperCase().trim();
    if (validLoadTypes.indexOf(P_LOAD_TYPE) === -1) {
        errors.push('LOAD_TYPE must be one of: ' + validLoadTypes.join(', '));
    }

    var validFreqs = ['HOURLY', 'DAILY', 'WEEKLY', 'MONTHLY', 'ON_DEMAND'];
    P_LOAD_FREQUENCY = (P_LOAD_FREQUENCY || 'DAILY').toUpperCase().trim();
    if (validFreqs.indexOf(P_LOAD_FREQUENCY) === -1) {
        errors.push('LOAD_FREQUENCY must be one of: ' + validFreqs.join(', '));
    }

    if (P_SOURCE_NAME) {
        var dupCheck = snowflake.execute({
            sqlText: "SELECT COUNT(*) FROM MDF_CONTROL_DB.CONFIG.INGESTION_CONFIG WHERE SOURCE_NAME = :1",
            binds: [P_SOURCE_NAME.trim()]
        });
        dupCheck.next();
        if (dupCheck.getColumnValue(1) > 0) {
            errors.push('SOURCE_NAME "' + P_SOURCE_NAME + '" already exists. Use a unique name.');
        }
    }

    if (errors.length > 0) {
        return 'REGISTRATION FAILED:\n  - ' + errors.join('\n  - ');
    }

    var fileFormatMap = {
        'CSV':     'MDF_CONTROL_DB.CONFIG.MDF_FF_CSV_STANDARD',
        'JSON':    'MDF_CONTROL_DB.CONFIG.MDF_FF_JSON_STANDARD',
        'PARQUET': 'MDF_CONTROL_DB.CONFIG.MDF_FF_PARQUET_STANDARD',
        'AVRO':    'MDF_CONTROL_DB.CONFIG.MDF_FF_AVRO_STANDARD',
        'ORC':     'MDF_CONTROL_DB.CONFIG.MDF_FF_ORC_STANDARD'
    };
    var fileFormatName = fileFormatMap[P_SOURCE_TYPE];

    var stageMap = {
        'CSV':     '@MDF_CONTROL_DB.CONFIG.MDF_STG_INTERNAL_CSV',
        'JSON':    '@MDF_CONTROL_DB.CONFIG.MDF_STG_INTERNAL_JSON',
        'PARQUET': '@MDF_CONTROL_DB.CONFIG.MDF_STG_INTERNAL_PARQUET',
        'AVRO':    '@MDF_CONTROL_DB.CONFIG.MDF_STG_INTERNAL_PARQUET',
        'ORC':     '@MDF_CONTROL_DB.CONFIG.MDF_STG_INTERNAL_PARQUET'
    };
    var stageName = stageMap[P_SOURCE_TYPE];

    var targetSchema = P_CLIENT_NAME.toUpperCase().trim();
    if (P_SOURCE_SYSTEM) {
        targetSchema = targetSchema + '_' + P_SOURCE_SYSTEM.toUpperCase().trim();
    }

    var description = P_DESCRIPTION || ('Auto-registered source: ' + P_SOURCE_NAME);

    var matchByColumnName = 'NONE';
    if (P_SOURCE_TYPE === 'PARQUET' || P_SOURCE_TYPE === 'AVRO' || P_SOURCE_TYPE === 'ORC') {
        matchByColumnName = 'CASE_INSENSITIVE';
    }

    try {
        var insertSql = `
            INSERT INTO MDF_CONTROL_DB.CONFIG.INGESTION_CONFIG (
                SOURCE_NAME, SOURCE_DESCRIPTION, CLIENT_NAME, SOURCE_SYSTEM, SOURCE_TYPE,
                STAGE_NAME, FILE_PATTERN, SUB_DIRECTORY,
                FILE_FORMAT_NAME,
                TARGET_DATABASE, TARGET_SCHEMA, TARGET_TABLE,
                LOAD_TYPE, LOAD_FREQUENCY, MATCH_BY_COLUMN_NAME,
                IS_ACTIVE
            ) VALUES (
                :1, :2, :3, :4, :5,
                :6, :7, :8,
                :9,
                'MDF_RAW_DB', :10, :11,
                :12, :13, :14,
                TRUE
            )
        `;

        snowflake.execute({
            sqlText: insertSql,
            binds: [
                P_SOURCE_NAME.trim(), description,
                P_CLIENT_NAME.trim().toUpperCase(),
                P_SOURCE_SYSTEM ? P_SOURCE_SYSTEM.trim().toUpperCase() : null,
                P_SOURCE_TYPE,
                stageName, P_FILE_PATTERN, P_SUB_DIRECTORY,
                fileFormatName,
                targetSchema, P_TARGET_TABLE.trim().toUpperCase(),
                P_LOAD_TYPE, P_LOAD_FREQUENCY, matchByColumnName
            ]
        });

        var msg = 'SOURCE REGISTERED SUCCESSFULLY!\n\n';
        msg += '  Source Name:     ' + P_SOURCE_NAME + '\n';
        msg += '  Client:          ' + P_CLIENT_NAME.toUpperCase() + '\n';
        msg += '  Type:            ' + P_SOURCE_TYPE + '\n';
        msg += '  File Format:     ' + fileFormatName + '\n';
        msg += '  Stage:           ' + stageName + '\n';
        msg += '  Target:          MDF_RAW_DB.' + targetSchema + '.' + P_TARGET_TABLE.toUpperCase() + '\n';
        msg += '  Load Type:       ' + P_LOAD_TYPE + '\n';
        msg += '  Frequency:       ' + P_LOAD_FREQUENCY + '\n';
        msg += '  Active:          TRUE\n\n';
        msg += 'NEXT STEPS:\n';
        msg += '  1. Upload files to stage: PUT file://path/' + (P_FILE_PATTERN || '*') + ' ' + stageName + (P_SUB_DIRECTORY ? '/' + P_SUB_DIRECTORY : '') + '\n';
        msg += '  2. Run ingestion: CALL MDF_CONTROL_DB.PROCEDURES.SP_GENERIC_INGESTION(\'' + P_SOURCE_NAME + '\', FALSE);\n';
        msg += '  3. Check results: SELECT * FROM MDF_CONTROL_DB.AUDIT.INGESTION_AUDIT_LOG WHERE SOURCE_NAME = \'' + P_SOURCE_NAME + '\';';

        return msg;

    } catch (err) {
        return 'REGISTRATION FAILED: ' + err.message;
    }
$$;

-- SP_DEACTIVATE_SOURCE: Safely deactivate a source (soft delete)
CREATE OR REPLACE PROCEDURE SP_DEACTIVATE_SOURCE(
    P_SOURCE_NAME VARCHAR
)
RETURNS VARCHAR
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER
AS
$$
    try {
        var rs = snowflake.execute({
            sqlText: "UPDATE MDF_CONTROL_DB.CONFIG.INGESTION_CONFIG SET IS_ACTIVE = FALSE, UPDATED_BY = CURRENT_USER(), UPDATED_AT = CURRENT_TIMESTAMP() WHERE SOURCE_NAME = :1",
            binds: [P_SOURCE_NAME]
        });

        if (rs.getNumRowsAffected() === 0) {
            return 'Source "' + P_SOURCE_NAME + '" not found.';
        }
        return 'Source "' + P_SOURCE_NAME + '" has been deactivated. It will no longer be processed by the framework.';
    } catch (err) {
        return 'ERROR: ' + err.message;
    }
$$;

-- VERIFICATION: SP_REGISTER_SOURCE
CALL SP_REGISTER_SOURCE(
    'TEST_REGISTRATION_CSV', 'TEST_CLIENT', 'CSV', 'RAW_TEST_DATA',
    '.*test.*[.]csv', 'test/data/', 'APPEND', 'DAILY',
    'TEST_SYSTEM', 'Test registration from Module 04 lab'
);

SELECT SOURCE_NAME, CLIENT_NAME, SOURCE_TYPE, TARGET_SCHEMA, TARGET_TABLE, IS_ACTIVE
FROM MDF_CONTROL_DB.CONFIG.INGESTION_CONFIG
WHERE SOURCE_NAME = 'TEST_REGISTRATION_CSV';

CALL SP_DEACTIVATE_SOURCE('TEST_REGISTRATION_CSV');

-- Clean up test
DELETE FROM MDF_CONTROL_DB.CONFIG.INGESTION_CONFIG WHERE SOURCE_NAME = 'TEST_REGISTRATION_CSV';


/*
#############################################################################
  MODULE 04 COMPLETE!

  Procedures Created:
    - SP_LOG_INGESTION (audit logging — START/END)
    - SP_LOG_ERROR (individual error logging)
    - SP_GENERATE_BATCH_ID (UUID generation)
    - SP_GENERIC_INGESTION (the main engine — handles all file types)
    - SP_REGISTER_SOURCE (simplified source onboarding)
    - SP_DEACTIVATE_SOURCE (soft delete)

  Next: MDF - Module 05 (CSV Ingestion Lab)
#############################################################################
*/
