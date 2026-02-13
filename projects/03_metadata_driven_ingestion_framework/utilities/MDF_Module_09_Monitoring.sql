/*
#############################################################################
  MDF - Module 09: Monitoring & Dashboard Views
  CONSOLIDATED WORKSHEET — Snowsight / VS Code Ready
#############################################################################
  SNOWBRIX ACADEMY — Metadata-Driven Ingestion Framework (MDF)

  This worksheet contains:
    - 7 monitoring views for ingestion health
    - Dashboard-ready queries for Snowsight
    - KPIs: success rate, throughput, latency, error severity

  DASHBOARD SECTIONS:
  ┌──────────────────────────────────────────────────────────────┐
  │  1. EXECUTIVE SUMMARY     → Overall health at a glance      │
  │  2. SOURCE HEALTH         → Per-source success/failure       │
  │  3. THROUGHPUT METRICS    → Rows/files loaded over time      │
  │  4. ERROR ANALYSIS        → Error patterns and trends        │
  │  5. PERFORMANCE           → Duration trends, SLA compliance  │
  │  6. OPERATIONAL           → Active configs, task status      │
  │  7. DAILY SUMMARY         → For daily reports                │
  └──────────────────────────────────────────────────────────────┘

  INSTRUCTIONS:
    - Run all CREATE VIEW statements, then use dashboard queries
    - Requires Modules 01-08 to be completed first
    - Estimated time: ~10 minutes

  PREREQUISITES:
    - Modules 01-08 completed
    - MDF_ADMIN role access
#############################################################################
*/

USE ROLE MDF_ADMIN;
USE DATABASE MDF_CONTROL_DB;
USE SCHEMA MONITORING;
USE WAREHOUSE MDF_MONITORING_WH;


-- ===========================================================================
-- VIEW 1: EXECUTIVE SUMMARY — Overall Health
-- ===========================================================================

CREATE OR REPLACE VIEW VW_INGESTION_EXECUTIVE_SUMMARY AS
WITH daily_stats AS (
    SELECT
        DATE_TRUNC('DAY', CREATED_AT) AS RUN_DATE,
        COUNT(*) AS TOTAL_RUNS,
        SUM(CASE WHEN RUN_STATUS = 'SUCCESS' THEN 1 ELSE 0 END) AS SUCCESS_COUNT,
        SUM(CASE WHEN RUN_STATUS = 'PARTIAL_SUCCESS' THEN 1 ELSE 0 END) AS PARTIAL_COUNT,
        SUM(CASE WHEN RUN_STATUS = 'FAILED' THEN 1 ELSE 0 END) AS FAILED_COUNT,
        SUM(CASE WHEN RUN_STATUS = 'SKIPPED' THEN 1 ELSE 0 END) AS SKIPPED_COUNT,
        SUM(COALESCE(ROWS_LOADED, 0)) AS TOTAL_ROWS_LOADED,
        SUM(COALESCE(FILES_PROCESSED, 0)) AS TOTAL_FILES_PROCESSED,
        SUM(COALESCE(BYTES_LOADED, 0)) AS TOTAL_BYTES_LOADED,
        AVG(COALESCE(DURATION_SECONDS, 0)) AS AVG_DURATION_SECONDS
    FROM MDF_CONTROL_DB.AUDIT.INGESTION_AUDIT_LOG
    WHERE CREATED_AT >= DATEADD(DAY, -30, CURRENT_TIMESTAMP())
    GROUP BY DATE_TRUNC('DAY', CREATED_AT)
)
SELECT
    RUN_DATE,
    TOTAL_RUNS,
    SUCCESS_COUNT,
    PARTIAL_COUNT,
    FAILED_COUNT,
    SKIPPED_COUNT,
    ROUND(SUCCESS_COUNT * 100.0 / NULLIF(TOTAL_RUNS, 0), 1) AS SUCCESS_RATE_PCT,
    TOTAL_ROWS_LOADED,
    TOTAL_FILES_PROCESSED,
    ROUND(TOTAL_BYTES_LOADED / 1024.0 / 1024.0, 2) AS TOTAL_MB_LOADED,
    ROUND(AVG_DURATION_SECONDS, 1) AS AVG_DURATION_SECONDS
FROM daily_stats
ORDER BY RUN_DATE DESC;


-- ===========================================================================
-- VIEW 2: SOURCE HEALTH — Per-Source Metrics
-- ===========================================================================

