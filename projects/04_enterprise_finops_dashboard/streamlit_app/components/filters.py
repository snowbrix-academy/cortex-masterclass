"""
Filter components for the Enterprise FinOps Dashboard.

Provides reusable filter UI components for consistent filtering across pages.
"""

import streamlit as st
from datetime import datetime, timedelta
from components import data


def render_date_range_filter(default_days=30, key_prefix="main"):
    """
    Render date range filter in sidebar.

    Args:
        default_days: Number of days to look back by default
        key_prefix: Unique prefix for widget keys

    Returns:
        Tuple of (start_date, end_date)
    """
    st.sidebar.markdown("### 📅 Date Range")

    # Quick select buttons
    col1, col2, col3 = st.sidebar.columns(3)

    today = datetime.now().date()

    with col1:
        if st.button("7D", key=f"{key_prefix}_7d", use_container_width=True):
            st.session_state[f'{key_prefix}_start_date'] = today - timedelta(days=7)
            st.session_state[f'{key_prefix}_end_date'] = today

    with col2:
        if st.button("30D", key=f"{key_prefix}_30d", use_container_width=True):
            st.session_state[f'{key_prefix}_start_date'] = today - timedelta(days=30)
            st.session_state[f'{key_prefix}_end_date'] = today

    with col3:
        if st.button("90D", key=f"{key_prefix}_90d", use_container_width=True):
            st.session_state[f'{key_prefix}_start_date'] = today - timedelta(days=90)
            st.session_state[f'{key_prefix}_end_date'] = today

    # Initialize session state if not present
    if f'{key_prefix}_start_date' not in st.session_state:
        st.session_state[f'{key_prefix}_start_date'] = today - timedelta(days=default_days)
    if f'{key_prefix}_end_date' not in st.session_state:
        st.session_state[f'{key_prefix}_end_date'] = today

    # Date pickers
    start_date = st.sidebar.date_input(
        "Start Date",
        value=st.session_state[f'{key_prefix}_start_date'],
        max_value=today,
        key=f"{key_prefix}_start"
    )

    end_date = st.sidebar.date_input(
        "End Date",
        value=st.session_state[f'{key_prefix}_end_date'],
        max_value=today,
        key=f"{key_prefix}_end"
    )

    # Update session state
    st.session_state[f'{key_prefix}_start_date'] = start_date
    st.session_state[f'{key_prefix}_end_date'] = end_date

    # Validation
    if start_date > end_date:
        st.sidebar.error("Start date must be before end date")
        return None, None

    st.sidebar.markdown(f"**Range:** {(end_date - start_date).days} days")

    return start_date, end_date


def render_warehouse_filter(key_prefix="main", multiselect=True):
    """
    Render warehouse filter in sidebar.

    Args:
        key_prefix: Unique prefix for widget keys
        multiselect: If True, allow multiple selection

    Returns:
        List of selected warehouse names (or single string if multiselect=False)
    """
    st.sidebar.markdown("### 🏢 Warehouses")

    try:
        warehouses_df = data.get_warehouse_list()

        if warehouses_df.empty:
            st.sidebar.warning("No warehouses found")
            return [] if multiselect else None

        warehouse_names = sorted(warehouses_df['WAREHOUSE_NAME'].unique().tolist())

        if multiselect:
            selected = st.sidebar.multiselect(
                "Select Warehouses",
                options=warehouse_names,
                default=[],
                key=f"{key_prefix}_warehouses",
                help="Leave empty to include all warehouses"
            )

            if not selected:
                st.sidebar.info(f"Showing all {len(warehouse_names)} warehouses")

            return selected if selected else warehouse_names
        else:
            selected = st.sidebar.selectbox(
                "Select Warehouse",
                options=["All"] + warehouse_names,
                key=f"{key_prefix}_warehouse"
            )

            return None if selected == "All" else selected

    except Exception as e:
        st.sidebar.error(f"Error loading warehouses: {str(e)}")
        return [] if multiselect else None


