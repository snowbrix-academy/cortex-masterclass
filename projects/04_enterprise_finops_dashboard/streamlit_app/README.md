# Enterprise FinOps Dashboard for Snowflake

Production-grade Streamlit multi-page application for Snowflake cost management, chargeback, and optimization.

## Overview

This dashboard provides comprehensive visibility into Snowflake costs with:

- **Executive Summary** - High-level KPIs and cost trends for leadership
- **Warehouse Analytics** - Detailed warehouse utilization and efficiency metrics
- **Query Cost Analysis** - Query-level cost breakdown and optimization candidates
- **Chargeback Report** - Entity-level cost attribution with drill-down capability
- **Budget Management** - Budget tracking, alerts, and forecasting
- **Optimization Recommendations** - AI-powered cost optimization opportunities
- **Admin Config** - System administration and configuration management

## Architecture

```
streamlit_app/
├── app.py                          # Main entry point with navigation
├── components/
│   ├── data.py                     # Data fetch functions (15+ functions)
│   ├── filters.py                  # Reusable filter components
│   ├── charts.py                   # Plotly chart functions
│   └── utils.py                    # Utility functions (formatting, export)
├── pages/
│   ├── 01_Executive_Summary.py
│   ├── 02_Warehouse_Analytics.py
│   ├── 03_Query_Cost_Analysis.py
│   ├── 04_Chargeback_Report.py
│   ├── 05_Budget_Management.py
│   ├── 06_Optimization_Recommendations.py
│   └── 07_Admin_Config.py
└── requirements.txt                # Python dependencies
```

## Prerequisites

- Python 3.9 or higher
- Snowflake account with FinOps framework deployed
- Appropriate Snowflake role with read access to:
  - `FINOPS_CONTROL_DB` database
  - `FINOPS_ANALYTICS_DB` database
  - `SNOWFLAKE.ACCOUNT_USAGE` views

## Installation

### 1. Clone the repository

```bash
cd C:/work/code/youtube/snowbrix_academy/projects/04_enterprise_finops_dashboard/streamlit_app
```

### 2. Create virtual environment

```bash
python -m venv venv

# Windows
venv\Scripts\activate

# Linux/Mac
source venv/bin/activate
```

### 3. Install dependencies

```bash
pip install -r requirements.txt
```

### 4. Configure Snowflake connection

Create `.streamlit/secrets.toml` file:

```toml
[snowflake]
account = "your_account"
user = "your_username"
password = "your_password"
warehouse = "FINOPS_WH_REPORTING_S"
database = "FINOPS_ANALYTICS_DB"
schema = "REPORTING"
role = "FINOPS_ANALYST_ROLE"
```

**Security Note:** Never commit `secrets.toml` to version control. Add `.streamlit/` to `.gitignore`.

### Alternative: Environment Variables

Instead of `secrets.toml`, you can set environment variables:

```bash
# Windows PowerShell
$env:SNOWFLAKE_ACCOUNT = "your_account"
$env:SNOWFLAKE_USER = "your_username"
$env:SNOWFLAKE_PASSWORD = "your_password"
$env:SNOWFLAKE_WAREHOUSE = "FINOPS_WH_REPORTING_S"
$env:SNOWFLAKE_DATABASE = "FINOPS_ANALYTICS_DB"
$env:SNOWFLAKE_SCHEMA = "REPORTING"
$env:SNOWFLAKE_ROLE = "FINOPS_ANALYST_ROLE"

# Linux/Mac
export SNOWFLAKE_ACCOUNT="your_account"
export SNOWFLAKE_USER="your_username"
export SNOWFLAKE_PASSWORD="your_password"
export SNOWFLAKE_WAREHOUSE="FINOPS_WH_REPORTING_S"
export SNOWFLAKE_DATABASE="FINOPS_ANALYTICS_DB"
export SNOWFLAKE_SCHEMA="REPORTING"
export SNOWFLAKE_ROLE="FINOPS_ANALYST_ROLE"
```

## Running the Dashboard

### Local Development

```bash
streamlit run app.py
```

The dashboard will open at `http://localhost:8501`

### With Custom Port

```bash
streamlit run app.py --server.port 8080
```

### Production Deployment

For production, use Streamlit Community Cloud or deploy to:

- **AWS EC2** with Docker
- **Azure App Service**
- **Google Cloud Run**
- **Snowflake Native App** (Streamlit-in-Snowflake)

