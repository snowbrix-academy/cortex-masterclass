# Module 01: Foundation Setup

**Duration:** ~25 minutes
**Difficulty:** Beginner
**Prerequisites:** Snowflake account with ACCOUNTADMIN access, basic SQL knowledge

---

## Script Structure

### 1. HOOK (30 seconds)

Every production-grade data platform starts with architecture decisions that determine scalability, maintainability, and cost efficiency for years to come.

Get the foundation wrong, and you'll fight technical debt forever. Get it right, and the rest builds smoothly.

In this module, we're building the architectural foundation for the Enterprise FinOps Dashboard: two databases with seven schemas, three compute warehouses sized correctly, a four-role RBAC model with least-privilege access, and resource monitors to cap framework costs at $150/month.

This is the backbone. Everything else depends on these decisions.

---

### 2. CORE CONTENT (20-22 minutes)

#### Section 2.1: Database Architecture — CONTROL vs ANALYTICS

**Visual on screen:**
- Two-database architecture diagram
- FINOPS_CONTROL_DB with 7 schemas highlighted
- FINOPS_ANALYTICS_DB with 3 schemas highlighted
- Data flow arrows between them

**Key concept:**

We're creating TWO databases, not one. This separation is intentional and critical:

**FINOPS_CONTROL_DB** = Single source of truth
- Raw cost facts from ACCOUNT_USAGE
- Stored procedures and business logic
- Chargeback attribution dimensions
- Budget definitions and alerts
- Configuration and metadata

**FINOPS_ANALYTICS_DB** = Performance layer
- Pre-aggregated metrics at daily/weekly/monthly grain
- Optimized for BI tool consumption (Power BI, Tableau)
- Prevents expensive ad-hoc aggregations on raw data
- Different retention policies (analytics can truncate old aggregates)

**Why separate?**

1. **Performance:** BI tools query pre-aggregated analytics DB, never hitting expensive raw data tables
2. **Security:** Control DB has stricter access controls; analytics DB is more permissive for reporting users
3. **Scalability:** Can scale read workloads independently of write workloads
4. **Cost optimization:** Analytics DB uses separate warehouse, preventing BI queries from impacting framework operations

**Schema breakdown for CONTROL DB:**

```
FINOPS_CONTROL_DB
├── CONFIG              → Global settings, credit pricing, tag taxonomy
├── COST_DATA           → Raw cost facts (warehouse, query, storage, serverless)
├── CHARGEBACK          → Attribution dimensions (SCD Type 2), attributed costs
├── BUDGET              → Budget definitions, vs actual, alerts, forecasts
├── OPTIMIZATION        → Recommendations, idle warehouse logs
├── PROCEDURES          → All stored procedures (JavaScript)
└── MONITORING          → Semantic views for reporting with row-level security
```

**Schema breakdown for ANALYTICS DB:**

```
FINOPS_ANALYTICS_DB
├── DAILY_AGGREGATES    → Daily rollups by warehouse, team, dept, project
├── WEEKLY_AGGREGATES   → Weekly rollups for trend analysis
└── MONTHLY_AGGREGATES  → Monthly rollups for budget comparisons
```

**Common mistake:**

