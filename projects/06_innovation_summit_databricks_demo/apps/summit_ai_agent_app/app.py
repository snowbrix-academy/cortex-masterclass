"""
==================================================================
  INNOVATION SUMMIT — STATION B: AI AGENT FRAMEWORK
  App: summit_ai_agent_app
  Purpose: "Autonomous Analyst" — multi-step investigation agent
  Deploy: Databricks Apps (Workspace → Apps → Create App)

  ARCHITECTURE:
  ├── UI: Streamlit (embedded in Databricks Apps)
  ├── Backend: Databricks AI Agent Framework
  ├── Tools: SQL execution, Python analysis
  └── Fallback: Replay mode (cached investigation)

  FEATURES:
  - Multi-step autonomous investigation
  - Real-time reasoning display (step-by-step)
  - Tools: SQL queries, data analysis
  - Fallback mode for demo reliability
==================================================================
"""

import streamlit as st
import pandas as pd
import json
import time
import os
from databricks.sdk import WorkspaceClient

# ─────────────────────────────────────────────
# 1. CONFIGURATION
# ─────────────────────────────────────────────

# Environment variables
CATALOG = os.getenv("CATALOG", "demo_ai_summit_databricks")
SQL_WAREHOUSE_ID = os.getenv("SQL_WAREHOUSE_ID", "")
AGENT_ENDPOINT = os.getenv("AGENT_ENDPOINT", "")  # If Agent Framework endpoint available

# Databricks Workspace Client
try:
    w = WorkspaceClient()
    IN_DATABRICKS = True
except Exception:
    w = None
    IN_DATABRICKS = False
    st.warning("⚠ Not running in Databricks environment. Using fallback mode.")

