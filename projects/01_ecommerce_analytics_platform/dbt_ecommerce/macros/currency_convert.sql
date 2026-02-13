-- ============================================================
-- SNOWBRIX E-COMMERCE PLATFORM
-- Macro: currency_convert
-- ============================================================
-- Converts a monetary amount from one currency to another
-- using the exchange rates defined in the currency_rates seed.
--
-- USAGE:
--   {{ currency_convert('payment_amount', 'payment_currency', 'USD') }}
--   {{ currency_convert('price', "'EUR'", "'GBP'") }}
--   {{ currency_convert('total', 'currency_col', var('currency')) }}
--
-- PARAMETERS:
--   amount_column     - Column name or expression containing the amount
--   from_currency     - Column name or literal string for source currency
--   to_currency       - Column name or literal string for target currency
--
-- HOW IT WORKS:
--   1. Looks up the exchange rate from the source currency to USD
--   2. Looks up the exchange rate from USD to the target currency
--   3. Converts: amount / from_rate * to_rate
--
-- The seed table stores rates relative to USD (1 USD = X units).
-- To convert EUR to GBP: amount_eur / eur_rate * gbp_rate
--
-- If no rate is found, returns the original amount unchanged
-- (assumes same currency or missing data).
-- ============================================================

{% macro currency_convert(amount_column, from_currency, to_currency) %}

    case
        -- If source and target currencies are the same, no conversion needed
        when upper({{ from_currency }}) = upper({{ to_currency }})
            then {{ amount_column }}

        -- Otherwise, convert via USD as the base currency
        else
            round(
                {{ amount_column }}
                / nullif(
                    (
                        select cr_from.exchange_rate
                        from {{ ref('currency_rates') }} cr_from
                        where upper(cr_from.from_currency) = 'USD'
                          and upper(cr_from.to_currency) = upper({{ from_currency }})
                        order by cr_from.effective_date desc
                        limit 1
                    ),
                    0
                )
                * (
                    select cr_to.exchange_rate
                    from {{ ref('currency_rates') }} cr_to
                    where upper(cr_to.from_currency) = 'USD'
                      and upper(cr_to.to_currency) = upper({{ to_currency }})
                    order by cr_to.effective_date desc
                    limit 1
                ),
                2
            )
    end

{% endmacro %}


-- ============================================================
-- Simplified version that converts any amount to the project's
-- default reporting currency (set via var('currency')).
--
-- USAGE:
--   {{ convert_to_reporting_currency('payment_amount', 'payment_currency') }}
-- ============================================================

{% macro convert_to_reporting_currency(amount_column, from_currency_column) %}

    {{ currency_convert(
        amount_column,
        from_currency_column,
        "'" ~ var('currency', 'USD') ~ "'"
    ) }}

{% endmacro %}
