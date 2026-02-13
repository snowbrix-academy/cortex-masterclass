# Enterprise FinOps Dashboard for Snowflake

## Snowbrix Academy — Production-Grade Data Engineering. No Fluff.

---

## What Is This?

A **complete, production-ready cost management and financial operations (FinOps) framework** for Snowflake that provides real-time cost visibility, automated chargeback attribution, budget controls, and actionable optimization recommendations.

**The Problem It Solves:**
- Organizations waste 30-40% of Snowflake spend on idle warehouses, inefficient queries, and lack of visibility
- Finance teams demand chargeback by department/team/project but lack tooling
- Platform teams lack real-time cost monitoring and automated controls
- No unified view of warehouse utilization, query costs, and budget burn rates

**The Solution:**
- Real-time cost collection from ACCOUNT_USAGE views
- Multi-dimensional chargeback attribution (by warehouse, user, role, tag, team, department)
- Automated budget controls with 3-tier alerts (80%/90%/100% thresholds)
- Interactive Streamlit dashboard with executive summary, drill-downs, and optimization insights
- Cost forecasting and anomaly detection
- Automated optimization recommendations

---

## Value Proposition

### For CFOs and Finance Teams
- **Chargeback visibility**: Attribute every dollar to team/department/project/cost center
- **Budget enforcement**: Automated alerts when teams approach spending limits
- **Cost forecasting**: Project month-end and quarter-end spend with confidence
- **Audit trail**: Complete lineage from Snowflake credit to business entity

### For Data Platform Teams
- **Real-time monitoring**: Warehouse utilization, idle time, query costs updated hourly
- **Optimization insights**: Automated recommendations for warehouse sizing, auto-suspend tuning, query optimization
- **Anomaly detection**: Alert on unusual spend spikes (>2σ from baseline)
- **Multi-tenant attribution**: Handle shared warehouses with proportional cost allocation

