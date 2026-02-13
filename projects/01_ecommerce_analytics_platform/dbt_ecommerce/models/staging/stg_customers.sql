-- ============================================================
-- SNOWBRIX E-COMMERCE PLATFORM
-- Staging Model: stg_customers
-- ============================================================
-- Source: ECOMMERCE_RAW.POSTGRES.RAW_CUSTOMERS
-- Grain: One row per unique customer (deduplicated by email)
-- Materialization: View (configured in dbt_project.yml)
--
-- Transformations applied:
--   1. Deduplicate by email (keep the most recently updated row)
--   2. Normalize state abbreviations ("California" -> "CA")
--   3. Handle NULL phone numbers (30% of records)
--   4. Lowercase and trim email addresses
--   5. Build full_name from first_name + last_name
--   6. Default country to 'US' when NULL
--
-- WHY DEDUPLICATION IS NEEDED:
-- The incremental extractor may load the same customer twice
-- if they were updated between extraction runs. The raw table
-- does not have a unique constraint (it's append-only on the
-- Snowflake side). We deduplicate here so downstream models
-- can rely on one row per customer.
-- ============================================================

with

source as (

    select * from {{ source('postgres', 'raw_customers') }}

),

-- Deduplicate by email. If the same customer appears multiple times
-- (from overlapping incremental loads), keep only the most recently
-- updated record. ROW_NUMBER partitioned by email, ordered by
-- updated_at DESC ensures the freshest data wins.
deduplicated as (

    select
        *,
        row_number() over (
            partition by lower(trim(email))
            order by updated_at desc
        ) as row_num

    from source

),

-- Keep only the first (most recent) row per email
unique_customers as (

    select * from deduplicated where row_num = 1

),

-- Normalize state names to two-letter abbreviations.
-- The source data has a mix of full names ("California") and
-- abbreviations ("CA"). We map common full names to abbreviations.
-- This is a simplified mapping for the most common US states.
renamed as (

    select
        -- Primary key
        cast(customer_id as integer)                    as customer_id,

        -- Contact information
        lower(trim(email))                              as email,
        trim(first_name)                                as first_name,
        trim(last_name)                                 as last_name,

        -- Build full name, handling NULLs gracefully
        case
            when first_name is not null and last_name is not null
                then trim(first_name) || ' ' || trim(last_name)
            when first_name is not null
                then trim(first_name)
            when last_name is not null
                then trim(last_name)
            else 'Unknown'
        end                                             as full_name,

        -- Phone is NULL for ~30% of customers. We preserve the NULL
        -- rather than defaulting, because "no phone on file" is
        -- meaningful information for customer outreach analytics.
        trim(phone)                                     as phone,

        -- Address fields
        trim(address)                                   as address,
        trim(city)                                      as city,

        -- Normalize state to 2-letter abbreviation
        case upper(trim(state))
            when 'ALABAMA'        then 'AL'
            when 'ALASKA'         then 'AK'
            when 'ARIZONA'        then 'AZ'
            when 'ARKANSAS'       then 'AR'
            when 'CALIFORNIA'     then 'CA'
            when 'COLORADO'       then 'CO'
            when 'CONNECTICUT'    then 'CT'
            when 'DELAWARE'       then 'DE'
            when 'FLORIDA'        then 'FL'
            when 'GEORGIA'        then 'GA'
            when 'HAWAII'         then 'HI'
            when 'IDAHO'          then 'ID'
            when 'ILLINOIS'       then 'IL'
            when 'INDIANA'        then 'IN'
            when 'IOWA'           then 'IA'
            when 'KANSAS'         then 'KS'
            when 'KENTUCKY'       then 'KY'
            when 'LOUISIANA'      then 'LA'
            when 'MAINE'          then 'ME'
            when 'MARYLAND'       then 'MD'
            when 'MASSACHUSETTS'  then 'MA'
            when 'MICHIGAN'       then 'MI'
            when 'MINNESOTA'      then 'MN'
            when 'MISSISSIPPI'    then 'MS'
            when 'MISSOURI'       then 'MO'
            when 'MONTANA'        then 'MT'
            when 'NEBRASKA'       then 'NE'
            when 'NEVADA'         then 'NV'
            when 'NEW HAMPSHIRE'  then 'NH'
            when 'NEW JERSEY'     then 'NJ'
            when 'NEW MEXICO'     then 'NM'
            when 'NEW YORK'       then 'NY'
            when 'NORTH CAROLINA' then 'NC'
            when 'NORTH DAKOTA'   then 'ND'
            when 'OHIO'           then 'OH'
            when 'OKLAHOMA'       then 'OK'
            when 'OREGON'         then 'OR'
            when 'PENNSYLVANIA'   then 'PA'
            when 'RHODE ISLAND'   then 'RI'
            when 'SOUTH CAROLINA' then 'SC'
            when 'SOUTH DAKOTA'   then 'SD'
            when 'TENNESSEE'      then 'TN'
            when 'TEXAS'          then 'TX'
            when 'UTAH'           then 'UT'
            when 'VERMONT'        then 'VT'
            when 'VIRGINIA'       then 'VA'
            when 'WASHINGTON'     then 'WA'
            when 'WEST VIRGINIA'  then 'WV'
            when 'WISCONSIN'      then 'WI'
            when 'WYOMING'        then 'WY'
            -- If it's already a 2-letter code, keep it as-is
            else upper(trim(state))
        end                                             as state,

        -- Default country to 'US' when NULL
        coalesce(trim(country), 'US')                   as country,

        trim(zip_code)                                  as zip_code,

        -- Audit timestamps
        cast(created_at as timestamp_ntz)               as created_at,
        cast(updated_at as timestamp_ntz)               as updated_at

    from unique_customers

)

select * from renamed
