# Module 02: Cost Collection Procedures

**Duration:** ~35 minutes
**Difficulty:** Intermediate
**Prerequisites:** Module 01 completed, understanding of Snowflake ACCOUNT_USAGE schema

---

## Script Structure

### 1. HOOK (45 seconds)

Cost visibility starts with accurate data collection. Miss a cost component, and your chargeback is wrong. Collect duplicates, and you're overcharging teams. Ignore ACCOUNT_USAGE latency, and you're wondering why yesterday's data is missing.

In this module, we're building the data collection engine: four stored procedures that pull every Snowflake cost component from ACCOUNT_USAGE views — warehouse compute credits, query-level costs, storage costs, and serverless features — with proper handling of latency, idempotent processing, and credit-to-dollar conversion.

This is the foundation of accurate chargeback. Get this right, and everything downstream is reliable.

---

### 2. CORE CONTENT (29-31 minutes)

#### Section 2.1: Understanding Snowflake Cost Components

**Visual on screen:**
- Four cost buckets with icons: Compute, Storage, Cloud Services, Serverless
- Pie chart showing typical enterprise breakdown (70% compute, 20% storage, 5% cloud services, 5% serverless)
- Example invoice line items

**The four cost categories:**

**1. Compute Credits (Warehouses)**
- Source: `ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY`
- Grain: Per-minute time slices
- Components:
  - CREDITS_USED_COMPUTE (warehouse execution)
  - CREDITS_USED_CLOUD_SERVICES (metadata operations)
- Typical share: 60-75% of total Snowflake spend

**2. Storage Costs**
- Source: `ACCOUNT_USAGE.DATABASE_STORAGE_USAGE_HISTORY` and `TABLE_STORAGE_METRICS`
- Grain: Daily snapshots
- Components:
  - Active storage (current data)
  - Time-travel storage (historical versions within retention period)
  - Failsafe storage (7-day disaster recovery)
- Typical share: 15-25% of total spend
- Charged in TB-months (e.g., $23/TB-month on AWS US-EAST-1)

**3. Cloud Services Credits**
- Source: Same as compute (WAREHOUSE_METERING_HISTORY)
- **Critical rule:** Only charged if >10% of daily compute credits
- Covers: Query compilation, metadata operations, authentication, data transfer coordination
- Typical share: 0-10% (often $0 due to 10% threshold)

**4. Serverless Features**
- Sources: `TASK_HISTORY`, `PIPE_USAGE_HISTORY`, `MATERIALIZED_VIEW_REFRESH_HISTORY`, `AUTOMATIC_CLUSTERING_HISTORY`, `SEARCH_OPTIMIZATION_HISTORY`
- Grain: Per-execution
- Components:
  - Snowflake Tasks (scheduled jobs)
  - Snowpipe (continuous ingestion)
  - Materialized view refreshes
  - Automatic clustering
  - Search optimization service
- Typical share: 5-15% of total spend

**Key insight:**

Warehouse compute is the largest component but also the easiest to optimize. Storage is steady-state. Serverless can surprise you if not monitored.

---

#### Section 2.2: ACCOUNT_USAGE Latency — The Data Freshness Problem

**Visual on screen:**
- Timeline showing data creation → ACCOUNT_USAGE availability (45 min to 3 hour lag)
- Warning icon highlighting the gap
- Comparison table: INFORMATION_SCHEMA (real-time, 1-hour retention) vs ACCOUNT_USAGE (latent, 1-year retention)

**The latency reality:**

| View | Typical Latency | Retention | Use Case |
|------|-----------------|-----------|----------|
| INFORMATION_SCHEMA.QUERY_HISTORY | Minutes | 1 hour | Real-time monitoring |
| ACCOUNT_USAGE.QUERY_HISTORY | 45 min - 3 hours | 1 year | Cost analysis, chargeback |
| ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY | 45 minutes | 1 year | Warehouse cost tracking |
| ACCOUNT_USAGE.STORAGE_USAGE | ~24 hours | 1 year | Storage cost tracking |

