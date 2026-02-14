# Module 2 Lab: Deploy Your First Cortex Analyst App

**Duration:** 60 minutes
**Difficulty:** Intermediate
**Prerequisites:** Module 1 complete (environment set up)

---

## 🎯 Learning Objectives

By completing this lab, you will:

1. **Understand semantic YAML models** (tables, relationships, verified queries)
2. **Build a Streamlit app** that calls Cortex Analyst REST API
3. **Deploy app to Snowflake** (Streamlit in Snowflake)
4. **Test natural language queries** with live data
5. **Extend semantic model** by adding new tables and relationships

**Deliverables:**
- ✅ Working Cortex Analyst Streamlit app (deployed)
- ✅ Extended semantic model (add 2 tables)
- ✅ 3 new verified queries
- ✅ GitHub PR with your changes

---

## 📋 Prerequisites

**Before starting:**
- [x] Module 1 lab complete
- [x] Snowflake environment set up (588K rows loaded)
- [x] Semantic model uploaded (@CORTEX_ANALYST_STAGE)
- [x] VS Code or text editor installed
- [x] Git configured

**Check prerequisites:**

```sql
-- Verify data exists
USE ROLE SYSADMIN;
USE WAREHOUSE COMPUTE_WH;
USE DATABASE DEMO_AI_SUMMIT;
USE SCHEMA CORTEX_ANALYST_DEMO;

SELECT COUNT(*) FROM CUSTOMERS; -- Should return 1,000
SELECT COUNT(*) FROM ORDERS;    -- Should return 50,000

-- Verify semantic model exists
LIST @CORTEX_ANALYST_STAGE;     -- Should show cortex_analyst_demo.yaml
```

**If any checks fail:** Go back to Module 1 and complete setup.

---

## 📁 Lab Structure

```
labs/module_02/
├── README.md (this file)
├── semantic_model_extended.yaml (your extended YAML - create this)
├── app_cortex_analyst.py (Streamlit app - copy and modify)
└── screenshots/ (optional - add app screenshots)
```

---

## 🚀 Part A: Guided Lab (70% - 40 minutes)

Follow the Module 2 video or use these written instructions.

### **Step 1: Understand Semantic YAML Structure** (10 minutes)

**1.1 Open Existing Semantic Model**

Open `semantic_models/cortex_analyst_demo.yaml` in VS Code.

**Structure:**
```yaml
name: Cortex Analyst Demo
description: E-commerce analytics semantic model

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
        description: Full name
        synonyms:
          - customer name
          - client name
      ...

relationships:
  - name: orders_to_customers
    left_table: ORDERS
    left_column: CUSTOMER_ID
    right_table: CUSTOMERS
    right_column: CUSTOMER_ID

verified_queries:
  - name: total_revenue
    question: "What is the total revenue?"
    sql: |
      SELECT SUM(oi.quantity * oi.price) AS total_revenue
      FROM ORDER_ITEMS oi;
```

**Three sections:**

**1. Tables:** Define which tables Cortex can query
- Database/schema/table location
- Columns with descriptions and synonyms
- Data types

**2. Relationships:** Define how tables join
- Left table + column
- Right table + column
- Relationship name

**3. Verified Queries:** Pre-validated SQL for common questions
- Question (natural language)
- SQL (validated to work)
- Name (identifier)

**1.2 Current Model Coverage**

The demo YAML includes:
- **5 tables:** CUSTOMERS, PRODUCTS, ORDERS, ORDER_ITEMS, REGIONS
- **6 relationships:** orders↔customers, order_items↔orders, order_items↔products, customers↔regions
- **5 verified queries:** total revenue, top products, regional sales, customer segmentation, monthly trends

**In Part B, you'll add:** RETURNS and PRODUCT_REVIEWS tables.

**✅ Checkpoint 1:** Understand YAML structure

---

### **Step 2: Test Cortex Analyst via SQL** (5 minutes)

**2.1 Direct API Call**

In Snowflake Worksheets:

