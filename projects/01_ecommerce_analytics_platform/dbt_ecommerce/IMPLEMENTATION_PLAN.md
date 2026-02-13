# MODULE 3: TRANSFORMATION (dbt)

## dbt E-Commerce Analytics — Detailed Implementation Plan

**Video Segment:** 1:10 - 2:10 (60 minutes)
**Git Tags:** `v0.3-dbt-staging`, `v0.4-dbt-marts`, `v0.5-dbt-tested`

---

## OVERVIEW

This module transforms raw ingested data into a production-ready star schema using dbt (data build tool) on Snowflake. The transformation layer sits between raw data (Module 2) and the dashboard/orchestration layers (Modules 4-5).

We follow the **staging -> intermediate -> marts** layered architecture recommended by dbt Labs. Each layer has a clear purpose, materialization strategy, and testing approach.

---

## SUBMODULE 3.1: PROJECT SETUP

**Files:** `dbt_project.yml`, `profiles.yml.example`, `packages.yml`

### dbt Project Configuration

The `dbt_project.yml` defines:
- **Project name:** `ecommerce`
- **Profile:** `ecommerce` (maps to `profiles.yml`)
- **Model materializations by folder:**
  - `staging/` = view (lightweight, always-fresh, zero storage cost)
  - `intermediate/` = table (reused by multiple downstream models)
  - `marts/` = table (default), with specific models overridden to incremental
- **Variables:**
  - `start_date`: Earliest date to include in date spine (default: '2024-01-01')
  - `currency`: Default reporting currency (default: 'USD')

### Profile Configuration

The `profiles.yml.example` shows the Snowflake connection pattern:
- Uses environment variables for all credentials (never hardcode secrets)
- Two targets: `dev` (personal schema) and `prod` (shared schemas)
- The `dev` target writes to a personal schema (`dbt_<username>`) for safe development
- The `prod` target writes to the correct database/schema per model layer:
  - Staging models -> `ECOMMERCE_STAGING.STAGING`
  - Intermediate models -> `ECOMMERCE_ANALYTICS.INTERMEDIATE`
  - Marts models -> `ECOMMERCE_ANALYTICS.MARTS`

### Package Dependencies

We use two community packages:
- **dbt-utils** (>= 1.1.0): `date_spine`, `generate_surrogate_key`, `star`, `safe_add`
- **dbt-expectations** (>= 0.10.0): Advanced data quality tests (expect_column_values_to_be_between, etc.)

---

## SUBMODULE 3.2: SOURCES

**File:** `models/staging/sources.yml`

### Source Definitions

Sources map dbt to the raw Snowflake tables created in Module 1. We define three source groups matching the three schemas in `ECOMMERCE_RAW`:

| Source | Schema | Tables |
|--------|--------|--------|
| `postgres` | `ECOMMERCE_RAW.POSTGRES` | RAW_ORDERS, RAW_CUSTOMERS, RAW_PRODUCTS, RAW_ORDER_ITEMS |
| `stripe` | `ECOMMERCE_RAW.STRIPE` | RAW_PAYMENTS, RAW_REFUNDS |
| `csv_uploads` | `ECOMMERCE_RAW.CSV_UPLOADS` | RAW_MARKETING_SPEND, RAW_CAMPAIGN_PERFORMANCE |

### Freshness Checks

Every source table has freshness monitoring using the `_loaded_at` column:
- **warn_after:** 12 hours (data pipeline is daily; 12h means it ran but was delayed)
- **error_after:** 24 hours (pipeline missed a full day; something is broken)

Run `dbt source freshness` to check. Airflow triggers this before every dbt run.

---

## SUBMODULE 3.3: STAGING MODELS

**Files:** `models/staging/stg_*.sql`, `models/staging/schema.yml`
**Materialization:** View
**Naming convention:** `stg_<entity>` (e.g., `stg_orders`, `stg_customers`)

### Purpose of the Staging Layer

Staging models are 1:1 with source tables. They perform ONLY:
1. **Renaming** columns to consistent conventions (snake_case, no ambiguity)
2. **Type casting** to correct data types
3. **Filtering** out known bad data (test orders, internal accounts)
4. **Light cleaning** (trim whitespace, normalize casing)
5. **Adding computed columns** that are pure functions of input columns