CREATE OR REPLACE VIEW VW_SOURCE_HEALTH AS
SELECT
    ic.SOURCE_NAME,
    ic.CLIENT_NAME,
    ic.SOURCE_TYPE,
    ic.LOAD_FREQUENCY,
    ic.IS_ACTIVE,
    COUNT(a.AUDIT_ID) AS RUNS_LAST_7D,
    SUM(CASE WHEN a.RUN_STATUS = 'SUCCESS' THEN 1 ELSE 0 END) AS SUCCESSES_7D,
    SUM(CASE WHEN a.RUN_STATUS = 'FAILED' THEN 1 ELSE 0 END) AS FAILURES_7D,
    ROUND(
        SUM(CASE WHEN a.RUN_STATUS = 'SUCCESS' THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(a.AUDIT_ID), 0), 1
    ) AS SUCCESS_RATE_7D_PCT,
    MAX(a.CREATED_AT) AS LAST_RUN_AT,
    MAX(CASE WHEN a.CREATED_AT = sub.LATEST_RUN THEN a.RUN_STATUS END) AS LAST_RUN_STATUS,
    SUM(COALESCE(a.ROWS_LOADED, 0)) AS TOTAL_ROWS_7D,
    ROUND(AVG(COALESCE(a.DURATION_SECONDS, 0)), 1) AS AVG_DURATION_7D,
    CASE
        WHEN SUM(CASE WHEN a.RUN_STATUS = 'FAILED' THEN 1 ELSE 0 END) = 0 THEN 'HEALTHY'
        WHEN SUM(CASE WHEN a.RUN_STATUS = 'FAILED' THEN 1 ELSE 0 END) <= 2 THEN 'WARNING'
        ELSE 'CRITICAL'
    END AS HEALTH_STATUS
FROM MDF_CONTROL_DB.CONFIG.INGESTION_CONFIG ic
LEFT JOIN MDF_CONTROL_DB.AUDIT.INGESTION_AUDIT_LOG a
    ON ic.SOURCE_NAME = a.SOURCE_NAME
    AND a.CREATED_AT >= DATEADD(DAY, -7, CURRENT_TIMESTAMP())
LEFT JOIN (
    SELECT SOURCE_NAME, MAX(CREATED_AT) AS LATEST_RUN
    FROM MDF_CONTROL_DB.AUDIT.INGESTION_AUDIT_LOG
    GROUP BY SOURCE_NAME
) sub ON ic.SOURCE_NAME = sub.SOURCE_NAME
GROUP BY ic.SOURCE_NAME, ic.CLIENT_NAME, ic.SOURCE_TYPE, ic.LOAD_FREQUENCY, ic.IS_ACTIVE;


-- ===========================================================================
-- VIEW 3: THROUGHPUT METRICS — Data Volume Over Time
-- ===========================================================================

CREATE OR REPLACE VIEW VW_THROUGHPUT_METRICS AS
SELECT
    DATE_TRUNC('HOUR', CREATED_AT) AS HOUR_BUCKET,
    SOURCE_NAME,
    SUM(COALESCE(ROWS_LOADED, 0)) AS ROWS_LOADED,
    SUM(COALESCE(FILES_PROCESSED, 0)) AS FILES_PROCESSED,
    ROUND(SUM(COALESCE(BYTES_LOADED, 0)) / 1024.0 / 1024.0, 2) AS MB_LOADED,
    COUNT(*) AS RUN_COUNT,
    AVG(COALESCE(DURATION_SECONDS, 0)) AS AVG_DURATION_SECONDS
FROM MDF_CONTROL_DB.AUDIT.INGESTION_AUDIT_LOG
WHERE CREATED_AT >= DATEADD(DAY, -7, CURRENT_TIMESTAMP())
  AND RUN_STATUS IN ('SUCCESS', 'PARTIAL_SUCCESS')
GROUP BY DATE_TRUNC('HOUR', CREATED_AT), SOURCE_NAME;


-- ===========================================================================
-- VIEW 4: ERROR ANALYSIS — Error Patterns
-- ===========================================================================

