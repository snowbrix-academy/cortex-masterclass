"""
Snowbrix E-Commerce Platform — Analytics Dashboard

A production-ready Streamlit dashboard that connects to Snowflake
and visualizes e-commerce KPIs, revenue trends, customer lifetime
value, and product performance.

Usage:
    streamlit run dashboard/streamlit_app.py
"""

import os
import sys
from datetime import date, timedelta
from pathlib import Path

import streamlit as st
import plotly.express as px
import plotly.graph_objects as go
import pandas as pd

# Add project root to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))
from dashboard.snowflake_connection import run_query, load_sql_file

# ── Page Config ──────────────────────────────────────────────

st.set_page_config(
    page_title="Snowbrix E-Commerce Dashboard",
    page_icon="📊",
    layout="wide",
    initial_sidebar_state="collapsed",
)

# ── Brand Colors ─────────────────────────────────────────────

COLORS = {
    "primary": "#1A1A2E",
    "cyan": "#00D4FF",
    "orange": "#FF6B35",
    "gray": "#B0A8A0",
    "red": "#E63946",
    "green": "#2ECC71",
    "light_bg": "#F8F9FA",
}

# ── Sidebar: Filters ────────────────────────────────────────

st.sidebar.title("Filters")

date_range = st.sidebar.selectbox(
    "Date Range",
    ["Last 7 Days", "Last 30 Days", "Last 90 Days", "Last 365 Days", "Custom"],
    index=1,
)

if date_range == "Custom":
    start_date = st.sidebar.date_input("Start Date", date.today() - timedelta(days=30))
    end_date = st.sidebar.date_input("End Date", date.today())
else:
    days_map = {
        "Last 7 Days": 7,
        "Last 30 Days": 30,
        "Last 90 Days": 90,
        "Last 365 Days": 365,
    }
    days = days_map[date_range]
    start_date = date.today() - timedelta(days=days)
    end_date = date.today()

auto_refresh = st.sidebar.checkbox("Auto-refresh (5 min)", value=False)

# ── Header ───────────────────────────────────────────────────

st.markdown(
    """
    <h1 style='text-align: center; color: #1A1A2E;'>
        Snowbrix E-Commerce Dashboard
    </h1>
    <p style='text-align: center; color: #B0A8A0;'>
        Production-Grade Data Engineering. No Fluff.
    </p>
    """,
    unsafe_allow_html=True,
)

st.divider()

# ── KPI Cards ────────────────────────────────────────────────


@st.cache_data(ttl=300)  # Cache for 5 minutes
def load_kpis():
    sql = load_sql_file("kpis.sql")
    return run_query(sql)


try:
    kpi_df = load_kpis()

    if not kpi_df.empty:
        row = kpi_df.iloc[0]

        col1, col2, col3, col4 = st.columns(4)

        with col1:
            st.metric(
                label="Total Revenue (30d)",
                value=f"${row['TOTAL_REVENUE']:,.0f}",
                delta=f"{row['REVENUE_CHANGE_PCT']}%" if pd.notna(row['REVENUE_CHANGE_PCT']) else None,
            )

        with col2:
            st.metric(
                label="Total Orders (30d)",
                value=f"{row['TOTAL_ORDERS']:,.0f}",
                delta=f"{row['ORDERS_CHANGE_PCT']}%" if pd.notna(row['ORDERS_CHANGE_PCT']) else None,
            )

        with col3:
            st.metric(
                label="Avg Order Value",
                value=f"${row['AVG_ORDER_VALUE']:,.2f}",
                delta=f"{row['AOV_CHANGE_PCT']}%" if pd.notna(row['AOV_CHANGE_PCT']) else None,
            )

        with col4:
            st.metric(
                label="New Customers (30d)",
                value=f"{row['NEW_CUSTOMERS']:,.0f}",
                delta=f"{row['CUSTOMERS_CHANGE_PCT']}%" if pd.notna(row['CUSTOMERS_CHANGE_PCT']) else None,
            )
    else:
        st.warning("No KPI data available. Ensure dbt models have been run.")

except Exception as e:
    st.error(f"Error loading KPIs: {e}")

st.divider()

# ── Revenue Chart ────────────────────────────────────────────


@st.cache_data(ttl=300)
def load_revenue(start, end):
    sql = load_sql_file("revenue.sql")
    return run_query(sql, params={"start_date": str(start), "end_date": str(end)})


