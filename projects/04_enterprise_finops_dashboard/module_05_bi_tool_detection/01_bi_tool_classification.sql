/*
=============================================================================
  MODULE 05 : BI TOOL DETECTION
  SCRIPT 01 : BI Tool Classification and Usage Tracking
=============================================================================
  SNOWBRIX ACADEMY — Enterprise FinOps Dashboard for Snowflake

  LEARNING OBJECTIVES:
    1. Classify queries by BI tool (Power BI, Tableau, Looker, dbt, etc.)
    2. Track BI tool usage and costs
    3. Identify expensive reports and dashboards
    4. Provide BI tool cost breakdown for chargeback

  BI TOOL DETECTION METHODS:
  ┌──────────────────────────────────────────────────────────────┐
  │  1. APPLICATION_NAME matching                                │
  │     → QUERY_HISTORY.APPLICATION_NAME                         │
  │     → Pattern: 'PowerBI', 'Tableau', 'dbt', etc.            │
  │                                                               │
  │  2. Service account naming                                   │
  │     → SVC_POWERBI_*, SVC_TABLEAU_*, etc.                    │
  │                                                               │
  │  3. Query pattern analysis                                   │
  │     → Power BI: Multiple small queries                       │
  │     → Tableau: Large result sets                             │
  │     → dbt: CREATE TABLE/VIEW statements                      │
  └──────────────────────────────────────────────────────────────┘

  PREREQUISITES:
    - FACT_QUERY_COST_HISTORY populated

  ESTIMATED TIME: 15 minutes

=============================================================================
*/

USE ROLE FINOPS_ADMIN_ROLE;
USE DATABASE FINOPS_CONTROL_DB;
USE SCHEMA CHARGEBACK;
USE WAREHOUSE FINOPS_WH_ADMIN;

-- =========================================================================
-- DIMENSION: DIM_BI_TOOL_REGISTRY
-- Registry of BI tools with detection patterns
-- =========================================================================
CREATE TABLE IF NOT EXISTS DIM_BI_TOOL_REGISTRY (
    TOOL_ID                     NUMBER AUTOINCREMENT PRIMARY KEY,
    TOOL_NAME                   VARCHAR(100) NOT NULL,
    TOOL_CATEGORY               VARCHAR(50) COMMENT 'BI_PLATFORM, ORCHESTRATION, TRANSFORMATION, NOTEBOOK',
    VENDOR_NAME                 VARCHAR(100),

    -- Detection Patterns
    APPLICATION_NAME_PATTERN    VARCHAR(500) COMMENT 'Regex pattern for APPLICATION_NAME',
    SERVICE_ACCOUNT_PATTERN     VARCHAR(500) COMMENT 'Pattern for service account names',
    WAREHOUSE_NAME_PATTERN      VARCHAR(500) COMMENT 'Pattern for dedicated warehouses',

    -- Cost Characteristics
    TYPICAL_QUERY_SIZE          VARCHAR(20) COMMENT 'SMALL, MEDIUM, LARGE',
    TYPICAL_RESULT_SET_SIZE     VARCHAR(20) COMMENT 'SMALL, MEDIUM, LARGE',

    IS_ACTIVE                   BOOLEAN DEFAULT TRUE,
    CREATED_AT                  TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),

    CONSTRAINT chk_tool_category CHECK (
        TOOL_CATEGORY IN ('BI_PLATFORM', 'ORCHESTRATION', 'TRANSFORMATION', 'NOTEBOOK', 'ETL', 'OTHER')
    )
)
COMMENT = 'Dimension: Registry of BI tools with detection patterns';


-- =========================================================================
-- FACT TABLE: FACT_BI_TOOL_USAGE
-- Daily aggregated BI tool usage and costs
-- =========================================================================
CREATE TABLE IF NOT EXISTS FACT_BI_TOOL_USAGE (
    USAGE_DATE                  DATE NOT NULL,
    TOOL_NAME                   VARCHAR(100) NOT NULL,
    TOOL_CATEGORY               VARCHAR(50),
    ENTITY_ID                   NUMBER COMMENT 'FK to DIM_CHARGEBACK_ENTITY',
    ENTITY_NAME                 VARCHAR(200),

    -- Usage Metrics
    QUERY_COUNT                 NUMBER DEFAULT 0,
    UNIQUE_USERS                NUMBER DEFAULT 0,
    UNIQUE_WAREHOUSES           NUMBER DEFAULT 0,

    -- Cost Metrics
    COST_USD                    NUMBER(18, 4) DEFAULT 0.00,
    CREDITS_CONSUMED            NUMBER(18, 4) DEFAULT 0.00,
    AVG_QUERY_COST_USD          NUMBER(18, 4),
    MAX_QUERY_COST_USD          NUMBER(18, 4),

    -- Performance Metrics
    AVG_EXECUTION_TIME_MS       NUMBER,
    TOTAL_BYTES_SCANNED         NUMBER,

    CALCULATED_AT               TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),

    PRIMARY KEY (USAGE_DATE, TOOL_NAME, ENTITY_ID)
)
PARTITION BY (USAGE_DATE)
CLUSTER BY (USAGE_DATE, TOOL_NAME)
COMMENT = 'Fact: Daily BI tool usage aggregated by tool and entity';


