# FinOps Consolidated Worksheets - Summary

**Project:** Enterprise FinOps Dashboard for Snowflake
**Created:** 2026-02-08
**Purpose:** Snowsight-ready consolidated SQL worksheets for production-grade FinOps implementation

---

## Overview

This directory contains **8 consolidated worksheets** that combine all individual SQL scripts from each module into single, executable files optimized for Snowsight and VS Code.

Each worksheet follows a consistent structure:
- **Header block** with module overview, prerequisites, and instructions
- **Section dividers** between combined scripts
- **Complete SQL** from all module scripts
- **Footer block** with completion summary and next steps

---

## Consolidated Worksheets

| Module | Worksheet File | Size | Lines | Scripts | Est. Time |
|--------|----------------|------|-------|---------|-----------|
| 01 | `FINOPS_Module_01_Foundation_Setup.sql` | 28 KB | 625 | 3 | 15 min |
| 02 | `FINOPS_Module_02_Cost_Collection.sql` | 99 KB | 2,492 | 4 | 30 min |
| 03 | `FINOPS_Module_03_Chargeback_Attribution.sql` | 74 KB | 1,832 | 3 | 25 min |
| 04 | `FINOPS_Module_04_Budget_Controls.sql` | 48 KB | 1,134 | 3 | 25 min |
| 05 | `FINOPS_Module_05_BI_Tool_Detection.sql` | 20 KB | 512 | 2 | 15 min |
| 06 | `FINOPS_Module_06_Optimization_Recommendations.sql` | 28 KB | 670 | 3 | 30 min |
| 07 | `FINOPS_Module_07_Monitoring_Views.sql` | 24 KB | 630 | 3 | 20 min |
| 08 | `FINOPS_Module_08_Automation_Tasks.sql` | 22 KB | 607 | 2 | 20 min |
| **Total** | **8 files** | **343 KB** | **8,502 lines** | **23 scripts** | **~3 hours** |

---

## Module 01: Foundation Setup
**File:** `FINOPS_Module_01_Foundation_Setup.sql`
**Size:** 28 KB | 625 lines | 3 scripts | 15 minutes

### Combined Scripts:
1. `01_databases_and_schemas.sql` - Create FINOPS_CONTROL_DB and FINOPS_ANALYTICS_DB
2. `02_warehouses.sql` - Create framework warehouses with resource monitors
3. `03_roles_and_grants.sql` - Implement RBAC with least-privilege access

### Objects Created:
- **Databases:** FINOPS_CONTROL_DB, FINOPS_ANALYTICS_DB
- **Schemas:** CONFIG, COST_DATA, CHARGEBACK, BUDGET, OPTIMIZATION, PROCEDURES, MONITORING
- **Warehouses:** FINOPS_WH_ADMIN (XSMALL), FINOPS_WH_ETL (SMALL), FINOPS_WH_REPORTING (SMALL)
- **Resource Monitor:** FINOPS_FRAMEWORK_MONITOR (50 credits/month)
- **Roles:** FINOPS_ADMIN_ROLE, FINOPS_ANALYST_ROLE, FINOPS_TEAM_LEAD_ROLE, FINOPS_EXECUTIVE_ROLE

### Prerequisites:
- ACCOUNTADMIN or SYSADMIN role access
- Fresh Snowflake account or no existing FINOPS_ objects

---

## Module 02: Cost Collection
**File:** `FINOPS_Module_02_Cost_Collection.sql`
**Size:** 99 KB | 2,492 lines | 4 scripts | 30 minutes

### Combined Scripts:
1. `01_cost_tables.sql` - Create fact tables and global configuration
2. `02_sp_collect_warehouse_costs.sql` - Collect warehouse credit consumption
3. `03_sp_collect_query_costs.sql` - Collect query-level cost attribution
4. `04_sp_collect_storage_costs.sql` - Collect daily storage costs

### Objects Created:
- **Fact Tables:**
  - FACT_WAREHOUSE_COST_HISTORY (per-minute grain, partitioned by USAGE_DATE)
  - FACT_QUERY_COST_HISTORY (per-query grain, partitioned by QUERY_DATE)
  - FACT_STORAGE_COST_HISTORY (per-database per-day grain)
  - FACT_SERVERLESS_COST_HISTORY (serverless feature costs)
