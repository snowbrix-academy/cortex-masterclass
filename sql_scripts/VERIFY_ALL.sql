/*
==================================================================
  DEMO AI SUMMIT — FULL VERIFICATION
  Script: VERIFY_ALL.sql
  Purpose: Verify all objects, data, and services after setup
  Run: After RUN_ALL_SCRIPTS.sql completes
  Expected: All 10 checks pass with expected values

  WHEN TO RUN:
  - T-7: After initial setup
  - T-5: After Streamlit app deployment
  - T-1: Final smoke test
  - T-0 AM: Morning warm-up verification
==================================================================
*/

USE ROLE DEMO_AI_ROLE;
USE WAREHOUSE DEMO_AI_WH;
USE DATABASE DEMO_AI_SUMMIT;

-- ═══════════════════════════════════════════════
-- CHECK 1: Schemas exist
-- Expected: CORTEX_ANALYST_DEMO, DOC_AI_DEMO, STAGING
-- ═══════════════════════════════════════════════
SELECT '--- CHECK 1: SCHEMAS ---' AS check_name;
SELECT SCHEMA_NAME
FROM INFORMATION_SCHEMA.SCHEMATA
WHERE CATALOG_NAME = 'DEMO_AI_SUMMIT'
    AND SCHEMA_NAME NOT IN ('INFORMATION_SCHEMA', 'PUBLIC')
ORDER BY SCHEMA_NAME;

-- ═══════════════════════════════════════════════
-- CHECK 2: All tables with row counts
-- Expected: 12+ tables with counts matching spec
-- ═══════════════════════════════════════════════
SELECT '--- CHECK 2: TABLE ROW COUNTS ---' AS check_name;
SELECT table_schema, table_name, row_count
FROM INFORMATION_SCHEMA.TABLES
WHERE table_catalog = 'DEMO_AI_SUMMIT'
    AND table_schema IN ('CORTEX_ANALYST_DEMO', 'DOC_AI_DEMO')
    AND table_type = 'BASE TABLE'
ORDER BY table_schema, table_name;

-- ═══════════════════════════════════════════════
-- CHECK 3: Semantic model staged
-- Expected: cortex_analyst_demo.yaml in stage
-- ═══════════════════════════════════════════════
SELECT '--- CHECK 3: SEMANTIC MODEL ---' AS check_name;
LIST @CORTEX_ANALYST_DEMO.SEMANTIC_MODELS;

-- ═══════════════════════════════════════════════
-- CHECK 4: Cortex Search service healthy
-- Expected: DOCUMENTS_SEARCH_SERVICE with ACTIVE status
-- ═══════════════════════════════════════════════
SELECT '--- CHECK 4: CORTEX SEARCH ---' AS check_name;
SHOW CORTEX SEARCH SERVICES IN SCHEMA DOC_AI_DEMO;

-- ═══════════════════════════════════════════════
-- CHECK 5: Cortex LLM functions work
-- Expected: Text response (proves functions are enabled)
-- ═══════════════════════════════════════════════
SELECT '--- CHECK 5: CORTEX LLM ---' AS check_name;
SELECT SNOWFLAKE.CORTEX.COMPLETE('llama3.1-8b', 'Say hello in one sentence.') AS llm_test;

-- ═══════════════════════════════════════════════
-- CHECK 6: PLANTED PATTERN — Q3 vs Q2 revenue by region
-- Expected: EMEA ~ -17%, LATAM ~ -8%, APAC ~ +6%
-- ═══════════════════════════════════════════════
SELECT '--- CHECK 6: Q3 vs Q2 REVENUE ---' AS check_name;
SELECT
    r.territory,
    SUM(CASE WHEN d.quarter = 2 AND d.year = 2025 THEN s.amount END) AS q2_revenue,
    SUM(CASE WHEN d.quarter = 3 AND d.year = 2025 THEN s.amount END) AS q3_revenue,
    ROUND((q3_revenue - q2_revenue) / q2_revenue * 100, 1) AS pct_change
