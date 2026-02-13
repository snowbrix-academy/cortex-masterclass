"""
==================================================================
  DEMO AI SUMMIT — STATION A: CORTEX ANALYST
  App: app_cortex_analyst.py
  Purpose: "Talk to Your Data" — NL-to-SQL chat interface
  Deploy: Streamlit in Snowflake (Snowsight → Streamlit → + Streamlit App)

  STRUCTURE:
  1. Imports & Session
  2. Configuration
  3. Page Layout
  4. Session State
  5. Cortex Analyst Integration
  6. Chat UI
  7. Reset & Fallback
==================================================================
"""

# ─────────────────────────────────────────────
# 1. IMPORTS & SESSION
# ─────────────────────────────────────────────
import streamlit as st
import json
import time
from snowflake.snowpark.context import get_active_session

# _snowflake is available inside Streamlit in Snowflake
# It provides send_snow_api_request() for Cortex Analyst communication
import _snowflake

# Cortex Analyst REST API endpoint
API_ENDPOINT = "/api/v2/cortex/analyst/message"
API_TIMEOUT = 50000  # milliseconds

session = get_active_session()

# ─────────────────────────────────────────────
# 2. CONFIGURATION
# ─────────────────────────────────────────────
# Semantic model location — update stage path if different
SEMANTIC_MODEL_FILE = "@DEMO_AI_SUMMIT.CORTEX_ANALYST_DEMO.SEMANTIC_MODELS/cortex_analyst_demo.yaml"

# Database context for queries
DATABASE = "DEMO_AI_SUMMIT"
SCHEMA = "CORTEX_ANALYST_DEMO"

# Fallback: cached responses for when Cortex Analyst is unavailable
FALLBACK_MODE = False  # Set to True to use cached responses

# Pre-built responses for fallback mode (matches visitor challenge cards)
CACHED_RESPONSES = {
    "total sales last quarter": {
        "summary": "Total sales last quarter (Q3 2025) were $11.8M, down from $14.2M in Q2 2025 — a 17% decline driven primarily by EMEA region underperformance.",
        "sql": "SELECT SUM(amount) AS total_sales FROM SALES_FACT sf JOIN DIM_DATE dd ON sf.order_date = dd.date_key WHERE dd.year = 2025 AND dd.quarter = 3;",
        "data": [{"TOTAL_SALES": 11800000}]
    },
    "regions underperformed": {
        "summary": "EMEA and LATAM missed Q4 targets by 12% and 8% respectively. APAC exceeded target by 6%. North America was flat.",
        "sql": """SELECT r.territory, SUM(CASE WHEN d.quarter = 2 THEN s.amount END) AS q2_rev,
SUM(CASE WHEN d.quarter = 3 THEN s.amount END) AS q3_rev,
ROUND((q3_rev - q2_rev) / q2_rev * 100, 1) AS pct_change
FROM SALES_FACT s JOIN DIM_REGION r ON s.region_id = r.region_id
JOIN DIM_DATE d ON s.order_date = d.date_key
WHERE d.year = 2025 AND d.quarter IN (2,3) GROUP BY r.territory ORDER BY pct_change;""",
        "data": [
            {"TERRITORY": "EMEA", "Q2_REV": 4260000, "Q3_REV": 3536000, "PCT_CHANGE": -17.0},
            {"TERRITORY": "LATAM", "Q2_REV": 2840000, "Q3_REV": 2499000, "PCT_CHANGE": -12.0},
            {"TERRITORY": "NA", "Q2_REV": 3550000, "Q3_REV": 3266000, "PCT_CHANGE": -8.0},
            {"TERRITORY": "APAC", "Q2_REV": 3550000, "Q3_REV": 3763000, "PCT_CHANGE": 6.0}
        ]
    },
    "highest return rate": {
        "summary": "Electronics has the highest return rate at 14.2%, significantly above the company average of 4.8%. All other categories fall between 2.8% and 4.5%.",
        "sql": """SELECT p.category, COUNT(*) AS total_orders,
SUM(CASE WHEN s.is_returned THEN 1 ELSE 0 END) AS returns,
ROUND(returns / total_orders * 100, 1) AS return_rate_pct
FROM SALES_FACT s JOIN DIM_PRODUCT p ON s.product_id = p.product_id
GROUP BY p.category ORDER BY return_rate_pct DESC;""",
        "data": [
            {"CATEGORY": "Electronics", "TOTAL_ORDERS": 83000, "RETURNS": 11786, "RETURN_RATE_PCT": 14.2},
            {"CATEGORY": "Apparel", "TOTAL_ORDERS": 83000, "RETURNS": 3735, "RETURN_RATE_PCT": 4.5},
            {"CATEGORY": "Health & Beauty", "TOTAL_ORDERS": 83000, "RETURNS": 3154, "RETURN_RATE_PCT": 3.8},
            {"CATEGORY": "Home & Kitchen", "TOTAL_ORDERS": 84000, "RETURNS": 2940, "RETURN_RATE_PCT": 3.5},
            {"CATEGORY": "Office Supplies", "TOTAL_ORDERS": 84000, "RETURNS": 2604, "RETURN_RATE_PCT": 3.1},
            {"CATEGORY": "Sports", "TOTAL_ORDERS": 83000, "RETURNS": 2324, "RETURN_RATE_PCT": 2.8}
        ]
    }
}

