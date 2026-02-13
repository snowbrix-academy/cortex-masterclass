-- ============================================================
-- SNOWBRIX E-COMMERCE PLATFORM
-- Mart Model: fct_daily_revenue
-- ============================================================
-- Grain: One row per day
-- Materialization: Table (full rebuild each run)
--
-- Pre-aggregated daily revenue metrics for dashboard performance.
-- Instead of querying fct_orders (100K+ rows) and aggregating
-- at query time, dashboards query this table (365 rows per year)
-- for instant results.
--
-- WHY NOT INCREMENTAL?
-- This model depends on fct_orders. When a historical order is
-- updated (status change, payment update), the daily aggregate
-- for that date changes. An incremental approach would miss
-- these retroactive changes. Since the output is small (one row
-- per day), a full rebuild is fast and guarantees accuracy.
--
-- METRICS INCLUDED:
--   - Total orders and completed orders
--   - Revenue (gross, net, discounts)
--   - Average order value
--   - New vs. returning customer counts
-- ============================================================

with

orders as (

    select * from {{ ref('fct_orders') }}

),

-- Identify each customer's first order date.
-- This is used to classify orders as "new customer" or "returning".
customer_first_order as (

    select
        customer_id,
        min(cast(order_date as date))                   as first_order_date
    from orders
    group by customer_id

),

-- Tag each order as new-customer or returning-customer.
orders_tagged as (

    select
        o.*,
        cast(o.order_date as date)                      as order_date_day,
        case
            when cast(o.order_date as date) = cfo.first_order_date
                then true
            else false
        end                                             as is_first_order
    from orders o
    left join customer_first_order cfo
        on o.customer_id = cfo.customer_id

),

-- Aggregate to daily grain.
daily_metrics as (

    select
        order_date_day                                  as date_day,

        -- Foreign key to dim_dates
        cast(to_char(order_date_day, 'YYYYMMDD') as integer) as date_key,

        -- Order counts
        count(distinct order_id)                        as total_orders,

        count(distinct
            case when order_status_category != 'cancelled'
                then order_id
            end
        )                                               as completed_orders,

        -- Revenue metrics (non-cancelled orders only)
        coalesce(sum(
            case when order_status_category != 'cancelled'
                then net_revenue
                else 0
            end
        ), 0)                                           as total_revenue,

        coalesce(sum(
            case when order_status_category != 'cancelled'
                then gross_revenue
                else 0
            end
        ), 0)                                           as total_gross_revenue,

        coalesce(sum(
            case when order_status_category != 'cancelled'
                then discount_total
                else 0
            end
        ), 0)                                           as total_discounts,

        -- Average order value
        case
            when count(distinct
                case when order_status_category != 'cancelled'
                    then order_id
                end
            ) > 0
            then round(
                sum(
                    case when order_status_category != 'cancelled'
                        then net_revenue
                        else 0
                    end
                ) / count(distinct
                    case when order_status_category != 'cancelled'
                        then order_id
                    end
                ), 2
            )
            else 0
        end                                             as avg_order_value,

        -- Items sold
        coalesce(sum(
            case when order_status_category != 'cancelled'
                then total_quantity
                else 0
            end
        ), 0)                                           as total_items_sold,

        -- Customer composition
        count(distinct
            case when is_first_order = true
                then customer_id
            end
        )                                               as new_customers,

        count(distinct
            case when is_first_order = false
                then customer_id
            end
        )                                               as returning_customers,

        count(distinct customer_id)                     as total_customers

    from orders_tagged
    group by order_date_day

)

select * from daily_metrics
order by date_day
