/*
=============================================================================
  MODULE 04 : CORE STORED PROCEDURES
  SCRIPT 03 : SP_REGISTER_SOURCE — Easy Source Onboarding
=============================================================================
  SNOWBRIX ACADEMY — Metadata-Driven Ingestion Framework (MDF)

  LEARNING OBJECTIVES:
    1. Create a simplified interface for onboarding new data sources
    2. Apply sensible defaults to reduce configuration burden
    3. Validate inputs before inserting config
    4. Understand the "convention over configuration" principle

  PROBLEM THIS SOLVES:
    The INGESTION_CONFIG table has 30+ columns. Expecting users to
    manually INSERT with all those fields is error-prone. This procedure
    wraps the INSERT with:
      - Input validation
      - Sensible defaults
      - Auto-mapping of file formats and stages
      - Friendly error messages
=============================================================================
*/

USE ROLE MDF_ADMIN;
USE DATABASE MDF_CONTROL_DB;
USE SCHEMA PROCEDURES;
USE WAREHOUSE MDF_ADMIN_WH;

-- =========================================================================
-- PROCEDURE: SP_REGISTER_SOURCE
-- Simplified interface to register a new data source.
-- Only requires the essential fields — everything else gets defaults.
-- =========================================================================
CREATE OR REPLACE PROCEDURE SP_REGISTER_SOURCE(
    P_SOURCE_NAME       VARCHAR,        -- Unique name: 'CLIENT_A_SALES_CSV'
    P_CLIENT_NAME       VARCHAR,        -- Client: 'CLIENT_A'
    P_SOURCE_TYPE       VARCHAR,        -- 'CSV', 'JSON', 'PARQUET', 'AVRO', 'ORC'
    P_TARGET_TABLE      VARCHAR,        -- Table name: 'RAW_SALES'
    P_FILE_PATTERN      VARCHAR,        -- File pattern: '.*sales.*[.]csv'
    P_SUB_DIRECTORY     VARCHAR DEFAULT NULL,     -- Sub-folder: 'client_a/sales/'
    P_LOAD_TYPE         VARCHAR DEFAULT 'APPEND', -- 'APPEND', 'TRUNCATE_RELOAD'
    P_LOAD_FREQUENCY    VARCHAR DEFAULT 'DAILY',  -- 'HOURLY', 'DAILY', 'WEEKLY'
    P_SOURCE_SYSTEM     VARCHAR DEFAULT NULL,      -- 'SAP', 'SALESFORCE', etc.
    P_DESCRIPTION       VARCHAR DEFAULT NULL
)
RETURNS VARCHAR
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER
AS
$$
    // =====================================================================
    // INPUT VALIDATION
    // =====================================================================
    var errors = [];

    // Required fields
    if (!P_SOURCE_NAME || P_SOURCE_NAME.trim() === '') {
        errors.push('SOURCE_NAME is required');
    }
    if (!P_CLIENT_NAME || P_CLIENT_NAME.trim() === '') {
        errors.push('CLIENT_NAME is required');
    }

    // Validate source type
    var validTypes = ['CSV', 'JSON', 'PARQUET', 'AVRO', 'ORC'];
    P_SOURCE_TYPE = (P_SOURCE_TYPE || '').toUpperCase().trim();
    if (validTypes.indexOf(P_SOURCE_TYPE) === -1) {
        errors.push('SOURCE_TYPE must be one of: ' + validTypes.join(', '));
    }

    // Validate load type
    var validLoadTypes = ['APPEND', 'TRUNCATE_RELOAD', 'MERGE'];
    P_LOAD_TYPE = (P_LOAD_TYPE || 'APPEND').toUpperCase().trim();
    if (validLoadTypes.indexOf(P_LOAD_TYPE) === -1) {
        errors.push('LOAD_TYPE must be one of: ' + validLoadTypes.join(', '));
    }

    // Validate frequency
    var validFreqs = ['HOURLY', 'DAILY', 'WEEKLY', 'MONTHLY', 'ON_DEMAND'];
    P_LOAD_FREQUENCY = (P_LOAD_FREQUENCY || 'DAILY').toUpperCase().trim();
    if (validFreqs.indexOf(P_LOAD_FREQUENCY) === -1) {
        errors.push('LOAD_FREQUENCY must be one of: ' + validFreqs.join(', '));
    }

    // Check for duplicate source name
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

    // =====================================================================
    // APPLY DEFAULTS (Convention Over Configuration)
    // =====================================================================

    // Map source type to default file format
    var fileFormatMap = {
        'CSV':     'MDF_CONTROL_DB.CONFIG.MDF_FF_CSV_STANDARD',
        'JSON':    'MDF_CONTROL_DB.CONFIG.MDF_FF_JSON_STANDARD',
        'PARQUET': 'MDF_CONTROL_DB.CONFIG.MDF_FF_PARQUET_STANDARD',
        'AVRO':    'MDF_CONTROL_DB.CONFIG.MDF_FF_AVRO_STANDARD',
        'ORC':     'MDF_CONTROL_DB.CONFIG.MDF_FF_ORC_STANDARD'
    };
    var fileFormatName = fileFormatMap[P_SOURCE_TYPE];

    // Map source type to default stage
    var stageMap = {
        'CSV':     '@MDF_CONTROL_DB.CONFIG.MDF_STG_INTERNAL_CSV',
        'JSON':    '@MDF_CONTROL_DB.CONFIG.MDF_STG_INTERNAL_JSON',
        'PARQUET': '@MDF_CONTROL_DB.CONFIG.MDF_STG_INTERNAL_PARQUET',
        'AVRO':    '@MDF_CONTROL_DB.CONFIG.MDF_STG_INTERNAL_PARQUET',
        'ORC':     '@MDF_CONTROL_DB.CONFIG.MDF_STG_INTERNAL_PARQUET'
    };
    var stageName = stageMap[P_SOURCE_TYPE];

    // Derive target schema from client name + source system
    var targetSchema = P_CLIENT_NAME.toUpperCase().trim();
    if (P_SOURCE_SYSTEM) {
        targetSchema = targetSchema + '_' + P_SOURCE_SYSTEM.toUpperCase().trim();
    }

    // Default description
    var description = P_DESCRIPTION || ('Auto-registered source: ' + P_SOURCE_NAME);

    // Match by column name for semi-structured types
    var matchByColumnName = 'NONE';
    if (P_SOURCE_TYPE === 'PARQUET' || P_SOURCE_TYPE === 'AVRO' || P_SOURCE_TYPE === 'ORC') {
        matchByColumnName = 'CASE_INSENSITIVE';
    }

    // =====================================================================
    // INSERT INTO CONFIG TABLE
    // =====================================================================
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
                P_SOURCE_NAME.trim(),
                description,
                P_CLIENT_NAME.trim().toUpperCase(),
                P_SOURCE_SYSTEM ? P_SOURCE_SYSTEM.trim().toUpperCase() : null,
                P_SOURCE_TYPE,
                stageName,
                P_FILE_PATTERN,
                P_SUB_DIRECTORY,
                fileFormatName,
                targetSchema,
                P_TARGET_TABLE.trim().toUpperCase(),
                P_LOAD_TYPE,
                P_LOAD_FREQUENCY,
                matchByColumnName
            ]
        });

        // Build confirmation message
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


