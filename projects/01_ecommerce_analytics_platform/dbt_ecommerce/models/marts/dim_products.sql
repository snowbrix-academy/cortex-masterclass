-- ============================================================
-- SNOWBRIX E-COMMERCE PLATFORM
-- Mart Model: dim_products
-- ============================================================
-- Grain: One row per product
-- Materialization: Table (configured in dbt_project.yml)
--
-- Product dimension with category hierarchy, margin calculations,
-- and price-based product classification. This dimension is
-- relatively stable (products change infrequently), so a full
-- table rebuild on each run is efficient and simple.
--
-- MARGIN CALCULATION:
--   margin = price - cost
--   margin_pct = (price - cost) / price * 100
--
-- Products with unknown cost (NULL) have NULL margin values.
-- Products with cost errors (flagged in staging) also have
-- NULL costs, so their margins are unknown.
-- ============================================================

with

products as (

    select * from {{ ref('stg_products') }}

),

final as (

    select
        -- Surrogate key
        {{ dbt_utils.generate_surrogate_key(['product_id']) }} as product_key,

        -- Natural key
        product_id,

        -- Product attributes
        product_name,
        category,
        subcategory,

        -- Category hierarchy: "Electronics > Headphones"
        -- Useful for drill-down reporting and breadcrumb navigation
        case
            when category is not null and subcategory is not null
                then category || ' > ' || subcategory
            when category is not null
                then category
            else 'Uncategorized'
        end                                             as category_hierarchy,

        -- Pricing
        price,
        cost,

        -- Margin calculations (NULL if cost is unknown)
        case
            when cost is not null
                then round(price - cost, 2)
            else null
        end                                             as margin,

        case
            when cost is not null and price > 0
                then round((price - cost) / price * 100, 2)
            else null
        end                                             as margin_pct,

        -- Price tier classification for segmented analysis.
        -- Thresholds based on the product catalog distribution:
        --   Budget:    < $25    (~30% of products)
        --   Mid-range: $25-$99  (~40% of products)
        --   Premium:   $100-$499 (~25% of products)
        --   Luxury:    $500+    (~5% of products)
        case
            when price < 25    then 'budget'
            when price < 100   then 'mid_range'
            when price < 500   then 'premium'
            else 'luxury'
        end                                             as price_tier,

        -- Physical attributes
        weight_kg,

        -- Status flags
        is_active,
        has_cost_error,

        -- Audit timestamps
        created_at                                      as product_created_at,
        updated_at                                      as product_updated_at

    from products

)

select * from final
