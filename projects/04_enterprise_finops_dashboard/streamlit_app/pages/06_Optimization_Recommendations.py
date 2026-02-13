"""
Optimization Recommendations Page

AI-powered cost optimization recommendations with estimated savings.
Tracks implementation status and actual ROI.
"""

import streamlit as st
import pandas as pd
from datetime import datetime
from components import data, filters, charts, utils

# Page configuration
st.set_page_config(page_title="Optimization Recommendations", layout="wide", page_icon="💡")

st.title("💡 Optimization Recommendations")
st.markdown("Cost optimization opportunities and implementation tracking")
st.markdown("---")

# Sidebar filters
st.sidebar.markdown("### 🎯 Filters")

# Category filter
categories = [
    "IDLE_WAREHOUSE",
    "AUTO_SUSPEND",
    "WAREHOUSE_SIZING",
    "QUERY_OPTIMIZATION",
    "STORAGE_OPTIMIZATION",
    "CLUSTERING_OPTIMIZATION"
]

selected_categories = st.sidebar.multiselect(
    "Category",
    options=categories,
    default=[],
    key="opt_categories",
    help="Leave empty to show all categories"
)

if not selected_categories:
    selected_categories = categories

# Priority filter
priorities = ["HIGH", "MEDIUM", "LOW"]
selected_priorities = st.sidebar.multiselect(
    "Priority",
    options=priorities,
    default=["HIGH", "MEDIUM"],
    key="opt_priorities"
)

# Status filter
statuses = ["PENDING", "IN_PROGRESS", "IMPLEMENTED", "DISMISSED"]
selected_statuses = st.sidebar.multiselect(
    "Status",
    options=statuses,
    default=["PENDING", "IN_PROGRESS"],
    key="opt_statuses"
)

if filters.render_refresh_button(key_prefix="opt"):
    st.cache_data.clear()
    st.rerun()

