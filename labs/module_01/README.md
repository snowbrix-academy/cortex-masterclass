# Module 1 Lab: Set Up Your Snowflake AI Workspace

**Duration:** 45 minutes
**Difficulty:** Beginner
**Prerequisites:** None (fresh start)

---

## 🎯 Learning Objectives

By completing this lab, you will:

1. **Create a Snowflake trial account** with Cortex services enabled
2. **Load production-grade sample data** (12 tables, 588,000 rows)
3. **Verify environment setup** using SQL queries
4. **Explore data relationships** to understand the schema
5. **Prepare for Cortex Analyst** by setting up stages and semantic models

**Deliverables:**
- ✅ Working Snowflake environment (verified)
- ✅ 5 exploratory SQL queries (Part B)
- ✅ GitHub PR with your queries

---

## 📋 Prerequisites

**Before starting:**
- [ ] Email account (for Snowflake trial)
- [ ] Web browser (Chrome, Firefox, Edge)
- [ ] Git installed locally
- [ ] GitHub account

**No prior Snowflake experience required.** This lab walks you through everything.

---

## 📁 Lab Structure

```
labs/module_01/
├── README.md (this file)
├── queries.sql (your Part B queries - create this)
└── screenshots/ (optional - add verification screenshots)
```

---

## 🚀 Part A: Guided Lab (70% - 30 minutes)

Follow the Module 1 video or use these written instructions.

### **Step 1: Create Snowflake Trial Account** (5 minutes)

**1.1 Sign Up**

Go to: https://signup.snowflake.com/

**Form details:**
- Email: [Your email]
- Edition: **Enterprise** (for Cortex access)
- Cloud: **AWS**
- Region: **US East (N. Virginia)** or **US West (Oregon)**

**Why these regions?** Cortex Analyst is only available in us-east-1 and us-west-2.

**1.2 Activate Account**

- Check email for activation link
- Set password (save it!)
- Log in to Snowsight

**1.3 Verify Cortex Services**

Open **Worksheets** (left sidebar), create new worksheet, paste:

```sql
-- Check Cortex services
SELECT SYSTEM$CORTEX_ANALYST_STATUS() AS analyst_status;
SELECT SYSTEM$CORTEX_AGENT_STATUS() AS agent_status;
SELECT SYSTEM$CORTEX_SEARCH_STATUS() AS search_status;

-- Check your region
SELECT CURRENT_REGION() AS region;
```

**Run all queries.**

**Expected results:**
```
analyst_status: ENABLED
agent_status: ENABLED
search_status: ENABLED
region: us-east-1 (or us-west-2)
```

**❌ If you see DISABLED:**

```sql
-- Enable cross-region Cortex (requires ACCOUNTADMIN)
USE ROLE ACCOUNTADMIN;
ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';

-- Verify again
SELECT SYSTEM$CORTEX_ANALYST_STATUS();
```

Should now return `ENABLED`.

**✅ Checkpoint 1:** Cortex services enabled

---

### **Step 2: Clone Course Repository** (5 minutes)

**2.1 Clone Repo**

Open terminal:

```bash
# Clone repository
git clone https://github.com/snowbrix-academy/cortex-masterclass.git
cd cortex-masterclass

# Verify files
ls sql_scripts/
```

**Expected output:**
```
01_infrastructure.sql
02_dimensions.sql
03_sales_fact.sql
05_agent_tables.sql
06_document_ai.sql
07_cortex_search.sql
RUN_ALL_SCRIPTS.sql
VERIFY_ALL.sql
```

**2.2 Review RUN_ALL_SCRIPTS.sql**

Open `sql_scripts/RUN_ALL_SCRIPTS.sql` in VS Code or any text editor.

**Structure:**
```sql
-- Section 1: Infrastructure (databases, warehouses, roles)
-- Section 2: Dimension tables (customers, products, regions)
-- Section 3: Fact tables (orders, order_items)
-- Section 4: Agent tables (inventory, suppliers)
-- Section 5: Document AI tables
-- Section 6: Verification queries
```

**3,000+ lines of SQL.** Don't worry — it runs in 2 minutes.

**✅ Checkpoint 2:** Repository cloned

---

### **Step 3: Load Data** (10 minutes)

**3.1 Run Setup Script**

In Snowflake Worksheets:

