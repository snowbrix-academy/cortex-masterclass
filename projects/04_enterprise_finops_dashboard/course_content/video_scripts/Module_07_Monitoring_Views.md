# Module 07: Monitoring Views & Reporting Layer

**Duration:** ~35 minutes
**Difficulty:** Intermediate
**Prerequisites:** Module 06 completed

---

## Script Structure

### 1. HOOK (45 seconds)

Finance needs a CFO-friendly summary. Engineering leads need query-level details. Team leads need row-level security showing only their team's costs. One database, three personas, different access patterns.

This module builds the semantic layer: 10+ monitoring views covering executive summary, warehouse analytics, query cost analysis, chargeback reports, budget status, and optimization dashboard. With row-level security using CURRENT_ROLE() and SECURE VIEWS to prevent data leakage.

Business intelligence, not just raw data.

---

### 2. CORE CONTENT (29-31 minutes)

**10+ monitoring views:**
- VW_EXECUTIVE_SUMMARY
- VW_WAREHOUSE_ANALYTICS
- VW_QUERY_COST_ANALYSIS
- VW_CHARGEBACK_REPORT
- VW_BUDGET_VS_ACTUAL
- VW_OPTIMIZATION_DASHBOARD
- VW_BI_TOOL_COSTS
- VW_IDLE_WAREHOUSE_REPORT
- VW_COST_ANOMALIES
- VW_STORAGE_TRENDS

**Row-level security pattern:** Filter by CURRENT_ROLE() and team mapping

**Pre-aggregation strategy:** ANALYTICS_DB for BI tool performance

### 3. HANDS-ON LAB (5 minutes)

Query all views, test row-level security, create sample dashboard queries

### 4. RECAP (30 seconds)

Monitoring views provide self-service cost visibility. Next: Module 08 — Automation with Tasks.
