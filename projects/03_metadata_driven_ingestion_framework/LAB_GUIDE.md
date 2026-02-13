# Metadata-Driven Ingestion Framework (MDF) for Snowflake

## Snowbrix Academy — Production-Grade Data Engineering. No Fluff.

---

## What Is This?

A **complete, reusable, metadata-driven ingestion framework** for Snowflake that handles both structured (CSV) and semi-structured (JSON, Parquet, Avro, ORC) data through a single generic approach. No hardcoded scripts. No copy-paste. One framework, infinite sources.

**The Problem It Solves:**
- Traditional approach: 100 data sources = 100 COPY INTO scripts to maintain
- MDF approach: 100 data sources = 100 rows in a config table, 1 generic procedure

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    MDF ARCHITECTURE                              │
│                                                                 │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐      │
│  │  S3 / Azure  │    │   API / DB   │    │  Local Files │      │
│  │  / GCS       │    │   Extracts   │    │  (Dev/Test)  │      │
│  └──────┬───────┘    └──────┬───────┘    └──────┬───────┘      │
│         │                   │                   │               │
│         └───────────────────┼───────────────────┘               │
│                             │                                   │
│                    ┌────────▼────────┐                          │
│                    │   STAGES        │  (Internal / External)   │
│                    └────────┬────────┘                          │
│                             │                                   │
│         ┌───────────────────┼───────────────────┐               │
│         │                   │                   │               │
│   ┌─────▼─────┐     ┌──────▼──────┐     ┌──────▼──────┐       │
│   │ CONFIG DB │     │  RAW DB     │     │ STAGING DB  │       │
│   │           │     │             │     │             │       │
│   │ • Config  │────▶│ • CSV Data  │────▶│ • Cleaned   │       │
│   │ • Audit   │     │ • JSON Data │     │ • Validated │       │
│   │ • Procs   │     │ • Parquet   │     │ • Typed     │       │
│   │ • Monitor │     │ • Avro/ORC  │     │             │       │
│   └───────────┘     └─────────────┘     └──────┬──────┘       │
│                                                 │               │
│                                          ┌──────▼──────┐       │
│                                          │ CURATED DB  │       │
│                                          │             │       │
│                                          │ • Business  │       │
│                                          │   Ready     │       │
│                                          └─────────────┘       │
└─────────────────────────────────────────────────────────────────┘
```

---

## Module Structure

| Module | Topic | Duration | Key Skills |
|--------|-------|----------|------------|
| **01** | Foundation Setup | 20 min | Databases, schemas, warehouses, roles, RBAC |
| **02** | File Formats & Stages | 15 min | File formats (CSV/JSON/Parquet), internal/external stages |
| **03** | Config Tables | 20 min | Metadata design, ingestion config, audit tables |
| **04** | Core Stored Procedures | 30 min | Dynamic SQL, SP_GENERIC_INGESTION, SP_REGISTER_SOURCE |
| **05** | Structured Data (CSV) | 30 min | CSV ingestion, PUT files, verify loads |
| **06** | Semi-Structured Data | 45 min | JSON/Parquet ingestion, VARIANT, FLATTEN, views |
| **07** | Error Handling & Audit | 25 min | Validation, retry logic, error analysis |
| **08** | Automation | 25 min | Tasks, CRON scheduling, streams, CDC |
| **09** | Monitoring & Dashboards | 20 min | Views, KPIs, health checks, Snowsight dashboards |
| **10** | Schema Evolution | 30 min | Schema drift, multi-client, INFER_SCHEMA, Dynamic Tables |

**Total Lab Time: ~4-5 hours**

---

## Quick Start

### Prerequisites
- Snowflake account (any edition — trial works)
- ACCOUNTADMIN or SYSADMIN role access
- SnowSQL CLI or Snowsight web interface

### Setup (15 minutes)

Run these scripts in order:

```
1. module_01_foundation_setup/01_databases_and_schemas.sql
2. module_01_foundation_setup/02_warehouses.sql
3. module_01_foundation_setup/03_roles_and_grants.sql
4. module_02_file_formats_and_stages/01_file_formats.sql
5. module_02_file_formats_and_stages/02_stages.sql
6. module_03_config_tables/01_ingestion_config.sql
7. module_03_config_tables/02_audit_and_supporting_tables.sql
8. module_04_core_stored_procedures/01_sp_audit_log.sql
9. module_04_core_stored_procedures/02_sp_generic_ingestion.sql
10. module_04_core_stored_procedures/03_sp_register_source.sql
```

Or use: `utilities/quick_start.sql` for a guided walkthrough.

### Your First Ingestion (5 minutes)

```sql
-- 1. Register a source (one command!)
CALL MDF_CONTROL_DB.PROCEDURES.SP_REGISTER_SOURCE(
    'MY_FIRST_SOURCE',    -- source name
    'MY_CLIENT',          -- client name
    'CSV',                -- file type
    'RAW_MY_DATA',        -- target table
    '.*[.]csv',           -- file pattern
    'my_data/'            -- sub-directory in stage
);