1. Create new worksheet
2. Open `sql_scripts/RUN_ALL_SCRIPTS.sql`
3. **Copy entire file** (Ctrl+A, Ctrl+C)
4. **Paste into worksheet** (Ctrl+V)
5. **Click "Run All"** button (▶▶)

**What happens:**
- Creates 4 databases: DEMO_AI_SUMMIT, MDF_RAW_DB, MDF_STAGING_DB, MDF_CURATED_DB
- Creates 1 warehouse: COMPUTE_WH (size: MEDIUM, auto-suspend: 60 sec)
- Creates 12 tables with sample data
- Loads 588,000 rows

**Execution time:** ~90-120 seconds

**Watch the results panel:** You'll see each script executing:
```
Creating warehouse COMPUTE_WH... ✅
Creating database DEMO_AI_SUMMIT... ✅
Loading CUSTOMERS... 1,000 rows ✅
Loading PRODUCTS... 500 rows ✅
Loading ORDERS... 50,000 rows ✅
Loading ORDER_ITEMS... 150,000 rows ✅
...
```

**3.2 Troubleshooting**

**Error: "Insufficient privileges to CREATE DATABASE"**

```sql
-- Switch to ACCOUNTADMIN role
USE ROLE ACCOUNTADMIN;

-- Re-run script
```

**Error: "Warehouse 'COMPUTE_WH' does not exist"**

```sql
-- Create warehouse first
CREATE WAREHOUSE IF NOT EXISTS COMPUTE_WH
  WAREHOUSE_SIZE = 'MEDIUM'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE;

USE WAREHOUSE COMPUTE_WH;
```

**✅ Checkpoint 3:** Data loaded (588K rows)

---

### **Step 4: Verify Data** (5 minutes)

**4.1 Run Verification Script**

Create new worksheet, paste:

```sql
-- From sql_scripts/VERIFY_ALL.sql
USE ROLE SYSADMIN;
USE WAREHOUSE COMPUTE_WH;
USE DATABASE DEMO_AI_SUMMIT;
USE SCHEMA CORTEX_ANALYST_DEMO;

-- Check row counts
SELECT 'CUSTOMERS' AS table_name, COUNT(*) AS row_count FROM CUSTOMERS
UNION ALL
SELECT 'PRODUCTS', COUNT(*) FROM PRODUCTS
UNION ALL
SELECT 'REGIONS', COUNT(*) FROM REGIONS
UNION ALL
SELECT 'ORDERS', COUNT(*) FROM ORDERS
UNION ALL
SELECT 'ORDER_ITEMS', COUNT(*) FROM ORDER_ITEMS
UNION ALL
SELECT 'RETURNS', COUNT(*) FROM RETURNS
UNION ALL
SELECT 'PRODUCT_REVIEWS', COUNT(*) FROM PRODUCT_REVIEWS
UNION ALL
SELECT 'INVENTORY', COUNT(*) FROM INVENTORY
UNION ALL
SELECT 'SUPPLIERS', COUNT(*) FROM SUPPLIERS
ORDER BY table_name;
```

**Expected results:**

| TABLE_NAME       | ROW_COUNT |
|------------------|-----------|
| CUSTOMERS        | 1,000     |
| INVENTORY        | 1,000     |
| ORDERS           | 50,000    |
| ORDER_ITEMS      | 150,000   |
| PRODUCTS         | 500       |
| PRODUCT_REVIEWS  | 10,000    |
| REGIONS          | 5         |
| RETURNS          | 5,000     |
| SUPPLIERS        | 50        |

**Total: 217,555 rows** (plus document AI tables)

**4.2 Test Joins**

Verify table relationships work:

```sql
-- Test: Customers → Orders → Order Items → Products
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

**Expected:** 10 rows with meaningful data (no NULLs, valid dates)

**✅ Checkpoint 4:** Data verified

---

### **Step 5: Set Up Cortex Analyst Stage** (5 minutes)

**5.1 Create Stage**

```sql
USE ROLE SYSADMIN;
USE WAREHOUSE COMPUTE_WH;
USE DATABASE DEMO_AI_SUMMIT;
USE SCHEMA CORTEX_ANALYST_DEMO;

-- Create stage for semantic models
CREATE STAGE IF NOT EXISTS CORTEX_ANALYST_STAGE;

-- Verify
SHOW STAGES;
```

**Expected:** CORTEX_ANALYST_STAGE appears in list

**5.2 Upload Semantic Model**

**Option A: Using SnowSQL (if installed)**

```bash
# From repository root
cd semantic_models

