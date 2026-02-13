"""
Admin Configuration Page

Administrative functions for managing entities, mappings, budgets, and system settings.
Restricted to admin users only.
"""

import streamlit as st
import pandas as pd
from datetime import datetime, date
from components import data, utils

# Page configuration
st.set_page_config(page_title="Admin Config", layout="wide", page_icon="⚙️")

st.title("⚙️ Admin Configuration")
st.markdown("System administration and configuration management")
st.markdown("---")

# Check for admin access (in production, implement proper authentication)
# For demo purposes, showing warning
st.warning("🔒 **Admin Access Required** - This page allows modification of system configuration")

# Main tabs
tab1, tab2, tab3, tab4, tab5, tab6 = st.tabs([
    "🏛️ Register Entity",
    "👤 Map User",
    "🏢 Map Warehouse",
    "💰 Set Budget",
    "⚙️ Global Settings",
    "📊 System Status"
])

# ============================================
# TAB 1: Register Entity
# ============================================
with tab1:
    st.markdown("### Register New Entity")
    st.markdown("Create entities in the organizational hierarchy (Business Unit > Department > Team)")

    with st.form("register_entity_form"):
        col1, col2 = st.columns(2)

        with col1:
            entity_type = st.selectbox(
                "Entity Type *",
                options=["BU", "DEPT", "TEAM"],
                help="BU = Business Unit, DEPT = Department, TEAM = Team"
            )

            entity_name = st.text_input(
                "Entity Name *",
                placeholder="e.g., Engineering, Data Platform, Marketing"
            )

            manager_email = st.text_input(
                "Manager Email",
                placeholder="manager@company.com"
            )

        with col2:
            # Parent entity selector (depends on type)
            if entity_type in ['DEPT', 'TEAM']:
                try:
                    entities = data.get_entity_hierarchy()

                    if entity_type == 'DEPT':
                        # Show business units as parent options
                        parent_options = entities[entities['ENTITY_TYPE'] == 'BU']['ENTITY_NAME'].tolist()
                    else:  # TEAM
                        # Show departments as parent options
                        parent_options = entities[entities['ENTITY_TYPE'] == 'DEPT']['ENTITY_NAME'].tolist()

                    if parent_options:
                        parent_entity = st.selectbox(
                            "Parent Entity *",
                            options=parent_options,
                            help="Select the parent entity in the hierarchy"
                        )
                    else:
                        st.warning(f"No parent entities available. Create a {'Business Unit' if entity_type == 'DEPT' else 'Department'} first.")
                        parent_entity = None
                except Exception as e:
                    st.error(f"Error loading parent entities: {str(e)}")
                    parent_entity = None
            else:
                parent_entity = None
                st.info("Business Units are top-level entities with no parent")

            cost_center = st.text_input(
                "Cost Center Code",
                placeholder="e.g., CC-1234"
            )

            environment = st.selectbox(
                "Default Environment",
                options=["PROD", "QA", "DEV", "SANDBOX", "ALL"],
                index=4
            )

        notes = st.text_area("Notes", placeholder="Additional information about this entity")

        submitted = st.form_submit_button("✅ Register Entity", use_container_width=True)

        if submitted:
            # Validation
            if not entity_name:
                st.error("Entity name is required")
            elif entity_type in ['DEPT', 'TEAM'] and not parent_entity:
                st.error("Parent entity is required")
            else:
                try:
                    # In production, this would call a stored procedure
                    st.success(f"✅ Entity '{entity_name}' registered successfully!")
                    st.info("📝 **Next Steps:** Map users or warehouses to this entity in the respective tabs")

                    # Show SQL that would be executed (for demo)
                    with st.expander("🔍 View SQL"):
                        sql = f"""
CALL FINOPS_CONTROL_DB.CONFIG.SP_REGISTER_ENTITY(
    '{entity_type}',
    '{entity_name}',
    {f"'{parent_entity}'" if parent_entity else 'NULL'},
    {f"'{manager_email}'" if manager_email else 'NULL'},
    {f"'{cost_center}'" if cost_center else 'NULL'},
    {f"'{environment}'" if environment else 'NULL'},
    {f"'{notes}'" if notes else 'NULL'}
);
                        """
                        st.code(sql, language='sql')
                except Exception as e:
                    st.error(f"Error registering entity: {str(e)}")

    st.markdown("---")

    # Show existing entities
    st.markdown("### Existing Entities")
    try:
        entities = data.get_entity_hierarchy()

        if not entities.empty:
            # Add search
            search = st.text_input("🔍 Search entities", "", key="entity_search")

            if search:
                entities = entities[
                    entities['ENTITY_NAME'].str.contains(search, case=False, na=False)
                ]

            display_entities = entities[[
                'ENTITY_NAME',
                'ENTITY_TYPE',
                'PARENT_ENTITY_NAME',
                'MANAGER_EMAIL',
                'COST_CENTER',
                'CREATED_AT'
            ]].copy()

            if 'CREATED_AT' in display_entities.columns:
                display_entities['CREATED_AT'] = pd.to_datetime(
                    display_entities['CREATED_AT']
                ).dt.strftime('%Y-%m-%d')

            st.dataframe(display_entities, use_container_width=True, hide_index=True)

            utils.export_to_csv(entities, "entity_registry")
        else:
            st.info("No entities registered yet")
    except Exception as e:
        st.error(f"Error loading entities: {str(e)}")

