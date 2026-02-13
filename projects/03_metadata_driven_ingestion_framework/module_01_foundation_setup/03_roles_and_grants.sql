/*
=============================================================================
  MODULE 01 : FOUNDATION SETUP
  SCRIPT 03 : Roles & Grants (RBAC)
=============================================================================
  SNOWBRIX ACADEMY — Metadata-Driven Ingestion Framework (MDF)

  LEARNING OBJECTIVES:
    1. Design a role hierarchy for the ingestion framework
    2. Create functional roles (not user-based roles)
    3. Apply least-privilege access principle
    4. Understand Snowflake's RBAC inheritance model

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

  ROLE DEFINITIONS:
    MDF_ADMIN       → Full control over MDF framework objects
    MDF_DEVELOPER   → Can modify procedures, configs (for development)
    MDF_LOADER      → Can execute COPY INTO, write to RAW
    MDF_TRANSFORMER → Can read RAW, write to STAGING/CURATED
    MDF_READER      → Read-only access to CURATED and MONITORING
=============================================================================
*/

USE ROLE SECURITYADMIN;

-- =========================================================================
-- STEP 1: CREATE FUNCTIONAL ROLES
-- =========================================================================
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

-- =========================================================================
-- STEP 2: BUILD THE ROLE HIERARCHY
-- Child roles inherit all privileges of their parent.
-- =========================================================================
GRANT ROLE MDF_READER      TO ROLE MDF_LOADER;
GRANT ROLE MDF_READER      TO ROLE MDF_TRANSFORMER;
GRANT ROLE MDF_LOADER      TO ROLE MDF_ADMIN;
GRANT ROLE MDF_TRANSFORMER TO ROLE MDF_ADMIN;
GRANT ROLE MDF_DEVELOPER   TO ROLE MDF_ADMIN;
GRANT ROLE MDF_ADMIN       TO ROLE SYSADMIN;

-- =========================================================================
-- STEP 3: DATABASE-LEVEL GRANTS
-- =========================================================================

-- MDF_ADMIN: Full control on all MDF databases
GRANT ALL PRIVILEGES ON DATABASE MDF_CONTROL_DB TO ROLE MDF_ADMIN;
GRANT ALL PRIVILEGES ON DATABASE MDF_RAW_DB     TO ROLE MDF_ADMIN;
GRANT ALL PRIVILEGES ON DATABASE MDF_STAGING_DB TO ROLE MDF_ADMIN;
GRANT ALL PRIVILEGES ON DATABASE MDF_CURATED_DB TO ROLE MDF_ADMIN;

-- MDF_DEVELOPER: Usage on control DB, read on data DBs
GRANT USAGE ON DATABASE MDF_CONTROL_DB TO ROLE MDF_DEVELOPER;
GRANT USAGE ON DATABASE MDF_RAW_DB     TO ROLE MDF_DEVELOPER;
GRANT USAGE ON DATABASE MDF_STAGING_DB TO ROLE MDF_DEVELOPER;
GRANT USAGE ON DATABASE MDF_CURATED_DB TO ROLE MDF_DEVELOPER;

-- MDF_LOADER: Usage on control + write on raw
GRANT USAGE ON DATABASE MDF_CONTROL_DB TO ROLE MDF_LOADER;
GRANT USAGE ON DATABASE MDF_RAW_DB     TO ROLE MDF_LOADER;

-- MDF_TRANSFORMER: Read raw, write staging/curated
GRANT USAGE ON DATABASE MDF_RAW_DB     TO ROLE MDF_TRANSFORMER;
GRANT USAGE ON DATABASE MDF_STAGING_DB TO ROLE MDF_TRANSFORMER;
GRANT USAGE ON DATABASE MDF_CURATED_DB TO ROLE MDF_TRANSFORMER;

-- MDF_READER: Read curated + monitoring only
GRANT USAGE ON DATABASE MDF_CURATED_DB  TO ROLE MDF_READER;
GRANT USAGE ON DATABASE MDF_CONTROL_DB  TO ROLE MDF_READER;

-- =========================================================================
-- STEP 4: SCHEMA-LEVEL GRANTS
-- =========================================================================

-- MDF_ADMIN: All schemas
GRANT ALL PRIVILEGES ON ALL SCHEMAS IN DATABASE MDF_CONTROL_DB TO ROLE MDF_ADMIN;
GRANT ALL PRIVILEGES ON ALL SCHEMAS IN DATABASE MDF_RAW_DB     TO ROLE MDF_ADMIN;
GRANT ALL PRIVILEGES ON ALL SCHEMAS IN DATABASE MDF_STAGING_DB TO ROLE MDF_ADMIN;
GRANT ALL PRIVILEGES ON ALL SCHEMAS IN DATABASE MDF_CURATED_DB TO ROLE MDF_ADMIN;