- **Configuration:** GLOBAL_SETTINGS (credit pricing, thresholds)
- **Audit:** PROCEDURE_EXECUTION_LOG
- **Procedures:**
  - SP_COLLECT_WAREHOUSE_COSTS (hourly collection)
  - SP_COLLECT_QUERY_COSTS (hourly collection)
  - SP_COLLECT_STORAGE_COSTS (daily collection)

### Key Features:
- Incremental collection with watermark tracking
- Idempotent MERGE statements (safe to re-run)
- ACCOUNT_USAGE latency handling (45 min - 3 hours)
- Configurable credit pricing
- Cloud services 10% threshold rule
- BI tool detection from APPLICATION_NAME
- Query-level cost calculation: (execution_time_ms / 3,600,000) * warehouse_size_credits * credit_price

### Prerequisites:
- Module 01 completed
- FINOPS_ADMIN_ROLE access
- IMPORTED PRIVILEGES on SNOWFLAKE database

---

## Module 03: Chargeback Attribution
**File:** `FINOPS_Module_03_Chargeback_Attribution.sql`
**Size:** 74 KB | 1,832 lines | 3 scripts | 25 minutes

### Combined Scripts:
1. `01_dimension_tables.sql` - Create SCD Type 2 dimension tables
2. `02_attribution_logic.sql` - Implement multi-layer attribution
3. `03_helper_procedures.sql` - Create utility procedures for mapping management

### Objects Created:
- **Dimension Tables (SCD Type 2):**
  - DIM_COST_CENTER (cost center master)
  - DIM_TEAM (team hierarchy)
  - DIM_DEPARTMENT (department structure)
  - DIM_PROJECT (project tracking)
- **Mapping Tables (SCD Type 2):**
  - DIM_USER_MAPPING (user → team/department/cost_center)
  - DIM_WAREHOUSE_MAPPING (warehouse → team/project/environment)
  - DIM_ROLE_MAPPING (role → team/department)
- **Attribution Views:**
  - VW_ATTRIBUTED_COSTS (join cost facts with attribution dimensions)
  - VW_UNALLOCATED_COSTS (track unattributed spend)
- **Procedures:**
  - SP_UPDATE_USER_MAPPING (maintain user-to-team mappings)
  - SP_UPDATE_WAREHOUSE_MAPPING (maintain warehouse-to-team mappings)

### Key Features:
- **SCD Type 2** for all mapping tables (effective_from, effective_to, is_current)
- **Multi-layer attribution hierarchy:**
  1. QUERY_TAG (highest priority)
  2. Warehouse tags
  3. User/role mapping
  4. Unallocated (goal: <5%)
- **Reorg-friendly:** Historical cost attribution under both old and new org structures
- **Tag taxonomy:** DEPARTMENT, TEAM, COST_CENTER, PROJECT, ENVIRONMENT, OWNER

### Prerequisites:
- Module 02 completed
- Organizational structure defined (teams, departments, cost centers)

---

## Module 04: Budget Controls
**File:** `FINOPS_Module_04_Budget_Controls.sql`
**Size:** 48 KB | 1,134 lines | 3 scripts | 25 minutes

### Combined Scripts:
1. `01_budget_tables.sql` - Create budget definition and tracking tables
2. `02_budget_procedures.sql` - Implement budget checking and forecasting
3. `03_alert_procedures.sql` - Create alert and notification procedures

### Objects Created:
- **Budget Tables:**
  - BUDGET_DEFINITIONS (monthly/quarterly budgets by cost center/team/department)
  - BUDGET_VS_ACTUAL (budget comparison tracking)
  - BUDGET_ALERT_HISTORY (alert audit trail)
- **Procedures:**
  - SP_CHECK_BUDGETS (compare actual vs budget, identify overruns)
  - SP_SEND_BUDGET_ALERTS (trigger notifications at 70%, 85%, 95%, 100%)
  - SP_FORECAST_COSTS (predict end-of-month spend based on current trend)
- **Views:**
  - VW_BUDGET_DASHBOARD (executive budget summary)
  - VW_BUDGET_ALERTS (active alerts and thresholds)

