"""
Query Cost Analysis Page

Detailed query-level cost analysis and optimization opportunities.
Identifies expensive queries, query patterns, and cost attribution by user.
"""

import streamlit as st
import pandas as pd
from datetime import datetime
from components import data, filters, charts, utils

# Page configuration
st.set_page_config(page_title="Query Cost Analysis", layout="wide", page_icon="🔍")

st.title("🔍 Query Cost Analysis")
st.markdown("Query-level cost breakdown and optimization insights")
st.markdown("---")

# Sidebar filters
start_date, end_date = filters.render_date_range_filter(default_days=7, key_prefix="query")

if not utils.validate_date_range(start_date, end_date):
    st.stop()

selected_warehouses = filters.render_warehouse_filter(key_prefix="query", multiselect=True)
selected_users = filters.render_user_filter(key_prefix="query", multiselect=True)
selected_query_types = filters.render_query_type_filter(key_prefix="query")

# Cost threshold filter
st.sidebar.markdown("### 💵 Cost Filters")
min_cost = st.sidebar.number_input(
    "Minimum Query Cost ($)",
    min_value=0.0,
    max_value=1000.0,
    value=0.0,
    step=0.1,
    key="query_min_cost"
)

if filters.render_refresh_button(key_prefix="query"):
    st.cache_data.clear()
    st.rerun()

