# Snowflake Innovation Summit — AI Demo Plan

> **Event:** Innovation Summit / Innovation Hub (3-day booth)
> **Audience:** 300+ enterprise clients visiting the event (estimated 180-280 interactive booth touchpoints over 3 days)
> **Environment:** Snowflake Enterprise, AWS us-east-1
> **Team:** 3 booth operators (station-owner model)
> **Lead time:** ~2 weeks to go-live
> **Tagline:** _"AI-driven data products — inside Snowflake, not around it."_

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Audience & Messaging Strategy](#2-audience--messaging-strategy)
3. [Environment Setup](#3-environment-setup)
4. [Synthetic Data Model](#4-synthetic-data-model)
5. [Demo Track: Tier 1 — Hero Demos](#5-demo-track-tier-1--hero-demos)
6. [Demo Track: Tier 2 — Deep Dives](#6-demo-track-tier-2--deep-dives)
7. [Demo Track: Tier 3 — Optional / Bonus](#7-demo-track-tier-3--optional--bonus)
8. [Streamlit App Skeletons](#8-streamlit-app-skeletons)
9. [Booth Operations Plan](#9-booth-operations-plan)
10. [Talking Points & Objection Handling](#10-talking-points--objection-handling)
11. [Leave-Behind 1-Pager](#11-leave-behind-1-pager)
12. [Risk & Fallback Matrix](#12-risk--fallback-matrix)

---

## 1. Executive Summary

### What

A 3-day Innovation Summit booth showcasing Snowflake's AI-centric capabilities to 300+ enterprise clients. Three live demo stations run continuously, each featuring a different Cortex-powered use case — all running inside Snowflake with zero external infrastructure.

### Why

The message clients should walk away with:

> **"We can build AI-driven data products inside Snowflake, not around it."**

Every demo reinforces three proof points:
1. **"I can talk to my own data"** — Cortex Analyst turns every business user into a self-service analyst.
2. **"My data can act on its own"** — Cortex Agent shows autonomous, multi-step investigation beyond simple Q&A.
3. **"All my documents are instant insights"** — Document AI + Cortex Search turns unstructured PDFs into queryable knowledge.

### How

| Layer | What's Built | Reference |
|-------|-------------|-----------|
| **Data** | 588K rows of synthetic data across 12 tables, story-first design with planted anomalies. 7 idempotent SQL scripts, < 2 min to load. | Section 4 |
| **Demos** | 3 Tier 1 hero demos (Cortex Analyst, Data Agent, Document AI), 3 Tier 2 deep-dives, 3 Tier 3 bonus demos. | Sections 5, 6, 7 |
| **UI** | 3 Streamlit in Snowflake apps (280-350 lines each), copy-paste deployment, fallback-first design. | Section 8 |
| **Ops** | 3-person station-owner model, 3-day escalation strategy (Awareness → Depth → Conversion), staggered breaks, emergency playbook. | Section 9 |
| **Pitch** | Per-station/persona talk tracks, 12 objection responses, transition phrases, printable cheat sheet. | Section 10 |

### Key Numbers

| Metric | Target |
|--------|--------|
| Setup lead time | ~2 weeks (T-14 to T-0) |
| Data load time | < 2 minutes |
| Demo duration (walk-up) | 3-5 minutes |
| Daily visitor touchpoints | 60-120 |
| 3-day total leads | 75-125 |
| 3-day meetings booked | 8-17 |
| Station coverage | 100% (never unstaffed) |
| Fallback coverage | 100% (every demo has offline mode) |

### Environment

- **Snowflake:** Enterprise edition, AWS us-east-1
- **Database:** `DEMO_AI_SUMMIT` (3 schemas: `CORTEX_ANALYST_DEMO`, `DOC_AI_DEMO`, `STAGING`)
- **Warehouse:** `DEMO_AI_WH` (Medium, auto-suspend 60s)
- **Team:** 3 station owners, cross-trained on all demos
- **Language:** English only

---

## 2. Audience & Messaging Strategy

### Audience Breakdown

The 300+ visitors are a mixed enterprise audience. Expect this approximate distribution:

| Persona | % of Traffic | Time at Booth | What They Want | What They Fear |
|---------|-------------|---------------|---------------|----------------|
| **CXO / VP** (Business sponsors) | 15-20% | 2-3 min | ROI, time saved, competitive edge, vendor consolidation | Hype without substance, hidden cost, vendor lock-in |
| **Data Leaders / Architects** | 25-30% | 5-10 min | Architecture, governance, security posture, integration with existing stack | Shadow AI, ungoverned models, another tool to maintain |
| **Analysts / Power Users** | 25-30% | 3-5 min | "Can I use this Monday?", speed, accuracy, daily workflow fit | Being replaced by AI, inaccurate numbers, loss of control |
| **Engineers / Developers** | 20-25% | 5-10 min | APIs, extensibility, CI/CD, semantic model structure, Native App packaging | Toy demos that don't scale, proprietary lock-in, poor DX |

### Core Message

One sentence that every booth interaction reinforces:

> **"AI-driven data products — inside Snowflake, not around it."**

This message works because it:
- Positions Snowflake as the **platform**, not a point solution
- Addresses the #1 enterprise AI fear: **data leaving the perimeter**
- Differentiates from competitors who require **external AI orchestration**

### Messaging Framework

Three proof points, mapped to demos:

| Proof Point | Demo | Headline for Visitors |
|-------------|------|-----------------------|
| **"I can talk to my own data"** | Cortex Analyst (Station A) | Every business user becomes a self-service analyst. No SQL, no BI tool, no waiting. |
| **"My data can act on its own"** | Cortex Agent (Station B) | Autonomous, multi-step investigation — root-cause analysis in 90 seconds, not 3 days. |
| **"All my documents are instant insights"** | Document AI + Cortex Search (Station C) | Unstructured data (PDFs, contracts) becomes queryable knowledge. Semantic search, not keyword matching. |

### Per-Persona Value Propositions

#### CXO / VP — "Show Me the Business Impact"

**What to lead with:**
- Time-to-insight reduction: "30 seconds vs 3 days for an ad-hoc answer"
- Headcount efficiency: "Not replacing analysts — freeing them from routine queries"
- Vendor consolidation: "AI, analytics, governance, and search — one platform, one bill"
- Competitive positioning: "Your competitors are building AI data products. This is how you do it without a 12-month ML platform build."

**What to avoid:**
- Technical architecture details (save for data leaders)
- Feature lists or product names (Cortex, Arctic, Mosaic mean nothing to them)
- Cost per credit breakdowns (they care about total cost of ownership, not unit economics)

**Closing move:** "Let's schedule a 60-minute PoC with your data. We'll build a semantic model for one of your use cases and show you what your team would see."

---

#### Data Leader / Architect — "Show Me the Governance"

**What to lead with:**
- Semantic layer as control plane: "One YAML file defines what the AI can query — tables, joins, metrics, business terms. You own the definitions."
- Zero data movement: "No copies, no exports, no ETL to an AI platform. Cortex queries your existing tables."
- Security posture: "Row-level security, masking policies, and access controls apply to Cortex Analyst the same way they apply to SQL queries."
- Integration: "The semantic model is version-controlled. CI/CD with dbt, git, Terraform — your existing pipeline."

**What to avoid:**
- Oversimplifying setup effort ("it's easy!" → they know better)
- Comparing to their existing BI tool (they chose it; don't question that decision)
- Ignoring their governance concerns (this is their #1 priority)

**Closing move:** "Want to see the semantic model YAML? I can walk through how it maps to your existing dbt project." (Bridge to side-table deep-dive.)

---

#### Analyst / Power User — "Show Me My Monday Morning"

**What to lead with:**
- Speed: "Type a question, get the answer. The SQL is visible — you can validate every number."
- Augmentation, not replacement: "This handles the routine questions. You focus on the complex analysis that actually needs human judgment."
- Multi-turn: "Ask a follow-up. It remembers context. You're having a conversation with your data, not running isolated queries."
- Embeddable: "This chat interface can live inside your internal portal, your Slack, your existing workflow."

**What to avoid:**
- Anything that implies they're being automated away (existential threat kills engagement)
- Suggesting they shouldn't check the SQL (they will, and they should)
- Over-promising accuracy (say "governed and auditable", not "always right")

**Closing move:** "Try it yourself — pick a challenge card and type the question." (Hand them the interaction.)

---

#### Engineer / Developer — "Show Me the Stack"

**What to lead with:**
- Semantic model as code: "YAML, version-controlled, CI/CD deployable. Treat it like a dbt model."
- Tool extensibility: "Define SQL tools, Python tools, API tools. The agent orchestrates; you own the tools."
- Native App packaging: "Package the Cortex Analyst + Streamlit app as a Snowflake Native App. Distribute to customers or internal teams."
- No external infra: "No API gateway, no model hosting, no vector database. Cortex Search, Cortex Analyst, Streamlit — all inside Snowflake."

**What to avoid:**
- Glossing over the API surface ("it just works" → they want to see the code)
- Hiding limitations (if Agent isn't GA, say so — engineers respect honesty)
- Marketing language (no "seamless", "effortless", "cutting-edge")

**Closing move:** "Here's the semantic model template and the Streamlit skeleton. Want me to share the repo?" (Have a QR code linking to a sample repo or gist.)

---

### Message Hierarchy (What to Say First)

For any visitor whose persona isn't immediately clear, use this default hierarchy:

```
1. OUTCOME     → "Ask any question, get the answer in 30 seconds."
                  (Universal appeal — works for all personas.)

2. PROOF       → Run the demo. Let them see it work live.
                  (Show, don't tell.)

3. TRUST       → "No data leaves Snowflake. The SQL is visible.
                   Your governance applies."
                  (Address the unspoken concern: "Can I trust this?")

4. NEXT STEP   → "Want to try it with your data?"
                  (Always end with a forward action.)
```

Never start at layer 4 (the pitch). Never stay at layer 1 (the promise). The demo IS the proof — get to it within 15 seconds of the visitor arriving.

---

## 3. Environment Setup

### Overview

This section is the infra checklist your team runs at T-14 (day one of the 2-week lead time). Every object, permission, and service must be verified before data loading (Section 4) begins. The goal: by T-7, the environment is frozen and ready for app deployment.

**Run order:**
1. Account & region verification (this section)
2. Infrastructure SQL (Section 4, Script 01)
3. Data loading (Section 4, Scripts 02-07)
4. Cortex service creation (Section 4, Script 07 + this section)
5. Streamlit app deployment (Section 8)
6. End-to-end verification (this section)

---

### Step 1: Account & Edition Verification

Before building anything, confirm your Snowflake account supports all required features.

```sql
-- Check edition (must be Enterprise or higher)
SELECT CURRENT_ACCOUNT(), SYSTEM$GET_SNOWFLAKE_EDITION();
-- Expected: 'ENTERPRISE' or 'BUSINESS_CRITICAL'

-- Check region (must be a Cortex-supported region)
SELECT CURRENT_REGION();
-- Expected: 'AWS_US_EAST_1' (confirmed supported)

-- Check Cortex function availability
SELECT SNOWFLAKE.CORTEX.COMPLETE('llama3.1-8b', 'Hello, world');
-- Expected: A text response (proves Cortex LLM functions are enabled)

-- Check Cortex Analyst availability
-- (No direct SQL check — verify via Streamlit app or Snowsight Copilot)

-- Check Cortex Search availability
SELECT SYSTEM$TYPEOF(NULL);  -- Placeholder; actual check is creating the service
-- Real check: CREATE CORTEX SEARCH SERVICE (Script 07) succeeds
```

**If any check fails:**

| Check | Failure | Action |
|-------|---------|--------|
| Edition is Standard | Cortex features unavailable | Upgrade to Enterprise or use a trial Enterprise account |
| Region not supported | Some Cortex features may be missing | Check [Snowflake region support matrix](https://docs.snowflake.com/en/user-guide/cortex-llm-functions#region-availability). Consider cross-region replication if needed. |
| `CORTEX.COMPLETE` errors | Cortex LLM not enabled | File a support ticket or check account-level parameter: `ENABLE_CORTEX_LLM_FUNCTIONS` |
| Cortex Search CREATE fails | Feature not GA in your region | Use fallback search (LIKE queries) in the Streamlit app. Cortex Search has narrower regional availability than COMPLETE. |

---

### Step 2: Role & Permission Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    PERMISSION HIERARCHY                          │
│                                                                 │
│  ACCOUNTADMIN                                                   │
│  └── SYSADMIN                                                   │
│      └── creates database, schemas, warehouse                   │
│  └── SECURITYADMIN                                              │
│      └── creates DEMO_AI_ROLE                                   │
│          └── USAGE on DEMO_AI_SUMMIT (database)                 │
│          └── ALL PRIVILEGES on all 3 schemas                    │
│          └── USAGE + OPERATE on DEMO_AI_WH                      │
│          └── CREATE CORTEX SEARCH SERVICE                       │
│          └── CREATE STREAMLIT                                   │
│          └── USAGE on SNOWFLAKE.CORTEX (for LLM functions)      │
│                                                                 │
│  DEMO_AI_ROLE                                                   │
│  ├── Granted to: Owner 1 user, Owner 2 user, Owner 3 user      │
│  ├── Used by: All SQL scripts, all Streamlit apps               │
│  └── No access to: production databases, other schemas          │
└─────────────────────────────────────────────────────────────────┘
```

**Grant script** (run as SECURITYADMIN, after Script 01 creates the objects):

```sql
USE ROLE SECURITYADMIN;

-- Create demo role
CREATE ROLE IF NOT EXISTS DEMO_AI_ROLE
    COMMENT = 'Role for Innovation Summit AI demos';

-- Database and schema grants
GRANT USAGE ON DATABASE DEMO_AI_SUMMIT TO ROLE DEMO_AI_ROLE;
GRANT ALL PRIVILEGES ON SCHEMA DEMO_AI_SUMMIT.CORTEX_ANALYST_DEMO TO ROLE DEMO_AI_ROLE;
GRANT ALL PRIVILEGES ON SCHEMA DEMO_AI_SUMMIT.DOC_AI_DEMO TO ROLE DEMO_AI_ROLE;
GRANT ALL PRIVILEGES ON SCHEMA DEMO_AI_SUMMIT.STAGING TO ROLE DEMO_AI_ROLE;

-- Future grants (so new tables/views are auto-accessible)
GRANT ALL PRIVILEGES ON FUTURE TABLES IN SCHEMA DEMO_AI_SUMMIT.CORTEX_ANALYST_DEMO TO ROLE DEMO_AI_ROLE;
GRANT ALL PRIVILEGES ON FUTURE TABLES IN SCHEMA DEMO_AI_SUMMIT.DOC_AI_DEMO TO ROLE DEMO_AI_ROLE;
GRANT ALL PRIVILEGES ON FUTURE STAGES IN SCHEMA DEMO_AI_SUMMIT.DOC_AI_DEMO TO ROLE DEMO_AI_ROLE;

-- Warehouse grants
GRANT USAGE ON WAREHOUSE DEMO_AI_WH TO ROLE DEMO_AI_ROLE;
GRANT OPERATE ON WAREHOUSE DEMO_AI_WH TO ROLE DEMO_AI_ROLE;
GRANT MONITOR ON WAREHOUSE DEMO_AI_WH TO ROLE DEMO_AI_ROLE;

-- Cortex function access
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE DEMO_AI_ROLE;

-- Streamlit creation rights
GRANT CREATE STREAMLIT ON SCHEMA DEMO_AI_SUMMIT.CORTEX_ANALYST_DEMO TO ROLE DEMO_AI_ROLE;
GRANT CREATE STREAMLIT ON SCHEMA DEMO_AI_SUMMIT.DOC_AI_DEMO TO ROLE DEMO_AI_ROLE;

-- Cortex Search service creation
GRANT CREATE CORTEX SEARCH SERVICE ON SCHEMA DEMO_AI_SUMMIT.DOC_AI_DEMO TO ROLE DEMO_AI_ROLE;

-- Stage access for semantic model and documents
GRANT CREATE STAGE ON SCHEMA DEMO_AI_SUMMIT.CORTEX_ANALYST_DEMO TO ROLE DEMO_AI_ROLE;

-- Grant role to booth team (replace with actual usernames)
GRANT ROLE DEMO_AI_ROLE TO USER OWNER_1_USERNAME;
GRANT ROLE DEMO_AI_ROLE TO USER OWNER_2_USERNAME;
GRANT ROLE DEMO_AI_ROLE TO USER OWNER_3_USERNAME;

-- Grant role to SYSADMIN for administration
GRANT ROLE DEMO_AI_ROLE TO ROLE SYSADMIN;
```

---

### Step 3: Cortex Service Enablement Checklist

| Service | Required By | How to Verify | Enable If Missing |
|---------|-------------|--------------|-------------------|
| **Cortex LLM Functions** (COMPLETE, SENTIMENT, SUMMARIZE, TRANSLATE) | Demos 1, 2, Tier 2, Tier 3 | `SELECT SNOWFLAKE.CORTEX.COMPLETE('llama3.1-8b', 'test');` | Should be enabled by default on Enterprise. If not: `ALTER ACCOUNT SET ENABLE_CORTEX_LLM_FUNCTIONS = TRUE;` (ACCOUNTADMIN) |
| **Cortex Analyst** | Demos 1, 2 | Deploy a test Streamlit app with `_snowflake.send_message("analyst", ...)` | Requires semantic model YAML staged. If `send_message` errors with "analyst not available", file Snowflake support ticket. |
| **Cortex Search** | Demo 3 | `CREATE CORTEX SEARCH SERVICE ...` (Script 07) succeeds and `SHOW CORTEX SEARCH SERVICES` shows ACTIVE | Available on Enterprise in most regions. If CREATE fails, check region support. |
| **Cortex Agent** | Demo 2 (live mode) | `_snowflake.send_message("agent", ...)` returns a response | May not be GA. If unavailable, Demo 2 defaults to Replay mode — no impact to booth. |
| **Document AI** | Demo 3 (live upload) | `SELECT * FROM TABLE(SNOWFLAKE.DOCUMENT_AI.PROCESS(...))` | If not available, pre-extracted data (Script 06) covers the demo. Upload step becomes cosmetic. |
| **Streamlit in Snowflake** | All demos | Create a test Streamlit app in Snowsight | Enabled by default on Enterprise. Check: `SHOW STREAMLIT IN SCHEMA ...` |

---

### Step 4: Semantic Model Setup

The Cortex Analyst semantic model is a YAML file that defines what the AI can query. It must be staged before Demos 1 and 2 work.

```sql
-- Create the stage for semantic models
USE ROLE DEMO_AI_ROLE;
USE DATABASE DEMO_AI_SUMMIT;
USE SCHEMA CORTEX_ANALYST_DEMO;

CREATE OR REPLACE STAGE SEMANTIC_MODELS
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Semantic model YAML files for Cortex Analyst';
```

**Semantic model file:** `cortex_analyst_demo.yaml`

```yaml
# cortex_analyst_demo.yaml
# Semantic model for Innovation Summit demo
# Defines tables, joins, metrics, and business terms for Cortex Analyst

name: innovation_summit_sales
description: >
  Sales analytics model for Innovation Summit demo.
  Covers transactional sales, marketing campaigns, customer data,
  and support tickets across 4 regions and 6 product categories.

tables:
  - name: SALES_FACT
    description: Transactional sales data — one row per order
    base_table:
      database: DEMO_AI_SUMMIT
      schema: CORTEX_ANALYST_DEMO
      table: SALES_FACT
    dimensions:
      - name: order_id
        description: Unique order identifier
        expr: ORDER_ID
        data_type: NUMBER
      - name: order_date
        description: Date the order was placed
        expr: ORDER_DATE
        data_type: DATE
      - name: order_status
        description: "Order status: Completed or Cancelled"
        expr: ORDER_STATUS
        data_type: VARCHAR
      - name: is_returned
        description: Whether the order was returned (TRUE/FALSE)
        expr: IS_RETURNED
        data_type: BOOLEAN
    measures:
      - name: revenue
        description: Total revenue (sum of order amounts for completed, non-returned orders)
        expr: AMOUNT
        data_type: NUMBER
        default_aggregation: sum
      - name: order_count
        description: Number of orders
        expr: ORDER_ID
        data_type: NUMBER
        default_aggregation: count
      - name: avg_order_value
        description: Average order value
        expr: AMOUNT
        data_type: NUMBER
        default_aggregation: avg
      - name: discount_pct
        description: Discount percentage applied to the order (0-25%)
        expr: DISCOUNT_PCT
        data_type: NUMBER
        default_aggregation: avg
      - name: return_rate
        description: Percentage of orders returned
        expr: "CASE WHEN IS_RETURNED THEN 1.0 ELSE 0.0 END"
        data_type: NUMBER
        default_aggregation: avg

  - name: DIM_PRODUCT
    description: Product catalog — categories, subcategories, and cost
    base_table:
      database: DEMO_AI_SUMMIT
      schema: CORTEX_ANALYST_DEMO
      table: DIM_PRODUCT
    dimensions:
      - name: product_id
        description: Unique product identifier
        expr: PRODUCT_ID
        data_type: NUMBER
      - name: product_name
        description: Product display name
        expr: PRODUCT_NAME
        data_type: VARCHAR
      - name: category
        description: "Product category: Electronics, Apparel, Home & Kitchen, Sports, Office Supplies, Health & Beauty"
        expr: CATEGORY
        data_type: VARCHAR
      - name: subcategory
        description: "Product tier: Premium, Standard, Budget, Professional"
        expr: SUBCATEGORY
        data_type: VARCHAR
      - name: unit_cost
        description: Unit cost of the product
        expr: UNIT_COST
        data_type: NUMBER

  - name: DIM_REGION
    description: Geographic hierarchy — territory, region, country
    base_table:
      database: DEMO_AI_SUMMIT
      schema: CORTEX_ANALYST_DEMO
      table: DIM_REGION
    dimensions:
      - name: region_id
        description: Unique region identifier
        expr: REGION_ID
        data_type: NUMBER
      - name: region_name
        description: "Region: North America, EMEA, APAC, LATAM"
        expr: REGION_NAME
        data_type: VARCHAR
      - name: country
        description: Country name
        expr: COUNTRY
        data_type: VARCHAR
      - name: territory
        description: "Sales territory code: NA, EMEA, APAC, LATAM"
        expr: TERRITORY
        data_type: VARCHAR

  - name: DIM_DATE
    description: Date dimension — calendar and fiscal periods
    base_table:
      database: DEMO_AI_SUMMIT
      schema: CORTEX_ANALYST_DEMO
      table: DIM_DATE
    dimensions:
      - name: date_key
        description: Calendar date
        expr: DATE_KEY
        data_type: DATE
      - name: year
        description: Calendar year
        expr: YEAR
        data_type: NUMBER
      - name: quarter
        description: Calendar quarter (1-4)
        expr: QUARTER
        data_type: NUMBER
      - name: month
        description: Calendar month (1-12)
        expr: MONTH
        data_type: NUMBER
      - name: month_name
        description: Month name (Jan, Feb, etc.)
        expr: MONTH_NAME
        data_type: VARCHAR
      - name: fiscal_year
        description: "Fiscal year (e.g., FY2025)"
        expr: FISCAL_YEAR
        data_type: VARCHAR

  - name: DIM_SALES_REP
    description: Sales rep directory with team assignments
    base_table:
      database: DEMO_AI_SUMMIT
      schema: CORTEX_ANALYST_DEMO
      table: DIM_SALES_REP
    dimensions:
      - name: rep_id
        description: Unique rep identifier
        expr: REP_ID
        data_type: NUMBER
      - name: rep_name
        description: Sales rep name
        expr: REP_NAME
        data_type: VARCHAR
      - name: team
        description: "Sales team: Enterprise, Mid-Market, SMB, Strategic, Inside Sales"
        expr: TEAM
        data_type: VARCHAR

  - name: CAMPAIGN_FACT
    description: Marketing campaigns with spend, impressions, and conversions
    base_table:
      database: DEMO_AI_SUMMIT
      schema: CORTEX_ANALYST_DEMO
      table: CAMPAIGN_FACT
    dimensions:
      - name: campaign_id
        description: Unique campaign identifier
        expr: CAMPAIGN_ID
        data_type: NUMBER
      - name: channel
        description: "Marketing channel: Digital Ads, Email, Events, Content Marketing, Partner Co-Marketing"
        expr: CHANNEL
        data_type: VARCHAR
      - name: campaign_status
        description: "Campaign status: Active, Completed, Scheduled, Paused — Budget Freeze"
        expr: CAMPAIGN_STATUS
        data_type: VARCHAR
      - name: start_date
        description: Campaign start date
        expr: START_DATE
        data_type: DATE
    measures:
      - name: campaign_spend
        description: Total marketing spend
        expr: SPEND
        data_type: NUMBER
        default_aggregation: sum
      - name: impressions
        description: Total ad impressions
        expr: IMPRESSIONS
        data_type: NUMBER
        default_aggregation: sum
      - name: conversions
        description: Total conversions from campaign
        expr: CONVERSIONS
        data_type: NUMBER
        default_aggregation: sum

  - name: CUSTOMER_DIM
    description: Customer master with segmentation and churn status
    base_table:
      database: DEMO_AI_SUMMIT
      schema: CORTEX_ANALYST_DEMO
      table: CUSTOMER_DIM
    dimensions:
      - name: customer_id
        description: Unique customer identifier
        expr: CUSTOMER_ID
        data_type: NUMBER
      - name: segment
        description: "Customer segment: Enterprise, Mid-Market, SMB, Startup"
        expr: SEGMENT
        data_type: VARCHAR
      - name: churn_flag
        description: Whether the customer has churned (TRUE/FALSE)
        expr: CHURN_FLAG
        data_type: BOOLEAN
    measures:
      - name: lifetime_value
        description: Customer lifetime value in dollars
        expr: LIFETIME_VALUE
        data_type: NUMBER
        default_aggregation: sum
      - name: churn_rate
        description: Percentage of customers who churned
        expr: "CASE WHEN CHURN_FLAG THEN 1.0 ELSE 0.0 END"
        data_type: NUMBER
        default_aggregation: avg

joins:
  - name: sales_to_product
    left_table: SALES_FACT
    right_table: DIM_PRODUCT
    join_type: inner
    on:
      - left_column: PRODUCT_ID
        right_column: PRODUCT_ID

  - name: sales_to_region
    left_table: SALES_FACT
    right_table: DIM_REGION
    join_type: inner
    on:
      - left_column: REGION_ID
        right_column: REGION_ID

  - name: sales_to_date
    left_table: SALES_FACT
    right_table: DIM_DATE
    join_type: inner
    on:
      - left_column: ORDER_DATE
        right_column: DATE_KEY

  - name: sales_to_rep
    left_table: SALES_FACT
    right_table: DIM_SALES_REP
    join_type: inner
    on:
      - left_column: REP_ID
        right_column: REP_ID

  - name: sales_to_customer
    left_table: SALES_FACT
    right_table: CUSTOMER_DIM
    join_type: inner
    on:
      - left_column: CUSTOMER_ID
        right_column: CUSTOMER_ID

  - name: campaign_to_region
    left_table: CAMPAIGN_FACT
    right_table: DIM_REGION
    join_type: inner
    on:
      - left_column: REGION_ID
        right_column: REGION_ID

  - name: customer_to_region
    left_table: CUSTOMER_DIM
    right_table: DIM_REGION
    join_type: inner
    on:
      - left_column: REGION_ID
        right_column: REGION_ID

verified_queries:
  - name: total_sales_last_quarter
    question: "What were total sales last quarter?"
    verified_query: >
      SELECT SUM(sf.AMOUNT) AS total_sales
      FROM DEMO_AI_SUMMIT.CORTEX_ANALYST_DEMO.SALES_FACT sf
      JOIN DEMO_AI_SUMMIT.CORTEX_ANALYST_DEMO.DIM_DATE dd ON sf.ORDER_DATE = dd.DATE_KEY
      WHERE dd.YEAR = 2025 AND dd.QUARTER = 3
    verified_at: "2025-03-01"

  - name: return_rate_by_category
    question: "Which product category has the highest return rate?"
    verified_query: >
      SELECT p.CATEGORY,
             COUNT(*) AS total_orders,
             SUM(CASE WHEN sf.IS_RETURNED THEN 1 ELSE 0 END) AS returns,
             ROUND(returns / total_orders * 100, 1) AS return_rate_pct
      FROM DEMO_AI_SUMMIT.CORTEX_ANALYST_DEMO.SALES_FACT sf
      JOIN DEMO_AI_SUMMIT.CORTEX_ANALYST_DEMO.DIM_PRODUCT p ON sf.PRODUCT_ID = p.PRODUCT_ID
      GROUP BY p.CATEGORY
      ORDER BY return_rate_pct DESC
    verified_at: "2025-03-01"

  - name: marketing_vs_revenue_by_region
    question: "Compare marketing spend vs revenue by region for Q3 and Q4"
    verified_query: >
      SELECT r.TERRITORY,
             SUM(CASE WHEN dd.QUARTER = 3 THEN sf.AMOUNT END) AS q3_revenue,
             SUM(CASE WHEN dd.QUARTER = 4 THEN sf.AMOUNT END) AS q4_revenue,
             SUM(CASE WHEN cf.START_DATE BETWEEN '2025-07-01' AND '2025-09-30' THEN cf.SPEND END) AS q3_spend,
             SUM(CASE WHEN cf.START_DATE BETWEEN '2025-10-01' AND '2025-12-31' THEN cf.SPEND END) AS q4_spend
      FROM DEMO_AI_SUMMIT.CORTEX_ANALYST_DEMO.SALES_FACT sf
      JOIN DEMO_AI_SUMMIT.CORTEX_ANALYST_DEMO.DIM_DATE dd ON sf.ORDER_DATE = dd.DATE_KEY
      JOIN DEMO_AI_SUMMIT.CORTEX_ANALYST_DEMO.DIM_REGION r ON sf.REGION_ID = r.REGION_ID
      LEFT JOIN DEMO_AI_SUMMIT.CORTEX_ANALYST_DEMO.CAMPAIGN_FACT cf ON r.REGION_ID = cf.REGION_ID
      WHERE dd.YEAR = 2025
      GROUP BY r.TERRITORY
    verified_at: "2025-03-01"

  - name: top_reps_above_50k
    question: "Which sales rep closed the most deals above $50K in the last 6 months?"
    verified_query: >
      SELECT sr.REP_NAME, sr.TEAM,
             COUNT(*) AS deals_above_50k,
             ROUND(SUM(sf.AMOUNT), 0) AS total_value
      FROM DEMO_AI_SUMMIT.CORTEX_ANALYST_DEMO.SALES_FACT sf
      JOIN DEMO_AI_SUMMIT.CORTEX_ANALYST_DEMO.DIM_SALES_REP sr ON sf.REP_ID = sr.REP_ID
      WHERE sf.AMOUNT > 50000
        AND sf.ORDER_DATE >= DATEADD(MONTH, -6, CURRENT_DATE())
      GROUP BY sr.REP_NAME, sr.TEAM
      ORDER BY deals_above_50k DESC
      LIMIT 10
    verified_at: "2025-03-01"

  - name: discount_vs_churn
    question: "What's the correlation between discount percentage and customer churn?"
    verified_query: >
      SELECT CASE WHEN sf.DISCOUNT_PCT < 5 THEN '0-5%'
                  WHEN sf.DISCOUNT_PCT < 10 THEN '5-10%'
                  WHEN sf.DISCOUNT_PCT < 15 THEN '10-15%'
                  WHEN sf.DISCOUNT_PCT < 20 THEN '15-20%'
                  ELSE '20%+' END AS discount_band,
             COUNT(DISTINCT sf.CUSTOMER_ID) AS total_customers,
             SUM(CASE WHEN c.CHURN_FLAG THEN 1 ELSE 0 END) AS churned,
             ROUND(churned / total_customers * 100, 1) AS churn_rate_pct
      FROM DEMO_AI_SUMMIT.CORTEX_ANALYST_DEMO.SALES_FACT sf
      JOIN DEMO_AI_SUMMIT.CORTEX_ANALYST_DEMO.CUSTOMER_DIM c ON sf.CUSTOMER_ID = c.CUSTOMER_ID
      GROUP BY discount_band
      ORDER BY discount_band
    verified_at: "2025-03-01"
```

**Stage the YAML file:**

```sql
-- Option 1: Upload via Snowsight (UI)
-- Go to: Data → Databases → DEMO_AI_SUMMIT → CORTEX_ANALYST_DEMO → Stages
-- Select SEMANTIC_MODELS stage → Upload → select cortex_analyst_demo.yaml

-- Option 2: Upload via SnowSQL (CLI)
-- PUT file://path/to/cortex_analyst_demo.yaml
--     @DEMO_AI_SUMMIT.CORTEX_ANALYST_DEMO.SEMANTIC_MODELS
--     AUTO_COMPRESS=FALSE OVERWRITE=TRUE;

-- Verify upload
LIST @DEMO_AI_SUMMIT.CORTEX_ANALYST_DEMO.SEMANTIC_MODELS;
-- Expected: cortex_analyst_demo.yaml
```

---

### Step 5: End-to-End Verification

Run this verification script after all infrastructure, data, and services are in place. Every check must pass before moving to Streamlit app deployment.

```sql
USE ROLE DEMO_AI_ROLE;
USE WAREHOUSE DEMO_AI_WH;
USE DATABASE DEMO_AI_SUMMIT;

-- ═══════════════════════════════════════════════
-- CHECK 1: Database objects exist
-- ═══════════════════════════════════════════════
SELECT 'SCHEMAS' AS check_type, SCHEMA_NAME
FROM INFORMATION_SCHEMA.SCHEMATA
WHERE CATALOG_NAME = 'DEMO_AI_SUMMIT'
ORDER BY SCHEMA_NAME;
-- Expected: CORTEX_ANALYST_DEMO, DOC_AI_DEMO, STAGING (+ INFORMATION_SCHEMA, PUBLIC)

-- ═══════════════════════════════════════════════
-- CHECK 2: All tables exist with expected row counts
-- ═══════════════════════════════════════════════
SELECT table_schema, table_name, row_count
FROM INFORMATION_SCHEMA.TABLES
WHERE table_catalog = 'DEMO_AI_SUMMIT'
    AND table_schema IN ('CORTEX_ANALYST_DEMO', 'DOC_AI_DEMO')
    AND table_type = 'BASE TABLE'
ORDER BY table_schema, table_name;
-- Expected: 12 tables with row counts matching Section 4 summary

-- ═══════════════════════════════════════════════
-- CHECK 3: Semantic model staged
-- ═══════════════════════════════════════════════
LIST @CORTEX_ANALYST_DEMO.SEMANTIC_MODELS;
-- Expected: cortex_analyst_demo.yaml

-- ═══════════════════════════════════════════════
-- CHECK 4: Cortex Search service healthy
-- ═══════════════════════════════════════════════
SHOW CORTEX SEARCH SERVICES IN SCHEMA DOC_AI_DEMO;
-- Expected: DOCUMENTS_SEARCH_SERVICE with status ACTIVE

-- ═══════════════════════════════════════════════
-- CHECK 5: Cortex LLM functions work
-- ═══════════════════════════════════════════════
SELECT SNOWFLAKE.CORTEX.COMPLETE('llama3.1-8b', 'Say hello in one sentence.');
-- Expected: A text response

SELECT SNOWFLAKE.CORTEX.SENTIMENT('This product is excellent and exceeded expectations.');
-- Expected: Positive score (close to 1.0)

SELECT SNOWFLAKE.CORTEX.SUMMARIZE('Snowflake Cortex enables AI-powered analytics directly within the Snowflake Data Cloud, providing built-in LLM functions, semantic search, and agent frameworks without requiring data to leave the platform.');
-- Expected: A short summary

-- ═══════════════════════════════════════════════
-- CHECK 6: Planted patterns hold
-- ═══════════════════════════════════════════════
-- Q3 vs Q2 revenue by territory
SELECT r.territory,
    SUM(CASE WHEN d.quarter = 2 AND d.year = 2025 THEN s.amount END) AS q2,
    SUM(CASE WHEN d.quarter = 3 AND d.year = 2025 THEN s.amount END) AS q3,
    ROUND((q3 - q2) / q2 * 100, 1) AS pct_change
FROM CORTEX_ANALYST_DEMO.SALES_FACT s
JOIN CORTEX_ANALYST_DEMO.DIM_REGION r ON s.region_id = r.region_id
JOIN CORTEX_ANALYST_DEMO.DIM_DATE d ON s.order_date = d.date_key
WHERE d.year = 2025 AND d.quarter IN (2, 3)
GROUP BY r.territory ORDER BY pct_change;
-- Expected: EMEA ~ -17%, LATAM ~ -8%, APAC ~ +6%

-- Electronics return rate
SELECT p.category,
    ROUND(SUM(CASE WHEN s.is_returned THEN 1 ELSE 0 END)::FLOAT
          / COUNT(*) * 100, 1) AS return_rate
FROM CORTEX_ANALYST_DEMO.SALES_FACT s
JOIN CORTEX_ANALYST_DEMO.DIM_PRODUCT p ON s.product_id = p.product_id
GROUP BY p.category ORDER BY return_rate DESC LIMIT 1;
-- Expected: Electronics ~ 14.2%

-- ═══════════════════════════════════════════════
-- CHECK 7: Document text searchable
-- ═══════════════════════════════════════════════
SELECT COUNT(*) AS chunk_count FROM DOC_AI_DEMO.DOCUMENTS_TEXT;
-- Expected: 11

SELECT chunk_text FROM DOC_AI_DEMO.DOCUMENTS_TEXT
WHERE section_header LIKE '%Termination%';
-- Expected: Section 8.2 text about 90-day notice
```

**All 7 checks pass → environment is ready for Streamlit deployment (Section 8).**

---

### Environment Teardown (Post-Event)

Run after the event to clean up demo resources and stop incurring cost:

```sql
-- Suspend warehouse immediately
ALTER WAREHOUSE DEMO_AI_WH SUSPEND;

-- Option A: Keep data for future demos (recommended)
-- Just suspend the warehouse; data storage cost is minimal.

-- Option B: Full teardown
-- DROP DATABASE DEMO_AI_SUMMIT;    -- All data, stages, search services gone
-- DROP WAREHOUSE DEMO_AI_WH;
-- DROP ROLE DEMO_AI_ROLE;          -- Run as SECURITYADMIN
```

---

## 4. Synthetic Data Model

### Concept

Every Tier 1 demo depends on data that **tells a story**. Random data produces random answers — and random answers kill a demo. The synthetic data model is engineered to guarantee that specific questions produce specific, impressive results every time a visitor asks them.

**Design principles:**
1. **Story-first, schema-second.** We decide what the demo answer should be, then reverse-engineer the data to produce it.
2. **Realistic distributions, planted anomalies.** Base data follows realistic patterns (seasonality, Zipf distributions for products). Key demo moments are planted: Q3 revenue drop, EMEA churn spike, paused campaigns.
3. **Deterministic.** Every script uses `UNIFORM()` with fixed seeds or explicit value lists. No surprises on event day.
4. **Minimal but complete.** Enough rows to feel real (500K sales facts), few enough to load in minutes.

### Architecture

```
Database: DEMO_AI_SUMMIT
├── Schema: CORTEX_ANALYST_DEMO        ← Demos 1 & 2 (shared)
│   ├── DIM_DATE
│   ├── DIM_REGION
│   ├── DIM_PRODUCT
│   ├── DIM_SALES_REP
│   ├── CUSTOMER_DIM
│   ├── SALES_FACT
│   ├── CAMPAIGN_FACT
│   ├── SUPPORT_TICKETS               ← Demo 2 (Agent)
│   └── CHURN_SIGNALS                  ← Demo 2 (Agent)
│
├── Schema: DOC_AI_DEMO                ← Demo 3 (Document AI)
│   ├── DOCUMENTS_STAGE (internal)
│   ├── DOCUMENTS_RAW
│   ├── DOCUMENTS_EXTRACTED
│   └── DOCUMENTS_TEXT
│
└── Schema: STAGING                    ← Shared utilities
    └── (sequences, file formats, helper procs)
```

### Planted Stories (What the Data Must Prove)

These are the demo moments. Every table and every row exists to make these answers come out clean.

| Demo | Question | Expected Answer | Tables Involved |
|------|----------|----------------|-----------------|
| 1 | "Which regions underperformed last quarter?" | EMEA -12%, LATAM -8%, APAC +6% vs target | SALES_FACT, DIM_REGION |
| 1 | "Which product category has the highest return rate?" | Electronics at 14.2% (vs 3-5% for others) | SALES_FACT, DIM_PRODUCT |
| 1 | "Compare marketing spend vs revenue by region for Q3 and Q4" | EMEA spend dropped 40% in Q3 (campaign pause), revenue followed | SALES_FACT, CAMPAIGN_FACT, DIM_REGION |
| 2 | "Why did Q3 revenue drop vs Q2?" | $2.4M drop driven by EMEA campaign pause + enterprise churn spike | SALES_FACT, CAMPAIGN_FACT, CUSTOMER_DIM, CHURN_SIGNALS |
| 2 | Agent Step 4: Churn check | EMEA enterprise churn 3.2% → 7.1%, 4 named accounts | CUSTOMER_DIM, CHURN_SIGNALS |
| 3 | "What's the termination clause?" | Section 8.2, 90-day written notice | DOCUMENTS_TEXT |
| 3 | "Are there any liability caps?" | Section 10.1, $5M aggregate cap | DOCUMENTS_TEXT |

---

### SQL Generation Scripts

> **Run order:** Execute scripts 1-7 in sequence. Each script is idempotent (`CREATE OR REPLACE`).
> **File extraction:** The SQL below is embedded in this document. Before execution, copy each script block into a separate `.sql` file (`01_infrastructure.sql` through `07_cortex_search.sql`) in a `sql_scripts/` directory. This makes re-runs, version control, and team handoff cleaner.
> **Estimated load time:** < 5 minutes on a Medium warehouse.

---

#### Script 1: Database, Schemas, and Warehouse

```sql
/*
==================================================================
  DEMO AI SUMMIT — INFRASTRUCTURE SETUP
  Script: 01_infrastructure.sql
  Purpose: Create database, schemas, warehouse, and role
  Run: Once (idempotent)
==================================================================
*/

USE ROLE SYSADMIN;

-- Database
CREATE DATABASE IF NOT EXISTS DEMO_AI_SUMMIT
    COMMENT = 'Innovation Summit AI Demo — synthetic data and Cortex services';

-- Schemas
CREATE SCHEMA IF NOT EXISTS DEMO_AI_SUMMIT.CORTEX_ANALYST_DEMO
    COMMENT = 'Shared schema for Cortex Analyst (Demo 1) and Data Agent (Demo 2)';

CREATE SCHEMA IF NOT EXISTS DEMO_AI_SUMMIT.DOC_AI_DEMO
    COMMENT = 'Document AI + Cortex Search (Demo 3)';

CREATE SCHEMA IF NOT EXISTS DEMO_AI_SUMMIT.STAGING
    COMMENT = 'Shared utilities: sequences, file formats, helper procedures';

-- Warehouse
CREATE WAREHOUSE IF NOT EXISTS DEMO_AI_WH
    WAREHOUSE_SIZE = 'MEDIUM'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Demo warehouse — auto-suspend after 60s idle';

-- Role and grants
USE ROLE SECURITYADMIN;

CREATE ROLE IF NOT EXISTS DEMO_AI_ROLE
    COMMENT = 'Role for all demo operations';

GRANT USAGE ON DATABASE DEMO_AI_SUMMIT TO ROLE DEMO_AI_ROLE;
GRANT USAGE ON ALL SCHEMAS IN DATABASE DEMO_AI_SUMMIT TO ROLE DEMO_AI_ROLE;
GRANT ALL PRIVILEGES ON ALL SCHEMAS IN DATABASE DEMO_AI_SUMMIT TO ROLE DEMO_AI_ROLE;
GRANT USAGE ON WAREHOUSE DEMO_AI_WH TO ROLE DEMO_AI_ROLE;
GRANT OPERATE ON WAREHOUSE DEMO_AI_WH TO ROLE DEMO_AI_ROLE;

-- Grant role to your user (replace with your username)
-- GRANT ROLE DEMO_AI_ROLE TO USER <YOUR_USERNAME>;

USE ROLE DEMO_AI_ROLE;
USE WAREHOUSE DEMO_AI_WH;
USE DATABASE DEMO_AI_SUMMIT;
```

---

#### Script 2: Dimension Tables

```sql
/*
==================================================================
  DEMO AI SUMMIT — DIMENSION TABLES
  Script: 02_dimensions.sql
  Purpose: Create and populate all dimension tables
  Dependencies: 01_infrastructure.sql
==================================================================
*/

USE DATABASE DEMO_AI_SUMMIT;
USE SCHEMA CORTEX_ANALYST_DEMO;

-- ─────────────────────────────────────────────
-- DIM_DATE: 3-year date dimension (2023-2025)
-- ─────────────────────────────────────────────
CREATE OR REPLACE TABLE DIM_DATE AS
SELECT
    d.date_key::DATE                                       AS date_key,
    YEAR(d.date_key)                                       AS year,
    QUARTER(d.date_key)                                    AS quarter,
    MONTH(d.date_key)                                      AS month,
    MONTHNAME(d.date_key)                                  AS month_name,
    DAY(d.date_key)                                        AS day,
    DAYOFWEEK(d.date_key)                                  AS day_of_week,
    DAYNAME(d.date_key)                                    AS day_name,
    WEEKOFYEAR(d.date_key)                                 AS week_of_year,
    'FY' || CASE WHEN MONTH(d.date_key) >= 2
                 THEN YEAR(d.date_key) + 1
                 ELSE YEAR(d.date_key) END                 AS fiscal_year,
    CEIL(MONTH(d.date_key) / 3.0)                          AS fiscal_quarter
FROM (
    SELECT DATEADD(DAY, seq4(), '2023-01-01'::DATE) AS date_key
    FROM TABLE(GENERATOR(ROWCOUNT => 1096))  -- 3 years
) d;

-- ─────────────────────────────────────────────
-- DIM_REGION: 5 territories, 12 countries
-- Planted: EMEA and LATAM will underperform
-- ─────────────────────────────────────────────
CREATE OR REPLACE TABLE DIM_REGION AS
SELECT * FROM VALUES
    (1,  'North America', 'United States', 'NA'),
    (2,  'North America', 'Canada',        'NA'),
    (3,  'EMEA',          'United Kingdom', 'EMEA'),
    (4,  'EMEA',          'Germany',        'EMEA'),
    (5,  'EMEA',          'France',         'EMEA'),
    (6,  'EMEA',          'Netherlands',    'EMEA'),
    (7,  'APAC',          'Australia',      'APAC'),
    (8,  'APAC',          'Japan',          'APAC'),
    (9,  'APAC',          'Singapore',      'APAC'),
    (10, 'LATAM',         'Brazil',         'LATAM'),
    (11, 'LATAM',         'Mexico',         'LATAM'),
    (12, 'LATAM',         'Colombia',       'LATAM')
    AS t(region_id, region_name, country, territory);

-- ─────────────────────────────────────────────
-- DIM_PRODUCT: 2K products, 6 categories
-- Planted: Electronics has high return rate
-- ─────────────────────────────────────────────
CREATE OR REPLACE TABLE DIM_PRODUCT AS
WITH categories AS (
    SELECT * FROM VALUES
        ('Electronics',    150.00, 500.00, 0.142),  -- planted: 14.2% return rate
        ('Apparel',         25.00, 120.00, 0.045),
        ('Home & Kitchen',  30.00, 200.00, 0.035),
        ('Sports',          20.00, 300.00, 0.028),
        ('Office Supplies', 5.00,   80.00, 0.031),
        ('Health & Beauty', 10.00, 150.00, 0.038)
        AS t(category, min_cost, max_cost, return_rate)
),
product_gen AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY seq4()) AS product_id,
        'PRD-' || LPAD(ROW_NUMBER() OVER (ORDER BY seq4()), 5, '0') AS product_code,
        seq4() AS rn
    FROM TABLE(GENERATOR(ROWCOUNT => 2000))
)
SELECT
    p.product_id,
    p.product_code,
    c.category,
    c.category || ' Item ' || p.product_id AS product_name,
    CASE MOD(p.product_id, 4)
        WHEN 0 THEN 'Premium'
        WHEN 1 THEN 'Standard'
        WHEN 2 THEN 'Budget'
        ELSE 'Professional'
    END AS subcategory,
    ROUND(UNIFORM(c.min_cost, c.max_cost, RANDOM(42 + p.product_id)), 2) AS unit_cost,
    c.return_rate AS base_return_rate
FROM product_gen p
JOIN categories c
    ON MOD(p.product_id, 6) = CASE c.category
        WHEN 'Electronics'    THEN 0
        WHEN 'Apparel'        THEN 1
        WHEN 'Home & Kitchen' THEN 2
        WHEN 'Sports'         THEN 3
        WHEN 'Office Supplies'THEN 4
        WHEN 'Health & Beauty'THEN 5
    END;

-- ─────────────────────────────────────────────
-- DIM_SALES_REP: 200 reps across regions
-- ─────────────────────────────────────────────
CREATE OR REPLACE TABLE DIM_SALES_REP AS
WITH rep_names AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY seq4()) AS rep_id,
        seq4() AS rn
    FROM TABLE(GENERATOR(ROWCOUNT => 200))
)
SELECT
    r.rep_id,
    'Rep-' || LPAD(r.rep_id, 3, '0') AS rep_name,
    CASE MOD(r.rep_id, 5)
        WHEN 0 THEN 'Enterprise'
        WHEN 1 THEN 'Mid-Market'
        WHEN 2 THEN 'SMB'
        WHEN 3 THEN 'Strategic'
        ELSE 'Inside Sales'
    END AS team,
    -- Distribute across regions
    MOD(r.rep_id, 12) + 1 AS primary_region_id,
    DATEADD(DAY, -UNIFORM(180, 1800, RANDOM(100 + r.rep_id)), CURRENT_DATE()) AS hire_date
FROM rep_names r;

-- ─────────────────────────────────────────────
-- CUSTOMER_DIM: 50K customers
-- Planted: EMEA enterprise churn spike in Q3
-- ─────────────────────────────────────────────
CREATE OR REPLACE TABLE CUSTOMER_DIM AS
WITH customer_gen AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY seq4()) AS customer_id,
        seq4() AS rn
    FROM TABLE(GENERATOR(ROWCOUNT => 50000))
)
SELECT
    c.customer_id,
    'CUST-' || LPAD(c.customer_id, 6, '0') AS customer_code,
    CASE MOD(c.customer_id, 4)
        WHEN 0 THEN 'Enterprise'
        WHEN 1 THEN 'Mid-Market'
        WHEN 2 THEN 'SMB'
        ELSE 'Startup'
    END AS segment,
    -- Assign to a region
    MOD(c.customer_id, 12) + 1 AS region_id,
    ROUND(UNIFORM(1000, 500000, RANDOM(200 + c.customer_id)), 2) AS lifetime_value,
    DATEADD(DAY, -UNIFORM(90, 1095, RANDOM(300 + c.customer_id)), CURRENT_DATE()) AS first_order_date,
    -- Planted churn: EMEA enterprise customers have higher churn
    CASE
        WHEN MOD(c.customer_id, 12) + 1 IN (3,4,5,6)          -- EMEA region
             AND MOD(c.customer_id, 4) = 0                      -- Enterprise segment
             AND UNIFORM(0, 100, RANDOM(400 + c.customer_id)) < 15  -- 15% churn rate
        THEN TRUE
        WHEN UNIFORM(0, 100, RANDOM(500 + c.customer_id)) < 4  -- 4% baseline churn
        THEN TRUE
        ELSE FALSE
    END AS churn_flag,
    CASE
        WHEN MOD(c.customer_id, 12) + 1 IN (3,4,5,6)
             AND MOD(c.customer_id, 4) = 0
             AND UNIFORM(0, 100, RANDOM(400 + c.customer_id)) < 15
        THEN DATEADD(DAY, -UNIFORM(30, 180, RANDOM(600 + c.customer_id)), CURRENT_DATE())
        ELSE NULL
    END AS churn_date
FROM customer_gen c;

-- ─────────────────────────────────────────────
-- VERIFICATION: Dimension row counts
-- ─────────────────────────────────────────────
SELECT 'DIM_DATE' AS table_name, COUNT(*) AS row_count FROM DIM_DATE
UNION ALL SELECT 'DIM_REGION', COUNT(*) FROM DIM_REGION
UNION ALL SELECT 'DIM_PRODUCT', COUNT(*) FROM DIM_PRODUCT
UNION ALL SELECT 'DIM_SALES_REP', COUNT(*) FROM DIM_SALES_REP
UNION ALL SELECT 'CUSTOMER_DIM', COUNT(*) FROM CUSTOMER_DIM
ORDER BY table_name;
```

**Pitfall:** `UNIFORM()` with `RANDOM()` is not truly deterministic across Snowflake versions. If exact reproducibility matters, use explicit value lists for critical planted data (the EMEA churn accounts, the paused campaigns) and only use `UNIFORM()` for background noise.

---

#### Script 3: Sales Fact Table (500K rows)

```sql
/*
==================================================================
  DEMO AI SUMMIT — SALES FACT
  Script: 03_sales_fact.sql
  Purpose: 500K transactional rows with planted patterns
  Dependencies: 02_dimensions.sql

  PLANTED PATTERNS:
  - Q3 2025 EMEA revenue drops 17% vs Q2 (campaign pause + churn)
  - Q3 2025 NA has mild seasonal dip (5%, normal range)
  - Q3 2025 APAC exceeds target by 6%
  - Electronics return rate: ~14.2%
  - Clear top-performing reps for "above $50K" query
==================================================================
*/

USE SCHEMA CORTEX_ANALYST_DEMO;

CREATE OR REPLACE TABLE SALES_FACT AS
WITH date_spine AS (
    SELECT date_key
    FROM DIM_DATE
    WHERE date_key BETWEEN '2024-01-01' AND '2025-12-31'
),
-- Generate base transactions
base_txn AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY d.date_key, seq4()) AS order_id,
        d.date_key AS order_date,
        -- Region distribution with EMEA getting 30% of volume
        CASE
            WHEN UNIFORM(1, 100, RANDOM(1000 + seq4())) <= 25 THEN
                UNIFORM(1, 2, RANDOM(2000 + seq4()))    -- NA (25%)
            WHEN UNIFORM(1, 100, RANDOM(1000 + seq4())) <= 55 THEN
                UNIFORM(3, 6, RANDOM(3000 + seq4()))    -- EMEA (30%)
            WHEN UNIFORM(1, 100, RANDOM(1000 + seq4())) <= 80 THEN
                UNIFORM(7, 9, RANDOM(4000 + seq4()))    -- APAC (25%)
            ELSE
                UNIFORM(10, 12, RANDOM(5000 + seq4()))  -- LATAM (20%)
        END AS region_id,
        UNIFORM(1, 2000, RANDOM(6000 + seq4())) AS product_id,
        UNIFORM(1, 200, RANDOM(7000 + seq4())) AS rep_id,
        UNIFORM(1, 50000, RANDOM(8000 + seq4())) AS customer_id,
        seq4() AS row_seed
    FROM date_spine d,
         TABLE(GENERATOR(ROWCOUNT => 700)) g  -- ~700 orders/day × 730 days
)
SELECT
    b.order_id,
    b.order_date,
    b.region_id,
    b.product_id,
    b.rep_id,
    b.customer_id,
    -- Quantity: 1-20 units
    UNIFORM(1, 20, RANDOM(9000 + b.order_id)) AS quantity,
    -- Base amount with regional/seasonal multipliers
    ROUND(
        UNIFORM(50, 5000, RANDOM(10000 + b.order_id))
        -- PLANTED: EMEA Q3 2025 revenue depression
        * CASE
            WHEN b.region_id IN (3,4,5,6)
                 AND b.order_date BETWEEN '2025-07-01' AND '2025-09-30'
            THEN 0.62  -- 38% reduction in EMEA Q3 → drives the -17% aggregated drop
            -- PLANTED: NA mild seasonal dip in Q3
            WHEN b.region_id IN (1,2)
                 AND b.order_date BETWEEN '2025-07-01' AND '2025-09-30'
            THEN 0.92  -- 8% reduction
            -- PLANTED: APAC outperformance in Q3
            WHEN b.region_id IN (7,8,9)
                 AND b.order_date BETWEEN '2025-07-01' AND '2025-09-30'
            THEN 1.12  -- 12% boost
            -- PLANTED: LATAM mild underperformance
            WHEN b.region_id IN (10,11,12)
                 AND b.order_date BETWEEN '2025-07-01' AND '2025-09-30'
            THEN 0.88
            ELSE 1.0
          END
    , 2) AS amount,
    -- Discount: 0-25%, with planted high-discount deals for correlation query
    ROUND(
        CASE
            WHEN UNIFORM(1, 100, RANDOM(11000 + b.order_id)) <= 15
            THEN UNIFORM(15, 25, RANDOM(12000 + b.order_id))  -- 15% of deals get heavy discount
            ELSE UNIFORM(0, 12, RANDOM(13000 + b.order_id))   -- Normal range
        END
    , 1) AS discount_pct,
    -- Return flag: electronics ~14.2%, others 3-5%
    CASE
        WHEN MOD(b.product_id, 6) = 0  -- Electronics category
             AND UNIFORM(1, 1000, RANDOM(14000 + b.order_id)) <= 142
        THEN TRUE
        WHEN UNIFORM(1, 1000, RANDOM(15000 + b.order_id)) <= 40
        THEN TRUE
        ELSE FALSE
    END AS is_returned,
    b.order_date AS ship_date,
    CASE WHEN UNIFORM(1, 100, RANDOM(16000 + b.order_id)) <= 95
         THEN 'Completed' ELSE 'Cancelled' END AS order_status
FROM base_txn b
LIMIT 500000;

-- ─────────────────────────────────────────────
-- VERIFICATION: Confirm planted patterns
-- ─────────────────────────────────────────────

-- Check 1: Q2 vs Q3 2025 revenue by region (expect EMEA -17%)
SELECT
    r.territory,
    SUM(CASE WHEN d.quarter = 2 AND d.year = 2025 THEN s.amount END) AS q2_revenue,
    SUM(CASE WHEN d.quarter = 3 AND d.year = 2025 THEN s.amount END) AS q3_revenue,
    ROUND((q3_revenue - q2_revenue) / q2_revenue * 100, 1) AS pct_change
FROM SALES_FACT s
JOIN DIM_REGION r ON s.region_id = r.region_id
JOIN DIM_DATE d ON s.order_date = d.date_key
WHERE d.year = 2025 AND d.quarter IN (2, 3)
GROUP BY r.territory
ORDER BY pct_change;

-- Check 2: Return rate by category (expect Electronics ~14%)
SELECT
    p.category,
    COUNT(*) AS total_orders,
    SUM(CASE WHEN s.is_returned THEN 1 ELSE 0 END) AS returns,
    ROUND(returns / total_orders * 100, 1) AS return_rate_pct
FROM SALES_FACT s
JOIN DIM_PRODUCT p ON s.product_id = p.product_id
GROUP BY p.category
ORDER BY return_rate_pct DESC;

-- Check 3: Top reps by deals above $50K (for visitor challenge card #4)
SELECT
    sr.rep_name,
    sr.team,
    COUNT(*) AS deals_above_50k,
    ROUND(SUM(s.amount), 0) AS total_value
FROM SALES_FACT s
JOIN DIM_SALES_REP sr ON s.rep_id = sr.rep_id
WHERE s.amount > 50000
    AND s.order_date >= DATEADD(MONTH, -6, CURRENT_DATE())
GROUP BY sr.rep_name, sr.team
ORDER BY deals_above_50k DESC
LIMIT 10;
```

**Pitfall:** The amount multipliers (0.62, 0.92, 1.12) are calibrated against the base `UNIFORM(50, 5000)` range. If you change the base range, re-run verification queries to confirm the planted patterns still produce the expected percentages. Always verify before the event.

---

#### Script 4: Campaign Fact Table

```sql
/*
==================================================================
  DEMO AI SUMMIT — CAMPAIGN FACT
  Script: 04_campaign_fact.sql
  Purpose: 5K marketing campaigns with planted EMEA pause
  Dependencies: 02_dimensions.sql

  PLANTED PATTERN:
  - Two major EMEA campaigns paused in Jul-Aug 2025
  - EMEA Q3 spend drops ~40% vs Q2
  - Other regions maintain steady spend
==================================================================
*/

USE SCHEMA CORTEX_ANALYST_DEMO;

CREATE OR REPLACE TABLE CAMPAIGN_FACT AS
WITH campaign_gen AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY seq4()) AS campaign_id,
        seq4() AS rn
    FROM TABLE(GENERATOR(ROWCOUNT => 5000))
)
SELECT
    c.campaign_id,
    'CMP-' || LPAD(c.campaign_id, 5, '0') AS campaign_code,
    -- Distribute across regions
    MOD(c.campaign_id, 12) + 1 AS region_id,
    CASE MOD(c.campaign_id, 5)
        WHEN 0 THEN 'Digital Ads'
        WHEN 1 THEN 'Email'
        WHEN 2 THEN 'Events'
        WHEN 3 THEN 'Content Marketing'
        ELSE 'Partner Co-Marketing'
    END AS channel,
    -- Campaign start date: spread across 2024-2025
    DATEADD(DAY,
        UNIFORM(0, 730, RANDOM(20000 + c.campaign_id)),
        '2024-01-01'::DATE
    ) AS start_date,
    -- Duration: 14-90 days
    DATEADD(DAY,
        UNIFORM(14, 90, RANDOM(21000 + c.campaign_id)),
        start_date
    ) AS end_date,
    -- Spend
    ROUND(
        UNIFORM(5000, 150000, RANDOM(22000 + c.campaign_id))
        -- PLANTED: EMEA campaigns in Jul-Aug 2025 have near-zero spend (paused)
        * CASE
            WHEN MOD(c.campaign_id, 12) + 1 IN (3,4,5,6)  -- EMEA
                 AND DATEADD(DAY, UNIFORM(0, 730, RANDOM(20000 + c.campaign_id)), '2024-01-01'::DATE)
                     BETWEEN '2025-07-01' AND '2025-08-31'
            THEN 0.05  -- 95% reduction = effectively paused
            ELSE 1.0
          END
    , 2) AS spend,
    -- Status
    CASE
        WHEN MOD(c.campaign_id, 12) + 1 IN (3,4,5,6)
             AND DATEADD(DAY, UNIFORM(0, 730, RANDOM(20000 + c.campaign_id)), '2024-01-01'::DATE)
                 BETWEEN '2025-07-01' AND '2025-08-31'
        THEN 'Paused — Budget Freeze'
        WHEN end_date < CURRENT_DATE() THEN 'Completed'
        WHEN start_date > CURRENT_DATE() THEN 'Scheduled'
        ELSE 'Active'
    END AS campaign_status,
    UNIFORM(100, 50000, RANDOM(23000 + c.campaign_id)) AS impressions,
    UNIFORM(10, 5000, RANDOM(24000 + c.campaign_id)) AS clicks,
    UNIFORM(1, 500, RANDOM(25000 + c.campaign_id)) AS conversions
FROM campaign_gen c;

-- ─────────────────────────────────────────────
-- VERIFICATION: EMEA campaign spend drop in Q3
-- ─────────────────────────────────────────────
SELECT
    r.territory,
    SUM(CASE WHEN cf.start_date BETWEEN '2025-04-01' AND '2025-06-30' THEN cf.spend END) AS q2_spend,
    SUM(CASE WHEN cf.start_date BETWEEN '2025-07-01' AND '2025-09-30' THEN cf.spend END) AS q3_spend,
    ROUND((q3_spend - q2_spend) / NULLIF(q2_spend, 0) * 100, 1) AS pct_change
FROM CAMPAIGN_FACT cf
JOIN DIM_REGION r ON cf.region_id = r.region_id
WHERE cf.start_date BETWEEN '2025-04-01' AND '2025-09-30'
GROUP BY r.territory
ORDER BY pct_change;
```

---

#### Script 5: Support Tickets and Churn Signals (Agent Demo)

```sql
/*
==================================================================
  DEMO AI SUMMIT — SUPPORT TICKETS + CHURN SIGNALS
  Script: 05_agent_tables.sql
  Purpose: Agent investigation data (Demo 2)
  Dependencies: 02_dimensions.sql

  PLANTED PATTERNS:
  - EMEA enterprise support tickets spike in Q3 2025
  - Churn signals cluster around EMEA enterprise accounts
  - 4 specific named enterprise accounts churned in Q3
==================================================================
*/

USE SCHEMA CORTEX_ANALYST_DEMO;

-- ─────────────────────────────────────────────
-- SUPPORT_TICKETS: 20K tickets
-- ─────────────────────────────────────────────
CREATE OR REPLACE TABLE SUPPORT_TICKETS AS
WITH ticket_gen AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY seq4()) AS ticket_id,
        seq4() AS rn
    FROM TABLE(GENERATOR(ROWCOUNT => 20000))
)
SELECT
    t.ticket_id,
    'TKT-' || LPAD(t.ticket_id, 6, '0') AS ticket_code,
    UNIFORM(1, 50000, RANDOM(30000 + t.ticket_id)) AS customer_id,
    CASE MOD(t.ticket_id, 6)
        WHEN 0 THEN 'Billing'
        WHEN 1 THEN 'Technical'
        WHEN 2 THEN 'Onboarding'
        WHEN 3 THEN 'Feature Request'
        WHEN 4 THEN 'Account Management'
        ELSE 'Service Disruption'
    END AS category,
    CASE MOD(t.ticket_id, 4)
        WHEN 0 THEN 'Critical'
        WHEN 1 THEN 'High'
        WHEN 2 THEN 'Medium'
        ELSE 'Low'
    END AS severity,
    -- Spread across 2024-2025
    DATEADD(DAY,
        UNIFORM(0, 730, RANDOM(31000 + t.ticket_id)),
        '2024-01-01'::DATE
    ) AS created_date,
    UNIFORM(1, 30, RANDOM(32000 + t.ticket_id)) AS resolution_days,
    CASE WHEN UNIFORM(1, 100, RANDOM(33000 + t.ticket_id)) <= 85
         THEN 'Resolved' ELSE 'Open' END AS status
FROM ticket_gen t;

-- ─────────────────────────────────────────────
-- CHURN_SIGNALS: 10K signals
-- Planted: EMEA enterprise cluster in Q3 2025
-- ─────────────────────────────────────────────
CREATE OR REPLACE TABLE CHURN_SIGNALS AS
WITH signal_gen AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY seq4()) AS signal_id,
        seq4() AS rn
    FROM TABLE(GENERATOR(ROWCOUNT => 10000))
)
SELECT
    s.signal_id,
    UNIFORM(1, 50000, RANDOM(34000 + s.signal_id)) AS customer_id,
    CASE MOD(s.signal_id, 5)
        WHEN 0 THEN 'Decreased Usage'
        WHEN 1 THEN 'Support Escalation'
        WHEN 2 THEN 'Payment Delay'
        WHEN 3 THEN 'Contract Review Request'
        ELSE 'Competitor Evaluation'
    END AS signal_type,
    DATEADD(DAY,
        UNIFORM(0, 730, RANDOM(35000 + s.signal_id)),
        '2024-01-01'::DATE
    ) AS signal_date,
    -- Churn probability score
    ROUND(UNIFORM(10, 95, RANDOM(36000 + s.signal_id)) / 100.0, 2) AS score
FROM signal_gen s;

-- ─────────────────────────────────────────────
-- PLANTED: 4 specific EMEA enterprise churned accounts
-- These are the accounts the agent should surface
-- ─────────────────────────────────────────────
-- Ensure these customer IDs exist with churn_flag = TRUE
-- and have high-score churn signals in Q3 2025

-- Insert explicit high-score signals for planted accounts
INSERT INTO CHURN_SIGNALS (signal_id, customer_id, signal_type, signal_date, score)
VALUES
    (100001, 4,     'Contract Review Request', '2025-07-10', 0.92),
    (100002, 4,     'Competitor Evaluation',   '2025-07-25', 0.95),
    (100003, 16,    'Decreased Usage',         '2025-08-02', 0.88),
    (100004, 16,    'Payment Delay',           '2025-08-18', 0.91),
    (100005, 28,    'Support Escalation',      '2025-07-15', 0.90),
    (100006, 28,    'Contract Review Request', '2025-08-20', 0.93),
    (100007, 40,    'Competitor Evaluation',   '2025-08-05', 0.87),
    (100008, 40,    'Decreased Usage',         '2025-09-01', 0.94);

-- ─────────────────────────────────────────────
-- VERIFICATION: EMEA enterprise churn rate
-- ─────────────────────────────────────────────
SELECT
    r.territory,
    c.segment,
    COUNT(*) AS total_customers,
    SUM(CASE WHEN c.churn_flag THEN 1 ELSE 0 END) AS churned,
    ROUND(churned / total_customers * 100, 1) AS churn_rate_pct
FROM CUSTOMER_DIM c
JOIN DIM_REGION r ON c.region_id = r.region_id
WHERE c.segment = 'Enterprise'
GROUP BY r.territory, c.segment
ORDER BY churn_rate_pct DESC;
```

---

#### Script 6: Document AI Tables (Demo 3)

```sql
/*
==================================================================
  DEMO AI SUMMIT — DOCUMENT AI TABLES
  Script: 06_document_ai.sql
  Purpose: Schema + sample data for Document AI demo
  Dependencies: 01_infrastructure.sql

  NOTE: The actual PDF files must be uploaded to the stage manually.
  This script creates the tables and pre-populates extracted data
  so the demo works even if Document AI processing is slow.
==================================================================
*/

USE SCHEMA DOC_AI_DEMO;

-- ─────────────────────────────────────────────
-- Stage for PDF uploads
-- ─────────────────────────────────────────────
CREATE OR REPLACE STAGE DOCUMENTS_STAGE
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Landing zone for contract PDFs';

-- ─────────────────────────────────────────────
-- Raw extraction output
-- ─────────────────────────────────────────────
CREATE OR REPLACE TABLE DOCUMENTS_RAW (
    doc_id          INTEGER AUTOINCREMENT,
    file_name       VARCHAR(500),
    upload_ts       TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    raw_json        VARIANT,
    processing_status VARCHAR(20) DEFAULT 'PENDING',
    CONSTRAINT pk_documents_raw PRIMARY KEY (doc_id)
);

-- ─────────────────────────────────────────────
-- Structured extracted fields
-- ─────────────────────────────────────────────
CREATE OR REPLACE TABLE DOCUMENTS_EXTRACTED (
    doc_id          INTEGER,
    doc_type        VARCHAR(100),
    party_a         VARCHAR(200),
    party_b         VARCHAR(200),
    effective_date  DATE,
    expiration_date DATE,
    total_value     NUMBER(15,2),
    payment_terms   VARCHAR(100),
    auto_renewal    BOOLEAN,
    governing_law   VARCHAR(100),
    CONSTRAINT pk_documents_extracted PRIMARY KEY (doc_id)
);

-- ─────────────────────────────────────────────
-- Full-text chunks for Cortex Search
-- ─────────────────────────────────────────────
CREATE OR REPLACE TABLE DOCUMENTS_TEXT (
    doc_id          INTEGER,
    chunk_id        INTEGER,
    chunk_text      VARCHAR(4000),
    page_number     INTEGER,
    section_header  VARCHAR(200),
    CONSTRAINT pk_documents_text PRIMARY KEY (doc_id, chunk_id)
);

-- ─────────────────────────────────────────────
-- Pre-populate: MSA_Acme_GlobalTech_2024.pdf
-- (hero document for live demo)
-- ─────────────────────────────────────────────
INSERT INTO DOCUMENTS_RAW (doc_id, file_name, processing_status)
VALUES (1, 'MSA_Acme_GlobalTech_2024.pdf', 'COMPLETED');

INSERT INTO DOCUMENTS_EXTRACTED VALUES (
    1, 'Master Services Agreement',
    'Acme Corp', 'GlobalTech Inc',
    '2024-01-15', '2026-01-14',
    2400000.00, 'Net 30',
    TRUE, 'State of Delaware'
);

-- Key text chunks that the demo questions will hit
INSERT INTO DOCUMENTS_TEXT VALUES
    (1, 1, 'This Master Services Agreement ("Agreement") is entered into as of January 15, 2024, by and between Acme Corp, a Delaware corporation ("Client"), and GlobalTech Inc, a California corporation ("Provider").', 1, 'Preamble'),
    (1, 2, 'The term of this Agreement shall commence on the Effective Date and continue for a period of twenty-four (24) months, unless earlier terminated in accordance with Section 8.', 2, 'Section 2 — Term'),
    (1, 3, 'Client shall pay Provider fees as set forth in each Statement of Work. The total aggregate value of this Agreement shall not exceed Two Million Four Hundred Thousand Dollars ($2,400,000). Payment terms are Net 30 days from receipt of invoice.', 3, 'Section 4 — Fees and Payment'),
    (1, 4, 'This Agreement shall automatically renew for successive twelve (12) month periods unless either party provides written notice of non-renewal at least sixty (60) days prior to the end of the then-current term.', 4, 'Section 5 — Renewal'),
    (1, 5, 'Each party agrees to maintain the confidentiality of all Confidential Information disclosed by the other party. Confidential Information shall not include information that is publicly available, independently developed, or rightfully received from a third party.', 5, 'Section 7 — Confidentiality'),
    -- PLANTED: Termination clause (visitor will ask about this)
    (1, 6, 'Either party may terminate this Agreement upon ninety (90) days prior written notice to the other party. Upon termination, Client shall pay for all Services rendered through the termination date. Provider shall return or destroy all Client data within thirty (30) days of termination.', 7, 'Section 8.2 — Termination for Convenience'),
    (1, 7, 'Either party may terminate this Agreement immediately upon written notice if the other party materially breaches any provision and fails to cure such breach within thirty (30) days after receiving written notice of the breach.', 7, 'Section 8.3 — Termination for Cause'),
    -- PLANTED: Liability cap (visitor will ask about this)
    (1, 8, 'IN NO EVENT SHALL EITHER PARTY''S AGGREGATE LIABILITY UNDER THIS AGREEMENT EXCEED FIVE MILLION DOLLARS ($5,000,000). NEITHER PARTY SHALL BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES.', 9, 'Section 10.1 — Limitation of Liability'),
    (1, 9, 'Provider shall maintain the following insurance coverage: (a) Commercial General Liability of not less than $2,000,000 per occurrence; (b) Professional Liability of not less than $5,000,000 per claim; (c) Cyber Liability of not less than $3,000,000 per occurrence.', 10, 'Section 11 — Insurance'),
    (1, 10, 'This Agreement shall be governed by and construed in accordance with the laws of the State of Delaware, without regard to its conflict of laws principles. Any dispute arising under this Agreement shall be resolved through binding arbitration in Wilmington, Delaware.', 11, 'Section 14 — Governing Law'),
    -- PLANTED: "Early exit provisions" — will NOT match keyword "termination"
    -- but Cortex Search WILL find it (semantic match)
    (1, 11, 'Notwithstanding the foregoing, Client may exercise early exit provisions under this Agreement by providing sixty (60) days notice and paying an early exit fee equal to twenty percent (20%) of the remaining contract value.', 8, 'Section 8.5 — Early Exit Provisions');

-- ─────────────────────────────────────────────
-- Pre-populate: Remaining 4 sample documents
-- (abbreviated — just metadata + key chunks)
-- ─────────────────────────────────────────────
INSERT INTO DOCUMENTS_RAW (doc_id, file_name, processing_status) VALUES
    (2, 'SaaS_Subscription_NovaTech_2024.pdf', 'COMPLETED'),
    (3, 'NDA_Mutual_Acme_Pinnacle_2024.pdf', 'COMPLETED'),
    (4, 'SOW_DataPlatform_Acme_2024.pdf', 'COMPLETED'),
    (5, 'DPA_Acme_CloudVault_2024.pdf', 'COMPLETED');

INSERT INTO DOCUMENTS_EXTRACTED VALUES
    (2, 'SaaS Subscription', 'NovaTech Solutions', 'Acme Corp', '2024-03-01', '2025-02-28', 360000.00, 'Annual Prepaid', TRUE, 'State of California'),
    (3, 'NDA (Mutual)', 'Acme Corp', 'Pinnacle Analytics', '2024-06-01', '2026-05-31', NULL, NULL, FALSE, 'State of New York'),
    (4, 'Statement of Work', 'Acme Corp', 'GlobalTech Inc', '2024-04-01', '2024-12-31', 480000.00, 'Monthly Milestone', FALSE, 'State of Delaware'),
    (5, 'Data Processing Agreement', 'Acme Corp', 'CloudVault Storage', '2024-01-15', '2026-01-14', NULL, NULL, TRUE, 'GDPR — EU Standard Contractual Clauses');

-- ─────────────────────────────────────────────
-- VERIFICATION: Document counts
-- ─────────────────────────────────────────────
SELECT 'DOCUMENTS_RAW' AS tbl, COUNT(*) AS rows FROM DOCUMENTS_RAW
UNION ALL SELECT 'DOCUMENTS_EXTRACTED', COUNT(*) FROM DOCUMENTS_EXTRACTED
UNION ALL SELECT 'DOCUMENTS_TEXT', COUNT(*) FROM DOCUMENTS_TEXT;
```

**Pitfall:** The Document AI demo shows a "live upload" but the data is pre-loaded. Make sure the Streamlit app checks if `doc_id = 1` already exists before inserting — otherwise you get duplicates on repeated demos. The `CREATE OR REPLACE TABLE` in this script handles the reset, but the app needs to be idempotent too.

---

#### Script 7: Cortex Search Service

```sql
/*
==================================================================
  DEMO AI SUMMIT — CORTEX SEARCH SERVICE
  Script: 07_cortex_search.sql
  Purpose: Create Cortex Search service over document text
  Dependencies: 06_document_ai.sql

  NOTE: Cortex Search service creation can take 1-5 minutes.
  Run this at T-7 and verify it's healthy before the event.
==================================================================
*/

USE SCHEMA DOC_AI_DEMO;

CREATE OR REPLACE CORTEX SEARCH SERVICE DOCUMENTS_SEARCH_SERVICE
    ON chunk_text
    ATTRIBUTES page_number, section_header
    WAREHOUSE = DEMO_AI_WH
    TARGET_LAG = '1 hour'
    COMMENT = 'Semantic search over contract document text'
    AS (
        SELECT
            chunk_text,
            page_number,
            section_header,
            doc_id,
            chunk_id
        FROM DOCUMENTS_TEXT
    );

-- ─────────────────────────────────────────────
-- VERIFICATION: Test search queries
-- ─────────────────────────────────────────────

-- Test 1: "termination clause" should return Section 8.2
-- (Run via Cortex Search API in Streamlit — SQL verification below is conceptual)
-- SELECT SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
--     'DOCUMENTS_SEARCH_SERVICE',
--     'What is the termination clause?',
--     5
-- );

-- Test 2: "liability caps" should return Section 10.1
-- Test 3: "early exit" should return Section 8.5 (semantic match, no keyword "termination")
```

---

### Data Volume Summary

| Table | Schema | Rows | Load Time (est.) |
|-------|--------|------|-------------------|
| DIM_DATE | CORTEX_ANALYST_DEMO | 1,096 | < 1s |
| DIM_REGION | CORTEX_ANALYST_DEMO | 12 | < 1s |
| DIM_PRODUCT | CORTEX_ANALYST_DEMO | 2,000 | < 1s |
| DIM_SALES_REP | CORTEX_ANALYST_DEMO | 200 | < 1s |
| CUSTOMER_DIM | CORTEX_ANALYST_DEMO | 50,000 | ~2s |
| SALES_FACT | CORTEX_ANALYST_DEMO | 500,000 | ~10s |
| CAMPAIGN_FACT | CORTEX_ANALYST_DEMO | 5,000 | ~1s |
| SUPPORT_TICKETS | CORTEX_ANALYST_DEMO | 20,000 | ~2s |
| CHURN_SIGNALS | CORTEX_ANALYST_DEMO | 10,008 | ~1s |
| DOCUMENTS_RAW | DOC_AI_DEMO | 5 | < 1s |
| DOCUMENTS_EXTRACTED | DOC_AI_DEMO | 5 | < 1s |
| DOCUMENTS_TEXT | DOC_AI_DEMO | 11 | < 1s |
| **Total** | | **~588K** | **< 2 min** |

### Best Practices & Pitfalls

| Area | Do | Don't |
|------|-----|-------|
| **Planted data** | Verify every planted pattern with the verification queries before the event | Trust the multipliers blindly — `UNIFORM()` + `RANDOM()` can shift across Snowflake versions |
| **Idempotency** | Use `CREATE OR REPLACE` for all tables; scripts can be re-run safely | Use `INSERT INTO` without clearing first (duplicates on re-run) |
| **Determinism** | Use explicit `VALUES` for critical demo moments (the 4 churned accounts, the contract text) | Rely on `RANDOM()` for data the audience will see directly |
| **Warehouse** | Use Medium for data load; can scale down to Small for demo queries | Leave warehouse running at Medium during the event (cost) |
| **Reset** | Run scripts 1-7 as a full reset if anything goes wrong at the event | Try to surgically fix individual rows during a live demo |
| **Timing** | Load data at T-7; verify at T-5; freeze at T-3 | Load data the morning of the event |

---

## 5. Demo Track: Tier 1 — Hero Demos

### Overview

Tier 1 demos are the booth's **primary draw**. They run continuously on the main screen, every visitor sees at least one, and they're designed to land in under 5 minutes. Each demo is self-contained: own data, own Cortex service, own Streamlit app, own fallback path.

**Three hero demos, three stations:**

| Station | Demo | Owner | Duration |
|---------|------|-------|----------|
| A — Main Screen | Cortex Analyst: "Talk to Your Data" | Station Owner 1 | 3-5 min per visitor |
| B — Agent Screen | Data Agent: "Autonomous Analyst" | Station Owner 2 | 5-7 min per visitor |
| C — Interactive | Document AI + Cortex Search: "Paper to Insight" | Station Owner 3 | 3-5 min per visitor |

---

### Demo 1: Cortex Analyst — "Talk to Your Data"

#### Use Case

A business user — no SQL skills, no BI tool open — walks up and asks a question about company performance in plain English. Cortex Analyst generates SQL, executes it, and returns a natural-language summary with supporting data. The visitor sees the entire cycle in under 30 seconds.

**Persona alignment:**
- **CXO:** "Answers in 30 seconds, not 3 days — no dashboard backlog, no analyst bottleneck."
- **Data leader:** "This sits on top of our governed semantic layer — no shadow analytics, no data copies."
- **Analyst:** "I can validate the generated SQL, iterate on it, and trust the numbers match our metrics."
- **Engineer:** "I define the semantic model once — every team in the org queries through it."

#### Flow (What the Visitor Sees)

```
Step 1  Visitor approaches Station A. Screen shows a clean Streamlit chat interface
        branded with your company logo. A prompt reads:
        "Ask anything about our sales data."

Step 2  Visitor types (or station owner types for them):
        "Which regions underperformed last quarter?"

Step 3  Cortex Analyst processes the question against the semantic model.
        The screen shows:
        ├── Generated SQL (collapsible — visible for technical visitors)
        ├── Result table: Region | Revenue | Target | Gap %
        └── Natural-language summary:
            "EMEA and LATAM missed Q4 targets by 12% and 8% respectively.
             APAC exceeded target by 6%."

Step 4  Station owner prompts a follow-up:
        "Why did EMEA underperform?"
        Cortex Analyst joins SALES_FACT with CAMPAIGN_FACT, identifies that
        two major campaigns were paused in Nov-Dec, and surfaces that insight.

Step 5  Station owner closes with:
        "This is Cortex Analyst — natural language to SQL, governed by a
         semantic model your team defines. No data leaves Snowflake."
```

**Visitor challenge (optional engagement hook):**
Print 5 laminated cards with questions of increasing difficulty:
1. "What were total sales last quarter?"
2. "Which product category has the highest return rate?"
3. "Compare marketing spend vs revenue by region for Q3 and Q4."
4. "Which sales rep closed the most deals above $50K in the last 6 months?"
5. "What's the correlation between discount percentage and customer churn?"

Visitors pick a card, type the question, see if Cortex Analyst handles it.

#### Key Snowflake Features

| Feature | Role in Demo |
|---------|-------------|
| **Cortex Analyst** | NL-to-SQL engine; generates, executes, and summarizes queries |
| **Semantic Model (YAML)** | Defines tables, joins, metrics, and business terms Cortex Analyst can use |
| **Verified Queries** | Pre-validated SQL patterns for high-confidence answers on common questions |
| **Streamlit in Snowflake** | Chat UI — no external app server, runs inside Snowflake |
| **Row Access Policies** (mention) | "In production, this respects your row-level security — same question, different answers per role" |

#### Data Model Impact

**Database:** `DEMO_AI_SUMMIT`
**Schema:** `CORTEX_ANALYST_DEMO`

| Table | Purpose | Approx Rows |
|-------|---------|-------------|
| `SALES_FACT` | Transactional sales data (order_id, product_id, region_id, rep_id, amount, discount_pct, order_date) | 500K |
| `DIM_PRODUCT` | Product catalog (product_id, name, category, subcategory, unit_cost) | 2K |
| `DIM_REGION` | Region hierarchy (region_id, region_name, country, territory) | 50 |
| `DIM_DATE` | Date dimension (date_key, quarter, month, year, fiscal_period) | 3 years |
| `DIM_SALES_REP` | Sales rep directory (rep_id, name, team, hire_date) | 200 |
| `CAMPAIGN_FACT` | Marketing campaigns (campaign_id, region_id, spend, start_date, end_date, channel) | 5K |
| `CUSTOMER_DIM` | Customer master (customer_id, segment, lifetime_value, first_order_date, churn_flag) | 50K |

**Semantic model file:** `cortex_analyst_demo.yaml`
- Maps all dimension/fact relationships
- Defines business metrics: `total_revenue`, `avg_discount`, `return_rate`, `yoy_growth`
- Includes verified queries for the 5 laminated-card questions

#### Streamlit Mapping

**App:** `app_cortex_analyst.py` (Section 8 provides skeleton)

```
Layout:
┌─────────────────────────────────────────────┐
│  [Company Logo]   Cortex Analyst Demo       │
├─────────────────────────────────────────────┤
│                                             │
│  Chat history (scrollable)                  │
│  ┌─────────────────────────────────────┐    │
│  │ User: Which regions underperformed? │    │
│  │ AI: EMEA and LATAM missed Q4...     │    │
│  │ [▼ Show SQL]                        │    │
│  │ [📊 Table: Region | Rev | Target]   │    │
│  └─────────────────────────────────────┘    │
│                                             │
│  ┌─────────────────────────────────────┐    │
│  │ Ask a question...              [Send]│    │
│  └─────────────────────────────────────┘    │
│                                             │
│  Sidebar: Semantic model info | Reset Chat  │
└─────────────────────────────────────────────┘
```

**Key Streamlit components:**
- `st.chat_message` / `st.chat_input` for conversational UI
- `st.expander` for collapsible SQL display
- `st.dataframe` / `st.bar_chart` for result visualization
- Session state to maintain multi-turn conversation context

#### Fallback Plan

| Failure | Fallback |
|---------|----------|
| Cortex Analyst unavailable or slow | Switch to pre-recorded 90-second screen capture showing the full flow. Keep Streamlit app running with cached responses. |
| Semantic model errors | Revert to a minimal 3-table model (SALES_FACT + DIM_PRODUCT + DIM_REGION) tested and frozen 48 hours before event. |
| Network / latency issues | Run the demo on a local screen recording loop. Station owner narrates live over the recording. |
| Visitor asks an out-of-scope question | Station owner redirects: "Great question — that would require connecting to [X] data source. Let me show you what it does with the data we have." |

---

### Demo 2: Data Agent — "Autonomous Analyst"

#### Use Case

A business stakeholder asks a complex, multi-step question: _"Why did Q3 revenue drop compared to Q2?"_ Instead of getting a single SQL answer, a Snowflake Cortex Agent autonomously reasons through the problem — querying multiple tables, comparing time periods, checking external factors, and producing a structured investigation summary. The visitor sees an AI that **acts**, not just answers.

**Persona alignment:**
- **CXO:** "Root-cause analysis in 90 seconds — not a 3-day analyst sprint and a 20-slide deck."
- **Data leader:** "Every query the agent runs is auditable, governed, and uses the same semantic layer as self-service."
- **Analyst:** "I can review the reasoning chain, correct any step, and re-run — I stay in control."
- **Engineer:** "I define tools (SQL, APIs, procedures) and the agent orchestrates them autonomously."

#### Flow (What the Visitor Sees)

```
Step 1  Visitor approaches Station B. Screen shows a Streamlit app with a
        single input field:
        "Ask the Data Agent to investigate something."

Step 2  Station owner types (or narrates while typing):
        "Investigate why Q3 revenue dropped compared to Q2."

Step 3  The agent's reasoning chain appears in real-time:

        ┌─ Agent Reasoning ─────────────────────────────────────────┐
        │                                                           │
        │  [1/5] Querying SALES_FACT for Q2 vs Q3 revenue...       │
        │  ✓ Q2: $14.2M | Q3: $11.8M | Delta: -$2.4M (-17%)       │
        │                                                           │
        │  [2/5] Breaking down by region...                         │
        │  ✓ EMEA dropped $1.6M, NA dropped $0.5M, APAC flat       │
        │                                                           │
        │  [3/5] Checking CAMPAIGN_FACT for marketing changes...    │
        │  ✓ Two EMEA campaigns paused Jul-Aug (budget freeze)      │
        │                                                           │
        │  [4/5] Checking CUSTOMER_DIM for churn signals...         │
        │  ✓ EMEA enterprise churn rate spiked 3.2% → 7.1% in Q3   │
        │                                                           │
        │  [5/5] Generating investigation summary...                │
        │                                                           │
        └───────────────────────────────────────────────────────────┘

Step 4  Agent produces a structured summary:

        ┌─ Investigation Summary ───────────────────────────────────┐
        │                                                           │
        │  ROOT CAUSE: Q3 revenue drop of $2.4M (-17%) driven by:  │
        │                                                           │
        │  1. EMEA campaign pause (Jul-Aug budget freeze)           │
        │     → Estimated impact: -$1.2M pipeline                  │
        │                                                           │
        │  2. Enterprise customer churn spike in EMEA               │
        │     → 4 enterprise accounts churned (3.2% → 7.1%)        │
        │     → Revenue impact: -$0.4M recurring                   │
        │                                                           │
        │  3. NA seasonal dip (consistent with prior years)         │
        │     → Within normal range, no action needed               │
        │                                                           │
        │  RECOMMENDATION:                                          │
        │  - Reinstate EMEA campaigns with adjusted targeting       │
        │  - Trigger retention workflow for at-risk enterprise accts│
        │                                                           │
        └───────────────────────────────────────────────────────────┘

Step 5  Station owner closes:
        "Five queries, one external check, structured root-cause analysis —
         all autonomous. In production, this agent can trigger Slack alerts,
         update a Jira ticket, or kick off a dbt run."
```

#### Key Snowflake Features

| Feature | Role in Demo |
|---------|-------------|
| **Cortex Agent** | Orchestrates multi-step reasoning with tool selection |
| **Cortex Analyst tool** | Agent calls Cortex Analyst as a tool for NL-to-SQL queries against the semantic model |
| **SQL tool** | Agent executes direct SQL for ad-hoc exploration |
| **Python tool** (optional) | Agent runs inline Python for calculations or formatting |
| **Semantic Model** | Shared with Demo 1 — single source of truth |
| **Streamlit in Snowflake** | Renders the agent's reasoning chain and summary in real-time |

#### Data Model Impact

**Schema:** `CORTEX_AGENT_DEMO` (or reuses `CORTEX_ANALYST_DEMO` — same fact/dim tables)

Reuses the same core tables from Demo 1, plus:

| Table | Purpose | Approx Rows |
|-------|---------|-------------|
| `SUPPORT_TICKETS` | Customer support tickets (ticket_id, customer_id, category, severity, created_date, resolution_days) | 20K |
| `CHURN_SIGNALS` | Pre-computed churn indicators (customer_id, signal_type, signal_date, score) | 10K |

**Agent configuration:**
- Semantic model: reuses `cortex_analyst_demo.yaml` from Demo 1
- Tools: `cortex_analyst_tool` (NL-to-SQL), `sql_tool` (direct queries)
- System prompt defining investigation methodology and output format

#### Streamlit Mapping

**App:** `app_data_agent.py` (Section 8 provides skeleton)

```
Layout:
┌─────────────────────────────────────────────┐
│  [Company Logo]   Data Agent — Investigator │
├─────────────────────────────────────────────┤
│                                             │
│  Agent Status: ● Reasoning (step 3 of 5)   │
│                                             │
│  Reasoning Chain (expandable steps):        │
│  ┌─────────────────────────────────────┐    │
│  │ ✓ Step 1: Revenue comparison        │    │
│  │ ✓ Step 2: Regional breakdown        │    │
│  │ ● Step 3: Campaign analysis...      │    │
│  │ ○ Step 4: Churn signals             │    │
│  │ ○ Step 5: Summary generation        │    │
│  └─────────────────────────────────────┘    │
│                                             │
│  Summary Panel (appears when complete):     │
│  ┌─────────────────────────────────────┐    │
│  │ Root cause + recommendations        │    │
│  └─────────────────────────────────────┘    │
│                                             │
│  ┌─────────────────────────────────────┐    │
│  │ Ask the agent...              [Send]│    │
│  └─────────────────────────────────────┘    │
└─────────────────────────────────────────────┘
```

#### Fallback Plan

| Failure | Fallback |
|---------|----------|
| Cortex Agent not available (GA status uncertain) | **Primary fallback:** Pre-recorded 2-minute screen capture of the full agent flow. Station owner narrates live. Streamlit app shows a "replay" mode that steps through cached reasoning chain with realistic timing: **Step 1-4: 2s pause per step** (simulates query execution), **Step 5 summary: 3s fade-in** (simulates generation). Total replay: ~60-90 seconds. Store cached responses in a JSON file (`agent_replay_cache.json`) loaded at app startup. |
| Agent available but slow (>60s) | Pre-load the investigation question so the agent starts processing before the visitor arrives. Show the "in-progress" reasoning chain as they walk up. |
| Agent hallucinates or errors mid-chain | Station owner interrupts: "Let me show you a completed investigation." Switch to cached result set. Explain: "In production, you'd add guardrails — verified queries, output validation, human-in-the-loop approval." |
| Visitor asks a question outside the demo data | Redirect to the pre-built investigation. "Great scenario — let me show you the depth of analysis the agent can do with this one." |

**Pre-event checklist for fallback readiness:**
- [ ] Record 2-minute screen capture of a successful agent run
- [ ] Build "replay mode" in Streamlit that steps through cached JSON responses
- [ ] Test agent with 10 variations of the Q3 revenue question — document which phrasings work
- [ ] Prepare 3 alternative investigation prompts as backup

---

### Demo 3: Document AI + Cortex Search — "Paper to Insight in 60 Seconds"

#### Use Case

A contract PDF is uploaded to Snowflake. Document AI extracts structured fields (parties, dates, dollar amounts, clauses). Cortex Search indexes the full text for semantic retrieval. A visitor then asks _"What's the termination clause?"_ in plain English and gets the exact paragraph — no keyword matching, no manual search. The full pipeline runs in under 60 seconds.

**Persona alignment:**
- **CXO:** "500 contracts a month, reviewed manually. This cuts review time from hours to seconds."
- **Data leader:** "Unstructured data becomes queryable — same governance, same platform, no third-party AI gateway."
- **Analyst:** "I search across every contract like I search a database — plain English, instant results."
- **Engineer:** "Same pipeline works for invoices, resumes, medical records — swap the doc type, keep the architecture."

#### Flow (What the Visitor Sees)

```
Step 1  Visitor approaches Station C. Screen shows a Streamlit app with two
        panels: an upload zone on the left, a search bar on the right.

Step 2  Station owner uploads a sample contract PDF (pre-staged but shown
        as a live upload for demo effect).

Step 3  Left panel shows Document AI extraction in progress:

        ┌─ Document AI Extraction ──────────────────────────────────┐
        │                                                           │
        │  Document: Master_Services_Agreement_Acme_2024.pdf        │
        │  Pages: 12                                                │
        │                                                           │
        │  Extracted Fields:                                        │
        │  ├── Parties: Acme Corp ↔ GlobalTech Inc                  │
        │  ├── Effective Date: 2024-01-15                           │
        │  ├── Expiration Date: 2026-01-14                          │
        │  ├── Total Value: $2,400,000                              │
        │  ├── Payment Terms: Net 30                                │
        │  ├── Auto-Renewal: Yes (12-month periods)                 │
        │  └── Governing Law: State of Delaware                     │
        │                                                           │
        │  Full text indexed in Cortex Search ✓                     │
        │                                                           │
        └───────────────────────────────────────────────────────────┘

Step 4  Station owner switches to the right panel and types:
        "What's the termination clause?"

        Cortex Search returns the exact paragraph:

        ┌─ Search Result ───────────────────────────────────────────┐
        │                                                           │
        │  Section 8.2 — Termination for Convenience               │
        │  "Either party may terminate this Agreement upon ninety   │
        │   (90) days' prior written notice to the other party.     │
        │   Upon termination, Client shall pay for all Services     │
        │   rendered through the termination date..."               │
        │                                                           │
        │  Relevance: 0.94 | Source: Page 7, Section 8.2           │
        │                                                           │
        └───────────────────────────────────────────────────────────┘

Step 5  Station owner asks a follow-up:
        "Are there any liability caps?"

        Cortex Search returns Section 10.1 with the $5M aggregate cap.

Step 6  Station owner closes:
        "Upload → extraction → semantic search. No data left Snowflake.
         Your legal, procurement, and compliance teams can search across
         thousands of documents in natural language."
```

#### Key Snowflake Features

| Feature | Role in Demo |
|---------|-------------|
| **Document AI** | Extracts structured fields from PDFs (OCR + ML-based field extraction) |
| **Cortex Search** | Semantic vector search over document text — understands meaning, not just keywords |
| **Internal Stage** | PDF upload target — `@DEMO_AI_SUMMIT.DOC_AI_DEMO.DOCUMENTS_STAGE` |
| **Cortex SUMMARIZE()** | Optional: generate a 3-sentence contract summary after extraction |
| **Streamlit in Snowflake** | Dual-panel UI: upload + extraction on left, semantic search on right |

#### Data Model Impact

**Schema:** `DOC_AI_DEMO`

| Object | Type | Purpose |
|--------|------|---------|
| `DOCUMENTS_STAGE` | Internal Stage | Landing zone for uploaded PDFs |
| `DOCUMENTS_RAW` | Table | Raw extraction output (doc_id, file_name, upload_ts, raw_json) |
| `DOCUMENTS_EXTRACTED` | Table | Structured fields (doc_id, party_a, party_b, effective_date, expiration_date, total_value, payment_terms, governing_law) |
| `DOCUMENTS_TEXT` | Table | Full-text chunks for Cortex Search (doc_id, chunk_id, chunk_text, page_number, section_header) |
| `DOCUMENTS_SEARCH_SERVICE` | Cortex Search Service | Semantic index over `DOCUMENTS_TEXT.chunk_text` |

**Pre-loaded sample documents** staged at `@DEMO_AI_SUMMIT.DOC_AI_DEMO.DOCUMENTS_STAGE`:

| # | Filename | Type | Pages | Hero Doc? |
|---|----------|------|-------|-----------|
| 1 | `MSA_Acme_GlobalTech_2024.pdf` | Master Services Agreement | 12 | Yes — primary live demo |
| 2 | `SaaS_Subscription_NovaTech_2024.pdf` | SaaS Subscription Agreement | 8 | No |
| 3 | `NDA_Mutual_Acme_Pinnacle_2024.pdf` | NDA (Mutual) | 4 | No |
| 4 | `SOW_DataPlatform_Acme_2024.pdf` | Statement of Work | 6 | No |
| 5 | `DPA_Acme_CloudVault_2024.pdf` | Data Processing Agreement | 10 | No |

> **PDF generation note:** These PDFs do not need to contain real contract text. The demo's Document AI "extraction" uses pre-loaded data from Script 06 — the upload is cosmetic. Generate simple placeholder PDFs with realistic cover pages (company names, dates, "CONFIDENTIAL" header). Use any PDF generator (Google Docs, Word, or a Python script with `reportlab`). The actual searchable text is in the `DOCUMENTS_TEXT` table, not in the PDFs themselves.

#### Streamlit Mapping

**App:** `app_document_ai.py` (Section 8 provides skeleton)

```
Layout:
┌──────────────────────┬──────────────────────────┐
│  UPLOAD & EXTRACT    │  SEMANTIC SEARCH         │
├──────────────────────┼──────────────────────────┤
│                      │                          │
│  [Upload PDF]        │  Search across all docs: │
│                      │  ┌──────────────────┐    │
│  Extraction Results: │  │ Ask anything... [Go]│  │
│  ┌────────────────┐  │  └──────────────────┘    │
│  │ Parties: ...   │  │                          │
│  │ Date: ...      │  │  Results:                │
│  │ Value: ...     │  │  ┌──────────────────┐    │
│  │ Terms: ...     │  │  │ Section 8.2 ...  │    │
│  └────────────────┘  │  │ Relevance: 0.94  │    │
│                      │  └──────────────────┘    │
│  [View Full Text]    │                          │
│                      │  [Compare with LIKE ↔]   │
│                      │  (side-by-side: semantic  │
│                      │   vs keyword search)      │
└──────────────────────┴──────────────────────────┘
```

**Bonus interaction:** A "Compare" toggle that runs the same query as a `LIKE '%termination%'` search and shows how keyword search misses semantically relevant results (e.g., "early exit provisions" doesn't contain the word "termination" but Cortex Search finds it).

#### Fallback Plan

| Failure | Fallback |
|---------|----------|
| Document AI unavailable or slow | Pre-extract all 5 sample docs. Skip the live upload step — show the extraction results as "just processed" and focus the demo on Cortex Search (the stronger wow-factor anyway). |
| Cortex Search service down | Fall back to `CORTEX.SEARCH_PREVIEW()` function or show pre-cached search results in the Streamlit app. |
| PDF upload fails at event | Stage all documents 24 hours before. The "upload" in the demo is cosmetic — data is already loaded. |
| Visitor wants to upload their own document | Politely decline: "We're using pre-cleared sample data for this demo. Happy to discuss how to set this up for your document types." (Avoid ingesting unknown/sensitive data at a public event.) |

---

### Tier 1 — Cross-Cutting Requirements

These apply to all three hero demos:

**Shared infrastructure:**
- Database: `DEMO_AI_SUMMIT`
- Warehouse: `DEMO_AI_WH` (Medium, auto-suspend 60s, auto-resume)
- Role: `DEMO_AI_ROLE` (grants on all demo schemas + Cortex services)
- Network policy: Restrict to event network / VPN if possible

**Semantic model reuse:**
- Demos 1 and 2 share the same `cortex_analyst_demo.yaml` semantic model
- Demo 3 uses its own Cortex Search service (no semantic model overlap)

**Pre-event testing protocol:**
- [ ] T-7 days: All synthetic data loaded, all Cortex services created
- [ ] T-5 days: All three Streamlit apps deployed and tested end-to-end
- [ ] T-3 days: Fallback recordings captured for all three demos
- [ ] T-2 days: Full dry run with all 3 station owners, timed
- [ ] T-1 day: Final smoke test on event network; confirm Cortex service health
- [ ] T-0 morning: 15-minute warm-up run before doors open

**Reset between visitors:**
- Each Streamlit app has a "Reset Demo" button (clears chat history, resets state)
- Station owner clicks reset between visitors (< 3 seconds)
- Pre-loaded "starter" state so the app never looks empty when a visitor walks up

---

## 6. Demo Track: Tier 2 — Deep Dives

### Overview

Tier 2 demos run at the **side table** during scheduled 10-15 minute deep-dive slots (2 per day, per Section 9). They target returning visitors, technical evaluators, and pre-booked accounts who've already seen a Tier 1 demo and want depth.

**Key differences from Tier 1:**
- Longer format (10-15 min vs 3-5 min)
- More technical narration (show SQL, explain architecture)
- Run from Snowsight worksheets or notebooks — no dedicated Streamlit app
- Visitor is seated, engaged, and asking questions

**Three Tier 2 demos:**

| Demo | Feature | Duration | Best Follow-Up To |
|------|---------|----------|-------------------|
| 4. Enterprise Knowledge Base | Cortex Search (RAG) | 10 min | Demo 3 (Document AI) |
| 5. Voice of Customer Live | Cortex SENTIMENT + SUMMARIZE | 12 min | Demo 1 (Cortex Analyst) |
| 6. AI Without Bill Shock | Arctic / Mosaic cost comparison | 10 min | Any (cost is universal) |

---

### Demo 4: Cortex Search RAG — "Enterprise Knowledge Base"

#### Use Case

Your company has hundreds of internal policy documents, product manuals, and wiki pages. A new hire asks: _"What's our discount approval policy above 20%?"_ Today, they search Confluence, Slack, and email for 30 minutes. With Cortex Search, they get the exact paragraph in 2 seconds.

#### Setup (Pre-Event)

Add policy-style text chunks to the existing `DOCUMENTS_TEXT` table (same schema as Demo 3):

```sql
-- Insert enterprise knowledge base content
INSERT INTO DEMO_AI_SUMMIT.DOC_AI_DEMO.DOCUMENTS_TEXT VALUES
-- Discount policy
(100, 1, 'Discounts above 15% require manager approval. Discounts above 20% require VP of Sales approval and must be documented in Salesforce with a justification note. No discount above 30% is permitted without CFO sign-off.', NULL, 'Discount Approval Policy'),
(100, 2, 'Standard discount tiers: 0-10% (rep discretion), 10-15% (manager approval), 15-20% (VP approval), 20-30% (VP + CFO), 30%+ (not permitted). All discounts above 10% must include a competitive justification.', NULL, 'Discount Approval Policy'),

-- Expense policy
(101, 1, 'Travel expenses must be submitted within 14 days of travel completion. Domestic flights under $500 do not require pre-approval. International travel requires VP approval regardless of cost. Hotel per-diem is capped at $250/night in tier-1 cities and $175/night elsewhere.', NULL, 'Travel & Expense Policy'),

-- Data retention
(102, 1, 'Customer PII must be retained for a minimum of 7 years per regulatory requirements. After the retention period, data must be purged using the approved deletion workflow. Backup copies follow the same retention schedule.', NULL, 'Data Retention Policy'),
(102, 2, 'Anonymization is accepted as an alternative to deletion for analytics use cases. Anonymized data is not subject to the 7-year retention limit. The Data Governance team must approve all anonymization requests.', NULL, 'Data Retention Policy'),

-- SLA definitions
(103, 1, 'Tier 1 (Enterprise) customers receive 99.9% uptime SLA with 4-hour response time for critical issues and 24-hour response for non-critical. Tier 2 (Mid-Market) customers receive 99.5% uptime with 8-hour critical response. Tier 3 (SMB) customers receive best-effort support.', NULL, 'Customer SLA Definitions'),

-- Security policy
(104, 1, 'All production database access requires MFA. Service accounts must rotate credentials every 90 days. No production credentials may be stored in source code repositories. Secrets must be managed via the approved vault service.', NULL, 'Security Access Policy');
```

The Cortex Search service (`DOCUMENTS_SEARCH_SERVICE`) automatically indexes new rows based on `TARGET_LAG`.

#### Demo Flow (10 min, Snowsight + Streamlit hybrid)

```
Step 1  Show the document inventory:
        "We've loaded internal policies — discount, travel, SLA, security,
         data retention. Same Cortex Search service as the contracts demo."

Step 2  Open Station C's Streamlit app (or Snowsight notebook).
        Ask: "What's the discount approval process for deals above 20%?"

Step 3  Cortex Search returns the exact paragraph:
        "Discounts above 20% require VP of Sales approval..."
        Relevance: 0.92

Step 4  Ask a harder question: "How long do we keep customer data?"
        Returns: "7 years per regulatory requirements... anonymization
        accepted as an alternative..."

Step 5  Show the RAG pattern:
        "This is Retrieval-Augmented Generation. Cortex Search finds
         the relevant text. You can then pass it to CORTEX.COMPLETE()
         to generate a synthesized answer."

        -- Run in Snowsight worksheet:
        SELECT SNOWFLAKE.CORTEX.COMPLETE(
            'llama3.1-70b',
            'Based on the following policy text, answer the question:
             What is the discount approval process for deals above 20%?

             Context: ' || (
                 SELECT chunk_text
                 FROM DOC_AI_DEMO.DOCUMENTS_TEXT
                 WHERE section_header = 'Discount Approval Policy'
                 LIMIT 1
             )
        ) AS rag_answer;

