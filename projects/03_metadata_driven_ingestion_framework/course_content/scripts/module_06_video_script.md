# Module 06 — Semi-Structured Data (JSON & Parquet) | Video Script

**Duration:** ~35 minutes
**Type:** 100% Hands-On
**Deliverable:** Semi-structured pipeline + FLATTEN views

---

## [0:00 - 0:15] THE HOOK

**[SCREEN: Snowsight showing a LATERAL FLATTEN query — nested JSON items array expanding into clean, typed rows]**

> "One VARIANT column. Nested objects, arrays, optional fields — all of it. Watch what happens when we FLATTEN it. Every array element becomes its own row. Every nested field gets a typed column. That's Snowflake's semi-structured engine, and in the next 35 minutes, you'll build a complete JSON and Parquet pipeline with flattened views using the MDF framework."

---

## [0:15 - 1:30] THE CONTEXT

**[SLIDE: Course Roadmap — Module 06 highlighted]**

> "Welcome to Module 06. In Module 05, we built the CSV pipeline — structured data, fixed columns, schema-on-write. Now we're handling the other half of the data world: semi-structured data. JSON. Parquet. The formats where the schema lives inside the data, not inside your table definition."

**[SLIDE: Schema-on-Read vs Schema-on-Write comparison]**

> "Two approaches:
>
> **Schema-on-Write** is what we did with CSV. You define the columns first, and the data must match. Add a column to the source file? The load breaks unless you update the table.
>
> **Schema-on-Read** is the JSON approach. You load everything into a single VARIANT column. The raw data is preserved exactly as-is. You define the schema later — at query time — by extracting and casting the fields you need.
>
> The MDF framework supports both. CSV uses schema-on-write. JSON uses schema-on-read. Same framework, different strategy. Zero code changes to the core procedures."

---

## [1:30 - 4:30] BUILD — JSON TARGET TABLE

**[Switch to Snowsight, open 01_json_ingestion_lab.sql]**

> "Let's build it. First, the target table for JSON data."

**[Run: CREATE SCHEMA MDF_RAW_DB.DEMO_WEB]**

> "A new schema in RAW — DEMO_WEB. This is for our web analytics events."

**[Run: CREATE TABLE RAW_EVENTS]**

> "Here's the table. Look at this:
>
> One column for the actual data — RAW_DATA, type VARIANT. That's it. One column holds the entire JSON document. Every field, every nested object, every array — all stored in one VARIANT column.
>
> Then our MDF metadata columns: _MDF_FILE_NAME from METADATA$FILENAME, _MDF_FILE_ROW from METADATA$FILE_ROW_NUMBER, and _MDF_LOADED_AT with the current timestamp. The same metadata pattern we used for CSV. Consistent across every source type.
>
> This is schema-on-read in action. We don't care what fields the JSON contains at load time. We figure that out when we query."

---

## [4:30 - 7:00] BUILD — UPLOAD & PREVIEW JSON

**[Run: PUT command for events.json to stage]**

> "Upload the sample events.json to our JSON stage. Same PUT command pattern — file path, stage path, auto-compress."

**[Run: LIST @MDF_STG_INTERNAL_JSON]**

> "There it is. One file in the JSON stage."

**[Run: SELECT $1 FROM stage query with LIMIT 3]**

> "Let's preview before loading. SELECT $1 from the stage with the JSON file format. There are our events — PAGE_VIEW, BUTTON_CLICK, FORM_SUBMIT. Each one is a self-contained JSON object with nested fields: device info, geo data, optional metadata.
>
> Notice the structure. Top-level fields like event_id and event_type. Nested objects like device with type, os, and browser inside it. And some events have fields that others don't — video_title only appears on video events. purchase items only appear on purchase events. This is why schema-on-read works here. A rigid column-per-field table would be full of NULLs."

---

## [7:00 - 9:30] BUILD — RUN INGESTION

**[Run: CALL SP_GENERIC_INGESTION for DEMO_EVENTS_JSON]**

> "Ingestion through the framework. Same SP_GENERIC_INGESTION procedure we used for CSV. The config table entry tells it to use the JSON file format and load into RAW_EVENTS.
>
> Let's check the audit log."

**[Run: Audit log query]**

> "RUN_STATUS: SUCCESS. 10 rows loaded. One file processed. The framework doesn't care whether the data is CSV or JSON. It reads the config, picks the right file format, and loads. That's the power of metadata-driven design."

---

## [9:30 - 14:00] BUILD — DOT NOTATION

**[SLIDE: Dot Notation for Nested JSON Access]**

> "Now for the real work — querying this data. Snowflake gives you dot notation to reach into VARIANT columns."

**[Run: SELECT RAW_DATA from RAW_EVENTS LIMIT 3]**

> "Raw VARIANT data. One column. Let's extract fields."

**[Run: Top-level field extraction with dot notation]**

