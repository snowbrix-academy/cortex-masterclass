"""
Chargeback Report Page

Entity-level cost attribution and chargeback reporting.
Provides drill-down capability from business unit to team level.
"""

import streamlit as st
import pandas as pd
from datetime import datetime, timedelta
from components import data, filters, charts, utils

# Page configuration
st.set_page_config(page_title="Chargeback Report", layout="wide", page_icon="💰")

st.title("💰 Chargeback Report")
st.markdown("Cost attribution and chargeback by entity hierarchy")
st.markdown("---")

# Sidebar filters
start_date, end_date = filters.render_date_range_filter(default_days=30, key_prefix="chargeback")

if not utils.validate_date_range(start_date, end_date):
    st.stop()

period = filters.render_period_selector(key_prefix="chargeback")

# Entity filter with drill-down
selected_entity_id = filters.render_entity_filter(key_prefix="chargeback")

if filters.render_refresh_button(key_prefix="chargeback"):
    st.cache_data.clear()
    st.rerun()

# Main content
try:
    with utils.show_loading_spinner("Loading chargeback report..."):
        # Fetch entity hierarchy
        entity_hierarchy = data.get_entity_hierarchy()

        # Fetch cost data
        cost_by_entity = data.get_cost_by_entity(start_date, end_date)

        # Fetch cost trend by entity
        cost_trend_by_entity = data.get_cost_trend_by_entity(start_date, end_date, period)

    # Check if data is available
    if cost_by_entity.empty:
        utils.create_empty_state("No chargeback data available. Configure entity mappings in Admin Config.")
        st.stop()

    # Calculate summary metrics
    total_allocated_cost = cost_by_entity[
        cost_by_entity['ENTITY_NAME'] != 'UNALLOCATED'
    ]['TOTAL_COST'].sum()

    unallocated_cost = cost_by_entity[
        cost_by_entity['ENTITY_NAME'] == 'UNALLOCATED'
    ]['TOTAL_COST'].sum()

    total_cost = total_allocated_cost + unallocated_cost
    allocation_rate = (total_allocated_cost / total_cost * 100) if total_cost > 0 else 0

    num_entities = cost_by_entity[cost_by_entity['ENTITY_NAME'] != 'UNALLOCATED']['ENTITY_NAME'].nunique()

    # KPI Row
    st.markdown("### Chargeback Summary")
    col1, col2, col3, col4 = st.columns(4)

    with col1:
        utils.show_metric_card(
            label="Total Cost",
            value=utils.format_currency(total_cost),
            help_text="Total cost across all entities"
        )

    with col2:
        utils.show_metric_card(
            label="Allocated Cost",
            value=utils.format_currency(total_allocated_cost),
            help_text="Cost successfully attributed to entities"
        )

    with col3:
        badge_type = "OK" if allocation_rate > 95 else "WARNING" if allocation_rate > 85 else "CRITICAL"
        st.metric(
            label="Allocation Rate",
            value=f"{allocation_rate:.1f}%",
            help="Percentage of costs successfully allocated"
        )
        st.markdown(utils.show_alert_badge(badge_type, f"{allocation_rate:.1f}% allocated"), unsafe_allow_html=True)

    with col4:
        utils.show_metric_card(
            label="Active Entities",
            value=utils.format_number(num_entities),
            help_text="Number of entities with cost attribution"
        )

    st.markdown("---")

    # Entity hierarchy navigation
    st.markdown("### 🏛️ Entity Hierarchy Navigation")

    # Show breadcrumb if entity is selected
    if selected_entity_id and not entity_hierarchy.empty:
        entity_info = entity_hierarchy[entity_hierarchy['ENTITY_ID'] == selected_entity_id]

        if not entity_info.empty:
            entity_row = entity_info.iloc[0]
            breadcrumb = f"Home > {entity_row.get('BUSINESS_UNIT', 'N/A')}"

            if entity_row['ENTITY_TYPE'] in ['DEPT', 'TEAM']:
                breadcrumb += f" > {entity_row.get('DEPARTMENT', entity_row['ENTITY_NAME'])}"

            if entity_row['ENTITY_TYPE'] == 'TEAM':
                breadcrumb += f" > {entity_row['ENTITY_NAME']}"

            st.markdown(f"**Current View:** {breadcrumb}")

    # Filter cost data by selected entity
    if selected_entity_id:
        # Get all child entities
        selected_entities = [selected_entity_id]

        # Add children
        if not entity_hierarchy.empty:
            children = entity_hierarchy[entity_hierarchy['PARENT_ENTITY_ID'] == selected_entity_id]
            selected_entities.extend(children['ENTITY_ID'].tolist())

            # Add grandchildren if any
            for child_id in children['ENTITY_ID'].tolist():
                grandchildren = entity_hierarchy[entity_hierarchy['PARENT_ENTITY_ID'] == child_id]
                selected_entities.extend(grandchildren['ENTITY_ID'].tolist())

        # Filter data
        filtered_cost = cost_by_entity[cost_by_entity['ENTITY_ID'].isin(selected_entities)]
    else:
        filtered_cost = cost_by_entity.copy()

    # Cost breakdown by entity type
    st.markdown("### 💼 Cost by Entity Type")

    col_chart, col_table = st.columns([2, 1])

    with col_chart:
        # Aggregate by entity type
        if 'ENTITY_TYPE' in filtered_cost.columns:
            cost_by_type = filtered_cost.groupby('ENTITY_TYPE').agg({
                'TOTAL_COST': 'sum'
            }).reset_index()

            type_bar = charts.create_top_spenders_bar(
                cost_by_type,
                category_col='ENTITY_TYPE',
                value_col='TOTAL_COST',
                title='Cost by Entity Type',
                horizontal=False
            )
            st.plotly_chart(type_bar, use_container_width=True)
        else:
            st.info("Entity type data not available")

    with col_table:
        st.markdown("#### Summary by Type")
        if 'ENTITY_TYPE' in filtered_cost.columns:
            type_summary = filtered_cost.groupby('ENTITY_TYPE').agg({
                'TOTAL_COST': 'sum',
                'ENTITY_NAME': 'count'
            }).reset_index()

            type_summary.columns = ['ENTITY_TYPE', 'TOTAL_COST', 'ENTITY_COUNT']
            type_summary['TOTAL_COST'] = type_summary['TOTAL_COST'].apply(utils.format_currency)
            type_summary['ENTITY_COUNT'] = type_summary['ENTITY_COUNT'].apply(utils.format_number)

            st.dataframe(type_summary, use_container_width=True, hide_index=True)

    st.markdown("---")

    # Top entities table with sparklines
    st.markdown("### 📊 Cost by Entity (with Trend)")

    # Get top entities
    top_entities = filtered_cost.nlargest(20, 'TOTAL_COST').copy()

    if not top_entities.empty:
        # Create display table
        display_data = []

        for _, entity_row in top_entities.iterrows():
            entity_id = entity_row['ENTITY_ID']
            entity_name = entity_row['ENTITY_NAME']
            total_cost = entity_row['TOTAL_COST']

            # Get trend data for sparkline
            if not cost_trend_by_entity.empty:
                entity_trend = cost_trend_by_entity[
                    cost_trend_by_entity['ENTITY_ID'] == entity_id
                ].sort_values('PERIOD')

                trend_values = entity_trend['TOTAL_COST'].tolist() if not entity_trend.empty else []
            else:
                trend_values = []

            display_data.append({
                'Entity': entity_name,
                'Type': entity_row.get('ENTITY_TYPE', 'N/A'),
                'Total Cost': utils.format_currency(total_cost),
                'Trend': trend_values
            })

        display_df = pd.DataFrame(display_data)

        # Display without sparkline column first
        table_df = display_df[['Entity', 'Type', 'Total Cost']].copy()
        st.dataframe(table_df, use_container_width=True, hide_index=True)

        # Show sparklines in expander
        with st.expander("📈 View Cost Trends"):
            for idx, row in display_df.iterrows():
                if row['Trend'] and len(row['Trend']) > 1:
                    col1, col2 = st.columns([1, 3])
                    with col1:
                        st.markdown(f"**{row['Entity']}**")
                        st.markdown(f"{row['Total Cost']}")
                    with col2:
                        sparkline_fig = utils.create_sparkline(row['Trend'])
                        if sparkline_fig:
                            st.plotly_chart(sparkline_fig, use_container_width=True, key=f"sparkline_{idx}")
                    st.markdown("---")

    st.markdown("---")

    # Cost trend over time
    st.markdown("### 📈 Cost Trend Over Time")

    if not cost_trend_by_entity.empty:
        # Pivot data for multi-line chart
        trend_pivot = cost_trend_by_entity.pivot_table(
            index='PERIOD',
            columns='ENTITY_NAME',
            values='TOTAL_COST',
            aggfunc='sum'
        ).reset_index()

        # Get top 5 entities for clarity
        top_5_entities = filtered_cost.nlargest(5, 'TOTAL_COST')['ENTITY_NAME'].tolist()

        # Filter to top entities
        trend_cols = ['PERIOD'] + [col for col in trend_pivot.columns if col in top_5_entities]
        trend_data = trend_pivot[trend_cols].copy()

        if len(trend_data.columns) > 1:
            trend_chart = charts.create_multi_line_chart(
                trend_data,
                x_col='PERIOD',
                y_cols=[col for col in trend_data.columns if col != 'PERIOD'],
                title=f'Cost Trend by Entity ({period})'
            )
            st.plotly_chart(trend_chart, use_container_width=True)
        else:
            st.info("Not enough trend data available")
    else:
        st.info("Trend data not available")

    st.markdown("---")

    # Detailed entity table
    st.markdown("### 📋 Detailed Entity Breakdown")

    # Add search box
    search_term = st.text_input("🔍 Search entities", "", key="entity_search")

    if search_term:
        filtered_cost = filtered_cost[
            filtered_cost['ENTITY_NAME'].str.contains(search_term, case=False, na=False)
        ]

    # Prepare display table
    detail_columns = [
        'ENTITY_NAME',
        'ENTITY_TYPE',
        'TOTAL_COST',
        'COMPUTE_COST',
        'STORAGE_COST',
        'CLOUD_SERVICES_COST'
    ]

    detail_columns = [col for col in detail_columns if col in filtered_cost.columns]
    detail_df = filtered_cost[detail_columns].copy()

    # Format currency columns
    currency_cols = [col for col in detail_df.columns if 'COST' in col]
    for col in currency_cols:
        detail_df[col] = detail_df[col].apply(utils.format_currency)

    st.dataframe(detail_df, use_container_width=True, hide_index=True)

    st.markdown("---")

    # Top queries by entity
    st.markdown("### 🔍 Top Queries by Entity")

    if not top_entities.empty:
        entity_selector = st.selectbox(
            "Select entity to view top queries",
            options=top_entities['ENTITY_NAME'].tolist(),
            key="entity_query_selector"
        )

        if entity_selector:
            selected_entity = top_entities[top_entities['ENTITY_NAME'] == entity_selector].iloc[0]
            entity_id = selected_entity['ENTITY_ID']

            # Fetch queries for this entity
            try:
                entity_queries = data.get_queries_by_entity(start_date, end_date, entity_id, limit=20)

                if not entity_queries.empty:
                    query_display = entity_queries[[
                        'QUERY_ID',
                        'USER_NAME',
                        'WAREHOUSE_NAME',
                        'QUERY_TYPE',
                        'QUERY_COST',
                        'EXECUTION_TIME_SEC',
                        'START_TIME'
                    ]].copy()

                    query_display['QUERY_COST'] = query_display['QUERY_COST'].apply(utils.format_currency)
                    query_display['EXECUTION_TIME_SEC'] = query_display['EXECUTION_TIME_SEC'].apply(lambda x: f"{x:.2f}s")
                    query_display['START_TIME'] = pd.to_datetime(query_display['START_TIME']).dt.strftime('%Y-%m-%d %H:%M')

                    st.dataframe(query_display, use_container_width=True, hide_index=True)

                    # Expandable query detail
                    with st.expander("📄 View Query Details"):
                        query_id = st.selectbox(
                            "Select Query ID",
                            options=entity_queries['QUERY_ID'].tolist(),
                            key="entity_query_detail"
                        )

                        if query_id:
                            query_row = entity_queries[entity_queries['QUERY_ID'] == query_id].iloc[0]

                            col1, col2 = st.columns(2)
                            with col1:
                                st.markdown(f"**Cost:** {utils.format_currency(query_row['QUERY_COST'])}")
                                st.markdown(f"**User:** {query_row['USER_NAME']}")
                                st.markdown(f"**Warehouse:** {query_row['WAREHOUSE_NAME']}")

                            with col2:
                                st.markdown(f"**Execution Time:** {query_row['EXECUTION_TIME_SEC']:.2f}s")
                                st.markdown(f"**Query Type:** {query_row['QUERY_TYPE']}")
                                st.markdown(f"**Start Time:** {query_row['START_TIME']}")

                            if 'QUERY_TEXT' in query_row and pd.notna(query_row['QUERY_TEXT']):
                                st.markdown("**SQL Query:**")
                                st.code(query_row['QUERY_TEXT'], language='sql')
                else:
                    st.info(f"No queries found for {entity_selector}")
            except Exception as e:
                st.warning(f"Unable to load queries: {str(e)}")

    st.markdown("---")

    # Unallocated costs section
    if unallocated_cost > 0:
        st.markdown("### ⚠️ Unallocated Costs")

        col1, col2 = st.columns([1, 2])

        with col1:
            st.metric(
                label="Unallocated Amount",
                value=utils.format_currency(unallocated_cost),
                delta=f"{(unallocated_cost / total_cost * 100):.1f}% of total"
            )

        with col2:
            st.warning(
                "These costs are not attributed to any entity. "
                "Review warehouse and user mappings in Admin Config to improve allocation rate."
            )

    st.markdown("---")

    # Export section
    st.markdown("### 📥 Export Chargeback Report")

    col1, col2, col3 = st.columns(3)

    with col1:
        if not filtered_cost.empty:
            utils.export_to_csv(filtered_cost, "chargeback_report")

    with col2:
        if not filtered_cost.empty:
            utils.export_to_excel(filtered_cost, "chargeback_report", sheet_name="Chargeback")

    with col3:
        if not cost_trend_by_entity.empty:
            utils.export_to_csv(cost_trend_by_entity, "cost_trend_by_entity")

except Exception as e:
    st.error(f"Error loading chargeback report: {str(e)}")
    st.exception(e)
