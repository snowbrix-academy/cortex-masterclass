# MASTER IMPLEMENTATION PLAN

## E-Commerce Analytics Platform on Snowflake

---

## PLAN OVERVIEW

This document is the master blueprint. Each module below links to its own detailed implementation plan. The modules are designed to be built sequentially — each depends on the previous one.

```
MODULE 1                MODULE 2               MODULE 3
Infrastructure    →     Ingestion        →     Transformation
(Snowflake env)         (Python ETL)           (dbt models)
    │                       │                       │
    │                       │                       │
    ▼                       ▼                       ▼
Git Tag: v0.1          Git Tag: v0.2          Git Tags: v0.3, v0.4, v0.5
Video: 0:00-0:25       Video: 0:25-1:10       Video: 1:10-2:10
                                                    │
                                                    ▼
MODULE 4                MODULE 5               MODULE 6
Orchestration     →     Dashboard        →     Operations
(Airflow DAGs)          (Streamlit)            (Cost + Security)
    │                       │                       │
    ▼                       ▼                       ▼
Git Tag: v0.6          Git Tag: v0.7          Git Tag: v1.0
Video: 2:10-2:45       Video: 2:45-3:12       Video: 3:12-3:25
```

---

## MODULE 1: INFRASTRUCTURE

**Folder:** `infrastructure/`
**Detailed Plan:** [`infrastructure/IMPLEMENTATION_PLAN.md`](infrastructure/IMPLEMENTATION_PLAN.md)
**Video Segment:** 0:00 - 0:25 (25 minutes)
**Git Tag:** `v0.1-architecture`

### What Gets Built

| Submodule | File | Purpose |
|-----------|------|---------|
| 1.1 Account & Databases | `snowflake_setup.sql` | Create databases: ECOMMERCE_RAW, ECOMMERCE_STAGING, ECOMMERCE_ANALYTICS |
| 1.2 Warehouse Strategy | `snowflake_setup.sql` | Create 3 warehouses with specific sizes and auto-suspend policies |
| 1.3 Schema Structure | `snowflake_setup.sql` | Create schemas within each database for logical separation |
| 1.4 RBAC & Security | `rbac_setup.sql` | Roles: LOADER, TRANSFORMER, ANALYST, ADMIN with minimum permissions |
| 1.5 Resource Monitors | `resource_monitors.sql` | Cost alerting at 75%, 90%, 100% thresholds |
| 1.6 Network Policies | `network_policies.sql` | IP allowlisting for production access |
| 1.7 Stages | `stages_setup.sql` | Internal stages for CSV and Parquet file loading |

### Key Decisions Documented

- Why 3 separate databases instead of 1 database with 3 schemas
- Why warehouse sizes differ per workload
- Auto-suspend timing tradeoffs (60s vs 300s vs never)
- Role hierarchy design rationale

### Exit Criteria

- [ ] 3 databases created and accessible
- [ ] 3 warehouses running with correct policies
- [ ] RBAC roles created with grants applied
- [ ] Resource monitors active with Slack alerting configured
- [ ] Internal stages created for file loading

---

## MODULE 2: DATA INGESTION

**Folder:** `ingestion/`
**Detailed Plan:** [`ingestion/IMPLEMENTATION_PLAN.md`](ingestion/IMPLEMENTATION_PLAN.md)
**Video Segment:** 0:25 - 1:10 (45 minutes)
**Git Tag:** `v0.2-ingestion`

### What Gets Built

| Submodule | File(s) | Purpose |
|-----------|---------|---------|
| 2.1 Source Database Setup | `seed/seed_postgres.py`, `seed/schema.sql`, `seed/generate_data.py` | Docker Postgres with realistic e-commerce data (100K orders, 50K customers, 200 products) |
| 2.2 Snowflake Client | `utils/snowflake_client.py` | Reusable connection manager with context manager pattern |
| 2.3 Retry Handler | `utils/retry_handler.py` | Exponential backoff utility for all connectors |
| 2.4 Postgres Extractor | `postgres_extractor.py` | Full-load and incremental extraction from Postgres to Snowflake RAW |
| 2.5 Stripe Connector | `stripe_connector.py` | Stripe API pagination, rate limiting, JSON flattening |
| 2.6 CSV Loader | `csv_loader.py` | Google Sheets CSV → Snowflake stage → COPY INTO |
| 2.7 Ingestion Config | `config.py` | Centralized configuration from environment variables |

