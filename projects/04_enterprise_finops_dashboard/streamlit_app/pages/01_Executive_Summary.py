"""
Executive Summary Page

High-level KPIs and cost overview for C-level and senior leadership.
Provides at-a-glance view of spend trends, top spenders, and cost breakdown.
"""

import streamlit as st
import pandas as pd
from datetime import datetime, timedelta
from components import data, filters, charts, utils

# Page configuration
st.set_page_config(page_title="Executive Summary", layout="wide", page_icon="📊")

st.title("📊 Executive Summary")
st.markdown("High-level cost overview and key performance indicators")
st.markdown("---")

# Sidebar filters
start_date, end_date = filters.render_date_range_filter(default_days=30, key_prefix="exec")

if not utils.validate_date_range(start_date, end_date):
    st.stop()

environments = filters.render_environment_filter(key_prefix="exec")

if filters.render_refresh_button(key_prefix="exec"):
    st.cache_data.clear()
    st.rerun()

# Main content
try:
    with utils.show_loading_spinner("Loading executive summary..."):
        # Fetch data
        daily_costs = data.get_daily_cost_summary(start_date, end_date)
        cost_by_type = data.get_cost_by_type(start_date, end_date)
        top_warehouses = data.get_top_warehouses_by_cost(start_date, end_date, limit=10)
        top_users = data.get_top_users_by_cost(start_date, end_date, limit=10)
        cost_by_entity = data.get_cost_by_entity(start_date, end_date)

    # Check if data is available
    if daily_costs.empty:
        utils.create_empty_state("No cost data available for the selected period")
        st.stop()

    # Calculate KPIs
    total_cost = daily_costs['TOTAL_COST'].sum()
    total_credits = daily_costs['TOTAL_CREDITS'].sum()

    # Calculate previous period for comparison
    days_diff = (end_date - start_date).days
    prev_start = start_date - timedelta(days=days_diff)
    prev_end = start_date - timedelta(days=1)

    prev_costs = data.get_daily_cost_summary(prev_start, prev_end)
    prev_total_cost = prev_costs['TOTAL_COST'].sum() if not prev_costs.empty else 0

    # Calculate deltas
    cost_delta_val, cost_delta_pct = utils.calculate_delta(total_cost, prev_total_cost)

    # Calculate unallocated percentage
    if not cost_by_entity.empty:
        unallocated_cost = cost_by_entity[
            cost_by_entity['ENTITY_NAME'] == 'UNALLOCATED'
        ]['TOTAL_COST'].sum()
        unallocated_pct = (unallocated_cost / total_cost) if total_cost > 0 else 0
    else:
        unallocated_pct = 0

    # Top warehouse and user
    top_warehouse = top_warehouses.iloc[0]['WAREHOUSE_NAME'] if not top_warehouses.empty else "N/A"
    top_warehouse_cost = top_warehouses.iloc[0]['TOTAL_COST'] if not top_warehouses.empty else 0

    top_user = top_users.iloc[0]['USER_NAME'] if not top_users.empty else "N/A"
    top_user_cost = top_users.iloc[0]['TOTAL_COST'] if not top_users.empty else 0

    # KPI Row
    st.markdown("### Key Performance Indicators")
    col1, col2, col3, col4, col5 = st.columns(5)

    with col1:
        utils.show_metric_card(
            label="Total Spend",
            value=utils.format_currency(total_cost),
            delta=cost_delta_pct,
            delta_label="vs previous period",
            help_text=f"Total cost from {start_date} to {end_date}"
        )

    with col2:
        utils.show_metric_card(
            label="Total Credits Used",
            value=utils.format_credits(total_credits),
            help_text="Sum of all compute, cloud services, and serverless credits"
        )

    with col3:
        # Unallocated percentage badge
        if unallocated_pct > 0.10:
            badge_type = "WARNING"
        elif unallocated_pct > 0.05:
            badge_type = "INFO"
        else:
            badge_type = "OK"

        st.metric(
            label="Unallocated Costs",
            value=utils.format_percentage(unallocated_pct),
            help="Percentage of costs not attributed to any entity"
        )
        st.markdown(utils.show_alert_badge(badge_type), unsafe_allow_html=True)

    with col4:
        st.metric(
            label="Top Warehouse",
            value=top_warehouse,
            delta=utils.format_currency(top_warehouse_cost),
            help="Highest spending warehouse in the period"
        )

    with col5:
        st.metric(
            label="Top User",
            value=top_user,
            delta=utils.format_currency(top_user_cost),
            help="Highest spending user in the period"
        )

    st.markdown("---")

    # Charts section
    col_left, col_right = st.columns(2)

    with col_left:
        st.markdown("### 📈 Cost Trend (30-Day)")
        if not daily_costs.empty:
            trend_chart = charts.create_spend_trend_chart(
                daily_costs,
                date_col='USAGE_DATE',
                value_col='TOTAL_COST',
                title='Daily Cost Trend'
            )
            st.plotly_chart(trend_chart, use_container_width=True)
        else:
            st.info("No trend data available")

    with col_right:
        st.markdown("### 🎯 Cost Breakdown by Type")
        if not cost_by_type.empty:
            pie_chart = charts.create_cost_breakdown_pie(
                cost_by_type,
                labels_col='COST_TYPE',
                values_col='TOTAL_COST',
                title='Cost by Type'
            )
            st.plotly_chart(pie_chart, use_container_width=True)
        else:
            st.info("No cost type data available")

    st.markdown("---")

    # Top Spenders Section
    col_warehouses, col_users = st.columns(2)

    with col_warehouses:
        st.markdown("### 🏢 Top 10 Warehouses by Cost")
        if not top_warehouses.empty:
            bar_chart = charts.create_top_spenders_bar(
                top_warehouses,
                category_col='WAREHOUSE_NAME',
                value_col='TOTAL_COST',
                title='Top Warehouses',
                limit=10,
                horizontal=True
            )
            st.plotly_chart(bar_chart, use_container_width=True)

            # Data table
            with st.expander("📋 View Detailed Table"):
                display_df = top_warehouses.copy()
                display_df['TOTAL_COST'] = display_df['TOTAL_COST'].apply(utils.format_currency)
                display_df['TOTAL_CREDITS'] = display_df['TOTAL_CREDITS'].apply(utils.format_credits)
                st.dataframe(display_df, use_container_width=True, hide_index=True)
        else:
            st.info("No warehouse data available")

    with col_users:
        st.markdown("### 👤 Top 10 Users by Cost")
        if not top_users.empty:
            bar_chart = charts.create_top_spenders_bar(
                top_users,
                category_col='USER_NAME',
                value_col='TOTAL_COST',
                title='Top Users',
                limit=10,
                horizontal=True
            )
            st.plotly_chart(bar_chart, use_container_width=True)

            # Data table
            with st.expander("📋 View Detailed Table"):
                display_df = top_users.copy()
                display_df['TOTAL_COST'] = display_df['TOTAL_COST'].apply(utils.format_currency)
                display_df['QUERY_COUNT'] = display_df['QUERY_COUNT'].apply(lambda x: utils.format_number(x))
                st.dataframe(display_df, use_container_width=True, hide_index=True)
        else:
            st.info("No user data available")

    st.markdown("---")

    # Entity Hierarchy Treemap
    st.markdown("### 🏛️ Cost by Entity Hierarchy")
    if not cost_by_entity.empty and 'BUSINESS_UNIT' in cost_by_entity.columns:
        # Filter out unallocated for cleaner visualization
        entity_data = cost_by_entity[cost_by_entity['ENTITY_NAME'] != 'UNALLOCATED'].copy()

        if not entity_data.empty:
            # Prepare data for treemap (need hierarchy columns)
            treemap_data = []
            for _, row in entity_data.iterrows():
                treemap_data.append({
                    'BUSINESS_UNIT': row.get('BUSINESS_UNIT', 'Unknown'),
                    'DEPARTMENT': row.get('DEPARTMENT', row['ENTITY_NAME']),
                    'TEAM': row.get('TEAM', row['ENTITY_NAME']),
                    'TOTAL_COST': row['TOTAL_COST']
                })

            treemap_df = pd.DataFrame(treemap_data)

            treemap_chart = charts.create_entity_treemap(
                treemap_df,
                path_cols=['BUSINESS_UNIT', 'DEPARTMENT', 'TEAM'],
                value_col='TOTAL_COST'
            )
            st.plotly_chart(treemap_chart, use_container_width=True)
        else:
            st.info("All costs are unallocated. Configure entity mappings to see hierarchy.")
    else:
        st.info("Entity hierarchy data not available. Configure entities in Admin Config.")

    st.markdown("---")

    # Cost Summary Table
    st.markdown("### 📊 Detailed Cost Summary")

    summary_data = {
        'Metric': [
            'Total Cost',
            'Average Daily Cost',
            'Peak Daily Cost',
            'Total Credits Used',
            'Compute Cost',
            'Storage Cost',
            'Cloud Services Cost',
            'Unallocated Cost',
            'Number of Warehouses',
            'Number of Active Users',
            'Total Queries Executed'
        ],
        'Value': [
            utils.format_currency(total_cost),
            utils.format_currency(daily_costs['TOTAL_COST'].mean()) if not daily_costs.empty else "$0",
            utils.format_currency(daily_costs['TOTAL_COST'].max()) if not daily_costs.empty else "$0",
            utils.format_credits(total_credits),
            utils.format_currency(cost_by_type[cost_by_type['COST_TYPE'] == 'COMPUTE']['TOTAL_COST'].sum()) if not cost_by_type.empty else "$0",
            utils.format_currency(cost_by_type[cost_by_type['COST_TYPE'] == 'STORAGE']['TOTAL_COST'].sum()) if not cost_by_type.empty else "$0",
            utils.format_currency(cost_by_type[cost_by_type['COST_TYPE'] == 'CLOUD_SERVICES']['TOTAL_COST'].sum()) if not cost_by_type.empty else "$0",
            utils.format_currency(unallocated_cost) if not cost_by_entity.empty else "$0",
            utils.format_number(len(top_warehouses)),
            utils.format_number(len(top_users)),
            utils.format_number(daily_costs['QUERY_COUNT'].sum()) if 'QUERY_COUNT' in daily_costs.columns else "N/A"
        ]
    }

    summary_df = pd.DataFrame(summary_data)
    st.dataframe(summary_df, use_container_width=True, hide_index=True)

    st.markdown("---")

    # Export section
    st.markdown("### 📥 Export Data")
    col1, col2, col3 = st.columns(3)

    with col1:
        if not daily_costs.empty:
            utils.export_to_csv(daily_costs, "daily_cost_summary")

    with col2:
        if not top_warehouses.empty:
            utils.export_to_csv(top_warehouses, "top_warehouses")

    with col3:
        if not top_users.empty:
            utils.export_to_csv(top_users, "top_users")

except Exception as e:
    st.error(f"Error loading executive summary: {str(e)}")
    st.exception(e)
