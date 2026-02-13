# MODULE 6: OPERATIONS

## Cost Optimization, Security Hardening & Production Readiness

**Video Segment:** 3:12 - 3:25 (13 minutes)
**Git Tag:** `v1.0-production`

---

## OVERVIEW

This is the final pass that transforms a working demo into a production system. Most tutorials stop at "it works." We go further: Is it secure? Is it cost-efficient? Can it survive its first month in production without someone getting paged at 3 AM?

---

## SUBMODULE 6.1: COST ANALYSIS

**File:** `docs/cost_analysis.md`

### What Gets Built

A complete cost breakdown of the entire platform:
- Per-warehouse credit consumption (actual, not estimated)
- Per-query cost analysis (which queries cost the most?)
- Storage costs by database layer
- Month-over-month projection
- Comparison to the company's previous setup ($3,400/month)

### Key Queries (from `infrastructure/monitoring_queries.sql`)

| Query | Purpose |
|-------|---------|
| Credit consumption by warehouse | Know which workload costs the most |
| Top 20 most expensive queries | Find optimization targets |
| Warehouse utilization heatmap | Find idle compute you're paying for |
| Full-table scan queries | Find queries missing filters |
| Storage by database | Understand data growth trajectory |

### Optimization Recommendations

| Finding | Action | Expected Savings |
|---------|--------|-----------------|
| LOADING_WH idle 22 hrs/day | Auto-suspend already at 60s (good) | Already optimized |
| TRANSFORMING_WH Medium for 3-min run | Consider downgrading to Small if build time is acceptable (<8 min) | ~$30/month |
| REPORTING_WH scale-out to 2 rarely triggers | Keep current config (concurrency protection) | $0 (insurance) |
| 3 queries scanning 100% of partitions | Add clustering keys or WHERE filters | ~$15/month in query costs |
| RAW database 90-day retention | Reduce to 30 days if recovery risk is acceptable | ~$5/month storage |

---

## SUBMODULE 6.2: SECURITY HARDENING

**Files:** `infrastructure/rbac_setup.sql`, `infrastructure/network_policies.sql`

### Security Checklist

| Item | Status | Notes |
|------|--------|-------|
| All pipelines use service accounts | Required | No personal credentials in automated processes |
| Service accounts have minimum permissions | Required | LOADER can't read ANALYTICS, ANALYST can't read RAW |
| Network policies configured | Required for prod | Restrict IP ranges to known infrastructure |
| Key-pair auth for service accounts | Recommended | Replace passwords with RSA key pairs |
| MFA enabled for human accounts | Recommended | ACCOUNTADMIN and SYSADMIN must use MFA |
| No `ACCOUNTADMIN` in pipelines | Required | Pipelines use custom roles only |
| Credentials in environment variables | Required | Never hardcoded, never in git |
| `.env` in `.gitignore` | Required | Verified |

### Service Account Audit Query

```sql
-- Verify no service account has ACCOUNTADMIN
SELECT u.name, r.name AS role_name
FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_USERS u
JOIN SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_ROLES r
  ON u.grantee_name = r.grantee_name
WHERE u.name LIKE 'SVC_%'
  AND r.name = 'ACCOUNTADMIN';
-- Expected: 0 rows
```

---

## SUBMODULE 6.3: PRODUCTION CHECKLIST

**File:** `docs/production_checklist.md`

### The 15-Point Production Readiness Checklist

```
INFRASTRUCTURE
□  1. All 3 databases created with correct retention policies
□  2. All 3 warehouses sized and configured (auto-suspend, scaling)
□  3. Resource monitors active with Slack alerting at 75%, 90%, 100%
□  4. Network policies configured for production IPs

SECURITY
□  5. RBAC roles created with minimum permissions verified
□  6. Service accounts created (no personal accounts in pipelines)
□  7. Credentials stored in environment variables (not code)
□  8. .env file in .gitignore (confirmed)

PIPELINE
□  9. Full load tested end-to-end (Postgres → RAW → Staging → Marts)
□ 10. Incremental load tested (run twice, verify no duplicates)
□ 11. dbt test suite passes with 0 failures
□ 12. Airflow DAG runs on schedule with Slack notifications

MONITORING
□ 13. Slack alerts configured for pipeline failures
□ 14. SLA monitoring active (30-min SLA on full DAG)
□ 15. Cost monitoring dashboard accessible

DOCUMENTATION
□ 16. Architecture diagram up to date
□ 17. dbt docs generated and browsable
□ 18. Runbook for common failures documented
```

---

## SUBMODULE 6.4: MONITORING & ALERTING

### Alert Routing

| Alert Type | Channel | Response Time |
|-----------|---------|---------------|
| Pipeline failure | Slack #data-alerts | 30 min during business hours |
| SLA breach | Slack #data-alerts + PagerDuty | 15 min |
| Cost monitor 75% | Slack #data-costs | Next business day |
| Cost monitor 90% | Slack #data-costs + Email to lead | Same day |
| Cost monitor 100% (suspend) | Slack #data-costs + PagerDuty | Immediate |
| dbt test failure | Slack #data-quality | 1 hour |

### Common Failure Runbook

| Failure | Likely Cause | Resolution |
|---------|-------------|------------|
| Postgres extraction timeout | Source DB under load | Retry. If persistent, check Postgres locks. |
| Snowflake COPY INTO error | Schema change in source | Check error log. Update RAW table DDL. |
| dbt test failure | Data quality issue upstream | Check which test failed. Trace to source. |
| Stripe API 429 | Rate limit exceeded | Retry handler should catch this. If persistent, reduce batch size. |
| Warehouse suspended by monitor | Monthly credit limit hit | Review top queries. Right-size warehouse. Request budget increase. |
| Dashboard shows stale data | Airflow DAG didn't run | Check Airflow UI. Trigger manual run. |

---

## FILES IN THIS MODULE

```
docs/
├── IMPLEMENTATION_PLAN.md       ← You are here
├── cost_analysis.md             ← Detailed cost breakdown
├── production_checklist.md      ← 15-point go-live checklist
└── runbook.md                   ← Common failure resolution guide
```

---

## WHAT WE'D ADD IN WEEK 2

If this were a real client engagement, here's what we'd build next:

| Priority | Enhancement | Why |
|----------|------------|-----|
| P1 | Key-pair authentication for service accounts | Passwords are insecure for production |
| P1 | CI/CD pipeline (GitHub Actions) | Automated dbt testing on every PR |
| P2 | Data quality dashboard (separate from analytics) | Proactive quality monitoring |
| P2 | Tableau/Looker connection | Streamlit is great for demo, not for 50 analysts |
| P3 | Snowflake Tasks for lightweight scheduling | Replace Airflow for simple use cases |
| P3 | Data masking on PII columns | Customer email, phone, address |

## WHAT WE'D REVISIT IN MONTH 3

| Item | Why Revisit |
|------|------------|
| Warehouse sizes | 3 months of real usage data to right-size definitively |
| Incremental strategy | Move from timestamp-based to Snowflake Streams for lower latency |
| Table clustering | Analyze query patterns and add clustering keys to large tables |
| dbt model materialization | Some views might need to become tables for performance |
| Cost monitors | Adjust thresholds based on actual spend patterns |
