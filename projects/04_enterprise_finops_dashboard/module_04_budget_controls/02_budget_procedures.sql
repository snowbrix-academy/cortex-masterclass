/*
=============================================================================
  MODULE 04 : BUDGET CONTROLS
  SCRIPT 02 : Budget Monitoring Procedures
=============================================================================
  SNOWBRIX ACADEMY — Enterprise FinOps Dashboard for Snowflake

  LEARNING OBJECTIVES:
    1. Implement budget vs actual comparison logic
    2. Calculate burn rate and forecast to period-end
    3. Detect budget threshold breaches (70%, 85%, 95%)
    4. Implement anomaly detection (z-score and spike detection)
    5. Generate actionable budget alerts

  PREREQUISITES:
    - Module 04, Script 01 completed (budget tables)
    - FACT_CHARGEBACK_DAILY populated with actual costs

  ESTIMATED TIME: 15 minutes

=============================================================================
*/

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
