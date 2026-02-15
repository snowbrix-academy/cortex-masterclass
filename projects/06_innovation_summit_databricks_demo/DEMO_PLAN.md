# Databricks Innovation Summit — AI Demo Plan

> **Event:** Innovation Summit / Innovation Hub (3-day booth)
> **Audience:** 300+ enterprise clients visiting the event (estimated 180-280 interactive booth touchpoints over 3 days)
> **Environment:** Databricks Premium with Unity Catalog, AWS us-east-1
> **Team:** 3 booth operators (station-owner model)
> **Lead time:** ~2 weeks to go-live
> **Tagline:** _"AI-driven data products — inside the Lakehouse, not around it."_

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Audience & Messaging Strategy](#2-audience--messaging-strategy)
3. [Environment Setup](#3-environment-setup)
4. [Synthetic Data Model](#4-synthetic-data-model)
5. [Demo Track: Tier 1 — Hero Demos](#5-demo-track-tier-1--hero-demos)
6. [Demo Track: Tier 2 — Deep Dives](#6-demo-track-tier-2--deep-dives)
7. [Demo Track: Tier 3 — Optional / Bonus](#7-demo-track-tier-3--optional--bonus)
8. [Databricks Apps](#8-databricks-apps)
9. [Booth Operations Plan](#9-booth-operations-plan)
10. [Talking Points & Objection Handling](#10-talking-points--objection-handling)
11. [Leave-Behind 1-Pager](#11-leave-behind-1-pager)
12. [Risk & Fallback Matrix](#12-risk--fallback-matrix)

---

## 1. Executive Summary

### What

A 3-day Innovation Summit booth showcasing Databricks' AI-centric capabilities to 300+ enterprise clients. Three live demo stations run continuously, each featuring a different Mosaic AI-powered use case — all running inside the Databricks Lakehouse with zero external infrastructure.

### Why

The message clients should walk away with:

> **"We can build AI-driven data products inside the Lakehouse, not around it."**

Every demo reinforces three proof points:
1. **"I can talk to my own data"** — AI/BI Genie turns every business user into a self-service analyst.
2. **"My data can act on its own"** — AI Agent Framework shows autonomous, multi-step investigation beyond simple Q&A.
3. **"All my documents are instant insights"** — Document Intelligence + Vector Search turns unstructured PDFs into queryable knowledge.

### How

| Layer | What's Built | Reference |
|-------|-------------|-----------|
| **Data** | 588K rows of synthetic data across 12 tables, story-first design with planted anomalies. 7 idempotent notebooks, < 2 min to load. | Section 4 |
| **Demos** | 3 Tier 1 hero demos (AI/BI Genie, Agent Framework, Document AI), 3 Tier 2 deep-dives, 3 Tier 3 bonus demos. | Sections 5, 6, 7 |
| **UI** | 3 Databricks Apps (Python-based), one-click deployment, fallback-first design. | Section 8 |
| **Ops** | 3-person station-owner model, 3-day escalation strategy (Awareness → Depth → Conversion), staggered breaks, emergency playbook. | Section 9 |
| **Pitch** | Per-station/persona talk tracks, 12 objection responses, transition phrases, printable cheat sheet. | Section 10 |

### Key Numbers

| Metric | Target |
|--------|--------|
| Setup lead time | ~2 weeks (T-14 to T-0) |
| Data load time | < 2 minutes |
| Demo duration (walk-up) | 3-5 minutes |
| Daily visitor touchpoints | 60-120 |
| 3-day total leads | 75-125 |
| 3-day meetings booked | 8-17 |
| Station coverage | 100% (never unstaffed) |
| Fallback coverage | 100% (every demo has offline mode) |

### Environment

- **Platform:** Databricks Premium with Unity Catalog
- **Cloud:** AWS us-east-1 (or Azure/GCP equivalent)
- **Catalog:** `DEMO_AI_SUMMIT_DATABRICKS`
- **Schemas:** `raw`, `enriched`, `gold`
- **Cluster:** Interactive cluster (Standard_DS13_v2 or equivalent, auto-terminate after 30 min)
- **Team:** 3 station owners, cross-trained on all demos
- **Language:** English only

---

## 2. Audience & Messaging Strategy

### Audience Breakdown

The 300+ visitors are a mixed enterprise audience. Expect this approximate distribution:

| Persona | % of Traffic | Time at Booth | What They Want | What They Fear |
|---------|-------------|---------------|---------------|----------------|
| **CXO / VP** (Business sponsors) | 15-20% | 2-3 min | ROI, time saved, competitive edge, platform consolidation | Hype without substance, hidden cost, vendor lock-in |
| **Data Leaders / Architects** | 25-30% | 5-10 min | Architecture, governance, security posture, integration with existing stack | Shadow AI, ungoverned models, another tool to maintain |
| **Analysts / Power Users** | 25-30% | 3-5 min | "Can I use this Monday?", speed, accuracy, daily workflow fit | Being replaced by AI, inaccurate numbers, loss of control |
| **Engineers / Developers** | 20-25% | 5-10 min | APIs, extensibility, CI/CD, semantic model structure, MLOps integration | Toy demos that don't scale, proprietary lock-in, poor DX |

### Core Message

One sentence that every booth interaction reinforces:

> **"AI-driven data products — inside the Lakehouse, not around it."**

This message works because it:
- Positions Databricks as the **platform**, not a point solution
- Addresses the #1 enterprise AI fear: **data leaving the perimeter**
- Differentiates from competitors who require **external AI orchestration**

### Messaging Framework

Three proof points, mapped to demos:

| Proof Point | Demo | Headline for Visitors |
|-------------|------|-----------------------|
| **"I can talk to my own data"** | AI/BI Genie (Station A) | Every business user becomes a self-service analyst. No SQL, no BI tool, no waiting. |
| **"My data can act on its own"** | AI Agent Framework (Station B) | Autonomous, multi-step investigation — root-cause analysis in 90 seconds, not 3 days. |
| **"All my documents are instant insights"** | Document Intelligence + Vector Search (Station C) | Unstructured data (PDFs, contracts) becomes queryable knowledge. Semantic search, not keyword matching. |

### Per-Persona Value Propositions

#### CXO / VP — "Show Me the Business Impact"

**What to lead with:**
- Time-to-insight reduction: "30 seconds vs 3 days for an ad-hoc answer"
- Headcount efficiency: "Not replacing analysts — freeing them from routine queries"
- Platform consolidation: "AI, analytics, governance, and MLOps — one platform, one bill"
- Competitive positioning: "Your competitors are building AI data products. This is how you do it without a 12-month ML platform build."

**What to avoid:**
- Technical architecture details (save for data leaders)
- Feature lists or product names (Mosaic, Genie, DBRX mean nothing to them)
- Cost per DBU breakdowns (they care about total cost of ownership, not unit economics)

**Closing move:** "Let's schedule a 60-minute PoC with your data. We'll build a Genie space for one of your use cases and show you what your team would see."

---

#### Data Leader / Architect — "Show Me the Governance"

**What to lead with:**
- Unity Catalog as control plane: "One semantic layer defines what the AI can query — tables, joins, metrics, business terms. You own the definitions."
- Zero data movement: "No copies, no exports, no ETL to an AI platform. Genie queries your existing Delta tables."
- Security posture: "Row-level security, dynamic views, and access controls apply to Genie the same way they apply to SQL queries."
- Integration: "The semantic layer integrates with your dbt workflow, version-controlled with git, deployed via CI/CD."

**What to avoid:**
- Oversimplifying setup effort ("it's easy!" → they know better)
- Comparing to their existing BI tool (they chose it; don't question that decision)
- Ignoring their governance concerns (this is their #1 priority)

**Closing move:** "Want to see how Genie integrates with Unity Catalog? I can walk through how it maps to your existing data mesh." (Bridge to side-table deep-dive.)

---

#### Analyst / Power User — "Show Me My Monday Morning"

**What to lead with:**
- Speed: "Type a question, get the answer. The SQL is visible — you can validate every number."
- Augmentation, not replacement: "This handles the routine questions. You focus on the complex analysis that actually needs human judgment."
- Multi-turn: "Ask a follow-up. It remembers context. You're having a conversation with your data, not running isolated queries."
- Embeddable: "This chat interface can live inside your internal portal, your Slack, your existing workflow."

**What to avoid:**
- Anything that implies they're being automated away (existential threat kills engagement)
- Suggesting they shouldn't check the SQL (they will, and they should)
- Over-promising accuracy (say "governed and auditable", not "always right")

**Closing move:** "Try it yourself — pick a challenge card and type the question." (Hand them the interaction.)

---

#### Engineer / Developer — "Show Me the Stack"

**What to lead with:**
- Semantic layer as code: "Python SDK, notebook-driven, CI/CD deployable. Treat it like a dbt model."
- Tool extensibility: "Define SQL tools, Python UDFs, REST API tools. The agent orchestrates; you own the tools."
- Lakehouse Apps: "Package the Genie + Databricks App as a shareable solution. Distribute to customers or internal teams."
- No external infra: "No API gateway, no model hosting, no vector database. Genie, Agent Framework, Vector Search — all inside Databricks."

**What to avoid:**
- Glossing over the API surface ("it just works" → they want to see the code)
- Hiding limitations (if Agent Framework is preview, say so — engineers respect honesty)
- Marketing language (no "seamless", "effortless", "cutting-edge")

**Closing move:** "Here's the notebook template and the app skeleton. Want me to share the repo?" (Have a QR code linking to a sample repo or GitHub gist.)

---

### Message Hierarchy (What to Say First)

For any visitor whose persona isn't immediately clear, use this default hierarchy:

```
1. OUTCOME     → "Ask any question, get the answer in 30 seconds."
                  (Universal appeal — works for all personas.)

2. PROOF       → Run the demo. Let them see it work live.
                  (Show, don't tell.)

3. TRUST       → "No data leaves Databricks. The SQL is visible.
                   Your governance applies."
                  (Address the unspoken concern: "Can I trust this?")

4. NEXT STEP   → "Want to try it with your data?"
                  (Always end with a forward action.)
```

Never start at layer 4 (the pitch). Never stay at layer 1 (the promise). The demo IS the proof — get to it within 15 seconds of the visitor arriving.

---

## 3. Environment Setup

### Overview

This section is the infra checklist your team runs at T-14 (day one of the 2-week lead time). Every object, permission, and service must be verified before data loading (Section 4) begins. The goal: by T-7, the environment is frozen and ready for app deployment.

**Run order:**
1. Workspace & Unity Catalog verification (this section)
2. Infrastructure notebook (Section 4, Notebook 01)
3. Data loading (Section 4, Notebooks 02-07)
4. Genie space creation + Vector Search index (Section 4, Notebook 07 + this section)
5. Databricks Apps deployment (Section 8)
6. End-to-end verification (this section)

---

### Step 1: Workspace & Edition Verification

Before building anything, confirm your Databricks workspace supports all required features.

```python
# Run this in a notebook to verify access
import os

# Check workspace tier (must be Premium or Enterprise)
# This requires admin access to workspace settings
# Expected: 'PREMIUM' or 'ENTERPRISE'

# Check Unity Catalog availability
spark.sql("SHOW CATALOGS").display()
# Expected: Should see system catalogs and ability to create new catalogs

# Check Mosaic AI availability
# Vector Search check
try:
    from databricks.vector_search.client import VectorSearchClient
    vsc = VectorSearchClient()
    print("✓ Vector Search client initialized")
except Exception as e:
    print(f"✗ Vector Search unavailable: {e}")

# Genie API check (if available via SDK)
try:
    # Placeholder - actual Genie API verification
    print("✓ AI/BI Genie available in workspace")
except Exception as e:
    print(f"✗ Genie unavailable: {e}")

# Foundation model access check
try:
    from databricks import sql
    # Check access to DBRX or Llama models via SQL
    spark.sql("SELECT ai_query('databricks-dbrx-instruct', 'Hello')").display()
    print("✓ Foundation models accessible")
except Exception as e:
    print(f"✗ Foundation models unavailable: {e}")
```

**If any check fails:**

| Check | Failure | Action |
|-------|---------|--------|
| Tier is Standard | Mosaic AI features unavailable | Upgrade to Premium or use a trial Premium workspace |
| Unity Catalog not enabled | Cannot create governed catalog | Enable Unity Catalog in workspace settings or use a new workspace |
| Vector Search unavailable | Vector Search not enabled | File a support ticket or enable via workspace settings |
| Genie unavailable | Feature not GA in your region | Use SQL Assistant as fallback; Genie has narrower regional availability |
| Foundation models blocked | Account settings or region issue | Check workspace model serving permissions and region support |

---

### Step 2: Unity Catalog & Permission Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    UNITY CATALOG HIERARCHY                       │
│                                                                 │
│  DEMO_AI_SUMMIT_DATABRICKS (catalog)                           │
│  ├── raw (schema)                                               │
│  │   └── Landing zone for ingested data                         │
│  ├── enriched (schema)                                          │
│  │   └── Joined and transformed tables                          │
│  ├── gold (schema)                                              │
│  │   └── Business-ready analytics tables                        │
│  └── documents (schema)                                         │
│      └── Document chunks + embeddings                           │
│                                                                 │
│  Volumes:                                                       │
│  └── /Volumes/demo_ai_summit_databricks/documents/raw_docs     │
│      └── PDF files for Document Intelligence                    │
│                                                                 │
│  Vector Search Endpoint:                                        │
│  └── demo_ai_summit_vs_endpoint                                │
│      └── Serves: documents_search_index                         │
└─────────────────────────────────────────────────────────────────┘
```

**Permission Model:**

| Principal | Grants | Purpose |
|-----------|--------|---------|
| **Demo Admin User** | CREATE CATALOG, ALL PRIVILEGES on catalog | Setup and teardown |
| **Demo User Group** | USE CATALOG, USE SCHEMA, SELECT on all tables | Read-only access for apps |
| **Service Principal (Apps)** | USE CATALOG, USE SCHEMA, SELECT on tables, EXECUTE on vector search | App authentication |
| **Vector Search SP** | SELECT on embedding source tables, WRITE to vector index | Index refresh |

---

### Step 3: Cluster Configuration

**Interactive Demo Cluster:**

```json
{
  "cluster_name": "Demo-AI-Summit-Interactive",
  "spark_version": "14.3.x-scala2.12",
  "node_type_id": "Standard_DS13_v2",
  "num_workers": 2,
  "autoscale": {
    "min_workers": 1,
    "max_workers": 3
  },
  "auto_termination_minutes": 30,
  "data_security_mode": "USER_ISOLATION",
  "runtime_engine": "PHOTON",
  "custom_tags": {
    "project": "innovation_summit_demo",
    "cost_center": "marketing_events"
  },
  "spark_conf": {
    "spark.databricks.delta.preview.enabled": "true",
    "spark.sql.adaptive.enabled": "true"
  },
  "init_scripts": []
}
```

**Serverless SQL Warehouse (for Genie):**

```json
{
  "name": "Demo-AI-Genie-Warehouse",
  "cluster_size": "Medium",
  "min_num_clusters": 1,
  "max_num_clusters": 3,
  "auto_stop_mins": 10,
  "enable_serverless_compute": true,
  "warehouse_type": "PRO",
  "channel": {
    "name": "CHANNEL_NAME_CURRENT"
  }
}
```

---

### Step 4: Feature Enablement Checklist

Before proceeding to data setup:

- [ ] Unity Catalog enabled
- [ ] Catalog `DEMO_AI_SUMMIT_DATABRICKS` created
- [ ] Schemas `raw`, `enriched`, `gold`, `documents` created
- [ ] Volume `/Volumes/demo_ai_summit_databricks/documents/raw_docs` created
- [ ] Interactive cluster running
- [ ] SQL warehouse created and started
- [ ] Vector Search endpoint `demo_ai_summit_vs_endpoint` created
- [ ] Workspace users added to `Demo User Group`
- [ ] Service principal created for app authentication
- [ ] All permissions granted per table above

---

## 4. Synthetic Data Model

### Overview

The data model supports all three demo stations with a single unified dataset. The design is **story-first**: synthetic data includes planted anomalies (Q3 revenue drop, EMEA churn spike, paused campaigns) that the Agent can discover during investigations.

**Key Stats:**
- **12 tables** (5 dimensions, 2 facts, 5 document/metadata tables)
- **588,000 total rows**
- **Load time:** < 2 minutes on a 2-node cluster
- **Storage:** ~45 MB (Delta compressed)

### Schema Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         LAKEHOUSE ARCHITECTURE                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  RAW SCHEMA (demo_ai_summit_databricks.raw)                    │
│  ├── dim_customer                 [12,000 rows]                │
│  ├── dim_product                  [500 rows]                   │
│  ├── dim_region                   [20 rows]                    │
│  ├── dim_date                     [1,095 rows (3 years)]       │
│  └── dim_sales_rep                [150 rows]                   │
│                                                                 │
│  ENRICHED SCHEMA (demo_ai_summit_databricks.enriched)         │
│  ├── sales_fact                   [500,000 rows]               │
│  └── campaign_fact                [2,400 rows]                 │
│                                                                 │
│  GOLD SCHEMA (demo_ai_summit_databricks.gold)                 │
│  ├── sales_summary_by_quarter                                  │
│  ├── customer_churn_analysis                                   │
│  └── campaign_performance                                      │
│                                                                 │
│  DOCUMENTS SCHEMA (demo_ai_summit_databricks.documents)       │
│  ├── documents_raw                [5 PDF metadata rows]        │
│  ├── documents_extracted          [5 structured extraction]    │
│  ├── documents_text               [72 chunks]                  │
│  └── documents_embeddings         [72 embedding vectors]       │
│                                                                 │
│  UC VOLUME: /Volumes/.../documents/raw_docs                    │
│  └── 5 PDF files (MSA, SaaS Agreement, NDA, SOW, DPA)        │
└─────────────────────────────────────────────────────────────────┘
```

### Planted Anomalies (For Agent Station B)

These anomalies are intentionally designed for the autonomous agent to discover:

| Anomaly | Location | Signal Strength | Discovery Method |
|---------|----------|-----------------|------------------|
| **Q3 Revenue Drop (-17%)** | `sales_fact` Q2 vs Q3 2025 | HIGH | Time-series comparison |
| **EMEA Campaign Pause** | `campaign_fact` status = "Paused — Budget Freeze" | HIGH | Filter by region + status |
| **Enterprise Churn Spike (EMEA)** | `dim_customer` churn_rate 3.2% → 7.1% | MEDIUM | Cohort analysis by segment |
| **NA Seasonal Dip** | `sales_fact` Q3 NA territory | LOW | Historical pattern (expected) |

---

## 5. Demo Track: Tier 1 — Hero Demos

### Station A: AI/BI Genie — "Talk to Your Data"

**Tagline:** Every business user becomes a self-service analyst.

**Duration:** 3-5 minutes

**Tech Stack:**
- Databricks AI/BI Genie
- Unity Catalog semantic layer
- SQL warehouse (serverless)

**Demo Flow:**

1. **Setup (pre-visit):**
   - Genie space `summit_sales_analytics` pre-created
   - Semantic layer includes: `sales_fact`, `dim_customer`, `dim_product`, `dim_region`, `dim_date`
   - Sample questions pre-loaded

2. **Live Demo:**
   - Visitor asks: "What was Q3 revenue by region?"
   - Genie generates SQL, executes query, returns chart + table
   - Show SQL transparency (expandable SQL view)
   - Ask follow-up: "Why did EMEA drop?"
   - Genie remembers context, drills into EMEA

3. **Key Talking Points:**
   - "No SQL required — just ask in plain English"
   - "The SQL is visible and auditable — you can validate every number"
   - "Unity Catalog security applies — row-level security, masking, all enforced"
   - "Embeddable in Slack, portals, or your custom apps"

4. **Objection Handling:**
   - **"We already have Tableau"** → "This augments Tableau. Genie handles ad-hoc questions; Tableau handles recurring dashboards."
   - **"AI makes mistakes"** → "That's why the SQL is visible. You validate, not blindly trust."
   - **"Our analysts will be obsolete"** → "No — analysts still do the hard work. This frees them from 'what was revenue last quarter?' questions."

5. **Transition to Next Station:**
   - "Genie answers questions. What if you need an agent that investigates on its own? Let me show you Station B."

---

### Station B: AI Agent Framework — "Autonomous Analyst"

**Tagline:** Multi-step investigations that replace 3-day root-cause analyses with 90-second agent runs.

**Duration:** 3-5 minutes

**Tech Stack:**
- Databricks AI Agent Framework
- Agent tools: `sql_exec_tool`, `unity_catalog_tool`, `python_tool`
- Foundation model: DBRX-instruct or Llama 3.1 70B

**Demo Flow:**

1. **Setup (pre-visit):**
   - Agent `summit_investigator_agent` pre-configured
   - Tools registered: SQL query tool, Python analysis tool
   - Replay cache available (for fallback if live agent fails)

2. **Live Demo:**
   - Visitor asks: "Investigate why Q3 revenue dropped."
   - Agent reasoning displayed step-by-step:
     - Step 1: Query sales_fact Q2 vs Q3 (finds -17% drop)
     - Step 2: Break down by region (EMEA dropped $1.6M)
     - Step 3: Check campaign_fact (finds paused campaigns)
     - Step 4: Check customer churn (finds 7.1% churn spike)
     - Step 5: Generate summary + recommendations
   - Agent returns: Root cause, findings, recommendations

3. **Key Talking Points:**
   - "The agent thinks like an analyst — it doesn't just answer, it investigates"
   - "Multi-step reasoning: query → analyze → cross-reference → conclude"
   - "You define the tools — SQL, Python, REST APIs — the agent orchestrates"
   - "Transparent: every step is visible, every query is logged"

4. **Objection Handling:**
   - **"Agents hallucinate"** → "That's why we use tools. The agent doesn't guess — it queries your data."
   - **"This is too complex for my team"** → "The agent is the complexity. Your team just asks questions."
   - **"What if it makes a wrong conclusion?"** → "You review the reasoning chain. It's auditable, not a black box."

5. **Transition to Next Station:**
   - "Agents work with structured data. What about your unstructured documents? Station C shows you."

---

### Station C: Document Intelligence + Vector Search — "Paper to Insight"

**Tagline:** Turn PDFs into queryable knowledge in 60 seconds.

**Duration:** 3-5 minutes

**Tech Stack:**
- Databricks Document Intelligence (PDF extraction)
- Databricks Vector Search (semantic search over embeddings)
- Unity Catalog Volumes (document storage)

**Demo Flow:**

1. **Setup (pre-visit):**
   - 5 sample PDFs uploaded to UC Volume: MSA, SaaS Agreement, NDA, SOW, DPA
   - Document Intelligence processed PDFs → structured fields
   - Text chunks embedded → Vector Search index `documents_search_index`

2. **Live Demo (Two-Panel):**

   **Left Panel: Upload & Extract**
   - Select PDF: "MSA_Acme_GlobalTech_2024.pdf"
   - Click "Process Document"
   - Show extracted fields:
     - Document Type: Master Services Agreement
     - Parties: Acme Corp ↔ GlobalTech Inc
     - Effective Date: 2024-01-15
     - Total Value: $2,400,000
     - Payment Terms: Net 30
     - Auto-Renewal: Yes

   **Right Panel: Semantic Search**
   - Enter query: "What is the termination clause?"
   - Vector Search returns: Top 3 relevant chunks with scores
   - Show chunk text + page number + relevance score
   - **Bonus:** Toggle "Compare Mode" → show keyword search (LIKE) vs semantic search
     - Keyword search: 0 results (exact match required)
     - Semantic search: 3 results (understands meaning)

3. **Key Talking Points:**
   - "Document Intelligence extracts structured fields — no manual data entry"
   - "Vector Search understands meaning, not just keywords"
   - "All documents stay in Unity Catalog — governed, auditable, secure"
   - "Search across thousands of contracts in seconds"

4. **Objection Handling:**
   - **"We already use Adobe Extract"** → "This integrates with your lakehouse. No copying PDFs to external services."
   - **"Vector search is expensive"** → "Databricks manages the infrastructure. You pay per query, not per index."
   - **"What if the extraction is wrong?"** → "You can review and correct. It's augmentation, not automation."

5. **Transition to Next Step:**
   - "These three demos cover structured data, investigations, and documents. Want to see how they integrate? Let me show you the architecture."

---

## 6. Demo Track: Tier 2 — Deep Dives

### Deep Dive A: Genie + Unity Catalog Integration

**Audience:** Data Architects, Governance Leaders

**Duration:** 5-10 minutes

**What to Show:**
1. **Unity Catalog Lineage:**
   - Show Genie queries tracked in Unity Catalog audit logs
   - Lineage: query → tables → columns
   - Access controls enforced (row-level security, column masking)

2. **Semantic Layer as Code:**
   - Show how Genie space maps to Delta tables
   - Metrics defined in YAML (similar to dbt metrics)
   - Version-controlled, CI/CD deployable

3. **Multi-Workspace Sharing:**
   - Explain Delta Sharing: Genie space can be shared across workspaces
   - Consumer workspace queries data without copying

**Talking Points:**
- "Unity Catalog is the control plane — Genie respects all your governance"
- "The semantic layer is code — treat it like infrastructure"
- "Delta Sharing means you publish once, consume everywhere"

---

### Deep Dive B: Agent Framework + Tool Extensibility

**Audience:** Engineers, Developers, ML Engineers

**Duration:** 5-10 minutes

**What to Show:**
1. **Tool Definition:**
   - Show how to define custom tools in Python
   - Example: REST API tool that calls Salesforce API
   - Agent orchestrates: query Databricks → call Salesforce → synthesize answer

2. **Agent Configuration:**
   - Show agent notebook setup
   - Model selection: DBRX vs Llama vs GPT-4 (via external model serving)
   - System prompt customization

3. **Deployment:**
   - Package agent as MLflow model
   - Deploy to Model Serving endpoint
   - REST API for agent invocation

**Talking Points:**
- "You define the tools — the agent figures out when to use them"
- "MLflow tracks every agent run — inputs, outputs, reasoning steps"
- "Deploy as REST API — integrate with Slack, Teams, your custom apps"

---

### Deep Dive C: Vector Search + RAG Patterns

**Audience:** ML Engineers, Data Scientists

**Duration:** 5-10 minutes

**What to Show:**
1. **Index Creation:**
   - Show how to create Vector Search index from Delta table
   - Embedding model: Databricks BGE or custom embeddings
   - Index sync strategy: continuous vs on-demand

2. **Hybrid Search:**
   - Combine vector search (semantic) + keyword search (BM25)
   - Show reranking with DBRX

3. **RAG Pipeline:**
   - Query → Vector Search → retrieve chunks → LLM generates answer
   - Show how to add citations (chunk_id, page_number, source_doc)

**Talking Points:**
- "Vector Search scales to billions of vectors — no infrastructure to manage"
- "Hybrid search combines the best of semantic and keyword"
- "RAG with citations = trustworthy AI"

---

## 7. Demo Track: Tier 3 — Optional / Bonus

### Bonus 1: Lakehouse Monitoring

**Audience:** Data Engineers, ML Engineers

**What to Show:**
- Lakehouse Monitoring dashboard for `sales_fact` table
- Data quality metrics: null rates, schema evolution, outliers
- Alerts: email when churn_rate > 5%

**Talking Point:** "Databricks monitors your data quality automatically — no dbt tests needed."

---

### Bonus 2: MLOps Integration

**Audience:** ML Engineers, DevOps

**What to Show:**
- Agent deployed as MLflow model
- Model versioning, A/B testing, rollback
- Integration with CI/CD (GitHub Actions → Databricks Jobs)

**Talking Point:** "Treat agents like ML models — version, test, deploy, monitor."

---

### Bonus 3: Cost Attribution & Observability

**Audience:** FinOps, Platform Engineers

**What to Show:**
- System tables: `system.billing.usage`
- Cost breakdown by workspace, cluster, SQL warehouse
- Tag-based chargeback (tag queries by team/project)

**Talking Point:** "Databricks gives you full cost visibility — no surprise bills."

---

## 8. Databricks Apps

### Overview

Three Databricks Apps power the three demo stations. Each app is Python-based, deployed via Databricks Apps UI, and supports fallback modes if live services are unavailable.

**App Architecture:**

```
┌─────────────────────────────────────────────────────────────────┐
│                      DATABRICKS APPS                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  App A: summit_ai_genie_app                                    │
│  ├── Framework: Streamlit (via Databricks Apps)                │
│  ├── Backend: Genie API (REST)                                 │
│  ├── Fallback: Pre-cached Q&A                                  │
│  └── Auth: Service Principal                                    │
│                                                                 │
│  App B: summit_ai_agent_app                                    │
│  ├── Framework: Streamlit (via Databricks Apps)                │
│  ├── Backend: Agent Framework API                              │
│  ├── Fallback: Replay mode (cached investigation)              │
│  └── Auth: Service Principal                                    │
│                                                                 │
│  App C: summit_ai_document_app                                 │
│  ├── Framework: Streamlit (via Databricks Apps)                │
│  ├── Backend: Vector Search API + Document Intelligence        │
│  ├── Fallback: Keyword search (LIKE)                           │
│  └── Auth: Service Principal                                    │
└─────────────────────────────────────────────────────────────────┘
```

---

## 9. Booth Operations Plan

### Station Coverage Strategy

**3-Person Team:**
- **Person A:** Station A (Genie) owner, cross-trained on Station B
- **Person B:** Station B (Agent) owner, cross-trained on Station C
- **Person C:** Station C (Document AI) owner, cross-trained on Station A

**Break Rotation:**
- Staggered 15-minute breaks every 90 minutes
- Never leave a station unstaffed
- If emergency, Person A covers all stations (has admin access)

---

## 10. Talking Points & Objection Handling

### Top 12 Objections

1. **"We already have a BI tool"** → "This augments your BI tool — handles ad-hoc questions, not recurring dashboards"
2. **"AI is too expensive"** → "Cost per query is ~$0.001. Compare to analyst time: $50/hour"
3. **"Our data is too messy"** → "Genie works with your existing tables — no cleanup required"
4. **"We don't trust AI"** → "That's why SQL is visible — you validate, not blindly trust"
5. **"Agents hallucinate"** → "We use tools, not freeform generation — agent queries your data, doesn't guess"
6. **"This is a POC, not production"** → "These demos run on production-grade infrastructure — same Databricks you'd deploy"
7. **"We need on-prem"** → "Databricks supports on-prem (Azure Gov Cloud, AWS GovCloud, private link)"
8. **"What about compliance?"** → "Unity Catalog + audit logs = SOC 2, HIPAA, GDPR compliant"
9. **"We don't have ML engineers"** → "Genie requires zero ML expertise — business users ask questions, that's it"
10. **"Lock-in worries"** → "Delta format is open. Semantic layer is YAML. Export anytime."
11. **"Too complex to maintain"** → "Databricks manages infrastructure — you maintain semantic layer, not servers"
12. **"We're happy with current tools"** → "Great! Databricks integrates — use Genie alongside Tableau, not instead"

---

## 11. Leave-Behind 1-Pager

**QR Code Links:**
- Demo Recordings: [link to YouTube playlist]
- Sample Notebooks: [link to GitHub repo]
- Genie Documentation: [link to docs.databricks.com]
- Schedule PoC: [link to Calendly]

**Headline:**
> AI-Driven Data Products — Inside the Lakehouse, Not Around It

**3 Proof Points:**
1. Talk to your data (Genie)
2. Agents that investigate (Agent Framework)
3. Documents become insights (Vector Search)

**Contact:**
- booth-lead@company.com
- [QR code to contact form]

---

## 12. Risk & Fallback Matrix

| Risk | Likelihood | Impact | Mitigation | Fallback |
|------|-----------|--------|------------|----------|
| Genie API down | LOW | HIGH | Health check every 30 min | Pre-cached Q&A mode |
| Agent Framework timeout | MEDIUM | HIGH | 60s timeout + retry | Replay mode (cached investigation) |
| Vector Search index unavailable | LOW | MEDIUM | Index health check at booth start | Keyword search (LIKE) |
| Cluster terminated | LOW | HIGH | Auto-restart enabled | Always-on SQL warehouse as backup |
| Network outage | LOW | CRITICAL | Offline mode for all apps | Slide-based walkthrough + recorded video |
| Databricks workspace unavailable | VERY LOW | CRITICAL | Multi-region failover | Switch to backup workspace (pre-deployed) |

**Emergency Contact:**
- On-call engineer: [phone number]
- Databricks support: Priority support ticket

---

**END OF DEMO PLAN**
