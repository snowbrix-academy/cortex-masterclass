/*
=============================================================================
  MODULE 01 : FOUNDATION SETUP
  SCRIPT 01 : Databases & Schemas
=============================================================================
  SNOWBRIX ACADEMY — Enterprise FinOps Dashboard for Snowflake

  LEARNING OBJECTIVES:
    1. Understand the FinOps framework architecture (CONTROL + ANALYTICS)
    2. Create the FINOPS_CONTROL_DB that houses all framework objects
    3. Create the FINOPS_ANALYTICS_DB for pre-aggregated metrics
    4. Understand schema separation: cost data vs chargeback vs budget vs monitoring

  PREREQUISITES:
    - ACCOUNTADMIN or SYSADMIN role access
    - Basic understanding of Snowflake cost model (credits, storage)
    - Familiarity with ACCOUNT_USAGE views

  ARCHITECTURE OVERVIEW:
  ┌──────────────────────────────────────────────────────────────┐
  │  FINOPS_CONTROL_DB          (Framework Database)             │
  │  ├── CONFIG              (Global settings, credit pricing)   │
  │  ├── COST_DATA           (Raw cost facts from ACCOUNT_USAGE) │
  │  ├── CHARGEBACK          (Attribution dimensions, SCD Type 2)│
  │  ├── BUDGET              (Budget defs, vs actual, alerts)    │
  │  ├── OPTIMIZATION        (Recommendations, idle logs)        │
  │  ├── PROCEDURES          (All stored procedures)             │
  │  └── MONITORING          (Semantic views for reporting)      │
  │                                                              │
  │  FINOPS_ANALYTICS_DB     (Pre-Aggregated Metrics)            │
  │  ├── DAILY_AGGREGATES    (Daily rollups for BI tools)        │
  │  ├── WEEKLY_AGGREGATES   (Weekly rollups)                    │
  │  └── MONTHLY_AGGREGATES  (Monthly rollups)                   │
  └──────────────────────────────────────────────────────────────┘

  COST DATA FLOW:
  ┌─────────────────────┐
  │ ACCOUNT_USAGE views │  (Snowflake system views)
  │ - WAREHOUSE_METERING│
  │ - QUERY_HISTORY     │
  │ - STORAGE_USAGE     │
  │ - DATABASE_STORAGE  │
  │ - TASK_HISTORY      │
  │ - PIPE_USAGE_HISTORY│
  └──────────┬──────────┘
             │
             │ Collected by stored procedures
             │ (Hourly/Daily via Tasks)
             ▼
  ┌──────────────────────┐
  │ FINOPS_CONTROL_DB    │
  │   COST_DATA schema   │
  │ - Warehouse costs    │
  │ - Query costs        │
  │ - Storage costs      │
  │ - Serverless costs   │
  └──────────┬───────────┘
             │
             │ Attribution procedures
             ▼
  ┌──────────────────────┐
  │ FINOPS_CONTROL_DB    │
  │   CHARGEBACK schema  │
  │ - Attributed costs   │
  │   by team/dept/proj  │
  └──────────┬───────────┘
             │
             │ Pre-aggregation for BI tools
             ▼
  ┌──────────────────────┐
  │ FINOPS_ANALYTICS_DB  │
  │ - Daily/weekly/monthly│
  │   rollups            │
  └──────────┬───────────┘
             │
             │ Consumed by dashboards
             ▼
  ┌──────────────────────┐
  │ Streamlit Dashboard  │
  │ Power BI / Tableau   │
  └──────────────────────┘

=============================================================================
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
