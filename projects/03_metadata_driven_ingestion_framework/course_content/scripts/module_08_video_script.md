# Module 08 — Automation: Tasks & Streams | Video Script

**Duration:** ~25 minutes
**Type:** Architecture + Hands-On
**Deliverable:** Scheduled task tree + CDC streams

---

## [0:00 - 0:15] THE HOOK

**[SCREEN: Snowsight showing SHOW TASKS with MDF_TASK_ROOT running, child tasks cascading]**

> "A root task kicks off at 6 AM. Two child tasks run in parallel — one ingests CSV, the other ingests JSON. When both finish, a retry task picks up the failures. Zero human intervention. That's what we're building in this module — a self-driving ingestion pipeline."

---

## [0:15 - 1:30] THE CONTEXT

**[SLIDE: Course Roadmap — Module 08 highlighted]**

> "Welcome to Module 08. Over the last seven modules, we built stored procedures that ingest CSV and JSON, config tables that define what to load, and error handling that catches failures. But right now, someone has to manually call those procedures. That someone is usually you. At 3 AM. On a Saturday."

**[SLIDE: Why Automate — manual vs scheduled diagram]**

> "Automation solves two problems:
>
> **Scheduling** — tasks run your procedures on a CRON schedule. No human trigger needed. 6 AM every day, or every hour, or every five minutes. You define it once.
>
> **Change detection** — streams track what changed in a table since the last time you looked. New row in the config table? The stream catches it. New entry in the audit log? The stream catches that too. Combine tasks with streams and you get event-driven pipelines — things happen because data changed, not because the clock ticked."

---

## [1:30 - 4:00] TASK FUNDAMENTALS

**[SLIDE: Task Anatomy — CRON, warehouse, body]**

> "A Snowflake task has three parts:
>
> **Schedule** — when does it run? You define this with CRON syntax or a simple interval. CRON gives you full control: minute, hour, day-of-month, month, day-of-week. The expression `0 6 * * *` means 'at minute zero, hour six, every day of every month, every day of the week.' 6 AM daily. That's our root schedule.
>
> **Warehouse** — what compute does it use? Tasks need a warehouse. We'll use MDF_INGESTION_WH for our ingestion tasks because we already sized it for COPY INTO workloads.
>
> **Body** — what does it do? A SQL statement or a stored procedure call. One statement per task. If you need multiple steps, that's where task trees come in."

**[SLIDE: CRON Syntax Reference table]**

> "CRON syntax. Five fields:
>
> Minute — 0 to 59. Hour — 0 to 23. Day of month — 1 to 31. Month — 1 to 12. Day of week — 0 to 6, Sunday through Saturday.
>
> Asterisk means 'every.' So `0 6 * * *` is 6 AM every day. `0 */2 * * *` is every two hours. `30 8 * * 1-5` is 8:30 AM weekdays only.
>
> One gotcha: Snowflake CRON uses UTC by default. If your business runs on Eastern Time, you need to specify the timezone explicitly in the SCHEDULE parameter. We use `USING CRON 0 6 * * * America/New_York` — don't forget that timezone or your 6 AM task runs at 6 AM UTC, which is 1 AM Eastern."

---

## [4:00 - 7:00] TASK TREES — ARCHITECTURE

**[SLIDE: Task Tree Architecture — ASCII diagram showing parent/child/grandchild]**

> "Task trees. This is where it gets powerful.
>
> A root task has a schedule. Child tasks don't have their own schedule — they run when their parent completes. Grandchild tasks run when their parent completes. You build a directed acyclic graph — a DAG — of dependencies.
>
> Here's our MDF task tree:
>
> At the top, MDF_TASK_ROOT. It runs at 6 AM daily. Its body is a simple log statement — 'root task started.' Its only job is to be the scheduler.
>
> Below it, two parallel children: MDF_TASK_INGEST_CSV and MDF_TASK_INGEST_JSON. They both list MDF_TASK_ROOT as their parent, which means they start simultaneously the moment the root task finishes. CSV calls SP_INGEST_CSV. JSON calls SP_INGEST_JSON. Parallel execution — your CSV and JSON loads run at the same time.
>
> Below both children, MDF_TASK_RETRY. This task has an `AFTER` clause that references both MDF_TASK_INGEST_CSV AND MDF_TASK_INGEST_JSON. It only runs after both siblings complete. Its job: call the retry procedure for anything that failed in the first pass."

**[SLIDE: Parallel vs. Sequential execution diagram]**

> "Why parallel? Because CSV ingestion and JSON ingestion are independent workloads. There's no reason to wait for CSV to finish before starting JSON. In production, we've seen this cut total pipeline time by 40%. Ten CSV sources and eight JSON sources — they all run concurrently instead of sequentially.
>
> The retry task is sequential on purpose. It needs to know what failed. It can't run until both ingestion tasks are done."

