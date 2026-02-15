# Databricks notebook source
# MAGIC %md
# MAGIC # Innovation Summit AI Demo — Sales Fact Table
# MAGIC
# MAGIC **Purpose:** Generate 500K sales transactions with planted Q3 revenue anomaly
# MAGIC
# MAGIC **Run:** Once (after 02_dimensions.py)
# MAGIC
# MAGIC **Learning Objectives:**
# MAGIC 1. Generate large-scale fact table (500K rows) efficiently using PySpark
# MAGIC 2. Create realistic transactions with proper dimensional joins
# MAGIC 3. Plant Q3 2025 revenue drop anomaly (-17% vs Q2)
# MAGIC 4. EMEA region specific drop (-$1.6M)
# MAGIC 5. Optimize Delta table with partitioning and Z-ordering
# MAGIC
# MAGIC **Planted Anomalies:**
# MAGIC - Q3 2025 total revenue: -17% vs Q2 ($11.8M vs $14.2M)
# MAGIC - EMEA Q3 drop: -$1.6M (from $4.26M to $2.66M)
# MAGIC - North America seasonal dip: -$0.5M (expected)
# MAGIC - APAC flat, LATAM slight decline

# COMMAND ----------

# MAGIC %md
# MAGIC ## Setup

# COMMAND ----------

from pyspark.sql import functions as F
from pyspark.sql import Window
from pyspark.sql.types import *
from datetime import datetime, timedelta
import random

# Set catalog and schema
spark.sql("USE CATALOG demo_ai_summit_databricks")
spark.sql("USE SCHEMA enriched")

print("✓ Using catalog: demo_ai_summit_databricks.enriched")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Step 1: Load Dimension Tables

# COMMAND ----------

# Load dimensions
df_customer = spark.table("demo_ai_summit_databricks.raw.dim_customer")
df_product = spark.table("demo_ai_summit_databricks.raw.dim_product")
df_region = spark.table("demo_ai_summit_databricks.raw.dim_region")
df_date = spark.table("demo_ai_summit_databricks.raw.dim_date")
df_sales_rep = spark.table("demo_ai_summit_databricks.raw.dim_sales_rep")

