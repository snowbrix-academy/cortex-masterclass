/*
#############################################################################
  MDF - Module 01: Foundation Setup
  CONSOLIDATED WORKSHEET — Snowsight / VS Code Ready
#############################################################################
  SNOWBRIX ACADEMY — Metadata-Driven Ingestion Framework (MDF)

  This worksheet combines ALL Module 01 scripts into a single file:
    Part 1: Databases & Schemas
    Part 2: Warehouses (Compute)
    Part 3: Roles & Grants (RBAC)

  INSTRUCTIONS:
    - Run each section sequentially (top to bottom)
    - Each section can be run independently if needed
    - Use Ctrl+Enter in Snowsight to run selected statements
    - Estimated time: ~15 minutes

  PREREQUISITES:
    - ACCOUNTADMIN or SYSADMIN role access
    - Fresh Snowflake account or no existing MDF_ objects
#############################################################################
*/


-- ===========================================================================
-- ███████████████████████████████████████████████████████████████████████████
-- PART 1 OF 3: DATABASES & SCHEMAS
-- ███████████████████████████████████████████████████████████████████████████
-- ===========================================================================

/*
  ARCHITECTURE OVERVIEW:
  ┌──────────────────────────────────────────────────────────────┐
  │  MDF_CONTROL_DB          (Framework Database)                │
  │  ├── CONFIG              (Config tables, registries)         │
  │  ├── AUDIT               (Audit logs, run history)           │
  │  ├── PROCEDURES           (All stored procedures)             │
  │  └── MONITORING          (Views, dashboards)                 │
  │                                                              │
  │  MDF_RAW_DB              (Raw Data Landing Zone)             │
  │  ├── <CLIENT>_<SOURCE>   (Dynamic schemas per source)        │
  │                                                              │
  │  MDF_STAGING_DB          (Cleaned & Validated Data)          │
  │  ├── <CLIENT>_<SOURCE>   (Mirrors raw with quality checks)   │
  │                                                              │
  │  MDF_CURATED_DB          (Business-Ready Data)               │
  │  ├── <CLIENT>_<DOMAIN>   (Transformed, aggregated)           │
  └──────────────────────────────────────────────────────────────┘
*/

-- STEP 1: USE ACCOUNTADMIN ROLE
USE ROLE ACCOUNTADMIN;

-- STEP 2: CREATE THE MDF CONTROL DATABASE
CREATE DATABASE IF NOT EXISTS MDF_CONTROL_DB
    COMMENT = 'Metadata-Driven Framework: Control database housing all framework objects, configs, and procedures';

CREATE SCHEMA IF NOT EXISTS MDF_CONTROL_DB.CONFIG
    COMMENT = 'Configuration tables: ingestion configs, file format registry, stage registry';

CREATE SCHEMA IF NOT EXISTS MDF_CONTROL_DB.AUDIT
    COMMENT = 'Audit and logging: ingestion run history, error logs, data quality results';

CREATE SCHEMA IF NOT EXISTS MDF_CONTROL_DB.PROCEDURES
    COMMENT = 'All stored procedures for the ingestion framework';

CREATE SCHEMA IF NOT EXISTS MDF_CONTROL_DB.MONITORING
    COMMENT = 'Monitoring views, dashboard queries, and alerting objects';

-- STEP 3: CREATE THE DATA LAYER DATABASES
CREATE DATABASE IF NOT EXISTS MDF_RAW_DB
    COMMENT = 'Raw data landing zone: exact copy of source files, no transformations applied';

CREATE DATABASE IF NOT EXISTS MDF_STAGING_DB
    COMMENT = 'Staging layer: cleaned, validated, and de-duplicated data';

CREATE DATABASE IF NOT EXISTS MDF_CURATED_DB
    COMMENT = 'Curated layer: business-ready, transformed, and aggregated data';

-- STEP 4: CREATE DEFAULT SCHEMAS IN DATA DATABASES
CREATE SCHEMA IF NOT EXISTS MDF_RAW_DB.SHARED
    COMMENT = 'Shared raw schema for cross-client or reference data';

CREATE SCHEMA IF NOT EXISTS MDF_STAGING_DB.SHARED
    COMMENT = 'Shared staging schema for cross-client or reference data';