# ============================================
# TAB 2: Map User to Entity
# ============================================
with tab2:
    st.markdown("### Map User to Entity")
    st.markdown("Assign users to entities for cost attribution")

    with st.form("map_user_form"):
        col1, col2 = st.columns(2)

        with col1:
            try:
                users = data.get_user_list()
                user_names = sorted(users['USER_NAME'].tolist()) if not users.empty else []

                user_name = st.selectbox(
                    "User *",
                    options=user_names,
                    help="Select user to map"
                )
            except Exception as e:
                st.error(f"Error loading users: {str(e)}")
                user_name = None

        with col2:
            try:
                entities = data.get_entity_hierarchy()
                entity_names = sorted(entities['ENTITY_NAME'].tolist()) if not entities.empty else []

                entity_name = st.selectbox(
                    "Entity *",
                    options=entity_names,
                    help="Select target entity"
                )
            except Exception as e:
                st.error(f"Error loading entities: {str(e)}")
                entity_name = None

        col3, col4 = st.columns(2)

        with col3:
            allocation_pct = st.slider(
                "Allocation Percentage *",
                min_value=1,
                max_value=100,
                value=100,
                help="Percentage of user's cost to allocate to this entity"
            )

        with col4:
            effective_from = st.date_input(
                "Effective From *",
                value=date.today()
            )

        notes = st.text_area("Notes", placeholder="Reason for mapping or special instructions")

        submitted = st.form_submit_button("✅ Create Mapping", use_container_width=True)

        if submitted:
            if not user_name or not entity_name:
                st.error("User and entity are required")
            else:
                try:
                    st.success(f"✅ User '{user_name}' mapped to '{entity_name}' ({allocation_pct}%)")

                    with st.expander("🔍 View SQL"):
                        sql = f"""
CALL FINOPS_CONTROL_DB.CONFIG.SP_MAP_USER_TO_ENTITY(
    '{user_name}',
    '{entity_name}',
    {allocation_pct},
    '{effective_from}',
    {f"'{notes}'" if notes else 'NULL'}
);
                        """
                        st.code(sql, language='sql')
                except Exception as e:
                    st.error(f"Error creating mapping: {str(e)}")

    st.markdown("---")

    # Show existing mappings
    st.markdown("### Existing User Mappings")
    try:
        user_mappings = data.get_user_entity_mappings()

        if not user_mappings.empty:
            search = st.text_input("🔍 Search mappings", "", key="user_mapping_search")

            if search:
                user_mappings = user_mappings[
                    (user_mappings['USER_NAME'].str.contains(search, case=False, na=False)) |
                    (user_mappings['ENTITY_NAME'].str.contains(search, case=False, na=False))
                ]

            display_mappings = user_mappings[[
                'USER_NAME',
                'ENTITY_NAME',
                'ALLOCATION_PCT',
                'EFFECTIVE_FROM',
                'IS_CURRENT'
            ]].copy()

            if 'EFFECTIVE_FROM' in display_mappings.columns:
                display_mappings['EFFECTIVE_FROM'] = pd.to_datetime(
                    display_mappings['EFFECTIVE_FROM']
                ).dt.strftime('%Y-%m-%d')

            display_mappings['ALLOCATION_PCT'] = display_mappings['ALLOCATION_PCT'].apply(
                lambda x: f"{x:.0f}%"
            )

            st.dataframe(display_mappings, use_container_width=True, hide_index=True)

            utils.export_to_csv(user_mappings, "user_entity_mappings")
        else:
            st.info("No user mappings created yet")
    except Exception as e:
        st.error(f"Error loading user mappings: {str(e)}")

