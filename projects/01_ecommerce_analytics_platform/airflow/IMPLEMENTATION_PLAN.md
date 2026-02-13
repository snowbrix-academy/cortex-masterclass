# MODULE 4: ORCHESTRATION (Airflow)

## Apache Airflow DAG Orchestration for the E-Commerce Analytics Platform

**Video Segment:** 2:10 - 2:45 (35 minutes)
**Git Tag:** `v0.6-airflow`

---

## OVERVIEW

This module wires together everything built in Modules 1-3 into a single, automated, observable pipeline. Apache Airflow orchestrates:

1. **Six parallel data extractions** (Postgres, Stripe, CSV)
2. **Sequential dbt transformations** (staging -> intermediate -> marts)
3. **dbt test suite execution** (data quality gate)
4. **Slack notifications** (success/failure/SLA breach)

We use Airflow because:

- It is the industry standard for batch orchestration
- It provides a visual DAG graph, task-level retries, SLA monitoring, and an alerting framework
- Docker Compose gives us a reproducible local environment identical to production
- The TaskFlow API (Airflow 2.x) simplifies Python-native task definitions

---

## SUBMODULE 4.1: AIRFLOW SETUP WITH DOCKER

**Files:** Root `docker-compose.yml` (already built), `airflow/Dockerfile`

### What Gets Built

A custom Airflow Docker image that extends the official `apache/airflow:2.8.1-python3.11` image with all project-specific Python dependencies pre-installed.

### Architecture

```
docker-compose.yml (root)
    |
    +-- postgres-source       (e-commerce source DB, port 5432)
    +-- postgres-airflow      (Airflow metadata DB, port 5433)
    +-- airflow-webserver     (UI on port 8080)
    +-- airflow-scheduler     (triggers DAG runs)
    +-- airflow-init          (one-time DB init + admin user creation)
```

### Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| LocalExecutor (not Celery) | Single-machine dev environment. Celery adds Redis/RabbitMQ complexity for no benefit at this scale. |
| Custom Dockerfile | We need dbt-core, dbt-snowflake, and our ingestion dependencies inside the Airflow container. |
| Volume mounts for DAGs/plugins | Live code reload during development -- no image rebuild needed for DAG changes. |
| Ingestion code mounted at `/opt/airflow/ingestion` | The DAG imports and calls ingestion modules directly. No code duplication. |
| dbt project mounted at `/opt/airflow/dbt_ecommerce` | BashOperator runs `dbt run` against the mounted project directory. |

### Dockerfile Strategy

```
apache/airflow:2.8.1-python3.11   (base image)
    |
    +-- pip install dbt-core, dbt-snowflake
    +-- pip install snowflake-connector-python
    +-- pip install psycopg2-binary, stripe, requests
    +-- pip install pandas, pyarrow, tenacity
    +-- pip install python-dotenv
```

We pin every dependency version for reproducibility. The `--no-cache-dir` flag keeps the image small.

---

## SUBMODULE 4.2: CONNECTION CONFIGURATION

**Method:** Environment variables passed through `docker-compose.yml`

### Connections Required

| Connection | Method | Variables |
|------------|--------|-----------|
| Snowflake | Env vars read by `ingestion/config.py` | `SNOWFLAKE_ACCOUNT`, `SNOWFLAKE_USER`, `SNOWFLAKE_PASSWORD`, `SNOWFLAKE_ROLE`, `SNOWFLAKE_WAREHOUSE` |
| PostgreSQL (source) | Docker network hostname | `POSTGRES_HOST=postgres-source`, `POSTGRES_PORT=5432` |
| Stripe API | Env var | `STRIPE_API_KEY` |
| Slack Webhook | Env var | `SLACK_WEBHOOK_URL` |

### Why Environment Variables Instead of Airflow Connections UI

For this project, all connectors are custom Python scripts (not Airflow providers). They read credentials from `os.environ` via `ingestion/config.py`. Using Airflow's built-in Connection objects would add unnecessary indirection since we are not using provider-based operators (e.g., SnowflakeOperator).

The `.env` file at the project root is the single source of truth. Docker Compose passes these through to all Airflow containers via the `x-airflow-common` anchor.

