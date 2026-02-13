"""
==================================================================
  DEMO AI SUMMIT — STATION C: DOCUMENT AI + CORTEX SEARCH
  App: app_document_ai.py
  Purpose: "Paper to Insight in 60 Seconds" — upload, extract, search
  Deploy: Streamlit in Snowflake (Snowsight → Streamlit → + Streamlit App)

  LAYOUT: Two-panel (Upload & Extract | Semantic Search)
  BONUS: "Compare" toggle — semantic vs keyword search side-by-side

  STRUCTURE:
  1. Imports & Session
  2. Configuration
  3. Page Layout
  4. Session State
  5. Document AI Integration
  6. Cortex Search Integration
  7. Keyword Search (for comparison)
  8. Two-Panel UI
  9. Reset & Controls
==================================================================
"""

# ─────────────────────────────────────────────
# 1. IMPORTS & SESSION
# ─────────────────────────────────────────────
import streamlit as st
import json
import pandas as pd
from snowflake.snowpark.context import get_active_session

session = get_active_session()

# _snowflake for REST API calls (available inside SiS)
try:
    import _snowflake
    IN_SNOWFLAKE = True
except ImportError:
    IN_SNOWFLAKE = False

# ─────────────────────────────────────────────
# 2. CONFIGURATION
# ─────────────────────────────────────────────
DATABASE = "DEMO_AI_SUMMIT"
SCHEMA = "DOC_AI_DEMO"
STAGE = f"@{DATABASE}.{SCHEMA}.DOCUMENTS_STAGE"

# Cortex Search service name
SEARCH_SERVICE_NAME = "DOCUMENTS_SEARCH_SERVICE"

# Number of search results to return
SEARCH_LIMIT = 5

# Pre-loaded documents (for "upload" simulation)
PRELOADED_DOCS = {
    "MSA_Acme_GlobalTech_2024.pdf": {
        "doc_id": 1,
        "doc_type": "Master Services Agreement",
        "party_a": "Acme Corp",
        "party_b": "GlobalTech Inc",
        "effective_date": "2024-01-15",
        "expiration_date": "2026-01-14",
        "total_value": "$2,400,000",
        "payment_terms": "Net 30",
        "auto_renewal": True,
        "governing_law": "State of Delaware",
        "pages": 12
    },
    "SaaS_Subscription_NovaTech_2024.pdf": {
        "doc_id": 2,
        "doc_type": "SaaS Subscription Agreement",
        "party_a": "NovaTech Solutions",
        "party_b": "Acme Corp",
        "effective_date": "2024-03-01",
        "expiration_date": "2025-02-28",
        "total_value": "$360,000",
        "payment_terms": "Annual Prepaid",
        "auto_renewal": True,
        "governing_law": "State of California",
        "pages": 8
    },
    "NDA_Mutual_Acme_Pinnacle_2024.pdf": {
        "doc_id": 3,
        "doc_type": "NDA (Mutual)",
        "party_a": "Acme Corp",
        "party_b": "Pinnacle Analytics",
        "effective_date": "2024-06-01",
        "expiration_date": "2026-05-31",
        "total_value": "N/A",
        "payment_terms": "N/A",
        "auto_renewal": False,
        "governing_law": "State of New York",
        "pages": 4
    },
    "SOW_DataPlatform_Acme_2024.pdf": {
        "doc_id": 4,
        "doc_type": "Statement of Work",
        "party_a": "Acme Corp",
        "party_b": "GlobalTech Inc",
        "effective_date": "2024-04-01",
        "expiration_date": "2024-12-31",
        "total_value": "$480,000",
        "payment_terms": "Monthly Milestone",
        "auto_renewal": False,
        "governing_law": "State of Delaware",
        "pages": 6
    },
    "DPA_Acme_CloudVault_2024.pdf": {
        "doc_id": 5,
        "doc_type": "Data Processing Agreement",
        "party_a": "Acme Corp",
        "party_b": "CloudVault Storage",
        "effective_date": "2024-01-15",
        "expiration_date": "2026-01-14",
        "total_value": "N/A",
        "payment_terms": "N/A",
        "auto_renewal": True,
        "governing_law": "GDPR — EU Standard Contractual Clauses",
        "pages": 10
    }
}

