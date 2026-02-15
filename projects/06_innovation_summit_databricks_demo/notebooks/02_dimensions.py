# Databricks notebook source
# MAGIC %md
# MAGIC # Innovation Summit AI Demo — Dimension Tables
# MAGIC
# MAGIC **Purpose:** Generate synthetic dimension data for the demo
# MAGIC
# MAGIC **Run:** Once (after 01_infrastructure.py)
# MAGIC
# MAGIC **Learning Objectives:**
# MAGIC 1. Create dimension tables using PySpark
# MAGIC 2. Generate synthetic data with realistic distributions
# MAGIC 3. Write Delta tables to Unity Catalog
# MAGIC 4. Add table comments and column descriptions
# MAGIC
# MAGIC **Tables Created:**
# MAGIC - `dim_customer` (12,000 rows) — Customer master with segments and churn status
# MAGIC - `dim_product` (500 rows) — Product catalog with categories
# MAGIC - `dim_region` (20 rows) — Geographic hierarchy
# MAGIC - `dim_date` (1,095 rows) — Date dimension for 3 years
# MAGIC - `dim_sales_rep` (150 rows) — Sales rep directory

# COMMAND ----------

# MAGIC %md
# MAGIC ## Setup

# COMMAND ----------

from pyspark.sql import functions as F
from pyspark.sql.types import *
from datetime import datetime, timedelta
import random

# Set catalog and schema
spark.sql("USE CATALOG demo_ai_summit_databricks")
spark.sql("USE SCHEMA raw")

print("✓ Using catalog: demo_ai_summit_databricks.raw")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Dimension: Customer (dim_customer)

# COMMAND ----------

# Generate 12,000 customers
num_customers = 12000

# Define segments
segments = ['Enterprise', 'Mid-Market', 'SMB']
segment_weights = [0.15, 0.35, 0.50]  # Enterprise 15%, Mid-Market 35%, SMB 50%

# Define regions
regions = ['North America', 'EMEA', 'APAC', 'LATAM']
region_weights = [0.40, 0.30, 0.20, 0.10]

# Customer data generation
customer_data = []
for i in range(1, num_customers + 1):
    segment = random.choices(segments, weights=segment_weights)[0]
    region = random.choices(regions, weights=region_weights)[0]

    # Planted anomaly: EMEA enterprise customers have higher churn in Q3
    if region == 'EMEA' and segment == 'Enterprise':
        churn_rate = 0.071  # 7.1% (high)
        is_churned = random.random() < churn_rate
    else:
        # Normal churn rates by segment
        churn_rates = {'Enterprise': 0.032, 'Mid-Market': 0.048, 'SMB': 0.065}
        is_churned = random.random() < churn_rates[segment]

    customer_data.append((
        i,  # customer_id
        f"Customer-{i:05d}",  # customer_name
        segment,
        region,
        is_churned,
        random.choice(['Active', 'Inactive']) if not is_churned else 'Churned',
        random.randint(1, 60)  # months_tenure
    ))

# Create DataFrame
df_customer = spark.createDataFrame(
    customer_data,
    ['customer_id', 'customer_name', 'segment', 'region', 'is_churned', 'status', 'months_tenure']
)

# Write to Delta table
df_customer.write.format("delta").mode("overwrite").saveAsTable("demo_ai_summit_databricks.raw.dim_customer")

# Add table comment
spark.sql("""
COMMENT ON TABLE demo_ai_summit_databricks.raw.dim_customer IS
'Customer master — segments, regions, churn status. PLANTED ANOMALY: EMEA Enterprise churn = 7.1% (vs 3.2% baseline)'
""")

print(f"✓ dim_customer created: {df_customer.count()} rows")
df_customer.show(5)

# COMMAND ----------

# MAGIC %md
# MAGIC ## Dimension: Product (dim_product)

# COMMAND ----------

# Product categories and subcategories
categories = {
    'Electronics': ['Premium', 'Standard', 'Budget'],
    'Apparel': ['Premium', 'Standard', 'Budget'],
    'Home & Kitchen': ['Premium', 'Standard', 'Budget'],
    'Sports': ['Professional', 'Standard'],
    'Office Supplies': ['Premium', 'Standard', 'Budget'],
    'Health & Beauty': ['Premium', 'Standard']
}

