"""
==================================================================
  INNOVATION SUMMIT — STATION C: DOCUMENT INTELLIGENCE + VECTOR SEARCH
  App: summit_ai_document_app
  Purpose: "Paper to Insight in 60 Seconds" — document search
  Deploy: Databricks Apps (Workspace → Apps → Create App)

  ARCHITECTURE:
  ├── UI: Streamlit (two-panel layout)
  ├── Left Panel: Document upload & extraction
  ├── Right Panel: Semantic search (Vector Search)
  └── Bonus: Compare mode (semantic vs keyword)

  FEATURES:
  - Document selection and metadata display
  - Semantic search via Databricks Vector Search
  - Keyword search comparison mode
  - Real-time relevance scoring
==================================================================
"""

import streamlit as st
import pandas as pd
import json
import os
from databricks.sdk import WorkspaceClient
from databricks.vector_search.client import VectorSearchClient

# ─────────────────────────────────────────────
# 1. CONFIGURATION
# ─────────────────────────────────────────────

# Environment variables
CATALOG = os.getenv("CATALOG", "demo_ai_summit_databricks")
VECTOR_SEARCH_ENDPOINT = os.getenv("VECTOR_SEARCH_ENDPOINT", "demo_ai_summit_vs_endpoint")
VECTOR_SEARCH_INDEX = os.getenv("VECTOR_SEARCH_INDEX", "demo_ai_summit_databricks.documents.documents_search_index")
SEARCH_LIMIT = 5

# Databricks clients
try:
    w = WorkspaceClient()
    vsc = VectorSearchClient()
    IN_DATABRICKS = True
except Exception:
    w = None
    vsc = None
    IN_DATABRICKS = False
    st.warning("⚠ Not running in Databricks environment. Using fallback mode.")

# Pre-loaded documents (for demo)
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
        "auto_renewal": "Yes",
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
        "auto_renewal": "Yes",
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
        "auto_renewal": "No",
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
        "auto_renewal": "No",
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
        "auto_renewal": "Yes",
        "governing_law": "GDPR — EU Standard Contractual Clauses",
        "pages": 10
    }
}

