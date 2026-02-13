# Module 06: Cost Optimization Recommendations

**Duration:** ~30 minutes
**Difficulty:** Intermediate to Advanced
**Prerequisites:** Module 05 completed

---

## Script Structure

### 1. HOOK (45 seconds)

WH_ANALYTICS_PROD runs 24/7 but only executes queries 30% of the time. 70% idle = $5,000/month wasted. Query Q_123456 scans 500GB to return 10 rows — add a filter, save $200/execution. Table SALES_HISTORY hasn't been queried in 120 days — archive it, save $50/month in time-travel storage.

This module builds the optimization engine: automated detection of idle warehouses, auto-suspend tuning recommendations, warehouse sizing analysis, query optimization candidates, storage waste identification, and clustering key suggestions. Prioritized by potential savings.

Turn cost visibility into cost action.

---

### 2. CORE CONTENT (25-27 minutes)

**6 recommendation categories:**
1. Idle warehouse detection (>50% unused)
2. Auto-suspend tuning
3. Warehouse sizing (too large or too small)
4. Query optimization (expensive queries with suggestions)
5. Storage waste (stale tables, excessive time-travel)
6. Clustering key recommendations

**SP_GENERATE_RECOMMENDATIONS:** Automated recommendation engine

### 3. HANDS-ON LAB (5 minutes)

Generate recommendations, view by potential savings, mark as implemented

### 4. RECAP (30 seconds)

Optimization recommendations drive 15-30% cost reduction. Next: Module 07 — Monitoring Views.
