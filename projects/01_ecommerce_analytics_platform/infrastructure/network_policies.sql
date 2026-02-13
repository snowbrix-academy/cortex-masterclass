-- ============================================================
-- SNOWBRIX E-COMMERCE PLATFORM
-- Network Policies
-- ============================================================
-- In DEVELOPMENT: allows all IPs (0.0.0.0/0)
-- In PRODUCTION: restrict to known IPs only
-- ============================================================

USE ROLE SECURITYADMIN;

-- ============================================================
-- DEVELOPMENT POLICY (permissive)
-- ============================================================

CREATE NETWORK POLICY IF NOT EXISTS ECOMMERCE_DEV_POLICY
    ALLOWED_IP_LIST = ('0.0.0.0/0')
    COMMENT = 'DEVELOPMENT ONLY: Allows all IPs. Replace in production.';

-- ============================================================
-- PRODUCTION POLICY TEMPLATE (restrictive)
-- Uncomment and fill in real IPs when going to production.
-- ============================================================

-- CREATE OR REPLACE NETWORK POLICY ECOMMERCE_PROD_POLICY
--     ALLOWED_IP_LIST = (
--         '203.0.113.0/24',      -- Office network CIDR
--         '198.51.100.50/32',    -- Airflow server static IP
--         '198.51.100.51/32',    -- Streamlit dashboard host
--         '198.51.100.52/32'     -- CI/CD runner (GitHub Actions)
--     )
--     BLOCKED_IP_LIST = ()
--     COMMENT = 'Production network policy. Only known infrastructure IPs allowed.';

-- Apply to service accounts (production):
-- ALTER USER SVC_ECOMMERCE_LOADER SET NETWORK_POLICY = ECOMMERCE_PROD_POLICY;
-- ALTER USER SVC_ECOMMERCE_DBT SET NETWORK_POLICY = ECOMMERCE_PROD_POLICY;
-- ALTER USER SVC_ECOMMERCE_DASHBOARD SET NETWORK_POLICY = ECOMMERCE_PROD_POLICY;

-- Apply at account level (locks down everything):
-- ALTER ACCOUNT SET NETWORK_POLICY = ECOMMERCE_PROD_POLICY;
