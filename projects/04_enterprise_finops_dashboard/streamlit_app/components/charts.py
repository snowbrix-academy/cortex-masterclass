"""
Chart components for the Enterprise FinOps Dashboard.

Provides reusable Plotly chart functions with consistent styling.
"""

import plotly.graph_objects as go
import plotly.express as px
import pandas as pd
from datetime import datetime


# Theme colors
PRIMARY_COLOR = '#1f77b4'
SECONDARY_COLOR = '#00d4ff'
SUCCESS_COLOR = '#00cc66'
WARNING_COLOR = '#ffaa00'
DANGER_COLOR = '#ff4444'
CHART_COLORS = ['#1f77b4', '#00d4ff', '#00cc66', '#ffaa00', '#ff4444', '#9467bd', '#8c564b', '#e377c2']


def get_default_layout():
    """Get default layout configuration for dark theme."""
    return dict(
        template='plotly_dark',
        paper_bgcolor='rgba(0,0,0,0)',
        plot_bgcolor='rgba(0,0,0,0)',
        font=dict(color='#e0e0e0'),
        hovermode='closest',
        margin=dict(l=60, r=40, t=60, b=60)
    )


def create_spend_trend_chart(df, date_col='USAGE_DATE', value_col='TOTAL_COST', title='Cost Trend'):
    """
    Create line chart showing spend trend over time.

    Args:
        df: DataFrame with date and cost columns
        date_col: Name of date column
        value_col: Name of value column
        title: Chart title

    Returns:
        Plotly Figure
    """
    if df is None or df.empty:
        return create_empty_chart("No data available")

    fig = go.Figure()

    fig.add_trace(go.Scatter(
        x=df[date_col],
        y=df[value_col],
        mode='lines+markers',
        line=dict(color=PRIMARY_COLOR, width=3),
        marker=dict(size=8, color=SECONDARY_COLOR),
        hovertemplate='<b>%{x}</b><br>Cost: $%{y:,.2f}<extra></extra>'
    ))

    fig.update_layout(
        **get_default_layout(),
        title=title,
        xaxis_title='Date',
        yaxis_title='Cost ($)',
        yaxis=dict(tickprefix='$', tickformat=',.0f')
    )

    return fig


def create_warehouse_utilization_heatmap(df):
    """
    Create heatmap showing warehouse utilization by hour and day.

    Args:
        df: DataFrame with columns WAREHOUSE_NAME, HOUR_OF_DAY, DAY_OF_WEEK, CREDITS_USED

    Returns:
        Plotly Figure
    """
    if df is None or df.empty:
        return create_empty_chart("No utilization data available")

    # Pivot data for heatmap
    pivot_df = df.pivot_table(
        index='HOUR_OF_DAY',
        columns='DAY_OF_WEEK',
        values='CREDITS_USED',
        aggfunc='sum',
        fill_value=0
    )

    # Ensure days are in correct order
    day_order = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
    pivot_df = pivot_df.reindex(columns=[d for d in day_order if d in pivot_df.columns])

    fig = go.Figure(data=go.Heatmap(
        z=pivot_df.values,
        x=pivot_df.columns,
        y=pivot_df.index,
        colorscale='Blues',
        hoverongaps=False,
        hovertemplate='<b>%{x}</b><br>Hour: %{y}<br>Credits: %{z:.2f}<extra></extra>'
    ))

    fig.update_layout(
        **get_default_layout(),
        title='Warehouse Utilization Heatmap (Credits by Day & Hour)',
        xaxis_title='Day of Week',
        yaxis_title='Hour of Day',
        yaxis=dict(autorange='reversed')
    )

    return fig


def create_cost_breakdown_pie(df, labels_col='COST_TYPE', values_col='COST_AMOUNT', title='Cost Breakdown'):
    """
    Create pie chart showing cost breakdown by category.

    Args:
        df: DataFrame with category and cost columns
        labels_col: Name of labels column
        values_col: Name of values column
        title: Chart title

    Returns:
        Plotly Figure
    """
    if df is None or df.empty:
        return create_empty_chart("No cost data available")

    fig = go.Figure(data=[go.Pie(
        labels=df[labels_col],
        values=df[values_col],
        hole=0.4,
        marker=dict(colors=CHART_COLORS),
        hovertemplate='<b>%{label}</b><br>Cost: $%{value:,.2f}<br>Percentage: %{percent}<extra></extra>'
    )])

    fig.update_layout(
        **get_default_layout(),
        title=title,
        showlegend=True,
        legend=dict(orientation='h', yanchor='bottom', y=-0.2)
    )

    return fig


