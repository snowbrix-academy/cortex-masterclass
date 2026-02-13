/*
#############################################################################
  FINOPS - Module 04: Budget Controls
  CONSOLIDATED WORKSHEET — Snowsight / VS Code Ready
#############################################################################
  SNOWBRIX ACADEMY — Enterprise FinOps Dashboard for Snowflake

  This worksheet contains:
    - 01_budget_tables.sql
    - 02_budget_procedures.sql
    - 03_alert_procedures.sql
    

  INSTRUCTIONS:
    - Run each section sequentially (top to bottom)
    - Requires Module 03 to be completed first (if applicable)
    - Estimated time: ~25 minutes

  PREREQUISITES:
    - Module 03 completed
    - FINOPS_ADMIN_ROLE access
#############################################################################
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

-- ===========================================================================
-- ===========================================================================
-- 02_BUDGET_PROCEDURES
-- ===========================================================================
-- ===========================================================================


USE ROLE FINOPS_ADMIN_ROLE;
USE DATABASE FINOPS_CONTROL_DB;
USE SCHEMA PROCEDURES;
USE WAREHOUSE FINOPS_WH_ETL;

-- =========================================================================
-- PROCEDURE: SP_CHECK_BUDGETS
-- Checks all active budgets, calculates actuals, detects threshold breaches
-- =========================================================================
CREATE OR REPLACE PROCEDURE SP_CHECK_BUDGETS(
    P_CHECK_DATE DATE DEFAULT CURRENT_DATE()
)
RETURNS VARIANT
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER
AS
$$
    function executeSql(sqlText, binds) {
        var stmt = snowflake.createStatement({sqlText: sqlText, binds: binds || []});
        return stmt.execute();
    }

    function executeScalar(sqlText, binds) {
        var rs = executeSql(sqlText, binds);
        return rs.next() ? rs.getColumnValue(1) : null;
    }

    var result = {
        procedure: 'SP_CHECK_BUDGETS',
        status: 'INITIALIZING',
        check_date: P_CHECK_DATE
    };

    try {
        // Step 1: Update FACT_BUDGET_ACTUALS with daily costs
        var updateActualsSql = `
        MERGE INTO FINOPS_CONTROL_DB.BUDGET.FACT_BUDGET_ACTUALS AS target
        USING (
            SELECT
                bp.BUDGET_ID,
                ? AS ACTUAL_DATE,
                COALESCE(SUM(cd.COST_USD), 0) AS ACTUAL_COST_USD,
                COALESCE(SUM(cd.CREDITS_CONSUMED), 0) AS ACTUAL_CREDITS,

                -- Cumulative metrics
                (SELECT COALESCE(SUM(ba.ACTUAL_COST_USD), 0)
                 FROM FINOPS_CONTROL_DB.BUDGET.FACT_BUDGET_ACTUALS ba
                 JOIN FINOPS_CONTROL_DB.BUDGET.DIM_BUDGET_PERIOD p ON bp.PERIOD_ID = p.PERIOD_ID
                 WHERE ba.BUDGET_ID = bp.BUDGET_ID
                   AND ba.ACTUAL_DATE >= p.PERIOD_START_DATE
                   AND ba.ACTUAL_DATE <= ?) AS CUMULATIVE_COST_MTD,

                -- Budget remaining
                bp.BUDGET_USD - (SELECT COALESCE(SUM(ba.ACTUAL_COST_USD), 0)
                                 FROM FINOPS_CONTROL_DB.BUDGET.FACT_BUDGET_ACTUALS ba
                                 JOIN FINOPS_CONTROL_DB.BUDGET.DIM_BUDGET_PERIOD p ON bp.PERIOD_ID = p.PERIOD_ID
                                 WHERE ba.BUDGET_ID = bp.BUDGET_ID
                                   AND ba.ACTUAL_DATE >= p.PERIOD_START_DATE
                                   AND ba.ACTUAL_DATE <= ?) AS BUDGET_REMAINING_USD,

                -- Percentage consumed
                ROUND((SELECT COALESCE(SUM(ba.ACTUAL_COST_USD), 0)
                       FROM FINOPS_CONTROL_DB.BUDGET.FACT_BUDGET_ACTUALS ba
                       JOIN FINOPS_CONTROL_DB.BUDGET.DIM_BUDGET_PERIOD p ON bp.PERIOD_ID = p.PERIOD_ID
                       WHERE ba.BUDGET_ID = bp.BUDGET_ID
                         AND ba.ACTUAL_DATE >= p.PERIOD_START_DATE
                         AND ba.ACTUAL_DATE <= ?) / NULLIF(bp.BUDGET_USD, 0) * 100, 2) AS PCT_CONSUMED,

                -- Burn rate (trailing 7 days average)
                (SELECT AVG(ba.ACTUAL_COST_USD)
                 FROM FINOPS_CONTROL_DB.BUDGET.FACT_BUDGET_ACTUALS ba
                 WHERE ba.BUDGET_ID = bp.BUDGET_ID
                   AND ba.ACTUAL_DATE BETWEEN DATEADD(DAY, -7, ?) AND ?) AS DAILY_BURN_RATE,

                -- Days remaining in period
                DATEDIFF(DAY, ?, p.PERIOD_END_DATE) AS DAYS_REMAINING_IN_PERIOD,

                -- Projected month-end cost
                (SELECT COALESCE(SUM(ba.ACTUAL_COST_USD), 0)
                 FROM FINOPS_CONTROL_DB.BUDGET.FACT_BUDGET_ACTUALS ba
                 JOIN FINOPS_CONTROL_DB.BUDGET.DIM_BUDGET_PERIOD pd ON bp.PERIOD_ID = pd.PERIOD_ID
                 WHERE ba.BUDGET_ID = bp.BUDGET_ID
                   AND ba.ACTUAL_DATE >= pd.PERIOD_START_DATE
                   AND ba.ACTUAL_DATE <= ?) +
                (AVG(ba7.ACTUAL_COST_USD) * DATEDIFF(DAY, ?, p.PERIOD_END_DATE)) AS PROJECTED_MONTH_END_COST

            FROM FINOPS_CONTROL_DB.BUDGET.FACT_BUDGET_PLAN bp
            JOIN FINOPS_CONTROL_DB.BUDGET.DIM_BUDGET_PERIOD p
                ON bp.PERIOD_ID = p.PERIOD_ID
            LEFT JOIN FINOPS_CONTROL_DB.CHARGEBACK.FACT_CHARGEBACK_DAILY cd
                ON cd.ENTITY_ID = bp.ENTITY_ID
                AND cd.CHARGEBACK_DATE = ?
            LEFT JOIN FINOPS_CONTROL_DB.BUDGET.FACT_BUDGET_ACTUALS ba7
                ON ba7.BUDGET_ID = bp.BUDGET_ID
                AND ba7.ACTUAL_DATE BETWEEN DATEADD(DAY, -7, ?) AND ?
            WHERE bp.STATUS = 'ACTIVE'
              AND ? BETWEEN p.PERIOD_START_DATE AND p.PERIOD_END_DATE
            GROUP BY bp.BUDGET_ID, bp.BUDGET_USD, bp.PERIOD_ID, p.PERIOD_END_DATE
        ) AS source
        ON target.BUDGET_ID = source.BUDGET_ID AND target.ACTUAL_DATE = source.ACTUAL_DATE
        WHEN MATCHED THEN UPDATE SET
            target.ACTUAL_COST_USD = source.ACTUAL_COST_USD,
            target.CUMULATIVE_COST_MTD = source.CUMULATIVE_COST_MTD,
            target.BUDGET_REMAINING_USD = source.BUDGET_REMAINING_USD,
            target.PCT_CONSUMED = source.PCT_CONSUMED,
            target.DAILY_BURN_RATE = source.DAILY_BURN_RATE,
            target.DAYS_REMAINING_IN_PERIOD = source.DAYS_REMAINING_IN_PERIOD,
            target.PROJECTED_MONTH_END_COST = source.PROJECTED_MONTH_END_COST,
            target.IS_ON_TRACK = (source.PROJECTED_MONTH_END_COST <= (SELECT BUDGET_USD FROM FINOPS_CONTROL_DB.BUDGET.FACT_BUDGET_PLAN WHERE BUDGET_ID = source.BUDGET_ID))
        WHEN NOT MATCHED THEN INSERT (
            BUDGET_ID, ACTUAL_DATE, ACTUAL_COST_USD, CUMULATIVE_COST_MTD,
            BUDGET_REMAINING_USD, PCT_CONSUMED, DAILY_BURN_RATE, DAYS_REMAINING_IN_PERIOD,
            PROJECTED_MONTH_END_COST
        ) VALUES (
            source.BUDGET_ID, source.ACTUAL_DATE, source.ACTUAL_COST_USD, source.CUMULATIVE_COST_MTD,
            source.BUDGET_REMAINING_USD, source.PCT_CONSUMED, source.DAILY_BURN_RATE,
            source.DAYS_REMAINING_IN_PERIOD, source.PROJECTED_MONTH_END_COST
        )`;

        var updateStmt = snowflake.createStatement({
            sqlText: updateActualsSql,
            binds: [P_CHECK_DATE, P_CHECK_DATE, P_CHECK_DATE, P_CHECK_DATE,
                    P_CHECK_DATE, P_CHECK_DATE, P_CHECK_DATE, P_CHECK_DATE,
                    P_CHECK_DATE, P_CHECK_DATE, P_CHECK_DATE, P_CHECK_DATE, P_CHECK_DATE]
        });
        var updateResult = updateStmt.execute();
        updateResult.next();

        result.actuals_updated = updateResult.getColumnValue('number of rows inserted') +
                                 updateResult.getColumnValue('number of rows updated');

        // Step 2: Check for threshold breaches and create alerts
        var checkThresholdsSql = `
        INSERT INTO FINOPS_CONTROL_DB.BUDGET.FACT_BUDGET_ALERTS (
            BUDGET_ID, ENTITY_ID, PERIOD_ID, ALERT_TYPE, ALERT_SEVERITY,
            PCT_CONSUMED, ACTUAL_COST_USD, BUDGET_AMOUNT_USD, PROJECTED_OVERAGE_USD,
            ALERT_MESSAGE, RECOMMENDATION, NOTIFICATION_RECIPIENTS
        )
        SELECT
            bp.BUDGET_ID,
            bp.ENTITY_ID,
            bp.PERIOD_ID,
            CASE
                WHEN ba.PCT_CONSUMED >= bp.THRESHOLD_BLOCK_PCT THEN 'BLOCK'
                WHEN ba.PCT_CONSUMED >= bp.THRESHOLD_CRITICAL_PCT THEN 'CRITICAL'
                WHEN ba.PCT_CONSUMED >= bp.THRESHOLD_WARNING_PCT THEN 'WARNING'
            END AS ALERT_TYPE,
            CASE
                WHEN ba.PCT_CONSUMED >= bp.THRESHOLD_BLOCK_PCT THEN 'CRITICAL'
                WHEN ba.PCT_CONSUMED >= bp.THRESHOLD_CRITICAL_PCT THEN 'HIGH'
                WHEN ba.PCT_CONSUMED >= bp.THRESHOLD_WARNING_PCT THEN 'MEDIUM'
            END AS ALERT_SEVERITY,
            ba.PCT_CONSUMED,
            ba.CUMULATIVE_COST_MTD,
            bp.BUDGET_USD,
            GREATEST(ba.PROJECTED_MONTH_END_COST - bp.BUDGET_USD, 0) AS PROJECTED_OVERAGE_USD,
            CONCAT(
                e.ENTITY_NAME, ' has consumed ', ROUND(ba.PCT_CONSUMED, 1), '% of monthly budget ($',
                ROUND(ba.CUMULATIVE_COST_MTD, 2), ' of $', ROUND(bp.BUDGET_USD, 2), '). ',
                'Projected month-end: $', ROUND(ba.PROJECTED_MONTH_END_COST, 2)
            ) AS ALERT_MESSAGE,
            CASE
                WHEN ba.PCT_CONSUMED >= bp.THRESHOLD_BLOCK_PCT THEN
                    'URGENT: Review all non-critical workloads. Consider warehouse suspension for non-essential queries.'
                WHEN ba.PCT_CONSUMED >= bp.THRESHOLD_CRITICAL_PCT THEN
                    'Review query patterns and optimize expensive queries. Defer non-critical analytics.'
                WHEN ba.PCT_CONSUMED >= bp.THRESHOLD_WARNING_PCT THEN
                    'Monitor daily spend closely. Review warehouse auto-suspend settings.'
            END AS RECOMMENDATION,
            bp.BUDGET_OWNER_EMAIL AS NOTIFICATION_RECIPIENTS
        FROM FINOPS_CONTROL_DB.BUDGET.FACT_BUDGET_PLAN bp
        JOIN FINOPS_CONTROL_DB.BUDGET.FACT_BUDGET_ACTUALS ba
            ON bp.BUDGET_ID = ba.BUDGET_ID
        JOIN FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY e
            ON bp.ENTITY_ID = e.ENTITY_ID
        WHERE ba.ACTUAL_DATE = ?
          AND bp.STATUS = 'ACTIVE'
          AND (ba.PCT_CONSUMED >= bp.THRESHOLD_WARNING_PCT)
          AND NOT EXISTS (
              SELECT 1 FROM FINOPS_CONTROL_DB.BUDGET.FACT_BUDGET_ALERTS prev
              WHERE prev.BUDGET_ID = bp.BUDGET_ID
                AND prev.ALERT_TYPE = CASE
                    WHEN ba.PCT_CONSUMED >= bp.THRESHOLD_BLOCK_PCT THEN 'BLOCK'
                    WHEN ba.PCT_CONSUMED >= bp.THRESHOLD_CRITICAL_PCT THEN 'CRITICAL'
                    WHEN ba.PCT_CONSUMED >= bp.THRESHOLD_WARNING_PCT THEN 'WARNING'
                END
                AND prev.ALERT_TIMESTAMP >= DATEADD(DAY, -1, CURRENT_TIMESTAMP())
                AND prev.IS_RESOLVED = FALSE
          )`;

        var alertStmt = snowflake.createStatement({
            sqlText: checkThresholdsSql,
            binds: [P_CHECK_DATE]
        });
        var alertResult = alertStmt.execute();
        alertResult.next();
        result.alerts_created = alertResult.getColumnValue(1);

        // Step 3: Summary statistics
        var summarySql = `
        SELECT
            COUNT(DISTINCT bp.BUDGET_ID) AS BUDGETS_CHECKED,
            COUNT(DISTINCT CASE WHEN ba.PCT_CONSUMED >= bp.THRESHOLD_WARNING_PCT THEN bp.BUDGET_ID END) AS BUDGETS_OVER_WARNING,
            COUNT(DISTINCT CASE WHEN ba.PCT_CONSUMED >= bp.THRESHOLD_CRITICAL_PCT THEN bp.BUDGET_ID END) AS BUDGETS_OVER_CRITICAL,
            COUNT(DISTINCT CASE WHEN ba.PCT_CONSUMED >= bp.THRESHOLD_BLOCK_PCT THEN bp.BUDGET_ID END) AS BUDGETS_OVER_BLOCK,
            SUM(bp.BUDGET_USD) AS TOTAL_BUDGET,
            SUM(ba.CUMULATIVE_COST_MTD) AS TOTAL_SPENT,
            AVG(ba.PCT_CONSUMED) AS AVG_PCT_CONSUMED
        FROM FINOPS_CONTROL_DB.BUDGET.FACT_BUDGET_PLAN bp
        JOIN FINOPS_CONTROL_DB.BUDGET.FACT_BUDGET_ACTUALS ba ON bp.BUDGET_ID = ba.BUDGET_ID
        WHERE ba.ACTUAL_DATE = ? AND bp.STATUS = 'ACTIVE'`;

        var summaryRs = executeSql(summarySql, [P_CHECK_DATE]);
        if (summaryRs.next()) {
            result.summary = {
                budgets_checked: summaryRs.getColumnValue('BUDGETS_CHECKED'),
                budgets_over_warning: summaryRs.getColumnValue('BUDGETS_OVER_WARNING'),
                budgets_over_critical: summaryRs.getColumnValue('BUDGETS_OVER_CRITICAL'),
                budgets_over_block: summaryRs.getColumnValue('BUDGETS_OVER_BLOCK'),
                total_budget_usd: summaryRs.getColumnValue('TOTAL_BUDGET'),
                total_spent_usd: summaryRs.getColumnValue('TOTAL_SPENT'),
                avg_pct_consumed: summaryRs.getColumnValue('AVG_PCT_CONSUMED')
            };
        }

        result.status = 'SUCCESS';
        return result;

    } catch (err) {
        result.status = 'ERROR';
        result.error_message = err.message;
        return result;
    }
$$;


-- =========================================================================
-- PROCEDURE: SP_DETECT_ANOMALIES
-- Detects cost anomalies using z-score and spike detection
-- =========================================================================
CREATE OR REPLACE PROCEDURE SP_DETECT_ANOMALIES(
    P_CHECK_DATE DATE DEFAULT CURRENT_DATE()
)
RETURNS VARIANT
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER
AS
$$
    function executeSql(sqlText, binds) {
        var stmt = snowflake.createStatement({sqlText: sqlText, binds: binds || []});
        return stmt.execute();
    }

    var result = {
        procedure: 'SP_DETECT_ANOMALIES',
        status: 'INITIALIZING',
        check_date: P_CHECK_DATE
    };

    try {
        // Update anomaly flags in FACT_BUDGET_ACTUALS
        var detectAnomaliesSql = `
        UPDATE FINOPS_CONTROL_DB.BUDGET.FACT_BUDGET_ACTUALS AS target
        SET
            IS_ANOMALY = source.IS_ANOMALY,
            Z_SCORE = source.Z_SCORE,
            PCT_CHANGE_VS_LAST_WEEK = source.PCT_CHANGE_VS_LAST_WEEK,
            CALCULATED_AT = CURRENT_TIMESTAMP()
        FROM (
            SELECT
                ba.BUDGET_ID,
                ba.ACTUAL_DATE,
                -- Z-score calculation (vs 30-day rolling average)
                CASE
                    WHEN stats.STDDEV_COST > 0 THEN
                        (ba.ACTUAL_COST_USD - stats.AVG_COST) / stats.STDDEV_COST
                    ELSE 0
                END AS Z_SCORE,
                -- Week-over-week percentage change
                CASE
                    WHEN prev_week.ACTUAL_COST_USD > 0 THEN
                        ((ba.ACTUAL_COST_USD - prev_week.ACTUAL_COST_USD) / prev_week.ACTUAL_COST_USD) * 100
                    ELSE 0
                END AS PCT_CHANGE_VS_LAST_WEEK,
                -- Anomaly flag
                CASE
                    WHEN ABS((ba.ACTUAL_COST_USD - stats.AVG_COST) / NULLIF(stats.STDDEV_COST, 0)) >
                         bp.ANOMALY_Z_SCORE_THRESHOLD THEN TRUE
                    WHEN ABS((ba.ACTUAL_COST_USD - prev_week.ACTUAL_COST_USD) / NULLIF(prev_week.ACTUAL_COST_USD, 0)) * 100 >
                         bp.ANOMALY_PCT_SPIKE_THRESHOLD THEN TRUE
                    ELSE FALSE
                END AS IS_ANOMALY
            FROM FINOPS_CONTROL_DB.BUDGET.FACT_BUDGET_ACTUALS ba
            JOIN FINOPS_CONTROL_DB.BUDGET.FACT_BUDGET_PLAN bp ON ba.BUDGET_ID = bp.BUDGET_ID
            LEFT JOIN (
                SELECT
                    BUDGET_ID,
                    AVG(ACTUAL_COST_USD) AS AVG_COST,
                    STDDEV(ACTUAL_COST_USD) AS STDDEV_COST
                FROM FINOPS_CONTROL_DB.BUDGET.FACT_BUDGET_ACTUALS
                WHERE ACTUAL_DATE BETWEEN DATEADD(DAY, -30, ?) AND DATEADD(DAY, -1, ?)
                GROUP BY BUDGET_ID
            ) stats ON ba.BUDGET_ID = stats.BUDGET_ID
            LEFT JOIN FINOPS_CONTROL_DB.BUDGET.FACT_BUDGET_ACTUALS prev_week
                ON ba.BUDGET_ID = prev_week.BUDGET_ID
                AND prev_week.ACTUAL_DATE = DATEADD(DAY, -7, ba.ACTUAL_DATE)
            WHERE ba.ACTUAL_DATE = ?
              AND bp.ENABLE_ANOMALY_DETECTION = TRUE
        ) AS source
        WHERE target.BUDGET_ID = source.BUDGET_ID
          AND target.ACTUAL_DATE = source.ACTUAL_DATE`;

        var detectStmt = snowflake.createStatement({
            sqlText: detectAnomaliesSql,
            binds: [P_CHECK_DATE, P_CHECK_DATE, P_CHECK_DATE]
        });
        var detectResult = detectStmt.execute();
        detectResult.next();
        result.rows_checked = detectResult.getColumnValue(1);

        // Create anomaly alerts
        var createAlertsSql = `
        INSERT INTO FINOPS_CONTROL_DB.BUDGET.FACT_BUDGET_ALERTS (
            BUDGET_ID, ENTITY_ID, PERIOD_ID, ALERT_TYPE, ALERT_SEVERITY,
            PCT_CONSUMED, ACTUAL_COST_USD, BUDGET_AMOUNT_USD,
            ALERT_MESSAGE, RECOMMENDATION, NOTIFICATION_RECIPIENTS
        )
        SELECT
            bp.BUDGET_ID,
            bp.ENTITY_ID,
            bp.PERIOD_ID,
            'ANOMALY' AS ALERT_TYPE,
            CASE
                WHEN ba.Z_SCORE > 3 OR ABS(ba.PCT_CHANGE_VS_LAST_WEEK) > 100 THEN 'HIGH'
                ELSE 'MEDIUM'
            END AS ALERT_SEVERITY,
            ba.PCT_CONSUMED,
            ba.ACTUAL_COST_USD,
            bp.BUDGET_USD,
            CONCAT(
                'Cost anomaly detected for ', e.ENTITY_NAME, '. ',
                'Daily cost: $', ROUND(ba.ACTUAL_COST_USD, 2), ' ',
                '(Z-score: ', ROUND(ba.Z_SCORE, 2), ', ',
                'Week-over-week change: ', ROUND(ba.PCT_CHANGE_VS_LAST_WEEK, 1), '%)'
            ) AS ALERT_MESSAGE,
            'Investigate unusual query patterns. Review FACT_QUERY_COST_HISTORY for expensive queries on this date.' AS RECOMMENDATION,
            bp.BUDGET_OWNER_EMAIL
        FROM FINOPS_CONTROL_DB.BUDGET.FACT_BUDGET_ACTUALS ba
        JOIN FINOPS_CONTROL_DB.BUDGET.FACT_BUDGET_PLAN bp ON ba.BUDGET_ID = bp.BUDGET_ID
        JOIN FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY e ON bp.ENTITY_ID = e.ENTITY_ID
        WHERE ba.ACTUAL_DATE = ?
          AND ba.IS_ANOMALY = TRUE
          AND NOT EXISTS (
              SELECT 1 FROM FINOPS_CONTROL_DB.BUDGET.FACT_BUDGET_ALERTS prev
              WHERE prev.BUDGET_ID = bp.BUDGET_ID
                AND prev.ALERT_TYPE = 'ANOMALY'
                AND prev.ALERT_TIMESTAMP >= DATEADD(HOUR, -12, CURRENT_TIMESTAMP())
          )`;

        var alertStmt = snowflake.createStatement({
            sqlText: createAlertsSql,
            binds: [P_CHECK_DATE]
        });
        var alertResult = alertStmt.execute();
        alertResult.next();
        result.anomaly_alerts_created = alertResult.getColumnValue(1);

        result.status = 'SUCCESS';
        return result;

    } catch (err) {
        result.status = 'ERROR';
        result.error_message = err.message;
        return result;
    }
$$;


-- =========================================================================
-- GRANT PERMISSIONS
-- =========================================================================
GRANT USAGE ON PROCEDURE SP_CHECK_BUDGETS(DATE) TO ROLE FINOPS_ANALYST_ROLE;
GRANT USAGE ON PROCEDURE SP_DETECT_ANOMALIES(DATE) TO ROLE FINOPS_ANALYST_ROLE;


-- =========================================================================
-- VERIFICATION QUERIES
-- =========================================================================

/*
-- Test: Check budgets for current date
CALL SP_CHECK_BUDGETS(CURRENT_DATE());

-- Test: Detect anomalies
CALL SP_DETECT_ANOMALIES(CURRENT_DATE());

-- Verify: Budget actuals
SELECT
    e.ENTITY_NAME,
    ba.ACTUAL_DATE,
    ba.ACTUAL_COST_USD,
    ba.CUMULATIVE_COST_MTD,
    ba.BUDGET_REMAINING_USD,
    ba.PCT_CONSUMED,
    ba.DAILY_BURN_RATE,
    ba.PROJECTED_MONTH_END_COST,
    ba.IS_ON_TRACK,
    ba.IS_ANOMALY
FROM FINOPS_CONTROL_DB.BUDGET.FACT_BUDGET_ACTUALS ba
JOIN FINOPS_CONTROL_DB.BUDGET.FACT_BUDGET_PLAN bp ON ba.BUDGET_ID = bp.BUDGET_ID
JOIN FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY e ON bp.ENTITY_ID = e.ENTITY_ID
ORDER BY ba.ACTUAL_DATE DESC, e.ENTITY_NAME
LIMIT 20;

-- Verify: Recent alerts
SELECT
    a.ALERT_ID,
    e.ENTITY_NAME,
    a.ALERT_TYPE,
    a.ALERT_SEVERITY,
    a.ALERT_TIMESTAMP,
    a.PCT_CONSUMED,
    a.ACTUAL_COST_USD,
    a.BUDGET_AMOUNT_USD,
    a.ALERT_MESSAGE
FROM FINOPS_CONTROL_DB.BUDGET.FACT_BUDGET_ALERTS a
JOIN FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY e ON a.ENTITY_ID = e.ENTITY_ID
WHERE a.ALERT_TIMESTAMP >= DATEADD(DAY, -7, CURRENT_TIMESTAMP())
ORDER BY a.ALERT_TIMESTAMP DESC;
*/

