# OPERATIONAL RUNBOOK

## E-Commerce Analytics Platform — Incident Response Guide

---

## ALERT ROUTING

| Severity | Channel | Response SLA | Escalation |
|----------|---------|-------------|------------|
| **P1 — Pipeline down** | Slack #data-alerts + PagerDuty | 15 min | Lead Engineer → CTO |
| **P2 — Data quality failure** | Slack #data-alerts | 1 hour | On-call → Lead Engineer |
| **P3 — SLA breach** | Slack #data-alerts | 30 min | On-call investigates |
| **P4 — Cost warning** | Slack #data-costs | Next business day | Lead reviews |

---

## COMMON INCIDENTS

### 1. Airflow DAG Failure: Postgres Extraction Timeout

**Symptom:** `extract_postgres_orders` task fails with `ConnectionTimeout` or `OperationalError`

**Likely Causes:**
- Source PostgreSQL database under heavy load
- Long-running locks from the application
- Network connectivity issue between Airflow and Postgres

**Resolution:**
1. Check Airflow task logs for the specific error message
2. Test connectivity: `psql -h <host> -U postgres -d ecommerce_source -c "SELECT 1"`
3. Check Postgres active locks: `SELECT * FROM pg_locks WHERE granted = FALSE;`
4. If transient: the retry policy (2 retries, 5 min delay) should auto-recover
5. If persistent: contact the application team to investigate Postgres load

**Prevention:** Add connection timeout to `psycopg2.connect(connect_timeout=30)`

---

### 2. Snowflake COPY INTO Error: Schema Mismatch

**Symptom:** `COPY INTO RAW_ORDERS` fails with `Number of columns in file does not match`

**Likely Cause:** A column was added/removed in the source PostgreSQL table

**Resolution:**
1. Compare source schema: `\d orders` in psql
2. Compare target schema: `DESC TABLE ECOMMERCE_RAW.POSTGRES.RAW_ORDERS` in Snowflake
3. If new column added: `ALTER TABLE RAW_ORDERS ADD COLUMN new_col <type>;`
4. If column removed: Leave the Snowflake column (NULLs for old column are fine)
5. Update the Parquet extraction to include/exclude the changed column
6. Re-run the extraction task

**Prevention:** Add schema drift detection to the extraction script

---

### 3. dbt Test Failure: Unique Test on stg_customers

**Symptom:** `dbt test` fails with `Failure in test unique_stg_customers_customer_id`

**Likely Cause:** Duplicate customers in the source system (same customer_id, multiple rows)

**Resolution:**
1. Run: `SELECT customer_id, COUNT(*) FROM ECOMMERCE_RAW.POSTGRES.RAW_CUSTOMERS GROUP BY 1 HAVING COUNT(*) > 1;`
2. If duplicates exist in RAW: the deduplication logic in `stg_customers.sql` should handle it (ROW_NUMBER by updated_at DESC, keep latest)
3. If the dedup isn't working: check the `stg_customers.sql` model for the correct window function
4. If the source is genuinely sending duplicates: investigate upstream

**Prevention:** Source freshness check + row count reconciliation in the DAG

---

### 4. Stripe API 429: Rate Limit Exceeded

**Symptom:** `extract_stripe_payments` fails with HTTP 429

**Likely Cause:** Too many API requests in a short period (Stripe limit: 100 req/sec for test mode, 25 req/sec recommended)

**Resolution:**
1. The retry handler should auto-recover with exponential backoff
2. If persistent: reduce `batch_size` in config (100 → 50)
3. Check Stripe dashboard for current rate limit status
4. If running in test mode: Stripe test mode has stricter limits

**Prevention:** Already handled by `retry_on_rate_limit` decorator. Ensure `requests_per_second` config is set conservatively.

---

### 5. Resource Monitor: Warehouse Suspended

**Symptom:** Queries fail with `Warehouse LOADING_WH is suspended`

**Likely Cause:** Monthly credit limit hit the 100% threshold

**Resolution:**
1. Check: `SHOW RESOURCE MONITORS;` — see which monitor triggered
2. Determine if the usage spike is legitimate or from a runaway query
3. If legitimate: increase the credit quota for the remainder of the month
   ```sql
   ALTER RESOURCE MONITOR LOADING_MONITOR SET CREDIT_QUOTA = 75;
   ```
4. If runaway query: identify and kill it
   ```sql
   SELECT QUERY_ID, WAREHOUSE_NAME, TOTAL_ELAPSED_TIME, QUERY_TEXT
   FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY())
   WHERE EXECUTION_STATUS = 'RUNNING' ORDER BY START_TIME;

   SELECT SYSTEM$CANCEL_QUERY('<query_id>');
   ```

**Prevention:** Set warning alerts at lower thresholds. Review top queries weekly.

---

### 6. Dashboard Shows Stale Data

**Symptom:** Streamlit dashboard shows yesterday's (or older) data

**Likely Causes:**
- Airflow DAG didn't run (scheduler issue)
- DAG ran but failed silently
- dbt models succeeded but dashboard is reading from a cached query

**Resolution:**
1. Check Airflow UI: was today's DAG run successful?
2. Check Snowflake: `SELECT MAX(date) FROM ECOMMERCE_ANALYTICS.MARTS.FCT_DAILY_REVENUE;`
3. If DAG didn't run: trigger manually from Airflow UI
4. If data is current in Snowflake but stale in dashboard: clear Streamlit cache (refresh with Ctrl+F5 or restart app)
5. Check if the REPORTING_WH is suspended (see #5 above)

**Prevention:** Add a data freshness check to the dashboard itself (show "Last updated: X" prominently)

---

### 7. dbt Run Fails: Insufficient Permissions

**Symptom:** `dbt run` fails with `SQL access control error: Insufficient privileges`

**Likely Cause:** The SVC_ECOMMERCE_DBT user's role doesn't have the required grants

**Resolution:**
1. Check which specific model failed and which table/view it's trying to create
2. Verify grants:
   ```sql
   SHOW GRANTS TO ROLE ECOMMERCE_TRANSFORMER;
   ```
3. Common fix: FUTURE grants weren't applied
   ```sql
   GRANT ALL ON FUTURE TABLES IN SCHEMA ECOMMERCE_ANALYTICS.MARTS TO ROLE ECOMMERCE_TRANSFORMER;
   ```
4. Re-run `rbac_setup.sql` to reapply all grants

**Prevention:** Test dbt with the service account role (not SYSADMIN) during development

---

## USEFUL DIAGNOSTIC QUERIES

```sql
-- Current running queries
SELECT QUERY_ID, USER_NAME, WAREHOUSE_NAME,
       DATEDIFF('second', START_TIME, CURRENT_TIMESTAMP()) AS RUNNING_SECONDS,
       LEFT(QUERY_TEXT, 200)
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY_BY_WAREHOUSE())
WHERE EXECUTION_STATUS = 'RUNNING';

-- Recent failures (last 24h)
SELECT QUERY_ID, USER_NAME, ERROR_CODE, ERROR_MESSAGE, START_TIME
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE START_TIME >= DATEADD('hour', -24, CURRENT_TIMESTAMP())
  AND EXECUTION_STATUS = 'FAIL'
ORDER BY START_TIME DESC
LIMIT 20;

-- Current warehouse status
SHOW WAREHOUSES LIKE '%_WH';

-- Resource monitor status
SHOW RESOURCE MONITORS;

-- Current sessions
SELECT CURRENT_USER(), CURRENT_ROLE(), CURRENT_WAREHOUSE(), CURRENT_DATABASE();
```

---

*Keep this runbook updated as new failure modes are discovered. Review quarterly.*
