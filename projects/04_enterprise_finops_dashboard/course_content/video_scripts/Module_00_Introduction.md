# Module 00: Enterprise FinOps Dashboard — Course Introduction

**Duration:** ~10 minutes
**Difficulty:** Beginner
**Prerequisites:** None (this is the introduction)

---

## Script Structure

### 1. HOOK (45 seconds)

Your Snowflake bill just came in. $150,000 this month. Your CFO wants to know: which teams are responsible for this spend? Which projects are the most expensive? Where's the waste?

You have no answer.

This is the $75K-to-$150K problem. Most organizations waste 30-40% of their Snowflake spend on idle warehouses, inefficient queries, and zero cost visibility. Finance teams demand chargeback by department, but platform teams lack the tooling to provide it.

By the end of this course, you'll build a complete, production-ready FinOps framework that solves this problem. Real-time cost visibility. Automated chargeback attribution. Budget controls with alerts. Actionable optimization recommendations. All built natively in Snowflake.

---

### 2. CORE CONTENT (7-8 minutes)

#### Section 2.1: The Problem — Snowflake Cost Chaos

**Visual on screen:**
- Invoice screenshot showing $150K monthly spend with no breakdown
- Frustrated CFO looking at spreadsheet with no details
- Platform team dashboard showing only warehouse status, no costs

**Key points to emphasize:**
- Snowflake's ACCOUNT_USAGE views contain all cost data, but it's raw and unattributed
- Finance teams need answers by team, department, project, cost center — not just by warehouse
- Platform teams lack real-time monitoring and automated controls
- No unified view of idle waste, query costs, or budget burn rates
- Industry data shows 30-40% waste rate without FinOps governance

**The ROI calculation:**
- $500K annual Snowflake spend (medium-sized enterprise)
- 35% waste rate = $175K wasted annually
- FinOps framework recovers 60% of waste = $105K saved
- Framework operating cost: ~$2K/year
- **Net savings: $103K/year. ROI: 5,150%.**

**Common mistake:**
Many teams try to solve this with manual Excel exports from ACCOUNT_USAGE. This breaks down at scale (hundreds of warehouses, thousands of users), has no automation, and provides no real-time visibility.

---

#### Section 2.2: What You'll Build — The Solution

**Visual on screen:**
- Architecture diagram showing data flow from ACCOUNT_USAGE → FINOPS_CONTROL_DB → FINOPS_ANALYTICS_DB → Streamlit Dashboard
- Screenshot of executive summary dashboard with KPIs
- Example chargeback report showing costs by team/department

**The Enterprise FinOps Dashboard Framework includes:**

1. **Real-time cost collection**
   - Warehouse compute credits (per-minute grain)
   - Query-level costs with user/role/warehouse attribution
   - Storage costs (active + time-travel + failsafe)
   - Serverless features (tasks, Snowpipe, materialized views)
   - Cloud services credits (with 10% threshold rule)

2. **Multi-dimensional chargeback attribution**
   - Direct attribution: Dedicated warehouse → team (1:1 mapping)
   - Proportional attribution: Shared warehouse → multiple teams by usage
   - Tag-based attribution: QUERY_TAG for fine-grained project tracking
   - BI tool classification: Power BI, Tableau, dbt, Airflow detection

3. **Automated budget controls**
   - 3-tier alert system: 80% warning, 90% critical, 100% block
   - Anomaly detection: Z-score and percentage spike methods
   - Budget forecasting to month-end based on burn rate
   - Separate CAPEX (storage) vs OPEX (compute) tracking

4. **Cost optimization recommendations**
   - Idle warehouse detection (>50% unused time)
   - Auto-suspend tuning (match query cadence)
   - Warehouse sizing analysis (too large or too small)
   - Query optimization candidates (expensive queries with suggestions)
   - Storage waste identification (stale tables, excessive time-travel)
   - Clustering key recommendations

5. **Interactive Streamlit dashboard**
   - 7 pages: Executive Summary, Warehouse Analytics, Query Analysis, Chargeback, Budget Management, Optimization, Admin/Config
   - Role-based access control: Each team sees only their costs
   - Drill-down capabilities: Department → Team → Warehouse → Query
   - Export functionality: CSV/Excel downloads for finance reporting

