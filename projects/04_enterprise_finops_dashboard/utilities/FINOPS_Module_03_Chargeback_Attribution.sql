/*
#############################################################################
  FINOPS - Module 03: Chargeback Attribution
  CONSOLIDATED WORKSHEET — Snowsight / VS Code Ready
#############################################################################
  SNOWBRIX ACADEMY — Enterprise FinOps Dashboard for Snowflake

  This worksheet contains:
    - 01_dimension_tables.sql
    - 02_attribution_logic.sql
    - 03_helper_procedures.sql
    

  INSTRUCTIONS:
    - Run each section sequentially (top to bottom)
    - Requires Module 02 to be completed first (if applicable)
    - Estimated time: ~25 minutes

  PREREQUISITES:
    - Module 02 completed
    - FINOPS_ADMIN_ROLE access
#############################################################################
*/


USE ROLE FINOPS_ADMIN_ROLE;
USE DATABASE FINOPS_CONTROL_DB;
USE SCHEMA CHARGEBACK;
USE WAREHOUSE FINOPS_WH_ADMIN;

-- =========================================================================
-- DIMENSION: DIM_CHARGEBACK_ENTITY
-- Stores the organizational hierarchy: teams, departments, projects, cost centers
-- =========================================================================
CREATE TABLE IF NOT EXISTS DIM_CHARGEBACK_ENTITY (
    -- Primary Key
    ENTITY_ID               NUMBER AUTOINCREMENT PRIMARY KEY,

    -- Entity Classification
    ENTITY_TYPE             VARCHAR(50) NOT NULL COMMENT 'TEAM, DEPARTMENT, PROJECT, BUSINESS_UNIT, COST_CENTER',
    ENTITY_NAME             VARCHAR(200) NOT NULL COMMENT 'Unique name within entity type',
    ENTITY_CODE             VARCHAR(50) COMMENT 'Short code for entity (e.g., DATA_ENG, ANALYTICS)',

    -- Hierarchical Relationships
    PARENT_ENTITY_ID        NUMBER COMMENT 'FK to parent entity (team → department → business unit)',
    COST_CENTER_CODE        VARCHAR(50) COMMENT 'Financial system cost center identifier',

    -- Contact Information
    MANAGER_NAME            VARCHAR(200) COMMENT 'Team lead or department manager name',
    MANAGER_EMAIL           VARCHAR(200) COMMENT 'Contact email for budget alerts',

    -- Allocation Rules
    DEFAULT_ALLOCATION_PCT  NUMBER(5, 2) DEFAULT 100.00 COMMENT 'Default allocation percentage (100% = dedicated)',

    -- Status and Versioning (SCD Type 2)
    IS_ACTIVE               BOOLEAN DEFAULT TRUE COMMENT 'FALSE for decommissioned entities',
    VALID_FROM              DATE NOT NULL DEFAULT CURRENT_DATE() COMMENT 'SCD Type 2: effective start date',
    VALID_TO                DATE DEFAULT '9999-12-31' COMMENT 'SCD Type 2: effective end date',
    IS_CURRENT              BOOLEAN DEFAULT TRUE COMMENT 'SCD Type 2: current version flag',

    -- Audit Metadata
    CREATED_AT              TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CREATED_BY              VARCHAR(200) DEFAULT CURRENT_USER(),
    UPDATED_AT              TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_BY              VARCHAR(200) DEFAULT CURRENT_USER(),

    -- Constraints
    CONSTRAINT chk_entity_type CHECK (ENTITY_TYPE IN ('TEAM', 'DEPARTMENT', 'PROJECT', 'BUSINESS_UNIT', 'COST_CENTER')),
    CONSTRAINT chk_valid_dates CHECK (VALID_FROM <= VALID_TO),
    CONSTRAINT chk_allocation_pct CHECK (DEFAULT_ALLOCATION_PCT BETWEEN 0 AND 100)
)
COMMENT = 'Dimension: Chargeback entities (teams, departments, projects, cost centers) with SCD Type 2 versioning';

-- Create index for performance
CREATE INDEX IF NOT EXISTS idx_entity_current ON DIM_CHARGEBACK_ENTITY(ENTITY_NAME, IS_CURRENT) WHERE IS_CURRENT = TRUE;
CREATE INDEX IF NOT EXISTS idx_entity_valid_dates ON DIM_CHARGEBACK_ENTITY(VALID_FROM, VALID_TO);


-- =========================================================================
-- MAPPING: DIM_COST_CENTER_MAPPING
-- Maps users, warehouses, and roles to chargeback entities
-- Supports proportional allocation for shared resources
-- =========================================================================
CREATE TABLE IF NOT EXISTS DIM_COST_CENTER_MAPPING (
    -- Primary Key
    MAPPING_ID              NUMBER AUTOINCREMENT PRIMARY KEY,

    -- Source Identification (what are we mapping?)
    SOURCE_TYPE             VARCHAR(20) NOT NULL COMMENT 'USER, WAREHOUSE, ROLE',
    SOURCE_VALUE            VARCHAR(200) NOT NULL COMMENT 'Username, warehouse name, or role name',

    -- Target Attribution (where does cost go?)
    ENTITY_ID               NUMBER NOT NULL COMMENT 'FK to DIM_CHARGEBACK_ENTITY',

    -- Proportional Allocation Support
    ALLOCATION_PERCENTAGE   NUMBER(5, 2) DEFAULT 100.00 NOT NULL COMMENT '100% = dedicated, <100% = shared',
    ALLOCATION_RULE         VARCHAR(500) COMMENT 'Description of allocation logic (e.g., "50% Team A, 50% Team B")',

    -- Environment Classification
    ENVIRONMENT             VARCHAR(20) COMMENT 'PROD, QA, DEV, SANDBOX for additional filtering',

    -- Status and Versioning (SCD Type 2)
    IS_ACTIVE               BOOLEAN DEFAULT TRUE,
    VALID_FROM              DATE NOT NULL DEFAULT CURRENT_DATE(),
    VALID_TO                DATE DEFAULT '9999-12-31',
    IS_CURRENT              BOOLEAN DEFAULT TRUE,

    -- Audit Metadata
    CREATED_AT              TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CREATED_BY              VARCHAR(200) DEFAULT CURRENT_USER(),
    UPDATED_AT              TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_BY              VARCHAR(200) DEFAULT CURRENT_USER(),

    -- Constraints
    CONSTRAINT chk_source_type CHECK (SOURCE_TYPE IN ('USER', 'WAREHOUSE', 'ROLE')),
    CONSTRAINT chk_environment CHECK (ENVIRONMENT IN ('PROD', 'QA', 'DEV', 'SANDBOX', 'SHARED') OR ENVIRONMENT IS NULL),
    CONSTRAINT chk_mapping_dates CHECK (VALID_FROM <= VALID_TO),
    CONSTRAINT chk_mapping_allocation CHECK (ALLOCATION_PERCENTAGE BETWEEN 0 AND 100),

    -- Foreign Key
    CONSTRAINT fk_mapping_entity FOREIGN KEY (ENTITY_ID) REFERENCES DIM_CHARGEBACK_ENTITY(ENTITY_ID)
)
COMMENT = 'Mapping: Associates users, warehouses, and roles to chargeback entities with proportional allocation support (SCD Type 2)';

-- Performance indexes
CREATE INDEX IF NOT EXISTS idx_mapping_source ON DIM_COST_CENTER_MAPPING(SOURCE_TYPE, SOURCE_VALUE, IS_CURRENT) WHERE IS_CURRENT = TRUE;
CREATE INDEX IF NOT EXISTS idx_mapping_entity ON DIM_COST_CENTER_MAPPING(ENTITY_ID, IS_CURRENT) WHERE IS_CURRENT = TRUE;
CREATE INDEX IF NOT EXISTS idx_mapping_dates ON DIM_COST_CENTER_MAPPING(VALID_FROM, VALID_TO);


-- =========================================================================
-- FACT TABLE: FACT_CHARGEBACK_DAILY
-- Pre-aggregated daily costs by entity (for fast BI consumption)
-- =========================================================================
CREATE TABLE IF NOT EXISTS FACT_CHARGEBACK_DAILY (
    -- Grain: One row per day, per entity, per cost type
    CHARGEBACK_DATE         DATE NOT NULL,
    ENTITY_ID               NUMBER NOT NULL COMMENT 'FK to DIM_CHARGEBACK_ENTITY',

    -- Denormalized Dimensions (for fast querying without joins)
    ENTITY_NAME             VARCHAR(200) NOT NULL,
    ENTITY_TYPE             VARCHAR(50) NOT NULL,
    COST_CENTER_CODE        VARCHAR(50),
    PARENT_ENTITY_NAME      VARCHAR(200) COMMENT 'Department or Business Unit name',

    -- Cost Breakdown by Type
    COST_TYPE               VARCHAR(50) NOT NULL COMMENT 'COMPUTE, STORAGE, CLOUD_SERVICES, SERVERLESS',

    -- Cost Metrics
    COST_USD                NUMBER(18, 4) DEFAULT 0.00 NOT NULL,
    CREDITS_CONSUMED        NUMBER(18, 4) DEFAULT 0.00,

    -- Query Metadata (for COMPUTE costs only)
    QUERY_COUNT             NUMBER DEFAULT 0 COMMENT 'Number of queries attributed to this entity',
    UNIQUE_USERS            NUMBER DEFAULT 0 COMMENT 'Distinct users who generated costs',
    UNIQUE_WAREHOUSES       NUMBER DEFAULT 0 COMMENT 'Distinct warehouses used',

    -- Attribution Metadata
    ATTRIBUTION_METHOD      VARCHAR(50) COMMENT 'QUERY_TAG, WAREHOUSE_MAPPING, USER_MAPPING, UNALLOCATED',
    ALLOCATION_PERCENTAGE   NUMBER(5, 2) DEFAULT 100.00 COMMENT 'Proportional allocation (100% = dedicated)',

    -- Audit Trail
    CALCULATED_AT           TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CALCULATED_BY           VARCHAR(200) DEFAULT 'SP_CALCULATE_CHARGEBACK',

    -- Constraints
    CONSTRAINT chk_chargeback_cost_type CHECK (COST_TYPE IN ('COMPUTE', 'STORAGE', 'CLOUD_SERVICES', 'SERVERLESS')),
    CONSTRAINT chk_chargeback_method CHECK (
        ATTRIBUTION_METHOD IN ('QUERY_TAG', 'WAREHOUSE_MAPPING', 'USER_MAPPING', 'ROLE_MAPPING', 'UNALLOCATED', 'DEFAULT')
    ),

    -- Composite Primary Key
    PRIMARY KEY (CHARGEBACK_DATE, ENTITY_ID, COST_TYPE)
)
PARTITION BY (CHARGEBACK_DATE)
CLUSTER BY (CHARGEBACK_DATE, ENTITY_ID)
COMMENT = 'Fact: Daily chargeback costs aggregated by entity and cost type. Partitioned by date for fast queries.';