### For Engineering Teams
- **Self-service visibility**: Each team sees their own costs without admin access
- **Query-level details**: Identify expensive queries and optimize before month-end
- **Tag-based attribution**: Use QUERY_TAG to attribute costs to specific projects or pipelines

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        FINOPS ARCHITECTURE                                   │
│                                                                             │
│  ┌─────────────────────┐          ┌─────────────────────┐                  │
│  │  ACCOUNT_USAGE      │          │  INFORMATION_SCHEMA │                  │
│  │  - WAREHOUSE_       │          │  - TAG_REFERENCES   │                  │
│  │    METERING_HISTORY │          │  - TAGS             │                  │
│  │  - QUERY_HISTORY    │          │                     │                  │
│  │  - STORAGE_USAGE    │          │                     │                  │
│  │  - DATABASE_STORAGE │          │                     │                  │
│  │  - TASK_HISTORY     │          │                     │                  │
│  │  - PIPE_USAGE_      │          │                     │                  │
│  │    HISTORY          │          │                     │                  │
│  └─────────┬───────────┘          └──────────┬──────────┘                  │
│            │                                  │                             │
│            │   ┌──────────────────────────────┘                             │
│            │   │                                                            │
│            └───┼───────────────┐                                            │
│                │               │                                            │
│         ┌──────▼───────────────▼──────────┐                                 │
│         │  FINOPS_CONTROL_DB              │                                 │
│         │                                 │                                 │
│         │  ┌────────────────────────┐     │                                 │
│         │  │  CONFIG Schema         │     │  Configuration & Metadata       │
│         │  │  - Global settings     │     │                                 │
│         │  │  - Tag taxonomy        │     │                                 │
│         │  │  - Credit pricing      │     │                                 │
│         │  │  - Alert config        │     │                                 │
│         │  └────────────────────────┘     │                                 │
│         │                                 │                                 │
│         │  ┌────────────────────────┐     │                                 │
│         │  │  COST_DATA Schema      │     │  Raw Cost Facts                 │
│         │  │  - Warehouse costs     │     │                                 │
│         │  │  - Query costs         │     │                                 │
│         │  │  - Storage costs       │     │                                 │
│         │  │  - Serverless costs    │     │                                 │
│         │  └────────────────────────┘     │                                 │
│         │                                 │                                 │
│         │  ┌────────────────────────┐     │                                 │
│         │  │  CHARGEBACK Schema     │     │  Attribution Dimensions         │
│         │  │  - Dim cost center     │     │                                 │
│         │  │  - Dim warehouse       │     │  (SCD Type 2 for all)           │
│         │  │  - Dim user            │     │                                 │
│         │  │  - Dim role hierarchy  │     │                                 │
│         │  │  - Fact attributed cost│     │                                 │
│         │  └────────────────────────┘     │                                 │
│         │                                 │                                 │
│         │  ┌────────────────────────┐     │                                 │
│         │  │  BUDGET Schema         │     │  Budget Management              │
│         │  │  - Budget definitions  │     │                                 │
│         │  │  - Budget vs actual    │     │                                 │
│         │  │  - Alert history       │     │                                 │
│         │  │  - Forecast            │     │                                 │
│         │  └────────────────────────┘     │                                 │
│         │                                 │                                 │
│         │  ┌────────────────────────┐     │                                 │
│         │  │  OPTIMIZATION Schema   │     │  Cost Optimization              │
│         │  │  - Recommendations     │     │                                 │
│         │  │  - Idle warehouse log  │     │                                 │
│         │  │  - Query optimization  │     │                                 │
│         │  └────────────────────────┘     │                                 │
│         │                                 │                                 │
│         │  ┌────────────────────────┐     │                                 │
│         │  │  MONITORING Schema     │     │  Reporting Views                │
│         │  │  - VW_Executive_Summary│     │                                 │
│         │  │  - VW_Warehouse_       │     │  (Row-level security enforced)  │
│         │  │    Analytics           │     │                                 │
│         │  │  - VW_Chargeback_      │     │                                 │
│         │  │    Report              │     │                                 │
│         │  │  - VW_Budget_Status    │     │                                 │
│         │  │  - VW_Optimization_    │     │                                 │
│         │  │    Dashboard           │     │                                 │
│         │  └────────────────────────┘     │                                 │
│         │                                 │                                 │
│         │  ┌────────────────────────┐     │                                 │
│         │  │  PROCEDURES Schema     │     │  Stored Procedures (JavaScript) │
│         │  │  - SP_COLLECT_WH_COSTS │     │                                 │
│         │  │  - SP_COLLECT_QRY_COSTS│     │                                 │
│         │  │  - SP_CALCULATE_       │     │                                 │
│         │  │    CHARGEBACK          │     │                                 │
│         │  │  - SP_CHECK_BUDGETS    │     │                                 │
│         │  │  - SP_GENERATE_        │     │                                 │
│         │  │    RECOMMENDATIONS     │     │                                 │
│         │  └────────────────────────┘     │                                 │
│         └─────────────────────────────────┘                                 │
│                        │                                                    │
│                        │                                                    │
│         ┌──────────────▼──────────────────┐                                 │
│         │  FINOPS_ANALYTICS_DB            │                                 │
│         │                                 │                                 │
│         │  Pre-aggregated metrics for     │  Performance-optimized for      │
│         │  fast BI tool consumption       │  Power BI, Tableau, Streamlit   │
│         │                                 │                                 │
│         │  - Daily cost by warehouse      │                                 │
│         │  - Daily cost by team/dept      │                                 │
│         │  - Weekly/monthly rollups       │                                 │
│         │  - Top N queries by cost        │                                 │
│         └─────────────────────────────────┘                                 │
│                        │                                                    │
│                        │                                                    │
│         ┌──────────────▼──────────────────┐                                 │
│         │  Streamlit Dashboard            │                                 │
│         │                                 │                                 │
│         │  Page 1: Executive Summary      │  Role-based access:             │
│         │  Page 2: Warehouse Analytics    │  - FINOPS_ADMIN (all data)      │
│         │  Page 3: Query Cost Analysis    │  - FINOPS_ANALYST (read-only)   │
│         │  Page 4: Chargeback Report      │  - FINOPS_TEAM_LEAD (team only) │
│         │  Page 5: Budget Management      │  - FINOPS_EXECUTIVE (summary)   │
│         │  Page 6: Optimization           │                                 │
│         │  Page 7: Admin / Config         │                                 │
│         └─────────────────────────────────┘                                 │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Module Structure

