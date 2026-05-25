-- Regression checks for the first analyst-facing Phase 2 labor/trade serving layer.
DO $$
DECLARE
    phase2_indicator_count INT;
    labor_indicator_count INT;
    labor_non_labor_indicator_count INT;
    labor_row_count INT;
    employment_populated_count INT;
    labor_force_participation_populated_count INT;
    latest_row_count INT;
    unemployment_populated_count INT;
    trade_populated_count INT;
    mismatched_balance_count INT;
    mismatched_direction_count INT;
BEGIN
    SELECT COUNT(DISTINCT indicator_code)
    INTO phase2_indicator_count
    FROM mart.mart_country_phase2_series_annual
    WHERE indicator_code IN (
        'EMPLOYMENT_RATE_PCT',
        'LABOR_FORCE_PARTICIPATION_RATE_PCT',
        'UNEMPLOYMENT_RATE_PCT',
        'TRADE_EXPORTS_CURR_USD',
        'TRADE_IMPORTS_CURR_USD'
    );

    IF phase2_indicator_count <> 5 THEN
        RAISE EXCEPTION 'Phase 2 starter mart test failed: expected 5 distinct seeded indicators in mart_country_phase2_series_annual, found %', phase2_indicator_count;
    END IF;

    SELECT COUNT(DISTINCT indicator_code)
    INTO labor_indicator_count
    FROM mart.mart_country_labor_series_annual
    WHERE indicator_code IN (
        'EMPLOYMENT_RATE_PCT',
        'LABOR_FORCE_PARTICIPATION_RATE_PCT',
        'UNEMPLOYMENT_RATE_PCT'
    );

    IF labor_indicator_count <> 3 THEN
        RAISE EXCEPTION 'Phase 2 starter mart test failed: expected 3 distinct labor indicators in mart_country_labor_series_annual, found %', labor_indicator_count;
    END IF;

    SELECT COUNT(*)
    INTO labor_non_labor_indicator_count
    FROM mart.mart_country_labor_series_annual
    WHERE indicator_code NOT IN (
        'EMPLOYMENT_RATE_PCT',
        'LABOR_FORCE_PARTICIPATION_RATE_PCT',
        'UNEMPLOYMENT_RATE_PCT'
    );

    IF labor_non_labor_indicator_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 starter mart test failed: mart_country_labor_series_annual contains % non-labor row(s)', labor_non_labor_indicator_count;
    END IF;

    SELECT COUNT(*)
    INTO labor_row_count
    FROM mart.mart_country_labor_series_annual;

    IF labor_row_count = 0 THEN
        RAISE EXCEPTION 'Phase 2 starter mart test failed: mart_country_labor_series_annual returned no rows';
    END IF;

    SELECT COUNT(*)
    INTO latest_row_count
    FROM mart.mart_country_phase2_latest;

    IF latest_row_count = 0 THEN
        RAISE EXCEPTION 'Phase 2 starter mart test failed: mart_country_phase2_latest returned no rows';
    END IF;

    SELECT COUNT(*)
    INTO employment_populated_count
    FROM mart.mart_country_phase2_latest
    WHERE employment_rate_pct_year IS NOT NULL
      AND employment_rate_pct IS NOT NULL;

    IF employment_populated_count = 0 THEN
        RAISE EXCEPTION 'Phase 2 starter mart test failed: latest Phase 2 view has no populated employment-rate values';
    END IF;

    SELECT COUNT(*)
    INTO labor_force_participation_populated_count
    FROM mart.mart_country_phase2_latest
    WHERE labor_force_participation_rate_pct_year IS NOT NULL
      AND labor_force_participation_rate_pct IS NOT NULL;

    IF labor_force_participation_populated_count = 0 THEN
        RAISE EXCEPTION 'Phase 2 starter mart test failed: latest Phase 2 view has no populated labor-force-participation values';
    END IF;

    SELECT COUNT(*)
    INTO unemployment_populated_count
    FROM mart.mart_country_phase2_latest
    WHERE unemployment_rate_pct_year IS NOT NULL
      AND unemployment_rate_pct IS NOT NULL;

    IF unemployment_populated_count = 0 THEN
        RAISE EXCEPTION 'Phase 2 starter mart test failed: latest Phase 2 view has no populated unemployment values';
    END IF;

    SELECT COUNT(*)
    INTO trade_populated_count
    FROM mart.mart_country_phase2_latest
    WHERE trade_exports_curr_usd_year IS NOT NULL
      AND trade_exports_curr_usd IS NOT NULL
      AND trade_imports_curr_usd_year IS NOT NULL
      AND trade_imports_curr_usd IS NOT NULL;

    IF trade_populated_count = 0 THEN
        RAISE EXCEPTION 'Phase 2 starter mart test failed: latest Phase 2 view has no populated trade values';
    END IF;

    SELECT COUNT(*)
    INTO mismatched_balance_count
    FROM mart.mart_country_phase2_latest
    WHERE trade_exports_curr_usd IS NOT NULL
      AND trade_imports_curr_usd IS NOT NULL
      AND (
            trade_balance_curr_usd IS NULL
            OR trade_balance_curr_usd <> trade_exports_curr_usd - trade_imports_curr_usd
      );

    IF mismatched_balance_count > 0 THEN
        RAISE EXCEPTION 'Phase 2 starter mart test failed: % row(s) have an incorrect trade_balance_curr_usd derivation', mismatched_balance_count;
    END IF;

    SELECT COUNT(*)
    INTO mismatched_direction_count
    FROM mart.mart_country_phase2_latest
    WHERE (
            trade_exports_curr_usd IS NULL OR trade_imports_curr_usd IS NULL
          )
          AND trade_balance_direction <> 'unknown'
       OR (
            trade_exports_curr_usd IS NOT NULL
        AND trade_imports_curr_usd IS NOT NULL
        AND trade_exports_curr_usd > trade_imports_curr_usd
        AND trade_balance_direction <> 'surplus'
       )
       OR (
            trade_exports_curr_usd IS NOT NULL
        AND trade_imports_curr_usd IS NOT NULL
        AND trade_exports_curr_usd < trade_imports_curr_usd
        AND trade_balance_direction <> 'deficit'
       )
       OR (
            trade_exports_curr_usd IS NOT NULL
        AND trade_imports_curr_usd IS NOT NULL
        AND trade_exports_curr_usd = trade_imports_curr_usd
        AND trade_balance_direction <> 'balanced'
       );

    IF mismatched_direction_count > 0 THEN
        RAISE EXCEPTION 'Phase 2 starter mart test failed: % row(s) have an incorrect trade_balance_direction', mismatched_direction_count;
    END IF;
END;
$$;

SELECT
    iso_alpha_3,
    country_name,
    indicator_code,
    observation_year,
    observation_value,
    source_code,
    dataset_code,
    series_code
FROM mart.mart_country_labor_series_annual
ORDER BY iso_alpha_3, indicator_code, observation_year DESC
LIMIT 10;

SELECT
    iso_alpha_3,
    country_name,
    employment_rate_pct_year,
    employment_rate_pct,
    labor_force_participation_rate_pct_year,
    labor_force_participation_rate_pct,
    unemployment_rate_pct_year,
    unemployment_rate_pct,
    trade_exports_curr_usd_year,
    trade_exports_curr_usd,
    trade_imports_curr_usd_year,
    trade_imports_curr_usd,
    trade_balance_curr_usd,
    trade_balance_direction
FROM mart.mart_country_phase2_latest
ORDER BY iso_alpha_3
LIMIT 10;