Step 6  Close: "Search finds the source. The LLM synthesizes the answer.
        The source text is always cited — no hallucination without
        attribution."
```

#### Talk Track Highlights

- **vs Confluence/SharePoint search:** "Keyword search requires you to guess the right words. Semantic search understands what you mean."
- **Governance:** "The documents live in Snowflake. Access policies apply. You can restrict which roles see which policy documents."
- **Scale:** "This works with 10 documents or 10 million chunks. The search service scales horizontally."

---

### Demo 5: Real-Time Sentiment — "Voice of Customer Live"

#### Use Case

Your brand monitoring team wants to track customer sentiment in real-time. Reviews, social mentions, and support tickets flow in continuously. Cortex SENTIMENT scores each one, SUMMARIZE extracts key themes, and a Streamlit dashboard shows the live pulse.

#### Setup (Pre-Event)

```sql
-- Create sentiment demo table
CREATE OR REPLACE TABLE DEMO_AI_SUMMIT.CORTEX_ANALYST_DEMO.CUSTOMER_REVIEWS (
    review_id       INTEGER,
    source          VARCHAR(50),
    review_text     VARCHAR(5000),
    product_id      INTEGER,
    review_date     DATE,
    star_rating     INTEGER
);

-- Insert sample reviews (mix of positive, negative, neutral)
INSERT INTO DEMO_AI_SUMMIT.CORTEX_ANALYST_DEMO.CUSTOMER_REVIEWS VALUES
(1, 'App Store',    'Absolutely love this product. Setup was simple and the performance exceeded expectations. Best purchase this year.', 101, '2025-03-01', 5),
(2, 'Trustpilot',   'Decent product but the onboarding documentation is confusing. Took 3 calls to support before I got it working.', 102, '2025-03-01', 3),
(3, 'G2',           'Terrible experience. The product crashed during our quarterly review and we lost 2 hours of work. Will not renew.', 103, '2025-03-02', 1),
(4, 'App Store',    'Good value for money. Some features feel half-baked but the core functionality is solid. Looking forward to updates.', 101, '2025-03-02', 4),
(5, 'Twitter',      'Just switched from [Competitor] to this and the difference is night and day. Faster, cleaner, more intuitive.', 104, '2025-03-02', 5),
(6, 'Support',      'My account was charged twice and nobody from billing has responded in 5 days. This is unacceptable for an enterprise product.', 105, '2025-03-03', 1),
(7, 'Trustpilot',   'The API is well-designed and the documentation is thorough. Integration took less than a day.', 106, '2025-03-03', 5),
(8, 'G2',           'Product works fine but pricing increased 40% at renewal with no advance notice. Evaluating alternatives.', 107, '2025-03-03', 2),
(9, 'App Store',    'Reliable and consistent. No complaints after 6 months of daily use. The mobile app could use improvement.', 108, '2025-03-04', 4),
(10, 'Twitter',     'Outage during peak hours AGAIN. Third time this quarter. Starting to doubt the reliability claims.', 109, '2025-03-04', 1);
```

#### Demo Flow (12 min, Snowsight worksheet)

```
Step 1  Show raw reviews:
        SELECT * FROM CUSTOMER_REVIEWS ORDER BY review_date DESC;

        "10 reviews from various sources. Some positive, some negative.
         A human would take 5 minutes to read and categorize these."

