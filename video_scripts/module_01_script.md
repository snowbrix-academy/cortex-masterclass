# Module 1 Video Script: Set Up Your Snowflake AI Workspace

**Duration:** 12 minutes
**Instructor:** Snowbrix Academy
**Tone:** Direct, authoritative, demo-first
**Tagline:** "Production-Grade Data Engineering. No Fluff."

---

## Pre-Recording Checklist

- [ ] Clean Snowflake account (or create fresh trial)
- [ ] Browser tabs closed (only Snowflake Worksheets open)
- [ ] Code editor ready with SQL scripts
- [ ] OBS recording settings: 1920×1080, 30fps
- [ ] Microphone tested
- [ ] Desktop cleaned (no personal files visible)

---

## [00:00-00:30] Cold Open (30 seconds)

**[SCREEN: Blank screen with course logo]**

**SCRIPT:**

"Welcome to the Snowflake Cortex Masterclass. I'm going to show you how to build production AI data apps — no theory, no fluff, just working code.

Module 1: We're setting up your Snowflake AI workspace. By the end, you'll have a verified environment with 12 tables and 588,000 rows ready for Cortex Analyst, Agent, and Document AI.

Let's get started."

**[CUT TO: Instructor screen - Snowflake signup page]**

---

## [00:30-02:00] Section 1: Create Snowflake Trial (90 seconds)

