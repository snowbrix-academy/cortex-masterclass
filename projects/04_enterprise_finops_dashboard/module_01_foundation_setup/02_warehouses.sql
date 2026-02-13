/*
=============================================================================
  MODULE 01 : FOUNDATION SETUP
  SCRIPT 02 : Warehouses & Resource Monitors
=============================================================================
  SNOWBRIX ACADEMY — Enterprise FinOps Dashboard for Snowflake

  LEARNING OBJECTIVES:
    1. Create appropriately-sized warehouses for the FinOps framework
    2. Implement resource monitors to control framework costs
    3. Understand warehouse sizing for different workload types
    4. Configure auto-suspend and auto-resume for cost optimization

  PREREQUISITES:
    - Module 01, Script 01 completed (databases and schemas created)
    - ACCOUNTADMIN role access

  WAREHOUSE STRATEGY:
  ┌──────────────────────────────────────────────────────────────┐
  │  WAREHOUSE                │ SIZE  │ USE CASE                 │
  │──────────────────────────────────────────────────────────────│
  │  FINOPS_WH_ADMIN          │ XSMALL│ Manual admin tasks,      │
  │                           │       │ one-time procedures,     │
  │                           │       │ testing                  │
  │──────────────────────────────────────────────────────────────│
  │  FINOPS_WH_ETL            │ SMALL │ Scheduled data collection│
  │                           │       │ (cost collection, budget │
  │                           │       │  checks, recommendations)│
  │──────────────────────────────────────────────────────────────│
  │  FINOPS_WH_REPORTING      │ SMALL │ BI tool queries (Power BI│
  │                           │       │ Tableau, Streamlit)      │
  │                           │       │ Multi-cluster if needed  │
  └──────────────────────────────────────────────────────────────┘

  RESOURCE MONITOR STRATEGY:
  - Framework should cost <$100/month (assuming $3/credit)
  - Set monitor at $150/month to provide buffer but alert on overruns
  - Suspend tasks if 100% of quota consumed (safety net)

=============================================================================
*/

USE ROLE ACCOUNTADMIN;

-- =========================================================================
-- STEP 1: CREATE RESOURCE MONITOR FOR FINOPS FRAMEWORK
-- This ensures the FinOps framework itself doesn't become a cost problem.
-- =========================================================================

CREATE RESOURCE MONITOR IF NOT EXISTS FINOPS_FRAMEWORK_MONITOR
    WITH
        CREDIT_QUOTA = 50               -- 50 credits/month (~$150 at $3/credit)
        FREQUENCY = MONTHLY             -- Reset monthly
        START_TIMESTAMP = IMMEDIATELY
        TRIGGERS
            ON 75 PERCENT DO NOTIFY      -- Alert FinOps admin at 75%
            ON 90 PERCENT DO NOTIFY      -- Alert again at 90%
            ON 100 PERCENT DO SUSPEND    -- Suspend tasks at 100% (safety net)
    COMMENT = 'Resource monitor for FinOps framework warehouses - budget $150/month';


-- =========================================================================
-- STEP 2: CREATE FINOPS_WH_ADMIN (XSMALL - For Manual Operations)
-- Used for:
-- - Manual testing and validation
-- - One-time data collection runs
-- - Admin troubleshooting
-- - Initial framework setup
-- =========================================================================

CREATE WAREHOUSE IF NOT EXISTS FINOPS_WH_ADMIN
    WITH
        WAREHOUSE_SIZE = 'XSMALL'       -- 1 credit/hour
        AUTO_SUSPEND = 60               -- Suspend after 1 minute idle
        AUTO_RESUME = TRUE              -- Auto-resume on query
        INITIALLY_SUSPENDED = TRUE      -- Start suspended
        RESOURCE_MONITOR = FINOPS_FRAMEWORK_MONITOR
    COMMENT = 'FinOps Admin Warehouse: For manual admin tasks, testing, troubleshooting';


-- =========================================================================
-- STEP 3: CREATE FINOPS_WH_ETL (SMALL - For Scheduled Data Collection)
-- Used for:
-- - Hourly/daily cost collection tasks
-- - Budget checking procedures
-- - Chargeback calculation
-- - Optimization recommendation generation
-- =========================================================================

CREATE WAREHOUSE IF NOT EXISTS FINOPS_WH_ETL
    WITH
        WAREHOUSE_SIZE = 'SMALL'        -- 2 credits/hour
        AUTO_SUSPEND = 60               -- Suspend after 1 minute idle
        AUTO_RESUME = TRUE              -- Auto-resume on query
        INITIALLY_SUSPENDED = TRUE      -- Start suspended
        RESOURCE_MONITOR = FINOPS_FRAMEWORK_MONITOR
    COMMENT = 'FinOps ETL Warehouse: For scheduled cost collection, budget checks, recommendations';


-- =========================================================================
-- STEP 4: CREATE FINOPS_WH_REPORTING (SMALL - For BI Tool Queries)
-- Used for:
-- - Power BI / Tableau queries
-- - Streamlit dashboard
-- - Ad-hoc analyst queries
-- - Multi-cluster can be enabled later if needed
-- =========================================================================

