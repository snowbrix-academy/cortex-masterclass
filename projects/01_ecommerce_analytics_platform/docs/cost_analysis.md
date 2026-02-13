# COST ANALYSIS

## E-Commerce Analytics Platform — Monthly Cost Breakdown

---

## COMPUTE COSTS

### Warehouse Credit Consumption (Monthly Estimate)

| Warehouse | Size | Credits/Hr | Daily Runtime | Monthly Credits | Monthly Cost |
|-----------|------|-----------|---------------|-----------------|-------------|
| LOADING_WH | Small | 1 | ~1.5 hrs | ~45 | $135 |
| TRANSFORMING_WH | Medium | 2 | ~0.5 hrs | ~30 | $90 |
| REPORTING_WH | Small | 1 | ~3 hrs | ~90 | $270 |
| **Total Compute** | | | | **~165** | **~$495** |

**Note:** Credit cost varies by Snowflake edition and contract:
- Standard: $2.00/credit
- Enterprise: $3.00/credit
- Business Critical: $4.00/credit

Estimates above use $3.00/credit (Enterprise). Actual cost will be lower with auto-suspend reducing idle time.

### Realistic Estimate (With Auto-Suspend)

Auto-suspend means warehouses only run during active queries. Actual utilization is typically 30-50% of the daily runtime estimate above.

| Warehouse | Realistic Monthly Credits | Realistic Monthly Cost |
|-----------|--------------------------|----------------------|
| LOADING_WH | ~20 | $60 |
| TRANSFORMING_WH | ~15 | $45 |
| REPORTING_WH | ~12 | $36 |
| **Total (Realistic)** | **~47** | **~$141** |

---

## STORAGE COSTS

| Database | Estimated Size | Monthly Cost (@ $23/TB) |
|----------|---------------|------------------------|
| ECOMMERCE_RAW | ~5 GB | $0.12 |
| ECOMMERCE_STAGING | ~0.5 GB (views, minimal) | $0.01 |
| ECOMMERCE_ANALYTICS | ~3 GB | $0.07 |
| Time Travel (90-day RAW) | ~15 GB | $0.35 |
| Fail-Safe (7-day) | ~5 GB | $0.12 |
| **Total Storage** | **~28.5 GB** | **~$0.67** |

Storage is negligible at this scale. It becomes significant at 10TB+.

---

## TOTAL MONTHLY COST

| Category | Monthly Cost |
|----------|-------------|
| Compute (realistic) | $141 |
| Storage | $1 |
| Cloud Services (metadata ops) | ~$5 |
| **Total** | **~$147/month** |

---

## ROI COMPARISON

### Previous Setup (Analytics on Production Postgres)

| Cost Item | Monthly Cost |
|-----------|-------------|
| Oversized RDS instance (to handle analytics queries) | $1,200 |
| Performance impact on production app (lost revenue estimate) | $1,500 |
| Engineer time maintaining ad-hoc queries | $700 |
| **Total** | **~$3,400/month** |

### New Setup (Snowflake Analytics Platform)

| Cost Item | Monthly Cost |
|-----------|-------------|
| Snowflake (compute + storage) | $147 |
| Airflow hosting (Docker on existing server) | $0 |
| Streamlit (local/Streamlit Cloud free tier) | $0 |
| **Total** | **~$147/month** |

### Savings

```
Previous:  $3,400/month  →  $40,800/year
New:       $  147/month  →  $  1,764/year
Savings:   $3,253/month  →  $39,036/year
ROI:       23x
```

---

## TOP COST OPTIMIZATION OPPORTUNITIES

### 1. Warehouse Right-Sizing

Run this query after 2 weeks of production usage:

```sql
SELECT
    WAREHOUSE_NAME,
    ROUND(AVG(AVG_RUNNING), 1) AS avg_concurrent_queries,
    ROUND(AVG(AVG_QUEUED_LOAD), 1) AS avg_queued,
    MAX(AVG_RUNNING) AS peak_concurrent
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_LOAD_HISTORY
WHERE START_TIME >= DATEADD('day', -14, CURRENT_TIMESTAMP())
GROUP BY WAREHOUSE_NAME;
```

**If avg_concurrent_queries < 1 and avg_queued = 0:** The warehouse is oversized. Consider downsizing.

### 2. Query Optimization

Run the "Top 20 Most Expensive Queries" from `monitoring_queries.sql`. Look for:
- Queries scanning >80% of partitions (missing WHERE clause or bad clustering)
- Queries running >60 seconds on small tables (bad JOIN logic)
- Duplicate queries (same SQL, different users — cache should handle this)

### 3. Auto-Suspend Tuning

After 1 month, review actual suspend/resume patterns:

```sql
SELECT
    WAREHOUSE_NAME,
    COUNT(*) AS resume_count,
    ROUND(AVG(CREDITS_USED), 4) AS avg_credits_per_resume
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE START_TIME >= DATEADD('day', -30, CURRENT_TIMESTAMP())
GROUP BY WAREHOUSE_NAME;
```

**If resume_count is very high (>100/day):** The warehouse is suspending and resuming too often. Increase auto-suspend to 120-300 seconds.

---

*Cost analysis generated on platform build date. Revisit monthly with actual ACCOUNT_USAGE data.*