/*
=============================================================================
  OBJECTS CREATED:
    - SP_CHECK_BUDGETS
    - SP_DETECT_ANOMALIES

  NEXT STEPS:
    → Script 03: Alert notification procedures
=============================================================================
*/

-- ===========================================================================
-- ===========================================================================
-- 03_ALERT_PROCEDURES
-- ===========================================================================
-- ===========================================================================


USE ROLE FINOPS_ADMIN_ROLE;
USE DATABASE FINOPS_CONTROL_DB;
USE SCHEMA PROCEDURES;
USE WAREHOUSE FINOPS_WH_ADMIN;

-- =========================================================================
-- PROCEDURE: SP_SEND_ALERT_NOTIFICATIONS
-- Sends pending alert notifications via configured channels
-- =========================================================================
CREATE OR REPLACE PROCEDURE SP_SEND_ALERT_NOTIFICATIONS()
RETURNS VARIANT
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER
AS
$$
    function executeSql(sqlText, binds) {
        var stmt = snowflake.createStatement({sqlText: sqlText, binds: binds || []});
        return stmt.execute();
    }

    var result = {
        procedure: 'SP_SEND_ALERT_NOTIFICATIONS',
        status: 'INITIALIZING',
        notifications_sent: 0
    };

    try {
        // Get pending alerts (not yet notified)
        var getPendingSql = `
        SELECT
            a.ALERT_ID,
            e.ENTITY_NAME,
            a.ALERT_TYPE,
            a.ALERT_SEVERITY,
            a.ALERT_MESSAGE,
            a.RECOMMENDATION,
            a.NOTIFICATION_RECIPIENTS
        FROM FINOPS_CONTROL_DB.BUDGET.FACT_BUDGET_ALERTS a
        JOIN FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY e ON a.ENTITY_ID = e.ENTITY_ID
        WHERE a.NOTIFICATION_SENT = FALSE
          AND a.IS_RESOLVED = FALSE
        ORDER BY a.ALERT_SEVERITY DESC, a.ALERT_TIMESTAMP DESC
        LIMIT 100`;

        var pendingRs = executeSql(getPendingSql, []);
        var alertsSent = 0;

        while (pendingRs.next()) {
            var alertId = pendingRs.getColumnValue('ALERT_ID');
            var entityName = pendingRs.getColumnValue('ENTITY_NAME');
            var alertType = pendingRs.getColumnValue('ALERT_TYPE');
            var alertMessage = pendingRs.getColumnValue('ALERT_MESSAGE');
            var recipients = pendingRs.getColumnValue('NOTIFICATION_RECIPIENTS');

            // Placeholder: In production, integrate with email/Slack API
            // For now, log the notification
            var logSql = `
            INSERT INTO FINOPS_CONTROL_DB.AUDIT.NOTIFICATION_LOG (
                ALERT_ID, NOTIFICATION_TYPE, RECIPIENTS, MESSAGE, STATUS
            ) VALUES (?, 'EMAIL', ?, ?, 'SENT')`;

            executeSql(logSql, [alertId, recipients, alertMessage]);

            // Mark alert as notified
            var updateSql = `
            UPDATE FINOPS_CONTROL_DB.BUDGET.FACT_BUDGET_ALERTS
            SET NOTIFICATION_SENT = TRUE,
                NOTIFICATION_CHANNEL = 'EMAIL',
                NOTIFICATION_SENT_AT = CURRENT_TIMESTAMP()
            WHERE ALERT_ID = ?`;

            executeSql(updateSql, [alertId]);
            alertsSent++;
        }

        result.notifications_sent = alertsSent;
        result.status = 'SUCCESS';
        return result;

    } catch (err) {
        result.status = 'ERROR';
        result.error_message = err.message;
        return result;
    }
