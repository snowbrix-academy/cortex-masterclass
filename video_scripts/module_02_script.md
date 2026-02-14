# Module 2 Video Script: Deploy Your First Cortex Analyst App

**Duration:** 15 minutes
**Instructor:** Snowbrix Academy
**Tone:** Direct, authoritative, demo-first
**Tagline:** "Production-Grade Data Engineering. No Fluff."

---

## Pre-Recording Checklist

- [ ] Module 1 environment fully set up
- [ ] Semantic YAML file ready (cortex_analyst_demo.yaml)
- [ ] Streamlit app file ready (app_cortex_analyst.py)
- [ ] Browser tabs: Snowflake Worksheets + Snowsight (Streamlit)
- [ ] VS Code open with YAML and Python files
- [ ] Test queries prepared
- [ ] OBS recording: 1920×1080, 30fps
- [ ] Microphone tested

---

## [00:00-00:30] Cold Open (30 seconds)

**[SCREEN: Show completed Streamlit app running - user typing query, getting results]**

**SCRIPT:**

"This is what we're building today. A Cortex Analyst app where users ask questions in plain English, and Snowflake generates SQL and returns results.

No manual SQL writing. No dashboard navigation. Just natural language to data.

Module 2: Deploy Your First Cortex Analyst App.

By the end, you'll have a working app deployed in Snowflake. Let's build it."

**[CUT TO: Instructor screen]**

---

## [00:30-02:30] Section 1: Understanding Semantic YAML (2 minutes)

**[SCREEN: VS Code with cortex_analyst_demo.yaml open]**

**SCRIPT:**

"Cortex Analyst needs context to generate correct SQL. That context comes from a semantic YAML model.

**[SHOW FILE STRUCTURE - scroll through YAML]**

This YAML defines three things:

**[HIGHLIGHT: 'tables' section]**

**1. Tables:** Which Snowflake tables to query.

**[SCROLL TO: CUSTOMERS table definition]**

For each table, we specify:
- Database, schema, table name
- Columns with data types and descriptions
- Synonyms (alternative names)

**[READ/HIGHLIGHT:]**
```yaml
tables:
  - name: CUSTOMERS
    base_table:
      database: DEMO_AI_SUMMIT
      schema: CORTEX_ANALYST_DEMO
      table: CUSTOMERS
    columns:
      - name: CUSTOMER_ID
        data_type: NUMBER
        description: Unique customer identifier
      - name: CUSTOMER_NAME
        data_type: STRING
        description: Full name of the customer
        synonyms:
          - customer name
          - client name
```

Why synonyms? So users can ask 'Show me client names' and Cortex knows to query CUSTOMER_NAME column.

**[SCROLL TO: 'relationships' section]**

**2. Relationships:** How tables join together.

**[HIGHLIGHT relationship:]**
```yaml
relationships:
  - name: orders_to_customers
    left_table: ORDERS
    left_column: CUSTOMER_ID
    right_table: CUSTOMERS
    right_column: CUSTOMER_ID
```

This tells Cortex: 'Orders and Customers join on CUSTOMER_ID.'

Without this, Cortex doesn't know how to join tables. It would generate invalid SQL.

**[SCROLL TO: 'verified_queries' section]**

**3. Verified Queries:** Pre-validated SQL patterns for common questions.

**[HIGHLIGHT verified query:]**
```yaml
verified_queries:
  - name: total_revenue
    question: "What is the total revenue?"
    sql: |
      SELECT SUM(oi.quantity * oi.price) AS total_revenue
      FROM ORDER_ITEMS oi;
```

When a user asks 'What is the total revenue?', Cortex uses this pre-validated SQL instead of generating new SQL. Faster and more reliable.

**[SCROLL BACK TO TOP]**

Our YAML has:
- 7 tables (CUSTOMERS, PRODUCTS, ORDERS, ORDER_ITEMS, RETURNS, REGIONS, PRODUCT_REVIEWS)
- 12 relationships
- 8 verified queries

Enough to answer complex questions like 'What are the top 5 products by revenue in California?'

Let's verify this YAML is uploaded to Snowflake."

---

## [02:30-03:30] Section 2: Verify Semantic Model Upload (60 seconds)

**[SCREEN: Snowflake Worksheets]**

**SCRIPT:**

"Open Snowflake Worksheets. Check if the semantic model is uploaded.