Many teams put everything in one database with a single schema. This creates:
- Performance bottlenecks (BI tools aggregate raw query history)
- Security issues (everyone needs access to everything)
- Maintenance nightmares (can't separate ETL from reporting workloads)

**Code walkthrough:**

```sql
-- Create control database
CREATE DATABASE IF NOT EXISTS FINOPS_CONTROL_DB
    COMMENT = 'FinOps Framework: Control database housing cost data, chargeback, budgets, procedures';

-- Create all schemas with descriptive comments
CREATE SCHEMA IF NOT EXISTS FINOPS_CONTROL_DB.CONFIG
    COMMENT = 'Global configuration, credit pricing, tag taxonomy';

CREATE SCHEMA IF NOT EXISTS FINOPS_CONTROL_DB.COST_DATA
    COMMENT = 'Raw cost facts from ACCOUNT_USAGE views';

-- ... (repeat for all schemas)

-- Create analytics database
CREATE DATABASE IF NOT EXISTS FINOPS_ANALYTICS_DB
    COMMENT = 'Pre-aggregated metrics for fast BI tool consumption';
```

**Expected result:**

After running script 01, you'll have two databases with 10 total schemas, all visible in Snowsight's database browser.

---

#### Section 2.2: Warehouse Sizing Strategy

**Visual on screen:**
- Three warehouse boxes with size labels (XSMALL, SMALL, SMALL w/ multi-cluster)
- Comparison table showing credits per hour
- Cost calculator: XSMALL = 1 credit/hr × $3 = $3/hr × 24hr × 30days = $2,160/mo if running continuously
- With auto-suspend: XSMALL running 1hr/day = $90/month

**The three warehouses:**

**1. FINOPS_WH_ADMIN (XSMALL)**
- **Purpose:** Admin tasks, one-time operations, manual queries
- **Size:** XSMALL (1 credit/hour)
- **Auto-suspend:** 300 seconds (5 minutes)
- **Reasoning:** Rarely used, low concurrency, cost-sensitive
- **Estimated cost:** ~$10-20/month

**2. FINOPS_WH_ETL (SMALL)**
- **Purpose:** Scheduled cost collection procedures (hourly/daily tasks)
- **Size:** SMALL (2 credits/hour)
- **Auto-suspend:** 60 seconds (aggressive)
- **Reasoning:** Predictable workload, no concurrent queries, short-duration operations
- **Estimated cost:** ~$50-80/month

**3. FINOPS_WH_REPORTING (SMALL, multi-cluster)**
- **Purpose:** BI tools (Power BI, Tableau), Streamlit dashboard, ad-hoc analysis
- **Size:** SMALL (2 credits/hour per cluster)
- **Multi-cluster:** MIN 1, MAX 3 (scales for concurrency)
- **Auto-suspend:** 180 seconds (3 minutes)
- **Reasoning:** High concurrency from multiple users, read-only queries, needs scaling
- **Estimated cost:** ~$60-100/month (depending on concurrency)

**Total framework cost: $120-200/month** (depending on usage patterns)

**Sizing principles:**

- **Start small, scale if needed:** Begin with smaller warehouses; monitor query queue time
- **Aggressive auto-suspend for batch workloads:** ETL warehouse suspends after 60 seconds
- **Multi-cluster for concurrency, not speed:** Reporting warehouse scales OUT (more clusters), not UP (bigger size)
- **Separate concerns:** Never mix ETL and reporting on same warehouse (cost attribution becomes impossible)

**Common mistakes:**

1. **Starting with LARGE warehouses:** Wastes 8x the credits of SMALL
2. **Long auto-suspend timeouts:** 10+ minutes = paying for idle time
3. **Single warehouse for everything:** Can't attribute costs or tune independently
4. **Multi-cluster for batch ETL:** Multi-cluster is for concurrency, not batch processing

**Code walkthrough:**

```sql
-- ADMIN warehouse: Rarely used, cost-sensitive
CREATE WAREHOUSE IF NOT EXISTS FINOPS_WH_ADMIN
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 300            -- 5 minutes
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE    -- Don't start consuming credits immediately
    COMMENT = 'FinOps Framework: Admin operations';

-- ETL warehouse: Scheduled tasks, aggressive auto-suspend
CREATE WAREHOUSE IF NOT EXISTS FINOPS_WH_ETL
    WAREHOUSE_SIZE = 'SMALL'
    AUTO_SUSPEND = 60             -- 1 minute (aggressive)
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'FinOps Framework: Cost collection and chargeback procedures';

-- REPORTING warehouse: Multi-cluster for concurrency
CREATE WAREHOUSE IF NOT EXISTS FINOPS_WH_REPORTING
    WAREHOUSE_SIZE = 'SMALL'
    MIN_CLUSTER_COUNT = 1
    MAX_CLUSTER_COUNT = 3         -- Scales to 3 clusters for concurrency
    SCALING_POLICY = 'STANDARD'   -- Moderate scaling (waits ~1min before scaling)
    AUTO_SUSPEND = 180            -- 3 minutes
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'FinOps Framework: BI tools, Streamlit, reporting queries';
```

**Verification query:**

```sql
SHOW WAREHOUSES LIKE 'FINOPS_%';
```

Expected result: 3 warehouses, all SUSPENDED initially, with correct sizes and auto-suspend values.

---

#### Section 2.3: Resource Monitors — Framework Cost Cap

**Visual on screen:**
- Resource monitor gauge showing 50 credit threshold
- Alert tier visualization (80%, 90%, 100%)
- Cost calculation: 50 credits × $3 = $150 cap

**Why resource monitors?**

Even with correct sizing, a runaway task or accidental query could consume thousands of credits. Resource monitors act as circuit breakers.

**Framework cost cap:**

- **50 credits/month threshold**
- At $3/credit = $150/month cap
- Alerts at 80% (40 credits), 90% (45 credits), suspend at 100% (50 credits)

**Three alert tiers:**

1. **80% consumed:** Email notification to FinOps admin (soft warning)
2. **90% consumed:** Email + Slack alert (critical warning)
3. **100% consumed:** SUSPEND all framework warehouses immediately (hard block)

**What happens when suspended?**

- All FINOPS_WH_* warehouses stop accepting new queries
- In-progress queries complete (not killed mid-execution)
- Manual intervention required to re-enable (prevents accidental runaway costs)
- ACCOUNTADMIN can always override

**Code walkthrough:**

```sql
-- Create resource monitor
CREATE RESOURCE MONITOR IF NOT EXISTS FINOPS_FRAMEWORK_MONITOR
    WITH CREDIT_QUOTA = 50                    -- 50 credits/month
    FREQUENCY = MONTHLY                       -- Resets first day of month
    START_TIMESTAMP = IMMEDIATELY             -- Start monitoring now
    TRIGGERS
        ON 80 PERCENT DO NOTIFY              -- Soft warning
        ON 90 PERCENT DO NOTIFY              -- Critical warning
        ON 100 PERCENT DO SUSPEND            -- Hard block (suspend warehouses)
    ;

-- Assign monitor to all framework warehouses
ALTER WAREHOUSE FINOPS_WH_ADMIN SET RESOURCE_MONITOR = FINOPS_FRAMEWORK_MONITOR;
ALTER WAREHOUSE FINOPS_WH_ETL SET RESOURCE_MONITOR = FINOPS_FRAMEWORK_MONITOR;
ALTER WAREHOUSE FINOPS_WH_REPORTING SET RESOURCE_MONITOR = FINOPS_FRAMEWORK_MONITOR;
```

**Best practices:**

- Set monitor BEFORE resuming warehouses or creating tasks
- Start conservative (50 credits); increase if legitimate usage needs more
- Monitor monthly consumption trends; adjust quota if consistently hitting cap
- Configure email notifications to go to FinOps team distribution list

**Common mistake:**

Setting credit quota too low and hitting suspension during month-end reporting. Start at 50 credits, monitor actual consumption for 1-2 months, then adjust.

---

#### Section 2.4: RBAC Model — Four Roles with Least-Privilege

**Visual on screen:**
- Role hierarchy diagram showing ACCOUNTADMIN → SYSADMIN → 4 FinOps roles
- Permission matrix table
- Example use cases for each role

**The four roles:**

**1. FINOPS_ADMIN_ROLE**
- **Permissions:** Full read/write on all schemas, execute all procedures, manage config
- **Use case:** FinOps team members, platform admins building/maintaining framework
- **Users:** 2-5 people (tight control)

**2. FINOPS_ANALYST_ROLE**
- **Permissions:** Read-only on all views and cost tables, can export data
- **Use case:** Finance analysts, data governance team, auditors
- **Users:** 5-20 people (broader read access)

**3. FINOPS_TEAM_LEAD_ROLE**
- **Permissions:** Read-only on own team's costs via row-level security in views
- **Use case:** Engineering team leads, project managers wanting visibility into their team's spend
- **Users:** 10-50 people (self-service access)

**4. FINOPS_EXECUTIVE_ROLE**
- **Permissions:** Read-only on executive summary views only (no query-level details)
- **Use case:** CFO, VP Finance, executive leadership needing high-level KPIs
- **Users:** 5-10 people (summary access only)

**Role hierarchy:**

```
ACCOUNTADMIN (Snowflake built-in)
    └── SYSADMIN (Snowflake built-in)
        └── FINOPS_ADMIN_ROLE (full framework access)
            ├── FINOPS_ANALYST_ROLE (read-only all data)
            ├── FINOPS_TEAM_LEAD_ROLE (read-only team data)
            └── FINOPS_EXECUTIVE_ROLE (read-only summary)
```

**Permission grants:**

```sql
-- FINOPS_ADMIN_ROLE: Full access
GRANT USAGE ON DATABASE FINOPS_CONTROL_DB TO ROLE FINOPS_ADMIN_ROLE;
GRANT ALL ON ALL SCHEMAS IN DATABASE FINOPS_CONTROL_DB TO ROLE FINOPS_ADMIN_ROLE;
GRANT ALL ON ALL TABLES IN DATABASE FINOPS_CONTROL_DB TO ROLE FINOPS_ADMIN_ROLE;
GRANT ALL ON ALL VIEWS IN DATABASE FINOPS_CONTROL_DB TO ROLE FINOPS_ADMIN_ROLE;
GRANT USAGE ON ALL PROCEDURES IN SCHEMA FINOPS_CONTROL_DB.PROCEDURES TO ROLE FINOPS_ADMIN_ROLE;
GRANT USAGE ON ALL WAREHOUSES LIKE 'FINOPS_%' TO ROLE FINOPS_ADMIN_ROLE;

-- FINOPS_ANALYST_ROLE: Read-only
GRANT USAGE ON DATABASE FINOPS_CONTROL_DB TO ROLE FINOPS_ANALYST_ROLE;
GRANT USAGE ON ALL SCHEMAS IN DATABASE FINOPS_CONTROL_DB TO ROLE FINOPS_ANALYST_ROLE;
GRANT SELECT ON ALL TABLES IN SCHEMA FINOPS_CONTROL_DB.COST_DATA TO ROLE FINOPS_ANALYST_ROLE;
GRANT SELECT ON ALL VIEWS IN SCHEMA FINOPS_CONTROL_DB.MONITORING TO ROLE FINOPS_ANALYST_ROLE;
-- No procedure execution rights, no warehouse usage (reads via FINOPS_WH_REPORTING only)
```

**Future grants:**

Use FUTURE GRANTS to automatically grant permissions to newly created objects:

```sql
GRANT SELECT ON FUTURE TABLES IN SCHEMA FINOPS_CONTROL_DB.MONITORING TO ROLE FINOPS_ANALYST_ROLE;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA FINOPS_CONTROL_DB.MONITORING TO ROLE FINOPS_ANALYST_ROLE;
```

**Best practices:**

- Assign users to lowest-privilege role that meets their needs
- Review role membership quarterly (remove inactive users)
- Use Snowflake tags to enforce row-level security in views (covered in Module 07)
- Never grant ACCOUNTADMIN for day-to-day framework operations

---

### 3. HANDS-ON LAB (5-6 minutes)

**Lab Objective:** Execute the three foundation scripts and verify the framework skeleton is ready

**Steps:**

1. **Log into Snowsight**
   - Navigate to Worksheets → + (new worksheet)
   - Switch to ACCOUNTADMIN role (top-right dropdown)

2. **Run Script 01: Databases and Schemas**
   ```sql
   -- Open: module_01_foundation_setup/01_databases_and_schemas.sql
   -- Execute all statements (Cmd+A / Ctrl+A, then Run)
   ```
   - **Expected result:**
     - 2 databases created
     - 10 schemas created across both databases
     - No errors

3. **Verify databases and schemas**
   ```sql
   SHOW DATABASES LIKE 'FINOPS_%';
   -- Should return: FINOPS_CONTROL_DB, FINOPS_ANALYTICS_DB

   SHOW SCHEMAS IN DATABASE FINOPS_CONTROL_DB;
   -- Should return: CONFIG, COST_DATA, CHARGEBACK, BUDGET, OPTIMIZATION, PROCEDURES, MONITORING
   ```

4. **Run Script 02: Warehouses**
   ```sql
   -- Open: module_01_foundation_setup/02_warehouses.sql
   -- Execute all statements
   ```
   - **Expected result:**
     - 3 warehouses created (ADMIN, ETL, REPORTING)
     - 1 resource monitor created and assigned
     - All warehouses SUSPENDED initially

5. **Verify warehouses**
   ```sql
   SHOW WAREHOUSES LIKE 'FINOPS_%';
   -- Check: SIZE, AUTO_SUSPEND, MAX_CLUSTER_COUNT columns

   SHOW RESOURCE MONITORS LIKE 'FINOPS_%';
   -- Should show FINOPS_FRAMEWORK_MONITOR with 50 credit quota
   ```

6. **Run Script 03: Roles and Grants**
   ```sql
   -- Open: module_01_foundation_setup/03_roles_and_grants.sql
   -- Execute all statements
   ```
   - **Expected result:**
     - 4 roles created
     - Grants applied to roles
     - Future grants configured

7. **Verify roles**
   ```sql
   SHOW ROLES LIKE 'FINOPS_%';
   -- Should return: FINOPS_ADMIN_ROLE, FINOPS_ANALYST_ROLE, FINOPS_TEAM_LEAD_ROLE, FINOPS_EXECUTIVE_ROLE

   SHOW GRANTS TO ROLE FINOPS_ADMIN_ROLE;
   -- Should show database, schema, warehouse grants
   ```

8. **Test role switching**
   ```sql
   -- Switch to FINOPS_ADMIN_ROLE (top-right dropdown)
   USE ROLE FINOPS_ADMIN_ROLE;
   USE WAREHOUSE FINOPS_WH_ADMIN;

   -- Verify you can select from config schema
   SELECT * FROM FINOPS_CONTROL_DB.CONFIG.GLOBAL_SETTINGS;
   -- Should return empty table (we haven't populated config yet)
   ```

**Expected Results:**
- All databases, warehouses, roles created successfully
- No error messages
- You can switch to FINOPS_ADMIN_ROLE and use framework warehouses
- Resource monitor is active and monitoring consumption

**Troubleshooting:**

- **Error: "Insufficient privileges"**
  - Solution: Make sure you're using ACCOUNTADMIN role for initial setup

- **Error: "Object already exists"**
  - Solution: Safe to ignore if re-running scripts (IF NOT EXISTS clauses handle this)

- **Warehouses not showing MIN_CLUSTER_COUNT**
  - Solution: MIN_CLUSTER_COUNT only visible for multi-cluster warehouses (FINOPS_WH_REPORTING)

---

### 4. RECAP (45 seconds)

In this module, you built the architectural foundation for the Enterprise FinOps Dashboard:

1. **Two-database architecture:** FINOPS_CONTROL_DB (single source of truth) + FINOPS_ANALYTICS_DB (performance layer)
2. **Seven schemas:** Separating config, cost data, chargeback, budgets, optimization, procedures, monitoring
3. **Three warehouses:** Sized correctly (XSMALL/SMALL) with aggressive auto-suspend
4. **Resource monitor:** 50 credit/month cap ($150) to prevent runaway costs
5. **Four-role RBAC:** Least-privilege access model (admin, analyst, team lead, executive)

This foundation supports enterprise scale: 1000+ users, 100+ warehouses, millions of queries per day.

Next up: **Module 02 — Cost Collection Procedures**. We'll build stored procedures to collect warehouse credits, query costs, and storage costs from ACCOUNT_USAGE views. This is where the real data starts flowing.

---

## Production Notes

- **B-roll suggestions:**
  - Snowsight showing database hierarchy
  - Warehouse size comparison table
  - Resource monitor alert email screenshot
  - Role permission matrix diagram

- **Screen recordings needed:**
  - Creating database and schemas in Snowsight
  - Showing warehouse auto-suspend in action (time-lapse)
  - Switching between roles and showing permission differences
  - Running SHOW commands to verify objects

- **Pause points:**
  - After explaining two-database architecture (key concept)
  - After warehouse sizing strategy (important decisions)
  - Before hands-on lab (let viewers prepare)

- **Emphasis words:**
  - "Two databases" (architecture decision)
  - "Aggressive auto-suspend" (cost optimization)
  - "Least-privilege" (security principle)
  - "50 credits" (cost cap)
  - "Production-ready" (not a toy setup)