Staging models NEVER join multiple tables. That's the intermediate layer's job.

### Models

| Model | Source Table | Key Transformations |
|-------|-------------|---------------------|
| `stg_orders` | `RAW_ORDERS` | Cast dates, add `order_status_category` (active/completed/cancelled), filter test orders (order_id < 0) |
| `stg_customers` | `RAW_CUSTOMERS` | Deduplicate by email (keep latest), normalize state abbreviations, handle NULL phone/address |
| `stg_payments` | `RAW_PAYMENTS` | Convert amount from cents to dollars, map Stripe statuses to internal statuses, cast types |
| `stg_products` | `RAW_PRODUCTS` | Normalize category casing, flag negative-cost products, handle NULL cost/weight |

### Testing Strategy (Staging)

| Test | Applied To | Why |
|------|-----------|-----|
| `unique` | All primary keys | Guarantees no duplication made it through cleaning |
| `not_null` | All primary keys + critical columns | NULL PKs break downstream joins |
| `accepted_values` | `stg_orders.order_status_category` | Ensures our CASE statement covers all statuses |

---

## SUBMODULE 3.4: INTERMEDIATE MODELS

**Files:** `models/intermediate/int_*.sql`, `models/intermediate/schema.yml`
**Materialization:** Table
**Naming convention:** `int_<description>` (e.g., `int_order_items_enriched`)

### Purpose of the Intermediate Layer

Intermediate models combine multiple staging models with business logic. They serve as reusable building blocks for the final mart models. Key principle: if two or more mart models need the same join or calculation, it belongs in intermediate.

### Models

| Model | Inputs | Output | Purpose |
|-------|--------|--------|---------|
| `int_order_items_enriched` | `stg_orders`, `stg_products`, `stg_payments` + `RAW_ORDER_ITEMS` | One row per order with aggregated item and payment info | Central order enrichment: joins orders with their line items, products, and payments. Calculates gross revenue, discount amount, net revenue, item count per order. |
| `int_customer_lifetime` | `stg_customers`, `int_order_items_enriched` | One row per customer with lifetime metrics | Customer-level aggregations: lifetime value (LTV), first/last order dates, order count, average order value, days since last order. |

---

## SUBMODULE 3.5: MART MODELS -- DIMENSIONS

**Files:** `models/marts/dim_*.sql`, `models/marts/schema.yml`
**Materialization:** Table
**Naming convention:** `dim_<entity>` (e.g., `dim_customers`)

### Dimension Models

| Model | Source | Grain | Key Features |
|-------|--------|-------|-------------|
| `dim_customers` | `int_customer_lifetime` | One row per customer | Customer tier classification (Bronze/Silver/Gold/Platinum based on LTV), Type 2 SCD pattern for tracking tier changes over time |
| `dim_products` | `stg_products` | One row per product | Category hierarchy, margin calculation (price - cost), margin percentage, product size classification |
| `dim_dates` | Generated (no source) | One row per date | Date spine from `dbt_utils.date_spine`. Fiscal calendar (FY starts Feb 1), day-of-week names, ISO week, quarter, holiday flags (US federal holidays) |

### Type 2 SCD Explanation (dim_customers)

Type 2 Slowly Changing Dimensions track historical changes by creating new rows when attributes change. For our `dim_customers`:

```
customer_id | customer_tier | valid_from  | valid_to    | is_current
------------|---------------|-------------|-------------|----------
1001        | bronze        | 2024-01-15  | 2024-06-30  | false
1001        | silver        | 2024-07-01  | NULL        | true
```

**How it works:**
1. On each dbt run, we calculate the current tier for every customer
2. We compare to the latest snapshot in the dimension
3. If the tier changed, we close the old row (`valid_to = current_date - 1`, `is_current = false`)
4. We insert a new row with the new tier (`valid_from = current_date`, `is_current = true`)

In this simplified implementation, we use a dbt snapshot-style pattern within the model itself, computing current tier from `int_customer_lifetime` and providing the `is_current` flag. A full production implementation would use `dbt snapshot` with a dedicated snapshots directory.