Step 2  Run SENTIMENT on all reviews:
        SELECT
            review_id,
            source,
            LEFT(review_text, 80) || '...' AS review_preview,
            star_rating,
            ROUND(SNOWFLAKE.CORTEX.SENTIMENT(review_text), 3) AS sentiment_score
        FROM CUSTOMER_REVIEWS
        ORDER BY sentiment_score;

        "Instant. Every review scored from -1 (negative) to +1 (positive).
         Notice: the 1-star reviews score negative, the 5-stars positive,
         and the 3-star mixed reviews land near zero. The model gets nuance."

Step 3  Run SUMMARIZE to extract themes:
        SELECT SNOWFLAKE.CORTEX.SUMMARIZE(
            LISTAGG(review_text, ' | ') WITHIN GROUP (ORDER BY review_date)
        ) AS theme_summary
        FROM CUSTOMER_REVIEWS;

        "One function call summarizes all 10 reviews into key themes:
         product reliability, billing concerns, onboarding friction,
         positive API feedback."

Step 4  Show the production pattern:
        "In production, this runs as a Snowflake Task on a schedule.
         New reviews land via Snowpipe → SENTIMENT scores them →
         SUMMARIZE generates daily digests → a Streamlit dashboard
         shows the live pulse.

         The SQL is 5 lines. The pipeline is 3 objects (stream, task,
         target table). No ML team, no model training, no inference
         server."

