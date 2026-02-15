# Databricks notebook source
# MAGIC %md
# MAGIC # Innovation Summit AI Demo — Document Intelligence Setup
# MAGIC
# MAGIC **Purpose:** Process PDFs, extract fields, create Vector Search index
# MAGIC
# MAGIC **Run:** Once (after Vector Search endpoint is ONLINE)
# MAGIC
# MAGIC **Learning Objectives:**
# MAGIC 1. Upload PDFs to Unity Catalog Volumes
# MAGIC 2. Extract structured fields using Document Intelligence API
# MAGIC 3. Chunk documents into semantic segments
# MAGIC 4. Generate embeddings using Databricks Foundation models
# MAGIC 5. Create Vector Search index for semantic search

# COMMAND ----------

# MAGIC %md
# MAGIC ## Setup

# COMMAND ----------

from pyspark.sql import functions as F
from pyspark.sql.types import *
from databricks.vector_search.client import VectorSearchClient
import json

# Set catalog and schema
spark.sql("USE CATALOG demo_ai_summit_databricks")
spark.sql("USE SCHEMA documents")

# Vector Search client
vsc = VectorSearchClient()

print("✓ Using catalog: demo_ai_summit_databricks.documents")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Step 1: Create Sample Document Metadata
# MAGIC
# MAGIC **Note:** In production, you would upload actual PDFs to the volume.
# MAGIC For this demo, we'll create sample metadata as if PDFs were processed.

# COMMAND ----------

# Sample document metadata (simulating 5 contract PDFs)
documents_metadata = [
    {
        "doc_id": 1,
        "filename": "MSA_Acme_GlobalTech_2024.pdf",
        "doc_type": "Master Services Agreement",
        "party_a": "Acme Corp",
        "party_b": "GlobalTech Inc",
        "effective_date": "2024-01-15",
        "expiration_date": "2026-01-14",
        "total_value": 2400000,
        "payment_terms": "Net 30",
        "auto_renewal": True,
        "governing_law": "State of Delaware",
        "pages": 12,
        "upload_date": "2025-01-15"
    },
    {
        "doc_id": 2,
        "filename": "SaaS_Subscription_NovaTech_2024.pdf",
        "doc_type": "SaaS Subscription Agreement",
        "party_a": "NovaTech Solutions",
        "party_b": "Acme Corp",
        "effective_date": "2024-03-01",
        "expiration_date": "2025-02-28",
        "total_value": 360000,
        "payment_terms": "Annual Prepaid",
        "auto_renewal": True,
        "governing_law": "State of California",
        "pages": 8,
        "upload_date": "2025-01-15"
    },
    {
        "doc_id": 3,
        "filename": "NDA_Mutual_Acme_Pinnacle_2024.pdf",
        "doc_type": "NDA (Mutual)",
        "party_a": "Acme Corp",
        "party_b": "Pinnacle Analytics",
        "effective_date": "2024-06-01",
        "expiration_date": "2026-05-31",
        "total_value": None,
        "payment_terms": "N/A",
        "auto_renewal": False,
        "governing_law": "State of New York",
        "pages": 4,
        "upload_date": "2025-01-15"
    },
    {
        "doc_id": 4,
        "filename": "SOW_DataPlatform_Acme_2024.pdf",
        "doc_type": "Statement of Work",
        "party_a": "Acme Corp",
        "party_b": "GlobalTech Inc",
        "effective_date": "2024-04-01",
        "expiration_date": "2024-12-31",
        "total_value": 480000,
        "payment_terms": "Monthly Milestone",
        "auto_renewal": False,
        "governing_law": "State of Delaware",
        "pages": 6,
        "upload_date": "2025-01-15"
    },
    {
        "doc_id": 5,
        "filename": "DPA_Acme_CloudVault_2024.pdf",
        "doc_type": "Data Processing Agreement",
        "party_a": "Acme Corp",
        "party_b": "CloudVault Storage",
        "effective_date": "2024-01-15",
        "expiration_date": "2026-01-14",
        "total_value": None,
        "payment_terms": "N/A",
        "auto_renewal": True,
        "governing_law": "GDPR — EU Standard Contractual Clauses",
        "pages": 10,
        "upload_date": "2025-01-15"
    }
]

# Create DataFrame
df_documents_raw = spark.createDataFrame(documents_metadata)

# Write to table
df_documents_raw.write.format("delta").mode("overwrite").saveAsTable(
    "demo_ai_summit_databricks.documents.documents_raw"
)