> "The syntax: RAW_DATA colon field_name, double-colon, then the target type. RAW_DATA:event_id::VARCHAR. RAW_DATA:timestamp::TIMESTAMP. The colon navigates into the VARIANT. The double-colon casts to a SQL type. Without the cast, you get VARIANT values — which work, but downstream consumers expect typed columns."

**[Run: Nested field extraction — device, geo]**

> "Nested objects use dot notation chaining. RAW_DATA:device.type::VARCHAR gives you the device type. RAW_DATA:geo.country::VARCHAR gives you the country. You can go as deep as the nesting goes. device.type. geo.city. metadata.campaign.
>
> Here's what's powerful: if a field doesn't exist in a particular record, you get NULL. No error. No failure. RAW_DATA:video_title::VARCHAR returns NULL for PAGE_VIEW events and returns the actual title for VIDEO_PLAY events. Schema-on-read handles missing fields gracefully."

**[Run: Optional/conditional fields query]**

> "Look at this result set. video_title is populated for video events, NULL for everything else. company_size appears only for form submissions. purchase_amount only for purchases. One query, all event types, and Snowflake handles the optionality automatically."

---

## [14:00 - 19:00] BUILD — LATERAL FLATTEN

**[SLIDE: LATERAL FLATTEN Explained — visual showing array expanding into rows]**

> "Dot notation handles objects. But what about arrays? Our PURCHASE event has an items array — multiple products in one order. Dot notation can't help here because you don't know how many elements are in the array. That's where LATERAL FLATTEN comes in."

**[Run: Query to find events with items array]**

> "First, let's find events with arrays. RAW_DATA:items IS NOT NULL. There's our PURCHASE event with two items in the array."

**[Run: LATERAL FLATTEN query on items]**

> "Here's the FLATTEN syntax. FROM the events table aliased as e, comma, LATERAL FLATTEN with INPUT pointing to the array path — e.RAW_DATA:items — aliased as f.
>
> Now f.VALUE gives you each array element. f.VALUE:product_id::VARCHAR. f.VALUE:quantity::NUMBER. f.VALUE:price::NUMBER. One purchase event with two items becomes two rows. Each row has the parent event fields from e and the item-level fields from f.
>
> The computed column at the end — quantity times price — gives you the line total. Standard SQL math on flattened data. This is how you go from a nested JSON document to a clean, analytical result set.
>
> LATERAL FLATTEN is the single most important function for semi-structured data in Snowflake. If you remember one thing from this module, remember this pattern."

---

## [19:00 - 24:00] BUILD — VW_EVENTS_FLATTENED STAGING VIEW

**[SLIDE: VW_EVENTS_FLATTENED — View Architecture]**

> "We've been running ad-hoc queries. Now let's formalize this. Best practice: raw VARIANT data stays in the RAW layer. Typed, flattened views live in STAGING."

**[Run: CREATE SCHEMA MDF_STAGING_DB.DEMO_WEB]**

> "Staging schema for our web analytics."

**[Run: CREATE VIEW VW_EVENTS_FLATTENED]**

> "This is the money view. VW_EVENTS_FLATTENED in the STAGING database.
>
> Every field extracted and typed. event_id as VARCHAR. event_timestamp as TIMESTAMP_TZ. device fields. geo fields. campaign metadata. And all the event-specific optional fields — video_title, watch_time_seconds, completion_rate, order_id, total_amount, api_status_code, response_time_ms.
>
> Plus the MDF metadata columns carried through — file name and loaded-at timestamp.
>
> This view is what downstream consumers query. They never touch the VARIANT column directly. They get clean, typed, documented columns. If the source JSON adds a new field next week, the raw data already has it — you just add one line to the view definition. No re-ingestion. No table rebuild."

**[Run: Event count by type query on the view]**

> "Querying the view. Event type, count, unique users, unique sessions. Clean. Typed. Fast. This is what your analysts see."

**[Run: Events by country query]**

> "Country breakdown. US, UK, Germany — all extracted from nested geo objects, now simple columns."

**[Run: Device breakdown query]**

> "Device type and OS combinations. Desktop Windows, Mobile iOS, Desktop macOS, Server Linux. All from nested JSON, all queryable with standard SQL."

---

## [24:00 - 29:00] BUILD — PARQUET INGESTION WITH INFER_SCHEMA

**[SLIDE: Parquet + INFER_SCHEMA]**

> "Now Parquet. If JSON is schema-on-read, Parquet is schema-already-there. Parquet files carry their schema inside the file — column names, data types, everything. Snowflake can read that schema directly.
>
> The key function: INFER_SCHEMA. It reads a Parquet file in a stage and returns the column definitions. You can use this to auto-create tables — no manual column definitions needed."

**[Run: INFER_SCHEMA query on Parquet stage]**

> "SELECT star FROM TABLE, INFER_SCHEMA, with the stage location and the Parquet file format. Look at the output: column name, data type, nullable, ordinal position. Snowflake extracted the full schema from the file metadata. No guessing. No manual mapping."