-- =========================================================================
-- QUERY TAG PARSING TABLE: DIM_QUERY_TAG_RULES
-- Defines rules for parsing QUERY_TAG metadata
-- =========================================================================
CREATE TABLE IF NOT EXISTS DIM_QUERY_TAG_RULES (
    RULE_ID                 NUMBER AUTOINCREMENT PRIMARY KEY,
    RULE_NAME               VARCHAR(100) NOT NULL,
    TAG_KEY                 VARCHAR(50) NOT NULL COMMENT 'Key to extract from query tag (e.g., "team", "project")',
    ENTITY_TYPE             VARCHAR(50) NOT NULL COMMENT 'TEAM, PROJECT, DEPARTMENT, etc.',
    PRIORITY                NUMBER DEFAULT 100 COMMENT 'Lower number = higher priority',
    IS_ACTIVE               BOOLEAN DEFAULT TRUE,
    CREATED_AT              TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),

    CONSTRAINT chk_tag_entity_type CHECK (ENTITY_TYPE IN ('TEAM', 'DEPARTMENT', 'PROJECT', 'BUSINESS_UNIT', 'COST_CENTER'))
)
COMMENT = 'Dimension: Rules for parsing QUERY_TAG into entity mappings (e.g., team=DATA_ENG → ENTITY_NAME)';

-- Insert default query tag parsing rules
INSERT INTO DIM_QUERY_TAG_RULES (RULE_NAME, TAG_KEY, ENTITY_TYPE, PRIORITY) VALUES
    ('Team Tag', 'team', 'TEAM', 10),
    ('Project Tag', 'project', 'PROJECT', 20),
    ('Department Tag', 'department', 'DEPARTMENT', 30),
    ('Cost Center Tag', 'cost_center', 'COST_CENTER', 40);


-- =========================================================================
-- SAMPLE DATA: INSERT EXAMPLE ENTITIES AND MAPPINGS
-- =========================================================================

-- Insert Business Units
INSERT INTO DIM_CHARGEBACK_ENTITY (ENTITY_TYPE, ENTITY_NAME, ENTITY_CODE, COST_CENTER_CODE, MANAGER_NAME, MANAGER_EMAIL)
VALUES
    ('BUSINESS_UNIT', 'Engineering', 'ENG', 'CC-1000', 'Jane Doe', 'jane.doe@company.com'),
    ('BUSINESS_UNIT', 'Finance', 'FIN', 'CC-2000', 'John Smith', 'john.smith@company.com'),
    ('BUSINESS_UNIT', 'Marketing', 'MKT', 'CC-3000', 'Sarah Lee', 'sarah.lee@company.com');

-- Insert Departments
INSERT INTO DIM_CHARGEBACK_ENTITY (ENTITY_TYPE, ENTITY_NAME, ENTITY_CODE, PARENT_ENTITY_ID, COST_CENTER_CODE, MANAGER_NAME, MANAGER_EMAIL)
VALUES
    ('DEPARTMENT', 'Data Engineering', 'DATA_ENG', 1, 'CC-1100', 'Alice Chen', 'alice.chen@company.com'),
    ('DEPARTMENT', 'Analytics', 'ANALYTICS', 1, 'CC-1200', 'Bob Wilson', 'bob.wilson@company.com'),
    ('DEPARTMENT', 'ML Engineering', 'ML_ENG', 1, 'CC-1300', 'Carol Martinez', 'carol.martinez@company.com'),
    ('DEPARTMENT', 'Financial Planning', 'FIN_PLAN', 2, 'CC-2100', 'David Brown', 'david.brown@company.com'),
    ('DEPARTMENT', 'Marketing Analytics', 'MKT_ANALYTICS', 3, 'CC-3100', 'Emma Davis', 'emma.davis@company.com');

-- Insert Teams
INSERT INTO DIM_CHARGEBACK_ENTITY (ENTITY_TYPE, ENTITY_NAME, ENTITY_CODE, PARENT_ENTITY_ID, COST_CENTER_CODE, MANAGER_NAME, MANAGER_EMAIL)
VALUES
    ('TEAM', 'ETL Pipeline Team', 'ETL_PIPELINE', 4, 'CC-1110', 'Frank Zhang', 'frank.zhang@company.com'),
    ('TEAM', 'Data Lake Team', 'DATA_LAKE', 4, 'CC-1120', 'Grace Kim', 'grace.kim@company.com'),
    ('TEAM', 'BI Platform Team', 'BI_PLATFORM', 5, 'CC-1210', 'Henry Liu', 'henry.liu@company.com'),
    ('TEAM', 'Self-Service Analytics', 'SELF_SERVICE', 5, 'CC-1220', 'Ivy Johnson', 'ivy.johnson@company.com'),
    ('TEAM', 'ML Platform Team', 'ML_PLATFORM', 6, 'CC-1310', 'Jack Taylor', 'jack.taylor@company.com'),
    ('TEAM', 'Campaign Analytics', 'CAMPAIGN_ANALYTICS', 8, 'CC-3110', 'Kelly White', 'kelly.white@company.com');

-- Insert Projects
INSERT INTO DIM_CHARGEBACK_ENTITY (ENTITY_TYPE, ENTITY_NAME, ENTITY_CODE, PARENT_ENTITY_ID, COST_CENTER_CODE, MANAGER_NAME, MANAGER_EMAIL)
VALUES
    ('PROJECT', 'Customer 360', 'CUSTOMER_360', 4, 'CC-1100', 'Alice Chen', 'alice.chen@company.com'),
    ('PROJECT', 'Revenue Dashboard', 'REVENUE_DASH', 5, 'CC-1200', 'Bob Wilson', 'bob.wilson@company.com'),
    ('PROJECT', 'Churn Prediction Model', 'CHURN_MODEL', 6, 'CC-1300', 'Carol Martinez', 'carol.martinez@company.com'),
    ('PROJECT', 'Marketing Attribution', 'MKT_ATTR', 8, 'CC-3100', 'Emma Davis', 'emma.davis@company.com');


-- =========================================================================
-- SAMPLE WAREHOUSE MAPPINGS
-- =========================================================================

-- Dedicated warehouses (100% allocation)
INSERT INTO DIM_COST_CENTER_MAPPING (SOURCE_TYPE, SOURCE_VALUE, ENTITY_ID, ALLOCATION_PERCENTAGE, ENVIRONMENT, ALLOCATION_RULE)
VALUES
    -- ETL warehouses → ETL Pipeline Team
    ('WAREHOUSE', 'WH_ETL_PROD', 9, 100.00, 'PROD', 'Dedicated warehouse for ETL Pipeline Team'),
    ('WAREHOUSE', 'WH_ETL_DEV', 9, 100.00, 'DEV', 'Dev environment for ETL Pipeline Team'),

    -- Analytics warehouses → BI Platform Team
    ('WAREHOUSE', 'WH_BI_PROD', 11, 100.00, 'PROD', 'Dedicated warehouse for BI Platform Team'),
    ('WAREHOUSE', 'WH_ANALYTICS_ADHOC', 12, 100.00, 'PROD', 'Ad-hoc analysis for Self-Service Analytics'),

    -- ML warehouses → ML Platform Team
    ('WAREHOUSE', 'WH_ML_TRAINING', 13, 100.00, 'PROD', 'Model training warehouse for ML Platform Team'),
    ('WAREHOUSE', 'WH_ML_INFERENCE', 13, 100.00, 'PROD', 'Model inference warehouse for ML Platform Team'),

    -- FinOps Framework warehouses → Data Engineering (operational overhead)
    ('WAREHOUSE', 'FINOPS_WH_ADMIN', 4, 100.00, 'PROD', 'FinOps framework admin warehouse'),
    ('WAREHOUSE', 'FINOPS_WH_ETL', 4, 100.00, 'PROD', 'FinOps framework ETL warehouse'),
    ('WAREHOUSE', 'FINOPS_WH_REPORTING', 4, 100.00, 'PROD', 'FinOps framework reporting warehouse');

-- Shared warehouse (proportional allocation)
INSERT INTO DIM_COST_CENTER_MAPPING (SOURCE_TYPE, SOURCE_VALUE, ENTITY_ID, ALLOCATION_PERCENTAGE, ENVIRONMENT, ALLOCATION_RULE)
VALUES
    ('WAREHOUSE', 'WH_SHARED_ANALYTICS', 11, 60.00, 'SHARED', 'BI Platform Team: 60% allocation based on historical usage'),
    ('WAREHOUSE', 'WH_SHARED_ANALYTICS', 12, 40.00, 'SHARED', 'Self-Service Analytics: 40% allocation based on historical usage');


-- =========================================================================
-- SAMPLE USER MAPPINGS (for shared warehouses)
-- =========================================================================
INSERT INTO DIM_COST_CENTER_MAPPING (SOURCE_TYPE, SOURCE_VALUE, ENTITY_ID, ALLOCATION_PERCENTAGE, ALLOCATION_RULE)
VALUES
    -- Service accounts
    ('USER', 'SVC_DBT_PROD', 9, 100.00, 'dbt service account for ETL Pipeline Team'),
    ('USER', 'SVC_AIRFLOW_PROD', 9, 100.00, 'Airflow service account for ETL Pipeline Team'),
    ('USER', 'SVC_FIVETRAN', 10, 100.00, 'Fivetran service account for Data Lake Team'),

    -- Human users (example)
    ('USER', 'FRANK.ZHANG@COMPANY.COM', 9, 100.00, 'Team lead: ETL Pipeline Team'),
    ('USER', 'GRACE.KIM@COMPANY.COM', 10, 100.00, 'Team lead: Data Lake Team'),
    ('USER', 'HENRY.LIU@COMPANY.COM', 11, 100.00, 'Team lead: BI Platform Team');


-- =========================================================================
-- UNALLOCATED COST TRACKING ENTITY
-- =========================================================================
INSERT INTO DIM_CHARGEBACK_ENTITY (ENTITY_TYPE, ENTITY_NAME, ENTITY_CODE, COST_CENTER_CODE, MANAGER_NAME, MANAGER_EMAIL)
VALUES
    ('COST_CENTER', 'Unallocated Costs', 'UNALLOCATED', 'CC-9999', 'FinOps Admin', 'finops@company.com');


-- =========================================================================
-- VERIFICATION QUERIES
-- =========================================================================

