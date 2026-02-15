# Databricks notebook source
# MAGIC %md
# MAGIC # Innovation Summit AI Demo — Campaign Fact Table
# MAGIC
# MAGIC **Purpose:** Generate 2.4K marketing campaigns with EMEA pause anomaly
# MAGIC
# MAGIC **Run:** Once (after 03_sales_fact.py)
# MAGIC
# MAGIC **Learning Objectives:**
# MAGIC 1. Generate marketing campaign data with realistic distributions
# MAGIC 2. Create campaigns across multiple channels and regions
# MAGIC 3. Plant EMEA campaign pause anomaly (Jul-Aug 2025)
# MAGIC 4. Link campaigns to sales performance patterns
# MAGIC
# MAGIC **Planted Anomalies:**
# MAGIC - 2 EMEA campaigns paused in Jul-Aug 2025 (status: "Paused — Budget Freeze")
# MAGIC - These campaigns correlate with EMEA Q3 revenue drop

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
spark.sql("USE SCHEMA enriched")

print("✓ Using catalog: demo_ai_summit_databricks.enriched")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Step 1: Define Campaign Parameters

# COMMAND ----------

# Campaign channels
channels = ['Digital Ads', 'Email', 'Events', 'Content Marketing', 'Partner Co-Marketing']

# Campaign statuses
statuses = ['Active', 'Completed', 'Scheduled']

# Territories
territories = ['NA', 'EMEA', 'APAC', 'LATAM']

# Date range: Jan 2023 - Dec 2025 (3 years)
start_date = datetime(2023, 1, 1)
end_date = datetime(2025, 12, 31)
total_days = (end_date - start_date).days

