/*
=============================================================================
  MODULE 03 : CHARGEBACK ATTRIBUTION
  SCRIPT 03 : Helper Procedures for Easy Onboarding
=============================================================================
  SNOWBRIX ACADEMY — Enterprise FinOps Dashboard for Snowflake

  LEARNING OBJECTIVES:
    1. Create helper procedures for entity and mapping management
    2. Simplify onboarding of new teams, departments, and projects
    3. Implement SCD Type 2 updates for organizational changes
    4. Provide admin-friendly interfaces for common operations

  HELPER PROCEDURES:
  ┌──────────────────────────────────────────────────────────────┐
  │  1. SP_REGISTER_CHARGEBACK_ENTITY                            │
  │     → Easy entity creation with parent lookup                │
  │                                                               │
  │  2. SP_MAP_USER_TO_ENTITY                                    │
  │     → Map user to team/dept with allocation support          │
  │                                                               │
  │  3. SP_MAP_WAREHOUSE_TO_ENTITY                               │
  │     → Map warehouse to team/dept with proportional allocation│
  │                                                               │
  │  4. SP_UPDATE_ENTITY_MAPPING                                 │
  │     → SCD Type 2 update when org changes                     │
  │                                                               │
  │  5. SP_GET_ENTITY_HIERARCHY                                  │
  │     → Retrieve full entity tree                              │
  └──────────────────────────────────────────────────────────────┘

  PREREQUISITES:
    - Module 03, Script 01 and 02 completed

  ESTIMATED TIME: 15 minutes

=============================================================================
*/

USE ROLE FINOPS_ADMIN_ROLE;
USE DATABASE FINOPS_CONTROL_DB;
USE SCHEMA PROCEDURES;
USE WAREHOUSE FINOPS_WH_ADMIN;

-- =========================================================================
-- PROCEDURE: SP_REGISTER_CHARGEBACK_ENTITY
-- Registers a new chargeback entity (team, department, project, etc.)
-- =========================================================================
CREATE OR REPLACE PROCEDURE SP_REGISTER_CHARGEBACK_ENTITY(
    P_ENTITY_TYPE       VARCHAR,
    P_ENTITY_NAME       VARCHAR,
    P_ENTITY_CODE       VARCHAR,
    P_PARENT_NAME       VARCHAR DEFAULT NULL,
    P_COST_CENTER_CODE  VARCHAR DEFAULT NULL,
    P_MANAGER_NAME      VARCHAR DEFAULT NULL,
    P_MANAGER_EMAIL     VARCHAR DEFAULT NULL
)
RETURNS VARIANT
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER
AS
$$
    var result = {
        procedure: 'SP_REGISTER_CHARGEBACK_ENTITY',
        status: 'INITIALIZING',
        entity_name: P_ENTITY_NAME
    };

    try {
        // Validate entity type
        var validTypes = ['TEAM', 'DEPARTMENT', 'PROJECT', 'BUSINESS_UNIT', 'COST_CENTER'];
        if (!validTypes.includes(P_ENTITY_TYPE)) {
            throw new Error('Invalid ENTITY_TYPE. Must be one of: ' + validTypes.join(', '));
        }

        // Check if entity already exists
        var checkExisting = snowflake.createStatement({
            sqlText: `SELECT ENTITY_ID FROM FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY
                      WHERE ENTITY_NAME = ? AND IS_CURRENT = TRUE`,
            binds: [P_ENTITY_NAME]
        });
        var existingRs = checkExisting.execute();

        if (existingRs.next()) {
            result.status = 'ALREADY_EXISTS';
            result.entity_id = existingRs.getColumnValue('ENTITY_ID');
            result.message = 'Entity already exists with ID: ' + result.entity_id;
            return result;
        }

        // Get parent entity ID if parent name provided
        var parentEntityId = null;
        if (P_PARENT_NAME) {
            var getParent = snowflake.createStatement({
                sqlText: `SELECT ENTITY_ID FROM FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY
                          WHERE ENTITY_NAME = ? AND IS_CURRENT = TRUE`,
                binds: [P_PARENT_NAME]
            });
            var parentRs = getParent.execute();

            if (parentRs.next()) {
                parentEntityId = parentRs.getColumnValue('ENTITY_ID');
            } else {
                throw new Error('Parent entity not found: ' + P_PARENT_NAME);
            }
        }

        // Insert new entity
        var insertSql = `
            INSERT INTO FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY (
                ENTITY_TYPE, ENTITY_NAME, ENTITY_CODE,
                PARENT_ENTITY_ID, COST_CENTER_CODE,
                MANAGER_NAME, MANAGER_EMAIL
            )
            VALUES (?, ?, ?, ?, ?, ?, ?)
        `;

        var insertStmt = snowflake.createStatement({
            sqlText: insertSql,
            binds: [P_ENTITY_TYPE, P_ENTITY_NAME, P_ENTITY_CODE,
                    parentEntityId, P_COST_CENTER_CODE,
                    P_MANAGER_NAME, P_MANAGER_EMAIL]
        });
        insertStmt.execute();

        // Get the new entity ID
        var getNewId = snowflake.createStatement({
            sqlText: `SELECT ENTITY_ID FROM FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY
                      WHERE ENTITY_NAME = ? AND IS_CURRENT = TRUE`,
            binds: [P_ENTITY_NAME]
        });
        var newIdRs = getNewId.execute();
        newIdRs.next();

        result.status = 'SUCCESS';
        result.entity_id = newIdRs.getColumnValue('ENTITY_ID');
        result.entity_type = P_ENTITY_TYPE;
        result.parent_entity_id = parentEntityId;
        result.message = 'Entity registered successfully';

        return result;

    } catch (err) {
        result.status = 'ERROR';
        result.error_message = err.message;
        return result;
    }