FROM CORTEX_ANALYST_DEMO.SALES_FACT s
JOIN CORTEX_ANALYST_DEMO.DIM_REGION r ON s.region_id = r.region_id
JOIN CORTEX_ANALYST_DEMO.DIM_DATE d ON s.order_date = d.date_key
WHERE d.year = 2025 AND d.quarter IN (2, 3)
GROUP BY r.territory
ORDER BY pct_change;

-- ═══════════════════════════════════════════════
-- CHECK 7: PLANTED PATTERN — Electronics return rate
-- Expected: Electronics ~ 14.2%, others 2.8-4.5%
-- ═══════════════════════════════════════════════
SELECT '--- CHECK 7: RETURN RATES ---' AS check_name;
SELECT
    p.category,
    COUNT(*) AS total_orders,
    SUM(CASE WHEN s.is_returned THEN 1 ELSE 0 END) AS returns,
    ROUND(returns::FLOAT / total_orders * 100, 1) AS return_rate_pct
FROM CORTEX_ANALYST_DEMO.SALES_FACT s
JOIN CORTEX_ANALYST_DEMO.DIM_PRODUCT p ON s.product_id = p.product_id
GROUP BY p.category
ORDER BY return_rate_pct DESC;

-- ═══════════════════════════════════════════════
-- CHECK 8: PLANTED PATTERN — EMEA enterprise churn
-- Expected: EMEA Enterprise churn > 7%
-- ═══════════════════════════════════════════════
SELECT '--- CHECK 8: EMEA CHURN ---' AS check_name;
SELECT
    r.territory,
    c.segment,
    COUNT(*) AS total_customers,
    SUM(CASE WHEN c.churn_flag THEN 1 ELSE 0 END) AS churned,
    ROUND(churned::FLOAT / total_customers * 100, 1) AS churn_rate_pct
FROM CORTEX_ANALYST_DEMO.CUSTOMER_DIM c
JOIN CORTEX_ANALYST_DEMO.DIM_REGION r ON c.region_id = r.region_id
WHERE c.segment = 'Enterprise'
GROUP BY r.territory, c.segment
ORDER BY churn_rate_pct DESC;

-- ═══════════════════════════════════════════════
-- CHECK 9: Document text searchable
-- Expected: 11+ chunks for hero MSA doc, plus knowledge base chunks
-- ═══════════════════════════════════════════════
SELECT '--- CHECK 9: DOCUMENT CHUNKS ---' AS check_name;
SELECT COUNT(*) AS total_chunks FROM DOC_AI_DEMO.DOCUMENTS_TEXT;

SELECT section_header, LEFT(chunk_text, 80) AS preview
FROM DOC_AI_DEMO.DOCUMENTS_TEXT
WHERE section_header LIKE '%Termination%'
   OR section_header LIKE '%Liability%'
   OR section_header LIKE '%Discount%';

-- ═══════════════════════════════════════════════
-- CHECK 10: Tier 2 data loaded
-- Expected: CUSTOMER_REVIEWS (10 rows), LLM_COST_COMPARISON (8 rows)
-- ═══════════════════════════════════════════════
SELECT '--- CHECK 10: TIER 2 DATA ---' AS check_name;
SELECT 'CUSTOMER_REVIEWS' AS tbl, COUNT(*) AS row_count FROM CORTEX_ANALYST_DEMO.CUSTOMER_REVIEWS
UNION ALL
SELECT 'LLM_COST_COMPARISON', COUNT(*) FROM CORTEX_ANALYST_DEMO.LLM_COST_COMPARISON;

-- ═══════════════════════════════════════════════
-- SUMMARY
-- ═══════════════════════════════════════════════
SELECT '=== ALL CHECKS COMPLETE ===' AS status,
       'Review results above. All planted patterns should match expected values.' AS note;
