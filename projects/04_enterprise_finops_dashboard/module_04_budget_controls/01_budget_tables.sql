/*
=============================================================================
  MODULE 04 : BUDGET CONTROLS
  SCRIPT 01 : Budget Tables and Configuration
=============================================================================
  SNOWBRIX ACADEMY — Enterprise FinOps Dashboard for Snowflake

  LEARNING OBJECTIVES:
    1. Design budget structure (monthly, quarterly, annual)
    2. Implement budget vs actual tracking
    3. Define alert thresholds (soft warnings, hard blocks)
    4. Create anomaly detection framework
    5. Build budget forecast models

  BUDGET CONTROL FRAMEWORK:
  ┌──────────────────────────────────────────────────────────────┐
  │  Budget Definition                                           │
  │    → Entity (team/dept) + Period (month/quarter/year)       │
  │    → Budget amount in USD and credits                        │
  │    → Alert thresholds: 70%, 85%, 95%, 100%                  │
  │                                                               │
  │  Budget Tracking                                             │
  │    → Daily actual cost accumulation                          │
  │    → Cumulative MTD/QTD/YTD tracking                         │
  │    → Burn rate calculation                                   │
  │    → Forecast to period-end                                  │
  │                                                               │
  │  Alert System                                                │
  │    → Soft alerts (email notification)                        │
  │    → Hard alerts (escalation + optional warehouse suspend)   │
  │    → Anomaly detection (z-score based)                       │
  └──────────────────────────────────────────────────────────────┘

  PREREQUISITES:
    - Module 03 completed (chargeback attribution)
    - FACT_CHARGEBACK_DAILY table populated

  ESTIMATED TIME: 20 minutes

=============================================================================
*/

USE ROLE FINOPS_ADMIN_ROLE;
USE DATABASE FINOPS_CONTROL_DB;
USE SCHEMA BUDGET;
USE WAREHOUSE FINOPS_WH_ADMIN;

-- =========================================================================
-- DIMENSION: DIM_BUDGET_PERIOD
-- Defines budget periods (monthly, quarterly, annual)
-- =========================================================================
CREATE TABLE IF NOT EXISTS DIM_BUDGET_PERIOD (
    PERIOD_ID               NUMBER AUTOINCREMENT PRIMARY KEY,
    PERIOD_TYPE             VARCHAR(20) NOT NULL COMMENT 'MONTHLY, QUARTERLY, ANNUAL',
    PERIOD_START_DATE       DATE NOT NULL,
    PERIOD_END_DATE         DATE NOT NULL,
    FISCAL_YEAR             NUMBER NOT NULL COMMENT 'Fiscal year (e.g., 2025)',
    FISCAL_QUARTER          NUMBER COMMENT 'Fiscal quarter (1-4)',
    FISCAL_MONTH            NUMBER COMMENT 'Fiscal month (1-12)',
    PERIOD_NAME             VARCHAR(50) COMMENT 'Human-readable (e.g., "FY2025 Q1", "Jan 2025")',
    IS_CURRENT              BOOLEAN DEFAULT FALSE,
    CREATED_AT              TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),

    CONSTRAINT chk_period_type CHECK (PERIOD_TYPE IN ('MONTHLY', 'QUARTERLY', 'ANNUAL')),
    CONSTRAINT chk_period_dates CHECK (PERIOD_START_DATE < PERIOD_END_DATE),
    CONSTRAINT chk_fiscal_quarter CHECK (FISCAL_QUARTER BETWEEN 1 AND 4 OR FISCAL_QUARTER IS NULL),
    CONSTRAINT chk_fiscal_month CHECK (FISCAL_MONTH BETWEEN 1 AND 12 OR FISCAL_MONTH IS NULL)
)
COMMENT = 'Dimension: Budget periods (monthly, quarterly, annual) with fiscal calendar alignment';

CREATE INDEX IF NOT EXISTS idx_period_dates ON DIM_BUDGET_PERIOD(PERIOD_START_DATE, PERIOD_END_DATE);


