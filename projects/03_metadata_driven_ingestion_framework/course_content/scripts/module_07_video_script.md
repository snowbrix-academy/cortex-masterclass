# Module 07 — Error Handling & Audit | Video Script

**Duration:** ~20 minutes
**Type:** Pattern + Hands-On
**Deliverable:** Validation + retry procedures

---

## [0:00 - 0:15] THE HOOK

**[SCREEN: Snowsight showing error analysis query — failures grouped by source with failure rates]**

> "Thirty-seven failed loads in the last 24 hours. Three sources responsible for 90% of them. One error pattern repeating across all three. I found this in under ten seconds — because the framework told me exactly where to look."

---

## [0:15 - 1:30] THE CONTEXT

**[SLIDE: Course Roadmap — Module 07 highlighted]**

> "Welcome to Module 07. We've built ingestion procedures, loaded CSV and JSON data, and everything has worked. That's the demo. Production is different."

**[SLIDE: Error Philosophy — "Errors are expected. Undetected errors are the problem."]**

> "Here's the philosophy that drives this entire module: **errors are expected. Undetected errors are the problem.**
>
> A file with a bad row? That happens every Tuesday. A schema change from an upstream system? That happens every quarter. A cloud storage timeout? That happens whenever it feels like it.
>
> The question isn't whether your pipeline will fail. It will. The question is: when it fails, do you find out in 10 seconds or 10 days? Do you retry automatically or wait for someone to notice? Do you know which rows failed and why, or do you just see 'load failed' and start guessing?
>
> That's what we're building today — the detection, diagnosis, and recovery layer."

---

## [1:30 - 4:30] SP_VALIDATE_LOAD — CONCEPT

**[SLIDE: SP_VALIDATE_LOAD — 5 Checks diagram]**

> "First: post-load validation. SP_VALIDATE_LOAD runs after every successful ingestion and performs five checks."

**[SLIDE: Check 1 — Table Exists]**

> "Check one: **Table Exists**. Does the target table actually exist and is it accessible? This catches permission issues, dropped tables, typos in config. If this fails, everything else is skipped — no point checking row counts on a table that doesn't exist."

**[SLIDE: Check 2 — Row Count Threshold]**

> "Check two: **Row Count Threshold**. Is the table empty? Is the row count below a configured minimum? An empty table after a load is a red flag. A table with 50 rows when you usually get 50,000 — that's a different kind of red flag. The threshold is configurable per source in the INGESTION_CONFIG table."

**[SLIDE: Check 3 — Null Checks]**

> "Check three: **Null Checks on Specified Columns**. You define which columns should never be null — think customer_id, transaction_date, amount. The procedure checks each one and reports the null count. This is a WARNING, not a FAILURE, because sometimes nulls are legitimate. But you want to know about them."

**[SLIDE: Check 4 — Duplicate Detection]**

> "Check four: **Duplicate Detection**. Compares the row count against the distinct count of file name plus row number from the latest load. If you loaded the same file twice — because a retry ran when the original actually succeeded — this catches it."

**[SLIDE: Check 5 — Data Freshness]**

> "Check five: **Data Freshness**. When was the last row loaded? If the latest load timestamp is from three days ago but you expect daily data, something upstream is broken. This check gives you that visibility."

---

## [4:30 - 8:00] SP_VALIDATE_LOAD — LIVE

**[Switch to Snowsight, run 01_error_handling_lab.sql — SP_VALIDATE_LOAD section]**

> "Let's build it. Open the lab script."

**[Run: CREATE OR REPLACE PROCEDURE SP_VALIDATE_LOAD]**

> "The procedure takes three parameters: BATCH_ID, CONFIG_ID, and SOURCE_NAME. It returns a VARIANT — a JSON object with every check result, the overall status, and a timestamp."

**[Highlight the addCheck function]**

> "Notice the addCheck helper function. Every check follows the same pattern — name, status, message, optional details. If any check returns FAILED, the overall status is FAILED. If any check returns WARNING and nothing has failed, overall is WARNING. This gives you a single status to check while keeping all the detail underneath."

**[Highlight Check 1 — table exists try/catch]**

> "Check one wraps the query in a try/catch. If the SELECT throws an error — table doesn't exist, no permission — we catch it, mark it FAILED, and return immediately. No point running four more checks."

**[Highlight Check 3 — null check loop]**

