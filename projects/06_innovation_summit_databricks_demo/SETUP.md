# Databricks Innovation Summit AI Demo — Setup Guide

This guide walks you through deploying the Innovation Summit AI Demo on Databricks.

---

## Prerequisites

### Required Access
- **Databricks Workspace:** Premium or Enterprise tier
- **Unity Catalog:** Enabled and configured
- **Permissions:**
  - Catalog create/manage
  - Cluster create/manage
  - SQL warehouse create/manage (Serverless recommended)
  - Vector Search endpoint create
  - Workspace admin (for Apps deployment)

### Required Features
- ✅ Unity Catalog
- ✅ Mosaic AI (Genie, Agent Framework, Vector Search)
- ✅ Databricks Apps
- ✅ Foundation models (DBRX or Llama 3.1)

### Recommended Environment
- **Cloud:** AWS us-east-1, Azure East US, or GCP us-central1
- **Cluster:** 2-node interactive cluster (Standard_DS13_v2 or equivalent)
- **SQL Warehouse:** Serverless Pro (Medium size)

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    LAKEHOUSE ARCHITECTURE                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  DEMO_AI_SUMMIT_DATABRICKS (Unity Catalog)                     │
│  ├── raw                  — Dimension tables                    │
│  ├── enriched             — Fact tables (sales, campaigns)     │
│  ├── gold                 — Analytics aggregations             │
│  └── documents            — Document chunks + embeddings        │
│                                                                 │
│  Vector Search Endpoint: demo_ai_summit_vs_endpoint            │
│  └── Index: documents_search_index                             │
│                                                                 │
│  AI/BI Genie Space: summit_sales_analytics                     │
│  └── Semantic layer over sales + dimensions                     │
│                                                                 │
│  Agent: summit_investigator_agent                              │
│  └── Tools: SQL, Python, Unity Catalog                         │
│                                                                 │
│  Databricks Apps (3 stations):                                 │
│  ├── summit_ai_genie_app        (Station A)                    │
│  ├── summit_ai_agent_app        (Station B)                    │
│  └── summit_ai_document_app     (Station C)                    │
└─────────────────────────────────────────────────────────────────┘
```

---

## Setup Steps

### Step 1: Clone Repository

```bash
git clone https://github.com/your-org/snowbrix_academy.git
cd snowbrix_academy/projects/06_innovation_summit_databricks_demo
```

### Step 2: Import Notebooks to Databricks

**Option A: Databricks CLI**
```bash
# Install Databricks CLI
pip install databricks-cli

# Configure authentication
databricks configure --token

