-- ============================================================
-- SNOWBRIX E-COMMERCE PLATFORM
-- Staging Model: stg_products
-- ============================================================
-- Source: ECOMMERCE_RAW.POSTGRES.RAW_PRODUCTS
-- Grain: One row per product
-- Materialization: View (configured in dbt_project.yml)
--
-- Transformations applied:
--   1. Normalize category and subcategory to title case
--   2. Flag products with negative cost (data entry errors)
--   3. Set negative costs to NULL (preserve flag for tracking)
--   4. Default NULL weight to 0 kg
--   5. Trim whitespace from all string fields
--
-- DATA QUALITY NOTE:
-- Some products in the source system have negative cost values.
-- This is a known data entry error (someone typed -5.99 instead
-- of 5.99). We flag these with has_cost_error = true and set
-- their cost to NULL. The flag enables the data team to track
-- how many products have this issue and work with the source
-- system team to fix it.
-- ============================================================

with

source as (

    select * from {{ source('postgres', 'raw_products') }}

),

renamed as (

    select
        -- Primary key
        cast(product_id as integer)                     as product_id,

        -- Product attributes
        trim(name)                                      as product_name,

        -- Normalize category to title case (e.g., "ELECTRONICS" -> "Electronics")
        -- INITCAP handles this in Snowflake
        initcap(trim(category))                         as category,
        initcap(trim(subcategory))                      as subcategory,

        -- Price should always be positive
        cast(price as number(10, 2))                    as price,

        -- Handle negative cost: set to NULL but preserve the error flag
        case
            when cost < 0 then null
            else cast(cost as number(10, 2))
        end                                             as cost,

        -- Default NULL weight to 0 kg
        coalesce(cast(weight_kg as number(8, 2)), 0)    as weight_kg,

        -- Active flag
        coalesce(is_active, true)                       as is_active,

        -- Data quality flag: true if the source cost was negative
        case
            when cost < 0 then true
            else false
        end                                             as has_cost_error,

        -- Audit timestamps
        cast(created_at as timestamp_ntz)               as created_at,
        cast(updated_at as timestamp_ntz)               as updated_at

    from source

)

select * from renamed