CREATE SCHEMA IF NOT EXISTS MDF_CURATED_DB.SHARED
    COMMENT = 'Shared curated schema for cross-client or reference data';

-- VERIFICATION: Databases & Schemas
SHOW DATABASES LIKE 'MDF_%';
SHOW SCHEMAS IN DATABASE MDF_CONTROL_DB;
SHOW SCHEMAS IN DATABASE MDF_RAW_DB;
SHOW SCHEMAS IN DATABASE MDF_STAGING_DB;
SHOW SCHEMAS IN DATABASE MDF_CURATED_DB;


-- ===========================================================================
-- ███████████████████████████████████████████████████████████████████████████
-- PART 2 OF 3: WAREHOUSES (COMPUTE)
-- ███████████████████████████████████████████████████████████████████████████
-- ===========================================================================

/*
  WHY SEPARATE WAREHOUSES:
  ┌────────────────────────────────────────────────────────────┐
  │  MDF_INGESTION_WH   → COPY INTO operations (I/O heavy)    │
  │  MDF_TRANSFORM_WH   → Staging transforms (compute heavy)  │
  │  MDF_MONITORING_WH   → Dashboard queries (lightweight)     │
  │  MDF_ADMIN_WH        → Procedure execution, maintenance    │
  └────────────────────────────────────────────────────────────┘
*/

USE ROLE SYSADMIN;

-- Ingestion Warehouse
CREATE WAREHOUSE IF NOT EXISTS MDF_INGESTION_WH
    WITH
        WAREHOUSE_SIZE      = 'SMALL'
        AUTO_SUSPEND        = 60
        AUTO_RESUME         = TRUE
        MIN_CLUSTER_COUNT   = 1
        MAX_CLUSTER_COUNT   = 2
        SCALING_POLICY      = 'STANDARD'
        INITIALLY_SUSPENDED = TRUE
        COMMENT             = 'MDF: Ingestion warehouse for COPY INTO operations';

-- Transform Warehouse
CREATE WAREHOUSE IF NOT EXISTS MDF_TRANSFORM_WH
    WITH
        WAREHOUSE_SIZE      = 'MEDIUM'
        AUTO_SUSPEND        = 120
        AUTO_RESUME         = TRUE
        MIN_CLUSTER_COUNT   = 1
        MAX_CLUSTER_COUNT   = 1
        SCALING_POLICY      = 'STANDARD'
        INITIALLY_SUSPENDED = TRUE
        COMMENT             = 'MDF: Transform warehouse for staging-to-curated processing';

-- Monitoring Warehouse
CREATE WAREHOUSE IF NOT EXISTS MDF_MONITORING_WH
    WITH
        WAREHOUSE_SIZE      = 'XSMALL'
        AUTO_SUSPEND        = 60
        AUTO_RESUME         = TRUE
        MIN_CLUSTER_COUNT   = 1
        MAX_CLUSTER_COUNT   = 1
        INITIALLY_SUSPENDED = TRUE
        COMMENT             = 'MDF: Monitoring warehouse for dashboard and health check queries';

-- Admin Warehouse
CREATE WAREHOUSE IF NOT EXISTS MDF_ADMIN_WH
    WITH
        WAREHOUSE_SIZE      = 'SMALL'
        AUTO_SUSPEND        = 60
        AUTO_RESUME         = TRUE
        MIN_CLUSTER_COUNT   = 1
        MAX_CLUSTER_COUNT   = 1
        INITIALLY_SUSPENDED = TRUE
        COMMENT             = 'MDF: Admin warehouse for stored procedures and maintenance';

-- RESOURCE MONITORS
USE ROLE ACCOUNTADMIN;

CREATE OR REPLACE RESOURCE MONITOR MDF_INGESTION_MONITOR
    WITH
        CREDIT_QUOTA = 100
        FREQUENCY    = MONTHLY
        START_TIMESTAMP = IMMEDIATELY
        TRIGGERS
            ON 75 PERCENT DO NOTIFY
            ON 90 PERCENT DO NOTIFY
            ON 100 PERCENT DO SUSPEND
            ON 110 PERCENT DO SUSPEND_IMMEDIATE;

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

