# Quick Start Guide - Enterprise FinOps Dashboard

## 5-Minute Setup

### Step 1: Create secrets file

Create `.streamlit/secrets.toml`:

```bash
mkdir .streamlit
```

Add this content (replace with your Snowflake credentials):

```toml
[snowflake]
account = "xy12345.us-east-1.aws"
user = "finops_user"
password = "YourPassword123"
warehouse = "FINOPS_WH_REPORTING_S"
database = "FINOPS_ANALYTICS_DB"
schema = "REPORTING"
role = "FINOPS_ANALYST_ROLE"
```

### Step 2: Install dependencies

```bash
pip install -r requirements.txt
```

### Step 3: Run the dashboard

```bash
streamlit run app.py
```

Dashboard opens at: `http://localhost:8501`

---

## First-Time Setup Checklist

Before running the dashboard, ensure these exist in Snowflake:

### ✅ Databases
- [ ] `FINOPS_CONTROL_DB` exists
- [ ] `FINOPS_ANALYTICS_DB` exists

```sql
SHOW DATABASES LIKE 'FINOPS%';
```

### ✅ Role & Permissions
- [ ] Role `FINOPS_ANALYST_ROLE` exists
- [ ] Role has `USAGE` on both databases
- [ ] Role has `SELECT` on all views

```sql
USE ROLE ACCOUNTADMIN;

CREATE ROLE IF NOT EXISTS FINOPS_ANALYST_ROLE;

GRANT USAGE ON DATABASE FINOPS_CONTROL_DB TO ROLE FINOPS_ANALYST_ROLE;
GRANT USAGE ON DATABASE FINOPS_ANALYTICS_DB TO ROLE FINOPS_ANALYST_ROLE;

GRANT USAGE ON ALL SCHEMAS IN DATABASE FINOPS_CONTROL_DB TO ROLE FINOPS_ANALYST_ROLE;
GRANT USAGE ON ALL SCHEMAS IN DATABASE FINOPS_ANALYTICS_DB TO ROLE FINOPS_ANALYST_ROLE;

GRANT SELECT ON ALL VIEWS IN DATABASE FINOPS_ANALYTICS_DB TO ROLE FINOPS_ANALYST_ROLE;
```

### ✅ Warehouse
- [ ] Warehouse `FINOPS_WH_REPORTING_S` exists

```sql
CREATE WAREHOUSE IF NOT EXISTS FINOPS_WH_REPORTING_S
WITH WAREHOUSE_SIZE = 'SMALL'
     AUTO_SUSPEND = 300
     AUTO_RESUME = TRUE
     INITIALLY_SUSPENDED = TRUE;

GRANT USAGE ON WAREHOUSE FINOPS_WH_REPORTING_S TO ROLE FINOPS_ANALYST_ROLE;
```

### ✅ Cost Data Collection
- [ ] Cost collection tasks are running

```sql
SHOW TASKS IN SCHEMA FINOPS_CONTROL_DB.COST_COLLECTION;

-- Check task execution history
SELECT
    NAME,
    STATE,
    SCHEDULED_TIME,
    COMPLETED_TIME,
    ERROR_MESSAGE
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY())
WHERE NAME LIKE 'TASK_COLLECT%'
ORDER BY SCHEDULED_TIME DESC
LIMIT 10;
```

### ✅ Verify Data Exists
- [ ] Cost data is populated

```sql
USE ROLE FINOPS_ANALYST_ROLE;
USE DATABASE FINOPS_ANALYTICS_DB;
USE SCHEMA REPORTING;

-- Check if data exists
SELECT COUNT(*) FROM VW_DAILY_COST_SUMMARY;
SELECT COUNT(*) FROM VW_WAREHOUSE_COST_DETAIL;
SELECT COUNT(*) FROM VW_ENTITY_COST_ATTRIBUTION;
```

If counts are 0, manually trigger cost collection:

```sql
USE ROLE ACCOUNTADMIN;
EXECUTE TASK FINOPS_CONTROL_DB.COST_COLLECTION.TASK_COLLECT_WAREHOUSE_COSTS;
EXECUTE TASK FINOPS_CONTROL_DB.COST_COLLECTION.TASK_COLLECT_QUERY_HISTORY;
```

---

## Troubleshooting

### Problem: "Could not connect to Snowflake"

**Check:**
1. Account identifier format: `account.region.cloud`
2. Credentials are correct
3. Network allows HTTPS (port 443)

**Test connection:**
```bash
python -c "import snowflake.connector; print(snowflake.connector.connect(account='xy12345', user='user', password='pass'))"
```

### Problem: "No data available"

**Check:**
1. Tasks are running: `SHOW TASKS;`
2. Data exists in views: `SELECT COUNT(*) FROM VW_DAILY_COST_SUMMARY;`
3. Date range filter is not too restrictive

### Problem: "Insufficient privileges"

**Fix:**
```sql
USE ROLE ACCOUNTADMIN;
GRANT SELECT ON ALL VIEWS IN DATABASE FINOPS_ANALYTICS_DB TO ROLE FINOPS_ANALYST_ROLE;
```

### Problem: Dashboard is slow

**Solutions:**
1. Reduce date range (use 7 days instead of 30)
2. Use larger warehouse: `ALTER WAREHOUSE ... SET WAREHOUSE_SIZE = 'MEDIUM';`
3. Materialize views instead of regular views
4. Add partitioning to large tables

---

## Page Navigation

Once running, the dashboard has 7 pages:

| Page | URL | Purpose |
|------|-----|---------|
| Executive Summary | `/01_Executive_Summary` | KPIs and trends for leadership |
| Warehouse Analytics | `/02_Warehouse_Analytics` | Warehouse efficiency and utilization |
| Query Cost Analysis | `/03_Query_Cost_Analysis` | Expensive queries and optimization |
| Chargeback Report | `/04_Chargeback_Report` | Entity-level cost attribution |
| Budget Management | `/05_Budget_Management` | Budget tracking and alerts |
| Optimization Recommendations | `/06_Optimization_Recommendations` | Cost saving opportunities |
| Admin Config | `/07_Admin_Config` | System configuration |

---

## Next Steps

1. **Configure Entities** → Go to "Admin Config" → "Register Entity"
2. **Map Warehouses** → "Admin Config" → "Map Warehouse"
3. **Set Budgets** → "Admin Config" → "Set Budget"
4. **View Reports** → Navigate to "Executive Summary"

---

## Getting Help

- **Documentation**: See `README.md`
- **Snowflake Docs**: https://docs.snowflake.com
- **Streamlit Docs**: https://docs.streamlit.io

---

## Security Notes

⚠️ **NEVER commit `secrets.toml` to git!**

Add to `.gitignore`:
```
.streamlit/secrets.toml
.streamlit/*.toml
*.env
venv/
__pycache__/
```

For production, use:
- Environment variables
- Snowflake external OAuth
- Key pair authentication
- Secrets management service (AWS Secrets Manager, Azure Key Vault)
