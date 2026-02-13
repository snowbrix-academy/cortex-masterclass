"""
==================================================================
  DEMO AI SUMMIT — STATION B: DATA AGENT
  App: app_data_agent.py
  Purpose: "Autonomous Analyst" — multi-step investigation agent
  Deploy: Streamlit in Snowflake (Snowsight → Streamlit → + Streamlit App)

  IMPORTANT: Cortex Agent GA status may be uncertain. This app
  supports TWO modes:
    - LIVE MODE: Calls Cortex Agent API for real-time reasoning
    - REPLAY MODE: Steps through cached investigation with
      realistic timing (2s/step, 3s summary fade-in)

  Station owner toggles between modes via sidebar.

  STRUCTURE:
  1. Imports & Session
  2. Configuration & Replay Cache
  3. Page Layout
  4. Session State
  5. Live Agent Integration
  6. Replay Engine
  7. Investigation UI
  8. Reset & Controls
==================================================================
"""

# ─────────────────────────────────────────────
# 1. IMPORTS & SESSION
# ─────────────────────────────────────────────
import streamlit as st
import json
import time
from snowflake.snowpark.context import get_active_session

session = get_active_session()

# Conditional import — _snowflake only available inside SiS
try:
    import _snowflake
    IN_SNOWFLAKE = True
except ImportError:
    IN_SNOWFLAKE = False

# ─────────────────────────────────────────────
# 2. CONFIGURATION & REPLAY CACHE
# ─────────────────────────────────────────────

# Semantic model — shared with Station A (Cortex Analyst)
SEMANTIC_MODEL_FILE = "@DEMO_AI_SUMMIT.CORTEX_ANALYST_DEMO.SEMANTIC_MODELS/cortex_analyst_demo.yaml"

# Cortex Agent REST API
AGENT_API_ENDPOINT = "/api/v2/cortex/agent:run"
AGENT_API_TIMEOUT = 60000  # milliseconds

# Agent tool definitions (Cortex Agent API format)
AGENT_TOOLS = [
    {
        "name": "analyst",
        "tool_spec": {
            "type": "cortex_analyst_text2sql_tool",
            "semantic_model_file": SEMANTIC_MODEL_FILE
        }
    },
    {
        "name": "sql_exec",
        "tool_spec": {
            "type": "sql_exec_tool",
            "warehouse": "DEMO_AI_WH"
        }
    }
]

