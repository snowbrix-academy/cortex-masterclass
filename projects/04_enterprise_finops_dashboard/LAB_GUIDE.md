# Enterprise FinOps Dashboard for Snowflake — Lab Guide

## Snowbrix Academy — Production-Grade Data Engineering. No Fluff.

---

## What You'll Build

A complete, production-ready financial operations (FinOps) framework for Snowflake that provides:

- **Real-time cost visibility** across warehouses, queries, storage, and serverless features
- **Multi-dimensional chargeback** attribution by team, department, project, cost center
- **Automated budget controls** with 3-tier alerting (80%/90%/100% thresholds)
- **Interactive Streamlit dashboard** with executive summary, warehouse analytics, query cost analysis
- **Cost optimization recommendations** based on idle warehouses, query patterns, and resource usage
- **BI tool cost tracking** (Power BI, Tableau, dbt, Airflow classification)

---

## Prerequisites

- Snowflake account (Enterprise Edition recommended for tagging features)
- ACCOUNTADMIN or SYSADMIN role access
- Basic understanding of Snowflake cost model:
  - Compute credits (warehouse consumption)
  - Storage costs (active + time-travel + failsafe)
  - Cloud services (free up to 10% of daily compute)
  - Serverless features (tasks, Snowpipe, materialized views)
- Familiarity with ACCOUNT_USAGE schema
- Python 3.8+ (for Streamlit dashboard)

---

## Module Overview

| Module | Topic | Duration | Deliverables |
|--------|-------|----------|-------------|
| **01** | Foundation Setup | 25 min | Databases, warehouses, roles, RBAC |
| **02** | Cost Collection | 35 min | Cost tables, SP_COLLECT_WH_COSTS, SP_COLLECT_QRY_COSTS |
| **03** | Chargeback Attribution | 40 min | SCD Type 2 dimensions, SP_CALCULATE_CHARGEBACK |
| **04** | Budget Controls | 30 min | Budget tables, SP_CHECK_BUDGETS, anomaly detection |
| **05** | BI Tool Detection | 25 min | User classification, channel cost tracking |
| **06** | Optimization | 30 min | SP_GENERATE_RECOMMENDATIONS, idle warehouse detection |
| **07** | Monitoring Views | 35 min | 10+ semantic views for reporting, row-level security |
| **08** | Automation | 20 min | Scheduled tasks with DAG dependencies |

**Total Time: 4-5 hours**

---

## Quick Start (15 minutes)

### Option A: Run Individual Scripts

Execute each script in order:

```sql
-- Module 01: Foundation
module_01_foundation_setup/01_databases_and_schemas.sql
module_01_foundation_setup/02_warehouses.sql
module_01_foundation_setup/03_roles_and_grants.sql

-- Module 02: Cost Collection
module_02_cost_collection/01_cost_tables.sql
module_02_cost_collection/02_sp_collect_warehouse_costs.sql
module_02_cost_collection/03_sp_collect_query_costs.sql
module_02_cost_collection/04_sp_collect_storage_costs.sql

-- Module 03: Chargeback
module_03_chargeback_attribution/01_dimension_tables.sql
module_03_chargeback_attribution/02_sp_calculate_chargeback.sql
module_03_chargeback_attribution/03_sp_register_chargeback_entity.sql

-- Module 04: Budgets
module_04_budget_controls/01_budget_tables.sql
module_04_budget_controls/02_sp_check_budgets.sql
module_04_budget_controls/03_sp_detect_anomalies.sql

-- Module 05: BI Tool Detection
module_05_bi_tool_detection/01_user_classification.sql
module_05_bi_tool_detection/02_sp_classify_bi_channels.sql

-- Module 06: Optimization
module_06_optimization_recommendations/01_optimization_tables.sql
module_06_optimization_recommendations/02_sp_generate_recommendations.sql

-- Module 07: Monitoring
module_07_monitoring_views/01_executive_summary_views.sql
module_07_monitoring_views/02_warehouse_analytics_views.sql
module_07_monitoring_views/03_query_cost_views.sql
module_07_monitoring_views/04_chargeback_views.sql
module_07_monitoring_views/05_budget_views.sql
module_07_monitoring_views/06_optimization_views.sql

-- Module 08: Automation
module_08_automation_tasks/01_tasks_and_scheduling.sql
```

