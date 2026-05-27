-- Regression checks for the first analyst-facing Phase 2 serving layer.
DO $$
DECLARE
    phase2_indicator_count INT;
    labor_indicator_count INT;
    labor_non_labor_indicator_count INT;
    labor_row_count INT;
    labor_conflict_non_labor_indicator_count INT;
    labor_conflict_missing_selected_count INT;
    labor_conflict_row_count INT;
    labor_conflict_duplicate_version_count INT;
    labor_conflict_latest_row_count INT;
    labor_conflict_latest_duplicate_dataset_count INT;
    labor_conflict_latest_missing_selected_count INT;
    labor_conflict_latest_invalid_selected_key_count INT;
    labor_conflict_summary_row_count INT;
    labor_revision_non_labor_indicator_count INT;
    labor_revision_missing_change_type_count INT;
    inflation_indicator_count INT;
    inflation_non_inflation_indicator_count INT;
    inflation_row_count INT;
    inflation_conflict_non_inflation_indicator_count INT;
    inflation_conflict_missing_selected_count INT;
    inflation_conflict_row_count INT;
    inflation_conflict_duplicate_version_count INT;
    inflation_conflict_latest_row_count INT;
    inflation_conflict_latest_duplicate_dataset_count INT;
    inflation_conflict_latest_missing_selected_count INT;
    inflation_conflict_latest_invalid_selected_key_count INT;
    inflation_conflict_summary_row_count INT;
    gdp_conflict_non_gdp_indicator_count INT;
    gdp_conflict_missing_selected_count INT;
    gdp_conflict_row_count INT;
    gdp_conflict_duplicate_version_count INT;
    gdp_conflict_latest_row_count INT;
    gdp_conflict_latest_duplicate_dataset_count INT;
    gdp_conflict_latest_missing_selected_count INT;
    gdp_conflict_latest_invalid_selected_key_count INT;
    gdp_conflict_summary_row_count INT;
    summary_alias_mismatch_count INT;
    phase2_conflict_summary_row_count INT;
    phase2_conflict_summary_family_count INT;
    phase2_qa_missing_conflict_counts INT;
    phase2_qa_ifs_conflict_count INT;
    phase2_qa_ilostat_conflict_count INT;
    phase2_qa_weo_conflict_count INT;
    phase2_qa_trade_conflict_count INT;
    trade_external_indicator_count INT;
    trade_external_non_trade_indicator_count INT;
    trade_external_row_count INT;
    trade_revision_non_trade_indicator_count INT;
    trade_revision_missing_change_type_count INT;
    trade_revision_row_count INT;
    phase2_qa_row_count INT;
    phase2_qa_invalid_dataset_count INT;
    phase2_qa_invalid_status_count INT;
    latest_row_count INT;
    macro_plus_external_row_count INT;
    employment_populated_count INT;
    labor_force_participation_populated_count INT;
    unemployment_populated_count INT;
    inflation_populated_count INT;
    trade_populated_count INT;
    external_balance_populated_count INT;
    macro_populated_count INT;
    latest_phase2_coverage_populated_count INT;
    latest_phase2_recency_populated_count INT;
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
        'INFLATION_CPI_PCT',
        'TRADE_EXPORTS_CURR_USD',
        'TRADE_IMPORTS_CURR_USD',
        'CURRENT_ACCOUNT_BALANCE_CURR_USD',
        'CURRENT_ACCOUNT_BALANCE_PCT_GDP'
    );

    IF phase2_indicator_count <> 8 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: expected 8 distinct seeded indicators in mart_country_phase2_series_annual, found %', phase2_indicator_count;
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
        RAISE EXCEPTION 'Phase 2 mart test failed: expected 3 distinct labor indicators in mart_country_labor_series_annual, found %', labor_indicator_count;
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
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_country_labor_series_annual contains % non-labor row(s)', labor_non_labor_indicator_count;
    END IF;

    SELECT COUNT(*)
    INTO labor_row_count
    FROM mart.mart_country_labor_series_annual;

    IF labor_row_count = 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_country_labor_series_annual returned no rows';
    END IF;

    SELECT COUNT(*)
    INTO labor_conflict_non_labor_indicator_count
    FROM mart.vw_labor_source_conflicts
    WHERE indicator_code NOT IN (
        'EMPLOYMENT_RATE_PCT',
        'LABOR_FORCE_PARTICIPATION_RATE_PCT',
        'UNEMPLOYMENT_RATE_PCT'
    );

    IF labor_conflict_non_labor_indicator_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: vw_labor_source_conflicts contains % non-labor row(s)', labor_conflict_non_labor_indicator_count;
    END IF;

    SELECT COUNT(*)
    INTO labor_conflict_missing_selected_count
    FROM mart.vw_labor_source_conflicts
    WHERE selected_observation_version_key IS NULL
       OR selected_dataset_code IS NULL
       OR selected_selection_method IS NULL;

    IF labor_conflict_missing_selected_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: vw_labor_source_conflicts contains % row(s) missing selected-row lineage', labor_conflict_missing_selected_count;
    END IF;

    SELECT COUNT(*)
    INTO labor_conflict_row_count
    FROM mart.vw_labor_source_conflicts;

    IF labor_conflict_row_count = 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: vw_labor_source_conflicts returned no rows; expected the real WDI-vs-ILOSTAT overlap proof';
    END IF;

    SELECT COUNT(*) - COUNT(DISTINCT observation_version_key)
    INTO labor_conflict_duplicate_version_count
    FROM mart.vw_labor_source_conflicts;

    IF labor_conflict_duplicate_version_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: vw_labor_source_conflicts repeats % observation version row(s)', labor_conflict_duplicate_version_count;
    END IF;

    SELECT COUNT(*)
    INTO labor_conflict_latest_row_count
    FROM mart.vw_labor_source_conflicts_latest;

    IF labor_conflict_latest_row_count = 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: vw_labor_source_conflicts_latest returned no rows; expected the real WDI-vs-ILOSTAT overlap proof';
    END IF;

    SELECT COUNT(*) - COUNT(DISTINCT (country_key, indicator_key, time_key, source_dataset_key))
    INTO labor_conflict_latest_duplicate_dataset_count
    FROM mart.vw_labor_source_conflicts_latest;

    IF labor_conflict_latest_duplicate_dataset_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: vw_labor_source_conflicts_latest contains % duplicate latest row(s) for the same country/indicator/year/dataset key', labor_conflict_latest_duplicate_dataset_count;
    END IF;

    SELECT COUNT(*)
    INTO labor_conflict_latest_missing_selected_count
    FROM mart.vw_labor_source_conflicts_latest
    WHERE selected_observation_version_key IS NULL
       OR selected_dataset_code IS NULL
       OR selected_selection_method IS NULL;

    IF labor_conflict_latest_missing_selected_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: vw_labor_source_conflicts_latest contains % row(s) missing selected-row lineage', labor_conflict_latest_missing_selected_count;
    END IF;

    SELECT COUNT(*)
    INTO labor_conflict_latest_invalid_selected_key_count
    FROM (
        SELECT
            country_key,
            indicator_key,
            time_key,
            COUNT(*) FILTER (WHERE is_selected_published_row) AS selected_rows_for_key
        FROM mart.vw_labor_source_conflicts_latest
        GROUP BY country_key, indicator_key, time_key
        HAVING COUNT(*) FILTER (WHERE is_selected_published_row) <> 1
    ) invalid_keys;

    IF labor_conflict_latest_invalid_selected_key_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: vw_labor_source_conflicts_latest has % conflict key(s) without exactly one selected published row', labor_conflict_latest_invalid_selected_key_count;
    END IF;

    SELECT COUNT(*)
    INTO labor_conflict_summary_row_count
    FROM mart.vw_labor_source_conflict_summary;

    IF labor_conflict_summary_row_count = 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: vw_labor_source_conflict_summary returned no rows despite seeded labor overlap';
    END IF;

    SELECT COUNT(*)
    INTO summary_alias_mismatch_count
    FROM (
        (
            SELECT * FROM mart.vw_labor_source_conflict_summary
            EXCEPT ALL
            SELECT * FROM mart.vw_labor_source_conflict_summary_latest
        )
        UNION ALL
        (
            SELECT * FROM mart.vw_labor_source_conflict_summary_latest
            EXCEPT ALL
            SELECT * FROM mart.vw_labor_source_conflict_summary
        )
    ) summary_alias_diff;

    IF summary_alias_mismatch_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: vw_labor_source_conflict_summary drifted from vw_labor_source_conflict_summary_latest (% mismatched row(s))', summary_alias_mismatch_count;
    END IF;

    SELECT COUNT(*)
    INTO labor_revision_non_labor_indicator_count
    FROM mart.vw_labor_revision_history
    WHERE indicator_code NOT IN (
        'EMPLOYMENT_RATE_PCT',
        'LABOR_FORCE_PARTICIPATION_RATE_PCT',
        'UNEMPLOYMENT_RATE_PCT'
    );

    IF labor_revision_non_labor_indicator_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: vw_labor_revision_history contains % non-labor row(s)', labor_revision_non_labor_indicator_count;
    END IF;

    SELECT COUNT(*)
    INTO labor_revision_missing_change_type_count
    FROM mart.vw_labor_revision_history
    WHERE change_type IS NULL;

    IF labor_revision_missing_change_type_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: vw_labor_revision_history contains % row(s) missing change_type', labor_revision_missing_change_type_count;
    END IF;

    SELECT COUNT(DISTINCT indicator_code)
    INTO inflation_indicator_count
    FROM mart.mart_country_inflation_series_annual
    WHERE indicator_code = 'INFLATION_CPI_PCT';

    IF inflation_indicator_count <> 1 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: expected 1 inflation indicator in mart_country_inflation_series_annual, found %', inflation_indicator_count;
    END IF;

    SELECT COUNT(*)
    INTO inflation_non_inflation_indicator_count
    FROM mart.mart_country_inflation_series_annual
    WHERE indicator_code <> 'INFLATION_CPI_PCT';

    IF inflation_non_inflation_indicator_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_country_inflation_series_annual contains % non-inflation row(s)', inflation_non_inflation_indicator_count;
    END IF;

    SELECT COUNT(*)
    INTO inflation_row_count
    FROM mart.mart_country_inflation_series_annual;

    IF inflation_row_count = 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_country_inflation_series_annual returned no rows';
    END IF;

    SELECT COUNT(*)
    INTO inflation_conflict_non_inflation_indicator_count
    FROM mart.vw_inflation_source_conflicts
    WHERE indicator_code <> 'INFLATION_CPI_PCT';

    IF inflation_conflict_non_inflation_indicator_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: vw_inflation_source_conflicts contains % non-inflation row(s)', inflation_conflict_non_inflation_indicator_count;
    END IF;

    SELECT COUNT(*)
    INTO inflation_conflict_missing_selected_count
    FROM mart.vw_inflation_source_conflicts
    WHERE selected_observation_version_key IS NULL
       OR selected_dataset_code IS NULL
       OR selected_selection_method IS NULL;

    IF inflation_conflict_missing_selected_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: vw_inflation_source_conflicts contains % row(s) missing selected-row lineage', inflation_conflict_missing_selected_count;
    END IF;

    SELECT COUNT(*)
    INTO inflation_conflict_row_count
    FROM mart.vw_inflation_source_conflicts;

    IF inflation_conflict_row_count = 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: vw_inflation_source_conflicts returned no rows despite seeded IFS/WDI overlap';
    END IF;

    SELECT COUNT(*) - COUNT(DISTINCT observation_version_key)
    INTO inflation_conflict_duplicate_version_count
    FROM mart.vw_inflation_source_conflicts;

    IF inflation_conflict_duplicate_version_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: vw_inflation_source_conflicts repeats % observation version row(s)', inflation_conflict_duplicate_version_count;
    END IF;

    SELECT COUNT(*)
    INTO inflation_conflict_latest_row_count
    FROM mart.vw_inflation_source_conflicts_latest;

    IF inflation_conflict_latest_row_count = 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: vw_inflation_source_conflicts_latest returned no rows despite seeded IFS/WDI overlap';
    END IF;

    SELECT COUNT(*) - COUNT(DISTINCT (country_key, indicator_key, time_key, source_dataset_key))
    INTO inflation_conflict_latest_duplicate_dataset_count
    FROM mart.vw_inflation_source_conflicts_latest;

    IF inflation_conflict_latest_duplicate_dataset_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: vw_inflation_source_conflicts_latest contains % duplicate latest row(s) for the same country/indicator/year/dataset key', inflation_conflict_latest_duplicate_dataset_count;
    END IF;

    SELECT COUNT(*)
    INTO inflation_conflict_latest_missing_selected_count
    FROM mart.vw_inflation_source_conflicts_latest
    WHERE selected_observation_version_key IS NULL
       OR selected_dataset_code IS NULL
       OR selected_selection_method IS NULL;

    IF inflation_conflict_latest_missing_selected_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: vw_inflation_source_conflicts_latest contains % row(s) missing selected-row lineage', inflation_conflict_latest_missing_selected_count;
    END IF;

    SELECT COUNT(*)
    INTO inflation_conflict_latest_invalid_selected_key_count
    FROM (
        SELECT
            country_key,
            indicator_key,
            time_key,
            COUNT(*) FILTER (WHERE is_selected_published_row) AS selected_rows_for_key
        FROM mart.vw_inflation_source_conflicts_latest
        GROUP BY country_key, indicator_key, time_key
        HAVING COUNT(*) FILTER (WHERE is_selected_published_row) <> 1
    ) invalid_keys;

    IF inflation_conflict_latest_invalid_selected_key_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: vw_inflation_source_conflicts_latest has % conflict key(s) without exactly one selected published row', inflation_conflict_latest_invalid_selected_key_count;
    END IF;

    SELECT COUNT(*)
    INTO inflation_conflict_summary_row_count
    FROM mart.vw_inflation_source_conflict_summary_latest;

    IF inflation_conflict_summary_row_count = 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: vw_inflation_source_conflict_summary_latest returned no rows despite seeded IFS/WDI overlap';
    END IF;

    SELECT COUNT(*)
    INTO inflation_conflict_summary_row_count
    FROM mart.vw_inflation_source_conflict_summary;

    IF inflation_conflict_summary_row_count = 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: vw_inflation_source_conflict_summary returned no rows despite seeded IFS/WDI overlap';
    END IF;

    SELECT COUNT(*)
    INTO summary_alias_mismatch_count
    FROM (
        (
            SELECT * FROM mart.vw_inflation_source_conflict_summary
            EXCEPT ALL
            SELECT * FROM mart.vw_inflation_source_conflict_summary_latest
        )
        UNION ALL
        (
            SELECT * FROM mart.vw_inflation_source_conflict_summary_latest
            EXCEPT ALL
            SELECT * FROM mart.vw_inflation_source_conflict_summary
        )
    ) summary_alias_diff;

    IF summary_alias_mismatch_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: vw_inflation_source_conflict_summary drifted from vw_inflation_source_conflict_summary_latest (% mismatched row(s))', summary_alias_mismatch_count;
    END IF;

    SELECT COUNT(*)
    INTO gdp_conflict_non_gdp_indicator_count
    FROM mart.vw_gdp_source_conflicts
    WHERE indicator_code <> 'GDP_CURR_USD';

    IF gdp_conflict_non_gdp_indicator_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: vw_gdp_source_conflicts contains % non-GDP row(s)', gdp_conflict_non_gdp_indicator_count;
    END IF;

    SELECT COUNT(*)
    INTO gdp_conflict_missing_selected_count
    FROM mart.vw_gdp_source_conflicts
    WHERE selected_observation_version_key IS NULL
       OR selected_dataset_code IS NULL
       OR selected_selection_method IS NULL;

    IF gdp_conflict_missing_selected_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: vw_gdp_source_conflicts contains % row(s) missing selected-row lineage', gdp_conflict_missing_selected_count;
    END IF;

    SELECT COUNT(*)
    INTO gdp_conflict_row_count
    FROM mart.vw_gdp_source_conflicts;

    IF gdp_conflict_row_count = 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: vw_gdp_source_conflicts returned no rows despite seeded IFS/WDI overlap';
    END IF;

    SELECT COUNT(*) - COUNT(DISTINCT observation_version_key)
    INTO gdp_conflict_duplicate_version_count
    FROM mart.vw_gdp_source_conflicts;

    IF gdp_conflict_duplicate_version_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: vw_gdp_source_conflicts repeats % observation version row(s)', gdp_conflict_duplicate_version_count;
    END IF;

    SELECT COUNT(*)
    INTO gdp_conflict_latest_row_count
    FROM mart.vw_gdp_source_conflicts_latest;

    IF gdp_conflict_latest_row_count = 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: vw_gdp_source_conflicts_latest returned no rows despite seeded IFS/WDI overlap';
    END IF;

    SELECT COUNT(*) - COUNT(DISTINCT (country_key, indicator_key, time_key, source_dataset_key))
    INTO gdp_conflict_latest_duplicate_dataset_count
    FROM mart.vw_gdp_source_conflicts_latest;

    IF gdp_conflict_latest_duplicate_dataset_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: vw_gdp_source_conflicts_latest contains % duplicate latest row(s) for the same country/indicator/year/dataset key', gdp_conflict_latest_duplicate_dataset_count;
    END IF;

    SELECT COUNT(*)
    INTO gdp_conflict_latest_missing_selected_count
    FROM mart.vw_gdp_source_conflicts_latest
    WHERE selected_observation_version_key IS NULL
       OR selected_dataset_code IS NULL
       OR selected_selection_method IS NULL;

    IF gdp_conflict_latest_missing_selected_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: vw_gdp_source_conflicts_latest contains % row(s) missing selected-row lineage', gdp_conflict_latest_missing_selected_count;
    END IF;

    SELECT COUNT(*)
    INTO gdp_conflict_latest_invalid_selected_key_count
    FROM (
        SELECT
            country_key,
            indicator_key,
            time_key,
            COUNT(*) FILTER (WHERE is_selected_published_row) AS selected_rows_for_key
        FROM mart.vw_gdp_source_conflicts_latest
        GROUP BY country_key, indicator_key, time_key
        HAVING COUNT(*) FILTER (WHERE is_selected_published_row) <> 1
    ) invalid_keys;

    IF gdp_conflict_latest_invalid_selected_key_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: vw_gdp_source_conflicts_latest has % conflict key(s) without exactly one selected published row', gdp_conflict_latest_invalid_selected_key_count;
    END IF;

    SELECT COUNT(*)
    INTO gdp_conflict_summary_row_count
    FROM mart.vw_gdp_source_conflict_summary_latest;

    IF gdp_conflict_summary_row_count = 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: vw_gdp_source_conflict_summary_latest returned no rows despite seeded IFS/WDI overlap';
    END IF;

    SELECT COUNT(*)
    INTO gdp_conflict_summary_row_count
    FROM mart.vw_gdp_source_conflict_summary;

    IF gdp_conflict_summary_row_count = 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: vw_gdp_source_conflict_summary returned no rows despite seeded IFS/WDI overlap';
    END IF;

    SELECT COUNT(*)
    INTO summary_alias_mismatch_count
    FROM (
        (
            SELECT * FROM mart.vw_gdp_source_conflict_summary
            EXCEPT ALL
            SELECT * FROM mart.vw_gdp_source_conflict_summary_latest
        )
        UNION ALL
        (
            SELECT * FROM mart.vw_gdp_source_conflict_summary_latest
            EXCEPT ALL
            SELECT * FROM mart.vw_gdp_source_conflict_summary
        )
    ) summary_alias_diff;

    IF summary_alias_mismatch_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: vw_gdp_source_conflict_summary drifted from vw_gdp_source_conflict_summary_latest (% mismatched row(s))', summary_alias_mismatch_count;
    END IF;

    SELECT COUNT(*)
    INTO phase2_conflict_summary_row_count
    FROM mart.vw_phase2_source_conflict_summary;

    IF phase2_conflict_summary_row_count = 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: vw_phase2_source_conflict_summary returned no rows';
    END IF;

    SELECT COUNT(DISTINCT conflict_family)
    INTO phase2_conflict_summary_family_count
    FROM mart.vw_phase2_source_conflict_summary;

    IF phase2_conflict_summary_family_count <> 3 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: expected 3 conflict families in vw_phase2_source_conflict_summary, found %', phase2_conflict_summary_family_count;
    END IF;

    SELECT COUNT(DISTINCT indicator_code)
    INTO trade_external_indicator_count
    FROM mart.mart_country_trade_external_panel_annual
    WHERE indicator_code IN (
        'TRADE_EXPORTS_CURR_USD',
        'TRADE_IMPORTS_CURR_USD',
        'CURRENT_ACCOUNT_BALANCE_CURR_USD',
        'CURRENT_ACCOUNT_BALANCE_PCT_GDP'
    );

    IF trade_external_indicator_count <> 4 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: expected 4 trade/external indicators in mart_country_trade_external_panel_annual, found %', trade_external_indicator_count;
    END IF;

    SELECT COUNT(*)
    INTO trade_external_non_trade_indicator_count
    FROM mart.mart_country_trade_external_panel_annual
    WHERE indicator_code NOT IN (
        'TRADE_EXPORTS_CURR_USD',
        'TRADE_IMPORTS_CURR_USD',
        'CURRENT_ACCOUNT_BALANCE_CURR_USD',
        'CURRENT_ACCOUNT_BALANCE_PCT_GDP'
    );

    IF trade_external_non_trade_indicator_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_country_trade_external_panel_annual contains % non-trade row(s)', trade_external_non_trade_indicator_count;
    END IF;

    SELECT COUNT(*)
    INTO trade_external_row_count
    FROM mart.mart_country_trade_external_panel_annual;

    IF trade_external_row_count = 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_country_trade_external_panel_annual returned no rows';
    END IF;

    SELECT COUNT(*)
    INTO trade_revision_non_trade_indicator_count
    FROM mart.vw_trade_external_revision_history
    WHERE indicator_code NOT IN (
        'TRADE_EXPORTS_CURR_USD',
        'TRADE_IMPORTS_CURR_USD',
        'CURRENT_ACCOUNT_BALANCE_CURR_USD',
        'CURRENT_ACCOUNT_BALANCE_PCT_GDP'
    );

    IF trade_revision_non_trade_indicator_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: vw_trade_external_revision_history contains % non-trade row(s)', trade_revision_non_trade_indicator_count;
    END IF;

    SELECT COUNT(*)
    INTO trade_revision_missing_change_type_count
    FROM mart.vw_trade_external_revision_history
    WHERE change_type IS NULL;

    IF trade_revision_missing_change_type_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: vw_trade_external_revision_history contains % row(s) missing change_type', trade_revision_missing_change_type_count;
    END IF;

    SELECT COUNT(*)
    INTO trade_revision_row_count
    FROM mart.vw_trade_external_revision_history;

    IF trade_revision_row_count = 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: vw_trade_external_revision_history returned no rows';
    END IF;

    SELECT COUNT(*)
    INTO phase2_qa_row_count
    FROM mart.vw_domain_qa_summary_phase2;

    IF phase2_qa_row_count = 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: vw_domain_qa_summary_phase2 returned no rows';
    END IF;

    SELECT COUNT(*)
    INTO phase2_qa_invalid_dataset_count
    FROM mart.vw_domain_qa_summary_phase2
    WHERE dataset_code NOT IN ('IFS', 'ILOSTAT', 'UN_COMTRADE_ANNUAL', 'WEO');

    IF phase2_qa_invalid_dataset_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: vw_domain_qa_summary_phase2 contains % row(s) outside the seeded Phase 2 datasets', phase2_qa_invalid_dataset_count;
    END IF;

    SELECT COUNT(*)
    INTO phase2_qa_invalid_status_count
    FROM mart.vw_domain_qa_summary_phase2
    WHERE latest_publish_status IS NULL
       OR freshness_status IS NULL;

    IF phase2_qa_invalid_status_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: vw_domain_qa_summary_phase2 contains % row(s) missing publish/freshness status', phase2_qa_invalid_status_count;
    END IF;

    SELECT COUNT(*)
    INTO phase2_qa_missing_conflict_counts
    FROM mart.vw_domain_qa_summary_phase2
    WHERE current_conflict_key_count IS NULL
       OR current_conflict_dataset_row_count IS NULL
       OR current_selected_conflict_key_count IS NULL;

    IF phase2_qa_missing_conflict_counts <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: vw_domain_qa_summary_phase2 contains % row(s) missing conflict-count QA fields', phase2_qa_missing_conflict_counts;
    END IF;

    SELECT current_conflict_key_count
    INTO phase2_qa_ifs_conflict_count
    FROM mart.vw_domain_qa_summary_phase2
    WHERE dataset_code = 'IFS';

    IF COALESCE(phase2_qa_ifs_conflict_count, 0) = 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: vw_domain_qa_summary_phase2 shows no conflict participation for IFS despite inflation/GDP overlap';
    END IF;

    SELECT current_conflict_key_count
    INTO phase2_qa_ilostat_conflict_count
    FROM mart.vw_domain_qa_summary_phase2
    WHERE dataset_code = 'ILOSTAT';

    IF COALESCE(phase2_qa_ilostat_conflict_count, 0) = 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: vw_domain_qa_summary_phase2 shows no conflict participation for ILOSTAT despite labor overlap';
    END IF;

    SELECT current_conflict_key_count
    INTO phase2_qa_weo_conflict_count
    FROM mart.vw_domain_qa_summary_phase2
    WHERE dataset_code = 'WEO';

    IF COALESCE(phase2_qa_weo_conflict_count, -1) <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: vw_domain_qa_summary_phase2 expected zero conflict participation for WEO, found %', phase2_qa_weo_conflict_count;
    END IF;

    SELECT current_conflict_key_count
    INTO phase2_qa_trade_conflict_count
    FROM mart.vw_domain_qa_summary_phase2
    WHERE dataset_code = 'UN_COMTRADE_ANNUAL';

    IF COALESCE(phase2_qa_trade_conflict_count, -1) <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: vw_domain_qa_summary_phase2 expected zero conflict participation for UN_COMTRADE_ANNUAL, found %', phase2_qa_trade_conflict_count;
    END IF;

    SELECT COUNT(*)
    INTO latest_row_count
    FROM mart.mart_country_phase2_latest;

    IF latest_row_count = 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_country_phase2_latest returned no rows';
    END IF;

    SELECT COUNT(*)
    INTO latest_phase2_coverage_populated_count
    FROM mart.mart_country_phase2_latest
    WHERE phase2_indicator_coverage_count > 0;

    IF latest_phase2_coverage_populated_count = 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_country_phase2_latest has no rows with positive phase2_indicator_coverage_count';
    END IF;

    SELECT COUNT(*)
    INTO latest_phase2_recency_populated_count
    FROM mart.mart_country_phase2_latest
    WHERE latest_phase2_observation_year IS NOT NULL;

    IF latest_phase2_recency_populated_count = 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_country_phase2_latest has no rows with populated latest_phase2_observation_year';
    END IF;

    SELECT COUNT(*)
    INTO macro_plus_external_row_count
    FROM mart.mart_country_macro_plus_external_latest;

    IF macro_plus_external_row_count = 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_country_macro_plus_external_latest returned no rows';
    END IF;

    SELECT COUNT(*)
    INTO macro_populated_count
    FROM mart.mart_country_macro_plus_external_latest
    WHERE gdp_curr_usd_year IS NOT NULL
      AND gdp_curr_usd IS NOT NULL
      AND pop_total_year IS NOT NULL
      AND pop_total IS NOT NULL;

    IF macro_populated_count = 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_country_macro_plus_external_latest has no populated macro foundation values';
    END IF;

    SELECT COUNT(*)
    INTO employment_populated_count
    FROM mart.mart_country_macro_plus_external_latest
    WHERE employment_rate_pct_year IS NOT NULL
      AND employment_rate_pct IS NOT NULL;

    IF employment_populated_count = 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_country_macro_plus_external_latest has no populated employment-rate values';
    END IF;

    SELECT COUNT(*)
    INTO labor_force_participation_populated_count
    FROM mart.mart_country_macro_plus_external_latest
    WHERE labor_force_participation_rate_pct_year IS NOT NULL
      AND labor_force_participation_rate_pct IS NOT NULL;

    IF labor_force_participation_populated_count = 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_country_macro_plus_external_latest has no populated labor-force-participation values';
    END IF;

    SELECT COUNT(*)
    INTO unemployment_populated_count
    FROM mart.mart_country_macro_plus_external_latest
    WHERE unemployment_rate_pct_year IS NOT NULL
      AND unemployment_rate_pct IS NOT NULL;

    IF unemployment_populated_count = 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_country_macro_plus_external_latest has no populated unemployment values';
    END IF;

    SELECT COUNT(*)
    INTO inflation_populated_count
    FROM mart.mart_country_macro_plus_external_latest
    WHERE inflation_cpi_pct_year IS NOT NULL
      AND inflation_cpi_pct IS NOT NULL;

    IF inflation_populated_count = 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_country_macro_plus_external_latest has no populated inflation values';
    END IF;

    SELECT COUNT(*)
    INTO trade_populated_count
    FROM mart.mart_country_macro_plus_external_latest
    WHERE trade_exports_curr_usd_year IS NOT NULL
      AND trade_exports_curr_usd IS NOT NULL
      AND trade_imports_curr_usd_year IS NOT NULL
      AND trade_imports_curr_usd IS NOT NULL;

    IF trade_populated_count = 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_country_macro_plus_external_latest has no populated trade values';
    END IF;

    SELECT COUNT(*)
    INTO external_balance_populated_count
    FROM mart.mart_country_macro_plus_external_latest
    WHERE current_account_balance_curr_usd_year IS NOT NULL
      AND current_account_balance_curr_usd IS NOT NULL
      AND current_account_balance_pct_gdp_year IS NOT NULL
      AND current_account_balance_pct_gdp IS NOT NULL;

    IF external_balance_populated_count = 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_country_macro_plus_external_latest has no populated external-balance values';
    END IF;

    SELECT COUNT(*)
    INTO mismatched_balance_count
    FROM mart.mart_country_macro_plus_external_latest
    WHERE trade_exports_curr_usd IS NOT NULL
      AND trade_imports_curr_usd IS NOT NULL
      AND (
            trade_balance_curr_usd IS NULL
            OR trade_balance_curr_usd <> trade_exports_curr_usd - trade_imports_curr_usd
      );

    IF mismatched_balance_count > 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: % row(s) have an incorrect trade_balance_curr_usd derivation', mismatched_balance_count;
    END IF;

    SELECT COUNT(*)
    INTO mismatched_direction_count
    FROM mart.mart_country_macro_plus_external_latest
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
        RAISE EXCEPTION 'Phase 2 mart test failed: % row(s) have an incorrect trade_balance_direction', mismatched_direction_count;
    END IF;