CREATE OR REPLACE VIEW VW_ERROR_ANALYSIS AS
SELECT
    SOURCE_NAME,
    ERROR_CODE,
    LEFT(ERROR_MESSAGE, 200) AS ERROR_PATTERN,
    COUNT(*) AS OCCURRENCE_COUNT,
    MIN(CREATED_AT) AS FIRST_SEEN,
    MAX(CREATED_AT) AS LAST_SEEN,
    DATEDIFF('HOUR', MIN(CREATED_AT), MAX(CREATED_AT)) AS DURATION_HOURS,
    CASE
        WHEN COUNT(*) >= 10 THEN 'CRITICAL'
        WHEN COUNT(*) >= 5 THEN 'HIGH'
        WHEN COUNT(*) >= 2 THEN 'MEDIUM'
        ELSE 'LOW'
    END AS SEVERITY
FROM MDF_CONTROL_DB.AUDIT.INGESTION_AUDIT_LOG
WHERE RUN_STATUS IN ('FAILED', 'PARTIAL_SUCCESS')
  AND CREATED_AT >= DATEADD(DAY, -30, CURRENT_TIMESTAMP())
GROUP BY SOURCE_NAME, ERROR_CODE, LEFT(ERROR_MESSAGE, 200);


-- ===========================================================================
-- VIEW 5: PERFORMANCE METRICS — Duration Trends
-- ===========================================================================

CREATE OR REPLACE VIEW VW_PERFORMANCE_METRICS AS
SELECT
    SOURCE_NAME,
    DATE_TRUNC('DAY', CREATED_AT) AS RUN_DATE,
    COUNT(*) AS RUN_COUNT,
    MIN(DURATION_SECONDS) AS MIN_DURATION_SEC,
    AVG(DURATION_SECONDS) AS AVG_DURATION_SEC,
    MAX(DURATION_SECONDS) AS MAX_DURATION_SEC,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY DURATION_SECONDS) AS P95_DURATION_SEC,
    SUM(ROWS_LOADED) AS TOTAL_ROWS,
    ROUND(SUM(ROWS_LOADED) / NULLIF(SUM(DURATION_SECONDS), 0), 0) AS ROWS_PER_SECOND
FROM MDF_CONTROL_DB.AUDIT.INGESTION_AUDIT_LOG
WHERE CREATED_AT >= DATEADD(DAY, -30, CURRENT_TIMESTAMP())
  AND DURATION_SECONDS IS NOT NULL
  AND RUN_STATUS IN ('SUCCESS', 'PARTIAL_SUCCESS')
GROUP BY SOURCE_NAME, DATE_TRUNC('DAY', CREATED_AT);


-- ===========================================================================
-- VIEW 6: OPERATIONAL OVERVIEW — Config & Task Status
-- ===========================================================================

CREATE OR REPLACE VIEW VW_OPERATIONAL_OVERVIEW AS
SELECT
    ic.CLIENT_NAME,
    COUNT(*) AS TOTAL_SOURCES,
    SUM(CASE WHEN ic.IS_ACTIVE THEN 1 ELSE 0 END) AS ACTIVE_SOURCES,
    SUM(CASE WHEN NOT ic.IS_ACTIVE THEN 1 ELSE 0 END) AS INACTIVE_SOURCES,
    LISTAGG(DISTINCT ic.SOURCE_TYPE, ', ') WITHIN GROUP (ORDER BY ic.SOURCE_TYPE) AS DATA_TYPES,
    LISTAGG(DISTINCT ic.LOAD_FREQUENCY, ', ') WITHIN GROUP (ORDER BY ic.LOAD_FREQUENCY) AS FREQUENCIES,
    SUM(CASE WHEN ic.ENABLE_VALIDATION THEN 1 ELSE 0 END) AS VALIDATION_ENABLED,
    SUM(CASE WHEN ic.ENABLE_SCHEMA_EVOLUTION THEN 1 ELSE 0 END) AS SCHEMA_EVOLUTION_ENABLED
FROM MDF_CONTROL_DB.CONFIG.INGESTION_CONFIG ic
GROUP BY ic.CLIENT_NAME;


-- ===========================================================================
-- VIEW 7: DAILY INGESTION SUMMARY — For Daily Reports
-- ===========================================================================