ALTER WAREHOUSE MDF_INGESTION_WH SET RESOURCE_MONITOR = MDF_INGESTION_MONITOR;
ALTER WAREHOUSE MDF_TRANSFORM_WH SET RESOURCE_MONITOR = MDF_TRANSFORM_MONITOR;

-- VERIFICATION: Warehouses
SHOW WAREHOUSES LIKE 'MDF_%';
SHOW RESOURCE MONITORS LIKE 'MDF_%';


-- ===========================================================================
-- ███████████████████████████████████████████████████████████████████████████
-- PART 3 OF 3: ROLES & GRANTS (RBAC)
-- ███████████████████████████████████████████████████████████████████████████
-- ===========================================================================

/*
  ROLE HIERARCHY:
  ┌─────────────────────────────────────────────────────────┐
  │                    ACCOUNTADMIN                          │
  │                         │                                │
  │                    SYSADMIN                               │
  │                    ┌────┴─────┐                           │
  │              MDF_ADMIN    MDF_DEVELOPER                   │
  │              ┌────┴────┐       │                          │
  │        MDF_LOADER  MDF_TRANSFORMER                       │
  │              │         │                                  │
  │         MDF_READER ────┘                                  │
  └─────────────────────────────────────────────────────────┘
*/

USE ROLE SECURITYADMIN;

-- Create roles
CREATE ROLE IF NOT EXISTS MDF_ADMIN
    COMMENT = 'MDF: Full admin access to all framework objects';
CREATE ROLE IF NOT EXISTS MDF_DEVELOPER
    COMMENT = 'MDF: Developer access for procedure and config changes';
CREATE ROLE IF NOT EXISTS MDF_LOADER
    COMMENT = 'MDF: Service role for data ingestion (COPY INTO)';
CREATE ROLE IF NOT EXISTS MDF_TRANSFORMER
    COMMENT = 'MDF: Service role for staging-to-curated transforms';
CREATE ROLE IF NOT EXISTS MDF_READER
    COMMENT = 'MDF: Read-only access to curated data and monitoring';

-- Build the role hierarchy
GRANT ROLE MDF_READER      TO ROLE MDF_LOADER;
GRANT ROLE MDF_READER      TO ROLE MDF_TRANSFORMER;
GRANT ROLE MDF_LOADER      TO ROLE MDF_ADMIN;
GRANT ROLE MDF_TRANSFORMER TO ROLE MDF_ADMIN;
GRANT ROLE MDF_DEVELOPER   TO ROLE MDF_ADMIN;
GRANT ROLE MDF_ADMIN       TO ROLE SYSADMIN;

-- Database-level grants
GRANT ALL PRIVILEGES ON DATABASE MDF_CONTROL_DB TO ROLE MDF_ADMIN;
GRANT ALL PRIVILEGES ON DATABASE MDF_RAW_DB     TO ROLE MDF_ADMIN;
GRANT ALL PRIVILEGES ON DATABASE MDF_STAGING_DB TO ROLE MDF_ADMIN;
GRANT ALL PRIVILEGES ON DATABASE MDF_CURATED_DB TO ROLE MDF_ADMIN;

GRANT USAGE ON DATABASE MDF_CONTROL_DB TO ROLE MDF_DEVELOPER;
GRANT USAGE ON DATABASE MDF_RAW_DB     TO ROLE MDF_DEVELOPER;
GRANT USAGE ON DATABASE MDF_STAGING_DB TO ROLE MDF_DEVELOPER;
GRANT USAGE ON DATABASE MDF_CURATED_DB TO ROLE MDF_DEVELOPER;

GRANT USAGE ON DATABASE MDF_CONTROL_DB TO ROLE MDF_LOADER;
GRANT USAGE ON DATABASE MDF_RAW_DB     TO ROLE MDF_LOADER;

GRANT USAGE ON DATABASE MDF_RAW_DB     TO ROLE MDF_TRANSFORMER;
GRANT USAGE ON DATABASE MDF_STAGING_DB TO ROLE MDF_TRANSFORMER;
GRANT USAGE ON DATABASE MDF_CURATED_DB TO ROLE MDF_TRANSFORMER;