$$;


-- =========================================================================
-- CREATE NOTIFICATION_LOG TABLE IF NOT EXISTS
-- =========================================================================
CREATE TABLE IF NOT EXISTS FINOPS_CONTROL_DB.AUDIT.NOTIFICATION_LOG (
    LOG_ID          NUMBER AUTOINCREMENT PRIMARY KEY,
    ALERT_ID        NUMBER,
    NOTIFICATION_TYPE VARCHAR(50),
    RECIPIENTS      VARCHAR(2000),
    MESSAGE         VARCHAR(5000),
    STATUS          VARCHAR(20),
    SENT_AT         TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);


-- =========================================================================
-- VIEW: VW_CURRENT_BUDGET_STATUS
-- Real-time budget status for all active budgets
-- =========================================================================
CREATE OR REPLACE VIEW FINOPS_CONTROL_DB.MONITORING.VW_CURRENT_BUDGET_STATUS AS
SELECT
    e.ENTITY_NAME,
    e.ENTITY_TYPE,
    p.PERIOD_NAME,
    bp.BUDGET_USD,
    ba.CUMULATIVE_COST_MTD AS ACTUAL_COST_USD,
    ba.BUDGET_REMAINING_USD,
    ba.PCT_CONSUMED,
    ba.DAILY_BURN_RATE,
    ba.DAYS_REMAINING_IN_PERIOD,
    ba.PROJECTED_MONTH_END_COST,
    CASE
        WHEN ba.PROJECTED_MONTH_END_COST > bp.BUDGET_USD THEN ba.PROJECTED_MONTH_END_COST - bp.BUDGET_USD
        ELSE 0
    END AS PROJECTED_OVERAGE_USD,
    ba.IS_ON_TRACK,
    CASE
        WHEN ba.PCT_CONSUMED >= bp.THRESHOLD_BLOCK_PCT THEN 'BLOCK'
        WHEN ba.PCT_CONSUMED >= bp.THRESHOLD_CRITICAL_PCT THEN 'CRITICAL'
        WHEN ba.PCT_CONSUMED >= bp.THRESHOLD_WARNING_PCT THEN 'WARNING'
        ELSE 'OK'
    END AS BUDGET_STATUS,
    bp.BUDGET_OWNER_NAME,
    bp.BUDGET_OWNER_EMAIL,
    ba.ACTUAL_DATE AS LAST_UPDATED
