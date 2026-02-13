# Module 03: Chargeback Attribution

**Duration:** ~40 minutes
**Difficulty:** Intermediate to Advanced
**Prerequisites:** Module 02 completed, understanding of dimensional modeling, SCD Type 2 concepts

---

## Script Structure

### 1. HOOK (45 seconds)

You've collected $150,000 worth of Snowflake costs this month. Finance asks: "Which teams are responsible?"

Without attribution, you have data but no answers. With proper chargeback, you have complete accountability: every dollar traced to a team, department, project, and cost center.

In this module, we're building the attribution engine: SCD Type 2 dimensions that handle team re orgs gracefully, a multi-dimensional attribution procedure that supports direct, proportional, and tag-based allocation, and an onboarding procedure that makes registering new teams effortless.

This is where cost data becomes actionable business intelligence.

---

### 2. CORE CONTENT (34-36 minutes)

#### Section 2.1: Attribution Hierarchy — The Dimensional Model

**Visual on screen:**
- Multi-dimensional attribution cube
- Attribution hierarchy diagram
- Example mapping table

**The attribution hierarchy:**

```
User → Role → Team → Department → Business Unit → Cost Center
         ↓
    Warehouse → Environment → Project/Application
         ↓
    Query Tag → BI Tool → Service Account
```

**Three attribution methods:**

**1. Direct Attribution (Preferred)**
- Dedicated warehouse per team: 100% of costs → team
- Example: WH_DATA_ENG_PROD → DATA_ENGINEERING team
- Simple, clear, no ambiguity
- **Recommendation:** Use this whenever possible

**2. Proportional Attribution (Shared Warehouses)**
- Formula: `team_cost = (team_query_credits / total_warehouse_credits) * warehouse_total_cost`
- Example: Team A uses 60% of warehouse credits → Team A pays 60% of total cost (including idle time)
- Idle time allocated proportionally to active usage
- More complex but necessary for shared infrastructure

**3. Tag-Based Attribution (Fine-Grained)**
- Query-level tags override warehouse-level attribution
- Example: `QUERY_TAG = 'PROJECT:CUSTOMER360|TEAM:MARKETING'`
- Enables project-level cost tracking on shared warehouses
- Most granular method

**Key principle:** Attribution method priority order:
1. QUERY_TAG (if present) — highest priority
2. Warehouse-to-team mapping (if exists)
3. Role-to-team mapping (fallback)
4. User-to-team mapping (last resort)
5. UNALLOCATED (if no match)

**Goal:** Keep unallocated costs <5% of total spend

---

#### Section 2.2: SCD Type 2 Dimensions — Handling Organizational Change

**Visual on screen:**
- SCD Type 2 table structure with effective dates
- Before/after reorg example
- Timeline showing old and new mappings

**Why SCD Type 2?**

Organizations change: teams merge, departments reorganize, warehouses get reassigned. Without history tracking, you can't:
- Report costs under both old and new structure during transitions
- Audit historical chargeback decisions
- Handle backfill cost attribution correctly

**SCD Type 2 pattern:**

```sql
CREATE TABLE DIM_COST_CENTER_MAPPING (
    MAPPING_SK          NUMBER AUTOINCREMENT PRIMARY KEY,
    WAREHOUSE_NAME      VARCHAR,
    ROLE_NAME           VARCHAR,
    TEAM                VARCHAR,
    DEPARTMENT          VARCHAR,
    BUSINESS_UNIT       VARCHAR,
    COST_CENTER         VARCHAR,
    PROJECT             VARCHAR,
    ENVIRONMENT         VARCHAR,
    EFFECTIVE_FROM      TIMESTAMP_NTZ NOT NULL,
    EFFECTIVE_TO        TIMESTAMP_NTZ DEFAULT '9999-12-31 23:59:59',
    IS_CURRENT          BOOLEAN DEFAULT TRUE,
    CREATED_AT          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_BY          VARCHAR
);
```

**Example: Team reorg on Feb 1, 2024**

Before reorg:
```
MAPPING_SK | WAREHOUSE_NAME    | TEAM           | EFFECTIVE_FROM | EFFECTIVE_TO | IS_CURRENT
1          | WH_ANALYTICS_PROD | ANALYTICS_TEAM | 2023-01-01     | 2024-01-31   | FALSE
```

After reorg (Analytics splits into ML and BI teams):
```
MAPPING_SK | WAREHOUSE_NAME    | TEAM       | EFFECTIVE_FROM | EFFECTIVE_TO | IS_CURRENT
1          | WH_ANALYTICS_PROD | ML_TEAM    | 2024-02-01     | 9999-12-31   | TRUE
2          | WH_BI_PROD        | BI_TEAM    | 2024-02-01     | 9999-12-31   | TRUE
```

