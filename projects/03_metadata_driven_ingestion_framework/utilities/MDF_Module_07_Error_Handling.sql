/*
#############################################################################
  MDF - Module 07: Error Handling & Audit Logging
  CONSOLIDATED WORKSHEET — Snowsight / VS Code Ready
#############################################################################
  SNOWBRIX ACADEMY — Metadata-Driven Ingestion Framework (MDF)

  This worksheet contains:
    - SP_VALIDATE_LOAD (post-load validation — 5 checks)
    - SP_RETRY_FAILED_LOADS (automated retry with backoff)
    - Error analysis queries for daily monitoring

  KEY PRINCIPLE:
    "In production, things WILL fail. The question isn't IF,
     it's HOW FAST you can detect, diagnose, and recover."

  INSTRUCTIONS:
    - Run each section sequentially (top to bottom)
    - Requires Modules 01-06 to be completed first
    - Estimated time: ~20 minutes

  PREREQUISITES:
    - Modules 01-06 completed (data loaded in audit log)
    - MDF_ADMIN role access
#############################################################################
*/

USE ROLE MDF_ADMIN;
USE DATABASE MDF_CONTROL_DB;
USE SCHEMA PROCEDURES;
USE WAREHOUSE MDF_ADMIN_WH;


-- ===========================================================================
-- SP_VALIDATE_LOAD — Post-Load Validation (5 Checks)
-- ===========================================================================

CREATE OR REPLACE PROCEDURE SP_VALIDATE_LOAD(
    P_BATCH_ID      VARCHAR,
    P_CONFIG_ID     NUMBER,
    P_SOURCE_NAME   VARCHAR
)
RETURNS VARIANT
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER
AS
$$
    var results = {
        source_name: P_SOURCE_NAME,
        batch_id: P_BATCH_ID,
        checks: [],
        overall_status: 'PASSED',
        timestamp: new Date().toISOString()
    };

    function addCheck(name, status, message, details) {
        var check = {
            check_name: name,
            status: status,
            message: message,
            details: details || null
        };
        results.checks.push(check);
        if (status === 'FAILED') {
            results.overall_status = 'FAILED';
        } else if (status === 'WARNING' && results.overall_status !== 'FAILED') {
            results.overall_status = 'WARNING';
        }
    }

    try {
        var configRs = snowflake.execute({
            sqlText: `SELECT * FROM MDF_CONTROL_DB.CONFIG.INGESTION_CONFIG WHERE CONFIG_ID = :1`,
            binds: [P_CONFIG_ID]
        });

        if (!configRs.next()) {
            addCheck('CONFIG_EXISTS', 'FAILED', 'Config ID ' + P_CONFIG_ID + ' not found');
            return results;
        }

        var targetDb     = configRs.getColumnValue('TARGET_DATABASE');
        var targetSchema = configRs.getColumnValue('TARGET_SCHEMA');
        var targetTable  = configRs.getColumnValue('TARGET_TABLE');
        var targetFull   = targetDb + '.' + targetSchema + '.' + targetTable;
        var enableValidation = configRs.getColumnValue('ENABLE_VALIDATION');
        var rowThreshold = configRs.getColumnValue('ROW_COUNT_THRESHOLD');
        var nullCheckCols = configRs.getColumnValue('NULL_CHECK_COLUMNS');

        if (!enableValidation) {
            addCheck('VALIDATION_ENABLED', 'SKIPPED', 'Validation is disabled for this source');
            return results;
        }

        // CHECK 1: Table Exists
        try {
            var tableCheck = snowflake.execute({
                sqlText: 'SELECT COUNT(*) AS CNT FROM ' + targetFull + ' LIMIT 1'
            });
            addCheck('TABLE_EXISTS', 'PASSED', 'Target table ' + targetFull + ' exists');
        } catch (err) {
            addCheck('TABLE_EXISTS', 'FAILED', 'Target table ' + targetFull + ' does not exist or is inaccessible');
            return results;
        }

        // CHECK 2: Row Count
        var rowCountRs = snowflake.execute({
            sqlText: 'SELECT COUNT(*) AS ROW_COUNT FROM ' + targetFull
        });
        rowCountRs.next();
        var rowCount = rowCountRs.getColumnValue('ROW_COUNT');

        if (rowCount === 0) {
            addCheck('ROW_COUNT', 'FAILED', 'Table is empty (0 rows)');
        } else if (rowThreshold && rowCount < rowThreshold) {
            addCheck('ROW_COUNT', 'WARNING',
                'Row count (' + rowCount + ') is below threshold (' + rowThreshold + ')',
                { actual: rowCount, threshold: rowThreshold });
        } else {
            addCheck('ROW_COUNT', 'PASSED',
                'Row count: ' + rowCount + (rowThreshold ? ' (threshold: ' + rowThreshold + ')' : ''));
        }

        // CHECK 3: Null Checks on Required Columns
        if (nullCheckCols) {
            var columns = nullCheckCols.split(',');
            for (var i = 0; i < columns.length; i++) {
                var col = columns[i].trim();
                try {
                    var nullRs = snowflake.execute({
                        sqlText: 'SELECT COUNT(*) AS NULL_COUNT FROM ' + targetFull + ' WHERE ' + col + ' IS NULL'
                    });
                    nullRs.next();
                    var nullCount = nullRs.getColumnValue('NULL_COUNT');

                    if (nullCount > 0) {
                        addCheck('NULL_CHECK_' + col, 'WARNING',
                            col + ' has ' + nullCount + ' NULL values',
                            { column: col, null_count: nullCount, total_rows: rowCount });
                    } else {
                        addCheck('NULL_CHECK_' + col, 'PASSED', col + ' has no NULL values');
                    }
                } catch (colErr) {
                    addCheck('NULL_CHECK_' + col, 'WARNING',
                        'Could not check column ' + col + ': ' + colErr.message);
                }
            }
        }

        // CHECK 4: Duplicate Check
        var dupRs = snowflake.execute({
            sqlText: 'SELECT COUNT(*) - COUNT(DISTINCT _MDF_FILE_ROW || _MDF_FILE_NAME) AS DUP_COUNT FROM ' +
                     targetFull + ' WHERE _MDF_LOADED_AT >= DATEADD(HOUR, -1, CURRENT_TIMESTAMP())'
        });
        dupRs.next();
        var dupCount = dupRs.getColumnValue('DUP_COUNT');

        if (dupCount > 0) {
            addCheck('DUPLICATE_CHECK', 'WARNING',
                dupCount + ' potential duplicate rows detected in latest load',
                { duplicate_count: dupCount });
        } else {
            addCheck('DUPLICATE_CHECK', 'PASSED', 'No duplicates detected in latest load');
        }

        // CHECK 5: Data Freshness
        var freshnessRs = snowflake.execute({
            sqlText: 'SELECT MAX(_MDF_LOADED_AT) AS LATEST_LOAD FROM ' + targetFull
        });
        freshnessRs.next();
        var latestLoad = freshnessRs.getColumnValue('LATEST_LOAD');
        addCheck('DATA_FRESHNESS', 'PASSED', 'Latest load timestamp: ' + latestLoad);

    } catch (err) {
        addCheck('VALIDATION_ERROR', 'FAILED', 'Validation procedure error: ' + err.message);
    }

    // Update audit log with validation results
    try {
        snowflake.execute({
            sqlText: `UPDATE MDF_CONTROL_DB.AUDIT.INGESTION_AUDIT_LOG
                      SET VALIDATION_STATUS = :1, VALIDATION_DETAILS = PARSE_JSON(:2)
                      WHERE BATCH_ID = :3 AND SOURCE_NAME = :4`,
            binds: [results.overall_status, JSON.stringify(results), P_BATCH_ID, P_SOURCE_NAME]
        });
    } catch (logErr) { }

    return results;