# Replay cache: Pre-recorded investigation for Q3 revenue drop
REPLAY_CACHE = {
    "investigate_q3_revenue": {
        "question": "Investigate why Q3 revenue dropped compared to Q2.",
        "steps": [
            {
                "step": 1,
                "total": 5,
                "label": "Querying sales_fact for Q2 vs Q3 revenue",
                "tool": "sql_exec",
                "detail": "Q2: $14.2M | Q3: $11.8M | Delta: -$2.4M (-17%)",
                "timing_seconds": 2.0,
                "sql": """
SELECT
  d.quarter,
  COUNT(s.order_id) as transactions,
  ROUND(SUM(s.amount), 2) as revenue
FROM demo_ai_summit_databricks.enriched.sales_fact s
JOIN demo_ai_summit_databricks.raw.dim_date d ON s.date_key = d.date_key
WHERE d.year = 2025 AND d.quarter IN (2, 3)
GROUP BY d.quarter
ORDER BY d.quarter
                """,
                "data": pd.DataFrame({
                    "quarter": [2, 3],
                    "transactions": [48000, 36000],
                    "revenue": [14200000, 11800000]
                })
            },
            {
                "step": 2,
                "total": 5,
                "label": "Breaking down by territory",
                "tool": "sql_exec",
                "detail": "EMEA dropped $1.6M, NA dropped $0.5M, APAC flat",
                "timing_seconds": 2.0,
                "sql": """
SELECT
  r.territory,
  SUM(CASE WHEN d.quarter = 2 THEN s.amount ELSE 0 END) as q2_revenue,
  SUM(CASE WHEN d.quarter = 3 THEN s.amount ELSE 0 END) as q3_revenue,
  SUM(CASE WHEN d.quarter = 3 THEN s.amount ELSE 0 END) -
  SUM(CASE WHEN d.quarter = 2 THEN s.amount ELSE 0 END) as delta
FROM demo_ai_summit_databricks.enriched.sales_fact s
JOIN demo_ai_summit_databricks.raw.dim_region r ON s.region_id = r.region_id
JOIN demo_ai_summit_databricks.raw.dim_date d ON s.date_key = d.date_key
WHERE d.year = 2025 AND d.quarter IN (2, 3)
GROUP BY r.territory
ORDER BY delta
                """,
                "data": pd.DataFrame({
                    "territory": ["EMEA", "LATAM", "NA", "APAC"],
                    "q2_revenue": [4260000, 2840000, 3550000, 3550000],
                    "q3_revenue": [2660000, 2500000, 3050000, 3590000],
                    "delta": [-1600000, -340000, -500000, 40000]
                })
            },
            {
                "step": 3,
                "total": 5,
                "label": "Checking campaign_fact for marketing changes",
                "tool": "sql_exec",
                "detail": "Two EMEA campaigns paused Jul-Aug (budget freeze)",
                "timing_seconds": 2.0,
                "sql": """
SELECT
  campaign_id,
  channel,
  territory,
  campaign_status,
  start_date,
  end_date
FROM demo_ai_summit_databricks.enriched.campaign_fact
WHERE campaign_status LIKE '%Paused%'
  AND territory = 'EMEA'
  AND start_date >= '2025-07-01'
                """,
                "data": pd.DataFrame({
                    "campaign_id": ["CMP-00234", "CMP-00891"],
                    "channel": ["Digital Ads", "Email"],
                    "territory": ["EMEA", "EMEA"],
                    "campaign_status": ["Paused — Budget Freeze", "Paused — Budget Freeze"],
                    "start_date": ["2025-07-01", "2025-08-01"],
                    "end_date": ["2025-07-31", "2025-08-31"]
                })
            },
            {
                "step": 4,
                "total": 5,
                "label": "Checking dim_customer for churn signals",
                "tool": "sql_exec",
                "detail": "EMEA enterprise churn rate spiked 3.2% to 7.1% in Q3",
                "timing_seconds": 2.0,
                "sql": """
SELECT
  region,
  segment,
  COUNT(*) as total_customers,
  SUM(CASE WHEN is_churned THEN 1 ELSE 0 END) as churned,
  ROUND(AVG(CASE WHEN is_churned THEN 1.0 ELSE 0.0 END) * 100, 2) as churn_rate_pct
FROM demo_ai_summit_databricks.raw.dim_customer
WHERE region = 'EMEA' AND segment = 'Enterprise'
GROUP BY region, segment
                """,
                "data": pd.DataFrame({
                    "region": ["EMEA"],
                    "segment": ["Enterprise"],
                    "total_customers": [1800],
                    "churned": [128],
                    "churn_rate_pct": [7.1]
                })
            },
            {
                "step": 5,
                "total": 5,
                "label": "Generating investigation summary",
                "tool": "reasoning",
                "detail": "Compiling root-cause analysis and recommendations...",
                "timing_seconds": 3.0,
                "data": None
            }
        ],
        "summary": {
            "root_cause": "Q3 revenue drop of $2.4M (-17%) driven by three factors:",
            "findings": [
                {
                    "title": "EMEA campaign pause (Jul-Aug budget freeze)",
                    "detail": "Two major digital campaigns paused due to budget freeze. Estimated pipeline impact: -$1.2M.",
                    "severity": "HIGH"
                },
                {
                    "title": "Enterprise customer churn spike in EMEA",
                    "detail": "128 enterprise accounts churned (churn rate 3.2% → 7.1%). Revenue impact: -$0.4M recurring.",
                    "severity": "HIGH"
                },
                {
                    "title": "NA seasonal dip (consistent with prior years)",
                    "detail": "North America showed a 5% seasonal decline, within the normal historical range. No action needed.",
                    "severity": "LOW"
                }
            ],
            "recommendations": [
                "Reinstate EMEA campaigns with adjusted targeting for Q4 recovery.",
                "Trigger retention workflow for remaining at-risk enterprise accounts.",
                "Schedule QBRs with top 10 EMEA enterprise accounts within 2 weeks."
            ]
        }
    }
}

# ─────────────────────────────────────────────
# 2. PAGE LAYOUT
# ─────────────────────────────────────────────

st.set_page_config(
    page_title="AI Agent — Autonomous Analyst",
    page_icon="🤖",
    layout="wide"
)

st.markdown("""
<style>
    .booth-header {
        padding: 0.5rem 1rem;
        background: linear-gradient(90deg, #FF6B35 0%, #D32F2F 100%);
        color: white;
        border-radius: 0.5rem;
        margin-bottom: 1rem;
        text-align: center;
    }
    .booth-header h1 { margin: 0; font-size: 1.8rem; }
    .booth-header p { margin: 0; font-size: 1rem; opacity: 0.9; }

    .step-container {
        border-left: 3px solid #FF9800;
        padding-left: 1rem;
        margin: 1rem 0;
    }
    .step-done { border-left-color: #4CAF50; }
    .step-active { border-left-color: #FF9800; }
    .step-pending { border-left-color: #9E9E9E; opacity: 0.6; }

    .summary-card {
        border: 2px solid #29B5E8;
        border-radius: 0.5rem;
        padding: 1.5rem;
        margin-top: 1.5rem;
        background-color: #E3F2FD;
    }
    .severity-high { color: #D32F2F; font-weight: bold; }
    .severity-low { color: #4CAF50; }
</style>
""", unsafe_allow_html=True)