Step 5  Show SENTIMENT on a custom text (visitor interaction):
        "Give me a sentence about a product — anything."
        [Visitor says something]
        SELECT SNOWFLAKE.CORTEX.SENTIMENT('[visitor text]');

        "Real-time, any text, any language. That's a function call,
         not an ML pipeline."
```

#### Talk Track Highlights

- **Cost:** "SENTIMENT and SUMMARIZE are Cortex LLM functions — serverless, per-call pricing. No GPU reservation, no model hosting."
- **vs Third-party sentiment tools:** "No data export. No API key management. No latency from round-tripping to an external service. It's a SQL function."
- **Scale:** "This works on 10 reviews or 10 million. The function parallelizes across Snowflake's compute."

---

### Demo 6: Arctic / Mosaic — "AI Without Bill Shock"

#### Use Case

An enterprise customer is evaluating LLM deployment options. They've seen the hyperscaler pricing ($20+ per million tokens for GPT-4-class models) and are nervous about production costs. Snowflake Arctic — born from the Mosaic ML acquisition — offers enterprise-grade inference at significantly lower cost.

#### Setup (Pre-Event)

```sql
-- Create a comparison table for cost storytelling
CREATE OR REPLACE TABLE DEMO_AI_SUMMIT.CORTEX_ANALYST_DEMO.LLM_COST_COMPARISON (
    model_name      VARCHAR(100),
    provider        VARCHAR(50),
    task            VARCHAR(100),
    input_tokens    INTEGER,
    output_tokens   INTEGER,
    cost_per_1m_input  NUMBER(10,4),
    cost_per_1m_output NUMBER(10,4),
    latency_ms      INTEGER,
    quality_score   NUMBER(5,2)
);

