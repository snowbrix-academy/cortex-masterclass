"""
Warehouse Analytics Page

Detailed warehouse utilization, performance, and cost analysis.
Provides insights into warehouse efficiency and optimization opportunities.
"""

import streamlit as st
import pandas as pd
from datetime import datetime
from components import data, filters, charts, utils

# Page configuration
st.set_page_config(page_title="Warehouse Analytics", layout="wide", page_icon="🏢")

st.title("🏢 Warehouse Analytics")
st.markdown("Detailed warehouse utilization and efficiency analysis")
st.markdown("---")

# Sidebar filters
start_date, end_date = filters.render_date_range_filter(default_days=30, key_prefix="warehouse")

if not utils.validate_date_range(start_date, end_date):
    st.stop()

selected_warehouses = filters.render_warehouse_filter(key_prefix="warehouse", multiselect=True)
environments = filters.render_environment_filter(key_prefix="warehouse")

if filters.render_refresh_button(key_prefix="warehouse"):
    st.cache_data.clear()
    st.rerun()

# Main content
try:
    with utils.show_loading_spinner("Loading warehouse analytics..."):
        # Fetch data
        warehouse_costs = data.get_warehouse_cost_detail(start_date, end_date)

        # Filter by selected warehouses
        if selected_warehouses:
            warehouse_costs = warehouse_costs[
                warehouse_costs['WAREHOUSE_NAME'].isin(selected_warehouses)
            ]

        warehouse_utilization = data.get_warehouse_utilization(start_date, end_date)
        if selected_warehouses:
            warehouse_utilization = warehouse_utilization[
                warehouse_utilization['WAREHOUSE_NAME'].isin(selected_warehouses)
            ]

        idle_time_data = data.get_warehouse_idle_time(start_date, end_date)
        if selected_warehouses:
            idle_time_data = idle_time_data[
                idle_time_data['WAREHOUSE_NAME'].isin(selected_warehouses)
            ]

    # Check if data is available
    if warehouse_costs.empty:
        utils.create_empty_state("No warehouse data available for the selected filters")
        st.stop()

    # Calculate summary metrics
    total_cost = warehouse_costs['TOTAL_COST'].sum()
    total_credits = warehouse_costs['TOTAL_CREDITS'].sum()
    total_warehouses = warehouse_costs['WAREHOUSE_NAME'].nunique()

    avg_cost_per_warehouse = total_cost / total_warehouses if total_warehouses > 0 else 0

    # Calculate idle time percentage
    if not idle_time_data.empty:
        total_idle_minutes = idle_time_data['IDLE_MINUTES'].sum()
        total_active_minutes = idle_time_data['ACTIVE_MINUTES'].sum()
        total_minutes = total_idle_minutes + total_active_minutes
        idle_pct = (total_idle_minutes / total_minutes * 100) if total_minutes > 0 else 0
    else:
        idle_pct = 0

    # KPI Row
    st.markdown("### Warehouse Summary")
    col1, col2, col3, col4 = st.columns(4)

    with col1:
        utils.show_metric_card(
            label="Total Warehouse Cost",
            value=utils.format_currency(total_cost),
            help_text=f"Total cost across {total_warehouses} warehouses"
        )

    with col2:
        utils.show_metric_card(
            label="Average Cost per Warehouse",
            value=utils.format_currency(avg_cost_per_warehouse),
            help_text="Mean cost per warehouse in the selected period"
        )

    with col3:
        utils.show_metric_card(
            label="Total Credits Used",
            value=utils.format_credits(total_credits),
            help_text="Sum of all warehouse credits consumed"
        )

    with col4:
        idle_color = "WARNING" if idle_pct > 20 else "OK" if idle_pct > 10 else "OK"
        st.metric(
            label="Idle Time %",
            value=f"{idle_pct:.1f}%",
            help="Percentage of time warehouses were idle but not suspended"
        )
        st.markdown(utils.show_alert_badge(
            "WARNING" if idle_pct > 20 else "INFO",
            f"{idle_pct:.1f}% idle"
        ), unsafe_allow_html=True)

    st.markdown("---")

    # Warehouse selector for detailed view
    st.markdown("### Warehouse Details")
    warehouse_list = sorted(warehouse_costs['WAREHOUSE_NAME'].unique().tolist())

    selected_warehouse_detail = st.selectbox(
        "Select warehouse for detailed view",
        options=warehouse_list,
        key="warehouse_detail_selector"
    )

    if selected_warehouse_detail:
        # Filter data for selected warehouse
        wh_data = warehouse_costs[
            warehouse_costs['WAREHOUSE_NAME'] == selected_warehouse_detail
        ]

        wh_util_data = warehouse_utilization[
            warehouse_utilization['WAREHOUSE_NAME'] == selected_warehouse_detail
        ]

        wh_idle_data = idle_time_data[
            idle_time_data['WAREHOUSE_NAME'] == selected_warehouse_detail
        ]

        col1, col2, col3, col4 = st.columns(4)

        with col1:
            wh_cost = wh_data['TOTAL_COST'].sum()
            st.metric("Warehouse Cost", utils.format_currency(wh_cost))

        with col2:
            wh_credits = wh_data['TOTAL_CREDITS'].sum()
            st.metric("Credits Used", utils.format_credits(wh_credits))

        with col3:
            wh_queries = wh_data['QUERY_COUNT'].sum() if 'QUERY_COUNT' in wh_data.columns else 0
            st.metric("Total Queries", utils.format_number(wh_queries))

        with col4:
            if not wh_idle_data.empty:
                wh_idle_min = wh_idle_data['IDLE_MINUTES'].sum()
                wh_active_min = wh_idle_data['ACTIVE_MINUTES'].sum()
                wh_total_min = wh_idle_min + wh_active_min
                wh_idle_pct = (wh_idle_min / wh_total_min * 100) if wh_total_min > 0 else 0
                st.metric("Idle %", f"{wh_idle_pct:.1f}%")
            else:
                st.metric("Idle %", "N/A")

        # Warehouse utilization chart over time
        if not wh_data.empty and 'USAGE_DATE' in wh_data.columns:
            st.markdown("#### Cost Trend")
            wh_trend = charts.create_spend_trend_chart(
                wh_data,
                date_col='USAGE_DATE',
                value_col='TOTAL_COST',
                title=f'{selected_warehouse_detail} - Daily Cost'
            )
            st.plotly_chart(wh_trend, use_container_width=True)

    st.markdown("---")

    # Utilization Heatmap
    st.markdown("### ⏰ Utilization Heatmap")
    if not warehouse_utilization.empty:
        # Check if we have the required columns for heatmap
        if all(col in warehouse_utilization.columns for col in ['HOUR_OF_DAY', 'DAY_OF_WEEK', 'CREDITS_USED']):
            heatmap = charts.create_warehouse_utilization_heatmap(warehouse_utilization)
            st.plotly_chart(heatmap, use_container_width=True)

            st.info("💡 **Insight:** Peak usage hours indicate optimal times for scheduled jobs. "
                   "Consider consolidating workloads during off-peak hours to reduce multi-cluster costs.")
        else:
            st.warning("Utilization heatmap data not available. Ensure warehouse metering is enabled.")
    else:
        st.info("No utilization pattern data available")

    st.markdown("---")

    # Idle Time Analysis
    st.markdown("### 💤 Idle Time Analysis")
    if not idle_time_data.empty:
        col_chart, col_table = st.columns([2, 1])

        with col_chart:
            # Create idle percentage for each warehouse
            idle_time_data['IDLE_PCT'] = (
                idle_time_data['IDLE_MINUTES'] /
                (idle_time_data['IDLE_MINUTES'] + idle_time_data['ACTIVE_MINUTES']) * 100
            )

            idle_bar = charts.create_top_spenders_bar(
                idle_time_data.nlargest(15, 'IDLE_PCT'),
                category_col='WAREHOUSE_NAME',
                value_col='IDLE_PCT',
                title='Warehouses with Highest Idle Time %',
                horizontal=True
            )
            st.plotly_chart(idle_bar, use_container_width=True)

        with col_table:
            st.markdown("#### Top Idle Warehouses")
            idle_display = idle_time_data.nlargest(10, 'IDLE_PCT')[
                ['WAREHOUSE_NAME', 'IDLE_PCT']
            ].copy()
            idle_display['IDLE_PCT'] = idle_display['IDLE_PCT'].apply(lambda x: f"{x:.1f}%")
            st.dataframe(idle_display, use_container_width=True, hide_index=True)

        st.warning("⚠️ **Recommendation:** Warehouses with >20% idle time should have auto-suspend "
                  "adjusted to 60-120 seconds. Idle time represents wasted compute cost.")
    else:
        st.info("No idle time data available")

    st.markdown("---")

    # Warehouse Cost Comparison
    st.markdown("### 💰 Cost by Warehouse")
    if not warehouse_costs.empty:
        # Aggregate by warehouse
        wh_summary = warehouse_costs.groupby('WAREHOUSE_NAME').agg({
            'TOTAL_COST': 'sum',
            'TOTAL_CREDITS': 'sum',
            'QUERY_COUNT': 'sum' if 'QUERY_COUNT' in warehouse_costs.columns else 'count'
        }).reset_index()

        wh_summary = wh_summary.sort_values('TOTAL_COST', ascending=False)

        col_chart, col_table = st.columns([2, 1])

        with col_chart:
            wh_bar = charts.create_top_spenders_bar(
                wh_summary.head(15),
                category_col='WAREHOUSE_NAME',
                value_col='TOTAL_COST',
                title='Top Warehouses by Cost',
                horizontal=True
            )
            st.plotly_chart(wh_bar, use_container_width=True)

        with col_table:
            st.markdown("#### Cost Summary")
            wh_display = wh_summary.head(10).copy()
            wh_display['TOTAL_COST'] = wh_display['TOTAL_COST'].apply(utils.format_currency)
            wh_display['TOTAL_CREDITS'] = wh_display['TOTAL_CREDITS'].apply(utils.format_credits)
            wh_display['QUERY_COUNT'] = wh_display['QUERY_COUNT'].apply(utils.format_number)
            st.dataframe(wh_display, use_container_width=True, hide_index=True)

    st.markdown("---")

    # Efficiency Metrics Table
    st.markdown("### 📊 Warehouse Efficiency Metrics")

    if not warehouse_costs.empty:
        # Calculate efficiency metrics
        wh_efficiency = warehouse_costs.groupby('WAREHOUSE_NAME').agg({
            'TOTAL_COST': 'sum',
            'TOTAL_CREDITS': 'sum',
            'QUERY_COUNT': 'sum' if 'QUERY_COUNT' in warehouse_costs.columns else 'count'
        }).reset_index()

        wh_efficiency['COST_PER_QUERY'] = (
            wh_efficiency['TOTAL_COST'] / wh_efficiency['QUERY_COUNT']
        ).round(4)

        wh_efficiency['AVG_DAILY_COST'] = (
            wh_efficiency['TOTAL_COST'] / (end_date - start_date).days
        ).round(2)

        # Add idle time if available
        if not idle_time_data.empty:
            idle_summary = idle_time_data.groupby('WAREHOUSE_NAME').agg({
                'IDLE_MINUTES': 'sum',
                'ACTIVE_MINUTES': 'sum'
            }).reset_index()

            idle_summary['IDLE_PCT'] = (
                idle_summary['IDLE_MINUTES'] /
                (idle_summary['IDLE_MINUTES'] + idle_summary['ACTIVE_MINUTES']) * 100
            ).round(1)

            wh_efficiency = wh_efficiency.merge(
                idle_summary[['WAREHOUSE_NAME', 'IDLE_PCT']],
                on='WAREHOUSE_NAME',
                how='left'
            )

        # Format for display
        display_efficiency = wh_efficiency.copy()
        display_efficiency['TOTAL_COST'] = display_efficiency['TOTAL_COST'].apply(utils.format_currency)
        display_efficiency['TOTAL_CREDITS'] = display_efficiency['TOTAL_CREDITS'].apply(utils.format_credits)
        display_efficiency['QUERY_COUNT'] = display_efficiency['QUERY_COUNT'].apply(utils.format_number)
        display_efficiency['COST_PER_QUERY'] = display_efficiency['COST_PER_QUERY'].apply(
            lambda x: f"${x:.4f}"
        )
        display_efficiency['AVG_DAILY_COST'] = display_efficiency['AVG_DAILY_COST'].apply(utils.format_currency)

        if 'IDLE_PCT' in display_efficiency.columns:
            display_efficiency['IDLE_PCT'] = display_efficiency['IDLE_PCT'].apply(
                lambda x: f"{x:.1f}%" if pd.notna(x) else "N/A"
            )

        st.dataframe(display_efficiency, use_container_width=True, hide_index=True)

    st.markdown("---")

    # Auto-Suspend Recommendations
    st.markdown("### 💡 Auto-Suspend Recommendations")

    if not idle_time_data.empty:
        # Identify warehouses with high idle time
        high_idle = idle_time_data[idle_time_data['IDLE_PCT'] > 15].copy()

        if not high_idle.empty:
            st.warning(f"⚠️ {len(high_idle)} warehouses have idle time >15%. Consider adjusting auto-suspend settings.")

            high_idle_display = high_idle[['WAREHOUSE_NAME', 'IDLE_PCT', 'IDLE_MINUTES']].copy()
            high_idle_display['IDLE_PCT'] = high_idle_display['IDLE_PCT'].apply(lambda x: f"{x:.1f}%")
            high_idle_display['IDLE_MINUTES'] = high_idle_display['IDLE_MINUTES'].apply(utils.format_number)
            high_idle_display['RECOMMENDATION'] = "Reduce auto-suspend to 60-120 seconds"

            st.dataframe(high_idle_display, use_container_width=True, hide_index=True)

            # Calculate potential savings
            high_idle_cost = warehouse_costs[
                warehouse_costs['WAREHOUSE_NAME'].isin(high_idle['WAREHOUSE_NAME'])
            ]['TOTAL_COST'].sum()

            potential_savings = high_idle_cost * (high_idle['IDLE_PCT'].mean() / 100)

            st.success(f"💰 **Potential Monthly Savings:** {utils.format_currency(potential_savings)} "
                      f"by optimizing auto-suspend settings")
        else:
            st.success("✅ All warehouses have acceptable idle time (<15%)")
    else:
        st.info("Enable idle time tracking to see recommendations")

    st.markdown("---")

    # Export section
    st.markdown("### 📥 Export Data")
    col1, col2, col3 = st.columns(3)

    with col1:
        if not warehouse_costs.empty:
            utils.export_to_csv(warehouse_costs, "warehouse_costs")

    with col2:
        if not idle_time_data.empty:
            utils.export_to_csv(idle_time_data, "warehouse_idle_time")

    with col3:
        if 'wh_efficiency' in locals() and not wh_efficiency.empty:
            utils.export_to_excel(wh_efficiency, "warehouse_efficiency")

except Exception as e:
    st.error(f"Error loading warehouse analytics: {str(e)}")
    st.exception(e)
