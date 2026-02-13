-- ============================================================
-- KPI Cards: Summary metrics for the dashboard header
-- ============================================================
-- Returns a single row with 8 values:
-- current period metrics + prior period metrics for comparison
-- ============================================================

WITH current_period AS (
    SELECT
        SUM(revenue) AS total_revenue,
        SUM(total_orders) AS total_orders,
        ROUND(AVG(avg_order_value), 2) AS avg_order_value,
        SUM(new_customers) AS new_customers
    FROM ECOMMERCE_ANALYTICS.MARTS.FCT_DAILY_REVENUE
    WHERE date >= DATEADD('day', -30, CURRENT_DATE())
      AND date < CURRENT_DATE()
),

prior_period AS (
    SELECT
        SUM(revenue) AS total_revenue,
        SUM(total_orders) AS total_orders,
        ROUND(AVG(avg_order_value), 2) AS avg_order_value,
        SUM(new_customers) AS new_customers
    FROM ECOMMERCE_ANALYTICS.MARTS.FCT_DAILY_REVENUE
    WHERE date >= DATEADD('day', -60, CURRENT_DATE())
      AND date < DATEADD('day', -30, CURRENT_DATE())
)

SELECT
    c.total_revenue,
    c.total_orders,
    c.avg_order_value,
    c.new_customers,
    p.total_revenue AS prior_revenue,
    p.total_orders AS prior_orders,
    p.avg_order_value AS prior_aov,
    p.new_customers AS prior_new_customers,
    -- Percentage changes
    ROUND((c.total_revenue - p.total_revenue) / NULLIF(p.total_revenue, 0) * 100, 1) AS revenue_change_pct,
    ROUND((c.total_orders - p.total_orders) / NULLIF(p.total_orders, 0) * 100, 1) AS orders_change_pct,
    ROUND((c.avg_order_value - p.avg_order_value) / NULLIF(p.avg_order_value, 0) * 100, 1) AS aov_change_pct,
    ROUND((c.new_customers - p.new_customers) / NULLIF(p.new_customers, 0) * 100, 1) AS customers_change_pct
FROM current_period c
CROSS JOIN prior_period p;
