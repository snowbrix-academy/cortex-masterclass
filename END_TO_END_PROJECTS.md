# SNOWBRIX ACADEMY — END-TO-END PROJECT SERIES

## Flagship Long-Form Content (1-5 Hours) | Version 1.0 | February 2026

---

## THE PHILOSOPHY

These are the videos that **define the channel**. Not 10-minute overviews. Not "intro to Snowflake" tutorials. These are full-build, zero-to-production projects where the viewer watches real infrastructure get created, break, get debugged, and go live.

**Why long-form projects matter:**

```
10-min videos     → "That was helpful"        → Viewer moves on
1-5 hour projects → "I built something real"   → Viewer is loyal for life
```

- YouTube rewards watch time. A 3-hour video with 30% retention = 54 minutes of watch time per viewer. That's 5x what a 10-minute video delivers.
- Long-form projects are the **#1 conversion tool for the Academy**. After watching someone build for 3 hours, the viewer thinks: "If the free content is this good, what's in the paid program?"
- These become **permanent SEO assets**. "Snowflake end-to-end project" and "Databricks real-time pipeline tutorial" are search queries that never stop.

### Release Cadence

- **1 flagship project per month** (in addition to the 2x/week regular cadence)
- Released on the **last Saturday of each month** at 8 AM EST
- Each project generates **8-12 Shorts**, **3-4 LinkedIn posts**, and **2-3 newsletter sections**

### Production Format

```
SINGLE VIDEO (1-3 hours)
├── No chapters skipped
├── All mistakes shown and debugged on camera
├── Timestamps every 5-10 min for navigation
├── GitHub repo linked with tagged commits matching video timestamps
└── Architecture diagram in description + pinned comment

MULTI-PART SERIES (3-5 hours total, split into 45-75 min episodes)
├── Each episode is self-contained but connected
├── Cliffhanger/preview at the end of each part
├── Playlist auto-created
├── GitHub repo with branches per episode (part-1, part-2, etc.)
└── Combined architecture diagram evolves across episodes
```

---

## TABLE OF CONTENTS