-- 2. Upload a file
-- PUT file://path/to/data.csv @MDF_CONTROL_DB.CONFIG.MDF_STG_INTERNAL_CSV/my_data/;

-- 3. Run ingestion
CALL MDF_CONTROL_DB.PROCEDURES.SP_GENERIC_INGESTION('MY_FIRST_SOURCE', FALSE);

-- 4. Check results
SELECT * FROM MDF_CONTROL_DB.AUDIT.INGESTION_AUDIT_LOG
WHERE SOURCE_NAME = 'MY_FIRST_SOURCE'
ORDER BY CREATED_AT DESC LIMIT 1;
```

---

## Project Structure

```
03_metadata_driven_ingestion_framework/
│
├── module_01_foundation_setup/
│   ├── 01_databases_and_schemas.sql    # Create MDF databases & schemas
│   ├── 02_warehouses.sql               # Compute & resource monitors
│   └── 03_roles_and_grants.sql         # RBAC role hierarchy
│
├── module_02_file_formats_and_stages/
│   ├── 01_file_formats.sql             # CSV, JSON, Parquet, Avro, ORC formats
│   └── 02_stages.sql                   # Internal + external stage templates
│
├── module_03_config_tables/
│   ├── 01_ingestion_config.sql         # Master config table + sample data
│   └── 02_audit_and_supporting_tables.sql  # Audit, error, registry tables
│
├── module_04_core_stored_procedures/
│   ├── 01_sp_audit_log.sql             # Logging procedures
│   ├── 02_sp_generic_ingestion.sql     # THE main ingestion engine
│   └── 03_sp_register_source.sql       # Easy source onboarding
│
├── module_05_structured_data_csv/
│   └── 01_csv_ingestion_lab.sql        # Hands-on CSV lab
│
├── module_06_semi_structured_data/
│   └── 01_json_ingestion_lab.sql       # Hands-on JSON/Parquet lab
│
├── module_07_error_handling_and_audit/
│   └── 01_error_handling_lab.sql       # Validation & retry procedures
│
├── module_08_automation_tasks_streams/
│   └── 01_tasks_and_scheduling.sql     # Scheduled tasks & streams
│
├── module_09_monitoring_and_dashboards/
│   └── 01_monitoring_views.sql         # 7 monitoring views
│
├── module_10_schema_evolution_advanced/
│   └── 01_schema_evolution.sql         # Schema drift & multi-client
│
├── sample_data/
│   ├── csv/
│   │   ├── customers.csv               # 15 customer records
│   │   ├── orders.csv                  # 20 order records
│   │   └── products.csv                # 12 product records
│   └── json/
│       └── events.json                 # 10 clickstream events (nested JSON)
│
├── utilities/
│   ├── quick_start.sql                 # Guided setup script
│   └── cleanup.sql                     # Teardown all objects
│
└── LAB_GUIDE.md                        # This file
```

---

## Key Framework Objects

### Databases
| Database | Purpose |
|----------|---------|
| `MDF_CONTROL_DB` | Framework brain: configs, procedures, audit, monitoring |
| `MDF_RAW_DB` | Raw data landing zone (immutable) |
| `MDF_STAGING_DB` | Cleaned, validated, typed data |
| `MDF_CURATED_DB` | Business-ready, transformed data |

### Core Procedures
| Procedure | What It Does |
|-----------|-------------|
| `SP_GENERIC_INGESTION` | The engine: reads config, builds COPY INTO, executes, logs |
| `SP_REGISTER_SOURCE` | Onboard a new source with one call |
| `SP_LOG_INGESTION` | Write to audit log |
| `SP_VALIDATE_LOAD` | Post-load data quality checks |
| `SP_RETRY_FAILED_LOADS` | Auto-retry failed ingestion runs |
| `SP_DETECT_SCHEMA_CHANGES` | Compare file schema vs table schema |
| `SP_APPLY_SCHEMA_EVOLUTION` | Add new columns to target tables |
| `SP_ONBOARD_CLIENT` | Register multiple sources for a new client |

### Monitoring Views
| View | Dashboard Section |
|------|------------------|
| `VW_INGESTION_EXECUTIVE_SUMMARY` | Daily success rates, volume trends |
| `VW_SOURCE_HEALTH` | Per-source health status (HEALTHY/WARNING/CRITICAL) |
| `VW_THROUGHPUT_METRICS` | Rows and bytes loaded over time |
| `VW_ERROR_ANALYSIS` | Error patterns with severity classification |
| `VW_PERFORMANCE_METRICS` | Duration trends, P95, rows/second |
| `VW_OPERATIONAL_OVERVIEW` | Client-level config summary |
| `VW_DAILY_SUMMARY` | Today's KPIs at a glance |

---

## How to Add a New Client (Production Workflow)

```sql
-- Step 1: Register all sources with one call
CALL SP_ONBOARD_CLIENT(
    'ACME_CORP',
    PARSE_JSON('[
        {"name": "SALES",    "type": "CSV",     "table": "RAW_SALES",    "pattern": ".*sales.*[.]csv"},
        {"name": "EVENTS",   "type": "JSON",    "table": "RAW_EVENTS",   "pattern": ".*events.*[.]json"},
        {"name": "METRICS",  "type": "PARQUET", "table": "RAW_METRICS",  "pattern": ".*[.]parquet"}
    ]')
);

