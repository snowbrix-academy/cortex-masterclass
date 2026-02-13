-- ============================================================
-- Customer Analytics: LTV distribution and top customers
-- ============================================================

-- Query 1: LTV Distribution (for histogram)
SELECT
    customer_id,
    lifetime_revenue,
    total_orders,
    first_order_date,
    last_order_date,
    avg_order_value,
    customer_tier
FROM ECOMMERCE_ANALYTICS.MARTS.DIM_CUSTOMERS
WHERE lifetime_revenue > 0
ORDER BY lifetime_revenue DESC;