INSERT INTO LLM_COST_COMPARISON VALUES
('GPT-4o',            'OpenAI (via Azure)', 'SQL Generation',     500, 200, 5.00,  15.00, 2800, 92.5),
('GPT-4o',            'OpenAI (via Azure)', 'Text Summarization', 2000, 300, 5.00,  15.00, 3500, 94.0),
('Claude 3.5 Sonnet', 'Anthropic (via AWS)', 'SQL Generation',    500, 200, 3.00,  15.00, 2200, 93.0),
('Claude 3.5 Sonnet', 'Anthropic (via AWS)', 'Text Summarization',2000, 300, 3.00,  15.00, 2800, 93.5),
('Llama 3.1 70B',     'Snowflake Cortex',   'SQL Generation',     500, 200, 0.00,   0.00, 1500, 88.0),
('Llama 3.1 70B',     'Snowflake Cortex',   'Text Summarization', 2000, 300, 0.00,   0.00, 1800, 87.5),
('Arctic',            'Snowflake Cortex',   'SQL Generation',     500, 200, 0.00,   0.00, 1200, 86.0),
('Arctic',            'Snowflake Cortex',   'Text Summarization', 2000, 300, 0.00,   0.00, 1400, 85.0);

-- NOTE: Cortex models use credit-based pricing (included in your Snowflake
-- compute spend), not per-token pricing. The $0.00 above represents that
-- there's no ADDITIONAL per-token charge — you pay via warehouse/serverless credits.
-- Adjust these numbers to reflect current Snowflake pricing at event time.
```

#### Demo Flow (10 min, Snowsight worksheet)

```
Step 1  Frame the problem:
        "Your team wants to deploy LLM-powered features — SQL generation,
         document summarization, sentiment analysis. You call Azure OpenAI
         or AWS Bedrock. What does that cost at scale?"

