"""
Budget Management Page

Budget vs actual tracking, alerts, and forecasting.
Provides budget status monitoring and burn rate analysis.
"""

import streamlit as st
import pandas as pd
from datetime import datetime, timedelta
from components import data, filters, charts, utils

# Page configuration
st.set_page_config(page_title="Budget Management", layout="wide", page_icon="📊")

st.title("📊 Budget Management")
st.markdown("Budget tracking, alerts, and forecasting")
st.markdown("---")

# Sidebar filters
start_date, end_date = filters.render_date_range_filter(default_days=30, key_prefix="budget")

if not utils.validate_date_range(start_date, end_date):
    st.stop()

selected_entity_id = filters.render_entity_filter(key_prefix="budget")

if filters.render_refresh_button(key_prefix="budget"):
    st.cache_data.clear()
    st.rerun()

# Main content
try:
    with utils.show_loading_spinner("Loading budget data..."):
        # Fetch budget data
        budget_status = data.get_budget_status()
        budget_alerts = data.get_budget_alerts()
        cost_by_entity = data.get_cost_by_entity(start_date, end_date)

    # Check if budget data is available
    if budget_status.empty:
        st.warning("⚠️ No budgets configured. Set budgets in Admin Config to enable budget tracking.")
        st.stop()

    # Filter by selected entity
    if selected_entity_id:
        budget_status = budget_status[budget_status['ENTITY_ID'] == selected_entity_id]

    # Calculate summary metrics
    total_budget = budget_status['BUDGET_AMOUNT'].sum()
    total_actual = budget_status['ACTUAL_SPEND'].sum()
    total_remaining = total_budget - total_actual
    overall_consumed_pct = (total_actual / total_budget * 100) if total_budget > 0 else 0

    # Count alerts by severity
    if not budget_alerts.empty:
        critical_alerts = len(budget_alerts[budget_alerts['ALERT_SEVERITY'] == 'CRITICAL'])
        warning_alerts = len(budget_alerts[budget_alerts['ALERT_SEVERITY'] == 'WARNING'])
        info_alerts = len(budget_alerts[budget_alerts['ALERT_SEVERITY'] == 'INFO'])
    else:
        critical_alerts = warning_alerts = info_alerts = 0

    # KPI Row
    st.markdown("### Budget Overview")
    col1, col2, col3, col4, col5 = st.columns(5)

    with col1:
        utils.show_metric_card(
            label="Total Budget",
            value=utils.format_currency(total_budget),
            help_text="Sum of all entity budgets"
        )

    with col2:
        utils.show_metric_card(
            label="Actual Spend",
            value=utils.format_currency(total_actual),
            help_text="Current period spend to date"
        )

    with col3:
        remaining_color = "OK" if total_remaining > 0 else "CRITICAL"
        utils.show_metric_card(
            label="Remaining Budget",
            value=utils.format_currency(total_remaining),
            help_text="Budget remaining in current period"
        )

    with col4:
        consumed_badge = "CRITICAL" if overall_consumed_pct > 90 else "WARNING" if overall_consumed_pct > 75 else "OK"
        st.metric(
            label="Budget Consumed",
            value=f"{overall_consumed_pct:.1f}%",
            help="Percentage of total budget consumed"
        )
        st.markdown(utils.show_alert_badge(consumed_badge, f"{overall_consumed_pct:.1f}%"), unsafe_allow_html=True)

    with col5:
        total_alerts = critical_alerts + warning_alerts + info_alerts
        st.metric(
            label="Active Alerts",
            value=utils.format_number(total_alerts),
            help="Number of active budget alerts"
        )

        if critical_alerts > 0:
            st.markdown(utils.show_alert_badge("CRITICAL", f"{critical_alerts} critical"), unsafe_allow_html=True)
        elif warning_alerts > 0:
            st.markdown(utils.show_alert_badge("WARNING", f"{warning_alerts} warnings"), unsafe_allow_html=True)
        else:
            st.markdown(utils.show_alert_badge("OK", "All good"), unsafe_allow_html=True)

    st.markdown("---")

    # Alert Summary
    if not budget_alerts.empty and (critical_alerts > 0 or warning_alerts > 0):
        st.markdown("### 🚨 Active Alerts")

        # Filter by severity
        alert_filter = st.multiselect(
            "Filter by severity",
            options=['CRITICAL', 'WARNING', 'INFO'],
            default=['CRITICAL', 'WARNING'],
            key="alert_severity_filter"
        )

        filtered_alerts = budget_alerts[budget_alerts['ALERT_SEVERITY'].isin(alert_filter)]

        if not filtered_alerts.empty:
            for _, alert in filtered_alerts.iterrows():
                severity = alert['ALERT_SEVERITY']
                entity = alert['ENTITY_NAME']
                message = alert['ALERT_MESSAGE']

                if severity == 'CRITICAL':
                    st.error(f"🔴 **{entity}:** {message}")
                elif severity == 'WARNING':
                    st.warning(f"🟡 **{entity}:** {message}")
                else:
                    st.info(f"🔵 **{entity}:** {message}")

        st.markdown("---")

    # Budget gauges
    st.markdown("### 💰 Budget Status by Entity")

    # Display top entities
    top_budget_entities = budget_status.nlargest(12, 'BUDGET_AMOUNT')

    if not top_budget_entities.empty:
        # Create gauge charts in grid
        cols = st.columns(3)

        for idx, (_, entity_row) in enumerate(top_budget_entities.iterrows()):
            with cols[idx % 3]:
                entity_name = entity_row['ENTITY_NAME']
                budget = entity_row['BUDGET_AMOUNT']
                actual = entity_row['ACTUAL_SPEND']
                remaining = budget - actual
                consumed_pct = (actual / budget * 100) if budget > 0 else 0

                # Create gauge
                gauge_fig = charts.create_budget_gauge(
                    actual,
                    budget,
                    title=entity_name
                )
                st.plotly_chart(gauge_fig, use_container_width=True)

                # Status text
                if consumed_pct >= 100:
                    st.markdown(f"❌ **Over budget by {utils.format_currency(abs(remaining))}**")
                elif consumed_pct >= 90:
                    st.markdown(f"🔴 **{utils.format_currency(remaining)} remaining ({100 - consumed_pct:.1f}%)**")
                elif consumed_pct >= 75:
                    st.markdown(f"🟡 **{utils.format_currency(remaining)} remaining ({100 - consumed_pct:.1f}%)**")
                else:
                    st.markdown(f"🟢 **{utils.format_currency(remaining)} remaining ({100 - consumed_pct:.1f}%)**")

    st.markdown("---")

    # Detailed budget table
    st.markdown("### 📊 Budget Status Table")

    # Calculate additional metrics
    budget_table = budget_status.copy()
    budget_table['REMAINING'] = budget_table['BUDGET_AMOUNT'] - budget_table['ACTUAL_SPEND']
    budget_table['PCT_CONSUMED'] = (
        budget_table['ACTUAL_SPEND'] / budget_table['BUDGET_AMOUNT'] * 100
    ).round(1)

    # Calculate forecast (assuming linear burn rate)
    days_in_period = (end_date - start_date).days
    if days_in_period > 0:
        budget_table['DAILY_BURN'] = budget_table['ACTUAL_SPEND'] / days_in_period
        budget_table['FORECAST'] = budget_table['DAILY_BURN'] * 30  # Forecast for 30 days
    else:
        budget_table['DAILY_BURN'] = 0
        budget_table['FORECAST'] = 0

    # Format display columns
    display_budget = budget_table[[
        'ENTITY_NAME',
        'BUDGET_AMOUNT',
        'ACTUAL_SPEND',
        'REMAINING',
        'PCT_CONSUMED',
        'FORECAST'
    ]].copy()

    display_budget['BUDGET_AMOUNT'] = display_budget['BUDGET_AMOUNT'].apply(utils.format_currency)
    display_budget['ACTUAL_SPEND'] = display_budget['ACTUAL_SPEND'].apply(utils.format_currency)
    display_budget['REMAINING'] = display_budget['REMAINING'].apply(utils.format_currency)
    display_budget['PCT_CONSUMED'] = display_budget['PCT_CONSUMED'].apply(lambda x: f"{x:.1f}%")
    display_budget['FORECAST'] = display_budget['FORECAST'].apply(utils.format_currency)

    st.dataframe(display_budget, use_container_width=True, hide_index=True)

    st.markdown("---")

    # Burn rate analysis
    st.markdown("### 🔥 Burn Rate Analysis")

    # Get daily costs for burn rate
    daily_costs = data.get_daily_cost_summary(start_date, end_date)

    if not daily_costs.empty:
        col_chart, col_metrics = st.columns([2, 1])

        with col_chart:
            # Create burn rate chart
            burn_chart = charts.create_spend_trend_chart(
                daily_costs,
                date_col='USAGE_DATE',
                value_col='TOTAL_COST',
                title='Daily Burn Rate'
            )
            st.plotly_chart(burn_chart, use_container_width=True)

        with col_metrics:
            st.markdown("#### Burn Rate Metrics")

            avg_daily_burn = daily_costs['TOTAL_COST'].mean()
            max_daily_burn = daily_costs['TOTAL_COST'].max()
            min_daily_burn = daily_costs['TOTAL_COST'].min()

            # Calculate trend
            if len(daily_costs) > 1:
                recent_avg = daily_costs.tail(7)['TOTAL_COST'].mean()
                earlier_avg = daily_costs.head(7)['TOTAL_COST'].mean()
                trend_pct = ((recent_avg - earlier_avg) / earlier_avg * 100) if earlier_avg > 0 else 0
            else:
                trend_pct = 0

            metrics_data = {
                'Metric': ['Avg Daily', 'Max Daily', 'Min Daily', '7-Day Trend'],
                'Value': [
                    utils.format_currency(avg_daily_burn),
                    utils.format_currency(max_daily_burn),
                    utils.format_currency(min_daily_burn),
                    f"{trend_pct:+.1f}%"
                ]
            }

            st.dataframe(pd.DataFrame(metrics_data), use_container_width=True, hide_index=True)

            # Projection
            days_remaining_in_month = 30 - (datetime.now().day if datetime.now().day < 30 else 0)
            projected_month_end = total_actual + (avg_daily_burn * days_remaining_in_month)

            st.markdown("#### Month-End Projection")
            st.metric(
                label="Projected Total",
                value=utils.format_currency(projected_month_end),
                delta=f"vs budget: {utils.format_currency(projected_month_end - total_budget)}"
            )

            if projected_month_end > total_budget:
                st.error("⚠️ Projected to exceed budget")
            else:
                st.success("✅ On track")

    st.markdown("---")

    # Forecast chart with confidence interval
    st.markdown("### 📈 Forecast to Month-End")

    if not daily_costs.empty and len(daily_costs) > 3:
        # Calculate forecast
        days_elapsed = len(daily_costs)
        days_remaining = 30 - days_elapsed

        # Linear forecast
        avg_daily = daily_costs['TOTAL_COST'].mean()
        std_daily = daily_costs['TOTAL_COST'].std()

        # Create forecast dataframe
        forecast_dates = pd.date_range(
            start=daily_costs['USAGE_DATE'].max() + timedelta(days=1),
            periods=days_remaining,
            freq='D'
        )

        forecast_df = pd.DataFrame({
            'USAGE_DATE': list(daily_costs['USAGE_DATE']) + list(forecast_dates),
            'ACTUAL': list(daily_costs['TOTAL_COST']) + [None] * days_remaining,
            'FORECAST': [None] * days_elapsed + [avg_daily] * days_remaining,
            'UPPER': [None] * days_elapsed + [avg_daily + (2 * std_daily)] * days_remaining,
            'LOWER': [None] * days_elapsed + [max(0, avg_daily - (2 * std_daily))] * days_remaining
        })

        # Create multi-line chart
        import plotly.graph_objects as go

        fig = go.Figure()

        # Actual data
        fig.add_trace(go.Scatter(
            x=forecast_df['USAGE_DATE'][:days_elapsed],
            y=forecast_df['ACTUAL'][:days_elapsed],
            mode='lines+markers',
            name='Actual',
            line=dict(color=charts.PRIMARY_COLOR, width=3),
            marker=dict(size=6)
        ))

        # Forecast
        fig.add_trace(go.Scatter(
            x=forecast_df['USAGE_DATE'][days_elapsed:],
            y=forecast_df['FORECAST'][days_elapsed:],
            mode='lines',
            name='Forecast',
            line=dict(color=charts.SECONDARY_COLOR, width=2, dash='dash')
        ))

        # Confidence interval
        fig.add_trace(go.Scatter(
            x=forecast_df['USAGE_DATE'][days_elapsed:],
            y=forecast_df['UPPER'][days_elapsed:],
            mode='lines',
            name='Upper Bound',
            line=dict(width=0),
            showlegend=False
        ))

        fig.add_trace(go.Scatter(
            x=forecast_df['USAGE_DATE'][days_elapsed:],
            y=forecast_df['LOWER'][days_elapsed:],
            mode='lines',
            name='Lower Bound',
            line=dict(width=0),
            fillcolor='rgba(0, 212, 255, 0.2)',
            fill='tonexty',
            showlegend=True
        ))

        # Budget line
        fig.add_hline(
            y=total_budget,
            line_dash='dot',
            line_color='red',
            annotation_text=f'Budget: {utils.format_currency(total_budget)}',
            annotation_position='right'
        )

        fig.update_layout(
            **charts.get_default_layout(),
            title='Cost Forecast with 95% Confidence Interval',
            xaxis_title='Date',
            yaxis_title='Daily Cost ($)',
            yaxis=dict(tickprefix='$', tickformat=',.0f')
        )

        st.plotly_chart(fig, use_container_width=True)

        st.info("📊 **Note:** Forecast uses linear extrapolation based on historical daily average. "
               "Confidence interval represents ±2 standard deviations.")

    st.markdown("---")

    # Alert history
    st.markdown("### 📜 Alert History")

    if not budget_alerts.empty:
        alert_history = budget_alerts.copy()

        if 'CREATED_AT' in alert_history.columns:
            alert_history = alert_history.sort_values('CREATED_AT', ascending=False)

        display_alerts = alert_history[[
            'ENTITY_NAME',
            'ALERT_SEVERITY',
            'ALERT_MESSAGE',
            'CREATED_AT'
        ]].head(20).copy()

        if 'CREATED_AT' in display_alerts.columns:
            display_alerts['CREATED_AT'] = pd.to_datetime(display_alerts['CREATED_AT']).dt.strftime('%Y-%m-%d %H:%M')

        st.dataframe(display_alerts, use_container_width=True, hide_index=True)
    else:
        st.success("✅ No budget alerts recorded")

    st.markdown("---")

    # Export section
    st.markdown("### 📥 Export Data")

    col1, col2, col3 = st.columns(3)

    with col1:
        if not budget_status.empty:
            utils.export_to_csv(budget_table, "budget_status")

    with col2:
        if not budget_alerts.empty:
            utils.export_to_csv(budget_alerts, "budget_alerts")

    with col3:
        if not daily_costs.empty:
            utils.export_to_excel(daily_costs, "daily_burn_rate")

except Exception as e:
    st.error(f"Error loading budget management: {str(e)}")
    st.exception(e)
