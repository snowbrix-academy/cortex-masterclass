# Module 01 — Foundation Setup | Video Script

**Duration:** ~25 minutes
**Type:** Architecture + Hands-On
**Deliverable:** 4 databases, 4 warehouses, 5 RBAC roles

---

## [0:00 - 0:15] THE HOOK

**[SCREEN: Snowsight showing SHOW DATABASES LIKE 'MDF_%' with 4 databases listed]**

> "Four databases. Four warehouses. Five roles. A complete multi-layer architecture with cost controls and security baked in from day one. That's what we're building in the next 25 minutes. And every module after this one depends on getting this right."

---

## [0:15 - 1:30] THE CONTEXT

**[SLIDE: Course Intro — Module 01 highlighted in roadmap]**

> "Welcome to Module 01 of the Metadata-Driven Ingestion Framework. This is the foundation. Everything we build in the next 10 modules sits on top of what we create here."

**[SLIDE: Architecture diagram showing the 4 databases]**

> "Here's the architecture. We're building a four-database structure:
>
> **MDF_CONTROL_DB** — this is the brain. Config tables, stored procedures, audit logs, monitoring views. This database runs the framework.
>
> **MDF_RAW_DB** — the landing zone. Data comes in here exactly as-is from source files. No transformations. No cleaning. Raw.
>
> **MDF_STAGING_DB** — cleaned and validated data. Quality checks happen here.
>
> **MDF_CURATED_DB** — business-ready data. This is what your analysts query.
>
> Why separate databases? Isolation. Security. Cost tracking. You can grant an analyst access to CURATED without them ever seeing RAW. That's not an accident — it's a design decision."

---

## [1:30 - 7:00] DATABASES & SCHEMAS

**[SWITCH TO: Snowsight worksheet]**

> "Let's build it. I'm going to switch to Snowsight and run through the SQL step by step."

**[Run: 01_databases_and_schemas.sql]**

> "First, we set the role to ACCOUNTADMIN. You need this for creating databases.

**[Run CREATE DATABASE MDF_CONTROL_DB]**

> "MDF_CONTROL_DB — the control database. Notice the COMMENT. Every object we create gets a comment explaining its purpose. When someone new joins your team six months from now, they'll understand what this is without asking."

**[Run CREATE SCHEMA statements for CONFIG, AUDIT, PROCEDURES, MONITORING]**

> "Four schemas inside the control database. Each schema has a specific job:
> - CONFIG stores all the configuration tables
> - AUDIT stores run history and error logs
> - PROCEDURES holds all stored procedures
> - MONITORING has the dashboard views
>
> Separation of concerns. The same principle that makes good application code makes good database design."

**[Run CREATE DATABASE for RAW, STAGING, CURATED]**

> "Now the data layer databases. RAW, STAGING, CURATED. Three layers.
>
> Here's the rule for RAW: **never transform data in RAW**. It's your safety net. If a transformation goes wrong downstream, you can always re-process from the original source data. The moment you modify data in RAW, you've lost that ability."

**[Run SHOW DATABASES and SHOW SCHEMAS verification queries]**

> "Let's verify. SHOW DATABASES LIKE 'MDF_%' — there are our four databases. SHOW SCHEMAS confirms the control schemas are in place."

---

## [7:00 - 14:00] WAREHOUSES & RESOURCE MONITORS

**[SLIDE: Why separate warehouses diagram]**

> "Next: compute. We're creating four warehouses, and there's a reason for each one."

**[SLIDE: Warehouse sizing table]**

> "MDF_INGESTION_WH — SMALL, for COPY INTO. These operations are I/O heavy, not compute heavy. A SMALL warehouse is typically more than enough.
>
> MDF_TRANSFORM_WH — MEDIUM, for staging transforms. This is where compute actually matters.
>
> MDF_MONITORING_WH — XSMALL, for dashboard queries. These are lightweight SELECTs on audit tables.
>
> MDF_ADMIN_WH — SMALL, for procedure execution.
>
> Why not one warehouse for everything? Cost attribution. When your CFO asks 'Why is our Snowflake bill $40K this month?', you can point to exactly which workload caused the spike. Ingestion cost $5K. Transforms cost $30K. That's actionable information."

**[Switch to Snowsight, run 02_warehouses.sql]**

> "Let's create them."