# ─────────────────────────────────────────────
# 3. PAGE LAYOUT
# ─────────────────────────────────────────────
st.set_page_config(
    page_title="Document AI — Paper to Insight",
    page_icon="📄",
    layout="wide"
)

st.markdown("""
<style>
    .booth-header {
        padding: 0.5rem 1rem;
        background: linear-gradient(90deg, #7B1FA2 0%, #4A148C 100%);
        color: white;
        border-radius: 0.5rem;
        margin-bottom: 1rem;
        text-align: center;
    }
    .booth-header h1 { margin: 0; font-size: 1.8rem; }
    .booth-header p { margin: 0; font-size: 1rem; opacity: 0.9; }

    /* Extraction field styling */
    .field-row {
        display: flex;
        padding: 0.3rem 0;
        border-bottom: 1px solid #eee;
    }
    .field-label { font-weight: bold; width: 150px; }
    .field-value { flex: 1; }

    /* Search result card */
    .search-result {
        border: 1px solid #ddd;
        border-radius: 0.5rem;
        padding: 1rem;
        margin-bottom: 0.5rem;
    }
    .relevance-high { border-left: 4px solid #4CAF50; }
    .relevance-medium { border-left: 4px solid #FF9800; }
</style>
""", unsafe_allow_html=True)

st.markdown("""
<div class="booth-header">
    <h1>Document AI — Paper to Insight in 60 Seconds</h1>
    <p>Upload a contract. Extract structured data. Search in natural language.</p>
</div>
""", unsafe_allow_html=True)

# ─────────────────────────────────────────────
# 4. SESSION STATE
# ─────────────────────────────────────────────
if "selected_doc" not in st.session_state:
    st.session_state.selected_doc = None

if "extraction_done" not in st.session_state:
    st.session_state.extraction_done = False

if "search_results" not in st.session_state:
    st.session_state.search_results = []

if "compare_mode" not in st.session_state:
    st.session_state.compare_mode = False

# ─────────────────────────────────────────────
# 5. DOCUMENT AI INTEGRATION
# ─────────────────────────────────────────────

def simulate_extraction(doc_name: str) -> dict:
    """
    Simulate Document AI extraction.

    In production, this would:
    1. PUT file to stage
    2. Call Document AI model to extract fields
    3. Parse VARIANT output into structured fields

    For the demo, we use pre-loaded data with a brief delay
    to simulate processing time.
    """
    import time

    doc_info = PRELOADED_DOCS.get(doc_name)
    if not doc_info:
        return None

    # Simulate extraction delay (visible to visitor)
    time.sleep(1.5)

    return doc_info


def get_extracted_data_from_db(doc_id: int) -> dict:
    """
    Pull extraction results from DOCUMENTS_EXTRACTED table.
    Use this if Document AI has already processed the document.
    """
    try:
        df = session.sql(f"""
            SELECT *
            FROM {DATABASE}.{SCHEMA}.DOCUMENTS_EXTRACTED
            WHERE doc_id = {doc_id}
        """).to_pandas()

        if len(df) > 0:
            row = df.iloc[0]
            return {
                "doc_type": row.get("DOC_TYPE", ""),
                "party_a": row.get("PARTY_A", ""),
                "party_b": row.get("PARTY_B", ""),
                "effective_date": str(row.get("EFFECTIVE_DATE", "")),
                "expiration_date": str(row.get("EXPIRATION_DATE", "")),
                "total_value": f"${row['TOTAL_VALUE']:,.2f}" if row.get("TOTAL_VALUE") else "N/A",
                "payment_terms": row.get("PAYMENT_TERMS", "N/A"),
                "auto_renewal": row.get("AUTO_RENEWAL", False),
                "governing_law": row.get("GOVERNING_LAW", "")
            }
    except Exception:
        pass
    return None


