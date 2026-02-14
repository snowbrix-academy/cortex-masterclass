/*
==================================================================
  DEMO AI SUMMIT — CAMPAIGN FACT
  Script: 04_campaign_fact.sql
  Purpose: 5K marketing campaigns with planted EMEA pause
  Dependencies: 02_dimensions.sql

  PLANTED PATTERN:
  - Two major EMEA campaigns paused in Jul-Aug 2025
  - EMEA Q3 spend drops ~40% vs Q2
  - Other regions maintain steady spend
==================================================================
*/

USE ROLE DEMO_AI_ROLE;
USE WAREHOUSE DEMO_AI_WH;
USE DATABASE DEMO_AI_SUMMIT;
USE SCHEMA CORTEX_ANALYST_DEMO;

CREATE OR REPLACE TABLE CAMPAIGN_FACT AS
WITH campaign_gen AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY seq4()) AS campaign_id,
        -- Pre-compute random values in CTE so start_date is
        -- consistent across spend/status CASE branches
        UNIFORM(0, 730, RANDOM()) AS rand_start_days,
        UNIFORM(14, 90, RANDOM()) AS rand_duration_days,
        UNIFORM(5000, 150000, RANDOM()) AS rand_spend,
        UNIFORM(100, 50000, RANDOM()) AS rand_impressions,
        UNIFORM(10, 5000, RANDOM()) AS rand_clicks,
        UNIFORM(1, 500, RANDOM()) AS rand_conversions
    FROM TABLE(GENERATOR(ROWCOUNT => 5000))
),
campaign_with_dates AS (
    SELECT
        c.campaign_id,
        'CMP-' || LPAD(c.campaign_id, 5, '0') AS campaign_code,
        MOD(c.campaign_id, 12) + 1 AS region_id,
        CASE MOD(c.campaign_id, 5)
            WHEN 0 THEN 'Digital Ads'
            WHEN 1 THEN 'Email'
            WHEN 2 THEN 'Events'
            WHEN 3 THEN 'Content Marketing'
            ELSE 'Partner Co-Marketing'
        END AS channel,
        DATEADD(DAY, c.rand_start_days, '2024-01-01'::DATE) AS start_date,
        DATEADD(DAY, c.rand_start_days + c.rand_duration_days, '2024-01-01'::DATE) AS end_date,
        c.rand_spend,
        c.rand_impressions,
        c.rand_clicks,
        c.rand_conversions
    FROM campaign_gen c
)
SELECT
    cwd.campaign_id,
    cwd.campaign_code,
    cwd.region_id,
    cwd.channel,
    cwd.start_date,
    cwd.end_date,
    -- PLANTED: EMEA campaigns in Jul-Aug 2025 have near-zero spend (paused)
    ROUND(
        cwd.rand_spend
        * CASE
            WHEN cwd.region_id IN (3,4,5,6)  -- EMEA
                 AND cwd.start_date BETWEEN '2025-07-01' AND '2025-08-31'
            THEN 0.05  -- 95% reduction = effectively paused
            ELSE 1.0
          END
    , 2) AS spend,
    -- Status
    CASE
        WHEN cwd.region_id IN (3,4,5,6)
             AND cwd.start_date BETWEEN '2025-07-01' AND '2025-08-31'
        THEN 'Paused — Budget Freeze'
        WHEN cwd.end_date < CURRENT_DATE() THEN 'Completed'
        WHEN cwd.start_date > CURRENT_DATE() THEN 'Scheduled'
        ELSE 'Active'
    END AS campaign_status,
    cwd.rand_impressions AS impressions,
    cwd.rand_clicks AS clicks,
    cwd.rand_conversions AS conversions
FROM campaign_with_dates cwd;

-- -----------------------------------------
-- VERIFICATION: EMEA campaign spend drop in Q3
-- -----------------------------------------
SELECT
    r.territory,
    SUM(CASE WHEN cf.start_date BETWEEN '2025-04-01' AND '2025-06-30' THEN cf.spend END) AS q2_spend,
    SUM(CASE WHEN cf.start_date BETWEEN '2025-07-01' AND '2025-09-30' THEN cf.spend END) AS q3_spend,
    ROUND((q3_spend - q2_spend) / NULLIF(q2_spend, 0) * 100, 1) AS pct_change
FROM CAMPAIGN_FACT cf
JOIN DIM_REGION r ON cf.region_id = r.region_id
WHERE cf.start_date BETWEEN '2025-04-01' AND '2025-09-30'
GROUP BY r.territory
ORDER BY pct_change;