def render_entity_filter(key_prefix="main", entity_type=None):
    """
    Render entity filter with hierarchical drill-down.

    Args:
        key_prefix: Unique prefix for widget keys
        entity_type: Filter to specific entity type (BU/DEPT/TEAM)

    Returns:
        Selected entity_id or None
    """
    st.sidebar.markdown("### 🏛️ Entity")

    try:
        entities_df = data.get_entity_hierarchy()

        if entities_df.empty:
            st.sidebar.warning("No entities found")
            return None

        # Filter by type if specified
        if entity_type:
            entities_df = entities_df[entities_df['ENTITY_TYPE'] == entity_type]

        # Business Unit selector
        business_units = sorted(
            entities_df[entities_df['ENTITY_TYPE'] == 'BU']['ENTITY_NAME'].unique().tolist()
        )

        selected_bu = st.sidebar.selectbox(
            "Business Unit",
            options=["All"] + business_units,
            key=f"{key_prefix}_bu"
        )

        # Department selector (filtered by BU)
        if selected_bu != "All":
            bu_id = entities_df[
                (entities_df['ENTITY_NAME'] == selected_bu) &
                (entities_df['ENTITY_TYPE'] == 'BU')
            ]['ENTITY_ID'].iloc[0]

            departments = sorted(
                entities_df[
                    (entities_df['PARENT_ENTITY_ID'] == bu_id) &
                    (entities_df['ENTITY_TYPE'] == 'DEPT')
                ]['ENTITY_NAME'].unique().tolist()
            )

            if departments:
                selected_dept = st.sidebar.selectbox(
                    "Department",
                    options=["All"] + departments,
                    key=f"{key_prefix}_dept"
                )

                # Team selector (filtered by Department)
                if selected_dept != "All":
                    dept_id = entities_df[
                        (entities_df['ENTITY_NAME'] == selected_dept) &
                        (entities_df['ENTITY_TYPE'] == 'DEPT')
                    ]['ENTITY_ID'].iloc[0]

                    teams = sorted(
                        entities_df[
                            (entities_df['PARENT_ENTITY_ID'] == dept_id) &
                            (entities_df['ENTITY_TYPE'] == 'TEAM')
                        ]['ENTITY_NAME'].unique().tolist()
                    )

                    if teams:
                        selected_team = st.sidebar.selectbox(
                            "Team",
                            options=["All"] + teams,
                            key=f"{key_prefix}_team"
                        )

                        if selected_team != "All":
                            team_id = entities_df[
                                (entities_df['ENTITY_NAME'] == selected_team) &
                                (entities_df['ENTITY_TYPE'] == 'TEAM')
                            ]['ENTITY_ID'].iloc[0]
                            return team_id

                    return dept_id
            return bu_id

        return None

    except Exception as e:
        st.sidebar.error(f"Error loading entities: {str(e)}")
        return None


def render_user_filter(key_prefix="main", multiselect=True):
    """
    Render user filter in sidebar.

    Args:
        key_prefix: Unique prefix for widget keys
        multiselect: If True, allow multiple selection

    Returns:
        List of selected usernames (or single string if multiselect=False)
    """
    st.sidebar.markdown("### 👤 Users")

    try:
        users_df = data.get_user_list()

        if users_df.empty:
            st.sidebar.warning("No users found")
            return [] if multiselect else None

        # Add user type filter
        user_types = ["All", "Human", "Service Account"]
        selected_type = st.sidebar.selectbox(
            "User Type",
            options=user_types,
            key=f"{key_prefix}_user_type"
        )

        # Filter users by type
        if selected_type != "All":
            users_df = users_df[users_df['USER_TYPE'] == selected_type.upper().replace(" ", "_")]

        user_names = sorted(users_df['USER_NAME'].unique().tolist())

        if not user_names:
            st.sidebar.info("No users of this type")
            return [] if multiselect else None

        if multiselect:
            selected = st.sidebar.multiselect(
                "Select Users",
                options=user_names,
                default=[],
                key=f"{key_prefix}_users",
                help="Leave empty to include all users"
            )

            if not selected:
                st.sidebar.info(f"Showing all {len(user_names)} users")

            return selected if selected else user_names
        else:
            selected = st.sidebar.selectbox(
                "Select User",
                options=["All"] + user_names,
                key=f"{key_prefix}_user"
            )

            return None if selected == "All" else selected

    except Exception as e:
        st.sidebar.error(f"Error loading users: {str(e)}")
        return [] if multiselect else None


def render_query_type_filter(key_prefix="main"):
    """
    Render query type filter in sidebar.

    Args:
        key_prefix: Unique prefix for widget keys

    Returns:
        List of selected query types
    """
    st.sidebar.markdown("### 🔍 Query Types")

    query_types = [
        "SELECT",
        "INSERT",
        "UPDATE",
        "DELETE",
        "CREATE",
        "ALTER",
        "DROP",
        "COPY",
        "MERGE",
        "TRUNCATE"
    ]

    selected = st.sidebar.multiselect(
        "Select Query Types",
        options=query_types,
        default=[],
        key=f"{key_prefix}_query_types",
        help="Leave empty to include all types"
    )

    if not selected:
        st.sidebar.info("Showing all query types")
        return query_types

    return selected


def render_environment_filter(key_prefix="main"):
    """
    Render environment filter in sidebar.

    Args:
        key_prefix: Unique prefix for widget keys

    Returns:
        List of selected environments
    """
    st.sidebar.markdown("### 🌍 Environments")

    environments = ["PROD", "QA", "DEV", "SANDBOX"]

    selected = st.sidebar.multiselect(
        "Select Environments",
        options=environments,
        default=[],
        key=f"{key_prefix}_environments",
        help="Leave empty to include all environments"
    )

    if not selected:
        st.sidebar.info("Showing all environments")
        return environments

    return selected


def render_refresh_button(key_prefix="main"):
    """
    Render refresh button in sidebar.

    Args:
        key_prefix: Unique prefix for widget keys

    Returns:
        Boolean indicating if button was clicked
    """
    st.sidebar.markdown("---")
    return st.sidebar.button(
        "🔄 Refresh Data",
        key=f"{key_prefix}_refresh",
        use_container_width=True,
        type="primary"
    )


def render_period_selector(key_prefix="main"):
    """
    Render period aggregation selector.

    Args:
        key_prefix: Unique prefix for widget keys

    Returns:
        Selected period ('DAILY', 'WEEKLY', 'MONTHLY', 'QUARTERLY')
    """
    period = st.sidebar.selectbox(
        "Aggregation Period",
        options=["DAILY", "WEEKLY", "MONTHLY", "QUARTERLY"],
        index=2,  # Default to MONTHLY
        key=f"{key_prefix}_period"
    )

    return period
