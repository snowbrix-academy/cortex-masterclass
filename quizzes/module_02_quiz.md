# Module 2 Quiz: Deploy Your First Cortex Analyst App

**Total Questions:** 10
**Passing Score:** 70% (7/10 correct)
**Time Limit:** 15 minutes
**Attempts:** Unlimited

---

## Instructions

- Answer all 10 questions
- You must score 70% or higher to pass
- You can retake the quiz as many times as needed
- Some questions have multiple correct answers
- Read each question carefully

---

## Questions

### Question 1: Semantic YAML Components (Multiple Choice)

**A semantic YAML model for Cortex Analyst must include which THREE components?**

A) Tables
B) Warehouses
C) Relationships
D) Verified queries
E) User permissions

**Select all that apply.**

<details>
<summary>Answer</summary>

**Correct Answers:** A, C, D

**Explanation:** A semantic YAML model has three required sections:

1. **Tables:** Defines which Snowflake tables Cortex can query, including columns, data types, descriptions, and synonyms
2. **Relationships:** Defines how tables join together (foreign key relationships)
3. **Verified queries:** Pre-validated SQL patterns for common questions

Warehouses and user permissions are managed in Snowflake, not in the semantic model.

**Example structure:**
```yaml
tables:
  - name: CUSTOMERS
    columns: [...]

relationships:
  - name: orders_to_customers
    left_table: ORDERS
    right_table: CUSTOMERS
    ...

verified_queries:
  - name: total_revenue
    question: "What is total revenue?"
    sql: "SELECT SUM(...)"
```

**Reference:** Module 2, Section 1 - Understanding Semantic YAML
</details>

---

### Question 2: Cortex Analyst API Endpoint (Fill in the Blank)

**Complete the Cortex Analyst REST API endpoint path:**

```
/api/v2/cortex/___________/message
```

<details>
<summary>Answer</summary>

**Correct Answer:** `analyst`

**Full endpoint:**
```
/api/v2/cortex/analyst/message
```

**Usage in Python:**
```python
endpoint = "/api/v2/cortex/analyst/message"
response = send_snow_api_request(
    method="POST",
    url=endpoint,
    body={
        "messages": [...],
        "semantic_model_file": "..."
    }
)
```

**Other Cortex endpoints:**
- `/api/v2/cortex/agent:run` - Cortex Agent
- `/api/v2/databases/{db}/schemas/{schema}/cortex-search-services/{svc}:query` - Cortex Search

**Reference:** Module 2, Section 4 - Build Streamlit App
</details>

---

### Question 3: Streamlit in Snowflake Compatibility (True/False)

**True or False: In Streamlit in Snowflake (SiS), you can use `st.chat_input()` to capture user questions.**

A) True
B) False

<details>
<summary>Answer</summary>

**Correct Answer:** B) False

**Explanation:** `st.chat_input()` is **NOT supported** in Streamlit in Snowflake (SiS).

**Instead, use:**
```python
# SiS-compatible approach
question = st.text_input("Ask a question:", key="question_input")
if st.button("Submit"):
    if question:
        # Process question
```

**Other SiS incompatibilities:**
- ❌ `st.chat_message()` → Use `st.write()` with role labels
- ❌ `st.toggle()` → Use `st.checkbox()`
- ❌ `st.rerun()` → Use `st.experimental_rerun()`
- ❌ `st.divider()` → Use `st.markdown("---")`

**Reference:** Module 2, Section 4 - Build Streamlit App
</details>

---

### Question 4: Pandas Column Names (Multiple Choice)

**When you query Snowflake and convert results to a Pandas DataFrame in Streamlit, what format are the column names returned in?**

A) lowercase (e.g., `product_name`)
B) UPPERCASE (e.g., `PRODUCT_NAME`)
C) Title Case (e.g., `Product_Name`)
D) It depends on how you created the table

<details>
<summary>Answer</summary>

**Correct Answer:** B) UPPERCASE

**Explanation:** Snowflake stores all identifiers as UPPERCASE by default (unless quoted). When you query via Snowpark and convert to Pandas:

```python
df = session.sql("SELECT product_name, revenue FROM ...").to_pandas()
print(df.columns)  # ['PRODUCT_NAME', 'REVENUE']

# Accessing df['product_name'] will raise KeyError!
```

