# MODULE 1: INFRASTRUCTURE

## Snowflake Environment Setup

**Video Segment:** 0:00 - 0:25 (25 minutes)
**Git Tag:** `v0.1-architecture`

---

## OVERVIEW

This module creates the entire Snowflake environment from zero. Every resource is defined in SQL scripts that can be re-run (idempotent with CREATE OR REPLACE / CREATE IF NOT EXISTS). Nothing is clicked through the UI — everything is code.

---

## SUBMODULE 1.1: DATABASES & SCHEMAS

**File:** `snowflake_setup.sql` (Section 1)

### What Gets Created

```
ECOMMERCE_RAW (Database)
├── POSTGRES (Schema)     — tables loaded from PostgreSQL source
├── STRIPE (Schema)       — tables loaded from Stripe API
└── CSV_UPLOADS (Schema)  — tables loaded from CSV/Google Sheets

ECOMMERCE_STAGING (Database)
└── STAGING (Schema)      — dbt staging models (views)

ECOMMERCE_ANALYTICS (Database)
├── INTERMEDIATE (Schema) — dbt intermediate models
└── MARTS (Schema)        — dbt dimension + fact tables
```

### Design Decisions

**Why 3 databases instead of 1?**

| Approach | Pros | Cons |
|----------|------|------|
| 1 database, 3 schemas | Simpler. Fewer grants. | Can't set different data retention per layer. Can't clone/drop a layer independently. Roles are harder to scope. |
| 3 databases | Layer isolation. Independent retention. Per-layer cloning. Clean RBAC. | More grants to manage. Cross-database queries need full qualification. |

**We choose 3 databases** because:
1. RAW needs 90-day time travel (recovery). ANALYTICS needs 1-day (cost savings).
2. We can `CREATE DATABASE ECOMMERCE_STAGING CLONE ECOMMERCE_STAGING` for testing without affecting other layers.
3. RBAC is cleaner: LOADER role has full access to RAW, zero access to ANALYTICS.

### Implementation Details

```sql
-- Each database with explicit data retention
CREATE DATABASE IF NOT EXISTS ECOMMERCE_RAW
    DATA_RETENTION_TIME_IN_DAYS = 90
    COMMENT = 'Raw ingested data from all sources. No transformations.';

CREATE DATABASE IF NOT EXISTS ECOMMERCE_STAGING
    DATA_RETENTION_TIME_IN_DAYS = 1
    COMMENT = 'dbt staging layer. Views over raw data. Cleaned and typed.';

CREATE DATABASE IF NOT EXISTS ECOMMERCE_ANALYTICS
    DATA_RETENTION_TIME_IN_DAYS = 30
    COMMENT = 'Production analytics layer. Dimensions, facts, aggregates.';
```

### Schemas Within Each Database

```sql
-- RAW: one schema per source system
CREATE SCHEMA IF NOT EXISTS ECOMMERCE_RAW.POSTGRES;
CREATE SCHEMA IF NOT EXISTS ECOMMERCE_RAW.STRIPE;
CREATE SCHEMA IF NOT EXISTS ECOMMERCE_RAW.CSV_UPLOADS;

-- STAGING: single schema for all staging models
CREATE SCHEMA IF NOT EXISTS ECOMMERCE_STAGING.STAGING;

-- ANALYTICS: separate intermediate from final marts
CREATE SCHEMA IF NOT EXISTS ECOMMERCE_ANALYTICS.INTERMEDIATE;
CREATE SCHEMA IF NOT EXISTS ECOMMERCE_ANALYTICS.MARTS;
```

---

## SUBMODULE 1.2: WAREHOUSE STRATEGY

**File:** `snowflake_setup.sql` (Section 2)

### Warehouses

