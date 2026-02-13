#!/usr/bin/env python3
"""
Create consolidated SQL worksheets for FinOps modules.
Combines all scripts from each module into single Snowsight-ready files.
"""

import os
from pathlib import Path
from typing import List, Tuple

# Module configuration
MODULES = [
    {
        "number": "01",
        "name": "Foundation Setup",
        "folder": "module_01_foundation_setup",
        "scripts": [
            "01_databases_and_schemas.sql",
            "02_warehouses.sql",
            "03_roles_and_grants.sql"
        ],
        "est_time": "15",
        "prereq": "ACCOUNTADMIN role access",
        "objects": [
            "Databases: FINOPS_CONTROL_DB, FINOPS_ANALYTICS_DB",
            "Schemas: CONFIG, COST_DATA, CHARGEBACK, BUDGET, OPTIMIZATION, PROCEDURES, MONITORING",
            "Warehouses: FINOPS_WH_ADMIN, FINOPS_WH_ETL, FINOPS_WH_REPORTING",
            "Resource Monitor: FINOPS_FRAMEWORK_MONITOR",
            "Roles: FINOPS_ADMIN_ROLE, FINOPS_ANALYST_ROLE, FINOPS_TEAM_LEAD_ROLE, FINOPS_EXECUTIVE_ROLE"
        ]
    },
    {
        "number": "02",
        "name": "Cost Collection",
        "folder": "module_02_cost_collection",
        "scripts": [
            "01_cost_tables.sql",
            "02_sp_collect_warehouse_costs.sql",
            "03_sp_collect_query_costs.sql",
            "04_sp_collect_storage_costs.sql"
        ],
        "est_time": "30",
        "prereq": "Module 01 completed",
        "objects": [
            "Tables: FACT_WAREHOUSE_COST_HISTORY, FACT_QUERY_COST_HISTORY, FACT_STORAGE_COST_HISTORY",
            "Table: FACT_SERVERLESS_COST_HISTORY, GLOBAL_SETTINGS, PROCEDURE_EXECUTION_LOG",
            "Procedures: SP_COLLECT_WAREHOUSE_COSTS, SP_COLLECT_QUERY_COSTS, SP_COLLECT_STORAGE_COSTS"
        ]
    },
    {
        "number": "03",
        "name": "Chargeback Attribution",
        "folder": "module_03_chargeback_attribution",
        "scripts": [
            "01_dimension_tables.sql",
            "02_attribution_logic.sql",
            "03_helper_procedures.sql"
        ],
        "est_time": "25",
        "prereq": "Module 02 completed",
        "objects": [
            "Dimension tables: DIM_COST_CENTER, DIM_TEAM, DIM_DEPARTMENT, DIM_PROJECT",
            "Mapping tables: DIM_USER_MAPPING, DIM_WAREHOUSE_MAPPING, DIM_ROLE_MAPPING (SCD Type 2)",
            "Attribution procedures and views"
        ]
    },
    {
        "number": "04",
        "name": "Budget Controls",
        "folder": "module_04_budget_controls",
        "scripts": [
            "01_budget_tables.sql",
            "02_budget_procedures.sql",
            "03_alert_procedures.sql"
        ],
        "est_time": "25",
        "prereq": "Module 03 completed",
        "objects": [
            "Tables: BUDGET_DEFINITIONS, BUDGET_VS_ACTUAL, BUDGET_ALERT_HISTORY",
            "Procedures: SP_CHECK_BUDGETS, SP_SEND_BUDGET_ALERTS, SP_FORECAST_COSTS"
        ]
    },
    {
        "number": "05",
        "name": "BI Tool Detection",
        "folder": "module_05_bi_tool_detection",
        "scripts": [
            "01_bi_tool_classification.sql",
            "02_bi_tool_analysis.sql"
        ],
        "est_time": "15",
        "prereq": "Module 02 completed",
        "objects": [
            "Tables: BI_TOOL_CLASSIFICATION_RULES, BI_TOOL_COST_SUMMARY",
            "Procedures: SP_CLASSIFY_BI_CHANNELS, SP_ANALYZE_BI_COSTS"
        ]
    },
    {
        "number": "06",
        "name": "Optimization Recommendations",
        "folder": "module_06_optimization_recommendations",
        "scripts": [
            "01_optimization_tables.sql",
            "02_optimization_procedures.sql",
            "03_optimization_views.sql"
        ],
        "est_time": "30",
        "prereq": "Module 02 completed",
        "objects": [
            "Tables: OPTIMIZATION_RECOMMENDATIONS, IDLE_WAREHOUSE_LOG, EXPENSIVE_QUERY_LOG",
            "Procedures: SP_GENERATE_RECOMMENDATIONS, SP_ANALYZE_IDLE_WAREHOUSES, SP_IDENTIFY_EXPENSIVE_QUERIES",
            "Views: VW_OPTIMIZATION_DASHBOARD, VW_COST_SAVING_OPPORTUNITIES"
        ]
    },
    {
        "number": "07",
        "name": "Monitoring Views",
        "folder": "module_07_monitoring_views",
        "scripts": [
            "01_executive_summary_views.sql",
            "02_warehouse_query_analytics.sql",
            "03_chargeback_reporting.sql"
        ],
        "est_time": "20",
        "prereq": "Modules 01-06 completed",
        "objects": [
            "Views: VW_EXECUTIVE_SUMMARY, VW_COST_TREND_DAILY, VW_COST_BREAKDOWN",
            "Views: VW_WAREHOUSE_ANALYTICS, VW_QUERY_ANALYTICS, VW_USER_COST_SUMMARY",
            "Views: VW_CHARGEBACK_REPORT, VW_TEAM_COSTS, VW_DEPARTMENT_COSTS (with row-level security)"
        ]
    },
    {
        "number": "08",
        "name": "Automation Tasks",
        "folder": "module_08_automation_tasks",
        "scripts": [
            "01_task_definitions.sql",
            "02_task_monitoring.sql"
        ],
        "est_time": "20",
        "prereq": "Modules 01-07 completed",
        "objects": [
            "Tasks: TASK_COLLECT_WAREHOUSE_COSTS, TASK_COLLECT_QUERY_COSTS, TASK_COLLECT_STORAGE_COSTS",
            "Tasks: TASK_CHECK_BUDGETS, TASK_GENERATE_RECOMMENDATIONS",
            "Views: VW_TASK_EXECUTION_HISTORY, VW_TASK_ERRORS"
        ]
    }
]

