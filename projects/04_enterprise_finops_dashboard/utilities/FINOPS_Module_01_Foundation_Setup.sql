/*
#############################################################################
  FINOPS - Module 01: Foundation Setup
  CONSOLIDATED WORKSHEET — Snowsight / VS Code Ready
#############################################################################
  SNOWBRIX ACADEMY — Enterprise FinOps Dashboard for Snowflake

  This worksheet contains:
    - 01_databases_and_schemas.sql
    - 02_warehouses.sql
    - 03_roles_and_grants.sql
    

  INSTRUCTIONS:
    - Run each section sequentially (top to bottom)
    - Requires Module 00 to be completed first (if applicable)
    - Estimated time: ~15 minutes

  PREREQUISITES:
    - ACCOUNTADMIN role access
    - FINOPS_ADMIN_ROLE access
#############################################################################
*/


-- =========================================================================
-- STEP 1: USE ACCOUNTADMIN ROLE (Required for initial setup)
-- =========================================================================
USE ROLE ACCOUNTADMIN;

-- =========================================================================
-- STEP 2: CREATE THE FINOPS CONTROL DATABASE
-- This is the "brain" of the framework. It stores all cost data,
-- chargeback attribution, budgets, optimization recommendations, and
-- stored procedures.
-- =========================================================================
CREATE DATABASE IF NOT EXISTS FINOPS_CONTROL_DB
    COMMENT = 'FinOps Framework: Control database housing cost data, chargeback attribution, budgets, and procedures';

-- CONFIG Schema: Global settings, credit pricing, tag taxonomy
CREATE SCHEMA IF NOT EXISTS FINOPS_CONTROL_DB.CONFIG
    COMMENT = 'Configuration: global settings, credit pricing, tag taxonomy, alert thresholds';

-- COST_DATA Schema: Raw cost facts collected from ACCOUNT_USAGE
CREATE SCHEMA IF NOT EXISTS FINOPS_CONTROL_DB.COST_DATA
    COMMENT = 'Raw cost facts: warehouse costs, query costs, storage costs, serverless costs';

-- CHARGEBACK Schema: Attribution dimensions and attributed cost facts
CREATE SCHEMA IF NOT EXISTS FINOPS_CONTROL_DB.CHARGEBACK
    COMMENT = 'Chargeback attribution: SCD Type 2 dimensions, attributed cost facts';

-- BUDGET Schema: Budget definitions, budget vs actual, alerts
CREATE SCHEMA IF NOT EXISTS FINOPS_CONTROL_DB.BUDGET
    COMMENT = 'Budget management: definitions, vs actual tracking, alert history, forecasts';

-- OPTIMIZATION Schema: Cost optimization recommendations and tracking
CREATE SCHEMA IF NOT EXISTS FINOPS_CONTROL_DB.OPTIMIZATION
    COMMENT = 'Cost optimization: recommendations, idle warehouse logs, query optimization candidates';

-- PROCEDURES Schema: All stored procedures for the framework
CREATE SCHEMA IF NOT EXISTS FINOPS_CONTROL_DB.PROCEDURES
    COMMENT = 'All stored procedures: cost collection, attribution, budget checks, recommendations';

-- MONITORING Schema: Semantic views for reporting and dashboards
CREATE SCHEMA IF NOT EXISTS FINOPS_CONTROL_DB.MONITORING
    COMMENT = 'Monitoring views: executive summary, warehouse analytics, chargeback reports, optimization dashboard';

-- =========================================================================
-- STEP 3: CREATE THE FINOPS ANALYTICS DATABASE
-- This database holds pre-aggregated metrics for fast BI tool consumption.
-- The goal is to avoid expensive aggregations in Power BI, Tableau, or
-- Streamlit. Instead, we pre-compute daily, weekly, and monthly rollups.
-- =========================================================================
CREATE DATABASE IF NOT EXISTS FINOPS_ANALYTICS_DB
    COMMENT = 'FinOps Analytics: Pre-aggregated metrics for fast BI tool consumption';