| Warehouse | Size | Auto-Suspend | Auto-Resume | Scaling | Purpose |
|-----------|------|-------------|-------------|---------|---------|
| `LOADING_WH` | Small | 60 seconds | Yes | 1 cluster (no scaling) | Data ingestion from all sources |
| `TRANSFORMING_WH` | Medium | 120 seconds | Yes | 1 cluster | dbt runs (staging + marts) |
| `REPORTING_WH` | Small | 60 seconds | Yes | Min 1, Max 2 (scale out) | Dashboard queries + analyst ad-hoc |

### Design Decisions

**Why different sizes?**

- **LOADING_WH (Small):** Ingestion is I/O-bound, not compute-bound. We're reading files and inserting rows. Small is sufficient. Using Medium would waste 2x credits for identical speed.
- **TRANSFORMING_WH (Medium):** dbt runs complex JOINs across tables with 100K+ rows. Medium provides enough compute for reasonable build times (~3 minutes for full run). Small would take ~8 minutes. The credit cost difference is negligible for a 3-minute run.
- **REPORTING_WH (Small with scale-out):** Dashboard queries are simple aggregations on pre-built facts. Small is fast enough. Scale-out to 2 clusters handles concurrent analysts without queuing.

**Why auto-suspend at 60s for loading but 120s for transforming?**

- LOADING_WH: Ingestion tasks are distinct (extract postgres, extract stripe, load CSV). Each completes, then there's idle time. 60s saves credits.
- TRANSFORMING_WH: dbt runs many sequential queries. Between each model, there's a 5-15 second gap. At 60s auto-suspend, the warehouse stays warm. At 120s, we avoid suspend/resume cycles during a dbt run (resume costs ~30 seconds).

### Implementation

```sql
CREATE WAREHOUSE IF NOT EXISTS LOADING_WH
    WITH WAREHOUSE_SIZE = 'SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    MIN_CLUSTER_COUNT = 1
    MAX_CLUSTER_COUNT = 1
    SCALING_POLICY = 'STANDARD'
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Data ingestion workloads. Small, fast auto-suspend.';

CREATE WAREHOUSE IF NOT EXISTS TRANSFORMING_WH
    WITH WAREHOUSE_SIZE = 'MEDIUM'
    AUTO_SUSPEND = 120
    AUTO_RESUME = TRUE
    MIN_CLUSTER_COUNT = 1
    MAX_CLUSTER_COUNT = 1
    SCALING_POLICY = 'STANDARD'
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'dbt transformation workloads. Medium for JOIN-heavy queries.';

CREATE WAREHOUSE IF NOT EXISTS REPORTING_WH
    WITH WAREHOUSE_SIZE = 'SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    MIN_CLUSTER_COUNT = 1
    MAX_CLUSTER_COUNT = 2
    SCALING_POLICY = 'STANDARD'
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Dashboard and analyst queries. Scale-out for concurrency.';
```

---

## SUBMODULE 1.3: RAW TABLE DEFINITIONS

**File:** `raw_tables.sql`

### Tables Created in ECOMMERCE_RAW.POSTGRES

| Table | Columns | Notes |
|-------|---------|-------|
| `RAW_ORDERS` | order_id, customer_id, order_date, status, total_amount, shipping_address, created_at, updated_at, _loaded_at | _loaded_at = ingestion timestamp for incremental tracking |
| `RAW_CUSTOMERS` | customer_id, email, first_name, last_name, phone, address, city, state, country, created_at, updated_at, _loaded_at | |
| `RAW_PRODUCTS` | product_id, name, category, subcategory, price, cost, weight, created_at, updated_at, _loaded_at | |
| `RAW_ORDER_ITEMS` | order_item_id, order_id, product_id, quantity, unit_price, discount, _loaded_at | |

### Tables Created in ECOMMERCE_RAW.STRIPE

| Table | Columns | Notes |
|-------|---------|-------|
| `RAW_PAYMENTS` | payment_id, order_id, amount, currency, status, payment_method, stripe_charge_id, created_at, _raw_json, _loaded_at | _raw_json stores the full Stripe response for auditability |
| `RAW_REFUNDS` | refund_id, payment_id, amount, reason, status, created_at, _raw_json, _loaded_at | |