| Module | Topic | Duration | Key Skills |
|--------|-------|----------|------------|
| **01** | Foundation Setup | 25 min | Databases, warehouses, roles, resource monitors, RBAC |
| **02** | Cost Collection | 35 min | Stored procedures to collect warehouse, query, storage, serverless costs |
| **03** | Chargeback Attribution | 40 min | Multi-dimensional attribution, SCD Type 2 dimensions, tag-based allocation |
| **04** | Budget Controls | 30 min | Budget definitions, 3-tier alerts, anomaly detection, forecasting |
| **05** | BI Tool Detection | 25 min | User classification, Power BI/Tableau/dbt detection, channel cost tracking |
| **06** | Optimization Recommendations | 30 min | Idle warehouse detection, query optimization, auto-suspend tuning |
| **07** | Monitoring Views | 35 min | 10+ semantic views for reporting, row-level security, pre-aggregation |
| **08** | Automation with Tasks | 20 min | Hourly/daily task scheduling, DAG dependencies, error handling |

**Total Lab Time: ~4-5 hours**

---

## Quick Start

### Prerequisites
- Snowflake account (Enterprise Edition recommended for tagging)
- ACCOUNTADMIN or SYSADMIN role access
- Basic understanding of Snowflake cost model (compute credits, storage)
- Snowsight web interface or SnowSQL CLI

### Setup (20 minutes)

Run these scripts in order:

```
1. module_01_foundation_setup/01_databases_and_schemas.sql
2. module_01_foundation_setup/02_warehouses.sql
3. module_01_foundation_setup/03_roles_and_grants.sql
4. module_02_cost_collection/01_cost_tables.sql
5. module_02_cost_collection/02_sp_collect_warehouse_costs.sql
6. module_02_cost_collection/03_sp_collect_query_costs.sql
7. module_03_chargeback_attribution/01_dimension_tables.sql
8. module_03_chargeback_attribution/02_sp_calculate_chargeback.sql
9. module_04_budget_controls/01_budget_tables.sql
10. module_04_budget_controls/02_sp_check_budgets.sql
```

Or use: `utilities/quick_start.sql` for a guided walkthrough.

### Your First Chargeback Report (5 minutes)

```sql
-- 1. Configure credit pricing for your contract
UPDATE FINOPS_CONTROL_DB.CONFIG.GLOBAL_SETTINGS
SET SETTING_VALUE = '3.00'  -- Your actual Snowflake credit price
WHERE SETTING_NAME = 'CREDIT_PRICE_USD';

-- 2. Register a team/department mapping
CALL FINOPS_CONTROL_DB.PROCEDURES.SP_REGISTER_CHARGEBACK_ENTITY(
    'DATA_ENGINEERING',           -- department name
    'PLATFORM_TEAM',              -- team name
    'WH_TRANSFORM_PROD',          -- warehouse they own
    'CC-12345',                   -- cost center
    'PROD'                        -- environment
);

-- 3. Collect cost data
CALL FINOPS_CONTROL_DB.PROCEDURES.SP_COLLECT_WAREHOUSE_COSTS();
CALL FINOPS_CONTROL_DB.PROCEDURES.SP_COLLECT_QUERY_COSTS();

-- 4. Calculate chargeback
CALL FINOPS_CONTROL_DB.PROCEDURES.SP_CALCULATE_CHARGEBACK(
    CURRENT_DATE() - 7,  -- from date
    CURRENT_DATE()       -- to date
);

-- 5. View chargeback report
SELECT * FROM FINOPS_CONTROL_DB.MONITORING.VW_CHARGEBACK_REPORT
WHERE REPORT_DATE >= CURRENT_DATE() - 7
ORDER BY TOTAL_COST_USD DESC;
```