-- =========================================================================
-- FACT TABLE: FACT_BUDGET_PLAN
-- Stores budget definitions for entities and periods
-- =========================================================================
CREATE TABLE IF NOT EXISTS FACT_BUDGET_PLAN (
    BUDGET_ID                   NUMBER AUTOINCREMENT PRIMARY KEY,
    ENTITY_ID                   NUMBER NOT NULL COMMENT 'FK to DIM_CHARGEBACK_ENTITY',
    PERIOD_ID                   NUMBER NOT NULL COMMENT 'FK to DIM_BUDGET_PERIOD',

    -- Budget Amounts
    BUDGET_USD                  NUMBER(18, 2) NOT NULL,
    BUDGET_CREDITS              NUMBER(18, 4) COMMENT 'Optional: budget in Snowflake credits',

    -- Alert Thresholds (percentage of budget consumed)
    THRESHOLD_WARNING_PCT       NUMBER(5, 2) DEFAULT 70.00 COMMENT 'Soft alert: email notification',
    THRESHOLD_CRITICAL_PCT      NUMBER(5, 2) DEFAULT 85.00 COMMENT 'Hard alert: escalation',
    THRESHOLD_BLOCK_PCT         NUMBER(5, 2) DEFAULT 95.00 COMMENT 'Hard alert: consider warehouse suspension',

    -- Anomaly Detection Settings
    ENABLE_ANOMALY_DETECTION    BOOLEAN DEFAULT TRUE,
    ANOMALY_Z_SCORE_THRESHOLD   NUMBER(5, 2) DEFAULT 2.0 COMMENT 'Flag if daily cost > 2 std devs above mean',
    ANOMALY_PCT_SPIKE_THRESHOLD NUMBER(5, 2) DEFAULT 50.0 COMMENT 'Flag if daily cost > 50% above same-day-last-week',

    -- Budget Ownership
    BUDGET_OWNER_NAME           VARCHAR(200) COMMENT 'Budget owner (team lead, director)',
    BUDGET_OWNER_EMAIL          VARCHAR(200) COMMENT 'Email for budget alerts',
    APPROVER_NAME               VARCHAR(200) COMMENT 'Budget approver (VP, CFO)',
    APPROVER_EMAIL              VARCHAR(200),

    -- Status
    STATUS                      VARCHAR(20) DEFAULT 'ACTIVE' COMMENT 'ACTIVE, SUSPENDED, EXPIRED',
    NOTES                       VARCHAR(1000) COMMENT 'Budget justification or notes',

    -- Audit Trail
    CREATED_AT                  TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CREATED_BY                  VARCHAR(200) DEFAULT CURRENT_USER(),
    UPDATED_AT                  TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_BY                  VARCHAR(200) DEFAULT CURRENT_USER(),

    -- Constraints
    CONSTRAINT chk_budget_status CHECK (STATUS IN ('ACTIVE', 'SUSPENDED', 'EXPIRED')),
    CONSTRAINT chk_budget_thresholds CHECK (
        THRESHOLD_WARNING_PCT < THRESHOLD_CRITICAL_PCT AND
        THRESHOLD_CRITICAL_PCT < THRESHOLD_BLOCK_PCT
    ),

    -- Foreign Keys
    CONSTRAINT fk_budget_entity FOREIGN KEY (ENTITY_ID) REFERENCES FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY(ENTITY_ID),
    CONSTRAINT fk_budget_period FOREIGN KEY (PERIOD_ID) REFERENCES DIM_BUDGET_PERIOD(PERIOD_ID),

    -- Unique Constraint (one budget per entity per period)
    CONSTRAINT uq_budget_entity_period UNIQUE (ENTITY_ID, PERIOD_ID)
)
COMMENT = 'Fact: Budget definitions with alert thresholds and anomaly detection settings';

CREATE INDEX IF NOT EXISTS idx_budget_entity ON FACT_BUDGET_PLAN(ENTITY_ID, STATUS);
CREATE INDEX IF NOT EXISTS idx_budget_period ON FACT_BUDGET_PLAN(PERIOD_ID, STATUS);