**Why this matters:** Without Type 2 SCD, when a customer upgrades from Silver to Gold, we lose the history. We can no longer answer "How many Gold customers did we have last quarter?" because the dimension only stores the current state.

---

## SUBMODULE 3.6: MART MODELS -- FACTS

**Files:** `models/marts/fct_*.sql`, `models/marts/schema.yml`
**Materialization:** Incremental (fct_orders), Table (fct_daily_revenue)
**Naming convention:** `fct_<business_process>` (e.g., `fct_orders`)

### Fact Models

| Model | Source | Grain | Materialization | Measures |
|-------|--------|-------|-----------------|----------|
| `fct_orders` | `int_order_items_enriched`, dims | One row per order | Incremental | order_total, discount_total, net_revenue, item_count, payment_amount |
| `fct_daily_revenue` | `fct_orders` | One row per day | Table | total_revenue, order_count, avg_order_value, new_customer_count, returning_customer_count |

### Incremental Materialization Explained (fct_orders)

Incremental models only process NEW or CHANGED rows on each run, rather than rebuilding the entire table. This is critical for fact tables that grow continuously.

**How it works:**

```sql
-- On first run: creates the table with ALL data
-- On subsequent runs: only processes rows where order_date > max(order_date) in existing table

{{
    config(
        materialized='incremental',
        unique_key='order_id',
        incremental_strategy='merge'
    )
}}

SELECT ...
FROM {{ ref('int_order_items_enriched') }}
{% if is_incremental() %}
    WHERE order_date > (SELECT MAX(order_date) FROM {{ this }})
{% endif %}
```

**Key details:**
- `unique_key='order_id'` tells dbt to MERGE (upsert) instead of just INSERT. If an existing order is updated, its row gets replaced.
- `incremental_strategy='merge'` uses Snowflake's MERGE statement (INSERT + UPDATE in one atomic operation).
- `{{ this }}` refers to the existing table (the target of the incremental load).
- `is_incremental()` returns `false` on the first run (full table build) and `true` on subsequent runs.
- To do a full rebuild: `dbt run --full-refresh -s fct_orders`

**Why not just rebuild every time?**
- `fct_orders` will have 100K+ rows, growing by ~1,600/day
- After a year: 685K rows. Full rebuild scans everything. Incremental scans ~1,600 rows.
- At scale (millions of rows), this saves significant compute time and Snowflake credits.

---

## SUBMODULE 3.7: CUSTOM TESTS

**File:** `tests/assert_no_negative_revenue.sql`

### Custom Data Tests

dbt supports two types of tests:
1. **Generic tests** (defined in schema.yml): `unique`, `not_null`, `accepted_values`, `relationships`
2. **Singular tests** (standalone SQL files in `tests/`): Custom business rule validations