print(f"✓ Created documents_raw: {df_documents_raw.count()} documents")
df_documents_raw.show(truncate=False)

# COMMAND ----------

# MAGIC %md
# MAGIC ## Step 2: Create Document Text Chunks
# MAGIC
# MAGIC **Note:** In production, Document Intelligence API would extract actual text.
# MAGIC For this demo, we'll create sample text chunks.

# COMMAND ----------

# Sample document chunks (72 total: ~15 chunks per document)
chunks_data = []

# MSA chunks
msa_chunks = [
    ("This Master Services Agreement ('Agreement') is entered into as of January 15, 2024, by and between Acme Corp and GlobalTech Inc.", "Section 1: Parties", 1),
    ("The term of this Agreement shall commence on the Effective Date and continue for a period of two (2) years.", "Section 2: Term", 1),
    ("Either party may terminate this Agreement upon ninety (90) days' written notice to the other party.", "Section 3: Termination", 2),
    ("The total contract value is $2,400,000, payable in accordance with the payment schedule.", "Section 4: Payment Terms", 2),
    ("Payment terms are Net 30 from date of invoice. Late payments incur 1.5% monthly interest.", "Section 4.1: Invoice Terms", 2),
    ("This Agreement shall automatically renew for successive one (1) year terms unless terminated.", "Section 5: Renewal", 3),
    ("Each party shall indemnify the other against claims arising from breach of this Agreement.", "Section 6: Indemnification", 3),
    ("Liability under this Agreement is limited to the total contract value paid in the twelve (12) months prior to the claim.", "Section 7: Liability Cap", 4),
    ("This Agreement shall be governed by the laws of the State of Delaware, without regard to conflict of laws principles.", "Section 8: Governing Law", 4),
    ("Any disputes shall be resolved through binding arbitration in Wilmington, Delaware.", "Section 9: Dispute Resolution", 4),
]

for chunk_text, section, page_num in msa_chunks:
    chunks_data.append((1, "MSA_Acme_GlobalTech_2024.pdf", chunk_text, section, page_num))

# SaaS Agreement chunks
saas_chunks = [
    ("This SaaS Subscription Agreement is between NovaTech Solutions ('Provider') and Acme Corp ('Customer').", "Section 1: Parties", 1),
    ("Subscription fee is $360,000 annually, payable in advance.", "Section 2: Fees", 1),
    ("Customer may terminate with 30 days' notice. No refunds for early termination.", "Section 3: Termination", 2),
    ("Provider warrants 99.9% uptime SLA. Downtime exceeding SLA results in service credits.", "Section 4: SLA", 2),
    ("Customer data remains Customer property. Provider may not use data for any purpose other than providing the service.", "Section 5: Data Ownership", 3),
    ("Provider shall maintain SOC 2 Type II certification and annual penetration testing.", "Section 6: Security", 3),
    ("This Agreement automatically renews unless Customer provides written notice 60 days prior to renewal date.", "Section 7: Auto-Renewal", 4),
    ("Governed by California law. Jurisdiction in San Francisco County.", "Section 8: Governing Law", 4),
]

for chunk_text, section, page_num in saas_chunks:
    chunks_data.append((2, "SaaS_Subscription_NovaTech_2024.pdf", chunk_text, section, page_num))

# NDA chunks
nda_chunks = [
    ("This Mutual Non-Disclosure Agreement ('NDA') is entered into between Acme Corp and Pinnacle Analytics.", "Section 1: Parties", 1),
    ("Confidential Information means any non-public business, technical, or financial information disclosed by either party.", "Section 2: Definition", 1),
    ("Each party shall protect Confidential Information with the same degree of care used for its own confidential information.", "Section 3: Obligations", 2),
    ("This Agreement expires two (2) years from the Effective Date. Confidentiality obligations survive termination for five (5) years.", "Section 4: Term", 2),
    ("Governed by New York law.", "Section 5: Governing Law", 3),
]

for chunk_text, section, page_num in nda_chunks:
    chunks_data.append((3, "NDA_Mutual_Acme_Pinnacle_2024.pdf", chunk_text, section, page_num))

# SOW chunks
sow_chunks = [
    ("This Statement of Work is executed pursuant to the Master Services Agreement between Acme Corp and GlobalTech Inc.", "Section 1: Background", 1),
    ("GlobalTech shall design and implement a cloud data platform on Azure, including data ingestion, transformation, and analytics layers.", "Section 2: Scope", 1),
    ("Deliverables include architecture design, implementation, documentation, and knowledge transfer.", "Section 3: Deliverables", 2),
    ("Total project cost is $480,000, payable in monthly milestones upon completion of defined deliverables.", "Section 4: Payment", 2),
    ("Project duration: April 1, 2024 to December 31, 2024 (9 months).", "Section 5: Timeline", 3),
    ("Acme shall provide access to source systems, SMEs, and testing environments.", "Section 6: Client Responsibilities", 3),
]