END;
$$;

SELECT
    conflict_family,
    conflict_scope,
    iso_alpha_3,
    country_name,
    indicator_code,
    observation_year,
    selected_dataset_code,
    selected_selection_method,
    candidate_dataset_values
FROM mart.vw_phase2_source_conflict_summary
ORDER BY conflict_family, observation_year DESC, iso_alpha_3
LIMIT 12;

SELECT
    dataset_code,
    source_code,
    freshness_status,
    latest_publish_status,
    latest_publish_total_dq_event_count,
    latest_publish_blocking_qa_event_count,
    current_phase2_published_row_count,
    current_phase2_indicator_count,
    current_conflict_key_count,
    current_conflict_dataset_row_count,
    current_selected_conflict_key_count,
    latest_conflict_observation_year,
    anomaly_flags
FROM mart.vw_domain_qa_summary_phase2
ORDER BY dataset_code;

SELECT
    iso_alpha_3,
    country_name,
    phase2_indicator_coverage_count,
    latest_phase2_observation_year,
    employment_rate_pct_year,
    employment_rate_pct,
    unemployment_rate_pct_year,
    unemployment_rate_pct,
    inflation_cpi_pct_year,
    inflation_cpi_pct,
    trade_exports_curr_usd_year,
    trade_exports_curr_usd,
    trade_imports_curr_usd_year,
    trade_imports_curr_usd,
    current_account_balance_curr_usd_year,
    current_account_balance_curr_usd,
    current_account_balance_pct_gdp_year,
    current_account_balance_pct_gdp,
    trade_balance_curr_usd,
    trade_balance_direction,
    latest_published_at
