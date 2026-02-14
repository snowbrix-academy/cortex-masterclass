/*
==================================================================
  DEMO AI SUMMIT — SALES FACT
  Script: 03_sales_fact.sql
  Purpose: 500K transactional rows with planted patterns
  Dependencies: 02_dimensions.sql

  PLANTED PATTERNS:
  - Q3 2025 EMEA revenue drops 17% vs Q2 (campaign pause + churn)
  - Q3 2025 NA has mild seasonal dip (5%, normal range)
  - Q3 2025 APAC exceeds target by 6%
  - Electronics return rate: ~14.2%
  - Clear top-performing reps for "above $50K" query
==================================================================
*/

USE ROLE DEMO_AI_ROLE;
USE WAREHOUSE DEMO_AI_WH;
USE DATABASE DEMO_AI_SUMMIT;
USE SCHEMA CORTEX_ANALYST_DEMO;

CREATE OR REPLACE TABLE SALES_FACT AS
WITH date_spine AS (
    SELECT date_key
    FROM DIM_DATE
    WHERE date_key BETWEEN '2024-01-01' AND '2025-12-31'
),
-- Pre-compute all random values in a CTE so correlated
-- values (like region_bucket across CASE branches) are stable
base_random AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY d.date_key, seq4()) AS order_id,
        d.date_key AS order_date,
        -- Region assignment: single bucket evaluated once
        UNIFORM(1, 100, RANDOM()) AS region_bucket,
        UNIFORM(1, 2, RANDOM()) AS na_region,
        UNIFORM(3, 6, RANDOM()) AS emea_region,
        UNIFORM(7, 9, RANDOM()) AS apac_region,
        UNIFORM(10, 12, RANDOM()) AS latam_region,
        UNIFORM(1, 2000, RANDOM()) AS product_id,
        UNIFORM(1, 200, RANDOM()) AS rep_id,
        UNIFORM(1, 50000, RANDOM()) AS customer_id,
        -- Per-row randoms for downstream columns
        UNIFORM(1, 20, RANDOM()) AS rand_quantity,
        UNIFORM(50, 5000, RANDOM()) AS rand_base_amount,
        UNIFORM(1, 100, RANDOM()) AS rand_discount_tier,
        UNIFORM(15, 25, RANDOM()) AS rand_heavy_discount,
        UNIFORM(0, 12, RANDOM()) AS rand_normal_discount,
        UNIFORM(1, 1000, RANDOM()) AS rand_electronics_return,
        UNIFORM(1, 1000, RANDOM()) AS rand_baseline_return,
        UNIFORM(1, 100, RANDOM()) AS rand_status
    FROM date_spine d,
         TABLE(GENERATOR(ROWCOUNT => 700)) g  -- ~700 orders/day x 730 days
),
base_txn AS (
    SELECT
        br.order_id,
        br.order_date,
        CASE
            WHEN br.region_bucket <= 25 THEN br.na_region       -- NA (25%)
            WHEN br.region_bucket <= 55 THEN br.emea_region     -- EMEA (30%)
            WHEN br.region_bucket <= 80 THEN br.apac_region     -- APAC (25%)
            ELSE br.latam_region                                 -- LATAM (20%)
        END AS region_id,
        br.product_id,
        br.rep_id,
        br.customer_id,
        br.rand_quantity,
        br.rand_base_amount,
        br.rand_discount_tier,
        br.rand_heavy_discount,
        br.rand_normal_discount,
        br.rand_electronics_return,
        br.rand_baseline_return,
        br.rand_status
    FROM base_random br
)
SELECT
    b.order_id,
    b.order_date,
    b.region_id,
    b.product_id,
    b.rep_id,
    b.customer_id,
    b.rand_quantity AS quantity,
    -- Base amount with regional/seasonal multipliers
    ROUND(
        b.rand_base_amount
        -- PLANTED: EMEA Q3 2025 revenue depression
        * CASE
            WHEN b.region_id IN (3,4,5,6)
                 AND b.order_date BETWEEN '2025-07-01' AND '2025-09-30'
            THEN 0.83  -- EMEA Q3 ~-17% drop
            -- PLANTED: NA mild seasonal dip in Q3
            WHEN b.region_id IN (1,2)
                 AND b.order_date BETWEEN '2025-07-01' AND '2025-09-30'
            THEN 0.95  -- NA Q3 ~-5% dip
            -- PLANTED: APAC outperformance in Q3
            WHEN b.region_id IN (7,8,9)
                 AND b.order_date BETWEEN '2025-07-01' AND '2025-09-30'
            THEN 1.06  -- APAC Q3 ~+6% boost
            -- PLANTED: LATAM mild underperformance
            WHEN b.region_id IN (10,11,12)
                 AND b.order_date BETWEEN '2025-07-01' AND '2025-09-30'
            THEN 0.92  -- LATAM Q3 ~-8% dip
            ELSE 1.0
          END
    , 2) AS amount,
    -- Discount: 0-25%, with planted high-discount deals for correlation query
    ROUND(
        CASE
            WHEN b.rand_discount_tier <= 15
            THEN b.rand_heavy_discount   -- 15% of deals get heavy discount
            ELSE b.rand_normal_discount  -- Normal range
        END
    , 1) AS discount_pct,
    -- Return flag: electronics ~14.2%, others ~4%
    CASE
        WHEN MOD(b.product_id, 6) = 0  -- Electronics category
             AND b.rand_electronics_return <= 142
        THEN TRUE
        WHEN b.rand_baseline_return <= 40
        THEN TRUE
        ELSE FALSE
    END AS is_returned,
    b.order_date AS ship_date,
    CASE WHEN b.rand_status <= 95
         THEN 'Completed' ELSE 'Cancelled' END AS order_status