### Security Notes

- The `.env` file is in `.gitignore` and never committed
- In production, use a secrets backend (AWS Secrets Manager, HashiCorp Vault)
- The Fernet key (`AIRFLOW__CORE__FERNET_KEY`) encrypts Airflow's internal connection store

---

## SUBMODULE 4.3: MASTER DAG DESIGN

**File:** `dags/ecommerce_master_dag.py`

### DAG Structure

```
ecommerce_master_dag (Schedule: Daily at 06:00 UTC, SLA: 30 min)
|
|  [PHASE 1: EXTRACTION — parallel]
|
+-- extract_postgres_orders --------+
+-- extract_postgres_customers -----+
+-- extract_postgres_products ------+--> all_extractions_complete
+-- extract_postgres_order_items ---+
+-- extract_stripe_charges ---------+
+-- load_csv_marketing -------------+
                                    |
                                    v
|  [PHASE 2: TRANSFORMATION — sequential]
|
+-- dbt_run_staging
|       |
|       v
+-- dbt_run_intermediate
|       |
|       v
+-- dbt_run_marts
|       |
|       v
+-- dbt_test_all
        |
        v
|  [PHASE 3: NOTIFICATION]
|
+-- notify_success
```

### Task Dependency Rationale

| Dependency | Why |
|------------|-----|
| 6 extractions run in parallel | They are independent data sources. Parallel execution reduces wall-clock time from ~15 min to ~5 min. |
| `all_extractions_complete` gate | Ensures ALL raw data is loaded before dbt starts. A partial dbt run on stale data produces incorrect results. |
| Staging before intermediate before marts | dbt model dependencies require this order. Staging cleans raw data; intermediate joins; marts aggregate. |
| dbt test after dbt run | Tests validate the output of the full transformation pipeline. Running tests on stale models is meaningless. |
| `notify_success` at the end | Confirms the full pipeline completed. Fires only if every upstream task succeeded. |
| `on_failure_callback` on every task | Fires Slack alert immediately when any task fails, without waiting for the full DAG to finish. |

### Task Implementation Details

| Task ID | Operator | What It Does |
|---------|----------|--------------|
| `extract_postgres_orders` | PythonOperator | Calls `PostgresExtractor.extract_table()` for the `orders` table config |
| `extract_postgres_customers` | PythonOperator | Calls `PostgresExtractor.extract_table()` for the `customers` table config |
| `extract_postgres_products` | PythonOperator | Calls `PostgresExtractor.extract_table()` for the `products` table config |
| `extract_postgres_order_items` | PythonOperator | Calls `PostgresExtractor.extract_table()` for the `order_items` table config |
| `extract_stripe_charges` | PythonOperator | Calls `StripeConnector.load_charges()` |
| `load_csv_marketing` | PythonOperator | Calls `CsvLoader.run()` |
| `all_extractions_complete` | EmptyOperator | Join point -- no logic, just a dependency anchor |
| `dbt_run_staging` | BashOperator | `cd /opt/airflow/dbt_ecommerce && dbt run --select staging` |
| `dbt_run_intermediate` | BashOperator | `cd /opt/airflow/dbt_ecommerce && dbt run --select intermediate` |
| `dbt_run_marts` | BashOperator | `cd /opt/airflow/dbt_ecommerce && dbt run --select marts` |
| `dbt_test_all` | BashOperator | `cd /opt/airflow/dbt_ecommerce && dbt test` |
| `notify_success` | PythonOperator | Calls `send_slack_alert(context, "success")` |

---

## SUBMODULE 4.4: SLACK ALERTING

**File:** `plugins/slack_alert.py`

### What Gets Built

A reusable Slack notification helper that sends formatted messages to a Slack channel via incoming webhook.

### Message Format

**Success (green)**:
```
[SUCCESS] ecommerce_master_dag
Task: notify_success
Execution Date: 2024-01-15T06:00:00+00:00
Duration: 12m 34s
Log: <link to Airflow task log>
```

**Failure (red)**:
```
[FAILURE] ecommerce_master_dag
Task: extract_postgres_orders
Execution Date: 2024-01-15T06:00:00+00:00
Duration: 2m 15s
Exception: Connection refused to postgres-source:5432
Log: <link to Airflow task log>
```