### Tables Created in ECOMMERCE_RAW.CSV_UPLOADS

| Table | Columns | Notes |
|-------|---------|-------|
| `RAW_MARKETING_SPEND` | date, channel, campaign_name, spend, impressions, clicks, _loaded_at | |
| `RAW_CAMPAIGN_PERFORMANCE` | date, campaign_id, campaign_name, channel, conversions, revenue_attributed, _loaded_at | |

### Key Design Pattern: The `_loaded_at` Column

Every raw table has a `_loaded_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()` column. This serves two purposes:
1. **Incremental tracking:** "Give me all rows loaded after the last successful run"
2. **Audit trail:** "When did this data arrive in our warehouse?"

---

## SUBMODULE 1.4: RBAC & SECURITY

**File:** `rbac_setup.sql`

### Role Hierarchy

```
ACCOUNTADMIN (Snowflake built-in — never used in pipelines)
    │
SYSADMIN (Snowflake built-in — owns all objects)
    │
    ├── ECOMMERCE_ADMIN
    │   Full control over all 3 databases.
    │   Used by: Senior engineers, dbt admins.
    │
    ├── ECOMMERCE_LOADER
    │   USAGE + INSERT on ECOMMERCE_RAW.
    │   No access to STAGING or ANALYTICS.
    │   Used by: Ingestion service account.
    │
    ├── ECOMMERCE_TRANSFORMER
    │   USAGE on ECOMMERCE_RAW (read only).
    │   USAGE + CREATE on ECOMMERCE_STAGING + ECOMMERCE_ANALYTICS.
    │   Used by: dbt service account.
    │
    └── ECOMMERCE_ANALYST
        USAGE + SELECT on ECOMMERCE_ANALYTICS only.
        No access to RAW or STAGING.
        Used by: Analysts, dashboard service account.
```

### Service Accounts

| Account | Role | Used By |
|---------|------|---------|
| `SVC_ECOMMERCE_LOADER` | ECOMMERCE_LOADER | Python ingestion scripts |
| `SVC_ECOMMERCE_DBT` | ECOMMERCE_TRANSFORMER | dbt runs (Airflow) |
| `SVC_ECOMMERCE_DASHBOARD` | ECOMMERCE_ANALYST | Streamlit app |

### Implementation