-- DAILY_AGGREGATES Schema: Daily rollups of cost data
CREATE SCHEMA IF NOT EXISTS FINOPS_ANALYTICS_DB.DAILY_AGGREGATES
    COMMENT = 'Daily cost aggregates: by warehouse, team, department, project, cost center';

-- WEEKLY_AGGREGATES Schema: Weekly rollups
CREATE SCHEMA IF NOT EXISTS FINOPS_ANALYTICS_DB.WEEKLY_AGGREGATES
    COMMENT = 'Weekly cost aggregates: for trend analysis and reporting';

-- MONTHLY_AGGREGATES Schema: Monthly rollups
CREATE SCHEMA IF NOT EXISTS FINOPS_ANALYTICS_DB.MONTHLY_AGGREGATES
    COMMENT = 'Monthly cost aggregates: for budget vs actual and executive reporting';


-- =========================================================================
-- VERIFICATION QUERIES
-- Run these to confirm everything was created correctly.
-- =========================================================================

-- List all FinOps databases
SHOW DATABASES LIKE 'FINOPS_%';

-- List schemas in control database
SHOW SCHEMAS IN DATABASE FINOPS_CONTROL_DB;

-- List schemas in analytics database
SHOW SCHEMAS IN DATABASE FINOPS_ANALYTICS_DB;

-- Verify database comments (validates purpose)
SELECT
    DATABASE_NAME,
    COMMENT
FROM SNOWFLAKE.INFORMATION_SCHEMA.DATABASES
WHERE DATABASE_NAME LIKE 'FINOPS_%'
ORDER BY DATABASE_NAME;


/*
=============================================================================
  BEST PRACTICES & TIPS:

  1. NAMING CONVENTION: All FinOps objects use the FINOPS_ prefix to avoid
     conflicts with existing objects in your Snowflake account.

  2. SEPARATION OF CONCERNS:
     - FINOPS_CONTROL_DB: Single source of truth for cost data and attribution
     - FINOPS_ANALYTICS_DB: Performance layer for BI tools (read-only for users)

  3. SCHEMA ORGANIZATION:
     - CONFIG: Store all configurable parameters here (credit price, thresholds)
     - COST_DATA: Raw facts from ACCOUNT_USAGE (minimal transformation)
     - CHARGEBACK: Attribution dimensions and logic (SCD Type 2 for audit trail)
     - BUDGET: Budget control and alerting
     - OPTIMIZATION: Proactive cost reduction recommendations
     - MONITORING: Business-friendly semantic views

  4. CONTROL DB IS SACRED: Only the FinOps admin role and framework service
     account should have write access. All other users get read-only access
     via MONITORING views with row-level security.

  5. ANALYTICS DB FOR SPEED: Pre-aggregated views reduce query time from
     minutes to seconds for BI tools. Update via scheduled tasks.

  6. GRANT PHILOSOPHY:
     - FINOPS_ADMIN: Full control (creates objects, runs procedures)
     - FINOPS_ANALYST: Read-only on all views (can analyze but not modify)
     - FINOPS_TEAM_LEAD: Read-only on their team's costs (row-level security)
     - FINOPS_EXECUTIVE: Read-only on executive summary views only

  WHAT'S NEXT:
  → Module 01, Script 02: Warehouses (compute sizing + resource monitors)
  → Module 01, Script 03: Roles & Grants (RBAC for the framework)
=============================================================================
*/

-- ===========================================================================
-- ===========================================================================
-- 02_WAREHOUSES
-- ===========================================================================
-- ===========================================================================


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

-- ===========================================================================
-- ===========================================================================
-- 03_ROLES_AND_GRANTS
-- ===========================================================================
-- ===========================================================================


USE ROLE ACCOUNTADMIN;

-- =========================================================================
-- STEP 1: CREATE FINOPS ROLES
-- =========================================================================

