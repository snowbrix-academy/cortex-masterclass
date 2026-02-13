/*
=============================================================================
  UTILITIES : QUICK START — Run All Modules in Sequence
=============================================================================
  SNOWBRIX ACADEMY — Enterprise FinOps Dashboard for Snowflake

  This script provides a guided walkthrough to set up the complete FinOps
  framework from scratch. Execute each section one at a time to understand
  what's happening at each step.

  TOTAL SETUP TIME: ~20 minutes

  EXECUTION ORDER:
    1. Module 01: Foundation (databases, warehouses, roles)
    2. Module 02: Cost collection (tables, procedures)
    3. Module 03: Chargeback attribution (dimensions, procedures)
    4. Module 04: Budget controls (budgets, alerts)
    5. Module 05: BI tool detection
    6. Module 06: Optimization recommendations
    7. Module 07: Monitoring views
    8. Module 08: Automation (tasks)

  PREREQUISITES:
    - ACCOUNTADMIN or SYSADMIN role access
    - Basic understanding of Snowflake cost model

=============================================================================
*/

-- =============================================
-- PHASE 1: FOUNDATION SETUP (5 minutes)
-- =============================================
SELECT '🏗️  PHASE 1: Foundation Setup' AS STATUS;
SELECT 'Creating databases, warehouses, and roles...' AS INFO;

-- Run: module_01_foundation_setup/01_databases_and_schemas.sql
-- Run: module_01_foundation_setup/02_warehouses.sql
-- Run: module_01_foundation_setup/03_roles_and_grants.sql

-- Verify Phase 1
SHOW DATABASES LIKE 'FINOPS_%';
SHOW WAREHOUSES LIKE 'FINOPS_%';
SHOW ROLES LIKE 'FINOPS_%';

SELECT 'Phase 1 Complete: Foundation created' AS STATUS;
SELECT '→ Next: Phase 2 - Cost Collection' AS NEXT_STEP;


-- =============================================
-- PHASE 2: COST COLLECTION SETUP (5 minutes)
-- =============================================
SELECT '💰 PHASE 2: Cost Collection Setup' AS STATUS;
SELECT 'Creating cost tables and collection procedures...' AS INFO;

-- Run: module_02_cost_collection/01_cost_tables.sql
-- Run: module_02_cost_collection/02_sp_collect_warehouse_costs.sql
-- Run: module_02_cost_collection/03_sp_collect_query_costs.sql
-- Run: module_02_cost_collection/04_sp_collect_storage_costs.sql

-- Verify Phase 2
SHOW TABLES IN SCHEMA FINOPS_CONTROL_DB.COST_DATA;
SHOW PROCEDURES IN SCHEMA FINOPS_CONTROL_DB.PROCEDURES;

-- Configure your Snowflake credit price
UPDATE FINOPS_CONTROL_DB.CONFIG.GLOBAL_SETTINGS
SET SETTING_VALUE = '3.00'  -- ⚠️ UPDATE THIS with your actual credit price
WHERE SETTING_NAME = 'CREDIT_PRICE_USD';

-- Test: Collect last 7 days of cost data
CALL FINOPS_CONTROL_DB.PROCEDURES.SP_COLLECT_WAREHOUSE_COSTS(
    CURRENT_DATE() - 7,
    CURRENT_DATE()
);

CALL FINOPS_CONTROL_DB.PROCEDURES.SP_COLLECT_QUERY_COSTS(
    CURRENT_DATE() - 7,
    CURRENT_DATE()
);

-- Verify data collected
SELECT COUNT(*) AS WAREHOUSE_COST_ROWS
FROM FINOPS_CONTROL_DB.COST_DATA.FACT_WAREHOUSE_COST_HISTORY;

SELECT COUNT(*) AS QUERY_COST_ROWS
FROM FINOPS_CONTROL_DB.COST_DATA.FACT_QUERY_COST_HISTORY;