-- =========================================================================
-- FACT TABLE: FACT_BUDGET_ACTUALS
-- Daily snapshot of budget consumption (actual vs budget)
-- =========================================================================
CREATE TABLE IF NOT EXISTS FACT_BUDGET_ACTUALS (
    -- Composite Primary Key
    BUDGET_ID                   NUMBER NOT NULL,
    ACTUAL_DATE                 DATE NOT NULL,

    -- Daily Actuals
    ACTUAL_COST_USD             NUMBER(18, 4) DEFAULT 0.00,
    ACTUAL_CREDITS              NUMBER(18, 4) DEFAULT 0.00,

    -- Cumulative Metrics
    CUMULATIVE_COST_MTD         NUMBER(18, 4) DEFAULT 0.00 COMMENT 'Month-to-date cumulative cost',
    CUMULATIVE_COST_QTD         NUMBER(18, 4) DEFAULT 0.00 COMMENT 'Quarter-to-date cumulative cost',
    CUMULATIVE_COST_YTD         NUMBER(18, 4) DEFAULT 0.00 COMMENT 'Year-to-date cumulative cost',

    -- Budget Consumption
    BUDGET_REMAINING_USD        NUMBER(18, 4),
    PCT_CONSUMED                NUMBER(5, 2) COMMENT 'Percentage of budget consumed',

    -- Burn Rate & Forecast
    DAILY_BURN_RATE             NUMBER(18, 4) COMMENT 'Average daily spend (trailing 7 days)',
    DAYS_REMAINING_IN_PERIOD    NUMBER,
    PROJECTED_MONTH_END_COST    NUMBER(18, 4) COMMENT 'Linear projection to period end',
    PROJECTED_OVERAGE_USD       NUMBER(18, 4) COMMENT 'Expected overage if projection holds',
    IS_ON_TRACK                 BOOLEAN COMMENT 'TRUE if projected to stay within budget',

    -- Anomaly Flags
    IS_ANOMALY                  BOOLEAN DEFAULT FALSE,
    Z_SCORE                     NUMBER(10, 4) COMMENT 'Z-score vs 30-day rolling average',
    PCT_CHANGE_VS_LAST_WEEK     NUMBER(10, 2) COMMENT 'Percentage change vs same day last week',

    -- Audit
    CALCULATED_AT               TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),

    -- Constraints
    PRIMARY KEY (BUDGET_ID, ACTUAL_DATE),
    CONSTRAINT fk_actual_budget FOREIGN KEY (BUDGET_ID) REFERENCES FACT_BUDGET_PLAN(BUDGET_ID)
)
PARTITION BY (ACTUAL_DATE)
CLUSTER BY (ACTUAL_DATE, BUDGET_ID)
COMMENT = 'Fact: Daily budget actuals with cumulative tracking, burn rate, and anomaly detection';


-- =========================================================================
-- FACT TABLE: FACT_BUDGET_ALERTS
-- Log of budget alerts triggered
-- =========================================================================
CREATE TABLE IF NOT EXISTS FACT_BUDGET_ALERTS (
    ALERT_ID                    NUMBER AUTOINCREMENT PRIMARY KEY,
    BUDGET_ID                   NUMBER NOT NULL,
    ENTITY_ID                   NUMBER NOT NULL,
    PERIOD_ID                   NUMBER NOT NULL,

    -- Alert Classification
    ALERT_TYPE                  VARCHAR(50) NOT NULL COMMENT 'WARNING, CRITICAL, BLOCK, ANOMALY',
    ALERT_SEVERITY              VARCHAR(20) NOT NULL COMMENT 'LOW, MEDIUM, HIGH, CRITICAL',
    ALERT_TIMESTAMP             TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),

    -- Budget Metrics at Time of Alert
    PCT_CONSUMED                NUMBER(5, 2),
    ACTUAL_COST_USD             NUMBER(18, 4),
    BUDGET_AMOUNT_USD           NUMBER(18, 4),
    PROJECTED_OVERAGE_USD       NUMBER(18, 4),

    -- Alert Message
    ALERT_MESSAGE               VARCHAR(2000),
    RECOMMENDATION              VARCHAR(2000),

    -- Notification Status
    NOTIFICATION_SENT           BOOLEAN DEFAULT FALSE,
    NOTIFICATION_CHANNEL        VARCHAR(50) COMMENT 'EMAIL, SLACK, TEAMS, PAGERDUTY',
    NOTIFICATION_RECIPIENTS     VARCHAR(1000) COMMENT 'Comma-separated email list',
    NOTIFICATION_SENT_AT        TIMESTAMP_NTZ,

    -- Resolution Tracking
    IS_RESOLVED                 BOOLEAN DEFAULT FALSE,
    RESOLVED_AT                 TIMESTAMP_NTZ,
    RESOLVED_BY                 VARCHAR(200),
    RESOLUTION_NOTES            VARCHAR(1000),

    -- Foreign Keys
    CONSTRAINT fk_alert_budget FOREIGN KEY (BUDGET_ID) REFERENCES FACT_BUDGET_PLAN(BUDGET_ID),
    CONSTRAINT chk_alert_type CHECK (ALERT_TYPE IN ('WARNING', 'CRITICAL', 'BLOCK', 'ANOMALY', 'OVERAGE')),
    CONSTRAINT chk_alert_severity CHECK (ALERT_SEVERITY IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL'))
)
COMMENT = 'Fact: Budget alerts log with notification tracking and resolution status';

