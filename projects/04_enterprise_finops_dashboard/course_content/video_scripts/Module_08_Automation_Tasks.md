# Module 08: Automation with Snowflake Tasks

**Duration:** ~20 minutes
**Difficulty:** Intermediate
**Prerequisites:** Module 07 completed

---

## Script Structure

### 1. HOOK (30 seconds)

Running cost collection manually every day doesn't scale. Tasks automate the entire pipeline: hourly query cost collection, daily warehouse and storage costs, daily chargeback attribution, daily budget checks, weekly optimization recommendations. Hands-off operation.

This module builds the task DAG: parent tasks with CRON schedules, child tasks with AFTER dependencies, error handling with notifications, and suspend/resume controls for maintenance windows.

Set it and forget it.

---

### 2. CORE CONTENT (16-18 minutes)

**Task DAG structure:**
```
TASK_COLLECT_WAREHOUSE_COSTS (hourly, root)
    ├── TASK_COLLECT_QUERY_COSTS (hourly, after warehouse costs)
    ├── TASK_COLLECT_STORAGE_COSTS (daily, after warehouse costs)
    └── TASK_CALCULATE_CHARGEBACK (daily, after all collection)
        ├── TASK_CHECK_BUDGETS (daily, after chargeback)
        └── TASK_DETECT_ANOMALIES (daily, after chargeback)
TASK_GENERATE_RECOMMENDATIONS (weekly, standalone)
```

**CRON scheduling:** `0 * * * * UTC` (hourly), `0 2 * * * UTC` (daily at 2 AM)

**Error handling:** Try-catch in stored procedures, email notifications on failure

### 3. HANDS-ON LAB (3 minutes)

Create task DAG, resume root tasks, monitor executions, view task history

### 4. RECAP (30 seconds)

Automated tasks ensure continuous cost monitoring. Next: Module 09 — Streamlit Dashboard Deep Dive.