FROM FINOPS_CONTROL_DB.BUDGET.FACT_BUDGET_PLAN bp
JOIN FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY e ON bp.ENTITY_ID = e.ENTITY_ID
JOIN FINOPS_CONTROL_DB.BUDGET.DIM_BUDGET_PERIOD p ON bp.PERIOD_ID = p.PERIOD_ID
LEFT JOIN FINOPS_CONTROL_DB.BUDGET.FACT_BUDGET_ACTUALS ba
    ON bp.BUDGET_ID = ba.BUDGET_ID
    AND ba.ACTUAL_DATE = (
        SELECT MAX(ACTUAL_DATE)
        FROM FINOPS_CONTROL_DB.BUDGET.FACT_BUDGET_ACTUALS
        WHERE BUDGET_ID = bp.BUDGET_ID
    )
WHERE bp.STATUS = 'ACTIVE'
  AND CURRENT_DATE() BETWEEN p.PERIOD_START_DATE AND p.PERIOD_END_DATE;


-- =========================================================================
-- VIEW: VW_BUDGET_ALERTS_SUMMARY
-- Summary of recent budget alerts
-- =========================================================================
CREATE OR REPLACE VIEW FINOPS_CONTROL_DB.MONITORING.VW_BUDGET_ALERTS_SUMMARY AS
SELECT
    e.ENTITY_NAME,
    a.ALERT_TYPE,
    a.ALERT_SEVERITY,
    a.ALERT_TIMESTAMP,
    a.PCT_CONSUMED,
    a.ACTUAL_COST_USD,
    a.BUDGET_AMOUNT_USD,
    a.ALERT_MESSAGE,
    a.RECOMMENDATION,
    a.NOTIFICATION_SENT,
    a.IS_RESOLVED,
    a.RESOLVED_AT