CREATE OR REPLACE VIEW VW_DAILY_SUMMARY AS
SELECT
    CURRENT_DATE() AS REPORT_DATE,
    COUNT(DISTINCT SOURCE_NAME) AS SOURCES_PROCESSED,
    SUM(CASE WHEN RUN_STATUS = 'SUCCESS' THEN 1 ELSE 0 END) AS SUCCESSFUL_RUNS,
    SUM(CASE WHEN RUN_STATUS = 'FAILED' THEN 1 ELSE 0 END) AS FAILED_RUNS,
    SUM(COALESCE(ROWS_LOADED, 0)) AS TOTAL_ROWS_TODAY,
    SUM(COALESCE(FILES_PROCESSED, 0)) AS TOTAL_FILES_TODAY,
    ROUND(SUM(COALESCE(BYTES_LOADED, 0)) / 1024.0 / 1024.0 / 1024.0, 3) AS TOTAL_GB_TODAY,
    MIN(START_TIME) AS EARLIEST_RUN,
    MAX(END_TIME) AS LATEST_RUN,
    ROUND(AVG(DURATION_SECONDS), 1) AS AVG_DURATION_SECONDS
FROM MDF_CONTROL_DB.AUDIT.INGESTION_AUDIT_LOG
WHERE DATE_TRUNC('DAY', CREATED_AT) = CURRENT_DATE();


-- ===========================================================================
-- DASHBOARD QUERIES (Ready for Snowsight Dashboards)
-- ===========================================================================

-- Query 1: Today's ingestion health (KPI tiles)
SELECT * FROM VW_DAILY_SUMMARY;

-- Query 2: Source health heat map
SELECT
    SOURCE_NAME, HEALTH_STATUS, SUCCESS_RATE_7D_PCT,
    RUNS_LAST_7D, FAILURES_7D, LAST_RUN_STATUS, LAST_RUN_AT
FROM VW_SOURCE_HEALTH
ORDER BY
    CASE HEALTH_STATUS WHEN 'CRITICAL' THEN 1 WHEN 'WARNING' THEN 2 ELSE 3 END,
    SOURCE_NAME;

-- Query 3: Ingestion trend (line chart — last 7 days)
SELECT * FROM VW_INGESTION_EXECUTIVE_SUMMARY
WHERE RUN_DATE >= DATEADD(DAY, -7, CURRENT_DATE())
ORDER BY RUN_DATE;

-- Query 4: Top errors requiring attention
SELECT * FROM VW_ERROR_ANALYSIS
WHERE SEVERITY IN ('CRITICAL', 'HIGH')
ORDER BY OCCURRENCE_COUNT DESC
LIMIT 10;

-- Query 5: Performance outliers (bar chart)
SELECT
    SOURCE_NAME,
    ROUND(AVG(AVG_DURATION_SEC), 1) AS AVG_DURATION,
    ROUND(MAX(MAX_DURATION_SEC), 1) AS MAX_DURATION,
    ROUND(AVG(P95_DURATION_SEC), 1) AS P95_DURATION
FROM VW_PERFORMANCE_METRICS
GROUP BY SOURCE_NAME
ORDER BY AVG_DURATION DESC;

-- Query 6: Client overview (for multi-tenant monitoring)
SELECT * FROM VW_OPERATIONAL_OVERVIEW;


-- ===========================================================================
-- VERIFICATION
-- ===========================================================================

SHOW VIEWS IN SCHEMA MDF_CONTROL_DB.MONITORING;

SELECT 'VW_INGESTION_EXECUTIVE_SUMMARY' AS VIEW_NAME, COUNT(*) AS ROWS FROM VW_INGESTION_EXECUTIVE_SUMMARY
UNION ALL SELECT 'VW_SOURCE_HEALTH', COUNT(*) FROM VW_SOURCE_HEALTH
UNION ALL SELECT 'VW_OPERATIONAL_OVERVIEW', COUNT(*) FROM VW_OPERATIONAL_OVERVIEW;


/*
#############################################################################
  MODULE 09 COMPLETE!

  Views Created:
    - VW_INGESTION_EXECUTIVE_SUMMARY (30-day daily health)
    - VW_SOURCE_HEALTH (per-source with HEALTHY/WARNING/CRITICAL)
    - VW_THROUGHPUT_METRICS (hourly data volumes)
    - VW_ERROR_ANALYSIS (error patterns with severity)
    - VW_PERFORMANCE_METRICS (P95 duration, rows/sec)
    - VW_OPERATIONAL_OVERVIEW (client config summary)
    - VW_DAILY_SUMMARY (today's KPIs)

  Next: MDF - Module 10 (Schema Evolution & Advanced Topics)
#############################################################################
*/