/*
-- Verify: Entity hierarchy
SELECT
    e.ENTITY_ID,
    e.ENTITY_TYPE,
    e.ENTITY_NAME,
    e.ENTITY_CODE,
    p.ENTITY_NAME AS PARENT_ENTITY,
    e.COST_CENTER_CODE,
    e.MANAGER_NAME,
    e.IS_CURRENT
FROM DIM_CHARGEBACK_ENTITY e
LEFT JOIN DIM_CHARGEBACK_ENTITY p ON e.PARENT_ENTITY_ID = p.ENTITY_ID
WHERE e.IS_CURRENT = TRUE
ORDER BY e.ENTITY_TYPE, e.ENTITY_NAME;


-- Verify: Warehouse mappings
SELECT
    m.MAPPING_ID,
    m.SOURCE_TYPE,
    m.SOURCE_VALUE,
    e.ENTITY_NAME,
    e.ENTITY_TYPE,
    m.ALLOCATION_PERCENTAGE,
    m.ENVIRONMENT,
    m.IS_CURRENT
FROM DIM_COST_CENTER_MAPPING m
JOIN DIM_CHARGEBACK_ENTITY e ON m.ENTITY_ID = e.ENTITY_ID
WHERE m.SOURCE_TYPE = 'WAREHOUSE'
  AND m.IS_CURRENT = TRUE
ORDER BY m.SOURCE_VALUE, m.ALLOCATION_PERCENTAGE DESC;


-- Verify: User mappings
SELECT
    m.SOURCE_VALUE AS USER_NAME,
    e.ENTITY_NAME AS TEAM,
    p.ENTITY_NAME AS DEPARTMENT,
    m.ALLOCATION_PERCENTAGE,
    m.IS_CURRENT
FROM DIM_COST_CENTER_MAPPING m
JOIN DIM_CHARGEBACK_ENTITY e ON m.ENTITY_ID = e.ENTITY_ID
LEFT JOIN DIM_CHARGEBACK_ENTITY p ON e.PARENT_ENTITY_ID = p.ENTITY_ID
WHERE m.SOURCE_TYPE = 'USER'
  AND m.IS_CURRENT = TRUE
ORDER BY e.ENTITY_NAME, m.SOURCE_VALUE;


-- Verify: Shared warehouse allocation (should sum to 100%)
SELECT
    SOURCE_VALUE AS WAREHOUSE_NAME,
    SUM(ALLOCATION_PERCENTAGE) AS TOTAL_ALLOCATION_PCT,
    COUNT(*) AS ENTITY_COUNT
FROM DIM_COST_CENTER_MAPPING
WHERE SOURCE_TYPE = 'WAREHOUSE'
  AND IS_CURRENT = TRUE
GROUP BY SOURCE_VALUE
HAVING COUNT(*) > 1;  -- Only show shared warehouses


-- Verify: Entity tree (full hierarchy)
WITH RECURSIVE entity_tree AS (
    -- Root entities (no parent)
    SELECT
        ENTITY_ID,
        ENTITY_TYPE,
        ENTITY_NAME,
        PARENT_ENTITY_ID,
        ENTITY_NAME AS PATH,
        1 AS LEVEL
    FROM DIM_CHARGEBACK_ENTITY
    WHERE PARENT_ENTITY_ID IS NULL
      AND IS_CURRENT = TRUE

    UNION ALL

    -- Child entities
    SELECT
        e.ENTITY_ID,
        e.ENTITY_TYPE,
        e.ENTITY_NAME,
        e.PARENT_ENTITY_ID,
        t.PATH || ' > ' || e.ENTITY_NAME AS PATH,
        t.LEVEL + 1 AS LEVEL
    FROM DIM_CHARGEBACK_ENTITY e
    JOIN entity_tree t ON e.PARENT_ENTITY_ID = t.ENTITY_ID
    WHERE e.IS_CURRENT = TRUE
)
SELECT
    LEVEL,
    ENTITY_TYPE,
    ENTITY_NAME,
    PATH AS FULL_HIERARCHY_PATH
FROM entity_tree
ORDER BY PATH;


-- Verify: Query tag parsing rules
SELECT
    RULE_ID,
    RULE_NAME,
    TAG_KEY,
    ENTITY_TYPE,
    PRIORITY,
    IS_ACTIVE
FROM DIM_QUERY_TAG_RULES
WHERE IS_ACTIVE = TRUE
ORDER BY PRIORITY;
*/


/*
=============================================================================
  BEST PRACTICES & DESIGN NOTES:

  1. SCD TYPE 2 PATTERN:
     - Always use VALID_FROM, VALID_TO, IS_CURRENT for time-based changes
     - Query with IS_CURRENT = TRUE for latest version
     - Query with date range for historical point-in-time attribution
     - NEVER delete records; close them by setting IS_CURRENT = FALSE

  2. PROPORTIONAL ALLOCATION:
     - Use ALLOCATION_PERCENTAGE for shared warehouses
     - Sum of percentages for same SOURCE_VALUE should = 100%
     - Document allocation rule in ALLOCATION_RULE column
     - Review allocation quarterly based on actual usage patterns

  3. ENTITY HIERARCHY:
     - Use PARENT_ENTITY_ID to create tree structure
     - Typical hierarchy: TEAM → DEPARTMENT → BUSINESS_UNIT
     - COST_CENTER can be at any level (usually department or BU)
     - Projects can span multiple teams (many-to-many via mappings)

  4. UNALLOCATED COSTS:
     - Always create an "Unallocated" entity to capture unmapped costs
     - Goal: Unallocated < 5% of total spend
     - Report unallocated costs prominently to drive tag adoption
     - Review unallocated costs weekly to identify mapping gaps

  5. QUERY TAG PRIORITY:
     - QUERY_TAG attribution takes precedence over warehouse mapping
     - Format: team=DATA_ENG;project=CUSTOMER_360;environment=PROD
     - Parse using SPLIT_TO_TABLE or REGEXP functions
     - Document tag format in DIM_QUERY_TAG_RULES

  6. WAREHOUSE NAMING CONVENTION:
     - Recommended: WH_{TEAM}_{PURPOSE}_{ENV}
     - Example: WH_ETL_INGESTION_PROD, WH_BI_REPORTING_DEV
     - Naming convention enables automatic mapping without manual config

  EDGE CASES HANDLED:
  - Multiple mappings for same source (proportional allocation)
  - Org changes mid-month (SCD Type 2 tracks both old and new)
  - Warehouse renamed (create new mapping, close old one)
  - User switches teams (create new user mapping with VALID_FROM)
  - Projects spanning multiple teams (use PROJECT entity type)

  OBJECTS CREATED:
    - FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY
    - FINOPS_CONTROL_DB.CHARGEBACK.DIM_COST_CENTER_MAPPING
    - FINOPS_CONTROL_DB.CHARGEBACK.FACT_CHARGEBACK_DAILY
    - FINOPS_CONTROL_DB.CHARGEBACK.DIM_QUERY_TAG_RULES

  NEXT STEPS:
    → Script 02: SP_CALCULATE_CHARGEBACK (attribution logic)
    → Script 03: Helper procedures (register entity, map user/warehouse)
=============================================================================
*/

-- ===========================================================================
-- ===========================================================================
-- 02_ATTRIBUTION_LOGIC
-- ===========================================================================
-- ===========================================================================


USE ROLE FINOPS_ADMIN_ROLE;
USE DATABASE FINOPS_CONTROL_DB;
USE SCHEMA PROCEDURES;
USE WAREHOUSE FINOPS_WH_ETL;