**Temporal join for attribution:**

```sql
-- Attribute costs using mapping effective at cost date
SELECT
    c.USAGE_DATE,
    c.WAREHOUSE_NAME,
    c.COST_USD,
    m.TEAM,
    m.DEPARTMENT,
    m.COST_CENTER
FROM FINOPS_CONTROL_DB.COST_DATA.FACT_WAREHOUSE_COST_HISTORY c
LEFT JOIN FINOPS_CONTROL_DB.CHARGEBACK.DIM_COST_CENTER_MAPPING m
    ON c.WAREHOUSE_NAME = m.WAREHOUSE_NAME
    AND c.USAGE_DATE >= m.EFFECTIVE_FROM
    AND c.USAGE_DATE < m.EFFECTIVE_TO
```

This ensures January costs attribute to ANALYTICS_TEAM, and February costs attribute to ML_TEAM/BI_TEAM.

---

#### Section 2.3: DIM_COST_CENTER_MAPPING — The Master Mapping Table

**Visual on screen:**
- Mapping table ERD
- Example rows with different entity types
- Registration workflow diagram

**Table structure:**

```sql
CREATE TABLE DIM_COST_CENTER_MAPPING (
    MAPPING_SK          NUMBER AUTOINCREMENT,
    ENTITY_TYPE         VARCHAR,  -- 'WAREHOUSE', 'ROLE', 'USER'
    ENTITY_NAME         VARCHAR,  -- Warehouse/role/user name
    TEAM                VARCHAR,
    DEPARTMENT          VARCHAR,
    BUSINESS_UNIT       VARCHAR,
    COST_CENTER         VARCHAR,
    PROJECT             VARCHAR,
    ENVIRONMENT         VARCHAR,  -- PROD, QA, DEV, SANDBOX
    EFFECTIVE_FROM      TIMESTAMP_NTZ NOT NULL,
    EFFECTIVE_TO        TIMESTAMP_NTZ DEFAULT '9999-12-31 23:59:59',
    IS_CURRENT          BOOLEAN DEFAULT TRUE,
    CREATED_AT          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_BY          VARCHAR
);
```

**Three entity types:**

1. **Warehouse mappings** (preferred)
   ```sql
   ('WAREHOUSE', 'WH_DATA_ENG_PROD', 'PLATFORM_TEAM', 'DATA_ENGINEERING', 'ENGINEERING', 'CC-12345', NULL, 'PROD')
   ```

2. **Role mappings** (fallback for shared warehouses)
   ```sql
   ('ROLE', 'DATA_ENGINEER_ROLE', 'PLATFORM_TEAM', 'DATA_ENGINEERING', 'ENGINEERING', 'CC-12345', NULL, NULL)
   ```

3. **User mappings** (last resort)
   ```sql
   ('USER', 'jane.doe@company.com', 'ANALYTICS_TEAM', 'DATA_SCIENCE', 'ENGINEERING', 'CC-67890', 'CUSTOMER360', NULL)
   ```

**Indexing strategy:**

```sql
-- Optimize temporal joins
CREATE INDEX idx_ccm_entity ON DIM_COST_CENTER_MAPPING(ENTITY_TYPE, ENTITY_NAME, IS_CURRENT);
CREATE INDEX idx_ccm_dates ON DIM_COST_CENTER_MAPPING(EFFECTIVE_FROM, EFFECTIVE_TO);
```

---

#### Section 2.4: SP_CALCULATE_CHARGEBACK — The Attribution Engine

**Visual on screen:**
- Procedure flowchart
- Attribution logic decision tree
- Example input/output data

**What this procedure does:**

1. **Collect all costs for date range**
   - Warehouse costs from FACT_WAREHOUSE_COST_HISTORY
   - Query costs from FACT_QUERY_COST_HISTORY
   - Storage costs from FACT_STORAGE_COST_HISTORY

2. **Apply attribution rules** (priority order)
   - Check QUERY_TAG for explicit attribution
   - Match WAREHOUSE_NAME to DIM_COST_CENTER_MAPPING
   - Match ROLE_NAME to DIM_COST_CENTER_MAPPING
   - Match USER_NAME to DIM_COST_CENTER_MAPPING
   - Assign 'UNALLOCATED' if no match

3. **Handle shared warehouse costs**
   - Calculate each team's proportion of warehouse usage
   - Allocate idle time proportionally
   - Attribute cloud services credits proportionally