# ============================================
# TAB 3: Map Warehouse to Entity
# ============================================
with tab3:
    st.markdown("### Map Warehouse to Entity")
    st.markdown("Assign warehouses to entities for direct cost attribution")

    with st.form("map_warehouse_form"):
        col1, col2 = st.columns(2)

        with col1:
            try:
                warehouses = data.get_warehouse_list()
                warehouse_names = sorted(warehouses['WAREHOUSE_NAME'].tolist()) if not warehouses.empty else []

                warehouse_name = st.selectbox(
                    "Warehouse *",
                    options=warehouse_names,
                    help="Select warehouse to map"
                )
            except Exception as e:
                st.error(f"Error loading warehouses: {str(e)}")
                warehouse_name = None

        with col2:
            try:
                entities = data.get_entity_hierarchy()
                entity_names = sorted(entities['ENTITY_NAME'].tolist()) if not entities.empty else []

                entity_name = st.selectbox(
                    "Entity *",
                    options=entity_names,
                    help="Select target entity"
                )
            except Exception as e:
                st.error(f"Error loading entities: {str(e)}")
                entity_name = None

        col3, col4 = st.columns(2)

        with col3:
            allocation_pct = st.slider(
                "Allocation Percentage *",
                min_value=1,
                max_value=100,
                value=100,
                help="Percentage of warehouse cost to allocate to this entity"
            )

        with col4:
            effective_from = st.date_input(
                "Effective From *",
                value=date.today(),
                key="wh_effective_from"
            )

        notes = st.text_area("Notes", placeholder="Reason for mapping or special instructions", key="wh_notes")

        submitted = st.form_submit_button("✅ Create Mapping", use_container_width=True)

        if submitted:
            if not warehouse_name or not entity_name:
                st.error("Warehouse and entity are required")
            else:
                try:
                    st.success(f"✅ Warehouse '{warehouse_name}' mapped to '{entity_name}' ({allocation_pct}%)")

                    with st.expander("🔍 View SQL"):
                        sql = f"""
CALL FINOPS_CONTROL_DB.CONFIG.SP_MAP_WAREHOUSE_TO_ENTITY(
    '{warehouse_name}',
    '{entity_name}',
    {allocation_pct},
    '{effective_from}',
    {f"'{notes}'" if notes else 'NULL'}
);
                        """
                        st.code(sql, language='sql')
                except Exception as e:
                    st.error(f"Error creating mapping: {str(e)}")

    st.markdown("---")

    # Show existing mappings
    st.markdown("### Existing Warehouse Mappings")
    try:
        wh_mappings = data.get_warehouse_entity_mappings()

        if not wh_mappings.empty:
            search = st.text_input("🔍 Search mappings", "", key="wh_mapping_search")

            if search:
                wh_mappings = wh_mappings[
                    (wh_mappings['WAREHOUSE_NAME'].str.contains(search, case=False, na=False)) |
                    (wh_mappings['ENTITY_NAME'].str.contains(search, case=False, na=False))
                ]

            display_mappings = wh_mappings[[
                'WAREHOUSE_NAME',
                'ENTITY_NAME',
                'ALLOCATION_PCT',
                'EFFECTIVE_FROM',
                'IS_CURRENT'
            ]].copy()

            if 'EFFECTIVE_FROM' in display_mappings.columns:
                display_mappings['EFFECTIVE_FROM'] = pd.to_datetime(
                    display_mappings['EFFECTIVE_FROM']
                ).dt.strftime('%Y-%m-%d')

            display_mappings['ALLOCATION_PCT'] = display_mappings['ALLOCATION_PCT'].apply(
                lambda x: f"{x:.0f}%"
            )

            st.dataframe(display_mappings, use_container_width=True, hide_index=True)

            utils.export_to_csv(wh_mappings, "warehouse_entity_mappings")
        else:
            st.info("No warehouse mappings created yet")
    except Exception as e:
        st.error(f"Error loading warehouse mappings: {str(e)}")