```sql
USE ROLE SYSADMIN;
USE WAREHOUSE COMPUTE_WH;
USE DATABASE DEMO_AI_SUMMIT;
USE SCHEMA CORTEX_ANALYST_DEMO;

-- Test Cortex Analyst
SELECT SNOWFLAKE.CORTEX.ANALYST(
    'What are the top 5 products by revenue?',
    '@CORTEX_ANALYST_STAGE/cortex_analyst_demo.yaml'
) AS response;
```

**Expected response (JSON):**
```json
{
  "message": {
    "content": "Here are the top 5 products by revenue: ..."
  },
  "sql": "SELECT p.product_name, SUM(...) ...",
  "data": [
    {"product_name": "Laptop", "revenue": 125450},
    ...
  ]
}
```

**2.2 Verify Generated SQL**

Copy the SQL from the response and run it separately:

```sql
-- [Paste generated SQL here]
SELECT
    p.product_name,
    SUM(oi.quantity * oi.price) AS revenue
FROM ORDER_ITEMS oi
JOIN PRODUCTS p ON oi.product_id = p.product_id
GROUP BY p.product_name
ORDER BY revenue DESC
LIMIT 5;
```

**Results should match** the data in JSON response.

**✅ Checkpoint 2:** Cortex Analyst works via SQL

---

### **Step 3: Build Streamlit App** (15 minutes)

**3.1 Copy Base App**

```bash
# From repository root
cd streamlit_apps
cp app_cortex_analyst.py ../labs/module_02/app_cortex_analyst.py
cd ../labs/module_02
```

**3.2 Review App Code**

Open `app_cortex_analyst.py`.

**Structure:**

```python
import streamlit as st
from snowflake.snowpark.context import get_active_session
from _snowflake import send_snow_api_request
import json

# Get Snowflake session (automatic auth in SiS)
session = get_active_session()

# Semantic model path
SEMANTIC_MODEL = "@CORTEX_ANALYST_DEMO.CORTEX_ANALYST_DEMO.CORTEX_ANALYST_STAGE/cortex_analyst_demo.yaml"

def query_cortex_analyst(question):
    """Call Cortex Analyst REST API"""
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

# Streamlit UI
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
                # CRITICAL: Normalize column names (Snowflake returns UPPERCASE)
                df.columns = [c.lower() for c in df.columns]
                st.dataframe(df)
    else:
        st.warning("Please enter a question.")
```

**Key points:**

**Line 11:** `get_active_session()` — Auto-authentication in Streamlit in Snowflake

**Line 14:** Semantic model path — Must match your stage location

**Line 17-33:** `query_cortex_analyst()` function — Calls REST API

**Line 57:** `df.columns = [c.lower()]` — **CRITICAL!** Snowflake returns UPPERCASE column names. Must normalize or you'll get KeyError.

**3.3 Customize (Optional)**

You can customize:
- Title
- Description
- Add logo
- Change colors

For this lab, the base app is sufficient.

**✅ Checkpoint 3:** App code reviewed

---

### **Step 4: Deploy App to Snowflake** (10 minutes)

**4.1 Create Stage for Streamlit Apps**

In Snowflake Worksheets:

```sql
USE ROLE SYSADMIN;
USE WAREHOUSE COMPUTE_WH;
USE DATABASE DEMO_AI_SUMMIT;
USE SCHEMA CORTEX_ANALYST_DEMO;

-- Create stage
CREATE STAGE IF NOT EXISTS STREAMLIT_STAGE;

-- Verify
SHOW STAGES;
```

**4.2 Upload Python File**

**Option A: Using SnowSQL**

```bash
# From labs/module_02/
snowsql -a YOUR_ACCOUNT -u YOUR_USER \
  -q "PUT file://app_cortex_analyst.py @DEMO_AI_SUMMIT.CORTEX_ANALYST_DEMO.STREAMLIT_STAGE AUTO_COMPRESS=FALSE;"
```

**Option B: Using Snowsight UI**

