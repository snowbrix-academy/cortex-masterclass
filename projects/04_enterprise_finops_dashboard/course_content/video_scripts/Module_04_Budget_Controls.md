# Module 04: Budget Controls & Alerts

**Duration:** ~30 minutes
**Difficulty:** Intermediate
**Prerequisites:** Module 03 completed, chargeback attribution running

---

## Script Structure

### 1. HOOK (30 seconds)

Your Data Engineering team has a $50,000 monthly budget. It's February 20th. They've already spent $48,000. Without automated controls, nobody notices until the invoice arrives on March 1st — $65,000 actual spend, 30% over budget.

This module builds the safety net: budget definitions at department and team level, a 3-tier alert system that warns at 80%, escalates at 90%, and blocks at 100%, anomaly detection using z-score analysis to catch unusual spikes, and month-end forecasting so you know on February 15th that you're trending toward overspend.

Prevention, not reaction.

---

### 2. CORE CONTENT (25-27 minutes)

#### Section 2.1: Budget Table Design

**3-tier alert system:** 80% warning, 90% critical, 100% block

**Procedure: SP_CHECK_BUDGETS** — Daily execution, compares actual spend to budget, triggers alerts

**Anomaly detection:** Z-score method (>2σ), percentage spike method (>50% vs last week)

**Month-end forecasting:** Linear projection based on burn rate

### 3. HANDS-ON LAB (5 minutes)

Set budgets, trigger alerts, view budget vs actual report

### 4. RECAP (30 seconds)

Budget controls with automated alerts prevent cost overruns. Next: Module 05 — BI Tool Detection.

---

## Production Notes

(Standard production notes format)