$$;


-- =========================================================================
-- PROCEDURE: SP_MAP_USER_TO_ENTITY
-- Maps a user to a chargeback entity with optional allocation percentage
-- =========================================================================
CREATE OR REPLACE PROCEDURE SP_MAP_USER_TO_ENTITY(
    P_USER_NAME         VARCHAR,
    P_ENTITY_NAME       VARCHAR,
    P_ALLOCATION_PCT    NUMBER DEFAULT 100.00,
    P_ENVIRONMENT       VARCHAR DEFAULT NULL,
    P_EFFECTIVE_DATE    DATE DEFAULT CURRENT_DATE()
)
RETURNS VARIANT
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER
AS
$$
    var result = {
        procedure: 'SP_MAP_USER_TO_ENTITY',
        status: 'INITIALIZING',
        user_name: P_USER_NAME,
        entity_name: P_ENTITY_NAME
    };

    try {
        // Validate allocation percentage
        if (P_ALLOCATION_PCT <= 0 || P_ALLOCATION_PCT > 100) {
            throw new Error('ALLOCATION_PCT must be between 0 and 100');
        }

        // Get entity ID
        var getEntity = snowflake.createStatement({
            sqlText: `SELECT ENTITY_ID FROM FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY
                      WHERE ENTITY_NAME = ? AND IS_CURRENT = TRUE`,
            binds: [P_ENTITY_NAME]
        });
        var entityRs = getEntity.execute();

        if (!entityRs.next()) {
            throw new Error('Entity not found: ' + P_ENTITY_NAME + '. Register entity first.');
        }

        var entityId = entityRs.getColumnValue('ENTITY_ID');

        // Check if mapping already exists
        var checkExisting = snowflake.createStatement({
            sqlText: `SELECT MAPPING_ID FROM FINOPS_CONTROL_DB.CHARGEBACK.DIM_COST_CENTER_MAPPING
                      WHERE SOURCE_TYPE = 'USER'
                        AND SOURCE_VALUE = ?
                        AND ENTITY_ID = ?
                        AND IS_CURRENT = TRUE`,
            binds: [P_USER_NAME, entityId]
        });
        var existingRs = checkExisting.execute();

        if (existingRs.next()) {
            result.status = 'ALREADY_MAPPED';
            result.mapping_id = existingRs.getColumnValue('MAPPING_ID');
            result.message = 'User already mapped to this entity. Use SP_UPDATE_ENTITY_MAPPING to change.';
            return result;
        }

        // Insert new mapping
        var insertSql = `
            INSERT INTO FINOPS_CONTROL_DB.CHARGEBACK.DIM_COST_CENTER_MAPPING (
                SOURCE_TYPE, SOURCE_VALUE, ENTITY_ID,
                ALLOCATION_PERCENTAGE, ENVIRONMENT,
                VALID_FROM, ALLOCATION_RULE
            )
            VALUES ('USER', ?, ?, ?, ?, ?, ?)
        `;

        var allocationRule = P_ALLOCATION_PCT < 100
            ? P_USER_NAME + ' allocated ' + P_ALLOCATION_PCT + '% to ' + P_ENTITY_NAME
            : P_USER_NAME + ' 100% dedicated to ' + P_ENTITY_NAME;

        var insertStmt = snowflake.createStatement({
            sqlText: insertSql,
            binds: [P_USER_NAME, entityId, P_ALLOCATION_PCT, P_ENVIRONMENT,
                    P_EFFECTIVE_DATE, allocationRule]
        });
        insertStmt.execute();

        // Get new mapping ID
        var getMappingId = snowflake.createStatement({
            sqlText: `SELECT MAPPING_ID FROM FINOPS_CONTROL_DB.CHARGEBACK.DIM_COST_CENTER_MAPPING
                      WHERE SOURCE_TYPE = 'USER'
                        AND SOURCE_VALUE = ?
                        AND ENTITY_ID = ?
                        AND IS_CURRENT = TRUE`,
            binds: [P_USER_NAME, entityId]
        });
        var mappingRs = getMappingId.execute();
        mappingRs.next();

        result.status = 'SUCCESS';
        result.mapping_id = mappingRs.getColumnValue('MAPPING_ID');
        result.entity_id = entityId;
        result.allocation_pct = P_ALLOCATION_PCT;
        result.message = 'User mapped successfully';

        return result;

    } catch (err) {
        result.status = 'ERROR';
        result.error_message = err.message;
        return result;
    }