FROM base_txn b
LIMIT 500000;

-- -----------------------------------------
-- VERIFICATION: Confirm planted patterns
-- -----------------------------------------

-- Check 1: Q2 vs Q3 2025 revenue by region (expect EMEA -17%)
SELECT
    r.territory,
    SUM(CASE WHEN d.quarter = 2 AND d.year = 2025 THEN s.amount END) AS q2_revenue,
    SUM(CASE WHEN d.quarter = 3 AND d.year = 2025 THEN s.amount END) AS q3_revenue,
    ROUND((q3_revenue - q2_revenue) / q2_revenue * 100, 1) AS pct_change
FROM SALES_FACT s
JOIN DIM_REGION r ON s.region_id = r.region_id
JOIN DIM_DATE d ON s.order_date = d.date_key
WHERE d.year = 2025 AND d.quarter IN (2, 3)
GROUP BY r.territory
ORDER BY pct_change;

-- Check 2: Return rate by category (expect Electronics ~14%)
SELECT
    p.category,
    COUNT(*) AS total_orders,
    SUM(CASE WHEN s.is_returned THEN 1 ELSE 0 END) AS returns,
    ROUND(returns / total_orders * 100, 1) AS return_rate_pct
FROM SALES_FACT s
JOIN DIM_PRODUCT p ON s.product_id = p.product_id
GROUP BY p.category
ORDER BY return_rate_pct DESC;

-- Check 3: Top reps by deals above $50K (for visitor challenge card #4)
SELECT
    sr.rep_name,
    sr.team,
    COUNT(*) AS deals_above_50k,
    ROUND(SUM(s.amount), 0) AS total_value
FROM SALES_FACT s
JOIN DIM_SALES_REP sr ON s.rep_id = sr.rep_id
WHERE s.amount > 50000
    AND s.order_date >= DATEADD(MONTH, -6, CURRENT_DATE())
GROUP BY sr.rep_name, sr.team
ORDER BY deals_above_50k DESC
LIMIT 10;