---

## Project Structure

```
04_enterprise_finops_dashboard/
│
├── module_01_foundation_setup/
│   ├── 01_databases_and_schemas.sql    # FINOPS_CONTROL_DB and FINOPS_ANALYTICS_DB
│   ├── 02_warehouses.sql               # Compute warehouses with resource monitors
│   └── 03_roles_and_grants.sql         # RBAC: ADMIN, ANALYST, TEAM_LEAD, EXECUTIVE
│
├── module_02_cost_collection/
│   ├── 01_cost_tables.sql              # Fact tables for warehouse, query, storage costs
│   ├── 02_sp_collect_warehouse_costs.sql  # Collect from WAREHOUSE_METERING_HISTORY
│   ├── 03_sp_collect_query_costs.sql   # Collect from QUERY_HISTORY with attribution
│   └── 04_sp_collect_storage_costs.sql # Collect database and table storage costs
│
├── module_03_chargeback_attribution/
│   ├── 01_dimension_tables.sql         # SCD Type 2 dimensions for attribution
│   ├── 02_sp_calculate_chargeback.sql  # Multi-dimensional attribution logic
│   └── 03_sp_register_chargeback_entity.sql  # Easy onboarding of teams/depts
│
├── module_04_budget_controls/
│   ├── 01_budget_tables.sql            # Budget definitions, vs actual, alerts
│   ├── 02_sp_check_budgets.sql         # 3-tier threshold checking (80/90/100%)
│   └── 03_sp_detect_anomalies.sql      # Z-score and percentage spike detection
│
├── module_05_bi_tool_detection/
│   ├── 01_user_classification.sql      # Human vs service account classification
│   └── 02_sp_classify_bi_channels.sql  # Power BI, Tableau, dbt, Airflow detection
│
├── module_06_optimization_recommendations/
│   ├── 01_optimization_tables.sql      # Recommendations, idle warehouse log
│   └── 02_sp_generate_recommendations.sql  # Auto-generate cost optimization insights
│
├── module_07_monitoring_views/
│   ├── 01_executive_summary_views.sql  # KPIs, trends, top spenders
│   ├── 02_warehouse_analytics_views.sql  # Utilization, idle time, cost per warehouse
│   ├── 03_query_cost_views.sql         # Expensive queries, optimization candidates
│   ├── 04_chargeback_views.sql         # Per team/dept/project attribution
│   ├── 05_budget_views.sql             # Budget vs actual, forecasts
│   └── 06_optimization_views.sql       # Actionable recommendations
│
├── module_08_automation_tasks/
│   └── 01_tasks_and_scheduling.sql     # Hourly/daily tasks with DAG dependencies
│
├── streamlit_app/
│   ├── app.py                          # Main Streamlit app entry point
│   ├── pages/
│   │   ├── 1_Executive_Summary.py      # KPI dashboard for executives
│   │   ├── 2_Warehouse_Analytics.py    # Warehouse utilization and costs
│   │   ├── 3_Query_Cost_Analysis.py    # Query-level cost details
│   │   ├── 4_Chargeback_Report.py      # Team/dept/project chargeback
│   │   ├── 5_Budget_Management.py      # Budget vs actual, alerts
│   │   ├── 6_Optimization.py           # Recommendations dashboard
│   │   └── 7_Admin_Config.py           # Admin functions
│   ├── components/
│   │   ├── filters.py                  # Reusable date range, warehouse filters
│   │   ├── charts.py                   # Plotly chart templates
│   │   └── data.py                     # Snowflake connection and data loading
│   └── requirements.txt                # Python dependencies
│
├── utilities/
│   ├── quick_start.sql                 # Guided setup script
│   ├── cleanup.sql                     # Teardown all objects
│   ├── FINOPS_Module_01_Foundation.sql # Consolidated Module 01 worksheet
│   ├── FINOPS_Module_02_Cost_Collection.sql
│   ├── FINOPS_Module_03_Chargeback.sql
│   ├── FINOPS_Module_04_Budget_Controls.sql
│   ├── FINOPS_Module_05_BI_Tools.sql
│   ├── FINOPS_Module_06_Optimization.sql
│   ├── FINOPS_Module_07_Monitoring.sql
│   └── FINOPS_Module_08_Automation.sql
│
├── sample_data/
│   ├── sample_cost_history.csv         # Sample warehouse cost data
│   ├── sample_query_history.csv        # Sample query cost data
│   └── sample_chargeback_mappings.csv  # Sample team/dept mappings
│
├── course_content/
│   ├── video_scripts/
│   │   ├── module_01_script.md
│   │   ├── module_02_script.md
│   │   └── ... (8 modules total)
│   └── slides/
│       ├── module_01_slides.html
│       ├── module_02_slides.html
│       └── ... (8 modules total)
│
└── LAB_GUIDE.md                        # This file
```