-- Admin role: Full control over the FinOps framework
CREATE ROLE IF NOT EXISTS FINOPS_ADMIN_ROLE
    COMMENT = 'FinOps Administrator: Full control over cost monitoring, chargeback, budgets, procedures';

-- Analyst role: Read-only access for finance analysts
CREATE ROLE IF NOT EXISTS FINOPS_ANALYST_ROLE
    COMMENT = 'FinOps Analyst: Read-only access to all cost data and reports';

-- Team lead role: Limited access to own team costs
CREATE ROLE IF NOT EXISTS FINOPS_TEAM_LEAD_ROLE
    COMMENT = 'FinOps Team Lead: Read-only access to own teams cost data via row-level security';

-- Executive role: High-level summary only
CREATE ROLE IF NOT EXISTS FINOPS_EXECUTIVE_ROLE
    COMMENT = 'FinOps Executive: Read-only access to executive summary views only';


-- =========================================================================
-- STEP 2: ESTABLISH ROLE HIERARCHY
-- Child roles inherit permissions from parent roles
-- =========================================================================

GRANT ROLE FINOPS_ANALYST_ROLE TO ROLE FINOPS_ADMIN_ROLE;
GRANT ROLE FINOPS_TEAM_LEAD_ROLE TO ROLE FINOPS_ADMIN_ROLE;
GRANT ROLE FINOPS_EXECUTIVE_ROLE TO ROLE FINOPS_ADMIN_ROLE;

-- Grant FinOps admin role to SYSADMIN (standard practice)
GRANT ROLE FINOPS_ADMIN_ROLE TO ROLE SYSADMIN;


-- =========================================================================
-- STEP 3: GRANT WAREHOUSE USAGE
-- All roles can use the FinOps warehouses, but resource monitor controls cost
-- =========================================================================

-- Admin role: Use all warehouses
GRANT USAGE ON WAREHOUSE FINOPS_WH_ADMIN TO ROLE FINOPS_ADMIN_ROLE;
GRANT USAGE ON WAREHOUSE FINOPS_WH_ETL TO ROLE FINOPS_ADMIN_ROLE;
GRANT USAGE ON WAREHOUSE FINOPS_WH_REPORTING TO ROLE FINOPS_ADMIN_ROLE;

-- Analyst role: Use reporting warehouse only
GRANT USAGE ON WAREHOUSE FINOPS_WH_REPORTING TO ROLE FINOPS_ANALYST_ROLE;

-- Team lead role: Use reporting warehouse only
GRANT USAGE ON WAREHOUSE FINOPS_WH_REPORTING TO ROLE FINOPS_TEAM_LEAD_ROLE;

-- Executive role: Use reporting warehouse only
GRANT USAGE ON WAREHOUSE FINOPS_WH_REPORTING TO ROLE FINOPS_EXECUTIVE_ROLE;


-- =========================================================================
-- STEP 4: GRANT DATABASE AND SCHEMA PERMISSIONS
-- =========================================================================

-- -------------------------------------------------------------------------
-- FINOPS_ADMIN_ROLE: Full control
-- -------------------------------------------------------------------------
GRANT USAGE ON DATABASE FINOPS_CONTROL_DB TO ROLE FINOPS_ADMIN_ROLE;
GRANT USAGE ON DATABASE FINOPS_ANALYTICS_DB TO ROLE FINOPS_ADMIN_ROLE;

-- Grant on all schemas in FINOPS_CONTROL_DB
GRANT USAGE ON ALL SCHEMAS IN DATABASE FINOPS_CONTROL_DB TO ROLE FINOPS_ADMIN_ROLE;
GRANT CREATE TABLE ON ALL SCHEMAS IN DATABASE FINOPS_CONTROL_DB TO ROLE FINOPS_ADMIN_ROLE;
GRANT CREATE VIEW ON ALL SCHEMAS IN DATABASE FINOPS_CONTROL_DB TO ROLE FINOPS_ADMIN_ROLE;
GRANT CREATE PROCEDURE ON ALL SCHEMAS IN DATABASE FINOPS_CONTROL_DB TO ROLE FINOPS_ADMIN_ROLE;
GRANT CREATE TASK ON SCHEMA FINOPS_CONTROL_DB.PROCEDURES TO ROLE FINOPS_ADMIN_ROLE;

