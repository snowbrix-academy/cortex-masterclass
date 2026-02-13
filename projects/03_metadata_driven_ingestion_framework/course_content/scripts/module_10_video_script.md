# Module 10 — Schema Evolution & Advanced Topics | Video Script

**Duration:** ~25 minutes
**Type:** Advanced + Demo
**Deliverable:** Schema evolution + multi-client onboarding

---

## [0:00 - 0:15] THE HOOK

**[SCREEN: Snowsight showing SP_ONBOARD_CLIENT result — 3 sources registered in one call]**

> "One procedure call. Three data sources. A new client fully onboarded in under a second. And when their files change schema next month — new columns, different types — the framework handles it automatically. No tickets. No manual ALTER TABLEs. That's Module 10."

---

## [0:15 - 1:30] THE CONTEXT

**[SLIDE: Course Roadmap — Module 10 highlighted, all previous modules shown as complete]**

> "Welcome to Module 10 — the final module. Over the last nine modules, we built a complete metadata-driven ingestion framework: databases, warehouses, roles, config tables, stored procedures, CSV ingestion, JSON and Parquet handling, error recovery, automated tasks and streams, monitoring dashboards. All of it."

**[SLIDE: Module 10 Overview — Schema Evolution + Multi-Client + Advanced]**

> "This module adds three capabilities that separate a demo framework from a production one:
>
> **Schema evolution** — automatically detecting and adapting to changes in source file structures.
>
> **Multi-client onboarding** — registering an entire client with multiple data sources in a single call.
>
> **Advanced patterns** — Dynamic Tables for real-time staging, and the production deployment checklist you'll need when this goes live.
>
> Let's start with the problem that every data pipeline hits eventually."

---

## [1:30 - 4:00] THE SCHEMA DRIFT PROBLEM

**[SLIDE: Schema Drift — What Happens When Sources Change]**

> "Schema drift. Your source system adds a column. Maybe the vendor updates their API, or someone in finance adds a field to the export. Your COPY INTO fails. Or worse — it succeeds but silently drops the new data.
>
> There are three scenarios we need to handle:
>
> **Scenario 1: New column appears.** The file has a column that the table doesn't. We need to detect it, add the column, and reload.
>
> **Scenario 2: Column type changes.** A field that was a NUMBER is now coming in as VARCHAR. We need to widen the type, never narrow it.
>
> **Scenario 3: Column disappears.** The file stops including a column. We keep the column in the table — downstream queries depend on it — but new rows get NULLs for that field.
>
> The golden rule: **never drop columns. Only add or widen.** Dropping a column breaks every view, every report, every downstream dependency that references it."

---

## [4:00 - 8:00] SP_DETECT_SCHEMA_CHANGES — LIVE

**[SLIDE: SP_DETECT_SCHEMA_CHANGES Architecture Diagram]**

> "First procedure: SP_DETECT_SCHEMA_CHANGES. This is a read-only operation. Safe to run anytime, against any source. It doesn't modify anything."

**[Switch to Snowsight, open 01_schema_evolution.sql]**

> "Here's how it works. It takes a SOURCE_NAME, looks up the config, then calls Snowflake's INFER_SCHEMA function against the stage files. INFER_SCHEMA reads the file headers — for CSV, the column names and positions; for Parquet, the embedded schema metadata — and returns the column definitions."

**[Highlight the INFER_SCHEMA call in the procedure]**

> "It then runs DESCRIBE TABLE on the target table to get the current schema. Now it has two sets of columns: what the file says, and what the table has.
>
> The comparison logic is straightforward. For each column in the file that isn't in the table — that's a new column. For each column in the table that isn't in the file — that's a missing column. The result comes back as a JSON object."

**[Run: CALL SP_DETECT_SCHEMA_CHANGES('DEMO_CUSTOMERS_CSV')]**

