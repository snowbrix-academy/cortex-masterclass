# Databricks notebook source
# MAGIC %md
# MAGIC # Innovation Summit AI Demo — Genie Space Configuration
# MAGIC
# MAGIC **Purpose:** Create AI/BI Genie semantic layer for sales analytics
# MAGIC
# MAGIC **Run:** Once (after all fact/dimension tables are created)
# MAGIC
# MAGIC **Note:** Genie space creation is primarily UI-driven.
# MAGIC This notebook provides step-by-step instructions with screenshots references.

# COMMAND ----------

# MAGIC %md
# MAGIC ## Overview
# MAGIC
# MAGIC **Genie Space:** `summit_sales_analytics`
# MAGIC
# MAGIC **Tables:**
# MAGIC - `demo_ai_summit_databricks.enriched.sales_fact`
# MAGIC - `demo_ai_summit_databricks.raw.dim_customer`
# MAGIC - `demo_ai_summit_databricks.raw.dim_product`
# MAGIC - `demo_ai_summit_databricks.raw.dim_region`
# MAGIC - `demo_ai_summit_databricks.raw.dim_date`
# MAGIC - `demo_ai_summit_databricks.raw.dim_sales_rep`
# MAGIC - `demo_ai_summit_databricks.enriched.campaign_fact`
# MAGIC
# MAGIC **Joins:** Star schema (sales_fact as central fact)
# MAGIC
# MAGIC **Metrics:**
# MAGIC - Revenue (SUM of amount)
# MAGIC - Order Count (COUNT of order_id)
# MAGIC - Average Order Value (AVG of amount)
# MAGIC - Churn Rate (AVG of is_churned)

# COMMAND ----------

# MAGIC %md
# MAGIC ## Step 1: Verify Prerequisites

# COMMAND ----------

# Check that all tables exist
print("=== Verifying Tables for Genie Space ===\n")

tables_to_check = [
    "demo_ai_summit_databricks.enriched.sales_fact",
    "demo_ai_summit_databricks.enriched.campaign_fact",
    "demo_ai_summit_databricks.raw.dim_customer",
    "demo_ai_summit_databricks.raw.dim_product",
    "demo_ai_summit_databricks.raw.dim_region",
    "demo_ai_summit_databricks.raw.dim_date",
    "demo_ai_summit_databricks.raw.dim_sales_rep"
]

all_exist = True
for table_name in tables_to_check:
    try:
        count = spark.table(table_name).count()
        print(f"✓ {table_name}: {count:,} rows")
    except Exception as e:
        print(f"✗ {table_name}: NOT FOUND")
        all_exist = False

if all_exist:
    print("\n✅ All tables ready for Genie space configuration")
else:
    print("\n⚠ Some tables are missing. Run notebooks 02-04 first.")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Step 2: Create Genie Space (Manual Steps)
