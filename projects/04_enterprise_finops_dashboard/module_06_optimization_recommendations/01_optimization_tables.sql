/*
=============================================================================
  MODULE 06 : OPTIMIZATION RECOMMENDATIONS
  SCRIPT 01 : Optimization Tables and Rules
=============================================================================
  SNOWBRIX ACADEMY — Enterprise FinOps Dashboard for Snowflake

  LEARNING OBJECTIVES:
    1. Design optimization recommendation framework
    2. Define optimization categories and rules
    3. Calculate potential savings estimates
    4. Track recommendation implementation

  OPTIMIZATION CATEGORIES:
  ┌──────────────────────────────────────────────────────────────┐
  │  1. IDLE_WAREHOUSE     → >50% idle time                      │
  │  2. AUTO_SUSPEND       → Suboptimal suspend timeout          │
  │  3. WAREHOUSE_SIZING   → Over/under-provisioned warehouses   │
  │  4. QUERY_OPTIMIZATION → Long-running, inefficient queries   │
  │  5. STORAGE_WASTE      → Unused tables, excessive time-travel│
  │  6. CLUSTERING         → Missing or expensive clustering     │
  └──────────────────────────────────────────────────────────────┘

  PREREQUISITES:
    - Cost collection and chargeback modules completed

  ESTIMATED TIME: 15 minutes

=============================================================================
*/

USE ROLE FINOPS_ADMIN_ROLE;
USE DATABASE FINOPS_CONTROL_DB;
USE SCHEMA OPTIMIZATION;
USE WAREHOUSE FINOPS_WH_ADMIN;

-- =========================================================================
-- DIMENSION: DIM_OPTIMIZATION_RULES
-- Pre-defined optimization detection rules
-- =========================================================================
CREATE TABLE IF NOT EXISTS DIM_OPTIMIZATION_RULES (
    RULE_ID                     NUMBER AUTOINCREMENT PRIMARY KEY,
    RULE_NAME                   VARCHAR(200) NOT NULL,
    CATEGORY                    VARCHAR(50) NOT NULL,
    DESCRIPTION                 VARCHAR(1000),

    -- Detection Logic
    DETECTION_SQL               VARCHAR(10000) COMMENT 'SQL query to detect issues',

    -- Recommendation Template
    RECOMMENDATION_TEMPLATE     VARCHAR(2000) COMMENT 'Template for recommendation text',

    -- Savings Calculation
    SAVINGS_FORMULA             VARCHAR(1000) COMMENT 'Formula to estimate savings',
    TYPICAL_SAVINGS_PCT         NUMBER(5, 2) COMMENT 'Typical % savings if implemented',

    -- Implementation Difficulty
    FEASIBILITY_SCORE           NUMBER(3, 1) COMMENT '1-10 scale, 10=easiest',
    EFFORT_ESTIMATE_HOURS       NUMBER COMMENT 'Estimated implementation effort',

    -- Status
    IS_ACTIVE                   BOOLEAN DEFAULT TRUE,
    PRIORITY                    NUMBER DEFAULT 100 COMMENT 'Lower = higher priority',
    CREATED_AT                  TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),

    CONSTRAINT chk_opt_category CHECK (
        CATEGORY IN ('IDLE_WAREHOUSE', 'AUTO_SUSPEND', 'WAREHOUSE_SIZING',
                     'QUERY_OPTIMIZATION', 'STORAGE_WASTE', 'CLUSTERING', 'MULTI_CLUSTER')
    ),
    CONSTRAINT chk_feasibility CHECK (FEASIBILITY_SCORE BETWEEN 1 AND 10)
)
COMMENT = 'Dimension: Optimization rules with detection logic and savings formulas';


-- =========================================================================
-- FACT TABLE: FACT_OPTIMIZATION_RECOMMENDATIONS
-- Active optimization recommendations with savings estimates
-- =========================================================================
CREATE TABLE IF NOT EXISTS FACT_OPTIMIZATION_RECOMMENDATIONS (
    RECOMMENDATION_ID           NUMBER AUTOINCREMENT PRIMARY KEY,
    RULE_ID                     NUMBER COMMENT 'FK to DIM_OPTIMIZATION_RULES',
    CATEGORY                    VARCHAR(50) NOT NULL,

    -- Target Object
    TARGET_OBJECT_TYPE          VARCHAR(50) COMMENT 'WAREHOUSE, QUERY, TABLE, DATABASE',
    TARGET_OBJECT_NAME          VARCHAR(500),
    ENTITY_ID                   NUMBER COMMENT 'FK to DIM_CHARGEBACK_ENTITY (owning team)',

    -- Issue Description
    ISSUE_DESCRIPTION           VARCHAR(2000),
    CURRENT_STATE               VARCHAR(1000) COMMENT 'Current configuration/behavior',
    RECOMMENDED_STATE           VARCHAR(1000) COMMENT 'Recommended configuration/behavior',

    -- Savings Estimate
    ESTIMATED_SAVINGS_USD_MONTHLY NUMBER(18, 2) COMMENT 'Estimated monthly savings',
    CONFIDENCE_LEVEL            VARCHAR(20) DEFAULT 'MEDIUM' COMMENT 'LOW, MEDIUM, HIGH',

    -- Prioritization
    PRIORITY_SCORE              NUMBER(10, 2) COMMENT 'savings × feasibility × confidence',
    FEASIBILITY_SCORE           NUMBER(3, 1),

    -- Implementation Status
    STATUS                      VARCHAR(20) DEFAULT 'NEW',
    CREATED_AT                  TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    IMPLEMENTED_AT              TIMESTAMP_NTZ,
    IMPLEMENTED_BY              VARCHAR(200),

    -- Validation
    ACTUAL_SAVINGS_USD_MONTHLY  NUMBER(18, 2) COMMENT 'Actual savings after implementation',
    VALIDATION_DATE             DATE,

    CONSTRAINT chk_rec_status CHECK (
        STATUS IN ('NEW', 'IN_PROGRESS', 'IMPLEMENTED', 'REJECTED', 'EXPIRED')
    ),
    CONSTRAINT chk_confidence CHECK (
        CONFIDENCE_LEVEL IN ('LOW', 'MEDIUM', 'HIGH')
    ),
    CONSTRAINT fk_rec_rule FOREIGN KEY (RULE_ID) REFERENCES DIM_OPTIMIZATION_RULES(RULE_ID)
)
COMMENT = 'Fact: Optimization recommendations with savings estimates and implementation tracking';