FROM FINOPS_CONTROL_DB.BUDGET.FACT_BUDGET_ALERTS a
JOIN FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY e ON a.ENTITY_ID = e.ENTITY_ID
WHERE a.ALERT_TIMESTAMP >= DATEADD(DAY, -30, CURRENT_TIMESTAMP())
ORDER BY a.ALERT_TIMESTAMP DESC;


-- =========================================================================
-- GRANT PERMISSIONS
-- =========================================================================
GRANT USAGE ON PROCEDURE SP_SEND_ALERT_NOTIFICATIONS() TO ROLE FINOPS_ADMIN_ROLE;
GRANT SELECT ON VIEW FINOPS_CONTROL_DB.MONITORING.VW_CURRENT_BUDGET_STATUS TO ROLE FINOPS_ANALYST_ROLE;
GRANT SELECT ON VIEW FINOPS_CONTROL_DB.MONITORING.VW_BUDGET_ALERTS_SUMMARY TO ROLE FINOPS_ANALYST_ROLE;


-- =========================================================================
-- VERIFICATION QUERIES
-- =========================================================================

/*
-- Test: Send pending notifications
CALL SP_SEND_ALERT_NOTIFICATIONS();

-- Verify: Current budget status
SELECT * FROM FINOPS_CONTROL_DB.MONITORING.VW_CURRENT_BUDGET_STATUS
ORDER BY PCT_CONSUMED DESC;

-- Verify: Recent alerts
SELECT * FROM FINOPS_CONTROL_DB.MONITORING.VW_BUDGET_ALERTS_SUMMARY
WHERE ALERT_TIMESTAMP >= DATEADD(DAY, -7, CURRENT_TIMESTAMP())
ORDER BY ALERT_SEVERITY DESC, ALERT_TIMESTAMP DESC;
*/

/*
=============================================================================
  OBJECTS CREATED:
    - SP_SEND_ALERT_NOTIFICATIONS
    - VW_CURRENT_BUDGET_STATUS
    - VW_BUDGET_ALERTS_SUMMARY
    - NOTIFICATION_LOG table

  NEXT STEPS:
    → Module 05: BI Tool Detection
=============================================================================
*/



/*
#############################################################################
  MODULE 04 COMPLETE!

  Objects Created:
    - Tables: BUDGET_DEFINITIONS, BUDGET_VS_ACTUAL, BUDGET_ALERT_HISTORY
    - Procedures: SP_CHECK_BUDGETS, SP_SEND_BUDGET_ALERTS, SP_FORECAST_COSTS

  Next: FINOPS - Module 05 (BI Tool Detection)
#############################################################################
*/