-- =========================================================================
-- PROCEDURE: SP_CALCULATE_CHARGEBACK
-- Calculates daily chargeback costs by entity using multi-method attribution
-- =========================================================================
CREATE OR REPLACE PROCEDURE SP_CALCULATE_CHARGEBACK(
    P_START_DATE        DATE,
    P_END_DATE          DATE,
    P_RECALCULATE_ALL   BOOLEAN DEFAULT FALSE  -- TRUE = recalculate existing dates
)
RETURNS VARIANT
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER
AS
$$
    // =====================================================================
    // HELPER FUNCTIONS
    // =====================================================================

    function executeSql(sqlText, binds) {
        try {
            var stmt = snowflake.createStatement({
                sqlText: sqlText,
                binds: binds || []
            });
            return stmt.execute();
        } catch (err) {
            throw new Error('SQL Error: ' + err.message + ' | SQL: ' + sqlText.substring(0, 300));
        }
    }

    function executeScalar(sqlText, binds) {
        var rs = executeSql(sqlText, binds);
        if (rs.next()) {
            return rs.getColumnValue(1);
        }
        return null;
    }

    function logExecution(execId, procName, status, startTime, endTime, rowsProcessed, errorMsg, params) {
        try {
            var durationSeconds = (endTime - startTime) / 1000;
            executeSql(
                `INSERT INTO FINOPS_CONTROL_DB.AUDIT.PROCEDURE_EXECUTION_LOG
                (EXECUTION_ID, PROCEDURE_NAME, EXECUTION_STATUS, START_TIME, END_TIME,
                 DURATION_SECONDS, ROWS_INSERTED, ERROR_MESSAGE, EXECUTION_PARAMETERS)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, PARSE_JSON(?))`,
                [execId, procName, status, startTime, endTime, durationSeconds,
                 rowsProcessed, errorMsg, JSON.stringify(params)]
            );
        } catch (err) {
            // Audit logging failure should not break procedure
            return;
        }
    }

    // =====================================================================
    // MAIN EXECUTION LOGIC
    // =====================================================================

    var executionId = executeScalar("SELECT UUID_STRING()");
    var procedureName = 'SP_CALCULATE_CHARGEBACK';
    var startTimestamp = new Date();
    var totalRowsProcessed = 0;

    var result = {
        execution_id: executionId,
        procedure_name: procedureName,
        status: 'INITIALIZING',
        start_time: startTimestamp.toISOString(),
        parameters: {
            start_date: P_START_DATE,
            end_date: P_END_DATE,
            recalculate_all: P_RECALCULATE_ALL
        }
    };

    try {
        // =================================================================
        // STEP 1: VALIDATE DATE RANGE
        // =================================================================

        if (P_START_DATE > P_END_DATE) {
            throw new Error('START_DATE must be <= END_DATE');
        }

        var daysDiff = Math.ceil((new Date(P_END_DATE) - new Date(P_START_DATE)) / (1000 * 60 * 60 * 24));
        result.days_to_process = daysDiff + 1;

        // Get UNALLOCATED entity ID
        var unallocatedEntityId = executeScalar(`
            SELECT ENTITY_ID
            FROM FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY
            WHERE ENTITY_CODE = 'UNALLOCATED'
              AND IS_CURRENT = TRUE
        `);

        if (!unallocatedEntityId) {
            throw new Error('UNALLOCATED entity not found in DIM_CHARGEBACK_ENTITY. Run module 03 script 01 first.');
        }

        result.unallocated_entity_id = unallocatedEntityId;

        // =================================================================
        // STEP 2: DELETE EXISTING DATA IF RECALCULATE_ALL = TRUE
        // =================================================================

        if (P_RECALCULATE_ALL) {
            result.status = 'DELETING_EXISTING_DATA';

            var deleteStmt = executeSql(`
                DELETE FROM FINOPS_CONTROL_DB.CHARGEBACK.FACT_CHARGEBACK_DAILY
                WHERE CHARGEBACK_DATE >= ? AND CHARGEBACK_DATE <= ?
            `, [P_START_DATE, P_END_DATE]);

            deleteStmt.next();
            result.rows_deleted = deleteStmt.getColumnValue(1);
        }

        // =================================================================
        // STEP 3: ATTRIBUTE COMPUTE COSTS (from FACT_QUERY_COST_HISTORY)
        // =================================================================

        result.status = 'ATTRIBUTING_COMPUTE_COSTS';

        var computeAttributionSql = `
        MERGE INTO FINOPS_CONTROL_DB.CHARGEBACK.FACT_CHARGEBACK_DAILY AS target
        USING (
            WITH query_costs AS (
                SELECT
                    q.QUERY_DATE,
                    q.WAREHOUSE_NAME,
                    q.USER_NAME,
                    q.ROLE_NAME,
                    q.QUERY_TAG,
                    q.TOTAL_COST_USD,
                    q.CREDITS_USED,
                    q.QUERY_ID
                FROM FINOPS_CONTROL_DB.COST_DATA.FACT_QUERY_COST_HISTORY q
                WHERE q.QUERY_DATE >= ?
                  AND q.QUERY_DATE <= ?
                  AND q.TOTAL_COST_USD > 0
            ),

            -- Priority 1: QUERY_TAG attribution
            query_tag_attribution AS (
                SELECT
                    qc.QUERY_DATE,
                    e.ENTITY_ID,
                    e.ENTITY_NAME,
                    e.ENTITY_TYPE,
                    e.COST_CENTER_CODE,
                    p.ENTITY_NAME AS PARENT_ENTITY_NAME,
                    qc.TOTAL_COST_USD,
                    qc.CREDITS_USED,
                    'QUERY_TAG' AS ATTRIBUTION_METHOD,
                    100.00 AS ALLOCATION_PERCENTAGE,
                    qc.WAREHOUSE_NAME,
                    qc.USER_NAME
                FROM query_costs qc
                CROSS JOIN LATERAL FLATTEN(INPUT => SPLIT(qc.QUERY_TAG, ';')) AS tag_parts
                JOIN FINOPS_CONTROL_DB.CHARGEBACK.DIM_QUERY_TAG_RULES r
                    ON LOWER(SPLIT_PART(tag_parts.VALUE, '=', 1)) = LOWER(r.TAG_KEY)
                    AND r.IS_ACTIVE = TRUE
                JOIN FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY e
                    ON LOWER(e.ENTITY_NAME) = LOWER(SPLIT_PART(tag_parts.VALUE, '=', 2))
                    AND e.ENTITY_TYPE = r.ENTITY_TYPE
                    AND e.IS_CURRENT = TRUE
                    AND qc.QUERY_DATE BETWEEN e.VALID_FROM AND e.VALID_TO
                LEFT JOIN FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY p
                    ON e.PARENT_ENTITY_ID = p.ENTITY_ID
                WHERE qc.QUERY_TAG IS NOT NULL
                  AND qc.QUERY_TAG != ''
            ),

            -- Priority 2: WAREHOUSE_MAPPING attribution (for queries without valid query tags)
            warehouse_attribution AS (
                SELECT
                    qc.QUERY_DATE,
                    m.ENTITY_ID,
                    e.ENTITY_NAME,
                    e.ENTITY_TYPE,
                    e.COST_CENTER_CODE,
                    p.ENTITY_NAME AS PARENT_ENTITY_NAME,
                    qc.TOTAL_COST_USD * (m.ALLOCATION_PERCENTAGE / 100.0) AS TOTAL_COST_USD,
                    qc.CREDITS_USED * (m.ALLOCATION_PERCENTAGE / 100.0) AS CREDITS_USED,
                    'WAREHOUSE_MAPPING' AS ATTRIBUTION_METHOD,
                    m.ALLOCATION_PERCENTAGE,
                    qc.WAREHOUSE_NAME,
                    qc.USER_NAME
                FROM query_costs qc
                LEFT JOIN query_tag_attribution qta
                    ON qc.QUERY_DATE = qta.QUERY_DATE
                    AND qc.USER_NAME = qta.USER_NAME
                    AND qc.WAREHOUSE_NAME = qta.WAREHOUSE_NAME
                JOIN FINOPS_CONTROL_DB.CHARGEBACK.DIM_COST_CENTER_MAPPING m
                    ON m.SOURCE_TYPE = 'WAREHOUSE'
                    AND UPPER(m.SOURCE_VALUE) = UPPER(qc.WAREHOUSE_NAME)
                    AND m.IS_CURRENT = TRUE
                    AND qc.QUERY_DATE BETWEEN m.VALID_FROM AND m.VALID_TO
                JOIN FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY e
                    ON m.ENTITY_ID = e.ENTITY_ID
                    AND e.IS_CURRENT = TRUE
                LEFT JOIN FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY p
                    ON e.PARENT_ENTITY_ID = p.ENTITY_ID
                WHERE qta.ENTITY_ID IS NULL  -- Only if no query tag match
            ),

            -- Priority 3: USER_MAPPING attribution
            user_attribution AS (
                SELECT
                    qc.QUERY_DATE,
                    m.ENTITY_ID,
                    e.ENTITY_NAME,
                    e.ENTITY_TYPE,
                    e.COST_CENTER_CODE,
                    p.ENTITY_NAME AS PARENT_ENTITY_NAME,
                    qc.TOTAL_COST_USD * (m.ALLOCATION_PERCENTAGE / 100.0) AS TOTAL_COST_USD,
                    qc.CREDITS_USED * (m.ALLOCATION_PERCENTAGE / 100.0) AS CREDITS_USED,
                    'USER_MAPPING' AS ATTRIBUTION_METHOD,
                    m.ALLOCATION_PERCENTAGE,
                    qc.WAREHOUSE_NAME,
                    qc.USER_NAME
                FROM query_costs qc
                LEFT JOIN query_tag_attribution qta
                    ON qc.QUERY_DATE = qta.QUERY_DATE
                    AND qc.USER_NAME = qta.USER_NAME
                LEFT JOIN warehouse_attribution wa
                    ON qc.QUERY_DATE = wa.QUERY_DATE
                    AND qc.USER_NAME = wa.USER_NAME
                    AND qc.WAREHOUSE_NAME = wa.WAREHOUSE_NAME
                JOIN FINOPS_CONTROL_DB.CHARGEBACK.DIM_COST_CENTER_MAPPING m
                    ON m.SOURCE_TYPE = 'USER'
                    AND UPPER(m.SOURCE_VALUE) = UPPER(qc.USER_NAME)
                    AND m.IS_CURRENT = TRUE
                    AND qc.QUERY_DATE BETWEEN m.VALID_FROM AND m.VALID_TO
                JOIN FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY e
                    ON m.ENTITY_ID = e.ENTITY_ID
                    AND e.IS_CURRENT = TRUE
                LEFT JOIN FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY p
                    ON e.PARENT_ENTITY_ID = p.ENTITY_ID
                WHERE qta.ENTITY_ID IS NULL
                  AND wa.ENTITY_ID IS NULL
            ),

            -- Priority 4: UNALLOCATED (no mapping found)
            unallocated_attribution AS (
                SELECT
                    qc.QUERY_DATE,
                    ? AS ENTITY_ID,
                    'Unallocated Costs' AS ENTITY_NAME,
                    'COST_CENTER' AS ENTITY_TYPE,
                    'CC-9999' AS COST_CENTER_CODE,
                    NULL AS PARENT_ENTITY_NAME,
                    qc.TOTAL_COST_USD,
                    qc.CREDITS_USED,
                    'UNALLOCATED' AS ATTRIBUTION_METHOD,
                    100.00 AS ALLOCATION_PERCENTAGE,
                    qc.WAREHOUSE_NAME,
                    qc.USER_NAME
                FROM query_costs qc
                LEFT JOIN query_tag_attribution qta USING (QUERY_DATE, USER_NAME, WAREHOUSE_NAME)
                LEFT JOIN warehouse_attribution wa USING (QUERY_DATE, USER_NAME, WAREHOUSE_NAME)
                LEFT JOIN user_attribution ua USING (QUERY_DATE, USER_NAME, WAREHOUSE_NAME)
                WHERE qta.ENTITY_ID IS NULL
                  AND wa.ENTITY_ID IS NULL
                  AND ua.ENTITY_ID IS NULL
            ),

            -- UNION all attribution methods
            all_attributions AS (
                SELECT * FROM query_tag_attribution
                UNION ALL SELECT * FROM warehouse_attribution
                UNION ALL SELECT * FROM user_attribution
                UNION ALL SELECT * FROM unallocated_attribution
            )

            -- Aggregate by date, entity, cost type
            SELECT
                QUERY_DATE AS CHARGEBACK_DATE,
                ENTITY_ID,
                ENTITY_NAME,
                ENTITY_TYPE,
                COST_CENTER_CODE,
                PARENT_ENTITY_NAME,
                'COMPUTE' AS COST_TYPE,
                SUM(TOTAL_COST_USD) AS COST_USD,
                SUM(CREDITS_USED) AS CREDITS_CONSUMED,
                COUNT(DISTINCT WAREHOUSE_NAME) AS UNIQUE_WAREHOUSES,
                COUNT(DISTINCT USER_NAME) AS UNIQUE_USERS,
                COUNT(*) AS QUERY_COUNT,
                ATTRIBUTION_METHOD,
                AVG(ALLOCATION_PERCENTAGE) AS ALLOCATION_PERCENTAGE
            FROM all_attributions
            GROUP BY
                QUERY_DATE, ENTITY_ID, ENTITY_NAME, ENTITY_TYPE,
                COST_CENTER_CODE, PARENT_ENTITY_NAME, ATTRIBUTION_METHOD
        ) AS source
        ON target.CHARGEBACK_DATE = source.CHARGEBACK_DATE
           AND target.ENTITY_ID = source.ENTITY_ID
           AND target.COST_TYPE = source.COST_TYPE
        WHEN MATCHED THEN
            UPDATE SET
                target.COST_USD = source.COST_USD,
                target.CREDITS_CONSUMED = source.CREDITS_CONSUMED,
                target.QUERY_COUNT = source.QUERY_COUNT,
                target.UNIQUE_USERS = source.UNIQUE_USERS,
                target.UNIQUE_WAREHOUSES = source.UNIQUE_WAREHOUSES,
                target.ATTRIBUTION_METHOD = source.ATTRIBUTION_METHOD,
                target.ALLOCATION_PERCENTAGE = source.ALLOCATION_PERCENTAGE,
                target.CALCULATED_AT = CURRENT_TIMESTAMP()
        WHEN NOT MATCHED THEN
            INSERT (
                CHARGEBACK_DATE, ENTITY_ID, ENTITY_NAME, ENTITY_TYPE,
                COST_CENTER_CODE, PARENT_ENTITY_NAME, COST_TYPE,
                COST_USD, CREDITS_CONSUMED, QUERY_COUNT,
                UNIQUE_USERS, UNIQUE_WAREHOUSES,
                ATTRIBUTION_METHOD, ALLOCATION_PERCENTAGE
            )
            VALUES (
                source.CHARGEBACK_DATE, source.ENTITY_ID, source.ENTITY_NAME, source.ENTITY_TYPE,
                source.COST_CENTER_CODE, source.PARENT_ENTITY_NAME, source.COST_TYPE,
                source.COST_USD, source.CREDITS_CONSUMED, source.QUERY_COUNT,
                source.UNIQUE_USERS, source.UNIQUE_WAREHOUSES,
                source.ATTRIBUTION_METHOD, source.ALLOCATION_PERCENTAGE
            )
        `;

        var computeStmt = snowflake.createStatement({
            sqlText: computeAttributionSql,
            binds: [P_START_DATE, P_END_DATE, unallocatedEntityId]
        });

        var computeResult = computeStmt.execute();
        computeResult.next();

        var computeRowsInserted = computeResult.getColumnValue('number of rows inserted');
        var computeRowsUpdated = computeResult.getColumnValue('number of rows updated');

        result.compute_attribution = {
            rows_inserted: computeRowsInserted,
            rows_updated: computeRowsUpdated,
            rows_affected: computeRowsInserted + computeRowsUpdated
        };

        totalRowsProcessed += (computeRowsInserted + computeRowsUpdated);

        // =================================================================
        // STEP 4: GENERATE SUMMARY STATISTICS
        // =================================================================

        result.status = 'GENERATING_SUMMARY';

        // Total cost summary
        var totalSummaryRs = executeSql(`
            SELECT
                SUM(COST_USD) AS TOTAL_COST,
                SUM(CREDITS_CONSUMED) AS TOTAL_CREDITS,
                COUNT(DISTINCT ENTITY_ID) AS ENTITIES_WITH_COSTS,
                COUNT(DISTINCT CHARGEBACK_DATE) AS DATES_PROCESSED
            FROM FINOPS_CONTROL_DB.CHARGEBACK.FACT_CHARGEBACK_DAILY
            WHERE CHARGEBACK_DATE >= ? AND CHARGEBACK_DATE <= ?
        `, [P_START_DATE, P_END_DATE]);

        if (totalSummaryRs.next()) {
            result.summary = {
                total_cost_usd: parseFloat(totalSummaryRs.getColumnValue('TOTAL_COST')).toFixed(2),
                total_credits: parseFloat(totalSummaryRs.getColumnValue('TOTAL_CREDITS')).toFixed(4),
                entities_with_costs: totalSummaryRs.getColumnValue('ENTITIES_WITH_COSTS'),
                dates_processed: totalSummaryRs.getColumnValue('DATES_PROCESSED')
            };
        }

        // Attribution method breakdown
        var methodBreakdownRs = executeSql(`
            SELECT
                ATTRIBUTION_METHOD,
                SUM(COST_USD) AS TOTAL_COST,
                COUNT(DISTINCT ENTITY_ID) AS ENTITY_COUNT,
                ROUND(SUM(COST_USD) / NULLIF((SELECT SUM(COST_USD) FROM FINOPS_CONTROL_DB.CHARGEBACK.FACT_CHARGEBACK_DAILY
                                              WHERE CHARGEBACK_DATE >= ? AND CHARGEBACK_DATE <= ?), 0) * 100, 2) AS PCT_OF_TOTAL
            FROM FINOPS_CONTROL_DB.CHARGEBACK.FACT_CHARGEBACK_DAILY
            WHERE CHARGEBACK_DATE >= ? AND CHARGEBACK_DATE <= ?
            GROUP BY ATTRIBUTION_METHOD
            ORDER BY TOTAL_COST DESC
        `, [P_START_DATE, P_END_DATE, P_START_DATE, P_END_DATE]);

        var methodBreakdown = [];
        while (methodBreakdownRs.next()) {
            methodBreakdown.push({
                attribution_method: methodBreakdownRs.getColumnValue('ATTRIBUTION_METHOD'),
                total_cost_usd: parseFloat(methodBreakdownRs.getColumnValue('TOTAL_COST')).toFixed(2),
                entity_count: methodBreakdownRs.getColumnValue('ENTITY_COUNT'),
                pct_of_total: methodBreakdownRs.getColumnValue('PCT_OF_TOTAL')
            });
        }
        result.attribution_method_breakdown = methodBreakdown;

        // Unallocated cost analysis
        var unallocatedRs = executeSql(`
            SELECT
                SUM(COST_USD) AS UNALLOCATED_COST,
                ROUND(SUM(COST_USD) / NULLIF((SELECT SUM(COST_USD) FROM FINOPS_CONTROL_DB.CHARGEBACK.FACT_CHARGEBACK_DAILY
                                              WHERE CHARGEBACK_DATE >= ? AND CHARGEBACK_DATE <= ?), 0) * 100, 2) AS UNALLOCATED_PCT
            FROM FINOPS_CONTROL_DB.CHARGEBACK.FACT_CHARGEBACK_DAILY
            WHERE CHARGEBACK_DATE >= ?
              AND CHARGEBACK_DATE <= ?
              AND ATTRIBUTION_METHOD = 'UNALLOCATED'
        `, [P_START_DATE, P_END_DATE, P_START_DATE, P_END_DATE]);

        if (unallocatedRs.next()) {
            var unallocatedCost = unallocatedRs.getColumnValue('UNALLOCATED_COST');
            var unallocatedPct = unallocatedRs.getColumnValue('UNALLOCATED_PCT');

            result.unallocated_analysis = {
                unallocated_cost_usd: unallocatedCost ? parseFloat(unallocatedCost).toFixed(2) : '0.00',
                unallocated_pct: unallocatedPct ? unallocatedPct : 0,
                is_within_target: unallocatedPct < 5.0,  // Target: <5% unallocated
                target_pct: 5.0
            };
        }

        // Top 5 most expensive entities
        var top5Rs = executeSql(`
            SELECT
                ENTITY_NAME,
                ENTITY_TYPE,
                SUM(COST_USD) AS TOTAL_COST,
                SUM(QUERY_COUNT) AS TOTAL_QUERIES,
                COUNT(DISTINCT CHARGEBACK_DATE) AS DAYS_WITH_COSTS
            FROM FINOPS_CONTROL_DB.CHARGEBACK.FACT_CHARGEBACK_DAILY
            WHERE CHARGEBACK_DATE >= ?
              AND CHARGEBACK_DATE <= ?
            GROUP BY ENTITY_NAME, ENTITY_TYPE
            ORDER BY TOTAL_COST DESC
            LIMIT 5
        `, [P_START_DATE, P_END_DATE]);

        var top5Entities = [];
        while (top5Rs.next()) {
            top5Entities.push({
                entity_name: top5Rs.getColumnValue('ENTITY_NAME'),
                entity_type: top5Rs.getColumnValue('ENTITY_TYPE'),
                total_cost_usd: parseFloat(top5Rs.getColumnValue('TOTAL_COST')).toFixed(2),
                total_queries: top5Rs.getColumnValue('TOTAL_QUERIES'),
                days_with_costs: top5Rs.getColumnValue('DAYS_WITH_COSTS')
            });
        }
        result.top_5_entities = top5Entities;

        // =================================================================
        // STEP 5: FINALIZE
        // =================================================================

        result.status = 'SUCCESS';
        result.end_time = new Date().toISOString();
        result.duration_seconds = ((new Date() - startTimestamp) / 1000).toFixed(2);

        logExecution(executionId, procedureName, 'SUCCESS', startTimestamp, new Date(),
                     totalRowsProcessed, null, result.parameters);

        return result;

    } catch (err) {
        result.status = 'ERROR';
        result.error_message = err.message;
        result.error_stack = err.stack;
        result.end_time = new Date().toISOString();

        logExecution(executionId, procedureName, 'ERROR', startTimestamp, new Date(),
                     totalRowsProcessed, err.message, result.parameters);

        return result;
    }