4. **Aggregate and store**
   - Summarize costs by team, department, project, cost center
   - Store in FACT_ATTRIBUTED_COST table
   - Include attribution method used (for audit trail)

**Attribution logic pseudo-code:**

```javascript
function attributeCost(query) {
    // Priority 1: QUERY_TAG
    if (query.QUERY_TAG) {
        var tags = parseQueryTag(query.QUERY_TAG);
        if (tags.TEAM) {
            return {
                team: tags.TEAM,
                project: tags.PROJECT,
                department: tags.DEPARTMENT,
                method: 'QUERY_TAG'
            };
        }
    }

    // Priority 2: Warehouse mapping
    var whMapping = lookupMapping('WAREHOUSE', query.WAREHOUSE_NAME, query.USAGE_DATE);
    if (whMapping) {
        return {
            team: whMapping.TEAM,
            department: whMapping.DEPARTMENT,
            costCenter: whMapping.COST_CENTER,
            method: 'WAREHOUSE_MAPPING'
        };
    }

    // Priority 3: Role mapping
    var roleMapping = lookupMapping('ROLE', query.ROLE_NAME, query.USAGE_DATE);
    if (roleMapping) {
        return {
            team: roleMapping.TEAM,
            department: roleMapping.DEPARTMENT,
            costCenter: roleMapping.COST_CENTER,
            method: 'ROLE_MAPPING'
        };
    }

    // Priority 4: User mapping
    var userMapping = lookupMapping('USER', query.USER_NAME, query.USAGE_DATE);
    if (userMapping) {
        return {..., method: 'USER_MAPPING'};
    }

    // Fallback: Unallocated
    return {
        team: 'UNALLOCATED',
        department: 'UNALLOCATED',
        costCenter: 'UNALLOCATED',
        method: 'NONE'
    };
}
```

**Procedure parameters:**

```sql
SP_CALCULATE_CHARGEBACK(
    P_START_DATE    DATE,
    P_END_DATE      DATE
)
```

**Output table: FACT_ATTRIBUTED_COST**

```sql
CREATE TABLE FACT_ATTRIBUTED_COST (
    COST_DATE               DATE NOT NULL,
    COST_TYPE               VARCHAR,  -- 'WAREHOUSE', 'QUERY', 'STORAGE', 'SERVERLESS'
    WAREHOUSE_NAME          VARCHAR,
    USER_NAME               VARCHAR,
    ROLE_NAME               VARCHAR,
    TEAM                    VARCHAR,
    DEPARTMENT              VARCHAR,
    BUSINESS_UNIT           VARCHAR,
    COST_CENTER             VARCHAR,
    PROJECT                 VARCHAR,
    ENVIRONMENT             VARCHAR,
    TOTAL_CREDITS           NUMBER(38,6),
    TOTAL_COST_USD          NUMBER(38,2),
    ATTRIBUTION_METHOD      VARCHAR,  -- 'QUERY_TAG', 'WAREHOUSE_MAPPING', 'ROLE_MAPPING', 'USER_MAPPING', 'NONE'
    CREATED_AT              TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);
```

---

#### Section 2.5: SP_REGISTER_CHARGEBACK_ENTITY — Easy Onboarding

**Visual on screen:**
- Before/after: Manual INSERT vs procedure call
- Registration form mockup
- Validation checks diagram

**The onboarding problem:**

Without a helper procedure, registering a new team requires:
1. Understanding SCD Type 2 pattern
2. Writing complex INSERT with effective dates
3. Ensuring no conflicts with existing mappings
4. Remembering all required fields

**The solution:**

```sql
CALL SP_REGISTER_CHARGEBACK_ENTITY(
    'DATA_ENGINEERING',      -- p_department
    'PLATFORM_TEAM',         -- p_team
    'WH_TRANSFORM_PROD',     -- p_warehouse_name
    'CC-12345',              -- p_cost_center
    'PROD'                   -- p_environment
);
```

**What the procedure does:**

1. **Validation checks:**
   - Warehouse exists: `SELECT COUNT(*) FROM INFORMATION_SCHEMA.WAREHOUSES WHERE NAME = :P_WAREHOUSE_NAME`
   - Department not empty
   - Team not empty
   - Cost center follows format (CC-XXXXX)

2. **Check for existing mapping:**
   - If warehouse already mapped and IS_CURRENT = TRUE, close old mapping (set EFFECTIVE_TO = CURRENT_DATE(), IS_CURRENT = FALSE)