---

## Key Framework Objects

### Databases
| Database | Purpose |
|----------|---------|
| `FINOPS_CONTROL_DB` | Framework brain: cost data, chargeback, budgets, procedures, monitoring |
| `FINOPS_ANALYTICS_DB` | Pre-aggregated metrics for fast BI tool consumption |

### Core Procedures
| Procedure | What It Does |
|-----------|-------------|
| `SP_COLLECT_WAREHOUSE_COSTS` | Collect credits and costs from WAREHOUSE_METERING_HISTORY (handles 10% cloud services threshold) |
| `SP_COLLECT_QUERY_COSTS` | Collect query-level costs with user, role, warehouse, tag attribution |
| `SP_COLLECT_STORAGE_COSTS` | Collect storage costs (active + time-travel + failsafe) by database/schema |
| `SP_COLLECT_SERVERLESS_COSTS` | Collect Task, Snowpipe, Materialized View maintenance costs |
| `SP_CALCULATE_CHARGEBACK` | Calculate multi-dimensional cost attribution (team, dept, project, cost center) |
| `SP_CHECK_BUDGETS` | Check budget thresholds and trigger alerts (80%, 90%, 100%) |
| `SP_DETECT_ANOMALIES` | Detect cost anomalies using z-score and percentage spike methods |
| `SP_GENERATE_RECOMMENDATIONS` | Auto-generate optimization recommendations (idle warehouses, oversized, auto-suspend) |
| `SP_REGISTER_CHARGEBACK_ENTITY` | Easy onboarding of new teams/departments with one call |
| `SP_CLASSIFY_BI_CHANNELS` | Classify queries by BI tool (Power BI, Tableau, dbt, etc.) |

### Monitoring Views
| View | Dashboard Section |
|------|------------------|
| `VW_EXECUTIVE_SUMMARY` | Daily spend, MTD/YTD trends, top 10 spenders, budget status |
| `VW_WAREHOUSE_ANALYTICS` | Per-warehouse utilization, idle time %, cost breakdown |
| `VW_QUERY_COST_ANALYSIS` | Top N expensive queries, cost per query, optimization candidates |
| `VW_CHARGEBACK_REPORT` | Cost by team, department, project, cost center with drill-down |
| `VW_BUDGET_VS_ACTUAL` | Budget vs actual spend by entity, burn rate, forecast |
| `VW_OPTIMIZATION_DASHBOARD` | Actionable recommendations ranked by potential savings |
| `VW_BI_TOOL_COSTS` | Cost breakdown by BI tool (Power BI, Tableau, Streamlit, dbt, etc.) |
| `VW_IDLE_WAREHOUSE_REPORT` | Warehouses with >50% idle time in last 7 days |
| `VW_COST_ANOMALIES` | Detected anomalies with severity (WARNING/CRITICAL) |
| `VW_STORAGE_TRENDS` | Storage costs by database with growth rate |