def create_entity_treemap(df, path_cols=['BUSINESS_UNIT', 'DEPARTMENT', 'TEAM'], value_col='TOTAL_COST'):
    """
    Create treemap showing hierarchical cost breakdown.

    Args:
        df: DataFrame with hierarchy and cost columns
        path_cols: List of column names for hierarchy (root to leaf)
        value_col: Name of value column

    Returns:
        Plotly Figure
    """
    if df is None or df.empty:
        return create_empty_chart("No entity data available")

    fig = px.treemap(
        df,
        path=path_cols,
        values=value_col,
        color=value_col,
        color_continuous_scale='Blues',
        hover_data={value_col: ':$,.2f'}
    )

    fig.update_layout(
        **get_default_layout(),
        title='Cost by Entity Hierarchy',
        coloraxis_colorbar=dict(title='Cost ($)')
    )

    fig.update_traces(
        texttemplate='<b>%{label}</b><br>$%{value:,.0f}',
        hovertemplate='<b>%{label}</b><br>Cost: $%{value:,.2f}<extra></extra>'
    )

    return fig


def create_budget_gauge(actual, budget, title='Budget Status'):
    """
    Create gauge chart showing budget consumption.

    Args:
        actual: Actual spend amount
        budget: Budget amount
        title: Chart title

    Returns:
        Plotly Figure
    """
    if budget == 0:
        percentage = 100
    else:
        percentage = (actual / budget) * 100

    # Determine color based on percentage
    if percentage < 70:
        color = SUCCESS_COLOR
    elif percentage < 85:
        color = WARNING_COLOR
    else:
        color = DANGER_COLOR

    fig = go.Figure(go.Indicator(
        mode='gauge+number+delta',
        value=actual,
        delta={'reference': budget, 'valueformat': '$,.0f'},
        title={'text': title},
        number={'prefix': '$', 'valueformat': ',.0f'},
        gauge={
            'axis': {'range': [None, budget * 1.2], 'tickprefix': '$', 'tickformat': ',.0f'},
            'bar': {'color': color},
            'steps': [
                {'range': [0, budget * 0.7], 'color': 'rgba(0, 204, 102, 0.2)'},
                {'range': [budget * 0.7, budget * 0.85], 'color': 'rgba(255, 170, 0, 0.2)'},
                {'range': [budget * 0.85, budget * 1.2], 'color': 'rgba(255, 68, 68, 0.2)'}
            ],
            'threshold': {
                'line': {'color': 'white', 'width': 4},
                'thickness': 0.75,
                'value': budget
            }
        }
    ))

    fig.update_layout(
        **get_default_layout(),
        height=300
    )

    return fig


def create_top_spenders_bar(df, category_col='ENTITY_NAME', value_col='TOTAL_COST',
                            title='Top Spenders', limit=10, horizontal=True):
    """
    Create bar chart showing top spenders.

    Args:
        df: DataFrame with category and cost columns
        category_col: Name of category column
        value_col: Name of value column
        title: Chart title
        limit: Number of top items to show
        horizontal: If True, create horizontal bar chart

    Returns:
        Plotly Figure
    """
    if df is None or df.empty:
        return create_empty_chart("No data available")

    # Sort and limit
    df_sorted = df.nlargest(limit, value_col)

    if horizontal:
        fig = go.Figure(data=[go.Bar(
            x=df_sorted[value_col],
            y=df_sorted[category_col],
            orientation='h',
            marker=dict(
                color=df_sorted[value_col],
                colorscale='Blues',
                showscale=False
            ),
            hovertemplate='<b>%{y}</b><br>Cost: $%{x:,.2f}<extra></extra>'
        )])

        fig.update_layout(
            **get_default_layout(),
            title=title,
            xaxis_title='Cost ($)',
            yaxis_title='',
            xaxis=dict(tickprefix='$', tickformat=',.0f'),
            yaxis=dict(autorange='reversed')
        )
    else:
        fig = go.Figure(data=[go.Bar(
            x=df_sorted[category_col],
            y=df_sorted[value_col],
            marker=dict(
                color=df_sorted[value_col],
                colorscale='Blues',
                showscale=False
            ),
            hovertemplate='<b>%{x}</b><br>Cost: $%{y:,.2f}<extra></extra>'
        )])

        fig.update_layout(
            **get_default_layout(),
            title=title,
            xaxis_title='',
            yaxis_title='Cost ($)',
            yaxis=dict(tickprefix='$', tickformat=',.0f')
        )

    return fig


def create_stacked_bar_chart(df, x_col, y_cols, title='Stacked Bar Chart'):
    """
    Create stacked bar chart with multiple categories.

    Args:
        df: DataFrame
        x_col: Column for x-axis (categories)
        y_cols: List of columns to stack
        title: Chart title

    Returns:
        Plotly Figure
    """
    if df is None or df.empty:
        return create_empty_chart("No data available")

    fig = go.Figure()

    for i, col in enumerate(y_cols):
        fig.add_trace(go.Bar(
            name=col,
            x=df[x_col],
            y=df[col],
            marker_color=CHART_COLORS[i % len(CHART_COLORS)],
            hovertemplate=f'<b>{col}</b><br>%{{x}}<br>Cost: $%{{y:,.2f}}<extra></extra>'
        ))

    fig.update_layout(
        **get_default_layout(),
        title=title,
        barmode='stack',
        xaxis_title='',
        yaxis_title='Cost ($)',
        yaxis=dict(tickprefix='$', tickformat=',.0f'),
        legend=dict(orientation='h', yanchor='bottom', y=-0.2)
    )

    return fig