def create_header(module: dict) -> str:
    """Create module header block."""
    return f"""/*
#############################################################################
  FINOPS - Module {module['number']}: {module['name']}
  CONSOLIDATED WORKSHEET — Snowsight / VS Code Ready
#############################################################################
  SNOWBRIX ACADEMY — Enterprise FinOps Dashboard for Snowflake

  This worksheet contains:
    {''.join([f"- {script}\n    " for script in module['scripts']])}

  INSTRUCTIONS:
    - Run each section sequentially (top to bottom)
    - Requires Module {str(int(module['number']) - 1).zfill(2)} to be completed first (if applicable)
    - Estimated time: ~{module['est_time']} minutes

  PREREQUISITES:
    - {module['prereq']}
    - FINOPS_ADMIN_ROLE access
#############################################################################
*/


"""

def create_section_divider(script_name: str) -> str:
    """Create section divider between scripts."""
    return f"""-- ===========================================================================
-- {'=' * 75}
-- {script_name.upper()}
-- {'=' * 75}
-- ===========================================================================


"""

def create_footer(module: dict) -> str:
    """Create module footer block."""
    objects_list = '\n    - '.join(module['objects'])
    next_module = str(int(module['number']) + 1).zfill(2)

    return f"""

/*
#############################################################################
  MODULE {module['number']} COMPLETE!

  Objects Created:
    - {objects_list}

  Next: FINOPS - Module {next_module} ({MODULES[int(module['number'])]['name'] if int(module['number']) < len(MODULES) else 'COMPLETE - ALL MODULES DONE!'})
#############################################################################
*/
"""

def read_script_content(base_path: Path, module_folder: str, script_name: str) -> str:
    """Read script content, removing the header block."""
    script_path = base_path / module_folder / script_name
    with open(script_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Remove the comment block at the start (everything before first non-comment SQL)
    lines = content.split('\n')
    in_comment_block = False
    content_start = 0

    for i, line in enumerate(lines):
        stripped = line.strip()
        if stripped.startswith('/*'):
            in_comment_block = True
        elif stripped.endswith('*/') and in_comment_block:
            in_comment_block = False
            content_start = i + 1
            break
        elif not in_comment_block and stripped and not stripped.startswith('--'):
            # Found first SQL statement
            break

    # Return content from after the header block
    return '\n'.join(lines[content_start:]).strip()

def create_consolidated_worksheet(base_path: Path, module: dict) -> str:
    """Create a consolidated worksheet for a module."""
    content = []

    # Add header
    content.append(create_header(module))

    # Add each script
    for idx, script in enumerate(module['scripts'], 1):
        if idx > 1:
            content.append(create_section_divider(script.replace('.sql', '')))

        script_content = read_script_content(base_path, module['folder'], script)
        content.append(script_content)
        content.append('\n\n')

    # Add footer
    content.append(create_footer(module))

    return ''.join(content)

def main():
    """Main execution function."""
    # Base path to FinOps project
    base_path = Path("C:/work/code/youtube/snowbrix_academy/projects/04_enterprise_finops_dashboard")
    utilities_path = base_path / "utilities"

    print("Creating consolidated FinOps worksheets...")
    print("=" * 80)

    for module in MODULES:
        output_filename = f"FINOPS_Module_{module['number']}_{module['name'].replace(' ', '_')}.sql"
        output_path = utilities_path / output_filename

        print(f"\nModule {module['number']}: {module['name']}")
        print(f"  - Combining {len(module['scripts'])} scripts...")

        try:
            consolidated_content = create_consolidated_worksheet(base_path, module)

            with open(output_path, 'w', encoding='utf-8') as f:
                f.write(consolidated_content)

            file_size_kb = len(consolidated_content) / 1024
            line_count = consolidated_content.count('\n')

            print(f"  [OK] Created: {output_filename}")
            print(f"       Size: {file_size_kb:.1f} KB, Lines: {line_count}")

        except Exception as e:
            print(f"  [ERROR] {e}")

    print("\n" + "=" * 80)
    print("All consolidated worksheets created successfully!")
    print(f"Location: {utilities_path}")

if __name__ == "__main__":
    main()
