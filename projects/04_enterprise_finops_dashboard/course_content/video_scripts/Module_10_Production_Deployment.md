# Module 10: Production Deployment & Advanced Scenarios

**Duration:** ~30 minutes
**Difficulty:** Advanced
**Prerequisites:** Modules 01-09 completed

---

## Script Structure

### 1. HOOK (45 seconds)

You've built the framework. Now make it production-ready: handling multi-region cost rollup, custom pricing models with enterprise discounts, chargeback during organizational reorgs using SCD Type 2, cost spike investigation workflows, integration with Slack and email for alerts, and a production deployment checklist covering security, performance, and monitoring.

This is the difference between a lab exercise and a system that handles $10M+ annual Snowflake spend for 1000+ users.

Production-grade. Not a prototype.

---

### 2. CORE CONTENT (25-27 minutes)

#### Advanced Scenarios:

**1. Multi-Region Cost Rollup**
- Challenge: Separate Snowflake accounts per region (US, EU, APAC)
- Solution: Replicate cost data to central account, union queries across regions
- Tagging strategy: Add REGION column to all cost tables

**2. Reserved Capacity Attribution**
- Challenge: Pre-purchased capacity credits vs on-demand
- Solution: Separate COST_TYPE = 'RESERVED' vs 'ON_DEMAND'
- Allocation: Proportional to usage across teams

**3. Custom Pricing Models**
- Challenge: Enterprise discount tiers (e.g., 20% discount after 1M credits/year)
- Solution: Tiered pricing table in CONFIG, apply retroactively in monthly adjustment procedure

**4. Chargeback During Reorg**
- Challenge: Engineering splits into Platform and ML teams on Feb 1st
- Solution: SCD Type 2 allows reporting under both old and new structure
- Finance sees transition period costs under both orgs for comparison

**5. Cost Spike Investigation Workflow**
- Scenario: Feb 15th spend is 300% higher than Feb 14th
- Investigation steps:
  1. Check VW_COST_ANOMALIES for flagged date
  2. Drill into VW_WAREHOUSE_ANALYTICS for warehouse-level spike
  3. Query VW_QUERY_COST_ANALYSIS for expensive queries on that date
  4. Identify root cause (user, query, warehouse)
  5. Document in ALERT_HISTORY with resolution notes

**6. External Integrations**
- **Slack alerts:**
  ```sql
  CREATE EXTERNAL FUNCTION SEND_SLACK_ALERT(...)
  RETURNS VARIANT
  API_INTEGRATION = SLACK_API_INTEGRATION
  AS 'https://hooks.slack.com/services/YOUR_WEBHOOK';
  ```
- **Email via Snowflake:**
  ```sql
  CALL SYSTEM$SEND_EMAIL(
      'finops-team@company.com',
      'Budget Alert: DATA_ENGINEERING at 90%',
      'Details: ...'
  );
  ```
- **ServiceNow tickets:** External function to create incident on 100% budget threshold

#### Production Deployment Checklist:

**Pre-Deployment:**
- [ ] Configure actual credit pricing (not $3 default)
- [ ] Register all teams/departments via SP_REGISTER_CHARGEBACK_ENTITY
- [ ] Apply Snowflake tags to all warehouses (DEPARTMENT, TEAM, COST_CENTER, ENVIRONMENT)
- [ ] Test cost collection for last 90 days (full history)
- [ ] Validate chargeback attribution accuracy (compare to known costs)
- [ ] Set budgets for all departments
- [ ] Configure alert email distribution lists
- [ ] Test Streamlit dashboard connectivity and RLS

**Deployment:**
- [ ] Run all module scripts in sequence (01-08)
- [ ] Verify all tables, views, procedures created (SHOW commands)
- [ ] Grant roles to users (GRANT ROLE FINOPS_ANALYST_ROLE TO USER jane.doe)
- [ ] Resume task tree (ALTER TASK ... RESUME)
- [ ] Monitor first task executions for errors (TASK_HISTORY queries)
- [ ] Deploy Streamlit app to Snowflake (CREATE STREAMLIT) or external hosting
- [ ] Validate row-level security (test as different roles)