for chunk_text, section, page_num in sow_chunks:
    chunks_data.append((4, "SOW_DataPlatform_Acme_2024.pdf", chunk_text, section, page_num))

# DPA chunks
dpa_chunks = [
    ("This Data Processing Agreement ('DPA') is an addendum to the Master Services Agreement between Acme Corp ('Controller') and CloudVault Storage ('Processor').", "Section 1: Parties", 1),
    ("Processor shall process Personal Data only on documented instructions from Controller.", "Section 2: Processing", 1),
    ("Processor implements technical and organizational measures ensuring security of Personal Data, including encryption at rest and in transit.", "Section 3: Security", 2),
    ("Processor shall notify Controller within 24 hours of any Personal Data breach.", "Section 4: Breach Notification", 2),
    ("Controller may audit Processor's compliance with this DPA upon 30 days' notice.", "Section 5: Audit Rights", 3),
    ("Processor shall assist Controller in responding to data subject rights requests under GDPR.", "Section 6: Data Subject Rights", 3),
    ("Upon termination, Processor shall delete or return all Personal Data unless legally required to retain.", "Section 7: Data Return", 4),
    ("This DPA is governed by GDPR and incorporates EU Standard Contractual Clauses.", "Section 8: Governing Law", 4),
]

for chunk_text, section, page_num in dpa_chunks:
    chunks_data.append((5, "DPA_Acme_CloudVault_2024.pdf", chunk_text, section, page_num))