FROM mart.mart_country_phase2_latest
ORDER BY iso_alpha_3
LIMIT 10;

\if :{?PHASE2_VERBOSE}
\else
\set PHASE2_VERBOSE 0
\endif
\if :PHASE2_VERBOSE
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
    indicator_code,
    observation_year,
    observation_value,
    source_code,
    dataset_code,
    series_code,
    selection_method
FROM mart.mart_country_inflation_series_annual
ORDER BY observation_year DESC, iso_alpha_3
LIMIT 10;

SELECT
    iso_alpha_3,
    country_name,
    indicator_code,
    observation_year,
    dataset_code,
    observation_value,
    selected_dataset_code,
    selected_observation_value,
    selected_selection_method,
    is_selected_published_row
FROM mart.vw_labor_source_conflicts
ORDER BY observation_year DESC, iso_alpha_3, indicator_code, dataset_code
LIMIT 10;

SELECT
    iso_alpha_3,
    country_name,
    indicator_code,
    observation_year,
    dataset_code,
    observation_value,
    selected_dataset_code,
    selected_observation_value,
    selected_selection_method,
    is_selected_published_row
FROM mart.vw_labor_source_conflicts_latest
ORDER BY observation_year DESC, iso_alpha_3, indicator_code, dataset_code
LIMIT 10;