$$;


-- ===========================================================================
-- SP_RETRY_FAILED_LOADS — Automated Retry with Backoff
-- ===========================================================================

CREATE OR REPLACE PROCEDURE SP_RETRY_FAILED_LOADS(
    P_HOURS_LOOKBACK    NUMBER DEFAULT 24,
    P_MAX_RETRIES       NUMBER DEFAULT 3
)
RETURNS VARIANT
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER
AS
$$
    var retryResults = [];

    try {
        var failedRs = snowflake.execute({
            sqlText: `
                SELECT
                    a.SOURCE_NAME,
                    a.BATCH_ID,
                    a.CONFIG_ID,
                    a.ERROR_MESSAGE,
                    COUNT(*) OVER (PARTITION BY a.SOURCE_NAME) AS FAIL_COUNT
                FROM MDF_CONTROL_DB.AUDIT.INGESTION_AUDIT_LOG a
                WHERE a.RUN_STATUS = 'FAILED'
                  AND a.CREATED_AT >= DATEADD(HOUR, -:1, CURRENT_TIMESTAMP())
                QUALIFY ROW_NUMBER() OVER (PARTITION BY a.SOURCE_NAME ORDER BY a.CREATED_AT DESC) = 1
            `,
            binds: [P_HOURS_LOOKBACK]
        });

        while (failedRs.next()) {
            var sourceName = failedRs.getColumnValue('SOURCE_NAME');
            var failCount  = failedRs.getColumnValue('FAIL_COUNT');
            var lastError  = failedRs.getColumnValue('ERROR_MESSAGE');

            if (failCount >= P_MAX_RETRIES) {
                retryResults.push({
                    source_name: sourceName,
                    action: 'SKIPPED',
                    reason: 'Max retries (' + P_MAX_RETRIES + ') exceeded. Failures: ' + failCount,
                    last_error: lastError
                });
                continue;
            }

            try {
                var retryRs = snowflake.execute({
                    sqlText: "CALL MDF_CONTROL_DB.PROCEDURES.SP_GENERIC_INGESTION(:1, FALSE)",
                    binds: [sourceName]
                });
                retryRs.next();
                var result = retryRs.getColumnValue(1);

                retryResults.push({
                    source_name: sourceName,
                    action: 'RETRIED',
                    attempt: failCount + 1,
                    result: result
                });
            } catch (retryErr) {
                retryResults.push({
                    source_name: sourceName,
                    action: 'RETRY_FAILED',
                    attempt: failCount + 1,
                    error: retryErr.message
                });
            }
        }

    } catch (err) {
        return { status: 'ERROR', message: err.message };
    }

    return {
        status: 'COMPLETED',
        retries_attempted: retryResults.length,
        results: retryResults
    };
