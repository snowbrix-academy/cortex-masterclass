/*
=============================================================================
  MODULE 01 : FOUNDATION SETUP
  SCRIPT 02 : Warehouses (Compute)
=============================================================================
  SNOWBRIX ACADEMY — Metadata-Driven Ingestion Framework (MDF)

  LEARNING OBJECTIVES:
    1. Understand warehouse sizing for ingestion workloads
    2. Create purpose-specific warehouses (ingestion, transform, monitoring)
    3. Configure auto-suspend and auto-resume for cost efficiency
    4. Set up resource monitors to prevent runaway costs

  KEY PRINCIPLE:
    "Never size a warehouse based on your biggest table.
     Size it based on your query complexity."
     — The Migration Architect

  WHY SEPARATE WAREHOUSES:
  ┌────────────────────────────────────────────────────────────┐
  │  MDF_INGESTION_WH   → COPY INTO operations (I/O heavy)    │
  │  MDF_TRANSFORM_WH   → Staging transforms (compute heavy)  │
  │  MDF_MONITORING_WH   → Dashboard queries (lightweight)     │
  │  MDF_ADMIN_WH        → Procedure execution, maintenance    │
  └────────────────────────────────────────────────────────────┘

  Separating compute means:
    - Ingestion doesn't compete with transforms for resources
    - Monitoring queries never slow down data loading
    - You can scale each independently based on workload
    - Cost attribution is crystal clear per workload type
=============================================================================
*/

USE ROLE SYSADMIN;

-- =========================================================================
-- STEP 1: INGESTION WAREHOUSE
-- Used for COPY INTO operations. These are I/O heavy, not compute heavy.
-- SMALL is typically sufficient for most file-based ingestion.
-- Auto-suspend at 60 seconds saves costs between load batches.
-- =========================================================================
CREATE WAREHOUSE IF NOT EXISTS MDF_INGESTION_WH
    WITH
        WAREHOUSE_SIZE      = 'SMALL'
        AUTO_SUSPEND        = 60          -- Suspend after 60 seconds idle
        AUTO_RESUME         = TRUE        -- Resume automatically on query
        MIN_CLUSTER_COUNT   = 1
        MAX_CLUSTER_COUNT   = 2           -- Scale out for parallel loads
        SCALING_POLICY      = 'STANDARD'
        INITIALLY_SUSPENDED = TRUE        -- Don't start billing immediately
        COMMENT             = 'MDF: Ingestion warehouse for COPY INTO operations';

-- =========================================================================
-- STEP 2: TRANSFORM WAREHOUSE
-- Used for staging-to-curated transformations. These can be compute heavy.
-- MEDIUM provides more compute for complex joins and aggregations.
-- =========================================================================
CREATE WAREHOUSE IF NOT EXISTS MDF_TRANSFORM_WH
    WITH
        WAREHOUSE_SIZE      = 'MEDIUM'
        AUTO_SUSPEND        = 120         -- 2 minutes (transforms run longer)
        AUTO_RESUME         = TRUE
        MIN_CLUSTER_COUNT   = 1
        MAX_CLUSTER_COUNT   = 1           -- Single cluster for transforms
        SCALING_POLICY      = 'STANDARD'
        INITIALLY_SUSPENDED = TRUE
        COMMENT             = 'MDF: Transform warehouse for staging-to-curated processing';

-- =========================================================================
-- STEP 3: MONITORING WAREHOUSE
-- Used for dashboard queries and health checks. Very lightweight.
-- XSMALL is more than enough for SELECT queries on audit tables.
-- =========================================================================
CREATE WAREHOUSE IF NOT EXISTS MDF_MONITORING_WH
    WITH
        WAREHOUSE_SIZE      = 'XSMALL'
        AUTO_SUSPEND        = 60
        AUTO_RESUME         = TRUE
        MIN_CLUSTER_COUNT   = 1
        MAX_CLUSTER_COUNT   = 1
        INITIALLY_SUSPENDED = TRUE
        COMMENT             = 'MDF: Monitoring warehouse for dashboard and health check queries';

