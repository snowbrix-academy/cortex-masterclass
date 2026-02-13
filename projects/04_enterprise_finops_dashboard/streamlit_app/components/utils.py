"""
Utility functions for the Enterprise FinOps Dashboard.

Provides formatting, export, and UI helper functions used across all pages.
"""

import streamlit as st
import pandas as pd
from io import BytesIO
from datetime import datetime
import plotly.graph_objects as go


def format_currency(value):
    """
    Format numeric value as currency with appropriate suffix.

    Args:
        value: Numeric value to format

    Returns:
        Formatted string (e.g., "$1.2M", "$345.6K", "$12.34")
    """
    if value is None or pd.isna(value):
        return "$0.00"

    try:
        value = float(value)
    except (ValueError, TypeError):
        return "$0.00"

    if abs(value) >= 1_000_000:
        return f"${value / 1_000_000:.2f}M"
    elif abs(value) >= 1_000:
        return f"${value / 1_000:.2f}K"
    else:
        return f"${value:.2f}"


def format_percentage(value):
    """
    Format numeric value as percentage.

    Args:
        value: Numeric value (0.15 = 15%)

    Returns:
        Formatted string (e.g., "15.0%")
    """
    if value is None or pd.isna(value):
        return "0.0%"

    try:
        value = float(value)
        return f"{value * 100:.1f}%"
    except (ValueError, TypeError):
        return "0.0%"


def format_number(value, decimals=0):
    """
    Format numeric value with comma separators.

    Args:
        value: Numeric value to format
        decimals: Number of decimal places (default 0)

    Returns:
        Formatted string (e.g., "1,234,567")
    """
    if value is None or pd.isna(value):
        return "0"

    try:
        value = float(value)
        if decimals == 0:
            return f"{int(value):,}"
        else:
            return f"{value:,.{decimals}f}"
    except (ValueError, TypeError):
        return "0"


def format_credits(value):
    """
    Format credit value with appropriate suffix.

    Args:
        value: Numeric credit value

    Returns:
        Formatted string (e.g., "1.2K credits", "345 credits")
    """
    if value is None or pd.isna(value):
        return "0 credits"

    try:
        value = float(value)
        if abs(value) >= 1_000:
            return f"{value / 1_000:.2f}K credits"
        else:
            return f"{value:.2f} credits"
    except (ValueError, TypeError):
        return "0 credits"


def export_to_csv(df, filename):
    """
    Create a download button for CSV export.

    Args:
        df: Pandas DataFrame to export
        filename: Suggested filename for download
    """
    if df is None or df.empty:
        st.warning("No data to export")
        return

    csv = df.to_csv(index=False)
    st.download_button(
        label="📥 Download CSV",
        data=csv,
        file_name=f"{filename}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv",
        mime="text/csv",
        use_container_width=True
    )


def export_to_excel(df, filename, sheet_name="Data"):
    """
    Create a download button for Excel export with formatting.

    Args:
        df: Pandas DataFrame to export
        filename: Suggested filename for download
        sheet_name: Name of the Excel sheet
    """
    if df is None or df.empty:
        st.warning("No data to export")
        return

    try:
        output = BytesIO()
        with pd.ExcelWriter(output, engine='xlsxwriter') as writer:
            df.to_excel(writer, index=False, sheet_name=sheet_name)

            # Get workbook and worksheet objects
            workbook = writer.book
            worksheet = writer.sheets[sheet_name]

            # Add header format
            header_format = workbook.add_format({
                'bold': True,
                'bg_color': '#1f77b4',
                'font_color': 'white',
                'border': 1
            })

            # Apply header format
            for col_num, value in enumerate(df.columns.values):
                worksheet.write(0, col_num, value, header_format)

            # Auto-adjust column widths
            for idx, col in enumerate(df.columns):
                max_length = max(
                    df[col].astype(str).apply(len).max(),
                    len(str(col))
                ) + 2
                worksheet.set_column(idx, idx, min(max_length, 50))

        output.seek(0)

        st.download_button(
            label="📥 Download Excel",
            data=output,
            file_name=f"{filename}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.xlsx",
            mime="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            use_container_width=True
        )
    except Exception as e:
        st.error(f"Export failed: {str(e)}")


def show_metric_card(label, value, delta=None, delta_label=None, help_text=None):
    """
    Display a styled metric card with optional delta.

    Args:
        label: Metric label
        value: Metric value (will be formatted if numeric)
        delta: Change value (e.g., "+5%", "-$1.2K")
        delta_label: Description of delta (e.g., "vs last month")
        help_text: Optional tooltip text
    """
    if delta and delta_label:
        st.metric(
            label=label,
            value=value,
            delta=f"{delta} {delta_label}",
            help=help_text
        )
    else:
        st.metric(
            label=label,
            value=value,
            help=help_text
        )


