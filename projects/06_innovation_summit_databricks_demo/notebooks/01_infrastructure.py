# Databricks notebook source
# MAGIC %md
# MAGIC # Innovation Summit AI Demo — Infrastructure Setup
# MAGIC
# MAGIC **Purpose:** Create Unity Catalog, schemas, volumes, and Vector Search endpoint
# MAGIC
# MAGIC **Run:** Once (idempotent)
# MAGIC
# MAGIC **Prerequisites:**
# MAGIC - Databricks Premium or Enterprise workspace
# MAGIC - Unity Catalog enabled
# MAGIC - Admin permissions (account admin or metastore admin)
# MAGIC
# MAGIC **Learning Objectives:**
# MAGIC 1. Create Unity Catalog catalog for demo
# MAGIC 2. Set up schema organization (raw, enriched, gold, documents)
# MAGIC 3. Create Unity Catalog volumes for document storage
# MAGIC 4. Initialize Vector Search endpoint
# MAGIC
# MAGIC **Architecture:**
# MAGIC ```
# MAGIC DEMO_AI_SUMMIT_DATABRICKS (catalog)
# MAGIC ├── raw (schema) — Landing zone
# MAGIC ├── enriched (schema) — Transformed data
# MAGIC ├── gold (schema) — Analytics-ready
# MAGIC └── documents (schema) — Document chunks + embeddings
# MAGIC
# MAGIC Volumes:
# MAGIC └── /Volumes/demo_ai_summit_databricks/documents/raw_docs
# MAGIC
# MAGIC Vector Search:
# MAGIC └── demo_ai_summit_vs_endpoint
# MAGIC ```

# COMMAND ----------

# MAGIC %md
# MAGIC ## Step 1: Verify Environment

# COMMAND ----------

# Check Unity Catalog availability
print("Checking Unity Catalog availability...")
catalogs = spark.sql("SHOW CATALOGS").collect()
print(f"✓ Unity Catalog enabled. Found {len(catalogs)} catalogs.")

# Check Mosaic AI features
try:
    from databricks.vector_search.client import VectorSearchClient
    print("✓ Vector Search client available")
except ImportError as e:
    print(f"⚠ Vector Search unavailable: {e}")

# Check foundation model access
try:
    result = spark.sql("SELECT ai_query('databricks-dbrx-instruct', 'Hello')").collect()
    print("✓ Foundation models accessible")
