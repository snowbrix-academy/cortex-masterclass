/*
==================================================================
  DEMO AI SUMMIT — DIMENSION TABLES
  Script: 02_dimensions.sql
  Purpose: Create and populate all dimension tables
  Dependencies: 01_infrastructure.sql
==================================================================
*/

USE DATABASE DEMO_AI_SUMMIT;
USE SCHEMA CORTEX_ANALYST_DEMO;

-- -----------------------------------------
-- DIM_DATE: 3-year date dimension (2023-2025)
-- -----------------------------------------
CREATE OR REPLACE TABLE DIM_DATE AS
SELECT
    d.date_key::DATE                                       AS date_key,
    YEAR(d.date_key)                                       AS year,
    QUARTER(d.date_key)                                    AS quarter,
    MONTH(d.date_key)                                      AS month,
    MONTHNAME(d.date_key)                                  AS month_name,
    DAY(d.date_key)                                        AS day,
    DAYOFWEEK(d.date_key)                                  AS day_of_week,
    DAYNAME(d.date_key)                                    AS day_name,
    WEEKOFYEAR(d.date_key)                                 AS week_of_year,
    'FY' || CASE WHEN MONTH(d.date_key) >= 2
                 THEN YEAR(d.date_key) + 1
                 ELSE YEAR(d.date_key) END                 AS fiscal_year,
    CEIL(MONTH(d.date_key) / 3.0)                          AS fiscal_quarter
FROM (
    SELECT DATEADD(DAY, seq4(), '2023-01-01'::DATE) AS date_key
    FROM TABLE(GENERATOR(ROWCOUNT => 1096))  -- 3 years
) d;

-- -----------------------------------------
-- DIM_REGION: 5 territories, 12 countries
-- Planted: EMEA and LATAM will underperform
-- -----------------------------------------
CREATE OR REPLACE TABLE DIM_REGION AS
SELECT * FROM VALUES
    (1,  'North America', 'United States', 'NA'),
    (2,  'North America', 'Canada',        'NA'),
    (3,  'EMEA',          'United Kingdom', 'EMEA'),
    (4,  'EMEA',          'Germany',        'EMEA'),
    (5,  'EMEA',          'France',         'EMEA'),
    (6,  'EMEA',          'Netherlands',    'EMEA'),
    (7,  'APAC',          'Australia',      'APAC'),
    (8,  'APAC',          'Japan',          'APAC'),
    (9,  'APAC',          'Singapore',      'APAC'),
    (10, 'LATAM',         'Brazil',         'LATAM'),
    (11, 'LATAM',         'Mexico',         'LATAM'),
    (12, 'LATAM',         'Colombia',       'LATAM')
    AS t(region_id, region_name, country, territory);

-- -----------------------------------------
-- DIM_PRODUCT: 2K products, 6 categories
-- Planted: Electronics has high return rate
-- -----------------------------------------
CREATE OR REPLACE TABLE DIM_PRODUCT AS
WITH categories AS (
    SELECT * FROM VALUES
        ('Electronics',    150.00, 500.00, 0.142),  -- planted: 14.2% return rate
        ('Apparel',         25.00, 120.00, 0.045),
        ('Home & Kitchen',  30.00, 200.00, 0.035),
        ('Sports',          20.00, 300.00, 0.028),
        ('Office Supplies', 5.00,   80.00, 0.031),
        ('Health & Beauty', 10.00, 150.00, 0.038)
        AS t(category, min_cost, max_cost, return_rate)
),
product_gen AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY seq4()) AS product_id,
        'PRD-' || LPAD(ROW_NUMBER() OVER (ORDER BY seq4()), 5, '0') AS product_code,
        seq4() AS rn
    FROM TABLE(GENERATOR(ROWCOUNT => 2000))
)
SELECT
    p.product_id,
    p.product_code,
    c.category,
    c.category || ' Item ' || p.product_id AS product_name,
    CASE MOD(p.product_id, 4)
        WHEN 0 THEN 'Premium'
        WHEN 1 THEN 'Standard'
        WHEN 2 THEN 'Budget'
        ELSE 'Professional'
    END AS subcategory,
    ROUND(c.min_cost + (c.max_cost - c.min_cost) * UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()), 2) AS unit_cost,
    c.return_rate AS base_return_rate