### Option B: Use Consolidated Worksheets

Open and run the consolidated worksheets in `utilities/`:

```
FINOPS_Module_01_Foundation.sql
FINOPS_Module_02_Cost_Collection.sql
FINOPS_Module_03_Chargeback.sql
FINOPS_Module_04_Budget_Controls.sql
FINOPS_Module_05_BI_Tools.sql
FINOPS_Module_06_Optimization.sql
FINOPS_Module_07_Monitoring.sql
FINOPS_Module_08_Automation.sql
```

### Option C: Fully Automated Setup

Run the quick start script for guided setup:

```sql
-- Run: utilities/quick_start.sql
```

---

## Your First Cost Report (5 minutes)

After completing the quick start, generate your first chargeback report:

```sql
USE ROLE FINOPS_ADMIN_ROLE;
USE WAREHOUSE FINOPS_WH_ADMIN;

-- Step 1: Configure your Snowflake credit price
UPDATE FINOPS_CONTROL_DB.CONFIG.GLOBAL_SETTINGS
SET SETTING_VALUE = '3.00'  -- Replace with your actual credit price
WHERE SETTING_NAME = 'CREDIT_PRICE_USD';

-- Step 2: Register a team (example: Data Engineering)
CALL FINOPS_CONTROL_DB.PROCEDURES.SP_REGISTER_CHARGEBACK_ENTITY(
    'DATA_ENGINEERING',      -- department
    'PLATFORM_TEAM',         -- team
    'COMPUTE_WH',            -- warehouse they own
    'CC-12345',              -- cost center
    'PROD'                   -- environment
);

-- Step 3: Collect last 7 days of cost data
CALL FINOPS_CONTROL_DB.PROCEDURES.SP_COLLECT_WAREHOUSE_COSTS(
    CURRENT_DATE() - 7,
    CURRENT_DATE()
);

CALL FINOPS_CONTROL_DB.PROCEDURES.SP_COLLECT_QUERY_COSTS(
    CURRENT_DATE() - 7,
    CURRENT_DATE()
);

-- Step 4: Calculate chargeback attribution
CALL FINOPS_CONTROL_DB.PROCEDURES.SP_CALCULATE_CHARGEBACK(
    CURRENT_DATE() - 7,
    CURRENT_DATE()
);

-- Step 5: View your first chargeback report
SELECT
    REPORT_DATE,
    DEPARTMENT,
    TEAM,
    WAREHOUSE_NAME,
    TOTAL_CREDITS,
    TOTAL_COST_USD,
    COST_TYPE
FROM FINOPS_CONTROL_DB.MONITORING.VW_CHARGEBACK_REPORT
WHERE REPORT_DATE >= CURRENT_DATE() - 7
ORDER BY REPORT_DATE DESC, TOTAL_COST_USD DESC
LIMIT 20;
```

---

## Module Details

### Module 01: Foundation Setup (25 min)

**What You'll Build:**
- `FINOPS_CONTROL_DB` with 7 schemas (CONFIG, COST_DATA, CHARGEBACK, BUDGET, OPTIMIZATION, PROCEDURES, MONITORING)
- `FINOPS_ANALYTICS_DB` for pre-aggregated metrics
- 3 warehouses: ADMIN (XSMALL), ETL (SMALL), REPORTING (SMALL, multi-cluster)
- Resource monitor to cap framework costs at $150/month
- 4 roles: ADMIN, ANALYST, TEAM_LEAD, EXECUTIVE with least-privilege RBAC

**Key Learning Points:**
- Separation of control DB (framework objects) vs analytics DB (BI consumption)
- Warehouse sizing strategy for FinOps workloads
- Future grants for dynamic object creation
- Role hierarchy and permissions

