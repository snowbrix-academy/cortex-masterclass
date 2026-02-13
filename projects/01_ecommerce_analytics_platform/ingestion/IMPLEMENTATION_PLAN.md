# MODULE 2: DATA INGESTION

## Python Extraction from PostgreSQL, Stripe API, and CSV Files

**Video Segment:** 0:25 - 1:10 (45 minutes)
**Git Tag:** `v0.2-ingestion`

---

## OVERVIEW

This module builds three custom data connectors in Python. We're NOT using Airbyte, Fivetran, or any managed ingestion tool. Why? Because:

1. You need to understand what these tools do before you pay $30K/year for them
2. For 3 sources, custom Python is faster to set up and cheaper to run
3. The patterns you learn here apply to EVERY connector you'll ever build

---

## SUBMODULE 2.1: SOURCE DATABASE SETUP

**Files:** `seed/schema.sql`, `seed/generate_data.py`, `seed/seed_postgres.py`

### What Gets Built

A realistic e-commerce PostgreSQL database with:
- **50,000 customers** — realistic names, emails, addresses (US-based)
- **200 products** — across 10 categories with realistic pricing
- **100,000 orders** — spanning 12 months, with seasonal patterns
- **250,000 order items** — 2.5 items per order average
- **Messy data** — intentional NULLs, inconsistent formatting, edge cases

### Why the Data Is Intentionally Messy

Real source systems are never clean. The seed data includes:
- Customers with NULL phone numbers (30%)
- Addresses with inconsistent state abbreviations ("CA" vs "California")
- Orders with status values that don't match any documentation ("pending_review")
- Products with negative costs (data entry error — the pipeline must handle it)
- Timestamps in different formats (some with timezone, some without)

This forces the ingestion and staging layers to handle real-world problems.

### Schema Definition (schema.sql)

```sql
CREATE TABLE customers (
    customer_id   SERIAL PRIMARY KEY,
    email         VARCHAR(255) NOT NULL UNIQUE,
    first_name    VARCHAR(100),
    last_name     VARCHAR(100),
    phone         VARCHAR(50),         -- 30% NULL
    address       VARCHAR(500),
    city          VARCHAR(100),
    state         VARCHAR(100),        -- Mixed: "CA" and "California"
    country       VARCHAR(100) DEFAULT 'US',
    zip_code      VARCHAR(20),
    created_at    TIMESTAMP DEFAULT NOW(),
    updated_at    TIMESTAMP DEFAULT NOW()
);

CREATE TABLE products (
    product_id    SERIAL PRIMARY KEY,
    name          VARCHAR(255) NOT NULL,
    category      VARCHAR(100),
    subcategory   VARCHAR(100),
    price         NUMERIC(10,2) NOT NULL,
    cost          NUMERIC(10,2),        -- Some NULL, some negative (bugs)
    weight_kg     NUMERIC(8,2),
    is_active     BOOLEAN DEFAULT TRUE,
    created_at    TIMESTAMP DEFAULT NOW(),
    updated_at    TIMESTAMP DEFAULT NOW()
);

CREATE TABLE orders (
    order_id      SERIAL PRIMARY KEY,
    customer_id   INTEGER REFERENCES customers(customer_id),
    order_date    TIMESTAMP NOT NULL,
    status        VARCHAR(50) NOT NULL, -- completed, shipped, cancelled, pending_review
    total_amount  NUMERIC(12,2) NOT NULL,
    shipping_address VARCHAR(500),
    shipping_city VARCHAR(100),
    shipping_state VARCHAR(100),
    shipping_country VARCHAR(100),
    shipping_zip  VARCHAR(20),
    created_at    TIMESTAMP DEFAULT NOW(),
    updated_at    TIMESTAMP DEFAULT NOW()
);

CREATE TABLE order_items (
    order_item_id SERIAL PRIMARY KEY,
    order_id      INTEGER REFERENCES orders(order_id),
    product_id    INTEGER REFERENCES products(product_id),
    quantity      INTEGER NOT NULL,
    unit_price    NUMERIC(10,2) NOT NULL,
    discount_pct  NUMERIC(5,2) DEFAULT 0,
    line_total    NUMERIC(12,2) NOT NULL,
    created_at    TIMESTAMP DEFAULT NOW()
);

-- Index for incremental extraction (query by updated_at)
CREATE INDEX idx_orders_updated ON orders(updated_at);
CREATE INDEX idx_customers_updated ON customers(updated_at);
CREATE INDEX idx_products_updated ON products(updated_at);
```

