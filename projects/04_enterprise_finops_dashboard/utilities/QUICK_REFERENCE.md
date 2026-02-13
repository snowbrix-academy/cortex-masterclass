# FinOps Consolidated Worksheets - Quick Reference

## 📁 File Locations

All consolidated worksheets are located in:
```
C:/work/code/youtube/snowbrix_academy/projects/04_enterprise_finops_dashboard/utilities/
```

---

## 📋 Execution Order

Execute these files **sequentially** in Snowsight or VS Code:

| Order | File | Est. Time | Description |
|-------|------|-----------|-------------|
| 1️⃣ | `FINOPS_Module_01_Foundation_Setup.sql` | 15 min | Databases, warehouses, roles |
| 2️⃣ | `FINOPS_Module_02_Cost_Collection.sql` | 30 min | Cost tables, collection procedures |
| 3️⃣ | `FINOPS_Module_03_Chargeback_Attribution.sql` | 25 min | SCD Type 2 dimensions, mappings |
| 4️⃣ | `FINOPS_Module_04_Budget_Controls.sql` | 25 min | Budgets, alerts, forecasting |
| 5️⃣ | `FINOPS_Module_05_BI_Tool_Detection.sql` | 15 min | BI tool classification |
| 6️⃣ | `FINOPS_Module_06_Optimization_Recommendations.sql` | 30 min | Cost optimization analysis |
| 7️⃣ | `FINOPS_Module_07_Monitoring_Views.sql` | 20 min | Dashboards, reporting views |
| 8️⃣ | `FINOPS_Module_08_Automation_Tasks.sql` | 20 min | Scheduled tasks, automation |

**Total Time:** ~3 hours for complete deployment

---

## ⚡ Quick Commands

### Open in Snowsight
1. Navigate to Snowsight → Worksheets
2. Click "+" → "New Worksheet from File"
3. Select a consolidated worksheet
4. Execute with Ctrl+Enter (or Cmd+Enter on Mac)

### Execute in VS Code
1. Install Snowflake extension
2. Open a consolidated worksheet
3. Configure Snowflake connection
4. Select all (Ctrl+A) and execute

---

## 🔐 Required Role

```sql
USE ROLE FINOPS_ADMIN_ROLE;
```

If you haven't completed Module 01 yet, use:
```sql
USE ROLE ACCOUNTADMIN;
```

---

## ✅ Post-Execution Checklist

After completing all 8 modules:

### 1. Test Cost Collection
```sql
-- Test warehouse cost collection
CALL FINOPS_CONTROL_DB.PROCEDURES.SP_COLLECT_WAREHOUSE_COSTS(24, TRUE);

-- Test query cost collection
CALL FINOPS_CONTROL_DB.PROCEDURES.SP_COLLECT_QUERY_COSTS(24, TRUE, 100);

-- Test storage cost collection
CALL FINOPS_CONTROL_DB.PROCEDURES.SP_COLLECT_STORAGE_COSTS(7, TRUE);
```

### 2. Verify Data Collection
```sql
-- Check warehouse costs (last 24 hours)
SELECT COUNT(*), SUM(COST_USD) AS TOTAL_COST
FROM FINOPS_CONTROL_DB.COST_DATA.FACT_WAREHOUSE_COST_HISTORY
WHERE START_TIME >= DATEADD(HOUR, -24, CURRENT_TIMESTAMP());

-- Check query costs (last 24 hours)
SELECT COUNT(*), SUM(COST_USD) AS TOTAL_COST
FROM FINOPS_CONTROL_DB.COST_DATA.FACT_QUERY_COST_HISTORY
WHERE QUERY_DATE >= DATEADD(DAY, -1, CURRENT_DATE());

-- Check storage costs (latest date)
SELECT * FROM FINOPS_CONTROL_DB.COST_DATA.FACT_STORAGE_COST_HISTORY
WHERE USAGE_DATE = (SELECT MAX(USAGE_DATE) FROM FINOPS_CONTROL_DB.COST_DATA.FACT_STORAGE_COST_HISTORY);
```