> "Check three iterates over a comma-separated list of column names from the config. Each column gets its own check result. If a column doesn't exist in the table — maybe it was renamed — we catch that error too and report it as a WARNING instead of crashing the whole validation."

**[Highlight the audit log update at the end]**

> "After all five checks, the results are written back to the audit log. VALIDATION_STATUS and VALIDATION_DETAILS — the full JSON. This means your monitoring dashboards can filter on validation failures, not just load failures."

---

## [8:00 - 11:00] SP_RETRY_FAILED_LOADS — CONCEPT & LIVE

**[SLIDE: Retry Flow — find failures, check count, retry or skip]**

> "Second procedure: SP_RETRY_FAILED_LOADS. This is your automatic recovery mechanism."

**[SLIDE: Retry Parameters]**

> "Two parameters. **P_HOURS_LOOKBACK** — how far back to search for failures. Default is 24 hours. **P_MAX_RETRIES** — maximum retry attempts per source. Default is 3. This prevents infinite retry loops. If a source has failed three times, stop retrying and alert a human."

**[Switch to Snowsight, run SP_RETRY_FAILED_LOADS section]**

> "Here's the logic. First, we query the audit log for failed loads within the lookback window. The QUALIFY clause with ROW_NUMBER gives us only the most recent failure per source — we don't want to retry the same source five times because it failed five times."

**[Highlight the fail count check]**

> "For each failed source, we check the total failure count. If it's already hit or exceeded MAX_RETRIES, we skip it and log the reason. This is critical in production. A source failing because of a network timeout? Retry it. A source failing because the schema changed? Retrying won't help — you need a human to update the config."

**[Highlight the SP_GENERIC_INGESTION call]**

> "If the retry count is within limits, we call SP_GENERIC_INGESTION — the same procedure from Module 04. The retry isn't a special path. It's the exact same ingestion flow. Same validation, same audit logging, same error handling. That's by design — no special cases, no 'retry mode' that behaves differently."

---

## [11:00 - 13:30] INGESTION_ERROR_LOG TABLE

**[SLIDE: INGESTION_ERROR_LOG table structure]**

> "Now let's talk about where error details live. The INGESTION_AUDIT_LOG tracks whether a load succeeded or failed. But when a load fails, you need the details — which file, which row, which column, what went wrong."

**[SLIDE: Error Log columns table]**

> "That's INGESTION_ERROR_LOG in the AUDIT schema. The columns:
>
> **SOURCE_NAME** and **BATCH_ID** — link back to the audit log.
>
> **FILE_NAME** — which specific file caused the error. When you're loading 200 files and 3 fail, you need to know which 3.
>
> **ROW_NUMBER** — the line number in the file. You can tell your data provider exactly where the problem is.
>
> **COLUMN_NAME** — which column triggered the error. 'Row 47, column AMOUNT, expected NUMBER got abc'. That's actionable.
>
> **ERROR_CODE** and **ERROR_MESSAGE** — Snowflake's error classification.
>
> **REJECTED_RECORD** — the actual raw data that failed. This is gold for debugging. You can see exactly what the source system sent."

**[Switch to Snowsight, show example query on INGESTION_ERROR_LOG]**

> "When you query this table, you get a complete forensic record of every failure. No guessing. No 'let me check the source file manually.' The framework captured it all."

---

## [13:30 - 16:30] ERROR ANALYSIS QUERIES

**[SLIDE: Error Analysis — 4 Essential Queries]**

> "Four queries you'll run daily in production. These are in your lab script."

**[Switch to Snowsight, run Query 1 — Failed loads last 24 hours]**

> "Query one: **Failures in the last 24 hours.** Simple filter on RUN_STATUS — FAILED or PARTIAL_SUCCESS — with a 24-hour window. This is your morning check. Open Snowsight, run this query, see if anything broke overnight. If it's clean, move on. If it's not, you know exactly what happened."

**[Run Query 2 — Error frequency by source]**

> "Query two: **Error frequency by source over the last 7 days.** This shows you patterns. If SALES_DAILY has a 2% failure rate, that's noise — probably intermittent timeouts. If HR_EXTRACT has a 40% failure rate, that's a systemic problem. The FAILURE_RATE_PCT column makes this immediately obvious."

**[Run Query 3 — Detailed error log entries]**