SELECT
    iso_alpha_3,
    country_name,
    indicator_code,
    observation_year,
    competing_dataset_count,
    selected_dataset_code,
    selected_observation_value,
    conflicting_value_spread,
    candidate_dataset_values
FROM mart.vw_labor_source_conflict_summary_latest
ORDER BY observation_year DESC, iso_alpha_3, indicator_code
LIMIT 10;

SELECT
    iso_alpha_3,
    country_name,
    indicator_code,
    observation_year,
    dataset_code,
    observation_value,
    selected_dataset_code,
    selected_observation_value,
    selected_selection_method,
    is_selected_published_row
FROM mart.vw_inflation_source_conflicts
ORDER BY observation_year DESC, iso_alpha_3, dataset_code
LIMIT 10;

SELECT
    iso_alpha_3,
    country_name,
    indicator_code,
    observation_year,
    dataset_code,
    observation_value,
    selected_dataset_code,
    selected_observation_value,
    selected_selection_method,
    is_selected_published_row
FROM mart.vw_inflation_source_conflicts_latest
ORDER BY observation_year DESC, iso_alpha_3, dataset_code
LIMIT 10;

SELECT
    iso_alpha_3,
    country_name,
    indicator_code,
    observation_year,
    competing_dataset_count,
    selected_dataset_code,
    selected_observation_value,
    conflicting_value_spread,
    candidate_dataset_values