**Key design principles:**
- **Production-ready:** Handles 1000+ users, 100+ warehouses, millions of queries/day
- **Audit trail:** Every dollar traced back to source ACCOUNT_USAGE views
- **Idempotent:** Re-running cost collection won't duplicate charges
- **SCD Type 2 dimensions:** Handles team reorgs without losing history
- **Credit pricing flexible:** Configurable per contract, edition, cloud provider
- **Cost-optimized:** Framework runs on XSMALL warehouse with $150/month cap

---

#### Section 2.3: Target Audience & Prerequisites

**Who this course is for:**

1. **FinOps Teams**
   - Responsible for Snowflake cost management and chargeback
   - Need automated tooling to replace manual Excel analysis
   - Must provide cost attribution to finance and business units

2. **Data Platform Teams**
   - Own Snowflake infrastructure and governance
   - Need real-time monitoring and cost optimization insights
   - Responsible for implementing cost controls and guardrails

3. **CFO Organizations**
   - Finance analysts needing department-level budget tracking
   - Controllers requiring cost center attribution for GL posting
   - VPs demanding cost accountability and waste reduction

4. **Data Engineering Teams**
   - Senior data engineers (2-7 years experience) learning FinOps
   - Aspiring platform engineers building career skills
   - Technical leads responsible for infrastructure efficiency

**Prerequisites:**

- **Snowflake knowledge:**
  - ACCOUNTADMIN or SYSADMIN role access
  - Basic SQL fluency (DDL, DML, joins, aggregations)
  - Understanding of Snowflake cost model (compute credits, storage, cloud services)
  - Familiarity with ACCOUNT_USAGE schema (helpful but not required)