**Scripts:**
1. `01_databases_and_schemas.sql` - Create databases and schemas
2. `02_warehouses.sql` - Create warehouses with resource monitors
3. `03_roles_and_grants.sql` - RBAC setup

**Verification:**
```sql
SHOW DATABASES LIKE 'FINOPS_%';
SHOW WAREHOUSES LIKE 'FINOPS_%';
SHOW ROLES LIKE 'FINOPS_%';
```

---

### Module 02: Cost Collection (35 min)

**What You'll Build:**
- `FACT_WAREHOUSE_COST_HISTORY` - Minute-by-minute warehouse credit consumption
- `FACT_QUERY_COST_HISTORY` - Query-level cost with user/role/warehouse attribution
- `FACT_STORAGE_COST_HISTORY` - Database storage costs (active + time-travel + failsafe)
- `FACT_SERVERLESS_COST_HISTORY` - Task, Snowpipe, materialized view costs
- `SP_COLLECT_WAREHOUSE_COSTS` - Collect from WAREHOUSE_METERING_HISTORY
- `SP_COLLECT_QUERY_COSTS` - Collect from QUERY_HISTORY
- `SP_COLLECT_STORAGE_COSTS` - Collect from DATABASE_STORAGE_USAGE_HISTORY
- `SP_COLLECT_SERVERLESS_COSTS` - Collect task, pipe, MV costs

