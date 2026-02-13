/*
==================================================================
  DEMO AI SUMMIT — CORTEX SEARCH SERVICE
  Script: 07_cortex_search.sql
  Purpose: Create Cortex Search service over document text
  Dependencies: 06_document_ai.sql

  NOTE: Cortex Search service creation can take 1-5 minutes.
  Run this at T-7 and verify it's healthy before the event.
==================================================================
*/

USE ROLE DEMO_AI_ROLE;
USE WAREHOUSE DEMO_AI_WH;
USE DATABASE DEMO_AI_SUMMIT;
USE SCHEMA DOC_AI_DEMO;

CREATE OR REPLACE CORTEX SEARCH SERVICE DOCUMENTS_SEARCH_SERVICE
    ON chunk_text
    ATTRIBUTES page_number, section_header
    WAREHOUSE = DEMO_AI_WH
    TARGET_LAG = '1 hour'
    COMMENT = 'Semantic search over contract document text'
    AS (
        SELECT
            chunk_text,
            page_number,
            section_header,
            doc_id,
            chunk_id
        FROM DOCUMENTS_TEXT
    );

-- ─────────────────────────────────────────────
-- VERIFICATION: Test search queries
-- ─────────────────────────────────────────────

-- Test 1: "termination clause" should return Section 8.2
-- (Run via Cortex Search API in Streamlit — SQL verification below is conceptual)
-- SELECT SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
--     'DOCUMENTS_SEARCH_SERVICE',
--     'What is the termination clause?',
--     5
-- );

-- Test 2: "liability caps" should return Section 10.1
-- Test 3: "early exit" should return Section 8.5 (semantic match, no keyword "termination")