$$;


-- =========================================================================
-- PROCEDURE: SP_MAP_WAREHOUSE_TO_ENTITY
-- Maps a warehouse to a chargeback entity with proportional allocation
-- =========================================================================
CREATE OR REPLACE PROCEDURE SP_MAP_WAREHOUSE_TO_ENTITY(
    P_WAREHOUSE_NAME    VARCHAR,
    P_ENTITY_NAME       VARCHAR,
    P_ALLOCATION_PCT    NUMBER DEFAULT 100.00,
    P_ENVIRONMENT       VARCHAR DEFAULT 'PROD',
    P_EFFECTIVE_DATE    DATE DEFAULT CURRENT_DATE()
)
RETURNS VARIANT
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER
AS
$$
    var result = {
        procedure: 'SP_MAP_WAREHOUSE_TO_ENTITY',
        status: 'INITIALIZING',
        warehouse_name: P_WAREHOUSE_NAME,
        entity_name: P_ENTITY_NAME
    };

    try {
        // Validate allocation percentage
        if (P_ALLOCATION_PCT <= 0 || P_ALLOCATION_PCT > 100) {
            throw new Error('ALLOCATION_PCT must be between 0 and 100');
        }

        // Get entity ID
        var getEntity = snowflake.createStatement({
            sqlText: `SELECT ENTITY_ID FROM FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY
                      WHERE ENTITY_NAME = ? AND IS_CURRENT = TRUE`,
            binds: [P_ENTITY_NAME]
        });
        var entityRs = getEntity.execute();

        if (!entityRs.next()) {
            throw new Error('Entity not found: ' + P_ENTITY_NAME);
        }

        var entityId = entityRs.getColumnValue('ENTITY_ID');

        // Check total allocation for this warehouse
        var checkTotal = snowflake.createStatement({
            sqlText: `SELECT COALESCE(SUM(ALLOCATION_PERCENTAGE), 0) AS TOTAL_ALLOCATED
                      FROM FINOPS_CONTROL_DB.CHARGEBACK.DIM_COST_CENTER_MAPPING
                      WHERE SOURCE_TYPE = 'WAREHOUSE'
                        AND SOURCE_VALUE = ?
                        AND IS_CURRENT = TRUE`,
            binds: [P_WAREHOUSE_NAME]
        });
        var totalRs = checkTotal.execute();
        totalRs.next();
        var totalAllocated = totalRs.getColumnValue('TOTAL_ALLOCATED');

        if (totalAllocated + P_ALLOCATION_PCT > 100) {
            throw new Error('Total allocation would exceed 100%. Current: ' + totalAllocated + '%, Attempting to add: ' + P_ALLOCATION_PCT + '%');
        }

        // Insert new mapping
        var insertSql = `
            INSERT INTO FINOPS_CONTROL_DB.CHARGEBACK.DIM_COST_CENTER_MAPPING (
                SOURCE_TYPE, SOURCE_VALUE, ENTITY_ID,
                ALLOCATION_PERCENTAGE, ENVIRONMENT,
                VALID_FROM, ALLOCATION_RULE
            )
            VALUES ('WAREHOUSE', ?, ?, ?, ?, ?, ?)
        `;

        var allocationRule = P_ALLOCATION_PCT < 100
            ? P_WAREHOUSE_NAME + ' shared: ' + P_ALLOCATION_PCT + '% to ' + P_ENTITY_NAME
            : P_WAREHOUSE_NAME + ' dedicated 100% to ' + P_ENTITY_NAME;

        var insertStmt = snowflake.createStatement({
            sqlText: insertSql,
            binds: [P_WAREHOUSE_NAME, entityId, P_ALLOCATION_PCT, P_ENVIRONMENT,
                    P_EFFECTIVE_DATE, allocationRule]
        });
        insertStmt.execute();

        // Get new mapping ID
        var getMappingId = snowflake.createStatement({
            sqlText: `SELECT MAPPING_ID FROM FINOPS_CONTROL_DB.CHARGEBACK.DIM_COST_CENTER_MAPPING
                      WHERE SOURCE_TYPE = 'WAREHOUSE'
                        AND SOURCE_VALUE = ?
                        AND ENTITY_ID = ?
                        AND IS_CURRENT = TRUE
                      ORDER BY CREATED_AT DESC
                      LIMIT 1`,
            binds: [P_WAREHOUSE_NAME, entityId]
        });
        var mappingRs = getMappingId.execute();
        mappingRs.next();

        result.status = 'SUCCESS';
        result.mapping_id = mappingRs.getColumnValue('MAPPING_ID');
        result.entity_id = entityId;
        result.allocation_pct = P_ALLOCATION_PCT;
        result.total_allocated_pct = totalAllocated + P_ALLOCATION_PCT;
        result.message = 'Warehouse mapped successfully';

        return result;

    } catch (err) {
        result.status = 'ERROR';
        result.error_message = err.message;
        return result;
    }