-- Future grants (apply to objects created in the future)
GRANT USAGE ON FUTURE SCHEMAS IN DATABASE FINOPS_CONTROL_DB TO ROLE FINOPS_ADMIN_ROLE;
GRANT SELECT, INSERT, UPDATE, DELETE ON FUTURE TABLES IN DATABASE FINOPS_CONTROL_DB TO ROLE FINOPS_ADMIN_ROLE;
GRANT SELECT ON FUTURE VIEWS IN DATABASE FINOPS_CONTROL_DB TO ROLE FINOPS_ADMIN_ROLE;

-- Grant on all schemas in FINOPS_ANALYTICS_DB
GRANT USAGE ON ALL SCHEMAS IN DATABASE FINOPS_ANALYTICS_DB TO ROLE FINOPS_ADMIN_ROLE;
GRANT CREATE TABLE ON ALL SCHEMAS IN DATABASE FINOPS_ANALYTICS_DB TO ROLE FINOPS_ADMIN_ROLE;
GRANT CREATE VIEW ON ALL SCHEMAS IN DATABASE FINOPS_ANALYTICS_DB TO ROLE FINOPS_ADMIN_ROLE;

GRANT USAGE ON FUTURE SCHEMAS IN DATABASE FINOPS_ANALYTICS_DB TO ROLE FINOPS_ADMIN_ROLE;
GRANT SELECT, INSERT, UPDATE, DELETE ON FUTURE TABLES IN DATABASE FINOPS_ANALYTICS_DB TO ROLE FINOPS_ADMIN_ROLE;
GRANT SELECT ON FUTURE VIEWS IN DATABASE FINOPS_ANALYTICS_DB TO ROLE FINOPS_ADMIN_ROLE;

-- -------------------------------------------------------------------------
-- FINOPS_ANALYST_ROLE: Read-only on all views and tables
-- -------------------------------------------------------------------------
GRANT USAGE ON DATABASE FINOPS_CONTROL_DB TO ROLE FINOPS_ANALYST_ROLE;
GRANT USAGE ON DATABASE FINOPS_ANALYTICS_DB TO ROLE FINOPS_ANALYST_ROLE;

GRANT USAGE ON ALL SCHEMAS IN DATABASE FINOPS_CONTROL_DB TO ROLE FINOPS_ANALYST_ROLE;
GRANT USAGE ON ALL SCHEMAS IN DATABASE FINOPS_ANALYTICS_DB TO ROLE FINOPS_ANALYST_ROLE;

-- Read-only access to all tables and views
GRANT SELECT ON ALL TABLES IN DATABASE FINOPS_CONTROL_DB TO ROLE FINOPS_ANALYST_ROLE;
GRANT SELECT ON ALL VIEWS IN DATABASE FINOPS_CONTROL_DB TO ROLE FINOPS_ANALYST_ROLE;
GRANT SELECT ON ALL TABLES IN DATABASE FINOPS_ANALYTICS_DB TO ROLE FINOPS_ANALYST_ROLE;
GRANT SELECT ON ALL VIEWS IN DATABASE FINOPS_ANALYTICS_DB TO ROLE FINOPS_ANALYST_ROLE;

-- Future grants for analyst
GRANT USAGE ON FUTURE SCHEMAS IN DATABASE FINOPS_CONTROL_DB TO ROLE FINOPS_ANALYST_ROLE;
GRANT USAGE ON FUTURE SCHEMAS IN DATABASE FINOPS_ANALYTICS_DB TO ROLE FINOPS_ANALYST_ROLE;
GRANT SELECT ON FUTURE TABLES IN DATABASE FINOPS_CONTROL_DB TO ROLE FINOPS_ANALYST_ROLE;
GRANT SELECT ON FUTURE VIEWS IN DATABASE FINOPS_CONTROL_DB TO ROLE FINOPS_ANALYST_ROLE;
GRANT SELECT ON FUTURE TABLES IN DATABASE FINOPS_ANALYTICS_DB TO ROLE FINOPS_ANALYST_ROLE;
GRANT SELECT ON FUTURE VIEWS IN DATABASE FINOPS_ANALYTICS_DB TO ROLE FINOPS_ANALYST_ROLE;