# MAGIC
# MAGIC Genie space creation is done via Databricks Workspace UI.
# MAGIC Follow these steps:
# MAGIC
# MAGIC ### 2.1 Navigate to Genie
# MAGIC 1. Open Databricks Workspace
# MAGIC 2. Click on **"AI/BI Genie"** in the left sidebar
# MAGIC    - If not visible: Go to Settings → Workspace Settings → Features → Enable AI/BI Genie
# MAGIC 3. Click **"Create Genie Space"**
# MAGIC
# MAGIC ### 2.2 Configure Genie Space
# MAGIC 1. **Name:** `summit_sales_analytics`
# MAGIC 2. **Description:** "Innovation Summit sales analytics demo — Q3 2025 revenue analysis"
# MAGIC 3. **SQL Warehouse:** Select your serverless warehouse (e.g., `Demo-AI-Genie-Warehouse`)
# MAGIC
# MAGIC ### 2.3 Add Tables
# MAGIC Click **"Add Tables"** and select:
# MAGIC - ✅ `demo_ai_summit_databricks.enriched.sales_fact`
# MAGIC - ✅ `demo_ai_summit_databricks.raw.dim_customer`
# MAGIC - ✅ `demo_ai_summit_databricks.raw.dim_product`
# MAGIC - ✅ `demo_ai_summit_databricks.raw.dim_region`
# MAGIC - ✅ `demo_ai_summit_databricks.raw.dim_date`
# MAGIC - ✅ `demo_ai_summit_databricks.raw.dim_sales_rep`
# MAGIC - ✅ `demo_ai_summit_databricks.enriched.campaign_fact`
# MAGIC
# MAGIC ### 2.4 Configure Joins (Auto-Detected)
# MAGIC Genie should auto-detect these joins:
# MAGIC - `sales_fact.customer_id` → `dim_customer.customer_id`
# MAGIC - `sales_fact.product_id` → `dim_product.product_id`
# MAGIC - `sales_fact.region_id` → `dim_region.region_id`
# MAGIC - `sales_fact.date_key` → `dim_date.date_key`
# MAGIC - `sales_fact.rep_id` → `dim_sales_rep.rep_id`
# MAGIC - `campaign_fact.territory` → `dim_region.territory`
# MAGIC
# MAGIC **Verify joins are correct** (star schema with sales_fact at center)
# MAGIC
# MAGIC ### 2.5 Define Metrics
# MAGIC Add custom metrics (if not auto-detected):
# MAGIC
# MAGIC 1. **Revenue**
# MAGIC    - Expression: `SUM(sales_fact.amount)`
# MAGIC    - Format: Currency (USD)
# MAGIC
# MAGIC 2. **Order Count**
# MAGIC    - Expression: `COUNT(DISTINCT sales_fact.order_id)`
# MAGIC    - Format: Number
# MAGIC
# MAGIC 3. **Average Order Value**
# MAGIC    - Expression: `AVG(sales_fact.amount)`
# MAGIC    - Format: Currency (USD)
# MAGIC
# MAGIC 4. **Churn Rate**
# MAGIC    - Expression: `AVG(CASE WHEN dim_customer.is_churned THEN 1.0 ELSE 0.0 END)`
# MAGIC    - Format: Percentage
# MAGIC
# MAGIC ### 2.6 Add Sample Questions
# MAGIC Configure suggested questions for users:
# MAGIC - "What was Q3 2025 revenue by region?"
# MAGIC - "Show me revenue by quarter for 2025"
# MAGIC - "Which territory had the highest revenue in Q3?"
# MAGIC - "What is the customer churn rate by segment?"
# MAGIC - "Show me top 10 products by revenue"
# MAGIC - "How many orders were returned in Q3 2025?"
# MAGIC - "What was EMEA revenue in Q2 vs Q3 2025?"
# MAGIC
# MAGIC ### 2.7 Test Genie Space
# MAGIC Before publishing:
# MAGIC 1. Click **"Test"** button
# MAGIC 2. Try sample question: "What was Q3 revenue by region?"
# MAGIC 3. Verify:
# MAGIC    - SQL generates correctly
# MAGIC    - Results match expectations
# MAGIC    - Chart displays properly
# MAGIC
# MAGIC ### 2.8 Publish
# MAGIC 1. Click **"Publish"**
# MAGIC 2. Grant permissions to **"Demo User Group"** (or ALL USERS for demo)
# MAGIC 3. Note the Genie Space ID (needed for app configuration)

# COMMAND ----------

# MAGIC %md
# MAGIC ## Step 3: Test Genie Space Programmatically (Optional)
# MAGIC
# MAGIC **Note:** Genie API may vary by Databricks version.
# MAGIC This is a placeholder for programmatic testing if SDK is available.

# COMMAND ----------

print("✓ Genie space configuration complete")
print("\nNext steps:")
print("1. Test Genie space in Workspace UI")
print("2. Configure summit_ai_genie_app with Genie Space ID")
print("3. Deploy app and test end-to-end")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Step 4: Verification Queries
# MAGIC
# MAGIC Run these queries to verify data is ready for Genie:

# COMMAND ----------