**Solution - Always normalize:**
```python
df.columns = [c.lower() for c in df.columns]
# Now you can access: df['product_name']
```

This is one of the most common SiS bugs. **Always normalize column names** after querying Snowflake.

**Reference:** Module 2, Section 4 - Code Walkthrough (Line 57)
</details>

---

### Question 5: Relationship Definition (Multiple Choice)

**Which relationship definition is CORRECT for joining ORDERS to CUSTOMERS?**

A)
```yaml
relationships:
  - name: orders_to_customers
    left_table: ORDERS
    left_column: CUSTOMER_ID
    right_table: CUSTOMERS
    right_column: CUSTOMER_ID
```

B)
```yaml
relationships:
  - name: orders_to_customers
    from: ORDERS.CUSTOMER_ID
    to: CUSTOMERS.CUSTOMER_ID
```

C)
```yaml
relationships:
  - name: orders_to_customers
    foreign_key: ORDERS.CUSTOMER_ID
    primary_key: CUSTOMERS.CUSTOMER_ID
```

D)
```yaml
relationships:
  - name: orders_to_customers
    join: ORDERS ON ORDERS.CUSTOMER_ID = CUSTOMERS.CUSTOMER_ID
```

<details>
<summary>Answer</summary>

**Correct Answer:** A

**Explanation:** Cortex Analyst uses this exact format for relationships:
```yaml
relationships:
  - name: orders_to_customers
    left_table: ORDERS
    left_column: CUSTOMER_ID
    right_table: CUSTOMERS
    right_column: CUSTOMER_ID
```

**Why this format?**
- `left_table` / `right_table`: Explicit table names
- `left_column` / `right_column`: Column names in each table
- `name`: Identifier for the relationship (can be referenced in verified queries)

Options B, C, and D use non-standard syntax that Cortex Analyst won't recognize.

**Reference:** Module 2, Section 1 - Understanding Semantic YAML
</details>

---

### Question 6: Verified Queries Purpose (Multiple Choice)

**What is the PRIMARY purpose of verified queries in a semantic YAML model?**

A) To improve security by restricting which queries users can run
B) To provide faster, pre-validated SQL for common questions
C) To automatically generate documentation
D) To train the Cortex Analyst LLM on your specific data

<details>
<summary>Answer</summary>

**Correct Answer:** B) To provide faster, pre-validated SQL for common questions

**Explanation:** Verified queries serve as pre-validated SQL templates that Cortex Analyst can use when it detects a matching question.

**Benefits:**
- **Faster:** No need to generate SQL from scratch
- **More reliable:** SQL has been tested and validated
- **Better results:** You control the exact SQL for important queries

**Example:**
```yaml
verified_queries:
  - name: total_revenue
    question: "What is the total revenue?"
    sql: |
      SELECT SUM(oi.quantity * oi.price) AS total_revenue
      FROM ORDER_ITEMS oi;
```

When a user asks "What is the total revenue?", Cortex matches this to the verified query and uses the pre-written SQL instead of generating new SQL.

**Verified queries do NOT:**
- Restrict what users can ask (they can still ask anything)
- Generate documentation automatically
- Train the model (they're used at inference time, not training)

**Reference:** Module 2, Section 1 - Verified Queries
</details>

---

### Question 7: Streamlit Deployment (Multiple Choice)

**After uploading your Streamlit Python file to a Snowflake stage, what command creates the Streamlit app?**

A) `CREATE APP cortex_analyst_app FROM @STAGE/app.py;`
B) `CREATE STREAMLIT cortex_analyst_app ROOT_LOCATION = '@STAGE' MAIN_FILE = '/app.py';`
C) `DEPLOY STREAMLIT @STAGE/app.py AS cortex_analyst_app;`
D) `CREATE OR REPLACE PYTHON APP cortex_analyst_app FROM @STAGE;`

<details>
<summary>Answer</summary>

**Correct Answer:** B

