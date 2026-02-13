/*
=============================================================================
  MODULE 03 : CHARGEBACK ATTRIBUTION
  SCRIPT 01 : Dimension Tables for Cost Attribution
=============================================================================
  SNOWBRIX ACADEMY — Enterprise FinOps Dashboard for Snowflake

  LEARNING OBJECTIVES:
    1. Understand SCD Type 2 dimensions for cost attribution
    2. Create chargeback entity hierarchy (TEAM → DEPT → BU → COST_CENTER)
    3. Build cost center mapping tables for users, warehouses, and roles
    4. Implement multi-dimensional attribution model
    5. Handle organizational changes with effective dating

  THE ATTRIBUTION CHALLENGE:
  Snowflake costs are generated at the WAREHOUSE and QUERY level, but
  organizations need costs attributed to TEAMS, DEPARTMENTS, PROJECTS, and
  COST CENTERS for chargeback and budget control.

  ATTRIBUTION HIERARCHY:
  ┌──────────────────────────────────────────────────────────────┐
  │  Query → User → Role → Team → Department → Business Unit     │
  │     ↓                                                         │
  │  Warehouse → Project → Team → Department → Cost Center       │
  │                                                               │
  │  Priority:                                                    │
  │    1. QUERY_TAG (team=X;project=Y) - Highest                 │
  │    2. Warehouse Mapping (dedicated warehouse)                │
  │    3. User/Role Mapping (shared warehouse)                   │
  │    4. UNALLOCATED (no mapping found)                         │
  └──────────────────────────────────────────────────────────────┘

  SCD TYPE 2 PATTERN:
  ┌──────────────────────────────────────────────────────────────┐
  │  When a team reorganizes or warehouse ownership changes:     │
  │    1. Close old record: SET VALID_TO = CURRENT_DATE(),       │
  │                         IS_CURRENT = FALSE                   │
  │    2. Insert new record: VALID_FROM = CURRENT_DATE(),        │
  │                          VALID_TO = '9999-12-31'             │
  │                          IS_CURRENT = TRUE                   │
  │                                                               │
  │  Benefits:                                                    │
  │    - Full audit trail of org changes                         │
  │    - Can report costs under both old and new structures      │
  │    - Time-travel queries for historical attribution          │
  └──────────────────────────────────────────────────────────────┘

  PREREQUISITES:
    - Module 01 completed (databases, warehouses, roles)
    - Module 02 completed (cost collection tables and procedures)

  ESTIMATED TIME: 20 minutes

=============================================================================
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
