-- ============================================================
-- SNOWBRIX E-COMMERCE PLATFORM
-- Mart Model: dim_dates
-- ============================================================
-- Grain: One row per calendar day
-- Materialization: Table (configured in dbt_project.yml)
--
-- Generated date dimension using dbt_utils.date_spine.
-- No source dependency — this is a purely generated table.
--
-- Spans from the project start_date variable (default: 2024-01-01)
-- through 2 years into the future to accommodate forecasting
-- and pre-populated date keys.
--
-- Includes:
--   - Standard calendar fields (day, week, month, quarter, year)
--   - Fiscal calendar (fiscal year starts February 1)
--   - ISO week numbering
--   - Weekend flags
--   - US federal holiday flags
--
-- FISCAL CALENDAR:
-- The fiscal year starts on February 1. This means:
--   FY2024 = Feb 1, 2024 through Jan 31, 2025
--   FQ1 = Feb, Mar, Apr
--   FQ2 = May, Jun, Jul
--   FQ3 = Aug, Sep, Oct
--   FQ4 = Nov, Dec, Jan
-- ============================================================

with

-- Generate a row for every day in the date range.
-- dbt_utils.date_spine creates a single column 'date_day'.
date_spine as (

    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="cast('" ~ var('start_date', '2024-01-01') ~ "' as date)",
        end_date="dateadd(year, 2, current_date())"
    ) }}

),

-- Extract standard calendar fields from each date.
calendar_fields as (

    select
        -- The date itself
        cast(date_day as date)                          as date_day,

        -- Integer key in YYYYMMDD format for efficient joins
        -- e.g., 2024-01-15 -> 20240115
        cast(to_char(date_day, 'YYYYMMDD') as integer)  as date_key,

        -- Day-level fields
        dayofweekiso(date_day)                          as day_of_week,
        dayname(date_day)                               as day_of_week_short,
        case dayofweekiso(date_day)
            when 1 then 'Monday'
            when 2 then 'Tuesday'
            when 3 then 'Wednesday'
            when 4 then 'Thursday'
            when 5 then 'Friday'
            when 6 then 'Saturday'
            when 7 then 'Sunday'
        end                                             as day_of_week_name,
        dayofmonth(date_day)                            as day_of_month,
        dayofyear(date_day)                             as day_of_year,

        -- Week-level fields
        weekiso(date_day)                               as week_of_year,

        -- Month-level fields
        month(date_day)                                 as month_number,
        monthname(date_day)                             as month_name_short,
        case month(date_day)
            when 1  then 'January'
            when 2  then 'February'
            when 3  then 'March'
            when 4  then 'April'
            when 5  then 'May'
            when 6  then 'June'
            when 7  then 'July'
            when 8  then 'August'
            when 9  then 'September'
            when 10 then 'October'
            when 11 then 'November'
            when 12 then 'December'
        end                                             as month_name,

        -- Quarter-level fields
        quarter(date_day)                               as quarter_number,

        -- Year-level fields
        year(date_day)                                  as year_number,

        -- Fiscal calendar fields.
        -- Fiscal year starts February 1.
        -- If current month >= 2, fiscal year = calendar year
        -- If current month = 1, fiscal year = calendar year - 1
        -- (January belongs to the previous fiscal year)
        case
            when month(date_day) >= 2
                then year(date_day)
            else year(date_day) - 1
        end                                             as fiscal_year,

        -- Fiscal quarter: shifted by 1 month from calendar quarter.
        -- FQ1 = Feb-Apr, FQ2 = May-Jul, FQ3 = Aug-Oct, FQ4 = Nov-Jan
        case
            when month(date_day) in (2, 3, 4)   then 1
            when month(date_day) in (5, 6, 7)   then 2
            when month(date_day) in (8, 9, 10)  then 3
            when month(date_day) in (11, 12, 1) then 4
        end                                             as fiscal_quarter,

        -- Weekend flag
        case
            when dayofweekiso(date_day) in (6, 7) then true
            else false
        end                                             as is_weekend

    from date_spine

),

-- Add US federal holiday flags.
-- This covers the 11 standard US federal holidays.
-- For holidays with variable dates (Thanksgiving, MLK Day, etc.),
-- we use simplified date-based rules.
with_holidays as (

    select
        cf.*,

        -- US Federal Holiday detection
        case
            -- New Year's Day: January 1
            when month_number = 1 and day_of_month = 1
                then true

            -- MLK Day: Third Monday of January
            when month_number = 1
                and day_of_week = 1  -- Monday
                and day_of_month between 15 and 21
                then true

            -- Presidents' Day: Third Monday of February
            when month_number = 2
                and day_of_week = 1
                and day_of_month between 15 and 21
                then true

            -- Memorial Day: Last Monday of May
            when month_number = 5
                and day_of_week = 1
                and day_of_month >= 25
                then true

            -- Juneteenth: June 19
            when month_number = 6 and day_of_month = 19
                then true

            -- Independence Day: July 4
            when month_number = 7 and day_of_month = 4
                then true

            -- Labor Day: First Monday of September
            when month_number = 9
                and day_of_week = 1
                and day_of_month <= 7
                then true

            -- Columbus Day: Second Monday of October
            when month_number = 10
                and day_of_week = 1
                and day_of_month between 8 and 14
                then true

            -- Veterans Day: November 11
            when month_number = 11 and day_of_month = 11
                then true

            -- Thanksgiving: Fourth Thursday of November
            when month_number = 11
                and day_of_week = 4  -- Thursday
                and day_of_month between 22 and 28
                then true

            -- Christmas Day: December 25
            when month_number = 12 and day_of_month = 25
                then true

            else false
        end                                             as is_holiday,

        -- Holiday name (NULL if not a holiday)
        case
            when month_number = 1 and day_of_month = 1
                then 'New Year''s Day'
            when month_number = 1 and day_of_week = 1 and day_of_month between 15 and 21
                then 'Martin Luther King Jr. Day'
            when month_number = 2 and day_of_week = 1 and day_of_month between 15 and 21
                then 'Presidents'' Day'
            when month_number = 5 and day_of_week = 1 and day_of_month >= 25
                then 'Memorial Day'
            when month_number = 6 and day_of_month = 19
                then 'Juneteenth'
            when month_number = 7 and day_of_month = 4
                then 'Independence Day'
            when month_number = 9 and day_of_week = 1 and day_of_month <= 7
                then 'Labor Day'
            when month_number = 10 and day_of_week = 1 and day_of_month between 8 and 14
                then 'Columbus Day'
            when month_number = 11 and day_of_month = 11
                then 'Veterans Day'
            when month_number = 11 and day_of_week = 4 and day_of_month between 22 and 28
                then 'Thanksgiving'
            when month_number = 12 and day_of_month = 25
                then 'Christmas Day'
            else null
        end                                             as holiday_name

    from calendar_fields cf

)

select * from with_holidays