snowsql -a YOUR_ACCOUNT -u YOUR_USER \
  -q "PUT file://cortex_analyst_demo.yaml @DEMO_AI_SUMMIT.CORTEX_ANALYST_DEMO.CORTEX_ANALYST_STAGE AUTO_COMPRESS=FALSE;"
```

**Option B: Using Snowsight UI**

1. In Snowsight: Data > Databases > DEMO_AI_SUMMIT > CORTEX_ANALYST_DEMO > Stages
2. Click **CORTEX_ANALYST_STAGE**
3. Click **+ Files**
4. Upload `semantic_models/cortex_analyst_demo.yaml`

**5.3 Verify Upload**

```sql
LIST @CORTEX_ANALYST_STAGE;
```

**Expected output:**
```
name: cortex_analyst_demo.yaml
size: 13,407 bytes
md5: [hash]
```

**✅ Checkpoint 5:** Semantic model uploaded

---

### **Part A Complete! 🎉**

You've successfully:
- ✅ Created Snowflake trial account
- ✅ Enabled Cortex services
- ✅ Loaded 588K rows across 12 tables
- ✅ Verified data and relationships
- ✅ Uploaded semantic model to stage

**Time to complete Part A:** 30 minutes

---

## 🔥 Part B: Challenge Lab (30% - 15 minutes)

Now that your environment is set up, **explore the data on your own.**

### **Challenge: Write 5 Exploratory Queries**

Create a file: `labs/module_01/queries.sql`

Write SQL queries to answer these questions:

**Query 1: Top Revenue Products**
```sql
-- Q1: What are the top 5 products by total revenue?
-- Hint: Join ORDER_ITEMS and PRODUCTS, calculate revenue = quantity × price
-- TODO: Write your query here
```

**Query 2: Regional Analysis**
```sql
-- Q2: Which region has the highest average order value?
-- Hint: Join ORDERS, CUSTOMERS, and REGIONS
-- TODO: Write your query here
```

**Query 3: Return Rate**
```sql
-- Q3: What percentage of orders resulted in returns?
-- Hint: Count RETURNS / Count ORDERS × 100
-- TODO: Write your query here
```

**Query 4: Customer Segmentation**
```sql
-- Q4: How many customers are in each tier (Gold, Silver, Bronze)?
-- Hint: GROUP BY customer_tier in CUSTOMERS table
-- TODO: Write your query here
```

**Query 5: Product Ratings**
```sql
-- Q5: What's the average rating for each product category?
-- Hint: Join PRODUCT_REVIEWS and PRODUCTS, GROUP BY category
-- TODO: Write your query here
```

### **Success Criteria**

Your queries should:
- ✅ Execute without errors
- ✅ Return meaningful results (not empty)
- ✅ Use appropriate JOINs (no cartesian products)
- ✅ Include comments explaining your logic
- ✅ Follow SQL formatting (readable)

**Example well-formatted query:**
```sql
-- Q1: Top 5 products by revenue
-- Business context: Helps identify best-selling products for inventory planning
SELECT
    p.product_name,
    p.category,
    SUM(oi.quantity * oi.price) AS total_revenue,
    COUNT(DISTINCT o.order_id) AS order_count
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
JOIN orders o ON oi.order_id = o.order_id
GROUP BY p.product_name, p.category
ORDER BY total_revenue DESC
LIMIT 5;
```

---

## 📤 Submission Instructions

### **Step 1: Create Your Queries File**

Create `labs/module_01/queries.sql` with your 5 queries.

### **Step 2: Test Your Queries**

Run all queries in Snowflake Worksheets. Verify:
- No syntax errors
- Results make sense
- Performance is reasonable (<5 seconds)

### **Step 3: Commit to Git**

```bash
# From repository root
git checkout -b lab-module-01

# Add your file
git add labs/module_01/queries.sql

# Commit
git commit -m "Add Module 1 lab: 5 exploratory queries

Completed queries:
- Q1: Top 5 products by revenue
- Q2: Region with highest avg order value
- Q3: Return rate percentage
- Q4: Customer segmentation by tier
- Q5: Average product ratings by category

All queries tested and verified in Snowflake.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"