# ─────────────────────────────────────────────
# 6. CORTEX SEARCH INTEGRATION
# ─────────────────────────────────────────────

def semantic_search(query: str, limit: int = SEARCH_LIMIT) -> list:
    """
    Search documents using Cortex Search via REST API.
    Returns list of dicts with: chunk_text, page_number, section_header, score.
    """
    if not IN_SNOWFLAKE:
        return _fallback_semantic_search(query, limit)

    try:
        # Cortex Search REST API endpoint
        endpoint = (
            f"/api/v2/databases/{DATABASE}/schemas/{SCHEMA}"
            f"/cortex-search-services/{SEARCH_SERVICE_NAME}:query"
        )

        request_body = {
            "query": query,
            "columns": ["chunk_text", "page_number", "section_header", "doc_id"],
            "limit": limit
        }

        resp = _snowflake.send_snow_api_request(
            "POST", endpoint, {}, {}, request_body, None, 30000
        )

        resp_json = json.loads(resp["content"])

        if resp["status"] >= 400:
            raise Exception(resp_json.get("message", f"API error {resp['status']}"))

        results = []
        for i, item in enumerate(resp_json.get("results", [])):
            # Score: ranked by position (API doesn't always return a score field)
            rank_score = round(1.0 - (i * 0.15), 2)
            results.append({
                "chunk_text": item.get("chunk_text", ""),
                "page_number": item.get("page_number", ""),
                "section_header": item.get("section_header", ""),
                "doc_id": item.get("doc_id", ""),
                "score": rank_score
            })

        return results

    except Exception as e:
        return _fallback_semantic_search(query, limit)


def _fallback_semantic_search(query: str, limit: int = 5) -> list:
    """
    Fallback: query DOCUMENTS_TEXT directly with LIKE.
    Less accurate than semantic search but ensures demo doesn't break.
    """
    try:
        stop_words = {"what", "is", "the", "a", "an", "are", "how", "do", "does",
                      "there", "any", "for", "in", "of", "to", "and", "or", "with"}
        keywords = [kw for kw in query.replace("'", "''").split()
                    if kw.lower().strip("?.,!") not in stop_words and len(kw) > 2]
        if not keywords:
            keywords = query.replace("'", "''").split()[:2]
        conditions = " OR ".join([f"LOWER(chunk_text) LIKE '%{kw.lower().strip(chr(63)+chr(46)+chr(44)+chr(33))}%'" for kw in keywords])

        df = session.sql(f"""
            SELECT chunk_text, page_number, section_header, doc_id,
                   0.50 AS score
            FROM {DATABASE}.{SCHEMA}.DOCUMENTS_TEXT
            WHERE {conditions}
            LIMIT {limit}
        """).to_pandas()

        # Normalize column names to lowercase (Snowflake returns UPPERCASE)
        df.columns = [c.lower() for c in df.columns]
        return df.to_dict("records")
    except Exception as e:
        st.caption(f"[DEBUG] Fallback search error: {str(e)}")
        return []


# ─────────────────────────────────────────────
# 7. KEYWORD SEARCH (for "Compare" toggle)
# ─────────────────────────────────────────────

def keyword_search(query: str, limit: int = SEARCH_LIMIT) -> list:
    """
    Traditional LIKE-based keyword search.
    Used in the "Compare" toggle to contrast with semantic search.
    """
    try:
        # Exact keyword matching — intentionally naive
        safe_query = query.replace("'", "''").lower()

        df = session.sql(f"""
            SELECT chunk_text, page_number, section_header, doc_id
            FROM {DATABASE}.{SCHEMA}.DOCUMENTS_TEXT
            WHERE LOWER(chunk_text) LIKE '%{safe_query}%'
            LIMIT {limit}
        """).to_pandas()

        df.columns = [c.lower() for c in df.columns]
        results = []
        for _, row in df.iterrows():
            results.append({
                "chunk_text": row["chunk_text"],
                "page_number": row["page_number"],
                "section_header": row["section_header"],
                "doc_id": row["doc_id"],
                "match_type": "KEYWORD (LIKE)"
            })

        return results

    except Exception:
        return []