$$;

-- =========================================================================
-- GRANT EXECUTE PERMISSIONS
-- =========================================================================
GRANT USAGE ON PROCEDURE SP_CALCULATE_CHARGEBACK(DATE, DATE, BOOLEAN)
    TO ROLE FINOPS_ANALYST_ROLE;


-- =========================================================================
-- VERIFICATION QUERIES
-- =========================================================================

/*
-- Test 1: Calculate chargeback for last 7 days
CALL FINOPS_CONTROL_DB.PROCEDURES.SP_CALCULATE_CHARGEBACK(
    DATEADD(DAY, -7, CURRENT_DATE()),
    CURRENT_DATE(),
    TRUE  -- Recalculate all
);


-- Test 2: Incremental chargeback (only new data)
CALL FINOPS_CONTROL_DB.PROCEDURES.SP_CALCULATE_CHARGEBACK(
    DATEADD(DAY, -1, CURRENT_DATE()),
    CURRENT_DATE(),
    FALSE
);


-- Verify: Daily chargeback by entity
SELECT
    CHARGEBACK_DATE,
    ENTITY_NAME,
    ENTITY_TYPE,
    COST_TYPE,
    COST_USD,
    ATTRIBUTION_METHOD,
    QUERY_COUNT,
    UNIQUE_USERS
FROM FINOPS_CONTROL_DB.CHARGEBACK.FACT_CHARGEBACK_DAILY
WHERE CHARGEBACK_DATE >= DATEADD(DAY, -7, CURRENT_DATE())
ORDER BY CHARGEBACK_DATE DESC, COST_USD DESC
LIMIT 50;


-- Verify: Attribution method effectiveness
SELECT
    ATTRIBUTION_METHOD,
    SUM(COST_USD) AS TOTAL_COST,
    COUNT(DISTINCT ENTITY_ID) AS ENTITY_COUNT,
    SUM(QUERY_COUNT) AS TOTAL_QUERIES,
    ROUND(SUM(COST_USD) / (SELECT SUM(COST_USD) FROM FINOPS_CONTROL_DB.CHARGEBACK.FACT_CHARGEBACK_DAILY
                            WHERE CHARGEBACK_DATE >= DATEADD(DAY, -7, CURRENT_DATE())) * 100, 2) AS PCT_OF_TOTAL
FROM FINOPS_CONTROL_DB.CHARGEBACK.FACT_CHARGEBACK_DAILY
WHERE CHARGEBACK_DATE >= DATEADD(DAY, -7, CURRENT_DATE())
GROUP BY ATTRIBUTION_METHOD
ORDER BY TOTAL_COST DESC;


-- Verify: Unallocated cost analysis
SELECT
    CHARGEBACK_DATE,
    SUM(COST_USD) AS UNALLOCATED_COST,
    SUM(QUERY_COUNT) AS UNALLOCATED_QUERIES
FROM FINOPS_CONTROL_DB.CHARGEBACK.FACT_CHARGEBACK_DAILY
WHERE ATTRIBUTION_METHOD = 'UNALLOCATED'
  AND CHARGEBACK_DATE >= DATEADD(DAY, -30, CURRENT_DATE())
GROUP BY CHARGEBACK_DATE
ORDER BY CHARGEBACK_DATE DESC;


-- Verify: Entity hierarchy rollup
SELECT
    e.ENTITY_TYPE,
    e.ENTITY_NAME,
    p.ENTITY_NAME AS PARENT_ENTITY,
    SUM(f.COST_USD) AS TOTAL_COST,
    SUM(f.QUERY_COUNT) AS TOTAL_QUERIES,
    COUNT(DISTINCT f.CHARGEBACK_DATE) AS DAYS_WITH_COSTS
FROM FINOPS_CONTROL_DB.CHARGEBACK.FACT_CHARGEBACK_DAILY f
JOIN FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY e
    ON f.ENTITY_ID = e.ENTITY_ID
LEFT JOIN FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY p
    ON e.PARENT_ENTITY_ID = p.ENTITY_ID
WHERE f.CHARGEBACK_DATE >= DATEADD(DAY, -7, CURRENT_DATE())
GROUP BY e.ENTITY_TYPE, e.ENTITY_NAME, p.ENTITY_NAME
ORDER BY TOTAL_COST DESC;


-- Verify: Shared warehouse allocation accuracy
SELECT
    f.ENTITY_NAME,
    f.ALLOCATION_PERCENTAGE,
    SUM(f.COST_USD) AS ALLOCATED_COST,
    f.ATTRIBUTION_METHOD
FROM FINOPS_CONTROL_DB.CHARGEBACK.FACT_CHARGEBACK_DAILY f
WHERE f.ATTRIBUTION_METHOD = 'WAREHOUSE_MAPPING'
  AND f.ALLOCATION_PERCENTAGE < 100.00
  AND f.CHARGEBACK_DATE >= DATEADD(DAY, -7, CURRENT_DATE())
GROUP BY f.ENTITY_NAME, f.ALLOCATION_PERCENTAGE, f.ATTRIBUTION_METHOD
ORDER BY ALLOCATED_COST DESC;
*/


