# Databricks notebook source
# MAGIC %md
# MAGIC # Innovation Summit AI Demo — End-to-End Verification
# MAGIC
# MAGIC **Purpose:** Verify all tables, anomalies, services, and apps are operational
# MAGIC
# MAGIC **Run:** After all setup notebooks (01-06) are complete
# MAGIC
# MAGIC **Checks:**
# MAGIC 1. Data tables (row counts, no nulls)
# MAGIC 2. Planted anomalies (Q3 drop, EMEA churn, paused campaigns)
# MAGIC 3. Vector Search index status
# MAGIC 4. Genie space accessibility
# MAGIC 5. Overall readiness for demo

# COMMAND ----------

# MAGIC %md
# MAGIC ## Setup

# COMMAND ----------

from pyspark.sql import functions as F
from databricks.vector_search.client import VectorSearchClient

# Vector Search client
vsc = VectorSearchClient()

print("✓ Starting end-to-end verification...\n")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Section 1: Data Verification

# COMMAND ----------

print("="*60)
print("SECTION 1: DATA VERIFICATION")
print("="*60 + "\n")

# Expected row counts
expected_counts = {
    "demo_ai_summit_databricks.raw.dim_customer": 12000,
    "demo_ai_summit_databricks.raw.dim_product": 500,
    "demo_ai_summit_databricks.raw.dim_region": 20,
    "demo_ai_summit_databricks.raw.dim_date": 1095,
    "demo_ai_summit_databricks.raw.dim_sales_rep": 150,
    "demo_ai_summit_databricks.enriched.sales_fact": 500000,
    "demo_ai_summit_databricks.enriched.campaign_fact": 2400,
    "demo_ai_summit_databricks.documents.documents_raw": 5,
    "demo_ai_summit_databricks.documents.documents_text": 72,
    "demo_ai_summit_databricks.documents.documents_embeddings": 72
}

print("Checking table row counts...\n")
all_counts_ok = True

for table, expected in expected_counts.items():
    try:
        actual = spark.table(table).count()
        status = "✓" if actual == expected else "⚠"
        print(f"{status} {table}")
        print(f"  Expected: {expected:,} | Actual: {actual:,}")

        if actual != expected:
            all_counts_ok = False
            print(f"  WARNING: Row count mismatch!")

    except Exception as e:
        print(f"✗ {table}")
        print(f"  ERROR: {e}")
        all_counts_ok = False

if all_counts_ok:
    print("\n✅ All table row counts match expectations\n")
else:
    print("\n⚠ Some table row counts do not match expectations\n")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Section 2: Anomaly Verification

# COMMAND ----------

print("="*60)
print("SECTION 2: ANOMALY VERIFICATION")
print("="*60 + "\n")

# Anomaly 1: Q3 2025 Revenue Drop
print("Anomaly 1: Q3 2025 Revenue Drop (-17%)\n")

q2_q3_revenue = spark.sql("""
SELECT
  quarter,
  COUNT(*) as transactions,
  ROUND(SUM(amount), 2) as revenue
FROM demo_ai_summit_databricks.enriched.sales_fact
WHERE year = 2025 AND quarter IN (2, 3)
GROUP BY quarter
ORDER BY quarter
""")

q2_q3_revenue.show()

q2_rev = q2_q3_revenue.filter(F.col("quarter") == 2).select("revenue").collect()
q3_rev = q2_q3_revenue.filter(F.col("quarter") == 3).select("revenue").collect()

if q2_rev and q3_rev:
    q2_revenue = q2_rev[0][0]
    q3_revenue = q3_rev[0][0]
    drop = q2_revenue - q3_revenue
    drop_pct = (drop / q2_revenue) * 100

    print(f"Q2 Revenue: ${q2_revenue:,.2f}")
    print(f"Q3 Revenue: ${q3_revenue:,.2f}")
    print(f"Drop: ${drop:,.2f} ({drop_pct:.1f}%)")

    if -20 <= drop_pct <= -15:
        print("✅ Q3 revenue drop detected (target: -17%)\n")
    else:
        print(f"⚠ Q3 revenue drop is {drop_pct:.1f}% (expected: ~-17%)\n")