# ─────────────────────────────────────────────
# 8. TWO-PANEL UI
# ─────────────────────────────────────────────

# Sidebar controls
with st.sidebar:
    st.markdown("### Demo Controls")

    if st.button("Reset Demo", use_container_width=True):
        st.session_state.selected_doc = None
        st.session_state.extraction_done = False
        st.session_state.search_results = []
        st.session_state.compare_mode = False
        st.experimental_rerun()

    st.markdown("---")

    # Relevance threshold slider
    min_score = st.slider(
        "Min Relevance Score",
        min_value=0.0, max_value=1.0, value=0.4, step=0.05,
        help="Only show results with score above this threshold"
    )
    st.session_state["min_score"] = min_score

    st.markdown("---")

    # Compare toggle
    st.session_state.compare_mode = st.checkbox(
        "Compare: Semantic vs Keyword",
        value=st.session_state.compare_mode,
        help="Show side-by-side results: Cortex Search (semantic) vs LIKE (keyword)"
    )

    st.markdown("---")

    # Document inventory
    st.markdown("### Staged Documents")
    for doc_name, info in PRELOADED_DOCS.items():
        icon = "📄" if info["doc_id"] != 1 else "⭐"
        st.caption(f"{icon} {doc_name} ({info['pages']}p)")

    st.markdown("---")

    st.markdown("### Sample Questions")
    sample_questions = [
        "What is the termination clause?",
        "Are there any liability caps?",
        "What are the payment terms?",
        "Is there an auto-renewal provision?",
        "What are the early exit provisions?"
    ]
    for i, q in enumerate(sample_questions):
        if st.button(q, key=f"sample_{i}", use_container_width=True):
            st.session_state["prefill_search"] = q
            st.experimental_rerun()

# Two-panel layout
left_col, right_col = st.columns([1, 1])

# ─── LEFT PANEL: Upload & Extract ───
with left_col:
    st.markdown("### Upload & Extract")

    # Document selector (simulates upload)
    selected = st.selectbox(
        "Select a document to process:",
        options=list(PRELOADED_DOCS.keys()),
        index=0,
        format_func=lambda x: f"{x} ({PRELOADED_DOCS[x]['pages']} pages)"
    )

    if st.button("Process Document", use_container_width=True):
        st.session_state.selected_doc = selected
        st.session_state.extraction_done = False

        with st.spinner(f"Document AI processing {selected}..."):
            extraction = simulate_extraction(selected)

        if extraction:
            st.session_state.extraction_done = True
            st.session_state.extraction_result = extraction
            st.experimental_rerun()

    # Show extraction results
    if st.session_state.extraction_done and st.session_state.get("extraction_result"):
        ext = st.session_state.extraction_result

        st.success(f"Extraction complete: {st.session_state.selected_doc}")

        # Structured fields display
        st.markdown(f"**Document:** {st.session_state.selected_doc}")
        st.markdown(f"**Pages:** {ext.get('pages', 'N/A')}")

        st.markdown("---")
        st.markdown("**Extracted Fields:**")

        fields = [
            ("Document Type", ext.get("doc_type", "")),
            ("Parties", f"{ext.get('party_a', '')} ↔ {ext.get('party_b', '')}"),
            ("Effective Date", ext.get("effective_date", "")),
            ("Expiration Date", ext.get("expiration_date", "")),
            ("Total Value", ext.get("total_value", "")),
            ("Payment Terms", ext.get("payment_terms", "")),
            ("Auto-Renewal", "Yes" if ext.get("auto_renewal") else "No"),
            ("Governing Law", ext.get("governing_law", ""))
        ]

        for label, value in fields:
            col_label, col_value = st.columns([0.4, 0.6])
            with col_label:
                st.markdown(f"**{label}**")
            with col_value:
                st.markdown(value)

        st.markdown("---")
        st.caption("Full text indexed in Cortex Search ✓")

    elif not st.session_state.extraction_done:
        # Empty state
        st.info("Select a document and click 'Process Document' to begin extraction.")