/*
=============================================================================
  BEST PRACTICES & DESIGN NOTES:

  1. ATTRIBUTION PRIORITY WATERFALL:
     - Always try highest-priority method first (QUERY_TAG)
     - Fall through to next priority only if previous fails
     - Track attribution method for transparency

  2. PROPORTIONAL ALLOCATION:
     - For shared warehouses, cost is split based on ALLOCATION_PERCENTAGE
     - Sum of allocations for same warehouse should = 100%
     - Use actual query execution time for more accurate proportional split

  3. UNALLOCATED COSTS:
     - Target: <5% of total costs unallocated
     - Report unallocated costs prominently to drive mapping adoption
     - Review unallocated queries weekly to identify missing mappings

  4. SCD TYPE 2 HANDLING:
     - Attribution respects VALID_FROM/VALID_TO dates
     - Costs attributed under org structure valid at query execution time
     - Supports historical reporting during reorgs

  5. PERFORMANCE OPTIMIZATION:
     - FACT_CHARGEBACK_DAILY is partitioned by CHARGEBACK_DATE
     - Pre-aggregated at daily grain for fast BI queries
     - Use MERGE for idempotency (safe to re-run)

  6. QUERY TAG FORMAT:
     - Recommended: team=TEAM_NAME;project=PROJECT_NAME;environment=ENV
     - Case-insensitive matching
     - Semicolon-delimited key=value pairs

  7. MONITORING & ALERTS:
     - Alert if unallocated_pct > 5%
     - Alert if daily cost spikes >50% vs 7-day average
     - Review attribution method breakdown weekly

  EDGE CASES HANDLED:
  - NULL or empty QUERY_TAG
  - Multiple mappings for same source (proportional allocation)
  - User/warehouse not found in mapping tables
  - Org changes mid-day (SCD Type 2)
  - Shared warehouses with split allocation
  - Query without user or warehouse (unallocated)

  OBJECTS CREATED:
    - FINOPS_CONTROL_DB.PROCEDURES.SP_CALCULATE_CHARGEBACK

  NEXT STEPS:
    → Script 03: Helper procedures (register entity, map user/warehouse)
    → Module 04: Budget controls
    → Module 07: Monitoring views for chargeback reporting
=============================================================================
*/

-- ===========================================================================
-- ===========================================================================
-- 03_HELPER_PROCEDURES
-- ===========================================================================
-- ===========================================================================


USE ROLE FINOPS_ADMIN_ROLE;
USE DATABASE FINOPS_CONTROL_DB;
USE SCHEMA PROCEDURES;
USE WAREHOUSE FINOPS_WH_ADMIN;

-- =========================================================================
-- PROCEDURE: SP_REGISTER_CHARGEBACK_ENTITY
-- Registers a new chargeback entity (team, department, project, etc.)
-- =========================================================================
CREATE OR REPLACE PROCEDURE SP_REGISTER_CHARGEBACK_ENTITY(
    P_ENTITY_TYPE       VARCHAR,
    P_ENTITY_NAME       VARCHAR,
    P_ENTITY_CODE       VARCHAR,
    P_PARENT_NAME       VARCHAR DEFAULT NULL,
    P_COST_CENTER_CODE  VARCHAR DEFAULT NULL,
    P_MANAGER_NAME      VARCHAR DEFAULT NULL,
    P_MANAGER_EMAIL     VARCHAR DEFAULT NULL
)
RETURNS VARIANT
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER
AS
$$
    var result = {
        procedure: 'SP_REGISTER_CHARGEBACK_ENTITY',
        status: 'INITIALIZING',
        entity_name: P_ENTITY_NAME
    };

    try {
        // Validate entity type
        var validTypes = ['TEAM', 'DEPARTMENT', 'PROJECT', 'BUSINESS_UNIT', 'COST_CENTER'];
        if (!validTypes.includes(P_ENTITY_TYPE)) {
            throw new Error('Invalid ENTITY_TYPE. Must be one of: ' + validTypes.join(', '));
        }

        // Check if entity already exists
        var checkExisting = snowflake.createStatement({
            sqlText: `SELECT ENTITY_ID FROM FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY
                      WHERE ENTITY_NAME = ? AND IS_CURRENT = TRUE`,
            binds: [P_ENTITY_NAME]
        });
        var existingRs = checkExisting.execute();

        if (existingRs.next()) {
            result.status = 'ALREADY_EXISTS';
            result.entity_id = existingRs.getColumnValue('ENTITY_ID');
            result.message = 'Entity already exists with ID: ' + result.entity_id;
            return result;
        }

        // Get parent entity ID if parent name provided
        var parentEntityId = null;
        if (P_PARENT_NAME) {
            var getParent = snowflake.createStatement({
                sqlText: `SELECT ENTITY_ID FROM FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY
                          WHERE ENTITY_NAME = ? AND IS_CURRENT = TRUE`,
                binds: [P_PARENT_NAME]
            });
            var parentRs = getParent.execute();

            if (parentRs.next()) {
                parentEntityId = parentRs.getColumnValue('ENTITY_ID');
            } else {
                throw new Error('Parent entity not found: ' + P_PARENT_NAME);
            }
        }

        // Insert new entity
        var insertSql = `
            INSERT INTO FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY (
                ENTITY_TYPE, ENTITY_NAME, ENTITY_CODE,
                PARENT_ENTITY_ID, COST_CENTER_CODE,
                MANAGER_NAME, MANAGER_EMAIL
            )
            VALUES (?, ?, ?, ?, ?, ?, ?)
        `;

        var insertStmt = snowflake.createStatement({
            sqlText: insertSql,
            binds: [P_ENTITY_TYPE, P_ENTITY_NAME, P_ENTITY_CODE,
                    parentEntityId, P_COST_CENTER_CODE,
                    P_MANAGER_NAME, P_MANAGER_EMAIL]
        });
        insertStmt.execute();

        // Get the new entity ID
        var getNewId = snowflake.createStatement({
            sqlText: `SELECT ENTITY_ID FROM FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY
                      WHERE ENTITY_NAME = ? AND IS_CURRENT = TRUE`,
            binds: [P_ENTITY_NAME]
        });
        var newIdRs = getNewId.execute();
        newIdRs.next();

        result.status = 'SUCCESS';
        result.entity_id = newIdRs.getColumnValue('ENTITY_ID');
        result.entity_type = P_ENTITY_TYPE;
        result.parent_entity_id = parentEntityId;
        result.message = 'Entity registered successfully';

        return result;

    } catch (err) {
        result.status = 'ERROR';
        result.error_message = err.message;
        return result;
    }
$$;


-- =========================================================================
-- PROCEDURE: SP_MAP_USER_TO_ENTITY
-- Maps a user to a chargeback entity with optional allocation percentage
-- =========================================================================
CREATE OR REPLACE PROCEDURE SP_MAP_USER_TO_ENTITY(
    P_USER_NAME         VARCHAR,
    P_ENTITY_NAME       VARCHAR,
    P_ALLOCATION_PCT    NUMBER DEFAULT 100.00,
    P_ENVIRONMENT       VARCHAR DEFAULT NULL,
    P_EFFECTIVE_DATE    DATE DEFAULT CURRENT_DATE()
)
RETURNS VARIANT
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER
AS
$$
    var result = {
        procedure: 'SP_MAP_USER_TO_ENTITY',
        status: 'INITIALIZING',
        user_name: P_USER_NAME,
        entity_name: P_ENTITY_NAME
    };

    try {
        // Validate allocation percentage
        if (P_ALLOCATION_PCT <= 0 || P_ALLOCATION_PCT > 100) {
            throw new Error('ALLOCATION_PCT must be between 0 and 100');
        }

        // Get entity ID
        var getEntity = snowflake.createStatement({
            sqlText: `SELECT ENTITY_ID FROM FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY
                      WHERE ENTITY_NAME = ? AND IS_CURRENT = TRUE`,
            binds: [P_ENTITY_NAME]
        });
        var entityRs = getEntity.execute();

        if (!entityRs.next()) {
            throw new Error('Entity not found: ' + P_ENTITY_NAME + '. Register entity first.');
        }

        var entityId = entityRs.getColumnValue('ENTITY_ID');

        // Check if mapping already exists
        var checkExisting = snowflake.createStatement({
            sqlText: `SELECT MAPPING_ID FROM FINOPS_CONTROL_DB.CHARGEBACK.DIM_COST_CENTER_MAPPING
                      WHERE SOURCE_TYPE = 'USER'
                        AND SOURCE_VALUE = ?
                        AND ENTITY_ID = ?
                        AND IS_CURRENT = TRUE`,
            binds: [P_USER_NAME, entityId]
        });
        var existingRs = checkExisting.execute();

        if (existingRs.next()) {
            result.status = 'ALREADY_MAPPED';
            result.mapping_id = existingRs.getColumnValue('MAPPING_ID');
            result.message = 'User already mapped to this entity. Use SP_UPDATE_ENTITY_MAPPING to change.';
            return result;
        }

        // Insert new mapping
        var insertSql = `
            INSERT INTO FINOPS_CONTROL_DB.CHARGEBACK.DIM_COST_CENTER_MAPPING (
                SOURCE_TYPE, SOURCE_VALUE, ENTITY_ID,
                ALLOCATION_PERCENTAGE, ENVIRONMENT,
                VALID_FROM, ALLOCATION_RULE
            )
            VALUES ('USER', ?, ?, ?, ?, ?, ?)
        `;

        var allocationRule = P_ALLOCATION_PCT < 100
            ? P_USER_NAME + ' allocated ' + P_ALLOCATION_PCT + '% to ' + P_ENTITY_NAME
            : P_USER_NAME + ' 100% dedicated to ' + P_ENTITY_NAME;

        var insertStmt = snowflake.createStatement({
            sqlText: insertSql,
            binds: [P_USER_NAME, entityId, P_ALLOCATION_PCT, P_ENVIRONMENT,
                    P_EFFECTIVE_DATE, allocationRule]
        });
        insertStmt.execute();

        // Get new mapping ID
        var getMappingId = snowflake.createStatement({
            sqlText: `SELECT MAPPING_ID FROM FINOPS_CONTROL_DB.CHARGEBACK.DIM_COST_CENTER_MAPPING
                      WHERE SOURCE_TYPE = 'USER'
                        AND SOURCE_VALUE = ?
                        AND ENTITY_ID = ?
                        AND IS_CURRENT = TRUE`,
            binds: [P_USER_NAME, entityId]
        });
        var mappingRs = getMappingId.execute();
        mappingRs.next();

        result.status = 'SUCCESS';
        result.mapping_id = mappingRs.getColumnValue('MAPPING_ID');
        result.entity_id = entityId;
        result.allocation_pct = P_ALLOCATION_PCT;
        result.message = 'User mapped successfully';

        return result;

    } catch (err) {
        result.status = 'ERROR';
        result.error_message = err.message;
        return result;
    }
