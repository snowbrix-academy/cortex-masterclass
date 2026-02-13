/*
=============================================================================
  MODULE 04 : BUDGET CONTROLS
  SCRIPT 03 : Alert Notification Procedures
=============================================================================
  SNOWBRIX ACADEMY — Enterprise FinOps Dashboard for Snowflake

  LEARNING OBJECTIVES:
    1. Implement alert notification system
    2. Support multiple notification channels (email, Slack, etc.)
    3. Track notification delivery status
    4. Create budget status views for dashboards

  PREREQUISITES:
    - Module 04, Scripts 01-02 completed

  ESTIMATED TIME: 10 minutes

=============================================================================
*/

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
