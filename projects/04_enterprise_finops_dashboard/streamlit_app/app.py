"""
Enterprise FinOps Dashboard for Snowflake
Snowbrix Academy — Production-Grade Data Engineering. No Fluff.

Main application entry point with navigation
"""

import streamlit as st
from components.data import get_snowflake_connection
import sys
from pathlib import Path

# Add components directory to path
sys.path.append(str(Path(__file__).parent))

# Page configuration
st.set_page_config(
    page_title="FinOps Dashboard | Snowbrix Academy",
    page_icon="💰",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Custom CSS for brand styling
st.markdown("""
    <style>
    .main-header {
        font-size: 2.5rem;
        font-weight: 700;
        color: #1e3a8a;
        margin-bottom: 0.5rem;
    }
    .sub-header {
        font-size: 1.2rem;
        color: #64748b;
        margin-bottom: 2rem;
    }
    .metric-card {
        background-color: #f8fafc;
        padding: 1.5rem;
        border-radius: 0.5rem;
        border-left: 4px solid #3b82f6;
    }
    .stMetric {
        background-color: #ffffff;
        padding: 1rem;
        border-radius: 0.5rem;
        box-shadow: 0 1px 3px rgba(0,0,0,0.1);
    }
    </style>
""", unsafe_allow_html=True)

# Sidebar configuration
with st.sidebar:
    st.image("https://via.placeholder.com/200x80/1e3a8a/ffffff?text=FinOps", width=200)
    st.markdown("### Enterprise FinOps Dashboard")
    st.markdown("**Snowbrix Academy**")
    st.markdown("---")

    # Navigation
    st.markdown("### Navigation")
    page = st.radio(
        "Select Page:",
        options=[
            "🏠 Home",
            "📊 Executive Summary",
            "🏭 Warehouse Analytics",
            "🔍 Query Cost Analysis",
            "💳 Chargeback Report",
            "📈 Budget Management",
            "🎯 Optimization",
            "⚙️ Admin / Config"
        ],
        label_visibility="collapsed"
    )

    st.markdown("---")

    # Connection status
    try:
        conn = get_snowflake_connection()
        st.success("✅ Connected to Snowflake")

        # Show current role and warehouse
        result = conn.cursor().execute("SELECT CURRENT_ROLE(), CURRENT_WAREHOUSE()").fetchone()
        st.info(f"**Role:** {result[0]}\n\n**Warehouse:** {result[1]}")
    except Exception as e:
        st.error(f"❌ Connection Error")
        st.error(str(e))

    st.markdown("---")
    st.markdown("**Quick Actions**")
    if st.button("🔄 Refresh Data"):
        st.cache_data.clear()
        st.rerun()

    st.markdown("---")
    st.markdown("""
    **About**

    Enterprise FinOps Dashboard for Snowflake cost visibility, chargeback attribution, and optimization.

    Built by Snowbrix Academy
    """)

# Main content area
if page == "🏠 Home":
    st.markdown('<div class="main-header">Enterprise FinOps Dashboard</div>', unsafe_allow_html=True)
    st.markdown('<div class="sub-header">Real-time Snowflake cost visibility, chargeback, and optimization</div>', unsafe_allow_html=True)

    st.markdown("---")

    col1, col2, col3 = st.columns(3)

    with col1:
        st.markdown("### 📊 Cost Visibility")
        st.markdown("""
        - Real-time warehouse costs
        - Query-level cost attribution
        - Storage trends and forecasts
        - Serverless feature costs
        """)

    with col2:
        st.markdown("### 💳 Chargeback")
        st.markdown("""
        - Multi-dimensional attribution
        - Team / Department / Project
        - Tag-based allocation
        - Unallocated cost tracking
        """)

    with col3:
        st.markdown("### 🎯 Optimization")
        st.markdown("""
        - Idle warehouse detection
        - Query optimization recommendations
        - Auto-suspend tuning
        - Storage waste identification
        """)

    st.markdown("---")

    st.markdown("### Getting Started")

    st.markdown("""
    **1. Executive Summary** - Start here for high-level KPIs and trends

    **2. Warehouse Analytics** - Drill down into per-warehouse utilization and costs

    **3. Query Cost Analysis** - Identify expensive queries and optimization candidates

    **4. Chargeback Report** - View costs by team, department, or project

    **5. Budget Management** - Track budget vs actual, alerts, and forecasts

    **6. Optimization** - Review actionable cost reduction recommendations

    **7. Admin / Config** - Configure settings, register teams, manage budgets
    """)

    st.markdown("---")

    st.info("""
    **📖 Documentation**

    For detailed setup instructions, see `LAB_GUIDE.md` in the project repository.

    For architecture details, see `README.md`.
    """)

elif page == "📊 Executive Summary":
    st.markdown("# 📊 Executive Summary")
    st.markdown("High-level KPIs, trends, and top spenders")

    # Import and run the executive summary page
    try:
        from pages import executive_summary
        executive_summary.render()
    except ImportError:
        st.warning("⚠️ Executive Summary page not yet implemented. See `streamlit_app/pages/1_Executive_Summary.py`")

elif page == "🏭 Warehouse Analytics":
    st.markdown("# 🏭 Warehouse Analytics")
    st.markdown("Per-warehouse utilization, idle time, and cost breakdown")

    try:
        from pages import warehouse_analytics
        warehouse_analytics.render()
    except ImportError:
        st.warning("⚠️ Warehouse Analytics page not yet implemented. See `streamlit_app/pages/2_Warehouse_Analytics.py`")

elif page == "🔍 Query Cost Analysis":
    st.markdown("# 🔍 Query Cost Analysis")
    st.markdown("Top expensive queries and optimization candidates")

    try:
        from pages import query_cost_analysis
        query_cost_analysis.render()
    except ImportError:
        st.warning("⚠️ Query Cost Analysis page not yet implemented. See `streamlit_app/pages/3_Query_Cost_Analysis.py`")

elif page == "💳 Chargeback Report":
    st.markdown("# 💳 Chargeback Report")
    st.markdown("Multi-dimensional cost attribution by team, department, and project")

    try:
        from pages import chargeback_report
        chargeback_report.render()
    except ImportError:
        st.warning("⚠️ Chargeback Report page not yet implemented. See `streamlit_app/pages/4_Chargeback_Report.py`")

elif page == "📈 Budget Management":
    st.markdown("# 📈 Budget Management")
    st.markdown("Budget vs actual, burn rate, forecasts, and alerts")

    try:
        from pages import budget_management
        budget_management.render()
    except ImportError:
        st.warning("⚠️ Budget Management page not yet implemented. See `streamlit_app/pages/5_Budget_Management.py`")

elif page == "🎯 Optimization":
    st.markdown("# 🎯 Optimization Recommendations")
    st.markdown("Actionable cost reduction recommendations ranked by potential savings")

    try:
        from pages import optimization
        optimization.render()
    except ImportError:
        st.warning("⚠️ Optimization page not yet implemented. See `streamlit_app/pages/6_Optimization.py`")

elif page == "⚙️ Admin / Config":
    st.markdown("# ⚙️ Admin / Configuration")
    st.markdown("Register teams, set budgets, configure alerts, manage settings")

    try:
        from pages import admin_config
        admin_config.render()
    except ImportError:
        st.warning("⚠️ Admin Config page not yet implemented. See `streamlit_app/pages/7_Admin_Config.py`")

# Footer
st.markdown("---")
st.markdown("""
<div style="text-align: center; color: #64748b; padding: 2rem 0;">
    <strong>Enterprise FinOps Dashboard for Snowflake</strong><br>
    Built by Snowbrix Academy — Production-Grade Data Engineering. No Fluff.<br>
    Version 1.0.0
</div>
""", unsafe_allow_html=True)
