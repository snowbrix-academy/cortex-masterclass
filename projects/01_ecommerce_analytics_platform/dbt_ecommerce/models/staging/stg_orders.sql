-- ============================================================
-- SNOWBRIX E-COMMERCE PLATFORM
-- Staging Model: stg_orders
-- ============================================================
-- Source: ECOMMERCE_RAW.POSTGRES.RAW_ORDERS
-- Grain: One row per order
-- Materialization: View (configured in dbt_project.yml)
--
-- Transformations applied:
--   1. Rename columns to consistent conventions
--   2. Cast types explicitly (defense against upstream changes)
--   3. Filter out test/invalid orders (order_id < 0)
--   4. Add order_status_category grouping column
--   5. Trim whitespace from string fields
--
-- This model is the ONLY place that reads from RAW_ORDERS.
-- All downstream models must use {{ ref('stg_orders') }}.
-- ============================================================

with

source as (

    select * from {{ source('postgres', 'raw_orders') }}

),

-- Filter out test orders. The source system uses negative IDs
-- for internal test transactions that should never appear in analytics.
filtered as (

    select *
    from source
    where order_id > 0

),

-- Rename and cast columns. Every column is explicitly cast to
-- ensure type stability even if the raw table schema changes.
renamed as (

    select
        -- Primary key
        cast(order_id as integer)                       as order_id,

        -- Foreign key
        cast(customer_id as integer)                    as customer_id,

        -- Order attributes
        cast(order_date as timestamp_ntz)               as order_date,
        trim(lower(status))                             as order_status,
        cast(total_amount as number(12, 2))             as order_total,

        -- Shipping address fields (trim whitespace)
        trim(shipping_address)                          as shipping_address,
        trim(shipping_city)                             as shipping_city,
        trim(shipping_state)                            as shipping_state,
        trim(shipping_country)                          as shipping_country,
        trim(shipping_zip)                              as shipping_zip,

        -- Audit timestamps
        cast(created_at as timestamp_ntz)               as created_at,
        cast(updated_at as timestamp_ntz)               as updated_at

    from filtered

),

-- Add a grouped status category for simplified reporting.
-- Raw statuses are granular; this groups them into three buckets
-- that match how the business thinks about order lifecycle.
categorized as (

    select
        *,
        case
            -- Active: order is in progress, not yet finalized
            when order_status in ('pending', 'pending_review', 'shipped')
                then 'active'

            -- Completed: order successfully fulfilled
            when order_status = 'completed'
                then 'completed'

            -- Cancelled: order was cancelled or returned
            when order_status in ('cancelled', 'returned')
                then 'cancelled'

            -- Fallback for any unknown statuses that appear in future data
            else 'active'
        end as order_status_category

    from renamed

)

select * from categorized
