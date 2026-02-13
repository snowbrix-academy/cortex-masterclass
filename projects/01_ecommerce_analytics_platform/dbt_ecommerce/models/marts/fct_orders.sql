-- ============================================================
-- SNOWBRIX E-COMMERCE PLATFORM
-- Mart Model: fct_orders
-- ============================================================
-- Grain: One row per order
-- Materialization: Incremental (merge strategy)
-- Unique key: order_id
--
-- This is the primary order fact table in the star schema.
-- It contains foreign keys to all dimension tables and
-- additive measures suitable for aggregation.
--
-- INCREMENTAL LOGIC:
-- On the first run, the full table is created from all data.
-- On subsequent runs, only orders with an order_date after the
-- maximum order_date already in the table are processed. The
-- MERGE strategy (via unique_key) handles both new orders
-- (INSERT) and updated orders (UPDATE) atomically.
--
-- To force a full rebuild: dbt run --full-refresh -s fct_orders
--
-- DIMENSION FOREIGN KEYS:
--   customer_key -> dim_customers (surrogate key)
--   product_key  -> dim_products (first product, simplified)
--   order_date_key -> dim_dates (integer YYYYMMDD)
-- ============================================================

{{
    config(
        materialized='incremental',
        unique_key='order_id',
        incremental_strategy='merge',
        on_schema_change='append_new_columns'
    )
}}

with

order_enriched as (

    select * from {{ ref('int_order_items_enriched') }}

),

dim_customers as (

    select
        customer_key,
        customer_id
    from {{ ref('dim_customers') }}
    where is_current = true

),

dim_dates as (

    select
        date_key,
        date_day
    from {{ ref('dim_dates') }}

),

-- For simplified star schema, we identify a "primary product"
-- per order. In a more detailed model, you'd have a separate
-- fct_order_items at the line-item grain. Here we pick the
-- first product (by order_item_id) as the representative product.
order_primary_product as (

    select
        order_id,
        product_id,
        row_number() over (
            partition by order_id
            order by order_item_id
        ) as item_rank
    from (
        select
            cast(order_item_id as integer) as order_item_id,
            cast(order_id as integer)      as order_id,
            cast(product_id as integer)    as product_id
        from {{ source('postgres', 'raw_order_items') }}
    )

),

primary_product as (

    select
        order_id,
        product_id
    from order_primary_product
    where item_rank = 1

),

dim_products as (

    select
        product_key,
        product_id
    from {{ ref('dim_products') }}

),

-- Build the fact table with all foreign keys and measures.
final as (

    select
        -- Degenerate dimension (order-level natural key)
        o.order_id,

        -- Foreign keys to dimensions
        dc.customer_key,
        dp.product_key,
        dd.date_key                                     as order_date_key,

        -- Natural keys (for convenience in ad-hoc queries)
        o.customer_id,
        o.order_date,

        -- Order attributes
        o.order_status,
        o.order_status_category,

        -- Additive measures
        o.item_count,
        o.total_quantity,
        o.order_total,
        o.gross_revenue,
        o.discount_amount                               as discount_total,
        o.net_revenue,
        o.payment_amount,

        -- Payment attributes (useful for filtering)
        o.payment_status,
        o.payment_method,

        -- Shipping attributes
        o.shipping_city,
        o.shipping_state,
        o.shipping_country,

        -- Audit timestamps
        o.order_created_at,
        o.order_updated_at,
        current_timestamp()                             as dbt_loaded_at

    from order_enriched o

    -- Join to customer dimension (current row only)
    left join dim_customers dc
        on o.customer_id = dc.customer_id

    -- Join to date dimension
    left join dim_dates dd
        on cast(o.order_date as date) = dd.date_day

    -- Join to product dimension via primary product
    left join primary_product pp
        on o.order_id = pp.order_id

    left join dim_products dp
        on pp.product_id = dp.product_id

    -- INCREMENTAL FILTER:
    -- On subsequent runs, only process orders newer than what we have.
    -- On the first run (is_incremental() = false), process everything.
    {% if is_incremental() %}
    where o.order_date > (
        select max(order_date)
        from {{ this }}
    )
    {% endif %}

)

select * from final