FROM mart.vw_inflation_source_conflict_summary_latest
ORDER BY observation_year DESC, iso_alpha_3, indicator_code
LIMIT 10;

SELECT
    iso_alpha_3,
    country_name,
    indicator_code,
    observation_year,
    dataset_code,
    observation_value,
    selected_dataset_code,
    selected_observation_value,
    selected_selection_method,
    is_selected_published_row
FROM mart.vw_gdp_source_conflicts
ORDER BY observation_year DESC, iso_alpha_3, dataset_code
LIMIT 10;

SELECT
    iso_alpha_3,
    country_name,
    indicator_code,
    observation_year,
    dataset_code,
    observation_value,
    selected_dataset_code,
    selected_observation_value,
    selected_selection_method,
    is_selected_published_row
FROM mart.vw_gdp_source_conflicts_latest
ORDER BY observation_year DESC, iso_alpha_3, dataset_code
LIMIT 10;

SELECT
    iso_alpha_3,
    country_name,
    indicator_code,
    observation_year,
    competing_dataset_count,
    selected_dataset_code,
    selected_observation_value,
    conflicting_value_spread,
    candidate_dataset_values
FROM mart.vw_gdp_source_conflict_summary_latest
ORDER BY observation_year DESC, iso_alpha_3, indicator_code
LIMIT 10;