# ─────────────────────────────────────────────
# 2. PAGE LAYOUT
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

    .field-row {
        padding: 0.5rem 0;
        border-bottom: 1px solid #eee;
    }
    .field-label {
        font-weight: bold;
        color: #555;
    }

    .search-result {
        border: 1px solid #ddd;
        border-radius: 0.5rem;
        padding: 1rem;
        margin-bottom: 0.5rem;
        background-color: #f9f9f9;
    }
    .relevance-high { border-left: 4px solid #4CAF50; }
    .relevance-medium { border-left: 4px solid #FF9800; }
    .relevance-low { border-left: 4px solid #9E9E9E; }
</style>
""", unsafe_allow_html=True)

st.markdown("""
<div class="booth-header">
    <h1>Document AI — Paper to Insight in 60 Seconds</h1>
    <p>Upload a contract. Extract structured data. Search in natural language.</p>
</div>
""", unsafe_allow_html=True)

# ─────────────────────────────────────────────
# 3. SESSION STATE
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
# 4. DOCUMENT EXTRACTION
# ─────────────────────────────────────────────

def simulate_extraction(doc_name: str) -> dict:
    """
    Simulate Document Intelligence extraction.
    In production, this would call Document Intelligence API.
    """
    import time

    doc_info = PRELOADED_DOCS.get(doc_name)
    if not doc_info:
        return None

    # Simulate extraction delay
    time.sleep(1.5)

    return doc_info

# ─────────────────────────────────────────────
# 5. VECTOR SEARCH INTEGRATION
# ─────────────────────────────────────────────

def semantic_search(query: str, limit: int = SEARCH_LIMIT) -> list:
    """
    Search documents using Databricks Vector Search.
    """
    if not IN_DATABRICKS or not vsc:
        return fallback_search(query, limit)

    try:
        # Query Vector Search index
        results = vsc.get_index(
            endpoint_name=VECTOR_SEARCH_ENDPOINT,
            index_name=VECTOR_SEARCH_INDEX
        ).similarity_search(
            query_text=query,
            columns=["chunk_text", "section_header", "page_number", "doc_id", "filename"],
            num_results=limit
        )

        # Parse results
        search_results = []
        if results and 'result' in results:
            for i, item in enumerate(results['result'].get('data_array', [])):
                # Extract fields (order depends on columns parameter)
                chunk_text = item[0] if len(item) > 0 else ""
                section_header = item[1] if len(item) > 1 else ""
                page_number = item[2] if len(item) > 2 else ""
                doc_id = item[3] if len(item) > 3 else ""
                filename = item[4] if len(item) > 4 else ""

                # Score (higher rank = higher score)
                score = round(1.0 - (i * 0.15), 2)

                search_results.append({
                    "chunk_text": chunk_text,
                    "section_header": section_header,
                    "page_number": page_number,
                    "doc_id": doc_id,
                    "filename": filename,
                    "score": score
                })

        return search_results

    except Exception as e:
        st.error(f"Vector Search error: {e}")
        return fallback_search(query, limit)


def fallback_search(query: str, limit: int = SEARCH_LIMIT) -> list:
    """
    Fallback: Simple keyword search in documents_text table.
    """
    if not IN_DATABRICKS or not w:
        # Return mock results for offline demo
        return [
            {
                "chunk_text": "Either party may terminate this Agreement upon ninety (90) days' written notice to the other party.",
                "section_header": "Section 3: Termination",
                "page_number": 2,
                "doc_id": 1,
                "filename": "MSA_Acme_GlobalTech_2024.pdf",
                "score": 0.85
            },
            {
                "chunk_text": "Customer may terminate with 30 days' notice. No refunds for early termination.",
                "section_header": "Section 3: Termination",
                "page_number": 2,
                "doc_id": 2,
                "filename": "SaaS_Subscription_NovaTech_2024.pdf",
                "score": 0.70
            }
        ]

    try:
        # Query using SQL
        from databricks.sdk.service.sql import StatementState

        # Extract keywords
        keywords = [kw.strip().lower() for kw in query.split() if len(kw) > 3]
        if not keywords:
            keywords = query.split()

        # Build LIKE conditions
        conditions = " OR ".join([f"LOWER(chunk_text) LIKE '%{kw}%'" for kw in keywords[:3]])

        sql = f"""
SELECT
  chunk_text,
  section_header,
  page_number,
  doc_id,
  filename
FROM {CATALOG}.documents.documents_text
WHERE {conditions}
LIMIT {limit}
        """

        # Execute via SQL warehouse
        statement = w.statement_execution.execute_statement(
            warehouse_id=os.getenv("SQL_WAREHOUSE_ID"),
            statement=sql,
            catalog=CATALOG
        )

        statement = w.statement_execution.wait_statement_state(
            statement_id=statement.statement_id,
            target_state=StatementState.SUCCEEDED
        )

        # Parse results
        results = []
        if statement.result and statement.result.data_array:
            for i, row in enumerate(statement.result.data_array):
                results.append({
                    "chunk_text": row[0],
                    "section_header": row[1],
                    "page_number": row[2],
                    "doc_id": row[3],
                    "filename": row[4],
                    "score": 0.50
                })

        return results

    except Exception as e:
        st.error(f"Fallback search error: {e}")
        return []


def keyword_search(query: str, limit: int = SEARCH_LIMIT) -> list:
    """
    Traditional keyword search (LIKE) for comparison mode.
    """
    # Simplified implementation
    return fallback_search(query, limit)

# ─────────────────────────────────────────────
# 6. UI COMPONENTS
# ─────────────────────────────────────────────

# Sidebar controls
with st.sidebar:
    st.markdown("### Demo Controls")

    if st.button("Reset Demo", use_container_width=True):
        st.session_state.selected_doc = None
        st.session_state.extraction_done = False
        st.session_state.search_results = []
        st.session_state.compare_mode = False
        st.rerun()

    st.markdown("---")

    # Min relevance score slider
    min_score = st.slider(
        "Min Relevance Score",
        min_value=0.0,
        max_value=1.0,
        value=0.4,
        step=0.05,
        help="Only show results above this threshold"
    )
    st.session_state["min_score"] = min_score

    st.markdown("---")

    # Compare mode toggle
    st.session_state.compare_mode = st.checkbox(
        "Compare: Semantic vs Keyword",
        value=st.session_state.compare_mode,
        help="Show side-by-side: Vector Search vs LIKE search"
    )

    st.markdown("---")

    # Document inventory
    st.markdown("### Staged Documents")
    for doc_name, info in PRELOADED_DOCS.items():
        icon = "⭐" if info["doc_id"] == 1 else "📄"
        st.caption(f"{icon} {doc_name} ({info['pages']}p)")

    st.markdown("---")

    # Sample questions
    st.markdown("### Sample Questions")
    sample_questions = [
        "What is the termination clause?",
        "Are there any liability caps?",
        "What are the payment terms?",
        "Is there an auto-renewal provision?",
        "What are the early exit provisions?"
    ]

    for i, q in enumerate(sample_questions):
        if st.button(f"Q{i+1}", key=f"sample_{i}", use_container_width=True):
            st.session_state["prefill_search"] = q
            st.rerun()

# Two-panel layout
left_col, right_col = st.columns([1, 1])

# ─── LEFT PANEL: Upload & Extract ───
with left_col:
    st.markdown("### 📤 Upload & Extract")

    # Document selector
    selected = st.selectbox(
        "Select a document to process:",
        options=list(PRELOADED_DOCS.keys()),
        index=0,
        format_func=lambda x: f"{x} ({PRELOADED_DOCS[x]['pages']} pages)"
    )

    if st.button("🔍 Process Document", use_container_width=True):
        st.session_state.selected_doc = selected
        st.session_state.extraction_done = False

        with st.spinner(f"Document AI processing {selected}..."):
            extraction = simulate_extraction(selected)

        if extraction:
            st.session_state.extraction_done = True
            st.session_state.extraction_result = extraction
            st.rerun()

    # Show extraction results
    if st.session_state.extraction_done and st.session_state.get("extraction_result"):
        ext = st.session_state.extraction_result

        st.success(f"✅ Extraction complete: {st.session_state.selected_doc}")

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
            ("Auto-Renewal", ext.get("auto_renewal", "")),
            ("Governing Law", ext.get("governing_law", ""))
        ]

        for label, value in fields:
            st.markdown(f'<div class="field-row">', unsafe_allow_html=True)
            st.markdown(f'<span class="field-label">{label}:</span> {value}')
            st.markdown('</div>', unsafe_allow_html=True)

        st.markdown("---")
        st.caption("✓ Full text indexed in Vector Search")

    else:
        st.info("Select a document and click 'Process Document' to begin extraction.")

# ─── RIGHT PANEL: Semantic Search ───
with right_col:
    st.markdown("### 🔍 Semantic Search")

    # Search input
    prefill = st.session_state.pop("prefill_search", "")
    search_query = st.text_input(
        "Search across all documents:",
        value=prefill,
        placeholder="e.g., What is the termination clause?",
        label_visibility="collapsed"
    )

    if st.button("🚀 Search", use_container_width=True) and search_query:
        # Semantic search
        with st.spinner("Searching (Vector Search)..."):
            semantic_results = semantic_search(search_query)

        # Filter by min score
        threshold = st.session_state.get("min_score", 0.4)
        if semantic_results:
            filtered = [r for r in semantic_results if r.get("score", 0) >= threshold]
            total = len(semantic_results)
            shown = len(filtered)

            st.markdown(
                f"**Vector Search Results** ({shown} of {total} matches, threshold: {threshold})"
            )

            for i, result in enumerate(filtered):
                score = result.get("score", 0)
                score_emoji = "🟢" if score > 0.8 else "🟡" if score > 0.5 else "🔴"
                css_class = "relevance-high" if score > 0.8 else "relevance-medium" if score > 0.5 else "relevance-low"

                with st.expander(
                    f"{score_emoji} {result.get('section_header', 'Unknown Section')} "
                    f"(Page {result.get('page_number', '?')}, Score: {score})",
                    expanded=(i == 0)
                ):
                    st.markdown(f'<div class="search-result {css_class}">', unsafe_allow_html=True)
                    st.markdown(f"*\"{result.get('chunk_text', '')}\"*")
                    st.caption(
                        f"📄 Source: {result.get('filename', 'Unknown')} | "
                        f"Page {result.get('page_number', '?')} | "
                        f"Section: {result.get('section_header', '?')}"
                    )
                    st.markdown('</div>', unsafe_allow_html=True)
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
                    f"This is expected — LIKE requires exact substring match. "
                    f"Vector Search understands meaning, not just keywords."
                )

            # Highlight the gap
            semantic_count = len(filtered) if semantic_results else 0
            keyword_count = len(keyword_results)

            if semantic_count > keyword_count:
                st.success(
                    f"Vector Search found **{semantic_count}** results vs "
                    f"keyword search's **{keyword_count}**. "
                    f"Semantic search understands intent!"
                )

    else:
        st.info("Enter a question to search across all indexed documents.")

# ─────────────────────────────────────────────
# 7. FOOTER
# ─────────────────────────────────────────────

st.markdown("---")
search_mode = "Vector Search + LIKE Compare" if st.session_state.compare_mode else "Vector Search"
st.caption(
    f"Powered by Databricks Document Intelligence + Vector Search | "
    f"Mode: {search_mode} | "
    f"Catalog: {CATALOG} | "
    f"No data leaves Databricks"
)
