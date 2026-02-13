# PRODUCTION READINESS CHECKLIST

## E-Commerce Analytics Platform — Go-Live Verification

---

## INFRASTRUCTURE

- [ ] **1. Databases created** — ECOMMERCE_RAW, ECOMMERCE_STAGING, ECOMMERCE_ANALYTICS exist with correct retention policies (90d, 1d, 30d)
- [ ] **2. Warehouses configured** — LOADING_WH (Small), TRANSFORMING_WH (Medium), REPORTING_WH (Small, scale-out 2) with auto-suspend enabled
- [ ] **3. Resource monitors active** — All 4 monitors (per-warehouse + account) created with alert thresholds at 75%, 90%, 100%
- [ ] **4. Network policies set** — Production IP ranges configured (not 0.0.0.0/0)

## SECURITY

- [ ] **5. RBAC roles verified** — ECOMMERCE_LOADER, TRANSFORMER, ANALYST, ADMIN created with correct grants
- [ ] **6. Service accounts active** — SVC_ECOMMERCE_LOADER, SVC_ECOMMERCE_DBT, SVC_ECOMMERCE_DASHBOARD exist and use custom roles (not ACCOUNTADMIN)
- [ ] **7. Credentials in env vars** — All Snowflake, Postgres, Stripe, Slack credentials are in .env, not in code
- [ ] **8. .gitignore verified** — .env, profiles.yml, *.csv (except seeds), __pycache__ all ignored

## DATA PIPELINE

- [ ] **9. Full load tested** — All 8 RAW tables populated with expected row counts
- [ ] **10. Incremental load tested** — Re-ran extraction; no duplicates; only new rows added
- [ ] **11. dbt test suite passes** — `dbt test` returns 0 failures (all unique, not_null, relationship, custom tests green)
- [ ] **12. Airflow DAG completes** — End-to-end run from extraction → dbt → notification succeeds

## MONITORING & ALERTING

- [ ] **13. Slack alerts work** — Tested both success and failure notifications fire to the correct channel
- [ ] **14. SLA monitoring active** — 30-minute SLA on master DAG; breach notification confirmed working
- [ ] **15. Cost dashboard accessible** — Monitoring queries return data; resource monitor notifications verified

## DOCUMENTATION

- [ ] **16. Architecture diagram current** — Matches actual deployed infrastructure
- [ ] **17. dbt docs generated** — `dbt docs generate` + `dbt docs serve` renders complete lineage
- [ ] **18. Runbook documented** — Common failure scenarios and resolutions written (see runbook.md)

---

## SIGN-OFF

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Lead Engineer | | | |
| Data Analyst (UAT) | | | |
| Project Manager | | | |

---

*All items must be checked before the pipeline is considered production-ready.*