# Push to your fork
git push origin lab-module-01
```

### **Step 4: Create Pull Request**

1. Go to: `https://github.com/YOUR-USERNAME/cortex-masterclass`
2. Click "Compare & pull request"
3. **Base:** YOUR-USERNAME/cortex-masterclass, branch: master
4. **Compare:** lab-module-01
5. **Title:** "Module 1 Lab Submission"
6. **Description:** Use this template:

```markdown
## Module 1 Lab Submission

### Part A: Environment Setup
- [x] Snowflake trial account created
- [x] Cortex services verified (ENABLED)
- [x] Data loaded (588,000 rows verified)
- [x] Semantic model uploaded to stage

### Part B: Exploratory Queries
- [x] Q1: Top 5 products by revenue
- [x] Q2: Region with highest avg order value
- [x] Q3: Return rate percentage
- [x] Q4: Customer segmentation by tier
- [x] Q5: Average product ratings by category

### Key Insights
[Share 2-3 interesting findings from your queries, e.g.:
- "Region West has 30% higher avg order value than other regions"
- "Gold tier customers represent only 10% but generate 45% of revenue"
- "Product return rate is 8.5%, highest for Electronics category"]

### Time Spent
- Part A: [X] minutes
- Part B: [X] minutes
- Total: [X] minutes

### Questions/Feedback
[Optional: Any questions for instructor or feedback on lab difficulty]
```

6. **Create pull request**

### **Step 5: Automated Checks**

GitHub Actions will run 4 checks:
1. ✅ SQL syntax validation (sqlfluff)
2. ✅ Query formatting
3. ✅ No SQL injection patterns
4. ✅ No hardcoded credentials

**If checks fail:** View details, fix issues locally, commit, and push again.

### **Step 6: Merge PR**

Once all checks pass ✅:
- Click "Merge pull request"
- Click "Confirm merge"

**🎉 Module 1 Complete!**

---

## 🛠️ Troubleshooting

### **Issue: "Cortex services show DISABLED"**

**Solution:**
```sql
USE ROLE ACCOUNTADMIN;
ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';
```

### **Issue: "SELECT COUNT(*) FROM CUSTOMERS returns 0"**

**Solution:** Data didn't load. Re-run `RUN_ALL_SCRIPTS.sql`

### **Issue: "Stage file upload failed"**

**Solution:** Use Snowsight UI upload (Data > Stages > + Files)

### **Issue: "Query takes >30 seconds"**

**Solution:** Add WHERE clause to limit data:
```sql
WHERE order_date >= '2024-01-01'
```

### **Issue: "Git push rejected"**

**Solution:**
```bash
# Pull latest changes first
git pull origin master

# Resolve conflicts (if any), then push
git push origin lab-module-01
```

---

## 📚 Additional Resources

**Snowflake Docs:**
- [Cortex Analyst](https://docs.snowflake.com/en/user-guide/cortex-analyst)
- [Snowflake Trial](https://docs.snowflake.com/en/user-guide/admin-trial-account)

**Course Docs:**
- [Setup Guide](../../docs/setup_guide.md)
- [Troubleshooting](../../docs/troubleshooting.md)
- [GitHub Workflow](../../docs/github_workflow.md)

**Community:**
- [GitHub Discussions](https://github.com/snowbrix-academy/cortex-masterclass/discussions)
- [GitHub Issues](https://github.com/snowbrix-academy/cortex-masterclass/issues)

---

## ✅ Module 1 Checklist

- [ ] Snowflake trial account created
- [ ] Cortex services enabled (ENABLED status)
- [ ] Course repository cloned
- [ ] RUN_ALL_SCRIPTS.sql executed successfully
- [ ] VERIFY_ALL.sql confirms 588K rows
- [ ] CORTEX_ANALYST_STAGE created
- [ ] Semantic model uploaded (cortex_analyst_demo.yaml)
- [ ] 5 exploratory queries written and tested
- [ ] queries.sql committed to Git
- [ ] Pull request created to your fork
- [ ] GitHub Actions checks pass ✅
- [ ] PR merged to master

**Ready for Module 2!** 🚀

---

**Estimated Time:**
- Part A: 30 minutes
- Part B: 15 minutes
- **Total: 45 minutes**

**Need help?** Post in [GitHub Discussions](https://github.com/snowbrix-academy/cortex-masterclass/discussions) or open an [Issue](https://github.com/snowbrix-academy/cortex-masterclass/issues).

**Production-Grade Data Engineering. No Fluff.**
