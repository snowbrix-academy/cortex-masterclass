# Module 03 — Config Tables: The Brain | Video Script

**Duration:** ~30 minutes
**Type:** Deep Dive + Hands-On
**Deliverable:** 6 metadata tables, 5 sample configs

---

## [0:00 - 0:15] THE HOOK

**[SCREEN: Snowsight showing SELECT from INGESTION_CONFIG with 5 rows visible — columns: SOURCE_NAME, SOURCE_TYPE, TARGET_TABLE, LOAD_FREQUENCY, IS_ACTIVE]**

> "Five rows. Five data sources. CSV, JSON, Parquet — all controlled from one table. No scripts to edit. No deployments to schedule. You change a row, the framework changes its behavior. By the end of this module, you'll have the brain of the entire framework built and populated."

---

## [0:15 - 1:30] THE CONTEXT

**[SLIDE: Course Roadmap — Module 03 highlighted]**

> "Welcome to Module 03. In Module 01, we built the infrastructure — databases, warehouses, roles. In Module 02, we taught the framework how to read files and where to find them. Now we're building the brain: the config tables that tell the framework what to load, where to put it, and how to handle every edge case."

**[SLIDE: Traditional vs Metadata-Driven comparison]**

> "Let me show you why this matters. Traditional approach: you need to ingest customer data from a CSV. You write a COPY INTO script. Next week, you get orders data. Another script. Then products. Another script. A month later, you have 20 sources and 20 scripts — each slightly different, each a maintenance liability.
>
> Metadata-driven approach: you write one generic procedure. One. It reads its instructions from a config table. New source? INSERT a row. Change the load frequency? UPDATE a column. Disable a source at 2 AM because it's broken? SET IS_ACTIVE = FALSE. One row, one second, no deployment.
>
> At scale, this is the difference between managing 100 config rows and managing 100 independent scripts. That's not a small difference. That's the difference between a framework and a mess."

---

## [1:30 - 4:00] THE BUILD — INGESTION_CONFIG: Source & Stage Columns

**[SLIDE: INGESTION_CONFIG — The Heart of the Framework]**

> "The INGESTION_CONFIG table is the single source of truth. Every data source that the framework ingests has exactly one row here. It has over 30 columns, but they're organized into logical groups. Let's walk through them."

**[Switch to Snowsight, open 01_ingestion_config.sql]**

> "Let's start building. Use role MDF_ADMIN, database MDF_CONTROL_DB, schema CONFIG."

**[Run: USE ROLE / USE DATABASE / USE SCHEMA / USE WAREHOUSE statements]**

> "First group: source identification."

**[Highlight lines 45-52 in the SQL]**

> "CONFIG_ID is our auto-incrementing primary key. SOURCE_NAME is the unique, human-readable identifier — follow the pattern CLIENT underscore ENTITY underscore FORMAT. So DEMO_CUSTOMERS_CSV, ACME_EVENTS_JSON. You should be able to read the name and know exactly what it is.
>
> CLIENT_NAME groups sources by client or business unit. SOURCE_SYSTEM tells you where the data originates — SAP, Salesforce, an internal API. SOURCE_TYPE is the file format — CSV, JSON, Parquet, Avro, ORC. These five columns answer the question: what is this data and where does it come from?"

**[Highlight lines 55-58]**

> "Second group: stage configuration. STAGE_NAME is the fully qualified stage path — the at-sign, database, schema, stage name. FILE_PATTERN is a regex that tells Snowflake which files to pick up. If your stage has 50 files but you only want the ones matching 'sales', this is how. SUB_DIRECTORY narrows it further — within a stage, which folder should the framework look in?"

---

## [4:00 - 6:30] THE BUILD — Format, Target & Load Behavior

**[Highlight lines 60-61]**

> "Third group: file format. Just one column — FILE_FORMAT_NAME. It references the named file formats we created in Module 02. One column, but it determines how Snowflake parses every byte of the source file."

**[Highlight lines 63-67]**

> "Fourth group: target configuration. Where does the data land? TARGET_DATABASE, TARGET_SCHEMA, TARGET_TABLE — these three columns build the fully qualified destination. And AUTO_CREATE_TARGET — set this to TRUE, and the framework will create the target schema and table if they don't exist. You won't have to pre-create 100 tables by hand."

**[Highlight lines 69-76]**