CREATE INDEX IF NOT EXISTS idx_alert_budget ON FACT_BUDGET_ALERTS(BUDGET_ID, IS_RESOLVED);
CREATE INDEX IF NOT EXISTS idx_alert_timestamp ON FACT_BUDGET_ALERTS(ALERT_TIMESTAMP);


-- =========================================================================
-- CONFIG TABLE: ALERT_NOTIFICATION_CONFIG
-- Configuration for alert notification channels
-- =========================================================================
CREATE TABLE IF NOT EXISTS ALERT_NOTIFICATION_CONFIG (
    CONFIG_ID                   NUMBER AUTOINCREMENT PRIMARY KEY,
    ENTITY_ID                   NUMBER COMMENT 'FK to DIM_CHARGEBACK_ENTITY (NULL = global)',
    ALERT_TYPE                  VARCHAR(50) COMMENT 'WARNING, CRITICAL, BLOCK, ANOMALY',
    NOTIFICATION_CHANNEL        VARCHAR(50) NOT NULL COMMENT 'EMAIL, SLACK, TEAMS, PAGERDUTY',
    NOTIFICATION_RECIPIENTS     VARCHAR(2000) NOT NULL COMMENT 'Email addresses or webhook URLs',
    IS_ACTIVE                   BOOLEAN DEFAULT TRUE,
    CREATED_AT                  TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),

    CONSTRAINT chk_notif_channel CHECK (NOTIFICATION_CHANNEL IN ('EMAIL', 'SLACK', 'TEAMS', 'PAGERDUTY', 'WEBHOOK'))
)
COMMENT = 'Config: Alert notification channels (email, Slack, Teams, PagerDuty)';


-- =========================================================================
-- POPULATE SAMPLE BUDGET PERIODS
-- =========================================================================

-- Generate monthly periods for FY2025
INSERT INTO DIM_BUDGET_PERIOD (PERIOD_TYPE, PERIOD_START_DATE, PERIOD_END_DATE, FISCAL_YEAR, FISCAL_QUARTER, FISCAL_MONTH, PERIOD_NAME)
SELECT
    'MONTHLY',
    DATE_FROM_PARTS(2025, SEQ4() + 1, 1) AS PERIOD_START_DATE,
    LAST_DAY(DATE_FROM_PARTS(2025, SEQ4() + 1, 1)) AS PERIOD_END_DATE,
    2025 AS FISCAL_YEAR,
    CEIL((SEQ4() + 1) / 3.0) AS FISCAL_QUARTER,
    SEQ4() + 1 AS FISCAL_MONTH,
    TO_CHAR(DATE_FROM_PARTS(2025, SEQ4() + 1, 1), 'MON YYYY') AS PERIOD_NAME
FROM TABLE(GENERATOR(ROWCOUNT => 12));

-- Generate quarterly periods for FY2025
INSERT INTO DIM_BUDGET_PERIOD (PERIOD_TYPE, PERIOD_START_DATE, PERIOD_END_DATE, FISCAL_YEAR, FISCAL_QUARTER, PERIOD_NAME)
VALUES
    ('QUARTERLY', '2025-01-01', '2025-03-31', 2025, 1, 'FY2025 Q1'),
    ('QUARTERLY', '2025-04-01', '2025-06-30', 2025, 2, 'FY2025 Q2'),
    ('QUARTERLY', '2025-07-01', '2025-09-30', 2025, 3, 'FY2025 Q3'),
    ('QUARTERLY', '2025-10-01', '2025-12-31', 2025, 4, 'FY2025 Q4');

-- Generate annual period for FY2025
INSERT INTO DIM_BUDGET_PERIOD (PERIOD_TYPE, PERIOD_START_DATE, PERIOD_END_DATE, FISCAL_YEAR, PERIOD_NAME)
VALUES ('ANNUAL', '2025-01-01', '2025-12-31', 2025, 'FY2025');

-- Mark current period
UPDATE DIM_BUDGET_PERIOD
SET IS_CURRENT = TRUE
WHERE PERIOD_TYPE = 'MONTHLY'
  AND CURRENT_DATE() BETWEEN PERIOD_START_DATE AND PERIOD_END_DATE;


-- =========================================================================
-- POPULATE SAMPLE BUDGETS
-- =========================================================================

