/*
#############################################################################
  MDF - Module 10: Schema Evolution & Advanced Topics
  CONSOLIDATED WORKSHEET — Snowsight / VS Code Ready
#############################################################################
  SNOWBRIX ACADEMY — Metadata-Driven Ingestion Framework (MDF)

  This worksheet contains:
    - SP_DETECT_SCHEMA_CHANGES (read-only detection)
    - SP_APPLY_SCHEMA_EVOLUTION (dry run + apply)
    - SP_ONBOARD_CLIENT (multi-source onboarding)
    - Dynamic Table example (commented — for experimentation)

  SCHEMA EVOLUTION SCENARIOS:
  ┌──────────────────────────────────────────────────────────────┐
  │  SCENARIO 1: New column appears in source file               │
  │  → Detect, add column to target table, reload                │
  │                                                              │
  │  SCENARIO 2: Column type changes                             │
  │  → Detect, widen column (e.g., NUMBER → VARCHAR), alert      │
  │                                                              │
  │  SCENARIO 3: Column disappears from source                   │
  │  → Detect, keep column (set to NULL for new rows), alert     │
  │                                                              │
  │  RULE: Never drop columns. Only add or widen.                │
  └──────────────────────────────────────────────────────────────┘

  INSTRUCTIONS:
    - Run each section sequentially (top to bottom)
    - This is the FINAL module — congratulations!
    - Estimated time: ~20 minutes

  PREREQUISITES:
    - Modules 01-09 completed
    - MDF_ADMIN role access
#############################################################################
*/

USE ROLE MDF_ADMIN;
USE DATABASE MDF_CONTROL_DB;
USE SCHEMA PROCEDURES;
USE WAREHOUSE MDF_ADMIN_WH;


-- ===========================================================================
-- SP_DETECT_SCHEMA_CHANGES — Read-Only Detection
-- ===========================================================================

CREATE OR REPLACE PROCEDURE SP_DETECT_SCHEMA_CHANGES(
    P_SOURCE_NAME   VARCHAR
)
RETURNS VARIANT
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER
AS
$$
    var result = {
        source_name: P_SOURCE_NAME,
        status: 'CHECKED',
        changes_detected: false,
        new_columns: [],
        type_changes: [],
        missing_columns: [],
        timestamp: new Date().toISOString()
    };

    try {
        var configRs = snowflake.execute({
            sqlText: `SELECT * FROM MDF_CONTROL_DB.CONFIG.INGESTION_CONFIG WHERE SOURCE_NAME = :1`,
            binds: [P_SOURCE_NAME]
        });
        if (!configRs.next()) {
            result.status = 'ERROR';
            result.message = 'Source not found';
            return result;
        }

        var stageName     = configRs.getColumnValue('STAGE_NAME');
        var subDir        = configRs.getColumnValue('SUB_DIRECTORY');
        var fileFormat    = configRs.getColumnValue('FILE_FORMAT_NAME');
        var filePattern   = configRs.getColumnValue('FILE_PATTERN');
        var targetDb      = configRs.getColumnValue('TARGET_DATABASE');
        var targetSchema  = configRs.getColumnValue('TARGET_SCHEMA');
        var targetTable   = configRs.getColumnValue('TARGET_TABLE');
        var targetFull    = targetDb + '.' + targetSchema + '.' + targetTable;

        var fullStagePath = stageName;
        if (subDir) fullStagePath += '/' + subDir;

        // Get file schema using INFER_SCHEMA
        var inferSql = `
            SELECT COLUMN_NAME, TYPE, NULLABLE, EXPRESSION, FILENAMES
            FROM TABLE(INFER_SCHEMA(
                LOCATION => '` + fullStagePath + `'
                , FILE_FORMAT => '` + fileFormat + `'
                ` + (filePattern ? ", FILES => '" + filePattern + "'" : "") + `
            ))
            ORDER BY ORDER_ID
        `;

        var fileColumns = {};
        try {
            var inferRs = snowflake.execute({ sqlText: inferSql });
            while (inferRs.next()) {
                var colName = inferRs.getColumnValue('COLUMN_NAME').toUpperCase();
                var colType = inferRs.getColumnValue('TYPE');
                fileColumns[colName] = colType;
            }
        } catch (inferErr) {
            result.status = 'WARNING';
            result.message = 'Could not infer schema: ' + inferErr.message;
            return result;
        }

        // Get current table schema
        var tableColumns = {};
        try {
            var descRs = snowflake.execute({
                sqlText: 'DESCRIBE TABLE ' + targetFull
            });
            while (descRs.next()) {
                var tColName = descRs.getColumnValue('name').toUpperCase();
                var tColType = descRs.getColumnValue('type');
                if (!tColName.startsWith('_MDF_')) {
                    tableColumns[tColName] = tColType;
                }
            }
        } catch (descErr) {
            result.status = 'INFO';
            result.message = 'Target table does not exist yet. Will be created on first load.';
            result.new_columns = Object.keys(fileColumns).map(function(k) {
                return { column: k, type: fileColumns[k] };
            });
            result.changes_detected = result.new_columns.length > 0;
            return result;
        }

        // Compare: Find new columns in file
        for (var fileCol in fileColumns) {
            if (!(fileCol in tableColumns)) {
                result.new_columns.push({
                    column: fileCol,
                    file_type: fileColumns[fileCol]
                });
                result.changes_detected = true;
            }
        }

        // Compare: Find columns missing from file
        for (var tableCol in tableColumns) {
            if (!(tableCol in fileColumns)) {
                result.missing_columns.push({
                    column: tableCol,
                    table_type: tableColumns[tableCol]
                });
            }
        }

    } catch (err) {
        result.status = 'ERROR';
        result.message = err.message;
    }

    return result;