1. Data > Databases > DEMO_AI_SUMMIT > CORTEX_ANALYST_DEMO > Stages
2. Click **STREAMLIT_STAGE**
3. Click **+ Files**
4. Upload `app_cortex_analyst.py`

**Verify upload:**
```sql
LIST @STREAMLIT_STAGE;
```

**Expected:** Shows `app_cortex_analyst.py`

**4.3 Create Streamlit App Object**

```sql
CREATE OR REPLACE STREAMLIT CORTEX_ANALYST_APP
  ROOT_LOCATION = '@DEMO_AI_SUMMIT.CORTEX_ANALYST_DEMO.STREAMLIT_STAGE'
  MAIN_FILE = '/app_cortex_analyst.py'
  QUERY_WAREHOUSE = COMPUTE_WH
  TITLE = 'Cortex Analyst Demo - Module 2';
```

**Expected:** `Streamlit CORTEX_ANALYST_APP created successfully`

**4.4 Grant Access (if needed)**

```sql
-- Grant access to your user
GRANT USAGE ON STREAMLIT CORTEX_ANALYST_APP TO ROLE SYSADMIN;
```

**✅ Checkpoint 4:** App deployed to Snowflake

---

### **Step 5: Test Streamlit App** (10 minutes)

**5.1 Access App**

In Snowsight:
1. Click **Projects** (left sidebar)
2. Click **Streamlit**
3. Click **CORTEX_ANALYST_APP**

**App should load** in 2-3 seconds.

**5.2 Test Queries**

Try these 5 queries:

**Query 1:**
```
What are the top 5 products by revenue?
```

**Expected:**
- Answer: Natural language summary
- Generated SQL: Joins ORDER_ITEMS and PRODUCTS
- Results table: 5 rows with product_name and revenue

**Query 2:**
```
What is the average order value by region?
```

**Expected:**
- SQL joins ORDERS → CUSTOMERS → REGIONS
- Results: 5 regions with avg_order_value

**Query 3:**
```
How many customers are in each tier?
```

**Expected:**
- SQL: GROUP BY customer_tier
- Results: Bronze/Silver/Gold counts

**Query 4:**
```
Show monthly revenue trend for 2024
```

**Expected:**
- SQL: DATE_TRUNC('month', order_date), SUM(revenue)
- Results: 12 rows (one per month)

**Query 5:**
```
Which products have the highest return rate?
```

**Expected:**
- Error! "RETURNS table not found in semantic model"
- This is expected — we'll add RETURNS in Part B

**5.3 Take Screenshots**

Capture:
- App UI with query input
- Results table
- Generated SQL

Save to `labs/module_02/screenshots/` (optional, for your records)

**✅ Checkpoint 5:** App tested and working

---

### **Part A Complete! 🎉**

You've successfully:
- ✅ Understood semantic YAML structure
- ✅ Tested Cortex Analyst via SQL
- ✅ Built and deployed Streamlit app
- ✅ Tested 4 working queries (1 intentionally failed)

**Time to complete Part A:** 40 minutes

---

## 🔥 Part B: Challenge Lab (30% - 20 minutes)

Now **extend the semantic model** to support more complex queries.

### **Challenge: Add 2 Tables to Semantic Model**

Create a new file: `labs/module_02/semantic_model_extended.yaml`

**Start by copying the original:**

```bash
cp ../../semantic_models/cortex_analyst_demo.yaml semantic_model_extended.yaml
```

**Add these 2 tables:**

#### **Table 1: RETURNS**

```yaml
tables:
  # ... existing tables ...

  - name: RETURNS
    base_table:
      database: DEMO_AI_SUMMIT
      schema: CORTEX_ANALYST_DEMO
      table: RETURNS
    description: Product returns data
    columns:
      - name: RETURN_ID
        data_type: NUMBER
        description: Unique return identifier
      - name: ORDER_ID
        data_type: NUMBER
        description: Associated order ID
      - name: PRODUCT_ID
        data_type: NUMBER
        description: Returned product ID
      - name: CUSTOMER_ID
        data_type: NUMBER
        description: Customer who returned product
      - name: RETURN_DATE
        data_type: DATE
        description: Date of return
      - name: RETURN_REASON
        data_type: STRING
        description: Reason for return (defective, wrong_item, changed_mind)
        synonyms:
          - reason
          - return reason
      - name: REFUND_AMOUNT
        data_type: FLOAT
        description: Refund amount issued
```