> "Let's run it. CALL SP_DETECT_SCHEMA_CHANGES with our demo customers source. Look at the result — changes_detected, new_columns array, missing_columns array, type_changes array. Everything you need to decide what to do next.
>
> Notice the status field: CHECKED. This is informational. Nothing changed in the database. You can run this in production as a scheduled health check without any risk."

---

## [8:00 - 12:30] SP_APPLY_SCHEMA_EVOLUTION — LIVE

**[SLIDE: SP_APPLY_SCHEMA_EVOLUTION — Dry Run vs Apply]**

> "Detection is step one. Step two is applying the changes. SP_APPLY_SCHEMA_EVOLUTION takes the same SOURCE_NAME, plus a critical parameter: P_DRY_RUN.
>
> DRY_RUN defaults to TRUE. This means by default, the procedure tells you what it *would* do without actually doing it. You have to explicitly set DRY_RUN to FALSE to apply changes. Defense in depth."

**[Switch to Snowsight, highlight the procedure code]**

> "Inside the procedure, three safety mechanisms:
>
> **First**, it calls SP_DETECT_SCHEMA_CHANGES internally. Same detection logic, guaranteed consistency.
>
> **Second**, the MAX_NEW_COLUMNS limit. Default is 10. If the file suddenly has 50 new columns, something is wrong — maybe the wrong file landed in the stage. The procedure blocks and tells you to review manually.
>
> **Third**, it only runs ALTER TABLE ADD COLUMN. Never ALTER COLUMN, never DROP COLUMN. The blast radius is limited to additive changes only."

**[Run: CALL SP_APPLY_SCHEMA_EVOLUTION('DEMO_CUSTOMERS_CSV', TRUE)]**

> "Dry run first. Look at the actions array — each entry shows the column name, the type, the exact ALTER TABLE SQL it would execute, and applied: false. This is your review step."

**[Run: CALL SP_APPLY_SCHEMA_EVOLUTION('DEMO_CUSTOMERS_CSV', FALSE)]**

> "Now with DRY_RUN set to FALSE. Same actions array, but now applied: true. The columns are in the table. Run a DESCRIBE TABLE to confirm — there are the new columns, ready for the next load.
>
> This is how you handle schema evolution in production. Detect, review, apply. Three steps, full visibility, no surprises."

---

## [12:30 - 16:00] MULTI-CLIENT ARCHITECTURE

**[SLIDE: Multi-Client Architecture — Schema-Per-Client Isolation]**

> "Now let's talk about scaling the framework to multiple clients. If you're a consultancy, an MSP, or any team that manages data pipelines for multiple business units — you need isolation.
>
> The pattern: one schema per client in each data layer. Client ACME gets RAW.ACME, STAGING.ACME, CURATED.ACME. Client GLOBEX gets RAW.GLOBEX, STAGING.GLOBEX, CURATED.GLOBEX.
>
> Why schema-level isolation instead of database-level? Fewer objects to manage. RBAC grants at the schema level give you the same data isolation without the overhead of separate databases per client."

**[SLIDE: SP_ONBOARD_CLIENT — Accepts JSON Array]**

> "SP_ONBOARD_CLIENT automates this. It takes a client name and a JSON array of source definitions. Each source definition specifies the name, the file type, the target table, and the file pattern.
>
> One call registers all sources for a client. It creates the config entries, sets up the sub-directories, assigns the naming convention — CLIENT_SOURCE for every object."

**[Switch to Snowsight, highlight the SP_ONBOARD_CLIENT code]**

> "Look at the loop. For each source in the array, it calls SP_REGISTER_SOURCE — the same procedure we built in Module 04. It's composing existing building blocks. That's the benefit of a modular framework.
>
> The source name is automatically prefixed with the client name. ACME_CORP plus SALES_CSV becomes ACME_CORP_SALES_CSV. Self-documenting. You can tell the client and the source from the name alone."

**[Run: CALL SP_ONBOARD_CLIENT with 3 sources]**