```sql
-- Create custom roles
CREATE ROLE IF NOT EXISTS ECOMMERCE_ADMIN;
CREATE ROLE IF NOT EXISTS ECOMMERCE_LOADER;
CREATE ROLE IF NOT EXISTS ECOMMERCE_TRANSFORMER;
CREATE ROLE IF NOT EXISTS ECOMMERCE_ANALYST;

-- Role hierarchy: all custom roles granted to SYSADMIN
GRANT ROLE ECOMMERCE_ADMIN TO ROLE SYSADMIN;
GRANT ROLE ECOMMERCE_LOADER TO ROLE ECOMMERCE_ADMIN;
GRANT ROLE ECOMMERCE_TRANSFORMER TO ROLE ECOMMERCE_ADMIN;
GRANT ROLE ECOMMERCE_ANALYST TO ROLE ECOMMERCE_ADMIN;

-- LOADER: write to RAW only
GRANT USAGE ON DATABASE ECOMMERCE_RAW TO ROLE ECOMMERCE_LOADER;
GRANT USAGE ON ALL SCHEMAS IN DATABASE ECOMMERCE_RAW TO ROLE ECOMMERCE_LOADER;
GRANT INSERT, SELECT ON ALL TABLES IN DATABASE ECOMMERCE_RAW TO ROLE ECOMMERCE_LOADER;
GRANT USAGE ON WAREHOUSE LOADING_WH TO ROLE ECOMMERCE_LOADER;

-- TRANSFORMER: read RAW, write STAGING + ANALYTICS
GRANT USAGE ON DATABASE ECOMMERCE_RAW TO ROLE ECOMMERCE_TRANSFORMER;
GRANT SELECT ON ALL TABLES IN DATABASE ECOMMERCE_RAW TO ROLE ECOMMERCE_TRANSFORMER;
GRANT USAGE, CREATE TABLE, CREATE VIEW ON DATABASE ECOMMERCE_STAGING TO ROLE ECOMMERCE_TRANSFORMER;
GRANT USAGE, CREATE TABLE, CREATE VIEW ON DATABASE ECOMMERCE_ANALYTICS TO ROLE ECOMMERCE_TRANSFORMER;
GRANT USAGE ON WAREHOUSE TRANSFORMING_WH TO ROLE ECOMMERCE_TRANSFORMER;

-- ANALYST: read ANALYTICS only
GRANT USAGE ON DATABASE ECOMMERCE_ANALYTICS TO ROLE ECOMMERCE_ANALYST;
GRANT SELECT ON ALL TABLES IN SCHEMA ECOMMERCE_ANALYTICS.MARTS TO ROLE ECOMMERCE_ANALYST;
GRANT USAGE ON WAREHOUSE REPORTING_WH TO ROLE ECOMMERCE_ANALYST;

-- Service accounts
CREATE USER IF NOT EXISTS SVC_ECOMMERCE_LOADER
    PASSWORD = 'CHANGE_ME_USE_KEY_PAIR_AUTH'
    DEFAULT_ROLE = ECOMMERCE_LOADER
    DEFAULT_WAREHOUSE = LOADING_WH
    MUST_CHANGE_PASSWORD = FALSE;
GRANT ROLE ECOMMERCE_LOADER TO USER SVC_ECOMMERCE_LOADER;
```

**Production note:** In production, use key-pair authentication instead of passwords. The password above is for the video demo only.

---

## SUBMODULE 1.5: RESOURCE MONITORS

**File:** `resource_monitors.sql`

### Monitors

| Monitor | Scope | Credit Limit | Alerts |
|---------|-------|-------------|--------|
| `LOADING_MONITOR` | LOADING_WH | 50 credits/month | 75%, 90%, 100% (suspend) |
| `TRANSFORMING_MONITOR` | TRANSFORMING_WH | 100 credits/month | 75%, 90%, 100% (suspend) |
| `REPORTING_MONITOR` | REPORTING_WH | 75 credits/month | 75%, 90%, 100% (suspend + notify) |
| `ACCOUNT_MONITOR` | Entire account | 300 credits/month | 80%, 95%, 100% |

### Implementation

```sql
CREATE RESOURCE MONITOR IF NOT EXISTS LOADING_MONITOR
    WITH CREDIT_QUOTA = 50
    FREQUENCY = MONTHLY
    START_TIMESTAMP = IMMEDIATELY
    TRIGGERS
        ON 75 PERCENT DO NOTIFY
        ON 90 PERCENT DO NOTIFY
        ON 100 PERCENT DO SUSPEND;

ALTER WAREHOUSE LOADING_WH SET RESOURCE_MONITOR = LOADING_MONITOR;
```

### Cost Math

| Warehouse | Size | Credits/Hr | Estimated Daily Use | Monthly Credits | Monthly Cost (@ $3/credit) |
|-----------|------|-----------|--------------------|-----------------|----|
| LOADING_WH | Small | 1 | 2 hours | 60 | $180 |
| TRANSFORMING_WH | Medium | 2 | 1 hour | 60 | $180 |
| REPORTING_WH | Small | 1 | 4 hours | 120 | $360 |
| **Total** | | | | **240** | **~$720 max** |

In practice, auto-suspend means actual usage is 30-50% of these estimates, bringing monthly cost to ~$150-300.