### Data Generator (generate_data.py)

Uses `Faker` library to generate realistic data:
- Customer names/emails: `Faker('en_US')`
- Order dates: distributed over 12 months with holiday spikes (Black Friday, Christmas)
- Order amounts: normal distribution centered at $65 with std dev of $40
- Product categories: Electronics, Clothing, Home & Garden, Books, Sports, etc.

---

## SUBMODULE 2.2: SNOWFLAKE CLIENT UTILITY

**File:** `utils/snowflake_client.py`

### What Gets Built

A reusable Snowflake connection manager that:
- Loads credentials from environment variables
- Implements Python context manager (`with` statement) for auto-cleanup
- Provides helper methods: `execute_query()`, `execute_file()`, `upload_file()`
- Handles connection pooling for batch operations
- Logs all queries with timing for debugging

### Interface

```python
class SnowflakeClient:
    def __init__(self, warehouse=None, database=None, schema=None):
        """Initialize from .env. Override warehouse/database/schema per use case."""

    def __enter__(self):
        """Open connection."""

    def __exit__(self, exc_type, exc_val, exc_tb):
        """Close connection. Rollback on exception."""

    def execute_query(self, sql, params=None):
        """Execute SQL, return results as list of dicts."""

    def execute_many(self, sql, data):
        """Batch insert using executemany for performance."""

    def upload_to_stage(self, local_path, stage_name):
        """PUT local file to Snowflake internal stage."""

    def copy_into_table(self, table_name, stage_name, file_format=None):
        """COPY INTO from stage to table."""

    def get_max_loaded_at(self, table_name):
        """Get the latest _loaded_at timestamp for incremental logic."""
```

---

## SUBMODULE 2.3: RETRY HANDLER UTILITY

**File:** `utils/retry_handler.py`

### What Gets Built

Exponential backoff utility for handling transient failures:
- API rate limits (Stripe: 429 Too Many Requests)
- Database connection drops (Postgres restarts)
- Network timeouts (Snowflake PUT operations)

### Implementation Pattern

```python
from tenacity import retry, stop_after_attempt, wait_exponential, retry_if_exception_type

def with_retry(max_attempts=3, min_wait=1, max_wait=30):
    """Decorator for retryable operations."""
    return retry(
        stop=stop_after_attempt(max_attempts),
        wait=wait_exponential(multiplier=1, min=min_wait, max=max_wait),
        retry=retry_if_exception_type((ConnectionError, TimeoutError)),
        before_sleep=log_retry_attempt
    )
```

---

## SUBMODULE 2.4: POSTGRES EXTRACTOR

**File:** `postgres_extractor.py`

### What Gets Built

A Python script that extracts data from PostgreSQL and loads into Snowflake's RAW layer.

### Two Modes

| Mode | Flag | When to Use | How It Works |
|------|------|-------------|-------------|
| Full Load | `--full-load` | Initial setup, recovery | Truncate target → Extract all rows → Load |
| Incremental | `--incremental` (default) | Daily runs | Query `MAX(_loaded_at)` from Snowflake → Extract rows with `updated_at > last_loaded` → Append |

### Extraction Flow

```
┌─────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  PostgreSQL  │────▶│  Extract to  │────▶│  PUT to      │────▶│  COPY INTO   │
│  Source      │     │  CSV/Parquet │     │  Snowflake   │     │  RAW Table   │
│  Table       │     │  (local tmp) │     │  Stage       │     │              │
└─────────────┘     └──────────────┘     └──────────────┘     └──────────────┘
```

### Key Implementation Details

