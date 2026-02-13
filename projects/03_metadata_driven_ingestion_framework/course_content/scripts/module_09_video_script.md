# Module 09 — Monitoring & Dashboards | Video Script

**Duration:** ~20 minutes
**Type:** Hands-On + Demo
**Deliverable:** 7 monitoring views + Snowsight dashboard

---

## [0:00 - 0:15] THE HOOK

**[SCREEN: Snowsight dashboard showing 4 KPI tiles — Success Rate 98.7%, Avg Duration 4.2s, Rows Loaded 1.2M, Active Sources 12 — with a source health heat map below in green/amber/red]**

> "A Snowsight dashboard. Four KPI tiles. A health heat map. Red, amber, green — you can see which sources are failing before anyone files a ticket. This is what we build in the next 20 minutes. Seven monitoring views and a live dashboard. No third-party tools. Just SQL and Snowsight."

---

## [0:15 - 1:30] THE CONTEXT

**[SLIDE: Course Roadmap — Module 09 highlighted]**

> "Welcome to Module 09. We're eight modules deep. We've built databases, file formats, config tables, stored procedures, ingestion pipelines, error handling, and automated tasks. All of it works. But here's the problem — how do you know it's working?"

**[SLIDE: Observability Philosophy — 'If you can't see it, you can't fix it']**

> "Observability. Not monitoring — observability. Monitoring tells you something is broken. Observability tells you why. And in a metadata-driven framework, we already have everything we need. The INGESTION_AUDIT_LOG table from Module 07 captures every run — status, duration, rows loaded, errors. All we need are the right views on top of that data.
>
> Seven views. Six dashboard sections. One Snowsight dashboard. Let's build it."

---

## [1:30 - 3:30] VIEW 1: EXECUTIVE SUMMARY

**[SLIDE: Executive Summary — what, why, key columns]**

> "View one: VW_INGESTION_EXECUTIVE_SUMMARY. This is the bird's-eye view. One row per day for the last 30 days.
>
> It answers the executive question: 'How is ingestion doing?' Total runs, success count, failure count, success rate percentage, total rows loaded, total megabytes loaded, average duration. Everything a stakeholder needs in one query."

**[Switch to Snowsight, run CREATE VIEW VW_INGESTION_EXECUTIVE_SUMMARY]**

> "The CTE aggregates the audit log by day. We compute SUCCESS_RATE_PCT as success count divided by total runs times 100. Notice we use NULLIF to avoid division by zero on days with no runs. The outer SELECT rounds everything for clean dashboard display.
>
> The 30-day window is intentional. Enough history for trends, not so much that the view gets slow."

---

## [3:30 - 5:30] VIEW 2: SOURCE HEALTH

**[SLIDE: Source Health — HEALTHY / WARNING / CRITICAL logic]**

> "View two: VW_SOURCE_HEALTH. This is the one your on-call team will live in. Per-source health with a traffic-light indicator.
>
> The logic is straightforward:
>
> **HEALTHY** — zero failures in the last 7 days. Green. No action needed.
>
> **WARNING** — 1 or 2 failures. Amber. Something happened, probably intermittent. Investigate when you can.
>
> **CRITICAL** — 3 or more failures. Red. This source needs immediate attention.
>
> We also pull the latest run status, the 7-day success rate, average duration, and total rows loaded. Every column is chosen because it helps you make a decision."

**[Switch to Snowsight, run CREATE VIEW VW_SOURCE_HEALTH]**

> "The join pattern is important. We LEFT JOIN the audit log to the config table so that sources with zero runs still appear — they'll show as HEALTHY with zero runs. If a source has never run, that's a config issue, not a monitoring issue.
>
> The subquery gets the latest run timestamp per source so we can extract the most recent status. This pattern avoids the common mistake of using MAX on a status column — which gives you alphabetical max, not chronological."

---

## [5:30 - 7:30] VIEW 3: THROUGHPUT METRICS

**[SLIDE: Throughput — rows, files, MB over time]**

> "View three: VW_THROUGHPUT_METRICS. Throughput answers 'how much data are we moving?'
>
> This view is bucketed by hour and source name. Rows loaded, files processed, megabytes loaded, run count, average duration. It only includes successful and partially successful runs — failed runs didn't move data, so they'd skew the averages.
>
> The 7-day window keeps the result set manageable for charting."

**[Switch to Snowsight, run CREATE VIEW VW_THROUGHPUT_METRICS]**

