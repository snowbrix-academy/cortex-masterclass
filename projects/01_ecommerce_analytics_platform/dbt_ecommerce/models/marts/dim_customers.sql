-- ============================================================
-- SNOWBRIX E-COMMERCE PLATFORM
-- Mart Model: dim_customers
-- ============================================================
-- Grain: One row per customer (with SCD Type 2 support)
-- Materialization: Table (configured in dbt_project.yml)
--
-- This is the customer dimension for the star schema. It
-- combines customer profile data with lifetime metrics and
-- assigns a tier classification based on lifetime value.
--
-- TYPE 2 SCD PATTERN (SIMPLIFIED):
-- ----------------------------------
-- A full Type 2 SCD implementation uses dbt snapshots to
-- track changes over time. This simplified version:
--   1. Calculates the current tier for every customer
--   2. Generates a surrogate key from customer_id + valid_from
--   3. Sets valid_from = customer_created_at for the initial row
--   4. Sets valid_to = NULL and is_current = true
--
-- In production, you would pair this with a dbt snapshot
-- (in the snapshots/ directory) that tracks tier changes:
--
--   {% snapshot snp_dim_customers %}
--   {{ config(
--       strategy='check',
--       check_cols=['customer_tier'],
--       unique_key='customer_id'
--   ) }}
--   SELECT * FROM {{ ref('dim_customers') }} WHERE is_current = true
--   {% endsnapshot %}
--
-- The snapshot would create new rows when customer_tier changes,
-- closing the old row with a valid_to date.
--
-- TIER THRESHOLDS:
--   Platinum: LTV >= $1,000  (top spenders, ~5% of customers)
--   Gold:     LTV >= $500    (loyal customers, ~15%)
--   Silver:   LTV >= $100    (regular customers, ~30%)
--   Bronze:   LTV < $100     (new or infrequent, ~50%)
-- ============================================================

with

customer_lifetime as (

    select * from {{ ref('int_customer_lifetime') }}

),

-- Assign customer tier based on lifetime value thresholds.
-- These thresholds should be reviewed quarterly with the
-- business team and adjusted as the customer base matures.
tiered as (

    select
        *,

        -- Customer tier based on LTV
        case
            when lifetime_value >= 1000 then 'platinum'
            when lifetime_value >= 500  then 'gold'
            when lifetime_value >= 100  then 'silver'
            else 'bronze'
        end as customer_tier

    from customer_lifetime

),

-- Build the final dimension with surrogate key and SCD metadata.
final as (

    select
        -- Surrogate key: hash of natural key + validity start.
        -- This ensures uniqueness even when SCD creates multiple
        -- rows per customer (each with a different valid_from).
        {{ dbt_utils.generate_surrogate_key([
            'customer_id',
            'customer_created_at'
        ]) }}                                           as customer_key,

        -- Natural key
        customer_id,

        -- Customer attributes
        email,
        first_name,
        last_name,
        full_name,
        phone,
        state,
        country,

        -- Tier classification
        customer_tier,

        -- Lifetime metrics
        lifetime_value,
        total_orders,
        avg_order_value,
        first_order_date,
        last_order_date,
        days_since_last_order,
        order_frequency_days,
        is_repeat_customer,
        total_items_purchased,

        -- SCD Type 2 metadata
        -- For the simplified implementation, valid_from is set to
        -- the customer creation date. A full snapshot-based SCD
        -- would track the date each tier change occurred.
        customer_created_at                             as valid_from,
        cast(null as timestamp_ntz)                     as valid_to,
        true                                            as is_current

    from tiered

)

select * from final
