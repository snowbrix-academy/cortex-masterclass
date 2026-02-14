# Snowflake Cortex Masterclass: Build Production AI Data Apps

> **Production-Grade Data Engineering. No Fluff.**

Learn to build AI-powered data applications using Snowflake Cortex (Analyst, Agent, Document AI).
This course reverse-engineers a real Innovation Summit booth demo into 10 hands-on modules.

[![Course Status](https://img.shields.io/badge/Status-In%20Development-yellow)](https://github.com/snowbrix-academy/cortex-masterclass)
[![Launch](https://img.shields.io/badge/Launch-Week%201%20(Feb%202026)-blue)](https://github.com/snowbrix-academy/cortex-masterclass)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

---

## 🎯 What You'll Build

By completing this course, you'll deploy:
- **Cortex Analyst app** — Natural language to SQL (semantic YAML, REST API)
- **Data Agent** — Multi-step root cause analysis (autonomous tool orchestration)
- **Document AI + RAG pipeline** — PDF extraction + semantic search
- **Unified dashboard** — Integrate all 3 apps into production-ready portfolio project

**Portfolio outcome:** Shareable Snowflake Native App deployed to your trial account (show recruiters, hiring managers).

---

## 📚 Course Structure (10 Modules, ~12 Hours)

| Module | Title | Duration | Deliverables |
|--------|-------|----------|--------------|
| **M1** | Set Up Your Snowflake AI Workspace | 45 min | Verified environment + quiz |
| **M2** | Deploy Your First Cortex Analyst App | 60 min | Working Analyst app + quiz + PR |
| **M3** | Build a Data Agent for Root Cause Analysis | 75 min | Working Agent app + quiz + PR |
| **M4** | Add Multi-Step Investigation Tools | 60 min | Extended agent + quiz + PR |
| **M5** | Deploy Document AI with Cortex Search | 90 min | Doc AI app + quiz + PR |
| **M6** | Build a RAG Pipeline for Customer Support | 75 min | RAG app + quiz + PR |
| **M7** | Integrate All Three Apps into One Dashboard | 60 min | Unified dashboard + quiz + PR |
| **M8** | Handle Production Patterns: Errors & Retries | 60 min | Hardened apps + quiz + PR |
| **M9** | Optimize Cost, Governance & Scale | 75 min | Cost dashboard + quiz + PR |
| **M10** | Build Your Capstone Portfolio Project | 90 min | Portfolio app + presentation + PR |

**Total:** 11.5 hours of hands-on learning

---

## 📖 Course Materials

### Current Status: Week 0 (Pre-Launch Development)

✅ **COURSE_DEVELOPMENT_PLAN.md** — Complete blueprint (115K+ words, 10 sections)
- Executive Summary
- 10-Module Curriculum Breakdown
- Data Progression Strategy (3→5→7→12 tables)
- Lab Design & Assessment Framework
- Video Production Workflow (NotebookLM + OBS + Camtasia)
- GitHub Repository & Automation
- Materials Creation Checklist (95 hours over 6 weeks)
- Corporate B2B Customization Package (₹2L-₹4L tiers)
- Marketing & Launch Strategy
- Production Timeline (Week 0-6)

### Coming Soon (Week 1-5):

⏳ **SQL Scripts** — Idempotent data setup scripts (12 tables, 588K rows)
⏳ **Streamlit Apps** — 3 production apps (Analyst, Agent, Document AI)
⏳ **Semantic Models** — YAML for Cortex Analyst (5→7→12 table progression)
⏳ **Lab Materials** — 10 lab READMEs (guided + open-ended challenges)
⏳ **Video Tutorials** — 10 modules (10-15 min each, YouTube)

---

## 🚀 Launch Timeline

| Week | Status | Deliverables |
|------|--------|--------------|
| **Week 0 (Feb 13-19)** | ✅ In Progress | Repository setup, course plan, landing page |
| **Week 1 (Feb 20-26)** | 🔜 Coming Soon | M1-M2 launch, early bird enrollment (₹4,999) |
| **Week 2-5** | 🔜 Planned | M3-M10 rollout (2 modules/week) |
| **Week 6+** | 🔜 Planned | Post-launch support, corporate B2B outreach |

**Launch Date:** Week 1 Wednesday (Feb 20, 2026)
**Early Bird:** ₹4,999 for first 50 students (₹2,000 savings)

---

## 🎓 Target Audience

**Primary:** Junior/mid data engineers (1-3 years), analysts, Snowflake/dbt users
**Geography:** India-focus (Bengaluru, Tier 2/3 cities)
**Prerequisites:**
- Basic SQL knowledge (SELECT, JOIN, WHERE)
- Snowflake trial account (free 30-day)
- GitHub account (free)

---

## 💼 Corporate Training

**Custom B2B packages available:**
- **₹2,00,000** (5-10 people) — Template customization + 1-day consulting
- **₹3,00,000** (11-20 people) — Above + on-site PoC deployment
- **₹4,00,000** (21-50 people) — Above + multi-team governance setup

**Industries:** FMCG/CPG, Finance, Healthcare, Telecom
**Delivery:** Hybrid (self-paced + 1-day live workshop)
**Contact:** [Email TBD]

---

## 📁 Repository Structure (Planned)

```
cortex-masterclass/
├── README.md                          # This file
├── COURSE_DEVELOPMENT_PLAN.md         # Complete blueprint (115K+ words)
├── LICENSE                            # MIT License
├── .gitignore                         # Exclude .env, node_modules, __pycache__
├── .github/
│   └── workflows/
│       └── lab-checks.yml             # CI/CD (sqlfluff, black, yamllint, row counts)
│
├── sql_scripts/                       # Reusable SQL (from Innovation Summit booth)
│   ├── 01_infrastructure.sql
│   ├── 02_dimensions.sql
│   ├── 03_sales_fact.sql
│   ├── 05_agent_tables.sql
│   ├── 06_document_ai.sql
│   ├── 07_cortex_search.sql
│   ├── RUN_ALL_SCRIPTS.sql
│   └── VERIFY_ALL.sql
│
├── streamlit_apps/                    # Reusable Streamlit apps
│   ├── app_cortex_analyst.py
│   ├── app_data_agent.py
│   └── app_document_ai.py
│
├── semantic_models/                   # Semantic YAML for Cortex Analyst
│   └── cortex_analyst_demo.yaml
│
├── slides/                            # Course presentation slides
│   └── Innovation_Summit_AI_Demo.pptx
│
├── docs/                              # Course documentation
│   ├── setup_guide.md                 # Snowflake trial, GitHub fork, setup
│   ├── troubleshooting.md             # Common errors + fixes
│   └── interview_prep.md              # 50 Cortex interview Q&A
│
├── labs/                              # Student lab submissions
│   ├── module_01/
│   │   ├── README.md                  # Lab instructions (Part A + Part B)
│   │   └── .gitkeep
│   ├── module_02/
│   └── ... (module_03 through module_10)
│
└── scripts/                           # Automation scripts
    ├── verify_row_counts.py
    ├── check_pr_template.py
    └── run_all_checks.sh
```

---

## 🤝 Contributing

**Students:** Fork this repo, complete labs, submit PRs to your own fork (not upstream).

**Instructors/Contributors:** Found a bug or want to improve content?
1. Fork this repo
2. Create feature branch: `git checkout -b fix-yaml-docs`
3. Commit changes: `git commit -m "Fix YAML indentation example"`
4. Push: `git push origin fix-yaml-docs`
5. Create PR to `snowbrix-academy/cortex-masterclass`

---

## 📝 License

MIT License — free to use, modify, distribute. See [LICENSE](LICENSE) (coming soon).

**Attribution:** Original booth demo from Snowflake Innovation Summit 2026.
Course created by [Snowbrix Academy](https://github.com/snowbrix-academy).

---

## 🆘 Support

- **Course Plan:** [COURSE_DEVELOPMENT_PLAN.md](COURSE_DEVELOPMENT_PLAN.md)
- **Issues:** [GitHub Issues](https://github.com/snowbrix-academy/cortex-masterclass/issues)
- **Discussions:** [GitHub Discussions](https://github.com/snowbrix-academy/cortex-masterclass/discussions)

---

## 📊 Course Metrics (Target)

| Metric | Month 1 | Month 3 | Month 6 |
|--------|---------|---------|---------|
| **Students enrolled** | 150 | 500 | 800 |
| **Revenue (self-paced)** | ₹10.5L | ₹35L | ₹56L |
| **Corporate clients** | 0 | 3 | 10 |
| **B2B revenue** | ₹0 | ₹6L | ₹20L |
| **Total revenue** | ₹10.5L | ₹41L | ₹76L |

---

## 🎬 Course Development Journey

**Phase:** Pre-Launch (Week 0)
**Status:** Repository created, course plan complete, materials in development
**Next Milestone:** Week 1 launch (M1-M2 live, early bird enrollment opens)

**Watch this space!** Course materials will be added progressively Week 1-5.

---

## 🏆 What Makes This Course Different?

✅ **Reverse-engineered from real booth demo** (Innovation Summit 2026, 300+ attendees)
✅ **Production patterns from Day 1** (not toy demos — deploy to Snowflake, handle errors, optimize costs)
✅ **Portfolio-ready projects** (3 apps: Analyst, Agent, Document AI — show recruiters)
✅ **Progressive data complexity** (3→5→7→12 tables with planted anomalies for root cause analysis)
✅ **Interview prep integrated** (2-3 questions per module, 50+ total with answers)
✅ **Corporate B2B ready** (₹2L-₹4L customization packages for FMCG, Finance, Healthcare, Telecom)

---

**Ready to build AI data apps in Snowflake?** Star this repo and watch for Week 1 launch! ⭐

**"Production-Grade Data Engineering. No Fluff."** — Snowbrix Academy