> "Hourly bucketing is the sweet spot for throughput charts. Daily is too coarse — you miss burst patterns. Minute-level is too noisy. Hour-by-source gives you clear visual patterns: you'll see when each source runs and how much data it moves."

---

## [7:30 - 9:30] VIEW 4: ERROR ANALYSIS

**[SLIDE: Error Analysis — pattern detection with severity]**

> "View four: VW_ERROR_ANALYSIS. This is where you go when something breaks.
>
> It groups errors by source, error code, and error message pattern. The LEFT on error message truncates to 200 characters — enough to identify the pattern without massive strings clogging your results.
>
> Severity is based on occurrence count:
>
> **CRITICAL** — 10 or more occurrences. This error is persistent and probably structural.
>
> **HIGH** — 5 to 9. Recurring, needs a fix.
>
> **MEDIUM** — 2 to 4. Might be transient, watch it.
>
> **LOW** — single occurrence. Could be a one-off.
>
> We also track FIRST_SEEN and LAST_SEEN so you can tell if an error is ongoing or resolved."

**[Switch to Snowsight, run CREATE VIEW VW_ERROR_ANALYSIS]**

> "The DURATION_HOURS column shows how long an error pattern has persisted. If an error has been recurring for 72 hours, that's different from one that appeared and disappeared in an hour. Duration plus count together tell the full story."

---

## [9:30 - 11:30] VIEW 5: PERFORMANCE METRICS

**[SLIDE: Performance — P95 duration, rows per second]**

> "View five: VW_PERFORMANCE_METRICS. Duration trends per source, per day.
>
> We compute min, average, max, and P95 duration. P95 — the 95th percentile — is the real number here. Average hides outliers. Max is too sensitive to a single bad run. P95 tells you: 95% of your runs completed faster than this value. If your P95 is 30 seconds but your SLA is 60, you have headroom. If P95 is 55 seconds, you're in the danger zone.
>
> ROWS_PER_SECOND gives you throughput velocity. If a source that normally processes 10,000 rows per second drops to 1,000, something changed — maybe the file grew, maybe the warehouse is contended."

**[Switch to Snowsight, run CREATE VIEW VW_PERFORMANCE_METRICS]**

> "PERCENTILE_CONT with a 0.95 argument — that's the Snowflake function for P95. It's an ordered-set aggregate, which is why the syntax uses WITHIN GROUP ORDER BY. Note we filter out null durations and failed runs to keep the statistics clean."

---

## [11:30 - 13:00] VIEW 6: OPERATIONAL OVERVIEW

**[SLIDE: Operational Overview — config health]**

> "View six: VW_OPERATIONAL_OVERVIEW. This view looks at the config table, not the audit log. It answers: 'What does our framework look like right now?'
>
> Per client: total sources, active versus inactive, data types in use, load frequencies, how many have validation enabled, how many have schema evolution enabled. This is your framework census."

**[Switch to Snowsight, run CREATE VIEW VW_OPERATIONAL_OVERVIEW]**

> "LISTAGG gives you a comma-separated list of distinct source types and frequencies per client. One row per client, everything you need to understand the config landscape. When someone asks 'how many active sources does Client X have?' — this view answers it instantly."

---

## [13:00 - 14:30] VIEW 7: DAILY SUMMARY

