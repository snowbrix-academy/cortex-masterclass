# Module 05 — CSV Ingestion Lab | Video Script

**Duration:** ~25 minutes
**Type:** 100% Hands-On
**Deliverable:** End-to-end CSV pipeline (3 sources)

---

## [0:00 - 0:15] THE HOOK

**[SCREEN: Snowsight showing query results — RAW_CUSTOMERS table with CUSTOMER_NAME, CUSTOMER_SEGMENT, _MDF_FILE_NAME, _MDF_LOADED_AT columns]**

> "15 customers. 20 orders. 12 products. Three CSV files, three target tables, one stored procedure call. Every row tagged with the source file name, the row number, and the exact timestamp it landed. That's what a metadata-driven pipeline delivers — and you're about to build one from scratch."

---

## [0:15 - 1:30] THE CONTEXT

**[SLIDE: Course Roadmap — Module 05 highlighted]**

> "Welcome to Module 05. This is the first pure hands-on lab in the course. No new theory. No new objects to create. Everything we need already exists — the databases from Module 01, the file formats and stages from Module 02, the config tables from Module 03, the stored procedures from Module 04. This module is where we prove it all works."

**[SLIDE: Lab Scenario — DEMO client with 3 data sources]**

> "Here's the scenario. A new client called DEMO has an ERP system that exports three CSV files:
>
> **customers.csv** — 15 rows of customer master data. Names, emails, addresses, segments.
>
> **orders.csv** — 20 rows of sales orders. Order IDs, amounts, statuses, payment methods.
>
> **products.csv** — 12 rows of product catalog data. Prices, categories, stock quantities.
>
> Our job: get these files from disk into the RAW layer using the MDF framework. Typed columns. Full audit trail. Idempotent re-runs. Let's go."

---

## [1:30 - 3:30] SET CONTEXT & CREATE TARGET TABLES

**[Switch to Snowsight, open 01_csv_ingestion_lab.sql]**

> "First — set the context. Role, database, warehouse."

**[Run: USE ROLE / USE DATABASE / USE WAREHOUSE]**

> "MDF_ADMIN role, MDF_CONTROL_DB database, MDF_INGESTION_WH warehouse. This is the same context we'll use for every ingestion operation."

**[Run: CREATE SCHEMA MDF_RAW_DB.DEMO_ERP]**

> "We need a schema in the raw database for this client. DEMO_ERP. One schema per source system — that's the convention."

**[Run: CREATE TABLE RAW_CUSTOMERS]**

> "Now the target table. Look at this carefully. Every column has an explicit type. CUSTOMER_ID is NUMBER. EMAIL is VARCHAR(300). REGISTRATION_DATE is DATE. IS_ACTIVE is BOOLEAN. We're not dumping everything into VARCHAR — we're defining the schema upfront.
>
> And at the bottom — three metadata columns. These are on every raw table in the framework:
>
> **_MDF_FILE_NAME** — defaults to METADATA$FILENAME. Snowflake automatically populates this with the staged file path during COPY INTO. You always know which file a row came from.
>
> **_MDF_FILE_ROW** — defaults to METADATA$FILE_ROW_NUMBER. The exact row number within the file. Combined with file name, you can trace any record back to its source.
>
> **_MDF_LOADED_AT** — defaults to CURRENT_TIMESTAMP(). When did this row land in Snowflake? Critical for debugging and SLA tracking."

**[Run: CREATE TABLE RAW_ORDERS and RAW_PRODUCTS]**

> "Same pattern for orders and products. Typed columns plus the three MDF metadata columns. Notice orders has NUMBER(12,2) for amounts and TIMESTAMP_NTZ for CREATED_AT. Products has a WEIGHT_KG decimal column and a BOOLEAN for IS_ACTIVE. These types enforce data quality at load time — if a CSV row has 'abc' where a NUMBER is expected, the framework catches it."

**[Run: SHOW TABLES IN SCHEMA MDF_RAW_DB.DEMO_ERP]**

> "Three tables. All ready to receive data."

---

## [3:30 - 7:00] UPLOAD CSV FILES

**[SLIDE: PUT Command Explained]**

> "In production, files land in S3 or Azure Blob automatically — a scheduled export, an SFTP drop, an event trigger. For this lab, we use the PUT command to upload files to an internal stage. PUT is Snowflake's file transfer command. It works in SnowSQL, the Snowflake CLI, and the Python connector. It does not work in Snowsight worksheets — that's a common gotcha."

**[Switch to SnowSQL terminal]**

> "Let me switch to SnowSQL."