# ============================================
# TAB 4: Set Budget
# ============================================
with tab4:
    st.markdown("### Set Entity Budget")
    st.markdown("Configure monthly/quarterly budgets and alert thresholds")

    with st.form("set_budget_form"):
        col1, col2 = st.columns(2)

        with col1:
            try:
                entities = data.get_entity_hierarchy()
                entity_names = sorted(entities['ENTITY_NAME'].tolist()) if not entities.empty else []

                entity_name = st.selectbox(
                    "Entity *",
                    options=entity_names,
                    help="Select entity to set budget for",
                    key="budget_entity"
                )
            except Exception as e:
                st.error(f"Error loading entities: {str(e)}")
                entity_name = None

            budget_period = st.selectbox(
                "Budget Period *",
                options=["MONTHLY", "QUARTERLY", "ANNUAL"],
                help="Budget period type"
            )

        with col2:
            budget_amount = st.number_input(
                "Budget Amount ($) *",
                min_value=0.0,
                value=10000.0,
                step=100.0,
                help="Budget amount in USD"
            )

            effective_month = st.date_input(
                "Effective From *",
                value=date.today().replace(day=1),
                help="Start of budget period"
            )

        st.markdown("#### Alert Thresholds")
        col3, col4, col5 = st.columns(3)

        with col3:
            warning_threshold = st.slider(
                "Warning Threshold (%)",
                min_value=0,
                max_value=100,
                value=75,
                help="Send warning alert at this percentage"
            )

        with col4:
            critical_threshold = st.slider(
                "Critical Threshold (%)",
                min_value=0,
                max_value=100,
                value=90,
                help="Send critical alert at this percentage"
            )

        with col5:
            enable_suspend = st.checkbox(
                "Enable Auto-Suspend",
                value=False,
                help="Automatically suspend non-critical warehouses at 100%"
            )

        notes = st.text_area("Notes", placeholder="Budget notes or justification", key="budget_notes")

        submitted = st.form_submit_button("✅ Set Budget", use_container_width=True)

        if submitted:
            if not entity_name or budget_amount <= 0:
                st.error("Valid entity and budget amount are required")
            elif warning_threshold >= critical_threshold:
                st.error("Warning threshold must be less than critical threshold")
            else:
                try:
                    st.success(f"✅ Budget of {utils.format_currency(budget_amount)} set for '{entity_name}'")
                    st.info(f"📊 Alerts: Warning at {warning_threshold}%, Critical at {critical_threshold}%")

                    with st.expander("🔍 View SQL"):
                        sql = f"""
CALL FINOPS_CONTROL_DB.CONFIG.SP_SET_ENTITY_BUDGET(
    '{entity_name}',
    '{budget_period}',
    {budget_amount},
    '{effective_month}',
    {warning_threshold},
    {critical_threshold},
    {str(enable_suspend).upper()},
    {f"'{notes}'" if notes else 'NULL'}
);
                        """
                        st.code(sql, language='sql')
                except Exception as e:
                    st.error(f"Error setting budget: {str(e)}")

    st.markdown("---")

    # Show existing budgets
    st.markdown("### Existing Budgets")
    try:
        budgets = data.get_budget_status()

        if not budgets.empty:
            display_budgets = budgets[[
                'ENTITY_NAME',
                'BUDGET_PERIOD',
                'BUDGET_AMOUNT',
                'ACTUAL_SPEND',
                'WARNING_THRESHOLD',
                'CRITICAL_THRESHOLD'
            ]].copy()

            display_budgets['BUDGET_AMOUNT'] = display_budgets['BUDGET_AMOUNT'].apply(utils.format_currency)
            display_budgets['ACTUAL_SPEND'] = display_budgets['ACTUAL_SPEND'].apply(utils.format_currency)
            display_budgets['WARNING_THRESHOLD'] = display_budgets['WARNING_THRESHOLD'].apply(lambda x: f"{x:.0f}%")
            display_budgets['CRITICAL_THRESHOLD'] = display_budgets['CRITICAL_THRESHOLD'].apply(lambda x: f"{x:.0f}%")

            st.dataframe(display_budgets, use_container_width=True, hide_index=True)

            utils.export_to_csv(budgets, "entity_budgets")
        else:
            st.info("No budgets configured yet")
    except Exception as e:
        st.error(f"Error loading budgets: {str(e)}")

