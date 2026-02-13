# Module 05: BI Tool Cost Detection & Classification

**Duration:** ~25 minutes
**Difficulty:** Intermediate
**Prerequisites:** Module 04 completed

---

## Script Structure

### 1. HOOK (30 seconds)

Power BI consumed $12,000 of Snowflake credits last month. Tableau: $8,000. dbt: $15,000. But your finance team only sees "warehouse costs" with no breakdown by tool.

This module builds BI tool classification: detecting Power BI, Tableau, Looker, dbt, Airflow from APPLICATION_NAME patterns and service account naming conventions, attributing costs to each tool, and enabling "cost per report" analysis for BI teams.

Know what each tool actually costs.

---

### 2. CORE CONTENT (20-22 minutes)

**BI tool detection logic:** APPLICATION_NAME matching, service account patterns (SVC_POWERBI_*, SVC_TABLEAU_*)

**User classification:** Human vs service account

**SP_CLASSIFY_BI_CHANNELS:** Procedure to classify queries and calculate costs by tool

### 3. HANDS-ON LAB (4 minutes)

Classify queries, view BI tool costs breakdown

### 4. RECAP (30 seconds)

BI tool cost tracking enables tool-level chargeback. Next: Module 06 — Optimization Recommendations.