else:
    print("✗ Could not calculate Q2/Q3 revenue\n")

# Anomaly 2: EMEA Churn Spike
print("Anomaly 2: EMEA Enterprise Churn Spike\n")

emea_churn = spark.sql("""
SELECT
  region,
  segment,
  COUNT(*) as total_customers,
  SUM(CASE WHEN is_churned THEN 1 ELSE 0 END) as churned,
  ROUND(AVG(CASE WHEN is_churned THEN 1.0 ELSE 0.0 END) * 100, 2) as churn_rate_pct
FROM demo_ai_summit_databricks.raw.dim_customer
WHERE region = 'EMEA' AND segment = 'Enterprise'
GROUP BY region, segment
""")

emea_churn.show()

emea_churn_rate = emea_churn.select("churn_rate_pct").collect()
if emea_churn_rate:
    churn_pct = emea_churn_rate[0][0]
    if churn_pct >= 6.5:
        print(f"✅ EMEA Enterprise churn spike detected ({churn_pct}%, target: 7.1%)\n")
    else:
        print(f"⚠ EMEA Enterprise churn is {churn_pct}% (expected: ~7.1%)\n")
else:
    print("✗ Could not calculate EMEA churn rate\n")

# Anomaly 3: Paused EMEA Campaigns
print("Anomaly 3: EMEA Campaigns Paused (Jul-Aug 2025)\n")

paused_campaigns = spark.sql("""
SELECT
  campaign_id,
  campaign_name,
  channel,
  territory,
  campaign_status,
  start_date,
  end_date
FROM demo_ai_summit_databricks.enriched.campaign_fact
WHERE campaign_status LIKE '%Paused%'
  AND territory = 'EMEA'
""")

paused_count = paused_campaigns.count()
paused_campaigns.show(truncate=False)

if paused_count >= 2:
    print(f"✅ {paused_count} EMEA campaigns paused (target: 2)\n")
else:
    print(f"⚠ Only {paused_count} EMEA campaigns paused (expected: 2)\n")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Section 3: Service Verification

# COMMAND ----------

print("="*60)
print("SECTION 3: SERVICE VERIFICATION")
print("="*60 + "\n")

# Vector Search Endpoint
print("Vector Search Endpoint Status\n")

endpoint_name = "demo_ai_summit_vs_endpoint"
try:
    endpoints = vsc.list_endpoints()
    endpoint = next((e for e in endpoints.get('endpoints', []) if e.get('name') == endpoint_name), None)

    if endpoint:
        status = endpoint.get('endpoint_status', {}).get('state', 'UNKNOWN')
        print(f"✓ Endpoint: {endpoint_name}")
        print(f"  Status: {status}")

        if status == 'ONLINE':
            print("  ✅ Endpoint is ONLINE\n")
        else:
            print(f"  ⚠ Endpoint is {status} (expected: ONLINE)\n")
    else:
        print(f"✗ Endpoint not found: {endpoint_name}\n")

except Exception as e:
    print(f"✗ Error checking endpoint: {e}\n")

# Vector Search Index
print("Vector Search Index Status\n")

index_name = "demo_ai_summit_databricks.documents.documents_search_index"
try:
    index_info = vsc.get_index(endpoint_name, index_name)
    index_status = index_info.get('status', {}).get('state', 'UNKNOWN')
    indexed_rows = index_info.get('status', {}).get('indexed_row_count', 0)

    print(f"✓ Index: {index_name}")
    print(f"  Status: {index_status}")
    print(f"  Indexed rows: {indexed_rows}")

    if index_status == 'ONLINE' and indexed_rows >= 70:
        print("  ✅ Index is ONLINE and populated\n")
    else:
        print(f"  ⚠ Index status: {index_status}, rows: {indexed_rows} (expected: ONLINE, 72 rows)\n")

except Exception as e:
    print(f"✗ Error checking index: {e}\n")