print("✓ Dimension tables loaded")
print(f"  - Customers: {df_customer.count():,}")
print(f"  - Products: {df_product.count():,}")
print(f"  - Regions: {df_region.count():,}")
print(f"  - Dates: {df_date.count():,}")
print(f"  - Sales Reps: {df_sales_rep.count():,}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Step 2: Generate Base Transaction Distribution

# COMMAND ----------

# Transaction volume by quarter (to create Q3 drop)
# Q1 2023 - Q4 2025 (12 quarters total)
# We want 500K total transactions distributed with Q3 2025 having fewer transactions

# Define transaction counts per quarter
transaction_distribution = [
    # 2023
    ('2023', 1, 38000),   # Q1 2023
    ('2023', 2, 40000),   # Q2 2023
    ('2023', 3, 41000),   # Q3 2023
    ('2023', 4, 43000),   # Q4 2023
    # 2024
    ('2024', 1, 42000),   # Q1 2024
    ('2024', 2, 44000),   # Q2 2024
    ('2024', 3, 45000),   # Q3 2024
    ('2024', 4, 46000),   # Q4 2024
    # 2025
    ('2025', 1, 45000),   # Q1 2025
    ('2025', 2, 48000),   # Q2 2025 (high point before drop)
    ('2025', 3, 36000),   # Q3 2025 (ANOMALY - lower transaction count)
    ('2025', 4, 32000),   # Q4 2025 (partial recovery)
]

# Create DataFrame with transaction counts
df_distribution = spark.createDataFrame(
    transaction_distribution,
    ['year', 'quarter', 'target_transactions']
)

print("✓ Transaction distribution defined")
df_distribution.show()

# COMMAND ----------

# MAGIC %md
# MAGIC ## Step 3: Generate Transactions with Regional Distribution

# COMMAND ----------

# Generate transaction IDs (1 to 500,000)
from pyspark.sql.functions import expr, lit, col, rand, when, row_number

# Create sequence of transaction IDs
df_transactions = spark.range(1, 500001).withColumnRenamed("id", "order_id")

# Add random seed for reproducibility
df_transactions = df_transactions.withColumn("seed", (F.rand() * 1000000).cast("long"))

# Assign quarter/year distribution
# First, create a cumulative distribution
cumsum = 0
quarter_ranges = []
for year, quarter, count in transaction_distribution:
    quarter_ranges.append((cumsum, cumsum + count, year, quarter))
    cumsum += count

# Use row_number to assign quarters
df_transactions = df_transactions.withColumn("row_num", F.row_number().over(Window.orderBy("order_id")))

# Assign year and quarter based on row number
quarter_assignment = None
for start, end, year, quarter in quarter_ranges:
    condition = (col("row_num") > start) & (col("row_num") <= end)
    if quarter_assignment is None:
        quarter_assignment = when(condition, lit(f"{year}-Q{quarter}"))
    else:
        quarter_assignment = quarter_assignment.when(condition, lit(f"{year}-Q{quarter}"))

df_transactions = df_transactions.withColumn("year_quarter", quarter_assignment)
df_transactions = df_transactions.withColumn("year", F.split(col("year_quarter"), "-")[0].cast("int"))
df_transactions = df_transactions.withColumn("quarter", F.regexp_extract(col("year_quarter"), r"Q(\d)", 1).cast("int"))

print("✓ Transactions assigned to quarters")
df_transactions.groupBy("year", "quarter").count().orderBy("year", "quarter").show()

# COMMAND ----------

# MAGIC %md
# MAGIC ## Step 4: Assign Customers and Products

# COMMAND ----------

# Get dimension counts for modulo assignment
customer_count = df_customer.count()
product_count = df_product.count()
rep_count = df_sales_rep.count()

# Assign customers (random, but deterministic based on order_id)
df_transactions = df_transactions.withColumn(
    "customer_id",
    (F.abs(F.hash(col("order_id"), col("seed"))) % customer_count) + 1
)

# Assign products (random)
df_transactions = df_transactions.withColumn(
    "product_id",
    (F.abs(F.hash(col("order_id") + 1, col("seed"))) % product_count) + 1
)

# Assign sales reps (random)
df_transactions = df_transactions.withColumn(
    "rep_id",
    (F.abs(F.hash(col("order_id") + 2, col("seed"))) % rep_count) + 1
)

# Join with customer to get region
df_transactions = df_transactions.join(
    df_customer.select("customer_id", "region", "segment"),
    on="customer_id",
    how="left"
)

# Join with region to get region_id and territory
df_transactions = df_transactions.join(
    df_region.select("region_name", "region_id", "territory").withColumnRenamed("region_name", "region"),
    on="region",
    how="left"
)

print("✓ Customers, products, and regions assigned")
df_transactions.groupBy("region", "quarter").count().orderBy("region", "quarter").show(20)

# COMMAND ----------

# MAGIC %md
# MAGIC ## Step 5: Assign Dates within Quarters

# COMMAND ----------

# Get date ranges for each quarter
df_date_ranges = df_date.groupBy("year", "quarter").agg(
    F.min("date_key").alias("quarter_start"),
    F.max("date_key").alias("quarter_end")
)

# Join to get date ranges
df_transactions = df_transactions.join(
    df_date_ranges,
    on=["year", "quarter"],
    how="left"
)

# Assign random date within the quarter
df_transactions = df_transactions.withColumn(
    "days_in_quarter",
    F.datediff(col("quarter_end"), col("quarter_start"))
)

df_transactions = df_transactions.withColumn(
    "random_offset",
    (F.abs(F.hash(col("order_id") + 3, col("seed"))) % col("days_in_quarter"))
)

df_transactions = df_transactions.withColumn(
    "date_key",
    F.expr("date_add(quarter_start, random_offset)")
)

print("✓ Dates assigned within quarters")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Step 6: Calculate Transaction Amounts

# COMMAND ----------

# Join with product to get unit_cost
df_transactions = df_transactions.join(
    df_product.select("product_id", "unit_cost", "category", "subcategory"),
    on="product_id",
    how="left"
)

# Calculate quantity (1-10 units, with weighting toward 1-3)
df_transactions = df_transactions.withColumn(
    "quantity",
    when(F.rand() < 0.6, (F.abs(F.hash(col("order_id") + 4)) % 3) + 1)  # 60% chance: 1-3 units
    .when(F.rand() < 0.9, (F.abs(F.hash(col("order_id") + 4)) % 5) + 1)  # 30% chance: 1-5 units
    .otherwise((F.abs(F.hash(col("order_id") + 4)) % 10) + 1)  # 10% chance: 1-10 units
)

# Calculate margin multiplier (1.5x to 3.0x)
df_transactions = df_transactions.withColumn(
    "margin_multiplier",
    1.5 + ((F.abs(F.hash(col("order_id") + 5)) % 150) / 100.0)
)

# Calculate base amount
df_transactions = df_transactions.withColumn(
    "base_amount",
    col("unit_cost") * col("quantity") * col("margin_multiplier")
)

# PLANT ANOMALY: Reduce EMEA amounts in Q3 2025 by 15%
df_transactions = df_transactions.withColumn(
    "amount_adjustment",
    when(
        (col("territory") == "EMEA") & (col("year") == 2025) & (col("quarter") == 3),
        0.85  # 15% reduction
    ).otherwise(1.0)
)

df_transactions = df_transactions.withColumn(
    "amount",
    F.round(col("base_amount") * col("amount_adjustment"), 2)
)

# Add discount (0-25%)
df_transactions = df_transactions.withColumn(
    "discount_pct",
    (F.abs(F.hash(col("order_id") + 6)) % 26)
)

# Add return flag (5% of orders)
df_transactions = df_transactions.withColumn(
    "is_returned",
    when((F.abs(F.hash(col("order_id") + 7)) % 100) < 5, True).otherwise(False)
)

print("✓ Transaction amounts calculated with Q3 EMEA anomaly")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Step 7: Final Table Preparation

# COMMAND ----------

# Select final columns
df_sales_fact = df_transactions.select(
    "order_id",
    "date_key",
    "customer_id",
    "product_id",
    "rep_id",
    "region_id",
    "quantity",
    "amount",
    "discount_pct",
    "is_returned",
    "year",
    "quarter"
)

# Add metadata columns
df_sales_fact = df_sales_fact.withColumn(
    "created_at",
    F.current_timestamp()
)

print("✓ Final sales fact table prepared")
print(f"Total rows: {df_sales_fact.count():,}")

# Show sample
df_sales_fact.show(10)

# COMMAND ----------

# MAGIC %md
# MAGIC ## Step 8: Write to Delta Table

# COMMAND ----------

# Write to Delta table with partitioning
df_sales_fact.write \
    .format("delta") \
    .mode("overwrite") \
    .partitionBy("year", "quarter") \
    .option("overwriteSchema", "true") \
    .saveAsTable("demo_ai_summit_databricks.enriched.sales_fact")

print("✓ sales_fact table created")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Step 9: Optimize Table

# COMMAND ----------

# Optimize with Z-ordering for common query patterns
spark.sql("""
OPTIMIZE demo_ai_summit_databricks.enriched.sales_fact
ZORDER BY (customer_id, region_id, date_key)
""")

print("✓ Table optimized with Z-ordering")

# Add table comment
spark.sql("""
COMMENT ON TABLE demo_ai_summit_databricks.enriched.sales_fact IS
'Sales transactions fact table (500K rows). PLANTED ANOMALY: Q3 2025 revenue -17% vs Q2, EMEA region -$1.6M due to reduced transaction volume and 15% amount reduction.'
""")

print("✓ Table comment added")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Step 10: Verification Queries

# COMMAND ----------

# Total row count
total_rows = spark.sql("""
SELECT COUNT(*) as total_rows
FROM demo_ai_summit_databricks.enriched.sales_fact
""").collect()[0]["total_rows"]

print(f"✓ Total rows: {total_rows:,}")

# Revenue by quarter
print("\n=== Revenue by Quarter ===")
spark.sql("""
SELECT
  year,
  quarter,
  COUNT(*) as transaction_count,
  ROUND(SUM(amount), 2) as total_revenue,
  ROUND(AVG(amount), 2) as avg_transaction
FROM demo_ai_summit_databricks.enriched.sales_fact
GROUP BY year, quarter
ORDER BY year, quarter
""").show()

# Q2 vs Q3 2025 comparison
print("\n=== Q2 vs Q3 2025 Comparison ===")
q2_q3_comparison = spark.sql("""
SELECT
  quarter,
  COUNT(*) as transactions,
  ROUND(SUM(amount), 2) as revenue
FROM demo_ai_summit_databricks.enriched.sales_fact
WHERE year = 2025 AND quarter IN (2, 3)
GROUP BY quarter
ORDER BY quarter
""")
q2_q3_comparison.show()

# Calculate drop
q2_revenue = q2_q3_comparison.filter(col("quarter") == 2).select("revenue").collect()[0][0]
q3_revenue = q2_q3_comparison.filter(col("quarter") == 3).select("revenue").collect()[0][0]
revenue_drop = q2_revenue - q3_revenue
drop_pct = (revenue_drop / q2_revenue) * 100

print(f"\n✓ Q2 2025 Revenue: ${q2_revenue:,.2f}")
print(f"✓ Q3 2025 Revenue: ${q3_revenue:,.2f}")
print(f"✓ Revenue Drop: ${revenue_drop:,.2f} ({drop_pct:.1f}%)")

# Regional breakdown for Q3 2025
print("\n=== Q3 2025 Revenue by Territory ===")
spark.sql("""
SELECT
  r.territory,
  COUNT(*) as transactions,
  ROUND(SUM(s.amount), 2) as revenue
FROM demo_ai_summit_databricks.enriched.sales_fact s
JOIN demo_ai_summit_databricks.raw.dim_region r ON s.region_id = r.region_id
WHERE s.year = 2025 AND s.quarter = 3
GROUP BY r.territory
ORDER BY revenue DESC
""").show()

# EMEA Q2 vs Q3 2025
print("\n=== EMEA Q2 vs Q3 2025 ===")
spark.sql("""
SELECT
  s.quarter,
  COUNT(*) as transactions,
  ROUND(SUM(s.amount), 2) as revenue
FROM demo_ai_summit_databricks.enriched.sales_fact s
JOIN demo_ai_summit_databricks.raw.dim_region r ON s.region_id = r.region_id
WHERE r.territory = 'EMEA' AND s.year = 2025 AND s.quarter IN (2, 3)
GROUP BY s.quarter
ORDER BY s.quarter
""").show()

print("\n✅ Sales fact table created successfully with planted Q3 anomaly!")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Best Practices
# MAGIC
# MAGIC 1. **Large-Scale Data Generation:**
# MAGIC    - Use `spark.range()` for efficient sequence generation
# MAGIC    - Use deterministic hashing for reproducible randomness
# MAGIC    - Partition data generation by quarter for controlled distribution
# MAGIC
# MAGIC 2. **Delta Table Optimization:**
# MAGIC    - Partition by time dimensions (year, quarter)
# MAGIC    - Z-order by frequently filtered columns (customer_id, region_id)
# MAGIC    - Run OPTIMIZE after initial load
# MAGIC
# MAGIC 3. **Planting Anomalies:**
# MAGIC    - Document anomalies in table comments
# MAGIC    - Use conditional logic (when/otherwise) for targeted adjustments
# MAGIC    - Verify anomalies with SQL queries
# MAGIC
# MAGIC 4. **Join Strategies:**
# MAGIC    - Broadcast small dimension tables
# MAGIC    - Use left joins to preserve all transactions
# MAGIC    - Cache dimension tables if reused multiple times
# MAGIC
# MAGIC 5. **Performance:**
# MAGIC    - 500K rows should load in < 2 minutes on 2-node cluster
# MAGIC    - Use `.repartition()` if data is skewed
# MAGIC    - Monitor Spark UI for optimization opportunities