---

## [7:00 - 12:00] TASK CREATION — LIVE

**[Switch to Snowsight, run task creation SQL]**

> "Let's build this tree."

**[Run: CREATE TASK MDF_TASK_ROOT]**

> "MDF_TASK_ROOT. CRON schedule, 6 AM New York time. Warehouse is MDF_INGESTION_WH. The body inserts a log entry into our audit table — 'MDF daily ingestion started.' This gives us a timestamp for when the pipeline kicked off."

```sql
CREATE OR REPLACE TASK MDF_CONTROL_DB.PROCEDURES.MDF_TASK_ROOT
  WAREHOUSE = MDF_INGESTION_WH
  SCHEDULE  = 'USING CRON 0 6 * * * America/New_York'
  COMMENT   = 'MDF root task — triggers daily ingestion pipeline'
AS
  CALL MDF_CONTROL_DB.PROCEDURES.SP_LOG_TASK_START('MDF_DAILY_INGESTION');
```

**[Run: CREATE TASK MDF_TASK_INGEST_CSV]**

> "First child. AFTER MDF_TASK_ROOT. No schedule — it inherits timing from its parent. The body calls our CSV ingestion stored procedure."

```sql
CREATE OR REPLACE TASK MDF_CONTROL_DB.PROCEDURES.MDF_TASK_INGEST_CSV
  WAREHOUSE = MDF_INGESTION_WH
  AFTER MDF_CONTROL_DB.PROCEDURES.MDF_TASK_ROOT
  COMMENT   = 'Ingest all active CSV sources'
AS
  CALL MDF_CONTROL_DB.PROCEDURES.SP_INGEST_ALL_CSV();
```

**[Run: CREATE TASK MDF_TASK_INGEST_JSON]**

> "Second child. Also AFTER MDF_TASK_ROOT. Same pattern — calls the JSON ingestion procedure. Because both children reference the same parent, they start in parallel."

```sql
CREATE OR REPLACE TASK MDF_CONTROL_DB.PROCEDURES.MDF_TASK_INGEST_JSON
  WAREHOUSE = MDF_INGESTION_WH
  AFTER MDF_CONTROL_DB.PROCEDURES.MDF_TASK_ROOT
  COMMENT   = 'Ingest all active JSON sources'
AS
  CALL MDF_CONTROL_DB.PROCEDURES.SP_INGEST_ALL_JSON();
```

**[Run: CREATE TASK MDF_TASK_RETRY]**

> "The retry task. Notice the AFTER clause — it lists both siblings. Snowflake waits for both to complete before firing this one. The body calls our retry procedure from Module 07."

```sql
CREATE OR REPLACE TASK MDF_CONTROL_DB.PROCEDURES.MDF_TASK_RETRY
  WAREHOUSE = MDF_INGESTION_WH
  AFTER MDF_CONTROL_DB.PROCEDURES.MDF_TASK_INGEST_CSV,
        MDF_CONTROL_DB.PROCEDURES.MDF_TASK_INGEST_JSON
  COMMENT   = 'Retry failed ingestions after both CSV and JSON complete'
AS
  CALL MDF_CONTROL_DB.PROCEDURES.SP_RETRY_FAILED_LOADS();
```

**[Run: ALTER TASK ... RESUME for all tasks — bottom-up]**

> "Critical step. Tasks are created in a suspended state. You must resume them, and you must resume bottom-up. Children first, then root. If you resume the root first and a child is still suspended, the root runs but the child doesn't — the pipeline silently breaks. Bottom-up. Always."

```sql
ALTER TASK MDF_CONTROL_DB.PROCEDURES.MDF_TASK_RETRY RESUME;
ALTER TASK MDF_CONTROL_DB.PROCEDURES.MDF_TASK_INGEST_JSON RESUME;
ALTER TASK MDF_CONTROL_DB.PROCEDURES.MDF_TASK_INGEST_CSV RESUME;
ALTER TASK MDF_CONTROL_DB.PROCEDURES.MDF_TASK_ROOT RESUME;
```

---

## [12:00 - 14:30] STREAMS — CHANGE DATA CAPTURE

**[SLIDE: What Is a Stream — CDC concept diagram]**