**[TYPE/PASTE:]**
```sql
USE ROLE SYSADMIN;
USE WAREHOUSE COMPUTE_WH;
USE DATABASE DEMO_AI_SUMMIT;
USE SCHEMA CORTEX_ANALYST_DEMO;

-- List files in stage
LIST @CORTEX_ANALYST_STAGE;
```

**[MOUSE: Run query]**

**[RESULTS: Shows cortex_analyst_demo.yaml]**

There it is. Size: 13.4 KB.

If you don't see it, go back to Module 1 and re-upload the YAML file.

Now let's test Cortex Analyst via SQL before building the Streamlit app."

---

## [03:30-05:00] Section 3: Test Cortex Analyst via SQL (90 seconds)

**[SCREEN: Snowflake Worksheets]**

**SCRIPT:**

"Cortex Analyst has a SQL API. Let's test it.

**[TYPE/PASTE:]**
```sql
SELECT SNOWFLAKE.CORTEX.ANALYST(
    'What are the top 5 products by revenue?',
    '@CORTEX_ANALYST_STAGE/cortex_analyst_demo.yaml'
) AS response;
```

**[EXPLAIN while typing:]**

Function: SNOWFLAKE.CORTEX.ANALYST
Parameter 1: User question (plain English)
Parameter 2: Path to semantic YAML

**[MOUSE: Run query]**

**[RESULTS: Shows JSON response]**

Result is JSON. Let's parse it.

**[SCROLL THROUGH RESPONSE - show structure]**
```json
{
  "message": {
    "content": "Here are the top 5 products by revenue: ..."
  },
  "sql": "SELECT p.product_name, SUM(oi.quantity * oi.price) AS revenue FROM ...",
  "data": [...]
}
```

Three keys:
- **message:** Natural language answer
- **sql:** Generated SQL query
- **data:** Query results as JSON array

**[MOUSE: Highlight 'sql' field]**

Look at the generated SQL:

**[COPY SQL from response, paste in new worksheet]**
```sql
SELECT
    p.product_name,
    SUM(oi.quantity * oi.price) AS revenue
FROM ORDER_ITEMS oi
JOIN PRODUCTS p ON oi.product_id = p.product_id
GROUP BY p.product_name
ORDER BY revenue DESC
LIMIT 5;
```

Cortex generated correct SQL:
- Joined ORDER_ITEMS and PRODUCTS
- Calculated revenue (quantity × price)
- Grouped by product name
- Ordered by revenue descending
- Limited to 5 rows

All from semantic model relationships.

**[RUN the generated SQL]**

**[RESULTS: Shows top 5 products]**

Data matches. Cortex Analyst works.

Now let's build a user-friendly interface — a Streamlit app."

---

## [05:00-07:30] Section 4: Build Streamlit App (2.5 minutes)

**[SCREEN: VS Code - create new file app_cortex_analyst.py]**

**SCRIPT:**

"We'll create a Streamlit app that calls Cortex Analyst via REST API.

**[CREATE NEW FILE: app_cortex_analyst.py]**

Let me walk through the code step by step.

**[TYPE/SHOW CODE - explain as you go]**

**Part 1: Imports**
```python
import streamlit as st
from snowflake.snowpark.context import get_active_session
from _snowflake import send_snow_api_request
import json
```

**[EXPLAIN:]**
- streamlit: UI library
- snowpark: Connect to Snowflake
- _snowflake.send_snow_api_request: Call Cortex API (Streamlit in Snowflake specific)

**Part 2: Session and Config**
```python
# Get Snowflake session
session = get_active_session()

# Semantic model path
SEMANTIC_MODEL = "@CORTEX_ANALYST_DEMO.CORTEX_ANALYST_DEMO.CORTEX_ANALYST_STAGE/cortex_analyst_demo.yaml"
```

**[EXPLAIN:]**
Streamlit in Snowflake has automatic authentication. No credentials needed.

**Part 3: Function to Call Cortex Analyst**
```python
def query_cortex_analyst(question):
    endpoint = "/api/v2/cortex/analyst/message"

    body = {
        "messages": [
            {
                "role": "user",
                "content": [{"type": "text", "text": question}]
            }
        ],
        "semantic_model_file": SEMANTIC_MODEL
    }

    response = send_snow_api_request(
        method="POST",
        url=endpoint,
        body=body
    )

    return response
```