# Main content
try:
    with utils.show_loading_spinner("Loading query cost analysis..."):
        # Fetch data
        expensive_queries = data.get_expensive_queries(
            start_date,
            end_date,
            min_cost=min_cost,
            limit=100
        )

        # Filter by selected criteria
        if selected_warehouses:
            expensive_queries = expensive_queries[
                expensive_queries['WAREHOUSE_NAME'].isin(selected_warehouses)
            ]

        if selected_users:
            expensive_queries = expensive_queries[
                expensive_queries['USER_NAME'].isin(selected_users)
            ]

        if selected_query_types:
            expensive_queries = expensive_queries[
                expensive_queries['QUERY_TYPE'].isin(selected_query_types)
            ]

        # Get summary data
        query_cost_by_user = data.get_query_cost_by_user(start_date, end_date)
        if selected_users:
            query_cost_by_user = query_cost_by_user[
                query_cost_by_user['USER_NAME'].isin(selected_users)
            ]

        query_cost_by_type = data.get_query_cost_by_type(start_date, end_date)

    # Check if data is available
    if expensive_queries.empty:
        utils.create_empty_state("No queries found matching the selected filters")
        st.stop()

    # Calculate summary metrics
    total_queries = len(expensive_queries)
    total_query_cost = expensive_queries['QUERY_COST'].sum()
    avg_query_cost = expensive_queries['QUERY_COST'].mean()
    max_query_cost = expensive_queries['QUERY_COST'].max()

    # Count optimization candidates (queries >$10)
    optimization_candidates = len(expensive_queries[expensive_queries['QUERY_COST'] > 10])

    # KPI Row
    st.markdown("### Query Cost Summary")
    col1, col2, col3, col4, col5 = st.columns(5)

    with col1:
        utils.show_metric_card(
            label="Total Queries Analyzed",
            value=utils.format_number(total_queries),
            help_text="Number of queries in the selected period"
        )

    with col2:
        utils.show_metric_card(
            label="Total Query Cost",
            value=utils.format_currency(total_query_cost),
            help_text="Sum of all query execution costs"
        )

    with col3:
        utils.show_metric_card(
            label="Average Query Cost",
            value=utils.format_currency(avg_query_cost),
            help_text="Mean cost per query"
        )

    with col4:
        utils.show_metric_card(
            label="Most Expensive Query",
            value=utils.format_currency(max_query_cost),
            help_text="Highest single query cost"
        )

    with col5:
        badge_type = "WARNING" if optimization_candidates > 10 else "INFO"
        st.metric(
            label="Optimization Candidates",
            value=utils.format_number(optimization_candidates),
            help="Queries with cost >$10"
        )
        st.markdown(utils.show_alert_badge(badge_type, f"{optimization_candidates} queries"), unsafe_allow_html=True)

    st.markdown("---")

    # Top Expensive Queries Table
    st.markdown("### 💸 Top Expensive Queries")

    # Display top 20 by default
    display_limit = st.slider("Number of queries to display", 10, 100, 20, step=10, key="query_display_limit")

    top_queries = expensive_queries.nlargest(display_limit, 'QUERY_COST').copy()

    # Format display columns
    display_cols = [
        'QUERY_ID',
        'USER_NAME',
        'WAREHOUSE_NAME',
        'QUERY_TYPE',
        'EXECUTION_TIME_SEC',
        'QUERY_COST',
        'START_TIME'
    ]

    # Ensure all columns exist
    display_cols = [col for col in display_cols if col in top_queries.columns]

    display_queries = top_queries[display_cols].copy()

    # Format columns
    if 'QUERY_COST' in display_queries.columns:
        display_queries['QUERY_COST'] = display_queries['QUERY_COST'].apply(utils.format_currency)
    if 'EXECUTION_TIME_SEC' in display_queries.columns:
        display_queries['EXECUTION_TIME_SEC'] = display_queries['EXECUTION_TIME_SEC'].apply(
            lambda x: f"{x:.2f}s"
        )
    if 'START_TIME' in display_queries.columns:
        display_queries['START_TIME'] = pd.to_datetime(display_queries['START_TIME']).dt.strftime('%Y-%m-%d %H:%M')

    st.dataframe(display_queries, use_container_width=True, hide_index=True)

    # Expandable query details
    st.markdown("#### 🔎 Query Details")
    with st.expander("Click to view query details and SQL text"):
        selected_query_id = st.selectbox(
            "Select Query ID",
            options=top_queries['QUERY_ID'].tolist(),
            key="query_detail_selector"
        )

        if selected_query_id:
            query_detail = top_queries[top_queries['QUERY_ID'] == selected_query_id].iloc[0]

            col1, col2, col3 = st.columns(3)

            with col1:
                st.markdown(f"**User:** {query_detail['USER_NAME']}")
                st.markdown(f"**Warehouse:** {query_detail['WAREHOUSE_NAME']}")
                st.markdown(f"**Query Type:** {query_detail['QUERY_TYPE']}")

            with col2:
                st.markdown(f"**Cost:** {utils.format_currency(query_detail['QUERY_COST'])}")
                st.markdown(f"**Execution Time:** {query_detail.get('EXECUTION_TIME_SEC', 0):.2f}s")
                st.markdown(f"**Credits:** {query_detail.get('CREDITS_USED', 0):.4f}")

            with col3:
                st.markdown(f"**Start Time:** {query_detail['START_TIME']}")
                st.markdown(f"**Rows Produced:** {utils.format_number(query_detail.get('ROWS_PRODUCED', 0))}")
                st.markdown(f"**Bytes Scanned:** {utils.format_number(query_detail.get('BYTES_SCANNED', 0))}")

            # SQL Text
            if 'QUERY_TEXT' in query_detail and pd.notna(query_detail['QUERY_TEXT']):
                st.markdown("**SQL Query:**")
                st.code(query_detail['QUERY_TEXT'], language='sql')
            else:
                st.info("Query text not available")

            # Optimization suggestions
            st.markdown("**💡 Optimization Suggestions:**")
            suggestions = []

            if query_detail.get('EXECUTION_TIME_SEC', 0) > 60:
                suggestions.append("⏱️ Long execution time - Consider adding filters or optimizing joins")

            if query_detail.get('BYTES_SCANNED', 0) > 1_000_000_000:  # 1GB
                suggestions.append("📊 Large data scan - Consider partitioning or clustering")

            if query_detail.get('QUERY_COST', 0) > 10:
                suggestions.append("💰 High cost - Review query necessity and frequency")

            if not suggestions:
                suggestions.append("✅ No immediate optimization suggestions")

            for suggestion in suggestions:
                st.markdown(f"- {suggestion}")

    st.markdown("---")

    # Cost Distribution Histogram
    st.markdown("### 📊 Query Cost Distribution")

    col_hist, col_stats = st.columns([2, 1])

    with col_hist:
        # Create histogram bins
        if not expensive_queries.empty:
            import plotly.graph_objects as go

            fig = go.Figure()
            fig.add_trace(go.Histogram(
                x=expensive_queries['QUERY_COST'],
                nbinsx=50,
                marker_color=charts.PRIMARY_COLOR,
                hovertemplate='Cost Range: $%{x:.2f}<br>Query Count: %{y}<extra></extra>'
            ))

            fig.update_layout(
                **charts.get_default_layout(),
                title='Query Cost Distribution',
                xaxis_title='Query Cost ($)',
                yaxis_title='Number of Queries',
                xaxis=dict(tickprefix='$', tickformat=',.0f')
            )

            st.plotly_chart(fig, use_container_width=True)

    with col_stats:
        st.markdown("#### Distribution Statistics")
        cost_stats = expensive_queries['QUERY_COST'].describe()

        stats_data = {
            'Metric': ['Mean', 'Median', 'Std Dev', '25th Percentile', '75th Percentile', '90th Percentile', '95th Percentile'],
            'Value': [
                utils.format_currency(cost_stats['mean']),
                utils.format_currency(cost_stats['50%']),
                utils.format_currency(cost_stats['std']),
                utils.format_currency(cost_stats['25%']),
                utils.format_currency(cost_stats['75%']),
                utils.format_currency(expensive_queries['QUERY_COST'].quantile(0.90)),
                utils.format_currency(expensive_queries['QUERY_COST'].quantile(0.95))
            ]
        }

        st.dataframe(pd.DataFrame(stats_data), use_container_width=True, hide_index=True)

    st.markdown("---")

    # Cost by User
    st.markdown("### 👤 Query Cost by User")

    if not query_cost_by_user.empty:
        col_chart, col_table = st.columns([2, 1])

        with col_chart:
            user_bar = charts.create_top_spenders_bar(
                query_cost_by_user.nlargest(15, 'TOTAL_COST'),
                category_col='USER_NAME',
                value_col='TOTAL_COST',
                title='Top Users by Query Cost',
                horizontal=True
            )
            st.plotly_chart(user_bar, use_container_width=True)

        with col_table:
            st.markdown("#### Top 10 Users")
            user_display = query_cost_by_user.nlargest(10, 'TOTAL_COST').copy()
            user_display['TOTAL_COST'] = user_display['TOTAL_COST'].apply(utils.format_currency)
            user_display['QUERY_COUNT'] = user_display['QUERY_COUNT'].apply(utils.format_number)
            st.dataframe(user_display, use_container_width=True, hide_index=True)
    else:
        st.info("No user cost data available")

    st.markdown("---")

    # Cost by Query Type
    st.markdown("### 🔍 Query Cost by Type")

    if not query_cost_by_type.empty:
        col_pie, col_table = st.columns([2, 1])

        with col_pie:
            type_pie = charts.create_cost_breakdown_pie(
                query_cost_by_type,
                labels_col='QUERY_TYPE',
                values_col='TOTAL_COST',
                title='Cost Distribution by Query Type'
            )
            st.plotly_chart(type_pie, use_container_width=True)

        with col_table:
            st.markdown("#### Query Type Summary")
            type_display = query_cost_by_type.copy()
            type_display['TOTAL_COST'] = type_display['TOTAL_COST'].apply(utils.format_currency)
            type_display['QUERY_COUNT'] = type_display['QUERY_COUNT'].apply(utils.format_number)
            type_display['AVG_COST'] = (
                query_cost_by_type['TOTAL_COST'] / query_cost_by_type['QUERY_COUNT']
            ).apply(utils.format_currency)
            st.dataframe(type_display, use_container_width=True, hide_index=True)
    else:
        st.info("No query type data available")

    st.markdown("---")

    # Optimization Candidates
    st.markdown("### 💡 Optimization Candidates (Cost > $10)")

    high_cost_queries = expensive_queries[expensive_queries['QUERY_COST'] > 10].copy()

    if not high_cost_queries.empty:
        st.warning(f"⚠️ {len(high_cost_queries)} queries identified with cost >$10. "
                  f"Combined cost: {utils.format_currency(high_cost_queries['QUERY_COST'].sum())}")

        # Group by user
        high_cost_by_user = high_cost_queries.groupby('USER_NAME').agg({
            'QUERY_COST': ['sum', 'count']
        }).reset_index()

        high_cost_by_user.columns = ['USER_NAME', 'TOTAL_COST', 'QUERY_COUNT']
        high_cost_by_user = high_cost_by_user.sort_values('TOTAL_COST', ascending=False)

        col1, col2 = st.columns(2)

        with col1:
            st.markdown("#### By User")
            user_opt_display = high_cost_by_user.head(10).copy()
            user_opt_display['TOTAL_COST'] = user_opt_display['TOTAL_COST'].apply(utils.format_currency)
            user_opt_display['QUERY_COUNT'] = user_opt_display['QUERY_COUNT'].apply(utils.format_number)
            st.dataframe(user_opt_display, use_container_width=True, hide_index=True)

        with col2:
            # Group by warehouse
            high_cost_by_wh = high_cost_queries.groupby('WAREHOUSE_NAME').agg({
                'QUERY_COST': ['sum', 'count']
            }).reset_index()

            high_cost_by_wh.columns = ['WAREHOUSE_NAME', 'TOTAL_COST', 'QUERY_COUNT']
            high_cost_by_wh = high_cost_by_wh.sort_values('TOTAL_COST', ascending=False)

            st.markdown("#### By Warehouse")
            wh_opt_display = high_cost_by_wh.head(10).copy()
            wh_opt_display['TOTAL_COST'] = wh_opt_display['TOTAL_COST'].apply(utils.format_currency)
            wh_opt_display['QUERY_COUNT'] = wh_opt_display['QUERY_COUNT'].apply(utils.format_number)
            st.dataframe(wh_opt_display, use_container_width=True, hide_index=True)

        # Detailed list
        with st.expander("📋 View All High-Cost Queries"):
            high_cost_display = high_cost_queries[[
                'QUERY_ID', 'USER_NAME', 'WAREHOUSE_NAME', 'QUERY_TYPE', 'QUERY_COST', 'EXECUTION_TIME_SEC', 'START_TIME'
            ]].copy()

            high_cost_display['QUERY_COST'] = high_cost_display['QUERY_COST'].apply(utils.format_currency)
            high_cost_display['EXECUTION_TIME_SEC'] = high_cost_display['EXECUTION_TIME_SEC'].apply(lambda x: f"{x:.2f}s")
            high_cost_display['START_TIME'] = pd.to_datetime(high_cost_display['START_TIME']).dt.strftime('%Y-%m-%d %H:%M')

            st.dataframe(high_cost_display, use_container_width=True, hide_index=True)
    else:
        st.success("✅ No queries with cost >$10 found. Excellent cost efficiency!")

    st.markdown("---")

    # Export section
    st.markdown("### 📥 Export Data")
    col1, col2, col3 = st.columns(3)

    with col1:
        if not expensive_queries.empty:
            utils.export_to_csv(expensive_queries, "expensive_queries")

    with col2:
        if not query_cost_by_user.empty:
            utils.export_to_csv(query_cost_by_user, "query_cost_by_user")

    with col3:
        if not query_cost_by_type.empty:
            utils.export_to_csv(query_cost_by_type, "query_cost_by_type")

except Exception as e:
    st.error(f"Error loading query cost analysis: {str(e)}")
    st.exception(e)