**Add relationships for RETURNS:**

```yaml
relationships:
  # ... existing relationships ...

  - name: returns_to_orders
    left_table: RETURNS
    left_column: ORDER_ID
    right_table: ORDERS
    right_column: ORDER_ID

  - name: returns_to_products
    left_table: RETURNS
    left_column: PRODUCT_ID
    right_table: PRODUCTS
    right_column: PRODUCT_ID

  - name: returns_to_customers
    left_table: RETURNS
    left_column: CUSTOMER_ID
    right_table: CUSTOMERS
    right_column: CUSTOMER_ID
```

#### **Table 2: PRODUCT_REVIEWS**

```yaml
  - name: PRODUCT_REVIEWS
    base_table:
      database: DEMO_AI_SUMMIT
      schema: CORTEX_ANALYST_DEMO
      table: PRODUCT_REVIEWS
    description: Customer product reviews and ratings
    columns:
      - name: REVIEW_ID
        data_type: NUMBER
        description: Unique review identifier
      - name: PRODUCT_ID
        data_type: NUMBER
        description: Product being reviewed
      - name: CUSTOMER_ID
        data_type: NUMBER
        description: Customer who wrote review
      - name: RATING
        data_type: NUMBER
        description: Rating from 1 to 5 stars
        synonyms:
          - star rating
          - product rating
      - name: REVIEW_TEXT
        data_type: STRING
        description: Review content
      - name: REVIEW_DATE
        data_type: DATE
        description: Date review was posted
```

**Add relationships for PRODUCT_REVIEWS:**

```yaml
  - name: reviews_to_products
    left_table: PRODUCT_REVIEWS
    left_column: PRODUCT_ID
    right_table: PRODUCTS
    right_column: PRODUCT_ID

  - name: reviews_to_customers
    left_table: PRODUCT_REVIEWS
    left_column: CUSTOMER_ID
    right_table: CUSTOMERS
    right_column: CUSTOMER_ID
```

---

### **Challenge: Add 3 Verified Queries**

Add these to `verified_queries` section:

**Verified Query 1: Return Rate**
```yaml
verified_queries:
  # ... existing verified queries ...

  - name: return_rate
    question: "What is the return rate?"
    sql: |
      SELECT
          COUNT(DISTINCT r.return_id) AS total_returns,
          COUNT(DISTINCT o.order_id) AS total_orders,
          (total_returns / total_orders * 100.0) AS return_rate_pct
      FROM ORDERS o
      LEFT JOIN RETURNS r ON o.order_id = r.order_id;
```

**Verified Query 2: Top Return Reasons**
```yaml
  - name: top_return_reasons
    question: "What are the most common return reasons?"
    sql: |
      SELECT
          return_reason,
          COUNT(*) AS return_count,
          ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS percentage
      FROM RETURNS
      GROUP BY return_reason
      ORDER BY return_count DESC;
```

**Verified Query 3: Products by Rating**
```yaml
  - name: products_by_rating
    question: "Which products have the highest average ratings?"
    sql: |
      SELECT
          p.product_name,
          p.category,
          AVG(pr.rating) AS avg_rating,
          COUNT(pr.review_id) AS review_count
      FROM PRODUCT_REVIEWS pr
      JOIN PRODUCTS p ON pr.product_id = p.product_id
      GROUP BY p.product_name, p.category
      HAVING COUNT(pr.review_id) >= 5  -- Only products with 5+ reviews
      ORDER BY avg_rating DESC
      LIMIT 10;
```

---

### **Test Your Extended Model**

**Step 1: Upload Extended YAML**