- **Optional skills (not required but helpful):**
  - JavaScript for stored procedures (we'll teach you)
  - Python 3.8+ for Streamlit dashboard (we provide complete code)
  - Basic statistics for anomaly detection (z-score explained)

**What you DON'T need:**
- No external tools or cloud accounts (everything runs in Snowflake)
- No machine learning expertise
- No DevOps or Kubernetes knowledge
- No advanced math or data science background

---

#### Section 2.4: Course Structure — 10 Modules

**Visual on screen:**
- Module roadmap showing progressive learning path
- Estimated time per module
- Dependencies between modules

**Module overview:**

| Module | Topic | Duration | What You'll Build |
|--------|-------|----------|-------------------|
| **01** | Foundation Setup | 25 min | Databases, warehouses, roles, RBAC, resource monitors |
| **02** | Cost Collection | 35 min | 4 stored procedures to collect warehouse, query, storage, serverless costs |
| **03** | Chargeback Attribution | 40 min | SCD Type 2 dimensions, multi-dimensional cost attribution engine |
| **04** | Budget Controls | 30 min | Budget tables, 3-tier alerts, anomaly detection, forecasting |
| **05** | BI Tool Detection | 25 min | User classification, Power BI/Tableau/dbt cost tracking |
| **06** | Optimization Engine | 30 min | 6 categories of automated recommendations |
| **07** | Monitoring Views | 35 min | 10+ semantic views for reporting with row-level security |
| **08** | Automation with Tasks | 20 min | Scheduled task DAG for hourly/daily processing |
| **09** | Streamlit Dashboard | 40 min | 7-page interactive dashboard with charts and filters |
| **10** | Production Deployment | 30 min | Multi-region, custom pricing, production checklist |

**Total time: ~4.5 hours** (hands-on labs included)

**Learning path:**
- Modules 01-02: Foundation (databases, cost collection)
- Modules 03-05: Attribution (chargeback, budgets, BI tools)
- Modules 06-07: Optimization (recommendations, monitoring views)
- Modules 08-10: Automation & production (tasks, dashboard, deployment)

**Each module includes:**
- Core concept explanation with visuals
- SQL script walkthrough with line-by-line annotation
- Hands-on lab with expected results
- Troubleshooting tips for common issues
- Best practices for production deployment

---

#### Section 2.5: Expected Outcomes & Value Proposition

**By the end of this course, you will:**

1. **Have a production-ready framework** deployed in your Snowflake account
   - Collecting cost data automatically (hourly/daily via tasks)
   - Attributing costs to teams, departments, projects, cost centers
   - Monitoring budgets with automated alerts
   - Generating optimization recommendations

2. **Understand Snowflake cost components deeply**
   - Compute credits and warehouse sizing formulas
   - Cloud services 10% threshold rule
   - Storage cost breakdown (active, time-travel, failsafe)
   - Serverless feature costs (tasks, Snowpipe, materialized views)

3. **Master chargeback attribution methodologies**
   - Direct attribution (dedicated warehouses)
   - Proportional attribution (shared warehouses)
   - Tag-based attribution (QUERY_TAG for projects)
   - BI tool cost tracking (Power BI, Tableau, dbt, Airflow)

4. **Build advanced SQL and JavaScript skills**
   - JavaScript stored procedures for complex logic
   - SCD Type 2 dimension modeling for history tracking
   - Incremental data processing patterns
   - Task orchestration with DAG dependencies

5. **Create executive-ready dashboards**
   - Streamlit multi-page application with role-based access
   - Plotly interactive charts (bar, line, pie, treemap)
   - Drill-down capabilities from summary to query-level detail
   - Export functionality for finance reporting

**Measurable business impact:**

- **15-30% reduction in Snowflake spend** within 3 months
- **<5% unallocated costs** (complete chargeback attribution)
- **Zero manual cost reporting** (fully automated)
- **Real-time budget alerts** (prevent overruns before month-end)
- **Quantified optimization opportunities** (idle warehouses, query improvements)

**Career impact:**

- Add "FinOps" and "Cost Optimization" to your resume
- Demonstrate production-grade Snowflake architecture skills
- Show end-to-end project delivery (data modeling, procedures, dashboards)
- Portfolio piece for senior engineer or architect roles

---

### 3. GETTING STARTED (1 minute)

**What you need to do next:**

1. **Access your Snowflake account**
   - You'll need ACCOUNTADMIN or SYSADMIN role
   - Enterprise Edition recommended (for tagging), but Standard works too
   - Estimate 50-100 credits (~$150-$300) for initial setup and testing

2. **Download course materials**
   - All SQL scripts available in GitHub repository
   - Streamlit app code provided
   - Sample data for testing included

3. **Set up your environment**
   - Snowsight web interface (recommended) or SnowSQL CLI
   - Text editor for reviewing scripts (VS Code, Notepad++, etc.)
   - Optional: Python 3.8+ if you want to run Streamlit locally

4. **Follow along with Module 01**
   - We'll create the foundation databases and warehouses
   - Takes 25 minutes including hands-on lab
   - By the end you'll have the framework skeleton ready

**Course format:**

- Watch the video for concept explanation
- Review the SQL script with comments
- Execute the script in your Snowflake account
- Verify results using provided queries
- Move to next module when verification passes

**Support and help:**

- SQL scripts are heavily commented for self-service learning
- Each module includes troubleshooting section
- Course materials include LAB_GUIDE.md with step-by-step instructions

---

### 4. RECAP (30 seconds)

Today you learned:

1. **The $75K-$150K problem:** Most organizations waste 30-40% of Snowflake spend with zero visibility
2. **The solution:** A production-ready FinOps framework built natively in Snowflake
3. **What you'll build:** Real-time cost collection, automated chargeback, budget controls, optimization recommendations, Streamlit dashboard
4. **Expected outcomes:** 15-30% cost reduction, complete chargeback attribution, zero manual reporting
5. **Course structure:** 10 modules, ~4.5 hours, hands-on labs included

Next up: **Module 01 — Foundation Setup**. We'll create the databases, warehouses, and RBAC model that form the backbone of the framework.

This is production-grade data engineering. No fluff. Let's build.

---

## Production Notes

- **B-roll suggestions:**
  - Snowflake invoice screenshots (anonymized)
  - ACCOUNT_USAGE view query results
  - Architecture diagrams with animated data flow
  - Dashboard screenshots showing KPIs and charts
  - Code editor showing SQL scripts

- **Screen recordings needed:**
  - Logging into Snowsight
  - Navigating to ACCOUNT_USAGE views
  - Quick demo of final dashboard (teaser)
  - Showing module folder structure

- **Pause points:**
  - After explaining the problem (let it sink in)
  - After showing ROI calculation (big number)
  - After course structure overview (let viewers plan)

- **Emphasis words:**
  - "30-40% waste" (the pain point)
  - "Real-time" (key differentiator)
  - "Production-ready" (not a toy)
  - "5,150% ROI" (the business case)
  - "No fluff" (brand promise)