-- -------------------------------------------------------------------------
-- FINOPS_TEAM_LEAD_ROLE: Read-only on MONITORING views only
-- Row-level security will be implemented in the views themselves
-- -------------------------------------------------------------------------
GRANT USAGE ON DATABASE FINOPS_CONTROL_DB TO ROLE FINOPS_TEAM_LEAD_ROLE;
GRANT USAGE ON SCHEMA FINOPS_CONTROL_DB.MONITORING TO ROLE FINOPS_TEAM_LEAD_ROLE;

-- Grant on views will be set after view creation in Module 07
-- Placeholder: GRANT SELECT ON FINOPS_CONTROL_DB.MONITORING.VW_* TO ROLE FINOPS_TEAM_LEAD_ROLE;

-- -------------------------------------------------------------------------
-- FINOPS_EXECUTIVE_ROLE: Read-only on executive summary views only
-- -------------------------------------------------------------------------
GRANT USAGE ON DATABASE FINOPS_CONTROL_DB TO ROLE FINOPS_EXECUTIVE_ROLE;
GRANT USAGE ON SCHEMA FINOPS_CONTROL_DB.MONITORING TO ROLE FINOPS_EXECUTIVE_ROLE;

-- Grant on specific executive views will be set after view creation in Module 07
-- Placeholder: GRANT SELECT ON FINOPS_CONTROL_DB.MONITORING.VW_EXECUTIVE_SUMMARY TO ROLE FINOPS_EXECUTIVE_ROLE;


-- =========================================================================
-- STEP 5: GRANT ACCESS TO ACCOUNT_USAGE SCHEMA
-- Required for cost collection procedures to read system views
-- =========================================================================

GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE TO ROLE FINOPS_ADMIN_ROLE;


-- =========================================================================
-- STEP 6: GRANT EXECUTE ON PROCEDURES (Future Grant)
-- Procedures will be created in Module 02-06
-- =========================================================================

-- Admin can execute all procedures
GRANT USAGE ON FUTURE PROCEDURES IN SCHEMA FINOPS_CONTROL_DB.PROCEDURES TO ROLE FINOPS_ADMIN_ROLE;

-- Analyst can execute read-only procedures (report generation)
-- Will be granted selectively after procedure creation


-- =========================================================================
-- VERIFICATION QUERIES
-- =========================================================================

-- List all FinOps roles
SHOW ROLES LIKE 'FINOPS_%';

-- Verify role hierarchy
SELECT
    GRANTEE_NAME AS ROLE,
    NAME AS GRANTED_ROLE,
    GRANTED_BY
FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_ROLES
WHERE GRANTEE_NAME LIKE 'FINOPS_%'
    AND GRANTED_ON = 'ROLE'
ORDER BY GRANTEE_NAME, NAME;

-- Verify warehouse grants
SELECT
    GRANTEE_NAME AS ROLE,
    TABLE_NAME AS WAREHOUSE,
    PRIVILEGE_TYPE
FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_ROLES
WHERE GRANTEE_NAME LIKE 'FINOPS_%'
    AND GRANTED_ON = 'WAREHOUSE'
ORDER BY GRANTEE_NAME, TABLE_NAME;

-- Verify database grants
SELECT
    GRANTEE_NAME AS ROLE,
    TABLE_NAME AS DATABASE_NAME,
    PRIVILEGE_TYPE
FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_ROLES
WHERE GRANTEE_NAME LIKE 'FINOPS_%'
    AND GRANTED_ON = 'DATABASE'