# Import notebooks
databricks workspace import_dir ./notebooks /Workspace/Users/your-email/innovation_summit_demo
```

**Option B: Workspace UI**
1. Open your Databricks workspace
2. Navigate to Workspace → Create → Import
3. Select "File" or "Folder"
4. Upload `notebooks/` directory
5. Notebooks will appear in your workspace

### Step 3: Run Setup Notebooks (In Order)

#### 3.1 Infrastructure Setup
**Notebook:** `01_infrastructure.py`

**What it does:**
- Creates Unity Catalog: `demo_ai_summit_databricks`
- Creates schemas: `raw`, `enriched`, `gold`, `documents`
- Creates volume: `/Volumes/demo_ai_summit_databricks/documents/raw_docs`
- Creates Vector Search endpoint: `demo_ai_summit_vs_endpoint`

**Run:**
```python
# Attach notebook to interactive cluster
# Run all cells (Cmd+Shift+Enter or Ctrl+Shift+Enter)
```

**Expected output:**
```
✓ Unity Catalog enabled
✓ Catalog created: demo_ai_summit_databricks
✓ Schemas created: raw, enriched, gold, documents
✓ Volume created
✓ Vector Search endpoint created (provisioning in progress)
```

**Duration:** 2-3 minutes (+ 5-10 minutes for Vector Search endpoint provisioning)

---

#### 3.2 Dimension Tables
**Notebook:** `02_dimensions.py`

**What it does:**
- Generates 12,000 customers (with EMEA churn anomaly)
- Generates 500 products across 6 categories
- Generates 20 regions (NA, EMEA, APAC, LATAM)
- Generates 1,095 dates (2023-2025)
- Generates 150 sales reps across 5 teams

**Run:**
```python
# Run all cells
```

**Expected output:**
```
✓ dim_customer: 12,000 rows
✓ dim_product: 500 rows
✓ dim_region: 20 rows
✓ dim_date: 1,095 rows
✓ dim_sales_rep: 150 rows
```

**Duration:** 1-2 minutes

---

#### 3.3 Fact Tables
**Notebooks:** `03_sales_fact.py`, `04_campaign_fact.py`

**What they do:**
- `03_sales_fact.py`: Generates 500,000 sales transactions
  - Planted anomaly: Q3 2025 revenue drop (-17%)
  - Regional breakdown: EMEA drops $1.6M
- `04_campaign_fact.py`: Generates 2,400 marketing campaigns
  - Planted anomaly: 2 EMEA campaigns paused (Jul-Aug 2025)

**Run:**
```python
# Run 03_sales_fact.py first
# Then run 04_campaign_fact.py
```

**Duration:** 2-3 minutes total

---

#### 3.4 Document Intelligence Setup
**Notebook:** `05_documents_setup.py`

**What it does:**
- Uploads 5 sample PDFs to UC Volume
- Extracts structured fields via Document Intelligence
- Chunks documents into 72 text segments
- Generates embeddings (BGE-large-en-v1.5)
- Creates Vector Search index: `documents_search_index`

**Run:**
```python
# Ensure Vector Search endpoint is ONLINE before running
# Check status: VectorSearchClient().list_endpoints()
```

**Duration:** 5-10 minutes (depending on PDF processing)

---

#### 3.5 Genie Space Configuration
**Notebook:** `06_genie_space.py`

**What it does:**
- Creates Genie space: `summit_sales_analytics`
- Defines semantic layer (tables, joins, metrics)
- Adds sample questions

**Run:**
```python
# Note: Genie space creation may require Workspace UI interaction
# Follow notebook instructions for manual steps
```

**Duration:** 5 minutes (including manual configuration)

---

### Step 4: Deploy Databricks Apps

#### 4.1 Create App: Station A (Genie)

**Location:** `apps/summit_ai_genie_app/`

**Files:**
- `app.py` — Streamlit-based UI
- `requirements.txt` — Python dependencies
- `app.yaml` — App configuration

**Deploy:**
1. Navigate to Workspace → Apps → Create App
2. Name: `summit_ai_genie_app`
3. Upload `app.py`, `requirements.txt`, `app.yaml`
4. Configure environment variables:
   - `GENIE_SPACE_ID`: `summit_sales_analytics`
   - `CATALOG`: `demo_ai_summit_databricks`
5. Deploy

**Test:**
- Open app URL
- Ask: "What was Q3 revenue by region?"
- Verify: Chart + table + SQL transparency

---

#### 4.2 Create App: Station B (Agent Framework)

**Location:** `apps/summit_ai_agent_app/`

**Deploy:**
1. Follow same steps as Station A
2. Configure environment variables:
   - `AGENT_ENDPOINT`: `summit_investigator_agent`
   - `CATALOG`: `demo_ai_summit_databricks`

**Test:**
- Ask: "Investigate why Q3 revenue dropped"
- Verify: Multi-step reasoning displayed

---

#### 4.3 Create App: Station C (Document Intelligence)

**Location:** `apps/summit_ai_document_app/`

**Deploy:**
1. Follow same steps as Station A
2. Configure environment variables:
   - `VECTOR_SEARCH_ENDPOINT`: `demo_ai_summit_vs_endpoint`
   - `VECTOR_SEARCH_INDEX`: `documents_search_index`
   - `CATALOG`: `demo_ai_summit_databricks`

**Test:**
- Select document: "MSA_Acme_GlobalTech_2024.pdf"
- Click "Process Document" → verify extracted fields
- Search: "What is the termination clause?"
- Verify: Semantic search results with scores

---

### Step 5: End-to-End Verification

**Verification Notebook:** `VERIFY_ALL.py`

**What it checks:**
- ✅ All tables exist and have expected row counts
- ✅ Planted anomalies are present (Q3 drop, EMEA churn)
- ✅ Vector Search index is online
- ✅ Genie space responds to queries
- ✅ Agent can execute investigations
- ✅ Apps are accessible

**Run:**
```python
# Run all cells in VERIFY_ALL.py
```

**Expected output:**
```
=== Data Verification ===
✓ dim_customer: 12,000 rows
✓ dim_product: 500 rows
✓ sales_fact: 500,000 rows
✓ campaign_fact: 2,400 rows
✓ documents_embeddings: 72 rows

=== Anomaly Verification ===
✓ Q3 revenue drop detected: -17%
✓ EMEA churn spike detected: 7.1%
✓ Paused campaigns detected: 2

=== Service Verification ===
✓ Vector Search endpoint: ONLINE
✓ Genie space: ACTIVE
✓ Agent endpoint: READY

=== App Verification ===
✓ summit_ai_genie_app: RUNNING
✓ summit_ai_agent_app: RUNNING
✓ summit_ai_document_app: RUNNING