| # | Project | Duration | Level | Stack |
|---|---------|----------|-------|-------|
| 1 | [E-Commerce Analytics Platform on Snowflake](#project-1) | 3.5 hrs | Intermediate | Snowflake, dbt, Airflow, Python |
| 2 | [Real-Time Streaming Lakehouse on Databricks](#project-2) | 4 hrs | Advanced | Databricks, Spark Structured Streaming, Delta Lake, Kafka |
| 3 | [Legacy Oracle-to-Snowflake Migration](#project-3) | 5 hrs (4 parts) | Advanced | Oracle, Snowflake, Python, Terraform, dbt |
| 4 | [Snowflake + Databricks Hybrid Architecture](#project-4) | 4.5 hrs (3 parts) | Advanced | Snowflake, Databricks, Apache Iceberg, Airflow |
| 5 | [Cost Monitoring & FinOps Dashboard](#project-5) | 2 hrs | Intermediate | Snowflake, Python, Streamlit, Snowflake Cortex |
| 6 | [Data Quality Framework from Scratch](#project-6) | 2.5 hrs | Intermediate | Snowflake OR Databricks, Great Expectations, dbt tests, Python |
| 7 | [Multi-Tenant SaaS Data Platform](#project-7) | 5 hrs (4 parts) | Expert | Snowflake, dbt, Airflow, Terraform, RBAC |
| 8 | [ML Feature Store on Databricks](#project-8) | 3 hrs | Advanced | Databricks, MLflow, Delta Lake, Feature Store, Python |
| 9 | [CDC Pipeline: Postgres to Snowflake in Real-Time](#project-9) | 2.5 hrs | Intermediate | Debezium, Kafka, Snowpipe Streaming, Snowflake |
| 10 | [Full Data Mesh Implementation](#project-10) | 5 hrs (4 parts) | Expert | Databricks Unity Catalog, Terraform, dbt, Airflow |
| 11 | [Reverse ETL & Operational Analytics](#project-11) | 2 hrs | Intermediate | Snowflake, Census/Hightouch (build our own), Python, APIs |
| 12 | [Disaster Recovery & High Availability](#project-12) | 3 hrs | Advanced | Snowflake (multi-region), Databricks, Terraform, Failover Testing |

---

<a id="project-1"></a>
## PROJECT 1: E-Commerce Analytics Platform on Snowflake

### "Build a Production E-Commerce Data Warehouse from Scratch"

**Duration:** 3 hours 30 minutes (single video)
**Level:** Intermediate
**Best For:** Data engineers with 1-3 years experience wanting to see a complete warehouse build

---

### The Scenario

> _"A mid-size e-commerce company (500K orders/month) is running analytics off their production Postgres database. Queries are slow, dashboards are broken, and the CEO wants real-time revenue tracking. They've bought Snowflake. Now what?"_

This is the most common scenario in the industry. Every viewer will recognize it.

### Tech Stack

```
SOURCE SYSTEMS                    PIPELINE                         WAREHOUSE
─────────────                    ────────                         ─────────
PostgreSQL (orders, users)   →   Python ingestion scripts    →   Snowflake
                                 (Airbyte alternative)            │
Stripe API (payments)        →   Airflow orchestration       →   dbt transformations
                                                                  │
Google Sheets (marketing)    →   Manual CSV loads            →   Dimensional model
                                                                  │
                                                              Streamlit dashboard
```

### Chapter-by-Chapter Breakdown

```
PART 1: THE ARCHITECTURE (0:00 - 0:25)
───────────────────────────────────────
0:00  Cold Open — "This company is losing $50K/month in analytics downtime.
       We're going to build their entire data warehouse in 3 hours."
0:03  The business problem — what the CEO actually asked for
0:08  Architecture diagram — draw it live, explain every decision
0:12  Why Snowflake (and not Databricks) for this use case — honest tradeoff analysis
0:15  Snowflake account setup — from zero
       → Organization, account, admin user
       → Region selection and why it matters for cost
0:18  Warehouse strategy — create 3 warehouses (ingestion, transform, reporting)
       → Size each one differently, explain WHY
       → Set auto-suspend and auto-resume policies
0:22  Database + schema structure
       → RAW, STAGING, ANALYTICS (the three-layer pattern)
       → Why NOT to use a single database
0:25  CHECKPOINT: "We now have a clean Snowflake environment. Zero data. Let's fix that."

PART 2: DATA INGESTION (0:25 - 1:10)
─────────────────────────────────────
0:25  Set up source PostgreSQL database
       → Use Docker to spin up Postgres locally
       → Load sample e-commerce dataset (100K orders, 50K customers, 200 products)
       → Show the schema, explain the mess (as real source systems are messy)
0:35  Build Python ingestion script from scratch
       → NOT using Airbyte/Fivetran — build it manually to understand the problem
       → Connect to Postgres, extract with incremental logic
       → Load into Snowflake RAW layer using PUT + COPY INTO
       → Handle data types, NULLs, encoding issues LIVE
       → "This is the part Fivetran hides from you. You need to understand it."
0:50  Build Stripe API connector
       → Call Stripe sandbox API for payment data
       → Paginate through results
       → Handle rate limits and retries
       → Flatten nested JSON in Snowflake using LATERAL FLATTEN
       → "Every API is different. The pattern is always the same."
1:00  Handle the messy CSV load (Google Sheets marketing data)
       → Download as CSV
       → Stage in Snowflake (internal stage)
       → COPY INTO with error handling (ON_ERROR = 'CONTINUE')
       → Show what happens with bad data — debug a real parsing error
1:05  Create Snowflake Tasks for scheduling (then explain why we'll replace them)
       → Build a simple task chain
       → Show the limitations
       → "This is where most people stop. We're going to do better."
1:10  CHECKPOINT: "Raw data is flowing. It's ugly. It's untyped. It works. Now we transform."

PART 3: TRANSFORMATION WITH dbt (1:10 - 2:10)
───────────────────────────────────────────────
1:10  dbt project setup from scratch
       → dbt init, profiles.yml, Snowflake connection
       → Project structure: models/staging, models/intermediate, models/marts
       → "This structure isn't optional. It's the difference between a project
          that scales and one that collapses."
1:18  Build staging models
       → stg_orders.sql — clean, rename, cast types
       → stg_customers.sql — deduplicate, handle NULLs
       → stg_payments.sql — join Stripe data to order IDs
       → stg_products.sql — normalize categories
       → Show dbt run, watch it execute, debug a real error
1:30  Build intermediate models
       → int_order_items_enriched.sql — join orders + products + payments
       → int_customer_lifetime.sql — calculate LTV, first/last order, frequency
       → Explain ref() and why dependency management matters
       → "Delete this one model and watch 14 downstream models break.
          That's why we use dbt."
1:40  Build mart models (dimensional)
       → dim_customers — Type 2 SCD (show the full SCD implementation)
       → dim_products — with category hierarchy
       → dim_dates — generate a date spine from scratch
       → fct_orders — the grain, the measures, the foreign keys
       → fct_daily_revenue — pre-aggregated for dashboard performance
       → "This is the star schema. It's 30 years old. It still works better
          than anything else for analytics."
1:55  dbt tests + documentation
       → Add unique, not_null, relationships, accepted_values tests
       → Build a custom test: "no orders should have negative revenue"
       → Generate dbt docs, show the lineage graph
       → "If you skip testing, you'll find out your data is wrong
          from your CEO. Don't do that."
2:03  dbt macros + Jinja
       → Build a reusable macro for currency conversion
       → Build a macro for incremental timestamp logic
       → Show how DRY code works in dbt
2:10  CHECKPOINT: "Our warehouse has clean, tested, documented data.
       Now someone needs to actually look at it."

PART 4: ORCHESTRATION WITH AIRFLOW (2:10 - 2:45)
─────────────────────────────────────────────────
2:10  Why Airflow (and not Snowflake Tasks or dbt Cloud)
       → Honest comparison: cost, flexibility, complexity
       → "For this project, Airflow is overkill. For your next project, it won't be."
2:15  Airflow setup (local with Docker Compose)
       → docker-compose up — Airflow running
       → Create connections: Snowflake, Postgres, Stripe API
2:20  Build the master DAG
       → Task 1: Extract from Postgres → Snowflake RAW
       → Task 2: Extract from Stripe → Snowflake RAW
       → Task 3: dbt run (staging → intermediate → marts)
       → Task 4: dbt test
       → Task 5: Send Slack notification (success/failure)
       → Set schedule: daily at 6 AM UTC
2:30  Error handling + retries
       → What happens when Postgres is down? (Simulate it)
       → What happens when dbt test fails? (Break a model on purpose)
       → Retry policies, alerting, dead man's switches
       → "The DAG that works 99% of the time will ruin your weekend
          the 1% it doesn't. Build for failure."
2:38  SLA monitoring
       → Set a 30-min SLA on the full pipeline
       → Show what happens when SLA is breached
2:42  Deploy and monitor
       → Trigger a full run, watch it end to end
       → Check Snowflake query history — see every query dbt ran
2:45  CHECKPOINT: "Pipeline is automated, monitored, and alerting. Last step: make it visible."

PART 5: DASHBOARD + COST OPTIMIZATION (2:45 - 3:25)
────────────────────────────────────────────────────
2:45  Build a Streamlit dashboard (NOT Tableau/Looker — we build it)
       → Connect to Snowflake fct_daily_revenue
       → Revenue over time (line chart)
       → Customer LTV distribution (histogram)
       → Top products by revenue (bar chart)
       → Real-time order count (big number)
       → "Streamlit isn't a replacement for Looker. But it's free,
          it's code, and it ships in 20 minutes."
3:00  Cost optimization pass
       → Check Snowflake ACCOUNT_USAGE.QUERY_HISTORY
       → Find the most expensive queries we just ran
       → Right-size the warehouses (did we over-provision?)
       → Set up resource monitors with alerts
       → Calculate the monthly cost of this entire platform
       → "This platform costs $127/month to run. The company was spending
          $3,400/month on their old analytics. That's the ROI."
3:12  Security hardening
       → Create roles: LOADER, TRANSFORMER, ANALYST, ADMIN
       → Grant minimum permissions per role
       → Create service accounts (no personal credentials in pipelines)
       → Enable network policies
       → "If your pipeline uses your personal login, you have a security problem
          and a bus-factor problem."
3:20  Production checklist walkthrough
       → Go through a 15-point checklist (shown on screen)
       → What we built, what we'd add in Week 2, what we'd revisit in Month 3
3:25  FINAL SUMMARY + Soft CTA

OUTRO (3:25 - 3:30)
────────────────────
"You just built a production-grade e-commerce data warehouse.
Not a demo. Not a sandbox. Something you could hand to an analyst tomorrow.

Everything — every SQL file, every Python script, every Airflow DAG —
is in the GitHub repo linked below. Tagged commits match the timestamps
in this video.

This is how we build platforms for our clients. If you want to go deeper —
the Academy covers this exact workflow across 8 weeks, with code reviews
and architecture feedback. Link below.

That's how it works in production."
```

### GitHub Repository Structure

```
snowbrix-ecommerce-warehouse/
├── README.md                          # Architecture diagram + setup guide
├── docker-compose.yml                 # Postgres + Airflow local env
├── .env.example                       # Never commit real credentials
│
├── ingestion/
│   ├── postgres_extractor.py          # Incremental extraction script
│   ├── stripe_connector.py            # Stripe API → Snowflake
│   ├── csv_loader.py                  # Google Sheets CSV handler
│   └── utils/
│       ├── snowflake_client.py        # Reusable Snowflake connection
│       └── retry_handler.py           # Exponential backoff utility
│
├── dbt_ecommerce/
│   ├── dbt_project.yml
│   ├── profiles.yml.example
│   ├── models/
│   │   ├── staging/
│   │   │   ├── stg_orders.sql
│   │   │   ├── stg_customers.sql
│   │   │   ├── stg_payments.sql
│   │   │   └── stg_products.sql
│   │   ├── intermediate/
│   │   │   ├── int_order_items_enriched.sql
│   │   │   └── int_customer_lifetime.sql
│   │   └── marts/
│   │       ├── dim_customers.sql      # Type 2 SCD
│   │       ├── dim_products.sql
│   │       ├── dim_dates.sql          # Date spine generator
│   │       ├── fct_orders.sql
│   │       └── fct_daily_revenue.sql
│   ├── macros/
│   │   ├── currency_convert.sql
│   │   └── incremental_timestamp.sql
│   ├── tests/
│   │   └── assert_no_negative_revenue.sql
│   └── seeds/
│       └── currency_rates.csv
│
├── airflow/
│   ├── dags/
│   │   └── ecommerce_master_dag.py    # Full orchestration DAG
│   └── plugins/
│       └── slack_alert.py             # Failure notification
│
├── dashboard/
│   └── streamlit_app.py               # Revenue dashboard
│
├── infrastructure/
│   ├── snowflake_setup.sql            # Account, warehouses, databases, roles
│   └── resource_monitors.sql          # Cost alerting
│
└── docs/
    ├── architecture.png               # System diagram
    └── cost_analysis.md               # Monthly cost breakdown
```

### Git Tag Strategy (Matches Video Timestamps)

```
git tag v0.1-architecture       # 0:25 — Snowflake environment ready
git tag v0.2-ingestion          # 1:10 — All raw data loaded
git tag v0.3-dbt-staging        # 1:30 — Staging models complete
git tag v0.4-dbt-marts          # 2:03 — Full dimensional model
git tag v0.5-dbt-tested         # 2:10 — Tests + docs added
git tag v0.6-airflow            # 2:45 — Orchestration deployed
git tag v0.7-dashboard          # 3:00 — Streamlit dashboard live
git tag v1.0-production         # 3:25 — Cost optimized, secured, done
```

---

<a id="project-2"></a>
## PROJECT 2: Real-Time Streaming Lakehouse on Databricks

### "Build a Real-Time IoT Analytics Platform with Databricks Delta Lake"

**Duration:** 4 hours (single video)
**Level:** Advanced
**Best For:** Engineers moving from batch to streaming, Databricks-curious Snowflake users

---

### The Scenario

> _"A logistics company has 10,000 delivery vehicles with GPS sensors transmitting location, speed, and engine diagnostics every 5 seconds. They need real-time fleet monitoring, route optimization data, and daily operational reports. They've chosen Databricks."_

### Tech Stack

```
IOT SENSORS (simulated)  →  Kafka (Confluent Cloud)  →  Databricks
     │                                                      │
  Python generator                              Spark Structured Streaming
  10K events/sec                                      │
                                                 Delta Lake (Bronze → Silver → Gold)
                                                      │
                                              ┌───────┴───────┐
                                              │               │
                                         Real-Time       Databricks SQL
                                         Alerts          Dashboard
                                         (PagerDuty)     (Fleet Overview)
```

### Chapter-by-Chapter Breakdown

```
PART 1: THE ARCHITECTURE DECISION (0:00 - 0:30)
────────────────────────────────────────────────
0:00  Cold Open — live feed of simulated GPS data scrolling on screen
       "10,000 vehicles. 50,000 events per second. Zero tolerance for data loss.
        Let's build the system that handles this."
0:05  Why Databricks and NOT Snowflake for this use case
       → Snowflake Snowpipe Streaming exists but Delta Lake + Spark is purpose-built
       → Honest tradeoff: Snowflake is better for the reporting layer
       → "Use the right tool. Not the one you know."
0:10  Medallion Architecture deep dive
       → Bronze: raw events, append-only, zero transformation
       → Silver: cleaned, deduped, enriched with geofencing data
       → Gold: aggregated metrics, SLA calculations, operational KPIs
       → "Three layers isn't arbitrary. Each serves a different consumer."
0:18  Databricks workspace setup from zero
       → Create workspace, configure Unity Catalog
       → Create catalogs: iot_dev, iot_staging, iot_prod
       → Cluster policies: why you NEVER let users create arbitrary clusters
       → "This one setting will save you $20K/month. I'm not exaggerating."
0:25  Kafka setup (Confluent Cloud)
       → Create cluster, topic: vehicle_telemetry
       → Schema Registry with Avro schema
       → Why Avro over JSON: "JSON feels easy until you have 50K events/sec.
          Then serialization cost matters."

PART 2: THE DATA SIMULATOR (0:30 - 1:00)
─────────────────────────────────────────
0:30  Build the IoT simulator in Python
       → Generate realistic GPS coordinates (vehicles moving on actual road networks)
       → Engine diagnostics: temperature, RPM, fuel level, error codes
       → Simulate anomalies: 2% of vehicles with engine overheating
       → Publish to Kafka at 10K events/second
       → "Most tutorials use 10 events. We're simulating production volume
          because problems only appear at scale."
0:45  Validate data in Kafka
       → Consume a sample, inspect the schema
       → Show lag metrics
       → "If your simulator is faster than your consumer, you've already
          found your first bottleneck."

PART 3: BRONZE LAYER — RAW INGESTION (1:00 - 1:40)
───────────────────────────────────────────────────
1:00  Spark Structured Streaming notebook
       → Read from Kafka, parse Avro
       → Write to Delta Lake (Bronze table) with append mode
       → Checkpointing: what it is, why it matters, where to store it
       → "Without checkpointing, a restart means reprocessing everything.
          With it, you pick up exactly where you stopped."
1:15  Handle late-arriving data
       → Add watermarking (10-minute watermark)
       → Show what happens WITHOUT watermarking (state grows forever)
       → "This is the most common streaming bug. State management.
          Nobody teaches it because it's boring. It's also critical."
1:25  Monitoring the stream
       → Spark UI: active batches, processing rate, input rate
       → Build an alert: if processing rate < input rate for 5 min, page the team
       → Auto-scaling: cluster scales from 2 to 8 workers under load
1:35  Schema evolution
       → Add a new field to the simulator (battery_voltage)
       → Show how Delta Lake handles schema evolution with mergeSchema
       → "New fields in production are inevitable. Your pipeline can't break when they arrive."

PART 4: SILVER LAYER — CLEANING + ENRICHMENT (1:40 - 2:20)
──────────────────────────────────────────────────────────
1:40  Build the Silver streaming job
       → Read from Bronze (Delta-to-Delta streaming)
       → Deduplication using dropDuplicates with watermark
       → Data quality filters: drop events with impossible coordinates
       → Type casting + null handling
1:55  Geofence enrichment
       → Load geofence boundaries (warehouses, customer sites, restricted zones)
       → Point-in-polygon calculation using Sedona (spatial Spark)
       → Add location context: "Vehicle 4821 is at Customer Site #37"
       → "This is where raw GPS becomes business intelligence."
2:05  Anomaly detection (streaming)
       → Engine temp > 105°C for > 2 minutes → alert
       → Build a stateful streaming aggregation using mapGroupsWithState
       → "This is the hardest part of streaming. Stateful logic across windows.
          Let me show you the pattern that works every time."
2:15  Write enriched data to Silver Delta table
       → Partitioned by date and region
       → Z-ORDER by vehicle_id (most common query filter)
       → OPTIMIZE scheduled every 4 hours
       → Explain compaction and why small files kill query performance

PART 5: GOLD LAYER — AGGREGATIONS (2:20 - 2:50)
────────────────────────────────────────────────
2:20  Build Gold tables (batch, not streaming)
       → gold_vehicle_daily_summary: distance, avg speed, fuel consumption, alerts
       → gold_fleet_kpis: fleet utilization, on-time delivery rate, cost per mile
       → gold_anomaly_log: every anomaly with context, duration, resolution status
       → "Gold tables are for humans. Bronze and Silver are for machines."
2:35  Materialized Views vs. Live Tables vs. Custom Aggregations
       → When to use each — honest tradeoffs
       → Build one of each to demonstrate the differences
       → "Databricks gives you 3 ways to do this. None of them is always right."
2:45  Data quality checks on Gold
       → Build assertions: "fleet utilization between 0 and 1"
       → Row count reconciliation: Bronze count ≈ Silver count (within watermark)
       → "If your Gold table has more rows than Silver, something is very wrong."

PART 6: DASHBOARD + ALERTS + COST (2:50 - 3:40)
────────────────────────────────────────────────
2:50  Build Databricks SQL Dashboard
       → Real-time fleet map (vehicle positions updated every 30 sec)
       → Fleet KPI cards: vehicles active, deliveries completed, alerts open
       → Anomaly timeline: when did each alert fire, how long to resolve
       → Cost per vehicle per day trending
3:10  Alert system
       → Databricks SQL Alerts: if anomaly_count > threshold, send webhook
       → PagerDuty integration for critical alerts
       → Slack integration for informational alerts
       → Alert escalation: info → warning → critical → page on-call
3:20  Cost optimization
       → Review cluster costs for the entire pipeline
       → Right-size the streaming cluster (metrics-based, not guessing)
       → Compare: this pipeline on Databricks vs. what it would cost on Snowflake
       → "Total cost: $2,400/month for real-time analytics on 10K vehicles.
          The old system (custom Kafka consumers + PostgreSQL) cost them $8K/month
          AND couldn't do real-time."
3:30  Production readiness checklist
       → CI/CD with Databricks Asset Bundles
       → Job configuration for streaming recovery
       → Monitoring runbook (what to check, when to page)

OUTRO (3:40 - 3:45)
```

### GitHub Repository Structure

```
snowbrix-iot-lakehouse/
├── README.md
├── docker-compose.yml                 # Kafka + Simulator local setup
│
├── simulator/
│   ├── vehicle_simulator.py           # 10K vehicle event generator
│   ├── geofence_data.json             # Boundary polygons
│   └── config.py                      # Kafka + schema registry config
│
├── databricks/
│   ├── notebooks/
│   │   ├── 01_bronze_ingestion.py     # Kafka → Delta Bronze
│   │   ├── 02_silver_enrichment.py    # Clean + geofence + anomaly detect
│   │   ├── 03_gold_aggregations.py    # Daily summaries + KPIs
│   │   └── 04_data_quality.py         # Assertions + reconciliation
│   │
│   ├── sql/
│   │   ├── dashboard_queries/         # SQL for each dashboard panel
│   │   └── alert_definitions.sql      # SQL alert configs
│   │
│   └── jobs/
│       ├── streaming_job_config.json  # Job definition for bronze + silver
│       └── batch_job_config.json      # Job definition for gold
│
├── infrastructure/
│   ├── terraform/
│   │   ├── main.tf                    # Databricks workspace + Unity Catalog
│   │   ├── clusters.tf                # Cluster policies + job clusters
│   │   └── kafka.tf                   # Confluent Cloud resources
│   └── databricks_asset_bundles/
│       └── bundle.yml                 # CI/CD deployment config
│
└── docs/
    ├── architecture.png
    ├── cost_model.md                  # Detailed cost breakdown
    └── runbook.md                     # Operational playbook
```

---

<a id="project-3"></a>
## PROJECT 3: Legacy Oracle-to-Snowflake Migration

### "The Full Migration: Oracle to Snowflake in 90 Days"

**Duration:** 5 hours (4 parts, ~75 min each)
**Level:** Advanced
**Best For:** Decision Makers evaluating migrations, Engineers leading their first migration

**This is the flagship series. The one that sells consulting engagements.**

---

### The Scenario

> _"A financial services company has a 15-year-old Oracle data warehouse with 800 tables, 200 stored procedures, 50 scheduled jobs, and 30 downstream reports. The Oracle license renewal is $400K/year. They want to be on Snowflake in 90 days."_

### Part-by-Part Breakdown

#### PART 1: "Assessment & Architecture" (75 min)

```
THE DISCOVERY (0:00 - 0:25)
────────────────────────────
0:00  "The CEO sent one email: 'We are not renewing Oracle.'
       That email started a 90-day clock. Here's Day 1."
0:05  What we inherited: the Oracle environment tour
       → 800 tables across 12 schemas
       → 200 PL/SQL stored procedures (some 3,000 lines long)
       → ETL jobs in Oracle Data Integrator (ODI)
       → Reports in Oracle BI Publisher + Tableau
       → Data: 4TB compressed, 12TB uncompressed
       → "This is what 15 years of 'just add another table' looks like."
0:15  Dependency mapping
       → Build a dependency graph using Oracle metadata views
       → SELECT from DBA_DEPENDENCIES, ALL_SOURCE, DBA_SCHEDULER_JOBS
       → Visualize in a graph tool — show the spaghetti
       → Identify critical path: which 50 tables feed the CEO's dashboard?
0:20  Data profiling
       → Run profiling queries: NULL rates, cardinality, data types
       → Identify Oracle-specific types: CLOB, BLOB, RAW, NUMBER(38)
       → Flag transformation challenges: Oracle DATE vs. Snowflake TIMESTAMP

THE ARCHITECTURE DECISION (0:25 - 0:50)
────────────────────────────────────────
0:25  Migration strategy: Big Bang vs. Phased vs. Parallel Run
       → We're doing Parallel Run. Here's why for financial services.
       → "Big Bang sounds fast. It's actually Russian roulette."
0:30  Schema redesign: Lift-and-Shift vs. Re-architect
       → Phase 1: Lift-and-shift (get data in Snowflake, same structure)
       → Phase 2: Re-architect with dbt (proper dimensional model)
       → "Don't try to redesign during migration. That's two projects pretending to be one."
0:35  Snowflake architecture decisions
       → Account structure (single account, multi-database)
       → Warehouse strategy per workload type
       → Storage considerations: 4TB → estimated Snowflake cost
0:40  Tool selection
       → Migration tool: custom Python (NOT Snowflake's SnowConvert for this case, explain why)
       → Orchestration: Airflow (replacing ODI)
       → Transformation: dbt (replacing PL/SQL stored procedures)
       → Testing: Great Expectations (data reconciliation)
0:45  The 90-day plan
       → Week 1-2: Infrastructure + first 50 tables (critical path)
       → Week 3-6: Remaining 750 tables + procedure conversion
       → Week 7-10: Parallel run (Oracle + Snowflake side by side)
       → Week 11-12: Cutover + monitoring
       → Buffer: 1 week (you always need a buffer)

THE INFRASTRUCTURE (0:50 - 1:15)
────────────────────────────────
0:50  Terraform the Snowflake environment
       → Full IaC: account config, databases, schemas, warehouses, roles
       → "If it's not in Terraform, it doesn't exist."
1:00  Network setup
       → PrivateLink between the client's VPC and Snowflake
       → IP allowlisting
       → Why this matters for financial services (compliance)
1:05  RBAC from Day 1
       → Role hierarchy: SYSADMIN → LOADER → TRANSFORMER → ANALYST
       → Service accounts for every pipeline
       → "Bolt security on at the end = you'll never do it. Build it first."
1:10  CI/CD pipeline
       → GitHub Actions: lint → test → deploy (for dbt and Terraform)
       → Environment promotion: dev → staging → prod
```

#### PART 2: "The Data Move" (75 min)

```
SCHEMA CONVERSION (0:00 - 0:20)
───────────────────────────────
0:00  "Day 3. Infrastructure is ready. Now we move 800 tables."
0:03  Oracle-to-Snowflake data type mapping
       → Build a mapping table (shown on screen)
       → Oracle NUMBER → Snowflake NUMBER
       → Oracle VARCHAR2 → Snowflake VARCHAR
       → Oracle DATE → Snowflake TIMESTAMP_NTZ (THE TRAP — explain timezone loss)
       → Oracle CLOB → Snowflake VARCHAR(16MB) (with size check)
       → "The DATE trap catches everyone. Oracle DATE has time. Snowflake DATE doesn't."
0:10  Generate Snowflake DDL from Oracle metadata
       → Python script that reads Oracle ALL_TAB_COLUMNS
       → Auto-generates CREATE TABLE statements
       → Handles: primary keys, not-null constraints, default values
       → Does NOT handle: Oracle-specific features (virtual columns, IOTs)
       → "We convert 90% automatically. The other 10% is where the money is."
0:18  Run the DDL — create all 800 tables in Snowflake

THE BULK LOAD (0:20 - 0:55)
───────────────────────────
0:20  The extraction strategy
       → For tables <1GB: full extract via Python (cx_Oracle → CSV → PUT → COPY)
       → For tables >1GB: parallel extraction with chunking
       → For the biggest table (2TB): Oracle Data Pump → S3 → Snowflake external stage
       → "Small tables are easy. The 2TB table is a 3-day project by itself."
0:30  Build the bulk extraction framework
       → Python script with concurrent.futures (parallel extraction)
       → Progress tracking: which tables are done, which failed, which are running
       → Automatic retry on failure
       → Logging everything to a migration tracking table IN Snowflake
0:40  Handle the big table
       → Export to Parquet files (not CSV — Parquet is 5x smaller, 10x faster to load)
       → Upload to S3 with multipart upload
       → Create external stage in Snowflake
       → COPY INTO with parallelism
       → "This single table took 14 hours. We ran it over the weekend."
0:50  Validate the bulk load
       → Row count reconciliation: Oracle count = Snowflake count for every table
       → Build an automated reconciliation report
       → "3 tables had mismatches. Let me show you why."
       → Debug the 3 failures live: encoding issue, truncated CLOB, timezone shift

INCREMENTAL SYNC (0:55 - 1:15)
──────────────────────────────
0:55  Setting up ongoing sync (Oracle is still live during migration)
       → Change Data Capture using Oracle LogMiner
       → Read changes → apply to Snowflake using MERGE
       → "The bulk load was a snapshot. But the business didn't stop. New orders
          are flowing into Oracle right now. We need to keep Snowflake in sync."
1:05  Build the incremental pipeline
       → Python CDC consumer
       → MERGE INTO pattern for upserts
       → Handle deletes (soft delete in Snowflake — never hard delete during migration)
1:10  Lag monitoring
       → How far behind is Snowflake from Oracle? (target: <5 minutes)
       → Alert if lag exceeds threshold
       → "During Week 4, lag spiked to 45 minutes. The root cause was a batch job
          in Oracle that updated 2 million rows in a single transaction."
```

#### PART 3: "Procedure Conversion & Parallel Run" (75 min)

```
PL/SQL TO dbt (0:00 - 0:40)
───────────────────────────
0:00  "200 stored procedures. Some written in 2011. Some with no comments.
       All of them run the business. Let's convert them."
0:05  Triage the procedures
       → Category 1: Pure SQL transformations (80%) → Convert to dbt models
       → Category 2: Business logic with cursors (15%) → Rewrite in dbt + Jinja
       → Category 3: External calls, file I/O, email (5%) → Rewrite in Python
       → "Not everything belongs in dbt. Knowing what doesn't is the skill."
0:15  Convert a Category 1 procedure live
       → Show the original PL/SQL (INSERT INTO... SELECT FROM... with JOINs)
       → Convert to dbt model
       → Test: results match Oracle output
0:25  Convert a Category 2 procedure live (the hard one)
       → Original: cursor loop with conditional logic
       → Rewrite as set-based SQL with CASE WHEN
       → Show performance improvement: cursor was 45 min, set-based is 12 sec
       → "Cursors are a code smell in a data warehouse. Always."
0:35  Handle the Category 3 oddball
       → Stored procedure that sends an email and writes to a file
       → Move email to Airflow task (SendGrid operator)
       → Move file write to Python task with S3 upload

PARALLEL RUN (0:40 - 1:15)
─────────────────────────
0:40  The parallel run strategy
       → Both Oracle and Snowflake pipelines run simultaneously for 3 weeks
       → Every output is compared, row-by-row
       → "This is expensive. Two systems running. Double the compute.
          It's also the only way to sleep at night during a migration."
0:50  Build the reconciliation framework
       → For each output table: hash every row in Oracle, hash in Snowflake
       → Compare hashes → identify mismatches
       → Drill into mismatches → find root cause
       → "We found 47 mismatches across 200 tables. 44 were timezone issues.
          2 were rounding differences. 1 was a genuine bug in our conversion."
1:00  Fix the mismatches (live debugging)
       → Timezone fix: explicit CONVERT_TIMEZONE in dbt models
       → Rounding fix: ROUND() with explicit precision matching Oracle behavior
       → Bug fix: a GROUP BY that was missing a column
1:08  Stakeholder reporting
       → Build a migration dashboard showing reconciliation status
       → Green/yellow/red for each table
       → Present to the (simulated) CTO: "Here's where we stand."
1:12  The sign-off process
       → Who approves cutover? What's the rollback plan?
       → "Never cut over without a written rollback plan. The one time you need it
          is the one time nobody remembers how to go back."
```

#### PART 4: "Cutover, Go-Live & Lessons Learned" (60 min)

```
CUTOVER WEEKEND (0:00 - 0:25)
─────────────────────────────
0:00  "It's Friday night. The cutover window starts now. 48 hours."
0:03  The cutover runbook (shown on screen, step by step)
       → Step 1: Freeze Oracle writes (application team coordination)
       → Step 2: Run final CDC sync — bring Snowflake to exact parity
       → Step 3: Run final reconciliation — every table must be green
       → Step 4: Switch application connection strings to Snowflake
       → Step 5: Run smoke tests (critical reports, dashboards, API queries)
       → Step 6: Monitor for 4 hours
       → Step 7: Declare go-live or rollback
0:10  What went wrong (something always goes wrong)
       → A Tableau dashboard broke because it used Oracle-specific SQL syntax
       → An API endpoint expected Oracle DATE format (DD-MON-YYYY)
       → A nightly job started 2 hours late because timezone config was off
       → "Three issues in 48 hours. That's actually a good migration."
0:18  Fixing the issues in real-time
       → Tableau: update SQL to Snowflake syntax (NVL → COALESCE, SYSDATE → CURRENT_TIMESTAMP)
       → API: add a formatting layer
       → Timezone: update Airflow schedule to account for UTC
0:22  Go-live decision
       → All smoke tests pass. All dashboards verified. All APIs responding.
       → "We're live."

POST-MIGRATION (0:25 - 0:50)
─────────────────────────────
0:25  Week 1 post-migration monitoring
       → Daily cost review (are warehouses sized correctly?)
       → Query performance comparison (Oracle vs. Snowflake)
       → User feedback collection
       → "The migration isn't done when you cut over. It's done when nobody
          mentions Oracle anymore."
0:35  Cost analysis: Oracle vs. Snowflake
       → Oracle: $400K/year license + $120K/year hardware + $80K/year DBA time
       → Snowflake: $42K/year compute + $18K/year storage + $0 license
       → Net savings: $540K/year
       → Migration cost: $180K (team time + Snowflake during parallel run)
       → ROI: 3x in Year 1
0:42  Decommission Oracle
       → 30-day grace period (data still accessible, no writes)
       → Export final archive to S3 (regulatory requirement)
       → Terminate Oracle instances
       → "Delete the Oracle admin's on-call rotation. That feels good."

LESSONS LEARNED (0:50 - 1:10)
─────────────────────────────
0:50  The 10 things we'd do differently
       1. Start reconciliation testing earlier (Week 1, not Week 7)
       2. Budget 2x the time for stored procedure conversion
       3. Involve the Tableau team from Day 1
       4. Don't underestimate timezone complexity
       5. Build the cost monitoring dashboard BEFORE migration, not after
       6. Document every Oracle-specific SQL pattern in a conversion guide
       7. Get executive sign-off on the cutover criteria in writing
       8. Plan for the "long tail" — the 5% of procedures that take 50% of the time
       9. Run load tests on Snowflake with production query patterns, not toy queries
       10. Hire a dedicated migration project manager (not a data engineer with a side role)

1:00  When NOT to migrate
       → If Oracle costs <$100K/year and your team is small, don't bother
       → If you have heavy PL/SQL business logic that nobody understands, fix that first
       → If your data is <500GB and you don't need Snowflake features, just use Postgres
       → "We could sell you a migration you don't need. We won't."

1:05  SOFT CTA
       "This is what our team does. Oracle, Teradata, Redshift, on-prem Hadoop —
        we move it to Snowflake or Databricks and we make sure it works.

        If you're staring down a migration and the timeline feels impossible,
        book a scoping call. We'll look at your environment and tell you honestly
        whether it's a 60-day job or a 6-month one. Link below."
```

---

<a id="project-4"></a>
## PROJECT 4: Snowflake + Databricks Hybrid Architecture

### "The Architecture Nobody's Building: Snowflake + Databricks Working Together"

**Duration:** 4.5 hours (3 parts, ~90 min each)
**Level:** Advanced
**Best For:** Architects evaluating multi-platform strategies — THIS IS THE CORE BRAND VIDEO

---

### The Scenario

> _"A healthcare analytics company needs Databricks for ML model training on unstructured data (medical images, clinical notes) and Snowflake for structured reporting (claims, patient demographics, operational KPIs). Instead of choosing one, we build both — connected by Apache Iceberg."_

### Why This Project Defines the Brand

This is the video Snowbrix was named for. Nobody else is building this. The entire industry frames it as "Snowflake vs. Databricks." We frame it as "Snowflake AND Databricks." This video is the proof.

### Part-by-Part Breakdown

#### PART 1: "The Interoperability Layer" (90 min)

```
0:00  "Snowflake vs. Databricks is the wrong question.
       The right question: which workload goes where?"
0:05  The decision framework (shown as a flowchart)
       → Structured SQL analytics? → Snowflake
       → ML training on unstructured data? → Databricks
       → Real-time streaming? → Databricks
       → BI/Reporting? → Snowflake
       → Data sharing with external partners? → Snowflake
       → Notebook-driven exploration? → Databricks
       → "Use both. Pay less. Get more."
0:15  Apache Iceberg: the bridge between platforms
       → What Iceberg is (table format, not a database)
       → How Snowflake reads Iceberg tables
       → How Databricks writes Iceberg tables
       → "Iceberg is the USB-C of data. Universal connector."
0:25  Build the shared storage layer
       → S3 bucket as the single source of truth
       → Iceberg catalog (AWS Glue as the catalog)
       → Both Snowflake and Databricks point to the same catalog
0:40  Create the first cross-platform table
       → Write a Delta table in Databricks
       → Convert to Iceberg (or use UniForm)
       → Read the SAME data from Snowflake — zero copy
       → "One write. Two platforms. No data movement. This is the future."
0:55  Build the metadata layer
       → Unity Catalog on Databricks side
       → Snowflake Iceberg Tables (external) on Snowflake side
       → Reconcile: do both platforms see the same row count? Same schema?
       → Handle metadata refresh cadence
1:10  Cost modeling
       → Compare: dual-platform Iceberg vs. copying data between platforms
       → Show the math: Iceberg saves 40-60% on storage + eliminates copy latency
1:20  CHECKPOINT
```

#### PART 2: "ML in Databricks, Analytics in Snowflake" (90 min)

```
0:00  Build the ML pipeline in Databricks
       → Load clinical notes (unstructured text data)
       → NLP model: extract diagnosis codes from free text
       → Train using Spark MLlib + MLflow tracking
       → Write predictions back to an Iceberg table
0:30  Build the analytics layer in Snowflake
       → Read the ML predictions via Iceberg external table
       → Join predictions with structured claims data (already in Snowflake)
       → Build a dbt model: "patients with predicted vs. actual diagnoses"
       → Create a Snowflake dashboard for clinical operations
1:00  The orchestration challenge
       → Airflow DAG that coordinates BOTH platforms
       → Task 1: Trigger Databricks job (ML training)
       → Task 2: Wait for Iceberg table refresh
       → Task 3: Trigger Snowflake dbt run (analytics)
       → Task 4: Data quality checks on final output
       → "Orchestrating two platforms is the hardest part. Not the code. The coordination."
1:20  Monitoring across platforms
       → Unified cost dashboard (Databricks compute + Snowflake compute + S3 storage)
       → Data freshness monitoring (is Snowflake seeing the latest Databricks output?)
       → Alert routing: which platform's team gets paged for which failure?
```

#### PART 3: "Production Hardening & Cost Optimization" (90 min)

```
0:00  Security across platforms
       → RBAC that spans both: who can read ML outputs in Snowflake?
       → Data masking: PII visible in Databricks for training, masked in Snowflake for reporting
       → Audit logging: unified trail across both platforms
0:25  Disaster recovery
       → What if Databricks is down? (Snowflake still serves reports from last Iceberg snapshot)
       → What if Snowflake is down? (Databricks ML pipeline is independent)
       → What if S3 is down? (Both are down. This is the single point of failure.)
       → "True hybrid means true resilience. Except for the storage layer."
0:40  Performance optimization
       → Iceberg table compaction strategy
       → Partition pruning: how to partition for BOTH platforms' query patterns
       → Caching behavior differences between Snowflake and Databricks
1:00  The cost comparison everyone wants
       → Total cost: hybrid (Snowflake + Databricks + S3)
       → vs. Snowflake-only (using Snowpark for ML)
       → vs. Databricks-only (using Databricks SQL for reporting)
       → "Hybrid wins by 23% in this scenario. But the real win is flexibility.
          You're not locked in to either vendor's roadmap."
1:15  When NOT to go hybrid
       → If your team is <5 engineers, stick to one platform
       → If you don't have ML workloads, Snowflake-only is fine
       → If you don't need BI/reporting, Databricks-only is fine
       → "Hybrid adds operational complexity. Only do it when the savings justify it."
```

---

<a id="project-5"></a>
## PROJECT 5: Cost Monitoring & FinOps Dashboard

### "Build a Snowflake FinOps Dashboard That Pays for Itself"

**Duration:** 2 hours (single video)
**Level:** Intermediate
**Best For:** Every Snowflake user — this is the highest-search-volume project

---

### The Scenario

> _"Your company spends $15K/month on Snowflake and nobody knows where the money goes. The finance team asks data engineering for a cost breakdown every quarter and it takes 2 weeks to compile. Let's automate it."_

### Chapter Breakdown

```
0:00 - 0:15   "Your Snowflake bill is lying to you. Let me show you what it actually says."
0:15 - 0:30   Snowflake ACCOUNT_USAGE schema deep dive — the 10 views that matter
0:30 - 0:50   Build SQL views: cost per warehouse, per user, per query, per department
0:50 - 1:10   Build a Streamlit FinOps dashboard
               → Daily spend trending (with forecast)
               → Top 10 most expensive queries (with user attribution)
               → Warehouse utilization heatmap (when is compute idle?)
               → Department chargeback report
               → Anomaly detection: "spend was 3x normal yesterday because..."
1:10 - 1:30   Automated alerting
               → Resource monitors with escalation thresholds
               → Slack alerts when daily spend exceeds budget
               → Weekly cost report email to finance team
               → Snowflake Cortex: natural language query over cost data
                 "Hey Cortex, why did spend spike on Tuesday?"
1:30 - 1:50   Cost optimization recommendations engine
               → Auto-detect: warehouses that should be smaller
               → Auto-detect: queries that scan full tables (missing filters)
               → Auto-detect: users running duplicate queries
               → Auto-detect: idle warehouses (auto-suspend not configured)
               → Generate a "Top 10 savings opportunities" report
1:50 - 2:00   "This dashboard took 2 hours to build. It found $4,200/month
               in savings in the first week. Build it today."
```

---

<a id="project-6"></a>
## PROJECT 6: Data Quality Framework from Scratch

### "The Data Quality Framework Your Pipeline Is Missing"

**Duration:** 2 hours 30 minutes (single video)
**Level:** Intermediate
**Best For:** Engineers tired of being surprised by bad data at 6 AM

---

### Chapter Breakdown

```
0:00 - 0:10   "Your pipeline succeeded. Your data is wrong. That's worse than a failure."
0:10 - 0:30   The 5 dimensions of data quality: Completeness, Accuracy, Consistency,
               Timeliness, Uniqueness — with real examples of each failing
0:30 - 0:55   Build dbt tests (beyond the basics)
               → Custom schema tests: revenue within expected range, dates not in the future
               → Source freshness checks: alert if source data is >2 hours stale
               → Cross-database validation: staging count = source count
0:55 - 1:20   Great Expectations integration
               → Install and configure with Snowflake/Databricks
               → Build an expectation suite for the orders table
               → Run validation, interpret results
               → Store results in a data quality metrics table
1:20 - 1:45   Build the quality monitoring dashboard
               → Data quality score per table per day (trending)
               → Automated anomaly detection: "NULL rate for email jumped from 2% to 45%"
               → Root cause analysis helper: which upstream change caused the quality drop?
               → SLA tracking: "Table X must be fresh by 6 AM. It was 22 min late."
1:45 - 2:05   Incident response automation
               → Quality check fails → Slack alert → create Jira ticket
               → Auto-quarantine: bad data flagged, not deleted, not served to dashboards
               → "Never serve bad data to stakeholders. Serve no data with an explanation."
2:05 - 2:20   Build a data contract (between producers and consumers)
               → YAML contract definition: expected schema, quality thresholds, SLAs
               → Automated enforcement: pipeline fails if contract is violated
               → "Data contracts are the API specs of the data world. If you don't have them,
                  you're building without a blueprint."
2:20 - 2:30   Production integration + soft CTA
```

---

<a id="project-7"></a>
## PROJECT 7: Multi-Tenant SaaS Data Platform

### "Build a Multi-Tenant Data Platform for a B2B SaaS Product"

**Duration:** 5 hours (4 parts, ~75 min each)
**Level:** Expert
**Best For:** Engineers at SaaS companies, platform engineers, architects

---

### The Scenario

> _"A B2B SaaS company has 200 customers. Each customer's data must be isolated. Some customers are 100x larger than others. They need per-customer analytics, cross-customer benchmarking (aggregated), and a customer-facing embedded dashboard. All on Snowflake."_

### Part Breakdown

```
PART 1: Tenant Isolation Architecture (75 min)
───────────────────────────────────────────────
- 3 isolation strategies: separate databases, shared database with RLS, hybrid
- Build all three, benchmark, show tradeoffs
- Implement Row-Level Security with session variables
- Secure Views vs. Secure UDFs — when to use each
- "The wrong isolation strategy will cost you $500K when you have 1,000 tenants."

PART 2: Ingestion at Scale (75 min)
───────────────────────────────────
- Build a parameterized ingestion framework
- One pipeline definition, 200 tenant configs
- Handle the "noisy neighbor": one tenant with 100M rows, 199 with 10K
- Dynamic warehouse scaling per tenant size
- Metadata-driven pipeline: add a new tenant by adding a row, not code

PART 3: The Analytics Layer (75 min)
────────────────────────────────────
- dbt with multi-tenant patterns
  → Jinja macros that loop over tenants
  → Incremental models that handle 200 different source schemas
  → Cross-tenant aggregation (anonymized benchmarks)
- Customer-facing embedded dashboard with Snowflake + Streamlit
  → Each customer logs in and sees ONLY their data
  → Secure token-based access
  → "Your customer sees a dashboard. They don't see Snowflake. They see YOUR product."

PART 4: Operations & Cost Management (75 min)
─────────────────────────────────────────────
- Per-tenant cost attribution (which customer costs the most?)
- Billing model: how to charge customers based on data volume/compute
- Tenant onboarding automation (Terraform + Python)
- Monitoring: per-tenant query performance, freshness, error rates
- Scale testing: simulate 1,000 tenants, find the breaking point
```

---

<a id="project-8"></a>
## PROJECT 8: ML Feature Store on Databricks

### "Build a Production Feature Store for Real-Time ML"

**Duration:** 3 hours (single video)
**Level:** Advanced
**Best For:** Data engineers supporting ML teams, MLOps engineers

---

### The Scenario

> _"A fintech company needs real-time fraud detection. The ML model needs 150 features computed from transaction history, user behavior, and device fingerprints. Features must be available in <50ms for online serving and as batch datasets for training."_

### Chapter Breakdown

```
0:00 - 0:20   Architecture: Online vs. Offline Feature Store
               → Offline (training): Delta Lake tables in Databricks
               → Online (serving): Feature Store with low-latency lookup
               → Point-in-time correctness: why you CANNOT just join on user_id
               → "Point-in-time joins are the #1 cause of training-serving skew.
                  Get this wrong and your model is learning from the future."

0:20 - 0:50   Build Offline Features
               → Transaction aggregations: 1-hour, 24-hour, 7-day, 30-day windows
               → User behavior features: login frequency, device changes, location variance
               → Build as dbt models on top of Delta Lake
               → Time-travel: generate feature values AS OF any historical timestamp

0:50 - 1:20   Databricks Feature Store Setup
               → Create feature tables with Feature Engineering client
               → Register features with metadata: descriptions, owners, freshness SLAs
               → Build a feature lookup function for training
               → Build the same lookup for online serving

1:20 - 1:50   Train the Fraud Detection Model
               → Pull training set with point-in-time correct features
               → Train XGBoost model, log to MLflow
               → Show feature importance — which features actually matter?
               → Register model in Unity Catalog

1:50 - 2:20   Online Serving Pipeline
               → Real-time feature computation with Spark Structured Streaming
               → Publish to online store (Databricks Online Tables)
               → Build a REST API endpoint: send transaction → get fraud score
               → Latency test: is it <50ms? (spoiler: first attempt is 200ms, then optimize)

2:20 - 2:50   Monitoring & Drift Detection
               → Feature drift: are the distributions changing over time?
               → Model performance monitoring: is accuracy degrading?
               → Automated retraining trigger: if drift > threshold → retrain pipeline
               → Dashboard: feature health, model performance, serving latency

2:50 - 3:00   Production Checklist + Soft CTA
```

---

<a id="project-9"></a>
## PROJECT 9: CDC Pipeline — Postgres to Snowflake in Real-Time

### "Real-Time Change Data Capture: Postgres to Snowflake with Zero Data Loss"

**Duration:** 2 hours 30 minutes (single video)
**Level:** Intermediate
**Best For:** Engineers replacing batch ETL with real-time sync — high search volume topic

---

### Chapter Breakdown

```
0:00 - 0:15   "Your dashboards are 24 hours stale. Your CEO asks why the numbers
               are different from the app. Let's fix that — today."

0:15 - 0:35   CDC Fundamentals
               → What is Change Data Capture (log-based vs. timestamp-based)
               → Why log-based wins: captures deletes, doesn't miss updates, zero source impact
               → The pipeline: Postgres WAL → Debezium → Kafka → Snowpipe Streaming → Snowflake
               → Architecture diagram drawn live

0:35 - 0:55   Set Up Postgres CDC Source
               → Enable logical replication (wal_level = logical)
               → Create a replication slot
               → Deploy Debezium via Docker (Kafka Connect)
               → Configure the Postgres connector
               → Show events flowing: INSERT, UPDATE, DELETE all captured
               → "One config change on Postgres. That's the entire source-side setup."

0:55 - 1:20   Kafka as the Transport Layer
               → Topic naming conventions: db.schema.table
               → Schema Registry for Debezium's envelope format
               → Retention and compaction: keep the log vs. keep the latest
               → Monitor lag: how far behind is the consumer?

1:20 - 1:50   Snowpipe Streaming into Snowflake
               → Set up Snowpipe Streaming client (Java SDK or Kafka connector for Snowflake)
               → Map Debezium events to Snowflake operations
               → Handle INSERTS → append to raw table
               → Handle UPDATES → MERGE into target table
               → Handle DELETES → soft delete with _deleted_at timestamp
               → Build the MERGE logic that handles all three in one statement
               → "One MERGE statement. Three operation types. Zero data loss."

1:50 - 2:10   Testing and Validation
               → Insert 10,000 rows in Postgres → verify they appear in Snowflake (<10 sec latency)
               → Update 1,000 rows → verify changes propagate
               → Delete 500 rows → verify soft deletes
               → Schema change: add a column in Postgres → handle gracefully in Snowflake
               → Failure simulation: kill Kafka, restart → verify no data loss (offset tracking)
               → "We killed Kafka for 5 minutes. When it came back, every row was accounted for."

2:10 - 2:25   Production Hardening
               → Monitoring dashboard: events/sec, latency, error rate, lag
               → Dead letter queue for malformed events
               → Alerting: if latency > 60 seconds, page the team
               → Cost analysis: this entire CDC pipeline costs $180/month to run

2:25 - 2:30   Soft CTA + Summary
```

---

<a id="project-10"></a>
## PROJECT 10: Full Data Mesh Implementation

### "Data Mesh in Practice: Not Theory, Not Slides — Real Implementation"

**Duration:** 5 hours (4 parts, ~75 min each)
**Level:** Expert
**Best For:** Platform engineers, data architects at companies with 50+ data engineers

---

### Part Breakdown

```
PART 1: Domain Decomposition (75 min)
─────────────────────────────────────
- "Data mesh is an organizational principle with technology implications.
   If you're buying a 'data mesh tool,' you've already failed."
- Map business domains: Sales, Marketing, Product, Finance, Customer Support
- Define data products per domain (with contracts, SLAs, ownership)
- Databricks Unity Catalog: one catalog per domain, shared metastore
- Build the self-serve data platform foundation with Terraform

PART 2: Domain Data Products (75 min)
─────────────────────────────────────
- Build 3 complete data products (one per domain):
  → Sales domain: pipeline, quality checks, published dataset, documentation
  → Marketing domain: attribution model, published dataset, API
  → Finance domain: revenue recognition, compliance checks, published dataset
- Each domain team owns their pipeline end-to-end
- Cross-domain data sharing with governed permissions

PART 3: The Self-Serve Platform (75 min)
────────────────────────────────────────
- Build the platform layer that enables domain teams:
  → Template pipeline: domain team fills in config, platform provides infra
  → Data quality as a service: shared Great Expectations deployment
  → Cost allocation: per-domain compute tracking and chargeback
  → Discovery: data catalog with search, lineage, documentation
  → "The platform team builds roads. The domain teams drive on them."

PART 4: Governance & Scaling (75 min)
────────────────────────────────────
- Federated governance model: global standards, local autonomy
- Unity Catalog row-level + column-level security
- PII handling across domains: tokenization, masking, access auditing
- Data product lifecycle: creation, versioning, deprecation, retirement
- "Data mesh at 5 domains is manageable. At 20, it's chaos without automation."
- Scale testing: simulate 20 domains, 200 data products
- Lessons from real implementations (anonymized client stories)
```

---

<a id="project-11"></a>
## PROJECT 11: Reverse ETL & Operational Analytics

### "Push Your Warehouse Data Back Into Production Systems"

**Duration:** 2 hours (single video)
**Level:** Intermediate
**Best For:** Engineers building customer-facing features powered by warehouse analytics

---

### The Scenario

> _"The marketing team wants to sync customer segments from Snowflake into HubSpot. The product team wants to push personalization scores into the application database. The sales team wants enriched leads in Salesforce. Let's build reverse ETL without buying a $50K/year tool."_

### Chapter Breakdown

```
0:00 - 0:15   "Reverse ETL is a $30K/year line item at most companies.
               We're going to build it for the cost of a Lambda function."

0:15 - 0:35   Architecture: Build vs. Buy
               → Census, Hightouch, Polytomic: what they do, what they cost
               → The 80% use case: simple row-level sync to a SaaS tool
               → "You can build the 80% in an afternoon. The 20% is where you evaluate buying."

0:35 - 1:00   Build the Reverse ETL Framework
               → Snowflake query → Python transformer → API push
               → Sync strategy: full replace vs. incremental (change detection with hashing)
               → Rate limit handling for destination APIs (HubSpot, Salesforce, etc.)
               → Build a reusable connector class with retry logic
               → "Every SaaS API is slightly different. The framework is always the same."

1:00 - 1:25   Connect 3 Destinations
               → HubSpot: push customer segments (batch API)
               → Application Postgres: push personalization scores (direct SQL)
               → Slack: push daily summary reports (webhook)
               → Each connector: <50 lines of Python

1:25 - 1:45   Orchestration + Monitoring
               → Airflow DAG: schedule syncs per destination
               → Sync tracking table: what was pushed, when, how many rows, any failures
               → Reconciliation: does HubSpot segment count = Snowflake query count?
               → Alert on discrepancy

1:45 - 2:00   When to Buy Instead
               → >10 destinations
               → Need field-level mapping UI for non-engineers
               → Need audit/compliance logging beyond what you want to build
               → "Know when you've outgrown your own tool. That's engineering maturity."
```

---

<a id="project-12"></a>
## PROJECT 12: Disaster Recovery & High Availability

### "What Happens When Snowflake Goes Down? The DR Plan Nobody Has"

**Duration:** 3 hours (single video)
**Level:** Advanced
**Best For:** Platform engineers, architects at companies with SLA requirements

---

### Chapter Breakdown

```
0:00 - 0:15   "Snowflake went down for 4 hours in [incident]. What was your plan?
               If the answer is 'wait,' this video is for you."

0:15 - 0:40   Snowflake's Built-In Resilience
               → Multi-AZ by default (what this protects against)
               → Time Travel (what this recovers)
               → Fail-Safe (what this DOESN'T recover — the misunderstanding)
               → "Time Travel is not a backup strategy. It's an undo button with an expiration date."

0:40 - 1:10   Build Cross-Region Replication
               → Set up replication from US-East to US-West
               → Database replication: which databases, how often
               → Account replication: roles, warehouses, everything
               → Test failover: switch the application to the secondary
               → Measure RPO (Recovery Point Objective) and RTO (Recovery Time Objective)
               → "Our RPO: 5 minutes. Our RTO: 12 minutes. What's yours?"

1:10 - 1:40   Automated Failover System
               → Health check endpoint: is primary Snowflake responding?
               → Automated decision: if primary down >5 min → trigger failover
               → Connection string rotation: application automatically points to secondary
               → Build with Python + DNS failover (Route53 health checks)
               → Test it: simulate primary region failure, watch the system recover

1:40 - 2:10   Cross-Platform DR (Snowflake + Databricks)
               → Critical data also exists in Databricks Delta Lake (via Iceberg)
               → If Snowflake is down, can Databricks serve emergency reports?
               → Build the emergency reporting pipeline in Databricks SQL
               → "Belt AND suspenders. Two platforms. Two regions. Zero excuses."

2:10 - 2:40   The DR Runbook
               → Step-by-step document (built live, template in GitHub)
               → Who to call (escalation chain)
               → Decision tree: when to failover vs. when to wait
               → Communication templates: what to tell stakeholders
               → Post-incident review process
               → "The runbook is worthless if nobody practices it. Run a fire drill quarterly."

2:40 - 3:00   Cost of DR vs. Cost of Downtime
               → DR setup: ~$3K/month (replication + standby resources)
               → Cost of 1 hour downtime for a mid-market company: $50K-$500K
               → "DR is insurance. It's expensive until you need it. Then it's priceless."
```

---

## APPENDIX: PROJECT RELEASE SCHEDULE

### Year 1 Monthly Flagship Releases

| Month | Project | Duration | Strategic Goal |
|-------|---------|----------|---------------|
| 1 | **#5: FinOps Dashboard** | 2 hrs | Easiest project, widest appeal, SEO anchor |
| 2 | **#1: E-Commerce Platform** | 3.5 hrs | Foundational "complete build" credential |
| 3 | **#9: CDC Pipeline** | 2.5 hrs | High search volume, fills "real-time" gap |
| 4 | **#6: Data Quality Framework** | 2.5 hrs | Every engineer needs this, broad appeal |
| 5 | **#3: Oracle-to-Snowflake Migration (Parts 1-2)** | 2.5 hrs | Consulting lead generator begins |
| 6 | **#3: Oracle-to-Snowflake Migration (Parts 3-4)** | 2.5 hrs | Consulting lead generator completes |
| 7 | **#2: Real-Time Streaming Lakehouse** | 4 hrs | Proves Databricks expertise |
| 8 | **#11: Reverse ETL** | 2 hrs | Practical, shareable, broad appeal |
| 9 | **#4: Hybrid Architecture (Parts 1-2)** | 3 hrs | THE brand-defining video starts |
| 10 | **#4: Hybrid Architecture (Part 3)** + **#12: Disaster Recovery** | 4.5 hrs | Complete the hybrid thesis + enterprise trust |
| 11 | **#8: ML Feature Store** | 3 hrs | Expand into MLOps audience |
| 12 | **#7: Multi-Tenant SaaS (Parts 1-2)** | 2.5 hrs | Expert-level content |

### Why This Order

1. **Months 1-3:** Accessible projects that rank in search. Build the subscriber base.
2. **Months 4-6:** The migration series. This is the consulting lead machine.
3. **Months 7-9:** Advanced projects that prove deep expertise. Academy content.
4. **Months 10-12:** Brand-defining work. The hybrid architecture is the thesis statement.

---

## APPENDIX: PRODUCTION CHECKLIST (Every Project Video)

```
PRE-PRODUCTION
□ GitHub repo created with README template
□ Architecture diagram (v1) in Figma
□ All credentials use environment variables (.env.example committed, .env gitignored)
□ Docker Compose for any local dependencies
□ Script outline with timestamps (matched to git tags)
□ Sample data prepared (realistic volume, no real client data)

RECORDING
□ Screen resolution: 1920x1080 (2K if font size allows readability)
□ Font size: 16px minimum in terminal/IDE
□ Dark theme across all tools (consistency)
□ Hide bookmarks bar, notification badges, personal info
□ Record audio separately (better quality, easier to fix mistakes)
□ Every error/mistake stays in the video (authenticity)

POST-PRODUCTION
□ Chapter timestamps every 5-10 minutes
□ Git tags match video timestamps (documented in description)
□ Thumbnail follows Split Verdict format (from Brand Bible)
□ Description includes: architecture diagram, repo link, timestamps, CTA
□ Pinned comment: "What should I build next? Drop your scenario below."
□ 3 Shorts clipped from the full video
□ LinkedIn post drafted for drop day
□ Newsletter section written

GITHUB REPO
□ README has: scenario description, architecture diagram, prerequisites, setup guide
□ Every commit has a clear message (viewers will read git log)
□ Branches per part (for multi-part series)
□ Tags match video timestamps
□ .env.example with all required variables
□ No real credentials, no client data, no PII
□ LICENSE file (MIT for code, CC-BY for docs)
```

---

*Snowbrix Academy End-to-End Projects v1.0 — February 2026*
*Each project is a business card. Build it like a client is watching. Because they are.*
