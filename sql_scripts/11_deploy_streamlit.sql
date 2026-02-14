/*
==================================================================
  DEMO AI SUMMIT — DEPLOY STREAMLIT APPS
  Script: 11_deploy_streamlit.sql
  Purpose: Create stages and Streamlit apps for all 3 demo stations
  Dependencies: All data scripts (01-10) completed

  AFTER RUNNING THIS SCRIPT:
  Upload the .py files via SnowSQL PUT commands (see bottom of script)
==================================================================
*/

USE ROLE DEMO_AI_ROLE;
USE WAREHOUSE DEMO_AI_WH;
USE DATABASE DEMO_AI_SUMMIT;

-- -----------------------------------------
-- Create stages for Streamlit app code
-- -----------------------------------------
CREATE STAGE IF NOT EXISTS CORTEX_ANALYST_DEMO.STREAMLIT_STAGE
    COMMENT = 'Streamlit app files for demo stations';

-- -----------------------------------------
-- Station A: Cortex Analyst — "Talk to Your Data"
-- -----------------------------------------
CREATE OR REPLACE STREAMLIT CORTEX_ANALYST_DEMO.STATION_A_CORTEX_ANALYST
    ROOT_LOCATION = '@CORTEX_ANALYST_DEMO.STREAMLIT_STAGE/station_a'
    MAIN_FILE = 'app_cortex_analyst.py'
    QUERY_WAREHOUSE = 'DEMO_AI_WH'
    COMMENT = 'Station A: Cortex Analyst — NL-to-SQL chat interface';

-- -----------------------------------------
-- Station B: Data Agent — "Autonomous Analyst"
-- -----------------------------------------
CREATE OR REPLACE STREAMLIT CORTEX_ANALYST_DEMO.STATION_B_DATA_AGENT
    ROOT_LOCATION = '@CORTEX_ANALYST_DEMO.STREAMLIT_STAGE/station_b'
    MAIN_FILE = 'app_data_agent.py'
    QUERY_WAREHOUSE = 'DEMO_AI_WH'
    COMMENT = 'Station B: Data Agent — multi-step investigation';

-- -----------------------------------------
-- Station C: Document AI — "Paper to Insight"
-- -----------------------------------------
CREATE OR REPLACE STREAMLIT CORTEX_ANALYST_DEMO.STATION_C_DOCUMENT_AI
    ROOT_LOCATION = '@CORTEX_ANALYST_DEMO.STREAMLIT_STAGE/station_c'
    MAIN_FILE = 'app_document_ai.py'
    QUERY_WAREHOUSE = 'DEMO_AI_WH'
    COMMENT = 'Station C: Document AI + Cortex Search';

-- -----------------------------------------
-- Verify Streamlit apps created
-- -----------------------------------------
SHOW STREAMLITS IN SCHEMA CORTEX_ANALYST_DEMO;