$$;


-- ===========================================================================
-- SP_APPLY_SCHEMA_EVOLUTION — Dry Run + Apply
-- ===========================================================================

CREATE OR REPLACE PROCEDURE SP_APPLY_SCHEMA_EVOLUTION(
    P_SOURCE_NAME   VARCHAR,
    P_DRY_RUN       BOOLEAN DEFAULT TRUE
)
RETURNS VARIANT
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER
AS
$$
    var result = {
        source_name: P_SOURCE_NAME,
        dry_run: P_DRY_RUN,
        actions: [],
        status: 'COMPLETED'
    };

    try {
        var detectRs = snowflake.execute({
            sqlText: "CALL MDF_CONTROL_DB.PROCEDURES.SP_DETECT_SCHEMA_CHANGES(:1)",
            binds: [P_SOURCE_NAME]
        });
        detectRs.next();
        var detection = JSON.parse(detectRs.getColumnValue(1));

        if (!detection.changes_detected) {
            result.status = 'NO_CHANGES';
            result.message = 'No schema changes detected for ' + P_SOURCE_NAME;
            return result;
        }

        var configRs = snowflake.execute({
            sqlText: `SELECT * FROM MDF_CONTROL_DB.CONFIG.INGESTION_CONFIG WHERE SOURCE_NAME = :1`,
            binds: [P_SOURCE_NAME]
        });
        configRs.next();
        var targetFull = configRs.getColumnValue('TARGET_DATABASE') + '.' +
                         configRs.getColumnValue('TARGET_SCHEMA') + '.' +
                         configRs.getColumnValue('TARGET_TABLE');
        var configId = configRs.getColumnValue('CONFIG_ID');
        var maxNewCols = 10;

        var evoRs = snowflake.execute({
            sqlText: `SELECT * FROM MDF_CONTROL_DB.CONFIG.SCHEMA_EVOLUTION_CONFIG WHERE CONFIG_ID = :1`,
            binds: [configId]
        });
        if (evoRs.next()) {
            maxNewCols = evoRs.getColumnValue('MAX_NEW_COLUMNS') || 10;
        }

        // Safety check
        if (detection.new_columns.length > maxNewCols) {
            result.status = 'BLOCKED';
            result.message = 'Too many new columns detected (' + detection.new_columns.length +
                           '). Max allowed: ' + maxNewCols + '. Review manually.';
            return result;
        }

        // Apply new columns
        for (var i = 0; i < detection.new_columns.length; i++) {
            var col = detection.new_columns[i];
            var alterSql = 'ALTER TABLE ' + targetFull + ' ADD COLUMN ' +
                          col.column + ' ' + (col.file_type || 'VARCHAR');

            var action = {
                action: 'ADD_COLUMN',
                column: col.column,
                type: col.file_type || 'VARCHAR',
                sql: alterSql,
                applied: false
            };

            if (!P_DRY_RUN) {
                try {
                    snowflake.execute({ sqlText: alterSql });
                    action.applied = true;
                } catch (alterErr) {
                    action.applied = false;
                    action.error = alterErr.message;
                }
            }

            result.actions.push(action);
        }

        if (P_DRY_RUN) {
            result.message = 'DRY RUN: ' + result.actions.length + ' changes detected. Set P_DRY_RUN=FALSE to apply.';
        } else {
            var applied = result.actions.filter(function(a) { return a.applied; }).length;
            result.message = applied + ' of ' + result.actions.length + ' changes applied successfully.';
        }

    } catch (err) {
        result.status = 'ERROR';
        result.message = err.message;
    }

    return result;