### Data Volume

| Source | Table | Rows (Full Load) | Incremental (Daily) |
|--------|-------|-------------------|---------------------|
| Postgres | orders | 100,000 | ~1,600 |
| Postgres | customers | 50,000 | ~200 |
| Postgres | products | 200 | ~2 |
| Postgres | order_items | 250,000 | ~4,000 |
| Stripe | payments | 100,000 | ~1,600 |
| Stripe | refunds | 5,000 | ~80 |
| CSV | marketing_spend | 365 | 1 (daily append) |
| CSV | campaign_performance | 1,200 | ~30 |

### Key Decisions Documented

- Why build custom Python instead of using Airbyte/Fivetran
- Incremental extraction strategy: timestamp-based vs. CDC
- PUT + COPY INTO vs. Snowpipe for batch loading
- JSON flattening: Python-side vs. Snowflake LATERAL FLATTEN

### Exit Criteria

- [ ] Postgres running in Docker with seeded data
- [ ] Full load completes for all 4 Postgres tables
- [ ] Incremental load works (re-run extracts only new/changed rows)
- [ ] Stripe API data loaded with nested JSON flattened
- [ ] CSV data staged and loaded with error handling
- [ ] All data visible in Snowflake RAW database

---

## MODULE 3: TRANSFORMATION (dbt)

**Folder:** `dbt_ecommerce/`
**Detailed Plan:** [`dbt_ecommerce/IMPLEMENTATION_PLAN.md`](dbt_ecommerce/IMPLEMENTATION_PLAN.md)
**Video Segment:** 1:10 - 2:10 (60 minutes)
**Git Tags:** `v0.3-dbt-staging`, `v0.4-dbt-marts`, `v0.5-dbt-tested`

### What Gets Built

| Submodule | File(s) | Purpose |
|-----------|---------|---------|
| 3.1 Project Setup | `dbt_project.yml`, `profiles.yml.example`, `packages.yml` | dbt configuration, Snowflake connection, package dependencies |
| 3.2 Sources | `models/staging/sources.yml` | Source definitions with freshness checks |
| 3.3 Staging Models | `models/staging/stg_*.sql` + `schema.yml` | Clean, rename, type-cast raw data (4 models) |
| 3.4 Intermediate Models | `models/intermediate/int_*.sql` + `schema.yml` | Business logic joins and calculations (2 models) |
| 3.5 Mart Models — Dimensions | `models/marts/dim_*.sql` + `schema.yml` | Dimension tables including Type 2 SCD (3 models) |
| 3.6 Mart Models — Facts | `models/marts/fct_*.sql` + `schema.yml` | Fact tables with measures and foreign keys (2 models) |
| 3.7 Custom Tests | `tests/assert_no_negative_revenue.sql` | Business rule validation beyond built-in tests |
| 3.8 Macros | `macros/currency_convert.sql`, `macros/incremental_timestamp.sql` | Reusable Jinja macros for DRY transformations |
| 3.9 Seeds | `seeds/currency_rates.csv` | Static reference data loaded via dbt seed |
| 3.10 Documentation | `models/*/schema.yml` | Column descriptions, tests, relationships |

### Model Dependency Graph

```
RAW SOURCES
├── raw_orders ──────────────┐
├── raw_customers ────────┐  │
├── raw_payments ───────┐ │  │
├── raw_products ─────┐ │ │  │
└── raw_marketing ──┐ │ │ │  │
                    │ │ │ │  │
STAGING             ▼ ▼ ▼ ▼  ▼
├── stg_products ──────────────────────────────┐
├── stg_payments ────────────────────────┐     │
├── stg_customers ─────────────────┐     │     │
└── stg_orders ──────────────┐     │     │     │
                             │     │     │     │
INTERMEDIATE                 ▼     ▼     ▼     ▼
├── int_order_items_enriched ◄─────┴─────┴─────┘
└── int_customer_lifetime ◄──┘
                             │
MARTS                        ▼
├── dim_customers ◄──── int_customer_lifetime
├── dim_products ◄───── stg_products
├── dim_dates ────────── (generated — no source dependency)
├── fct_orders ◄──────── int_order_items_enriched + dims
└── fct_daily_revenue ◄─ fct_orders (pre-aggregation)
```