---

## SUBMODULE 1.6: STAGES

**File:** `stages_setup.sql`

### Internal Stages

```sql
-- Stage for CSV file uploads
CREATE STAGE IF NOT EXISTS ECOMMERCE_RAW.CSV_UPLOADS.CSV_STAGE
    FILE_FORMAT = (
        TYPE = CSV
        SKIP_HEADER = 1
        FIELD_OPTIONALLY_ENCLOSED_BY = '"'
        NULL_IF = ('', 'NULL', 'null', 'N/A')
        ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
    )
    COMMENT = 'Internal stage for CSV file uploads from Google Sheets';

-- Stage for Parquet files (future use: bulk exports)
CREATE STAGE IF NOT EXISTS ECOMMERCE_RAW.POSTGRES.PARQUET_STAGE
    FILE_FORMAT = (
        TYPE = PARQUET
        SNAPPY_COMPRESSION = TRUE
    )
    COMMENT = 'Internal stage for Parquet file bulk loads';
```

---

## SUBMODULE 1.7: NETWORK POLICIES

**File:** `network_policies.sql`

```sql
-- Restrict access to known IP ranges
-- In production: add your office IP, VPN, Airflow server, Streamlit host
CREATE NETWORK POLICY IF NOT EXISTS ECOMMERCE_NETWORK_POLICY
    ALLOWED_IP_LIST = (
        '0.0.0.0/0'  -- DEVELOPMENT ONLY: allows all IPs
        -- Replace with actual IPs in production:
        -- '203.0.113.0/24',   -- Office network
        -- '198.51.100.50/32', -- Airflow server
        -- '198.51.100.51/32'  -- Streamlit host
    )
    COMMENT = 'Network policy for e-commerce platform. Restrict in production.';

-- Apply to service accounts
-- ALTER USER SVC_ECOMMERCE_LOADER SET NETWORK_POLICY = ECOMMERCE_NETWORK_POLICY;
```

---

## FILES IN THIS MODULE

```
infrastructure/
├── IMPLEMENTATION_PLAN.md       ← You are here
├── snowflake_setup.sql          ← Databases, schemas, warehouses (Submodules 1.1, 1.2)
├── raw_tables.sql               ← RAW layer table definitions (Submodule 1.3)
├── rbac_setup.sql               ← Roles, users, grants (Submodule 1.4)
├── resource_monitors.sql        ← Cost monitoring (Submodule 1.5)
├── stages_setup.sql             ← File stages for loading (Submodule 1.6)
├── network_policies.sql         ← Network access control (Submodule 1.7)
└── monitoring_queries.sql       ← Operational queries for Module 6
```

---

## VERIFICATION CHECKLIST

Run these after executing all SQL scripts:

```sql
-- Verify databases
SHOW DATABASES LIKE 'ECOMMERCE%';           -- Should return 3 rows

-- Verify warehouses
SHOW WAREHOUSES LIKE '%_WH';                -- Should return 3 rows

-- Verify roles
SHOW ROLES LIKE 'ECOMMERCE%';              -- Should return 4 rows

-- Verify resource monitors
SHOW RESOURCE MONITORS;                      -- Should return 4 rows

-- Verify stages
SHOW STAGES IN SCHEMA ECOMMERCE_RAW.CSV_UPLOADS;  -- Should return 1 row

-- Test RBAC isolation
USE ROLE ECOMMERCE_ANALYST;
SELECT * FROM ECOMMERCE_RAW.POSTGRES.RAW_ORDERS LIMIT 1;
-- Expected: Error — insufficient privileges (ANALYST cannot read RAW)

USE ROLE ECOMMERCE_LOADER;
SELECT * FROM ECOMMERCE_ANALYTICS.MARTS.FCT_ORDERS LIMIT 1;
-- Expected: Error — insufficient privileges (LOADER cannot read ANALYTICS)
```