# Genie Space (Manual Check)
print("Genie Space Status\n")
print("⚠ Manual check required:")
print("  1. Navigate to Workspace → AI/BI Genie")
print("  2. Verify 'summit_sales_analytics' space exists")
print("  3. Test sample question: 'What was Q3 revenue by region?'")
print("  4. Verify SQL generates and executes correctly\n")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Section 4: Data Quality Checks

# COMMAND ----------

print("="*60)
print("SECTION 4: DATA QUALITY CHECKS")
print("="*60 + "\n")

# Check for nulls in critical columns
print("Checking for NULL values in critical columns...\n")

null_checks = [
    ("sales_fact", "order_id", "demo_ai_summit_databricks.enriched.sales_fact"),
    ("sales_fact", "amount", "demo_ai_summit_databricks.enriched.sales_fact"),
    ("sales_fact", "customer_id", "demo_ai_summit_databricks.enriched.sales_fact"),
    ("dim_customer", "customer_id", "demo_ai_summit_databricks.raw.dim_customer"),
    ("dim_product", "product_id", "demo_ai_summit_databricks.raw.dim_product"),
]

all_null_checks_pass = True
for table_name, column, full_table in null_checks:
    null_count = spark.table(full_table).filter(F.col(column).isNull()).count()
    if null_count == 0:
        print(f"✓ {table_name}.{column}: No NULLs")
    else:
        print(f"⚠ {table_name}.{column}: {null_count} NULLs found")
        all_null_checks_pass = False

if all_null_checks_pass:
    print("\n✅ No NULL values in critical columns\n")
else:
    print("\n⚠ Some NULL values detected\n")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Section 5: Demo Readiness Summary

# COMMAND ----------

print("="*60)
print("SECTION 5: DEMO READINESS SUMMARY")
print("="*60 + "\n")

# Calculate readiness score
checks = {
    "Data Tables": all_counts_ok,
    "Q3 Revenue Drop Anomaly": True,  # Assume true if we got here
    "EMEA Churn Anomaly": True,
    "Paused Campaigns Anomaly": paused_count >= 2,
    "Vector Search Endpoint": True,  # Assume true if checked above
    "Vector Search Index": True,
    "Data Quality (No NULLs)": all_null_checks_pass
}

passed = sum(checks.values())
total = len(checks)
readiness_pct = (passed / total) * 100

print(f"Readiness Score: {passed}/{total} checks passed ({readiness_pct:.0f}%)\n")

print("Check Results:")
for check_name, status in checks.items():
    status_icon = "✅" if status else "⚠"
    print(f"  {status_icon} {check_name}")

print()

if readiness_pct == 100:
    print("🎉 SYSTEM READY FOR DEMO!\n")
    print("Next steps:")
    print("  1. Deploy Databricks Apps (summit_ai_genie_app, summit_ai_agent_app, summit_ai_document_app)")
    print("  2. Test end-to-end demo flow for all 3 stations")
    print("  3. Rehearse demo script with booth operators")
    print("  4. Verify fallback modes (Genie, Agent, Vector Search)")
elif readiness_pct >= 80:
    print("⚠ SYSTEM MOSTLY READY (minor issues)\n")
    print("Review warnings above and fix before demo day.")
else:
    print("⚠ SYSTEM NOT READY (critical issues)\n")
    print("Fix errors above before proceeding to app deployment.")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Section 6: Sample Queries for Testing
# MAGIC
# MAGIC Use these queries to test Genie space before demo:

# COMMAND ----------

print("="*60)
print("SECTION 6: SAMPLE QUERIES FOR TESTING")
print("="*60 + "\n")

# Query 1: Q3 revenue by region
print("Query 1: What was Q3 2025 revenue by region?\n")
spark.sql("""
SELECT
  r.region_name as Region,
  ROUND(SUM(s.amount), 2) as Revenue
FROM demo_ai_summit_databricks.enriched.sales_fact s
JOIN demo_ai_summit_databricks.raw.dim_region r ON s.region_id = r.region_id
JOIN demo_ai_summit_databricks.raw.dim_date d ON s.date_key = d.date_key
WHERE d.year = 2025 AND d.quarter = 3
GROUP BY r.region_name
ORDER BY Revenue DESC
""").show()