**Full command:**
```sql
CREATE OR REPLACE STREAMLIT cortex_analyst_app
  ROOT_LOCATION = '@DEMO_AI_SUMMIT.CORTEX_ANALYST_DEMO.STREAMLIT_STAGE'
  MAIN_FILE = '/app_cortex_analyst.py'
  QUERY_WAREHOUSE = COMPUTE_WH
  TITLE = 'Cortex Analyst Demo';
```

**Key parameters:**
- `ROOT_LOCATION`: Stage containing your Python files
- `MAIN_FILE`: Entry point Python file (must start with `/`)
- `QUERY_WAREHOUSE`: Warehouse for query execution
- `TITLE`: Display name in Snowsight UI

**Accessing the app:**
- Snowsight > Projects > Streamlit > cortex_analyst_app

**Reference:** Module 2, Section 5 - Deploy App to Snowflake
</details>

---

### Question 8: API Call in SiS (Multiple Choice)

**Which function should you use to call Cortex Analyst API from Streamlit in Snowflake?**

A) `requests.post()`
B) `snowflake.cortex.analyst()`
C) `_snowflake.send_snow_api_request()`
D) `st.experimental_cortex_api()`

<details>
<summary>Answer</summary>

**Correct Answer:** C) `_snowflake.send_snow_api_request()`

**Explanation:** In Streamlit in Snowflake, you MUST use the `_snowflake` module to call Snowflake APIs:

```python
from _snowflake import send_snow_api_request

response = send_snow_api_request(
    method="POST",
    url="/api/v2/cortex/analyst/message",
    body={
        "messages": [...],
        "semantic_model_file": "..."
    }
)
```

**Why not the others?**
- **A) requests.post():** Not available in SiS (no external HTTP libraries)
- **B) snowflake.cortex.analyst():** This is the SQL function, not Python API
- **D) st.experimental_cortex_api():** Doesn't exist

**Key point:** `_snowflake.send_snow_api_request()` automatically handles authentication using the current Snowflake session.

**Reference:** Module 2, Section 4 - Build Streamlit App
</details>

---

### Question 9: Synonyms in Semantic YAML (Multiple Choice)

**You add synonyms to a column definition:**
```yaml
columns:
  - name: CUSTOMER_NAME
    data_type: STRING
    description: Full customer name
    synonyms:
      - client name
      - account name
```

**What is the purpose of synonyms?**

A) To allow users to reference the column by alternative names in queries
B) To automatically rename the column in the database
C) To translate column names to different languages
D) To improve query performance

<details>
<summary>Answer</summary>

**Correct Answer:** A) To allow users to reference the column by alternative names in queries

**Explanation:** Synonyms help Cortex Analyst understand different ways users might refer to the same column.

**Example:**
Without synonyms:
- User asks: "Show me client names"
- Cortex doesn't know "client names" means CUSTOMER_NAME
- Query fails or returns wrong results

With synonyms:
- User asks: "Show me client names" or "Show me account names"
- Cortex maps "client names" → CUSTOMER_NAME
- Query succeeds

**Synonyms do NOT:**
- Change the actual database column name
- Provide translation (use multiple YAML files for internationalization)
- Impact performance (they're used during SQL generation only)

**Best practice:** Add common business terms and abbreviations as synonyms.

**Reference:** Module 2, Section 1 - Understanding Semantic YAML
</details>

---

### Question 10: Troubleshooting Scenario (Multiple Choice)

**Your Streamlit app displays this error:**
```
KeyError: 'revenue'
```

**But this SQL query works fine in Snowflake Worksheets:**
```sql
SELECT SUM(quantity * price) AS revenue
FROM order_items;
```

**What's the most likely cause?**

A) The REVENUE column doesn't exist in ORDER_ITEMS table
B) You forgot to normalize Pandas column names to lowercase
C) The Snowflake warehouse is suspended
D) The semantic model doesn't include ORDER_ITEMS table

<details>
<summary>Answer</summary>

**Correct Answer:** B) You forgot to normalize Pandas column names to lowercase

**Explanation:** This is the #1 most common Streamlit in Snowflake bug.

**What happened:**
1. Snowflake query returned column: `REVENUE` (uppercase)
2. Pandas DataFrame has column: `df.columns = ['REVENUE']`
3. Your code tried to access: `df['revenue']` (lowercase)
4. Python is case-sensitive: `'revenue' != 'REVENUE'`
5. KeyError!

