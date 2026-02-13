/*
==================================================================
  DEMO AI SUMMIT — INFRASTRUCTURE SETUP
  Script: 01_infrastructure.sql
  Purpose: Create database, schemas, warehouse, and role
  Run: Once (idempotent)
==================================================================
*/

USE ROLE SYSADMIN;

-- Database
CREATE DATABASE IF NOT EXISTS DEMO_AI_SUMMIT
    COMMENT = 'Innovation Summit AI Demo — synthetic data and Cortex services';

-- Schemas
CREATE SCHEMA IF NOT EXISTS DEMO_AI_SUMMIT.CORTEX_ANALYST_DEMO
    COMMENT = 'Shared schema for Cortex Analyst (Demo 1) and Data Agent (Demo 2)';

CREATE SCHEMA IF NOT EXISTS DEMO_AI_SUMMIT.DOC_AI_DEMO
    COMMENT = 'Document AI + Cortex Search (Demo 3)';

CREATE SCHEMA IF NOT EXISTS DEMO_AI_SUMMIT.STAGING
    COMMENT = 'Shared utilities: sequences, file formats, helper procedures';

-- Warehouse
CREATE WAREHOUSE IF NOT EXISTS DEMO_AI_WH
    WAREHOUSE_SIZE = 'MEDIUM'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Demo warehouse — auto-suspend after 60s idle';

-- Role and grants
USE ROLE SECURITYADMIN;

CREATE ROLE IF NOT EXISTS DEMO_AI_ROLE
    COMMENT = 'Role for all demo operations';

GRANT USAGE ON DATABASE DEMO_AI_SUMMIT TO ROLE DEMO_AI_ROLE;
GRANT USAGE ON ALL SCHEMAS IN DATABASE DEMO_AI_SUMMIT TO ROLE DEMO_AI_ROLE;
GRANT ALL PRIVILEGES ON ALL SCHEMAS IN DATABASE DEMO_AI_SUMMIT TO ROLE DEMO_AI_ROLE;
GRANT USAGE ON WAREHOUSE DEMO_AI_WH TO ROLE DEMO_AI_ROLE;
GRANT OPERATE ON WAREHOUSE DEMO_AI_WH TO ROLE DEMO_AI_ROLE;

-- Grant role to your user (change AMITKOTI to your username if different)
SET MY_USER = CURRENT_USER();
GRANT ROLE DEMO_AI_ROLE TO USER IDENTIFIER($MY_USER);

USE ROLE DEMO_AI_ROLE;
USE WAREHOUSE DEMO_AI_WH;
USE DATABASE DEMO_AI_SUMMIT;