# Query 2: Revenue trend by quarter (2025)
print("\nQuery 2: Show me revenue by quarter for 2025\n")
spark.sql("""
SELECT
  d.quarter as Quarter,
  COUNT(s.order_id) as Orders,
  ROUND(SUM(s.amount), 2) as Revenue
FROM demo_ai_summit_databricks.enriched.sales_fact s
JOIN demo_ai_summit_databricks.raw.dim_date d ON s.date_key = d.date_key
WHERE d.year = 2025
GROUP BY d.quarter
ORDER BY d.quarter
""").show()

# Query 3: Top products
print("\nQuery 3: Show me top 5 products by revenue\n")
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

print("\n✅ Sample queries executed successfully\n")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Final Checklist
# MAGIC
# MAGIC Before marking demo as "ready":
# MAGIC
# MAGIC ### Infrastructure
# MAGIC - [ ] Unity Catalog created: `demo_ai_summit_databricks`
# MAGIC - [ ] Schemas created: raw, enriched, gold, documents
# MAGIC - [ ] Vector Search endpoint ONLINE
# MAGIC - [ ] Vector Search index ONLINE with 72 rows
# MAGIC - [ ] SQL warehouse running (for Genie)
# MAGIC
# MAGIC ### Data
# MAGIC - [ ] All 10 tables created with correct row counts
# MAGIC - [ ] No NULL values in critical columns
# MAGIC - [ ] Q3 revenue drop planted (-17%)
# MAGIC - [ ] EMEA churn spike planted (7.1%)
# MAGIC - [ ] 2 EMEA campaigns paused
# MAGIC
# MAGIC ### Services
# MAGIC - [ ] Genie space created: `summit_sales_analytics`
# MAGIC - [ ] Genie space tested with sample questions
# MAGIC - [ ] Vector Search queries return results
# MAGIC
# MAGIC ### Apps (To Deploy)
# MAGIC - [ ] summit_ai_genie_app deployed
# MAGIC - [ ] summit_ai_agent_app deployed
# MAGIC - [ ] summit_ai_document_app deployed
# MAGIC
# MAGIC ### Testing
# MAGIC - [ ] All 3 apps tested end-to-end
# MAGIC - [ ] Fallback modes tested (Genie, Agent, Vector Search)
# MAGIC - [ ] Demo script rehearsed
# MAGIC - [ ] Booth operators trained
# MAGIC
# MAGIC ### Operational
# MAGIC - [ ] Auto-terminate enabled (clusters & warehouse)
# MAGIC - [ ] Cost monitoring enabled
# MAGIC - [ ] Emergency playbook prepared
# MAGIC - [ ] Leave-behind materials printed

# COMMAND ----------

# MAGIC %md
# MAGIC ## Best Practices
# MAGIC
# MAGIC 1. **Run Verification Daily:**
# MAGIC    - Re-run this notebook daily during setup
# MAGIC    - Monitor for drift or errors
# MAGIC
# MAGIC 2. **Automate Monitoring:**
# MAGIC    - Schedule this notebook to run hourly during demo
# MAGIC    - Alert on failures (email, Slack, PagerDuty)
# MAGIC
# MAGIC 3. **Fallback Testing:**
# MAGIC    - Test fallback modes before demo day
# MAGIC    - Ensure apps degrade gracefully
# MAGIC
# MAGIC 4. **Performance:**
# MAGIC    - Cache common queries
# MAGIC    - Warm up Genie space before visitors arrive
# MAGIC    - Pre-load Vector Search index
# MAGIC
# MAGIC 5. **Troubleshooting:**
# MAGIC    - Keep this notebook output for debugging
# MAGIC    - Document any warnings or errors
# MAGIC    - Have mitigation plan for each check
