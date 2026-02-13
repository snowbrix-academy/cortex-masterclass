# Module 09: Streamlit Dashboard Deep Dive

**Duration:** ~40 minutes
**Difficulty:** Intermediate
**Prerequisites:** Module 08 completed, basic Python knowledge helpful

---

## Script Structure

### 1. HOOK (45 seconds)

SQL views give you data. Dashboards give you insights. The Enterprise FinOps Dashboard has 7 pages: Executive Summary with KPIs and trends, Warehouse Analytics with utilization heatmaps, Query Cost Analysis with drill-down to query text, Chargeback Report with export to CSV, Budget Management with gauges and forecasts, Optimization Recommendations prioritized by savings, and Admin/Config for managing teams and settings.

All built with Streamlit and Plotly. Interactive, role-aware, production-ready.

This is what CFOs and engineering leaders actually use.

---

### 2. CORE CONTENT (34-36 minutes)

**7 dashboard pages:**

**Page 1: Executive Summary**
- st.metric cards: Total spend MTD/YTD, % change, budget utilization
- Plotly line chart: Daily spend trend (last 30 days)
- Plotly bar chart: Top 10 departments by cost
- Plotly pie chart: Cost by environment (PROD/QA/DEV)

**Page 2: Warehouse Analytics**
- Filters: Date range, warehouse, environment
- Plotly treemap: Warehouse cost breakdown
- Plotly line chart: Utilization % over time
- Plotly histogram: Idle time distribution

**Page 3: Query Cost Analysis**
- st.dataframe: Top 20 expensive queries with drill-down
- Plotly histogram: Query cost distribution
- Plotly bar chart: Cost by user
- Export button: Download to CSV

**Page 4: Chargeback Report**
- st.selectbox: Switch dimension (team/dept/project/cost center)
- Plotly bar chart: Cost by entity
- Plotly line chart: Trend over time
- Drill-down table with export

**Page 5: Budget Management**
- Plotly gauge charts: Budget % consumed per department
- st.metric: Days remaining, burn rate, forecast to month-end
- Plotly bar chart: Budget vs actual
- Alert history timeline

**Page 6: Optimization Recommendations**
- st.tabs: By category (idle, sizing, queries, storage)
- Recommendation cards with priority badges
- Plotly pie chart: Savings potential by category
- Action buttons: Mark implemented, dismiss, snooze

**Page 7: Admin/Config**
- Form: Register new chargeback entity (calls SP_REGISTER_CHARGEBACK_ENTITY)
- Input: Update credit pricing
- Button: Refresh cost data on-demand
- Audit log viewer

**Technical implementation:**

```python
import streamlit as st
import snowflake.connector
import plotly.express as px
import plotly.graph_objects as go
import pandas as pd

# Snowflake connection
@st.cache_resource
def get_snowflake_connection():
    return snowflake.connector.connect(
        user=st.secrets["snowflake"]["user"],
        password=st.secrets["snowflake"]["password"],
        account=st.secrets["snowflake"]["account"],
        warehouse='FINOPS_WH_REPORTING',
        database='FINOPS_CONTROL_DB',
        schema='MONITORING',
        role='FINOPS_ANALYST_ROLE'
    )

# Query data
@st.cache_data(ttl=600)  # Cache for 10 minutes
def load_executive_summary():
    conn = get_snowflake_connection()
    df = pd.read_sql(
        "SELECT * FROM VW_EXECUTIVE_SUMMARY",
        conn
    )
    return df

# Plotly chart example
fig = px.line(
    df,
    x='REPORT_DATE',
    y='DAILY_COST_USD',
    title='Daily Snowflake Spend (Last 30 Days)'
)
st.plotly_chart(fig, use_container_width=True)
```

### 3. HANDS-ON LAB (5 minutes)

Run Streamlit app locally, explore all 7 pages, test filters and exports, switch roles to test row-level security

### 4. RECAP (30 seconds)

Interactive dashboard turns cost data into actionable insights for all personas. Next: Module 10 — Production Deployment & Advanced Scenarios.
