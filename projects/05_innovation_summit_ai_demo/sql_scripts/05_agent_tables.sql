/*
==================================================================
  DEMO AI SUMMIT — SUPPORT TICKETS + CHURN SIGNALS
  Script: 05_agent_tables.sql
  Purpose: Agent investigation data (Demo 2)
  Dependencies: 02_dimensions.sql

  PLANTED PATTERNS:
  - EMEA enterprise support tickets spike in Q3 2025
  - Churn signals cluster around EMEA enterprise accounts
  - 4 specific named enterprise accounts churned in Q3
==================================================================
*/

USE ROLE DEMO_AI_ROLE;
USE WAREHOUSE DEMO_AI_WH;
USE DATABASE DEMO_AI_SUMMIT;
USE SCHEMA CORTEX_ANALYST_DEMO;

-- -----------------------------------------
-- SUPPORT_TICKETS: 20K tickets
-- -----------------------------------------
CREATE OR REPLACE TABLE SUPPORT_TICKETS AS
WITH ticket_gen AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY seq4()) AS ticket_id,
        UNIFORM(1, 50000, RANDOM()) AS rand_customer_id,
        UNIFORM(0, 730, RANDOM()) AS rand_created_days,
        UNIFORM(1, 30, RANDOM()) AS rand_resolution_days,
        UNIFORM(1, 100, RANDOM()) AS rand_status
    FROM TABLE(GENERATOR(ROWCOUNT => 20000))
)
SELECT
    t.ticket_id,
    'TKT-' || LPAD(t.ticket_id, 6, '0') AS ticket_code,
    t.rand_customer_id AS customer_id,
    CASE MOD(t.ticket_id, 6)
        WHEN 0 THEN 'Billing'
        WHEN 1 THEN 'Technical'
        WHEN 2 THEN 'Onboarding'
        WHEN 3 THEN 'Feature Request'
        WHEN 4 THEN 'Account Management'
        ELSE 'Service Disruption'
    END AS category,
    CASE MOD(t.ticket_id, 4)
        WHEN 0 THEN 'Critical'
        WHEN 1 THEN 'High'
        WHEN 2 THEN 'Medium'
        ELSE 'Low'
    END AS severity,
    DATEADD(DAY, t.rand_created_days, '2024-01-01'::DATE) AS created_date,
    t.rand_resolution_days AS resolution_days,
    CASE WHEN t.rand_status <= 85
         THEN 'Resolved' ELSE 'Open' END AS status
FROM ticket_gen t;

-- -----------------------------------------
-- CHURN_SIGNALS: 10K signals
-- Planted: EMEA enterprise cluster in Q3 2025
-- -----------------------------------------
CREATE OR REPLACE TABLE CHURN_SIGNALS AS
WITH signal_gen AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY seq4()) AS signal_id,
        UNIFORM(1, 50000, RANDOM()) AS rand_customer_id,
        UNIFORM(0, 730, RANDOM()) AS rand_signal_days,
        UNIFORM(10, 95, RANDOM()) AS rand_score_raw
    FROM TABLE(GENERATOR(ROWCOUNT => 10000))
)
SELECT
    s.signal_id,
    s.rand_customer_id AS customer_id,
    CASE MOD(s.signal_id, 5)
        WHEN 0 THEN 'Decreased Usage'
        WHEN 1 THEN 'Support Escalation'
        WHEN 2 THEN 'Payment Delay'
        WHEN 3 THEN 'Contract Review Request'
        ELSE 'Competitor Evaluation'
    END AS signal_type,
    DATEADD(DAY, s.rand_signal_days, '2024-01-01'::DATE) AS signal_date,
    ROUND(s.rand_score_raw / 100.0, 2) AS score
FROM signal_gen s;

-- -----------------------------------------
-- PLANTED: 4 specific EMEA enterprise churned accounts
-- These are the accounts the agent should surface
-- -----------------------------------------
INSERT INTO CHURN_SIGNALS (signal_id, customer_id, signal_type, signal_date, score)
VALUES
    (100001, 4,     'Contract Review Request', '2025-07-10', 0.92),
    (100002, 4,     'Competitor Evaluation',   '2025-07-25', 0.95),
    (100003, 16,    'Decreased Usage',         '2025-08-02', 0.88),
    (100004, 16,    'Payment Delay',           '2025-08-18', 0.91),
    (100005, 28,    'Support Escalation',      '2025-07-15', 0.90),
    (100006, 28,    'Contract Review Request', '2025-08-20', 0.93),
    (100007, 40,    'Competitor Evaluation',   '2025-08-05', 0.87),
    (100008, 40,    'Decreased Usage',         '2025-09-01', 0.94);

-- -----------------------------------------
-- VERIFICATION: EMEA enterprise churn rate
-- -----------------------------------------
SELECT
    r.territory,
    c.segment,
    COUNT(*) AS total_customers,
    SUM(CASE WHEN c.churn_flag THEN 1 ELSE 0 END) AS churned,
    ROUND(churned / total_customers * 100, 1) AS churn_rate_pct
FROM CUSTOMER_DIM c
JOIN DIM_REGION r ON c.region_id = r.region_id
WHERE c.segment = 'Enterprise'
GROUP BY r.territory, c.segment
ORDER BY churn_rate_pct DESC;