**Key Learning Points:**
- Cloud services 10% threshold rule: Only charges above 10% of daily compute credits
- Credit-to-dollar conversion using configurable pricing
- Idempotent data collection (won't duplicate on re-run)
- Incremental collection with date range parameters

**Scripts:**
1. `01_cost_tables.sql` - Create fact tables
2. `02_sp_collect_warehouse_costs.sql` - Warehouse cost collection
3. `03_sp_collect_query_costs.sql` - Query cost collection
4. `04_sp_collect_storage_costs.sql` - Storage cost collection

**Hands-On Lab:**
```sql
-- Collect last 30 days of warehouse costs
CALL SP_COLLECT_WAREHOUSE_COSTS(CURRENT_DATE() - 30, CURRENT_DATE());

-- View collected data
SELECT * FROM FINOPS_CONTROL_DB.COST_DATA.FACT_WAREHOUSE_COST_HISTORY
WHERE USAGE_DATE >= CURRENT_DATE() - 7
ORDER BY USAGE_DATE DESC, CREDITS_USED DESC
LIMIT 100;
```

---

### Module 03: Chargeback Attribution (40 min)

**What You'll Build:**
- `DIM_COST_CENTER_MAPPING` (SCD Type 2) - Maps warehouses, roles, users to cost centers
- `DIM_WAREHOUSE` (SCD Type 2) - Warehouse metadata with tags
- `DIM_USER` (SCD Type 2) - User classification (human vs service account)
- `DIM_ROLE_HIERARCHY` - Role grant chain for attribution traversal
- `FACT_ATTRIBUTED_COST` - Multi-dimensionally attributed costs
- `SP_CALCULATE_CHARGEBACK` - Attribution logic (direct, proportional, tag-based)
- `SP_REGISTER_CHARGEBACK_ENTITY` - Easy onboarding of teams/departments

**Key Learning Points:**
- SCD Type 2 for handling team reorgs without losing history
- Direct attribution (1:1 warehouse to team) vs proportional (shared warehouses)
- Tag-based attribution using QUERY_TAG and object tags
- Handling unallocated costs (goal: <5% of total)

**Scripts:**
1. `01_dimension_tables.sql` - Create SCD Type 2 dimensions
2. `02_sp_calculate_chargeback.sql` - Attribution procedure
3. `03_sp_register_chargeback_entity.sql` - Easy entity onboarding

**Hands-On Lab:**
```sql
-- Register a new department
CALL SP_REGISTER_CHARGEBACK_ENTITY(
    'FINANCE', 'ANALYTICS_TEAM', 'FINANCE_WH', 'CC-67890', 'PROD'
);

-- Calculate chargeback
CALL SP_CALCULATE_CHARGEBACK(CURRENT_DATE() - 7, CURRENT_DATE());

-- View attributed costs
SELECT
    DEPARTMENT,
    TEAM,
    SUM(TOTAL_COST_USD) AS TOTAL_COST
FROM FINOPS_CONTROL_DB.CHARGEBACK.FACT_ATTRIBUTED_COST
WHERE COST_DATE >= CURRENT_DATE() - 7
GROUP BY DEPARTMENT, TEAM
ORDER BY TOTAL_COST DESC;
```

---

### Module 04: Budget Controls (30 min)

**What You'll Build:**
- `BUDGET_DEFINITIONS` - Monthly/quarterly budgets by entity
- `BUDGET_VS_ACTUAL` - Budget comparison with variance
- `ALERT_HISTORY` - Log of all budget alerts triggered
- `SP_CHECK_BUDGETS` - 3-tier threshold checking (80%, 90%, 100%)
- `SP_DETECT_ANOMALIES` - Z-score and percentage spike detection

**Key Learning Points:**
- 3-tier alert strategy: Soft warnings at 80%/90%, hard block at 100%
- Anomaly detection using statistical methods (z-score >2σ)
- Budget forecasting to month-end based on burn rate
- Separation of CAPEX-equivalent (storage) vs OPEX-equivalent (compute)

**Scripts:**
1. `01_budget_tables.sql` - Budget tables and alert config
2. `02_sp_check_budgets.sql` - Budget threshold checking
3. `03_sp_detect_anomalies.sql` - Anomaly detection

**Hands-On Lab:**
```sql
-- Set a monthly budget for Data Engineering dept
INSERT INTO FINOPS_CONTROL_DB.BUDGET.BUDGET_DEFINITIONS (
    ENTITY_TYPE, ENTITY_NAME, BUDGET_PERIOD, BUDGET_AMOUNT_USD,
    THRESHOLD_WARNING, THRESHOLD_CRITICAL, THRESHOLD_BLOCK
) VALUES (
    'DEPARTMENT', 'DATA_ENGINEERING', 'MONTHLY', 50000,
    0.80, 0.90, 1.00
);

-- Check budgets
CALL SP_CHECK_BUDGETS();

-- View budget status
SELECT * FROM FINOPS_CONTROL_DB.MONITORING.VW_BUDGET_VS_ACTUAL
WHERE ENTITY_NAME = 'DATA_ENGINEERING';
```

---

### Module 05: BI Tool Detection (25 min)

**What You'll Build:**
- `USER_CLASSIFICATION` - Human vs service account classification
- `BI_TOOL_MAPPING` - Application name to BI tool mapping
- `SP_CLASSIFY_BI_CHANNELS` - Detect Power BI, Tableau, dbt, Airflow, etc.

**Key Learning Points:**
- Detect BI tools from APPLICATION_NAME in QUERY_HISTORY
- Service account naming patterns (SVC_, SA_)
- Dedicated warehouse strategy vs shared with QUERY_TAG enforcement
- BI tool cost attribution for chargeback

**Scripts:**
1. `01_user_classification.sql` - User type classification
2. `02_sp_classify_bi_channels.sql` - BI tool detection

**Hands-On Lab:**
```sql
-- Classify queries by BI tool
CALL SP_CLASSIFY_BI_CHANNELS(CURRENT_DATE() - 7, CURRENT_DATE());

-- View BI tool costs
SELECT
    BI_TOOL,
    COUNT(*) AS QUERY_COUNT,
    SUM(TOTAL_COST_USD) AS TOTAL_COST
FROM FINOPS_CONTROL_DB.MONITORING.VW_BI_TOOL_COSTS
WHERE REPORT_DATE >= CURRENT_DATE() - 7
GROUP BY BI_TOOL
ORDER BY TOTAL_COST DESC;
```

---

### Module 06: Optimization Recommendations (30 min)

**What You'll Build:**
- `OPTIMIZATION_RECOMMENDATIONS` - Auto-generated cost optimization insights
- `IDLE_WAREHOUSE_LOG` - Track warehouses with >50% idle time
- `SP_GENERATE_RECOMMENDATIONS` - Generate recommendations across 6 categories:
  1. Idle warehouse detection
  2. Auto-suspend tuning
  3. Warehouse sizing
  4. Query optimization
  5. Storage waste
  6. Multi-cluster scaling

**Key Learning Points:**
- Idle warehouse cost calculation: `idle_time_pct * total_cost`
- Query optimization signals: execution time, bytes scanned, spillage
- Storage waste: time-travel costs, unused tables (90+ days no queries)
- Recommendation prioritization by potential savings

**Scripts:**
1. `01_optimization_tables.sql` - Recommendation tables
2. `02_sp_generate_recommendations.sql` - Recommendation generation

**Hands-On Lab:**
```sql
-- Generate recommendations
CALL SP_GENERATE_RECOMMENDATIONS(CURRENT_DATE() - 7, CURRENT_DATE());

-- View top recommendations by savings potential
SELECT
    RECOMMENDATION_CATEGORY,
    RECOMMENDATION_TEXT,
    POTENTIAL_SAVINGS_USD,
    PRIORITY
FROM FINOPS_CONTROL_DB.OPTIMIZATION.OPTIMIZATION_RECOMMENDATIONS
WHERE CREATED_DATE >= CURRENT_DATE() - 7
    AND STATUS = 'OPEN'
ORDER BY POTENTIAL_SAVINGS_USD DESC
LIMIT 10;
```

---

### Module 07: Monitoring Views (35 min)

**What You'll Build:**
- `VW_EXECUTIVE_SUMMARY` - KPIs, trends, top 10 spenders
- `VW_WAREHOUSE_ANALYTICS` - Utilization, idle time, cost per warehouse
- `VW_QUERY_COST_ANALYSIS` - Top N expensive queries
- `VW_CHARGEBACK_REPORT` - Per team/dept/project costs
- `VW_BUDGET_VS_ACTUAL` - Budget status with burn rate
- `VW_OPTIMIZATION_DASHBOARD` - Actionable recommendations
- `VW_BI_TOOL_COSTS` - Cost by BI tool
- `VW_IDLE_WAREHOUSE_REPORT` - Warehouses with high idle time
- `VW_COST_ANOMALIES` - Detected anomalies
- `VW_STORAGE_TRENDS` - Storage growth and costs

**Key Learning Points:**
- Semantic layer for business-friendly reporting
- Row-level security using CURRENT_ROLE() and CURRENT_USER()
- Pre-aggregation to avoid expensive BI tool queries
- SECURE VIEW for cross-department data protection

**Scripts:**
1. `01_executive_summary_views.sql`
2. `02_warehouse_analytics_views.sql`
3. `03_query_cost_views.sql`
4. `04_chargeback_views.sql`
5. `05_budget_views.sql`
6. `06_optimization_views.sql`

**Hands-On Lab:**
```sql
-- Executive summary
SELECT * FROM FINOPS_CONTROL_DB.MONITORING.VW_EXECUTIVE_SUMMARY;

-- Top 10 warehouses by cost
SELECT * FROM FINOPS_CONTROL_DB.MONITORING.VW_WAREHOUSE_ANALYTICS
ORDER BY TOTAL_COST_USD DESC
LIMIT 10;

-- Chargeback report
SELECT * FROM FINOPS_CONTROL_DB.MONITORING.VW_CHARGEBACK_REPORT
WHERE REPORT_DATE >= CURRENT_DATE() - 30
ORDER BY TOTAL_COST_USD DESC;
```

---

### Module 08: Automation with Tasks (20 min)

**What You'll Build:**
- Task DAG with dependencies:
  1. `TASK_COLLECT_WAREHOUSE_COSTS` (hourly)
  2. `TASK_COLLECT_QUERY_COSTS` (hourly)
  3. `TASK_COLLECT_STORAGE_COSTS` (daily)
  4. `TASK_CALCULATE_CHARGEBACK` (daily, after cost collection)
  5. `TASK_CHECK_BUDGETS` (daily, after chargeback)
  6. `TASK_GENERATE_RECOMMENDATIONS` (weekly)
  7. `TASK_DETECT_ANOMALIES` (daily)

**Key Learning Points:**
- Task scheduling with CRON expressions
- Task dependencies using AFTER keyword
- Error handling and notification
- Suspend/resume tasks for maintenance

**Scripts:**
1. `01_tasks_and_scheduling.sql` - Create task DAG

**Hands-On Lab:**
```sql
-- View task status
SHOW TASKS IN SCHEMA FINOPS_CONTROL_DB.PROCEDURES;

-- View task run history
SELECT
    NAME,
    STATE,
    SCHEDULED_TIME,
    COMPLETED_TIME,
    ERROR_CODE,
    ERROR_MESSAGE
FROM SNOWFLAKE.ACCOUNT_USAGE.TASK_HISTORY
WHERE DATABASE_NAME = 'FINOPS_CONTROL_DB'
    AND SCHEMA_NAME = 'PROCEDURES'
    AND SCHEDULED_TIME >= CURRENT_DATE() - 1
ORDER BY SCHEDULED_TIME DESC;

-- Resume task tree (start automation)
ALTER TASK FINOPS_CONTROL_DB.PROCEDURES.TASK_COLLECT_WAREHOUSE_COSTS RESUME;
```

---

## Streamlit Dashboard

### Setup

```bash
cd streamlit_app

# Install dependencies
pip install -r requirements.txt

# Configure Snowflake connection
# Edit app.py or use Streamlit secrets management
# See: https://docs.streamlit.io/library/advanced-features/secrets-management

# Run dashboard
streamlit run app.py
```

### Pages

1. **Executive Summary**: KPIs, daily spend trend, top spenders, budget status
2. **Warehouse Analytics**: Utilization, idle time, cost breakdown, drill-down
3. **Query Cost Analysis**: Top 20 expensive queries, cost distribution, optimization candidates
4. **Chargeback Report**: Multi-dimensional view (team/dept/project), export to CSV
5. **Budget Management**: Budget vs actual, forecast, alert history
6. **Optimization**: Recommendations ranked by savings potential
7. **Admin/Config**: Register entities, update credit pricing, refresh data

### Features

- **Filters**: Date range, warehouse, department, team, user
- **Charts**: Plotly interactive charts (bar, line, pie, treemap)
- **Export**: Download reports as CSV or Excel
- **Refresh**: Manual refresh button for on-demand data updates
- **Role-based access**: Dashboard respects Snowflake RBAC

---

## Production Deployment Checklist

### Pre-Deployment

- [ ] Configure actual credit pricing in `GLOBAL_SETTINGS`
- [ ] Register all teams/departments via `SP_REGISTER_CHARGEBACK_ENTITY`
- [ ] Create Snowflake tags and apply to warehouses
- [ ] Test cost collection procedures with historical data
- [ ] Validate chargeback attribution accuracy
- [ ] Set budgets for all departments
- [ ] Configure alert email addresses

### Deployment

- [ ] Run all module scripts in sequence
- [ ] Verify all tables, views, procedures created
- [ ] Grant appropriate roles to users
- [ ] Resume task tree to start automation
- [ ] Test Streamlit dashboard connectivity
- [ ] Validate row-level security (test as different roles)

### Post-Deployment

- [ ] Monitor task execution for first week
- [ ] Review unallocated cost percentage (should be <5%)
- [ ] Audit budget vs actual for accuracy
- [ ] Review optimization recommendations
- [ ] Train finance analysts on dashboard usage
- [ ] Document custom configurations for your environment

---

## Troubleshooting

### Cost Collection Issues

**Problem**: No data in `FACT_WAREHOUSE_COST_HISTORY`

**Solution**:
1. Check ACCOUNT_USAGE grants: `SHOW GRANTS TO ROLE FINOPS_ADMIN_ROLE;`
2. Verify WAREHOUSE_METERING_HISTORY has data: `SELECT COUNT(*) FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY;`
3. Check procedure execution log: `SELECT * FROM FINOPS_CONTROL_DB.AUDIT.PROCEDURE_EXECUTION_LOG WHERE PROCEDURE_NAME = 'SP_COLLECT_WAREHOUSE_COSTS' ORDER BY EXECUTION_TIME DESC;`

### Chargeback Attribution Issues

**Problem**: High percentage of unallocated costs (>10%)

**Solution**:
1. Check for unmapped warehouses: `SELECT DISTINCT WAREHOUSE_NAME FROM FINOPS_CONTROL_DB.COST_DATA.FACT_WAREHOUSE_COST_HISTORY WHERE WAREHOUSE_NAME NOT IN (SELECT WAREHOUSE_NAME FROM FINOPS_CONTROL_DB.CHARGEBACK.DIM_COST_CENTER_MAPPING WHERE IS_CURRENT = TRUE);`
2. Register missing entities: `CALL SP_REGISTER_CHARGEBACK_ENTITY(...);`
3. Review role-to-team mappings

### Budget Alert Issues

**Problem**: Alerts not triggering

**Solution**:
1. Check budget definitions exist: `SELECT * FROM FINOPS_CONTROL_DB.BUDGET.BUDGET_DEFINITIONS;`
2. Check `SP_CHECK_BUDGETS` is running: `SELECT * FROM SNOWFLAKE.ACCOUNT_USAGE.TASK_HISTORY WHERE NAME = 'TASK_CHECK_BUDGETS' ORDER BY SCHEDULED_TIME DESC LIMIT 10;`
3. Verify alert thresholds are correct
4. Check alert email configuration

### Dashboard Issues

**Problem**: Streamlit dashboard shows no data

**Solution**:
1. Check Snowflake connection credentials
2. Verify role has SELECT grants on MONITORING views
3. Check date range filter (may be excluding all data)
4. Verify cost collection has run at least once

---

## Cleanup

To remove all FinOps framework objects:

```sql
-- Run: utilities/cleanup.sql
```

This drops:
- All databases: `FINOPS_CONTROL_DB`, `FINOPS_ANALYTICS_DB`
- All warehouses: `FINOPS_WH_*`
- All roles: `FINOPS_*_ROLE`
- Resource monitor: `FINOPS_FRAMEWORK_MONITOR`

**WARNING**: This is irreversible. Backup cost data if needed before running cleanup.

---

## Next Steps

### Extend the Framework

1. **Integrate with external alerting**: Send alerts to Slack, PagerDuty, or email via external function
2. **Add forecasting models**: Implement time-series forecasting (Prophet, ARIMA) for budget projections
3. **Cross-cloud comparison**: Compare costs across AWS, Azure, GCP Snowflake accounts
4. **Reserved capacity tracking**: Monitor Snowflake Capacity Commitment usage
5. **Custom allocation rules**: Add business-specific allocation logic (e.g., allocate platform costs by headcount)

### Advanced Topics

- **Reader account costs**: Attribute data sharing costs to consuming teams
- **Marketplace consumption**: Track and allocate Snowflake Marketplace listing costs
- **Replication costs**: Attribute cross-region replication costs
- **Data transfer costs**: Track inter-region and inter-cloud data transfer
- **Snowpark Container Services**: Collect and attribute container compute costs

---

## Support

For questions or issues:
- Review module-specific scripts and comments
- Check course content video scripts in `course_content/video_scripts/`
- Consult utilities/consolidated worksheets for module summaries

---

*Built by Snowbrix Academy — Production-Grade Data Engineering. No Fluff.*