> "Tasks handle scheduling. Streams handle change detection.
>
> A stream is a Snowflake object that sits on top of a table and records every change — inserts, updates, deletes. It's like a bookmark. The stream remembers where you last read, and when you query it, you see only the rows that changed since then.
>
> Three metadata columns come with every stream:
>
> **METADATA$ACTION** — INSERT or DELETE.
> **METADATA$ISUPDATE** — TRUE if this row was part of an UPDATE (an update is recorded as a DELETE plus an INSERT).
> **METADATA$ROW_ID** — a unique identifier for the row.
>
> Once you consume the stream in a DML transaction — a SELECT inside an INSERT, MERGE, or similar — the stream advances its offset. The consumed rows disappear from the stream. It's self-cleaning."

**[SLIDE: Stream Types — Standard vs Append-Only]**

> "Two stream types matter for us:
>
> **Standard** — captures inserts, updates, and deletes. Use this for config tables where rows can be modified.
>
> **Append-only** — captures only inserts. More efficient when you know rows are never updated or deleted. Use this for audit logs."

---

## [14:30 - 17:00] STREAM CREATION — LIVE

**[Switch to Snowsight]**

**[Run: CREATE STREAM MDF_CONFIG_STREAM]**

> "MDF_CONFIG_STREAM on our INGESTION_CONFIG table. Standard mode. When someone adds a new data source to the config table, this stream captures that change."

```sql
CREATE OR REPLACE STREAM MDF_CONTROL_DB.CONFIG.MDF_CONFIG_STREAM
  ON TABLE MDF_CONTROL_DB.CONFIG.INGESTION_CONFIG
  SHOW_INITIAL_ROWS = FALSE
  COMMENT = 'CDC stream on config table — detects new source registrations';
```

**[Run: CREATE STREAM MDF_AUDIT_STREAM]**

> "MDF_AUDIT_STREAM on the audit log table. Append-only — we only insert into audit logs, we never update or delete them. This stream is more efficient because Snowflake doesn't track updates or deletes."

```sql
CREATE OR REPLACE STREAM MDF_CONTROL_DB.AUDIT.MDF_AUDIT_STREAM
  ON TABLE MDF_CONTROL_DB.AUDIT.INGESTION_AUDIT_LOG
  APPEND_ONLY = TRUE
  COMMENT = 'Append-only CDC stream on audit log — tracks new ingestion events';
```

**[Run: SELECT * FROM MDF_CONFIG_STREAM]**

> "Right now the stream is empty — no changes since we created it. Let's force a change."

**[Run: INSERT a test row into INGESTION_CONFIG]**

> "I'll insert a new config row — a test data source. Now let's query the stream again."

**[Run: SELECT * FROM MDF_CONFIG_STREAM]**

> "There it is. One row. METADATA$ACTION is INSERT. METADATA$ISUPDATE is FALSE. The stream captured the change in real time. Now imagine this connected to a task that automatically sets up the new data source. That's what we'll build next."

---

## [17:00 - 20:30] STREAM-TRIGGERED TASKS

**[SLIDE: Stream + Task = Event-Driven Architecture]**

> "Here's where tasks and streams combine. A task with a WHEN condition can check SYSTEM$STREAM_HAS_DATA. If the stream has unconsumed data, the task runs. If the stream is empty, the task skips that scheduled execution. You pay for zero compute when nothing changed."

**[Run: CREATE TASK MDF_TASK_PROCESS_CONFIG_CHANGES]**

> "MDF_TASK_PROCESS_CONFIG_CHANGES. Runs every hour. But the WHEN clause checks our config stream — if nobody registered a new data source in the last hour, the task doesn't execute. When it does run, it calls a procedure that reads the stream and provisions the new source."

```sql
CREATE OR REPLACE TASK MDF_CONTROL_DB.PROCEDURES.MDF_TASK_PROCESS_CONFIG_CHANGES
  WAREHOUSE = MDF_ADMIN_WH
  SCHEDULE  = 'USING CRON 0 * * * * America/New_York'
  COMMENT   = 'Process new config registrations detected by stream'
  WHEN      = SYSTEM$STREAM_HAS_DATA('MDF_CONTROL_DB.CONFIG.MDF_CONFIG_STREAM')
AS
  CALL MDF_CONTROL_DB.PROCEDURES.SP_PROCESS_NEW_REGISTRATIONS();
```

**[Run: CREATE TASK MDF_TASK_HOURLY_INGEST]**

> "MDF_TASK_HOURLY_INGEST. Same pattern — hourly schedule with a WHEN condition. This one checks the audit stream. If new audit entries landed — meaning ingestion happened recently — it triggers downstream processing. If nothing happened, it saves your compute credits."