### Materialization Strategy

| Layer | Materialization | Why |
|-------|----------------|-----|
| Staging | View | Lightweight, always fresh, no storage cost |
| Intermediate | View (small) / Table (large) | Depends on query complexity and reuse |
| Dimensions | Table | Queried frequently, stable, need performance |
| Facts | Incremental | Large and growing — only process new rows |
| Daily Revenue | Table | Pre-aggregated for dashboard speed |

### Exit Criteria

- [ ] `dbt run` completes with 0 errors
- [ ] `dbt test` passes all 25+ tests
- [ ] `dbt docs generate` produces a browsable site
- [ ] Lineage graph shows correct dependencies
- [ ] Type 2 SCD on dim_customers captures historical changes
- [ ] Incremental model on fct_orders processes only new data on re-run

---

## MODULE 4: ORCHESTRATION (Airflow)

**Folder:** `airflow/`
**Detailed Plan:** [`airflow/IMPLEMENTATION_PLAN.md`](airflow/IMPLEMENTATION_PLAN.md)
**Video Segment:** 2:10 - 2:45 (35 minutes)
**Git Tag:** `v0.6-airflow`

### What Gets Built

| Submodule | File(s) | Purpose |
|-----------|---------|---------|
| 4.1 Airflow Setup | `docker-compose.yml` (root), `airflow/Dockerfile` | Local Airflow with Docker Compose |
| 4.2 Connections | Setup via Airflow UI/CLI | Snowflake, Postgres, Stripe API, Slack webhook connections |
| 4.3 Master DAG | `dags/ecommerce_master_dag.py` | End-to-end orchestration with dependency chain |
| 4.4 Slack Alerting | `plugins/slack_alert.py` | Success/failure notifications to Slack |
| 4.5 SLA Monitoring | Integrated in DAG definition | 30-minute SLA with breach callbacks |
| 4.6 Error Handling | Integrated in DAG definition | Retry policies, dead man's switch, failure isolation |

### DAG Structure

```
ecommerce_master_dag (Schedule: Daily at 06:00 UTC)
│
├── extract_postgres_orders ──────┐
├── extract_postgres_customers ───┤
├── extract_postgres_products ────┤── (parallel extraction)
├── extract_postgres_order_items ─┤
├── extract_stripe_payments ──────┤
└── load_csv_marketing ───────────┘
                                  │
                                  ▼
                          dbt_run_staging
                                  │
                                  ▼
                        dbt_run_intermediate
                                  │
                                  ▼
                          dbt_run_marts
                                  │
                                  ▼
                           dbt_test_all
                                  │
                          ┌───────┴───────┐
                          ▼               ▼
                   notify_success   notify_failure
                   (Slack: green)   (Slack: red)
```

### Exit Criteria

- [ ] Airflow UI accessible at localhost:8080
- [ ] All connections configured and tested
- [ ] DAG runs end-to-end without errors
- [ ] Slack notifications fire on success AND failure
- [ ] SLA breach triggers an alert
- [ ] Retry policy handles transient Postgres failures

---

## MODULE 5: DASHBOARD (Streamlit)

**Folder:** `dashboard/`
**Detailed Plan:** [`dashboard/IMPLEMENTATION_PLAN.md`](dashboard/IMPLEMENTATION_PLAN.md)
**Video Segment:** 2:45 - 3:12 (27 minutes)
**Git Tag:** `v0.7-dashboard`

### What Gets Built

| Submodule | File(s) | Purpose |
|-----------|---------|---------|
| 5.1 Snowflake Connection | `dashboard/snowflake_connection.py` | Cached connection for dashboard queries |
| 5.2 Revenue Dashboard | `dashboard/streamlit_app.py` | Main dashboard with 4 panels |
| 5.3 Query Layer | `dashboard/queries/` | SQL files for each dashboard metric |