try:
    revenue_df = load_revenue(start_date, end_date)

    if not revenue_df.empty:
        st.subheader("Revenue Over Time")

        fig = go.Figure()

        # Daily revenue bars
        fig.add_trace(go.Bar(
            x=revenue_df["DATE"],
            y=revenue_df["REVENUE"],
            name="Daily Revenue",
            marker_color=COLORS["cyan"],
            opacity=0.6,
        ))

        # 7-day rolling average line
        fig.add_trace(go.Scatter(
            x=revenue_df["DATE"],
            y=revenue_df["REVENUE_7D_AVG"],
            name="7-Day Avg",
            line=dict(color=COLORS["orange"], width=3),
        ))

        fig.update_layout(
            plot_bgcolor="white",
            height=400,
            margin=dict(l=40, r=40, t=20, b=40),
            legend=dict(orientation="h", yanchor="bottom", y=1.02),
            xaxis_title="",
            yaxis_title="Revenue ($)",
            yaxis_tickprefix="$",
            yaxis_tickformat=",",
        )

        st.plotly_chart(fig, use_container_width=True)
    else:
        st.info("No revenue data for the selected date range.")

except Exception as e:
    st.error(f"Error loading revenue data: {e}")

# ── Two-Column Section: Customers + Products ─────────────────

col_left, col_right = st.columns(2)

# ── Customer LTV Distribution ────────────────────────────────

with col_left:
    st.subheader("Customer Lifetime Value Distribution")

    @st.cache_data(ttl=600)
    def load_customers():
        sql = load_sql_file("customers.sql")
        return run_query(sql)

    try:
        cust_df = load_customers()

        if not cust_df.empty:
            fig_ltv = px.histogram(
                cust_df,
                x="LIFETIME_REVENUE",
                nbins=50,
                color_discrete_sequence=[COLORS["cyan"]],
                labels={"LIFETIME_REVENUE": "Lifetime Revenue ($)"},
            )
            fig_ltv.update_layout(
                plot_bgcolor="white",
                height=350,
                margin=dict(l=40, r=20, t=20, b=40),
                showlegend=False,
                xaxis_tickprefix="$",
            )
            st.plotly_chart(fig_ltv, use_container_width=True)

            # Summary stats
            mcol1, mcol2, mcol3 = st.columns(3)
            mcol1.metric("Median LTV", f"${cust_df['LIFETIME_REVENUE'].median():,.0f}")
            mcol2.metric("Mean LTV", f"${cust_df['LIFETIME_REVENUE'].mean():,.0f}")
            mcol3.metric("P90 LTV", f"${cust_df['LIFETIME_REVENUE'].quantile(0.9):,.0f}")

    except Exception as e:
        st.error(f"Error loading customer data: {e}")

# ── Top Products ─────────────────────────────────────────────

with col_right:
    st.subheader("Top 10 Products by Revenue")

    @st.cache_data(ttl=600)
    def load_products():
        sql = load_sql_file("products.sql")
        return run_query(sql)

    try:
        prod_df = load_products()

        if not prod_df.empty:
            fig_prod = px.bar(
                prod_df,
                y="PRODUCT_NAME",
                x="TOTAL_REVENUE",
                orientation="h",
                color="CATEGORY",
                color_discrete_sequence=[
                    COLORS["cyan"], COLORS["orange"], COLORS["green"],
                    COLORS["gray"], COLORS["red"],
                ],
                labels={
                    "TOTAL_REVENUE": "Revenue ($)",
                    "PRODUCT_NAME": "",
                    "CATEGORY": "Category",
                },
            )
            fig_prod.update_layout(
                plot_bgcolor="white",
                height=350,
                margin=dict(l=20, r=20, t=20, b=40),
                yaxis=dict(autorange="reversed"),
                xaxis_tickprefix="$",
                xaxis_tickformat=",",
            )
            st.plotly_chart(fig_prod, use_container_width=True)

    except Exception as e:
        st.error(f"Error loading product data: {e}")

# ── Footer ───────────────────────────────────────────────────

st.divider()
st.markdown(
    """
    <p style='text-align: center; color: #B0A8A0; font-size: 12px;'>
        Snowbrix Academy | Data refreshed from Snowflake ECOMMERCE_ANALYTICS.MARTS
    </p>
    """,
    unsafe_allow_html=True,
)

# ── Auto-Refresh ─────────────────────────────────────────────

if auto_refresh:
    import time
    time.sleep(300)  # 5 minutes
    st.rerun()