st.markdown("""
<div class="booth-header">
    <h1>AI Agent — Autonomous Analyst</h1>
    <p>Ask a complex question. Watch the agent investigate step by step.</p>
</div>
""", unsafe_allow_html=True)

# ─────────────────────────────────────────────
# 3. SESSION STATE
# ─────────────────────────────────────────────

if "agent_mode" not in st.session_state:
    st.session_state.agent_mode = "replay"  # Default to replay (safe)

if "investigation_steps" not in st.session_state:
    st.session_state.investigation_steps = []

if "investigation_summary" not in st.session_state:
    st.session_state.investigation_summary = None

if "investigation_question" not in st.session_state:
    st.session_state.investigation_question = None

# ─────────────────────────────────────────────
# 4. AGENT FRAMEWORK INTEGRATION (Live Mode)
# ─────────────────────────────────────────────

def run_live_agent(question: str):
    """
    Run Databricks AI Agent Framework in live mode.

    Note: This requires an Agent Framework endpoint to be deployed.
    Placeholder implementation - adapt based on Databricks SDK version.
    """
    try:
        if not AGENT_ENDPOINT:
            raise Exception("AGENT_ENDPOINT not configured")

        # Placeholder for Agent Framework API call
        # Actual implementation depends on Databricks SDK version
        # Example structure:
        # response = w.serving_endpoints.query(
        #     name=AGENT_ENDPOINT,
        #     inputs={"question": question}
        # )

        raise Exception("Live agent mode not implemented. Use replay mode.")

    except Exception as e:
        return {
            "steps": [],
            "summary": None,
            "error": f"Live agent failed: {str(e)}. Switching to replay mode."
        }

# ─────────────────────────────────────────────
# 5. REPLAY ENGINE
# ─────────────────────────────────────────────

def run_replay(investigation_key: str = "investigate_q3_revenue"):
    """
    Step through a cached investigation with realistic timing.
    """
    cache = REPLAY_CACHE.get(investigation_key)
    if not cache:
        st.error(f"No cached investigation found for key: {investigation_key}")
        return

    steps = cache["steps"]
    summary = cache["summary"]

    # Create placeholder containers
    status_placeholder = st.empty()
    steps_container = st.container()

    # Step through each reasoning step
    for i, step in enumerate(steps):
        # Update status
        status_placeholder.markdown(
            f"**Agent Status:** 🤖 Reasoning (step {step['step']} of {step['total']})"
        )

        # Render all steps (show progress)
        with steps_container:
            render_steps(steps, current_index=i, completed_up_to=i-1)

        # Simulate processing time
        time.sleep(step["timing_seconds"])

    # All steps done
    status_placeholder.markdown("**Agent Status:** ✅ Investigation complete")

    # Final render with all steps completed
    with steps_container:
        render_steps(steps, current_index=len(steps), completed_up_to=len(steps)-1)

    # Show summary
    render_summary(summary)

    # Store in session state
    st.session_state.investigation_steps = steps
    st.session_state.investigation_summary = summary


def render_steps(steps: list, current_index: int, completed_up_to: int):
    """Render investigation steps with status indicators."""
    for i, step in enumerate(steps):
        # Determine step status
        if i <= completed_up_to:
            icon = "✅"
            css_class = "step-done"
        elif i == current_index:
            icon = "⏳"
            css_class = "step-active"
        else:
            icon = "⬜"
            css_class = "step-pending"

        # Render step
        st.markdown(f'<div class="step-container {css_class}">', unsafe_allow_html=True)

        col1, col2 = st.columns([0.05, 0.95])
        with col1:
            st.markdown(icon)
        with col2:
            st.markdown(f"**Step {step['step']}/{step['total']}:** {step['label']}")

            # Show detail if completed
            if i <= completed_up_to:
                st.caption(f"🔍 {step['detail']}")

                # Show SQL if available
                if step.get('sql'):
                    with st.expander("📜 View SQL"):
                        st.code(step['sql'], language='sql')

                # Show data if available
                if step.get('data') is not None and isinstance(step['data'], pd.DataFrame):
                    st.dataframe(step['data'], use_container_width=True)

        st.markdown('</div>', unsafe_allow_html=True)