# ─────────────────────────────────────────────
# 3. PAGE LAYOUT
# ─────────────────────────────────────────────
st.set_page_config(
    page_title="Cortex Analyst — Talk to Your Data",
    page_icon="🔍",
    layout="wide"
)

# Custom CSS for booth presentation (large fonts, dark theme friendly)
st.markdown("""
<style>
    /* Larger chat text for booth visibility */
    .stChatMessage {
        font-size: 1.1rem;
    }
    /* Subtle branding bar */
    .booth-header {
        padding: 0.5rem 1rem;
        background: linear-gradient(90deg, #29B5E8 0%, #0D47A1 100%);
        color: white;
        border-radius: 0.5rem;
        margin-bottom: 1rem;
        text-align: center;
    }
    .booth-header h1 {
        margin: 0;
        font-size: 1.8rem;
    }
    .booth-header p {
        margin: 0;
        font-size: 1rem;
        opacity: 0.9;
    }
</style>
""", unsafe_allow_html=True)

# Header
st.markdown("""
<div class="booth-header">
    <h1>Cortex Analyst — Talk to Your Data</h1>
    <p>Ask any question about sales, products, regions, or campaigns in plain English</p>
</div>
""", unsafe_allow_html=True)

# ─────────────────────────────────────────────
# 4. SESSION STATE
# ─────────────────────────────────────────────
if "messages" not in st.session_state:
    st.session_state.messages = []

if "analyst_active" not in st.session_state:
    st.session_state.analyst_active = True

# ─────────────────────────────────────────────
# 5. CORTEX ANALYST INTEGRATION
# ─────────────────────────────────────────────

def send_to_cortex_analyst(user_question: str) -> dict:
    """
    Send a question to Cortex Analyst and return structured response.

    Returns dict with keys:
        - summary (str): Natural language answer
        - sql (str): Generated SQL
        - data (list[dict]): Query results
        - error (str|None): Error message if failed
    """
    if FALLBACK_MODE:
        return _get_cached_response(user_question)

    try:
        # Build message payload for Cortex Analyst API
        # st.session_state.messages already includes the current question
        # (appended before this function is called), so just convert all of them.
        # Cortex Analyst expects roles: "user" and "analyst" (not "assistant")
        prompt_messages = []
        for m in st.session_state.messages:
            role = "user" if m["role"] == "user" else "analyst"
            prompt_messages.append({
                "role": role,
                "content": [{"type": "text", "text": m["content"]}]
            })

        # Send via _snowflake REST API bridge (official SiS method)
        request_body = {
            "messages": prompt_messages,
            "semantic_model_file": SEMANTIC_MODEL_FILE
        }

        resp = _snowflake.send_snow_api_request(
            "POST",         # method
            API_ENDPOINT,   # path
            {},             # headers
            {},             # params
            request_body,   # body
            None,           # request_guid
            API_TIMEOUT,    # timeout in milliseconds
        )

        resp_json = json.loads(resp["content"])

        # Check for API error
        if resp["status"] >= 400:
            error_msg = resp_json.get("message", f"API error {resp['status']}")
            raise Exception(error_msg)

        # Parse response — Cortex Analyst returns structured content
        result = {
            "summary": "",
            "sql": "",
            "data": [],
            "error": None
        }

        # Extract content blocks from response
        if "message" in resp_json and "content" in resp_json["message"]:
            for block in resp_json["message"]["content"]:
                if block.get("type") == "text":
                    result["summary"] += block.get("text", "")
                elif block.get("type") == "sql":
                    result["sql"] = block.get("statement", "")
                    # Execute the generated SQL to get data
                    try:
                        df = session.sql(block["statement"]).to_pandas()
                        result["data"] = df.to_dict("records")
                    except Exception as sql_err:
                        result["error"] = f"SQL execution failed: {str(sql_err)}"

        return result

    except Exception as e:
        return {
            "summary": "",
            "sql": "",
            "data": [],
            "error": f"Cortex Analyst error: {str(e)}"
        }


def _get_cached_response(question: str) -> dict:
    """
    Match question against cached responses using keyword overlap.
    Used in fallback mode or when Cortex Analyst is unavailable.
    """
    question_lower = question.lower()
    best_match = None
    best_score = 0

    for key, response in CACHED_RESPONSES.items():
        # Simple keyword matching
        keywords = key.split()
        score = sum(1 for kw in keywords if kw in question_lower)
        if score > best_score:
            best_score = score
            best_match = response

    if best_match and best_score > 0:
        return {
            "summary": best_match["summary"],
            "sql": best_match["sql"],
            "data": best_match["data"],
            "error": None
        }

    return {
        "summary": "I don't have a cached response for this question. Please try one of the challenge card questions.",
        "sql": "",
        "data": [],
        "error": None
    }