**[Run: PUT file://...customers.csv @MDF_CONTROL_DB.CONFIG.MDF_STG_INTERNAL_CSV/demo/customers/ AUTO_COMPRESS=TRUE]**

> "PUT file-colon-slash-slash, then the local path to customers.csv, then the stage path. Notice the stage path structure: the stage name, slash demo, slash customers. This sub-path organization matters — each source gets its own directory within the stage. AUTO_COMPRESS equals TRUE tells Snowflake to gzip the file automatically. Saves storage, speeds up COPY INTO."

**[Run: PUT for orders.csv and products.csv]**

> "Same for orders and products. Each file goes to its own sub-directory."

**[Switch back to Snowsight]**

**[Run: LIST @MDF_CONTROL_DB.CONFIG.MDF_STG_INTERNAL_CSV]**

> "LIST confirms all three files are staged. You can see the file name, size, and the gzip compression. If you uploaded via Snowsight's UI instead of PUT, you'd see the same result here. The method doesn't matter — the stage is the stage."

---

## [7:00 - 9:00] PREVIEW DATA

**[Run: SELECT $1, $2, $3, $4, $5 FROM @stage/demo/customers/ LIMIT 5]**

> "Before we load, we preview. This query reads directly from the stage using positional column references — dollar-one through dollar-five. Combined with the file format, it shows us the parsed data before it hits any table.
>
> Why preview? Catches mismatches. If column three shows a date but your table expects a number, you'll see it here. Always preview before your first load of a new source. After the initial run, the framework handles it."

**[Run: SELECT preview for orders]**

> "Orders look clean. Five columns shown — order ID, customer ID, date, status, amount. The full file has 11 columns, but we're just spot-checking."

---

## [9:00 - 11:00] VERIFY CONFIG ENTRIES

**[Run: SELECT from INGESTION_CONFIG WHERE CLIENT_NAME = 'DEMO']**

> "The config entries for DEMO were inserted in Module 03. Let's verify they're there.
>
> Three rows. DEMO_CUSTOMERS_CSV, DEMO_ORDERS_CSV, DEMO_PRODUCTS_CSV. Each row maps a source name to a stage path, file format, target table, and load type. IS_ACTIVE is TRUE for all three.
>
> This is the single source of truth. The stored procedure reads this config to know what to do. It doesn't hardcode any paths, table names, or file formats. Change the config, change the behavior. That's the metadata-driven approach."

---

## [11:00 - 15:00] RUN THE INGESTION

**[SLIDE: SP_GENERIC_INGESTION Architecture]**

> "This is the moment of truth. One procedure call. It reads the config, builds the COPY INTO statement dynamically, executes it, captures the results, and writes to the audit log. Let's run it."

**[Run: CALL SP_GENERIC_INGESTION('DEMO_CUSTOMERS_CSV', FALSE)]**

> "First parameter — the source name. This matches the SOURCE_NAME column in INGESTION_CONFIG. Second parameter — FALSE means normal mode. TRUE would mean force reload, which re-processes files even if they've been loaded before.
>
> And... success. The procedure returns a result set showing what happened. Files processed, rows loaded, status."

**[Run: CALL SP_GENERIC_INGESTION('DEMO_ORDERS_CSV', FALSE)]**

> "Orders. Same pattern. One call."

**[Run: CALL SP_GENERIC_INGESTION('DEMO_PRODUCTS_CSV', FALSE)]**

> "Products. Done. Three sources loaded. Three procedure calls. In a production environment, you'd run these through a Snowflake Task on a schedule, or trigger them from an external orchestrator like Airflow. We'll set that up in Module 08."

---

## [15:00 - 18:00] CHECK AUDIT LOG

**[Run: SELECT from INGESTION_AUDIT_LOG ORDER BY CREATED_AT DESC LIMIT 10]**

> "Every run writes to the audit log. Let's look."

**[Zoom into the results grid]**

> "Three rows. One per source. Each row shows:
>
> **BATCH_ID** — unique identifier for this run. UUID format. If something fails, you reference this ID.
>
> **RUN_STATUS** — SUCCESS for all three.
>
> **FILES_PROCESSED** — one file each. That's correct — we uploaded one CSV per source.
>
> **ROWS_LOADED** — 15 for customers, 20 for orders, 12 for products. Matches exactly what we expected.
>
> **ROWS_FAILED** — zero across the board. No parse errors, no type mismatches.
>
> **DURATION_SECONDS** — sub-second for all three. These are small files, but the same procedure handles gigabyte-scale loads."

**[Run: Detailed audit query for DEMO_CUSTOMERS_CSV]**

> "The detailed view also shows COPY_COMMAND_EXECUTED — the exact COPY INTO statement the procedure generated. And FILES_LIST — every file that was processed. This is full traceability. If an audit asks 'what SQL ran and which files were loaded at 2 PM on Tuesday,' you have the answer."

---

## [18:00 - 20:30] VERIFY LOADED DATA

**[Run: Row count UNION ALL query across all three tables]**

> "Row counts. RAW_CUSTOMERS: 15. RAW_ORDERS: 20. RAW_PRODUCTS: 12. All accounted for."

**[Run: SELECT customer data with MDF metadata columns]**

> "Here's the payoff. Customer data — name, segment, and the three metadata columns. _MDF_FILE_NAME shows the full stage path: MDF_STG_INTERNAL_CSV/demo/customers/customers.csv.gz. _MDF_FILE_ROW shows the row number from the original file. _MDF_LOADED_AT shows the exact load timestamp.
>
> Every row is self-documenting. You never have to guess where data came from."

**[Run: SELECT order data with ORDER BY ORDER_DATE DESC]**

> "Orders sorted by date. Total amounts, statuses, payment methods — all properly typed. Notice TOTAL_AMOUNT is a proper numeric — we can aggregate it, average it, no casting required."

**[Run: Data quality check — NULL customer IDs]**

> "Quick quality check: any orders with NULL customer IDs? Zero. Clean data, clean load."

---

## [20:30 - 23:00] IDEMPOTENCY TEST

**[SLIDE: Idempotency — What It Means]**

> "Idempotency. Run the same operation twice, get the same result. This is non-negotiable for production pipelines. If a task retries after a timeout, if someone accidentally runs the script twice, if a scheduler double-fires — the data should not duplicate."

**[Run: CALL SP_GENERIC_INGESTION('DEMO_CUSTOMERS_CSV', FALSE)]**

> "Same call. Same source. Same parameters. Watch the result."

**[Zoom into results]**

> "FILES_PROCESSED: zero. ROWS_LOADED: zero. The procedure ran, checked the stage, found that customers.csv.gz had already been loaded, and skipped it. This is Snowflake's native COPY INTO behavior — it tracks loaded files in metadata. Our framework inherits this automatically."

**[Run: Audit log showing last two runs side by side]**

> "The audit log shows both runs. The first: SUCCESS, 1 file, 15 rows. The second: SKIPPED or SUCCESS with 0 files, 0 rows. No duplicates in the table. No manual deduplication needed.
>
> And if you ever need to force a reload — maybe the source corrected the data — you pass TRUE as the second parameter. That overrides the skip logic. But in normal operations, FALSE is what you want."

---

## [23:00 - 24:00] VERIFICATION & RECAP

**[SLIDE: What We Proved]**

> "Let's step back and look at what this lab proved:
>
> **One** — the MDF framework ingests CSV data end-to-end. From file upload to queryable table.
>
> **Two** — typed columns enforce schema at load time. Not everything is VARCHAR.
>
> **Three** — metadata columns trace every row to its source file and row number.
>
> **Four** — the audit log captures every run with full detail — files, rows, duration, the exact SQL.
>
> **Five** — idempotency works out of the box. Re-runs don't duplicate data.
>
> This is the production pattern. The same steps — config, stage, call, verify — apply whether you're loading 3 files or 3,000."

---

## [24:00 - 25:00] THE BRIDGE

> "That's Module 05 — CSV ingestion, end to end. CSV is the most common format you'll encounter, but it's not the only one.
>
> In Module 06, we handle semi-structured data — JSON and Parquet. The workflow is the same: config, stage, call, verify. But the table design is different. Instead of typed columns, we land JSON into a single VARIANT column and Parquet into its inferred schema. Same framework, different strategy.
>
> Try the four exercises at the bottom of the lab script before moving on. Register a new source, handle a bad file, test truncate-reload, and explore the metadata columns. These reinforce the patterns you'll use in every module going forward.
>
> All scripts are in the course repository. Link in the description.
>
> See you in Module 06."

---

## B-Roll / Visual Notes

| Timestamp | Visual |
|-----------|--------|
| 0:00-0:15 | Screen recording of RAW_CUSTOMERS query results with metadata columns visible |
| 0:15-1:30 | Course roadmap slide (Module 05 highlighted) → Lab scenario slide (3 data cards) |
| 1:30-2:00 | Live SQL — USE ROLE / DATABASE / WAREHOUSE |
| 2:00-3:30 | Live SQL — CREATE SCHEMA and CREATE TABLE statements, zoom on _MDF_ columns |
| 3:30-4:00 | PUT command explanation slide |
| 4:00-7:00 | SnowSQL terminal — PUT commands for all 3 files → LIST verification |
| 7:00-9:00 | Snowsight — stage preview queries with positional columns |
| 9:00-11:00 | Snowsight — INGESTION_CONFIG query, zoom on SOURCE_NAME and TARGET columns |
| 11:00-11:30 | SP_GENERIC_INGESTION architecture slide |
| 11:30-15:00 | Live SQL — three CALL statements with result sets |
| 15:00-18:00 | Audit log queries, zoom on BATCH_ID, FILES_PROCESSED, ROWS_LOADED |
| 18:00-20:30 | Data verification queries — row counts, sample data, quality checks |
| 20:30-21:00 | Idempotency concept slide |
| 21:00-23:00 | Live SQL — re-run showing 0 files/rows, audit log comparison |
| 23:00-24:00 | Recap slide — five key takeaways |
| 24:00-25:00 | Module 06 preview slide → outro |