**[EXPLAIN:]**
Endpoint: /api/v2/cortex/analyst/message
Body: JSON with user question and semantic model path
Response: JSON with message, SQL, and data

**Part 4: Streamlit UI**
```python
st.title("Cortex Analyst Demo")
st.markdown("Ask questions about sales data in plain English.")

# Input
question = st.text_input("Ask a question:", key="question_input")

if st.button("Submit"):
    if question:
        with st.spinner("Generating answer..."):
            response = query_cortex_analyst(question)

        # Display answer
        if "message" in response:
            st.subheader("Answer")
            st.write(response["message"]["content"])

            # Show generated SQL
            if "sql" in response:
                st.subheader("Generated SQL")
                st.code(response["sql"], language="sql")

            # Show data
            if "data" in response:
                st.subheader("Results")
                import pandas as pd
                df = pd.DataFrame(response["data"])
                # Normalize column names (Snowflake returns UPPERCASE)
                df.columns = [c.lower() for c in df.columns]
                st.dataframe(df)
    else:
        st.warning("Please enter a question.")
```

**[EXPLAIN:]**
- st.text_input: Text box for user question
- st.button: Submit button
- st.spinner: Loading indicator
- Display: Answer, SQL, and results table

**[HIGHLIGHT: df.columns = [c.lower() for c in df.columns]]**

Critical line. Snowflake returns UPPERCASE column names. Must normalize to lowercase or you'll get KeyError when accessing df['revenue'].

**[SAVE FILE]**

App complete. 50 lines of code. Let's deploy it."

---

## [07:30-09:30] Section 5: Deploy Streamlit App to Snowflake (2 minutes)

**[SCREEN: Snowflake Worksheets]**

**SCRIPT:**

"To deploy, we upload the Python file to a Snowflake stage, then create a Streamlit object.

**Step 1: Create stage for Streamlit apps**

**[TYPE/PASTE:]**
```sql
USE ROLE SYSADMIN;
USE WAREHOUSE COMPUTE_WH;
USE DATABASE DEMO_AI_SUMMIT;
USE SCHEMA CORTEX_ANALYST_DEMO;

-- Create stage
CREATE STAGE IF NOT EXISTS STREAMLIT_STAGE;
```

**[RUN query]**

**[SWITCH TO: Terminal]**

**Step 2: Upload Python file**

**[TYPE:]**
```bash
# From course repository root
cd streamlit_apps

# Upload to Snowflake stage
snowsql -a YOUR_ACCOUNT -u YOUR_USER \
  -q "PUT file://app_cortex_analyst.py @DEMO_AI_SUMMIT.CORTEX_ANALYST_DEMO.STREAMLIT_STAGE AUTO_COMPRESS=FALSE;"
```

**[ALTERNATIVE: Show Snowsight UI upload]**

Or via Snowsight UI:
- Navigate to Stages > STREAMLIT_STAGE
- Click + Files
- Upload app_cortex_analyst.py

**[VERIFY upload:]**
```sql
LIST @STREAMLIT_STAGE;
```

**[RESULTS: Shows app_cortex_analyst.py]**

File uploaded.

**Step 3: Create Streamlit app object**

**[TYPE/PASTE:]**
```sql
CREATE OR REPLACE STREAMLIT CORTEX_ANALYST_APP
  ROOT_LOCATION = '@DEMO_AI_SUMMIT.CORTEX_ANALYST_DEMO.STREAMLIT_STAGE'
  MAIN_FILE = '/app_cortex_analyst.py'
  QUERY_WAREHOUSE = COMPUTE_WH
  TITLE = 'Cortex Analyst Demo';
```

**[RUN query]**

**[RESULTS: Streamlit CORTEX_ANALYST_APP created successfully]**

Done. App is deployed.

Let's access it."

---

## [09:30-12:00] Section 6: Test Streamlit App (2.5 minutes)

**[SCREEN: Snowflake Snowsight UI]**

**SCRIPT:**

"Go to Snowsight. Click **Projects** in the left sidebar.

**[MOUSE: Click 'Projects' > 'Streamlit']**

You'll see **CORTEX_ANALYST_APP** in the list.

**[MOUSE: Click 'CORTEX_ANALYST_APP']**

**[SCREEN: Streamlit app loads]**

**[WAIT 2-3 seconds for app to fully load]**