product_data = []
product_id = 1

for category, subcategories in categories.items():
    for subcategory in subcategories:
        # Generate 70-100 products per category-subcategory combo
        num_products = random.randint(70, 100)
        for _ in range(num_products):
            # Unit cost varies by subcategory
            if subcategory == 'Premium' or subcategory == 'Professional':
                unit_cost = round(random.uniform(50, 300), 2)
            elif subcategory == 'Standard':
                unit_cost = round(random.uniform(15, 60), 2)
            else:  # Budget
                unit_cost = round(random.uniform(5, 20), 2)

            product_data.append((
                product_id,
                f"{category[:3].upper()}-{subcategory[:3].upper()}-{product_id:04d}",  # product_name
                category,
                subcategory,
                unit_cost
            ))
            product_id += 1

# Create DataFrame
df_product = spark.createDataFrame(
    product_data,
    ['product_id', 'product_name', 'category', 'subcategory', 'unit_cost']
)

# Write to Delta table
df_product.write.format("delta").mode("overwrite").saveAsTable("demo_ai_summit_databricks.raw.dim_product")

spark.sql("""
COMMENT ON TABLE demo_ai_summit_databricks.raw.dim_product IS
'Product catalog — categories (Electronics, Apparel, etc.), subcategories (Premium, Standard, Budget), unit costs'
""")

print(f"✓ dim_product created: {df_product.count()} rows")
df_product.groupBy('category', 'subcategory').count().show()

# COMMAND ----------

# MAGIC %md
# MAGIC ## Dimension: Region (dim_region)

# COMMAND ----------

# Geographic hierarchy
region_data = [
    (1, 'North America', 'USA', 'NA'),
    (2, 'North America', 'Canada', 'NA'),
    (3, 'North America', 'Mexico', 'NA'),
    (4, 'EMEA', 'United Kingdom', 'EMEA'),
    (5, 'EMEA', 'Germany', 'EMEA'),
    (6, 'EMEA', 'France', 'EMEA'),
    (7, 'EMEA', 'Spain', 'EMEA'),
    (8, 'EMEA', 'Italy', 'EMEA'),
    (9, 'EMEA', 'Netherlands', 'EMEA'),
    (10, 'APAC', 'Japan', 'APAC'),
    (11, 'APAC', 'Australia', 'APAC'),
    (12, 'APAC', 'Singapore', 'APAC'),
    (13, 'APAC', 'India', 'APAC'),
    (14, 'APAC', 'South Korea', 'APAC'),
    (15, 'LATAM', 'Brazil', 'LATAM'),
    (16, 'LATAM', 'Argentina', 'LATAM'),
    (17, 'LATAM', 'Chile', 'LATAM'),
    (18, 'LATAM', 'Colombia', 'LATAM'),
    (19, 'LATAM', 'Peru', 'LATAM'),
    (20, 'LATAM', 'Costa Rica', 'LATAM')
]

df_region = spark.createDataFrame(
    region_data,
    ['region_id', 'region_name', 'country', 'territory']
)

df_region.write.format("delta").mode("overwrite").saveAsTable("demo_ai_summit_databricks.raw.dim_region")

spark.sql("""
COMMENT ON TABLE demo_ai_summit_databricks.raw.dim_region IS
'Geographic hierarchy — territory (NA, EMEA, APAC, LATAM), region, country'
""")

print(f"✓ dim_region created: {df_region.count()} rows")
df_region.show()

# COMMAND ----------

# MAGIC %md
# MAGIC ## Dimension: Date (dim_date)

# COMMAND ----------

# Generate date dimension for 3 years (2023-2025)
start_date = datetime(2023, 1, 1)
end_date = datetime(2025, 12, 31)
date_range = (end_date - start_date).days + 1

date_data = []
for i in range(date_range):
    current_date = start_date + timedelta(days=i)

    date_data.append((
        current_date,  # date_key
        current_date.year,  # year
        (current_date.month - 1) // 3 + 1,  # quarter
        current_date.month,  # month
        current_date.strftime('%b'),  # month_name
        f"FY{current_date.year}",  # fiscal_year
        current_date.strftime('%A'),  # day_name
        current_date.isocalendar()[1],  # week_number
        1 if current_date.weekday() < 5 else 0  # is_weekday
    ))

