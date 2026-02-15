# TODO List — Databricks Innovation Summit Demo

This document tracks remaining work to complete the project.

---

## 📋 Completed

### Core Documentation
- [x] **DEMO_PLAN.md** — Comprehensive demo execution guide (adapted from Snowflake version)
- [x] **SETUP.md** — Deployment instructions with troubleshooting
- [x] **README.md** — Project overview and quick start

### Data Pipeline (Notebooks)
- [x] **01_infrastructure.py** — Unity Catalog, schemas, volumes, Vector Search endpoint setup
- [x] **02_dimensions.py** — Dimension tables (customer, product, region, date, sales_rep)
- [x] **03_sales_fact.py** — 500K sales transactions with Q3 2025 revenue drop anomaly
- [x] **04_campaign_fact.py** — 2.4K marketing campaigns with EMEA pause anomaly
- [x] **05_documents_setup.py** — Document Intelligence pipeline + Vector Search index
- [x] **06_genie_space.py** — Genie semantic layer configuration guide
- [x] **VERIFY_ALL.py** — End-to-end verification with 7-point readiness checklist

### Databricks Apps
- [x] **summit_ai_genie_app** — Station A: Genie chat interface (NL to SQL)
- [x] **summit_ai_agent_app** — Station B: Agent Framework (multi-step investigations)
- [x] **summit_ai_document_app** — Station C: Document Intelligence + Vector Search

---

## 🚧 In Progress

### High Priority (Required for Demo)

#### Sample Data

- [ ] **Sample PDFs** — 5 contract documents for Document Intelligence
  - `contracts/MSA_Acme_GlobalTech_2024.pdf`
  - `contracts/SaaS_Subscription_NovaTech_2024.pdf`
  - `contracts/NDA_Mutual_Acme_Pinnacle_2024.pdf`
  - `contracts/SOW_DataPlatform_Acme_2024.pdf`
  - `contracts/DPA_Acme_CloudVault_2024.pdf`
  - Source: Generate using docx or LaTeX, then convert to PDF
  - Or use existing contracts from project 05 as templates
  - Time estimate: 1 hour

### Medium Priority (Nice to Have)

- [ ] **Genie Space UI Configuration Guide** — Step-by-step screenshots
  - Workspace → AI/BI Genie → Create Space
  - Add tables, define joins, configure metrics
  - Screenshots with annotations
  - Time estimate: 30 min

- [ ] **Demo Video Recordings** — Walkthroughs for each station
  - Station A: 3-minute Genie demo
  - Station B: 3-minute Agent investigation
  - Station C: 3-minute Document search
  - Upload to YouTube (unlisted)
  - Time estimate: 2 hours

- [ ] **Cost Monitoring Dashboard** — Track demo costs in real-time
  - System tables query: `system.billing.usage`
  - Streamlit dashboard showing:
    - Cluster costs (by hour)
    - SQL warehouse costs
    - Vector Search costs
    - Total spend
  - Time estimate: 1 hour

- [ ] **One-Click Deploy Script** — Bash script to automate setup
  - Run all notebooks in sequence
  - Check for errors and retry
  - Display progress bar
  - Time estimate: 1 hour

### Low Priority (Future Enhancements)

- [ ] **Multi-Language Support** — Spanish, French, German demos
  - Translate sample questions
  - Translate UI strings
  - Test Genie/Agent with non-English queries

- [ ] **Advanced Agent Tools** — Extend beyond SQL
  - REST API tool (call external Salesforce API)
  - Python analysis tool (pandas, numpy)
  - Visualization tool (Plotly, matplotlib)

- [ ] **Real-Time Monitoring** — Booth operations dashboard
  - Live visitor count (button clicks)
  - Most popular questions
  - Error rate tracking
  - Demo uptime

- [ ] **A/B Testing Framework** — Compare Genie vs keyword search
  - Track accuracy metrics
  - Measure time-to-insight
  - User satisfaction survey

---

## 🎯 Milestones