SELECT 'Phase 2 Complete: Cost collection working' AS STATUS;
SELECT '→ Next: Phase 3 - Chargeback Attribution' AS NEXT_STEP;


-- =============================================
-- PHASE 3: CHARGEBACK ATTRIBUTION (5 minutes)
-- =============================================
SELECT '💳 PHASE 3: Chargeback Attribution Setup' AS STATUS;
SELECT 'Creating dimension tables and attribution logic...' AS INFO;

-- Run: module_03_chargeback_attribution/01_dimension_tables.sql
-- Run: module_03_chargeback_attribution/02_sp_calculate_chargeback.sql
-- Run: module_03_chargeback_attribution/03_sp_register_chargeback_entity.sql

-- Verify Phase 3
SHOW TABLES IN SCHEMA FINOPS_CONTROL_DB.CHARGEBACK;

-- Register your first team (example)
-- ⚠️ UPDATE THIS with your actual team information
CALL FINOPS_CONTROL_DB.PROCEDURES.SP_REGISTER_CHARGEBACK_ENTITY(
    'DATA_ENGINEERING',      -- department name
    'PLATFORM_TEAM',         -- team name
    'COMPUTE_WH',            -- warehouse they own
    'CC-12345',              -- cost center
    'PROD'                   -- environment
);

-- Calculate chargeback for last 7 days
CALL FINOPS_CONTROL_DB.PROCEDURES.SP_CALCULATE_CHARGEBACK(
    CURRENT_DATE() - 7,
    CURRENT_DATE()
);

-- Verify attributed costs
SELECT
    DEPARTMENT,
    TEAM,
    SUM(TOTAL_COST_USD) AS TOTAL_COST
FROM FINOPS_CONTROL_DB.CHARGEBACK.FACT_ATTRIBUTED_COST
WHERE COST_DATE >= CURRENT_DATE() - 7
GROUP BY DEPARTMENT, TEAM
ORDER BY TOTAL_COST DESC;

SELECT 'Phase 3 Complete: Chargeback attribution working' AS STATUS;
SELECT '→ Next: Phase 4 - Budget Controls' AS NEXT_STEP;


-- =============================================
-- PHASE 4: BUDGET CONTROLS (3 minutes)
-- =============================================
SELECT '📈 PHASE 4: Budget Controls Setup' AS STATUS;
SELECT 'Creating budget tables and alert logic...' AS INFO;

-- Run: module_04_budget_controls/01_budget_tables.sql
-- Run: module_04_budget_controls/02_sp_check_budgets.sql
-- Run: module_04_budget_controls/03_sp_detect_anomalies.sql

-- Verify Phase 4
SHOW TABLES IN SCHEMA FINOPS_CONTROL_DB.BUDGET;

-- Set a sample budget (example)
-- ⚠️ UPDATE THIS with your actual budget
INSERT INTO FINOPS_CONTROL_DB.BUDGET.BUDGET_DEFINITIONS (
    ENTITY_TYPE, ENTITY_NAME, BUDGET_PERIOD, BUDGET_AMOUNT_USD,
    THRESHOLD_WARNING, THRESHOLD_CRITICAL, THRESHOLD_BLOCK
) VALUES (
    'DEPARTMENT', 'DATA_ENGINEERING', 'MONTHLY', 50000,
    0.80, 0.90, 1.00  -- Alert at 80%, 90%, 100%
);

-- Test budget check
CALL FINOPS_CONTROL_DB.PROCEDURES.SP_CHECK_BUDGETS();

-- View budget status
SELECT * FROM FINOPS_CONTROL_DB.MONITORING.VW_BUDGET_VS_ACTUAL
WHERE ENTITY_NAME = 'DATA_ENGINEERING';

SELECT 'Phase 4 Complete: Budget controls working' AS STATUS;
SELECT '→ Next: Phase 5 - BI Tool Detection' AS NEXT_STEP;