**[Show: CREATE TABLE USING TEMPLATE pattern]**

> "Here's the pattern for auto-creating tables from Parquet. CREATE TABLE USING TEMPLATE with a subquery on INFER_SCHEMA. Snowflake reads the schema from the file and creates matching columns. Then COPY INTO loads the data.
>
> For the MDF framework, the config table entry for a Parquet source uses MDF_FF_PARQUET_STANDARD. The stored procedure handles the rest. Same framework, different file format, automatic schema detection."

**[Show: Querying Parquet-loaded data]**

> "Once loaded, Parquet data has proper typed columns from the start. No dot notation needed. No view creation required — although you might still want views for transformations or joins. The point is: Parquet gives you structure at load time, JSON gives you structure at query time. Both work in the MDF framework."

---

## [29:00 - 32:00] BUILD — ANALYTICS ON FLATTENED DATA

**[Switch back to Snowsight]**

> "Let's put it together. Real analytics queries on our flattened event data."

**[Run: Funnel analysis query — page views to signups to purchases]**

> "A simple funnel. PAGE_VIEW count, then SIGNUP count, then PURCHASE count. This tells you conversion rates. How many people who viewed a page eventually signed up? How many who signed up eventually purchased? All from one JSON file, one VARIANT column, one flattened view."

**[Run: Campaign performance query]**

> "Campaign attribution. Events grouped by campaign and medium, filtered to events that have campaign metadata. google_ads_q1 drove the most engagement. linkedin_awareness brought mobile users. organic_search led to the longest video watch times. This is the kind of analysis that was locked inside nested JSON five minutes ago."

**[Run: Hourly activity pattern query]**

> "Time-based patterns. Events by hour of day. You can see peak activity windows. All of this is standard SQL on typed columns — the VARIANT complexity is hidden behind the view."

---

## [32:00 - 34:00] VERIFICATION & RECAP

**[SLIDE: Module 06 Recap]**

> "Let's recap what we built in 35 minutes:
>
> **RAW_EVENTS table** with a VARIANT column — schema-on-read for JSON data.
>
> **Dot notation** to extract and type-cast nested fields — colon for navigation, double-colon for casting.
>
> **LATERAL FLATTEN** to explode arrays into rows — one purchase event becomes multiple line-item rows.
>
> **VW_EVENTS_FLATTENED** in the staging database — typed columns, clean interface for downstream consumers.
>
> **Parquet with INFER_SCHEMA** — automatic table creation from self-describing files.
>
> And here's the key point: the MDF framework handled JSON with the same stored procedure, same audit log, same config pattern as CSV. The file format changed. The approach changed. The framework didn't."

---

## [34:00 - 35:00] THE BRIDGE

> "That's Module 06 — semi-structured data. JSON and Parquet are now part of your framework.
>
> But what happens when things go wrong? A malformed JSON document. A missing file. A type-cast error inside a FLATTEN query. Right now, those failures are silent. In Module 07, we build error handling and audit logging. TRY_CAST for safe type conversions. VALIDATION_MODE to catch errors before they hit your tables. Structured error logging so you know exactly what failed, why it failed, and which file caused it.
>
> All the SQL scripts are in the course repository. Link in the description. Run the full lab yourself before Module 07.
>
> See you in Module 07."

---

## B-Roll / Visual Notes

| Timestamp | Visual |
|-----------|--------|
| 0:00-0:15 | Screen recording of LATERAL FLATTEN query result expanding rows |
| 0:15-1:30 | Course roadmap slide → Schema-on-Read vs Schema-on-Write comparison slide |
| 1:30-4:30 | Live SQL — CREATE SCHEMA, CREATE TABLE with VARIANT column |
| 4:30-7:00 | Live SQL — PUT, LIST, stage preview SELECT $1 |
| 7:00-9:30 | Live SQL — SP_GENERIC_INGESTION call + audit log check |
| 9:30-10:00 | Dot notation concept slide |
| 10:00-14:00 | Live SQL — dot notation queries, nested fields, optional fields |
| 14:00-14:30 | LATERAL FLATTEN concept slide with visual diagram |
| 14:30-19:00 | Live SQL — FLATTEN queries on items array |
| 19:00-19:30 | View architecture slide |
| 19:30-24:00 | Live SQL — CREATE VIEW, analytics queries on flattened view |
| 24:00-24:30 | Parquet + INFER_SCHEMA concept slide |
| 24:30-29:00 | Live SQL — INFER_SCHEMA, CREATE TABLE USING TEMPLATE, Parquet load |
| 29:00-32:00 | Live SQL — funnel analysis, campaign attribution, hourly patterns |
| 32:00-34:00 | Module 06 recap slide |
| 34:00-35:00 | Module 07 preview slide — Error Handling & Audit |