### Key Features:
- **Multi-tiered alerts:**
  - 70% of budget: Soft notification
  - 85% of budget: Escalated notification
  - 95% of budget: Critical alert
  - 100% of budget: Option to suspend non-critical warehouses
- **Anomaly detection:** Z-score based (>2σ from 30-day rolling average)
- **Forecasting:** Linear extrapolation to predict month-end spend
- **Budget grain:** Monthly, quarterly, and annual envelopes
- **Budget allocation:** By cost center, team, department, project

### Prerequisites:
- Module 03 completed (attribution must be in place)
- Budget definitions loaded for all cost centers/teams

---

## Module 05: BI Tool Detection
**File:** `FINOPS_Module_05_BI_Tool_Detection.sql`
**Size:** 20 KB | 512 lines | 2 scripts | 15 minutes

### Combined Scripts:
1. `01_bi_tool_classification.sql` - Create classification rules and detection logic
2. `02_bi_tool_analysis.sql` - Build BI tool cost analysis views

### Objects Created:
- **Classification Tables:**
  - BI_TOOL_CLASSIFICATION_RULES (APPLICATION_NAME patterns → BI tool mapping)
  - BI_TOOL_COST_SUMMARY (aggregated BI tool costs)
- **Procedures:**
  - SP_CLASSIFY_BI_CHANNELS (classify queries by BI tool from APPLICATION_NAME)
  - SP_ANALYZE_BI_COSTS (generate BI tool cost breakdowns)
- **Views:**
  - VW_BI_TOOL_COST_BREAKDOWN (daily/weekly/monthly BI tool costs)
  - VW_BI_TOOL_EFFICIENCY (BI tool query performance metrics)

### Detected BI Tools:
- **Power BI** (APPLICATION_NAME contains 'PowerBI', 'Microsoft.Mashup')
- **Tableau** (APPLICATION_NAME contains 'Tableau')
- **Looker** (APPLICATION_NAME contains 'Looker')
- **dbt** (APPLICATION_NAME contains 'dbt')
- **Streamlit** (APPLICATION_NAME contains 'Streamlit')
- **Airflow** (APPLICATION_NAME contains 'Airflow')
- **Fivetran** (APPLICATION_NAME contains 'Fivetran')
- **Talend** (APPLICATION_NAME contains 'Talend')
- **Matillion** (APPLICATION_NAME contains 'Matillion')

### Key Features:
- **Pattern-based classification** from QUERY_HISTORY.CLIENT_APPLICATION_ID
- **Service account detection** (SVC_POWERBI_*, SVC_TABLEAU_*)
- **BI tool cost aggregation** by day/week/month
- **Warehouse recommendation** for dedicated BI tool warehouses
- **Query efficiency metrics** per BI tool (avg execution time, cost per query)

### Prerequisites:
- Module 02 completed (query cost collection in place)
- BI tools actively querying Snowflake

---

## Module 06: Optimization Recommendations
**File:** `FINOPS_Module_06_Optimization_Recommendations.sql`
**Size:** 28 KB | 670 lines | 3 scripts | 30 minutes

### Combined Scripts:
1. `01_optimization_tables.sql` - Create recommendation tracking tables
2. `02_optimization_procedures.sql` - Implement optimization analysis procedures
3. `03_optimization_views.sql` - Build optimization dashboard views

### Objects Created:
- **Optimization Tables:**
  - OPTIMIZATION_RECOMMENDATIONS (cost-saving recommendations)
  - IDLE_WAREHOUSE_LOG (track underutilized warehouses)
  - EXPENSIVE_QUERY_LOG (track high-cost queries)
- **Procedures:**
  - SP_GENERATE_RECOMMENDATIONS (weekly cost optimization scan)
  - SP_ANALYZE_IDLE_WAREHOUSES (identify warehouses with >50% idle time)
  - SP_IDENTIFY_EXPENSIVE_QUERIES (flag queries costing >$10)
- **Views:**
  - VW_OPTIMIZATION_DASHBOARD (aggregated optimization opportunities)
  - VW_COST_SAVING_OPPORTUNITIES (ranked list of savings potential)

