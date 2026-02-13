/*
=============================================================================
  MODULE 01 : FOUNDATION SETUP
  SCRIPT 01 : Databases & Schemas
=============================================================================
  SNOWBRIX ACADEMY — Metadata-Driven Ingestion Framework (MDF)

  LEARNING OBJECTIVES:
    1. Understand the multi-layer architecture (RAW → STAGING → CURATED)
    2. Create the MDF control database that houses all framework objects
    3. Create the data layer databases for client data
    4. Understand schema separation: framework vs. data

  PREREQUISITES:
    - ACCOUNTADMIN or SYSADMIN role access
    - Basic understanding of Snowflake databases and schemas

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
=============================================================================
*/

-- =========================================================================
-- STEP 1: USE ACCOUNTADMIN ROLE (Required for initial setup)
-- =========================================================================
USE ROLE ACCOUNTADMIN;

-- =========================================================================
-- STEP 2: CREATE THE MDF CONTROL DATABASE
-- This is the "brain" of the framework. It stores all configuration,
-- metadata, audit logs, and stored procedures.
-- =========================================================================
CREATE DATABASE IF NOT EXISTS MDF_CONTROL_DB
    COMMENT = 'Metadata-Driven Framework: Control database housing all framework objects, configs, and procedures';

-- Control schemas
CREATE SCHEMA IF NOT EXISTS MDF_CONTROL_DB.CONFIG
    COMMENT = 'Configuration tables: ingestion configs, file format registry, stage registry';

CREATE SCHEMA IF NOT EXISTS MDF_CONTROL_DB.AUDIT
    COMMENT = 'Audit and logging: ingestion run history, error logs, data quality results';

CREATE SCHEMA IF NOT EXISTS MDF_CONTROL_DB.PROCEDURES
    COMMENT = 'All stored procedures for the ingestion framework';

CREATE SCHEMA IF NOT EXISTS MDF_CONTROL_DB.MONITORING
    COMMENT = 'Monitoring views, dashboard queries, and alerting objects';

-- =========================================================================
-- STEP 3: CREATE THE DATA LAYER DATABASES
-- These hold the actual data at different stages of processing.
-- The 3-layer approach ensures:
--   RAW      → Exact copy of source data (immutable landing zone)
--   STAGING  → Cleaned, validated, de-duplicated
--   CURATED  → Business-ready, transformed, aggregated
-- =========================================================================
CREATE DATABASE IF NOT EXISTS MDF_RAW_DB
    COMMENT = 'Raw data landing zone: exact copy of source files, no transformations applied';

CREATE DATABASE IF NOT EXISTS MDF_STAGING_DB
    COMMENT = 'Staging layer: cleaned, validated, and de-duplicated data';

CREATE DATABASE IF NOT EXISTS MDF_CURATED_DB
    COMMENT = 'Curated layer: business-ready, transformed, and aggregated data';

-- =========================================================================
-- STEP 4: CREATE DEFAULT SCHEMAS IN DATA DATABASES
-- We create a PUBLIC schema and a SHARED schema in each.
-- Client-specific schemas will be created dynamically by the framework.
-- =========================================================================

-- RAW DB default schemas
CREATE SCHEMA IF NOT EXISTS MDF_RAW_DB.SHARED
    COMMENT = 'Shared raw schema for cross-client or reference data';

-- STAGING DB default schemas
CREATE SCHEMA IF NOT EXISTS MDF_STAGING_DB.SHARED
    COMMENT = 'Shared staging schema for cross-client or reference data';

-- CURATED DB default schemas
CREATE SCHEMA IF NOT EXISTS MDF_CURATED_DB.SHARED
    COMMENT = 'Shared curated schema for cross-client or reference data';


-- =========================================================================
-- VERIFICATION QUERIES
-- Run these to confirm everything was created correctly.
-- =========================================================================

-- List all MDF databases
SHOW DATABASES LIKE 'MDF_%';

-- List schemas in control database
SHOW SCHEMAS IN DATABASE MDF_CONTROL_DB;

-- List schemas in data databases
SHOW SCHEMAS IN DATABASE MDF_RAW_DB;
SHOW SCHEMAS IN DATABASE MDF_STAGING_DB;
SHOW SCHEMAS IN DATABASE MDF_CURATED_DB;


/*
=============================================================================
  BEST PRACTICES & TIPS:

  1. NAMING CONVENTION: All MDF objects use the MDF_ prefix to avoid
     conflicts with existing objects in your Snowflake account.

  2. IMMUTABLE RAW LAYER: Never transform data in the RAW database.
     If something goes wrong downstream, you can always re-process
     from the original source data.

  3. SCHEMA-PER-SOURCE: Each data source gets its own schema in RAW
     and STAGING. This provides natural isolation and makes RBAC
     simple (grant access per schema = grant access per source).

  4. CONTROL DB IS SACRED: Only the framework's service account and
     admins should have write access to MDF_CONTROL_DB. Regular users
     should only read from MONITORING views.

  WHAT'S NEXT:
  → Module 01, Script 02: Warehouses (compute sizing for ingestion)
  → Module 01, Script 03: Roles & Grants (RBAC for the framework)
=============================================================================
*/
