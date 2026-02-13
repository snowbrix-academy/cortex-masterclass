# Module 02 — File Formats & Stages | Video Script

**Duration:** ~20 minutes
**Type:** Concept + Hands-On
**Deliverable:** 10 file formats, 4 internal stages, external stage templates

---

## [0:00 - 0:15] THE HOOK

**[SCREEN: Snowsight showing SHOW FILE FORMATS with 10 formats listed]**

> "Ten file formats. Four stages. One naming convention. After this module, your framework will know *how* to read any file — CSV, JSON, Parquet, Avro, ORC — and *where* to find them."

---

## [0:15 - 1:30] THE CONTEXT

**[SLIDE: Course Roadmap — Module 02 highlighted]**

> "Welcome to Module 02. In Module 01, we built the infrastructure — databases, warehouses, roles. Now we're telling the framework how to read data and where to find it."

**[SLIDE: What Are File Formats & Stages diagram]**

> "Two concepts:
>
> **File Formats** define the structure of your source files. Is it CSV? What's the delimiter? Does it have headers? Is it JSON? Should we strip the outer array? These are the rules Snowflake uses to parse your files.
>
> **Stages** are the locations where files live before being loaded. Think of a stage as a loading dock. Internal stages live inside Snowflake — great for development. External stages point to S3, Azure, or GCS — that's production."

---

## [1:30 - 3:30] FILE FORMAT CONCEPTS

**[SLIDE: Why Named File Formats Matter]**

> "You can define file format options inline in every COPY INTO statement. Most tutorials do it that way. Don't.
>
> Inline means every COPY INTO repeats the same settings. Change a null string? Update 50 scripts. Named file formats mean you define the rules once, reference them everywhere.
>
> Our naming convention: MDF_FF followed by the type and variant. MDF_FF_CSV_STANDARD. MDF_FF_JSON_NDJSON. MDF_FF_PARQUET_STANDARD. You can tell what a file format does just by reading its name."

**[SLIDE: CSV File Format Options table]**

> "For CSV, the critical options are:
>
> **SKIP_HEADER** — does the file have a header row? Most do. Set to 1.
>
> **FIELD_OPTIONALLY_ENCLOSED_BY** — double quotes. Without this, a field like 'John, Jr.' splits into two columns.
>
> **NULL_IF** — different systems represent nulls differently. 'NULL', 'null', empty string, 'N/A'. Define them all here, and downstream you get consistent SQL NULLs.
>
> **ERROR_ON_COLUMN_COUNT_MISMATCH** — set this to FALSE. If a source adds a column next month, your load shouldn't break. It just ignores the extra column."

---

## [3:30 - 7:00] CSV FILE FORMATS — LIVE

**[Switch to Snowsight, run 01_file_formats.sql]**

> "Let's create these. First, the standard CSV format."

**[Run: CREATE FILE FORMAT MDF_FF_CSV_STANDARD]**

> "MDF_FF_CSV_STANDARD. Comma-delimited, header row, double-quote enclosed, auto-compression detection. Notice the NULL_IF list — six different null representations. This handles the majority of CSV files you'll encounter."

**[Run: CREATE FILE FORMAT MDF_FF_CSV_PIPE]**

> "Pipe-delimited. Same settings, different delimiter. You see these in legacy system extracts — mainframes love pipe-delimited files."

**[Run: CREATE FILE FORMAT MDF_FF_CSV_TAB]**

> "Tab-delimited. TSV files. Same pattern."

**[Run: CREATE FILE FORMAT MDF_FF_CSV_NO_HEADER]**

> "And CSV without headers. SKIP_HEADER = 0. When the file has no header row, Snowflake maps columns by position — first column in the file goes to the first column in the table. Order matters."

---

## [7:00 - 10:00] JSON & SEMI-STRUCTURED FORMATS

**[SLIDE: JSON File Format Options]**

> "JSON is where it gets interesting. The key setting is STRIP_OUTER_ARRAY.
>
> Here's the issue: if your JSON file is a single array — open bracket, object, object, object, close bracket — Snowflake treats that as one row by default. One row containing the entire array. STRIP_OUTER_ARRAY unpacks it into individual rows. You almost always want this."

**[Run: CREATE FILE FORMAT MDF_FF_JSON_STANDARD]**

> "Standard JSON. STRIP_OUTER_ARRAY = TRUE, STRIP_NULL_VALUES = FALSE. We keep nulls because they tell us something about the source schema — a missing key versus an explicit null are different things."

**[Run: CREATE FILE FORMAT MDF_FF_JSON_NDJSON]**

> "NDJSON — newline-delimited JSON. One JSON object per line. STRIP_OUTER_ARRAY is FALSE because there's no outer array to strip. Each line is already a single record. You'll see this format from streaming systems — Kafka, Kinesis, Firehose."

**[Run: CREATE FILE FORMAT MDF_FF_JSON_COMPACT]**

> "Compact JSON. Same as standard but STRIP_NULL_VALUES = TRUE. Removes null keys from stored objects. Saves storage, reduces scan costs on wide JSON documents."

---

## [10:00 - 12:00] PARQUET, AVRO, ORC

**[SLIDE: Column-Oriented Formats comparison]**