### Optimization Categories:
1. **Idle Warehouses:** >50% idle time → reduce size or auto-suspend tuning
2. **Expensive Queries:** Cost >$10 → optimization candidates (missing filters, full scans)
3. **Auto-Suspend Misconfig:** Warehouses never suspending
4. **Oversized Warehouses:** Consistent low utilization → downsize
5. **Multi-Cluster Underuse:** Single cluster always sufficient → remove multi-cluster
6. **Storage Overhead:** Time-travel + failsafe >50% → reduce retention

### Key Features:
- **Weekly recommendation generation** (scheduled via Task)
- **Potential savings calculation** (estimated monthly cost reduction)
- **Priority ranking** (HIGH, MEDIUM, LOW based on impact)
- **Recommendation status tracking** (OPEN, IN_PROGRESS, IMPLEMENTED, REJECTED)
- **ROI calculation** (monthly savings vs implementation effort)

### Prerequisites:
- Module 02 completed (cost collection running for at least 7 days)
- Sufficient historical data for trend analysis

---

## Module 07: Monitoring Views
**File:** `FINOPS_Module_07_Monitoring_Views.sql`
**Size:** 24 KB | 630 lines | 3 scripts | 20 minutes

### Combined Scripts:
1. `01_executive_summary_views.sql` - Create high-level executive dashboards
2. `02_warehouse_query_analytics.sql` - Build warehouse and query analytics views
3. `03_chargeback_reporting.sql` - Implement chargeback reporting with row-level security

### Objects Created:
- **Executive Views:**
  - VW_EXECUTIVE_SUMMARY (daily cost summary, trends, top spenders)
  - VW_COST_TREND_DAILY (30-day rolling cost trend)
  - VW_COST_BREAKDOWN (cost by type: compute, storage, serverless)
- **Analytics Views:**
  - VW_WAREHOUSE_ANALYTICS (warehouse performance and cost metrics)
  - VW_QUERY_ANALYTICS (query performance and cost distribution)
  - VW_USER_COST_SUMMARY (cost by user, top spenders)
- **Chargeback Views (with row-level security):**
  - VW_CHARGEBACK_REPORT (attributed costs by team/department/project)
  - VW_TEAM_COSTS (team-level chargeback with RLS)
  - VW_DEPARTMENT_COSTS (department-level chargeback with RLS)

### Key Features:
- **Row-level security** using CURRENT_ROLE() and CURRENT_USER()
  - Team leads see only their team's costs
  - Executives see aggregated summary only
  - Analysts see all details
- **Pre-aggregated for BI tools** (fast Power BI, Tableau, Streamlit queries)
- **Semantic layer** (business-friendly column names and metrics)
- **Time intelligence** (MTD, QTD, YTD calculations)
- **Budget comparison** (actual vs budget, variance %)

### Prerequisites:
- Modules 01-06 completed
- Cost collection running for at least 7 days
- Attribution mappings populated

---

## Module 08: Automation Tasks
**File:** `FINOPS_Module_08_Automation_Tasks.sql`
**Size:** 22 KB | 607 lines | 2 scripts | 20 minutes

### Combined Scripts:
1. `01_task_definitions.sql` - Create scheduled tasks for framework automation
2. `02_task_monitoring.sql` - Implement task monitoring and alerting

### Objects Created:
- **Tasks (Scheduled Jobs):**
  - TASK_COLLECT_WAREHOUSE_COSTS (hourly: CRON 0 * * * * UTC)
  - TASK_COLLECT_QUERY_COSTS (hourly: CRON 5 * * * * UTC)
  - TASK_COLLECT_STORAGE_COSTS (daily: CRON 0 2 * * * UTC)
  - TASK_CHECK_BUDGETS (daily: CRON 0 6 * * * UTC)
  - TASK_GENERATE_RECOMMENDATIONS (weekly: CRON 0 8 * * 1 UTC)
- **Monitoring Views:**
  - VW_TASK_EXECUTION_HISTORY (recent task runs, success/failure rate)
  - VW_TASK_ERRORS (failed task executions with error details)
  - VW_TASK_SCHEDULE (task schedule and next run time)

### Task DAG Structure:
```
ROOT: TASK_COLLECT_WAREHOUSE_COSTS (hourly)
  └─> AFTER: TASK_COLLECT_QUERY_COSTS (hourly, 5 min offset)

ROOT: TASK_COLLECT_STORAGE_COSTS (daily, 2 AM UTC)

ROOT: TASK_CHECK_BUDGETS (daily, 6 AM UTC)
  └─> Uses: Cost collection data from previous day

ROOT: TASK_GENERATE_RECOMMENDATIONS (weekly, Monday 8 AM UTC)
  └─> Uses: 7+ days of historical cost data
```