Our custom test checks that no order in `fct_orders` has a negative total revenue. This catches data quality issues that slip through individual column tests (e.g., a product with a negative price that wasn't flagged).

**How dbt tests work:** A test query should return ZERO rows to pass. Any rows returned indicate test failures.

---

## SUBMODULE 3.8: MACROS

**Files:** `macros/currency_convert.sql`, `macros/incremental_timestamp.sql`

### Jinja Macros

Macros are reusable Jinja functions that generate SQL. They promote DRY (Don't Repeat Yourself) principles.

| Macro | Purpose | Usage |
|-------|---------|-------|
| `currency_convert(amount, from_currency, to_currency)` | Converts monetary values between currencies using the `currency_rates` seed table | Used in any model that needs multi-currency support |
| `incremental_timestamp(timestamp_column)` | Generates the standard incremental WHERE clause | Used in all incremental models for consistent filtering |

---

## SUBMODULE 3.9: SEEDS

**File:** `seeds/currency_rates.csv`

### Seed Data

Seeds are CSV files that dbt loads as tables in the warehouse. They are version-controlled and suitable for small, slowly-changing reference data.

Our `currency_rates.csv` contains exchange rates for 5 currencies (USD, EUR, GBP, CAD, AUD) with rates relative to USD. This is used by the `currency_convert` macro.

**When to use seeds vs. sources:**
- **Seeds:** Small (< 1000 rows), changes infrequently, maintained by the analytics team
- **Sources:** Large, changes frequently, maintained by upstream systems

---

## SUBMODULE 3.10: DOCUMENTATION

**Files:** All `schema.yml` files

### Documentation Strategy

Every model and every column in the mart layer has a description. This enables:
1. `dbt docs generate` creates a browsable documentation site
2. `dbt docs serve` hosts it locally at http://localhost:8080
3. The lineage graph shows the full dependency chain from source to mart
4. Analysts can self-serve understanding of what each column means

---

## MODEL DEPENDENCY GRAPH

```
RAW SOURCES (ECOMMERCE_RAW)
    |
    |-- ECOMMERCE_RAW.POSTGRES.RAW_ORDERS
    |-- ECOMMERCE_RAW.POSTGRES.RAW_CUSTOMERS
    |-- ECOMMERCE_RAW.POSTGRES.RAW_PRODUCTS
    |-- ECOMMERCE_RAW.POSTGRES.RAW_ORDER_ITEMS
    |-- ECOMMERCE_RAW.STRIPE.RAW_PAYMENTS
    |
    v
STAGING LAYER (views in ECOMMERCE_STAGING.STAGING)
    |
    |-- stg_orders .............. RAW_ORDERS -> clean, cast, categorize
    |-- stg_customers ........... RAW_CUSTOMERS -> dedupe, normalize
    |-- stg_payments ............ RAW_PAYMENTS -> cents->dollars, map statuses
    |-- stg_products ............ RAW_PRODUCTS -> normalize, flag bad cost
    |
    v
INTERMEDIATE LAYER (tables in ECOMMERCE_ANALYTICS.INTERMEDIATE)
    |
    |-- int_order_items_enriched .... stg_orders + RAW_ORDER_ITEMS + stg_products + stg_payments
    |-- int_customer_lifetime ....... stg_customers + int_order_items_enriched
    |
    v
MART LAYER (tables in ECOMMERCE_ANALYTICS.MARTS)
    |
    |-- dim_customers ........... int_customer_lifetime -> tier, SCD
    |-- dim_products ............ stg_products -> margin, hierarchy
    |-- dim_dates ............... generated via dbt_utils.date_spine
    |-- fct_orders .............. int_order_items_enriched + dims (INCREMENTAL)
    |-- fct_daily_revenue ....... fct_orders -> pre-aggregated daily metrics
```

---

## MATERIALIZATION STRATEGY

| Layer | Materialization | Database.Schema | Rationale |
|-------|----------------|-----------------|-----------|
| Staging | `view` | ECOMMERCE_STAGING.STAGING | Zero storage cost. Always reads fresh raw data. Acceptable because raw tables are small (< 250K rows). |
| Intermediate | `table` | ECOMMERCE_ANALYTICS.INTERMEDIATE | Reused by multiple mart models. Materializing avoids redundant computation. |
| Dimensions | `table` | ECOMMERCE_ANALYTICS.MARTS | Stable, frequently joined. Need fast query performance for dashboard queries. |
| fct_orders | `incremental` | ECOMMERCE_ANALYTICS.MARTS | Grows daily. Full rebuild wastes compute. Merge strategy handles late-arriving updates. |
| fct_daily_revenue | `table` | ECOMMERCE_ANALYTICS.MARTS | Pre-aggregated for dashboard speed. Rebuilt fully because it depends on the complete orders fact. |

---

## TESTING STRATEGY

### Test Coverage by Layer

| Layer | Test Types | Count | Purpose |
|-------|-----------|-------|---------|
| Sources | `freshness` | 8 tables | Detect stale data before transformation runs |
| Staging | `unique`, `not_null` on PKs | ~8 tests | Data integrity at the entry point |
| Staging | `accepted_values` on status columns | ~2 tests | Business rule validation |
| Intermediate | `not_null` on key columns | ~4 tests | Join integrity (no orphaned records) |
| Marts | `unique`, `not_null` on all PKs | ~10 tests | Final output integrity |
| Marts | `relationships` between facts and dims | ~6 tests | Referential integrity in star schema |
| Custom | `assert_no_negative_revenue` | 1 test | Business rule: revenue must be non-negative |
| **Total** | | **~40 tests** | |

### Running Tests

```bash
# Run all tests
dbt test

# Run tests for a specific model
dbt test -s fct_orders

# Run only source freshness tests
dbt source freshness

# Run tests for everything downstream of a model
dbt test -s stg_orders+
```

---

## FILES IN THIS MODULE

```
dbt_ecommerce/
|-- IMPLEMENTATION_PLAN.md              <- You are here
|-- dbt_project.yml                     <- Project configuration
|-- profiles.yml.example                <- Snowflake connection template
|-- packages.yml                        <- Package dependencies
|
|-- models/
|   |-- staging/
|   |   |-- sources.yml                 <- Source definitions + freshness
|   |   |-- schema.yml                  <- Staging model tests + docs
|   |   |-- stg_orders.sql             <- Clean orders
|   |   |-- stg_customers.sql          <- Clean customers
|   |   |-- stg_payments.sql           <- Clean payments
|   |   |-- stg_products.sql           <- Clean products
|   |
|   |-- intermediate/
|   |   |-- schema.yml                  <- Intermediate model tests + docs
|   |   |-- int_order_items_enriched.sql <- Order + items + payments
|   |   |-- int_customer_lifetime.sql   <- Customer lifetime metrics
|   |
|   |-- marts/
|       |-- schema.yml                  <- Mart model tests + docs
|       |-- dim_customers.sql           <- Customer dimension (Type 2 SCD)
|       |-- dim_products.sql            <- Product dimension
|       |-- dim_dates.sql              <- Date dimension (generated)
|       |-- fct_orders.sql             <- Order fact (incremental)
|       |-- fct_daily_revenue.sql      <- Daily revenue fact
|
|-- macros/
|   |-- currency_convert.sql            <- Currency conversion macro
|   |-- incremental_timestamp.sql       <- Incremental filter macro
|
|-- tests/
|   |-- assert_no_negative_revenue.sql  <- Custom business rule test
|
|-- seeds/
    |-- currency_rates.csv              <- Currency exchange rates
```

---

## VERIFICATION CHECKLIST

After building all models:

```bash
# 1. Install packages
dbt deps

# 2. Load seed data
dbt seed

# 3. Run all models
dbt run

# 4. Run all tests
dbt test

# 5. Check source freshness
dbt source freshness

# 6. Generate documentation
dbt docs generate
dbt docs serve
```

### Expected Results

| Command | Expected Outcome |
|---------|-----------------|
| `dbt run` | 11 models built (4 staging views, 2 intermediate tables, 5 mart tables) with 0 errors |
| `dbt test` | ~40 tests pass with 0 failures |
| `dbt source freshness` | All sources within 24h threshold |
| `dbt docs serve` | Browsable site with full lineage graph |

### Snowflake Verification

```sql
-- Verify staging views exist
SELECT TABLE_NAME, TABLE_TYPE
FROM ECOMMERCE_STAGING.INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'STAGING';
-- Expected: 4 views (STG_ORDERS, STG_CUSTOMERS, STG_PAYMENTS, STG_PRODUCTS)

-- Verify intermediate tables exist
SELECT TABLE_NAME, TABLE_TYPE
FROM ECOMMERCE_ANALYTICS.INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'INTERMEDIATE';
-- Expected: 2 tables (INT_ORDER_ITEMS_ENRICHED, INT_CUSTOMER_LIFETIME)

-- Verify mart tables exist
SELECT TABLE_NAME, TABLE_TYPE
FROM ECOMMERCE_ANALYTICS.INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'MARTS';
-- Expected: 5 tables (DIM_CUSTOMERS, DIM_PRODUCTS, DIM_DATES, FCT_ORDERS, FCT_DAILY_REVENUE)

-- Verify incremental model works
SELECT COUNT(*) AS row_count, MAX(order_date) AS latest_order
FROM ECOMMERCE_ANALYTICS.MARTS.FCT_ORDERS;
```

---

*Snowbrix Academy | Production-Grade Data Engineering. No Fluff.*