-- Get entity IDs for sample budgets
WITH entity_lookup AS (
    SELECT
        ENTITY_ID,
        ENTITY_NAME
    FROM FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY
    WHERE IS_CURRENT = TRUE
      AND ENTITY_TYPE IN ('DEPARTMENT', 'TEAM')
),
current_month_period AS (
    SELECT PERIOD_ID
    FROM DIM_BUDGET_PERIOD
    WHERE PERIOD_TYPE = 'MONTHLY'
      AND IS_CURRENT = TRUE
    LIMIT 1
)

-- Insert sample monthly budgets
INSERT INTO FACT_BUDGET_PLAN (
    ENTITY_ID, PERIOD_ID, BUDGET_USD, BUDGET_CREDITS,
    THRESHOLD_WARNING_PCT, THRESHOLD_CRITICAL_PCT, THRESHOLD_BLOCK_PCT,
    BUDGET_OWNER_NAME, BUDGET_OWNER_EMAIL, STATUS
)
SELECT
    e.ENTITY_ID,
    p.PERIOD_ID,
    CASE e.ENTITY_NAME
        WHEN 'Data Engineering' THEN 50000.00
        WHEN 'Analytics' THEN 30000.00
        WHEN 'ML Engineering' THEN 40000.00
        WHEN 'ETL Pipeline Team' THEN 20000.00
        WHEN 'BI Platform Team' THEN 15000.00
        WHEN 'ML Platform Team' THEN 25000.00
        ELSE 10000.00
    END AS BUDGET_USD,
    CASE e.ENTITY_NAME
        WHEN 'Data Engineering' THEN 12500.00
        WHEN 'Analytics' THEN 7500.00
        WHEN 'ML Engineering' THEN 10000.00
        WHEN 'ETL Pipeline Team' THEN 5000.00
        WHEN 'BI Platform Team' THEN 3750.00
        WHEN 'ML Platform Team' THEN 6250.00
        ELSE 2500.00
    END AS BUDGET_CREDITS,
    70.00 AS THRESHOLD_WARNING_PCT,
    85.00 AS THRESHOLD_CRITICAL_PCT,
    95.00 AS THRESHOLD_BLOCK_PCT,
    INITCAP(SPLIT_PART(e.ENTITY_NAME, ' ', 1) || ' Manager') AS BUDGET_OWNER_NAME,
    LOWER(REPLACE(e.ENTITY_NAME, ' ', '.')) || '@company.com' AS BUDGET_OWNER_EMAIL,
    'ACTIVE' AS STATUS
FROM entity_lookup e
CROSS JOIN current_month_period p
WHERE e.ENTITY_NAME IN (
    'Data Engineering', 'Analytics', 'ML Engineering',
    'ETL Pipeline Team', 'BI Platform Team', 'ML Platform Team'
);


-- =========================================================================
-- POPULATE SAMPLE ALERT NOTIFICATION CONFIG
-- =========================================================================
INSERT INTO ALERT_NOTIFICATION_CONFIG (ENTITY_ID, ALERT_TYPE, NOTIFICATION_CHANNEL, NOTIFICATION_RECIPIENTS, IS_ACTIVE)
VALUES
    (NULL, 'WARNING', 'EMAIL', 'finops-team@company.com', TRUE),
    (NULL, 'CRITICAL', 'EMAIL', 'finops-team@company.com,vp-engineering@company.com', TRUE),
    (NULL, 'CRITICAL', 'SLACK', '#finops-alerts', TRUE),
    (NULL, 'BLOCK', 'EMAIL', 'finops-team@company.com,vp-engineering@company.com,cfo@company.com', TRUE),
    (NULL, 'BLOCK', 'PAGERDUTY', 'https://events.pagerduty.com/integration/...(placeholder)', TRUE),
    (NULL, 'ANOMALY', 'EMAIL', 'finops-team@company.com', TRUE);


-- =========================================================================
-- VERIFICATION QUERIES
-- =========================================================================