### 3. Populate Mappings
```sql
-- Add user-to-team mappings (example)
INSERT INTO FINOPS_CONTROL_DB.CHARGEBACK.DIM_USER_MAPPING (
    USER_NAME, TEAM, DEPARTMENT, BUSINESS_UNIT, COST_CENTER, EFFECTIVE_FROM, IS_CURRENT
) VALUES
    ('JOHN.DOE@COMPANY.COM', 'DATA_ENGINEERING', 'ENGINEERING', 'TECHNOLOGY', 'CC-1001', CURRENT_DATE(), TRUE),
    ('JANE.SMITH@COMPANY.COM', 'DATA_ANALYTICS', 'ANALYTICS', 'DATA', 'CC-1002', CURRENT_DATE(), TRUE);

-- Add warehouse-to-team mappings (example)
INSERT INTO FINOPS_CONTROL_DB.CHARGEBACK.DIM_WAREHOUSE_MAPPING (
    WAREHOUSE_NAME, TEAM, PROJECT, ENVIRONMENT, COST_CENTER, EFFECTIVE_FROM, IS_CURRENT
) VALUES
    ('PROD_ETL_WH', 'DATA_ENGINEERING', 'ETL_PIPELINE', 'PROD', 'CC-1001', CURRENT_DATE(), TRUE),
    ('ANALYTICS_WH', 'DATA_ANALYTICS', 'REPORTING', 'PROD', 'CC-1002', CURRENT_DATE(), TRUE);
```

### 4. Update Configuration
```sql
-- Update credit price (example: $3.50/credit)
UPDATE FINOPS_CONTROL_DB.CONFIG.GLOBAL_SETTINGS
SET SETTING_VALUE = '3.50'
WHERE SETTING_NAME = 'CREDIT_PRICE_USD';

-- Update storage price (example: $25/TB/month)
UPDATE FINOPS_CONTROL_DB.CONFIG.GLOBAL_SETTINGS
SET SETTING_VALUE = '25.00'
WHERE SETTING_NAME = 'STORAGE_PRICE_USD_PER_TB_MONTH';

-- Update timezone (example: America/Los_Angeles)
UPDATE FINOPS_CONTROL_DB.CONFIG.GLOBAL_SETTINGS
SET SETTING_VALUE = 'America/Los_Angeles'
WHERE SETTING_NAME = 'FRAMEWORK_TIMEZONE';
```

### 5. Enable Automation
```sql
-- Resume all tasks to enable automation
ALTER TASK FINOPS_CONTROL_DB.PROCEDURES.TASK_COLLECT_WAREHOUSE_COSTS RESUME;
ALTER TASK FINOPS_CONTROL_DB.PROCEDURES.TASK_COLLECT_QUERY_COSTS RESUME;
ALTER TASK FINOPS_CONTROL_DB.PROCEDURES.TASK_COLLECT_STORAGE_COSTS RESUME;
ALTER TASK FINOPS_CONTROL_DB.PROCEDURES.TASK_CHECK_BUDGETS RESUME;
ALTER TASK FINOPS_CONTROL_DB.PROCEDURES.TASK_GENERATE_RECOMMENDATIONS RESUME;

-- Verify tasks are running
SELECT
    NAME,
    STATE,
    SCHEDULE,
    WAREHOUSE,
    NEXT_SCHEDULED_TIME
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY())
WHERE DATABASE_NAME = 'FINOPS_CONTROL_DB'
ORDER BY NEXT_SCHEDULED_TIME;
```

### 6. Check Task Execution
```sql
-- Monitor task execution (after first few hours)
SELECT * FROM FINOPS_CONTROL_DB.MONITORING.VW_TASK_EXECUTION_HISTORY
ORDER BY START_TIME DESC
LIMIT 20;

-- Check for task errors
SELECT * FROM FINOPS_CONTROL_DB.MONITORING.VW_TASK_ERRORS
ORDER BY START_TIME DESC
LIMIT 10;
```

### 7. Access Dashboards
```sql
-- Executive summary
SELECT * FROM FINOPS_CONTROL_DB.MONITORING.VW_EXECUTIVE_SUMMARY;

-- Cost trend (last 30 days)
SELECT * FROM FINOPS_CONTROL_DB.MONITORING.VW_COST_TREND_DAILY
WHERE USAGE_DATE >= DATEADD(DAY, -30, CURRENT_DATE())
ORDER BY USAGE_DATE DESC;

-- Optimization opportunities
SELECT * FROM FINOPS_CONTROL_DB.MONITORING.VW_OPTIMIZATION_DASHBOARD
WHERE PRIORITY = 'HIGH' AND STATUS = 'OPEN';
```