Example Dockerfile:

```dockerfile
FROM python:3.9-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .

EXPOSE 8501

CMD ["streamlit", "run", "app.py", "--server.port=8501", "--server.address=0.0.0.0"]
```

## Configuration

### Database Connection

The dashboard connects to two Snowflake databases:

- **FINOPS_CONTROL_DB** - Raw cost data, configuration tables, stored procedures
- **FINOPS_ANALYTICS_DB** - Pre-aggregated views optimized for BI queries

Ensure the specified `role` has `SELECT` privileges on both databases.

### Required Snowflake Objects

The dashboard expects these objects to exist (created by FinOps framework):

**Views:**
- `VW_DAILY_COST_SUMMARY`
- `VW_WAREHOUSE_COST_DETAIL`
- `VW_QUERY_COST_ANALYSIS`
- `VW_ENTITY_COST_ATTRIBUTION`
- `VW_BUDGET_STATUS`
- `VW_OPTIMIZATION_RECOMMENDATIONS`

**Config Tables:**
- `ENTITY_REGISTRY`
- `USER_ENTITY_MAPPING`
- `WAREHOUSE_ENTITY_MAPPING`
- `ENTITY_BUDGET`
- `GLOBAL_SETTINGS`

If these objects don't exist, run the FinOps framework SQL scripts first:

```bash
# Navigate to SQL scripts
cd ../sql_scripts/

# Run foundation modules
snowsql -f module_01_foundation_setup/01_databases_and_schemas.sql
snowsql -f module_02_cost_collection_tables/...
# ... etc
```

## Page Descriptions

### 1. Executive Summary

**Purpose:** High-level overview for C-level and senior leadership

**Features:**
- Total spend, credits used, unallocated percentage
- 30-day cost trend line chart
- Cost breakdown by type (compute/storage/cloud services)
- Top 10 warehouses and users by cost
- Entity hierarchy treemap
- Export to CSV

**Audience:** CFO, CTO, VP Engineering, VP Finance

---

### 2. Warehouse Analytics

**Purpose:** Detailed warehouse performance and efficiency analysis

**Features:**
- Warehouse utilization heatmap (by hour and day)
- Idle time analysis
- Cost per warehouse with drill-down
- Query count trends
- Efficiency metrics (cost per query, avg daily cost)
- Auto-suspend recommendations
- Export to CSV/Excel

**Audience:** Data Platform Engineers, FinOps Team, Engineering Managers

---

### 3. Query Cost Analysis

**Purpose:** Query-level cost breakdown and optimization identification

**Features:**
- Top expensive queries table (expandable with SQL text)
- Query cost distribution histogram
- Cost by user and query type
- Optimization candidates (queries >$10)
- Query detail view with optimization suggestions
- Export to CSV

**Audience:** Data Engineers, Analysts, FinOps Team

---

### 4. Chargeback Report

**Purpose:** Cost attribution and chargeback by entity hierarchy

**Features:**
- Entity hierarchy navigation (BU > Dept > Team)
- Cost breakdown by entity type
- Drill-down capability
- Cost trend by entity with sparklines
- Top queries by entity
- Unallocated cost tracking
- Export to CSV/Excel

**Audience:** Finance Team, Department Heads, Cost Center Owners

---

### 5. Budget Management

**Purpose:** Budget tracking, alerts, and forecasting

**Features:**
- Budget vs actual gauge charts
- Active alert summary (critical/warning/info)
- Detailed budget status table
- Burn rate analysis
- Month-end forecast with confidence interval
- Alert history
- Export to CSV/Excel

**Audience:** Finance Team, FinOps Team, Department Managers

---

### 6. Optimization Recommendations

**Purpose:** Cost optimization opportunities and ROI tracking

**Features:**
- Recommendations by category (idle warehouse, auto-suspend, sizing, query, storage, clustering)
- Priority and status filters
- Estimated monthly savings
- Implementation tracker
- ROI analysis (estimated vs actual savings)
- Quick wins identification (high impact, low effort)
- Mark as implemented/dismissed
- Export to CSV/Excel

**Audience:** FinOps Team, Data Platform Engineers, Engineering Leadership

---

### 7. Admin Config

**Purpose:** System administration and configuration management