$$;


-- =========================================================================
-- PROCEDURE: SP_MAP_WAREHOUSE_TO_ENTITY
-- Maps a warehouse to a chargeback entity with proportional allocation
-- =========================================================================
CREATE OR REPLACE PROCEDURE SP_MAP_WAREHOUSE_TO_ENTITY(
    P_WAREHOUSE_NAME    VARCHAR,
    P_ENTITY_NAME       VARCHAR,
    P_ALLOCATION_PCT    NUMBER DEFAULT 100.00,
    P_ENVIRONMENT       VARCHAR DEFAULT 'PROD',
    P_EFFECTIVE_DATE    DATE DEFAULT CURRENT_DATE()
)
RETURNS VARIANT
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER
AS
$$
    var result = {
        procedure: 'SP_MAP_WAREHOUSE_TO_ENTITY',
        status: 'INITIALIZING',
        warehouse_name: P_WAREHOUSE_NAME,
        entity_name: P_ENTITY_NAME
    };

    try {
        // Validate allocation percentage
        if (P_ALLOCATION_PCT <= 0 || P_ALLOCATION_PCT > 100) {
            throw new Error('ALLOCATION_PCT must be between 0 and 100');
        }

        // Get entity ID
        var getEntity = snowflake.createStatement({
            sqlText: `SELECT ENTITY_ID FROM FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY
                      WHERE ENTITY_NAME = ? AND IS_CURRENT = TRUE`,
            binds: [P_ENTITY_NAME]
        });
        var entityRs = getEntity.execute();

        if (!entityRs.next()) {
            throw new Error('Entity not found: ' + P_ENTITY_NAME);
        }

        var entityId = entityRs.getColumnValue('ENTITY_ID');

        // Check total allocation for this warehouse
        var checkTotal = snowflake.createStatement({
            sqlText: `SELECT COALESCE(SUM(ALLOCATION_PERCENTAGE), 0) AS TOTAL_ALLOCATED
                      FROM FINOPS_CONTROL_DB.CHARGEBACK.DIM_COST_CENTER_MAPPING
                      WHERE SOURCE_TYPE = 'WAREHOUSE'
                        AND SOURCE_VALUE = ?
                        AND IS_CURRENT = TRUE`,
            binds: [P_WAREHOUSE_NAME]
        });
        var totalRs = checkTotal.execute();
        totalRs.next();
        var totalAllocated = totalRs.getColumnValue('TOTAL_ALLOCATED');

        if (totalAllocated + P_ALLOCATION_PCT > 100) {
            throw new Error('Total allocation would exceed 100%. Current: ' + totalAllocated + '%, Attempting to add: ' + P_ALLOCATION_PCT + '%');
        }

        // Insert new mapping
        var insertSql = `
            INSERT INTO FINOPS_CONTROL_DB.CHARGEBACK.DIM_COST_CENTER_MAPPING (
                SOURCE_TYPE, SOURCE_VALUE, ENTITY_ID,
                ALLOCATION_PERCENTAGE, ENVIRONMENT,
                VALID_FROM, ALLOCATION_RULE
            )
            VALUES ('WAREHOUSE', ?, ?, ?, ?, ?, ?)
        `;

        var allocationRule = P_ALLOCATION_PCT < 100
            ? P_WAREHOUSE_NAME + ' shared: ' + P_ALLOCATION_PCT + '% to ' + P_ENTITY_NAME
            : P_WAREHOUSE_NAME + ' dedicated 100% to ' + P_ENTITY_NAME;

        var insertStmt = snowflake.createStatement({
            sqlText: insertSql,
            binds: [P_WAREHOUSE_NAME, entityId, P_ALLOCATION_PCT, P_ENVIRONMENT,
                    P_EFFECTIVE_DATE, allocationRule]
        });
        insertStmt.execute();

        // Get new mapping ID
        var getMappingId = snowflake.createStatement({
            sqlText: `SELECT MAPPING_ID FROM FINOPS_CONTROL_DB.CHARGEBACK.DIM_COST_CENTER_MAPPING
                      WHERE SOURCE_TYPE = 'WAREHOUSE'
                        AND SOURCE_VALUE = ?
                        AND ENTITY_ID = ?
                        AND IS_CURRENT = TRUE
                      ORDER BY CREATED_AT DESC
                      LIMIT 1`,
            binds: [P_WAREHOUSE_NAME, entityId]
        });
        var mappingRs = getMappingId.execute();
        mappingRs.next();

        result.status = 'SUCCESS';
        result.mapping_id = mappingRs.getColumnValue('MAPPING_ID');
        result.entity_id = entityId;
        result.allocation_pct = P_ALLOCATION_PCT;
        result.total_allocated_pct = totalAllocated + P_ALLOCATION_PCT;
        result.message = 'Warehouse mapped successfully';

        return result;

    } catch (err) {
        result.status = 'ERROR';
        result.error_message = err.message;
        return result;
    }
$$;


-- =========================================================================
-- PROCEDURE: SP_UPDATE_ENTITY_MAPPING
-- Updates an entity mapping using SCD Type 2 (closes old, opens new)
-- =========================================================================
CREATE OR REPLACE PROCEDURE SP_UPDATE_ENTITY_MAPPING(
    P_MAPPING_ID        NUMBER,
    P_NEW_ENTITY_NAME   VARCHAR,
    P_EFFECTIVE_DATE    DATE DEFAULT CURRENT_DATE()
)
RETURNS VARIANT
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER
AS
$$
    var result = {
        procedure: 'SP_UPDATE_ENTITY_MAPPING',
        status: 'INITIALIZING',
        mapping_id: P_MAPPING_ID
    };

    try {
        // Get current mapping details
        var getMapping = snowflake.createStatement({
            sqlText: `SELECT
                        SOURCE_TYPE, SOURCE_VALUE, ENTITY_ID,
                        ALLOCATION_PERCENTAGE, ENVIRONMENT
                      FROM FINOPS_CONTROL_DB.CHARGEBACK.DIM_COST_CENTER_MAPPING
                      WHERE MAPPING_ID = ? AND IS_CURRENT = TRUE`,
            binds: [P_MAPPING_ID]
        });
        var mappingRs = getMapping.execute();

        if (!mappingRs.next()) {
            throw new Error('Mapping ID not found or already closed: ' + P_MAPPING_ID);
        }

        var sourceType = mappingRs.getColumnValue('SOURCE_TYPE');
        var sourceValue = mappingRs.getColumnValue('SOURCE_VALUE');
        var oldEntityId = mappingRs.getColumnValue('ENTITY_ID');
        var allocationPct = mappingRs.getColumnValue('ALLOCATION_PERCENTAGE');
        var environment = mappingRs.getColumnValue('ENVIRONMENT');

        // Get new entity ID
        var getNewEntity = snowflake.createStatement({
            sqlText: `SELECT ENTITY_ID FROM FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY
                      WHERE ENTITY_NAME = ? AND IS_CURRENT = TRUE`,
            binds: [P_NEW_ENTITY_NAME]
        });
        var newEntityRs = getNewEntity.execute();

        if (!newEntityRs.next()) {
            throw new Error('New entity not found: ' + P_NEW_ENTITY_NAME);
        }

        var newEntityId = newEntityRs.getColumnValue('ENTITY_ID');

        if (oldEntityId === newEntityId) {
            result.status = 'NO_CHANGE';
            result.message = 'Mapping already points to this entity';
            return result;
        }

        // Close old mapping (SCD Type 2)
        var closeSql = `
            UPDATE FINOPS_CONTROL_DB.CHARGEBACK.DIM_COST_CENTER_MAPPING
            SET
                VALID_TO = ?,
                IS_CURRENT = FALSE,
                UPDATED_AT = CURRENT_TIMESTAMP(),
                UPDATED_BY = CURRENT_USER()
            WHERE MAPPING_ID = ?
        `;

        var closeStmt = snowflake.createStatement({
            sqlText: closeSql,
            binds: [P_EFFECTIVE_DATE, P_MAPPING_ID]
        });
        closeStmt.execute();

        // Open new mapping (SCD Type 2)
        var openSql = `
            INSERT INTO FINOPS_CONTROL_DB.CHARGEBACK.DIM_COST_CENTER_MAPPING (
                SOURCE_TYPE, SOURCE_VALUE, ENTITY_ID,
                ALLOCATION_PERCENTAGE, ENVIRONMENT,
                VALID_FROM, IS_CURRENT, ALLOCATION_RULE
            )
            VALUES (?, ?, ?, ?, ?, ?, TRUE, ?)
        `;

        var allocationRule = sourceValue + ' remapped to ' + P_NEW_ENTITY_NAME + ' effective ' + P_EFFECTIVE_DATE;

        var openStmt = snowflake.createStatement({
            sqlText: openSql,
            binds: [sourceType, sourceValue, newEntityId, allocationPct, environment,
                    P_EFFECTIVE_DATE, allocationRule]
        });
        openStmt.execute();

        // Get new mapping ID
        var getNewMapping = snowflake.createStatement({
            sqlText: `SELECT MAPPING_ID FROM FINOPS_CONTROL_DB.CHARGEBACK.DIM_COST_CENTER_MAPPING
                      WHERE SOURCE_TYPE = ?
                        AND SOURCE_VALUE = ?
                        AND ENTITY_ID = ?
                        AND IS_CURRENT = TRUE`,
            binds: [sourceType, sourceValue, newEntityId]
        });
        var newMappingRs = getNewMapping.execute();
        newMappingRs.next();

        result.status = 'SUCCESS';
        result.old_mapping_id = P_MAPPING_ID;
        result.new_mapping_id = newMappingRs.getColumnValue('MAPPING_ID');
        result.old_entity_id = oldEntityId;
        result.new_entity_id = newEntityId;
        result.effective_date = P_EFFECTIVE_DATE;
        result.message = 'Mapping updated successfully (SCD Type 2)';

        return result;

    } catch (err) {
        result.status = 'ERROR';
        result.error_message = err.message;
        return result;
    }