-- =========================================================================
-- POPULATE BI TOOL REGISTRY
-- =========================================================================
INSERT INTO DIM_BI_TOOL_REGISTRY (
    TOOL_NAME, TOOL_CATEGORY, VENDOR_NAME,
    APPLICATION_NAME_PATTERN, SERVICE_ACCOUNT_PATTERN, WAREHOUSE_NAME_PATTERN,
    TYPICAL_QUERY_SIZE, TYPICAL_RESULT_SET_SIZE
) VALUES
    -- BI Platforms
    ('Power BI', 'BI_PLATFORM', 'Microsoft',
     '(?i)(powerbi|microsoft.*pbi|pbiservice)', '(?i)(svc_powerbi|sa_pbi)', '(?i)(wh_powerbi|wh_pbi)',
     'SMALL', 'MEDIUM'),

    ('Tableau', 'BI_PLATFORM', 'Salesforce',
     '(?i)(tableau)', '(?i)(svc_tableau|sa_tableau)', '(?i)(wh_tableau)',
     'MEDIUM', 'LARGE'),

    ('Looker', 'BI_PLATFORM', 'Google',
     '(?i)(looker)', '(?i)(svc_looker|sa_looker)', '(?i)(wh_looker)',
     'MEDIUM', 'MEDIUM'),

    ('Sigma Computing', 'BI_PLATFORM', 'Sigma',
     '(?i)(sigma)', '(?i)(svc_sigma|sa_sigma)', '(?i)(wh_sigma)',
     'MEDIUM', 'MEDIUM'),

    ('Mode Analytics', 'BI_PLATFORM', 'Mode',
     '(?i)(mode)', '(?i)(svc_mode|sa_mode)', '(?i)(wh_mode)',
     'MEDIUM', 'MEDIUM'),

    -- Transformation Tools
    ('dbt', 'TRANSFORMATION', 'dbt Labs',
     '(?i)(dbt)', '(?i)(svc_dbt|sa_dbt)', '(?i)(wh_dbt|wh_transform)',
     'LARGE', 'SMALL'),

    -- Orchestration Tools
    ('Apache Airflow', 'ORCHESTRATION', 'Apache',
     '(?i)(airflow)', '(?i)(svc_airflow|sa_airflow)', '(?i)(wh_airflow|wh_orchestration)',
     'MEDIUM', 'SMALL'),

    ('Prefect', 'ORCHESTRATION', 'Prefect',
     '(?i)(prefect)', '(?i)(svc_prefect|sa_prefect)', '(?i)(wh_prefect)',
     'MEDIUM', 'SMALL'),

    ('Dagster', 'ORCHESTRATION', 'Dagster Labs',
     '(?i)(dagster)', '(?i)(svc_dagster|sa_dagster)', '(?i)(wh_dagster)',
     'MEDIUM', 'SMALL'),

    -- ETL Tools
    ('Fivetran', 'ETL', 'Fivetran',
     '(?i)(fivetran)', '(?i)(svc_fivetran|sa_fivetran|^fivetran$)', '(?i)(wh_fivetran)',
     'LARGE', 'SMALL'),

    ('Matillion', 'ETL', 'Matillion',
     '(?i)(matillion)', '(?i)(svc_matillion|sa_matillion)', '(?i)(wh_matillion)',
     'LARGE', 'SMALL'),

    -- Notebooks
    ('Jupyter', 'NOTEBOOK', 'Project Jupyter',
     '(?i)(jupyter|notebook)', '(?i)(svc_jupyter)', '(?i)(wh_jupyter|wh_notebook)',
     'MEDIUM', 'MEDIUM'),

    ('Hex', 'NOTEBOOK', 'Hex Technologies',
     '(?i)(hex)', '(?i)(svc_hex)', '(?i)(wh_hex)',
     'MEDIUM', 'MEDIUM'),

    -- Streamlit (in Snowflake)
    ('Streamlit', 'BI_PLATFORM', 'Snowflake',
     '(?i)(streamlit)', NULL, '(?i)(wh_streamlit)',
     'SMALL', 'MEDIUM'),

    -- Python/JDBC connectors
    ('Python', 'OTHER', 'Python Software Foundation',
     '(?i)(python|snowflake-connector-python)', '(?i)(svc_python)', NULL,
     'MEDIUM', 'MEDIUM'),

    ('JDBC', 'OTHER', 'Various',
     '(?i)(jdbc)', NULL, NULL,
     'MEDIUM', 'MEDIUM');