**Fix:**
```python
# After converting to Pandas
df = session.sql(query).to_pandas()

# Add this line (ALWAYS):
df.columns = [c.lower() for c in df.columns]

# Now this works:
df['revenue']  # ✅
```

**Why other options are wrong:**
- **A:** If column didn't exist, SQL query would fail (but it works in Worksheets)
- **C:** Warehouse suspension doesn't cause KeyError
- **D:** If table wasn't in semantic model, Cortex wouldn't generate the SQL

**Reference:** Module 2, Troubleshooting Section - Issue 2
</details>

---

## Scoring

**Pass:** 7/10 or higher (70%)
**Fail:** 6/10 or lower (below 70%)

**If you fail:**
- Review Module 2 video (15 minutes)
- Re-read Module 2 lab README
- Review the explanation for each incorrect answer
- Pay special attention to SiS compatibility issues (Q3, Q4, Q8, Q10)
- Retake quiz (unlimited attempts)

---

## Answer Key Summary

1. A, C, D (YAML components: tables, relationships, verified queries)
2. analyst (API endpoint)
3. B (st.chat_input not supported in SiS)
4. B (Snowflake returns UPPERCASE columns)
5. A (Correct relationship format)
6. B (Verified queries = pre-validated SQL)
7. B (CREATE STREAMLIT command)
8. C (_snowflake.send_snow_api_request)
9. A (Synonyms allow alternative names)
10. B (Forgot to normalize column names)

---

## Common Patterns in Wrong Answers

**If you got Q3, Q4, Q8, or Q10 wrong:**
→ Review **Streamlit in Snowflake compatibility** section
→ Key concepts: No st.chat_input, UPPERCASE columns, _snowflake API

**If you got Q1, Q5, or Q9 wrong:**
→ Review **semantic YAML structure** section
→ Key concepts: Tables/relationships/verified queries, relationship format, synonyms

**If you got Q6 or Q7 wrong:**
→ Review **deployment process** section
→ Key concepts: Verified queries purpose, CREATE STREAMLIT syntax

---

## Quiz Implementation Notes

**For Teachable/Thinkific:**
- Use "Multiple Choice" question type
- Enable "Multiple answers" for Q1
- Use "Fill in the blank" for Q2 (accept: "analyst", "ANALYST")
- Set passing grade to 70%
- Enable unlimited attempts
- Add code blocks for Q5, Q7, Q10 (use monospace font)

**For Google Forms:**
- Use "Checkboxes" for Q1
- Use "Short answer" for Q2 (auto-accept variations)
- Use "Multiple choice" for all others
- Add images for Q10 (screenshot of error)

**For Quizizz/Kahoot:**
- Convert Q2 to multiple choice with 4 options:
  - A) agent
  - B) analyst ✅
  - C) search
  - D) complete

---

## Bonus Challenge Question (Optional)

**For students who want extra credit:**

**Bonus: Explain why this verified query is poorly designed:**

```yaml
verified_queries:
  - name: get_data
    question: "Show me the data"
    sql: "SELECT * FROM orders LIMIT 1000;"
```

<details>
<summary>Answer</summary>

**Issues:**

1. **Vague question:** "Show me the data" is too generic. Won't match actual user questions like "What are recent orders?"

2. **SELECT *:** Returns all columns. Better to specify exactly which columns are needed.

3. **No context:** Doesn't explain what this query is for (recent orders? all orders? sample data?)

4. **Arbitrary LIMIT:** Why 1000? Should be based on business requirement.

**Better version:**
```yaml
verified_queries:
  - name: recent_orders_summary
    question: "What are the most recent orders?"
    sql: |
      SELECT
          order_id,
          customer_id,
          order_date,
          total_amount,
          order_status
      FROM orders
      ORDER BY order_date DESC
      LIMIT 100;  -- Last 100 orders
```

**Best practices for verified queries:**
- Specific question that users would actually ask
- Selective columns (not SELECT *)
- Meaningful name
- Comments explaining logic
- Appropriate filters and limits

</details>

---

**Time to complete:** 10-15 minutes
**Difficulty:** Intermediate
**Focus:** Semantic YAML, SiS compatibility, API usage, troubleshooting