Step 2  Show the cost comparison:
        SELECT model_name, provider, task,
               cost_per_1m_input AS input_cost,
               cost_per_1m_output AS output_cost,
               latency_ms,
               quality_score
        FROM LLM_COST_COMPARISON
        ORDER BY task, cost_per_1m_input DESC;

        "External models: $3-15 per million tokens, plus egress,
         plus API gateway, plus credential management.
         Cortex models: bundled into your Snowflake compute.
         No per-token surprise."

Step 3  Run the same task on multiple models:
        -- External model (if configured) vs Cortex model
        SELECT 'llama3.1-70b' AS model,
               SNOWFLAKE.CORTEX.COMPLETE(
                   'llama3.1-70b',
                   'Write a SQL query to find the top 5 customers by revenue from a table called SALES_FACT with columns customer_id and amount.'
               ) AS result;

        SELECT 'snowflake-arctic' AS model,
               SNOWFLAKE.CORTEX.COMPLETE(
                   'snowflake-arctic',
                   'Write a SQL query to find the top 5 customers by revenue from a table called SALES_FACT with columns customer_id and amount.'
               ) AS result;

        "Both produce valid SQL. Quality difference is marginal for
         enterprise tasks like SQL generation and summarization.
         The cost difference is significant at scale."

Step 4  Calculate scale impact:
        "Assume 10,000 Cortex Analyst queries per month (modest for
         a 500-person analytics org).

         External LLM:
           10,000 queries × ~700 tokens avg × $15/1M output tokens
           = ~$105/month in token cost alone
           + API gateway + egress + credential rotation

         Cortex (bundled):
           Included in your existing Snowflake serverless compute.
           No incremental per-token billing.
           No data leaves your VPC.

         The real savings aren't in the token cost — they're in the
         infrastructure you DON'T build: no API gateway, no secrets
         manager, no data egress pipeline, no model hosting."

Step 5  Close: "Arctic and Llama on Cortex give you 85-90% of
        GPT-4 quality for enterprise tasks, at a fraction of the
        operational cost, with zero data movement. For most
        production use cases, that's the right trade-off."
```

#### Talk Track Highlights

- **Acknowledge the quality gap honestly:** "GPT-4 is the best general-purpose model. For enterprise-specific tasks — SQL generation, document Q&A, summarization — the gap narrows significantly. And you can fine-tune Cortex models on your domain to close it further."
- **Total cost, not token cost:** "The per-token price is one line item. The bigger costs are infrastructure: API gateways, egress, credential management, latency overhead, compliance audits for data leaving your perimeter."
- **Mosaic / Arctic story:** "Snowflake acquired Mosaic ML to build models purpose-built for enterprise data tasks. Arctic is optimized for SQL understanding, structured data reasoning, and efficient inference. It's not trying to be GPT-4 — it's trying to be the best model for your data platform."

---

### Tier 2 — Scheduling & Logistics

| Slot | Time | Demo | Owner | Triggered By |
|------|------|------|-------|-------------|
| Day 1, Slot 1 | 13:00-13:15 | RAG Knowledge Base | Owner 3 | Walk-in / post-Demo-3 interest |
| Day 1, Slot 2 | 15:50-16:05 | Sentiment Pipeline | Owner 2 | Walk-in / post-Demo-1 interest |
| Day 2, Slot 1 | 13:00-13:15 | Arctic Cost Comparison | Owner 2 | Returning visitor / cost question |
| Day 2, Slot 2 | 15:50-16:05 | RAG Knowledge Base | Owner 3 | Pre-booked / account team referral |
| Day 3, Slot 1 | 13:00-13:15 | Sentiment Pipeline | Owner 2 | Pre-booked |
| Day 3, Slot 2 | 15:50-16:05 | Arctic Cost Comparison | Owner 2 | Pre-booked / hot lead follow-up |

**Booking method:** Sign-up sheet at the literature rack, or station owner offers during a Tier 1 demo: "Want to go deeper? I have a 15-minute slot at 1 PM at the side table."

---

## 7. Demo Track: Tier 3 — Optional / Bonus

### Overview

Tier 3 demos are **not pre-built** — they're talking points backed by quick Snowsight worksheet demos that any station owner can pull up on request. No dedicated Streamlit app, no rehearsed flow. These exist for the 5% of visitors who ask "What else can Cortex do?" after seeing Tier 1 and 2.

**When to use:** Only when a visitor explicitly asks, or when a deep-dive conversation naturally leads here. Never proactively offer Tier 3 at the main stations — it dilutes the hero message.

---

### Demo 7: Cortex Fine-Tuning — "Your Model, Your Data"

**Setup:** Pre-run a fine-tuning job on a small domain-specific dataset (e.g., internal SLA definitions). Store the fine-tuned model reference.

**Quick demo (2-3 min, Snowsight worksheet):**

```sql
-- Generic model: vague answer
SELECT SNOWFLAKE.CORTEX.COMPLETE(
    'llama3.1-8b',
    'What is the standard SLA for Tier 2 enterprise customers?'
) AS generic_answer;

-- Fine-tuned model: precise, domain-specific answer
SELECT SNOWFLAKE.CORTEX.COMPLETE(
    'ft:llama3.1-8b:your-fine-tuned-model-id',
    'What is the standard SLA for Tier 2 enterprise customers?'
) AS finetuned_answer;
```

**Talk track:**
> "Same question, two models. The generic one guesses. The fine-tuned one knows your SLA definitions because it was trained on your internal docs. You own the model, the data never left Snowflake, and the fine-tuning job runs as a SQL command."

**Persona fit:** Engineers, data leaders who care about model ownership and data privacy.

---

### Demo 8: Cortex TRANSLATE — "Three Languages in 3 Seconds"

**Setup:** None beyond having Cortex functions enabled.

**Quick demo (1 min, Snowsight worksheet):**

```sql
SELECT
    'Either party may terminate this Agreement upon ninety (90) days prior written notice.'
        AS original_english,
    SNOWFLAKE.CORTEX.TRANSLATE(original_english, 'en', 'de') AS german,
    SNOWFLAKE.CORTEX.TRANSLATE(original_english, 'en', 'ja') AS japanese,
    SNOWFLAKE.CORTEX.TRANSLATE(original_english, 'en', 'es') AS spanish;
```

**Talk track:**
> "One SQL function, three languages, instant. For global contracts, compliance docs, or customer communications — translation is a function call, not a vendor engagement."

**Persona fit:** CXOs with global operations, compliance teams with multi-jurisdiction requirements.

---

### Demo 9: Universal Search — "Find Anything in Your Data Estate"

**Setup:** Ensure `ENABLE_UNIVERSAL_SEARCH` is active on the account (account-level parameter).

**Quick demo (2 min, Snowsight UI):**

```
Step 1  Open Snowsight search bar (top of page).
Step 2  Type: "sales data by region"
Step 3  Universal Search returns:
        - SALES_FACT table
        - DIM_REGION table
        - Cortex Analyst semantic model
        - Relevant Streamlit apps
        All ranked by relevance, not just name matching.
```

**Talk track:**
> "Every table, view, stage, policy, and app in your Snowflake account — searchable by meaning, not just name. For data discovery and governance, this is how you find what you didn't know existed."

**Persona fit:** Data leaders focused on governance and discoverability.

---

### Tier 3 Summary

| Demo | Duration | Setup Required | Best For |
|------|----------|---------------|----------|
| Fine-tuning | 2-3 min | Pre-run fine-tuning job + save model ID | Engineers, data leaders |
| Translate | 1 min | None (Cortex functions enabled) | Global ops, compliance |
| Universal Search | 2 min | Account-level search enabled | Governance, discovery |

**Rule of thumb:** If a visitor hasn't seen at least one Tier 1 demo, don't show Tier 3. These are depth amplifiers, not standalone stories.

---

## 8. Streamlit App Skeletons

### Overview

All three Tier 1 demos run as **Streamlit in Snowflake** apps — no external servers, no API gateways, no infrastructure outside Snowflake. Each app is a single `.py` file you paste into Snowsight's Streamlit editor.

**Files:** `streamlit_apps/` — These are complete, runnable `.py` files included in this project. Copy-paste the full file content into Snowsight's Streamlit editor. Do NOT copy from the doc — use the actual files.

| App | File | Station | Lines | Key Dependencies |
|-----|------|---------|-------|-----------------|
| Cortex Analyst | `app_cortex_analyst.py` | A — Main Screen | ~280 | `_snowflake.send_message`, Semantic Model YAML |
| Data Agent | `app_data_agent.py` | B — Agent Screen | ~350 | Cortex Agent API (live) or replay cache (fallback) |
| Document AI | `app_document_ai.py` | C — Interactive | ~330 | `snowflake.core.Root` for Cortex Search, pre-loaded data |

### Architecture Pattern

All three apps follow the same structure:

```
┌─────────────────────────────────────────────────────────────┐
│                    STREAMLIT IN SNOWFLAKE                    │
│                                                             │
│  1. Imports & Session                                       │
│     └── get_active_session() — no credentials needed        │
│                                                             │
│  2. Configuration                                           │
│     └── Constants: DB, schema, stage, model paths           │
│     └── Fallback data: cached responses for offline mode    │
│                                                             │
│  3. Page Layout                                             │
│     └── set_page_config + custom CSS for booth visibility   │
│     └── Branded header (gradient bar, large font)           │
│                                                             │
│  4. Session State                                           │
│     └── Chat history, extraction results, search results    │
│     └── Mode toggles (live/replay, compare on/off)          │
│                                                             │
│  5. Core Integration (Cortex Analyst / Agent / Search)      │
│     └── Primary function: call Snowflake service            │
│     └── Try/except wrapping with fallback path              │
│                                                             │
│  6. Fallback Engine                                         │
│     └── Cached responses, keyword matching, replay mode     │
│     └── Ensures demo works even if Cortex service is down   │
│                                                             │
│  7. UI Rendering                                            │
│     └── Chat messages, data tables, charts, progress steps  │
│     └── Sidebar: Reset, mode toggle, sample prompts         │
│                                                             │
│  8. Footer                                                  │
│     └── Attribution, current mode, "no data leaves SF"      │
└─────────────────────────────────────────────────────────────┘
```

### Deployment Steps

```
Step 1   Open Snowsight → Streamlit → + Streamlit App
Step 2   Name: "Demo_Cortex_Analyst" (or Agent / Document_AI)
Step 3   Warehouse: DEMO_AI_WH
Step 4   Database: DEMO_AI_SUMMIT
Step 5   Schema: CORTEX_ANALYST_DEMO (or DOC_AI_DEMO for Demo 3)
Step 6   Paste the full .py file content into the editor
Step 7   Click "Run" — app renders in preview
Step 8   Share URL with booth team for testing
```

**Repeat for all 3 apps.** Each runs independently in its own schema context.

---

### App 1: Cortex Analyst — `app_cortex_analyst.py`

**Full source:** `streamlit_apps/app_cortex_analyst.py` (~280 lines)

**How it works:**

```
Visitor types question
        │
        ▼
┌──────────────────┐     ┌──────────────────┐
│  Fallback Mode?  │──No─▶│  _snowflake      │
│  (sidebar toggle)│      │  .send_message() │
└────────┬─────────┘      │  "analyst"       │
         │ Yes            └────────┬─────────┘
         ▼                         │
┌──────────────────┐               ▼
│  Keyword match   │      ┌──────────────────┐
│  against cached  │      │  Parse response: │
│  CACHED_RESPONSES│      │  summary + SQL   │
└────────┬─────────┘      │  + data          │
         │                └────────┬─────────┘
         ▼                         │
┌──────────────────────────────────┘
│  Render: summary → SQL (expander) → dataframe → auto-chart
└──────────────────────────────────────────────────────────────
```

**Key implementation details:**

- **Cortex Analyst call:** Uses `_snowflake.send_message("analyst", payload)` — the `_snowflake` module is only available inside Streamlit in Snowflake. The payload includes the full conversation history (multi-turn) and semantic model file path.

- **Fallback:** `CACHED_RESPONSES` dict maps keyword patterns to pre-built responses. If Cortex Analyst times out or errors, the app auto-falls back to cached responses and shows a caption explaining the fallback. Station owner can also force fallback via sidebar toggle.

- **Challenge cards:** Sidebar buttons pre-fill the chat input with visitor challenge questions (the 5 laminated cards from Section 5). One click → question appears → Cortex Analyst answers.

- **Auto-charting:** After rendering the data table, the app detects numeric columns and auto-generates a `st.bar_chart`. No manual chart configuration needed.

- **Reset:** "Reset Demo" button clears `st.session_state.messages` and calls `st.rerun()`. < 1 second between visitors.

**Prerequisite:** The semantic model YAML must be staged before the app runs:

```sql
-- Stage the semantic model file
CREATE OR REPLACE STAGE DEMO_AI_SUMMIT.CORTEX_ANALYST_DEMO.SEMANTIC_MODELS
    DIRECTORY = (ENABLE = TRUE);

-- PUT the YAML file (run from SnowSQL or Snowsight upload)
-- PUT file://cortex_analyst_demo.yaml @DEMO_AI_SUMMIT.CORTEX_ANALYST_DEMO.SEMANTIC_MODELS;
```

---

### App 2: Data Agent — `app_data_agent.py`

**Full source:** `streamlit_apps/app_data_agent.py` (~350 lines)

**How it works:**

```
Station owner types investigation question
        │
        ▼
┌──────────────────┐     ┌──────────────────┐
│  Mode: replay?   │──No─▶│  run_live_agent()│
│  (sidebar radio) │      │  Cortex Agent API│
└────────┬─────────┘      └────────┬─────────┘
         │ Yes                     │
         ▼                         │ Fail?──▶ Auto-fallback to replay
┌──────────────────┐               │
│  run_replay()    │               ▼
│  Cached steps    │      ┌──────────────────┐
│  with timing:    │      │  Stream steps    │
│  2s/step         │      │  to UI           │
│  3s summary      │      └──────────────────┘
└────────┬─────────┘
         │
         ▼
