# FinOps Utilities Directory

**Project:** Enterprise FinOps Dashboard for Snowflake
**Location:** `projects/04_enterprise_finops_dashboard/utilities/`
**Updated:** 2026-02-08

---

## 📁 Directory Contents

### 🎯 Start Here

| File | Size | Purpose |
|------|------|---------|
| **QUICK_REFERENCE.md** | 9.4 KB | Quick reference guide - START HERE |
| **CONSOLIDATED_WORKSHEETS_SUMMARY.md** | 21 KB | Comprehensive guide to all worksheets |
| **quick_start.sql** | 14 KB | Quick start script for testing |
| **cleanup.sql** | 6.1 KB | Cleanup script to remove all objects |

### 📊 Consolidated Worksheets (Production-Ready)

Execute these **in order** (01 → 08):

| Module | File | Size | Lines | Scripts | Time |
|--------|------|------|-------|---------|------|
| 01 | **FINOPS_Module_01_Foundation_Setup.sql** | 28 KB | 625 | 3 | 15 min |
| 02 | **FINOPS_Module_02_Cost_Collection.sql** | 99 KB | 2,492 | 4 | 30 min |
| 03 | **FINOPS_Module_03_Chargeback_Attribution.sql** | 74 KB | 1,832 | 3 | 25 min |
| 04 | **FINOPS_Module_04_Budget_Controls.sql** | 48 KB | 1,134 | 3 | 25 min |
| 05 | **FINOPS_Module_05_BI_Tool_Detection.sql** | 20 KB | 512 | 2 | 15 min |
| 06 | **FINOPS_Module_06_Optimization_Recommendations.sql** | 28 KB | 670 | 3 | 30 min |
| 07 | **FINOPS_Module_07_Monitoring_Views.sql** | 24 KB | 630 | 3 | 20 min |
| 08 | **FINOPS_Module_08_Automation_Tasks.sql** | 22 KB | 607 | 2 | 20 min |

**Total:** 343 KB | 8,502 lines | 23 scripts | ~3 hours

### 🛠️ Utility Scripts

| File | Size | Purpose |
|------|------|---------|
| **create_consolidated_worksheets.py** | 9.9 KB | Python script that generated the consolidated worksheets |

---

## 🚀 Getting Started

### Option 1: Full Deployment (Recommended)

Execute all 8 consolidated worksheets in order:

1. Open **QUICK_REFERENCE.md** for step-by-step instructions
2. Execute worksheets 01 through 08 sequentially
3. Follow post-execution checklist
4. Total time: ~3 hours

### Option 2: Quick Test

Use the quick start script for rapid testing:

```sql
-- Execute this single file for a quick test deployment
-- Location: quick_start.sql
```

### Option 3: Individual Modules

Execute individual modules as needed (ensure prerequisites are met).

---

## 📖 Documentation

### Essential Reading

1. **QUICK_REFERENCE.md** (9.4 KB)
   - Quick commands and troubleshooting
   - Post-execution checklist
   - Success criteria

2. **CONSOLIDATED_WORKSHEETS_SUMMARY.md** (21 KB)
   - Complete module descriptions
   - Architecture details
   - Cost estimates
   - Maintenance tasks

### Technical Details

Each consolidated worksheet includes:
- Module header with prerequisites
- Combined SQL from all module scripts
- Section dividers for navigation
- Verification queries
- Best practices and design notes
- Module completion summary

---

## 🎯 What Gets Created

### Infrastructure (Module 01)

- **2 Databases:** FINOPS_CONTROL_DB, FINOPS_ANALYTICS_DB
- **10 Schemas:** CONFIG, COST_DATA, CHARGEBACK, BUDGET, OPTIMIZATION, PROCEDURES, MONITORING, and 3 aggregate schemas
- **3 Warehouses:** FINOPS_WH_ADMIN (XSMALL), FINOPS_WH_ETL (SMALL), FINOPS_WH_REPORTING (SMALL)
- **1 Resource Monitor:** FINOPS_FRAMEWORK_MONITOR (50 credits/month)
- **4 Roles:** FINOPS_ADMIN_ROLE, FINOPS_ANALYST_ROLE, FINOPS_TEAM_LEAD_ROLE, FINOPS_EXECUTIVE_ROLE

### Cost Collection (Module 02)

- **4 Fact Tables:** Warehouse costs, query costs, storage costs, serverless costs
- **1 Config Table:** GLOBAL_SETTINGS (credit pricing, thresholds)
- **1 Audit Table:** PROCEDURE_EXECUTION_LOG
- **3 Stored Procedures:** SP_COLLECT_WAREHOUSE_COSTS, SP_COLLECT_QUERY_COSTS, SP_COLLECT_STORAGE_COSTS

### Attribution (Module 03)

- **4 Dimension Tables:** Cost centers, teams, departments, projects (SCD Type 2)
- **3 Mapping Tables:** User mappings, warehouse mappings, role mappings (SCD Type 2)
- **2 Attribution Procedures:** Update mappings and attribute costs

### Budgeting (Module 04)

- **3 Budget Tables:** Definitions, vs actual, alert history
- **3 Budget Procedures:** Check budgets, send alerts, forecast costs

### BI Tools (Module 05)

- **2 BI Tool Tables:** Classification rules, cost summary
- **2 BI Tool Procedures:** Classify channels, analyze costs
- Detection for: Power BI, Tableau, Looker, dbt, Streamlit, Airflow, Fivetran, Talend, Matillion

### Optimization (Module 06)

