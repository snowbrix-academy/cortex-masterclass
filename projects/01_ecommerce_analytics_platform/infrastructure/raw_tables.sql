-- ============================================================
-- SNOWBRIX E-COMMERCE PLATFORM
-- RAW Layer Table Definitions
-- ============================================================
-- Run after snowflake_setup.sql. Uses ECOMMERCE_RAW database.
-- Every table has _loaded_at for incremental tracking + auditing.
-- ============================================================

USE ROLE SYSADMIN;
USE DATABASE ECOMMERCE_RAW;

-- ============================================================
-- POSTGRES SOURCE TABLES
-- ============================================================

USE SCHEMA POSTGRES;

CREATE TABLE IF NOT EXISTS RAW_ORDERS (
    order_id        INTEGER         NOT NULL,
    customer_id     INTEGER         NOT NULL,
    order_date      TIMESTAMP_NTZ   NOT NULL,
    status          VARCHAR(50)     NOT NULL,
    total_amount    NUMBER(12, 2)   NOT NULL,
    shipping_address VARCHAR(500),
    shipping_city   VARCHAR(100),
    shipping_state  VARCHAR(100),
    shipping_country VARCHAR(100),
    shipping_zip    VARCHAR(20),
    created_at      TIMESTAMP_NTZ   NOT NULL,
    updated_at      TIMESTAMP_NTZ   NOT NULL,
    _loaded_at      TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Raw orders from PostgreSQL. One row per order.';

CREATE TABLE IF NOT EXISTS RAW_CUSTOMERS (
    customer_id     INTEGER         NOT NULL,
    email           VARCHAR(255)    NOT NULL,
    first_name      VARCHAR(100),
    last_name       VARCHAR(100),
    phone           VARCHAR(50),
    address         VARCHAR(500),
    city            VARCHAR(100),
    state           VARCHAR(100),
    country         VARCHAR(100),
    zip_code        VARCHAR(20),
    created_at      TIMESTAMP_NTZ   NOT NULL,
    updated_at      TIMESTAMP_NTZ   NOT NULL,
    _loaded_at      TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Raw customers from PostgreSQL. One row per customer.';

CREATE TABLE IF NOT EXISTS RAW_PRODUCTS (
    product_id      INTEGER         NOT NULL,
    name            VARCHAR(255)    NOT NULL,
    category        VARCHAR(100),
    subcategory     VARCHAR(100),
    price           NUMBER(10, 2)   NOT NULL,
    cost            NUMBER(10, 2),
    weight_kg       NUMBER(8, 2),
    is_active       BOOLEAN         DEFAULT TRUE,
    created_at      TIMESTAMP_NTZ   NOT NULL,
    updated_at      TIMESTAMP_NTZ   NOT NULL,
    _loaded_at      TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Raw products from PostgreSQL. One row per product.';

CREATE TABLE IF NOT EXISTS RAW_ORDER_ITEMS (
    order_item_id   INTEGER         NOT NULL,
    order_id        INTEGER         NOT NULL,
    product_id      INTEGER         NOT NULL,
    quantity        INTEGER         NOT NULL,
    unit_price      NUMBER(10, 2)   NOT NULL,
    discount_pct    NUMBER(5, 2)    DEFAULT 0,
    line_total      NUMBER(12, 2)   NOT NULL,
    _loaded_at      TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Raw order line items from PostgreSQL. One row per item in an order.';


-- ============================================================
-- STRIPE SOURCE TABLES
-- ============================================================

USE SCHEMA STRIPE;

CREATE TABLE IF NOT EXISTS RAW_PAYMENTS (
    payment_id      VARCHAR(255)    NOT NULL,
    order_id        INTEGER,
    amount          NUMBER(12, 2)   NOT NULL,
    currency        VARCHAR(10)     NOT NULL,
    status          VARCHAR(50)     NOT NULL,
    payment_method  VARCHAR(50),
    stripe_charge_id VARCHAR(255),
    created_at      TIMESTAMP_NTZ   NOT NULL,
    _raw_json       VARIANT,
    _loaded_at      TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Raw payments from Stripe API. _raw_json stores full API response.';

CREATE TABLE IF NOT EXISTS RAW_REFUNDS (
    refund_id       VARCHAR(255)    NOT NULL,
    payment_id      VARCHAR(255)    NOT NULL,
    amount          NUMBER(12, 2)   NOT NULL,
    reason          VARCHAR(255),
    status          VARCHAR(50)     NOT NULL,
    created_at      TIMESTAMP_NTZ   NOT NULL,
    _raw_json       VARIANT,
    _loaded_at      TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Raw refunds from Stripe API. Linked to payments via payment_id.';


-- ============================================================
-- CSV UPLOAD TABLES
-- ============================================================

USE SCHEMA CSV_UPLOADS;

CREATE TABLE IF NOT EXISTS RAW_MARKETING_SPEND (
    date            DATE            NOT NULL,
    channel         VARCHAR(100)    NOT NULL,
    campaign_name   VARCHAR(255),
    spend           NUMBER(12, 2)   NOT NULL,
    impressions     INTEGER,
    clicks          INTEGER,
    _loaded_at      TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Marketing spend from Google Sheets CSV export. Daily by channel.';

CREATE TABLE IF NOT EXISTS RAW_CAMPAIGN_PERFORMANCE (
    date            DATE            NOT NULL,
    campaign_id     VARCHAR(100)    NOT NULL,
    campaign_name   VARCHAR(255),
    channel         VARCHAR(100),
    conversions     INTEGER,
    revenue_attributed NUMBER(12, 2),
    _loaded_at      TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Campaign performance metrics from Google Sheets. Daily by campaign.';


-- ============================================================
-- VERIFICATION
-- ============================================================

SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, ROW_COUNT
FROM ECOMMERCE_RAW.INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA != 'INFORMATION_SCHEMA'
ORDER BY TABLE_SCHEMA, TABLE_NAME;