**[Run CREATE WAREHOUSE statements]**

> "Notice the key settings:
> - **AUTO_SUSPEND = 60** — suspends after 60 seconds idle. For ingestion, this is the sweet spot. COPY INTO is bursty — load, idle, load, idle.
> - **INITIALLY_SUSPENDED = TRUE** — don't start billing the moment we create it.
> - **MAX_CLUSTER_COUNT = 2** for ingestion — allows Snowflake to spin up a second cluster during parallel loads."

**[Run CREATE RESOURCE MONITOR statements]**

> "Resource monitors. These are your financial guardrails. I cannot stress this enough: **set resource monitors before you start loading data, not after you get the bill.**
>
> We've seen clients burn through their entire monthly budget overnight because of a misconfigured task. A single bad query with auto-resume enabled on an XL warehouse at 3 AM — $18K by morning.
>
> 75% — you get a notification. 100% — the warehouse suspends. 110% — force suspend. No exceptions."

---

## [14:00 - 22:00] ROLES & RBAC

**[SLIDE: Role hierarchy diagram]**

> "Security. This is where most teams get lazy. They give everyone SYSADMIN and call it a day. In production, that's a liability."

**[SLIDE: Role definitions table]**

> "We're building five functional roles:
>
> **MDF_ADMIN** — full control. This is for the framework owner.
> **MDF_DEVELOPER** — can modify procedures and configs. For your engineering team.
> **MDF_LOADER** — can execute COPY INTO, write to RAW. This is the service account role.
> **MDF_TRANSFORMER** — can read RAW, write to STAGING/CURATED.
> **MDF_READER** — read-only. Monitoring views and curated data.
>
> Notice the hierarchy: MDF_READER is the base. MDF_LOADER inherits from READER. MDF_ADMIN inherits from everything. This means if we grant something to READER, everyone above it gets it too."

**[Switch to Snowsight, run 03_roles_and_grants.sql]**

> "The key design principle here: **functional roles, not user roles**. 'MDF_LOADER' makes sense whether John or Jane is running the loads. 'JOHN_ROLE' doesn't."

**[Run role creation and hierarchy grants]**

> "Future grants. This is critical."

**[Run GRANT ... ON FUTURE ... statements]**

> "Without future grants, every new table, view, or procedure you create requires a manual GRANT statement. Future grants mean new objects automatically inherit the right permissions. Set it once, it works forever.
>
> Also notice: the LOADER role can only write to RAW. If the ingestion process is compromised — a bad script, a SQL injection, whatever — the blast radius is limited to raw data only. Staging and curated are untouched."

---

## [22:00 - 24:00] VERIFICATION & RECAP

**[Run all verification queries]**

> "Let's verify everything. SHOW ROLES — there are our five MDF roles. SHOW GRANTS confirms the hierarchy. SHOW DATABASES, SHOW WAREHOUSES — all present."

**[SLIDE: Module 01 Recap]**

> "Here's what we built in 25 minutes:
> - 4 databases with a clear multi-layer architecture
> - 4 purpose-specific warehouses with auto-suspend and resource monitors
> - 5 functional roles with least-privilege access and future grants
>
> This foundation is the same architecture we deploy for production clients. The scale changes. The design doesn't."

---

## [24:00 - 25:00] THE BRIDGE

> "That's Module 01 — the foundation. In Module 02, we'll create the file formats and stages. That's where we define *how* the framework reads different file types — CSV, JSON, Parquet — and *where* it finds them.
>
> All the SQL scripts are in the course repository. Link in the description. Run them yourself before the next module.
>
> See you in Module 02."

---

## B-Roll / Visual Notes

| Timestamp | Visual |
|-----------|--------|
| 0:00-0:15 | Screen recording of SHOW DATABASES output |
| 0:15-1:30 | Architecture slide → Course roadmap slide |
| 1:30-7:00 | Live SQL execution in Snowsight (dark theme) |
| 7:00-7:30 | Warehouse sizing slide |
| 7:30-14:00 | Live SQL + zoom into AUTO_SUSPEND and RESOURCE_MONITOR |
| 14:00-14:30 | Role hierarchy diagram slide |
| 14:30-22:00 | Live SQL + zoom into FUTURE GRANTS |
| 22:00-24:00 | Verification queries running live |
| 24:00-25:00 | Module recap slide → Module 02 preview |