# Main content
try:
    with utils.show_loading_spinner("Loading optimization recommendations..."):
        # Fetch recommendations
        recommendations = data.get_optimization_recommendations()

        # Filter by selected criteria
        if not recommendations.empty:
            recommendations = recommendations[
                (recommendations['CATEGORY'].isin(selected_categories)) &
                (recommendations['PRIORITY'].isin(selected_priorities)) &
                (recommendations['STATUS'].isin(selected_statuses))
            ]

    # Check if data is available
    if recommendations.empty:
        utils.create_empty_state("No recommendations found matching the selected filters")
        st.stop()

    # Calculate summary metrics
    total_recommendations = len(recommendations)
    pending_count = len(recommendations[recommendations['STATUS'] == 'PENDING'])
    implemented_count = len(recommendations[recommendations['STATUS'] == 'IMPLEMENTED'])

    total_estimated_savings = recommendations['ESTIMATED_MONTHLY_SAVINGS'].sum()
    high_priority_count = len(recommendations[recommendations['PRIORITY'] == 'HIGH'])

    # Calculate actual savings from implemented recommendations
    implemented_recs = recommendations[recommendations['STATUS'] == 'IMPLEMENTED']
    actual_savings = implemented_recs['ACTUAL_MONTHLY_SAVINGS'].sum() if 'ACTUAL_MONTHLY_SAVINGS' in implemented_recs.columns else 0

    # KPI Row
    st.markdown("### Optimization Summary")
    col1, col2, col3, col4, col5 = st.columns(5)

    with col1:
        utils.show_metric_card(
            label="Total Recommendations",
            value=utils.format_number(total_recommendations),
            help_text="Number of active recommendations"
        )

    with col2:
        utils.show_metric_card(
            label="Potential Monthly Savings",
            value=utils.format_currency(total_estimated_savings),
            help_text="Estimated savings if all implemented"
        )

    with col3:
        badge_type = "WARNING" if high_priority_count > 5 else "INFO"
        st.metric(
            label="High Priority",
            value=utils.format_number(high_priority_count),
            help="Number of high-priority recommendations"
        )
        st.markdown(utils.show_alert_badge(badge_type, f"{high_priority_count} items"), unsafe_allow_html=True)

    with col4:
        utils.show_metric_card(
            label="Pending",
            value=utils.format_number(pending_count),
            help_text="Recommendations awaiting action"
        )

    with col5:
        utils.show_metric_card(
            label="Implemented",
            value=utils.format_number(implemented_count),
            delta=utils.format_currency(actual_savings),
            delta_label="actual savings",
            help_text="Completed recommendations"
        )

    st.markdown("---")

    # Savings summary
    st.markdown("### 💰 Savings Potential by Category")

    col_chart, col_table = st.columns([2, 1])

    with col_chart:
        # Aggregate by category
        savings_by_category = recommendations.groupby('CATEGORY').agg({
            'ESTIMATED_MONTHLY_SAVINGS': 'sum',
            'RECOMMENDATION_ID': 'count'
        }).reset_index()

        savings_by_category.columns = ['CATEGORY', 'TOTAL_SAVINGS', 'COUNT']
        savings_by_category = savings_by_category.sort_values('TOTAL_SAVINGS', ascending=False)

        category_bar = charts.create_top_spenders_bar(
            savings_by_category,
            category_col='CATEGORY',
            value_col='TOTAL_SAVINGS',
            title='Potential Savings by Category',
            horizontal=True
        )
        st.plotly_chart(category_bar, use_container_width=True)

    with col_table:
        st.markdown("#### Category Summary")
        display_savings = savings_by_category.copy()
        display_savings['TOTAL_SAVINGS'] = display_savings['TOTAL_SAVINGS'].apply(utils.format_currency)
        display_savings['COUNT'] = display_savings['COUNT'].apply(utils.format_number)
        st.dataframe(display_savings, use_container_width=True, hide_index=True)

    st.markdown("---")

    # Recommendation cards
    st.markdown("### 📋 Detailed Recommendations")

    # Sort by priority and savings
    priority_order = {'HIGH': 0, 'MEDIUM': 1, 'LOW': 2}
    recommendations['PRIORITY_ORDER'] = recommendations['PRIORITY'].map(priority_order)
    recommendations = recommendations.sort_values(
        ['PRIORITY_ORDER', 'ESTIMATED_MONTHLY_SAVINGS'],
        ascending=[True, False]
    )

    for idx, rec in recommendations.iterrows():
        # Determine card color based on priority
        if rec['PRIORITY'] == 'HIGH':
            border_color = '#ff4444'
            priority_icon = '🔴'
        elif rec['PRIORITY'] == 'MEDIUM':
            border_color = '#ffaa00'
            priority_icon = '🟡'
        else:
            border_color = '#00cc66'
            priority_icon = '🟢'

        # Card container
        with st.container():
            st.markdown(f"""
            <div style="
                border-left: 4px solid {border_color};
                padding: 20px;
                margin-bottom: 20px;
                background-color: rgba(255, 255, 255, 0.05);
                border-radius: 5px;
            ">
            """, unsafe_allow_html=True)

            col1, col2, col3 = st.columns([3, 1, 1])

            with col1:
                st.markdown(f"### {priority_icon} {rec['TITLE']}")
                st.markdown(f"**Category:** {rec['CATEGORY'].replace('_', ' ').title()}")
                st.markdown(f"**Description:** {rec['DESCRIPTION']}")

                if 'TARGET_OBJECT' in rec and pd.notna(rec['TARGET_OBJECT']):
                    st.markdown(f"**Target:** `{rec['TARGET_OBJECT']}`")

            with col2:
                st.markdown("#### Estimated Savings")
                st.markdown(f"**{utils.format_currency(rec['ESTIMATED_MONTHLY_SAVINGS'])}/month**")
                st.markdown(f"**{utils.format_currency(rec['ESTIMATED_MONTHLY_SAVINGS'] * 12)}/year**")

                # Feasibility
                feasibility = rec.get('FEASIBILITY', 'MEDIUM')
                if feasibility == 'HIGH':
                    st.markdown("✅ **Easy to implement**")
                elif feasibility == 'MEDIUM':
                    st.markdown("🔧 **Moderate effort**")
                else:
                    st.markdown("⚠️ **Complex implementation**")

            with col3:
                st.markdown("#### Status")
                status = rec['STATUS']

                if status == 'PENDING':
                    st.markdown(utils.show_alert_badge('INFO', 'PENDING'), unsafe_allow_html=True)
                elif status == 'IN_PROGRESS':
                    st.markdown(utils.show_alert_badge('WARNING', 'IN PROGRESS'), unsafe_allow_html=True)
                elif status == 'IMPLEMENTED':
                    st.markdown(utils.show_alert_badge('OK', 'IMPLEMENTED'), unsafe_allow_html=True)
                else:
                    st.markdown(utils.show_alert_badge('INFO', 'DISMISSED'), unsafe_allow_html=True)

                # Action button
                rec_id = rec['RECOMMENDATION_ID']

                if status == 'PENDING':
                    if st.button("✅ Mark Implemented", key=f"impl_{rec_id}", use_container_width=True):
                        st.session_state[f'implement_{rec_id}'] = True
                        st.rerun()

                if status == 'PENDING' or status == 'IN_PROGRESS':
                    if st.button("❌ Dismiss", key=f"dismiss_{rec_id}", use_container_width=True):
                        st.session_state[f'dismiss_{rec_id}'] = True
                        st.rerun()

            st.markdown("</div>", unsafe_allow_html=True)

    st.markdown("---")

    # Implementation tracker
    st.markdown("### 📊 Implementation Tracker")

    col_chart, col_metrics = st.columns([2, 1])

    with col_chart:
        # Status breakdown
        status_counts = recommendations['STATUS'].value_counts().reset_index()
        status_counts.columns = ['STATUS', 'COUNT']

        status_pie = charts.create_cost_breakdown_pie(
            status_counts,
            labels_col='STATUS',
            values_col='COUNT',
            title='Recommendations by Status'
        )
        st.plotly_chart(status_pie, use_container_width=True)

    with col_metrics:
        st.markdown("#### Implementation Rate")

        total_recs = len(recommendations)
        impl_rate = (implemented_count / total_recs * 100) if total_recs > 0 else 0

        st.metric("Implementation Rate", f"{impl_rate:.1f}%")
        st.progress(impl_rate / 100)

        st.markdown("#### By Priority")
        for priority in ['HIGH', 'MEDIUM', 'LOW']:
            priority_recs = recommendations[recommendations['PRIORITY'] == priority]
            priority_impl = len(priority_recs[priority_recs['STATUS'] == 'IMPLEMENTED'])
            priority_total = len(priority_recs)

            if priority_total > 0:
                st.markdown(f"**{priority}:** {priority_impl}/{priority_total} ({priority_impl/priority_total*100:.0f}%)")

    st.markdown("---")

    # ROI Analysis
    st.markdown("### 💵 ROI Analysis")

    if implemented_count > 0:
        col1, col2, col3 = st.columns(3)

        with col1:
            st.markdown("#### Estimated vs Actual")
            estimated_impl = implemented_recs['ESTIMATED_MONTHLY_SAVINGS'].sum()
            actual_impl = actual_savings

            roi_data = pd.DataFrame({
                'Type': ['Estimated', 'Actual'],
                'Savings': [estimated_impl, actual_impl]
            })

            roi_bar = charts.create_top_spenders_bar(
                roi_data,
                category_col='Type',
                value_col='Savings',
                title='Savings Comparison',
                horizontal=False
            )
            st.plotly_chart(roi_bar, use_container_width=True)

        with col2:
            st.markdown("#### Achievement Rate")
            if estimated_impl > 0:
                achievement_rate = (actual_impl / estimated_impl * 100)
                st.metric("Actual vs Estimated", f"{achievement_rate:.1f}%")
                st.progress(min(achievement_rate / 100, 1.0))

                if achievement_rate >= 100:
                    st.success("🎉 Exceeded estimates!")
                elif achievement_rate >= 80:
                    st.success("✅ On target")
                else:
                    st.warning("⚠️ Below estimates")
            else:
                st.info("No estimated savings data")

        with col3:
            st.markdown("#### Total Realized Savings")
            st.metric("Monthly", utils.format_currency(actual_impl))
            st.metric("Annual", utils.format_currency(actual_impl * 12))

        # Implemented recommendations table
        st.markdown("#### Implemented Recommendations")
        if not implemented_recs.empty:
            impl_display = implemented_recs[[
                'TITLE',
                'CATEGORY',
                'ESTIMATED_MONTHLY_SAVINGS',
                'ACTUAL_MONTHLY_SAVINGS'
            ]].copy()

            impl_display['ESTIMATED_MONTHLY_SAVINGS'] = impl_display['ESTIMATED_MONTHLY_SAVINGS'].apply(
                utils.format_currency
            )
            impl_display['ACTUAL_MONTHLY_SAVINGS'] = impl_display['ACTUAL_MONTHLY_SAVINGS'].apply(
                utils.format_currency
            )

            st.dataframe(impl_display, use_container_width=True, hide_index=True)
    else:
        st.info("No recommendations implemented yet. Start implementing to track ROI.")

    st.markdown("---")

    # Quick wins
    st.markdown("### ⚡ Quick Wins (High Impact, Low Effort)")

    quick_wins = recommendations[
        (recommendations['PRIORITY'] == 'HIGH') &
        (recommendations['FEASIBILITY'] == 'HIGH') &
        (recommendations['STATUS'] == 'PENDING')
    ]

    if not quick_wins.empty:
        st.success(f"🎯 {len(quick_wins)} quick win opportunities identified! "
                  f"Potential savings: {utils.format_currency(quick_wins['ESTIMATED_MONTHLY_SAVINGS'].sum())}/month")

        quick_win_display = quick_wins[[
            'TITLE',
            'CATEGORY',
            'ESTIMATED_MONTHLY_SAVINGS',
            'DESCRIPTION'
        ]].copy()

        quick_win_display['ESTIMATED_MONTHLY_SAVINGS'] = quick_win_display['ESTIMATED_MONTHLY_SAVINGS'].apply(
            utils.format_currency
        )

        st.dataframe(quick_win_display, use_container_width=True, hide_index=True)
    else:
        st.info("No quick wins available. All high-priority, easy recommendations have been addressed!")

    st.markdown("---")

    # Export section
    st.markdown("### 📥 Export Data")

    col1, col2 = st.columns(2)

    with col1:
        if not recommendations.empty:
            utils.export_to_csv(recommendations, "optimization_recommendations")

    with col2:
        if not implemented_recs.empty:
            utils.export_to_excel(implemented_recs, "implemented_recommendations")

except Exception as e:
    st.error(f"Error loading optimization recommendations: {str(e)}")
    st.exception(e)