- **3 Optimization Tables:** Recommendations, idle warehouse log, expensive query log
- **3 Optimization Procedures:** Generate recommendations, analyze idle warehouses, identify expensive queries

### Monitoring (Module 07)

- **9 Monitoring Views:** Executive summary, cost trends, warehouse analytics, query analytics, chargeback reports
- Row-level security for team-specific views

### Automation (Module 08)

- **5 Scheduled Tasks:**
  - TASK_COLLECT_WAREHOUSE_COSTS (hourly)
  - TASK_COLLECT_QUERY_COSTS (hourly)
  - TASK_COLLECT_STORAGE_COSTS (daily)
  - TASK_CHECK_BUDGETS (daily)
  - TASK_GENERATE_RECOMMENDATIONS (weekly)
- **3 Monitoring Views:** Task execution history, task errors, task schedule

---

## 💰 Estimated Costs

### Framework Runtime

- **Compute:** ~44 credits/month (~$131/month @ $3/credit)
- **Storage (12 months):** ~200 GB (~$140/month @ $23/TB/month)
- **Total:** ~$270/month after 12 months

### Resource Limits

- **Resource Monitor:** 50 credits/month (~$150) with 10% buffer
- **Warehouse auto-suspend:** 60-300 seconds
- **Cost per collection:** 0.01-0.05 credits

---

## ✅ Success Criteria

Framework is successfully deployed when:

1. ✅ All 8 modules executed without errors
2. ✅ Cost data collecting every hour (warehouse + query costs)
3. ✅ Storage costs collecting daily
4. ✅ Attribution mappings populated (>95% allocation)
5. ✅ Tasks running on schedule without failures
6. ✅ Budget alerts configured and operational
7. ✅ Dashboards displaying cost data
8. ✅ Framework cost <50 credits/month

---

## 🛠️ Maintenance

### Daily
- Monitor task execution (check VW_TASK_EXECUTION_HISTORY)
- Review budget alerts
- Check for anomalies in cost data

### Weekly
- Review optimization recommendations
- Analyze BI tool cost trends
- Verify unallocated costs <5%

### Monthly
- Update credit pricing (if contract changes)
- Review and adjust budgets
- Audit role grants
- Implement high-priority optimization recommendations

### Quarterly
- Update SCD Type 2 mappings for org changes
- Review and tune alert thresholds
- Archive old data (>12 months)
- Performance tuning (clustering, partitioning)

---

## 🧹 Cleanup

To remove all FinOps objects:

```bash
# Execute cleanup script
cleanup.sql
```

Or use ACCOUNTADMIN role:

```sql
USE ROLE ACCOUNTADMIN;

-- Drop databases
DROP DATABASE IF EXISTS FINOPS_CONTROL_DB CASCADE;
DROP DATABASE IF EXISTS FINOPS_ANALYTICS_DB CASCADE;

-- Drop warehouses
DROP WAREHOUSE IF EXISTS FINOPS_WH_ADMIN;
DROP WAREHOUSE IF EXISTS FINOPS_WH_ETL;
DROP WAREHOUSE IF EXISTS FINOPS_WH_REPORTING;

-- Drop resource monitor
DROP RESOURCE MONITOR IF EXISTS FINOPS_FRAMEWORK_MONITOR;

-- Drop roles
DROP ROLE IF EXISTS FINOPS_ADMIN_ROLE;
DROP ROLE IF EXISTS FINOPS_ANALYST_ROLE;
DROP ROLE IF EXISTS FINOPS_TEAM_LEAD_ROLE;
DROP ROLE IF EXISTS FINOPS_EXECUTIVE_ROLE;
```

---

## 🔗 Related Directories

### Source Modules (Individual Scripts)

Original module scripts are located in:
- `../module_01_foundation_setup/` (3 scripts)
- `../module_02_cost_collection/` (4 scripts)
- `../module_03_chargeback_attribution/` (3 scripts)
- `../module_04_budget_controls/` (3 scripts)
- `../module_05_bi_tool_detection/` (2 scripts)
- `../module_06_optimization_recommendations/` (3 scripts)
- `../module_07_monitoring_views/` (3 scripts)
- `../module_08_automation_tasks/` (2 scripts)

**Note:** The consolidated worksheets in this directory combine all individual module scripts for easier execution.

---

## 📚 Additional Resources

### Snowflake Documentation
- [ACCOUNT_USAGE Views](https://docs.snowflake.com/en/sql-reference/account-usage.html)
- [Snowflake Pricing](https://www.snowflake.com/pricing/)
- [Tasks & Scheduling](https://docs.snowflake.com/en/user-guide/tasks-intro.html)
- [Resource Monitors](https://docs.snowflake.com/en/user-guide/resource-monitors.html)

### FinOps Resources
- [FinOps Foundation](https://www.finops.org/)
- [Cloud FinOps Book](https://www.finops.org/resources/book/)

---

## 📝 Change Log

### 2026-02-08
- **Initial Release:** Created all 8 consolidated worksheets
- **Total:** 343 KB, 8,502 lines, 23 combined scripts
- **Generator:** create_consolidated_worksheets.py
- **Documentation:** QUICK_REFERENCE.md, CONSOLIDATED_WORKSHEETS_SUMMARY.md

---

## 👤 Author

**Snowbrix Academy**
Enterprise FinOps Dashboard for Snowflake
Production-Grade Data Engineering. No Fluff.

---

**Need help?** Start with `QUICK_REFERENCE.md` for step-by-step instructions.
