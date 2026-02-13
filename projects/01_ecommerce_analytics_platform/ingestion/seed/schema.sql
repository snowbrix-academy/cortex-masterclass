-- ============================================================
-- SNOWBRIX E-COMMERCE PLATFORM
-- Source PostgreSQL Schema
-- ============================================================
-- This file is auto-loaded by Docker on first startup.
-- Mounted as /docker-entrypoint-initdb.d/01_schema.sql
-- ============================================================

-- Customers: 50,000 rows
CREATE TABLE IF NOT EXISTS customers (
    customer_id   SERIAL PRIMARY KEY,
    email         VARCHAR(255) NOT NULL UNIQUE,
    first_name    VARCHAR(100),
    last_name     VARCHAR(100),
    phone         VARCHAR(50),
    address       VARCHAR(500),
    city          VARCHAR(100),
    state         VARCHAR(100),
    country       VARCHAR(100) DEFAULT 'US',
    zip_code      VARCHAR(20),
    created_at    TIMESTAMP DEFAULT NOW(),
    updated_at    TIMESTAMP DEFAULT NOW()
);

-- Products: 200 rows
CREATE TABLE IF NOT EXISTS products (
    product_id    SERIAL PRIMARY KEY,
    name          VARCHAR(255) NOT NULL,
    category      VARCHAR(100),
    subcategory   VARCHAR(100),
    price         NUMERIC(10,2) NOT NULL,
    cost          NUMERIC(10,2),
    weight_kg     NUMERIC(8,2),
    is_active     BOOLEAN DEFAULT TRUE,
    created_at    TIMESTAMP DEFAULT NOW(),
    updated_at    TIMESTAMP DEFAULT NOW()
);

-- Orders: 100,000 rows
CREATE TABLE IF NOT EXISTS orders (
    order_id      SERIAL PRIMARY KEY,
    customer_id   INTEGER REFERENCES customers(customer_id),
    order_date    TIMESTAMP NOT NULL,
    status        VARCHAR(50) NOT NULL,
    total_amount  NUMERIC(12,2) NOT NULL,
    shipping_address VARCHAR(500),
    shipping_city VARCHAR(100),
    shipping_state VARCHAR(100),
    shipping_country VARCHAR(100) DEFAULT 'US',
    shipping_zip  VARCHAR(20),
    created_at    TIMESTAMP DEFAULT NOW(),
    updated_at    TIMESTAMP DEFAULT NOW()
);

-- Order Items: 250,000 rows
CREATE TABLE IF NOT EXISTS order_items (
    order_item_id SERIAL PRIMARY KEY,
    order_id      INTEGER REFERENCES orders(order_id),
    product_id    INTEGER REFERENCES products(product_id),
    quantity      INTEGER NOT NULL CHECK (quantity > 0),
    unit_price    NUMERIC(10,2) NOT NULL,
    discount_pct  NUMERIC(5,2) DEFAULT 0,
    line_total    NUMERIC(12,2) NOT NULL,
    created_at    TIMESTAMP DEFAULT NOW()
);

-- Indexes for incremental extraction
CREATE INDEX IF NOT EXISTS idx_orders_updated ON orders(updated_at);
CREATE INDEX IF NOT EXISTS idx_customers_updated ON customers(updated_at);
CREATE INDEX IF NOT EXISTS idx_products_updated ON products(updated_at);
CREATE INDEX IF NOT EXISTS idx_order_items_created ON order_items(created_at);
CREATE INDEX IF NOT EXISTS idx_orders_customer ON orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_order_items_order ON order_items(order_id);