```sql
CALL SP_ONBOARD_CLIENT(
    'NEWCLIENT',
    PARSE_JSON('[
        {"name": "INVOICES", "type": "CSV", "table": "RAW_INVOICES", "pattern": ".*invoices.*[.]csv"},
        {"name": "PAYMENTS", "type": "JSON", "table": "RAW_PAYMENTS", "pattern": ".*payments.*[.]json"},
        {"name": "METRICS",  "type": "PARQUET", "table": "RAW_METRICS", "pattern": ".*metrics.*[.]parquet"}
    ]')
);
```

> "Three sources registered. Look at the result: sources_registered: 3, sources_failed: 0. Each detail entry shows the source name and status. Now query INGESTION_CONFIG filtered by CLIENT_NAME — all three are there, active, ready to ingest."

---

## [16:00 - 18:30] DYNAMIC TABLES — PREVIEW

**[SLIDE: Dynamic Tables — Automatic Staging Without Tasks]**

> "One more advanced pattern before we wrap up: Dynamic Tables. This is a preview — the code is commented in the lab script, ready for you to experiment with.
>
> Dynamic Tables replace the manual pattern of tasks and streams for transforming data from RAW to STAGING. Instead of writing a task that runs every 15 minutes, you write a SELECT statement and tell Snowflake: keep this fresh within 5 minutes of the source changing."

**[Show the commented Dynamic Table SQL]**

```sql
CREATE OR REPLACE DYNAMIC TABLE MDF_STAGING_DB.DEMO_WEB.DT_EVENTS_FLATTENED
    TARGET_LAG = '5 MINUTES'
    WAREHOUSE = MDF_TRANSFORM_WH
AS
SELECT
    RAW_DATA:event_id::VARCHAR           AS EVENT_ID,
    RAW_DATA:event_type::VARCHAR         AS EVENT_TYPE,
    RAW_DATA:user_id::VARCHAR            AS USER_ID,
    RAW_DATA:timestamp::TIMESTAMP_TZ     AS EVENT_TIMESTAMP,
    RAW_DATA:page_url::VARCHAR           AS PAGE_URL,
    RAW_DATA:device.type::VARCHAR        AS DEVICE_TYPE,
    RAW_DATA:geo.country::VARCHAR        AS COUNTRY,
    _MDF_LOADED_AT
FROM MDF_RAW_DB.DEMO_WEB.RAW_EVENTS;
```

> "TARGET_LAG is the key parameter. Five minutes means Snowflake guarantees the Dynamic Table is never more than five minutes stale relative to the source. You can set this to one minute, one hour, or one day — depending on your freshness requirements and your compute budget.
>
> The trade-off is cost. Every refresh cycle uses warehouse compute. A one-minute lag on a large table is expensive. A one-day lag is cheap. Choose based on business need, not default."

---

## [18:30 - 22:00] VERIFICATION & RECAP

**[Switch to Snowsight, run verification queries]**

> "Let's verify everything from this module."

**[Run: SHOW PROCEDURES LIKE 'SP_DETECT%' and 'SP_APPLY%' and 'SP_ONBOARD%']**

> "Three new procedures: SP_DETECT_SCHEMA_CHANGES, SP_APPLY_SCHEMA_EVOLUTION, SP_ONBOARD_CLIENT. All in MDF_CONTROL_DB.PROCEDURES."

**[Run: SELECT from INGESTION_CONFIG showing onboarded client]**

> "INGESTION_CONFIG now has the onboarded client's sources — all three, all active, all with the right naming convention and file patterns."

**[Run: SP_DETECT_SCHEMA_CHANGES one more time to show clean output]**

> "And schema detection returns a clean check — no new columns, no missing columns. The table matches the file. That's the state you want in production."

---

## [22:00 - 24:00] COURSE WRAP-UP

**[SLIDE: Course Complete — All 10 Modules]**

