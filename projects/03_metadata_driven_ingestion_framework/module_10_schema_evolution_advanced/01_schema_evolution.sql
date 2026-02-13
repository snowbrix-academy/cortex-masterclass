/*
=============================================================================
  MODULE 10 : SCHEMA EVOLUTION & ADVANCED TOPICS
  SCRIPT 01 : Schema Evolution Handler & Multi-Client Patterns
=============================================================================
  SNOWBRIX ACADEMY — Metadata-Driven Ingestion Framework (MDF)

  LEARNING OBJECTIVES:
    1. Handle schema drift automatically (new columns in source files)
    2. Implement INFER_SCHEMA for automatic table creation
    3. Design multi-client isolation patterns
    4. Build a complete end-to-end onboarding workflow
    5. Advanced patterns: Dynamic Tables, data sharing

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
=============================================================================
*/

USE ROLE MDF_ADMIN;
USE DATABASE MDF_CONTROL_DB;
USE SCHEMA PROCEDURES;
USE WAREHOUSE MDF_ADMIN_WH;


-- =========================================================================
-- PROCEDURE: SP_DETECT_SCHEMA_CHANGES
-- Compares the current file schema against the target table schema.
-- Reports differences without making changes (safe to run anytime).
-- =========================================================================
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
        // Get config
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
                // Skip MDF metadata columns
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

        // Compare: Find columns missing from file (still in table)
        for (var tableCol in tableColumns) {
            if (!(tableCol in fileColumns)) {
                result.missing_columns.push({
                    column: tableCol,
                    table_type: tableColumns[tableCol]
                });
                // Missing columns are informational, not necessarily a problem
            }
        }

    } catch (err) {
        result.status = 'ERROR';
        result.message = err.message;
    }

    return result;
$$;


-- =========================================================================
-- PROCEDURE: SP_APPLY_SCHEMA_EVOLUTION
-- Applies detected schema changes to the target table.
-- Only adds columns — never drops or modifies existing ones.
-- =========================================================================
CREATE OR REPLACE PROCEDURE SP_APPLY_SCHEMA_EVOLUTION(
    P_SOURCE_NAME   VARCHAR,
    P_DRY_RUN       BOOLEAN DEFAULT TRUE    -- TRUE = show changes only, FALSE = apply
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
        // First, detect changes
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

        // Get target table info
        var configRs = snowflake.execute({
            sqlText: `SELECT * FROM MDF_CONTROL_DB.CONFIG.INGESTION_CONFIG WHERE SOURCE_NAME = :1`,
            binds: [P_SOURCE_NAME]
        });
        configRs.next();
        var targetFull = configRs.getColumnValue('TARGET_DATABASE') + '.' +
                         configRs.getColumnValue('TARGET_SCHEMA') + '.' +
                         configRs.getColumnValue('TARGET_TABLE');
        var configId = configRs.getColumnValue('CONFIG_ID');
        var maxNewCols = 10; // Safety limit

        // Check schema evolution config
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


-- =========================================================================
-- ADVANCED: MULTI-CLIENT ONBOARDING PROCEDURE
-- One-click onboarding for a new client with multiple data sources.
-- =========================================================================
CREATE OR REPLACE PROCEDURE SP_ONBOARD_CLIENT(
    P_CLIENT_NAME       VARCHAR,        -- 'ACME_CORP'
    P_SOURCES           VARIANT         -- JSON array of source definitions
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


-- =========================================================================
-- ADVANCED: DYNAMIC TABLE FOR REAL-TIME STAGING
-- Dynamic Tables automatically transform data from RAW to STAGING.
-- =========================================================================

/*
-- Example: Dynamic Table that flattens JSON events in real-time
CREATE OR REPLACE DYNAMIC TABLE MDF_STAGING_DB.DEMO_WEB.DT_EVENTS_FLATTENED
    TARGET_LAG = '5 MINUTES'             -- Refresh within 5 min of source change
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


-- =========================================================================
-- VERIFICATION & TESTING
-- =========================================================================

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
        {"name": "PAYMENTS", "type": "JSON", "table": "RAW_PAYMENTS", "pattern": ".*payments.*[.]json"}
    ]')
);
*/

-- View all registered sources after onboarding
-- SELECT SOURCE_NAME, CLIENT_NAME, SOURCE_TYPE, IS_ACTIVE
-- FROM MDF_CONTROL_DB.CONFIG.INGESTION_CONFIG
-- ORDER BY CLIENT_NAME, SOURCE_NAME;


/*
=============================================================================
  BEST PRACTICES & TIPS:

  1. SCHEMA EVOLUTION SAFETY:
     - Always run SP_DETECT_SCHEMA_CHANGES first (read-only)
     - Use DRY_RUN=TRUE with SP_APPLY_SCHEMA_EVOLUTION
     - Set MAX_NEW_COLUMNS to prevent runaway schema changes
     - Never auto-drop columns — downstream queries may depend on them

  2. MULTI-CLIENT ISOLATION:
     - Each client gets its own schema in RAW/STAGING/CURATED
     - RBAC grants at schema level = natural data isolation
     - Config table has CLIENT_NAME for filtering

  3. DYNAMIC TABLES:
     - Use for real-time transformation (replaces manual staging ETL)
     - TARGET_LAG controls freshness (1 min to 1 day)
     - No tasks/streams needed — Snowflake manages refresh internally
     - Cost: compute charges for each refresh cycle

  4. ONBOARDING WORKFLOW (Production):
     Step 1: SP_ONBOARD_CLIENT → Register sources
     Step 2: Upload sample files to stages
     Step 3: SP_GENERIC_INGESTION → Test load
     Step 4: SP_VALIDATE_LOAD → Verify data quality
     Step 5: Resume tasks → Enable automation

  CONGRATULATIONS! MODULE 10 COMPLETE!
  You've built a complete, production-ready, metadata-driven
  ingestion framework from scratch.
=============================================================================
*/
