-- ============================================================
-- Revenue Time Series: Daily revenue for the selected period
-- ============================================================
-- Used by the main revenue line chart.
-- Parameters: :start_date, :end_date (passed from date picker)
-- ============================================================

SELECT
    date,
    revenue,
    total_orders,
    avg_order_value,
    new_customers,
    -- 7-day rolling average for trend smoothing
    ROUND(AVG(revenue) OVER (
        ORDER BY date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ), 2) AS revenue_7d_avg,
    -- Cumulative revenue for the period
    SUM(revenue) OVER (
        ORDER BY date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_revenue
FROM ECOMMERCE_ANALYTICS.MARTS.FCT_DAILY_REVENUE
WHERE date >= %(start_date)s
  AND date <= %(end_date)s
ORDER BY date;