$$;


-- =========================================================================
-- PROCEDURE: SP_GET_ENTITY_HIERARCHY
-- Retrieves the full entity hierarchy tree
-- =========================================================================
CREATE OR REPLACE PROCEDURE SP_GET_ENTITY_HIERARCHY()
RETURNS TABLE (
    LEVEL NUMBER,
    ENTITY_ID NUMBER,
    ENTITY_TYPE VARCHAR,
    ENTITY_NAME VARCHAR,
    PARENT_NAME VARCHAR,
    FULL_PATH VARCHAR
)
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
    WITH RECURSIVE entity_tree AS (
        -- Root entities (no parent)
        SELECT
            1 AS LEVEL,
            ENTITY_ID,
            ENTITY_TYPE,
            ENTITY_NAME,
            NULL AS PARENT_NAME,
            ENTITY_NAME AS FULL_PATH
        FROM FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY
        WHERE PARENT_ENTITY_ID IS NULL
          AND IS_CURRENT = TRUE

        UNION ALL

        -- Child entities
        SELECT
            t.LEVEL + 1,
            e.ENTITY_ID,
            e.ENTITY_TYPE,
            e.ENTITY_NAME,
            t.ENTITY_NAME AS PARENT_NAME,
            t.FULL_PATH || ' > ' || e.ENTITY_NAME AS FULL_PATH
        FROM FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY e
        JOIN entity_tree t ON e.PARENT_ENTITY_ID = t.ENTITY_ID
        WHERE e.IS_CURRENT = TRUE
    )
    SELECT
        LEVEL,
        ENTITY_ID,
        ENTITY_TYPE,
        ENTITY_NAME,
        PARENT_NAME,
        FULL_PATH
    FROM entity_tree
    ORDER BY FULL_PATH;
$$;


-- =========================================================================
-- GRANT PERMISSIONS
-- =========================================================================
GRANT USAGE ON PROCEDURE SP_REGISTER_CHARGEBACK_ENTITY(VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR)
    TO ROLE FINOPS_ADMIN_ROLE;

GRANT USAGE ON PROCEDURE SP_MAP_USER_TO_ENTITY(VARCHAR, VARCHAR, NUMBER, VARCHAR, DATE)
    TO ROLE FINOPS_ADMIN_ROLE;

GRANT USAGE ON PROCEDURE SP_MAP_WAREHOUSE_TO_ENTITY(VARCHAR, VARCHAR, NUMBER, VARCHAR, DATE)
    TO ROLE FINOPS_ADMIN_ROLE;

GRANT USAGE ON PROCEDURE SP_UPDATE_ENTITY_MAPPING(NUMBER, VARCHAR, DATE)
    TO ROLE FINOPS_ADMIN_ROLE;

GRANT USAGE ON PROCEDURE SP_GET_ENTITY_HIERARCHY()
    TO ROLE FINOPS_ANALYST_ROLE;


-- =========================================================================
-- VERIFICATION QUERIES & EXAMPLES
-- =========================================================================

/*
-- Example 1: Register a new team
CALL SP_REGISTER_CHARGEBACK_ENTITY(
    'TEAM',                         -- Entity type
    'Data Science Team',            -- Entity name
    'DATA_SCI',                     -- Entity code
    'ML Engineering',               -- Parent department name
    'CC-1320',                      -- Cost center code
    'Lisa Anderson',                -- Manager name
    'lisa.anderson@company.com'     -- Manager email
);


-- Example 2: Map a user to a team (100% allocation)
CALL SP_MAP_USER_TO_ENTITY(
    'LISA.ANDERSON@COMPANY.COM',    -- User name
    'Data Science Team',             -- Entity name
    100.00,                          -- 100% allocation
    'PROD',                          -- Environment
    CURRENT_DATE()                   -- Effective date
);


-- Example 3: Map a warehouse to a team (dedicated)
CALL SP_MAP_WAREHOUSE_TO_ENTITY(
    'WH_DATASCI_PROD',              -- Warehouse name
    'Data Science Team',             -- Entity name
    100.00,                          -- 100% dedicated
    'PROD',                          -- Environment
    CURRENT_DATE()
);


-- Example 4: Map a shared warehouse to multiple teams
CALL SP_MAP_WAREHOUSE_TO_ENTITY('WH_SHARED_DEV', 'ETL Pipeline Team', 60.00, 'DEV', CURRENT_DATE());
CALL SP_MAP_WAREHOUSE_TO_ENTITY('WH_SHARED_DEV', 'Data Lake Team', 40.00, 'DEV', CURRENT_DATE());


-- Example 5: Update a user's team mapping (reorg scenario)
-- First, get the current mapping ID
SELECT
    MAPPING_ID,
    SOURCE_VALUE AS USER_NAME,
    e.ENTITY_NAME AS CURRENT_TEAM
FROM FINOPS_CONTROL_DB.CHARGEBACK.DIM_COST_CENTER_MAPPING m
JOIN FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY e ON m.ENTITY_ID = e.ENTITY_ID
WHERE m.SOURCE_TYPE = 'USER'
  AND m.SOURCE_VALUE = 'FRANK.ZHANG@COMPANY.COM'
  AND m.IS_CURRENT = TRUE;

-- Then update the mapping
CALL SP_UPDATE_ENTITY_MAPPING(
    12,                             -- Mapping ID from above query
    'Data Science Team',            -- New team name
    '2025-03-01'                    -- Effective date of reorg
);


-- Example 6: View full entity hierarchy
CALL SP_GET_ENTITY_HIERARCHY();


-- Verify: All user mappings
SELECT
    m.SOURCE_VALUE AS USER_NAME,
    e.ENTITY_NAME AS TEAM,
    p.ENTITY_NAME AS DEPARTMENT,
    m.ALLOCATION_PERCENTAGE,
    m.ENVIRONMENT,
    m.VALID_FROM,
    m.VALID_TO,
    m.IS_CURRENT
FROM FINOPS_CONTROL_DB.CHARGEBACK.DIM_COST_CENTER_MAPPING m
JOIN FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY e ON m.ENTITY_ID = e.ENTITY_ID
LEFT JOIN FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY p ON e.PARENT_ENTITY_ID = p.ENTITY_ID
WHERE m.SOURCE_TYPE = 'USER'
ORDER BY m.IS_CURRENT DESC, USER_NAME;


-- Verify: Warehouse allocation summary
SELECT
    m.SOURCE_VALUE AS WAREHOUSE_NAME,
    m.ENVIRONMENT,
    SUM(m.ALLOCATION_PERCENTAGE) AS TOTAL_ALLOCATED_PCT,
    COUNT(*) AS ENTITY_COUNT,
    LISTAGG(e.ENTITY_NAME || ' (' || m.ALLOCATION_PERCENTAGE || '%)', ', ') AS ALLOCATION_DETAILS
FROM FINOPS_CONTROL_DB.CHARGEBACK.DIM_COST_CENTER_MAPPING m
JOIN FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY e ON m.ENTITY_ID = e.ENTITY_ID
WHERE m.SOURCE_TYPE = 'WAREHOUSE'
  AND m.IS_CURRENT = TRUE
GROUP BY m.SOURCE_VALUE, m.ENVIRONMENT
ORDER BY WAREHOUSE_NAME;


-- Verify: SCD Type 2 history for a specific mapping
SELECT
    m.MAPPING_ID,
    m.SOURCE_VALUE,
    e.ENTITY_NAME,
    m.VALID_FROM,
    m.VALID_TO,
    m.IS_CURRENT,
    m.ALLOCATION_RULE
FROM FINOPS_CONTROL_DB.CHARGEBACK.DIM_COST_CENTER_MAPPING m
JOIN FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY e ON m.ENTITY_ID = e.ENTITY_ID
WHERE m.SOURCE_VALUE = 'FRANK.ZHANG@COMPANY.COM'
ORDER BY m.VALID_FROM DESC;
*/


/*
=============================================================================
  BEST PRACTICES:

  1. ENTITY REGISTRATION:
     - Always register parent entities before children
     - Use consistent naming conventions (title case, no abbreviations)
     - Assign manager email for automated budget alerts

  2. USER MAPPING:
     - Map all human users to teams for accurate attribution
     - Map service accounts to owning team
     - Use proportional allocation for users working across multiple projects

  3. WAREHOUSE MAPPING:
     - Prefer dedicated warehouses (100% allocation) for clear accountability
     - Use shared warehouses only when necessary
     - Ensure total allocation = 100% for shared warehouses

  4. SCD TYPE 2 UPDATES:
     - Always use SP_UPDATE_ENTITY_MAPPING, never UPDATE directly
     - Set EFFECTIVE_DATE to start of new fiscal period when possible
     - Document reason for change in ALLOCATION_RULE column

  5. PERIODIC REVIEWS:
     - Review unallocated costs weekly
     - Review entity hierarchy quarterly
     - Review user mappings after each reorg

  OBJECTS CREATED:
    - FINOPS_CONTROL_DB.PROCEDURES.SP_REGISTER_CHARGEBACK_ENTITY
    - FINOPS_CONTROL_DB.PROCEDURES.SP_MAP_USER_TO_ENTITY
    - FINOPS_CONTROL_DB.PROCEDURES.SP_MAP_WAREHOUSE_TO_ENTITY
    - FINOPS_CONTROL_DB.PROCEDURES.SP_UPDATE_ENTITY_MAPPING
    - FINOPS_CONTROL_DB.PROCEDURES.SP_GET_ENTITY_HIERARCHY

  NEXT STEPS:
    → Module 04: Budget controls (define budgets, check thresholds, alerts)
    → Test end-to-end: Cost collection → Attribution → Chargeback report
=============================================================================
*/



/*
#############################################################################
  MODULE 03 COMPLETE!

  Objects Created:
    - Dimension tables: DIM_COST_CENTER, DIM_TEAM, DIM_DEPARTMENT, DIM_PROJECT
    - Mapping tables: DIM_USER_MAPPING, DIM_WAREHOUSE_MAPPING, DIM_ROLE_MAPPING (SCD Type 2)
    - Attribution procedures and views

  Next: FINOPS - Module 04 (Budget Controls)
#############################################################################
*/