1. **Extract to local temp file** (not in-memory): For 100K rows, memory is fine. For 10M rows, you need disk. Build the pattern that scales.
2. **Parquet format** for extraction: 5x smaller than CSV, preserves types, faster to load.
3. **PUT + COPY INTO** pattern: PUT uploads to stage (compressed, parallel). COPY INTO loads from stage to table (parallel, transactional).
4. **_loaded_at tracking**: Every row gets a `CURRENT_TIMESTAMP()` on insert for incremental watermarking.

### CLI Interface

```bash
# Full load all tables
python ingestion/postgres_extractor.py --full-load

# Incremental load (default)
python ingestion/postgres_extractor.py

# Single table
python ingestion/postgres_extractor.py --table orders

# With logging
python ingestion/postgres_extractor.py --log-level DEBUG
```

### Tables Extracted

| Source Table | Target Table | Incremental Column | Est. Daily Rows |
|-------------|-------------|-------------------|-----------------|
| orders | RAW_ORDERS | updated_at | ~1,600 |
| customers | RAW_CUSTOMERS | updated_at | ~200 |
| products | RAW_PRODUCTS | updated_at | ~2 |
| order_items | RAW_ORDER_ITEMS | created_at (append-only) | ~4,000 |

---

## SUBMODULE 2.5: STRIPE CONNECTOR

**File:** `stripe_connector.py`

### What Gets Built

A Python connector that calls the Stripe API, paginates through results, handles rate limits, and loads payment data into Snowflake.

### API Endpoints Used

| Endpoint | Data | Pagination |
|----------|------|-----------|
| `GET /v1/charges` | Payment charges | Cursor-based (starting_after) |
| `GET /v1/refunds` | Refunds | Cursor-based (starting_after) |

### Stripe-Specific Challenges (and Solutions)

| Challenge | Solution |
|-----------|----------|
| Rate limit: 100 requests/sec | Retry handler with backoff. Batch 100 objects per request. |
| Nested JSON (e.g., `charge.payment_method_details.card.brand`) | Store full JSON as VARIANT in Snowflake. Flatten in dbt staging. |
| Timestamps are Unix epoch | Convert to TIMESTAMP_NTZ in Python before loading. |
| Currency amounts are in cents | Store raw (cents) in RAW. Convert to dollars in staging. |
| Pagination has no total count | Loop until `has_more == false`. |

### Data Flow

```
Stripe API
    │
    ▼
GET /v1/charges?limit=100&starting_after={last_id}
    │
    ▼ (loop until has_more == false)
    │
Flatten to records:
    {payment_id, order_id, amount_cents, currency, status, ...}
    │
    ▼
Write to NDJSON temp file
    │
    ▼
PUT to ECOMMERCE_RAW.STRIPE.JSON_STAGE
    │
    ▼
COPY INTO RAW_PAYMENTS (with VARIANT column for _raw_json)
```

### Incremental Strategy

Stripe's `created` parameter filters by creation timestamp. On each run:
1. Query `MAX(created_at)` from `RAW_PAYMENTS` in Snowflake
2. Call Stripe API with `created[gte]={last_timestamp}`
3. This only fetches new payments since the last run

---

## SUBMODULE 2.6: CSV LOADER

**File:** `csv_loader.py`

### What Gets Built

A loader for CSV files exported from Google Sheets (marketing data). Handles:
- File staging with PUT
- COPY INTO with error handling
- Bad data detection and quarantine

### Error Handling Strategy

```sql
-- Load with error tolerance
COPY INTO RAW_MARKETING_SPEND
    FROM @CSV_STAGE/marketing_spend.csv
    ON_ERROR = 'CONTINUE'        -- Don't fail the whole load for 1 bad row
    PURGE = TRUE;                 -- Delete staged file after successful load

-- Check what was rejected
SELECT * FROM TABLE(VALIDATE(RAW_MARKETING_SPEND, JOB_ID => '_last'));
```

### Files Expected

| File | Source | Columns | Frequency |
|------|--------|---------|-----------|
| `marketing_spend.csv` | Google Sheets "Marketing Budget" tab | date, channel, campaign_name, spend, impressions, clicks | Weekly export |
| `campaign_performance.csv` | Google Sheets "Campaign Results" tab | date, campaign_id, campaign_name, channel, conversions, revenue_attributed | Weekly export |

