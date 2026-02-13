-- ============================================================
-- SNOWBRIX E-COMMERCE PLATFORM
-- Intermediate Model: int_customer_lifetime
-- ============================================================
-- Grain: One row per customer
-- Materialization: Table (configured in dbt_project.yml)
--
-- This model calculates per-customer lifetime metrics by
-- combining customer profile data with their order history.
-- It serves as the primary input for dim_customers, which
-- adds tier classification and SCD tracking on top.
--
-- Metrics calculated:
--   - Lifetime value (total net revenue from non-cancelled orders)
--   - First and last order dates
--   - Total order count
--   - Total items purchased
--   - Average order value
--   - Days since last order (recency)
--   - Average days between orders (frequency)
--   - Repeat customer flag
--
-- Customers with ZERO orders are still included (with NULLs
-- for order metrics). This is intentional — they represent
-- registered users who haven't purchased yet, which is
-- valuable for marketing analysis.
-- ============================================================

with

customers as (

    select * from {{ ref('stg_customers') }}

),

orders_enriched as (

    select * from {{ ref('int_order_items_enriched') }}

),

-- Aggregate order-level data per customer.
-- Exclude cancelled orders from lifetime value calculations,
-- but still count them in total_orders for completeness.
customer_orders as (

    select
        customer_id,

        -- Order counts
        count(distinct order_id)                        as total_orders,

        -- Only count non-cancelled orders for revenue metrics
        count(distinct
            case when order_status_category != 'cancelled'
                then order_id
            end
        )                                               as completed_orders,

        -- Total items across all non-cancelled orders
        sum(
            case when order_status_category != 'cancelled'
                then total_quantity
                else 0
            end
        )                                               as total_items_purchased,

        -- Lifetime value = total net revenue from non-cancelled orders
        sum(
            case when order_status_category != 'cancelled'
                then net_revenue
                else 0
            end
        )                                               as lifetime_value,

        -- Date metrics
        min(order_date)                                 as first_order_date,
        max(order_date)                                 as last_order_date,

        -- Average order value (non-cancelled only)
        case
            when count(distinct
                case when order_status_category != 'cancelled'
                    then order_id
                end
            ) > 0
            then sum(
                case when order_status_category != 'cancelled'
                    then net_revenue
                    else 0
                end
            ) / count(distinct
                case when order_status_category != 'cancelled'
                    then order_id
                end
            )
            else 0
        end                                             as avg_order_value

    from orders_enriched
    group by customer_id

),

-- Calculate recency and frequency metrics.
-- These require date arithmetic that's cleaner in a separate CTE.
customer_metrics as (

    select
        customer_id,
        total_orders,
        completed_orders,
        total_items_purchased,
        lifetime_value,
        first_order_date,
        last_order_date,
        avg_order_value,

        -- Recency: days since last order
        datediff(
            'day',
            last_order_date,
            current_date()
        )                                               as days_since_last_order,

        -- Frequency: average days between orders
        -- Only meaningful if customer has 2+ orders
        case
            when total_orders >= 2
            then datediff(
                'day',
                first_order_date,
                last_order_date
            ) / nullif(total_orders - 1, 0)
            else null
        end                                             as order_frequency_days,

        -- Repeat customer flag
        case
            when total_orders > 1 then true
            else false
        end                                             as is_repeat_customer

    from customer_orders

),

-- Join customer profile with their lifetime metrics.
-- LEFT JOIN ensures customers with zero orders are included.
final as (

    select
        -- Customer profile
        c.customer_id,
        c.email,
        c.first_name,
        c.last_name,
        c.full_name,
        c.phone,
        c.state,
        c.country,
        c.created_at                                    as customer_created_at,

        -- Lifetime metrics (NULL for customers with no orders)
        m.first_order_date,
        m.last_order_date,
        coalesce(m.total_orders, 0)                     as total_orders,
        coalesce(m.total_items_purchased, 0)            as total_items_purchased,
        coalesce(m.lifetime_value, 0)                   as lifetime_value,
        coalesce(m.avg_order_value, 0)                  as avg_order_value,
        m.days_since_last_order,
        m.order_frequency_days,
        coalesce(m.is_repeat_customer, false)           as is_repeat_customer

    from customers c

    left join customer_metrics m
        on c.customer_id = m.customer_id

)

select * from final