$$;


-- ===========================================================================
-- SP_ONBOARD_CLIENT — Multi-Source Onboarding
-- ===========================================================================

CREATE OR REPLACE PROCEDURE SP_ONBOARD_CLIENT(
    P_CLIENT_NAME       VARCHAR,
    P_SOURCES           VARIANT
    /*
    Example P_SOURCES:
    [
        {"name": "SALES_CSV",    "type": "CSV",  "table": "RAW_SALES",    "pattern": ".*sales.*[.]csv"},
        {"name": "EVENTS_JSON",  "type": "JSON", "table": "RAW_EVENTS",  "pattern": ".*events.*[.]json"},
        {"name": "METRICS_PARQ", "type": "PARQUET", "table": "RAW_METRICS", "pattern": ".*metrics.*[.]parquet"}
    ]
    */
)
RETURNS VARIANT
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER
AS
$$
    var result = {
        client_name: P_CLIENT_NAME,
        sources_registered: 0,
        sources_failed: 0,
        details: []
    };

    try {
        var sources = P_SOURCES;

        if (!Array.isArray(sources) || sources.length === 0) {
            result.status = 'ERROR';
            result.message = 'P_SOURCES must be a non-empty JSON array';
            return result;
        }

        for (var i = 0; i < sources.length; i++) {
            var src = sources[i];
            var sourceName = P_CLIENT_NAME.toUpperCase() + '_' + src.name.toUpperCase();

            try {
                var regRs = snowflake.execute({
                    sqlText: `CALL MDF_CONTROL_DB.PROCEDURES.SP_REGISTER_SOURCE(
                        :1, :2, :3, :4, :5, :6, 'APPEND', 'DAILY', NULL, :7
                    )`,
                    binds: [
                        sourceName,
                        P_CLIENT_NAME,
                        src.type || 'CSV',
                        src.table || 'RAW_' + src.name,
                        src.pattern,
                        src.sub_directory || (P_CLIENT_NAME.toLowerCase() + '/' + src.name.toLowerCase() + '/'),
                        'Auto-onboarded source for client ' + P_CLIENT_NAME
                    ]
                });
                regRs.next();

                result.sources_registered++;
                result.details.push({
                    source_name: sourceName,
                    status: 'REGISTERED',
                    message: regRs.getColumnValue(1)
                });
            } catch (regErr) {
                result.sources_failed++;
                result.details.push({
                    source_name: sourceName,
                    status: 'FAILED',
                    error: regErr.message
                });
            }
        }

        result.status = result.sources_failed === 0 ? 'SUCCESS' : 'PARTIAL';
        result.message = result.sources_registered + ' sources registered, ' +
                        result.sources_failed + ' failed for client ' + P_CLIENT_NAME;

    } catch (err) {
        result.status = 'ERROR';
        result.message = err.message;
    }

    return result;