✅ All systems operational!
```

---

## Troubleshooting

### Issue: Vector Search endpoint stuck in "PROVISIONING"

**Solution:**
- Wait 10-15 minutes for provisioning to complete
- Check workspace region supports Vector Search
- Verify account has Vector Search enabled
- Contact Databricks support if > 30 minutes

### Issue: Genie space not responding

**Solution:**
- Verify SQL warehouse is running (not auto-stopped)
- Check Genie space configuration in UI (Workspace → AI/BI Genie)
- Ensure semantic layer tables are accessible
- Review Genie space permissions

### Issue: Agent Framework timeout

**Solution:**
- Increase agent timeout (default 60s → 120s)
- Use fallback replay mode in app
- Check foundation model availability (DBRX vs Llama)
- Review agent tool definitions

### Issue: Databricks App deployment fails

**Solution:**
- Verify `requirements.txt` dependencies are compatible
- Check `app.yaml` syntax
- Ensure service principal has catalog permissions
- Review app logs in Workspace → Apps → [Your App] → Logs

---

## Performance Optimization

### For Large-Scale Demos (1000+ visitors/day)

1. **Cluster Auto-Scaling:**
   ```json
   {
     "autoscale": {
       "min_workers": 2,
       "max_workers": 8
     }
   }
   ```

2. **SQL Warehouse Scaling:**
   - Use Serverless Pro with max 5 clusters
   - Enable auto-stop after 10 minutes

3. **Vector Search Index Optimization:**
   - Use `DELTA_SYNC` for automatic updates
   - Enable query caching (default: 1 hour)

4. **App Performance:**
   - Add response caching (Redis or in-memory)
   - Pre-warm Genie space with common queries
   - Use agent replay mode for demo consistency

---

## Cost Estimation

### Estimated Costs (AWS us-east-1, 3-day event)

| Component | Usage | Cost |
|-----------|-------|------|
| **Interactive Cluster** | 24 hours (3 days × 8 hours) | ~$150 |
| **SQL Warehouse** | 30 hours (with auto-stop) | ~$200 |
| **Vector Search** | 1000 queries | ~$5 |
| **Genie Queries** | 500 queries | ~$25 |
| **Agent Runs** | 200 investigations | ~$40 |
| **Storage (Delta)** | 1 GB (negligible) | ~$0.10 |
| **Apps** | 3 apps × 3 days | ~$30 |
| **Total** | | **~$450** |

**Cost-Saving Tips:**
- Use auto-terminate for clusters (30 min idle)
- Use Serverless SQL (pay-per-query, not per-hour)
- Enable agent replay mode (reduces LLM calls)
- Pre-generate embeddings (don't recompute)

---

## Security Considerations

### Unity Catalog Permissions

**Principle of Least Privilege:**
```sql
-- Grant read-only access to demo users
GRANT USE CATALOG ON CATALOG demo_ai_summit_databricks TO `demo_users`;
GRANT USE SCHEMA ON SCHEMA demo_ai_summit_databricks.raw TO `demo_users`;
GRANT USE SCHEMA ON SCHEMA demo_ai_summit_databricks.enriched TO `demo_users`;
GRANT USE SCHEMA ON SCHEMA demo_ai_summit_databricks.gold TO `demo_users`;
GRANT SELECT ON ALL TABLES IN SCHEMA demo_ai_summit_databricks.raw TO `demo_users`;
GRANT SELECT ON ALL TABLES IN SCHEMA demo_ai_summit_databricks.enriched TO `demo_users`;
GRANT SELECT ON ALL TABLES IN SCHEMA demo_ai_summit_databricks.gold TO `demo_users`;

-- Grant Vector Search access to service principal
GRANT EXECUTE ON VECTOR SEARCH INDEX documents_search_index TO `app_service_principal`;
```

### Row-Level Security (Optional)

If you want to demonstrate row-level security in Genie:

```sql
-- Create dynamic view with row filtering
CREATE OR REPLACE VIEW demo_ai_summit_databricks.gold.sales_fact_secure AS
SELECT *
FROM demo_ai_summit_databricks.enriched.sales_fact
WHERE region_id IN (
  SELECT region_id
  FROM demo_ai_summit_databricks.raw.dim_region
  WHERE territory = current_user_territory()  -- UDF that maps user → territory
);
```

---

## Next Steps

1. **Customize for Your Use Case:**
   - Replace synthetic data with your own data
   - Modify Genie semantic layer for your schema
   - Add custom agent tools (REST APIs, Python UDFs)

2. **Extend to Production:**
   - Add CI/CD pipeline (GitHub Actions + Databricks CLI)
   - Implement monitoring (Databricks Observability)
   - Add alerting (PagerDuty, Slack)

3. **Share with Team:**
   - Export notebooks as HTML for documentation
   - Create video walkthroughs (record app demos)
   - Package as Databricks Asset Bundle for distribution

---

## Support

**Questions or Issues?**
- Open a GitHub issue: [link to repo]
- Email: your-team@company.com
- Databricks Community Forum: https://community.databricks.com

**Databricks Documentation:**
- Unity Catalog: https://docs.databricks.com/unity-catalog/
- AI/BI Genie: https://docs.databricks.com/genie/
- Vector Search: https://docs.databricks.com/vector-search/
- Agent Framework: https://docs.databricks.com/agents/
- Databricks Apps: https://docs.databricks.com/apps/

---

**Version:** 1.0.0
**Last Updated:** 2026-02-15
**Maintained By:** Snowbrix Academy Team