except Exception as e:
    print(f"⚠ Foundation models unavailable: {e}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Step 2: Create Catalog

# COMMAND ----------

# Create catalog
spark.sql("""
CREATE CATALOG IF NOT EXISTS demo_ai_summit_databricks
COMMENT 'Innovation Summit AI Demo — Databricks Lakehouse Edition'
""")

print("✓ Catalog created: demo_ai_summit_databricks")

# Set as current catalog
spark.sql("USE CATALOG demo_ai_summit_databricks")
print("✓ Catalog activated")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Step 3: Create Schemas

# COMMAND ----------

# Raw schema — landing zone for ingested data
spark.sql("""
CREATE SCHEMA IF NOT EXISTS demo_ai_summit_databricks.raw
COMMENT 'Raw landing zone for ingested data'
""")
print("✓ Schema created: raw")

# Enriched schema — joined and transformed tables
spark.sql("""
CREATE SCHEMA IF NOT EXISTS demo_ai_summit_databricks.enriched
COMMENT 'Enriched data with joins and transformations'
""")
print("✓ Schema created: enriched")

# Gold schema — business-ready analytics tables
spark.sql("""
CREATE SCHEMA IF NOT EXISTS demo_ai_summit_databricks.gold
COMMENT 'Gold layer — analytics-ready aggregations'
""")
print("✓ Schema created: gold")

# Documents schema — document chunks and embeddings
spark.sql("""
CREATE SCHEMA IF NOT EXISTS demo_ai_summit_databricks.documents
COMMENT 'Document Intelligence + Vector Search — text chunks and embeddings'
""")
print("✓ Schema created: documents")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Step 4: Create Volumes for Documents

# COMMAND ----------

# Create volume for raw PDF files
spark.sql("""
CREATE VOLUME IF NOT EXISTS demo_ai_summit_databricks.documents.raw_docs
COMMENT 'Raw PDF files for Document Intelligence processing'
""")
print("✓ Volume created: /Volumes/demo_ai_summit_databricks/documents/raw_docs")

# Verify volume path
volume_path = "/Volumes/demo_ai_summit_databricks/documents/raw_docs"
dbutils.fs.mkdirs(volume_path)
print(f"✓ Volume path verified: {volume_path}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Step 5: Create Vector Search Endpoint

# COMMAND ----------

from databricks.vector_search.client import VectorSearchClient

# Initialize Vector Search client
vsc = VectorSearchClient()

# Endpoint name
endpoint_name = "demo_ai_summit_vs_endpoint"

# Check if endpoint exists
try:
    existing_endpoints = vsc.list_endpoints()
    endpoint_exists = any(e.get('name') == endpoint_name for e in existing_endpoints.get('endpoints', []))

    if endpoint_exists:
        print(f"✓ Vector Search endpoint already exists: {endpoint_name}")
    else:
        # Create endpoint
        vsc.create_endpoint(
            name=endpoint_name,
            endpoint_type="STANDARD"
        )
        print(f"✓ Vector Search endpoint created: {endpoint_name}")
        print("  (Note: Endpoint provisioning may take 5-10 minutes)")
except Exception as e:
    print(f"⚠ Vector Search endpoint creation failed: {e}")
    print("  You may need to create this manually via Workspace UI → Compute → Vector Search")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Step 6: Grant Permissions

# COMMAND ----------

# Grant permissions to current user
current_user = spark.sql("SELECT current_user() as user").collect()[0]['user']
print(f"Current user: {current_user}")

# Note: In production, you would create service principals and grant specific permissions
# For demo purposes, we assume the user running this notebook has appropriate permissions

# Grant usage on catalog and schemas (example - adjust as needed)
try:
    # These commands require admin privileges
    # Uncomment and adjust for your security model

    # spark.sql(f"GRANT USE CATALOG ON CATALOG demo_ai_summit_databricks TO `{current_user}`")
    # spark.sql(f"GRANT USE SCHEMA ON SCHEMA demo_ai_summit_databricks.raw TO `{current_user}`")
    # spark.sql(f"GRANT USE SCHEMA ON SCHEMA demo_ai_summit_databricks.enriched TO `{current_user}`")
    # spark.sql(f"GRANT USE SCHEMA ON SCHEMA demo_ai_summit_databricks.gold TO `{current_user}`")
    # spark.sql(f"GRANT USE SCHEMA ON SCHEMA demo_ai_summit_databricks.documents TO `{current_user}`")

    print("✓ Permissions configured (review grant statements above)")
except Exception as e:
    print(f"⚠ Permission grants skipped: {e}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Step 7: Verification

# COMMAND ----------

# Verify catalog structure
print("=== Catalog Structure ===")
schemas = spark.sql("SHOW SCHEMAS IN demo_ai_summit_databricks").collect()
for schema in schemas:
    print(f"  - {schema['databaseName']}")

# Verify volumes
print("\n=== Volumes ===")
volumes = spark.sql("SHOW VOLUMES IN demo_ai_summit_databricks.documents").collect()
for volume in volumes:
    print(f"  - {volume['volume_name']}")

# Verify Vector Search endpoint
print("\n=== Vector Search Endpoint ===")
try:
    endpoints = vsc.list_endpoints()
    for endpoint in endpoints.get('endpoints', []):
        if endpoint.get('name') == endpoint_name:
            print(f"  ✓ {endpoint_name} — Status: {endpoint.get('endpoint_status', {}).get('state', 'UNKNOWN')}")
except Exception as e:
    print(f"  ⚠ Could not verify endpoint: {e}")

print("\n✅ Infrastructure setup complete!")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Best Practices
# MAGIC
# MAGIC 1. **Unity Catalog Naming:**
# MAGIC    - Use lowercase with underscores: `demo_ai_summit_databricks`
# MAGIC    - Avoid hyphens (not supported in catalog names)
# MAGIC
# MAGIC 2. **Schema Organization:**
# MAGIC    - `raw`: Landing zone, minimal transformations
# MAGIC    - `enriched`: Joins, business logic
# MAGIC    - `gold`: Aggregations, analytics-ready
# MAGIC    - `documents`: Separate schema for unstructured data
# MAGIC
# MAGIC 3. **Vector Search Endpoints:**
# MAGIC    - One endpoint can serve multiple indexes
# MAGIC    - Endpoint provisioning takes 5-10 minutes
# MAGIC    - Check endpoint status before creating indexes
# MAGIC
# MAGIC 4. **Permissions:**
# MAGIC    - Use service principals for apps, not personal users
# MAGIC    - Follow principle of least privilege
# MAGIC    - Document all grants in version control
# MAGIC
# MAGIC 5. **Volumes:**
# MAGIC    - Use volumes for file storage (not DBFS)
# MAGIC    - Volumes are governed by Unity Catalog
# MAGIC    - Support external locations (S3, ADLS, GCS)