---

## Chargeback Attribution Model

### Attribution Hierarchy
```
User → Role → Team → Department → Business Unit → Cost Center
         ↓
    Warehouse → Environment → Project/Application
         ↓
    Query Tag → BI Tool → Service Account
```

### Attribution Methodology

**1. Direct Attribution (Preferred)**
- Dedicated warehouse per team: 100% of warehouse cost → team
- Example: `WH_DATA_ENG_PROD` → `DATA_ENGINEERING` team

**2. Proportional Attribution (Shared Warehouses)**
- Formula: `team_cost = (team_query_credits / total_warehouse_credits) * warehouse_total_cost`
- Idle time allocated proportionally to active usage
- Example: Team A uses 60% of credits → Team A gets 60% of total cost (including idle)

**3. Tag-Based Attribution (Fine-Grained)**
- Query-level tags override warehouse-level attribution
- Example: `QUERY_TAG = 'PROJECT:CUSTOMER360'` → attribute to Customer360 project even if warehouse is shared
- Session tags set via `ALTER SESSION SET QUERY_TAG = 'tag'`

**4. BI Tool Attribution**
- Detect BI tool from `APPLICATION_NAME` in QUERY_HISTORY
- Power BI: `APPLICATION_NAME LIKE '%PowerBI%'`
- Tableau: `APPLICATION_NAME LIKE '%Tableau%'`
- dbt: `APPLICATION_NAME = 'dbt'`
- Service accounts: naming pattern `SVC_*` or `SA_*`

### Multi-Dimensional Slicing

Costs can be sliced by:
- Team / Department / Business Unit
- Cost Center
- Project / Application
- Environment (PROD, QA, DEV, SANDBOX)
- BI Tool / Channel
- User (human vs service account)
- Warehouse
- Query Type (SELECT, INSERT, MERGE, DDL)

---

## Tagging Strategy

### Level 1: Object Tags (Snowflake Native Tags)

Applied to databases, schemas, warehouses:

```sql
-- Tag taxonomy
CREATE TAG FINOPS_CONTROL_DB.CONFIG.COST_CENTER;
CREATE TAG FINOPS_CONTROL_DB.CONFIG.DEPARTMENT;
CREATE TAG FINOPS_CONTROL_DB.CONFIG.TEAM;
CREATE TAG FINOPS_CONTROL_DB.CONFIG.ENVIRONMENT ALLOWED_VALUES 'PROD', 'QA', 'DEV', 'SANDBOX';
CREATE TAG FINOPS_CONTROL_DB.CONFIG.PROJECT;
CREATE TAG FINOPS_CONTROL_DB.CONFIG.OWNER;

-- Apply tags to warehouse
ALTER WAREHOUSE WH_TRANSFORM_PROD SET TAG
    FINOPS_CONTROL_DB.CONFIG.DEPARTMENT = 'DATA_ENGINEERING',
    FINOPS_CONTROL_DB.CONFIG.TEAM = 'PLATFORM_TEAM',
    FINOPS_CONTROL_DB.CONFIG.COST_CENTER = 'CC-12345',
    FINOPS_CONTROL_DB.CONFIG.ENVIRONMENT = 'PROD',
    FINOPS_CONTROL_DB.CONFIG.OWNER = 'jane.doe@company.com';
```

### Level 2: Session/Query Tags

Set per session or per query:

```sql
-- Set for entire session
ALTER SESSION SET QUERY_TAG = 'PROJECT:CUSTOMER360|PIPELINE:DAILY_ETL';

-- Set for single query
ALTER SESSION SET QUERY_TAG = 'PROJECT:REVENUE_DASHBOARD|USER:BI_TEAM';
SELECT * FROM sales_data;
```

### Level 3: Derived Tags

Computed from patterns:
- User email domain → department
- Warehouse naming convention → team
- Time of day → business hours vs off-hours