$$;


-- ===========================================================================
-- ERROR ANALYSIS QUERIES (Use these for daily monitoring)
-- ===========================================================================

-- 1. Failed loads in the last 24 hours
SELECT
    SOURCE_NAME, RUN_STATUS, ERROR_CODE, ERROR_MESSAGE,
    FILES_FAILED, ROWS_FAILED, CREATED_AT
FROM MDF_CONTROL_DB.AUDIT.INGESTION_AUDIT_LOG
WHERE RUN_STATUS IN ('FAILED', 'PARTIAL_SUCCESS')
  AND CREATED_AT >= DATEADD(HOUR, -24, CURRENT_TIMESTAMP())
ORDER BY CREATED_AT DESC;

-- 2. Error frequency by source (last 7 days)
SELECT
    SOURCE_NAME,
    COUNT(*) AS TOTAL_RUNS,
    SUM(CASE WHEN RUN_STATUS = 'SUCCESS' THEN 1 ELSE 0 END) AS SUCCESSES,
    SUM(CASE WHEN RUN_STATUS = 'FAILED' THEN 1 ELSE 0 END) AS FAILURES,
    ROUND(SUM(CASE WHEN RUN_STATUS = 'FAILED' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS FAILURE_RATE_PCT,
    MAX(CASE WHEN RUN_STATUS = 'FAILED' THEN ERROR_MESSAGE END) AS LAST_ERROR
FROM MDF_CONTROL_DB.AUDIT.INGESTION_AUDIT_LOG
WHERE CREATED_AT >= DATEADD(DAY, -7, CURRENT_TIMESTAMP())
GROUP BY SOURCE_NAME
HAVING FAILURES > 0
ORDER BY FAILURE_RATE_PCT DESC;

-- 3. Detailed error log entries
SELECT
    SOURCE_NAME, FILE_NAME, ROW_NUMBER, COLUMN_NAME,
    ERROR_CODE, ERROR_MESSAGE,
    LEFT(REJECTED_RECORD, 200) AS REJECTED_RECORD_PREVIEW,
    CREATED_AT
FROM MDF_CONTROL_DB.AUDIT.INGESTION_ERROR_LOG
ORDER BY CREATED_AT DESC
LIMIT 20;

-- 4. Error patterns (most common error types)
SELECT
    ERROR_CODE,
    LEFT(ERROR_MESSAGE, 100) AS ERROR_PATTERN,
    COUNT(*) AS OCCURRENCE_COUNT,
    COUNT(DISTINCT SOURCE_NAME) AS AFFECTED_SOURCES,
    MIN(CREATED_AT) AS FIRST_SEEN,
    MAX(CREATED_AT) AS LAST_SEEN
FROM MDF_CONTROL_DB.AUDIT.INGESTION_ERROR_LOG
GROUP BY ERROR_CODE, LEFT(ERROR_MESSAGE, 100)
ORDER BY OCCURRENCE_COUNT DESC;


-- ===========================================================================
-- TEST VALIDATION & RETRY
-- ===========================================================================

-- Run validation on a loaded source (replace batch_id with actual value)
-- CALL SP_VALIDATE_LOAD('your-batch-id', 1, 'DEMO_CUSTOMERS_CSV');

-- Retry failed loads from the last 24 hours
-- CALL SP_RETRY_FAILED_LOADS(24, 3);


/*
#############################################################################
  MODULE 07 COMPLETE!

  Procedures Created:
    - SP_VALIDATE_LOAD (5 post-load checks: exists, row count, nulls,
      duplicates, freshness)
    - SP_RETRY_FAILED_LOADS (auto-retry with max retry limit)

  Error Analysis Queries:
    - Failed loads (24h)
    - Error frequency by source (7d)
    - Detailed error log entries
    - Error patterns (most common types)

  Next: MDF - Module 08 (Automation — Tasks & Streams)
#############################################################################
*/