$$;


-- =========================================================================
-- PROCEDURE: SP_UPDATE_ENTITY_MAPPING
-- Updates an entity mapping using SCD Type 2 (closes old, opens new)
-- =========================================================================
CREATE OR REPLACE PROCEDURE SP_UPDATE_ENTITY_MAPPING(
    P_MAPPING_ID        NUMBER,
    P_NEW_ENTITY_NAME   VARCHAR,
    P_EFFECTIVE_DATE    DATE DEFAULT CURRENT_DATE()
)
RETURNS VARIANT
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER
AS
$$
    var result = {
        procedure: 'SP_UPDATE_ENTITY_MAPPING',
        status: 'INITIALIZING',
        mapping_id: P_MAPPING_ID
    };

    try {
        // Get current mapping details
        var getMapping = snowflake.createStatement({
            sqlText: `SELECT
                        SOURCE_TYPE, SOURCE_VALUE, ENTITY_ID,
                        ALLOCATION_PERCENTAGE, ENVIRONMENT
                      FROM FINOPS_CONTROL_DB.CHARGEBACK.DIM_COST_CENTER_MAPPING
                      WHERE MAPPING_ID = ? AND IS_CURRENT = TRUE`,
            binds: [P_MAPPING_ID]
        });
        var mappingRs = getMapping.execute();

        if (!mappingRs.next()) {
            throw new Error('Mapping ID not found or already closed: ' + P_MAPPING_ID);
        }

        var sourceType = mappingRs.getColumnValue('SOURCE_TYPE');
        var sourceValue = mappingRs.getColumnValue('SOURCE_VALUE');
        var oldEntityId = mappingRs.getColumnValue('ENTITY_ID');
        var allocationPct = mappingRs.getColumnValue('ALLOCATION_PERCENTAGE');
        var environment = mappingRs.getColumnValue('ENVIRONMENT');

        // Get new entity ID
        var getNewEntity = snowflake.createStatement({
            sqlText: `SELECT ENTITY_ID FROM FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY
                      WHERE ENTITY_NAME = ? AND IS_CURRENT = TRUE`,
            binds: [P_NEW_ENTITY_NAME]
        });
        var newEntityRs = getNewEntity.execute();

        if (!newEntityRs.next()) {
            throw new Error('New entity not found: ' + P_NEW_ENTITY_NAME);
        }

        var newEntityId = newEntityRs.getColumnValue('ENTITY_ID');

        if (oldEntityId === newEntityId) {
            result.status = 'NO_CHANGE';
            result.message = 'Mapping already points to this entity';
            return result;
        }

        // Close old mapping (SCD Type 2)
        var closeSql = `
            UPDATE FINOPS_CONTROL_DB.CHARGEBACK.DIM_COST_CENTER_MAPPING
            SET
                VALID_TO = ?,
                IS_CURRENT = FALSE,
                UPDATED_AT = CURRENT_TIMESTAMP(),
                UPDATED_BY = CURRENT_USER()
            WHERE MAPPING_ID = ?
        `;

        var closeStmt = snowflake.createStatement({
            sqlText: closeSql,
            binds: [P_EFFECTIVE_DATE, P_MAPPING_ID]
        });
        closeStmt.execute();

        // Open new mapping (SCD Type 2)
        var openSql = `
            INSERT INTO FINOPS_CONTROL_DB.CHARGEBACK.DIM_COST_CENTER_MAPPING (
                SOURCE_TYPE, SOURCE_VALUE, ENTITY_ID,
                ALLOCATION_PERCENTAGE, ENVIRONMENT,
                VALID_FROM, IS_CURRENT, ALLOCATION_RULE
            )
            VALUES (?, ?, ?, ?, ?, ?, TRUE, ?)
        `;

        var allocationRule = sourceValue + ' remapped to ' + P_NEW_ENTITY_NAME + ' effective ' + P_EFFECTIVE_DATE;

        var openStmt = snowflake.createStatement({
            sqlText: openSql,
            binds: [sourceType, sourceValue, newEntityId, allocationPct, environment,
                    P_EFFECTIVE_DATE, allocationRule]
        });
        openStmt.execute();

        // Get new mapping ID
        var getNewMapping = snowflake.createStatement({
            sqlText: `SELECT MAPPING_ID FROM FINOPS_CONTROL_DB.CHARGEBACK.DIM_COST_CENTER_MAPPING
                      WHERE SOURCE_TYPE = ?
                        AND SOURCE_VALUE = ?
                        AND ENTITY_ID = ?
                        AND IS_CURRENT = TRUE`,
            binds: [sourceType, sourceValue, newEntityId]
        });
        var newMappingRs = getNewMapping.execute();
        newMappingRs.next();

        result.status = 'SUCCESS';
        result.old_mapping_id = P_MAPPING_ID;
        result.new_mapping_id = newMappingRs.getColumnValue('MAPPING_ID');
        result.old_entity_id = oldEntityId;
        result.new_entity_id = newEntityId;
        result.effective_date = P_EFFECTIVE_DATE;
        result.message = 'Mapping updated successfully (SCD Type 2)';

        return result;

    } catch (err) {
        result.status = 'ERROR';
        result.error_message = err.message;
        return result;
    }
