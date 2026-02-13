/*
=============================================================================
  UTILITIES : QUICK START — Run All Modules in Sequence
=============================================================================
  This script runs all modules in the correct order for a fresh setup.
  Execute each section one at a time to understand what's happening.

  TOTAL SETUP TIME: ~15 minutes

  EXECUTION ORDER:
    1. Module 01: Foundation (databases, warehouses, roles)
    2. Module 02: File formats & stages
    3. Module 03: Config tables & sample data
    4. Module 04: Stored procedures
    5. Modules 05-10: Labs (run individually)
=============================================================================
*/

-- =============================================
-- PHASE 1: FOUNDATION SETUP
-- Run: module_01_foundation_setup/01_databases_and_schemas.sql
-- Run: module_01_foundation_setup/02_warehouses.sql
-- Run: module_01_foundation_setup/03_roles_and_grants.sql
-- =============================================

-- =============================================
-- PHASE 2: FILE FORMATS & STAGES
-- Run: module_02_file_formats_and_stages/01_file_formats.sql
-- Run: module_02_file_formats_and_stages/02_stages.sql
-- =============================================

-- =============================================
-- PHASE 3: CONFIG TABLES
-- Run: module_03_config_tables/01_ingestion_config.sql
-- Run: module_03_config_tables/02_audit_and_supporting_tables.sql
-- =============================================

-- =============================================
-- PHASE 4: STORED PROCEDURES
-- Run: module_04_core_stored_procedures/01_sp_audit_log.sql
-- Run: module_04_core_stored_procedures/02_sp_generic_ingestion.sql
-- Run: module_04_core_stored_procedures/03_sp_register_source.sql
-- =============================================

-- =============================================
-- PHASE 5: MONITORING VIEWS
-- Run: module_09_monitoring_and_dashboards/01_monitoring_views.sql
-- =============================================

-- =============================================
-- PHASE 6: AUTOMATION (Optional)
-- Run: module_08_automation_tasks_streams/01_tasks_and_scheduling.sql
-- =============================================

-- =============================================
-- PHASE 7: ADVANCED (Optional)
-- Run: module_07_error_handling_and_audit/01_error_handling_lab.sql
-- Run: module_10_schema_evolution_advanced/01_schema_evolution.sql
-- =============================================


-- =============================================
-- QUICK VERIFICATION: After running all phases
-- =============================================
-- Databases
SHOW DATABASES LIKE 'MDF_%';

-- Warehouses
SHOW WAREHOUSES LIKE 'MDF_%';

-- Roles
SHOW ROLES LIKE 'MDF_%';

-- Config entries
SELECT COUNT(*) AS CONFIG_COUNT FROM MDF_CONTROL_DB.CONFIG.INGESTION_CONFIG;

-- File formats
SHOW FILE FORMATS IN SCHEMA MDF_CONTROL_DB.CONFIG;

-- Stages
SHOW STAGES IN SCHEMA MDF_CONTROL_DB.CONFIG;

-- Procedures
SHOW PROCEDURES IN SCHEMA MDF_CONTROL_DB.PROCEDURES;

-- Monitoring views
SHOW VIEWS IN SCHEMA MDF_CONTROL_DB.MONITORING;

-- Success!
SELECT '🏗️ MDF Framework setup complete!' AS STATUS;