SELECT
    iso_alpha_3,
    country_name,
    indicator_code,
    observation_year,
    observation_value,
    trade_exports_curr_usd,
    trade_imports_curr_usd,
    trade_balance_curr_usd,
    trade_balance_direction,
    dataset_code
FROM mart.mart_country_trade_external_panel_annual
ORDER BY observation_year DESC, iso_alpha_3, indicator_code
LIMIT 10;

SELECT
    iso_alpha_3,
    country_name,
    indicator_code,
    observation_year,
    change_type,
    previous_dataset_code,
    new_dataset_code,
    previous_value,
    new_value,
    changed_at
FROM mart.vw_trade_external_revision_history
ORDER BY changed_at DESC, iso_alpha_3, indicator_code, observation_year
LIMIT 10;

SELECT
    iso_alpha_3,
    country_name,
    gdp_curr_usd_year,
    gdp_curr_usd,
    inflation_cpi_pct_year,
    inflation_cpi_pct,
    employment_rate_pct_year,
    employment_rate_pct,
    unemployment_rate_pct_year,
    unemployment_rate_pct,
    trade_exports_curr_usd_year,
    trade_exports_curr_usd,
    trade_imports_curr_usd_year,
    trade_imports_curr_usd,
    trade_balance_curr_usd,
    trade_balance_direction
FROM mart.mart_country_macro_plus_external_latest
ORDER BY iso_alpha_3
LIMIT 10;
\endif
