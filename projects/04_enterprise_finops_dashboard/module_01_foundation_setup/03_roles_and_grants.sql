/*
=============================================================================
  MODULE 01 : FOUNDATION SETUP
  SCRIPT 03 : Roles & Grants (RBAC)
=============================================================================
  SNOWBRIX ACADEMY — Enterprise FinOps Dashboard for Snowflake

  LEARNING OBJECTIVES:
    1. Implement least-privilege RBAC for the FinOps framework
    2. Create role hierarchy that mirrors organizational structure
    3. Understand future grants for dynamic object creation
    4. Configure row-level security preparation for team-level access

  PREREQUISITES:
    - Module 01, Script 01 completed (databases created)
    - Module 01, Script 02 completed (warehouses created)
    - ACCOUNTADMIN role access

  ROLE HIERARCHY:
  ┌──────────────────────────────────────────────────────────────┐
  │                    ACCOUNTADMIN                              │
  │                          │                                   │
  │                          ▼                                   │
  │                   FINOPS_ADMIN_ROLE                          │
  │                          │                                   │
  │         ┌────────────────┼────────────────┐                  │
  │         ▼                ▼                ▼                  │
  │  FINOPS_ANALYST_   FINOPS_TEAM_    FINOPS_EXECUTIVE_         │
  │       ROLE           LEAD_ROLE          ROLE                 │
  └──────────────────────────────────────────────────────────────┘

  ROLE PERMISSIONS:
  ┌──────────────────────────────────────────────────────────────┐
  │ ROLE                  │ PERMISSIONS                          │
  ├──────────────────────────────────────────────────────────────┤
  │ FINOPS_ADMIN_ROLE     │ Full control: CREATE, READ, WRITE,   │
  │                       │ EXECUTE procedures, manage config    │
  ├──────────────────────────────────────────────────────────────┤
  │ FINOPS_ANALYST_ROLE   │ Read-only: All views, can export     │
  │                       │ data, run reports                    │
  ├──────────────────────────────────────────────────────────────┤
  │ FINOPS_TEAM_LEAD_ROLE │ Read-only: Own team's costs via      │
  │                       │ row-level security in views          │
  ├──────────────────────────────────────────────────────────────┤
  │ FINOPS_EXECUTIVE_ROLE │ Read-only: Executive summary views   │
  │                       │ only, no drill-down details          │
  └──────────────────────────────────────────────────────────────┘

=============================================================================
*/

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