> "Fifth group: load behavior. This is where it gets interesting.
>
> LOAD_TYPE has three options. APPEND adds new data to existing data — the most common pattern for incremental loads. TRUNCATE_RELOAD wipes the table and reloads everything — use this for small dimension tables that get full refreshes. MERGE does upserts based on key columns — that's advanced territory, we'll cover it in Module 10.
>
> ON_ERROR controls what happens when Snowflake hits a bad row. CONTINUE skips the bad row and loads the rest — best for large files where you don't want one bad record to kill the whole load. SKIP_FILE skips the entire file if any row fails. ABORT_STATEMENT stops everything on the first error — strictest option.
>
> PURGE_FILES — set to TRUE and Snowflake deletes source files after a successful load. Be careful with this in production until you trust your pipeline.
>
> FORCE_RELOAD — normally Snowflake tracks which files it's already loaded and skips them. Set this to TRUE to reload files even if they've been processed before. Useful for reprocessing after a bug fix.
>
> MATCH_BY_COLUMN_NAME — for Parquet and other self-describing formats, this matches source columns to target columns by name instead of position. CASE_INSENSITIVE is usually what you want."

---

## [6:30 - 9:00] THE BUILD — Advanced Columns & Create Table

**[Highlight lines 78-82]**

> "Sixth group: copy options and semi-structured specifics. COPY_OPTIONS is a VARIANT column — that means it stores JSON. Any additional COPY INTO option that doesn't have its own column goes here. This future-proofs the table. Snowflake adds a new COPY option next year? You don't alter the table — you just put it in this JSON field.
>
> FLATTEN_PATH and FLATTEN_OUTER are for JSON and nested data. If your JSON has a structure like data dot records and you need to flatten into that nested array, FLATTEN_PATH tells the framework exactly where to look."

**[Highlight lines 84-88]**

> "Seventh group: scheduling. IS_ACTIVE is the master on/off switch. One boolean column that controls whether this source gets processed. Middle of the night, source is flooding bad data? UPDATE INGESTION_CONFIG SET IS_ACTIVE = FALSE WHERE SOURCE_NAME = 'BROKEN_SOURCE'. Done. No code change, no deployment, no pull request.
>
> LOAD_FREQUENCY and CRON_EXPRESSION define when processing happens. LOAD_PRIORITY determines order — lower number means higher priority. Your revenue data at priority 10 runs before your marketing analytics at priority 100."

**[Highlight lines 90-102]**

> "Groups eight, nine, and ten: data quality, schema evolution, and notifications. ENABLE_VALIDATION turns on post-load checks. ROW_COUNT_THRESHOLD alerts you if a load returns fewer rows than expected — a sign the source file might be truncated or empty. NULL_CHECK_COLUMNS lists columns that should never contain nulls.
>
> ENABLE_SCHEMA_EVOLUTION and SCHEMA_EVOLUTION_MODE control whether the framework auto-adapts when source schemas change. We'll go deep on this in Module 10.
>
> NOTIFY_ON_SUCCESS, NOTIFY_ON_FAILURE, NOTIFICATION_CHANNEL — self-explanatory. When things break at 3 AM, these columns ensure the right people know about it."

**[Highlight lines 104-112 — metadata and constraints]**

> "Finally, metadata. TAGS is another VARIANT column — custom JSON tags for governance. Domain, data tier, PII flag — anything your organization needs. CREATED_BY and CREATED_AT track who created the config and when. And a unique constraint on SOURCE_NAME — no duplicates allowed."

**[Run: The full CREATE TABLE INGESTION_CONFIG statement]**

> "Let's run it."

**[Show the success output]**

> "Table created. The COMMENT ON TABLE adds a description that shows up in Snowsight and DESCRIBE TABLE output. Good practice — future you will thank present you."

**[Run: COMMENT ON TABLE statement]**

---

## [9:00 - 13:00] THE BUILD — Audit Log (The Black Box Recorder)

**[SLIDE: The Black Box Recorder concept]**

> "Next: the audit log. If the INGESTION_CONFIG table is the brain, the audit log is the black box recorder. Just like an airplane's flight recorder captures everything that happens during a flight, this table captures everything that happens during every ingestion run. When something goes wrong — and in production, something always goes wrong — this table tells you exactly what happened and when."

**[Switch to Snowsight, open 02_audit_and_supporting_tables.sql]**

**[Run: USE SCHEMA AUDIT]**

> "We're switching to the AUDIT schema. Separation of concerns — config lives in CONFIG, audit logs live in AUDIT."

**[Highlight INGESTION_AUDIT_LOG columns, lines 41-86]**