Our app is live.

**[SHOW UI - describe what's on screen]**

Title: 'Cortex Analyst Demo'
Description: 'Ask questions about sales data in plain English.'
Text input box: 'Ask a question'
Submit button

Let's ask a question.

**[MOUSE: Click text input, TYPE:]**
"What are the top 5 products by revenue?"

**[MOUSE: Click 'Submit']**

**[SHOW: Spinner - 'Generating answer...']**

Cortex Analyst is:
1. Parsing the question
2. Identifying tables (PRODUCTS, ORDER_ITEMS)
3. Identifying metric (revenue = quantity × price)
4. Generating SQL with JOIN and GROUP BY
5. Executing SQL
6. Formatting results

**[RESULTS APPEAR - show each section]**

**Answer:**
'Here are the top 5 products by revenue: Laptop ($125,450), Smartphone ($98,320), ...'

**Generated SQL:**
```sql
SELECT
    p.product_name,
    SUM(oi.quantity * oi.price) AS revenue
FROM ORDER_ITEMS oi
JOIN PRODUCTS p ON oi.product_id = p.product_id
GROUP BY p.product_name
ORDER BY revenue DESC
LIMIT 5;
```

**Results (table):**
| product_name | revenue  |
|--------------|----------|
| Laptop       | 125,450  |
| Smartphone   | 98,320   |
| ...          | ...      |

Perfect.

Let's try a more complex question.

**[MOUSE: Clear text input, TYPE:]**
"What is the average order value by region?"

**[MOUSE: Click 'Submit']**

**[WAIT for response]**

**[RESULTS APPEAR]**

**Generated SQL:**
```sql
SELECT
    r.region_name,
    AVG(o.total_amount) AS avg_order_value
FROM ORDERS o
JOIN CUSTOMERS c ON o.customer_id = c.customer_id
JOIN REGIONS r ON c.region_id = r.region_id
GROUP BY r.region_name
ORDER BY avg_order_value DESC;
```

Cortex joined three tables (ORDERS, CUSTOMERS, REGIONS) automatically. This is the power of semantic relationships.

**[RESULTS TABLE]**
| region_name | avg_order_value |
|-------------|-----------------|
| West        | 245.30          |
| Northeast   | 238.50          |
| ...         | ...             |

One more test.

**[MOUSE: TYPE:]**
"Which customers returned the most products?"

**[MOUSE: Submit]**

**[RESULTS:]**

**SQL:**
```sql
SELECT
    c.customer_name,
    COUNT(r.return_id) AS return_count
FROM RETURNS r
JOIN CUSTOMERS c ON r.customer_id = c.customer_id
GROUP BY c.customer_name
ORDER BY return_count DESC
LIMIT 10;
```

**Data:**
Top 10 customers by return count.

App works. We've successfully deployed Cortex Analyst."

---

## [12:00-13:30] Section 7: Understanding What Just Happened (90 seconds)

**[SCREEN: Diagram/whiteboard or code editor with annotations]**

**SCRIPT:**

"Let's recap the architecture.

**[SHOW DIAGRAM - draw or use pre-made image]**

**Components:**
1. **User:** Types question in Streamlit app
2. **Streamlit (Snowflake-hosted):** Receives question
3. **Cortex Analyst API:** Receives question + semantic model path
4. **Semantic Model (YAML):** Defines tables, relationships, verified queries
5. **Cortex Analyst Engine:** Generates SQL based on semantic model
6. **Snowflake Warehouse:** Executes SQL on actual tables
7. **Results:** Return to Cortex Analyst → Streamlit → User

**[HIGHLIGHT data flow with arrows]**

Question → Streamlit → Cortex API → SQL Generation → Warehouse Execution → Results

**Why this is powerful:**

**1. No SQL expertise required.** Business users ask questions in natural language.

**2. Dynamic SQL generation.** Unlike BI dashboards (pre-built queries), Cortex generates SQL on-the-fly for any question.

**3. Semantic layer as single source of truth.** Change YAML once, all queries benefit.

**4. Security.** Cortex respects Snowflake RBAC. Users only see data they have permission to query.

**5. Scalable.** Serverless. Handles 1 user or 1,000 users.

This is production-grade AI data infrastructure."

---

## [13:30-14:30] Section 8: Common Issues & Troubleshooting (60 seconds)

**[SCREEN: VS Code or Snowflake Worksheets]**

**SCRIPT:**

"Three common issues:

**Issue 1: 'Cortex Analyst API endpoint not found' (404 error)**

**Cause:** Semantic model path incorrect or file not uploaded.

**Fix:**
```sql
-- Verify file exists
LIST @CORTEX_ANALYST_STAGE;

-- Check path in Python code
SEMANTIC_MODEL = "@CORTEX_ANALYST_DEMO.CORTEX_ANALYST_DEMO.CORTEX_ANALYST_STAGE/cortex_analyst_demo.yaml"
```

Path must match exactly (database.schema.stage/filename).

**Issue 2: 'KeyError: revenue' in Streamlit**

**Cause:** Forgot to normalize column names.

**Fix:**
```python
df.columns = [c.lower() for c in df.columns]
```

Snowflake returns UPPERCASE. Must convert to lowercase before accessing df['revenue'].

**Issue 3: 'Cortex Analyst returns empty results'**

**Cause:** Question too vague or data doesn't match.

**Fix:** Add verified queries for common patterns:
```yaml
verified_queries:
  - name: total_sales
    question: "What is total sales?"
    sql: "SELECT SUM(total_amount) FROM ORDERS;"
```

Verified queries are faster and more reliable than dynamic generation.

Check docs/troubleshooting.md in the course repo for more."

---

## [14:30-15:00] Closing & Next Steps (30 seconds)

**[SCREEN: Return to course logo or instructor]**

**SCRIPT:**

"Recap: You've deployed a production Cortex Analyst app.

Users can now:
- Ask questions in plain English
- Get SQL-generated answers
- Explore data without writing SQL

**Next: Module 3** — We build a Cortex Agent for multi-step root cause analysis.

Instead of answering one question, the agent will:
- Detect anomalies
- Investigate across multiple tables
- Identify root causes
- Report findings

Before Module 3, complete the Module 2 lab:
- Part A: Deploy the Cortex Analyst app (done if you followed along)
- Part B: Extend semantic model — add 2 new tables (PRODUCT_REVIEWS, RETURNS) and write 3 verified queries

Submit via GitHub PR.

See you in Module 3.

Production-Grade Data Engineering. No Fluff."

**[FADE TO: Course logo + GitHub link]**

---

## Post-Production Checklist

- [ ] Add timestamps in YouTube description
- [ ] Add chapter markers:
  - 00:00 Introduction
  - 00:30 Understanding Semantic YAML
  - 02:30 Verify Semantic Model
  - 03:30 Test Cortex Analyst via SQL
  - 05:00 Build Streamlit App
  - 07:30 Deploy to Snowflake
  - 09:30 Test Streamlit App
  - 12:00 Architecture Recap
  - 13:30 Troubleshooting
  - 14:30 Next Steps
- [ ] Add on-screen code callouts
- [ ] Add captions/subtitles
- [ ] Thumbnail: "Module 2: Cortex Analyst" with demo screenshot
- [ ] Pin comment: "Share your deployed app screenshot!"

---

## Demo Queries for Recording

**Prepare these queries to show in video:**
1. "What are the top 5 products by revenue?"
2. "What is the average order value by region?"
3. "Which customers returned the most products?"
4. "Show revenue trend by month for 2024"
5. "What percentage of orders resulted in returns?"

**Test all queries before recording** to ensure semantic model supports them.

---

## Screen Recording Notes

**Recording segments:**
1. Intro (30 sec)
2. YAML explanation (2 min)
3. SQL testing (1.5 min)
4. Code walkthrough (2.5 min)
5. Deployment (2 min)
6. Live demo (2.5 min)
7. Architecture (1.5 min)
8. Troubleshooting (1 min)
9. Closing (30 sec)

**Total raw footage:** ~20 minutes
**After editing:** ~15 minutes

**Editing tips:**
- Speed up file uploads (2x)
- Speed up SQL execution waiting (2x)
- Zoom into code editor when showing key lines
- Add text overlays for API endpoint URLs
- Highlight cursor when clicking Submit button

---

**Script Length:** ~3,200 words
**Speaking Rate:** 150 words/minute (slightly faster for demo)
**Calculated Duration:** 21 minutes
**Target Duration:** 15 minutes (after editing)

**Recording Date:** _____________
**Editor:** _____________
**Upload Date:** _____________