> "That's Module 10. And that's the entire course. Let me show you what you've built across ten modules:
>
> **Module 01** — Foundation. Four databases, four warehouses, five RBAC roles with least-privilege access.
>
> **Module 02** — File Formats and Stages. Ten named file formats covering CSV, JSON, Parquet, Avro, ORC. Four internal stages with directory tables.
>
> **Module 03** — Config Tables. The INGESTION_CONFIG table — the brain of the framework. One table controlling every data source.
>
> **Module 04** — Core Stored Procedures. SP_REGISTER_SOURCE, SP_GENERIC_INGESTION, SP_VALIDATE_LOAD. The engine.
>
> **Module 05** — Structured Data. End-to-end CSV ingestion with validation and error handling.
>
> **Module 06** — Semi-Structured Data. JSON flattening, Parquet ingestion, VARIANT column handling.
>
> **Module 07** — Error Handling and Audit. The audit log, the error recovery table, retry logic.
>
> **Module 08** — Automation. Tasks for scheduled ingestion, streams for change data capture.
>
> **Module 09** — Monitoring and Dashboards. Real-time views into pipeline health, load history, error rates.
>
> **Module 10** — Schema Evolution and Multi-Client Onboarding. The procedures that handle change and scale.
>
> That's a production-grade metadata-driven ingestion framework. Not a tutorial toy. A real system that handles structured and semi-structured data, monitors itself, recovers from errors, and adapts to schema changes."

---

## [24:00 - 25:00] PRODUCTION DEPLOYMENT ADVICE & CLOSE

**[SLIDE: Production Deployment Checklist]**

> "Before you deploy this to production, five things:
>
> **One** — Resource monitors on every warehouse. We set these up in Module 01. Double-check them before going live.
>
> **Two** — Network policies. Restrict which IPs can access your Snowflake account. This is account-level security that goes beyond RBAC.
>
> **Three** — Alert integrations. Connect the monitoring views to Slack, PagerDuty, or email. A dashboard nobody checks is decoration, not monitoring.
>
> **Four** — Backup your config table. INGESTION_CONFIG is the brain. If it gets corrupted, everything stops. Time Travel gives you 90 days, but consider exporting it regularly.
>
> **Five** — Document your sources. Each row in INGESTION_CONFIG should have a meaningful DESCRIPTION. Future you will thank present you.
>
> All ten modules of SQL scripts, sample data, and these slide decks are in the course repository. Link in the description.
>
> This has been the Metadata-Driven Ingestion Framework course from Snowbrix Academy. Go build something production-ready. See you in the next course."

---

## B-Roll / Visual Notes

| Timestamp | Visual |
|-----------|--------|
| 0:00-0:15 | Screen recording of SP_ONBOARD_CLIENT result in Snowsight |
| 0:15-1:30 | Course roadmap slide (all modules) → Module 10 overview slide |
| 1:30-4:00 | Schema drift problem slide → Three scenarios diagram |
| 4:00-4:30 | SP_DETECT_SCHEMA_CHANGES architecture slide |
| 4:30-8:00 | Live SQL in Snowsight — walking through detection procedure code and execution |
| 8:00-8:30 | SP_APPLY_SCHEMA_EVOLUTION dry run vs apply slide |
| 8:30-12:30 | Live SQL — dry run execution, then apply execution, then DESCRIBE TABLE |
| 12:30-13:30 | Multi-client architecture slide — schema-per-client diagram |
| 13:30-14:30 | SP_ONBOARD_CLIENT overview slide |
| 14:30-16:00 | Live SQL — SP_ONBOARD_CLIENT execution and config verification |
| 16:00-16:30 | Dynamic Tables concept slide |
| 16:30-18:30 | Code walkthrough — commented Dynamic Table example |
| 18:30-22:00 | Verification queries running live |
| 22:00-24:00 | Course complete slide — all 10 modules recap |
| 24:00-25:00 | Production checklist slide → Snowbrix Academy closing |
