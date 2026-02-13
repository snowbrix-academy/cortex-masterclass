-- ============================================================
-- Product Performance: Top products and category breakdown
-- ============================================================

-- Query 1: Top 10 Products by Revenue (last 90 days)
SELECT
    p.product_name,
    p.category,
    COUNT(DISTINCT o.order_id) AS order_count,
    SUM(o.order_total) AS total_revenue,
    ROUND(AVG(o.order_total), 2) AS avg_order_value
FROM ECOMMERCE_ANALYTICS.MARTS.FCT_ORDERS o
JOIN ECOMMERCE_ANALYTICS.MARTS.DIM_PRODUCTS p
    ON o.product_id = p.product_id
WHERE o.order_date >= DATEADD('day', -90, CURRENT_DATE())
GROUP BY p.product_name, p.category
ORDER BY total_revenue DESC
LIMIT 10;