**[SLIDE: Daily Summary — today's report card]**

> "View seven: VW_DAILY_SUMMARY. Today's report card. Sources processed, successful runs, failed runs, total rows, total files, total gigabytes, earliest and latest run times, average duration.
>
> This is the view you query at end-of-day — or that gets emailed to stakeholders. One row. Today's numbers. No historical context needed."

**[Switch to Snowsight, run CREATE VIEW VW_DAILY_SUMMARY]**

> "Notice CURRENT_DATE as the filter. This view always shows today's data. Yesterday's numbers are in the executive summary view. Clean separation of concerns."

---

## [14:30 - 17:30] BUILDING THE SNOWSIGHT DASHBOARD

**[Switch to Snowsight — Dashboard creation flow]**

> "Seven views are built. Now let's turn them into a dashboard.
>
> Snowsight dashboards — click the plus icon, 'New Dashboard.' Name it 'MDF Ingestion Monitor.'
>
> First tile: Daily Summary as a scoreboard. New tile, paste the query from VW_DAILY_SUMMARY. Display as a scoreboard — Snowsight will show each column as a KPI card. Success rate, average duration, total rows, active sources. Four numbers that tell you whether to drink coffee calmly or start debugging.
>
> Second tile: Source Health as a table. Select from VW_SOURCE_HEALTH, order by the CASE expression that puts CRITICAL first, then WARNING, then HEALTHY. Display as a table. Color the HEALTH_STATUS column — Snowsight supports conditional formatting. Red for CRITICAL, amber for WARNING, green for HEALTHY."

**[SCREEN: Adding the trend line chart tile]**

> "Third tile: Ingestion trend as a line chart. Executive summary view, last 7 days. X-axis is RUN_DATE, Y-axis is SUCCESS_RATE_PCT. You'll see the trend line — dips are immediately visible.
>
> Fourth tile: Error analysis as a table. Filter to CRITICAL and HIGH severity. This is your action list — the errors that need attention today.
>
> Fifth tile: Performance chart. Source names on X-axis, P95 duration on Y-axis. Bar chart. You'll immediately see which sources are slow."

**[SCREEN: Completed dashboard with all 5 tiles arranged]**

> "Five tiles. Set the dashboard to auto-refresh every 5 minutes. Now it's a live operational display.
>
> One thing — set the warehouse to MDF_MONITORING_WH. This is an XSMALL warehouse, costs almost nothing. Never run dashboard queries on your ingestion or transform warehouses."

---

## [17:30 - 19:00] VERIFICATION & RECAP

**[Switch to Snowsight, run SHOW VIEWS IN SCHEMA MDF_CONTROL_DB.MONITORING]**

> "Verification. SHOW VIEWS — all seven are there. Let's test a few."

**[Run: SELECT * FROM VW_DAILY_SUMMARY]**

> "Daily summary — one row, today's data. Working."

**[Run: SELECT * FROM VW_SOURCE_HEALTH ORDER BY HEALTH_STATUS]**

> "Source health — every configured source has a health status. HEALTHY, WARNING, or CRITICAL."

**[SLIDE: Module 09 Recap]**

> "Here's what we built:
>
> - **VW_INGESTION_EXECUTIVE_SUMMARY** — 30-day daily aggregates with success rate
> - **VW_SOURCE_HEALTH** — per-source traffic-light health: HEALTHY, WARNING, CRITICAL
> - **VW_THROUGHPUT_METRICS** — hourly data volume per source
> - **VW_ERROR_ANALYSIS** — error pattern detection with severity classification
> - **VW_PERFORMANCE_METRICS** — P95 duration and rows-per-second throughput
> - **VW_OPERATIONAL_OVERVIEW** — framework config census per client
> - **VW_DAILY_SUMMARY** — today's ingestion report card
>
> Plus a live Snowsight dashboard with KPI scorecards, health tables, trend lines, and performance charts. All on an XSMALL warehouse. Observability doesn't have to be expensive."

---

## [19:00 - 20:00] THE BRIDGE

> "That's Module 09 — monitoring and dashboards. You can now see everything your framework does. Every success, every failure, every trend.
>
> In Module 10, the final module, we tackle schema evolution and advanced topics. What happens when a source adds a column? Removes one? Changes a data type? The framework needs to handle all of that without manual intervention. That's the finish line.
>
> All the SQL scripts are in the course repository. Link in the description. Build the views, create the dashboard, and see your framework's health for yourself.
>
> See you in Module 10."

---

## B-Roll / Visual Notes

| Timestamp | Visual |
|-----------|--------|
| 0:00-0:15 | Snowsight dashboard with KPI tiles and source health heat map |
| 0:15-1:30 | Course roadmap slide with Module 09 highlighted, observability philosophy slide |
| 1:30-3:30 | Executive summary concept slide, live SQL in Snowsight |
| 3:30-5:30 | Source health logic slide (HEALTHY/WARNING/CRITICAL), live SQL |
| 5:30-7:30 | Throughput concept slide, live SQL |
| 7:30-9:30 | Error analysis slide with severity table, live SQL |
| 9:30-11:30 | Performance metrics slide with P95 explanation, live SQL |
| 11:30-13:00 | Operational overview slide, live SQL |
| 13:00-14:30 | Daily summary slide, live SQL |
| 14:30-17:30 | Screen recording: Snowsight dashboard creation, tile configuration, auto-refresh |
| 17:30-19:00 | Verification queries, Module 09 recap slide |
| 19:00-20:00 | Module 10 preview slide — schema evolution |
