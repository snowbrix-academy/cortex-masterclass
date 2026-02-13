-- ============================================================
-- SNOWBRIX E-COMMERCE PLATFORM
-- Intermediate Model: int_order_items_enriched
-- ============================================================
-- Grain: One row per order
-- Materialization: Table (configured in dbt_project.yml)
--
-- This model is the central order enrichment hub. It joins:
--   - stg_orders: order header (date, status, customer)
--   - raw_order_items: line item details (quantity, price, discount)
--   - stg_products: product info (name, category)
--   - stg_payments: payment info (amount, status, method)
--
-- Line items are aggregated to the order level so the output
-- is one row per order with summarized item metrics.
--
-- NOTE: We reference raw_order_items directly from the source
-- because there is no stg_order_items model (order_items needs
-- minimal cleaning — it's append-only with clean data types).
-- In a larger project, you'd create stg_order_items too.
-- ============================================================

with

orders as (

    select * from {{ ref('stg_orders') }}

),

-- Read order items directly from the raw source.
-- This table is append-only with clean types, so minimal staging needed.
order_items as (

    select
        cast(order_item_id as integer)          as order_item_id,
        cast(order_id as integer)               as order_id,
        cast(product_id as integer)             as product_id,
        cast(quantity as integer)               as quantity,
        cast(unit_price as number(10, 2))       as unit_price,
        coalesce(cast(discount_pct as number(5, 2)), 0) as discount_pct,
        cast(line_total as number(12, 2))       as line_total
    from {{ source('postgres', 'raw_order_items') }}

),

payments as (

    select * from {{ ref('stg_payments') }}

),

-- Aggregate line items to the order level.
-- We sum quantities, count items, and calculate revenue metrics.
order_item_summary as (

    select
        order_id,

        -- Item counts
        count(distinct order_item_id)                       as item_count,
        sum(quantity)                                        as total_quantity,

        -- Revenue metrics
        sum(line_total)                                     as gross_revenue,

        -- Calculate discount amount from the line-level data:
        -- discount_amount = sum(quantity * unit_price * discount_pct / 100)
        sum(
            quantity * unit_price * discount_pct / 100
        )                                                   as discount_amount,

        -- Net revenue = gross minus discounts
        sum(line_total) - sum(
            quantity * unit_price * discount_pct / 100
        )                                                   as net_revenue

    from order_items
    group by order_id

),

-- Get the primary payment for each order.
-- Some orders may have multiple payment attempts (failed then succeeded).
-- We take the most recent successful payment, or the most recent overall.
primary_payments as (

    select
        order_id,
        payment_amount,
        payment_status,
        payment_method,
        payment_created_at,
        row_number() over (
            partition by order_id
            order by
                -- Prefer completed payments over pending/failed
                case payment_status
                    when 'completed' then 1
                    when 'pending'   then 2
                    when 'failed'    then 3
                    else 4
                end,
                -- Among same-status payments, take the most recent
                payment_created_at desc
        ) as payment_rank
    from payments
    where order_id is not null

),

best_payment as (

    select * from primary_payments where payment_rank = 1

),

-- Final join: orders + aggregated items + best payment
enriched as (

    select
        -- Order header
        o.order_id,
        o.customer_id,
        o.order_date,
        o.order_status,
        o.order_status_category,
        o.order_total,
        o.shipping_city,
        o.shipping_state,
        o.shipping_country,
        o.shipping_zip,

        -- Aggregated item metrics
        coalesce(oi.item_count, 0)                  as item_count,
        coalesce(oi.total_quantity, 0)               as total_quantity,
        coalesce(oi.gross_revenue, 0)                as gross_revenue,
        coalesce(oi.discount_amount, 0)              as discount_amount,
        coalesce(oi.net_revenue, 0)                  as net_revenue,

        -- Payment info (may be NULL if no payment exists)
        p.payment_amount,
        p.payment_status,
        p.payment_method,
        p.payment_created_at,

        -- Audit
        o.created_at                                as order_created_at,
        o.updated_at                                as order_updated_at

    from orders o

    left join order_item_summary oi
        on o.order_id = oi.order_id

    left join best_payment p
        on o.order_id = p.order_id

)

select * from enriched