---

## Budget Management

### Budget Definition

```sql
-- Create monthly budget for a department
INSERT INTO FINOPS_CONTROL_DB.BUDGET.BUDGET_DEFINITIONS (
    ENTITY_TYPE, ENTITY_NAME, BUDGET_PERIOD, BUDGET_AMOUNT_USD,
    THRESHOLD_WARNING, THRESHOLD_CRITICAL, THRESHOLD_BLOCK
) VALUES (
    'DEPARTMENT', 'DATA_ENGINEERING', 'MONTHLY', 50000,
    0.80, 0.90, 1.00  -- Alert at 80%, 90%, 100%
);
```

### 3-Tier Alert System

| Threshold | Action | Type |
|-----------|--------|------|
| 80% of budget | Email to team lead | Soft Alert |
| 90% of budget | Email to director + Slack alert | Soft Alert |
| 100% of budget | Email to VP + FinOps team, option to suspend non-critical warehouses | Hard Alert |

### Anomaly Detection

**Z-Score Method:**
- Calculate 30-day rolling average and standard deviation of daily spend
- Flag days with spend > 2σ above average

**Percentage Spike Method:**
- Compare today's spend to same-day-last-week
- Flag if >50% increase

---

## Cost Optimization Recommendations

The framework auto-generates recommendations across 6 categories:

### 1. Idle Warehouse Detection
- Identify warehouses with >50% idle time in last 7 days
- Calculate waste: `idle_time_pct * total_cost`
- Recommendation: Reduce auto-suspend timeout or consolidate workloads

### 2. Auto-Suspend Tuning
- Identify warehouses with auto-suspend >10 minutes
- Compare to actual query patterns
- Recommendation: Reduce auto-suspend to match query cadence

### 3. Warehouse Sizing
- Identify warehouses with consistently low query queue time
- Recommendation: Downsize (e.g., L → M)
- Potential savings: 50% of warehouse cost

### 4. Query Optimization
- Identify queries with:
  - Execution time >5 minutes
  - Bytes scanned >100GB
  - Partitions scanned >1000
  - Spillage to remote storage
- Recommendation: Add clustering keys, use materialized views, optimize joins

### 5. Storage Waste
- Identify tables with high time-travel storage cost
- Identify tables not queried in 90+ days
- Recommendation: Reduce retention, archive, or drop unused tables

### 6. Multi-Cluster Scaling
- Identify warehouses with max clusters >3 but actual clusters used <2
- Recommendation: Reduce max clusters to save on scaling overhead

---

## Streamlit Dashboard

### Page 1: Executive Summary
- **KPIs:** Total spend MTD/YTD, % change vs last month, budget utilization %
- **Charts:**
  - Daily spend trend (last 30 days)
  - Top 10 departments by cost (bar chart)
  - Cost by environment (pie chart)
  - Budget vs actual (progress bars)

### Page 2: Warehouse Analytics
- **Filters:** Date range, warehouse, environment
- **Metrics:** Utilization %, idle time %, cost per hour
- **Charts:**
  - Warehouse cost breakdown (treemap)
  - Utilization over time (line chart)
  - Top 10 warehouses by cost (bar chart)
  - Idle time distribution (histogram)

### Page 3: Query Cost Analysis
- **Filters:** Date range, user, warehouse, query type
- **Metrics:** Total queries, avg cost per query, total credits
- **Charts:**
  - Top 20 most expensive queries (table with drill-down)
  - Query cost distribution (histogram)
  - Cost by user (bar chart)
  - Cost by query type (pie chart)

### Page 4: Chargeback Report
- **Filters:** Date range, department, team, cost center
- **Dimensions:** Switch between department/team/project/cost center view
- **Charts:**
  - Cost by entity (bar chart)
  - Trend over time (line chart)
  - Drill-down table with export to CSV