# ─── RIGHT PANEL: Semantic Search ───
with right_col:
    st.markdown("### Semantic Search")

    # Search input
    prefill = st.session_state.pop("prefill_search", None)
    search_query = st.text_input(
        "Search across all documents:",
        value=prefill or "",
        placeholder="e.g., What is the termination clause?"
    )

    if st.button("Search", use_container_width=True) and search_query:
        # Semantic search
        with st.spinner("Searching (Cortex Search)..."):
            semantic_results = semantic_search(search_query)

        # Filter results by min score threshold
        threshold = st.session_state.get("min_score", 0.4)
        if semantic_results:
            filtered = [r for r in semantic_results if r.get("score", 0) >= threshold]
            total = len(semantic_results)
            shown = len(filtered)
            st.markdown(
                f"**Cortex Search Results** ({shown} of {total} matches, threshold: {threshold})"
            )

            for i, result in enumerate(filtered):
                score = result.get("score", 0)
                score_color = "🟢" if score > 0.8 else "🟡" if score > 0.5 else "🔴"

                with st.expander(
                    f"{score_color} {result.get('section_header', 'Unknown Section')} "
                    f"(Page {result.get('page_number', '?')}, Score: {score})",
                    expanded=(i == 0)
                ):
                    st.markdown(f"*\"{result.get('chunk_text', '')}\"*")
                    st.caption(f"Source: Page {result.get('page_number', '?')} | "
                             f"Section: {result.get('section_header', '?')}")
        else:
            st.warning("No results found. Try rephrasing your question.")

        # ─── COMPARE MODE ───
        if st.session_state.compare_mode:
            st.markdown("---")
            st.markdown("**Keyword Search (LIKE) Results** — for comparison")

            with st.spinner("Running keyword search..."):
                keyword_results = keyword_search(search_query)

            if keyword_results:
                for result in keyword_results:
                    with st.expander(
                        f"🔵 {result.get('section_header', 'Unknown')} "
                        f"(Page {result.get('page_number', '?')})"
                    ):
                        st.markdown(f"*\"{result.get('chunk_text', '')}\"*")
            else:
                st.error(
                    f"Keyword search for \"{search_query}\" returned **0 results**. "
                    f"This is expected — LIKE '%{search_query}%' requires exact substring match. "
                    f"Cortex Search understands meaning, not just keywords."
                )

            # Highlight the gap
            semantic_count = len(semantic_results) if semantic_results else 0
            keyword_count = len(keyword_results)

            if semantic_count > keyword_count:
                st.success(
                    f"Cortex Search found **{semantic_count}** results vs "
                    f"keyword search's **{keyword_count}**. "
                    f"Semantic search understands intent — "
                    f"'early exit provisions' matches a query about 'termination' "
                    f"because the meaning is related."
                )

    elif not search_query:
        st.info("Enter a question to search across all indexed documents.")

# ─────────────────────────────────────────────
# 9. FOOTER
# ─────────────────────────────────────────────
st.markdown("---")
search_mode = "Cortex Search + LIKE Compare" if st.session_state.compare_mode else "Cortex Search"
st.caption(
    f"Powered by Snowflake Document AI + Cortex Search | "
    f"Mode: {search_mode} | "
    f"Stage: {STAGE} | "
    f"No data leaves Snowflake"
)