### Dashboard Panels

```
┌─────────────────────────────────────────────────────────────┐
│                    SNOWBRIX E-COMMERCE DASHBOARD              │
├──────────────┬──────────────┬──────────────┬────────────────┤
│  Total       │  Orders      │  Avg Order   │  Active        │
│  Revenue     │  Today       │  Value       │  Customers     │
│  $2.4M       │  1,247       │  $68.42      │  12,847        │
├──────────────┴──────────────┴──────────────┴────────────────┤
│                                                              │
│  Revenue Over Time (Line Chart — 90 days)                   │
│  ████████████████████████████████████████████                │
│                                                              │
├─────────────────────────────┬────────────────────────────────┤
│                             │                                │
│  Customer LTV Distribution  │  Top 10 Products by Revenue    │
│  (Histogram)                │  (Horizontal Bar Chart)        │
│                             │                                │
├─────────────────────────────┴────────────────────────────────┤
│                                                              │
│  Revenue by Category (Donut) │  Daily Order Trend (Area)     │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### Exit Criteria

- [ ] Dashboard launches at localhost:8501
- [ ] All 4 KPI cards show real numbers from Snowflake
- [ ] Charts render with correct data
- [ ] Page load time < 3 seconds
- [ ] Auto-refresh works (5-minute interval)

---

## MODULE 6: OPERATIONS (Cost + Security + Production Readiness)

**Folder:** `docs/` + `infrastructure/`
**Detailed Plan:** [`docs/IMPLEMENTATION_PLAN.md`](docs/IMPLEMENTATION_PLAN.md)
**Video Segment:** 3:12 - 3:25 (13 minutes)
**Git Tag:** `v1.0-production`

### What Gets Built

| Submodule | File(s) | Purpose |
|-----------|---------|---------|
| 6.1 Cost Analysis | `docs/cost_analysis.md` | Query-level cost breakdown + optimization recommendations |
| 6.2 Security Hardening | `infrastructure/rbac_setup.sql`, `infrastructure/network_policies.sql` | Role-based access + network restrictions |
| 6.3 Production Checklist | `docs/production_checklist.md` | 15-point go-live checklist |
| 6.4 Monitoring Queries | `infrastructure/monitoring_queries.sql` | Top-N expensive queries, warehouse utilization, user activity |

### Exit Criteria

- [ ] Monthly cost calculated and documented
- [ ] All pipelines use service accounts (no personal credentials)
- [ ] Resource monitors alert at 75%, 90%, 100%
- [ ] Network policies restrict access to known IPs
- [ ] Production checklist completed with all items green

---

## DEPENDENCY CHAIN

```
Module 1 (Infrastructure)
    │
    ├── MUST complete before Module 2 (Snowflake must exist to load into)
    │
Module 2 (Ingestion)
    │
    ├── MUST complete before Module 3 (RAW data must exist for dbt to transform)
    │
Module 3 (dbt Transformation)
    │
    ├── MUST complete before Module 4 (Airflow orchestrates existing scripts)
    │   AND before Module 5 (Dashboard queries mart models)
    │
Module 4 (Airflow) ──── can run in PARALLEL with ──── Module 5 (Dashboard)
    │                                                      │
    └──────────────────── BOTH before ─────────────────────┘
                              │
                        Module 6 (Operations)
                        (Final hardening pass)
```

---

## ESTIMATED BUILD TIME

| Module | Experienced Engineer | Following Video |
|--------|---------------------|-----------------|
| Module 1: Infrastructure | 30 min | 25 min |
| Module 2: Ingestion | 2 hrs | 45 min |
| Module 3: dbt | 3 hrs | 60 min |
| Module 4: Airflow | 1.5 hrs | 35 min |
| Module 5: Dashboard | 1 hr | 27 min |
| Module 6: Operations | 45 min | 13 min |
| **Total** | **~8.5 hrs** | **~3.5 hrs (video)** |

The video is faster because decisions are pre-made. Building from scratch requires decision time.

---

*Snowbrix Academy | Production-Grade Data Engineering. No Fluff.*