GRANT USAGE ON DATABASE MDF_CURATED_DB  TO ROLE MDF_READER;
GRANT USAGE ON DATABASE MDF_CONTROL_DB  TO ROLE MDF_READER;

-- Schema-level grants
GRANT ALL PRIVILEGES ON ALL SCHEMAS IN DATABASE MDF_CONTROL_DB TO ROLE MDF_ADMIN;
GRANT ALL PRIVILEGES ON ALL SCHEMAS IN DATABASE MDF_RAW_DB     TO ROLE MDF_ADMIN;
GRANT ALL PRIVILEGES ON ALL SCHEMAS IN DATABASE MDF_STAGING_DB TO ROLE MDF_ADMIN;
GRANT ALL PRIVILEGES ON ALL SCHEMAS IN DATABASE MDF_CURATED_DB TO ROLE MDF_ADMIN;

GRANT ALL PRIVILEGES ON FUTURE SCHEMAS IN DATABASE MDF_RAW_DB     TO ROLE MDF_ADMIN;
GRANT ALL PRIVILEGES ON FUTURE SCHEMAS IN DATABASE MDF_STAGING_DB TO ROLE MDF_ADMIN;
GRANT ALL PRIVILEGES ON FUTURE SCHEMAS IN DATABASE MDF_CURATED_DB TO ROLE MDF_ADMIN;

GRANT USAGE ON SCHEMA MDF_CONTROL_DB.CONFIG     TO ROLE MDF_LOADER;
GRANT USAGE ON SCHEMA MDF_CONTROL_DB.AUDIT      TO ROLE MDF_LOADER;
GRANT USAGE ON SCHEMA MDF_CONTROL_DB.PROCEDURES TO ROLE MDF_LOADER;
GRANT USAGE ON ALL SCHEMAS IN DATABASE MDF_RAW_DB TO ROLE MDF_LOADER;
GRANT USAGE ON FUTURE SCHEMAS IN DATABASE MDF_RAW_DB TO ROLE MDF_LOADER;

GRANT USAGE ON ALL SCHEMAS IN DATABASE MDF_RAW_DB     TO ROLE MDF_TRANSFORMER;
GRANT USAGE ON ALL SCHEMAS IN DATABASE MDF_STAGING_DB  TO ROLE MDF_TRANSFORMER;
GRANT USAGE ON ALL SCHEMAS IN DATABASE MDF_CURATED_DB  TO ROLE MDF_TRANSFORMER;
GRANT USAGE ON FUTURE SCHEMAS IN DATABASE MDF_RAW_DB     TO ROLE MDF_TRANSFORMER;
GRANT USAGE ON FUTURE SCHEMAS IN DATABASE MDF_STAGING_DB  TO ROLE MDF_TRANSFORMER;
GRANT USAGE ON FUTURE SCHEMAS IN DATABASE MDF_CURATED_DB  TO ROLE MDF_TRANSFORMER;

GRANT USAGE ON SCHEMA MDF_CURATED_DB.SHARED        TO ROLE MDF_READER;
GRANT USAGE ON SCHEMA MDF_CONTROL_DB.MONITORING    TO ROLE MDF_READER;

-- Table-level grants (with future grants)
GRANT SELECT ON ALL TABLES IN SCHEMA MDF_CONTROL_DB.CONFIG     TO ROLE MDF_LOADER;
GRANT SELECT ON FUTURE TABLES IN SCHEMA MDF_CONTROL_DB.CONFIG  TO ROLE MDF_LOADER;
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA MDF_CONTROL_DB.AUDIT    TO ROLE MDF_LOADER;
GRANT INSERT, UPDATE ON FUTURE TABLES IN SCHEMA MDF_CONTROL_DB.AUDIT TO ROLE MDF_LOADER;
GRANT ALL PRIVILEGES ON FUTURE TABLES IN DATABASE MDF_RAW_DB   TO ROLE MDF_LOADER;

GRANT SELECT ON FUTURE TABLES IN DATABASE MDF_RAW_DB      TO ROLE MDF_TRANSFORMER;
GRANT ALL PRIVILEGES ON FUTURE TABLES IN DATABASE MDF_STAGING_DB TO ROLE MDF_TRANSFORMER;
GRANT ALL PRIVILEGES ON FUTURE TABLES IN DATABASE MDF_CURATED_DB TO ROLE MDF_TRANSFORMER;