-- =============================================
-- PHASE 5: BI TOOL DETECTION (2 minutes)
-- =============================================
SELECT '🔍 PHASE 5: BI Tool Detection Setup' AS STATUS;
SELECT 'Creating user classification and BI tool detection...' AS INFO;

-- Run: module_05_bi_tool_detection/01_user_classification.sql
-- Run: module_05_bi_tool_detection/02_sp_classify_bi_channels.sql

-- Classify queries from last 7 days
CALL FINOPS_CONTROL_DB.PROCEDURES.SP_CLASSIFY_BI_CHANNELS(
    CURRENT_DATE() - 7,
    CURRENT_DATE()
);

-- View BI tool costs
SELECT
    BI_TOOL_NAME,
    COUNT(*) AS QUERY_COUNT,
    SUM(COST_USD) AS TOTAL_COST_USD
FROM FINOPS_CONTROL_DB.COST_DATA.FACT_QUERY_COST_HISTORY
WHERE QUERY_DATE >= CURRENT_DATE() - 7
    AND BI_TOOL_NAME IS NOT NULL
GROUP BY BI_TOOL_NAME
ORDER BY TOTAL_COST_USD DESC;

SELECT 'Phase 5 Complete: BI tool detection working' AS STATUS;
SELECT '→ Next: Phase 6 - Optimization Recommendations' AS NEXT_STEP;


-- =============================================
-- PHASE 6: OPTIMIZATION RECOMMENDATIONS (2 minutes)
-- =============================================
SELECT '🎯 PHASE 6: Optimization Setup' AS STATUS;
SELECT 'Creating optimization tables and recommendation generation...' AS INFO;

-- Run: module_06_optimization_recommendations/01_optimization_tables.sql
-- Run: module_06_optimization_recommendations/02_sp_generate_recommendations.sql

-- Generate recommendations for last 7 days
CALL FINOPS_CONTROL_DB.PROCEDURES.SP_GENERATE_RECOMMENDATIONS(
    CURRENT_DATE() - 7,
    CURRENT_DATE()
);

-- View top recommendations
SELECT
    RECOMMENDATION_CATEGORY,
    RECOMMENDATION_TEXT,
    POTENTIAL_SAVINGS_USD,
    PRIORITY
FROM FINOPS_CONTROL_DB.OPTIMIZATION.OPTIMIZATION_RECOMMENDATIONS
WHERE STATUS = 'OPEN'
ORDER BY POTENTIAL_SAVINGS_USD DESC
LIMIT 10;

SELECT 'Phase 6 Complete: Optimization recommendations working' AS STATUS;
SELECT '→ Next: Phase 7 - Monitoring Views' AS NEXT_STEP;


-- =============================================
-- PHASE 7: MONITORING VIEWS (3 minutes)
-- =============================================
SELECT '📊 PHASE 7: Monitoring Views Setup' AS STATUS;
SELECT 'Creating semantic views for reporting...' AS INFO;

-- Run: module_07_monitoring_views/01_executive_summary_views.sql
-- Run: module_07_monitoring_views/02_warehouse_analytics_views.sql
-- Run: module_07_monitoring_views/03_query_cost_views.sql
-- Run: module_07_monitoring_views/04_chargeback_views.sql
-- Run: module_07_monitoring_views/05_budget_views.sql
-- Run: module_07_monitoring_views/06_optimization_views.sql

-- Verify Phase 7
SHOW VIEWS IN SCHEMA FINOPS_CONTROL_DB.MONITORING;

-- Test key views
SELECT * FROM FINOPS_CONTROL_DB.MONITORING.VW_EXECUTIVE_SUMMARY;

SELECT * FROM FINOPS_CONTROL_DB.MONITORING.VW_WAREHOUSE_ANALYTICS
LIMIT 10;

