# Module 04 — Core Stored Procedures | Video Script

**Duration:** ~35 minutes
**Type:** Deep Dive + Live Coding
**Deliverable:** SP_GENERIC_INGESTION + 4 supporting procedures

---

## [0:00 - 0:15] THE HOOK

**[SCREEN: Snowsight showing the result of CALL SP_GENERIC_INGESTION('ALL', FALSE) — a VARIANT JSON response with batch_id, overall_status: SUCCESS, sources_processed: 3, and a details array]**

> "One procedure call. Every active data source — CSV, JSON, Parquet — loaded, logged, and verified. No manual COPY INTO. No per-source scripts. One line: CALL SP_GENERIC_INGESTION('ALL', FALSE). That's the engine we're building today."

---

## [0:15 - 1:30] THE CONTEXT

**[SLIDE: Course Roadmap — Module 04 highlighted]**

> "Welcome to Module 04. This is the most important module in the course. In Modules 01 through 03, we built the infrastructure — databases, warehouses, file formats, stages, config tables. All of that was setup. Today, we write the code that makes it all work."

**[SLIDE: What We're Building — 5 procedures overview]**

> "We're building five stored procedures:
>
> **SP_GENERATE_BATCH_ID** — creates a UUID to correlate every action in a single run.
>
> **SP_LOG_INGESTION** — writes start and end records to the audit log.
>
> **SP_LOG_ERROR** — captures individual file and row errors.
>
> **SP_GENERIC_INGESTION** — the main engine. It reads config, builds COPY INTO dynamically, executes it, captures results, and logs everything.
>
> **SP_REGISTER_SOURCE** — a simplified 10-parameter interface so onboarding a new source takes 30 seconds instead of writing a 30-column INSERT.
>
> SP_GENERIC_INGESTION is the centerpiece. Everything else supports it."

---

## [1:30 - 4:00] WHY JAVASCRIPT FOR STORED PROCEDURES

**[SLIDE: JavaScript vs SQL Script comparison]**

> "Before we write code, let's address the question: why JavaScript? Snowflake supports two procedural languages — SQL Script and JavaScript. Both work. Here's why we chose JavaScript.
>
> **Error handling.** JavaScript gives you try/catch with real exception objects. You get the error message, the error code, and you can catch specific errors differently. SQL Script has exception handlers, but they're less flexible when you need to branch logic based on error type.
>
> **Dynamic SQL.** We're building COPY INTO statements on the fly — assembling strings from config values. JavaScript string concatenation is straightforward. You build the SQL string, you execute it, you capture the result set.
>
> **Variable management.** We need to track file counts, row counts, error counts, build JSON arrays of results. JavaScript objects and arrays handle this naturally. No declaring every variable at the top of a BEGIN block.
>
> **Return types.** SP_GENERIC_INGESTION returns a VARIANT — a JSON object with batch_id, status, source details. JavaScript objects map directly to Snowflake VARIANT. You build the object in JavaScript, return it, and the caller gets structured JSON they can query with dot notation.
>
> One trade-off: JavaScript procedures use EXECUTE AS CALLER, which means they run with the caller's permissions. That actually fits our RBAC model — the MDF_LOADER role calls the procedure, and it can only write to RAW. Least privilege enforced by design."

---

## [4:00 - 7:00] SP_GENERATE_BATCH_ID & AUDIT LOGGING

**[Switch to Snowsight, open 01_sp_audit_log.sql]**

> "Let's start with the foundation: logging. Every procedure we build after this depends on logging, so we build it first."

**[Run: CREATE PROCEDURE SP_GENERATE_BATCH_ID]**

> "SP_GENERATE_BATCH_ID. Three lines of JavaScript. It calls UUID_STRING() and returns a unique identifier. Every ingestion run gets a batch ID. Every audit log entry, every error record, every validation result shares that same batch ID. It's your correlation key.
>
> When something goes wrong at 2 AM and you're debugging the next morning, you search by batch ID and you see the complete story — what started, what loaded, what failed, what errored. One ID connects it all."

**[Run: CALL SP_GENERATE_BATCH_ID() — show the UUID result]**

> "UUID. Unique every time. Simple."

**[Run: CREATE PROCEDURE SP_LOG_INGESTION]**

> "SP_LOG_INGESTION. This takes 17 parameters, but the logic is straightforward. It handles two actions: START and END.
>
> On START, it INSERTs a new row into INGESTION_AUDIT_LOG with the batch ID, config ID, source name, and a status of 'STARTED'. Start time is CURRENT_TIMESTAMP.
>
> On END, it UPDATEs that same row — fills in the end time, calculates duration in seconds, sets the final status, records file counts, row counts, bytes loaded, the actual COPY command that executed, and the COPY result as JSON.
>
> Notice the bind variables — :1, :2, :3. Never concatenate user-supplied values into SQL strings. That's SQL injection waiting to happen. Bind variables are parameterized and safe."

**[Run: CREATE PROCEDURE SP_LOG_ERROR]**

> "SP_LOG_ERROR. When individual files fail or rows get rejected, this procedure captures the details — which file, which row, which column, what the error was, and the rejected record itself. This feeds the error dashboard we'll build in Module 09."

**[Run: Verification — CALL SP_GENERATE_BATCH_ID, then SP_LOG_INGESTION START and END test calls]**

> "Let's test. Generate a batch ID. Log a start. Verify the record. Log an end with some dummy metrics. Verify the update. Duration calculated automatically. Clean up the test data."

---

## [7:00 - 10:00] SP_GENERIC_INGESTION — ARCHITECTURE OVERVIEW

**[SLIDE: Execution Flow — 8-step diagram]**

> "Now the main event. SP_GENERIC_INGESTION. Before we look at code, let's understand the execution flow. Eight steps:
>
> **Step 1: Read Config.** Query INGESTION_CONFIG for the source name. If the caller passes 'ALL', it queries all active sources ordered by load priority.
>
> **Step 2: Validate.** Check the config has required fields — stage name, file format, target database.
>
> **Step 3: Auto-Create Target.** If AUTO_CREATE_TARGET is true, create the schema and table automatically. This is where it gets interesting — the table structure depends on the source type.
>
> **Step 4: Handle Load Type.** If the config says TRUNCATE_RELOAD, truncate the target table first. If APPEND, skip this step.
>
> **Step 5: Generate COPY INTO.** Build the COPY INTO statement dynamically from config values. Different source types produce different SQL.
>
> **Step 6: Execute.** Run the generated SQL.
>
> **Step 7: Capture Results.** Iterate through the COPY result set. Count files loaded, files skipped, files failed. Sum rows and bytes. Build a JSON array of file-level details.
>
> **Step 8: Log and Return.** Write the audit log. Return a JSON summary to the caller.
>
> Each source runs independently. If source A fails, source B still runs. Error isolation."

---

## [10:00 - 14:00] SP_GENERIC_INGESTION — HELPER FUNCTIONS

**[Switch to Snowsight, open 02_sp_generic_ingestion.sql]**

> "Let's walk through the code. I'm going to highlight the key sections rather than read every line."

**[Scroll to the helper functions section]**

> "First, the helper functions. Four of them.
>
> **executeSql** — wraps snowflake.createStatement with error handling. Every SQL call goes through this function. If it fails, the error message includes the first 200 characters of the SQL that caused it. You'll thank yourself for this when debugging dynamic SQL at midnight.
>
> **executeScalar** — calls executeSql and returns just the first column of the first row. Used for things like SELECT CURRENT_WAREHOUSE() or SELECT COUNT(*).
>
> **generateBatchId** — calls UUID_STRING() through executeScalar.
>
> **logAudit** — wraps the call to SP_LOG_INGESTION. Notice the try/catch with an empty catch block. If logging fails, we don't want it to break the actual ingestion. The data load is more important than the audit record. We capture the logging failure in the return result instead."

---

## [14:00 - 20:00] SP_GENERIC_INGESTION — DYNAMIC SQL GENERATION

**[Scroll to the buildCopyCommand function]**

> "This is the heart of the engine: buildCopyCommand. It takes a config object and returns a COPY INTO string. Let's trace through each file type."

**[Highlight the CSV branch]**

> "**CSV.** The simplest path. COPY INTO target FROM stage, FILE_FORMAT equals the named format from config. That's it. The file format we created in Module 02 handles the parsing details — delimiters, headers, null strings. The procedure just references it by name."

**[Highlight the JSON branch]**

> "**JSON.** Same COPY INTO structure, but with an optional MATCH_BY_COLUMN_NAME clause. When you load JSON, you can either dump everything into a single VARIANT column, or — if MATCH_BY_COLUMN_NAME is set — Snowflake maps JSON keys to table columns automatically. The config controls which approach each source uses."

**[Highlight the Parquet/Avro/ORC branch]**

> "**Parquet, Avro, ORC.** Same structure again. These columnar formats almost always use MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE. Snowflake reads the column names from the file schema and matches them to table columns regardless of case. This is why self-describing formats are powerful — the file tells Snowflake how to load itself."

**[Highlight the common options section]**

> "After the type-specific logic, we add common options. FILE_PATTERN filters which files to load — maybe you only want files matching '.*sales.*[.]csv'. ON_ERROR defaults to CONTINUE — don't stop the entire load because one file has bad rows. SIZE_LIMIT caps how much data to load per run. PURGE removes files from the stage after successful load. And FORCE — if set to TRUE — reloads files that Snowflake already loaded. Useful for reprocessing after a fix."

---

## [20:00 - 24:00] SP_GENERIC_INGESTION — AUTO-CREATE TARGET

**[Scroll to the ensureTargetExists function]**

> "Auto-create target. This is where the procedure adapts to different file types.
>
> First, it always creates the schema if it doesn't exist. The schema name comes from config — typically CLIENT_SYSTEM, like ACME_SAP or PARTNER_SALESFORCE.
>
> For **JSON**, it creates a table with four columns: RAW_DATA as VARIANT — that's the entire JSON document. Then three metadata columns prefixed with _MDF_ — file name, file row number, and loaded timestamp. Every row knows which file it came from and when it was loaded. This is non-negotiable for debugging and reprocessing."

**[Highlight the Parquet/Avro/ORC section]**

> "For **Parquet, Avro, and ORC**, it uses INFER_SCHEMA with USING TEMPLATE. This is one of Snowflake's most powerful features. It reads the actual file in the stage, extracts the schema — column names, data types — and creates a table that matches exactly. No manual DDL.
>
> But there's a fallback. If INFER_SCHEMA fails — maybe no files are staged yet — it falls back to creating a VARIANT table. The ingestion still works; you just get raw data instead of typed columns. Once files arrive and you re-run with AUTO_CREATE, it creates the proper typed table."

**[Highlight the CSV note]**

> "For **CSV**, the procedure does NOT auto-create the table. CSV files don't carry schema information. You need to either create the table manually with the right columns and types, or rely on the column count matching. This is a deliberate design decision — you don't want the framework guessing column types for structured data. Module 05 covers the CSV workflow in detail."

---

## [24:00 - 27:00] SP_GENERIC_INGESTION — EXECUTION AND RESULT CAPTURE

**[Scroll to the main execution loop]**

> "The main loop. It iterates through every config record returned by the query. For each source:
>
> Log start. Handle truncate if needed. Auto-create target if configured. Build the COPY command. Execute it."

**[Highlight the result capture section]**

> "After COPY INTO executes, Snowflake returns a result set with one row per file. Each row has the file name, status, rows_parsed, rows_loaded, and errors_seen.
>
> We iterate through this result set and count everything. Files with status LOADED or PARTIALLY_LOADED are successes. LOAD_SKIPPED means Snowflake already loaded that file — it's not an error. Anything else is a failure.
>
> The final status for each source: SUCCESS if all files loaded. PARTIAL_SUCCESS if some loaded and some failed. FAILED if nothing loaded. SKIPPED if there were no files to process."

**[Highlight the error handling]**

> "The entire per-source block is wrapped in try/catch. If anything throws — bad SQL, missing stage, permission denied — we catch it, log it as FAILED with the error message, and move to the next source. Source isolation. One bad source doesn't take down the batch."

**[Highlight the return summary]**

> "At the end, we build a JSON summary object: batch_id, overall_status, sources_processed, sources_succeeded, sources_failed, and a details array with per-source results. The caller gets everything in one structured response."

---

## [27:00 - 29:00] VERIFICATION — SP_GENERIC_INGESTION

**[Run: CREATE OR REPLACE PROCEDURE SP_GENERIC_INGESTION]**

> "Let's create the procedure."

**[Run: DESCRIBE PROCEDURE SP_GENERIC_INGESTION(VARCHAR, BOOLEAN)]**

> "DESCRIBE shows the procedure definition. Two parameters: source name as VARCHAR, force reload as BOOLEAN."

**[Run: CALL SP_GENERIC_INGESTION('NON_EXISTENT_SOURCE', FALSE)]**

> "Test with a source that doesn't exist. We get back a JSON object: overall_status is NO_SOURCES_FOUND, sources_processed is 0, and a message telling us the source wasn't found or isn't active. No crash. No cryptic error. Clean, structured feedback."

---

## [29:00 - 33:00] SP_REGISTER_SOURCE — CONVENTION OVER CONFIGURATION

**[Switch to 03_sp_register_source.sql]**

**[SLIDE: SP_REGISTER_SOURCE — 10 parameters vs 30+ columns]**

> "Last procedure: SP_REGISTER_SOURCE. This solves a real problem.
>
> The INGESTION_CONFIG table has 30-plus columns. Expecting someone to write a manual INSERT with all those fields is error-prone and slow. SP_REGISTER_SOURCE wraps that INSERT with only 10 parameters — 5 required, 5 optional with defaults."

**[Highlight the parameter list]**

> "The required parameters: source name, client name, source type, target table, and file pattern. That's it. Everything else has a sensible default.
>
> The optional parameters: sub-directory, load type defaults to APPEND, load frequency defaults to DAILY, source system and description are both nullable."

**[Highlight the defaults mapping]**

> "Convention over configuration. You say 'CSV' and the procedure maps it to MDF_FF_CSV_STANDARD file format and @MDF_STG_INTERNAL_CSV stage. You say 'PARQUET' and it picks MDF_FF_PARQUET_STANDARD and @MDF_STG_INTERNAL_PARQUET. The target database is always MDF_RAW_DB. The target schema is derived from client name plus source system.
>
> For Parquet, Avro, and ORC, it automatically sets MATCH_BY_COLUMN_NAME to CASE_INSENSITIVE. For CSV and JSON, it's NONE.
>
> You provide 10 parameters. The procedure fills in 30-plus columns. That's the power of convention."

**[Highlight the validation section]**

> "Input validation. Required fields are checked. Source type is validated against the allowed list. Load type and frequency are validated. And it checks for duplicate source names before attempting the insert. All of this runs before any INSERT happens. Fail fast with a clear error message."

**[Run: CREATE PROCEDURE SP_REGISTER_SOURCE]**

**[Run: CALL SP_REGISTER_SOURCE test call]**

> "Let's test it. Register a test CSV source."

**[Show the output message with all the derived defaults]**

> "Look at the output. It confirms the source was registered and shows every value — including the ones it derived automatically. File format, stage, target path. And it gives you the next steps: upload files, call the ingestion procedure, check results. Self-documenting output."

**[Run: Verify in INGESTION_CONFIG, then deactivate and clean up]**

> "Verify in the config table — there's our row. Deactivate it — IS_ACTIVE set to FALSE. Soft delete, not hard delete. Config history is preserved for auditing."

---

## [33:00 - 34:00] VERIFICATION & RECAP

**[SLIDE: Module 04 Recap]**

> "Here's what we built:
> - **SP_GENERATE_BATCH_ID** — UUID correlation for every run
> - **SP_LOG_INGESTION** — start and end audit records with full metrics
> - **SP_LOG_ERROR** — granular error capture per file and row
> - **SP_GENERIC_INGESTION** — the engine: reads config, builds COPY INTO, executes, captures results, logs everything
> - **SP_REGISTER_SOURCE** — 10-parameter onboarding with convention-over-configuration defaults
>
> Five procedures. One call loads everything. The framework is operational."

---

## [34:00 - 35:00] THE BRIDGE

> "That's Module 04 — the core stored procedures. The engine is built. Now we need to feed it.
>
> In Module 05, we run the first end-to-end test. CSV files. We'll register a source using SP_REGISTER_SOURCE, upload files to the stage, call SP_GENERIC_INGESTION, and watch it create the target table, load the data, and log the results. Hands-on, start to finish.
>
> All the SQL scripts are in the course repository. Link in the description. Read through the code — especially SP_GENERIC_INGESTION. Understand the flow before the next module.
>
> See you in Module 05."

---

## B-Roll / Visual Notes

| Timestamp | Visual |
|-----------|--------|
| 0:00-0:15 | Screen recording of SP_GENERIC_INGESTION('ALL', FALSE) result JSON |
| 0:15-1:30 | Course roadmap slide → 5 procedures overview slide |
| 1:30-4:00 | Slide: JavaScript vs SQL Script comparison table |
| 4:00-5:00 | Live SQL — SP_GENERATE_BATCH_ID creation and test |
| 5:00-7:00 | Live SQL — SP_LOG_INGESTION and SP_LOG_ERROR creation + verification |
| 7:00-10:00 | Slide: 8-step execution flow diagram |
| 10:00-14:00 | Live SQL walkthrough — helper functions in SP_GENERIC_INGESTION |
| 14:00-20:00 | Live SQL walkthrough — buildCopyCommand with CSV/JSON/Parquet highlights |
| 20:00-24:00 | Live SQL walkthrough — ensureTargetExists with type-specific table creation |
| 24:00-27:00 | Live SQL walkthrough — main loop, result capture, error handling |
| 27:00-29:00 | Live SQL — SP_GENERIC_INGESTION creation and test calls |
| 29:00-33:00 | Live SQL — SP_REGISTER_SOURCE creation, test, verify, cleanup |
| 33:00-34:00 | Module recap slide |
| 34:00-35:00 | Module 05 preview slide |