---

## 🛠️ Troubleshooting

### Issue: Permission Denied

**Solution:** Ensure you're using the correct role
```sql
USE ROLE FINOPS_ADMIN_ROLE;
-- If that fails, use ACCOUNTADMIN temporarily
USE ROLE ACCOUNTADMIN;
```

### Issue: ACCOUNT_USAGE Views Not Accessible

**Solution:** Grant imported privileges
```sql
USE ROLE ACCOUNTADMIN;
GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE TO ROLE FINOPS_ADMIN_ROLE;
```

### Issue: Tasks Not Running

**Solution:** Check task state and warehouse
```sql
-- Check task state
SHOW TASKS IN SCHEMA FINOPS_CONTROL_DB.PROCEDURES;

-- Verify warehouse exists and is not suspended
SHOW WAREHOUSES LIKE 'FINOPS_WH_ETL';

-- Check for task errors
SELECT * FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY())
WHERE DATABASE_NAME = 'FINOPS_CONTROL_DB'
  AND STATE = 'FAILED'
ORDER BY SCHEDULED_TIME DESC
LIMIT 10;
```

### Issue: No Data in Cost Tables

**Solution:** Wait for ACCOUNT_USAGE latency (45 min - 3 hours), then manually trigger collection
```sql
-- Wait at least 1 hour after queries/warehouse activity
-- Then manually trigger collection
CALL FINOPS_CONTROL_DB.PROCEDURES.SP_COLLECT_WAREHOUSE_COSTS(24, FALSE);
CALL FINOPS_CONTROL_DB.PROCEDURES.SP_COLLECT_QUERY_COSTS(24, FALSE, 100);
CALL FINOPS_CONTROL_DB.PROCEDURES.SP_COLLECT_STORAGE_COSTS(7, FALSE);
```

### Issue: Procedure Fails

**Solution:** Check execution log for details
```sql
SELECT
    EXECUTION_ID,
    PROCEDURE_NAME,
    EXECUTION_STATUS,
    START_TIME,
    ERROR_MESSAGE,
    EXECUTION_PARAMETERS
FROM FINOPS_CONTROL_DB.AUDIT.PROCEDURE_EXECUTION_LOG
WHERE EXECUTION_STATUS = 'ERROR'
ORDER BY START_TIME DESC
LIMIT 10;
```

---

## 🧹 Cleanup (If Needed)

To remove all FinOps objects and start fresh:

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

**Or use the cleanup script:**
```
C:/work/code/youtube/snowbrix_academy/projects/04_enterprise_finops_dashboard/utilities/cleanup.sql
```

---

## 📊 Key Metrics to Monitor

### Daily
- Total cost (compute + storage)
- Cost per team/department
- Budget vs actual
- Unallocated cost percentage (<5% goal)

### Weekly
- Cost trend (vs last week)
- Top 10 most expensive warehouses
- Top 10 most expensive queries
- Top 10 most expensive users

### Monthly
- Budget variance analysis
- Optimization opportunities implemented
- ROI from cost savings
- Framework cost (should be ~$200-300/month)

---

## 🎯 Success Criteria

Framework is successfully deployed when:

1. ✅ All 8 modules executed without errors
2. ✅ Cost data flowing into COST_DATA schema (warehouse, query, storage)
3. ✅ Attribution mappings populated (users, warehouses, roles)
4. ✅ Tasks running on schedule without errors
5. ✅ Dashboards showing cost data (VW_EXECUTIVE_SUMMARY)
6. ✅ Budget alerts configured and testing
7. ✅ Unallocated costs <5% of total
8. ✅ Framework cost <50 credits/month (~$150)

---

## 📚 Documentation

- **Full Summary:** `CONSOLIDATED_WORKSHEETS_SUMMARY.md`
- **Quick Reference:** `QUICK_REFERENCE.md` (this file)
- **Cleanup Script:** `cleanup.sql`
- **Quick Start:** `quick_start.sql`

---

## 🆘 Support

For issues or questions:
1. Check the troubleshooting section above
2. Review the full summary document
3. Check PROCEDURE_EXECUTION_LOG for error details
4. Review Snowflake ACCOUNT_USAGE documentation

---

**Snowbrix Academy** | Production-Grade Data Engineering. No Fluff.