def create_scatter_plot(df, x_col, y_col, size_col=None, color_col=None,
                       title='Scatter Plot', x_label='X', y_label='Y'):
    """
    Create scatter plot with optional size and color dimensions.

    Args:
        df: DataFrame
        x_col: Column for x-axis
        y_col: Column for y-axis
        size_col: Optional column for marker size
        color_col: Optional column for marker color
        title: Chart title
        x_label: X-axis label
        y_label: Y-axis label

    Returns:
        Plotly Figure
    """
    if df is None or df.empty:
        return create_empty_chart("No data available")

    fig = px.scatter(
        df,
        x=x_col,
        y=y_col,
        size=size_col,
        color=color_col,
        color_continuous_scale='Blues',
        hover_data=df.columns
    )

    fig.update_layout(
        **get_default_layout(),
        title=title,
        xaxis_title=x_label,
        yaxis_title=y_label
    )

    return fig


def create_waterfall_chart(df, x_col, y_col, title='Waterfall Chart'):
    """
    Create waterfall chart showing cumulative effect.

    Args:
        df: DataFrame with x and y columns
        x_col: Column for x-axis (categories)
        y_col: Column for y-axis (values)
        title: Chart title

    Returns:
        Plotly Figure
    """
    if df is None or df.empty:
        return create_empty_chart("No data available")

    fig = go.Figure(go.Waterfall(
        x=df[x_col],
        y=df[y_col],
        connector={'line': {'color': 'rgb(63, 63, 63)'}},
        decreasing={'marker': {'color': DANGER_COLOR}},
        increasing={'marker': {'color': SUCCESS_COLOR}},
        totals={'marker': {'color': PRIMARY_COLOR}},
        hovertemplate='<b>%{x}</b><br>Amount: $%{y:,.2f}<extra></extra>'
    ))

    fig.update_layout(
        **get_default_layout(),
        title=title,
        xaxis_title='',
        yaxis_title='Amount ($)',
        yaxis=dict(tickprefix='$', tickformat=',.0f')
    )

    return fig


def create_funnel_chart(df, x_col, y_col, title='Funnel Chart'):
    """
    Create funnel chart.

    Args:
        df: DataFrame
        x_col: Column for stage names
        y_col: Column for values
        title: Chart title

    Returns:
        Plotly Figure
    """
    if df is None or df.empty:
        return create_empty_chart("No data available")

    fig = go.Figure(go.Funnel(
        y=df[x_col],
        x=df[y_col],
        textinfo='value+percent initial',
        marker={'color': CHART_COLORS},
        hovertemplate='<b>%{y}</b><br>Value: %{x:,.0f}<extra></extra>'
    ))

    fig.update_layout(
        **get_default_layout(),
        title=title
    )

    return fig


def create_box_plot(df, x_col, y_col, title='Box Plot'):
    """
    Create box plot showing distribution.

    Args:
        df: DataFrame
        x_col: Column for categories
        y_col: Column for values
        title: Chart title

    Returns:
        Plotly Figure
    """
    if df is None or df.empty:
        return create_empty_chart("No data available")

    fig = px.box(
        df,
        x=x_col,
        y=y_col,
        color=x_col,
        color_discrete_sequence=CHART_COLORS
    )

    fig.update_layout(
        **get_default_layout(),
        title=title,
        showlegend=False
    )

    return fig


def create_multi_line_chart(df, x_col, y_cols, title='Multi-Line Chart'):
    """
    Create line chart with multiple series.

    Args:
        df: DataFrame
        x_col: Column for x-axis
        y_cols: List of columns for y-axis
        title: Chart title

    Returns:
        Plotly Figure
    """
    if df is None or df.empty:
        return create_empty_chart("No data available")

    fig = go.Figure()

    for i, col in enumerate(y_cols):
        fig.add_trace(go.Scatter(
            x=df[x_col],
            y=df[col],
            mode='lines+markers',
            name=col,
            line=dict(width=3, color=CHART_COLORS[i % len(CHART_COLORS)]),
            marker=dict(size=8),
            hovertemplate=f'<b>{col}</b><br>%{{x}}<br>Value: %{{y:,.2f}}<extra></extra>'
        ))

    fig.update_layout(
        **get_default_layout(),
        title=title,
        xaxis_title='',
        yaxis_title='Value',
        legend=dict(orientation='h', yanchor='bottom', y=-0.2)
    )

    return fig


def create_empty_chart(message="No data available"):
    """
    Create empty chart with message.

    Args:
        message: Message to display

    Returns:
        Plotly Figure
    """
    fig = go.Figure()

    fig.add_annotation(
        text=message,
        xref='paper',
        yref='paper',
        x=0.5,
        y=0.5,
        showarrow=False,
        font=dict(size=16, color='#666')
    )

    fig.update_layout(
        **get_default_layout(),
        xaxis=dict(visible=False),
        yaxis=dict(visible=False),
        height=400
    )

    return fig
