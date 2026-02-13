/*
==================================================================
  DEMO AI SUMMIT — RUN ALL SCRIPTS
  Script: RUN_ALL_SCRIPTS.sql
  Purpose: Execute all setup scripts in order
  Usage: Run this file in Snowsight or SnowSQL

  IMPORTANT:
  - Run this ONCE at T-7 (7 days before event)
  - All scripts are idempotent (safe to re-run)
  - Total execution time: < 5 minutes on Medium warehouse
  - After running, execute VERIFY_ALL.sql to confirm

  SCRIPT ORDER:
  01 → Infrastructure (DB, schemas, warehouse, role)
  02 → Dimension tables (date, region, product, rep, customer)
  03 → Sales fact (500K rows, planted patterns)
  04 → Campaign fact (5K campaigns, EMEA pause)
  05 → Agent tables (support tickets, churn signals)
  06 → Document AI tables (stage, extraction, text chunks)
  07 → Cortex Search service
  08 → Tier 2: Knowledge base text chunks
  09 → Tier 2: Sentiment demo reviews
  10 → Tier 2: Arctic cost comparison data
==================================================================
*/

-- ═══════════════════════════════════════════════
-- STEP 0: Context
-- ═══════════════════════════════════════════════
-- NOTE: In Snowsight, you can run this entire file at once.
-- In SnowSQL, run each script individually:
--   !source 01_infrastructure.sql
--   !source 02_dimensions.sql
--   ... etc.

-- For Snowsight bulk execution, copy-paste from each script
-- file in order, or run them individually via the Snowsight
-- SQL editor.

-- ═══════════════════════════════════════════════
-- EXECUTION CHECKLIST
-- ═══════════════════════════════════════════════
-- [ ] 01_infrastructure.sql    → Database, schemas, warehouse, role
-- [ ] 02_dimensions.sql        → 5 dimension tables loaded
-- [ ] 03_sales_fact.sql        → 500K sales rows with planted patterns
-- [ ] 04_campaign_fact.sql     → 5K campaigns with EMEA pause
-- [ ] 05_agent_tables.sql      → 20K tickets + 10K churn signals
-- [ ] 06_document_ai.sql       → Doc AI tables + 5 pre-extracted docs
-- [ ] 07_cortex_search.sql     → Cortex Search service created (ACTIVE)
-- [ ] 08_tier2_knowledge_base.sql → Policy text chunks for RAG demo
-- [ ] 09_tier2_sentiment.sql   → 10 sample reviews for sentiment demo
-- [ ] 10_tier2_cost_comparison.sql → LLM cost comparison table
--
-- After all scripts:
-- [ ] Upload semantic model YAML:
--     PUT file://cortex_analyst_demo.yaml
--         @DEMO_AI_SUMMIT.CORTEX_ANALYST_DEMO.SEMANTIC_MODELS
--         AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
--
-- [ ] Run VERIFY_ALL.sql to confirm all objects and patterns

SELECT '=== Run each numbered script (01-10) in order. Check off each step above. ===' AS instructions;