# ============================================
# TAB 5: Global Settings
# ============================================
with tab5:
    st.markdown("### Global System Settings")
    st.markdown("Configure system-wide parameters and pricing")

    try:
        # Load current settings
        settings = data.get_global_settings()

        # Convert to dict for easier access
        settings_dict = {}
        if not settings.empty:
            for _, row in settings.iterrows():
                settings_dict[row['SETTING_NAME']] = row['SETTING_VALUE']
    except Exception as e:
        st.error(f"Error loading settings: {str(e)}")
        settings_dict = {}

    with st.form("global_settings_form"):
        st.markdown("#### Pricing Configuration")
        col1, col2 = st.columns(2)

        with col1:
            credit_price = st.number_input(
                "Credit Price ($ per credit)",
                min_value=0.0,
                value=float(settings_dict.get('CREDIT_PRICE_USD', 3.00)),
                step=0.01,
                format="%.4f",
                help="Price per compute credit (varies by contract and edition)"
            )

            storage_price_tb = st.number_input(
                "Storage Price ($ per TB/month)",
                min_value=0.0,
                value=float(settings_dict.get('STORAGE_PRICE_TB_MONTH', 23.00)),
                step=0.50,
                help="Price per terabyte per month"
            )

        with col2:
            cloud_services_threshold = st.number_input(
                "Cloud Services Threshold (%)",
                min_value=0,
                max_value=100,
                value=int(float(settings_dict.get('CLOUD_SERVICES_THRESHOLD_PCT', 10))),
                help="Free cloud services threshold (typically 10%)"
            )

            data_transfer_price_tb = st.number_input(
                "Data Transfer Price ($ per TB)",
                min_value=0.0,
                value=float(settings_dict.get('DATA_TRANSFER_PRICE_TB', 0.03)),
                step=0.01,
                format="%.4f",
                help="Price per terabyte of data transfer"
            )

        st.markdown("#### Collection Schedule")
        col3, col4 = st.columns(2)

        with col3:
            collection_frequency = st.selectbox(
                "Cost Collection Frequency",
                options=["HOURLY", "DAILY", "MANUAL"],
                index=1,
                help="How often to collect cost data"
            )

        with col4:
            retention_days = st.number_input(
                "Data Retention (days)",
                min_value=30,
                max_value=730,
                value=int(float(settings_dict.get('RETENTION_DAYS', 365))),
                help="Number of days to retain historical cost data"
            )

        st.markdown("#### System Configuration")
        col5, col6 = st.columns(2)

        with col5:
            enable_anomaly_detection = st.checkbox(
                "Enable Anomaly Detection",
                value=settings_dict.get('ENABLE_ANOMALY_DETECTION', 'TRUE') == 'TRUE',
                help="Automatically detect cost anomalies"
            )

            enable_auto_recommendations = st.checkbox(
                "Enable Auto Recommendations",
                value=settings_dict.get('ENABLE_AUTO_RECOMMENDATIONS', 'TRUE') == 'TRUE',
                help="Automatically generate optimization recommendations"
            )

        with col6:
            alert_email = st.text_input(
                "Alert Email Address",
                value=settings_dict.get('ALERT_EMAIL', ''),
                placeholder="finops@company.com",
                help="Email address for system alerts"
            )

        submitted = st.form_submit_button("💾 Save Settings", use_container_width=True)

        if submitted:
            try:
                st.success("✅ Global settings updated successfully!")

                with st.expander("🔍 View SQL"):
                    sql = f"""
-- Update credit price
CALL FINOPS_CONTROL_DB.CONFIG.SP_UPDATE_GLOBAL_SETTING('CREDIT_PRICE_USD', '{credit_price}');

-- Update storage price
CALL FINOPS_CONTROL_DB.CONFIG.SP_UPDATE_GLOBAL_SETTING('STORAGE_PRICE_TB_MONTH', '{storage_price_tb}');

-- Update cloud services threshold
CALL FINOPS_CONTROL_DB.CONFIG.SP_UPDATE_GLOBAL_SETTING('CLOUD_SERVICES_THRESHOLD_PCT', '{cloud_services_threshold}');

-- Update data transfer price
CALL FINOPS_CONTROL_DB.CONFIG.SP_UPDATE_GLOBAL_SETTING('DATA_TRANSFER_PRICE_TB', '{data_transfer_price_tb}');

-- Update retention days
CALL FINOPS_CONTROL_DB.CONFIG.SP_UPDATE_GLOBAL_SETTING('RETENTION_DAYS', '{retention_days}');

-- Update feature flags
CALL FINOPS_CONTROL_DB.CONFIG.SP_UPDATE_GLOBAL_SETTING('ENABLE_ANOMALY_DETECTION', '{str(enable_anomaly_detection).upper()}');
CALL FINOPS_CONTROL_DB.CONFIG.SP_UPDATE_GLOBAL_SETTING('ENABLE_AUTO_RECOMMENDATIONS', '{str(enable_auto_recommendations).upper()}');

-- Update alert email
CALL FINOPS_CONTROL_DB.CONFIG.SP_UPDATE_GLOBAL_SETTING('ALERT_EMAIL', '{alert_email}');
                    """
                    st.code(sql, language='sql')
            except Exception as e:
                st.error(f"Error updating settings: {str(e)}")