SELECT * FROM FINOPS_CONTROL_DB.MONITORING.VW_CHARGEBACK_REPORT
WHERE REPORT_DATE >= CURRENT_DATE() - 7
LIMIT 10;

SELECT 'Phase 7 Complete: Monitoring views created' AS STATUS;
SELECT '→ Next: Phase 8 - Automation' AS NEXT_STEP;


-- =============================================
-- PHASE 8: AUTOMATION WITH TASKS (2 minutes)
-- =============================================
SELECT '⏰ PHASE 8: Automation Setup' AS STATUS;
SELECT 'Creating scheduled tasks for automated data collection...' AS INFO;

-- Run: module_08_automation_tasks/01_tasks_and_scheduling.sql

-- Verify Phase 8
SHOW TASKS IN SCHEMA FINOPS_CONTROL_DB.PROCEDURES;

-- Tasks are created in SUSPENDED state by default
-- To start automation, resume the root tasks:
ALTER TASK FINOPS_CONTROL_DB.PROCEDURES.TASK_COLLECT_WAREHOUSE_COSTS RESUME;
ALTER TASK FINOPS_CONTROL_DB.PROCEDURES.TASK_COLLECT_STORAGE_COSTS RESUME;
ALTER TASK FINOPS_CONTROL_DB.PROCEDURES.TASK_DETECT_ANOMALIES RESUME;
ALTER TASK FINOPS_CONTROL_DB.PROCEDURES.TASK_GENERATE_RECOMMENDATIONS RESUME;

SELECT 'Phase 8 Complete: Automation tasks created and resumed' AS STATUS;
SELECT '→ Framework setup complete!' AS NEXT_STEP;


-- =============================================
-- FINAL VERIFICATION: Framework Health Check
-- =============================================
SELECT '✅ FINAL VERIFICATION' AS STATUS;
SELECT 'Running framework health check...' AS INFO;

-- Databases
SELECT 'Databases Created:' AS CHECK_TYPE,
       COUNT(*) AS COUNT
FROM SNOWFLAKE.INFORMATION_SCHEMA.DATABASES
WHERE DATABASE_NAME LIKE 'FINOPS_%';

-- Warehouses
SELECT 'Warehouses Created:' AS CHECK_TYPE,
       COUNT(*) AS COUNT
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSES
WHERE NAME LIKE 'FINOPS_%'
    AND DELETED IS NULL;

-- Roles
SELECT 'Roles Created:' AS CHECK_TYPE,
       COUNT(*) AS COUNT
FROM SNOWFLAKE.ACCOUNT_USAGE.ROLES
WHERE NAME LIKE 'FINOPS_%'
    AND DELETED_ON IS NULL;

-- Cost Tables
SELECT 'Cost Tables Created:' AS CHECK_TYPE,
       COUNT(*) AS COUNT
FROM SNOWFLAKE.INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'COST_DATA'
    AND TABLE_CATALOG = 'FINOPS_CONTROL_DB';

-- Procedures
SELECT 'Procedures Created:' AS CHECK_TYPE,
       COUNT(*) AS COUNT
FROM SNOWFLAKE.INFORMATION_SCHEMA.PROCEDURES
WHERE PROCEDURE_SCHEMA = 'PROCEDURES'
    AND PROCEDURE_CATALOG = 'FINOPS_CONTROL_DB';

-- Monitoring Views
SELECT 'Monitoring Views Created:' AS CHECK_TYPE,
       COUNT(*) AS COUNT
FROM SNOWFLAKE.INFORMATION_SCHEMA.VIEWS
WHERE TABLE_SCHEMA = 'MONITORING'
    AND TABLE_CATALOG = 'FINOPS_CONTROL_DB';

-- Tasks
SELECT 'Tasks Created:' AS CHECK_TYPE,
       COUNT(*) AS COUNT
FROM SNOWFLAKE.INFORMATION_SCHEMA.TASKS
WHERE TASK_SCHEMA = 'PROCEDURES'
    AND TASK_CATALOG = 'FINOPS_CONTROL_DB';