> "INGESTION_AUDIT_LOG. Every single run of the framework creates a record here. Let me walk through the important columns.
>
> AUDIT_ID is the auto-incrementing primary key. BATCH_ID is a UUID — a unique identifier for each execution run. If you kick off a batch that processes 10 sources, all 10 get the same BATCH_ID. This lets you query: show me everything from that 6 AM run on Tuesday.
>
> CONFIG_ID links back to INGESTION_CONFIG. SOURCE_NAME is denormalized — we store it directly in the audit log so you can query without joining. In production monitoring, you don't want a five-table join at 3 AM.
>
> RUN_STATUS has five states: STARTED, SUCCESS, PARTIAL_SUCCESS, FAILED, SKIPPED. PARTIAL_SUCCESS means some files loaded but others had errors — this is the most common status you'll deal with.
>
> START_TIME, END_TIME, DURATION_SECONDS — the basics. But look at the metrics: FILES_PROCESSED, FILES_SKIPPED, FILES_FAILED, ROWS_LOADED, ROWS_FAILED, BYTES_LOADED. Six numbers that tell you the complete story of every run.
>
> ERROR_CODE, ERROR_MESSAGE, ERROR_DETAILS — when things fail, this is where you look. ERROR_DETAILS is VARIANT, so it can store the full error context as structured JSON.
>
> COPY_COMMAND_EXECUTED stores the literal SQL that was run. This is invaluable for debugging. You can take that exact command, run it manually, and reproduce the issue.
>
> VALIDATION_STATUS and VALIDATION_DETAILS capture post-load check results. Did the row count threshold pass? Were there unexpected nulls?"

**[Run: CREATE TABLE INGESTION_AUDIT_LOG]**

> "Let's create it."

**[Run: ALTER TABLE ... CLUSTER BY]**

> "And the clustering key. Snowflake doesn't have traditional indexes, but clustering keys optimize micro-partition pruning. We cluster by CREATED_AT and SOURCE_NAME because the two most common queries are: show me recent failures, and show me all runs for source X. This clustering key makes both queries fast."

---

## [13:00 - 15:30] THE BUILD — Error Log

**[Highlight INGESTION_ERROR_LOG, lines 101-124]**

> "Next: the error log. This is separate from the audit log for a reason. The audit log has one row per ingestion run. The error log has one row per error — per bad file, per bad row. If a single run has 500 bad rows, that's 500 error log entries but still just one audit log entry. Keeping them separate prevents the audit log from growing uncontrollably.
>
> The key columns: FILE_NAME tells you which file had the problem. ROW_NUMBER tells you which row. COLUMN_NAME tells you which column. REJECTED_RECORD stores the actual bad data. When a stakeholder says 'why didn't my data load,' you can show them the exact row, the exact column, and the exact error."

**[Run: CREATE TABLE INGESTION_ERROR_LOG]**

**[Run: ALTER TABLE ... CLUSTER BY for error log]**

> "Same clustering strategy. Created at and source name."

---

## [15:30 - 19:00] THE BUILD — Supporting Tables (Registries)

**[SLIDE: Supporting Tables — 4 cards showing each table]**

> "Four more tables. These are the supporting cast — not as complex as INGESTION_CONFIG, but they make the framework self-aware."

**[Run: USE SCHEMA CONFIG]**

> "Back to the CONFIG schema."

**[Highlight FILE_FORMAT_REGISTRY, lines 137-149]**

> "FILE_FORMAT_REGISTRY. You might ask — we already have file format objects in Snowflake. Why do we need a table too? Because you can't easily join SHOW FILE FORMATS output with other tables. A registry table is queryable with standard SQL. You can join it with INGESTION_CONFIG to answer questions like: show me all sources using JSON file formats. Show me all active formats. It's a metadata layer on top of Snowflake objects."

**[Run: CREATE TABLE FILE_FORMAT_REGISTRY]**

**[Run: INSERT INTO FILE_FORMAT_REGISTRY — all 10 entries]**

> "Ten entries — matching the ten file formats we created in Module 02. FORMAT_OPTIONS stores the key settings as JSON for quick reference."

**[Highlight STAGE_REGISTRY, lines 169-183]**

> "STAGE_REGISTRY. Same concept for stages. Stage name, fully qualified path, type — internal or external with cloud provider — and the storage integration reference for external stages."

**[Run: CREATE TABLE STAGE_REGISTRY]**

**[Run: INSERT INTO STAGE_REGISTRY — 4 entries]**

> "Four entries for our four internal stages."

**[Highlight NOTIFICATION_CONFIG, lines 197-210]**

