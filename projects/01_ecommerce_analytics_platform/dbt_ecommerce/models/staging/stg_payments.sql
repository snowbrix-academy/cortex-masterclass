-- ============================================================
-- SNOWBRIX E-COMMERCE PLATFORM
-- Staging Model: stg_payments
-- ============================================================
-- Source: ECOMMERCE_RAW.STRIPE.RAW_PAYMENTS
-- Grain: One row per payment
-- Materialization: View (configured in dbt_project.yml)
--
-- Transformations applied:
--   1. Convert amount from cents to dollars (Stripe stores cents)
--   2. Map Stripe statuses to internal statuses
--   3. Uppercase currency codes for consistency
--   4. Cast all types explicitly
--   5. Rename columns with payment_ prefix for join clarity
--
-- IMPORTANT: Stripe stores monetary amounts in the smallest
-- currency unit. For USD, 1 dollar = 100 cents. A payment of
-- $68.42 is stored as 6842 in the raw table. We convert here
-- so all downstream models work in dollars.
-- ============================================================

with

source as (

    select * from {{ source('stripe', 'raw_payments') }}

),

renamed as (

    select
        -- Primary key
        cast(payment_id as varchar(255))                as payment_id,

        -- Foreign key to orders (from Stripe metadata)
        -- May be NULL for payments not linked to an order
        cast(order_id as integer)                       as order_id,

        -- Convert amount from cents to dollars.
        -- Stripe stores amounts as integers in the smallest currency unit.
        -- For USD: 6842 cents -> $68.42
        -- We use ROUND to ensure exactly 2 decimal places.
        round(cast(amount as number(12, 2)) / 100, 2)  as payment_amount,

        -- Uppercase currency code for consistency
        -- Stripe returns lowercase ("usd"), we store uppercase ("USD")
        upper(trim(currency))                           as payment_currency,

        -- Map Stripe statuses to internal statuses.
        -- This decouples our analytics from Stripe's naming conventions.
        -- If Stripe changes their status names, we only fix it here.
        case lower(trim(status))
            when 'succeeded' then 'completed'
            when 'pending'   then 'pending'
            when 'failed'    then 'failed'
            -- Catch any new Stripe statuses we haven't mapped yet
            else lower(trim(status))
        end                                             as payment_status,

        -- Payment method type
        trim(payment_method)                            as payment_method,

        -- Stripe charge ID for audit/reconciliation
        trim(stripe_charge_id)                          as stripe_charge_id,

        -- Payment timestamp
        cast(created_at as timestamp_ntz)               as payment_created_at

    from source

)

select * from renamed