-- Future schemas (so new schemas auto-inherit grants)
GRANT ALL PRIVILEGES ON FUTURE SCHEMAS IN DATABASE MDF_RAW_DB     TO ROLE MDF_ADMIN;
GRANT ALL PRIVILEGES ON FUTURE SCHEMAS IN DATABASE MDF_STAGING_DB TO ROLE MDF_ADMIN;
GRANT ALL PRIVILEGES ON FUTURE SCHEMAS IN DATABASE MDF_CURATED_DB TO ROLE MDF_ADMIN;

-- MDF_LOADER: Config read + Raw write
GRANT USAGE ON SCHEMA MDF_CONTROL_DB.CONFIG     TO ROLE MDF_LOADER;
GRANT USAGE ON SCHEMA MDF_CONTROL_DB.AUDIT      TO ROLE MDF_LOADER;
GRANT USAGE ON SCHEMA MDF_CONTROL_DB.PROCEDURES TO ROLE MDF_LOADER;
GRANT USAGE ON ALL SCHEMAS IN DATABASE MDF_RAW_DB TO ROLE MDF_LOADER;
GRANT USAGE ON FUTURE SCHEMAS IN DATABASE MDF_RAW_DB TO ROLE MDF_LOADER;

-- MDF_TRANSFORMER: Raw read + Staging/Curated write
GRANT USAGE ON ALL SCHEMAS IN DATABASE MDF_RAW_DB     TO ROLE MDF_TRANSFORMER;
GRANT USAGE ON ALL SCHEMAS IN DATABASE MDF_STAGING_DB  TO ROLE MDF_TRANSFORMER;
GRANT USAGE ON ALL SCHEMAS IN DATABASE MDF_CURATED_DB  TO ROLE MDF_TRANSFORMER;
GRANT USAGE ON FUTURE SCHEMAS IN DATABASE MDF_RAW_DB     TO ROLE MDF_TRANSFORMER;
GRANT USAGE ON FUTURE SCHEMAS IN DATABASE MDF_STAGING_DB  TO ROLE MDF_TRANSFORMER;
GRANT USAGE ON FUTURE SCHEMAS IN DATABASE MDF_CURATED_DB  TO ROLE MDF_TRANSFORMER;

-- MDF_READER: Curated read + Monitoring read
GRANT USAGE ON SCHEMA MDF_CURATED_DB.SHARED        TO ROLE MDF_READER;
GRANT USAGE ON SCHEMA MDF_CONTROL_DB.MONITORING    TO ROLE MDF_READER;

-- =========================================================================
-- STEP 5: TABLE-LEVEL GRANTS (Future grants for auto-inheritance)
-- =========================================================================

-- MDF_LOADER: Read config tables, write audit tables, write raw tables
GRANT SELECT ON ALL TABLES IN SCHEMA MDF_CONTROL_DB.CONFIG     TO ROLE MDF_LOADER;
GRANT SELECT ON FUTURE TABLES IN SCHEMA MDF_CONTROL_DB.CONFIG  TO ROLE MDF_LOADER;
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA MDF_CONTROL_DB.AUDIT    TO ROLE MDF_LOADER;
GRANT INSERT, UPDATE ON FUTURE TABLES IN SCHEMA MDF_CONTROL_DB.AUDIT TO ROLE MDF_LOADER;
GRANT ALL PRIVILEGES ON FUTURE TABLES IN DATABASE MDF_RAW_DB   TO ROLE MDF_LOADER;

-- MDF_TRANSFORMER: Read raw, write staging/curated
GRANT SELECT ON FUTURE TABLES IN DATABASE MDF_RAW_DB      TO ROLE MDF_TRANSFORMER;
GRANT ALL PRIVILEGES ON FUTURE TABLES IN DATABASE MDF_STAGING_DB TO ROLE MDF_TRANSFORMER;
GRANT ALL PRIVILEGES ON FUTURE TABLES IN DATABASE MDF_CURATED_DB TO ROLE MDF_TRANSFORMER;

-- MDF_READER: Read curated and monitoring
GRANT SELECT ON FUTURE TABLES IN DATABASE MDF_CURATED_DB  TO ROLE MDF_READER;
GRANT SELECT ON ALL VIEWS IN SCHEMA MDF_CONTROL_DB.MONITORING    TO ROLE MDF_READER;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA MDF_CONTROL_DB.MONITORING TO ROLE MDF_READER;