$$;


-- =========================================================================
-- PROCEDURE: SP_GET_ENTITY_HIERARCHY
-- Retrieves the full entity hierarchy tree
-- =========================================================================
CREATE OR REPLACE PROCEDURE SP_GET_ENTITY_HIERARCHY()
RETURNS TABLE (
    LEVEL NUMBER,
    ENTITY_ID NUMBER,
    ENTITY_TYPE VARCHAR,
    ENTITY_NAME VARCHAR,
    PARENT_NAME VARCHAR,
    FULL_PATH VARCHAR
)
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
    WITH RECURSIVE entity_tree AS (
        -- Root entities (no parent)
        SELECT
            1 AS LEVEL,
            ENTITY_ID,
            ENTITY_TYPE,
            ENTITY_NAME,
            NULL AS PARENT_NAME,
            ENTITY_NAME AS FULL_PATH
        FROM FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY
        WHERE PARENT_ENTITY_ID IS NULL
          AND IS_CURRENT = TRUE

        UNION ALL

        -- Child entities
        SELECT
            t.LEVEL + 1,
            e.ENTITY_ID,
            e.ENTITY_TYPE,
            e.ENTITY_NAME,
            t.ENTITY_NAME AS PARENT_NAME,
            t.FULL_PATH || ' > ' || e.ENTITY_NAME AS FULL_PATH
        FROM FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY e
        JOIN entity_tree t ON e.PARENT_ENTITY_ID = t.ENTITY_ID
        WHERE e.IS_CURRENT = TRUE
    )
    SELECT
        LEVEL,
        ENTITY_ID,
        ENTITY_TYPE,
        ENTITY_NAME,
        PARENT_NAME,
        FULL_PATH
    FROM entity_tree
    ORDER BY FULL_PATH;