CREATE WAREHOUSE IF NOT EXISTS FINOPS_WH_REPORTING
    WITH
        WAREHOUSE_SIZE = 'SMALL'        -- 2 credits/hour
        AUTO_SUSPEND = 300              -- Suspend after 5 minutes idle (BI tools query frequently)
        AUTO_RESUME = TRUE              -- Auto-resume on query
        INITIALLY_SUSPENDED = TRUE      -- Start suspended
        MIN_CLUSTER_COUNT = 1           -- Start with 1 cluster
        MAX_CLUSTER_COUNT = 2           -- Scale to 2 clusters if needed (for concurrent BI users)
        SCALING_POLICY = 'STANDARD'     -- Standard scaling (balance cost and performance)
        RESOURCE_MONITOR = FINOPS_FRAMEWORK_MONITOR
    COMMENT = 'FinOps Reporting Warehouse: For BI tools (Power BI, Tableau, Streamlit), ad-hoc queries';


-- =========================================================================
-- STEP 5: TAG WAREHOUSES FOR COST ATTRIBUTION
-- Tag the FinOps warehouses themselves so they appear correctly in
-- chargeback reports (attributed to the FinOps team).
-- Note: Tags will be created in Module 03. This is a placeholder.
-- =========================================================================

-- Tag application will happen after tag creation in Module 03
-- Placeholder for reference:
/*
ALTER WAREHOUSE FINOPS_WH_ADMIN SET TAG
    FINOPS_CONTROL_DB.CONFIG.DEPARTMENT = 'FINOPS',
    FINOPS_CONTROL_DB.CONFIG.TEAM = 'FINOPS_PLATFORM',
    FINOPS_CONTROL_DB.CONFIG.COST_CENTER = 'CC-FINOPS',
    FINOPS_CONTROL_DB.CONFIG.ENVIRONMENT = 'PROD',
    FINOPS_CONTROL_DB.CONFIG.OWNER = 'finops-admin@company.com';
*/


-- =========================================================================
-- VERIFICATION QUERIES
-- =========================================================================

-- List all FinOps warehouses
SHOW WAREHOUSES LIKE 'FINOPS_WH_%';

-- Verify warehouse configurations
SELECT
    NAME AS WAREHOUSE_NAME,
    SIZE,
    AUTO_SUSPEND,
    AUTO_RESUME,
    RESOURCE_MONITOR,
    MIN_CLUSTER_COUNT,
    MAX_CLUSTER_COUNT,
    SCALING_POLICY,
    COMMENT
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSES
WHERE NAME LIKE 'FINOPS_WH_%'
    AND DELETED IS NULL
ORDER BY NAME;

-- Verify resource monitor
SHOW RESOURCE MONITORS LIKE 'FINOPS_FRAMEWORK_MONITOR';

SELECT
    NAME AS MONITOR_NAME,
    CREDIT_QUOTA,
    FREQUENCY,
    START_TIME,
    END_TIME,
    COMMENT
FROM SNOWFLAKE.ACCOUNT_USAGE.RESOURCE_MONITORS
WHERE NAME = 'FINOPS_FRAMEWORK_MONITOR'
ORDER BY START_TIME DESC
LIMIT 1;


/*
=============================================================================
  BEST PRACTICES & TIPS:

  1. WAREHOUSE SIZING PHILOSOPHY:
     - Start small (XSMALL/SMALL)
     - Monitor actual usage via WAREHOUSE_METERING_HISTORY
     - Scale up only if query queue time is consistently high
     - The FinOps framework itself should be lightweight

  2. AUTO-SUSPEND TUNING:
     - Admin warehouse: 60 seconds (used infrequently)
     - ETL warehouse: 60 seconds (tasks run and finish quickly)
     - Reporting warehouse: 300 seconds (BI tools query frequently)
     - Balance: Shorter = more cost savings, Longer = less startup latency

  3. MULTI-CLUSTER CONSIDERATIONS:
     - Start with single cluster
     - Enable multi-cluster if >5 concurrent BI users
     - Monitor queue time: if >1 second consistently, add clusters
     - For this framework: 1-2 clusters is typically sufficient

  4. RESOURCE MONITOR AS SAFETY NET:
     - 50 credits/month = ~$150 at $3/credit (adjust for your pricing)
     - This is a generous budget for the framework itself
     - If hitting this limit, investigate runaway queries or configuration issues
     - SUSPEND at 100% prevents unlimited cost escalation

  5. COST ESTIMATION:
     - XSMALL: 1 credit/hour * 1 hour/month active = 1 credit/month
     - SMALL ETL: 2 credits/hour * 2 hours/day * 30 days = 120 credits/month
     - SMALL Reporting: 2 credits/hour * 4 hours/day * 30 days = 240 credits/month
     - Total estimate: ~360 credits/month IF running continuously
     - With auto-suspend: Likely <50 credits/month in practice

  6. WAREHOUSE NAMING CONVENTION:
     - FINOPS_WH_* prefix for all framework warehouses
     - Suffix describes purpose: ADMIN, ETL, REPORTING
     - Makes it easy to identify framework costs in reports

  7. INITIALLY_SUSPENDED:
     - All warehouses start suspended to avoid immediate costs
     - They resume automatically when first query is executed
     - Good practice for any new warehouse

  WHAT'S NEXT:
  → Module 01, Script 03: Roles & Grants (RBAC for the framework)
  → Module 02, Script 01: Cost Tables (create fact tables for cost data)
=============================================================================
*/