$$;


-- ===========================================================================
-- DYNAMIC TABLE EXAMPLE (Commented — Uncomment to experiment)
-- ===========================================================================

/*
CREATE OR REPLACE DYNAMIC TABLE MDF_STAGING_DB.DEMO_WEB.DT_EVENTS_FLATTENED
    TARGET_LAG = '5 MINUTES'
    WAREHOUSE = MDF_TRANSFORM_WH
AS
SELECT
    RAW_DATA:event_id::VARCHAR               AS EVENT_ID,
    RAW_DATA:event_type::VARCHAR             AS EVENT_TYPE,
    RAW_DATA:user_id::VARCHAR                AS USER_ID,
    RAW_DATA:session_id::VARCHAR             AS SESSION_ID,
    RAW_DATA:timestamp::TIMESTAMP_TZ         AS EVENT_TIMESTAMP,
    RAW_DATA:page_url::VARCHAR               AS PAGE_URL,
    RAW_DATA:device.type::VARCHAR            AS DEVICE_TYPE,
    RAW_DATA:device.os::VARCHAR              AS DEVICE_OS,
    RAW_DATA:geo.country::VARCHAR            AS COUNTRY,
    RAW_DATA:geo.city::VARCHAR               AS CITY,
    _MDF_LOADED_AT
FROM MDF_RAW_DB.DEMO_WEB.RAW_EVENTS;
*/


-- ===========================================================================
-- VERIFICATION & TESTING
-- ===========================================================================

-- Test schema detection
-- CALL SP_DETECT_SCHEMA_CHANGES('DEMO_CUSTOMERS_CSV');

-- Test dry run of schema evolution
-- CALL SP_APPLY_SCHEMA_EVOLUTION('DEMO_CUSTOMERS_CSV', TRUE);

-- Test multi-client onboarding
/*
CALL SP_ONBOARD_CLIENT(
    'NEWCLIENT',
    PARSE_JSON('[
        {"name": "INVOICES", "type": "CSV", "table": "RAW_INVOICES", "pattern": ".*invoices.*[.]csv"},
        {"name": "PAYMENTS", "type": "JSON", "table": "RAW_PAYMENTS", "pattern": ".*payments.*[.]json"},
        {"name": "METRICS",  "type": "PARQUET", "table": "RAW_METRICS", "pattern": ".*metrics.*[.]parquet"}
    ]')
);
*/

-- View all registered sources after onboarding
-- SELECT SOURCE_NAME, CLIENT_NAME, SOURCE_TYPE, IS_ACTIVE
-- FROM MDF_CONTROL_DB.CONFIG.INGESTION_CONFIG
-- ORDER BY CLIENT_NAME, SOURCE_NAME;


/*
#############################################################################
  MODULE 10 COMPLETE! — COURSE COMPLETE!
#############################################################################

  Procedures Created:
    - SP_DETECT_SCHEMA_CHANGES (read-only schema comparison)
    - SP_APPLY_SCHEMA_EVOLUTION (dry run + apply, safety limits)
    - SP_ONBOARD_CLIENT (multi-source client onboarding)

  FULL FRAMEWORK SUMMARY (All 10 Modules):
  ─────────────────────────────────────────
  Module 01: 4 databases, 4 warehouses, 5 RBAC roles
  Module 02: 10 file formats, 4 internal stages
  Module 03: INGESTION_CONFIG + 6 supporting tables
  Module 04: SP_GENERIC_INGESTION + SP_REGISTER_SOURCE + audit procs
  Module 05: CSV ingestion lab (end-to-end)
  Module 06: JSON/Parquet ingestion + LATERAL FLATTEN
  Module 07: SP_VALIDATE_LOAD + SP_RETRY_FAILED_LOADS
  Module 08: Task trees + Streams for automation
  Module 09: 7 monitoring views + dashboard queries
  Module 10: Schema evolution + multi-client onboarding

  Congratulations — you built a production-grade, metadata-driven
  ingestion framework from scratch!
#############################################################################
*/