3. **Insert new mapping:**
   ```sql
   INSERT INTO DIM_COST_CENTER_MAPPING (
       ENTITY_TYPE, ENTITY_NAME, TEAM, DEPARTMENT, COST_CENTER, ENVIRONMENT,
       EFFECTIVE_FROM, EFFECTIVE_TO, IS_CURRENT
   ) VALUES (
       'WAREHOUSE', :P_WAREHOUSE_NAME, :P_TEAM, :P_DEPARTMENT, :P_COST_CENTER, :P_ENVIRONMENT,
       CURRENT_DATE(), '9999-12-31', TRUE
   );
   ```

4. **Return confirmation:**
   ```json
   {
       "status": "SUCCESS",
       "warehouse": "WH_TRANSFORM_PROD",
       "team": "PLATFORM_TEAM",
       "department": "DATA_ENGINEERING",
       "cost_center": "CC-12345",
       "effective_from": "2024-02-08"
   }
   ```

**Common onboarding scenarios:**

1. **New team with dedicated warehouse:**
   ```sql
   CALL SP_REGISTER_CHARGEBACK_ENTITY('MARKETING', 'ANALYTICS_TEAM', 'WH_MARKETING_PROD', 'CC-99999', 'PROD');
   ```

2. **Warehouse reassignment (team reorg):**
   ```sql
   -- Same warehouse, new team (procedure handles closing old mapping)
   CALL SP_REGISTER_CHARGEBACK_ENTITY('FINANCE', 'FP&A_TEAM', 'WH_ANALYTICS_PROD', 'CC-55555', 'PROD');
   ```

3. **Bulk onboarding:**
   ```sql
   -- Loop through CSV of teams
   SELECT SP_REGISTER_CHARGEBACK_ENTITY(department, team, warehouse, cost_center, environment)
   FROM @STAGE/team_mappings.csv;
   ```

---

### 3. HANDS-ON LAB (7-8 minutes)

**Lab Objective:** Register teams, run attribution, view chargeback report

**Steps:**

1. **Create dimension tables**
   ```sql
   -- Run: module_03_chargeback_attribution/01_dimension_tables.sql
   -- Creates: DIM_COST_CENTER_MAPPING, DIM_WAREHOUSE, DIM_USER, DIM_ROLE_HIERARCHY, FACT_ATTRIBUTED_COST
   ```

2. **Create attribution procedures**
   ```sql
   -- Run: module_03_chargeback_attribution/02_sp_calculate_chargeback.sql
   -- Run: module_03_chargeback_attribution/03_sp_register_chargeback_entity.sql
   ```

3. **Register your first team**
   ```sql
   USE ROLE FINOPS_ADMIN_ROLE;
   USE WAREHOUSE FINOPS_WH_ADMIN;

   CALL FINOPS_CONTROL_DB.PROCEDURES.SP_REGISTER_CHARGEBACK_ENTITY(
       'DATA_ENGINEERING',
       'PLATFORM_TEAM',
       'COMPUTE_WH',           -- Replace with actual warehouse name from your account
       'CC-12345',
       'PROD'
   );
   ```

4. **Verify mapping**
   ```sql
   SELECT * FROM FINOPS_CONTROL_DB.CHARGEBACK.DIM_COST_CENTER_MAPPING
   WHERE IS_CURRENT = TRUE
   ORDER BY CREATED_AT DESC;
   ```

5. **Register additional teams** (optional)
   ```sql
   CALL SP_REGISTER_CHARGEBACK_ENTITY('FINANCE', 'ANALYTICS_TEAM', 'FINANCE_WH', 'CC-67890', 'PROD');
   CALL SP_REGISTER_CHARGEBACK_ENTITY('MARKETING', 'BI_TEAM', 'MARKETING_WH', 'CC-11111', 'PROD');
   ```

6. **Run chargeback attribution**
   ```sql
   CALL FINOPS_CONTROL_DB.PROCEDURES.SP_CALCULATE_CHARGEBACK(
       CURRENT_DATE() - 7,  -- Last 7 days
       CURRENT_DATE()
   );
   ```

7. **View attributed costs by team**
   ```sql
   SELECT
       COST_DATE,
       DEPARTMENT,
       TEAM,
       COST_CENTER,
       SUM(TOTAL_CREDITS) AS TOTAL_CREDITS,
       SUM(TOTAL_COST_USD) AS TOTAL_COST_USD,
       ATTRIBUTION_METHOD
   FROM FINOPS_CONTROL_DB.CHARGEBACK.FACT_ATTRIBUTED_COST
   WHERE COST_DATE >= CURRENT_DATE() - 7
   GROUP BY COST_DATE, DEPARTMENT, TEAM, COST_CENTER, ATTRIBUTION_METHOD
   ORDER BY COST_DATE DESC, TOTAL_COST_USD DESC;
   ```

