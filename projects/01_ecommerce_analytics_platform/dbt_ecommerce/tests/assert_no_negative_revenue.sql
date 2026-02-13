-- ============================================================
-- SNOWBRIX E-COMMERCE PLATFORM
-- Custom Test: assert_no_negative_revenue
-- ============================================================
-- This test validates that no order in fct_orders has negative
-- net revenue. Negative revenue would indicate a data quality
-- issue upstream (e.g., a product with a negative price that
-- wasn't properly filtered, or a discount exceeding the total).
--
-- HOW dbt TESTS WORK:
-- A test query must return ZERO rows to pass.
-- Any rows returned are considered test failures.
-- dbt will report the number of failing rows and fail the run.
--
-- BUSINESS RULE:
-- Revenue can be $0 (free order, 100% discount) but should
-- never be negative. If this test fails, investigate:
--   1. Check stg_products for unflagged negative prices
--   2. Check raw_order_items for discount_pct > 100
--   3. Check the order in the source system
-- ============================================================

-- Return all orders with negative net revenue.
-- An empty result set means the test passes.
select
    order_id,
    customer_id,
    order_date,
    net_revenue,
    gross_revenue,
    discount_total,
    order_status

from {{ ref('fct_orders') }}

-- Net revenue should never be negative
where net_revenue < 0