> "NOTIFICATION_CONFIG. When the framework needs to alert someone, it looks here. Supports email, Slack webhooks, Teams webhooks, and Snowflake native alerts. You configure who gets notified, on what events, and at what severity level. Notice MIN_SEVERITY — set it to ERROR and you won't get spammed with informational messages."

**[Run: CREATE TABLE NOTIFICATION_CONFIG]**

**[Run: INSERT INTO NOTIFICATION_CONFIG — 2 entries]**

**[Highlight SCHEMA_EVOLUTION_CONFIG, lines 227-242]**

> "SCHEMA_EVOLUTION_CONFIG. When a source adds or removes columns, this table controls how the framework responds. EVOLUTION_MODE has three options: ADD_COLUMNS only adds new columns and never removes existing ones — the safe default. FULL_EVOLUTION allows adding and modifying columns — powerful but dangerous in production. SNAPSHOT creates a new table version when the schema changes.
>
> MAX_NEW_COLUMNS is a safety valve. If a schema change suddenly adds 50 columns, something is probably wrong. Set this to 10, and the framework flags it for human review instead of blindly adding columns."

**[Run: CREATE TABLE SCHEMA_EVOLUTION_CONFIG]**

---

## [19:00 - 23:00] THE BUILD — Sample Configurations

**[Switch back to 01_ingestion_config.sql, scroll to INSERT statements]**

> "Now let's populate the brain. Five sample configurations — each demonstrating a different pattern."

**[Run: INSERT for DEMO_CUSTOMERS_CSV]**

> "Config one: customer data from a CSV file. Standard CSV format, daily APPEND load, priority 10. Notice the NULL_CHECK_COLUMNS — CUSTOMER_ID and CUSTOMER_NAME should never be null. The TAGS field marks this as master data, gold tier, with PII. That PII flag matters for compliance — you can query the config table to find every source that contains personal data."

**[Run: INSERT for DEMO_ORDERS_CSV]**

> "Config two: order transactions. Same format, same frequency, but priority 20 — customers load first, then orders. ROW_COUNT_THRESHOLD is 100 — if a daily orders file has fewer than 100 rows, something is probably wrong and the framework will flag it."

**[Run: INSERT for DEMO_PRODUCTS_CSV]**

> "Config three: products. Different pattern. LOAD_TYPE is TRUNCATE_RELOAD instead of APPEND. Product catalogs are typically small and get full refreshes. Load frequency is WEEKLY, priority 50. Not urgent, not critical. Notice we didn't set ENABLE_VALIDATION — it defaults to TRUE. Defaults do the heavy lifting."

**[Run: INSERT for DEMO_EVENTS_JSON]**

> "Config four: JSON event data from a web analytics API. Different format, different stage — MDF_STG_INTERNAL_JSON. ON_ERROR is SKIP_FILE instead of CONTINUE — if a JSON file is malformed, skip the whole thing rather than loading partial records. LOAD_FREQUENCY is HOURLY, priority 5 — this is high-velocity clickstream data.
>
> And here's the new column in action: FLATTEN_PATH is set to 'events'. That means the JSON has a structure where the records are nested under an 'events' key, and the framework will LATERAL FLATTEN into that path."

**[Run: INSERT for DEMO_SENSORS_PARQUET]**

> "Config five: Parquet data from an IoT platform. MATCH_BY_COLUMN_NAME is CASE_INSENSITIVE — Parquet carries its own schema, so Snowflake matches columns by name rather than position. ENABLE_SCHEMA_EVOLUTION is TRUE — IoT platforms add sensor fields frequently, and we want the framework to handle that automatically."

---

## [23:00 - 27:00] VERIFICATION & RECAP