**Post-Deployment:**
- [ ] Monitor task execution daily for first week
- [ ] Review unallocated cost % (goal <5%, register missing warehouses)
- [ ] Audit budget vs actual for accuracy
- [ ] Review optimization recommendations with engineering teams
- [ ] Train finance analysts on dashboard usage
- [ ] Document custom configurations (pricing, teams, budgets)
- [ ] Schedule monthly review meeting (FinOps + Finance + Engineering)

#### Scaling Considerations:

**1000+ users:**
- Use FINOPS_WH_REPORTING with MAX_CLUSTER_COUNT = 5+
- Pre-aggregate to ANALYTICS_DB daily to avoid expensive ad-hoc queries
- Partition cost tables by month: FACT_WAREHOUSE_COST_HISTORY_2024_01, _2024_02, etc.

**100+ warehouses:**
- Automate warehouse registration via WAREHOUSE_CREATED event trigger
- Use warehouse naming convention (WH_{TEAM}_{ENV}_{SIZE}) for auto-tagging
- Warehouse inventory view to track unregistered warehouses

**Millions of queries/day:**
- Filter QUERY_HISTORY: Exclude queries <1 second execution time
- Partition FACT_QUERY_COST_HISTORY by month
- Aggregate to hourly/daily grain for reporting (don't query raw facts in dashboards)

#### Course Recap:

**What you built:**
- 2 databases, 10 schemas, 3 warehouses, 4 roles
- 10+ stored procedures for cost collection, attribution, optimization
- 10+ monitoring views with row-level security
- 7-page Streamlit dashboard
- Automated task DAG running hourly/daily
- Complete audit trail from Snowflake invoice to team chargeback

**Business outcomes:**
- 15-30% cost reduction via optimization recommendations
- <5% unallocated costs (complete chargeback attribution)
- Zero manual cost reporting (fully automated)
- Real-time budget alerts (prevent overruns)
- Self-service cost visibility for all teams

**Career outcomes:**
- Production-grade Snowflake FinOps framework in your portfolio
- Advanced SQL and JavaScript stored procedure skills
- Dimensional modeling (SCD Type 2) expertise
- Dashboard development (Streamlit + Plotly)
- Resume bullet: "Built enterprise cost management framework handling $XM annual spend"

### 3. NEXT STEPS (2 minutes)

**Extend the framework:**
1. Add forecasting models (Prophet, ARIMA) for predictive budgeting
2. Integrate with external tools (Slack, PagerDuty, email)
3. Cross-cloud comparison (AWS, Azure, GCP Snowflake costs)
4. Reserved capacity tracking and optimization
5. Reader account cost attribution
6. Marketplace consumption tracking
7. Data transfer cost analysis
8. Snowpark Container Services costs

**Join the community:**
- Share your implementation and lessons learned
- Contribute enhancements back to the project
- Help others deploying the framework

### 4. RECAP (45 seconds)

In this course, you built a complete enterprise FinOps framework for Snowflake:
- Real-time cost collection from all Snowflake cost components
- Multi-dimensional chargeback attribution with SCD Type 2 dimensions
- Automated budget controls with 3-tier alerts
- Cost optimization recommendations prioritized by savings
- Interactive dashboard for all personas (CFO, engineering, team leads)
- Production-ready deployment handling enterprise scale

This is production-grade data engineering. No fluff. You have the tools to reduce Snowflake spend by 15-30%, achieve complete cost accountability, and provide self-service visibility to 1000+ users.

Go build. Go optimize. Go save your organization $100K+ per year.

---

## Production Notes

- **B-roll suggestions:**
  - Multi-region architecture diagram
  - Production checklist being checked off
  - Cost spike investigation workflow
  - Slack alert screenshot
  - Before/after metrics (waste reduction)

- **Screen recordings needed:**
  - Full dashboard walkthrough (all 7 pages)
  - Task monitoring dashboard
  - Cost spike investigation example
  - Final verification queries

- **Pause points:**
  - After production checklist (let viewers take notes)
  - After scaling considerations (important for large orgs)

- **Emphasis words:**
  - "Production-ready" (not a prototype)
  - "Enterprise scale" (1000+ users)
  - "15-30% cost reduction" (ROI)
  - "Complete audit trail" (compliance)
  - "No fluff" (brand promise)