# Replay cache: pre-recorded investigation for fallback
# Each step has: label, detail, timing (seconds), data (optional)
REPLAY_CACHE = {
    "investigate_q3_revenue": {
        "question": "Investigate why Q3 revenue dropped compared to Q2.",
        "steps": [
            {
                "step": 1,
                "total": 5,
                "label": "Querying SALES_FACT for Q2 vs Q3 revenue",
                "tool": "cortex_analyst_tool",
                "detail": "Q2: $14.2M | Q3: $11.8M | Delta: -$2.4M (-17%)",
                "timing_seconds": 2.0,
                "data": [
                    {"QUARTER": "Q2 2025", "REVENUE": 14200000},
                    {"QUARTER": "Q3 2025", "REVENUE": 11800000}
                ]
            },
            {
                "step": 2,
                "total": 5,
                "label": "Breaking down by region",
                "tool": "cortex_analyst_tool",
                "detail": "EMEA dropped $1.6M, NA dropped $0.5M, APAC flat",
                "timing_seconds": 2.0,
                "data": [
                    {"TERRITORY": "EMEA", "Q2_REV": 4260000, "Q3_REV": 2660000, "DELTA": -1600000},
                    {"TERRITORY": "NA", "Q2_REV": 3550000, "Q3_REV": 3050000, "DELTA": -500000},
                    {"TERRITORY": "APAC", "Q2_REV": 3550000, "Q3_REV": 3590000, "DELTA": 40000},
                    {"TERRITORY": "LATAM", "Q2_REV": 2840000, "Q3_REV": 2500000, "DELTA": -340000}
                ]
            },
            {
                "step": 3,
                "total": 5,
                "label": "Checking CAMPAIGN_FACT for marketing changes",
                "tool": "sql_exec",
                "detail": "Two EMEA campaigns paused Jul-Aug (budget freeze)",
                "timing_seconds": 2.0,
                "data": [
                    {"CAMPAIGN": "CMP-00234", "REGION": "EMEA", "STATUS": "Paused — Budget Freeze", "PERIOD": "Jul 2025"},
                    {"CAMPAIGN": "CMP-00891", "REGION": "EMEA", "STATUS": "Paused — Budget Freeze", "PERIOD": "Aug 2025"}
                ]
            },
            {
                "step": 4,
                "total": 5,
                "label": "Checking CUSTOMER_DIM for churn signals",
                "tool": "sql_exec",
                "detail": "EMEA enterprise churn rate spiked 3.2% to 7.1% in Q3",
                "timing_seconds": 2.0,
                "data": [
                    {"TERRITORY": "EMEA", "SEGMENT": "Enterprise", "PRIOR_CHURN": "3.2%", "Q3_CHURN": "7.1%", "ACCOUNTS_LOST": 4}
                ]
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
                    "detail": "4 enterprise accounts churned (churn rate 3.2% → 7.1%). Revenue impact: -$0.4M recurring.",
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
# 3. PAGE LAYOUT
# ─────────────────────────────────────────────
st.set_page_config(
    page_title="Data Agent — Autonomous Analyst",
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

    /* Step status indicators */
    .step-done { color: #4CAF50; font-weight: bold; }
    .step-active { color: #FF9800; font-weight: bold; }
    .step-pending { color: #9E9E9E; }

    /* Summary card */
    .summary-card {
        border: 2px solid #29B5E8;
        border-radius: 0.5rem;
        padding: 1rem;
        margin-top: 1rem;
    }
    .severity-high { color: #D32F2F; font-weight: bold; }
    .severity-low { color: #4CAF50; }
</style>
""", unsafe_allow_html=True)

st.markdown("""
<div class="booth-header">
    <h1>Data Agent — Autonomous Analyst</h1>
    <p>Ask a complex question. Watch the agent investigate step by step.</p>
</div>
""", unsafe_allow_html=True)

# ─────────────────────────────────────────────
# 4. SESSION STATE
# ─────────────────────────────────────────────
if "agent_mode" not in st.session_state:
    st.session_state.agent_mode = "replay"  # Default to replay (safe)

if "investigation_steps" not in st.session_state:
    st.session_state.investigation_steps = []

if "investigation_summary" not in st.session_state:
    st.session_state.investigation_summary = None

if "investigation_running" not in st.session_state:
    st.session_state.investigation_running = False

if "current_step" not in st.session_state:
    st.session_state.current_step = 0

# ─────────────────────────────────────────────
# 5. LIVE AGENT INTEGRATION
# ─────────────────────────────────────────────

def run_live_agent(question: str):
    """
    Run Cortex Agent in live mode via REST API.
    Streams reasoning steps back to the UI.

    If the API is not available, it will fall back to replay mode.
    """
    try:
        request_body = {
            "model": "llama3.1-70b",
            "messages": [
                {
                    "role": "user",
                    "content": [{"type": "text", "text": question}]
                }
            ],
            "tools": AGENT_TOOLS
        }

        resp = _snowflake.send_snow_api_request(
            "POST",
            AGENT_API_ENDPOINT,
            {},
            {},
            request_body,
            None,
            AGENT_API_TIMEOUT,
        )

        resp_json = json.loads(resp["content"])

        if resp["status"] >= 400:
            error_msg = resp_json.get("message", f"API error {resp['status']}")
            raise Exception(error_msg)

        # Parse agent response into steps
        steps = []
        summary = None

        if "message" in resp_json and "content" in resp_json["message"]:
            for block in resp_json["message"]["content"]:
                if block.get("type") == "tool_results":
                    # Agent tool call result
                    step_data = {
                        "step": len(steps) + 1,
                        "total": "?",
                        "label": block.get("tool_name", "Analyzing..."),
                        "tool": block.get("tool_name", ""),
                        "detail": "",
                        "data": None
                    }
                    # Try to extract SQL results
                    tool_content = block.get("content", [])
                    for tc in tool_content:
                        if tc.get("type") == "sql":
                            try:
                                df = session.sql(tc["statement"]).to_pandas()
                                step_data["data"] = df.to_dict("records")
                                step_data["detail"] = f"Returned {len(df)} rows"
                            except Exception:
                                step_data["detail"] = "Query executed"
                        elif tc.get("type") == "text":
                            step_data["detail"] = tc.get("text", "")
                    steps.append(step_data)

                elif block.get("type") == "text":
                    summary = block.get("text", "")

        # Update total count on all steps
        for s in steps:
            s["total"] = len(steps)

        return {"steps": steps, "summary": summary, "error": None}

    except Exception as e:
        return {
            "steps": [],
            "summary": None,
            "error": f"Live agent failed: {str(e)}. Switching to replay mode."
        }


# ─────────────────────────────────────────────
# 6. REPLAY ENGINE
# ─────────────────────────────────────────────

def run_replay(investigation_key: str = "investigate_q3_revenue"):
    """
    Step through a cached investigation with realistic timing.
    Timing: 2s per analysis step, 3s for summary generation.
    Uses st.empty() containers for real-time step updates.
    """
    cache = REPLAY_CACHE.get(investigation_key)
    if not cache:
        st.error(f"No cached investigation found for key: {investigation_key}")
        return

    steps = cache["steps"]
    summary = cache["summary"]

    # Status display area
    status_area = st.empty()
    steps_area = st.container()
    summary_area = st.empty()

    # Step through each reasoning step
    completed_steps = []

    for i, step in enumerate(steps):
        # Update status
        status_area.markdown(
            f"**Agent Status:** Reasoning (step {step['step']} of {step['total']})"
        )

        # Render all steps (completed + current + pending)
        with steps_area:
            _render_steps_progress(steps, current_index=i, completed=completed_steps)

        # Simulate processing time
        time.sleep(step["timing_seconds"])

        # Mark step as completed
        completed_steps.append(i)

    # All steps done — show final state
    status_area.markdown("**Agent Status:** Investigation complete")

    with steps_area:
        _render_steps_progress(steps, current_index=len(steps), completed=completed_steps)

    # Fade in summary (3s is built into last step timing)
    _render_summary(summary)

    # Store in session state
    st.session_state.investigation_steps = steps
    st.session_state.investigation_summary = summary


def _render_steps_progress(steps: list, current_index: int, completed: list):
    """Render the reasoning chain with step status indicators."""
    # Clear and re-render
    for i, step in enumerate(steps):
        if i in completed:
            icon = "✅"
            detail_text = step["detail"]
        elif i == current_index:
            icon = "⏳"
            detail_text = "Processing..."
        else:
            icon = "⬜"
            detail_text = ""

        col1, col2 = st.columns([0.05, 0.95])
        with col1:
            st.markdown(icon)
        with col2:
            st.markdown(f"**Step {step['step']}/{step['total']}:** {step['label']}")
            if detail_text:
                st.caption(detail_text)

            # Show data table for completed steps
            if i in completed and step.get("data"):
                import pandas as pd
                df = pd.DataFrame(step["data"])
                st.dataframe(df, use_container_width=True)


def _render_summary(summary: dict):
    """Render the investigation summary card."""
    st.markdown("---")
    st.markdown("### Investigation Summary")

    st.markdown(f"**ROOT CAUSE:** {summary['root_cause']}")

    for i, finding in enumerate(summary["findings"], 1):
        severity_color = "🔴" if finding["severity"] == "HIGH" else "🟢"
        st.markdown(f"{severity_color} **{i}. {finding['title']}**")
        st.markdown(f"   {finding['detail']}")

    st.markdown("---")
    st.markdown("**RECOMMENDATIONS:**")
    for rec in summary["recommendations"]:
        st.markdown(f"- {rec}")


# ─────────────────────────────────────────────
# 7. INVESTIGATION UI
# ─────────────────────────────────────────────

# Sidebar controls
with st.sidebar:
    st.markdown("### Demo Controls")

    # Reset
    if st.button("Reset Demo", use_container_width=True):
        st.session_state.investigation_steps = []
        st.session_state.investigation_summary = None
        st.session_state.investigation_running = False
        st.session_state.current_step = 0
        st.experimental_rerun()

    st.markdown("---")

    # Mode toggle
    mode = st.radio(
        "Agent Mode",
        options=["replay", "live"],
        index=0,
        format_func=lambda x: "Replay (cached)" if x == "replay" else "Live (Cortex Agent)",
        help="Use 'Replay' if Cortex Agent is unavailable. Use 'Live' for real-time agent."
    )
    st.session_state.agent_mode = mode

    if mode == "replay":
        st.info("Replay mode: Steps through a pre-recorded investigation with realistic timing (2s/step).")
    else:
        st.warning("Live mode: Requires Cortex Agent GA access. Falls back to replay if unavailable.")

    st.markdown("---")

    # Pre-built investigation prompts
    st.markdown("### Sample Investigations")
    prompts = [
        "Investigate why Q3 revenue dropped compared to Q2.",
        "What caused the EMEA performance decline?",
        "Analyze customer churn patterns in Q3.",
    ]
    for i, p in enumerate(prompts):
        if st.button(f"Prompt {i+1}", key=f"prompt_{i}", use_container_width=True):
            st.session_state["prefill_investigation"] = p
            st.experimental_rerun()

# Main investigation area
if st.session_state.investigation_summary:
    # Show completed investigation
    st.markdown(f"**Question:** {st.session_state.get('investigation_question', '')}")
    st.markdown("---")

    # Render completed steps
    for step in st.session_state.investigation_steps:
        col1, col2 = st.columns([0.05, 0.95])
        with col1:
            st.markdown("✅")
        with col2:
            st.markdown(f"**Step {step['step']}/{step['total']}:** {step['label']}")
            st.caption(step["detail"])
            if step.get("data"):
                import pandas as pd
                st.dataframe(pd.DataFrame(step["data"]), use_container_width=True)

    _render_summary(st.session_state.investigation_summary)

else:
    # Waiting for input
    prefill = st.session_state.pop("prefill_investigation", None)
    user_input = st.text_input("Ask the agent to investigate something...", value=prefill or "", key="agent_text_input")
    send_clicked = st.button("Send", use_container_width=True)

    question = user_input if (send_clicked and user_input) else None

    if question:
        st.session_state["investigation_question"] = question
        st.markdown(f"**Question:** {question}")
        st.markdown("---")

        if st.session_state.agent_mode == "replay":
            # Run replay mode
            run_replay("investigate_q3_revenue")
            # Store summary in session state for re-render
            cache = REPLAY_CACHE["investigate_q3_revenue"]
            st.session_state.investigation_steps = cache["steps"]
            st.session_state.investigation_summary = cache["summary"]
        else:
            # Try live mode, fall back to replay
            with st.spinner("Starting agent..."):
                result = run_live_agent(question)

            if result["error"]:
                st.warning(result["error"])
                st.info("Falling back to replay mode...")
                run_replay("investigate_q3_revenue")
                cache = REPLAY_CACHE["investigate_q3_revenue"]
                st.session_state.investigation_steps = cache["steps"]
                st.session_state.investigation_summary = cache["summary"]
            else:
                # Display live results
                for step in result["steps"]:
                    st.markdown(f"✅ **Step {step['step']}:** {step['label']}")
                    if step.get("detail"):
                        st.caption(step["detail"])
                    if step.get("data"):
                        import pandas as pd
                        st.dataframe(pd.DataFrame(step["data"]), use_container_width=True)

                if result["summary"]:
                    st.markdown("---")
                    st.markdown("### Investigation Summary")
                    st.markdown(result["summary"])

# ─────────────────────────────────────────────
# 8. FOOTER
# ─────────────────────────────────────────────
st.markdown("---")
mode_label = "REPLAY" if st.session_state.agent_mode == "replay" else "LIVE"
st.caption(f"Powered by Snowflake Cortex Agent | Mode: {mode_label} | Semantic model: cortex_analyst_demo.yaml")