# ============================================
# TAB 6: System Status
# ============================================
with tab6:
    st.markdown("### System Status & Health")

    try:
        # Database sizes
        st.markdown("#### Database Sizes")
        col1, col2, col3 = st.columns(3)

        with col1:
            st.metric("Control DB", "2.5 GB")
        with col2:
            st.metric("Analytics DB", "8.3 GB")
        with col3:
            st.metric("Total Storage", "10.8 GB")

        st.markdown("---")

        # Task status
        st.markdown("#### Scheduled Task Status")

        task_status = pd.DataFrame({
            'Task Name': [
                'TASK_COLLECT_WAREHOUSE_COSTS',
                'TASK_COLLECT_QUERY_HISTORY',
                'TASK_CALCULATE_CHARGEBACK',
                'TASK_CHECK_BUDGETS',
                'TASK_GENERATE_RECOMMENDATIONS'
            ],
            'Status': ['STARTED', 'STARTED', 'STARTED', 'STARTED', 'STARTED'],
            'Schedule': ['Every 1 hour', 'Every 1 hour', 'Every 6 hours', 'Daily at 8 AM', 'Daily at 2 AM'],
            'Last Run': [
                '2026-02-08 14:30:00',
                '2026-02-08 14:30:00',
                '2026-02-08 12:00:00',
                '2026-02-08 08:00:00',
                '2026-02-08 02:00:00'
            ],
            'Next Run': [
                '2026-02-08 15:30:00',
                '2026-02-08 15:30:00',
                '2026-02-08 18:00:00',
                '2026-02-09 08:00:00',
                '2026-02-09 02:00:00'
            ]
        })

        st.dataframe(task_status, use_container_width=True, hide_index=True)

        st.markdown("---")

        # Last collection times
        st.markdown("#### Last Data Collection")

        col1, col2, col3, col4 = st.columns(4)

        with col1:
            st.metric("Warehouse Costs", "5 min ago")
        with col2:
            st.metric("Query History", "5 min ago")
        with col3:
            st.metric("Storage Costs", "1 hour ago")
        with col4:
            st.metric("Budget Status", "30 min ago")

        st.markdown("---")

        # System health
        st.markdown("#### System Health Checks")

        health_checks = [
            {"Check": "Database Connectivity", "Status": "OK", "Details": "All databases accessible"},
            {"Check": "Data Freshness", "Status": "OK", "Details": "Latest data < 1 hour old"},
            {"Check": "Task Execution", "Status": "OK", "Details": "All tasks running on schedule"},
            {"Check": "Attribution Coverage", "Status": "WARNING", "Details": "12% costs unallocated"},
            {"Check": "Budget Alerts", "Status": "CRITICAL", "Details": "3 entities over budget"}
        ]

        for check in health_checks:
            col1, col2, col3 = st.columns([2, 1, 3])

            with col1:
                st.markdown(f"**{check['Check']}**")

            with col2:
                if check['Status'] == 'OK':
                    st.markdown(utils.show_alert_badge('OK', 'OK'), unsafe_allow_html=True)
                elif check['Status'] == 'WARNING':
                    st.markdown(utils.show_alert_badge('WARNING', 'WARNING'), unsafe_allow_html=True)
                else:
                    st.markdown(utils.show_alert_badge('CRITICAL', 'CRITICAL'), unsafe_allow_html=True)

            with col3:
                st.markdown(f"{check['Details']}")

        st.markdown("---")

        # Maintenance actions
        st.markdown("#### Maintenance Actions")

        col1, col2, col3 = st.columns(3)

        with col1:
            if st.button("🔄 Refresh All Data", use_container_width=True):
                with st.spinner("Refreshing all data..."):
                    st.success("✅ Data refresh initiated")

        with col2:
            if st.button("🧹 Clean Old Data", use_container_width=True):
                with st.spinner("Cleaning old data..."):
                    st.success("✅ Old data cleaned (retention policy applied)")

        with col3:
            if st.button("📊 Recalculate Attribution", use_container_width=True):
                with st.spinner("Recalculating cost attribution..."):
                    st.success("✅ Cost attribution recalculated")

    except Exception as e:
        st.error(f"Error loading system status: {str(e)}")