# ─────────────────────────────────────────────
# 6. CHAT UI
# ─────────────────────────────────────────────

# Sidebar: Semantic model info + controls
with st.sidebar:
    st.markdown("### Demo Controls")

    # Reset button (station owner uses between visitors)
    if st.button("Reset Demo", use_container_width=True):
        st.session_state.messages = []
        st.session_state["fallback_mode"] = False
        st.experimental_rerun()

    st.markdown("---")

    # Fallback toggle (station owner uses if Cortex Analyst goes down)
    fallback_on = st.checkbox("Fallback Mode (cached responses)", value=False)
    st.session_state["fallback_mode"] = fallback_on

    st.markdown("---")

    st.markdown("### Semantic Model")
    st.markdown(f"**File:** `cortex_analyst_demo.yaml`")
    st.markdown("**Tables:** SALES_FACT, DIM_PRODUCT, DIM_REGION, DIM_DATE, DIM_SALES_REP, CAMPAIGN_FACT, CUSTOMER_DIM")
    st.markdown("**Metrics:** total_revenue, avg_discount, return_rate, yoy_growth")

    st.markdown("---")

    # Challenge cards (visible prompt for visitors)
    st.markdown("### Visitor Challenge Cards")
    challenge_questions = [
        "What were total sales last quarter?",
        "Which product category has the highest return rate?",
        "Compare marketing spend vs revenue by region for Q3 and Q4.",
        "Which sales rep closed the most deals above $50K in the last 6 months?",
        "What's the correlation between discount percentage and customer churn?"
    ]
    for i, q in enumerate(challenge_questions, 1):
        if st.button(f"Card {i}", key=f"card_{i}", use_container_width=True):
            st.session_state["prefill_question"] = q
            st.experimental_rerun()

# Display chat history
for msg in st.session_state.messages:
    role_prefix = "**You:**" if msg["role"] == "user" else "**Analyst:**"
    st.markdown(f"{role_prefix} {msg['content']}")

    # Show SQL and data for assistant messages
    if msg["role"] == "assistant" and "sql" in msg:
        if msg["sql"]:
            with st.expander("Show Generated SQL"):
                st.code(msg["sql"], language="sql")
        if msg.get("data"):
            import pandas as pd
            df = pd.DataFrame(msg["data"])
            st.dataframe(df, use_container_width=True)

            # Auto-chart if data has numeric columns
            numeric_cols = df.select_dtypes(include=["number"]).columns.tolist()
            if len(numeric_cols) >= 1 and len(df) > 1:
                non_numeric = [c for c in df.columns if c not in numeric_cols]
                if non_numeric:
                    st.bar_chart(df.set_index(non_numeric[0])[numeric_cols[:2]])

# Chat input
prefill = st.session_state.pop("prefill_question", None)
user_input = st.text_input("Ask anything about your sales data...", value=prefill or "", key="chat_text_input")
send_clicked = st.button("Send", use_container_width=True)

# Use prefill if a challenge card was clicked, or send button was pressed
question = user_input if (send_clicked and user_input) else None

if question:
    # Display user message
    st.session_state.messages.append({"role": "user", "content": question})
    st.markdown(f"**You:** {question}")

    # Get response from Cortex Analyst
    # Read fallback mode directly from session state (set by checkbox in sidebar)
    use_fallback = st.session_state.get("fallback_mode", False)
    with st.spinner("Analyzing..."):
        if use_fallback:
            result = _get_cached_response(question)
        else:
            result = send_to_cortex_analyst(question)

    # Display summary
    if result["error"] and not result["summary"]:
        st.error(result["error"])
    else:
        st.markdown(f"**Analyst:** {result['summary']}")

        if result.get("error"):
            st.caption(result["error"])

        # Show SQL
        if result["sql"]:
            with st.expander("Show Generated SQL"):
                st.code(result["sql"], language="sql")

        # Show data
        if result["data"]:
            import pandas as pd
            df = pd.DataFrame(result["data"])
            st.dataframe(df, use_container_width=True)

            # Auto-chart
            numeric_cols = df.select_dtypes(include=["number"]).columns.tolist()
            if len(numeric_cols) >= 1 and len(df) > 1:
                non_numeric = [c for c in df.columns if c not in numeric_cols]
                if non_numeric:
                    st.bar_chart(df.set_index(non_numeric[0])[numeric_cols[:2]])

    # Store in session state for history
    st.session_state.messages.append({
        "role": "assistant",
        "content": result["summary"],
        "sql": result.get("sql", ""),
        "data": result.get("data", [])
    })

# ─────────────────────────────────────────────
# 7. FOOTER
# ─────────────────────────────────────────────
st.markdown("---")
st.caption("Powered by Snowflake Cortex Analyst | Semantic model: cortex_analyst_demo.yaml | No data leaves Snowflake")