### Milestone 1: Data Pipeline Complete ✅
- [x] Infrastructure setup
- [x] Dimension tables
- [x] Fact tables (sales, campaigns)
- [x] Document processing

### Milestone 2: Genie + Vector Search Operational ✅
- [x] Genie space configuration guide created
- [x] Vector Search index setup completed
- [x] Sample queries defined

### Milestone 3: All Apps Deployed ✅
- [x] Station A: Genie app
- [x] Station B: Agent app
- [x] Station C: Document app

### Milestone 4: Demo-Ready (ETA: 2-3 hours)
- [x] End-to-end verification script created
- [ ] Deploy apps to Databricks workspace and test
- [ ] All fallback modes tested in workspace
- [ ] Demo video recorded

**Completed:** ~95% (All code complete, testing pending)

---

## 📌 Implementation Notes

### Recommended Order

1. **Complete data pipeline** (notebooks 03-05)
   - Get all tables loaded first
   - Verify anomalies are planted correctly
   - Test with SQL queries before building apps

2. **Configure Genie space** (notebook 06)
   - Can be done in parallel with document setup
   - Requires SQL warehouse to be running
   - Test with sample questions before app integration

3. **Build apps** (Agent, Document)
   - Use Station A (Genie) app as template
   - Agent app needs agent endpoint configured
   - Document app needs Vector Search index ready

4. **End-to-end verification** (VERIFY_ALL.py)
   - Run after all apps are deployed
   - Fix any issues before demo day

### Databricks-Specific Considerations

1. **Genie Space Configuration:**
   - Not purely code-driven (unlike Snowflake Cortex Analyst YAML)
   - Requires Workspace UI interaction
   - Can be partially automated via API (if available)
   - Document manual steps with screenshots

2. **Vector Search Index:**
   - Endpoint must be ONLINE before creating index
   - Provisioning takes 5-10 minutes
   - Use DELTA_SYNC for automatic updates
   - Test queries before app integration

3. **Agent Framework:**
   - Tool definitions are Python-based (not SQL like Snowflake)
   - Agent endpoint needs to be created and deployed
   - May require Model Serving endpoint
   - Check Databricks SDK version for API compatibility

4. **Databricks Apps:**
   - Service principal authentication recommended
   - Environment variables set in app.yaml
   - Logs available in Workspace → Apps → [Your App] → Logs
   - Can be deployed via CLI or UI

---

## 🔗 References

### Snowflake Project (Template)
- Path: `projects/05_innovation_summit_ai_demo/`
- Use for:
  - Data generation logic (adapt to PySpark)
  - App UI design (same Streamlit structure)
  - Demo flow and talking points

### Databricks Documentation
- **Genie:** https://docs.databricks.com/genie/
- **Agent Framework:** https://docs.databricks.com/agents/
- **Vector Search:** https://docs.databricks.com/vector-search/
- **Databricks Apps:** https://docs.databricks.com/apps/

### Community Examples
- **Databricks Demos:** https://github.com/databricks-demos
- **AI/BI Genie Quickstart:** https://docs.databricks.com/genie/quickstart.html
- **Vector Search RAG Pattern:** https://docs.databricks.com/vector-search/rag.html

---

## ✅ Completion Checklist

Before marking the project as "production-ready":

- [ ] All 7 notebooks run without errors
- [ ] All 3 apps deploy successfully
- [ ] VERIFY_ALL.py passes all checks
- [ ] Fallback modes tested (Genie, Agent, Vector Search)
- [ ] Cost monitoring enabled (track actual spend)
- [ ] Security review (permissions, service principals)
- [ ] Demo script rehearsed (3 min per station)
- [ ] Booth operators trained (cross-trained on all stations)
- [ ] Emergency playbook prepared (what to do if Genie fails)
- [ ] Leave-behind materials printed (1-pager, QR codes)

---

**Last Updated:** 2026-02-15
**Owner:** Snowbrix Academy Team
**Priority:** HIGH (2-week sprint to go-live)