print("✓ Campaign parameters defined")
print(f"  Channels: {len(channels)}")
print(f"  Territories: {len(territories)}")
print(f"  Date range: {start_date.date()} to {end_date.date()}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Step 2: Generate Base Campaign Data

# COMMAND ----------

# Generate 2,400 campaigns
# Distribution: ~200 campaigns per month (~67 per region per month)
num_campaigns = 2400

# Create campaign IDs
campaign_data = []

for i in range(1, num_campaigns + 1):
    campaign_id = f"CMP-{i:05d}"

    # Random channel
    channel = random.choice(channels)

    # Random territory
    territory = random.choice(territories)

    # Random start date
    random_day = random.randint(0, total_days - 90)  # Leave 90 days for campaign duration
    campaign_start = start_date + timedelta(days=random_day)

    # Campaign duration: 30-90 days
    duration_days = random.randint(30, 90)
    campaign_end = campaign_start + timedelta(days=duration_days)

    # Determine status
    today = datetime(2025, 12, 31)  # As of end of 2025
    if campaign_end < today:
        status = 'Completed'
    elif campaign_start > today:
        status = 'Scheduled'
    else:
        status = 'Active'

    # Budget: varies by channel
    if channel == 'Events':
        budget = random.randint(50000, 200000)
    elif channel == 'Digital Ads':
        budget = random.randint(20000, 80000)
    elif channel == 'Partner Co-Marketing':
        budget = random.randint(15000, 60000)
    elif channel == 'Content Marketing':
        budget = random.randint(10000, 40000)
    else:  # Email
        budget = random.randint(5000, 25000)

    # Impressions (higher for digital)
    if channel == 'Digital Ads':
        impressions = random.randint(100000, 1000000)
    elif channel == 'Email':
        impressions = random.randint(50000, 300000)
    else:
        impressions = random.randint(10000, 100000)

    # Conversions (0.5% to 5% conversion rate)
    conversion_rate = random.uniform(0.005, 0.05)
    conversions = int(impressions * conversion_rate)

    # Cost per conversion
    cpc = round(budget / conversions if conversions > 0 else 0, 2)

    campaign_data.append((
        campaign_id,
        f"Campaign {i}",
        channel,
        territory,
        status,
        campaign_start.date(),
        campaign_end.date(),
        budget,
        impressions,
        conversions,
        cpc
    ))

# Create DataFrame
df_campaigns = spark.createDataFrame(
    campaign_data,
    ['campaign_id', 'campaign_name', 'channel', 'territory', 'campaign_status',
     'start_date', 'end_date', 'budget', 'impressions', 'conversions', 'cost_per_conversion']
)

print(f"✓ Generated {df_campaigns.count()} campaigns")
df_campaigns.show(10)

# COMMAND ----------

# MAGIC %md
# MAGIC ## Step 3: Plant EMEA Campaign Pause Anomaly

# COMMAND ----------

# Find 2 EMEA campaigns that run during Jul-Aug 2025
# These will be marked as "Paused — Budget Freeze"

# Filter for EMEA campaigns that overlap with Jul-Aug 2025
emea_q3_campaigns = df_campaigns.filter(
    (F.col("territory") == "EMEA") &
    (F.col("start_date") <= "2025-08-31") &
    (F.col("end_date") >= "2025-07-01")
).limit(2)

# Get their campaign IDs
paused_campaign_ids = [row['campaign_id'] for row in emea_q3_campaigns.collect()]

print(f"✓ Identified {len(paused_campaign_ids)} EMEA campaigns to pause:")
for cid in paused_campaign_ids:
    print(f"  - {cid}")

# Update status for these campaigns
df_campaigns = df_campaigns.withColumn(
    "campaign_status",
    F.when(F.col("campaign_id").isin(paused_campaign_ids), "Paused — Budget Freeze")
    .otherwise(F.col("campaign_status"))
)

# Verify
print("\n=== Paused Campaigns ===")
df_campaigns.filter(F.col("campaign_status").contains("Paused")).show(truncate=False)

# COMMAND ----------

# MAGIC %md
# MAGIC ## Step 4: Add Derived Metrics

# COMMAND ----------

# Add ROI calculation
df_campaigns = df_campaigns.withColumn(
    "roi",
    F.when(F.col("budget") > 0,
           F.round((F.col("conversions") * 100.0) / F.col("budget"), 2))
    .otherwise(0.0)
)

# Add quarter and year for analysis
df_campaigns = df_campaigns.withColumn(
    "start_year", F.year(F.col("start_date"))
)
df_campaigns = df_campaigns.withColumn(
    "start_quarter", F.quarter(F.col("start_date"))
)

# Add campaign duration in days
df_campaigns = df_campaigns.withColumn(
    "duration_days",
    F.datediff(F.col("end_date"), F.col("start_date"))
)

print("✓ Derived metrics added")
df_campaigns.select("campaign_id", "roi", "start_year", "start_quarter", "duration_days").show(10)

# COMMAND ----------

# MAGIC %md
# MAGIC ## Step 5: Write to Delta Table

# COMMAND ----------

# Write to Delta table
df_campaigns.write \
    .format("delta") \
    .mode("overwrite") \
    .option("overwriteSchema", "true") \
    .saveAsTable("demo_ai_summit_databricks.enriched.campaign_fact")

print("✓ campaign_fact table created")

# Add table comment
spark.sql("""
COMMENT ON TABLE demo_ai_summit_databricks.enriched.campaign_fact IS
'Marketing campaigns fact table (2.4K campaigns). PLANTED ANOMALY: 2 EMEA campaigns paused during Jul-Aug 2025 due to budget freeze, correlating with Q3 revenue drop.'
""")

print("✓ Table comment added")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Step 6: Verification Queries

# COMMAND ----------

# Total campaigns
total_campaigns = spark.sql("""
SELECT COUNT(*) as total
FROM demo_ai_summit_databricks.enriched.campaign_fact
""").collect()[0]["total"]

print(f"✓ Total campaigns: {total_campaigns:,}")

# Campaigns by channel
print("\n=== Campaigns by Channel ===")
spark.sql("""
SELECT
  channel,
  COUNT(*) as campaign_count,
  ROUND(SUM(budget), 2) as total_budget,
  SUM(conversions) as total_conversions
FROM demo_ai_summit_databricks.enriched.campaign_fact
GROUP BY channel
ORDER BY total_budget DESC
""").show()

# Campaigns by territory
print("\n=== Campaigns by Territory ===")
spark.sql("""
SELECT
  territory,
  COUNT(*) as campaign_count,
  ROUND(SUM(budget), 2) as total_budget
FROM demo_ai_summit_databricks.enriched.campaign_fact
GROUP BY territory
ORDER BY total_budget DESC
""").show()

# Campaign status distribution
print("\n=== Campaign Status Distribution ===")
spark.sql("""
SELECT
  campaign_status,
  COUNT(*) as count
FROM demo_ai_summit_databricks.enriched.campaign_fact
GROUP BY campaign_status
ORDER BY count DESC
""").show()

# Paused campaigns detail
print("\n=== Paused Campaigns (ANOMALY) ===")
spark.sql("""
SELECT
  campaign_id,
  campaign_name,
  channel,
  territory,
  campaign_status,
  start_date,
  end_date,
  budget,
  impressions,
  conversions
FROM demo_ai_summit_databricks.enriched.campaign_fact
WHERE campaign_status LIKE '%Paused%'
""").show(truncate=False)

# Q3 2025 EMEA campaigns
print("\n=== Q3 2025 EMEA Campaigns ===")
spark.sql("""
SELECT
  campaign_status,
  COUNT(*) as count,
  ROUND(SUM(budget), 2) as total_budget
FROM demo_ai_summit_databricks.enriched.campaign_fact
WHERE territory = 'EMEA'
  AND start_year = 2025
  AND start_quarter = 3
GROUP BY campaign_status
""").show()

print("\n✅ Campaign fact table created successfully with EMEA pause anomaly!")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Best Practices
# MAGIC
# MAGIC 1. **Realistic Campaign Data:**
# MAGIC    - Budget varies by channel type
# MAGIC    - Impressions correlate with channel (digital > email > events)
# MAGIC    - Conversion rates: 0.5% to 5% (industry standard)
# MAGIC
# MAGIC 2. **Date Handling:**
# MAGIC    - Campaign duration: 30-90 days (realistic range)
# MAGIC    - Status determined by current date vs start/end dates
# MAGIC    - Quarter/year extracted for time-series analysis
# MAGIC
# MAGIC 3. **Anomaly Design:**
# MAGIC    - Status change ("Paused — Budget Freeze") is easily queryable
# MAGIC    - Dates align with Q3 2025 (Jul-Aug)
# MAGIC    - Territory-specific (EMEA only)
# MAGIC    - Verifiable through SQL queries
# MAGIC
# MAGIC 4. **Metrics:**
# MAGIC    - ROI = (conversions / budget) * 100
# MAGIC    - Cost per conversion = budget / conversions
# MAGIC    - Duration in days for campaign length analysis
# MAGIC
# MAGIC 5. **Agent Discovery Path:**
# MAGIC    - Agent queries sales_fact → finds Q3 drop
# MAGIC    - Agent queries campaign_fact → finds paused campaigns
# MAGIC    - Agent correlates: EMEA drop + paused campaigns = root cause