8. **Check unallocated costs**
   ```sql
   SELECT
       SUM(CASE WHEN TEAM = 'UNALLOCATED' THEN TOTAL_COST_USD ELSE 0 END) AS UNALLOCATED_COST,
       SUM(TOTAL_COST_USD) AS TOTAL_COST,
       (UNALLOCATED_COST / TOTAL_COST * 100)::NUMBER(5,2) AS UNALLOCATED_PCT
   FROM FINOPS_CONTROL_DB.CHARGEBACK.FACT_ATTRIBUTED_COST
   WHERE COST_DATE >= CURRENT_DATE() - 7;
   ```

   **Goal:** Unallocated percentage <5%

9. **View attribution method breakdown**
   ```sql
   SELECT
       ATTRIBUTION_METHOD,
       COUNT(*) AS COST_RECORDS,
       SUM(TOTAL_COST_USD) AS TOTAL_COST_USD,
       (SUM(TOTAL_COST_USD) / (SELECT SUM(TOTAL_COST_USD) FROM FACT_ATTRIBUTED_COST) * 100)::NUMBER(5,2) AS PCT_OF_TOTAL
   FROM FINOPS_CONTROL_DB.CHARGEBACK.FACT_ATTRIBUTED_COST
   WHERE COST_DATE >= CURRENT_DATE() - 7
   GROUP BY ATTRIBUTION_METHOD
   ORDER BY TOTAL_COST_USD DESC;
   ```

**Expected Results:**
- Teams registered successfully with confirmation messages
- FACT_ATTRIBUTED_COST populated with 7 days of data
- Costs attributed to teams based on warehouse mappings
- Unallocated costs <5% (if you've mapped all warehouses)

**Troubleshooting:**

- **High unallocated percentage (>20%):**
  - Check which warehouses have no mapping: `SELECT DISTINCT WAREHOUSE_NAME FROM FACT_WAREHOUSE_COST_HISTORY WHERE WAREHOUSE_NAME NOT IN (SELECT ENTITY_NAME FROM DIM_COST_CENTER_MAPPING WHERE IS_CURRENT = TRUE)`
  - Register missing warehouses using SP_REGISTER_CHARGEBACK_ENTITY

- **Duplicate team registration error:**
  - Procedure automatically handles reassignment (closes old mapping, opens new)
  - Safe to re-run with same warehouse

- **Attribution method shows 'NONE' for everything:**
  - Verify mappings have IS_CURRENT = TRUE
  - Check effective date range includes cost dates

---

### 4. RECAP (45 seconds)

In this module, you built the chargeback attribution engine:

1. **Three attribution methods:** Direct (warehouse→team), proportional (shared warehouses), tag-based (QUERY_TAG)
2. **SCD Type 2 dimensions:** Handle team reorgs without losing history
3. **DIM_COST_CENTER_MAPPING:** Master table mapping warehouses/roles/users to teams/departments/cost centers
4. **SP_CALCULATE_CHARGEBACK:** Multi-dimensional attribution procedure with priority logic
5. **SP_REGISTER_CHARGEBACK_ENTITY:** One-call onboarding for new teams
6. **FACT_ATTRIBUTED_COST:** Complete chargeback data with attribution method audit trail

Goal achieved: Every dollar attributed to a team, department, project, and cost center.

Next up: **Module 04 — Budget Controls & Alerts**. We'll add budget definitions, 3-tier alerts, anomaly detection, and month-end forecasting.

---

## Production Notes

- **B-roll suggestions:**
  - SCD Type 2 timeline animation
  - Attribution method decision tree
  - Chargeback report with drill-down
  - Team registration workflow

- **Screen recordings needed:**
  - Calling SP_REGISTER_CHARGEBACK_ENTITY
  - Viewing attributed costs by team
  - Showing before/after reorg with SCD Type 2
  - Unallocated cost percentage calculation

- **Pause points:**
  - After SCD Type 2 explanation (complex concept)
  - After attribution priority logic (decision tree)

- **Emphasis words:**
  - "SCD Type 2" (history tracking)
  - "Multi-dimensional" (not just one dimension)
  - "Unallocated <5%" (goal metric)
  - "Priority order" (attribution logic)
  - "Audit trail" (attribution method tracking)