ORDER BY GRANTEE_NAME, TABLE_NAME;

-- Verify schema grants
SELECT
    GRANTEE_NAME AS ROLE,
    TABLE_SCHEMA AS SCHEMA_NAME,
    PRIVILEGE_TYPE,
    IS_GRANTABLE
FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_ROLES
WHERE GRANTEE_NAME LIKE 'FINOPS_%'
    AND GRANTED_ON = 'SCHEMA'
    AND TABLE_SCHEMA LIKE 'FINOPS_%'
ORDER BY GRANTEE_NAME, TABLE_SCHEMA;


/*
=============================================================================
  BEST PRACTICES & TIPS:

  1. LEAST PRIVILEGE PRINCIPLE:
     - Start with minimal permissions
     - Add permissions only when needed
     - Use role hierarchy to simplify management (child inherits from parent)

  2. FUTURE GRANTS ARE CRITICAL:
     - Without future grants, every new table/view requires manual grant updates
     - Future grants ensure new objects are automatically accessible
     - Apply future grants at schema level for consistency

  3. ROLE NAMING CONVENTION:
     - FINOPS_*_ROLE suffix for all framework roles
     - Descriptive middle part: ADMIN, ANALYST, TEAM_LEAD, EXECUTIVE
     - Matches industry standard patterns

  4. SEPARATION OF DUTIES:
     - ADMIN: Can modify framework (tables, procedures, config)
     - ANALYST: Can analyze data but not modify
     - TEAM_LEAD: Can see own team's costs only (row-level security)
     - EXECUTIVE: High-level summary only (reduce noise)

  5. ROW-LEVEL SECURITY (Implemented in Module 07):
     - Views will use CURRENT_ROLE() to filter data
     - Example: WHERE team = (SELECT team FROM user_mapping WHERE user = CURRENT_USER())
     - Team leads see only their team's costs
     - Implemented in view definition, not here

  6. WAREHOUSE ACCESS:
     - Admin: Access to all warehouses (for troubleshooting)
     - Analyst/Team Lead/Executive: Reporting warehouse only
     - Resource monitor prevents runaway costs

  7. ACCOUNT_USAGE ACCESS:
     - FINOPS_ADMIN_ROLE needs IMPORTED PRIVILEGES on SNOWFLAKE database
     - This grants read access to ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY, etc.
     - Required for cost collection procedures

  8. PRODUCTION READINESS:
     - In production, assign users to roles via Identity Provider (SSO)
     - Use Snowflake system parameters for default roles
     - Audit role grants quarterly (who has FINOPS_ADMIN_ROLE?)

  9. TESTING ROLE ACCESS:
     - Switch roles to test permissions: USE ROLE FINOPS_ANALYST_ROLE;
     - Try to create table (should fail for non-admin roles)
     - Try to select from views (should succeed for analyst/team lead)

  WHAT'S NEXT:
  → Module 02, Script 01: Cost Tables (create fact tables for cost data)
  → Module 02, Script 02: SP_COLLECT_WAREHOUSE_COSTS (collect warehouse costs)
=============================================================================
*/



/*
#############################################################################
  MODULE 01 COMPLETE!

  Objects Created:
    - Databases: FINOPS_CONTROL_DB, FINOPS_ANALYTICS_DB
    - Schemas: CONFIG, COST_DATA, CHARGEBACK, BUDGET, OPTIMIZATION, PROCEDURES, MONITORING
    - Warehouses: FINOPS_WH_ADMIN, FINOPS_WH_ETL, FINOPS_WH_REPORTING
    - Resource Monitor: FINOPS_FRAMEWORK_MONITOR
    - Roles: FINOPS_ADMIN_ROLE, FINOPS_ANALYST_ROLE, FINOPS_TEAM_LEAD_ROLE, FINOPS_EXECUTIVE_ROLE

  Next: FINOPS - Module 02 (Cost Collection)
#############################################################################
*/