```sql
CREATE OR REPLACE TASK MDF_CONTROL_DB.PROCEDURES.MDF_TASK_HOURLY_INGEST
  WAREHOUSE = MDF_INGESTION_WH
  SCHEDULE  = 'USING CRON 0 * * * * America/New_York'
  COMMENT   = 'Hourly ingestion — only runs when audit stream has new data'
  WHEN      = SYSTEM$STREAM_HAS_DATA('MDF_CONTROL_DB.AUDIT.MDF_AUDIT_STREAM')
AS
  CALL MDF_CONTROL_DB.PROCEDURES.SP_PROCESS_HOURLY_LOADS();
```

**[Resume both tasks]**

> "Resume both. These are standalone scheduled tasks, not part of the tree, so we resume them directly."

```sql
ALTER TASK MDF_CONTROL_DB.PROCEDURES.MDF_TASK_PROCESS_CONFIG_CHANGES RESUME;
ALTER TASK MDF_CONTROL_DB.PROCEDURES.MDF_TASK_HOURLY_INGEST RESUME;
```

---

## [20:30 - 23:00] TASK MONITORING — LIVE

**[Switch to Snowsight, run monitoring queries]**

> "You've built the pipeline. Now you need to watch it."

**[Run: SHOW TASKS query]**

> "SHOW TASKS shows all tasks, their state, schedule, and the predecessor chain. Verify everything is RESUMED."

```sql
SHOW TASKS IN SCHEMA MDF_CONTROL_DB.PROCEDURES;
```

**[Run: TASK_HISTORY table function]**

> "TASK_HISTORY is your execution log. Every run — when it started, when it finished, whether it succeeded or failed, and why. This is the first place to look when something breaks."

```sql
SELECT NAME, STATE, SCHEDULED_TIME, COMPLETED_TIME, ERROR_CODE, ERROR_MESSAGE
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
  SCHEDULED_TIME_RANGE_START => DATEADD('hour', -24, CURRENT_TIMESTAMP()),
  RESULT_LIMIT => 50
))
ORDER BY SCHEDULED_TIME DESC;
```

**[Run: Stream status query]**

> "For streams, check STALE_AFTER. Snowflake garbage-collects stream offsets after 14 days by default. If no task consumes the stream in 14 days, it goes stale — you lose the offset and have to recreate it. Monitor this. In production, we alert if a stream hasn't been consumed in 7 days."

```sql
SELECT STREAM_NAME, TABLE_NAME, STALE, STALE_AFTER, TYPE
FROM MDF_CONTROL_DB.INFORMATION_SCHEMA.STREAMS
WHERE STREAM_NAME LIKE 'MDF_%';
```

---

## [23:00 - 24:00] VERIFICATION & RECAP

**[SLIDE: Module 08 Recap]**

> "Here's what we built:
> - A 4-task tree: root, two parallel children for CSV and JSON, a retry grandchild
> - CRON scheduling with explicit timezone handling
> - 2 streams for CDC: one standard on the config table, one append-only on audit
> - 2 stream-triggered tasks that only consume compute when data has changed
> - Monitoring queries for task history and stream health
>
> The framework is now self-driving. Data loads itself. Failures retry themselves. New source registrations detect themselves."

---

## [24:00 - 25:00] THE BRIDGE

> "That's Module 08 — automation with tasks and streams. The pipeline runs on its own now. But running and knowing it's running are two different things.
>
> In Module 09, we build the monitoring layer. Dashboard views that show you what loaded, what failed, how long each source took, and whether your pipeline is trending healthy or drifting toward trouble. Observability. Because the worst kind of failure is the one nobody notices.
>
> All the SQL scripts are in the course repository. Link in the description. Run them yourself before the next module.
>
> See you in Module 09."

---

## B-Roll / Visual Notes

| Timestamp | Visual |
|-----------|--------|
| 0:00-0:15 | Screen recording of SHOW TASKS with task tree visible |
| 0:15-1:30 | Course roadmap slide -> manual vs automated diagram |
| 1:30-2:30 | Task anatomy slide — schedule, warehouse, body |
| 2:30-4:00 | CRON syntax reference table slide |
| 4:00-5:30 | Task tree architecture diagram — ASCII art style |
| 5:30-7:00 | Parallel vs sequential execution comparison slide |
| 7:00-12:00 | Live SQL execution in Snowsight — task creation, bottom-up resume |
| 12:00-13:30 | Stream CDC concept diagram — bookmark analogy |
| 13:30-14:30 | Stream types comparison slide |
| 14:30-17:00 | Live SQL — stream creation, test insert, stream query |
| 17:00-18:00 | Stream + Task architecture slide |
| 18:00-20:30 | Live SQL — stream-triggered tasks with WHEN clause |
| 20:30-23:00 | Live SQL — SHOW TASKS, TASK_HISTORY, stream health queries |
| 23:00-24:00 | Module recap slide |
| 24:00-25:00 | Module 09 preview slide — monitoring and dashboards |