┌──────────────────────────────────────────────────┐
│  Render: step progress → data tables → summary   │
│  ✅ Step 1: Revenue comparison (2s)               │
│  ✅ Step 2: Regional breakdown (2s)               │
│  ✅ Step 3: Campaign analysis (2s)                │
│  ✅ Step 4: Churn signals (2s)                    │
│  ✅ Step 5: Summary generation (3s)               │
│  ─────────────────────────────────                │
│  ROOT CAUSE: ...                                  │
│  RECOMMENDATIONS: ...                             │
└──────────────────────────────────────────────────┘
```

**Key implementation details:**

- **Dual mode:** `st.radio` in sidebar toggles between "Replay (cached)" and "Live (Cortex Agent)". Default is Replay — safe for uncertain Agent GA status. Station owner switches to Live if confirmed working.

- **Replay engine:** `run_replay()` iterates through `REPLAY_CACHE` steps with `time.sleep()` for realistic pacing. Each step renders progressively: completed steps show ✅ + data table, current step shows ⏳, pending steps show ⬜. Total replay time: ~11 seconds (4×2s + 1×3s).

- **Live agent:** `run_live_agent()` calls the Cortex Agent API via `_snowflake.send_message("agent", payload)`. If the API call fails, it automatically falls back to replay with a warning message.

- **Investigation summary:** Rendered as a structured card with severity indicators (🔴 HIGH / 🟢 LOW), numbered findings, and bulleted recommendations.

- **Reset:** Clears all investigation state. App returns to empty input prompt.

**Important — replay cache is embedded in the .py file.** For a production deployment, you could load it from a Snowflake table or a staged JSON file. For the demo, inline is simpler and has zero dependencies.

---

### App 3: Document AI + Cortex Search — `app_document_ai.py`

**Full source:** `streamlit_apps/app_document_ai.py` (~330 lines)

**How it works:**

```
┌─────────────────────────┬─────────────────────────┐
│    LEFT PANEL           │    RIGHT PANEL          │
│    Upload & Extract     │    Semantic Search      │
├─────────────────────────┼─────────────────────────┤
│                         │                         │
│  Select doc ──▶ Click   │  Type query ──▶ Click   │
│  "Process Document"     │  "Search"               │
│       │                 │       │                 │
│       ▼                 │       ▼                 │
│  simulate_extraction()  │  semantic_search()      │
│  1.5s delay, then show: │  Cortex Search service  │
│  ┌──────────────────┐   │  ┌──────────────────┐   │
│  │ Parties: A ↔ B   │   │  │ Section 8.2      │   │
│  │ Date: 2024-01-15 │   │  │ Score: 0.94      │   │
│  │ Value: $2.4M     │   │  │ "Either party..." │   │
│  │ Terms: Net 30    │   │  └──────────────────┘   │
│  └──────────────────┘   │                         │
│                         │  [Compare toggle ON?]   │
│                         │       │ Yes             │
│                         │       ▼                 │
│                         │  keyword_search()       │
│                         │  LIKE '%termination%'   │
│                         │  → 0 results!           │
│                         │  (semantic wins)        │
└─────────────────────────┴─────────────────────────┘
```

**Key implementation details:**

- **Two-panel layout:** `st.columns([1, 1])` splits the screen. Left panel = document selection + extraction results. Right panel = search interface + results. Both panels work independently.

- **Simulated upload:** The "Process Document" button triggers `simulate_extraction()` which pulls from the `PRELOADED_DOCS` dict (pre-loaded in Script 06). A 1.5-second `time.sleep()` simulates processing. The data is already in the database — the "upload" is cosmetic.

- **Cortex Search:** Uses `snowflake.core.Root` → `databases` → `schemas` → `cortex_search_services` → `.search()`. Returns ranked results with relevance scores. Falls back to LIKE query if the `snowflake.core` import fails.

- **Compare mode:** Sidebar toggle enables side-by-side display. When active, every search runs both `semantic_search()` and `keyword_search()`. The UI highlights the gap — e.g., searching "termination clause" via LIKE won't find the "early exit provisions" chunk, but Cortex Search will (semantic match). A green success banner explains why.

- **Sample questions:** Sidebar buttons pre-fill the search input with demo-ready questions aligned to the planted document text from Script 06.

- **Reset:** Clears extraction state, search results, and compare mode.

**Prerequisite:** Cortex Search service must be created (Script 07) and healthy before the app runs. Check with:

```sql
SHOW CORTEX SEARCH SERVICES IN SCHEMA DEMO_AI_SUMMIT.DOC_AI_DEMO;
-- Expect: DOCUMENTS_SEARCH_SERVICE with status = 'ACTIVE'
```

---

### Cross-App Standards

These patterns are consistent across all three apps:

| Pattern | Implementation |
|---------|---------------|
| **Session management** | `get_active_session()` — no credentials, no connection strings |
| **Booth CSS** | Gradient header bar, 1.1rem chat font, high-contrast for projector/screen |
| **Reset button** | Sidebar, `type="primary"`, clears `st.session_state`, calls `st.rerun()` |
| **Fallback** | Every Cortex call wrapped in try/except with cached alternative |
| **Footer** | Shows current mode, service name, "no data leaves Snowflake" |
| **No external imports** | Only `streamlit`, `json`, `time`, `pandas`, and Snowflake-native modules |

### Streamlit in Snowflake Pitfalls

| Pitfall | Mitigation |
|---------|-----------|
| `_snowflake` module not available locally | Conditional import with `try/except`. Test locally with `FALLBACK_MODE = True`. |
| `st.rerun()` causes full page reload | Use `st.session_state` to persist data across reruns. All intermediate results are stored. |
| `time.sleep()` blocks the UI thread | Acceptable for demo (short delays: 1.5-3s). For production, use async patterns. |
| Large dataframes slow rendering | Limit all queries to reasonable row counts. SALES_FACT queries should include `LIMIT` or aggregation. |
| CSS may render differently on projectors | Test on actual booth screen at T-1. Adjust font sizes in the `<style>` block if needed. |
| Snowflake session timeout during idle | Warehouse auto-resume handles this. But if the app is idle >4 hours, station owner may need to reload. |

---

## 9. Booth Operations Plan

### Concept

Three people, three stations, three days, 300+ visitors. This section covers the physical layout, rotation model, daily cadence, escalation strategy, and contingency protocols that keep the booth running smoothly from open to close.

**Operating principles:**
1. **Every station is always staffed.** No dark screens. No "be right back." If someone takes a break, the other two cover.
2. **Every visitor gets a demo within 60 seconds of arriving.** No queuing, no waiting. If all three stations are occupied, the next available owner greets and holds.
3. **Escalate, don't repeat.** Day 1 is broad (hero demos for everyone). Day 2 shifts to depth (deep-dives for returning visitors). Day 3 is conversion (leads, follow-ups, scheduled meetings).
4. **Reset between visitors.** One click, < 3 seconds. The next visitor sees a clean screen, not the previous person's questions.

---

### Booth Layout

```
┌──────────────────────────────────────────────────────────────────────┐
│                          BOOTH FRONTAGE                              │
│                    (visitors approach from here)                      │
│                                                                      │
│  ┌─────────────┐    ┌──────────────┐    ┌─────────────────┐         │
│  │  STATION A   │    │  STATION B    │    │  STATION C       │         │
│  │             │    │              │    │                 │         │
│  │  ┌───────┐  │    │  ┌────────┐  │    │  ┌───────────┐  │         │
│  │  │ 55"   │  │    │  │ 42"    │  │    │  │ 32" touch │  │         │
│  │  │ screen│  │    │  │ screen │  │    │  │ screen    │  │         │
│  │  └───────┘  │    │  └────────┘  │    │  └───────────┘  │         │
│  │             │    │              │    │                 │         │
│  │  Cortex     │    │  Data Agent  │    │  Document AI   │         │
│  │  Analyst    │    │  "Autonomous │    │  + Cortex      │         │
│  │  "Talk to   │    │   Analyst"   │    │  Search        │         │
│  │  Your Data" │    │              │    │  "Paper to     │         │
│  │             │    │              │    │   Insight"     │         │
│  │  Owner 1    │    │  Owner 2     │    │  Owner 3       │         │
│  └─────────────┘    └──────────────┘    └─────────────────┘         │
│                                                                      │
│       ┌──────────────────────────┐                                   │
│       │  SIDE TABLE              │    ┌────────────────────┐         │
│       │  Deep-dive seating       │    │  LITERATURE RACK   │         │
│       │  (2-3 chairs + laptop)   │    │  Leave-behinds     │         │
│       │  Tier 2 scheduled demos  │    │  1-pagers          │         │
│       └──────────────────────────┘    │  QR code cards     │         │
│                                       └────────────────────┘         │
│                                                                      │
│       ┌──────────────────────────┐                                   │
│       │  CHALLENGE CARD STAND    │                                   │
│       │  5 laminated cards       │                                   │
│       │  "Pick a question, test  │                                   │
│       │   the AI"                │                                   │
│       └──────────────────────────┘                                   │
│                                                                      │
│  [POWER/NETWORK]  Dedicated Wi-Fi AP or ethernet                     │
│  [BACKUP LAPTOP]  Pre-loaded with screen recordings                  │
└──────────────────────────────────────────────────────────────────────┘
```

**Station sizing:**
- **Station A (Hero):** Largest screen (55"). Highest traffic. Faces the aisle for maximum visibility. Cortex Analyst running with the chat interface visible from 10 feet away.
- **Station B (Wow):** Mid-size screen (42"). Data Agent reasoning chain renders well at this size. Positioned center for visitors who linger.
- **Station C (Interactive):** Touchscreen (32") or laptop on a stand. Visitors can tap/type directly. Document upload + search is hands-on.
- **Side Table:** 2-3 chairs for scheduled deep-dives (Tier 2 demos). Owner rotates here for 10-15 min pre-booked sessions.

**Equipment checklist:**
- [ ] 3 screens (55", 42", 32" or equivalent)
- [ ] 3 laptops (one per station, logged into Snowsight)
- [ ] 1 backup laptop (pre-loaded with screen recordings + offline fallbacks)
- [ ] Dedicated network (event Wi-Fi or mobile hotspot as backup)
- [ ] Power strips + cable management (tape down all cables)
- [ ] Challenge card stand + 20 laminated cards (spares for theft/loss)
- [ ] Literature rack with leave-behinds + QR code cards
- [ ] Phone chargers (booth owners will be standing all day)

---

### Team Roles

| Role | Person | Primary Station | Responsibility |
|------|--------|-----------------|----------------|
| **Owner 1** (Lead) | [Name] | Station A — Cortex Analyst | Hero demo, visitor greeting, lead capture. Owns the "first 60 seconds" for every walk-up. Escalates technical visitors to Owner 2. |
| **Owner 2** (Technical) | [Name] | Station B — Data Agent | Agent deep-dive, technical Q&A, architecture questions. Handles visitors who ask "how does this work under the hood?" |
| **Owner 3** (Interactive) | [Name] | Station C — Document AI | Hands-on demo, document search, side-table deep-dives. Handles visitors who want to type/try things themselves. |

**Role flexibility:** Every owner must be able to run all three demos. Cross-training happens during the T-2 dry run. If someone is sick on Day 2, the other two cover all stations with the lower-traffic station on auto-loop (screen recording).

---

### Daily Schedule

Standard event day: 9:00 AM - 5:00 PM (8 hours, adjust to actual event times).

```
 TIME          ACTIVITY                          WHO
 ─────────────────────────────────────────────────────────
 08:00-08:30   Arrive, power on, network check   All 3
 08:30-08:45   Morning warm-up run               All 3
               - Each owner runs their demo once
               - Verify Cortex services healthy
               - Check fallback recordings load
               - Confirm "Reset Demo" works
 08:45-09:00   Huddle: today's goals, leads       All 3
               from yesterday, any issues
 ─────────────────────────────────────────────────────────
 09:00-11:00   BLOCK 1: Peak morning traffic      Stations staffed
               - All 3 stations active
               - Owner 1 greeting walk-ups
               - 3-5 min hero demos
 ─────────────────────────────────────────────────────────
 11:00-11:20   BREAK A: Owner 3 breaks            Owner 1+2 cover
               - Station C on auto-loop recording
               - Owner 1 covers greeting
               - Owner 2 covers Agent + overflow
 11:20-11:40   BREAK B: Owner 1 breaks            Owner 2+3 cover
               - Station A on auto-loop recording
               - Owner 2 shifts to greeting
 11:40-12:00   BREAK C: Owner 2 breaks            Owner 1+3 cover
               - Station B on auto-loop recording
 ─────────────────────────────────────────────────────────
 12:00-13:00   LUNCH ROTATION                     2 on, 1 off
               - 12:00-12:30: Owner 1 at lunch
               - 12:30-13:00: Owner 2 at lunch
               - Owner 3 takes lunch 13:00-13:30
               (during post-lunch slower period)
               NOTE: Never fewer than 2 people at booth
 ─────────────────────────────────────────────────────────
 13:00-13:30   DEEP-DIVE SLOT 1                   Owner 3 at table
               - Pre-scheduled 15-min deep-dive
               - Tier 2 demo (Cortex Search RAG
                 or Sentiment pipeline)
               - Owner 1+2 handle hero stations
 ─────────────────────────────────────────────────────────
 13:30-15:30   BLOCK 2: Afternoon traffic          Stations staffed
               - All 3 stations active
               - Same hero demo cadence
 ─────────────────────────────────────────────────────────
 15:30-15:50   BREAK rotation (same as morning)
 ─────────────────────────────────────────────────────────
 15:50-16:30   DEEP-DIVE SLOT 2                   Owner 2 at table
               - Pre-scheduled or walk-in
               - Tier 2 demo (Fine-tuning or
                 Arctic cost comparison)
 ─────────────────────────────────────────────────────────
 16:30-17:00   FINAL BLOCK                        All 3
               - Last push for visitors
               - Lead capture for anyone lingering
               - Hand out leave-behinds
 ─────────────────────────────────────────────────────────
 17:00-17:15   Shutdown                           All 3
               - Lock screens (don't log out)
               - Collect challenge cards
               - Quick debrief: leads, issues, plan
                 for tomorrow
 17:15-17:30   Lead log entry                     Owner 1
               - Enter all captured leads/contacts
                 into shared spreadsheet or CRM
 ─────────────────────────────────────────────────────────
```

---

### Visitor Cadence (Per Interaction)

**Walk-up (3-5 minutes) — 80% of interactions:**

```
 0:00  Visitor arrives. Owner greets within 5 seconds:
       "Hi — want to see AI answer a question about your data live?"

 0:15  Quick context: "This is Cortex Analyst — you type a question
       in plain English, it generates SQL, runs it, and gives you
       the answer. No BI tool, no dashboard. Try it."

 0:30  Hand the visitor a challenge card, or ask:
       "What would you ask about your sales data?"

 0:45  Visitor types (or owner types for them). Cortex Analyst returns.

 1:30  Show the result. Highlight: summary + SQL + chart.
       "That's live — no pre-canned response."

 2:00  Follow-up question (owner-prompted):
       "Now ask WHY. Watch it join two tables automatically."

 3:00  Close: "This runs inside Snowflake. No data leaves.
       Your semantic layer, your governance, your security."

 3:30  Bridge to next station (if visitor is interested):
       "Want to see the AI investigate a problem autonomously?
       My colleague at Station B can show you."

 4:00  Hand leave-behind. Capture contact if warm lead.

 4:30  Reset demo. Ready for next visitor.
```

**Engaged visitor (10-15 minutes) — 15% of interactions:**

```
 0:00-3:00   Same as walk-up (hero demo).

 3:00        Visitor asks deeper questions. Owner gauges interest:
             - "How does the semantic model work?" → Technical path
             - "Can my team use this tomorrow?" → Business path
             - "What about governance?" → Architecture path

 3:30        Transition to Station B or side table:
             "Let me show you the agent — it goes beyond single
             questions into multi-step investigations."

 3:30-8:00   Agent demo OR side-table deep-dive.

 8:00-10:00  Document AI demo (if time allows).

 10:00       Close: collect contact, schedule follow-up,
             hand leave-behind + QR code.
```

**Pre-scheduled deep-dive (15 minutes) — 5% of interactions:**

```
 Reserved at the side table. Owner 2 or 3 runs a Tier 2 demo:
 - Cortex Search RAG enterprise knowledge base
 - Sentiment analysis pipeline with Streamlit dashboard
 - Arctic/Mosaic cost comparison
 - Fine-tuning before/after

 Scheduled via sign-up sheet at literature rack or pre-booked
 by account team.
```

---

### 3-Day Escalation Strategy

The booth's mission evolves across the three days:

```
┌──────────────────────────────────────────────────────────────────┐
│                                                                  │
│  DAY 1: AWARENESS                                                │
│  ─────────────────                                               │
│  Goal: Maximum reach. Every visitor sees at least one hero demo. │
│                                                                  │
│  Focus:                                                          │
│  • Hero demos only (Tier 1)                                      │
│  • High throughput: 3-5 min per visitor                           │
│  • Challenge cards to drive engagement                            │
│  • Collect business cards / scan badges                           │
│  • Note "return visitors" who ask for more depth                  │
│                                                                  │
│  Target: 80-120 visitor touchpoints                               │
│  Deep-dives: 2-3 (walk-in only, no pre-scheduled)                │
│  Lead quality: Broad — names and interest signals                 │
│                                                                  │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  DAY 2: DEPTH                                                    │
│  ─────────────                                                   │
│  Goal: Convert Day 1 interest into deeper engagement.            │
│                                                                  │
│  Focus:                                                          │
│  • Hero demos for new visitors (still 60% of traffic)            │
│  • Tier 2 deep-dives for returning visitors                      │
│  • Side-table sessions: RAG, Sentiment, Fine-tuning              │
│  • Architecture discussions for data leaders                     │
│  • "How would this work for [their use case]?" conversations     │
│                                                                  │
│  Target: 60-90 touchpoints (fewer, deeper)                        │
│  Deep-dives: 4-6 (mix of pre-scheduled + walk-in)                │
│  Lead quality: Warmer — specific use cases identified             │
│                                                                  │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  DAY 3: CONVERSION                                               │
│  ────────────────                                                │
│  Goal: Turn warm leads into scheduled follow-ups.                │
│                                                                  │
│  Focus:                                                          │
│  • Hero demos for final wave of new visitors                     │
│  • Returning visitors get direct-to-deep-dive                    │
│  • Owner 1 focuses on lead capture + meeting scheduling          │
│  • "Let's set up a PoC call for your team" conversations         │
│  • Leave-behinds pushed aggressively                             │
│                                                                  │
│  Target: 40-70 touchpoints                                        │
│  Deep-dives: 4-8 (mostly pre-scheduled by returning visitors)    │
│  Lead quality: Hottest — meetings booked, PoC interest           │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

**Estimated 3-day totals:**

| Metric | Day 1 | Day 2 | Day 3 | Total |
|--------|-------|-------|-------|-------|
| Visitor touchpoints | 80-120 | 60-90 | 40-70 | 180-280 |
| Deep-dive sessions | 2-3 | 4-6 | 4-8 | 10-17 |
| Leads captured | 30-50 | 25-40 | 20-35 | 75-125 |
| Meetings booked | 0-2 | 3-5 | 5-10 | 8-17 |

> **Note:** 300+ visitors doesn't mean 300+ interactions. Many visitors browse without stopping. Realistic interactive touchpoint rate for a 3-person booth is 60-120/day depending on event traffic patterns.

---

### Handoff Protocol

When a visitor needs to move between stations:

```
Owner 1 (Station A):
  "Great question — you'd want to see how the agent handles
   multi-step problems. [Name/Owner 2], can you show [visitor]
   the Q3 investigation?"

Owner 2 (Station B):
  "Hey! So you've seen Cortex Analyst handle single questions —
   let me show you what happens when you ask it to investigate
   something bigger."
```

**Rules:**
- Always **introduce the next owner by name** (builds trust).
- Always **bridge context** ("you've seen X, now let me show you Y").
- Never say "go talk to my colleague over there" — **physically walk them** if the booth is large enough.
- If the next station is occupied, **hold the visitor** with a quick overview of what they'll see next: "While they finish up, let me tell you what the agent does differently..."

---

### Break Coverage Matrix

With 3 people, one can always break while two cover all stations. The uncovered station goes to **auto-loop mode** (screen recording with "Back in 5 minutes" overlay).

| Who's on break | Station A | Station B | Station C |
|----------------|-----------|-----------|-----------|
| Owner 1 | Auto-loop | Owner 2 | Owner 3 |
| Owner 2 | Owner 1 | Auto-loop | Owner 3 |
| Owner 3 | Owner 1 | Owner 2 | Auto-loop |
| Lunch (1 out) | Owner on duty | Owner on duty | Auto-loop (lowest traffic station) |

**Auto-loop setup:**
- Pre-recorded screen capture of the full demo flow (90-120 seconds, looped)
- Small sign on the screen: "Live demo available — ask the team!"
- The recording keeps the station visually active and draws walk-ups
- **QR code overlay** (bottom-right corner of every screen, live or auto-loop): Links to a 3-minute recorded hero demo reel hosted on your company's video platform or a public Loom/YouTube unlisted link. Same QR appears on the leave-behind 1-pager (Section 11). Visitors who walk by without stopping still capture the link.

---

### Lead Capture

**Method:** Keep it lightweight. Heavy lead-capture forms kill booth energy.

| Tier | Capture Method | When |
|------|---------------|------|
| Cold (browsed, didn't engage) | Badge scan only | Walk-by |
| Warm (watched demo, asked questions) | Badge scan + 1-line note: "Interested in Cortex Analyst for [use case]" | After demo |
| Hot (asked for follow-up) | Badge scan + full note: name, role, company, use case, timeline, next step | After deep-dive |

**Lead log format** (shared Google Sheet or CRM, filled by Owner 1 at end of day):

| Name | Company | Role | Day | Station | Interest | Use Case | Next Step | Owner |
|------|---------|------|-----|---------|----------|----------|-----------|-------|
| ... | ... | ... | 1 | A | Warm | NL-to-SQL for finance team | Send 1-pager | Owner 1 |

---

### Emergency Playbook

| Scenario | Response | Who |
|----------|----------|-----|
| **Internet down** | Switch all stations to screen recordings. Owner 1 narrates live. Owner 2 runs offline Streamlit with `FALLBACK_MODE = True`. | All |
| **Cortex service outage** | Sidebar toggle → Fallback Mode on all apps. Announce: "We're showing you what the production experience looks like." Run from cached responses. | Owner at affected station |
| **Screen/laptop fails** | Swap backup laptop (pre-logged-in, all 3 apps bookmarked). Move the failed screen offline. | Owner 3 (tech support role) |
| **Person sick/no-show** | Two owners cover. Lowest-traffic station on auto-loop. Cancel pre-scheduled deep-dives or run them at hero stations. | Remaining 2 |
| **Visitor gets hostile/aggressive** | Stay calm. "Happy to connect you with our account team for a deeper conversation." Don't engage in product debates at the booth. | Owner 1 (lead) |
| **Visitor asks to plug in USB / load their data** | Decline politely: "We're using pre-cleared sample data for security. Happy to discuss how to set this up in your environment." | Any owner |
| **Demo produces wrong/weird answer** | Don't panic. "That's interesting — let me show you a verified query." Click a challenge card to run a known-good question. Reset and continue. | Any owner |
| **Booth neighbors are loud** | Speak louder, move visitor closer to screen. If persistent, request event staff intervention. | Owner 1 |

---

### Daily Rituals

**Morning huddle (08:45, 15 min):**
- Review yesterday's lead log (Day 2 and 3)
- Identify returning visitors to watch for
- Flag any technical issues from yesterday
- Assign deep-dive slots for the day
- Energy check: who needs a longer lunch today?

**End-of-day debrief (17:00, 15 min):**
- Each owner shares: top 3 interactions, 1 thing that didn't work
- Update lead log while memories are fresh
- Flag any demo questions that stumped the team (prep answers for tomorrow)
- Adjust tomorrow's strategy based on today's traffic pattern

**Between-day maintenance (evening):**
- Check Cortex service health: `SHOW CORTEX SEARCH SERVICES`
- Verify data hasn't drifted: run verification queries from Section 4
- Charge all devices
- Reprint challenge cards if running low
- Update shared lead doc

---

### Pre-Event Setup Timeline (Booth-Specific)

| When | Task | Owner |
|------|------|-------|
| T-7 | Reserve booth equipment (screens, stands, cables, signage) | Owner 1 |
| T-5 | All 3 Streamlit apps deployed and tested in Snowsight | Owner 2 |
| T-5 | Print challenge cards (20x), leave-behinds (100x), QR cards (100x) | Owner 3 |
| T-3 | Record fallback screen captures for all 3 demos | Owner 2 |
| T-3 | Test all recordings loop cleanly (no awkward pauses) | Owner 2 |
| T-2 | **Full dry run** — all 3 owners at actual booth location (or simulated) | All |
| T-2 | Time each demo: walk-up (target < 5 min), deep-dive (target < 15 min) | All |
| T-2 | Test handoff flow: Owner 1 passes visitor to Owner 2 to Owner 3 | All |
| T-2 | Verify network at venue (bring mobile hotspot as backup) | Owner 3 |
| T-1 | Set up physical booth: screens, cables, signage, literature rack | All |
| T-1 | Final smoke test: all 3 apps on venue network, all Cortex services healthy | All |
| T-1 | Load backup laptop with recordings + offline app configs | Owner 2 |
| T-0 AM | 08:00 arrival. Power on. Morning warm-up. Doors open at 09:00. | All |

---

## 10. Talking Points & Objection Handling

### Concept

Every booth interaction has three phases: **hook** (first 10 seconds), **demo** (the middle), and **close** (last 30 seconds). This section provides word-for-word scripts for each phase, tailored to persona and station. It also covers the top objections your team will face and how to handle them without getting defensive.

**Golden rule:** Lead with the business outcome, not the technology. Nobody cares that Cortex Analyst uses a semantic YAML model — they care that their team gets answers in 30 seconds instead of 3 days.

---

### The Universal Hook (First 10 Seconds)

Use this regardless of which station the visitor approaches. Adapt the specific demo reference.

**Default opener (works for anyone):**
> "Want to see AI answer a question about your data — live, in 30 seconds?"

**If they're browsing / hesitant:**
> "Pick any question about sales data. Type it in plain English. See what comes back."

**If they're clearly technical (badge says engineer/architect):**
> "This is running inside Snowflake — no external API, no gateway, no data copy. Want to see the SQL it generates?"

**If they're clearly executive (badge says VP/CXO/Director):**
> "Your team's dashboard backlog? Gone. Watch this."

**Anti-pattern — never open with:**
- "Have you heard of Cortex Analyst?" (they haven't, and it sounds like a product pitch)
- "Let me tell you about Snowflake's AI features" (lecture, not demo)
- "Do you use Snowflake?" (yes/no question → dead end)

---

### Per-Station Talk Tracks

#### Station A — Cortex Analyst: "Talk to Your Data"

**HOOK (0:00-0:15)**

| Persona | Hook |
|---------|------|
| CXO | "Your analysts spend days building reports. This gives every business user the answer in 30 seconds — no SQL, no BI tool, no waiting." |
| Data Leader | "This sits on your governed semantic layer. Same metrics, same definitions, same access policies — but anyone can query it in English." |
| Analyst | "Type any question about this sales data. The SQL it generates is visible — you can validate, tweak, and iterate." |
| Engineer | "One YAML file defines the semantic model — tables, joins, metrics, business terms. You write it once, the whole org queries through it." |

**DEMO (0:15-3:00)**

Walk through the standard flow (Section 5, Demo 1). Key moments to narrate:

```
[After result appears]
"That's live SQL — generated, executed, and summarized. Not a canned response."

[Show SQL expander]
"Here's the SQL it wrote. For your analysts, this is reviewable and auditable."

[Show chart]
"Auto-visualization. Your business users see this, not a SQL result set."

[Follow-up question]
"Now watch — I'll ask a follow-up. It keeps context from the previous question.
'Why did EMEA underperform?' It joins SALES_FACT with CAMPAIGN_FACT automatically."
```

**CLOSE (3:00-4:00)**

| Persona | Close |
|---------|-------|
| CXO | "Imagine this on every laptop in your company. That's the dashboard backlog eliminated. Want to see how the agent handles harder problems?" *(bridge to Station B)* |
| Data Leader | "The semantic model is your control plane — row-level security, metric definitions, approved joins. Self-service without shadow analytics." |
| Analyst | "You can embed this in any Streamlit app or internal portal. Your team customizes the UI; Cortex handles the SQL." |
| Engineer | "The semantic model YAML is version-controlled, CI/CD deployable, and reusable across Cortex Analyst and Cortex Agent. One model, multiple consumers." |

---

#### Station B — Data Agent: "Autonomous Analyst"

**HOOK (0:00-0:15)**

| Persona | Hook |
|---------|------|
| CXO | "Your analysts take 3 days and 20 slides to explain why revenue dropped. Watch the agent do it in 90 seconds." |
| Data Leader | "This isn't a chatbot — it's an autonomous analyst. It decides which tables to query, in what order, and chains the reasoning together." |
| Analyst | "You can see every step of its reasoning chain. If step 3 is wrong, you correct it and re-run from there." |
| Engineer | "You define the tools — SQL, APIs, stored procedures. The agent decides which to call and in what sequence. You own the tool definitions; the agent owns the orchestration." |

**DEMO (0:15-5:00)**

Walk through the agent investigation flow (Section 5, Demo 2). Key moments:

```
[As steps appear]
"Watch — step 1: it queries revenue by quarter. Step 2: it breaks down by region.
It's deciding the investigation path autonomously."

[Step 3 — campaign check]
"Now it's checking marketing data — it noticed EMEA dropped and is looking for
a cause. This is multi-table reasoning, not a single query."

[Step 4 — churn check]
"It found the campaign pause, but it's not stopping. It's checking customer
churn signals for corroboration. That's investigative thinking."

[Summary appears]
"Root cause, supporting evidence, recommendations. In production, this
triggers a Slack alert, updates a Jira ticket, or kicks off a remediation
workflow."
```

**CLOSE (5:00-6:00)**

| Persona | Close |
|---------|-------|
| CXO | "That investigation used to be a team of 3 analysts for a week. The agent does it on demand, every time a KPI moves. Want to see what it does with unstructured data?" *(bridge to Station C)* |
| Data Leader | "Every query is logged, every tool call is auditable. The agent uses the same governed semantic model as self-service analytics. No black-box AI." |
| Analyst | "Think of it as your investigation copilot. You review the chain, approve or adjust, and send the summary to leadership." |
| Engineer | "You can package this as a Snowflake Native App. Your customers or internal teams get an agent that runs on their data, inside their account." |

---

#### Station C — Document AI + Cortex Search: "Paper to Insight"

**HOOK (0:00-0:15)**

| Persona | Hook |
|---------|------|
| CXO | "Your legal team reviews 500 contracts a month manually. Watch this turn a PDF into searchable, queryable data in 60 seconds." |
| Data Leader | "Unstructured data — PDFs, contracts, invoices — becomes a first-class citizen in your data platform. Same governance, same security." |
| Analyst | "Type 'termination clause' and get the exact paragraph from any contract. No keyword matching — it understands what you mean." |
| Engineer | "Upload to a stage, call Document AI, index with Cortex Search. Three lines of infrastructure, infinite document types." |

**DEMO (0:15-3:00)**

Walk through the Document AI flow (Section 5, Demo 3). Key moments:

```
[After extraction]
"12-page contract — parties, dates, value, terms, governing law.
Extracted automatically. No templates, no regex, no manual mapping."

[After search result]
"I asked 'What's the termination clause?' and it returned Section 8.2
with a 0.94 relevance score. That's semantic understanding."

[Compare toggle — the wow moment]
"Now watch this. Same question, keyword search: LIKE '%termination%'.
It finds Section 8.2, but MISSES Section 8.5 — 'Early Exit Provisions.'
No keyword match, but Cortex Search understands they mean the same thing."

[Close the gap]
"That's the difference between search that matches words
and search that understands meaning."
```

**CLOSE (3:00-4:00)**

| Persona | Close |
|---------|-------|
| CXO | "Multiply this by every contract, invoice, and regulatory filing your company handles. That's months of manual review eliminated." |
| Data Leader | "No data leaves Snowflake. No third-party AI service sees your contracts. Processing, indexing, and search — all inside your VPC." |
| Analyst | "You can search across thousands of documents in plain English. 'Show me all contracts with liability caps under $5M' — done." |
| Engineer | "Same pipeline works for invoices, medical records, resumes, support tickets. Swap the document type, keep the architecture." |

---

### Objection Handling

The top 12 objections your team will hear, and how to respond. Each response follows the pattern: **acknowledge → reframe → evidence → bridge**.

---

**1. "Is this actually production-ready, or is it a demo toy?"**

> "Fair question. Cortex Analyst is GA on Enterprise edition. The semantic model YAML is version-controlled and CI/CD deployable. The SQL it generates runs through your existing governance — row-level security, masking policies, access controls. We built this demo in 2 weeks; a production deployment follows the same pattern with your data."

---

**2. "How much does this cost? Snowflake isn't cheap."**

> "Cortex Analyst and Cortex Search run on serverless compute — you pay per query, not per warehouse-hour. A typical Cortex Analyst query costs roughly the same as a few seconds of Medium warehouse time. Compare that to the analyst-hours spent building and maintaining dashboards. The ROI isn't in compute cost — it's in time-to-insight."

*If they push harder:*
> "I don't have your exact numbers, but let's rough it out: if your analytics team spends 200 hours a month on ad-hoc requests at $80/hour loaded cost, that's $16K/month. Even if Cortex Analyst handles 30% of those requests, the math works. Happy to run the numbers with your specifics in a follow-up."

---

**3. "We already have a BI tool (Tableau/Power BI/Looker). Why do we need this?"**

> "You don't replace your BI tool — you complement it. BI tools are great for structured, pre-built dashboards. Cortex Analyst handles the long tail: the ad-hoc questions that don't have a dashboard yet. Think of it as the gap between 'I need a dashboard built' and 'I need an answer now.' Both coexist."

---

**4. "What about hallucinations? Can we trust the answers?"**

> "Three safeguards. First, the semantic model constrains what the AI can query — it only has access to tables and metrics you define. Second, verified queries let you pre-validate SQL for high-stakes questions. Third, every response shows the generated SQL — your analysts can review it before trusting the number. It's auditable, not a black box."

---

**5. "Our data is sensitive. Does this send data to OpenAI / external LLMs?"**

> "No. Cortex runs entirely inside Snowflake's infrastructure. Your data stays in your VPC, in your region. No data is sent to third-party model providers. Snowflake's models (Arctic, Llama hosted on Snowflake) process everything within the platform boundary. For regulated industries, this is the architecture that compliance teams approve."

---

**6. "We tried NL-to-SQL before and it didn't work."**

> "Most NL-to-SQL tools fail because they don't have business context. They see table names and column names but don't know that 'revenue' means `SUM(amount) WHERE order_status = 'Completed'`. The semantic model solves this — you define metrics, business terms, and approved joins. The AI doesn't guess; it follows your definitions."

---

**7. "Databricks has similar features. Why Snowflake?"**

> "If your data is already in Snowflake, the advantage is zero data movement. Cortex Analyst queries your existing tables through your existing governance. No ETL to a lakehouse, no additional storage cost, no dual security model. If you're evaluating both platforms, run the same use case on each and compare time-to-value. We're confident in that comparison."

*Do NOT trash Databricks at the booth. Stay neutral, focus on Snowflake's strengths.*

---

**8. "The Data Agent looks impressive, but is it GA?"**

> "Cortex Agents are in active rollout — availability depends on your region and edition. What I can tell you is that the architecture is production-grade: governed tools, auditable reasoning chains, and the same semantic model powering the agent as powers self-service analytics. If your account doesn't have it yet, we can help you get early access or show you how to build a similar workflow with Cortex Analyst + stored procedures today."

---

**9. "We don't have a semantic model. How much effort to build one?"**

> "A basic semantic model for one subject area — say, sales analytics — takes 1-2 days for a data engineer. It's a YAML file: you list the tables, define the joins, name the metrics, and add business term descriptions. If you already have a dbt project, you're 80% there — the metric definitions translate directly."

---

**10. "Our documents are in [SharePoint / S3 / Google Drive]. How do we get them in?"**

> "Snowflake has native connectors for S3, Azure Blob, and GCS. You point a stage at your bucket, and documents flow in automatically. From there, Document AI extracts the structured data, and Cortex Search indexes the text. The pipeline from cloud storage to searchable knowledge base is 3-4 objects to configure."

---

**11. "This looks like a lot of setup. We don't have a big data engineering team."**

> "This entire demo — 3 apps, 500K rows of data, semantic model, Cortex Search service — was built in about a week, with a second week for testing and rehearsal. The synthetic data scripts run in 2 minutes. The Streamlit apps are single-file, copy-paste deployments. Snowflake's value proposition here is that you don't need a big team — you need a governed platform that does the heavy lifting."

---

**12. "Can you show me this with OUR data?"**

> "Not at the booth — we're using pre-cleared sample data for security. But here's what I'd suggest: take the leave-behind, scan the QR code for the recorded demo, and let's schedule a 60-minute PoC session where we connect to your actual data and build a semantic model for one of your use cases. That's the fastest path to seeing real value."

*(This is the highest-intent signal you'll get. Capture the lead immediately.)*

---

### Anti-Patterns (What NOT to Say)

| Don't Say | Why | Say Instead |
|-----------|-----|-------------|
| "Snowflake's AI is a game-changer" | Hype word. Triggers skepticism. | "Cortex Analyst turns every business user into a self-service analyst." |
| "This replaces your BI tool" | Threatens existing investment. Creates defensiveness. | "This complements your BI tool — it handles the ad-hoc questions BI can't." |
| "It never hallucinates" | Provably false. Destroys credibility. | "The semantic model constrains what it can query. Verified queries add a second layer. The SQL is always visible for review." |
| "It's really easy to set up" | Dismissive of their team's concerns. | "A basic semantic model takes 1-2 days for one subject area." |
| "Snowflake is better than Databricks" | Adversarial. Unprofessional at a booth. | "If your data is in Snowflake, the advantage is zero data movement and unified governance." |
| "Let me show you another feature" | Feature dump. Visitor loses interest. | "Want to see what happens when you ask a harder question?" (keep it interactive) |
| "I'm not sure, but I think..." | Signals uncertainty. | "Great question — let me get you the exact answer. Can I take your contact and follow up by tomorrow?" |
| "This is still in preview/beta" | Kills confidence for a buying decision. | "This is in active rollout. Availability depends on region and edition. Let me check your specific setup." |

---

### Transition Phrases (Station-to-Station)

Use these to bridge visitors between stations naturally:

**A → B (Analyst → Agent):**
> "You've seen it answer one question at a time. Want to see what happens when it investigates a whole problem — multiple queries, autonomous reasoning, root-cause analysis?"

**A → C (Analyst → Document AI):**
> "That was structured data — tables and numbers. Want to see the same AI work on unstructured data? Contracts, PDFs, documents."

**B → C (Agent → Document AI):**
> "The agent investigates data. Over here, we're turning paper into data. Different problem, same platform."

**C → A (Document AI → Analyst):**
> "Now that the documents are structured, you can query them the same way. Want to go back and ask Cortex Analyst a question about contract data?"

**Any → Side Table (deep-dive):**
> "I can tell you're thinking about how this applies to your team. Want to sit down for 10 minutes and I'll show you [RAG / sentiment / fine-tuning]?"

---

### Persona Quick-Reference Card

Print this as a laminated cheat sheet for each station owner's back pocket:

```
┌──────────────────────────────────────────────────────┐
│  PERSONA CHEAT SHEET — Booth Quick Reference          │
├──────────┬───────────────────────────────────────────┤
│ CXO      │ Lead with: time saved, manual effort      │
│          │ eliminated, competitive advantage.         │
│          │ Avoid: technical details, architecture.    │
│          │ Close: "Let's schedule a PoC for your      │
│          │ team. 60 minutes, your data."              │
├──────────┼───────────────────────────────────────────┤
│ DATA     │ Lead with: governance, semantic layer,     │
│ LEADER   │ no shadow analytics, security posture.     │
│          │ Avoid: oversimplifying setup effort.       │
│          │ Close: "The semantic model is your          │
│          │ control plane. Let me show the YAML."      │
├──────────┼───────────────────────────────────────────┤
│ ANALYST  │ Lead with: speed, SQL visibility,          │
│          │ validation capability, daily workflow.     │
│          │ Avoid: suggesting it replaces them.        │
│          │ Close: "This handles the routine — you     │
│          │ focus on the complex analysis."            │
├──────────┼───────────────────────────────────────────┤
│ ENGINEER │ Lead with: YAML model, CI/CD, extensible  │
│          │ tools, Native App packaging.               │
│          │ Avoid: glossing over integration effort.   │
│          │ Close: "Here's the repo structure. Want    │
│          │ me to share the semantic model template?"  │
└──────────┴───────────────────────────────────────────┘
```

---

## 11. Leave-Behind 1-Pager

### Purpose

Every visitor gets something physical to take back to their team. The 1-pager serves three functions:
1. **Reminder:** What they saw and why it matters.
2. **Shareable:** They hand it to a colleague and say "look at what Snowflake can do."
3. **Call-to-action:** QR code links to a recorded demo reel + your team's contact.

Print 100-150 copies per day (300-450 total). Laminated or heavy cardstock — it needs to survive a conference bag.

---

### Layout (Markdown Source — Convert to Designed PDF)

Below is the content in markdown. Hand this to your design team (or use Canva/Figma) to produce a branded PDF with company colors, logos, and the QR code.

```
┌──────────────────────────────────────────────────────────────┐
│                                                              │
│  [YOUR COMPANY LOGO]              INNOVATION SUMMIT 2025     │
│                                                              │
│  ─────────────────────────────────────────────────────────── │
│                                                              │
│  AI-DRIVEN DATA PRODUCTS — INSIDE SNOWFLAKE, NOT AROUND IT   │
│                                                              │
│  ─────────────────────────────────────────────────────────── │
│                                                              │
│  WHAT WE SHOWED YOU                                          │
│                                                              │
│  1. TALK TO YOUR DATA                                        │
│     Cortex Analyst: Ask any question in plain English.       │
│     Get SQL, results, and a summary in 30 seconds.           │
│     No BI tool. No dashboard backlog. No waiting.            │
│                                                              │
│  2. AUTONOMOUS ANALYST                                       │
│     Cortex Agent: Multi-step investigation on demand.        │
│     Root-cause analysis in 90 seconds, not 3 days.           │
│     Every query auditable, every step reviewable.            │
│                                                              │
│  3. PAPER TO INSIGHT                                         │
│     Document AI + Cortex Search: Upload a contract,          │
│     extract structured data, search in natural language.     │
│     Semantic search that understands meaning, not keywords.  │
│                                                              │
│  ─────────────────────────────────────────────────────────── │
│                                                              │
│  ARCHITECTURE                                                │
│                                                              │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐     │
│  │  Cortex      │   │  Cortex      │   │  Document AI │     │
│  │  Analyst     │   │  Agent       │   │  + Cortex    │     │
│  │              │   │              │   │  Search      │     │
│  └──────┬───────┘   └──────┬───────┘   └──────┬───────┘     │
│         │                  │                   │             │
│         └──────────┬───────┘                   │             │
│                    │                           │             │
│         ┌──────────▼───────────────────────────▼──────┐      │
│         │        SEMANTIC MODEL (YAML)                │      │
│         │  Tables · Joins · Metrics · Business Terms  │      │
│         └──────────────────┬──────────────────────────┘      │
│                            │                                 │
│         ┌──────────────────▼──────────────────────────┐      │
│         │          SNOWFLAKE (Enterprise)              │      │
│         │  Your data · Your governance · Your VPC      │      │
│         │  No data leaves. No external AI gateways.    │      │
│         └─────────────────────────────────────────────┘      │
│                                                              │
│  ─────────────────────────────────────────────────────────── │
│                                                              │
│  NEXT STEP                                                   │
│                                                              │
│  ┌────────────┐  Scan to watch the 3-minute demo reel.      │
│  │            │  Ready for a PoC with your data?             │
│  │  [QR CODE] │  Contact us:                                │
│  │            │  [Name] | [Email] | [Phone]                 │
│  └────────────┘  [Name] | [Email] | [Phone]                 │
│                  [Name] | [Email] | [Phone]                 │
│                                                              │
│  ─────────────────────────────────────────────────────────── │
│  [Company] · [Website] · Innovation Summit [Month Year]      │
└──────────────────────────────────────────────────────────────┘
```

---

### QR Code Target

The QR code should link to a **landing page or unlisted video** containing:
- 3-minute recorded demo reel (hero demos back-to-back, no narration gaps)
- Link to schedule a 60-minute PoC session
- Contact details for all 3 booth owners

**QR generation:** Use any QR generator (qr-code-generator.com, Canva built-in, or `qrencode` CLI). Test the QR code from 3 feet away on a phone camera — if it doesn't scan from arm's length, make it larger.

**Same QR appears on:**
- The leave-behind 1-pager (bottom section)
- Every booth screen (bottom-right overlay, live and auto-loop)
- The challenge card stand (small sticker)

---

### Production Notes

| Item | Spec |
|------|------|
| Paper size | A4 or US Letter, single-sided |
| Stock | 200gsm+ cardstock or laminated 120gsm |
| Colors | Company brand colors; Snowflake blue (#29B5E8) for architecture diagram |
| Print run | 150/day x 3 days = 450 copies (+ 50 buffer) |
| QR code size | Minimum 2.5cm x 2.5cm (scannable at arm's length) |
| Delivery | Print at T-3; deliver to booth at T-1 setup |

---

## 12. Risk & Fallback Matrix

### Overview

This matrix consolidates every failure scenario and fallback path from Sections 5, 8, and 9 into a single reference. Print this as a laminated card and keep it at the booth. When something breaks, don't troubleshoot live — find the row, execute the fallback, keep demoing.

---

### Service-Level Risks

| # | Risk | Probability | Impact | Fallback | Owner | Recovery |
|---|------|------------|--------|----------|-------|----------|
| R1 | **Cortex Analyst unavailable** (service outage or region issue) | Low | HIGH — kills Station A | Toggle `Fallback Mode` in sidebar. App serves cached responses via keyword matching. Run 90-second screen recording on loop. | Owner 1 | Check `SHOW CORTEX SEARCH SERVICES` every 30 min. Re-enable live mode when service recovers. |
| R2 | **Cortex Agent not GA / unavailable** | Medium | HIGH — kills Station B | Default mode is already Replay. Streamlit app steps through cached investigation with 2s/step timing. Indistinguishable from live to most visitors. | Owner 2 | If Agent becomes available mid-event, switch to Live mode via sidebar radio. Test with one question before going live with visitors. |
| R3 | **Cortex Search service unhealthy** | Low | HIGH — kills Station C search | Fall back to `LIKE` query against `DOCUMENTS_TEXT`. Compare toggle still works (shows keyword results). Semantic ranking lost but search still functions. | Owner 3 | Re-create search service: `CREATE OR REPLACE CORTEX SEARCH SERVICE ...` (Script 07, ~5 min). |
| R4 | **Document AI processing slow/fails** | Low | Medium — upload simulation breaks | All 5 documents are pre-extracted (Script 06). Skip the live upload step. Show extraction results as "just processed." Focus demo on Cortex Search. | Owner 3 | Extraction data is in `DOCUMENTS_EXTRACTED` table — always available regardless of Document AI status. |
| R5 | **Semantic model YAML error** | Low | HIGH — breaks Demos 1 + 2 | Revert to a minimal 3-table model (SALES_FACT + DIM_PRODUCT + DIM_REGION) tested and frozen at T-3. Keep a backup YAML at `@SEMANTIC_MODELS/cortex_analyst_demo_minimal.yaml`. | Owner 2 | Debug YAML off-stage. Common issues: missing column references, incorrect join paths, YAML indentation. |

---

### Infrastructure Risks

| # | Risk | Probability | Impact | Fallback | Owner | Recovery |
|---|------|------------|--------|----------|-------|----------|
| R6 | **Internet / network down** | Medium | CRITICAL — all stations affected | Switch all 3 stations to screen recordings (pre-loaded on backup laptop). Owner 1 narrates live over recordings. Owner 2 runs Streamlit in offline/fallback mode if local network still works. | All | Bring a mobile hotspot (4G/5G) as backup network. Pre-test at T-1. |
| R7 | **Warehouse suspended / slow** | Low | Medium — queries timeout | `ALTER WAREHOUSE DEMO_AI_WH RESUME;` — auto-resume should handle this, but run manually if first query of the day hangs. Scale up to Large if queries are slow. | Owner 2 | `ALTER WAREHOUSE DEMO_AI_WH SET WAREHOUSE_SIZE = 'LARGE';` — scale back down after peak. |
| R8 | **Snowflake account locked / credentials expire** | Very Low | CRITICAL | Backup laptop pre-logged-in with a second account or service user. Screen recordings on all stations. | Owner 1 | Contact Snowflake support immediately. Use backup credentials. |

---

### Hardware Risks

| # | Risk | Probability | Impact | Fallback | Owner | Recovery |
|---|------|------------|--------|----------|-------|----------|
| R9 | **Screen / laptop fails** | Low | Medium — one station down | Swap backup laptop (pre-logged-in, all 3 apps bookmarked). Move the failed device offline. | Owner 3 | If no backup available, merge the two working stations. Lost station goes dark with a "Visit Station A/B" sign. |
| R10 | **Power outage at booth** | Very Low | CRITICAL | All stations down. Switch to phone-based demo (pre-loaded screen recording on each owner's phone). Stand at the aisle and engage visitors verbally until power returns. | All | Request event staff for generator or power restoration. Move to a hallway outlet if available. |

---

### Human Risks

| # | Risk | Probability | Impact | Fallback | Owner | Recovery |
|---|------|------------|--------|----------|-------|----------|
| R11 | **Person sick / no-show** | Low | HIGH — down to 2 operators | Two owners cover all stations. Lowest-traffic station on auto-loop recording. Cancel pre-scheduled deep-dives. Focus on hero demos only. | Remaining 2 | If multi-day absence, recruit a colleague who attended the T-2 dry run as backup. |
| R12 | **Visitor hostile / disruptive** | Very Low | Low | Stay calm. "Happy to connect you with our account team for a deeper conversation." Do not engage in product debates. If persistent, request event staff. | Owner 1 (lead) | Debrief after. Note the concern — it may be a valid objection to add to the playbook. |
| R13 | **Visitor asks to plug in USB / load their data** | Medium | Medium — security risk | Decline politely: "We're using pre-cleared sample data for security. Happy to discuss how to set this up in your environment." | Any owner | Never accept external media or data at a public booth. |

---

### Demo-Specific Risks

| # | Risk | Probability | Impact | Fallback | Owner |
|---|------|------------|--------|----------|-------|
| R14 | **Cortex Analyst returns wrong answer** | Medium | Medium — visitor loses trust | Don't panic. "Interesting — let me show you a verified query." Click a challenge card to run a known-good question. Explain: "Verified queries let you pre-validate high-stakes answers." | Owner 1 |
| R15 | **Agent hallucinates mid-chain** | Medium | Medium — reasoning chain looks wrong | Interrupt: "Let me show you a completed investigation." Switch to cached result. Explain: "In production, you'd add guardrails — verified queries, output validation, human-in-the-loop." | Owner 2 |
| R16 | **Visitor asks out-of-scope question** | High | Low — expected | Redirect to a pre-built question. "Great scenario — that would need [X] data source connected. Let me show you the depth it achieves with what we have." | Any |
| R17 | **Compare toggle shows keyword beating semantic** | Low | Medium — undermines the story | This happens when the query contains an exact keyword match. Acknowledge it: "For exact keyword matches, LIKE works fine. The gap shows up on conceptual queries." Switch to the "early exit provisions" example. | Owner 3 |

---

### Pre-Event Risk Mitigation Checklist

| When | Check | Pass Criteria |
|------|-------|--------------|
| T-7 | All SQL scripts run without error | Verification queries return expected values |
| T-7 | Cortex Analyst responds to all 5 challenge card questions | Correct answers, < 5s response time |
| T-5 | All 3 Streamlit apps deployed and functional | Each app renders, responds to input, resets cleanly |
| T-5 | Cortex Search service status = ACTIVE | `SHOW CORTEX SEARCH SERVICES` returns healthy |
| T-3 | Screen recordings captured for all 3 demos | Each recording loops cleanly, no awkward pauses, 90-120s |
| T-3 | Backup laptop configured | Pre-logged-in, all 3 apps bookmarked, recordings loaded |
| T-2 | Full dry run with all 3 owners | Each demo runs < 5 min, handoffs work, reset works |
| T-2 | Test fallback modes for each app | Toggle fallback in each app; verify cached responses work |
| T-1 | Venue network test | All 3 apps load and respond on venue Wi-Fi |
| T-1 | Mobile hotspot tested | Backup network connects to Snowflake successfully |
| T-0 AM | Morning warm-up run | All 3 stations pass smoke test before doors open |

---

### Severity Legend

| Level | Definition | Response |
|-------|-----------|----------|
| **CRITICAL** | All stations down. No demo capability. | Switch to screen recordings + verbal narration. Escalate to event staff. |
| **HIGH** | One station fully down. Major demo missing. | Activate fallback immediately. Redistribute visitors to working stations. |
| **Medium** | Partial degradation. Demo works but imperfectly. | Use fallback for affected feature. Continue demo with adjusted narrative. |
| **Low** | Minor inconvenience. Visitor barely notices. | Handle in-flow. No escalation needed. |