### Page 5: Budget Management
- **View:** All budgets with status (HEALTHY/WARNING/CRITICAL)
- **Metrics:** % consumed, days remaining in period, burn rate
- **Charts:**
  - Budget vs actual (grouped bar chart)
  - Forecast to month-end (line chart with projection)
  - Alert history (timeline)

### Page 6: Optimization Recommendations
- **Categories:** Idle warehouses, auto-suspend, sizing, query optimization, storage
- **Prioritization:** Ranked by potential savings
- **Actions:** Mark as implemented, dismiss, snooze
- **Charts:**
  - Savings potential by category (pie chart)
  - Recommendations by severity (table)

### Page 7: Admin / Config
- **Functions:**
  - Register new chargeback entity
  - Update credit pricing
  - Configure alert thresholds
  - Refresh cost data on-demand
  - View audit log

---

## What Makes This Framework Production-Ready

1. **Handles All Cost Components**: Compute, storage, cloud services (10% threshold), serverless, data transfer, replication
2. **SCD Type 2 Dimensions**: Handles team reorgs, role changes, warehouse reassignments without losing history
3. **Idempotent Cost Collection**: Re-running procedures won't duplicate costs
4. **Audit Trail**: Every cost attribution fully traceable to source ACCOUNT_USAGE views
5. **Multi-Tenant**: Natural isolation through schema-level RBAC
6. **Scalable**: Handles millions of queries/day, hundreds of warehouses
7. **Credit Pricing Flexible**: Configurable per contract, edition, cloud provider
8. **Time Zone Aware**: UTC-to-local conversion for reporting
9. **Row-Level Security**: Each team sees only their costs in self-service dashboards
10. **Cost-Optimized**: Framework itself runs on small warehouse with resource monitor

---

## Edge Cases Handled

- **Unallocated Costs**: Tracked separately; goal <5% of total spend
- **Shared Services**: Platform team costs allocated via usage-weighted methodology
- **POCs and Sandboxes**: Auto-tagged as short-lived; separate reporting
- **Idle Warehouse Spend**: Attributed to warehouse owner; reported prominently
- **Bad Query Spikes**: Isolated and attributed; kill-switch procedures available
- **Backfills and Reprocessing**: Tagged with `QUERY_TAG = 'BACKFILL'` to separate from operational costs
- **Reorgs**: SCD Type 2 allows reporting under both old and new org structures during transitions
- **Cloud Services Credit Overage**: Only charges above 10% of daily compute are captured (per Snowflake billing)
- **Role Switching**: Each query attributed to the role active at execution time, not user default role

---

## RBAC Model

| Role | Permissions | Use Case |
|------|-------------|----------|
| `FINOPS_ADMIN` | Full read/write on all schemas, can execute all procedures | FinOps team, platform admins |
| `FINOPS_ANALYST` | Read-only on all views, can run reports, export data | Finance analysts, data governance |
| `FINOPS_TEAM_LEAD` | Read-only on own team's costs via row-level security | Engineering team leads |
| `FINOPS_EXECUTIVE` | Read-only on executive summary views only | CFO, VP Finance |

---

## Cleanup

To remove all FinOps objects from your Snowflake account:

```sql
-- Run: utilities/cleanup.sql
```

This drops all databases, warehouses, roles, and resource monitors created by the framework.

---

## ROI Calculator

**Assumptions:**
- Current Snowflake spend: $500K/year
- Waste rate before FinOps: 35% (industry average)
- Waste reduction with FinOps: 60% (conservative)

**Savings:**
- Annual waste: $500K * 0.35 = $175K
- Reduction achieved: $175K * 0.60 = $105K saved/year
- Framework cost: ~$2K/year (compute + storage)
- **Net savings: $103K/year**
- **ROI: 5,150%**

---

## Support and Contribution

This is a Snowbrix Academy educational project. Feel free to adapt for your organization.

For questions or issues:
- Review the LAB_GUIDE.md
- Check module-specific README files
- Consult video scripts in `course_content/`

---

*Built by Snowbrix Academy — Production-Grade Data Engineering. No Fluff.*