$$;


-- =========================================================================
-- GRANT PERMISSIONS
-- =========================================================================
GRANT USAGE ON PROCEDURE SP_REGISTER_CHARGEBACK_ENTITY(VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR)
    TO ROLE FINOPS_ADMIN_ROLE;

GRANT USAGE ON PROCEDURE SP_MAP_USER_TO_ENTITY(VARCHAR, VARCHAR, NUMBER, VARCHAR, DATE)
    TO ROLE FINOPS_ADMIN_ROLE;

GRANT USAGE ON PROCEDURE SP_MAP_WAREHOUSE_TO_ENTITY(VARCHAR, VARCHAR, NUMBER, VARCHAR, DATE)
    TO ROLE FINOPS_ADMIN_ROLE;

GRANT USAGE ON PROCEDURE SP_UPDATE_ENTITY_MAPPING(NUMBER, VARCHAR, DATE)
    TO ROLE FINOPS_ADMIN_ROLE;

GRANT USAGE ON PROCEDURE SP_GET_ENTITY_HIERARCHY()
    TO ROLE FINOPS_ANALYST_ROLE;


-- =========================================================================
-- VERIFICATION QUERIES & EXAMPLES
-- =========================================================================

/*
-- Example 1: Register a new team
CALL SP_REGISTER_CHARGEBACK_ENTITY(
    'TEAM',                         -- Entity type
    'Data Science Team',            -- Entity name
    'DATA_SCI',                     -- Entity code
    'ML Engineering',               -- Parent department name
    'CC-1320',                      -- Cost center code
    'Lisa Anderson',                -- Manager name
    'lisa.anderson@company.com'     -- Manager email
);


-- Example 2: Map a user to a team (100% allocation)
CALL SP_MAP_USER_TO_ENTITY(
    'LISA.ANDERSON@COMPANY.COM',    -- User name
    'Data Science Team',             -- Entity name
    100.00,                          -- 100% allocation
    'PROD',                          -- Environment
    CURRENT_DATE()                   -- Effective date
);


-- Example 3: Map a warehouse to a team (dedicated)
CALL SP_MAP_WAREHOUSE_TO_ENTITY(
    'WH_DATASCI_PROD',              -- Warehouse name
    'Data Science Team',             -- Entity name
    100.00,                          -- 100% dedicated
    'PROD',                          -- Environment
    CURRENT_DATE()
);


-- Example 4: Map a shared warehouse to multiple teams
CALL SP_MAP_WAREHOUSE_TO_ENTITY('WH_SHARED_DEV', 'ETL Pipeline Team', 60.00, 'DEV', CURRENT_DATE());
CALL SP_MAP_WAREHOUSE_TO_ENTITY('WH_SHARED_DEV', 'Data Lake Team', 40.00, 'DEV', CURRENT_DATE());


-- Example 5: Update a user's team mapping (reorg scenario)
-- First, get the current mapping ID
SELECT
    MAPPING_ID,
    SOURCE_VALUE AS USER_NAME,
    e.ENTITY_NAME AS CURRENT_TEAM
FROM FINOPS_CONTROL_DB.CHARGEBACK.DIM_COST_CENTER_MAPPING m
JOIN FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY e ON m.ENTITY_ID = e.ENTITY_ID
WHERE m.SOURCE_TYPE = 'USER'
  AND m.SOURCE_VALUE = 'FRANK.ZHANG@COMPANY.COM'
  AND m.IS_CURRENT = TRUE;

-- Then update the mapping
CALL SP_UPDATE_ENTITY_MAPPING(
    12,                             -- Mapping ID from above query
    'Data Science Team',            -- New team name
    '2025-03-01'                    -- Effective date of reorg
);


-- Example 6: View full entity hierarchy
CALL SP_GET_ENTITY_HIERARCHY();


-- Verify: All user mappings
SELECT
    m.SOURCE_VALUE AS USER_NAME,
    e.ENTITY_NAME AS TEAM,
    p.ENTITY_NAME AS DEPARTMENT,
    m.ALLOCATION_PERCENTAGE,
    m.ENVIRONMENT,
    m.VALID_FROM,
    m.VALID_TO,
    m.IS_CURRENT
FROM FINOPS_CONTROL_DB.CHARGEBACK.DIM_COST_CENTER_MAPPING m
JOIN FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY e ON m.ENTITY_ID = e.ENTITY_ID
LEFT JOIN FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY p ON e.PARENT_ENTITY_ID = p.ENTITY_ID
WHERE m.SOURCE_TYPE = 'USER'
ORDER BY m.IS_CURRENT DESC, USER_NAME;


-- Verify: Warehouse allocation summary
SELECT
    m.SOURCE_VALUE AS WAREHOUSE_NAME,
    m.ENVIRONMENT,
    SUM(m.ALLOCATION_PERCENTAGE) AS TOTAL_ALLOCATED_PCT,
    COUNT(*) AS ENTITY_COUNT,
    LISTAGG(e.ENTITY_NAME || ' (' || m.ALLOCATION_PERCENTAGE || '%)', ', ') AS ALLOCATION_DETAILS
FROM FINOPS_CONTROL_DB.CHARGEBACK.DIM_COST_CENTER_MAPPING m
JOIN FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY e ON m.ENTITY_ID = e.ENTITY_ID
WHERE m.SOURCE_TYPE = 'WAREHOUSE'
  AND m.IS_CURRENT = TRUE
GROUP BY m.SOURCE_VALUE, m.ENVIRONMENT
ORDER BY WAREHOUSE_NAME;


-- Verify: SCD Type 2 history for a specific mapping
SELECT
    m.MAPPING_ID,
    m.SOURCE_VALUE,
    e.ENTITY_NAME,
    m.VALID_FROM,
    m.VALID_TO,
    m.IS_CURRENT,
    m.ALLOCATION_RULE
FROM FINOPS_CONTROL_DB.CHARGEBACK.DIM_COST_CENTER_MAPPING m
JOIN FINOPS_CONTROL_DB.CHARGEBACK.DIM_CHARGEBACK_ENTITY e ON m.ENTITY_ID = e.ENTITY_ID
WHERE m.SOURCE_VALUE = 'FRANK.ZHANG@COMPANY.COM'
ORDER BY m.VALID_FROM DESC;
*/