**[SLIDE: Verification — Let's Prove It Works]**

> "Let's verify everything."

**[Run: SELECT CONFIG_ID, SOURCE_NAME, CLIENT_NAME, SOURCE_TYPE, TARGET path, LOAD_TYPE, LOAD_FREQUENCY, IS_ACTIVE, LOAD_PRIORITY FROM INGESTION_CONFIG ORDER BY LOAD_PRIORITY]**

> "Five configs, ordered by priority. Events at 5, customers at 10, orders at 20, sensors at 15, products at 50. All active. All pointing to different targets. This one query is a dashboard of your entire ingestion landscape."

**[Run: SELECT CLIENT_NAME, COUNT(*), LISTAGG(DISTINCT SOURCE_TYPE), LISTAGG(DISTINCT LOAD_FREQUENCY) FROM INGESTION_CONFIG GROUP BY CLIENT_NAME]**

> "Grouped by client: one client, DEMO, with five sources across three data types and three frequencies. In production, this query tells you at a glance what each client is sending you."

**[Run: DESCRIBE TABLE INGESTION_AUDIT_LOG]**

> "Audit log — all columns present. Ready to record every future run."

**[Run: Table count verification query from 02_audit_and_supporting_tables.sql]**

> "The scorecard: INGESTION_CONFIG has 5 rows. FILE_FORMAT_REGISTRY has 10. STAGE_REGISTRY has 4. NOTIFICATION_CONFIG has 2. Everything checks out."

**[Run: The JOIN query — INGESTION_CONFIG joined with FILE_FORMAT_REGISTRY and STAGE_REGISTRY]**

> "And here's the power of registry tables. One query joins config with format descriptions and stage types. You can see the complete picture: source name, client, data type, how it's parsed, where it's staged, where it lands, how often it runs. This is the query your operations team will live in."

**[SLIDE: Module 03 Recap]**

> "Here's what we built:
>
> Six tables. INGESTION_CONFIG — the brain, 30-plus columns controlling every aspect of ingestion. INGESTION_AUDIT_LOG — the black box recorder. INGESTION_ERROR_LOG — detailed error tracking. FILE_FORMAT_REGISTRY and STAGE_REGISTRY — queryable metadata layers. NOTIFICATION_CONFIG — alerting rules. And SCHEMA_EVOLUTION_CONFIG — change management.
>
> Five sample configurations covering CSV, JSON, and Parquet — each demonstrating different load types, frequencies, priorities, and error handling strategies.
>
> The key insight: adding a new data source to this framework is an INSERT statement. Not a new script. Not a code review. Not a deployment. An INSERT statement."

---

## [27:00 - 28:30] THE BRIDGE

**[SLIDE: How the Tables Relate — flow diagram]**

> "Before we close, look at how everything connects. INGESTION_CONFIG drives the stored procedure — that's Module 04. The procedure reads the config, executes the COPY INTO, and writes the results to INGESTION_AUDIT_LOG. It references FILE_FORMAT_REGISTRY and STAGE_REGISTRY for lookups. It checks NOTIFICATION_CONFIG for alerting. And SCHEMA_EVOLUTION_CONFIG tells it how to handle changes.
>
> The config tables are the brain. The stored procedures — which we build next — are the hands."

---

## [28:30 - 30:00] THE BRIDGE (continued)

> "That's Module 03 — the brain of the framework. We now have the complete metadata layer. The infrastructure from Module 01. The file formats and stages from Module 02. And now the config tables that tie everything together.
>
> In Module 04, we write the engine — the core stored procedure, SP_GENERIC_INGESTION. That procedure will read from the config table we just built, construct COPY INTO statements dynamically, execute them, and log everything to the audit table. One procedure that handles every source type.
>
> All the SQL scripts are in the course repository. Link in the description. I recommend running both scripts in Module 03 yourself — create the tables, insert the sample configs, run the verification queries. Get comfortable with the config table because you'll be working with it for the rest of the course.
>
> See you in Module 04."

---

## B-Roll / Visual Notes

| Timestamp | Visual |
|-----------|--------|
| 0:00-0:15 | Screen recording of INGESTION_CONFIG with 5 rows visible in Snowsight |
| 0:15-0:45 | Course roadmap slide with Module 03 highlighted |
| 0:45-1:30 | Traditional vs metadata-driven comparison slide (side by side) |
| 1:30-2:00 | INGESTION_CONFIG overview slide — "The Heart of the Framework" |
| 2:00-6:30 | Live SQL in Snowsight — walking through column groups in 01_ingestion_config.sql |
| 6:30-9:00 | Continue live SQL — advanced columns, then run CREATE TABLE |
| 9:00-9:30 | Black box recorder concept slide |
| 9:30-13:00 | Live SQL — INGESTION_AUDIT_LOG in 02_audit_and_supporting_tables.sql |
| 13:00-15:30 | Live SQL — INGESTION_ERROR_LOG creation |
| 15:30-16:00 | Supporting tables overview slide (4 cards) |
| 16:00-19:00 | Live SQL — FILE_FORMAT_REGISTRY, STAGE_REGISTRY, NOTIFICATION_CONFIG, SCHEMA_EVOLUTION_CONFIG |
| 19:00-19:30 | Switch back to 01_ingestion_config.sql for sample INSERTs |
| 19:30-23:00 | Live SQL — five INSERT statements with explanation |
| 23:00-27:00 | Verification queries running live, showing results |
| 27:00-28:30 | Flow diagram slide — how tables relate |
| 28:30-30:00 | Module recap slide, then Module 04 preview |