/*
-- Verify: Budget periods
SELECT
    PERIOD_ID,
    PERIOD_TYPE,
    PERIOD_NAME,
    PERIOD_START_DATE,
    PERIOD_END_DATE,
    FISCAL_YEAR,
    FISCAL_QUARTER,
    IS_CURRENT
FROM DIM_BUDGET_PERIOD
ORDER BY PERIOD_START_DATE, PERIOD_TYPE;


-- Verify: Sample budgets
SELECT
    bp.BUDGET_ID,
    e.ENTITY_NAME,
    e.ENTITY_TYPE,
    p.PERIOD_NAME,
    bp.BUDGET_USD,
    bp.BUDGET_CREDITS,
    bp.THRESHOLD_WARNING_PCT,
    bp.THRESHOLD_CRITICAL_PCT,
    bp.THRESHOLD_BLOCK_PCT,
    bp.BUDGET_OWNER_NAME,
    bp.STATUS
FROM FACT_BUDGET_PLAN bp
JOIN FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY e ON bp.ENTITY_ID = e.ENTITY_ID
JOIN DIM_BUDGET_PERIOD p ON bp.PERIOD_ID = p.PERIOD_ID
WHERE bp.STATUS = 'ACTIVE'
ORDER BY bp.BUDGET_USD DESC;


-- Verify: Alert notification config
SELECT
    CONFIG_ID,
    COALESCE(e.ENTITY_NAME, 'GLOBAL') AS ENTITY,
    ALERT_TYPE,
    NOTIFICATION_CHANNEL,
    NOTIFICATION_RECIPIENTS,
    IS_ACTIVE
FROM ALERT_NOTIFICATION_CONFIG c
LEFT JOIN FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY e ON c.ENTITY_ID = e.ENTITY_ID
WHERE IS_ACTIVE = TRUE
ORDER BY ALERT_TYPE, NOTIFICATION_CHANNEL;


-- Verify: Budget summary by entity type
SELECT
    e.ENTITY_TYPE,
    COUNT(DISTINCT bp.BUDGET_ID) AS BUDGET_COUNT,
    SUM(bp.BUDGET_USD) AS TOTAL_BUDGET_USD,
    AVG(bp.BUDGET_USD) AS AVG_BUDGET_USD,
    MIN(bp.THRESHOLD_WARNING_PCT) AS MIN_WARNING_THRESHOLD,
    MAX(bp.THRESHOLD_BLOCK_PCT) AS MAX_BLOCK_THRESHOLD
FROM FACT_BUDGET_PLAN bp
JOIN FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY e ON bp.ENTITY_ID = e.ENTITY_ID
WHERE bp.STATUS = 'ACTIVE'
GROUP BY e.ENTITY_TYPE
ORDER BY TOTAL_BUDGET_USD DESC;
*/


/*
=============================================================================
  BEST PRACTICES & DESIGN NOTES:

  1. BUDGET PERIOD DESIGN:
     - Monthly budgets for operational control
     - Quarterly budgets for executive reporting
     - Annual budgets for strategic planning
     - Align fiscal periods with company fiscal calendar

  2. BUDGET ALLOCATION:
     - Start with department-level budgets
     - Roll down to team-level after 1-2 quarters
     - Use historical spend + growth factor for sizing
     - Reserve 10-15% for unallocated/emergency costs

  3. ALERT THRESHOLDS:
     - 70%: Soft warning (team lead email)
     - 85%: Critical alert (director email + Slack)
     - 95%: Block alert (VP + CFO, consider warehouse suspension)
     - Customize thresholds per entity based on spend volatility

  4. ANOMALY DETECTION:
     - Z-score > 2.0: Unusual daily spend (statistical outlier)
     - >50% spike: Day-over-day or week-over-week spike
     - Both methods catch different types of anomalies

  5. BUDGET FORECASTING:
     - Linear projection: Simple, works for steady spend
     - Weighted average: Better for volatile spend patterns
     - Seasonal adjustment: Use historical same-period data

  6. NOTIFICATION STRATEGY:
     - Email: Always (audit trail)
     - Slack/Teams: Real-time operational alerts
     - PagerDuty: Critical issues only (off-hours escalation)

  OBJECTS CREATED:
    - FINOPS_CONTROL_DB.BUDGET.DIM_BUDGET_PERIOD
    - FINOPS_CONTROL_DB.BUDGET.FACT_BUDGET_PLAN
    - FINOPS_CONTROL_DB.BUDGET.FACT_BUDGET_ACTUALS
    - FINOPS_CONTROL_DB.BUDGET.FACT_BUDGET_ALERTS
    - FINOPS_CONTROL_DB.BUDGET.ALERT_NOTIFICATION_CONFIG

  NEXT STEPS:
    → Script 02: SP_CHECK_BUDGETS (budget monitoring procedure)
    → Script 03: SP_FORECAST_BUDGET (budget forecasting logic)
    → Script 04: SP_SEND_ALERT (notification procedures)
=============================================================================
*/