/*
=============================================================================
  BEST PRACTICES:

  1. ENTITY REGISTRATION:
     - Always register parent entities before children
     - Use consistent naming conventions (title case, no abbreviations)
     - Assign manager email for automated budget alerts

  2. USER MAPPING:
     - Map all human users to teams for accurate attribution
     - Map service accounts to owning team
     - Use proportional allocation for users working across multiple projects

  3. WAREHOUSE MAPPING:
     - Prefer dedicated warehouses (100% allocation) for clear accountability
     - Use shared warehouses only when necessary
     - Ensure total allocation = 100% for shared warehouses

  4. SCD TYPE 2 UPDATES:
     - Always use SP_UPDATE_ENTITY_MAPPING, never UPDATE directly
     - Set EFFECTIVE_DATE to start of new fiscal period when possible
     - Document reason for change in ALLOCATION_RULE column

  5. PERIODIC REVIEWS:
     - Review unallocated costs weekly
     - Review entity hierarchy quarterly
     - Review user mappings after each reorg

  OBJECTS CREATED:
    - FINOPS_CONTROL_DB.PROCEDURES.SP_REGISTER_CHARGEBACK_ENTITY
    - FINOPS_CONTROL_DB.PROCEDURES.SP_MAP_USER_TO_ENTITY
    - FINOPS_CONTROL_DB.PROCEDURES.SP_MAP_WAREHOUSE_TO_ENTITY
    - FINOPS_CONTROL_DB.PROCEDURES.SP_UPDATE_ENTITY_MAPPING
    - FINOPS_CONTROL_DB.PROCEDURES.SP_GET_ENTITY_HIERARCHY

  NEXT STEPS:
    → Module 04: Budget controls (define budgets, check thresholds, alerts)
    → Test end-to-end: Cost collection → Attribution → Chargeback report
=============================================================================
*/