-- Step 2: Upload sample files and test
CALL SP_GENERIC_INGESTION('ACME_CORP_SALES', FALSE);

-- Step 3: Validate
CALL SP_VALIDATE_LOAD('batch-id', config_id, 'ACME_CORP_SALES');

-- Step 4: Check monitoring
SELECT * FROM VW_SOURCE_HEALTH WHERE CLIENT_NAME = 'ACME_CORP';
```

---

## Cleanup

To remove all MDF objects from your Snowflake account:

```sql
-- Run: utilities/cleanup.sql
```

This drops all databases, warehouses, roles, and resource monitors created by the framework.

---

## What Makes This Framework Production-Ready

1. **Metadata-Driven**: All behavior controlled by config tables, not code
2. **Audit Trail**: Every run logged with full details for compliance
3. **Error Isolation**: One source failure doesn't affect others
4. **Idempotent**: Re-running the same source skips already-loaded files
5. **Multi-Format**: CSV, JSON, Parquet, Avro, ORC from one procedure
6. **Multi-Client**: Natural isolation through schema-per-client design
7. **Schema Evolution**: Detect and handle column changes automatically
8. **Cost-Optimized**: Separate warehouses, resource monitors, auto-suspend
9. **RBAC**: Least-privilege roles with future grants
10. **Observable**: 7 monitoring views covering health, performance, errors

---

*Built by Snowbrix Academy — Production-Grade Data Engineering. No Fluff.*
