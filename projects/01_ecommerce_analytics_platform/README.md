# E-Commerce Analytics Platform on Snowflake

## Build a Production E-Commerce Data Warehouse from Scratch

**Video Duration:** 3 hours 30 minutes | **Level:** Intermediate | **Project Code:** PROJ-01

---

## The Business Scenario

A mid-size e-commerce company processing **500K orders/month** is running analytics directly off their production PostgreSQL database. The consequences:

- Dashboard queries take 45 seconds (unacceptable for executives)
- The production database slows down during reporting hours
- No historical snapshots — they can't answer "what did the data look like last month?"
- The CEO wants real-time revenue tracking and the current setup can't deliver

**They've purchased Snowflake. Our job: build the entire analytics platform from zero to production.**

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                        SOURCE SYSTEMS                               │
├──────────────────┬──────────────────┬──────────────────────────────┤
│ PostgreSQL       │ Stripe API       │ Google Sheets (CSV)          │
│ - orders         │ - payments       │ - marketing_spend            │
│ - customers      │ - refunds        │ - campaign_performance       │
│ - products       │ - disputes       │                              │
│ - order_items    │                  │                              │
└────────┬─────────┴────────┬─────────┴──────────────┬───────────────┘
         │                  │                        │
         ▼                  ▼                        ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     INGESTION LAYER (Python)                        │
├──────────────────┬──────────────────┬──────────────────────────────┤
│ postgres_        │ stripe_          │ csv_loader.py                │
│ extractor.py     │ connector.py     │                              │
│ (Incremental)    │ (API + Pagination)│ (Stage + COPY INTO)         │
└────────┬─────────┴────────┬─────────┴──────────────┬───────────────┘
         │                  │                        │
         ▼                  ▼                        ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    SNOWFLAKE (3-Layer Architecture)                  │
│                                                                     │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────────────┐    │
│  │  RAW DATABASE │   │   STAGING    │   │   ANALYTICS          │    │
│  │              │   │  DATABASE    │   │   DATABASE           │    │
│  │ raw_orders   │──▶│ stg_orders   │──▶│ dim_customers        │    │
│  │ raw_customers│   │ stg_customers│   │ dim_products         │    │
│  │ raw_payments │   │ stg_payments │   │ dim_dates            │    │
│  │ raw_products │   │ stg_products │   │ fct_orders           │    │
│  │ raw_marketing│   │              │   │ fct_daily_revenue    │    │
│  └──────────────┘   └──────────────┘   └──────────────────────┘    │
│                                                                     │
│  Warehouses: LOADING_WH (S) │ TRANSFORMING_WH (M) │ REPORTING_WH(S)│
└─────────────────────────────────────────────────────────────────────┘
         │                              │
         ▼                              ▼
┌──────────────────┐          ┌──────────────────────┐
│  AIRFLOW          │          │  STREAMLIT DASHBOARD  │
│  Orchestration    │          │  - Revenue trending   │
│  - Daily 6AM UTC  │          │  - Customer LTV       │
│  - Slack alerts   │          │  - Top products       │
│  - SLA monitoring │          │  - Real-time orders   │
└──────────────────┘          └──────────────────────┘
```

---

## Tech Stack

| Layer | Technology | Version | Why |
|-------|-----------|---------|-----|
| Source Database | PostgreSQL | 15+ | Industry standard OLTP |
| Cloud Warehouse | Snowflake | Latest | Cost-effective analytics at scale |
| Ingestion | Python | 3.11+ | Full control, no vendor lock-in |
| Transformation | dbt-core | 1.7+ | SQL-first, testable, documented |
| Orchestration | Apache Airflow | 2.8+ | Industry standard, extensible |
| Dashboard | Streamlit | 1.30+ | Free, code-first, fast to ship |
| Containerization | Docker + Compose | Latest | Reproducible local environment |

---

## Modules

| Module | Folder | Description |
|--------|--------|-------------|
| **Module 1** | `infrastructure/` | Snowflake environment: databases, warehouses, roles, security |
| **Module 2** | `ingestion/` | Python extraction from Postgres, Stripe API, CSV files |
| **Module 3** | `dbt_ecommerce/` | dbt transformation: staging, intermediate, marts, tests |
| **Module 4** | `airflow/` | Orchestration DAGs, alerting, SLA monitoring |
| **Module 5** | `dashboard/` | Streamlit FinOps and analytics dashboard |
| **Module 6** | `docs/` | Architecture docs, cost analysis, production checklist |

Each module has its own `IMPLEMENTATION_PLAN.md` with detailed submodules.

---

## Prerequisites

- Docker Desktop installed and running
- Python 3.11+ with pip
- A Snowflake account (free trial works — 30 days, $400 credit)
- A Stripe account (free sandbox/test mode)
- Git

---

## Quick Start

```bash
# 1. Clone the repository
git clone <repo-url>
cd 01_ecommerce_analytics_platform

# 2. Copy environment variables
cp .env.example .env
# Edit .env with your Snowflake credentials + Stripe API key

# 3. Start local services (Postgres + Airflow)
docker-compose up -d

# 4. Install Python dependencies
pip install -r requirements.txt

# 5. Seed the source PostgreSQL database
python ingestion/seed/seed_postgres.py

# 6. Run the Snowflake infrastructure setup
# Execute infrastructure/snowflake_setup.sql in your Snowflake worksheet

# 7. Run the initial data load
python ingestion/postgres_extractor.py --full-load
python ingestion/stripe_connector.py --full-load
python ingestion/csv_loader.py

# 8. Run dbt transformations
cd dbt_ecommerce
dbt deps
dbt run
dbt test
cd ..

# 9. Launch the dashboard
streamlit run dashboard/streamlit_app.py
```

---

## Git Tags (Match Video Timestamps)

| Tag | Video Timestamp | Milestone |
|-----|----------------|-----------|
| `v0.1-architecture` | 0:25 | Snowflake environment ready |
| `v0.2-ingestion` | 1:10 | All raw data loaded |
| `v0.3-dbt-staging` | 1:30 | Staging models complete |
| `v0.4-dbt-marts` | 2:03 | Full dimensional model |
| `v0.5-dbt-tested` | 2:10 | Tests + docs added |
| `v0.6-airflow` | 2:45 | Orchestration deployed |
| `v0.7-dashboard` | 3:00 | Streamlit dashboard live |
| `v1.0-production` | 3:25 | Cost optimized, secured, done |

---

## Cost Estimate

| Resource | Monthly Cost |
|----------|-------------|
| Snowflake LOADING_WH (Small, ~2 hrs/day) | ~$46 |
| Snowflake TRANSFORMING_WH (Medium, ~1 hr/day) | ~$60 |
| Snowflake REPORTING_WH (Small, ~4 hrs/day) | ~$21 |
| Snowflake Storage (50GB compressed) | ~$23 |
| **Total** | **~$150/month** |

The company was spending $3,400/month on their old analytics approach. **ROI: 22x.**

---

*Snowbrix Academy | Production-Grade Data Engineering. No Fluff.*