**Features:**
- **Register Entity** - Create BU/Dept/Team entities
- **Map User** - Assign users to entities with allocation %
- **Map Warehouse** - Assign warehouses to entities
- **Set Budget** - Configure budgets with alert thresholds
- **Global Settings** - Credit pricing, storage pricing, system config
- **System Status** - Database sizes, task status, health checks

**Audience:** FinOps Admins, Data Platform Admins

---

## Troubleshooting

### Connection Errors

**Error:** `snowflake.connector.errors.DatabaseError: 250001: Could not connect to Snowflake backend`

**Solution:**
- Verify account identifier format: `account.region.cloud` (e.g., `xy12345.us-east-1.aws`)
- Check firewall allows outbound HTTPS (port 443)
- Verify credentials in `secrets.toml`

### Permission Errors

**Error:** `SQL access control error: Insufficient privileges to operate on database 'FINOPS_CONTROL_DB'`

**Solution:**
```sql
-- Grant read access to role
USE ROLE ACCOUNTADMIN;
GRANT USAGE ON DATABASE FINOPS_CONTROL_DB TO ROLE FINOPS_ANALYST_ROLE;
GRANT USAGE ON ALL SCHEMAS IN DATABASE FINOPS_CONTROL_DB TO ROLE FINOPS_ANALYST_ROLE;
GRANT SELECT ON ALL VIEWS IN DATABASE FINOPS_CONTROL_DB TO ROLE FINOPS_ANALYST_ROLE;
```

### Missing Data

**Error:** Pages show "No data available"

**Solution:**
- Verify FinOps framework tasks are running:
  ```sql
  SHOW TASKS LIKE 'TASK_COLLECT%' IN SCHEMA FINOPS_CONTROL_DB.COST_COLLECTION;
  ```
- Check task execution history:
  ```sql
  SELECT * FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY())
  WHERE NAME LIKE 'TASK_COLLECT%'
  ORDER BY SCHEDULED_TIME DESC
  LIMIT 10;
  ```
- Manually trigger cost collection:
  ```sql
  EXECUTE TASK FINOPS_CONTROL_DB.COST_COLLECTION.TASK_COLLECT_WAREHOUSE_COSTS;
  ```

### Performance Issues

**Symptom:** Dashboard is slow to load

**Solution:**
- Reduce date range in filters (default to 7 days instead of 30)
- Ensure reporting views are materialized:
  ```sql
  -- Check view definitions
  SHOW VIEWS IN SCHEMA FINOPS_ANALYTICS_DB.REPORTING;

  -- Convert to materialized views if needed
  CREATE OR REPLACE MATERIALIZED VIEW VW_DAILY_COST_SUMMARY AS
  SELECT ...;
  ```
- Use a larger warehouse for reporting:
  ```sql
  ALTER WAREHOUSE FINOPS_WH_REPORTING_S SET WAREHOUSE_SIZE = 'MEDIUM';
  ```

## Development

### Adding New Pages

1. Create new file in `pages/` with naming convention: `NN_Page_Name.py`
2. Import required components:
   ```python
   from components import data, filters, charts, utils
   ```
3. Use consistent page structure (see existing pages as templates)
4. Add data fetch function to `components/data.py` if needed

### Adding New Charts

Add chart function to `components/charts.py`:

```python
def create_custom_chart(df, x_col, y_col, title='Chart Title'):
    """
    Create custom chart.

    Args:
        df: DataFrame
        x_col: X-axis column
        y_col: Y-axis column
        title: Chart title

    Returns:
        Plotly Figure
    """
    fig = go.Figure()
    # ... chart creation logic
    return fig
```

### Adding New Filters

Add filter function to `components/filters.py`:

```python
def render_custom_filter(key_prefix="main"):
    """
    Render custom filter in sidebar.

    Args:
        key_prefix: Unique prefix for widget keys

    Returns:
        Selected value(s)
    """
    st.sidebar.markdown("### Filter Name")
    selected = st.sidebar.selectbox(...)
    return selected
```

## Support

For issues or questions:

1. Check [Snowbrix Academy documentation](https://github.com/snowbrix/academy)
2. Review [Streamlit documentation](https://docs.streamlit.io)
3. Review [Snowflake Python connector docs](https://docs.snowflake.com/en/user-guide/python-connector)

## License

MIT License - See project root for details

## Credits

Built by **Snowbrix Academy** - Production-grade data engineering education

**Course:** Enterprise FinOps Dashboard for Snowflake
**Module:** Streamlit Multi-Page Application
**Author:** Snowbrix Data Architects
