# Troubleshooting Guide — Snowflake Cortex Masterclass

Common errors and how to fix them.

---

## Table of Contents

1. [Snowflake Setup Issues](#snowflake-setup-issues)
2. [Cortex API Errors](#cortex-api-errors)
3. [Semantic YAML Issues](#semantic-yaml-issues)
4. [Streamlit in Snowflake (SiS) Issues](#streamlit-in-snowflake-sis-issues)
5. [Git Workflow Issues](#git-workflow-issues)
6. [Data Loading Issues](#data-loading-issues)
7. [GitHub Actions CI/CD Issues](#github-actions-cicd-issues)

---

## Snowflake Setup Issues

### ❌ Error: "CORTEX_ANALYST not available in region"

**Cause:** Cortex services are only available in specific AWS regions (us-east-1, us-west-2).

**Fix:**
```sql
-- Option 1: Enable cross-region access (requires ACCOUNTADMIN)
USE ROLE ACCOUNTADMIN;
ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';

-- Option 2: Create new trial account in us-east-1 or us-west-2
```

---

### ❌ Error: "Insufficient privileges to CREATE DATABASE"

**Cause:** User doesn't have CREATE DATABASE privilege.

**Fix:**
```sql
-- Check current role
SELECT CURRENT_ROLE();

-- Switch to ACCOUNTADMIN (Snowflake trial accounts have this)
USE ROLE ACCOUNTADMIN;

-- Grant privilege to your user
GRANT CREATE DATABASE ON ACCOUNT TO ROLE SYSADMIN;
USE ROLE SYSADMIN;
```

---

### ❌ Error: "Warehouse 'COMPUTE_WH' does not exist"

**Cause:** Default warehouse not created or dropped.

**Fix:**
```sql
-- Create warehouse
CREATE WAREHOUSE IF NOT EXISTS COMPUTE_WH
  WAREHOUSE_SIZE = 'MEDIUM'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE;

-- Use warehouse
USE WAREHOUSE COMPUTE_WH;
```

---

## Cortex API Errors

### ❌ Error: "HTTP 404: Cortex Analyst API endpoint not found"

**Cause:** Semantic model file path incorrect or model not uploaded.

**Fix:**
```python
# Correct path format for Cortex Analyst
semantic_model_path = "@CORTEX_ANALYST_DEMO.CORTEX_ANALYST_DEMO.CORTEX_ANALYST_STAGE/cortex_analyst_demo.yaml"

# Verify stage exists
# SQL: SHOW STAGES IN SCHEMA CORTEX_ANALYST_DEMO;
```

---

### ❌ Error: "Cortex Agent timeout after 60 seconds"

**Cause:** Agent tool calls taking too long (complex queries, large datasets).

**Fix:**
1. **Optimize SQL queries** (add WHERE filters, LIMIT results)
2. **Reduce tool complexity** (break into smaller tools)
3. **Increase warehouse size** (MEDIUM → LARGE)

```sql
-- Increase warehouse size for faster queries
ALTER WAREHOUSE COMPUTE_WH SET WAREHOUSE_SIZE = 'LARGE';
```

---

### ❌ Error: "Cortex Search returns no results"

**Cause:** Search service not indexed yet, or TARGETLAG too high.

**Fix:**
```sql
-- Check search service status
SHOW CORTEX SEARCH SERVICES IN SCHEMA CORTEX_ANALYST_DEMO;

-- If status = 'INDEXING', wait a few minutes

-- Tune TARGETLAG (lower = fresher index, higher cost)
ALTER CORTEX SEARCH SERVICE doc_search_service
  SET TARGET_LAG = '1 minute';
```

---

## Semantic YAML Issues

### ❌ Error: "YAML indentation error: expected <key>, found <value>"

**Cause:** Incorrect indentation (mixing tabs and spaces, or wrong spacing).

**Fix:**
- **Use 2 spaces for indentation** (NOT tabs)
- Validate with `yamllint`:

```bash
# Install yamllint
pip install yamllint

# Validate YAML
yamllint semantic_models/cortex_analyst_demo.yaml

# Common issues:
# - Line 42: Use 2 spaces, not 4
# - Line 58: Don't mix tabs and spaces
# - Line 73: Missing colon after key
```

**Before (incorrect):**
```yaml
tables:
    - name: ORDERS  # 4 spaces (wrong)
      base_table:
      	database: DEMO  # Tab character (wrong)
```

**After (correct):**
```yaml
tables:
  - name: ORDERS  # 2 spaces
    base_table:
      database: DEMO  # 2 spaces
```

---

### ❌ Error: "Semantic model validation failed: relationship not found"

**Cause:** Foreign key relationship defined but referenced table/column doesn't exist.

**Fix:**
```yaml
# Ensure both tables exist and column names match exactly

# Correct relationship definition:
relationships:
  - name: orders_to_customers
    left_table: ORDERS
    left_column: CUSTOMER_ID
    right_table: CUSTOMERS
    right_column: CUSTOMER_ID
```

**Verify in SQL:**
```sql
-- Check column exists in both tables
DESC TABLE ORDERS;
DESC TABLE CUSTOMERS;

-- Verify foreign key values match
SELECT DISTINCT o.CUSTOMER_ID
FROM ORDERS o
LEFT JOIN CUSTOMERS c ON o.CUSTOMER_ID = c.CUSTOMER_ID
WHERE c.CUSTOMER_ID IS NULL;
-- Should return 0 rows (all foreign keys valid)
```

---

### ❌ Error: "Verified query returns empty results"

**Cause:** Sample query doesn't match actual data, or aggregation returns NULL.

**Fix:**
```yaml
# Test your verified_queries in Snowflake Worksheets first

verified_queries:
  - name: top_products_by_revenue
    question: "What are the top 5 products by revenue?"
    sql: |
      SELECT
        p.product_name,
        SUM(oi.quantity * oi.price) AS revenue
      FROM ORDER_ITEMS oi
      JOIN PRODUCTS p ON oi.product_id = p.product_id
      GROUP BY p.product_name
      ORDER BY revenue DESC
      LIMIT 5;
    # ⚠️ Test this SQL returns 5 rows before adding to YAML
```

---

## Streamlit in Snowflake (SiS) Issues

### ❌ Error: "st.chat_input() not found"

**Cause:** `st.chat_input()` is not supported in Streamlit in Snowflake (SiS).

**Fix:** Use `st.text_input()` + `st.button()` instead.

**Before (doesn't work in SiS):**
```python
user_query = st.chat_input("Ask a question")
if user_query:
    # Process query
```

**After (SiS-compatible):**
```python
user_query = st.text_input("Ask a question", key="query_input")
if st.button("Submit"):
    if user_query:
        # Process query
```

---

### ❌ Error: "KeyError: column 'REVENUE' not found"

**Cause:** Snowflake returns UPPERCASE column names, but code expects lowercase.

**Fix:** Normalize column names after query:

```python
# Execute Snowflake query
df = session.sql("SELECT product_name, SUM(revenue) AS revenue FROM ...").to_pandas()

# ⚠️ Snowflake returns uppercase: ['PRODUCT_NAME', 'REVENUE']

# Normalize to lowercase
df.columns = [c.lower() for c in df.columns]

# Now you can access: df['revenue'] ✅
```

---

### ❌ Error: "st.rerun() not found"

**Cause:** `st.rerun()` not available in older SiS versions.

**Fix:** Use `st.experimental_rerun()` instead.

```python
# SiS-compatible rerun
if st.button("Reset"):
    st.experimental_rerun()
```

---

### ❌ Error: "API call failed: _snowflake.send_message() not defined"

**Cause:** Incorrect API call function for SiS.

**Fix:** Use `_snowflake.send_snow_api_request()` for ALL Cortex API calls:

```python
# ❌ Wrong (doesn't work in SiS)
response = _snowflake.send_message(endpoint, body)

# ✅ Correct (SiS-compatible)
response = _snowflake.send_snow_api_request(
    method="POST",
    url=endpoint,
    body=body
)
```

---

## Git Workflow Issues

### ❌ Error: "Permission denied (publickey)"

**Cause:** SSH key not set up for GitHub.

**Fix:**
```bash
# Option 1: Use HTTPS instead of SSH
git remote set-url origin https://github.com/YOUR-USERNAME/cortex-masterclass.git

# Option 2: Set up SSH key
ssh-keygen -t ed25519 -C "your_email@example.com"
# Add public key to GitHub: Settings > SSH and GPG keys
```

---

### ❌ Error: "fatal: refusing to merge unrelated histories"

**Cause:** Local and remote repos have different commit histories.

**Fix:**
```bash
git pull origin master --allow-unrelated-histories
```

---

### ❌ Error: "Commit rejected: secrets detected"

**Cause:** Accidentally committing `.env` file or credentials.

**Fix:**
```bash
# Remove from staging
git reset HEAD .env

# Add to .gitignore
echo ".env" >> .gitignore
echo "credentials.json" >> .gitignore

# If already committed, remove from history
git rm --cached .env
git commit -m "Remove .env from version control"
```

---

### ❌ Error: "PR checks failed: SQL syntax error"

**Cause:** SQL file has syntax errors (missing semicolons, reserved keywords).

**Fix:**
```bash
# Install sqlfluff locally
pip install sqlfluff

# Lint SQL files
sqlfluff lint labs/module_02/*.sql --dialect snowflake

# Fix automatically
sqlfluff fix labs/module_02/*.sql --dialect snowflake

# Common issues:
# - Missing semicolons at end of statements
# - Reserved keyword 'rows' used (use 'row_count' instead)
# - Missing commas in SELECT lists
```

---

## Data Loading Issues

### ❌ Error: "SELECT COUNT(*) FROM CUSTOMERS returns 0"

**Cause:** Data not loaded or script failed silently.

**Fix:**
```sql
-- Check if script ran
SELECT * FROM CUSTOMERS LIMIT 10;

-- If empty, re-run data loading script
-- Copy contents of sql_scripts/02_dimensions.sql (lines 1-80)
-- Execute in Snowflake Worksheets

-- Verify row count
SELECT COUNT(*) FROM CUSTOMERS;
-- Expected: 1000
```

---

### ❌ Error: "Number of columns in file (5) does not match table (7)"

**Cause:** CSV file structure doesn't match table definition.

**Fix:**
```sql
-- Check table structure
DESC TABLE CUSTOMERS;

-- Ensure CSV has matching columns
-- Or use COPY INTO with column mapping:
COPY INTO CUSTOMERS (customer_id, name, email, tier, region_id)
FROM @my_stage/customers.csv
FILE_FORMAT = (TYPE = CSV SKIP_HEADER = 1);
```

---

### ❌ Error: "COPY INTO failed: file not found in stage"

**Cause:** File not uploaded to stage or wrong path.

**Fix:**
```sql
-- List files in stage
LIST @CORTEX_ANALYST_DEMO.CORTEX_ANALYST_DEMO.CORTEX_ANALYST_STAGE;

-- Upload file (if using SnowSQL)
PUT file:///path/to/file.csv @my_stage AUTO_COMPRESS=FALSE;

-- Verify
LIST @my_stage;
```

---

## GitHub Actions CI/CD Issues

### ❌ Error: "sqlfluff command not found in GitHub Actions"

**Cause:** Dependencies not installed in CI pipeline.

**Fix:** Already handled in `.github/workflows/lab-checks.yml`:

```yaml
- name: Install dependencies
  run: |
    pip install sqlfluff==2.3.5
    pip install black==23.12.1
    pip install flake8==7.0.0
    pip install yamllint==1.33.0
```

If still failing, check GitHub Actions logs for specific error.

---

### ❌ Error: "PR checks failed but no error message"

**Cause:** GitHub Actions workflow syntax error or permission issue.

**Fix:**
1. Go to GitHub repo > Actions tab
2. Click failed workflow run
3. Expand failed step to see error details
4. Common issues:
   - YAML indentation in workflow file
   - Missing permissions (need write access to repo)

---

## Interview Trap: "My Streamlit app works locally but fails in Snowflake"

**Wrong Answer:**
"I don't know, Snowflake is broken."

**Correct Answer (From Course):**
"Streamlit in Snowflake (SiS) has compatibility differences vs local Streamlit:
1. **No st.chat_input()** → Use st.text_input() + st.button()
2. **Uppercase Pandas columns** → df.columns = [c.lower() for c in df.columns]
3. **No st.rerun()** → Use st.experimental_rerun()
4. **API calls use _snowflake.send_snow_api_request()** (not send_message)
5. **No st.toggle()** → Use st.checkbox()

Always test in SiS environment before assuming it works."

---

## Still Stuck?

1. **Check course docs:**
   - [Setup Guide](setup_guide.md)
   - [GitHub Workflow](github_workflow.md)

2. **Search GitHub Issues:**
   https://github.com/snowbrix-academy/cortex-masterclass/issues

3. **Ask in Discussions:**
   https://github.com/snowbrix-academy/cortex-masterclass/discussions

4. **Office Hours:**
   Weekly Q&A sessions (check course announcements)

---

**Most issues = YAML indentation, SiS compatibility, or uppercase columns.** Check these first! ✅