-- =========================================================================
-- PROCEDURE: SP_CLASSIFY_BI_TOOLS
-- Classifies queries by BI tool and aggregates usage
-- =========================================================================
CREATE OR REPLACE PROCEDURE SP_CLASSIFY_BI_TOOLS(
    P_START_DATE DATE,
    P_END_DATE DATE
)
RETURNS VARIANT
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER
AS
$$
    function executeSql(sqlText, binds) {
        var stmt = snowflake.createStatement({sqlText: sqlText, binds: binds || []});
        return stmt.execute();
    }

    var result = {
        procedure: 'SP_CLASSIFY_BI_TOOLS',
        status: 'INITIALIZING',
        start_date: P_START_DATE,
        end_date: P_END_DATE
    };

    try {
        // Classify and aggregate BI tool usage
        var classifySql = `
        MERGE INTO FINOPS_CONTROL_DB.CHARGEBACK.FACT_BI_TOOL_USAGE AS target
        USING (
            SELECT
                q.QUERY_DATE AS USAGE_DATE,
                COALESCE(t.TOOL_NAME, 'Unknown') AS TOOL_NAME,
                t.TOOL_CATEGORY,
                e.ENTITY_ID,
                e.ENTITY_NAME,
                COUNT(DISTINCT q.QUERY_ID) AS QUERY_COUNT,
                COUNT(DISTINCT q.USER_NAME) AS UNIQUE_USERS,
                COUNT(DISTINCT q.WAREHOUSE_NAME) AS UNIQUE_WAREHOUSES,
                SUM(q.TOTAL_COST_USD) AS COST_USD,
                SUM(q.CREDITS_USED) AS CREDITS_CONSUMED,
                AVG(q.TOTAL_COST_USD) AS AVG_QUERY_COST_USD,
                MAX(q.TOTAL_COST_USD) AS MAX_QUERY_COST_USD,
                AVG(q.EXECUTION_TIME_MS) AS AVG_EXECUTION_TIME_MS,
                SUM(q.BYTES_SCANNED) AS TOTAL_BYTES_SCANNED
            FROM FINOPS_CONTROL_DB.COST_DATA.FACT_QUERY_COST_HISTORY q
            LEFT JOIN FINOPS_CONTROL_DB.CHARGEBACK.DIM_BI_TOOL_REGISTRY t
                ON REGEXP_LIKE(q.APPLICATION_NAME, t.APPLICATION_NAME_PATTERN, 'i')
                OR REGEXP_LIKE(q.USER_NAME, t.SERVICE_ACCOUNT_PATTERN, 'i')
                OR REGEXP_LIKE(q.WAREHOUSE_NAME, t.WAREHOUSE_NAME_PATTERN, 'i')
            LEFT JOIN FINOPS_CONTROL_DB.CHARGEBACK.DIM_COST_CENTER_MAPPING m
                ON m.SOURCE_TYPE = 'USER'
                AND UPPER(m.SOURCE_VALUE) = UPPER(q.USER_NAME)
                AND m.IS_CURRENT = TRUE
            LEFT JOIN FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY e
                ON m.ENTITY_ID = e.ENTITY_ID
            WHERE q.QUERY_DATE >= ?
              AND q.QUERY_DATE <= ?
            GROUP BY
                q.QUERY_DATE, t.TOOL_NAME, t.TOOL_CATEGORY,
                e.ENTITY_ID, e.ENTITY_NAME
        ) AS source
        ON target.USAGE_DATE = source.USAGE_DATE
           AND target.TOOL_NAME = source.TOOL_NAME
           AND (target.ENTITY_ID = source.ENTITY_ID OR (target.ENTITY_ID IS NULL AND source.ENTITY_ID IS NULL))
        WHEN MATCHED THEN UPDATE SET
            target.QUERY_COUNT = source.QUERY_COUNT,
            target.UNIQUE_USERS = source.UNIQUE_USERS,
            target.COST_USD = source.COST_USD,
            target.CALCULATED_AT = CURRENT_TIMESTAMP()
        WHEN NOT MATCHED THEN INSERT (
            USAGE_DATE, TOOL_NAME, TOOL_CATEGORY, ENTITY_ID, ENTITY_NAME,
            QUERY_COUNT, UNIQUE_USERS, UNIQUE_WAREHOUSES,
            COST_USD, CREDITS_CONSUMED, AVG_QUERY_COST_USD, MAX_QUERY_COST_USD,
            AVG_EXECUTION_TIME_MS, TOTAL_BYTES_SCANNED
        ) VALUES (
            source.USAGE_DATE, source.TOOL_NAME, source.TOOL_CATEGORY,
            source.ENTITY_ID, source.ENTITY_NAME,
            source.QUERY_COUNT, source.UNIQUE_USERS, source.UNIQUE_WAREHOUSES,
            source.COST_USD, source.CREDITS_CONSUMED, source.AVG_QUERY_COST_USD,
            source.MAX_QUERY_COST_USD, source.AVG_EXECUTION_TIME_MS, source.TOTAL_BYTES_SCANNED
        )`;

        var classifyStmt = snowflake.createStatement({
            sqlText: classifySql,
            binds: [P_START_DATE, P_END_DATE]
        });
        var classifyResult = classifyStmt.execute();
        classifyResult.next();

        result.rows_inserted = classifyResult.getColumnValue('number of rows inserted');
        result.rows_updated = classifyResult.getColumnValue('number of rows updated');
        result.status = 'SUCCESS';

        return result;

    } catch (err) {
        result.status = 'ERROR';
        result.error_message = err.message;
        return result;
    }