-- =========================================================================
-- STEP 4: ADMIN WAREHOUSE
-- Used for procedure execution and framework maintenance.
-- SMALL with aggressive auto-suspend.
-- =========================================================================
CREATE WAREHOUSE IF NOT EXISTS MDF_ADMIN_WH
    WITH
        WAREHOUSE_SIZE      = 'SMALL'
        AUTO_SUSPEND        = 60
        AUTO_RESUME         = TRUE
        MIN_CLUSTER_COUNT   = 1
        MAX_CLUSTER_COUNT   = 1
        INITIALLY_SUSPENDED = TRUE
        COMMENT             = 'MDF: Admin warehouse for stored procedures and maintenance';


-- =========================================================================
-- STEP 5: RESOURCE MONITORS
-- These are your financial guardrails. They prevent runaway costs.
-- Set them BEFORE you start loading data, not after you get the bill.
-- =========================================================================
USE ROLE ACCOUNTADMIN;

-- Resource monitor for ingestion warehouse
CREATE OR REPLACE RESOURCE MONITOR MDF_INGESTION_MONITOR
    WITH
        CREDIT_QUOTA = 100                     -- 100 credits per month
        FREQUENCY    = MONTHLY
        START_TIMESTAMP = IMMEDIATELY
        TRIGGERS
            ON 75 PERCENT DO NOTIFY            -- Alert at 75%
            ON 90 PERCENT DO NOTIFY            -- Alert at 90%
            ON 100 PERCENT DO SUSPEND          -- Suspend at 100%
            ON 110 PERCENT DO SUSPEND_IMMEDIATE; -- Force suspend at 110%

-- Resource monitor for transform warehouse
CREATE OR REPLACE RESOURCE MONITOR MDF_TRANSFORM_MONITOR
    WITH
        CREDIT_QUOTA = 200
        FREQUENCY    = MONTHLY
        START_TIMESTAMP = IMMEDIATELY
        TRIGGERS
            ON 75 PERCENT DO NOTIFY
            ON 90 PERCENT DO NOTIFY
            ON 100 PERCENT DO SUSPEND
            ON 110 PERCENT DO SUSPEND_IMMEDIATE;

-- Assign resource monitors to warehouses
ALTER WAREHOUSE MDF_INGESTION_WH SET RESOURCE_MONITOR = MDF_INGESTION_MONITOR;
ALTER WAREHOUSE MDF_TRANSFORM_WH SET RESOURCE_MONITOR = MDF_TRANSFORM_MONITOR;


-- =========================================================================
-- VERIFICATION QUERIES
-- =========================================================================

-- Show all MDF warehouses
SHOW WAREHOUSES LIKE 'MDF_%';

-- Show resource monitors
SHOW RESOURCE MONITORS LIKE 'MDF_%';

-- Check warehouse configurations
SELECT
    "name"          AS warehouse_name,
    "size"          AS warehouse_size,
    "auto_suspend"  AS auto_suspend_seconds,
    "auto_resume"   AS auto_resume_enabled,
    "min_cluster_count" AS min_clusters,
    "max_cluster_count" AS max_clusters
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID(-2)));  -- References the SHOW WAREHOUSES result


/*
=============================================================================
  BEST PRACTICES & TIPS:

  1. START SMALL: You can always scale UP a warehouse. Scaling down after
     you've been running XL for a month means you already overpaid.

  2. AUTO-SUSPEND AT 60s: For ingestion workloads, 60 seconds is the sweet
     spot. COPY INTO operations are bursty — load, idle, load, idle.

  3. RESOURCE MONITORS ARE NOT OPTIONAL: Without them, a single bad query
     or misconfigured task can burn through your entire monthly budget
     overnight. We've seen it happen. Multiple times.

  4. MULTI-CLUSTER FOR INGESTION: Setting max_cluster_count = 2 allows
     Snowflake to spin up a second cluster during parallel loads.
     This costs 2x credits during that window but loads data 2x faster.

  5. WAREHOUSE PER WORKLOAD TYPE: This isn't just about isolation.
     It's about cost attribution. When the CFO asks "why is our Snowflake
     bill $40K this month?", you can point to exactly which workload
     caused the spike.

  WHAT'S NEXT:
  → Module 01, Script 03: Roles & Grants (RBAC setup)
=============================================================================
*/