### Key Features:
- **Incremental execution** (only collect new data since last run)
- **Error handling and logging** (all failures logged to PROCEDURE_EXECUTION_LOG)
- **Task dependencies** (AFTER clause for sequential execution)
- **Scheduled at UTC** (avoid daylight saving time issues)
- **Warehouse assignment** (TASK uses FINOPS_WH_ETL)
- **Auto-suspend after execution** (warehouse suspends after 60 seconds idle)

### Task Management:
```sql
-- Resume all tasks (start automation)
ALTER TASK TASK_COLLECT_WAREHOUSE_COSTS RESUME;
ALTER TASK TASK_COLLECT_STORAGE_COSTS RESUME;
ALTER TASK TASK_CHECK_BUDGETS RESUME;
ALTER TASK TASK_GENERATE_RECOMMENDATIONS RESUME;

-- Suspend all tasks (stop automation)
ALTER TASK TASK_COLLECT_WAREHOUSE_COSTS SUSPEND;
ALTER TASK TASK_COLLECT_STORAGE_COSTS SUSPEND;
ALTER TASK TASK_CHECK_BUDGETS SUSPEND;
ALTER TASK TASK_GENERATE_RECOMMENDATIONS SUSPEND;

-- Check task execution history
SELECT * FROM VW_TASK_EXECUTION_HISTORY ORDER BY START_TIME DESC LIMIT 10;

-- Check task errors
SELECT * FROM VW_TASK_ERRORS ORDER BY START_TIME DESC LIMIT 10;
```

### Prerequisites:
- Modules 01-07 completed
- All cost collection procedures tested manually
- FINOPS_WH_ETL warehouse operational

---

## Usage Instructions

### Sequential Execution (Recommended)

Execute the consolidated worksheets **in order (Module 01 → Module 08)**:

1. **Open Snowsight** or VS Code with Snowflake extension
2. **Load the worksheet:** `FINOPS_Module_01_Foundation_Setup.sql`
3. **Select all (Ctrl+A)** and **Execute (Ctrl+Enter)**
4. **Verify completion:** Run verification queries at the end of the worksheet
5. **Repeat for each module** (02 through 08)

### Selective Execution

To execute individual sections within a worksheet:
1. Use the **section dividers** as navigation landmarks
2. Select the SQL statements for that section
3. Execute with Ctrl+Enter

### Verification

Each worksheet includes **verification queries** at the end:
- Confirm objects created successfully
- Check data collection results
- Validate grants and permissions

### Troubleshooting

If a script fails:
1. **Check prerequisites:** Ensure previous modules completed
2. **Review error message:** Most errors are permission-related
3. **Verify role:** Ensure you're using FINOPS_ADMIN_ROLE
4. **Check PROCEDURE_EXECUTION_LOG:** For stored procedure errors
   ```sql
   SELECT * FROM FINOPS_CONTROL_DB.AUDIT.PROCEDURE_EXECUTION_LOG
   WHERE EXECUTION_STATUS = 'ERROR'
   ORDER BY START_TIME DESC LIMIT 10;
   ```

---

## Production Deployment Checklist

Before deploying to production:

- [ ] **Update GLOBAL_SETTINGS:**
  - Set CREDIT_PRICE_USD to your actual contract price
  - Set STORAGE_PRICE_USD_PER_TB_MONTH to your regional pricing
  - Adjust FRAMEWORK_TIMEZONE to your reporting timezone

- [ ] **Configure budgets:**
  - Load budget definitions into BUDGET_DEFINITIONS table
  - Set appropriate alert thresholds

- [ ] **Populate mappings:**
  - DIM_USER_MAPPING (all active users → teams)
  - DIM_WAREHOUSE_MAPPING (all warehouses → teams/projects)
  - DIM_ROLE_MAPPING (key roles → teams)

- [ ] **Test cost collection:**
  - Manually run SP_COLLECT_WAREHOUSE_COSTS
  - Manually run SP_COLLECT_QUERY_COSTS
  - Manually run SP_COLLECT_STORAGE_COSTS
  - Verify data in COST_DATA schema