def render_summary(summary: dict):
    """Render investigation summary card."""
    st.markdown("---")
    st.markdown("### 🎯 Investigation Summary")

    st.markdown(f'<div class="summary-card">', unsafe_allow_html=True)

    st.markdown(f"**ROOT CAUSE:** {summary['root_cause']}")
    st.markdown("")

    st.markdown("**KEY FINDINGS:**")
    for i, finding in enumerate(summary["findings"], 1):
        severity_color = "🔴" if finding["severity"] == "HIGH" else "🟢"
        severity_class = "severity-high" if finding["severity"] == "HIGH" else "severity-low"

        st.markdown(f"{severity_color} **{i}. {finding['title']}**")
        st.markdown(f"   {finding['detail']}")
        st.markdown("")

    st.markdown("---")
    st.markdown("**RECOMMENDATIONS:**")
    for rec in summary["recommendations"]:
        st.markdown(f"- {rec}")

    st.markdown('</div>', unsafe_allow_html=True)

# ─────────────────────────────────────────────
# 6. UI COMPONENTS
# ─────────────────────────────────────────────

# Sidebar controls
with st.sidebar:
    st.markdown("### Demo Controls")

    # Reset button
    if st.button("Reset Investigation", use_container_width=True):
        st.session_state.investigation_steps = []
        st.session_state.investigation_summary = None
        st.session_state.investigation_question = None
        st.rerun()

    st.markdown("---")

    # Mode toggle
    mode = st.radio(
        "Agent Mode",
        options=["replay", "live"],
        index=0,
        format_func=lambda x: "Replay (cached)" if x == "replay" else "Live (Agent Framework)",
        help="Use 'Replay' for consistent demo. Use 'Live' if Agent endpoint is deployed."
    )
    st.session_state.agent_mode = mode

    if mode == "replay":
        st.info("📦 Replay mode: Steps through pre-recorded investigation with realistic timing (2s/step).")
    else:
        st.warning("⚡ Live mode: Requires Agent Framework endpoint. Falls back to replay if unavailable.")

    st.markdown("---")

    # Sample investigations
    st.markdown("### Sample Investigations")
    sample_prompts = [
        "Investigate why Q3 revenue dropped compared to Q2.",
        "What caused the EMEA performance decline?",
        "Analyze customer churn patterns in Q3 2025.",
    ]

    for i, prompt in enumerate(sample_prompts):
        if st.button(f"📊 Prompt {i+1}", key=f"prompt_{i}", use_container_width=True):
            st.session_state["prefill_investigation"] = prompt
            st.rerun()

# Main investigation area
if st.session_state.investigation_summary:
    # Show completed investigation
    st.markdown(f"**Question:** {st.session_state.investigation_question}")
    st.markdown("---")

    # Render all steps (completed state)
    render_steps(
        st.session_state.investigation_steps,
        current_index=len(st.session_state.investigation_steps),
        completed_up_to=len(st.session_state.investigation_steps)-1
    )

    # Render summary
    render_summary(st.session_state.investigation_summary)

else:
    # Waiting for input
    prefill = st.session_state.pop("prefill_investigation", "")
    user_input = st.text_input(
        "Ask the agent to investigate something...",
        value=prefill,
        placeholder="e.g., Investigate why Q3 revenue dropped",
        label_visibility="collapsed"
    )

    col1, col2 = st.columns([1, 5])
    with col1:
        send_clicked = st.button("🚀 Investigate", use_container_width=True)

    if send_clicked and user_input:
        st.session_state.investigation_question = user_input
        st.markdown(f"**Question:** {user_input}")
        st.markdown("---")

        if st.session_state.agent_mode == "replay":
            # Run replay mode
            run_replay("investigate_q3_revenue")
        else:
            # Try live mode, fall back to replay
            with st.spinner("Starting agent..."):
                result = run_live_agent(user_input)

            if result["error"]:
                st.warning(result["error"])
                st.info("Falling back to replay mode...")
                run_replay("investigate_q3_revenue")

# ─────────────────────────────────────────────
# 7. FOOTER
# ─────────────────────────────────────────────

st.markdown("---")
mode_label = "REPLAY" if st.session_state.agent_mode == "replay" else "LIVE"
st.caption(f"Powered by Databricks AI Agent Framework | Mode: {mode_label} | Catalog: {CATALOG}")
