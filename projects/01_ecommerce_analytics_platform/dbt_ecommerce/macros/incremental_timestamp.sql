-- ============================================================
-- SNOWBRIX E-COMMERCE PLATFORM
-- Macro: incremental_timestamp
-- ============================================================
-- Generates a reusable WHERE clause for incremental models
-- based on a timestamp column. This ensures all incremental
-- models use the same pattern for filtering new rows.
--
-- USAGE (in an incremental model):
--
--   SELECT * FROM {{ ref('some_upstream_model') }}
--   {{ incremental_timestamp('order_date') }}
--
-- This expands to:
--   WHERE order_date > (SELECT MAX(order_date) FROM <this_table>)
--   (only when the model is running incrementally, not on first run)
--
-- PARAMETERS:
--   timestamp_column - The column name to use for incremental filtering
--   lookback_hours   - Optional hours to look back beyond the max timestamp
--                      to catch late-arriving data (default: 0)
--
-- WHY A MACRO?
-- Without this macro, every incremental model has its own
-- copy of the is_incremental() + WHERE logic. If we need to
-- change the pattern (e.g., add a lookback window), we'd have
-- to update every model. With the macro, we change it once.
-- ============================================================

{% macro incremental_timestamp(timestamp_column, lookback_hours=0) %}

    {% if is_incremental() %}
        where {{ timestamp_column }} > (
            select
                {% if lookback_hours > 0 %}
                    -- Look back beyond the max timestamp to catch late-arriving data.
                    -- For example, if lookback_hours=3, we re-process the last 3 hours
                    -- of data on every run. This handles records that arrive late but
                    -- have a timestamp within the lookback window.
                    dateadd(
                        'hour',
                        -{{ lookback_hours }},
                        max({{ timestamp_column }})
                    )
                {% else %}
                    max({{ timestamp_column }})
                {% endif %}
            from {{ this }}
        )
    {% endif %}

{% endmacro %}


-- ============================================================
-- Macro: incremental_date
-- ============================================================
-- Variant of incremental_timestamp for date columns (no time
-- component). Uses DATE comparison instead of TIMESTAMP.
--
-- USAGE:
--   SELECT * FROM {{ ref('some_model') }}
--   {{ incremental_date('order_date', lookback_days=1) }}
-- ============================================================

{% macro incremental_date(date_column, lookback_days=0) %}

    {% if is_incremental() %}
        where cast({{ date_column }} as date) > (
            select
                {% if lookback_days > 0 %}
                    dateadd(
                        'day',
                        -{{ lookback_days }},
                        max(cast({{ date_column }} as date))
                    )
                {% else %}
                    max(cast({{ date_column }} as date))
                {% endif %}
            from {{ this }}
        )
    {% endif %}

{% endmacro %}