CREATE INDEX IF NOT EXISTS idx_rec_status ON FACT_OPTIMIZATION_RECOMMENDATIONS(STATUS, PRIORITY_SCORE DESC);
CREATE INDEX IF NOT EXISTS idx_rec_entity ON FACT_OPTIMIZATION_RECOMMENDATIONS(ENTITY_ID, STATUS);


-- =========================================================================
-- POPULATE OPTIMIZATION RULES
-- =========================================================================

INSERT INTO DIM_OPTIMIZATION_RULES (
    RULE_NAME, CATEGORY, DESCRIPTION, TYPICAL_SAVINGS_PCT,
    FEASIBILITY_SCORE, EFFORT_ESTIMATE_HOURS, PRIORITY
) VALUES
    -- Idle Warehouse Rules
    ('High Idle Time Warehouse', 'IDLE_WAREHOUSE',
     'Warehouse with >60% idle time in last 7 days',
     40.0, 9.0, 1, 10),

    ('Excessive Auto-Suspend Timeout', 'AUTO_SUSPEND',
     'Warehouse auto-suspend timeout >10 minutes with infrequent queries',
     15.0, 10.0, 0.25, 20),

    -- Warehouse Sizing Rules
    ('Over-Provisioned Warehouse', 'WAREHOUSE_SIZING',
     'Warehouse with consistently low queue time and <50% credit utilization',
     30.0, 8.0, 1, 30),

    ('Under-Provisioned Warehouse', 'WAREHOUSE_SIZING',
     'Warehouse with frequent queuing and >90% credit utilization',
     NULL, 7.0, 2, 40),

    -- Query Optimization Rules
    ('Expensive Query Without Clustering', 'QUERY_OPTIMIZATION',
     'High-cost query scanning >100GB without clustering key',
     25.0, 5.0, 8, 50),

    ('Query with Excessive Spilling', 'QUERY_OPTIMIZATION',
     'Query spilling to disk (>1GB spilled bytes)',
     20.0, 6.0, 4, 60),

    ('Inefficient SELECT * Query', 'QUERY_OPTIMIZATION',
     'Expensive query using SELECT * on wide tables',
     15.0, 9.0, 2, 70),

    -- Storage Optimization Rules
    ('Unused Table with High Storage Cost', 'STORAGE_WASTE',
     'Table not queried in 90+ days with >1TB storage',
     80.0, 10.0, 0.5, 15),

    ('Excessive Time-Travel Retention', 'STORAGE_WASTE',
     'Database with time-travel >7 days for non-prod data',
     10.0, 10.0, 0.25, 80),

    -- Clustering Rules
    ('High Reclustering Cost', 'CLUSTERING',
     'Table with automatic clustering consuming >$500/month',
     50.0, 6.0, 4, 90),

    ('Missing Clustering Key', 'CLUSTERING',
     'Large table (>1TB) frequently filtered without clustering key',
     30.0, 5.0, 6, 100);


-- =========================================================================
-- VERIFICATION QUERIES
-- =========================================================================

/*
-- Verify: Optimization rules
SELECT
    RULE_ID,
    RULE_NAME,
    CATEGORY,
    TYPICAL_SAVINGS_PCT,
    FEASIBILITY_SCORE,
    EFFORT_ESTIMATE_HOURS,
    PRIORITY,
    IS_ACTIVE
FROM DIM_OPTIMIZATION_RULES
WHERE IS_ACTIVE = TRUE
ORDER BY PRIORITY;


-- Verify: Rule distribution by category
SELECT
    CATEGORY,
    COUNT(*) AS RULE_COUNT,
    AVG(TYPICAL_SAVINGS_PCT) AS AVG_SAVINGS_PCT,
    AVG(FEASIBILITY_SCORE) AS AVG_FEASIBILITY
FROM DIM_OPTIMIZATION_RULES
WHERE IS_ACTIVE = TRUE
GROUP BY CATEGORY
ORDER BY CATEGORY;
*/

/*
=============================================================================
  OBJECTS CREATED:
    - DIM_OPTIMIZATION_RULES
    - FACT_OPTIMIZATION_RECOMMENDATIONS

  NEXT STEPS:
    → Script 02: SP_GENERATE_RECOMMENDATIONS (detection procedures)
    → Script 03: Optimization analysis views
=============================================================================
*/