> "Query three: **Detailed error log entries.** This hits INGESTION_ERROR_LOG for the raw details — file name, row number, column name, the rejected record itself. This is what you send to the source team when you need them to fix their data."

**[Run Query 4 — Error patterns]**

> "Query four: **Error patterns.** Groups errors by ERROR_CODE and message, counts occurrences, shows affected sources. If you see 'Number of columns in file does not match' appearing 500 times across 8 sources, that's not 8 separate problems — that's one schema change that affected everything. Pattern recognition turns noise into signal."

---

## [16:30 - 18:30] ERROR SEVERITY & STRATEGY

**[SLIDE: Error Severity Classification table]**

> "Not all errors are equal. Here's how the framework classifies them:
>
> **CRITICAL** — table doesn't exist, config missing, procedure crash. Everything stops. Alert immediately.
>
> **ERROR** — load failed, zero rows loaded, file not found. The source didn't load. Retry automatically if within limits.
>
> **WARNING** — row count below threshold, nulls in monitored columns, partial success. Data loaded, but something looks off. Log it, surface it in dashboards.
>
> **INFO** — load succeeded, validation passed. Business as usual.
>
> This classification drives your response. Critical gets a PagerDuty alert at 3 AM. Warning gets reviewed in the morning standup. Info gets archived. You don't wake someone up because a CSV had two null email addresses."

**[SLIDE: ON_ERROR Strategy per Source Type]**

> "One more production pattern: ON_ERROR strategy. This is set per source in your config table.
>
> **ABORT_STATEMENT** — for critical data. Financial transactions, compliance records. One bad row stops everything. You investigate before any data enters the system.
>
> **SKIP_FILE** — the balanced option. Bad files are skipped, good files load. Most production sources use this.
>
> **CONTINUE** — for high-volume, tolerant sources. Clickstream data, IoT sensor readings. Skip bad rows, load everything else. You'll review the rejected records later, but the pipeline keeps moving."

---

## [18:30 - 19:30] VERIFICATION & RECAP

**[SLIDE: Module 07 Recap]**

> "Here's what we built:
> - **SP_VALIDATE_LOAD** — 5 post-load checks: table exists, row count threshold, null checks, duplicate detection, data freshness
> - **SP_RETRY_FAILED_LOADS** — automatic recovery with lookback window and max retry limits
> - **INGESTION_ERROR_LOG** — per-row, per-file error forensics
> - **4 analysis queries** — failures, frequency, details, patterns
> - **Error severity classification** — CRITICAL, ERROR, WARNING, INFO
>
> The framework now detects failures, diagnoses root causes, retries when appropriate, and gives you everything you need to fix what it can't retry."

---

## [19:30 - 20:00] THE BRIDGE

> "That's Module 07 — error handling and audit. Your pipeline can now fail gracefully and recover automatically. But right now, everything still requires a human to press the button. Someone has to call SP_GENERIC_INGESTION. Someone has to call SP_RETRY_FAILED_LOADS.
>
> In Module 08, we automate everything. Tasks and Streams. Scheduled ingestion. Event-driven processing. The framework starts running itself.
>
> All the SQL scripts are in the course repository. Link in the description. Run the validation and retry procedures yourself before the next module.
>
> See you in Module 08."

---

## B-Roll / Visual Notes

| Timestamp | Visual |
|-----------|--------|
| 0:00-0:15 | Screen recording of error analysis query results in Snowsight |
| 0:15-1:30 | Course roadmap slide -> Error philosophy slide |
| 1:30-4:30 | Slides: 5 validation checks, one per slide with icons |
| 4:30-8:00 | Live SQL execution in Snowsight — SP_VALIDATE_LOAD creation |
| 8:00-8:30 | Retry flow diagram slide |
| 8:30-11:00 | Live SQL — SP_RETRY_FAILED_LOADS creation and walkthrough |
| 11:00-11:30 | Error log table structure slide |
| 11:30-13:30 | Live SQL — INGESTION_ERROR_LOG queries |
| 13:30-13:45 | Error analysis overview slide |
| 13:45-16:30 | Live SQL — running all 4 analysis queries with results |
| 16:30-18:00 | Slides: severity classification table, ON_ERROR strategy |
| 18:30-19:30 | Module recap slide with all deliverables listed |
| 19:30-20:00 | Module 08 preview slide -> closing |