GRANT SELECT ON FUTURE TABLES IN DATABASE MDF_CURATED_DB  TO ROLE MDF_READER;
GRANT SELECT ON ALL VIEWS IN SCHEMA MDF_CONTROL_DB.MONITORING    TO ROLE MDF_READER;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA MDF_CONTROL_DB.MONITORING TO ROLE MDF_READER;

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA MDF_CONTROL_DB.CONFIG TO ROLE MDF_DEVELOPER;
GRANT SELECT, INSERT, UPDATE, DELETE ON FUTURE TABLES IN SCHEMA MDF_CONTROL_DB.CONFIG TO ROLE MDF_DEVELOPER;
GRANT USAGE ON ALL PROCEDURES IN SCHEMA MDF_CONTROL_DB.PROCEDURES TO ROLE MDF_DEVELOPER;
GRANT USAGE ON FUTURE PROCEDURES IN SCHEMA MDF_CONTROL_DB.PROCEDURES TO ROLE MDF_DEVELOPER;

-- Warehouse grants
GRANT ALL PRIVILEGES ON WAREHOUSE MDF_INGESTION_WH  TO ROLE MDF_ADMIN;
GRANT ALL PRIVILEGES ON WAREHOUSE MDF_TRANSFORM_WH  TO ROLE MDF_ADMIN;
GRANT ALL PRIVILEGES ON WAREHOUSE MDF_MONITORING_WH  TO ROLE MDF_ADMIN;
GRANT ALL PRIVILEGES ON WAREHOUSE MDF_ADMIN_WH       TO ROLE MDF_ADMIN;

GRANT USAGE, OPERATE ON WAREHOUSE MDF_INGESTION_WH TO ROLE MDF_LOADER;
GRANT USAGE, OPERATE ON WAREHOUSE MDF_TRANSFORM_WH TO ROLE MDF_TRANSFORMER;
GRANT USAGE ON WAREHOUSE MDF_MONITORING_WH TO ROLE MDF_READER;
GRANT USAGE, OPERATE ON WAREHOUSE MDF_ADMIN_WH TO ROLE MDF_DEVELOPER;

-- Stage and file format grants
GRANT USAGE ON ALL STAGES IN SCHEMA MDF_CONTROL_DB.CONFIG TO ROLE MDF_LOADER;
GRANT USAGE ON FUTURE STAGES IN SCHEMA MDF_CONTROL_DB.CONFIG TO ROLE MDF_LOADER;
GRANT USAGE ON ALL FILE FORMATS IN SCHEMA MDF_CONTROL_DB.CONFIG TO ROLE MDF_LOADER;
GRANT USAGE ON FUTURE FILE FORMATS IN SCHEMA MDF_CONTROL_DB.CONFIG TO ROLE MDF_LOADER;

-- VERIFICATION: Roles & Grants
SHOW ROLES LIKE 'MDF_%';
SHOW GRANTS TO ROLE MDF_ADMIN;
SHOW GRANTS TO ROLE MDF_LOADER;
SHOW GRANTS TO ROLE MDF_READER;
SHOW GRANTS ON DATABASE MDF_CONTROL_DB;
SHOW GRANTS ON DATABASE MDF_RAW_DB;


/*
#############################################################################
  MODULE 01 COMPLETE!

  Objects Created:
    - 4 databases: MDF_CONTROL_DB, MDF_RAW_DB, MDF_STAGING_DB, MDF_CURATED_DB
    - 4 schemas in MDF_CONTROL_DB: CONFIG, AUDIT, PROCEDURES, MONITORING
    - 3 SHARED schemas in data databases
    - 4 warehouses: MDF_INGESTION_WH, MDF_TRANSFORM_WH, MDF_MONITORING_WH, MDF_ADMIN_WH
    - 2 resource monitors: MDF_INGESTION_MONITOR, MDF_TRANSFORM_MONITOR
    - 5 roles: MDF_ADMIN, MDF_DEVELOPER, MDF_LOADER, MDF_TRANSFORMER, MDF_READER
    - Full RBAC hierarchy with future grants

  Next: MDF - Module 02 (File Formats & Stages)
#############################################################################
*/