-- MDF_DEVELOPER: Config read/write + Procedure usage
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA MDF_CONTROL_DB.CONFIG TO ROLE MDF_DEVELOPER;
GRANT SELECT, INSERT, UPDATE, DELETE ON FUTURE TABLES IN SCHEMA MDF_CONTROL_DB.CONFIG TO ROLE MDF_DEVELOPER;
GRANT USAGE ON ALL PROCEDURES IN SCHEMA MDF_CONTROL_DB.PROCEDURES TO ROLE MDF_DEVELOPER;
GRANT USAGE ON FUTURE PROCEDURES IN SCHEMA MDF_CONTROL_DB.PROCEDURES TO ROLE MDF_DEVELOPER;

-- =========================================================================
-- STEP 6: WAREHOUSE GRANTS
-- =========================================================================

-- MDF_ADMIN: All warehouses
GRANT ALL PRIVILEGES ON WAREHOUSE MDF_INGESTION_WH  TO ROLE MDF_ADMIN;
GRANT ALL PRIVILEGES ON WAREHOUSE MDF_TRANSFORM_WH  TO ROLE MDF_ADMIN;
GRANT ALL PRIVILEGES ON WAREHOUSE MDF_MONITORING_WH  TO ROLE MDF_ADMIN;
GRANT ALL PRIVILEGES ON WAREHOUSE MDF_ADMIN_WH       TO ROLE MDF_ADMIN;

-- MDF_LOADER: Ingestion warehouse only
GRANT USAGE, OPERATE ON WAREHOUSE MDF_INGESTION_WH TO ROLE MDF_LOADER;

-- MDF_TRANSFORMER: Transform warehouse only
GRANT USAGE, OPERATE ON WAREHOUSE MDF_TRANSFORM_WH TO ROLE MDF_TRANSFORMER;

-- MDF_READER: Monitoring warehouse only
GRANT USAGE ON WAREHOUSE MDF_MONITORING_WH TO ROLE MDF_READER;

-- MDF_DEVELOPER: Admin warehouse
GRANT USAGE, OPERATE ON WAREHOUSE MDF_ADMIN_WH TO ROLE MDF_DEVELOPER;

-- =========================================================================
-- STEP 7: STAGE AND FILE FORMAT GRANTS
-- =========================================================================

-- MDF_LOADER needs to read from stages
GRANT USAGE ON ALL STAGES IN SCHEMA MDF_CONTROL_DB.CONFIG TO ROLE MDF_LOADER;
GRANT USAGE ON FUTURE STAGES IN SCHEMA MDF_CONTROL_DB.CONFIG TO ROLE MDF_LOADER;

-- MDF_LOADER needs to use file formats
GRANT USAGE ON ALL FILE FORMATS IN SCHEMA MDF_CONTROL_DB.CONFIG TO ROLE MDF_LOADER;
GRANT USAGE ON FUTURE FILE FORMATS IN SCHEMA MDF_CONTROL_DB.CONFIG TO ROLE MDF_LOADER;


-- =========================================================================
-- VERIFICATION QUERIES
-- =========================================================================

-- Show all MDF roles
SHOW ROLES LIKE 'MDF_%';

-- Verify role hierarchy
SHOW GRANTS TO ROLE MDF_ADMIN;
SHOW GRANTS TO ROLE MDF_LOADER;
SHOW GRANTS TO ROLE MDF_READER;

-- Verify database grants
SHOW GRANTS ON DATABASE MDF_CONTROL_DB;
SHOW GRANTS ON DATABASE MDF_RAW_DB;


/*
=============================================================================
  BEST PRACTICES & TIPS:

  1. FUNCTIONAL ROLES, NOT USER ROLES: Create roles based on what they DO,
     not who they ARE. "MDF_LOADER" is better than "JOHN_ROLE" because when
     John leaves, the role still makes sense.

  2. FUTURE GRANTS ARE CRITICAL: Without GRANT ... ON FUTURE ..., every new
     table, view, or procedure requires manual grant updates. Future grants
     ensure new objects auto-inherit the right permissions.

  3. LEAST PRIVILEGE: The loader role can only write to RAW. It cannot touch
     STAGING or CURATED. If the ingestion process is compromised, the blast
     radius is limited to raw data only.

  4. SERVICE ACCOUNTS: In production, create a dedicated user (e.g.,
     MDF_SERVICE_USER) with the MDF_LOADER role. Never use personal accounts
     for automated ingestion.

  5. GRANT OWNERSHIP CAREFULLY: OWNERSHIP grants are powerful — the owner
     can drop objects. Only MDF_ADMIN should own framework objects.

  MODULE 01 COMPLETE!
  → Next: Module 02 — File Formats & Stages
=============================================================================
*/