> "Parquet, Avro, and ORC are self-describing formats. They carry their schema inside the file. This means Snowflake needs minimal configuration — it reads the schema from the file itself.
>
> **Parquet** — the most common. Columnar storage, Snappy compression. This is the standard for data lakes. If someone says 'our data is in the lake,' it's probably Parquet.
>
> **Avro** — row-based, schema evolution friendly. Common in Kafka and Confluent environments.
>
> **ORC** — Optimized Row Columnar. Hadoop ecosystem. You'll see it in legacy Hive migrations."

**[Run: CREATE FILE FORMAT statements for Parquet, Avro, ORC]**

> "Three formats, minimal config each. Parquet gets SNAPPY_COMPRESSION and BINARY_AS_TEXT. Avro and ORC just need COMPRESSION = AUTO. The formats do the heavy lifting."

---

## [12:00 - 14:30] INTERNAL STAGES

**[SLIDE: Stage Types diagram showing Internal vs External]**

> "Now: where the files live. Stages.
>
> Snowflake has three types of internal stages:
>
> **User stages** — the at-tilde (@~). Auto-created per user. Don't use these for frameworks — they're tied to individual users.
>
> **Table stages** — the at-percent (@%table). Auto-created per table. Same problem — too tightly coupled.
>
> **Named stages** — explicitly created, shareable, reusable. This is what we use. You grant access to roles, not users."

**[Switch to Snowsight, run 02_stages.sql]**

**[Run: CREATE STAGE statements for internal stages]**

> "Four internal stages. DEV for general testing. CSV, JSON, and PARQUET for type-specific ingestion.
>
> The key setting: DIRECTORY = ENABLE TRUE. Directory tables let you query file metadata using standard SQL — file name, size, last modified timestamp. This is how the MDF framework detects new files without scanning the entire stage."

**[Run: LIST @MDF_STG_INTERNAL_DEV]**

> "LIST shows you what's in a stage. Right now they're empty — we'll populate them in Module 05. But the infrastructure is ready."

---

## [14:30 - 17:00] EXTERNAL STAGES

**[SLIDE: External Stage Architecture — S3/Azure/GCS]**

> "In production, your files aren't inside Snowflake. They're in S3, Azure Blob, or GCS. External stages point to those locations.
>
> The right way to connect: **Storage Integrations**. Never hardcode AWS access keys or Azure SAS tokens in a stage definition. Storage Integrations use IAM roles — they're more secure, easier to rotate, and auditable."

**[Show the external stage template code — S3 section]**

> "Here's the S3 pattern:
>
> Step one: Create a Storage Integration with the IAM role ARN and allowed locations. Notice STORAGE_ALLOWED_LOCATIONS — be specific. Don't allow the entire bucket when you only need one prefix.
>
> Step two: Describe the integration to get the external ID for the trust policy.
>
> Step three: Create the external stage referencing the integration.
>
> We've left these as templates in the lab scripts — uncomment and modify for your cloud provider. For this course, we'll use internal stages to keep things portable."

**[SLIDE: Storage Integration Best Practices]**

> "Three rules for external stages:
>
> One — always use Storage Integrations over direct credentials.
>
> Two — restrict STORAGE_ALLOWED_LOCATIONS to the minimum paths.
>
> Three — one stage per purpose. Don't mix sales data and HR data in the same stage. You can't grant granular access to a sub-path within a stage."

---

## [17:00 - 19:00] VERIFICATION & RECAP

**[Switch to Snowsight, run verification queries]**

> "Let's verify. SHOW FILE FORMATS — there are our ten formats. Four CSV variants, three JSON variants, one each for Parquet, Avro, and ORC."

**[Run: SHOW STAGES]**

> "SHOW STAGES — four internal stages, all with directory tables enabled."

**[Run: DESCRIBE FILE FORMAT and DESCRIBE STAGE]**

> "DESCRIBE lets you inspect any object. You can see every setting — what's explicitly set and what's defaulted. Useful for debugging when a load doesn't behave as expected."

**[SLIDE: Module 02 Recap]**

> "Here's what we built:
> - 10 file formats covering CSV, JSON, Parquet, Avro, and ORC
> - 4 internal stages with directory tables
> - External stage templates for S3, Azure, and GCS
> - A naming convention that makes every object self-documenting
>
> The framework now knows how to read files and where to find them."

---

## [19:00 - 20:00] THE BRIDGE

> "That's Module 02 — file formats and stages. In Module 03, we build the brain of the framework: the config tables. That's where we define *what* to load, *where* to put it, and *how* to handle it. One config table to control everything.
>
> All the SQL scripts are in the course repository. Link in the description. Run them yourself before the next module.
>
> See you in Module 03."

---

## B-Roll / Visual Notes

| Timestamp | Visual |
|-----------|--------|
| 0:00-0:15 | Screen recording of SHOW FILE FORMATS output |
| 0:15-1:30 | Course roadmap slide → File formats & stages concept slide |
| 1:30-3:30 | Slide: named vs inline formats → CSV options table |
| 3:30-7:00 | Live SQL execution in Snowsight — CSV file formats |
| 7:00-7:30 | JSON options slide |
| 7:30-10:00 | Live SQL — JSON file formats |
| 10:00-10:30 | Column-oriented formats comparison slide |
| 10:30-12:00 | Live SQL — Parquet, Avro, ORC formats |
| 12:00-12:30 | Stage types diagram slide |
| 12:30-14:30 | Live SQL — internal stages |
| 14:30-15:30 | External stage architecture slide |
| 15:30-17:00 | Code walkthrough — external stage templates |
| 17:00-19:00 | Verification queries running live |
| 19:00-20:00 | Module recap slide → Module 03 preview |