df_date = spark.createDataFrame(
    date_data,
    ['date_key', 'year', 'quarter', 'month', 'month_name', 'fiscal_year', 'day_name', 'week_number', 'is_weekday']
)

df_date.write.format("delta").mode("overwrite").saveAsTable("demo_ai_summit_databricks.raw.dim_date")

spark.sql("""
COMMENT ON TABLE demo_ai_summit_databricks.raw.dim_date IS
'Date dimension — calendar and fiscal periods (2023-2025), week/quarter/year rollups'
""")

print(f"✓ dim_date created: {df_date.count()} rows")
df_date.filter(F.col('year') == 2025).show(10)

# COMMAND ----------

# MAGIC %md
# MAGIC ## Dimension: Sales Rep (dim_sales_rep)

# COMMAND ----------

# Sales teams
teams = ['Enterprise', 'Mid-Market', 'SMB', 'Strategic', 'Inside Sales']
team_sizes = [20, 35, 40, 15, 40]  # Number of reps per team

sales_rep_data = []
rep_id = 1

first_names = ['Alex', 'Jordan', 'Taylor', 'Morgan', 'Casey', 'Riley', 'Avery', 'Quinn', 'Skyler', 'Peyton',
               'Jamie', 'Drew', 'Cameron', 'Parker', 'Sage', 'Dakota', 'Rowan', 'River', 'Phoenix', 'Kai']
last_names = ['Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Garcia', 'Miller', 'Davis', 'Rodriguez', 'Martinez',
              'Hernandez', 'Lopez', 'Gonzalez', 'Wilson', 'Anderson', 'Thomas', 'Taylor', 'Moore', 'Jackson', 'Lee']

for team, size in zip(teams, team_sizes):
    for _ in range(size):
        first_name = random.choice(first_names)
        last_name = random.choice(last_names)

        sales_rep_data.append((
            rep_id,
            f"{first_name} {last_name}",
            team,
            random.randint(1, 120)  # months_with_company
        ))
        rep_id += 1

df_sales_rep = spark.createDataFrame(
    sales_rep_data,
    ['rep_id', 'rep_name', 'team', 'months_with_company']
)

df_sales_rep.write.format("delta").mode("overwrite").saveAsTable("demo_ai_summit_databricks.raw.dim_sales_rep")

spark.sql("""
COMMENT ON TABLE demo_ai_summit_databricks.raw.dim_sales_rep IS
'Sales rep directory — teams (Enterprise, Mid-Market, SMB, Strategic, Inside Sales), tenure'
""")

print(f"✓ dim_sales_rep created: {df_sales_rep.count()} rows")
df_sales_rep.groupBy('team').count().show()

# COMMAND ----------

# MAGIC %md
# MAGIC ## Verification

# COMMAND ----------

# Display all dimension tables
print("=== Dimension Tables Summary ===")
tables = spark.sql("SHOW TABLES IN demo_ai_summit_databricks.raw").collect()
for table in tables:
    table_name = table['tableName']
    if table_name.startswith('dim_'):
        row_count = spark.table(f"demo_ai_summit_databricks.raw.{table_name}").count()
        print(f"✓ {table_name}: {row_count:,} rows")

print("\n✅ All dimension tables created successfully!")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Best Practices
# MAGIC
# MAGIC 1. **Synthetic Data Generation:**
# MAGIC    - Use realistic distributions (not uniform)
# MAGIC    - Plant anomalies intentionally (EMEA churn spike)
# MAGIC    - Document anomalies in table comments
# MAGIC
# MAGIC 2. **Delta Tables:**
# MAGIC    - Always use `.saveAsTable()` for Unity Catalog
# MAGIC    - Add table and column comments for documentation
# MAGIC    - Use `mode("overwrite")` for idempotent scripts
# MAGIC
# MAGIC 3. **Naming Conventions:**
# MAGIC    - Prefix dimensions with `dim_`
# MAGIC    - Use lowercase with underscores
# MAGIC    - Keep names concise but descriptive
# MAGIC
# MAGIC 4. **Performance:**
# MAGIC    - For large dimension tables (>1M rows), consider partitioning
# MAGIC    - Use `.repartition()` before write for balanced files
# MAGIC    - Enable Delta optimization with `OPTIMIZE` command