- [ ] **Enable tasks:**
  - Resume all tasks (TASK_COLLECT_*)
  - Monitor task execution for first 24 hours
  - Check PROCEDURE_EXECUTION_LOG for errors

- [ ] **Grant access:**
  - Assign users to FINOPS roles (ANALYST, TEAM_LEAD, EXECUTIVE)
  - Test row-level security in VW_TEAM_COSTS
  - Validate BI tool access (Power BI, Tableau)

- [ ] **Set up alerting:**
  - Configure email/Slack notifications for budget alerts
  - Set up monitoring for task failures
  - Create alerts for anomaly detection

---

## Estimated Costs

### Framework Runtime Costs

Assuming $3/credit:

| Component | Frequency | Credits/Run | Monthly Credits | Monthly Cost |
|-----------|-----------|-------------|-----------------|--------------|
| Warehouse cost collection | Hourly (24/day) | 0.01 | 7.2 | $21.60 |
| Query cost collection | Hourly (24/day) | 0.05 | 36 | $108.00 |
| Storage cost collection | Daily (1/day) | 0.005 | 0.15 | $0.45 |
| Budget checks | Daily (1/day) | 0.01 | 0.3 | $0.90 |
| Recommendations | Weekly (4/month) | 0.02 | 0.08 | $0.24 |
| **Total framework cost** | — | — | **~44 credits** | **~$131/month** |

**Resource Monitor:** 50 credits/month (~$150) provides 10% buffer

### Storage Costs

Framework storage (FINOPS_CONTROL_DB + FINOPS_ANALYTICS_DB):
- **First month:** ~5 GB (~$0.15/day)
- **After 6 months:** ~100 GB (~$2.30/day, ~$70/month)
- **After 12 months:** ~200 GB (~$4.60/day, ~$140/month)

**Total estimated cost:** $200-300/month (compute + storage) after 12 months

---

## Support and Maintenance

### Monthly Maintenance Tasks

1. **Review unallocated costs:** Goal <5%
   ```sql
   SELECT * FROM VW_UNALLOCATED_COSTS WHERE USAGE_DATE >= DATEADD(MONTH, -1, CURRENT_DATE());
   ```

2. **Update credit pricing:** If contract changes
   ```sql
   UPDATE FINOPS_CONTROL_DB.CONFIG.GLOBAL_SETTINGS
   SET SETTING_VALUE = '3.50'
   WHERE SETTING_NAME = 'CREDIT_PRICE_USD';
   ```

3. **Audit role grants:** Who has FINOPS_ADMIN_ROLE?
   ```sql
   SHOW GRANTS OF ROLE FINOPS_ADMIN_ROLE;
   ```

4. **Review optimization recommendations:** Implement high-priority items
   ```sql
   SELECT * FROM VW_OPTIMIZATION_DASHBOARD WHERE PRIORITY = 'HIGH' AND STATUS = 'OPEN';
   ```

### Quarterly Maintenance Tasks

1. **Update SCD Type 2 mappings** for reorgs
2. **Review and adjust budgets** for next quarter
3. **Archive old data** (>12 months) to reduce storage costs
4. **Audit BI tool classification rules** (new tools added?)
5. **Performance tuning** (check clustering, partitioning effectiveness)

---

## Additional Resources

### Documentation
- [Snowflake ACCOUNT_USAGE Views](https://docs.snowflake.com/en/sql-reference/account-usage.html)
- [Snowflake Pricing](https://www.snowflake.com/pricing/)
- [FinOps Foundation](https://www.finops.org/)

### Related Files
- `cleanup.sql` - Cleanup script to remove all FinOps objects
- `quick_start.sql` - Quick start guide for testing
- `create_consolidated_worksheets.py` - Script used to generate these worksheets

---

## Change Log

### 2026-02-08
- Initial creation of all 8 consolidated worksheets
- Combined 23 individual SQL scripts into 8 production-ready files
- Total of 8,502 lines of SQL across 343 KB

---

## Author

**Snowbrix Academy**
Enterprise FinOps Dashboard for Snowflake
Production-Grade Data Engineering. No Fluff.

---

**END OF SUMMARY**