```sql
-- Upload new YAML (using Snowsight UI or SnowSQL)
-- File: semantic_model_extended.yaml
-- Destination: @CORTEX_ANALYST_STAGE
```

**Step 2: Test New Queries**

```sql
-- Test with extended model
SELECT SNOWFLAKE.CORTEX.ANALYST(
    'What is the return rate?',
    '@CORTEX_ANALYST_STAGE/semantic_model_extended.yaml'
) AS response;

-- Should return: "The return rate is 8.5%..."
```

**Step 3: Update Streamlit App**

Edit `app_cortex_analyst.py`, change line 14:

```python
# Before:
SEMANTIC_MODEL = "@CORTEX_ANALYST_DEMO.CORTEX_ANALYST_DEMO.CORTEX_ANALYST_STAGE/cortex_analyst_demo.yaml"

# After:
SEMANTIC_MODEL = "@CORTEX_ANALYST_DEMO.CORTEX_ANALYST_DEMO.CORTEX_ANALYST_STAGE/semantic_model_extended.yaml"
```

**Step 4: Re-deploy App**

```bash
# Upload updated Python file
snowsql -a YOUR_ACCOUNT -u YOUR_USER \
  -q "PUT file://app_cortex_analyst.py @DEMO_AI_SUMMIT.CORTEX_ANALYST_DEMO.STREAMLIT_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;"
```

```sql
-- Recreate Streamlit app (picks up new file)
CREATE OR REPLACE STREAMLIT CORTEX_ANALYST_APP
  ROOT_LOCATION = '@DEMO_AI_SUMMIT.CORTEX_ANALYST_DEMO.STREAMLIT_STAGE'
  MAIN_FILE = '/app_cortex_analyst.py'
  QUERY_WAREHOUSE = COMPUTE_WH
  TITLE = 'Cortex Analyst Demo - Extended';
```

**Step 5: Test New Queries in App**

Try these in Streamlit:

```
What is the return rate?
```
**Expected:** "The return rate is 8.5%..." with SQL and data

```
What are the most common return reasons?
```
**Expected:** Table with return_reason, return_count, percentage

```
Which products have the highest ratings?
```
**Expected:** Top 10 products by avg_rating

**✅ Part B Complete!** Your semantic model now supports returns and reviews analysis.

---

## 📤 Submission Instructions

### **Step 1: Validate Your Files**

Ensure you have:
- [ ] `semantic_model_extended.yaml` (with 7 tables, 10 relationships, 8 verified queries)
- [ ] `app_cortex_analyst.py` (updated to use extended model)
- [ ] `screenshots/` (optional)

**Validate YAML syntax:**

```bash
# Install yamllint if not installed
pip install yamllint

# Validate
yamllint semantic_model_extended.yaml
```

**Expected:** No errors (warnings about line length are OK)

### **Step 2: Test All Queries**

In Streamlit app, test:
- [ ] "What are the top 5 products by revenue?" (original query)
- [ ] "What is the return rate?" (new query)
- [ ] "What are the most common return reasons?" (new query)
- [ ] "Which products have the highest ratings?" (new query)

All should work without errors.

### **Step 3: Commit to Git**

```bash
# From repository root
git checkout -b lab-module-02

# Add your files
git add labs/module_02/semantic_model_extended.yaml
git add labs/module_02/app_cortex_analyst.py

# Commit
git commit -m "Add Module 2 lab: Extended semantic model with RETURNS and PRODUCT_REVIEWS

Added to semantic model:
- RETURNS table (7 columns, 3 relationships)
- PRODUCT_REVIEWS table (6 columns, 2 relationships)
- 3 new verified queries (return rate, return reasons, product ratings)

Updated Streamlit app to use extended model.
Tested all queries successfully in Snowflake.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"

# Push to your fork
git push origin lab-module-02
```

### **Step 4: Create Pull Request**

Use this template:

```markdown
## Module 2 Lab Submission

### Part A: Deploy Cortex Analyst App
- [x] Understood semantic YAML structure
- [x] Tested Cortex Analyst via SQL
- [x] Built Streamlit app (50 lines)
- [x] Deployed to Snowflake
- [x] Tested 5 queries (4 working, 1 intentionally failed)

### Part B: Extend Semantic Model
- [x] Added RETURNS table (7 columns, 3 relationships)
- [x] Added PRODUCT_REVIEWS table (6 columns, 2 relationships)
- [x] Added 3 verified queries:
  - return_rate: "What is the return rate?"
  - top_return_reasons: "Most common return reasons"
  - products_by_rating: "Products with highest ratings"
- [x] Updated Streamlit app to use extended model
- [x] Tested all new queries successfully

### Key Insights
[Share 2-3 interesting findings, e.g.:
- "Return rate is 8.5%, highest for Electronics (12%)"
- "Top return reason: 'changed_mind' (45% of returns)"
- "Products with 4.5+ rating have 30% lower return rates"]

### Challenges Faced
[Optional: What was difficult? How did you solve it?
Example: "YAML indentation errors - used yamllint to validate"]

### Time Spent
- Part A: [X] minutes
- Part B: [X] minutes
- Total: [X] minutes

### Questions/Feedback
[Any questions or feedback on lab difficulty]
```

### **Step 5: Merge PR**

Once GitHub Actions checks pass ✅, merge your PR.

**🎉 Module 2 Complete!**

---

## 🛠️ Troubleshooting

### **Issue: "Cortex Analyst API endpoint not found (404)"**

**Solution:** Verify semantic model path is correct:
```sql
LIST @CORTEX_ANALYST_STAGE;
-- Verify file name matches exactly
```

### **Issue: "KeyError: 'revenue' in Streamlit"**

**Solution:** Add column normalization:
```python
df.columns = [c.lower() for c in df.columns]
```

### **Issue: "YAML validation error: expected <block end>"**

**Solution:** Check indentation (use 2 spaces, not tabs):
```bash
yamllint semantic_model_extended.yaml
```

### **Issue: "Streamlit app not updating after file change"**

**Solution:** Use `OVERWRITE=TRUE` when uploading:
```bash
snowsql -q "PUT file://app.py @STAGE OVERWRITE=TRUE;"
```

Then recreate Streamlit object.

### **Issue: "Query returns empty results"**

**Solution:** Verify data exists:
```sql
SELECT COUNT(*) FROM RETURNS;  -- Should be 5,000
SELECT COUNT(*) FROM PRODUCT_REVIEWS;  -- Should be 10,000
```

---

## 📚 Additional Resources

**Snowflake Docs:**
- [Cortex Analyst Semantic Models](https://docs.snowflake.com/en/user-guide/cortex-analyst-semantic-model)
- [Streamlit in Snowflake](https://docs.snowflake.com/en/developer-guide/streamlit/about-streamlit)

**Course Docs:**
- [Troubleshooting Guide](../../docs/troubleshooting.md)
- [Snowflake AI APIs](../../memory/snowflake-ai-apis.md)

**Community:**
- [GitHub Discussions](https://github.com/snowbrix-academy/cortex-masterclass/discussions)

---

## ✅ Module 2 Checklist

- [ ] Semantic YAML structure understood
- [ ] Cortex Analyst tested via SQL
- [ ] Streamlit app built and deployed
- [ ] 5 original queries tested
- [ ] RETURNS table added to YAML
- [ ] PRODUCT_REVIEWS table added to YAML
- [ ] 3 verified queries added
- [ ] Extended model uploaded to stage
- [ ] App updated to use extended model
- [ ] All new queries tested successfully
- [ ] Files committed to Git
- [ ] Pull request created
- [ ] GitHub Actions checks pass ✅
- [ ] PR merged to master

**Ready for Module 3!** 🚀

---

**Estimated Time:**
- Part A: 40 minutes
- Part B: 20 minutes
- **Total: 60 minutes**

**Production-Grade Data Engineering. No Fluff.**