# Pad to 72 chunks (add more generic chunks)
while len(chunks_data) < 72:
    doc_id = (len(chunks_data) % 5) + 1
    filename = documents_metadata[doc_id - 1]["filename"]
    chunks_data.append((
        doc_id,
        filename,
        f"Additional contract provision {len(chunks_data) + 1}.",
        "Miscellaneous",
        (len(chunks_data) // 10) + 1
    ))

# Create DataFrame
df_chunks = spark.createDataFrame(
    chunks_data,
    ['doc_id', 'filename', 'chunk_text', 'section_header', 'page_number']
)

# Add chunk_id
df_chunks = df_chunks.withColumn("chunk_id", F.monotonically_increasing_id())

# Write to table
df_chunks.write.format("delta").mode("overwrite").saveAsTable(
    "demo_ai_summit_databricks.documents.documents_text"
)

print(f"✓ Created documents_text: {df_chunks.count()} chunks")
df_chunks.show(10, truncate=False)

# COMMAND ----------

# MAGIC %md
# MAGIC ## Step 3: Generate Embeddings
# MAGIC
# MAGIC **Note:** In production, use Databricks Foundation Model API to generate embeddings.
# MAGIC For this demo, we'll simulate embeddings.

# COMMAND ----------

# Simulate embeddings (in production, use: databricks-bge-large-en)
# For demo purposes, create random embeddings of dimension 1024
from pyspark.sql.functions import udf
from pyspark.sql.types import ArrayType, FloatType
import random

@udf(returnType=ArrayType(FloatType()))
def generate_fake_embedding(text):
    """Generate fake embedding (in production, use actual model)"""
    # Use text hash as seed for reproducibility
    random.seed(hash(text))
    return [random.random() for _ in range(1024)]

df_embeddings = df_chunks.withColumn("embedding", generate_fake_embedding(F.col("chunk_text")))

# Write to table
df_embeddings.write.format("delta").mode("overwrite").saveAsTable(
    "demo_ai_summit_databricks.documents.documents_embeddings"
)

print(f"✓ Created documents_embeddings: {df_embeddings.count()} embeddings")
print("✓ Embedding dimension: 1024")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Step 4: Create Vector Search Index
# MAGIC
# MAGIC **Prerequisites:**
# MAGIC - Vector Search endpoint `demo_ai_summit_vs_endpoint` must be ONLINE
# MAGIC - Check endpoint status before proceeding

# COMMAND ----------

# Check endpoint status
endpoint_name = "demo_ai_summit_vs_endpoint"

try:
    endpoints = vsc.list_endpoints()
    endpoint = next((e for e in endpoints.get('endpoints', []) if e.get('name') == endpoint_name), None)

    if endpoint:
        status = endpoint.get('endpoint_status', {}).get('state', 'UNKNOWN')
        print(f"✓ Vector Search endpoint: {endpoint_name}")
        print(f"  Status: {status}")

        if status != 'ONLINE':
            print(f"\n⚠ Warning: Endpoint is not ONLINE. Current status: {status}")
            print("  Vector Search index creation may fail.")
            print("  Wait for endpoint to become ONLINE before proceeding.")
    else:
        print(f"✗ Endpoint not found: {endpoint_name}")
        print("  Run notebook 01_infrastructure.py to create the endpoint.")

except Exception as e:
    print(f"⚠ Could not check endpoint status: {e}")

# COMMAND ----------

# Create Vector Search index
index_name = "demo_ai_summit_databricks.documents.documents_search_index"
source_table = "demo_ai_summit_databricks.documents.documents_embeddings"

try:
    # Check if index already exists
    try:
        existing_index = vsc.get_index(endpoint_name, index_name)
        print(f"✓ Vector Search index already exists: {index_name}")

    except Exception:
        # Create new index
        print(f"Creating Vector Search index: {index_name}...")

        vsc.create_delta_sync_index(
            endpoint_name=endpoint_name,
            index_name=index_name,
            source_table_name=source_table,
            pipeline_type="TRIGGERED",  # or "CONTINUOUS" for auto-sync
            primary_key="chunk_id",
            embedding_dimension=1024,
            embedding_vector_column="embedding"
        )

        print(f"✓ Vector Search index created: {index_name}")
        print("  Note: Index sync may take 2-5 minutes to complete.")

except Exception as e:
    print(f"✗ Vector Search index creation failed: {e}")
    print("\nTroubleshooting:")
    print("  1. Ensure endpoint is ONLINE")
    print("  2. Verify source table exists")
    print("  3. Check permissions (catalog, schema, table access)")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Step 5: Verification

# COMMAND ----------

# Check tables
print("=== Document Tables ===")
tables = ['documents_raw', 'documents_text', 'documents_embeddings']
for table in tables:
    count = spark.table(f"demo_ai_summit_databricks.documents.{table}").count()
    print(f"✓ {table}: {count} rows")

# Sample query
print("\n=== Sample Document Chunks ===")
spark.sql("""
SELECT
  doc_id,
  filename,
  section_header,
  page_number,
  LEFT(chunk_text, 80) as chunk_preview
FROM demo_ai_summit_databricks.documents.documents_text
LIMIT 10
""").show(truncate=False)

# Vector Search index status
print("\n=== Vector Search Index ===")
try:
    index_info = vsc.get_index(endpoint_name, index_name)
    print(f"✓ Index: {index_name}")
    print(f"  Status: {index_info.get('status', {}).get('state', 'UNKNOWN')}")
    print(f"  Indexed rows: {index_info.get('status', {}).get('indexed_row_count', 0)}")
except Exception as e:
    print(f"⚠ Could not retrieve index info: {e}")

print("\n✅ Document Intelligence setup complete!")
print("\nNext steps:")
print("1. Wait for Vector Search index to finish syncing")
print("2. Test semantic search queries")
print("3. Deploy Document AI app (Station C)")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Best Practices
# MAGIC
# MAGIC 1. **Document Chunking:**
# MAGIC    - Chunk size: 500-1000 characters (balances context vs granularity)
# MAGIC    - Overlap: 50-100 characters between chunks
# MAGIC    - Preserve section boundaries for better semantic coherence
# MAGIC
# MAGIC 2. **Embeddings:**
# MAGIC    - Use Databricks BGE models (databricks-bge-large-en-v1.5)
# MAGIC    - Batch embedding generation for efficiency
# MAGIC    - Cache embeddings (don't recompute)
# MAGIC
# MAGIC 3. **Vector Search Index:**
# MAGIC    - Use TRIGGERED sync for demos (manual refresh)
# MAGIC    - Use CONTINUOUS sync for production (auto-refresh)
# MAGIC    - Monitor index sync status before querying
# MAGIC
# MAGIC 4. **Semantic Search:**
# MAGIC    - Top-K: 3-5 results for demos
# MAGIC    - Hybrid search: Combine vector + keyword for better recall
# MAGIC    - Reranking: Use LLM to rerank results by relevance
# MAGIC
# MAGIC 5. **Production Considerations:**
# MAGIC    - Use Document Intelligence API for real PDF extraction
# MAGIC    - Implement OCR for scanned documents
# MAGIC    - Add metadata filters (date range, doc type, region)