-- =========================================================================
-- PROCEDURE: SP_DEACTIVATE_SOURCE
-- Safely deactivate a source (soft delete — never hard delete config).
-- =========================================================================
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


-- =========================================================================
-- VERIFICATION
-- =========================================================================

-- Test registration with all defaults
CALL SP_REGISTER_SOURCE(
    'TEST_REGISTRATION_CSV',       -- source name
    'TEST_CLIENT',                  -- client name
    'CSV',                          -- source type
    'RAW_TEST_DATA',               -- target table
    '.*test.*[.]csv',              -- file pattern
    'test/data/',                   -- sub-directory
    'APPEND',                       -- load type
    'DAILY',                        -- frequency
    'TEST_SYSTEM',                  -- source system
    'Test registration from Module 04 lab'  -- description
);

-- View the registered source
SELECT SOURCE_NAME, CLIENT_NAME, SOURCE_TYPE, TARGET_SCHEMA, TARGET_TABLE, IS_ACTIVE
FROM MDF_CONTROL_DB.CONFIG.INGESTION_CONFIG
WHERE SOURCE_NAME = 'TEST_REGISTRATION_CSV';

-- Deactivate the test source
CALL SP_DEACTIVATE_SOURCE('TEST_REGISTRATION_CSV');

-- Clean up test
DELETE FROM MDF_CONTROL_DB.CONFIG.INGESTION_CONFIG WHERE SOURCE_NAME = 'TEST_REGISTRATION_CSV';


/*
=============================================================================
  BEST PRACTICES & TIPS:

  1. CONVENTION OVER CONFIGURATION: The procedure auto-maps file formats
     and stages based on source type. You only override when needed.

  2. INPUT VALIDATION FIRST: Always validate all inputs before making
     any changes. This prevents partial inserts and hard-to-debug state.

  3. SOFT DELETES: SP_DEACTIVATE_SOURCE sets IS_ACTIVE = FALSE instead
     of deleting the row. The config history is preserved for auditing.

  4. NEXT STEPS IN OUTPUT: The procedure returns clear next steps.
     This is a UX decision — the user knows exactly what to do next.

  MODULE 04 COMPLETE!
  → Next: Module 05 — Structured Data Ingestion (CSV) Lab
=============================================================================
*/