**Why this matters for cost collection:**

- If you run cost collection at 9:00 AM, you'll only get data up to ~7:30 AM
- Collecting "yesterday's" data at midnight might only get data up to 9:00 PM yesterday
- Solution: Always respect a lookback buffer (2-3 hours minimum)

**Watermark strategy:**

Instead of collecting by calendar date boundaries, we track the last successfully collected timestamp and work forward incrementally.

```sql
-- Bad approach (calendar boundaries)
WHERE START_TIME >= '2024-01-15 00:00:00'  -- Might miss data due to latency

-- Good approach (watermark + buffer)
WHERE START_TIME >= DATEADD(HOUR, -3, :LAST_COLLECTION_TIMESTAMP)
```

**Common mistake:**

Running hourly cost collection and wondering why it only collects data from 3 hours ago. This is expected behavior due to ACCOUNT_USAGE latency. Design procedures to handle this gracefully.

---

#### Section 2.3: SP_COLLECT_WAREHOUSE_COSTS — Warehouse Credit Consumption

**Visual on screen:**
- Flowchart showing procedure execution flow
- WAREHOUSE_METERING_HISTORY table structure
- Credit-to-dollar conversion formula
- Code walkthrough with line numbers

**What this procedure does:**

1. Retrieves last collection timestamp (watermark) from metadata table
2. Queries WAREHOUSE_METERING_HISTORY for new records (with 2-hour buffer for latency)
3. Retrieves credit price from CONFIG.GLOBAL_SETTINGS
4. Calculates USD cost: `credits_used × credit_price`
5. Calculates cost per second: `cost_usd / duration_seconds` (needed for query attribution)
6. Merges data into FACT_WAREHOUSE_COST_HISTORY (idempotent — won't create duplicates)
7. Updates watermark timestamp
8. Returns summary (rows collected, date range, credits total, cost total)

**Critical cost calculation:**

```javascript
// Credit price varies by contract, edition, cloud provider
var creditPriceUSD = 3.00;  // Example: Enterprise Edition on AWS

// Warehouse size determines credits per hour
// XSMALL = 1 credit/hr, SMALL = 2, MEDIUM = 4, LARGE = 8, etc.

// Per-minute cost calculation from WAREHOUSE_METERING_HISTORY
var creditsUsed = row.CREDITS_USED;  // Already computed by Snowflake
var costUSD = creditsUsed * creditPriceUSD;

// Cost per second for query attribution
var durationSeconds = (endTime - startTime) / 1000;  // milliseconds to seconds
var costPerSecond = costUSD / durationSeconds;
```

**Idempotent MERGE pattern:**

```sql
MERGE INTO FINOPS_CONTROL_DB.COST_DATA.FACT_WAREHOUSE_COST_HISTORY AS target
USING (
    SELECT
        START_TIME,
        END_TIME,
        WAREHOUSE_NAME,
        CREDITS_USED,
        CREDITS_USED_COMPUTE,
        CREDITS_USED_CLOUD_SERVICES,
        CREDITS_USED * :CREDIT_PRICE AS COST_USD
    FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
    WHERE START_TIME >= :LAST_WATERMARK
        AND START_TIME < DATEADD(HOUR, -2, CURRENT_TIMESTAMP())  -- Respect latency
) AS source
ON target.START_TIME = source.START_TIME
    AND target.WAREHOUSE_NAME = source.WAREHOUSE_NAME
WHEN MATCHED THEN UPDATE SET
    target.CREDITS_USED = source.CREDITS_USED,
    target.COST_USD = source.COST_USD
WHEN NOT MATCHED THEN INSERT (...)
    VALUES (...);
```

**Why MERGE instead of INSERT?**

- Safe to re-run procedure for same date range (won't create duplicates)
- Handles late-arriving data (if Snowflake updates ACCOUNT_USAGE retroactively)
- Supports backfilling historical data without cleanup

**Procedure parameters:**

```sql
SP_COLLECT_WAREHOUSE_COSTS(
    P_LOOKBACK_HOURS    NUMBER DEFAULT 24,      -- How far back to look
    P_INCREMENTAL       BOOLEAN DEFAULT TRUE    -- Use watermark (TRUE) or full refresh (FALSE)
)
```

**Expected runtime:** 10-30 seconds for 24 hours of data, scales linearly with history

---

#### Section 2.4: SP_COLLECT_QUERY_COSTS — Query-Level Attribution

**Visual on screen:**
- Query cost attribution formula
- QUERY_HISTORY table structure with key columns highlighted
- QUERY_TAG parsing logic diagram
- Example output showing query with attributed cost

**What makes query-level cost collection complex:**

Unlike warehouse-level costs (directly provided by Snowflake), query-level costs must be **calculated** based on:
- Query execution time
- Warehouse size active during execution
- Credit price

**The formula:**

```javascript
// Query execution time in hours
var executionTimeHours = EXECUTION_TIME_MS / 3600000;

// Warehouse size in credits per hour
// XSMALL=1, SMALL=2, MEDIUM=4, LARGE=8, XLARGE=16, 2XLARGE=32, etc.
var warehouseSizeCredits = getWarehouseCreditsPerHour(WAREHOUSE_SIZE);

// Credits consumed by this query
var creditsUsed = executionTimeHours * warehouseSizeCredits;

// Cost in USD
var costUSD = creditsUsed * creditPriceUSD;
```

**Attribution dimensions captured:**

From QUERY_HISTORY, we extract:
- USER_NAME (who ran the query)
- ROLE_NAME (which role was active)
- WAREHOUSE_NAME (which warehouse executed it)
- QUERY_TAG (user-set tag for project/team attribution)
- QUERY_TYPE (SELECT, INSERT, UPDATE, DELETE, MERGE, COPY, CREATE, etc.)
- DATABASE_NAME, SCHEMA_NAME (context)
- BYTES_SCANNED, ROWS_PRODUCED (for optimization analysis)
- EXECUTION_TIME, QUEUED_TIME (for performance analysis)

**QUERY_TAG parsing:**

Users can set tags to attribute queries to projects:

```sql
ALTER SESSION SET QUERY_TAG = 'PROJECT:CUSTOMER360|TEAM:DATA_ENG|DEPT:ENGINEERING';
```

The procedure parses this into structured columns:

```javascript
function parseQueryTag(queryTag) {
    var tags = {};
    if (queryTag) {
        var parts = queryTag.split('|');
        parts.forEach(function(part) {
            var kv = part.split(':');
            if (kv.length === 2) {
                tags[kv[0].toUpperCase()] = kv[1];
            }
        });
    }
    return tags;
}

// Extract: PROJECT, TEAM, DEPARTMENT from QUERY_TAG
var tags = parseQueryTag(row.QUERY_TAG);
var project = tags.PROJECT || 'UNALLOCATED';
var team = tags.TEAM || 'UNALLOCATED';
var department = tags.DEPARTMENT || 'UNALLOCATED';
```

**Handling NULL values:**

- USER_NAME can be NULL (system queries) → map to 'SYSTEM'
- QUERY_TAG often NULL → map to 'UNALLOCATED'
- WAREHOUSE_NAME can be NULL (lightweight queries) → exclude from cost (charged to cloud services)

**Performance optimization:**

QUERY_HISTORY is massive (millions of rows per day in large accounts). We:
- Filter to exclude system queries (USER_NAME != 'SNOWFLAKE')
- Partition table by date for automatic pruning
- Collect incrementally (last 24 hours, not full history)

**Expected runtime:** 1-3 minutes for 24 hours of data (depends on query volume)

---

#### Section 2.5: SP_COLLECT_STORAGE_COSTS — Storage Cost Calculation

**Visual on screen:**
- Storage cost breakdown chart (active vs time-travel vs failsafe)
- Per-TB pricing by cloud provider table
- DATABASE_STORAGE_USAGE_HISTORY structure

**Three types of storage:**

**1. Active storage**
- Current data in tables
- Charged at base rate (e.g., $23/TB-month on AWS)

**2. Time-travel storage**
- Historical versions within retention period (0-90 days)
- Charged at same rate as active storage
- Grows if tables have frequent updates/deletes

**3. Failsafe storage**
- 7-day disaster recovery period after time-travel
- Not user-accessible
- Charged at same rate
- Automatically purged after 7 days

**Cost formula:**

```sql
-- Monthly cost per database
monthly_storage_cost_usd =
    (average_active_bytes / 1099511627776) * storage_price_per_tb +        -- Active
    (average_time_travel_bytes / 1099511627776) * storage_price_per_tb +  -- Time-travel
    (average_failsafe_bytes / 1099511627776) * storage_price_per_tb       -- Failsafe

-- Note: 1099511627776 bytes = 1 TB
```

**Storage pricing varies by cloud:**

| Cloud | Region | Price per TB-month |
|-------|--------|-------------------|
| AWS | US-EAST-1 | $23 |
| AWS | EU-WEST-1 | $25 |
| Azure | East US 2 | $23 |
| GCP | US-CENTRAL1 | $23 |

**Data source:**

```sql
SELECT
    USAGE_DATE,
    DATABASE_NAME,
    AVERAGE_DATABASE_BYTES,              -- Active storage
    AVERAGE_FAILSAFE_BYTES,              -- Failsafe (7-day recovery)
    -- Time-travel calculated as: STORAGE_BYTES - DATABASE_BYTES - FAILSAFE_BYTES
    (STORAGE_BYTES - AVERAGE_DATABASE_BYTES - AVERAGE_FAILSAFE_BYTES) AS TIME_TRAVEL_BYTES
FROM SNOWFLAKE.ACCOUNT_USAGE.DATABASE_STORAGE_USAGE_HISTORY
WHERE USAGE_DATE >= :START_DATE
```

**Collection frequency:**

Storage data updates daily (not hourly like compute). Collect once per day, typically overnight.

**Expected runtime:** 10-20 seconds (storage data is small, one row per database per day)

---

#### Section 2.6: SP_COLLECT_SERVERLESS_COSTS — Tasks, Snowpipe, MV Refresh

**Visual on screen:**
- Five serverless feature icons
- Billing grain for each (per-execution, per-second, etc.)
- Cost comparison chart (which features cost the most)

**Serverless features tracked:**

**1. Snowflake Tasks**
- Source: `TASK_HISTORY`
- Billing: Per-second of execution time (uses serverless compute)
- Formula: `(execution_seconds / 3600) * serverless_credit_rate * credit_price`
- Note: Serverless compute typically costs more per credit than warehouse compute

**2. Snowpipe**
- Source: `PIPE_USAGE_HISTORY`
- Billing: Per-file processed + per-compute-second
- Common cost driver: Many small files (high overhead per file)

**3. Materialized Views**
- Source: `MATERIALIZED_VIEW_REFRESH_HISTORY`
- Billing: Per-refresh execution time
- Cost driver: Frequent refreshes on large base tables

**4. Automatic Clustering**
- Source: `AUTOMATIC_CLUSTERING_HISTORY`
- Billing: Per-second of clustering maintenance
- Cost driver: Tables with high DML and clustering keys

**5. Search Optimization Service**
- Source: `SEARCH_OPTIMIZATION_HISTORY`
- Billing: Per-table maintenance
- Cost driver: Large tables with search optimization enabled

**Collection strategy:**

Each serverless feature has its own ACCOUNT_USAGE view. We collect all five in one procedure for efficiency:

```javascript
// Collect Tasks
var taskData = collectFromTaskHistory(startDate, endDate);

// Collect Snowpipe
var pipeData = collectFromPipeUsageHistory(startDate, endDate);

// Collect Materialized Views
var mvData = collectFromMVRefreshHistory(startDate, endDate);

// ... repeat for clustering and search optimization

// Merge all into FACT_SERVERLESS_COST_HISTORY
mergeServerlessCosts(taskData, pipeData, mvData, ...);
```

**Why serverless costs matter:**

Even with no warehouses running, serverless features can consume 10-20% of total Snowflake spend. Many teams forget to monitor these.

---

### 3. HANDS-ON LAB (6-7 minutes)

**Lab Objective:** Execute cost collection procedures and verify data is flowing

**Steps:**

1. **Configure credit pricing**
   ```sql
   USE ROLE FINOPS_ADMIN_ROLE;
   USE WAREHOUSE FINOPS_WH_ADMIN;

   -- Set your actual Snowflake credit price (varies by contract)
   -- Standard Edition on AWS: ~$2-2.50
   -- Enterprise Edition: ~$3-4
   -- Business Critical: ~$4-5
   UPDATE FINOPS_CONTROL_DB.CONFIG.GLOBAL_SETTINGS
   SET SETTING_VALUE = '3.00'  -- Replace with your price
   WHERE SETTING_NAME = 'CREDIT_PRICE_USD';

   -- Verify
   SELECT * FROM FINOPS_CONTROL_DB.CONFIG.GLOBAL_SETTINGS
   WHERE SETTING_NAME = 'CREDIT_PRICE_USD';
   ```

2. **Create cost tables**
   ```sql
   -- Run: module_02_cost_collection/01_cost_tables.sql
   -- Creates: FACT_WAREHOUSE_COST_HISTORY, FACT_QUERY_COST_HISTORY, FACT_STORAGE_COST_HISTORY, FACT_SERVERLESS_COST_HISTORY
   ```

3. **Create cost collection procedures**
   ```sql
   -- Run: module_02_cost_collection/02_sp_collect_warehouse_costs.sql
   -- Run: module_02_cost_collection/03_sp_collect_query_costs.sql
   -- Run: module_02_cost_collection/04_sp_collect_storage_costs.sql
   ```

4. **Collect last 7 days of warehouse costs**
   ```sql
   CALL FINOPS_CONTROL_DB.PROCEDURES.SP_COLLECT_WAREHOUSE_COSTS(
       168,     -- 7 days * 24 hours = 168 hours
       FALSE    -- Full refresh (not incremental)
   );

   -- Output shows: Rows collected, date range, total credits, total cost USD
   ```

5. **Verify warehouse cost data**
   ```sql
   SELECT
       USAGE_DATE,
       WAREHOUSE_NAME,
       SUM(CREDITS_USED) AS TOTAL_CREDITS,
       SUM(COST_USD) AS TOTAL_COST_USD
   FROM FINOPS_CONTROL_DB.COST_DATA.FACT_WAREHOUSE_COST_HISTORY
   WHERE USAGE_DATE >= CURRENT_DATE() - 7
   GROUP BY USAGE_DATE, WAREHOUSE_NAME
   ORDER BY USAGE_DATE DESC, TOTAL_COST_USD DESC;
   ```

   **Expected result:** Rows for each warehouse used in last 7 days, with non-zero credits and costs

6. **Collect query costs**
   ```sql
   CALL FINOPS_CONTROL_DB.PROCEDURES.SP_COLLECT_QUERY_COSTS(
       168,     -- 7 days
       FALSE    -- Full refresh
   );
   ```

7. **View top 10 most expensive queries**
   ```sql
   SELECT
       QUERY_ID,
       USER_NAME,
       WAREHOUSE_NAME,
       EXECUTION_TIME_SECONDS,
       CREDITS_USED,
       COST_USD,
       QUERY_TEXT
   FROM FINOPS_CONTROL_DB.COST_DATA.FACT_QUERY_COST_HISTORY
   WHERE QUERY_DATE >= CURRENT_DATE() - 7
   ORDER BY COST_USD DESC
   LIMIT 10;
   ```

   **Expected result:** List of queries sorted by cost, showing user, warehouse, execution time

8. **Collect storage costs**
   ```sql
   CALL FINOPS_CONTROL_DB.PROCEDURES.SP_COLLECT_STORAGE_COSTS(
       CURRENT_DATE() - 7,
       CURRENT_DATE()
   );
   ```

9. **View storage costs by database**
   ```sql
   SELECT
       USAGE_DATE,
       DATABASE_NAME,
       ACTIVE_STORAGE_GB,
       TIME_TRAVEL_STORAGE_GB,
       FAILSAFE_STORAGE_GB,
       TOTAL_STORAGE_COST_USD
   FROM FINOPS_CONTROL_DB.COST_DATA.FACT_STORAGE_COST_HISTORY
   WHERE USAGE_DATE >= CURRENT_DATE() - 7
   ORDER BY USAGE_DATE DESC, TOTAL_STORAGE_COST_USD DESC;
   ```

**Expected Results:**
- All procedures execute successfully with summary output
- Cost tables populated with 7 days of historical data
- Costs calculated in USD based on configured credit price
- No duplicate rows (MERGE ensures idempotence)

**Troubleshooting:**

- **No data returned:**
  - Check if your account has been active for 7 days
  - Verify ACCOUNT_USAGE grants: `SHOW GRANTS ON DATABASE SNOWFLAKE;`
  - Reduce lookback period to 24 hours if newer account

- **Credit price seems wrong:**
  - Verify correct price in GLOBAL_SETTINGS
  - Check Snowflake contract/invoice for actual credit price
  - Different editions (Standard/Enterprise/Business Critical) have different prices

- **Query collection very slow:**
  - Normal for accounts with high query volume (millions of queries)
  - Add filter to QUERY_HISTORY: `WHERE TOTAL_ELAPSED_TIME > 1000` (exclude <1 second queries)

---

### 4. RECAP (45 seconds)

In this module, you built the cost collection engine for the Enterprise FinOps Dashboard:

1. **Four cost components:** Warehouse compute, query-level, storage, serverless features
2. **ACCOUNT_USAGE latency handling:** 2-hour buffer, watermark-based incremental collection
3. **SP_COLLECT_WAREHOUSE_COSTS:** Per-minute warehouse credit consumption with cost calculation
4. **SP_COLLECT_QUERY_COSTS:** Query-level attribution with QUERY_TAG parsing
5. **SP_COLLECT_STORAGE_COSTS:** Active, time-travel, and failsafe storage tracking
6. **Idempotent MERGE pattern:** Safe to re-run, won't create duplicates

You now have accurate, complete cost data flowing into FINOPS_CONTROL_DB.COST_DATA schema.

Next up: **Module 03 — Chargeback Attribution**. We'll build the attribution engine that maps these costs to teams, departments, projects, and cost centers using SCD Type 2 dimensions.

---

## Production Notes

- **B-roll suggestions:**
  - ACCOUNT_USAGE view query results
  - Cost table with thousands of rows
  - Credit pricing comparison table
  - Query execution visualization

- **Screen recordings needed:**
  - Running SP_COLLECT_WAREHOUSE_COSTS with output
  - Querying FACT_WAREHOUSE_COST_HISTORY results
  - Showing top expensive queries
  - QUERY_TAG in action (setting and querying)

- **Pause points:**
  - After explaining ACCOUNT_USAGE latency (complex concept)
  - After query cost formula (let it sink in)
  - Before hands-on lab

- **Emphasis words:**
  - "Idempotent" (won't create duplicates)
  - "Watermark" (incremental processing)
  - "10% threshold" (cloud services rule)
  - "Query-level attribution" (key capability)
  - "Complete cost visibility" (all components tracked)