FROM product_gen p
JOIN categories c
    ON MOD(p.product_id, 6) = CASE c.category
        WHEN 'Electronics'    THEN 0
        WHEN 'Apparel'        THEN 1
        WHEN 'Home & Kitchen' THEN 2
        WHEN 'Sports'         THEN 3
        WHEN 'Office Supplies'THEN 4
        WHEN 'Health & Beauty'THEN 5
    END;

-- -----------------------------------------
-- DIM_SALES_REP: 200 reps across regions
-- -----------------------------------------
CREATE OR REPLACE TABLE DIM_SALES_REP AS
WITH rep_names AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY seq4()) AS rep_id,
        seq4() AS rn
    FROM TABLE(GENERATOR(ROWCOUNT => 200))
)
SELECT
    r.rep_id,
    'Rep-' || LPAD(r.rep_id, 3, '0') AS rep_name,
    CASE MOD(r.rep_id, 5)
        WHEN 0 THEN 'Enterprise'
        WHEN 1 THEN 'Mid-Market'
        WHEN 2 THEN 'SMB'
        WHEN 3 THEN 'Strategic'
        ELSE 'Inside Sales'
    END AS team,
    -- Distribute across regions
    MOD(r.rep_id, 12) + 1 AS primary_region_id,
    DATEADD(DAY, -UNIFORM(180, 1800, RANDOM()), CURRENT_DATE()) AS hire_date
FROM rep_names r;

-- -----------------------------------------
-- CUSTOMER_DIM: 50K customers
-- Planted: EMEA enterprise churn spike in Q3
-- Uses CTE to pre-compute random values so
-- churn_flag and churn_date stay correlated
-- -----------------------------------------
CREATE OR REPLACE TABLE CUSTOMER_DIM AS
WITH customer_gen AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY seq4()) AS customer_id,
        UNIFORM(1000, 500000, RANDOM()) AS rand_ltv,
        UNIFORM(90, 1095, RANDOM()) AS rand_first_order_days,
        UNIFORM(0, 100, RANDOM()) AS rand_emea_churn,
        UNIFORM(0, 100, RANDOM()) AS rand_baseline_churn,
        UNIFORM(30, 180, RANDOM()) AS rand_churn_date_days
    FROM TABLE(GENERATOR(ROWCOUNT => 50000))
)
SELECT
    c.customer_id,
    'CUST-' || LPAD(c.customer_id, 6, '0') AS customer_code,
    CASE MOD(c.customer_id, 4)
        WHEN 0 THEN 'Enterprise'
        WHEN 1 THEN 'Mid-Market'
        WHEN 2 THEN 'SMB'
        ELSE 'Startup'
    END AS segment,
    MOD(c.customer_id, 12) + 1 AS region_id,
    ROUND(c.rand_ltv, 2) AS lifetime_value,
    DATEADD(DAY, -c.rand_first_order_days, CURRENT_DATE()) AS first_order_date,
    -- Planted churn: EMEA enterprise customers have higher churn
    CASE
        WHEN MOD(c.customer_id, 12) + 1 IN (3,4,5,6)          -- EMEA region
             AND MOD(c.customer_id, 4) = 0                      -- Enterprise segment
             AND c.rand_emea_churn < 15                          -- 15% churn rate
        THEN TRUE
        WHEN c.rand_baseline_churn < 4                           -- 4% baseline churn
        THEN TRUE
        ELSE FALSE
    END AS churn_flag,
    CASE
        WHEN MOD(c.customer_id, 12) + 1 IN (3,4,5,6)
             AND MOD(c.customer_id, 4) = 0
             AND c.rand_emea_churn < 15
        THEN DATEADD(DAY, -c.rand_churn_date_days, CURRENT_DATE())
        ELSE NULL
    END AS churn_date
FROM customer_gen c;

-- -----------------------------------------
-- VERIFICATION: Dimension row counts
-- -----------------------------------------
SELECT 'DIM_DATE' AS table_name, COUNT(*) AS row_count FROM DIM_DATE
UNION ALL SELECT 'DIM_REGION', COUNT(*) FROM DIM_REGION
UNION ALL SELECT 'DIM_PRODUCT', COUNT(*) FROM DIM_PRODUCT
UNION ALL SELECT 'DIM_SALES_REP', COUNT(*) FROM DIM_SALES_REP
UNION ALL SELECT 'CUSTOMER_DIM', COUNT(*) FROM CUSTOMER_DIM
ORDER BY table_name;