-- Cost Data Collected
SELECT 'Warehouse Cost Rows:' AS CHECK_TYPE,
       COUNT(*) AS COUNT
FROM FINOPS_CONTROL_DB.COST_DATA.FACT_WAREHOUSE_COST_HISTORY;

SELECT 'Query Cost Rows:' AS CHECK_TYPE,
       COUNT(*) AS COUNT
FROM FINOPS_CONTROL_DB.COST_DATA.FACT_QUERY_COST_HISTORY;

-- Chargeback Attribution
SELECT 'Attributed Cost Rows:' AS CHECK_TYPE,
       COUNT(*) AS COUNT
FROM FINOPS_CONTROL_DB.CHARGEBACK.FACT_ATTRIBUTED_COST;

-- Budgets
SELECT 'Budgets Defined:' AS CHECK_TYPE,
       COUNT(*) AS COUNT
FROM FINOPS_CONTROL_DB.BUDGET.BUDGET_DEFINITIONS;

-- Recommendations
SELECT 'Open Recommendations:' AS CHECK_TYPE,
       COUNT(*) AS COUNT
FROM FINOPS_CONTROL_DB.OPTIMIZATION.OPTIMIZATION_RECOMMENDATIONS
WHERE STATUS = 'OPEN';


-- =============================================
-- SUCCESS! Framework is ready to use
-- =============================================
SELECT '🎉 SUCCESS!' AS STATUS;
SELECT 'Enterprise FinOps Dashboard framework is ready!' AS MESSAGE;

SELECT '📖 NEXT STEPS:' AS INFO;
SELECT '1. Open Streamlit dashboard: streamlit run streamlit_app/app.py' AS STEP_1;
SELECT '2. Connect Power BI / Tableau to MONITORING views' AS STEP_2;
SELECT '3. Register all teams via SP_REGISTER_CHARGEBACK_ENTITY' AS STEP_3;
SELECT '4. Set budgets for all departments' AS STEP_4;
SELECT '5. Review optimization recommendations' AS STEP_5;
SELECT '6. Schedule weekly cost review meetings' AS STEP_6;

SELECT 'For detailed documentation, see LAB_GUIDE.md' AS DOCUMENTATION;
SELECT 'For troubleshooting, see IMPLEMENTATION_STATUS.md' AS TROUBLESHOOTING;


/*
=============================================================================
  COMMON ISSUES & SOLUTIONS:

  Issue: "SQL compilation error: Object 'FINOPS_CONTROL_DB.CONFIG.GLOBAL_SETTINGS' does not exist"
  Solution: Run Phase 2, Script 01 (cost_tables.sql) to create CONFIG tables

  Issue: "Insufficient privileges to operate on warehouse 'FINOPS_WH_ADMIN'"
  Solution: Switch to FINOPS_ADMIN_ROLE: USE ROLE FINOPS_ADMIN_ROLE;

  Issue: "No data in FACT_WAREHOUSE_COST_HISTORY"
  Solution: Verify ACCOUNT_USAGE grants: SHOW GRANTS TO ROLE FINOPS_ADMIN_ROLE;
            Should have IMPORTED PRIVILEGES on SNOWFLAKE database

  Issue: "High unallocated cost percentage (>10%)"
  Solution: Register all warehouses via SP_REGISTER_CHARGEBACK_ENTITY
            Review DIM_COST_CENTER_MAPPING for missing mappings

  Issue: "Tasks not executing"
  Solution: Resume tasks: ALTER TASK <task_name> RESUME;
            Check task history: SELECT * FROM SNOWFLAKE.ACCOUNT_USAGE.TASK_HISTORY
                                WHERE DATABASE_NAME = 'FINOPS_CONTROL_DB'
                                ORDER BY SCHEDULED_TIME DESC LIMIT 10;

=============================================================================
*/