---

## SUBMODULE 2.7: CONFIGURATION

**File:** `config.py`

### What Gets Built

Centralized configuration loaded from environment variables with validation:

```python
@dataclass
class IngestionConfig:
    # Snowflake
    snowflake_account: str
    snowflake_user: str
    snowflake_password: str
    snowflake_role: str = "ECOMMERCE_LOADER"
    snowflake_warehouse: str = "LOADING_WH"
    snowflake_database: str = "ECOMMERCE_RAW"

    # PostgreSQL
    postgres_host: str = "localhost"
    postgres_port: int = 5432
    postgres_db: str = "ecommerce_source"
    postgres_user: str = "postgres"
    postgres_password: str = "postgres"

    # Stripe
    stripe_api_key: str = ""
    stripe_api_base: str = "https://api.stripe.com/v1"

    # Runtime
    batch_size: int = 10000
    temp_dir: str = "/tmp/snowbrix"
    log_level: str = "INFO"
```

---

## FILES IN THIS MODULE

```
ingestion/
├── IMPLEMENTATION_PLAN.md          ← You are here
├── config.py                       ← Centralized configuration
├── postgres_extractor.py           ← Full + incremental Postgres extraction
├── stripe_connector.py             ← Stripe API → Snowflake
├── csv_loader.py                   ← CSV file staging + COPY INTO
│
├── utils/
│   ├── __init__.py
│   ├── snowflake_client.py         ← Reusable Snowflake connection manager
│   └── retry_handler.py            ← Exponential backoff utility
│
└── seed/
    ├── schema.sql                  ← Postgres schema (loaded by Docker)
    ├── generate_data.py            ← Faker-based data generator
    └── seed_postgres.py            ← Orchestrates seeding
```

---

## VERIFICATION CHECKLIST

After running all ingestion scripts:

```sql
-- Verify row counts in Snowflake
SELECT 'RAW_ORDERS' AS TABLE_NAME, COUNT(*) AS ROW_COUNT
    FROM ECOMMERCE_RAW.POSTGRES.RAW_ORDERS
UNION ALL
SELECT 'RAW_CUSTOMERS', COUNT(*) FROM ECOMMERCE_RAW.POSTGRES.RAW_CUSTOMERS
UNION ALL
SELECT 'RAW_PRODUCTS', COUNT(*) FROM ECOMMERCE_RAW.POSTGRES.RAW_PRODUCTS
UNION ALL
SELECT 'RAW_ORDER_ITEMS', COUNT(*) FROM ECOMMERCE_RAW.POSTGRES.RAW_ORDER_ITEMS
UNION ALL
SELECT 'RAW_PAYMENTS', COUNT(*) FROM ECOMMERCE_RAW.STRIPE.RAW_PAYMENTS
UNION ALL
SELECT 'RAW_REFUNDS', COUNT(*) FROM ECOMMERCE_RAW.STRIPE.RAW_REFUNDS
UNION ALL
SELECT 'RAW_MARKETING_SPEND', COUNT(*) FROM ECOMMERCE_RAW.CSV_UPLOADS.RAW_MARKETING_SPEND
UNION ALL
SELECT 'RAW_CAMPAIGN_PERFORMANCE', COUNT(*) FROM ECOMMERCE_RAW.CSV_UPLOADS.RAW_CAMPAIGN_PERFORMANCE;

-- Expected results:
-- RAW_ORDERS:               100,000
-- RAW_CUSTOMERS:             50,000
-- RAW_PRODUCTS:                 200
-- RAW_ORDER_ITEMS:          250,000
-- RAW_PAYMENTS:             100,000
-- RAW_REFUNDS:                5,000
-- RAW_MARKETING_SPEND:          365
-- RAW_CAMPAIGN_PERFORMANCE:   1,200

-- Verify incremental works (run extractor twice, count shouldn't double)
SELECT COUNT(*), MAX(_loaded_at) FROM ECOMMERCE_RAW.POSTGRES.RAW_ORDERS;
```