$$;


-- =========================================================================
-- GRANT PERMISSIONS
-- =========================================================================
GRANT USAGE ON PROCEDURE SP_CLASSIFY_BI_TOOLS(DATE, DATE) TO ROLE FINOPS_ANALYST_ROLE;
GRANT SELECT ON TABLE FACT_BI_TOOL_USAGE TO ROLE FINOPS_ANALYST_ROLE;


-- =========================================================================
-- VERIFICATION QUERIES
-- =========================================================================

/*
-- Test: Classify BI tools for last 7 days
CALL SP_CLASSIFY_BI_TOOLS(DATEADD(DAY, -7, CURRENT_DATE()), CURRENT_DATE());

-- Verify: BI tool usage summary
SELECT
    TOOL_NAME,
    TOOL_CATEGORY,
    SUM(QUERY_COUNT) AS TOTAL_QUERIES,
    SUM(COST_USD) AS TOTAL_COST_USD,
    COUNT(DISTINCT USAGE_DATE) AS DAYS_ACTIVE,
    AVG(AVG_QUERY_COST_USD) AS AVG_QUERY_COST
FROM FACT_BI_TOOL_USAGE
WHERE USAGE_DATE >= DATEADD(DAY, -30, CURRENT_DATE())
GROUP BY TOOL_NAME, TOOL_CATEGORY
ORDER BY TOTAL_COST_USD DESC;

-- Verify: BI tool costs by entity
SELECT
    TOOL_NAME,
    ENTITY_NAME,
    SUM(COST_USD) AS TOTAL_COST_USD,
    SUM(QUERY_COUNT) AS TOTAL_QUERIES,
    AVG(UNIQUE_USERS) AS AVG_DAILY_USERS
FROM FACT_BI_TOOL_USAGE
WHERE USAGE_DATE >= DATEADD(DAY, -30, CURRENT_DATE())
  AND ENTITY_NAME IS NOT NULL
GROUP BY TOOL_NAME, ENTITY_NAME
ORDER BY TOTAL_COST_USD DESC
LIMIT 20;
*/

/*
=============================================================================
  OBJECTS CREATED:
    - DIM_BI_TOOL_REGISTRY
    - FACT_BI_TOOL_USAGE
    - SP_CLASSIFY_BI_TOOLS

  NEXT STEPS:
    → Script 02: BI tool analysis views
=============================================================================
*/
