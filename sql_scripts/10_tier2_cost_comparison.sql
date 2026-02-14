/*
==================================================================
  DEMO AI SUMMIT - TIER 2: COST COMPARISON
  Script: 10_tier2_cost_comparison.sql
  Purpose: LLM cost comparison table for Arctic demo (Demo 6)
  Dependencies: 01_infrastructure.sql
==================================================================
*/

USE ROLE DEMO_AI_ROLE;
USE WAREHOUSE DEMO_AI_WH;
USE DATABASE DEMO_AI_SUMMIT;
USE SCHEMA CORTEX_ANALYST_DEMO;

-- Create a comparison table for cost storytelling
CREATE OR REPLACE TABLE DEMO_AI_SUMMIT.CORTEX_ANALYST_DEMO.LLM_COST_COMPARISON (
    model_name      VARCHAR(100),
    provider        VARCHAR(50),
    task            VARCHAR(100),
    input_tokens    INTEGER,
    output_tokens   INTEGER,
    cost_per_1m_input  NUMBER(10,4),
    cost_per_1m_output NUMBER(10,4),
    latency_ms      INTEGER,
    quality_score   NUMBER(5,2)
);

INSERT INTO LLM_COST_COMPARISON VALUES
('GPT-4o',            'OpenAI (via Azure)', 'SQL Generation',     500, 200, 5.00,  15.00, 2800, 92.5),
('GPT-4o',            'OpenAI (via Azure)', 'Text Summarization', 2000, 300, 5.00,  15.00, 3500, 94.0),
('Claude 3.5 Sonnet', 'Anthropic (via AWS)', 'SQL Generation',    500, 200, 3.00,  15.00, 2200, 93.0),
('Claude 3.5 Sonnet', 'Anthropic (via AWS)', 'Text Summarization',2000, 300, 3.00,  15.00, 2800, 93.5),
('Llama 3.1 70B',     'Snowflake Cortex',   'SQL Generation',     500, 200, 0.00,   0.00, 1500, 88.0),
('Llama 3.1 70B',     'Snowflake Cortex',   'Text Summarization', 2000, 300, 0.00,   0.00, 1800, 87.5),
('Arctic',            'Snowflake Cortex',   'SQL Generation',     500, 200, 0.00,   0.00, 1200, 86.0),
('Arctic',            'Snowflake Cortex',   'Text Summarization', 2000, 300, 0.00,   0.00, 1400, 85.0);

-- NOTE: Cortex models use credit-based pricing (included in your Snowflake
-- compute spend), not per-token pricing. The $0.00 above represents that
-- there's no ADDITIONAL per-token charge — you pay via warehouse/serverless credits.
-- Adjust these numbers to reflect current Snowflake pricing at event time.