**[SCREEN: https://signup.snowflake.com]**

**SCRIPT:**

"First, we need a Snowflake trial account. Go to signup.snowflake.com.

**[MOUSE: Click through signup form]**

Email, name, company — you can put 'Personal' if you're doing this individually.

**[HIGHLIGHT: Edition dropdown]**

Edition: Select **Enterprise**. This gives you access to Cortex services.

**[HIGHLIGHT: Cloud provider]**

Cloud: **AWS**.

**[HIGHLIGHT: Region dropdown]**

Region: This is critical. Choose **US East (N. Virginia)** or **US West (Oregon)**. Cortex Analyst is only available in these regions.

If you're already on a different region — no problem. I'll show you how to enable cross-region access in a minute.

**[MOUSE: Click 'Continue', check email]**

Check your email for the activation link, set a strong password, and log in.

**[CUT TO: Snowflake UI logged in]**

You're now in Snowsight — Snowflake's web interface."

---

## [02:00-03:30] Section 2: Verify Cortex Access (90 seconds)

**[SCREEN: Snowflake Worksheets tab]**

**SCRIPT:**

"Before we load data, let's verify Cortex services are enabled.

**[MOUSE: Click 'Worksheets' > '+ Worksheet']**

Create a new worksheet. Paste this SQL:

**[TYPE/PASTE:]**
```sql
-- Check Cortex Analyst
SELECT SYSTEM$CORTEX_ANALYST_STATUS();

-- Check Cortex Agent
SELECT SYSTEM$CORTEX_AGENT_STATUS();

-- Check Cortex Search
SELECT SYSTEM$CORTEX_SEARCH_STATUS();

-- Check region
SELECT CURRENT_REGION();
```

**[MOUSE: Click 'Run All' button]**

Run all queries.

**[RESULTS PANEL: Shows 'ENABLED', 'ENABLED', 'ENABLED', 'us-east-1']**

All three services return **'ENABLED'**. Perfect. Region shows **us-east-1**. We're good to go.

**[SCREEN: Alternate scenario - if DISABLED]**

If you see **'DISABLED'**, it means you're in an unsupported region. Here's the fix:

**[TYPE/PASTE:]**
```sql
USE ROLE ACCOUNTADMIN;
ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';
```

**[MOUSE: Run query]**

This enables cross-region inference. Note: it incurs data transfer costs. For production, deploy in us-east-1 or us-west-2.

**[CUT BACK TO: Main flow]**

Cortex is enabled. Let's load data."

---

## [03:30-05:30] Section 3: Clone Course Repository (2 minutes)

**[SCREEN: GitHub repository page]**

**SCRIPT:**

"All course materials are on GitHub. Go to:

**[SHOW URL BAR:]** github.com/snowbrix-academy/cortex-masterclass

**[MOUSE: Click 'Code' > Copy HTTPS URL]**

Copy the repository URL.

**[SWITCH TO: Terminal/Command Prompt]**

Open your terminal. Clone the repo:

**[TYPE:]**
```bash
git clone https://github.com/snowbrix-academy/cortex-masterclass.git
cd cortex-masterclass
```

**[SHOW: Directory listing]**
```bash
ls
```

**[SCREEN: Shows folders]**
```
docs/
labs/
sql_scripts/
streamlit_apps/
semantic_models/
...
```

The **sql_scripts** folder contains all our setup scripts. Let's load them into Snowflake.

**[SWITCH TO: VS Code or File Explorer]**

Open **sql_scripts** folder. You'll see:

**[LIST FILES ON SCREEN:]**
```
01_infrastructure.sql      — Creates databases, warehouses, roles
02_dimensions.sql          — Loads dimension tables (customers, products, regions)
03_sales_fact.sql          — Loads sales fact table (orders, order_items)
05_agent_tables.sql        — Root cause analysis tables
06_document_ai.sql         — Document AI tables
07_cortex_search.sql       — Search service setup
RUN_ALL_SCRIPTS.sql        — Master script (runs all)
VERIFY_ALL.sql             — Verification queries
```

We'll use **RUN_ALL_SCRIPTS.sql** to set up everything at once."

---

## [05:30-07:30] Section 4: Run Setup Scripts (2 minutes)

**[SCREEN: VS Code with RUN_ALL_SCRIPTS.sql open]**

**SCRIPT:**

"Open **RUN_ALL_SCRIPTS.sql**. This is the master script that calls all other setup scripts.

**[SCROLL THROUGH FILE - show structure]**

It's organized into sections:
- Infrastructure (warehouses, databases)
- Dimension tables
- Fact tables
- Agent tables
- Document AI tables

Each section is self-contained with:
- USE statements (role, warehouse, database, schema)
- CREATE statements
- INSERT statements with sample data
- Verification queries

Let's run it.

**[MOUSE: Select all (Ctrl+A), Copy (Ctrl+C)]**

Copy the entire script.

**[SWITCH TO: Snowflake Worksheets]**

Back in Snowflake Worksheets, create a new worksheet.

**[MOUSE: Click '+ Worksheet']**

Paste the script.

**[MOUSE: Paste (Ctrl+V)]**

**[SHOW: Script in worksheet - 3000+ lines]**

This is 3,000+ lines. Don't worry — it runs in under 2 minutes.

**[MOUSE: Click 'Run All' button]**

Click **'Run All'**.

**[SCREEN: Shows queries executing - results panel scrolling]**

Snowflake is executing all scripts sequentially:
- Creating warehouses...
- Creating databases...
- Loading customers... 1,000 rows
- Loading products... 500 rows
- Loading orders... 50,000 rows
- Loading order_items... 150,000 rows
- ...

**[WAIT: Show progress for 10-15 seconds, then JUMP CUT to completion]**

**[SCREEN: Shows 'Statement executed successfully' message]**

Done. 588,000 rows loaded across 12 tables.

Let's verify everything worked."

---

## [07:30-09:00] Section 5: Verify Data Loaded (90 seconds)

**[SCREEN: Snowflake Worksheets - new worksheet]**

**SCRIPT:**

"Create a new worksheet. We'll run the verification script.

**[SWITCH TO: VS Code]**

Open **VERIFY_ALL.sql** from the sql_scripts folder.

**[SHOW FILE CONTENTS - scroll through]**

This script checks row counts for all 12 tables and validates data quality.

**[COPY script, SWITCH BACK TO: Snowflake]**

Paste and run.

**[MOUSE: Run All]**

**[RESULTS PANEL: Shows table with columns: TABLE_NAME, ROW_COUNT]**

Results:

**[HIGHLIGHT each row as you read]**
```
CUSTOMERS        1,000
PRODUCTS         500
REGIONS          5
ORDERS           50,000
ORDER_ITEMS      150,000
RETURNS          5,000
PRODUCT_REVIEWS  10,000
...
Total: 588,000 rows
```

Perfect. All tables loaded successfully.

Let's do a quick sanity check — run a join query to make sure relationships work.

**[TYPE/PASTE:]**
```sql
SELECT
    c.customer_name,
    p.product_name,
    oi.quantity,
    oi.price,
    o.order_date
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN customers c ON o.customer_id = c.customer_id
JOIN products p ON oi.product_id = p.product_id
LIMIT 10;
```

**[MOUSE: Run query]**

**[RESULTS: Shows 10 rows with joined data]**

Joins work. Data quality looks good. We're ready for Cortex.

But first, one more critical check: Cortex Analyst needs a semantic model file uploaded to a Snowflake stage."

---

## [09:00-10:30] Section 6: Set Up Cortex Analyst Stage (90 seconds)

**[SCREEN: Snowflake Worksheets]**

**SCRIPT:**

"Cortex Analyst reads semantic YAML models from Snowflake stages. Let's create one.

**[TYPE/PASTE:]**
```sql
USE ROLE SYSADMIN;
USE WAREHOUSE COMPUTE_WH;
USE DATABASE DEMO_AI_SUMMIT;
USE SCHEMA CORTEX_ANALYST_DEMO;

-- Create stage for semantic models
CREATE STAGE IF NOT EXISTS CORTEX_ANALYST_STAGE;

-- Verify stage exists
SHOW STAGES;
```

**[MOUSE: Run queries]**

**[RESULTS: Shows CORTEX_ANALYST_STAGE in list]**

Stage created.

Now we need to upload a semantic YAML file. In Module 2, we'll build one from scratch. For now, let's upload the booth demo semantic model.

**[SWITCH TO: Terminal]**

From the course repository root:

**[TYPE:]**
```bash
cd semantic_models
ls
```

**[SHOW: cortex_analyst_demo.yaml]**

This YAML defines 7 tables with relationships and verified queries.

**[TYPE: (show on screen, don't execute if SnowSQL not available)]**
```bash
snowsql -a YOUR_ACCOUNT -u YOUR_USER \
  -q "PUT file://cortex_analyst_demo.yaml @DEMO_AI_SUMMIT.CORTEX_ANALYST_DEMO.CORTEX_ANALYST_STAGE AUTO_COMPRESS=FALSE;"
```

**[ALTERNATIVE PATH:]**

If you don't have SnowSQL installed, you can upload via Snowsight UI:

**[SWITCH TO: Snowflake UI]**

**[MOUSE: Navigate to Data > Databases > DEMO_AI_SUMMIT > CORTEX_ANALYST_DEMO > Stages]**

Click **CORTEX_ANALYST_STAGE** > **+ Files** > Upload **cortex_analyst_demo.yaml**.

**[SHOW: File uploaded]**

Verify it's there:

**[SWITCH TO: Worksheets]**
```sql
LIST @CORTEX_ANALYST_STAGE;
```

**[RESULTS: Shows cortex_analyst_demo.yaml]**

Perfect. Semantic model uploaded. Cortex Analyst can now read it."

---

## [10:30-11:30] Section 7: Test Cortex Analyst (60 seconds)

**[SCREEN: Snowflake Worksheets]**

**SCRIPT:**

"Let's do a quick smoke test. Can Cortex Analyst answer a question?

**[TYPE/PASTE:]**
```sql
SELECT SNOWFLAKE.CORTEX.COMPLETE(
    'mistral-large',
    'You are a data analyst. Answer: What is the total revenue?'
) AS response;
```

**[MOUSE: Run query]**

**[RESULTS: Shows AI-generated response]**

Cortex LLM works. But this is just text generation — not connected to our data.

In Module 2, we'll use **Cortex Analyst** (not COMPLETE) to query our tables using natural language. That requires the semantic model we just uploaded.

For now, our environment is fully set up."

---

## [11:30-12:00] Closing (30 seconds)

**[SCREEN: Return to course logo or instructor camera]**

**SCRIPT:**

"Recap: You now have a working Snowflake environment with:
- Cortex services enabled
- 12 tables with 588,000 rows
- A semantic model uploaded to a stage
- Everything verified

**Next: Module 2.**

We'll deploy your first Cortex Analyst app. You'll build a Streamlit interface where users ask questions in plain English — 'What are the top 5 products by revenue?' — and Cortex Analyst generates SQL and returns results.

Before Module 2, complete the Module 1 lab:
- Part A: Follow along with this video (already done if you followed along)
- Part B: Write 5 queries to explore the data (challenge yourself)

Submit your lab via GitHub PR. Instructions in the course repo.

See you in Module 2.

Production-Grade Data Engineering. No Fluff."

**[FADE TO: Course logo + GitHub link]**

---

## Post-Production Checklist

- [ ] Add timestamps in YouTube description
- [ ] Add chapter markers:
  - 00:00 Introduction
  - 00:30 Create Snowflake Trial
  - 02:00 Verify Cortex Access
  - 03:30 Clone Repository
  - 05:30 Run Setup Scripts
  - 07:30 Verify Data
  - 09:00 Set Up Stage
  - 10:30 Test Cortex Analyst
  - 11:30 Recap & Next Steps
- [ ] Add on-screen text overlays for key commands
- [ ] Add captions/subtitles
- [ ] Thumbnail: "Module 1: Snowflake Setup" with Snowflake logo
- [ ] Add GitHub repo link in description
- [ ] Pin comment: "Stuck? Post your error here for help."

---

## Screen Recording Notes

**Tools needed:**
- OBS Studio (free) for screen recording
- Camtasia/DaVinci Resolve for editing
- Blue Yeti or similar USB mic (clear audio critical)

**Recording tips:**
- Use 1920×1080 resolution
- 30fps
- Record in segments (easier to edit)
- Do a dry run first
- Keep mouse movements smooth
- Pause 2 seconds before/after each section (easier to cut)
- If you make a mistake, pause 3 seconds, then restart the sentence

**Editing:**
- Remove long pauses (keep pace fast)
- Add zoom-ins for small text
- Highlight mouse cursor when clicking important buttons
- Speed up long-running queries (2x speed)
- Add text overlays for SQL commands viewers should copy
- Background music: Subtle, low volume (optional)

---

## Demo Data Notes

**If recording with real trial account:**
- Use disposable email or +alias (e.g., you+demo@gmail.com)
- Clear browser cookies before recording
- Use incognito mode to avoid auto-fills
- Blur any personal account URLs in post-production

---

**Script Length:** ~2,400 words
**Speaking Rate:** 140 words/minute
**Calculated Duration:** 17 minutes
**Target Duration:** 12 minutes (after editing, removing pauses, speeding up long operations)

**Recording Date:** _____________
**Editor:** _____________
**Upload Date:** _____________