### Implementation

- Uses Slack's Block Kit API for rich formatting
- Color-coded attachments: green (#36a64f) for success, red (#ff0000) for failure
- Includes task duration calculated from `context["task_instance"]`
- Includes direct link to the task log in the Airflow UI
- Reads `SLACK_WEBHOOK_URL` from environment variables
- Gracefully handles missing webhook URL (logs warning instead of crashing the DAG)

---

## SUBMODULE 4.5: SLA MONITORING

**Integrated into:** `dags/ecommerce_master_dag.py`

### SLA Definitions

| Scope | SLA | Rationale |
|-------|-----|-----------|
| Full DAG | 30 minutes | The entire pipeline (extract + transform + test) should complete within 30 min. If it exceeds this, downstream dashboards will show stale data. |
| Individual extraction tasks | 10 minutes each | A single source extraction taking >10 min indicates a problem (source DB overloaded, network issue, Stripe rate limiting). |
| dbt run (all layers) | 15 minutes total | Snowflake should process staging + intermediate + marts in under 15 min with the TRANSFORMING_WH warehouse. |
| dbt test | 5 minutes | Tests are lightweight queries. >5 min means a test is scanning too much data. |

### SLA Breach Handling

When an SLA is breached, Airflow:

1. Records the breach in the Airflow metadata database
2. Triggers the `sla_miss_callback` function defined on the DAG
3. The callback calls `send_slack_alert()` with status `"sla_breach"` and the breach details
4. The task continues running (SLA breach does NOT kill the task)

### Why 30 Minutes

- Extractions: ~5 min (parallel)
- dbt staging: ~2 min
- dbt intermediate: ~3 min
- dbt marts: ~5 min
- dbt test: ~2 min
- Overhead (scheduling, container startup): ~3 min
- **Total expected: ~20 min** with 50% buffer = 30 min SLA

---

## SUBMODULE 4.6: ERROR HANDLING AND RETRY POLICIES

**Integrated into:** `dags/ecommerce_master_dag.py`

### Retry Strategy Table

| Task Type | Retries | Delay Between | Backoff | Rationale |
|-----------|---------|---------------|---------|-----------|
| Postgres extraction | 2 | 5 min | Fixed | Source DB might be temporarily overloaded. 5 min is enough for a connection pool reset. |
| Stripe extraction | 2 | 5 min | Fixed | Rate limits (429) are already handled in-code with exponential backoff. DAG-level retry handles broader failures. |
| CSV loading | 2 | 5 min | Fixed | File staging failures are usually transient network issues. |
| dbt run (any layer) | 2 | 5 min | Fixed | Snowflake warehouse might be suspended or queued. Retry gives it time to resume. |
| dbt test | 1 | 3 min | Fixed | Tests should be deterministic. If they fail, it is likely a real data quality issue, not transient. One retry to rule out Snowflake hiccups. |
| Slack notification | 0 | N/A | N/A | Notification failures should not block the pipeline or trigger cascading retries. |

### Error Isolation Strategy

Each extraction task is independent. If `extract_postgres_orders` fails:

1. Its `on_failure_callback` fires a Slack alert immediately
2. Airflow retries the task up to 2 times with 5-minute delays
3. If all retries fail, the task is marked as `failed`
4. `all_extractions_complete` will NOT trigger (it requires all upstream tasks to succeed)
5. dbt tasks will be skipped (no partial transformations on incomplete data)
6. The DAG run is marked as `failed`

This prevents the dangerous scenario of running dbt on partial raw data, which would produce silently incorrect mart tables.

### Failure Callback Chain

```
Task fails
    |
    v
on_failure_callback fires
    |
    v
send_slack_alert(context, "failure")
    |
    v
Airflow retry policy kicks in (if retries remaining)
    |
    +-- Retry succeeds --> task marked success, pipeline continues
    |
    +-- All retries exhausted --> task marked failed
            |
            v
        Downstream tasks skipped
            |
            v
        DAG marked failed
```

---

## DAG PARAMETERS SUMMARY

```python
default_args = {
    "owner": "snowbrix",
    "depends_on_past": False,
    "email_on_failure": False,        # We use Slack, not email
    "email_on_retry": False,
    "retries": 2,
    "retry_delay": timedelta(minutes=5),
    "on_failure_callback": slack_failure_alert,
    "execution_timeout": timedelta(minutes=30),
}

dag = DAG(
    dag_id="ecommerce_master_dag",
    default_args=default_args,
    description="End-to-end E-Commerce analytics pipeline: Extract -> Transform -> Test -> Notify",
    schedule_interval="0 6 * * *",    # Daily at 06:00 UTC
    start_date=datetime(2024, 1, 1),
    catchup=False,
    max_active_runs=1,
    tags=["ecommerce", "production", "daily"],
    sla_miss_callback=slack_sla_alert,
)
```

---

## FILES IN THIS MODULE

```
airflow/
+-- IMPLEMENTATION_PLAN.md          <-- You are here
+-- Dockerfile                      <-- Custom Airflow image with dbt + ingestion deps
|
+-- dags/
|   +-- ecommerce_master_dag.py     <-- Master orchestration DAG
|
+-- plugins/
|   +-- slack_alert.py              <-- Slack notification helper
|
+-- logs/                           <-- Airflow task logs (gitignored, volume-mounted)
```

---

## VERIFICATION CHECKLIST

After deploying the Airflow module, verify each item:

### Infrastructure

- [ ] `docker-compose up -d` starts all 5 containers without errors
- [ ] Airflow UI accessible at `http://localhost:8080` (admin/admin)
- [ ] Airflow scheduler is healthy (`docker-compose logs airflow-scheduler`)
- [ ] The `ecommerce_master_dag` appears in the Airflow UI DAGs list

### Connections

- [ ] Environment variables are passed through (check Airflow container: `docker exec airflow-scheduler env | grep SNOWFLAKE`)
- [ ] PostgreSQL source is reachable from Airflow container (`docker exec airflow-scheduler python -c "import psycopg2; psycopg2.connect(host='postgres-source', dbname='ecommerce_source', user='postgres', password='postgres')"`)
- [ ] Snowflake credentials are valid (trigger a manual DAG run and check extraction logs)

### DAG Execution

- [ ] Unpause the DAG in the Airflow UI
- [ ] Trigger a manual run (play button)
- [ ] All 6 extraction tasks run in parallel (check Gantt chart in UI)
- [ ] `all_extractions_complete` triggers only after all 6 extractions succeed
- [ ] dbt tasks run sequentially: staging -> intermediate -> marts -> test
- [ ] `notify_success` fires at the end
- [ ] Full DAG completes within 30 minutes (SLA)
- [ ] DAG run status is green (success)

### Alerting

- [ ] Trigger a failure (e.g., stop postgres-source container mid-run)
- [ ] Slack failure alert fires with correct DAG name, task name, and error message
- [ ] Complete a successful run and verify Slack success alert fires
- [ ] Simulate an SLA breach (set SLA to 1 second) and verify Slack SLA alert fires

### Retry Behavior

- [ ] Stop postgres-source during extraction, verify Airflow retries after 5 minutes
- [ ] After restarting postgres-source, verify the retry succeeds
- [ ] Confirm retry count shows "1 of 2" in the Airflow UI task details

---

## TROUBLESHOOTING

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| DAG not appearing in UI | Python syntax error in DAG file | Check `docker-compose logs airflow-scheduler` for import errors |
| "Module not found: ingestion" | Volume mount not configured | Verify `./ingestion:/opt/airflow/ingestion` in `docker-compose.yml` |
| dbt command not found | Dockerfile dependencies not installed | Rebuild: `docker-compose build --no-cache` |
| Slack alerts not firing | `SLACK_WEBHOOK_URL` not set | Add to `.env` file and restart containers |
| "Connection refused" to postgres-source | Container not on same Docker network | Both services must be in the same `docker-compose.yml` |
| SLA breach on first run | Full load takes longer than incremental | Expected on first run. SLA is calibrated for daily incremental loads. |

---

*Snowbrix Academy | Production-Grade Data Engineering. No Fluff.*