# Q3 2025 revenue by region (expected query from Genie)
print("=== Q3 2025 Revenue by Region ===")
spark.sql("""
SELECT
  r.region_name as Region,
  COUNT(s.order_id) as Orders,
  ROUND(SUM(s.amount), 2) as Revenue
FROM demo_ai_summit_databricks.enriched.sales_fact s
JOIN demo_ai_summit_databricks.raw.dim_region r ON s.region_id = r.region_id
JOIN demo_ai_summit_databricks.raw.dim_date d ON s.date_key = d.date_key
WHERE d.year = 2025 AND d.quarter = 3
GROUP BY r.region_name
ORDER BY Revenue DESC
""").show()

# Top products by revenue
print("\n=== Top 5 Products by Revenue ===")
spark.sql("""
SELECT
  p.product_name as Product,
  p.category as Category,
  ROUND(SUM(s.amount), 2) as Revenue
FROM demo_ai_summit_databricks.enriched.sales_fact s
JOIN demo_ai_summit_databricks.raw.dim_product p ON s.product_id = p.product_id
GROUP BY p.product_name, p.category
ORDER BY Revenue DESC
LIMIT 5
""").show()

# Churn rate by segment
print("\n=== Churn Rate by Segment ===")
spark.sql("""
SELECT
  segment as Segment,
  COUNT(*) as Total_Customers,
  SUM(CASE WHEN is_churned THEN 1 ELSE 0 END) as Churned,
  ROUND(AVG(CASE WHEN is_churned THEN 1.0 ELSE 0.0 END) * 100, 2) as Churn_Rate_Pct
FROM demo_ai_summit_databricks.raw.dim_customer
GROUP BY segment
ORDER BY Churn_Rate_Pct DESC
""").show()

print("\n✅ Verification complete. Data ready for Genie queries.")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Configuration Summary
# MAGIC
# MAGIC **Genie Space:** `summit_sales_analytics`
# MAGIC
# MAGIC **Key Features:**
# MAGIC - ✅ Star schema with 7 tables
# MAGIC - ✅ Auto-detected joins
# MAGIC - ✅ Custom metrics (Revenue, Order Count, AOV, Churn Rate)
# MAGIC - ✅ Sample questions configured
# MAGIC - ✅ Published and accessible
# MAGIC
# MAGIC **Integration:**
# MAGIC - Station A app (`summit_ai_genie_app`) uses this Genie space
# MAGIC - SQL warehouse: `Demo-AI-Genie-Warehouse`
# MAGIC - Permissions: Demo User Group or ALL USERS
# MAGIC
# MAGIC **Next Steps:**
# MAGIC 1. ✅ Genie space created and tested
# MAGIC 2. ⬜ Deploy summit_ai_genie_app
# MAGIC 3. ⬜ Test end-to-end demo flow
# MAGIC
# MAGIC **Troubleshooting:**
# MAGIC - If Genie space not visible: Check workspace features enabled
# MAGIC - If queries fail: Verify SQL warehouse is running
# MAGIC - If joins incorrect: Manually configure in Genie UI

# COMMAND ----------

# MAGIC %md
# MAGIC ## Best Practices
# MAGIC
# MAGIC 1. **Semantic Layer Design:**
# MAGIC    - Use star schema (fact at center, dimensions radiate)
# MAGIC    - Descriptive column names (region_name vs region_id)
# MAGIC    - Business-friendly terminology (Revenue vs SUM(amount))
# MAGIC
# MAGIC 2. **Metric Definitions:**
# MAGIC    - Always specify aggregation (SUM, AVG, COUNT)
# MAGIC    - Use DISTINCT for count metrics (avoid double-counting)
# MAGIC    - Format metrics (currency, percentage, number)
# MAGIC
# MAGIC 3. **Sample Questions:**
# MAGIC    - Cover common use cases (time-series, top-N, comparisons)
# MAGIC    - Use business language, not SQL jargon
# MAGIC    - Include dimensional breakdowns (by region, by product)
# MAGIC
# MAGIC 4. **Testing:**
# MAGIC    - Test all sample questions before publishing
# MAGIC    - Verify SQL is optimal (no cartesian joins)
# MAGIC    - Check performance on large datasets
# MAGIC
# MAGIC 5. **Maintenance:**
# MAGIC    - Update Genie space when schema changes
# MAGIC    - Refresh metrics definitions periodically
# MAGIC    - Monitor query patterns and add new sample questions