def show_alert_badge(alert_type, message=None):
    """
    Display a colored badge for alert types.

    Args:
        alert_type: 'CRITICAL', 'WARNING', 'OK', 'INFO'
        message: Optional message text

    Returns:
        Colored HTML badge
    """
    colors = {
        'CRITICAL': '#ff4444',
        'WARNING': '#ffaa00',
        'OK': '#00cc66',
        'INFO': '#0099ff'
    }

    color = colors.get(alert_type.upper(), '#999999')
    badge_text = message if message else alert_type.upper()

    badge_html = f"""
    <span style="
        background-color: {color};
        color: white;
        padding: 4px 12px;
        border-radius: 12px;
        font-size: 12px;
        font-weight: bold;
        display: inline-block;
        margin: 2px;
    ">{badge_text}</span>
    """

    return badge_html


def calculate_delta(current_value, previous_value):
    """
    Calculate percentage change between two values.

    Args:
        current_value: Current period value
        previous_value: Previous period value

    Returns:
        Tuple of (delta_value, delta_percentage_string)
    """
    if previous_value is None or previous_value == 0:
        return (current_value, "+100.0%")

    try:
        current = float(current_value) if current_value else 0
        previous = float(previous_value) if previous_value else 0

        if previous == 0:
            return (current, "+100.0%")

        delta_val = current - previous
        delta_pct = ((current - previous) / previous) * 100

        sign = "+" if delta_pct >= 0 else ""
        return (delta_val, f"{sign}{delta_pct:.1f}%")
    except (ValueError, TypeError):
        return (0, "0.0%")


def create_empty_state(message="No data available for the selected filters"):
    """
    Display an empty state message with icon.

    Args:
        message: Message to display
    """
    st.markdown(f"""
    <div style="
        text-align: center;
        padding: 60px 20px;
        color: #666;
        font-size: 16px;
    ">
        <div style="font-size: 48px; margin-bottom: 20px;">📊</div>
        <div>{message}</div>
    </div>
    """, unsafe_allow_html=True)


def create_sparkline(values):
    """
    Create a simple sparkline chart for inline display.

    Args:
        values: List of numeric values

    Returns:
        Plotly figure
    """
    if not values or len(values) < 2:
        return None

    fig = go.Figure()
    fig.add_trace(go.Scatter(
        y=values,
        mode='lines',
        line=dict(color='#00d4ff', width=2),
        hovertemplate='%{y:.2f}<extra></extra>'
    ))

    fig.update_layout(
        height=50,
        margin=dict(l=0, r=0, t=0, b=0),
        xaxis=dict(visible=False),
        yaxis=dict(visible=False),
        showlegend=False,
        paper_bgcolor='rgba(0,0,0,0)',
        plot_bgcolor='rgba(0,0,0,0)',
        hovermode='x'
    )

    return fig


def validate_date_range(start_date, end_date):
    """
    Validate that date range is valid.

    Args:
        start_date: Start date
        end_date: End date

    Returns:
        Boolean indicating if valid
    """
    if not start_date or not end_date:
        return False

    if start_date > end_date:
        st.error("Start date must be before end date")
        return False

    return True


def format_sql_query(sql_text, max_length=500):
    """
    Format SQL query for display with truncation.

    Args:
        sql_text: SQL query string
        max_length: Maximum length before truncation

    Returns:
        Formatted SQL string
    """
    if not sql_text:
        return "N/A"

    sql_text = sql_text.strip()

    if len(sql_text) > max_length:
        return sql_text[:max_length] + "..."

    return sql_text


def show_loading_spinner(message="Loading data..."):
    """
    Context manager for showing loading spinner.

    Usage:
        with show_loading_spinner("Fetching data..."):
            data = fetch_data()
    """
    return st.spinner(message)


def get_color_scale(value, min_val, max_val, reverse=False):
    """
    Get color from gradient scale based on value position.

    Args:
        value: Current value
        min_val: Minimum value in range
        max_val: Maximum value in range
        reverse: If True, low values are green, high values are red

    Returns:
        Hex color code
    """
    if min_val == max_val:
        return '#ffaa00'

    ratio = (value - min_val) / (max_val - min_val)
    ratio = max(0, min(1, ratio))  # Clamp to 0-1

    if reverse:
        ratio = 1 - ratio

    # Green to Yellow to Red gradient
    if ratio < 0.5:
        # Green to Yellow
        r = int(ratio * 2 * 255)
        g = 255
    else:
        # Yellow to Red
        r = 255
        g = int((1 - (ratio - 0.5) * 2) * 255)

    return f'#{r:02x}{g:02x}00'
