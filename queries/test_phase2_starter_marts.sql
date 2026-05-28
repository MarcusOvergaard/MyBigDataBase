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
    phase2_readiness_summary_row_count INT;
    phase2_readiness_invalid_gap_count INT;
    phase2_readiness_invalid_missing_indicator_count INT;
    phase2_readiness_invalid_trade_pair_count INT;
    phase2_readiness_invalid_external_pair_count INT;
    phase2_readiness_invalid_labor_coverage_count INT;
    phase2_readiness_invalid_macro_trade_external_coverage_count INT;
    phase2_readiness_invalid_status_count INT;
    phase2_issues_row_count INT;
    phase2_issues_expected_row_count INT;
    phase2_issues_invalid_complete_count INT;
    phase2_issues_invalid_flag_count INT;
    phase2_issues_invalid_severity_count INT;
    phase2_issues_invalid_severity_logic_count INT;
    phase2_dataset_trend_row_count INT;
    phase2_dataset_trend_latest_row_count INT;
    phase2_dataset_trend_expected_latest_row_count INT;
    phase2_dataset_trend_invalid_gap_count INT;
    phase2_dataset_trend_invalid_ratio_count INT;
    phase2_dataset_trend_invalid_latest_flag_count INT;
    phase2_dataset_trend_invalid_status_count INT;
    phase2_dependency_row_count INT;
    phase2_dependency_expected_row_count INT;
    phase2_dependency_duplicate_row_count INT;
    phase2_dependency_missing_expected_dataset_count INT;
    phase2_dependency_missing_selected_dataset_count INT;
    phase2_dependency_issue_alignment_count INT;
    phase2_dependency_invalid_status_count INT;
    phase2_dependency_invalid_fallback_count INT;
    phase2_dependency_china_lfpr_mismatch_count INT;
    phase2_ingestion_gap_row_count INT;
    phase2_ingestion_gap_expected_row_count INT;
    phase2_ingestion_gap_duplicate_row_count INT;
    phase2_ingestion_gap_invalid_stage_count INT;
    phase2_ingestion_gap_invalid_status_count INT;
    phase2_ingestion_gap_invalid_count_arithmetic_count INT;
    phase2_ingestion_gap_unexpected_published_count INT;
    phase2_ingestion_gap_china_lfpr_mismatch_count INT;
    phase2_dataset_ingestion_rollup_row_count INT;
    phase2_dataset_ingestion_rollup_expected_row_count INT;
    phase2_dataset_ingestion_rollup_duplicate_row_count INT;
    phase2_dataset_ingestion_rollup_invalid_stage_count INT;
    phase2_dataset_ingestion_rollup_invalid_status_count INT;
    phase2_dataset_ingestion_rollup_invalid_stage_arithmetic_count INT;
    phase2_dataset_ingestion_rollup_invalid_status_arithmetic_count INT;
    phase2_dataset_ingestion_rollup_china_lfpr_mismatch_count INT;
    phase2_dataset_operator_panel_row_count INT;
    phase2_dataset_operator_panel_expected_row_count INT;
    phase2_dataset_operator_panel_duplicate_row_count INT;
    phase2_dataset_operator_panel_invalid_arithmetic_count INT;
    phase2_dataset_operator_panel_invalid_status_count INT;
    phase2_dataset_operator_panel_invalid_operator_logic_count INT;
    phase2_dataset_operator_panel_ilostat_mismatch_count INT;
    phase2_dataset_operator_panel_scan_row_count INT;
    phase2_dataset_operator_panel_scan_invalid_rank_count INT;
    phase2_dataset_operator_panel_scan_invalid_ratio_count INT;
    phase2_dataset_operator_panel_scan_ratio_mismatch_count INT;
    phase2_dataset_status_history_row_count INT;
    phase2_dataset_status_history_expected_row_count INT;
    phase2_dataset_status_history_latest_row_count INT;
    phase2_dataset_status_history_duplicate_row_count INT;
    phase2_dataset_status_history_invalid_status_count INT;
    phase2_dataset_status_history_invalid_latest_rank_count INT;
    phase2_dataset_status_history_scan_row_count INT;
    phase2_dataset_status_history_scan_invalid_rank_count INT;
    phase2_dataset_status_history_scan_invalid_ratio_count INT;
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
    INTO phase2_readiness_summary_row_count
    FROM mart.mart_country_phase2_readiness_summary;

    IF phase2_readiness_summary_row_count <> latest_row_count THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_country_phase2_readiness_summary row count % did not match mart_country_phase2_latest row count %', phase2_readiness_summary_row_count, latest_row_count;
    END IF;

    SELECT COUNT(*)
    INTO phase2_readiness_invalid_gap_count
    FROM mart.mart_country_phase2_readiness_summary
    WHERE phase2_indicator_gap_count <> 8 - phase2_indicator_coverage_count
       OR phase2_indicator_gap_count < 0
       OR phase2_indicator_gap_count > 8;

    IF phase2_readiness_invalid_gap_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_country_phase2_readiness_summary has % row(s) with invalid gap counts', phase2_readiness_invalid_gap_count;
    END IF;

    SELECT COUNT(*)
    INTO phase2_readiness_invalid_missing_indicator_count
    FROM mart.mart_country_phase2_readiness_summary
    WHERE COALESCE(cardinality(missing_indicator_codes), 0) <> phase2_indicator_gap_count;

    IF phase2_readiness_invalid_missing_indicator_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_country_phase2_readiness_summary has % row(s) where missing_indicator_codes does not match phase2_indicator_gap_count', phase2_readiness_invalid_missing_indicator_count;
    END IF;

    SELECT COUNT(*)
    INTO phase2_readiness_invalid_trade_pair_count
    FROM mart.mart_country_phase2_readiness_summary rs
    JOIN mart.mart_country_phase2_latest l USING (country_key)
    WHERE rs.has_trade_pair <> (l.trade_exports_curr_usd_year IS NOT NULL AND l.trade_imports_curr_usd_year IS NOT NULL);

    IF phase2_readiness_invalid_trade_pair_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_country_phase2_readiness_summary has % row(s) with incorrect has_trade_pair flags', phase2_readiness_invalid_trade_pair_count;
    END IF;

    SELECT COUNT(*)
    INTO phase2_readiness_invalid_external_pair_count
    FROM mart.mart_country_phase2_readiness_summary rs
    JOIN mart.mart_country_phase2_latest l USING (country_key)
    WHERE rs.has_external_balance_pair <> (l.current_account_balance_curr_usd_year IS NOT NULL AND l.current_account_balance_pct_gdp_year IS NOT NULL);

    IF phase2_readiness_invalid_external_pair_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_country_phase2_readiness_summary has % row(s) with incorrect has_external_balance_pair flags', phase2_readiness_invalid_external_pair_count;
    END IF;

    SELECT COUNT(*)
    INTO phase2_readiness_invalid_labor_coverage_count
    FROM mart.mart_country_phase2_readiness_summary rs
    JOIN mart.mart_country_phase2_latest l USING (country_key)
    WHERE rs.labor_indicator_coverage_count <>
        (
            CASE WHEN l.employment_rate_pct_year IS NOT NULL THEN 1 ELSE 0 END
          + CASE WHEN l.labor_force_participation_rate_pct_year IS NOT NULL THEN 1 ELSE 0 END
          + CASE WHEN l.unemployment_rate_pct_year IS NOT NULL THEN 1 ELSE 0 END
        );

    IF phase2_readiness_invalid_labor_coverage_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_country_phase2_readiness_summary has % row(s) with incorrect labor_indicator_coverage_count', phase2_readiness_invalid_labor_coverage_count;
    END IF;

    SELECT COUNT(*)
    INTO phase2_readiness_invalid_macro_trade_external_coverage_count
    FROM mart.mart_country_phase2_readiness_summary rs
    JOIN mart.mart_country_phase2_latest l USING (country_key)
    WHERE rs.macro_trade_external_indicator_coverage_count <>
        (
            CASE WHEN l.inflation_cpi_pct_year IS NOT NULL THEN 1 ELSE 0 END
          + CASE WHEN l.trade_exports_curr_usd_year IS NOT NULL THEN 1 ELSE 0 END
          + CASE WHEN l.trade_imports_curr_usd_year IS NOT NULL THEN 1 ELSE 0 END
          + CASE WHEN l.current_account_balance_curr_usd_year IS NOT NULL THEN 1 ELSE 0 END
          + CASE WHEN l.current_account_balance_pct_gdp_year IS NOT NULL THEN 1 ELSE 0 END
        );

    IF phase2_readiness_invalid_macro_trade_external_coverage_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_country_phase2_readiness_summary has % row(s) with incorrect macro_trade_external_indicator_coverage_count', phase2_readiness_invalid_macro_trade_external_coverage_count;
    END IF;

    SELECT COUNT(*)
    INTO phase2_readiness_invalid_status_count
    FROM mart.mart_country_phase2_readiness_summary
    WHERE phase2_coverage_status <>
        CASE
            WHEN phase2_indicator_coverage_count = 8 THEN 'complete'
            WHEN phase2_indicator_coverage_count >= 6 THEN 'mostly_complete'
            WHEN phase2_indicator_coverage_count >= 1 THEN 'partial'
            ELSE 'empty'
        END;

    IF phase2_readiness_invalid_status_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_country_phase2_readiness_summary has % row(s) with incorrect phase2_coverage_status values', phase2_readiness_invalid_status_count;
    END IF;

    SELECT COUNT(*)
    INTO phase2_issues_row_count
    FROM mart.mart_country_phase2_issues;

    SELECT COUNT(*)
    INTO phase2_issues_expected_row_count
    FROM mart.mart_country_phase2_readiness_summary
    WHERE phase2_coverage_status <> 'complete'
       OR latest_phase2_observation_year IS NULL
       OR latest_phase2_observation_year < 2022
       OR NOT has_trade_pair
       OR NOT has_external_balance_pair;

    IF phase2_issues_row_count <> phase2_issues_expected_row_count THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_country_phase2_issues row count % did not match expected issue row count %', phase2_issues_row_count, phase2_issues_expected_row_count;
    END IF;

    SELECT COUNT(*)
    INTO phase2_issues_invalid_complete_count
    FROM mart.mart_country_phase2_issues
    WHERE phase2_coverage_status = 'complete'
      AND has_trade_pair
      AND has_external_balance_pair;

    IF phase2_issues_invalid_complete_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_country_phase2_issues contains % fully complete row(s)', phase2_issues_invalid_complete_count;
    END IF;

    SELECT COUNT(*)
    INTO phase2_issues_invalid_flag_count
    FROM mart.mart_country_phase2_issues
    WHERE COALESCE(cardinality(issue_flags), 0) = 0;

    IF phase2_issues_invalid_flag_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_country_phase2_issues has % row(s) without issue_flags', phase2_issues_invalid_flag_count;
    END IF;

    SELECT COUNT(*)
    INTO phase2_issues_invalid_severity_count
    FROM mart.mart_country_phase2_issues
    WHERE issue_severity NOT IN ('low', 'medium', 'high');

    IF phase2_issues_invalid_severity_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_country_phase2_issues has % row(s) with invalid issue_severity values', phase2_issues_invalid_severity_count;
    END IF;

    SELECT COUNT(*)
    INTO phase2_issues_invalid_severity_logic_count
    FROM mart.mart_country_phase2_issues
    WHERE issue_severity <>
        CASE
            WHEN phase2_indicator_gap_count >= 3 THEN 'high'
            WHEN phase2_indicator_gap_count >= 1 THEN 'medium'
            WHEN NOT has_trade_pair OR NOT has_external_balance_pair THEN 'medium'
            ELSE 'low'
        END;

    IF phase2_issues_invalid_severity_logic_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_country_phase2_issues has % row(s) with inconsistent issue_severity logic', phase2_issues_invalid_severity_logic_count;
    END IF;

    SELECT COUNT(*)
    INTO phase2_dataset_trend_row_count
    FROM mart.mart_phase2_dataset_coverage_trend;

    IF phase2_dataset_trend_row_count = 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_phase2_dataset_coverage_trend returned no rows';
    END IF;

    SELECT COUNT(*)
    INTO phase2_dataset_trend_latest_row_count
    FROM mart.mart_phase2_dataset_coverage_trend
    WHERE is_latest_observation_year;

    SELECT COUNT(*)
    INTO phase2_dataset_trend_expected_latest_row_count
    FROM (
        SELECT DISTINCT source_dataset_key, indicator_code
        FROM mart.mart_phase2_dataset_coverage_trend
    ) latest_keys;

    IF phase2_dataset_trend_latest_row_count <> phase2_dataset_trend_expected_latest_row_count THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_phase2_dataset_coverage_trend latest-row count % did not match distinct dataset/indicator count %', phase2_dataset_trend_latest_row_count, phase2_dataset_trend_expected_latest_row_count;
    END IF;

    SELECT COUNT(*)
    INTO phase2_dataset_trend_invalid_gap_count
    FROM mart.mart_phase2_dataset_coverage_trend
    WHERE missing_country_count <> expected_country_count - covered_country_count
       OR COALESCE(cardinality(missing_country_iso_alpha_3_codes), 0) <> missing_country_count;

    IF phase2_dataset_trend_invalid_gap_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_phase2_dataset_coverage_trend has % row(s) with inconsistent missing-country arithmetic', phase2_dataset_trend_invalid_gap_count;
    END IF;

    SELECT COUNT(*)
    INTO phase2_dataset_trend_invalid_ratio_count
    FROM mart.mart_phase2_dataset_coverage_trend
    WHERE coverage_ratio < 0
       OR coverage_ratio > 1
       OR (prior_year_coverage_ratio IS NOT NULL AND (prior_year_coverage_ratio < 0 OR prior_year_coverage_ratio > 1));

    IF phase2_dataset_trend_invalid_ratio_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_phase2_dataset_coverage_trend has % row(s) with out-of-range coverage ratios', phase2_dataset_trend_invalid_ratio_count;
    END IF;

    SELECT COUNT(*)
    INTO phase2_dataset_trend_invalid_latest_flag_count
    FROM mart.mart_phase2_dataset_coverage_trend
    WHERE is_latest_observation_year <> (observation_year = latest_observation_year_for_indicator)
       OR observation_year_lag_from_latest <> latest_observation_year_for_indicator - observation_year;

    IF phase2_dataset_trend_invalid_latest_flag_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_phase2_dataset_coverage_trend has % row(s) with inconsistent latest-year flags', phase2_dataset_trend_invalid_latest_flag_count;
    END IF;

    SELECT COUNT(*)
    INTO phase2_dataset_trend_invalid_status_count
    FROM mart.mart_phase2_dataset_coverage_trend
    WHERE coverage_status <>
        CASE
            WHEN covered_country_count = expected_country_count THEN 'complete'
            WHEN covered_country_count >= expected_country_count - 1 THEN 'country_specific_gap'
            WHEN coverage_ratio >= 0.8000 THEN 'broad_but_patchy'
            ELSE 'source_wide_gap'
        END;

    IF phase2_dataset_trend_invalid_status_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_phase2_dataset_coverage_trend has % row(s) with inconsistent coverage_status values', phase2_dataset_trend_invalid_status_count;
    END IF;

    SELECT COUNT(*)
    INTO phase2_dependency_row_count
    FROM mart.mart_country_phase2_dependency_explainer;

    SELECT COUNT(*)
    INTO phase2_dependency_expected_row_count
    FROM mart.mart_country_phase2_readiness_summary rs
    CROSS JOIN (
        SELECT indicator_code
        FROM core.dim_indicator
        WHERE indicator_code IN (
            'EMPLOYMENT_RATE_PCT',
            'LABOR_FORCE_PARTICIPATION_RATE_PCT',
            'UNEMPLOYMENT_RATE_PCT',
            'INFLATION_CPI_PCT',
            'TRADE_EXPORTS_CURR_USD',
            'TRADE_IMPORTS_CURR_USD',
            'CURRENT_ACCOUNT_BALANCE_CURR_USD',
            'CURRENT_ACCOUNT_BALANCE_PCT_GDP'
        )
    ) indicators;

    IF phase2_dependency_row_count <> phase2_dependency_expected_row_count THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_country_phase2_dependency_explainer row count % did not match expected country-indicator grid %', phase2_dependency_row_count, phase2_dependency_expected_row_count;
    END IF;

    SELECT COUNT(*)
    INTO phase2_dependency_duplicate_row_count
    FROM (
        SELECT country_key, indicator_key, COUNT(*) AS row_count
        FROM mart.mart_country_phase2_dependency_explainer
        GROUP BY country_key, indicator_key
        HAVING COUNT(*) <> 1
    ) duplicate_rows;

    IF phase2_dependency_duplicate_row_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_country_phase2_dependency_explainer has % duplicated country-indicator key(s)', phase2_dependency_duplicate_row_count;
    END IF;

    SELECT COUNT(*)
    INTO phase2_dependency_missing_expected_dataset_count
    FROM mart.mart_country_phase2_dependency_explainer
    WHERE expected_dataset_code IS NULL
       OR expected_source_code IS NULL
       OR expected_priority_rank IS NULL;

    IF phase2_dependency_missing_expected_dataset_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_country_phase2_dependency_explainer has % row(s) missing expected-dataset lineage', phase2_dependency_missing_expected_dataset_count;
    END IF;

    SELECT COUNT(*)
    INTO phase2_dependency_missing_selected_dataset_count
    FROM mart.mart_country_phase2_dependency_explainer
    WHERE is_indicator_present
      AND (selected_dataset_code IS NULL OR selected_source_code IS NULL OR selected_observation_year IS NULL);

    IF phase2_dependency_missing_selected_dataset_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_country_phase2_dependency_explainer has % present-indicator row(s) missing selected-dataset lineage', phase2_dependency_missing_selected_dataset_count;
    END IF;

    SELECT COUNT(*)
    INTO phase2_dependency_issue_alignment_count
    FROM mart.mart_country_phase2_dependency_explainer de
    JOIN mart.mart_country_phase2_readiness_summary rs
      ON rs.country_key = de.country_key
    WHERE (de.selected_observation_year IS NULL) <>
          (de.indicator_code = ANY(COALESCE(rs.missing_indicator_codes, ARRAY[]::text[])));

    IF phase2_dependency_issue_alignment_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_country_phase2_dependency_explainer has % row(s) out of sync with readiness missing_indicator_codes', phase2_dependency_issue_alignment_count;
    END IF;

    SELECT COUNT(*)
    INTO phase2_dependency_invalid_status_count
    FROM mart.mart_country_phase2_dependency_explainer
    WHERE dependency_status NOT IN (
        'covered_by_expected_dataset',
        'covered_by_fallback_dataset',
        'missing_despite_complete_expected_dataset',
        'missing_country_from_expected_dataset',
        'missing_from_patchy_expected_dataset',
        'missing_with_country_fallback_history',
        'missing_without_country_fallback_history',
        'missing_without_configured_fallback'
    );

    IF phase2_dependency_invalid_status_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_country_phase2_dependency_explainer has % row(s) with invalid dependency_status values', phase2_dependency_invalid_status_count;
    END IF;

    SELECT COUNT(*)
    INTO phase2_dependency_invalid_fallback_count
    FROM mart.mart_country_phase2_dependency_explainer
    WHERE configured_fallback_dataset_count <> COALESCE(cardinality(configured_fallback_dataset_codes), 0)
       OR available_fallback_dataset_count_for_country <> COALESCE(cardinality(available_fallback_dataset_codes_for_country), 0);

    IF phase2_dependency_invalid_fallback_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_country_phase2_dependency_explainer has % row(s) with inconsistent fallback counts', phase2_dependency_invalid_fallback_count;
    END IF;

    SELECT COUNT(*)
    INTO phase2_dependency_china_lfpr_mismatch_count
    FROM mart.mart_country_phase2_dependency_explainer
    WHERE iso_alpha_3 = 'CHN'
      AND indicator_code = 'LABOR_FORCE_PARTICIPATION_RATE_PCT'
      AND NOT (
            expected_dataset_code = 'ILOSTAT'
        AND 'WDI' = ANY(configured_fallback_dataset_codes)
        AND 'WDI' = ANY(available_fallback_dataset_codes_for_country)
        AND selected_dataset_code = 'WDI'
        AND dependency_status = 'covered_by_fallback_dataset'
      );

    IF phase2_dependency_china_lfpr_mismatch_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_country_phase2_dependency_explainer lost the CHN labor-force-participation fallback proof';
    END IF;

    SELECT COUNT(*)
    INTO phase2_ingestion_gap_row_count
    FROM mart.mart_country_phase2_ingestion_gap_explainer;

    SELECT COUNT(*)
    INTO phase2_ingestion_gap_expected_row_count
    FROM mart.mart_country_phase2_dependency_explainer
    WHERE NOT is_indicator_present;

    IF phase2_ingestion_gap_row_count <> phase2_ingestion_gap_expected_row_count THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_country_phase2_ingestion_gap_explainer row count % did not match the dependency-explainer missing-row count %', phase2_ingestion_gap_row_count, phase2_ingestion_gap_expected_row_count;
    END IF;

    SELECT COUNT(*)
    INTO phase2_ingestion_gap_duplicate_row_count
    FROM (
        SELECT country_key, indicator_key, COUNT(*) AS row_count
        FROM mart.mart_country_phase2_ingestion_gap_explainer
        GROUP BY country_key, indicator_key
        HAVING COUNT(*) <> 1
    ) duplicate_rows;

    IF phase2_ingestion_gap_duplicate_row_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_country_phase2_ingestion_gap_explainer has % duplicated country-indicator key(s)', phase2_ingestion_gap_duplicate_row_count;
    END IF;

    SELECT COUNT(*)
    INTO phase2_ingestion_gap_invalid_stage_count
    FROM mart.mart_country_phase2_ingestion_gap_explainer
    WHERE gap_stage NOT IN ('fetch_scope', 'normalization', 'qa_blocking', 'publication');

    IF phase2_ingestion_gap_invalid_stage_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_country_phase2_ingestion_gap_explainer has % row(s) with invalid gap_stage values', phase2_ingestion_gap_invalid_stage_count;
    END IF;

    SELECT COUNT(*)
    INTO phase2_ingestion_gap_invalid_status_count
    FROM mart.mart_country_phase2_ingestion_gap_explainer
    WHERE gap_status NOT IN (
        'no_expected_dataset_batch_history',
        'missing_snapshot_evidence_for_latest_batch',
        'country_not_present_in_latest_raw_landing',
        'indicator_not_present_for_country_in_latest_raw_landing',
        'raw_landed_but_not_normalized_to_staging',
        'blocked_by_publish_qa',
        'staged_but_not_versioned',
        'publish_run_not_successful',
        'versioned_but_not_visible_in_published_surface',
        'gap_resolved_elsewhere'
    );

    IF phase2_ingestion_gap_invalid_status_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_country_phase2_ingestion_gap_explainer has % row(s) with invalid gap_status values', phase2_ingestion_gap_invalid_status_count;
    END IF;

    SELECT COUNT(*)
    INTO phase2_ingestion_gap_invalid_count_arithmetic_count
    FROM mart.mart_country_phase2_ingestion_gap_explainer
    WHERE latest_expected_batch_country_indicator_raw_row_count > latest_expected_batch_country_raw_row_count
       OR latest_expected_batch_country_raw_row_count > latest_expected_batch_raw_row_count
       OR latest_expected_batch_country_indicator_staging_row_count > latest_expected_batch_country_staging_row_count
       OR latest_expected_batch_country_staging_row_count > latest_expected_batch_staging_row_count
       OR latest_expected_batch_country_indicator_version_row_count > latest_expected_batch_version_row_count
       OR latest_expected_batch_country_indicator_blocking_qa_event_count > latest_expected_batch_country_indicator_dq_event_count;

    IF phase2_ingestion_gap_invalid_count_arithmetic_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_country_phase2_ingestion_gap_explainer has % row(s) with inconsistent count arithmetic', phase2_ingestion_gap_invalid_count_arithmetic_count;
    END IF;

    SELECT COUNT(*)
    INTO phase2_ingestion_gap_unexpected_published_count
    FROM mart.mart_country_phase2_ingestion_gap_explainer
    WHERE current_expected_dataset_country_indicator_published_row_count <> 0;

    IF phase2_ingestion_gap_unexpected_published_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_country_phase2_ingestion_gap_explainer has % row(s) that still show published expected-dataset rows despite being unresolved gaps', phase2_ingestion_gap_unexpected_published_count;
    END IF;

    SELECT COUNT(*)
    INTO phase2_ingestion_gap_china_lfpr_mismatch_count
    FROM mart.mart_country_phase2_ingestion_gap_explainer
    WHERE iso_alpha_3 = 'CHN'
      AND indicator_code = 'LABOR_FORCE_PARTICIPATION_RATE_PCT';

    IF phase2_ingestion_gap_china_lfpr_mismatch_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_country_phase2_ingestion_gap_explainer still shows the repaired CHN labor-force-participation gap';
    END IF;

    SELECT COUNT(*)
    INTO phase2_dataset_ingestion_rollup_row_count
    FROM mart.mart_phase2_dataset_ingestion_gap_rollup;

    SELECT COUNT(DISTINCT expected_source_dataset_key)
    INTO phase2_dataset_ingestion_rollup_expected_row_count
    FROM mart.mart_country_phase2_ingestion_gap_explainer;

    IF phase2_dataset_ingestion_rollup_row_count <> phase2_dataset_ingestion_rollup_expected_row_count THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_phase2_dataset_ingestion_gap_rollup row count % did not match distinct expected-dataset gap count %', phase2_dataset_ingestion_rollup_row_count, phase2_dataset_ingestion_rollup_expected_row_count;
    END IF;

    SELECT COUNT(*)
    INTO phase2_dataset_ingestion_rollup_duplicate_row_count
    FROM (
        SELECT expected_source_dataset_key, COUNT(*) AS row_count
        FROM mart.mart_phase2_dataset_ingestion_gap_rollup
        GROUP BY expected_source_dataset_key
        HAVING COUNT(*) <> 1
    ) duplicate_rows;

    IF phase2_dataset_ingestion_rollup_duplicate_row_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_phase2_dataset_ingestion_gap_rollup has % duplicated expected-dataset key(s)', phase2_dataset_ingestion_rollup_duplicate_row_count;
    END IF;

    SELECT COUNT(*)
    INTO phase2_dataset_ingestion_rollup_invalid_stage_count
    FROM mart.mart_phase2_dataset_ingestion_gap_rollup
    WHERE dominant_gap_stage NOT IN ('fetch_scope', 'normalization', 'qa_blocking', 'publication');

    IF phase2_dataset_ingestion_rollup_invalid_stage_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_phase2_dataset_ingestion_gap_rollup has % row(s) with invalid dominant_gap_stage values', phase2_dataset_ingestion_rollup_invalid_stage_count;
    END IF;

    SELECT COUNT(*)
    INTO phase2_dataset_ingestion_rollup_invalid_status_count
    FROM mart.mart_phase2_dataset_ingestion_gap_rollup
    WHERE dominant_gap_status NOT IN (
        'no_expected_dataset_batch_history',
        'missing_snapshot_evidence_for_latest_batch',
        'country_not_present_in_latest_raw_landing',
        'indicator_not_present_for_country_in_latest_raw_landing',
        'raw_landed_but_not_normalized_to_staging',
        'blocked_by_publish_qa',
        'staged_but_not_versioned',
        'publish_run_not_successful',
        'versioned_but_not_visible_in_published_surface',
        'gap_resolved_elsewhere'
    );

    IF phase2_dataset_ingestion_rollup_invalid_status_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_phase2_dataset_ingestion_gap_rollup has % row(s) with invalid dominant_gap_status values', phase2_dataset_ingestion_rollup_invalid_status_count;
    END IF;

    SELECT COUNT(*)
    INTO phase2_dataset_ingestion_rollup_invalid_stage_arithmetic_count
    FROM mart.mart_phase2_dataset_ingestion_gap_rollup
    WHERE missing_country_indicator_count < affected_country_count
       OR missing_country_indicator_count < affected_indicator_count
       OR missing_country_indicator_count < dominant_gap_stage_count
       OR fetch_scope_gap_count + normalization_gap_count + qa_blocking_gap_count + publication_gap_count <> missing_country_indicator_count;

    IF phase2_dataset_ingestion_rollup_invalid_stage_arithmetic_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_phase2_dataset_ingestion_gap_rollup has % row(s) with inconsistent stage arithmetic', phase2_dataset_ingestion_rollup_invalid_stage_arithmetic_count;
    END IF;

    SELECT COUNT(*)
    INTO phase2_dataset_ingestion_rollup_invalid_status_arithmetic_count
    FROM mart.mart_phase2_dataset_ingestion_gap_rollup
    WHERE missing_country_indicator_count < dominant_gap_status_count
       OR no_expected_dataset_batch_history_count
        + missing_snapshot_evidence_for_latest_batch_count
        + country_not_present_in_latest_raw_landing_count
        + indicator_not_present_for_country_in_latest_raw_landing_count
        + raw_landed_but_not_normalized_to_staging_count
        + blocked_by_publish_qa_count
        + staged_but_not_versioned_count
        + publish_run_not_successful_count
        + versioned_but_not_visible_in_published_surface_count
        + gap_resolved_elsewhere_count <> missing_country_indicator_count;

    IF phase2_dataset_ingestion_rollup_invalid_status_arithmetic_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_phase2_dataset_ingestion_gap_rollup has % row(s) with inconsistent status arithmetic', phase2_dataset_ingestion_rollup_invalid_status_arithmetic_count;
    END IF;

    SELECT COUNT(*)
    INTO phase2_dataset_ingestion_rollup_china_lfpr_mismatch_count
    FROM mart.mart_phase2_dataset_ingestion_gap_rollup
    WHERE expected_dataset_code = 'ILOSTAT';

    IF phase2_dataset_ingestion_rollup_china_lfpr_mismatch_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_phase2_dataset_ingestion_gap_rollup still shows unresolved ILOSTAT gaps after the CHN labor fallback repair';
    END IF;

    SELECT COUNT(*)
    INTO phase2_dataset_operator_panel_row_count
    FROM mart.mart_phase2_dataset_operator_panel;

    SELECT COUNT(*)
    INTO phase2_dataset_operator_panel_expected_row_count
    FROM mart.vw_domain_qa_summary_phase2;

    IF phase2_dataset_operator_panel_row_count <> phase2_dataset_operator_panel_expected_row_count THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_phase2_dataset_operator_panel row count % did not match vw_domain_qa_summary_phase2 row count %', phase2_dataset_operator_panel_row_count, phase2_dataset_operator_panel_expected_row_count;
    END IF;

    SELECT COUNT(*)
    INTO phase2_dataset_operator_panel_duplicate_row_count
    FROM (
        SELECT source_dataset_key, COUNT(*) AS row_count
        FROM mart.mart_phase2_dataset_operator_panel
        GROUP BY source_dataset_key
        HAVING COUNT(*) <> 1
    ) duplicate_rows;

    IF phase2_dataset_operator_panel_duplicate_row_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_phase2_dataset_operator_panel has % duplicated source_dataset_key row(s)', phase2_dataset_operator_panel_duplicate_row_count;
    END IF;

    SELECT COUNT(*)
    INTO phase2_dataset_operator_panel_invalid_arithmetic_count
    FROM mart.mart_phase2_dataset_operator_panel
    WHERE latest_indicator_count <> latest_complete_indicator_count + latest_gap_indicator_count
       OR latest_missing_country_sum <> latest_expected_country_sum - latest_covered_country_sum
       OR latest_indicator_count <> current_phase2_indicator_count
       OR has_latest_coverage_gap <> (latest_gap_indicator_count > 0)
       OR missing_country_indicator_count < affected_country_count
       OR missing_country_indicator_count < affected_indicator_count
       OR fetch_scope_gap_count + normalization_gap_count + qa_blocking_gap_count + publication_gap_count <> missing_country_indicator_count;

    IF phase2_dataset_operator_panel_invalid_arithmetic_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_phase2_dataset_operator_panel has % row(s) with inconsistent coverage/gap arithmetic', phase2_dataset_operator_panel_invalid_arithmetic_count;
    END IF;

    SELECT COUNT(*)
    INTO phase2_dataset_operator_panel_invalid_status_count
    FROM mart.mart_phase2_dataset_operator_panel
    WHERE operator_panel_status NOT IN ('healthy', 'warning_coverage_gap', 'failing_active_gap');

    IF phase2_dataset_operator_panel_invalid_status_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_phase2_dataset_operator_panel has % row(s) with invalid operator_panel_status values', phase2_dataset_operator_panel_invalid_status_count;
    END IF;

    SELECT COUNT(*)
    INTO phase2_dataset_operator_panel_invalid_operator_logic_count
    FROM mart.mart_phase2_dataset_operator_panel
    WHERE operator_panel_status <>
        CASE
            WHEN missing_country_indicator_count > 0 THEN 'failing_active_gap'
            WHEN latest_gap_indicator_count > 0 THEN 'warning_coverage_gap'
            ELSE 'healthy'
        END;

    IF phase2_dataset_operator_panel_invalid_operator_logic_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_phase2_dataset_operator_panel has % row(s) with inconsistent operator-panel status logic', phase2_dataset_operator_panel_invalid_operator_logic_count;
    END IF;

    SELECT COUNT(*)
    INTO phase2_dataset_operator_panel_ilostat_mismatch_count
    FROM mart.mart_phase2_dataset_operator_panel
    WHERE dataset_code = 'ILOSTAT'
      AND NOT (
            current_phase2_indicator_count = 3
        AND latest_indicator_count = 3
        AND latest_complete_indicator_count = 0
        AND latest_gap_indicator_count = 3
        AND missing_country_indicator_count = 0
        AND affected_country_count = 0
        AND affected_indicator_count = 0
        AND COALESCE(cardinality(affected_country_iso_alpha_3_codes), 0) = 0
        AND COALESCE(cardinality(affected_indicator_codes), 0) = 0
        AND fetch_scope_gap_count = 0
        AND normalization_gap_count = 0
        AND qa_blocking_gap_count = 0
        AND publication_gap_count = 0
        AND dominant_gap_stage IS NULL
        AND dominant_gap_status IS NULL
        AND operator_panel_status = 'warning_coverage_gap'
        AND latest_gap_indicator_codes::text[] = ARRAY[
            'EMPLOYMENT_RATE_PCT',
            'LABOR_FORCE_PARTICIPATION_RATE_PCT',
            'UNEMPLOYMENT_RATE_PCT'
        ]::text[]
      );

    IF phase2_dataset_operator_panel_ilostat_mismatch_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_phase2_dataset_operator_panel lost the repaired ILOSTAT warning-only proof';
    END IF;

    SELECT COUNT(*)
    INTO phase2_dataset_operator_panel_scan_row_count
    FROM mart.vw_phase2_dataset_operator_panel_scan;

    IF phase2_dataset_operator_panel_scan_row_count <> phase2_dataset_operator_panel_row_count THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: vw_phase2_dataset_operator_panel_scan row count % did not match mart_phase2_dataset_operator_panel row count %', phase2_dataset_operator_panel_scan_row_count, phase2_dataset_operator_panel_row_count;
    END IF;

    SELECT COUNT(*)
    INTO phase2_dataset_operator_panel_scan_invalid_rank_count
    FROM mart.vw_phase2_dataset_operator_panel_scan
    WHERE operator_attention_rank <> CASE operator_panel_status
        WHEN 'failing_active_gap' THEN 1
        WHEN 'warning_coverage_gap' THEN 2
        ELSE 3
    END;

    IF phase2_dataset_operator_panel_scan_invalid_rank_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: vw_phase2_dataset_operator_panel_scan has % row(s) with inconsistent operator_attention_rank', phase2_dataset_operator_panel_scan_invalid_rank_count;
    END IF;

    SELECT COUNT(*)
    INTO phase2_dataset_operator_panel_scan_invalid_ratio_count
    FROM mart.vw_phase2_dataset_operator_panel_scan
    WHERE latest_indicator_coverage_ratio IS NULL
       OR latest_indicator_coverage_ratio < 0
       OR latest_indicator_coverage_ratio > 1
       OR latest_country_coverage_ratio IS NULL
       OR latest_country_coverage_ratio < 0
       OR latest_country_coverage_ratio > 1;

    IF phase2_dataset_operator_panel_scan_invalid_ratio_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: vw_phase2_dataset_operator_panel_scan has % row(s) with invalid compact coverage ratios', phase2_dataset_operator_panel_scan_invalid_ratio_count;
    END IF;

    SELECT COUNT(*)
    INTO phase2_dataset_operator_panel_scan_ratio_mismatch_count
    FROM mart.vw_phase2_dataset_operator_panel_scan
    WHERE latest_indicator_coverage_ratio <> ROUND(
            (latest_complete_indicator_count + latest_gap_indicator_count)::numeric
            / NULLIF(required_phase2_indicator_count, 0),
            4
        )
       OR latest_country_coverage_ratio <> ROUND(
            (latest_expected_country_sum - latest_missing_country_sum)::numeric
            / NULLIF(latest_expected_country_sum, 0),
            4
        );

    IF phase2_dataset_operator_panel_scan_ratio_mismatch_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: vw_phase2_dataset_operator_panel_scan has % row(s) whose compact ratios do not match parent coverage arithmetic', phase2_dataset_operator_panel_scan_ratio_mismatch_count;
    END IF;

    SELECT COUNT(*)
    INTO phase2_dataset_status_history_row_count
    FROM mart.mart_phase2_dataset_status_history;

    SELECT COUNT(*)
    INTO phase2_dataset_status_history_expected_row_count
    FROM raw.source_batch sb
    JOIN ref.source_dataset sd ON sd.source_dataset_key = sb.source_dataset_key
    WHERE sd.dataset_code IN ('IFS', 'WEO', 'ILOSTAT', 'UN_COMTRADE_ANNUAL');

    IF phase2_dataset_status_history_row_count <> phase2_dataset_status_history_expected_row_count THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_phase2_dataset_status_history row count % did not match expected Phase 2 source-batch count %', phase2_dataset_status_history_row_count, phase2_dataset_status_history_expected_row_count;
    END IF;

    SELECT COUNT(*)
    INTO phase2_dataset_status_history_latest_row_count
    FROM mart.mart_phase2_dataset_status_history
    WHERE is_latest_batch_for_dataset;

    IF phase2_dataset_status_history_latest_row_count <> 4 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_phase2_dataset_status_history expected 4 latest dataset rows, found %', phase2_dataset_status_history_latest_row_count;
    END IF;

    SELECT COUNT(*)
    INTO phase2_dataset_status_history_duplicate_row_count
    FROM (
        SELECT source_dataset_key, source_batch_key, COUNT(*) AS row_count
        FROM mart.mart_phase2_dataset_status_history
        GROUP BY source_dataset_key, source_batch_key
        HAVING COUNT(*) <> 1
    ) duplicate_rows;

    IF phase2_dataset_status_history_duplicate_row_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_phase2_dataset_status_history has % duplicated dataset-batch key(s)', phase2_dataset_status_history_duplicate_row_count;
    END IF;

    SELECT COUNT(*)
    INTO phase2_dataset_status_history_invalid_status_count
    FROM mart.mart_phase2_dataset_status_history
    WHERE batch_status NOT IN (
        'not_published',
        'publish_failed',
        'no_phase2_output',
        'partial_indicator_coverage',
        'partial_country_coverage',
        'phase2_output_present'
    );

    IF phase2_dataset_status_history_invalid_status_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_phase2_dataset_status_history has % row(s) with invalid batch_status values', phase2_dataset_status_history_invalid_status_count;
    END IF;

    SELECT COUNT(*)
    INTO phase2_dataset_status_history_invalid_latest_rank_count
    FROM mart.mart_phase2_dataset_status_history
    WHERE is_latest_batch_for_dataset <> (batch_recency_rank = 1)
       OR batch_recency_rank < 1;

    IF phase2_dataset_status_history_invalid_latest_rank_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: mart_phase2_dataset_status_history has % row(s) with inconsistent latest-batch ranking flags', phase2_dataset_status_history_invalid_latest_rank_count;
    END IF;

    SELECT COUNT(*)
    INTO phase2_dataset_status_history_scan_row_count
    FROM mart.vw_phase2_dataset_status_history_scan;

    IF phase2_dataset_status_history_scan_row_count <> phase2_dataset_status_history_row_count THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: vw_phase2_dataset_status_history_scan row count % did not match mart_phase2_dataset_status_history row count %', phase2_dataset_status_history_scan_row_count, phase2_dataset_status_history_row_count;
    END IF;

    SELECT COUNT(*)
    INTO phase2_dataset_status_history_scan_invalid_rank_count
    FROM mart.vw_phase2_dataset_status_history_scan
    WHERE batch_status_rank <> CASE batch_status
        WHEN 'publish_failed' THEN 1
        WHEN 'not_published' THEN 2
        WHEN 'no_phase2_output' THEN 3
        WHEN 'partial_indicator_coverage' THEN 4
        WHEN 'partial_country_coverage' THEN 5
        ELSE 6
    END;

    IF phase2_dataset_status_history_scan_invalid_rank_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: vw_phase2_dataset_status_history_scan has % row(s) with inconsistent batch_status_rank', phase2_dataset_status_history_scan_invalid_rank_count;
    END IF;

    SELECT COUNT(*)
    INTO phase2_dataset_status_history_scan_invalid_ratio_count
    FROM mart.vw_phase2_dataset_status_history_scan
    WHERE indicator_coverage_ratio IS NULL
       OR indicator_coverage_ratio < 0
       OR indicator_coverage_ratio > 1
       OR country_indicator_pair_coverage_ratio IS NULL
       OR country_indicator_pair_coverage_ratio < 0
       OR country_indicator_pair_coverage_ratio > 1;

    IF phase2_dataset_status_history_scan_invalid_ratio_count <> 0 THEN
        RAISE EXCEPTION 'Phase 2 mart test failed: vw_phase2_dataset_status_history_scan has % row(s) with invalid compact coverage ratios', phase2_dataset_status_history_scan_invalid_ratio_count;
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
    dataset_code,
    indicator_code,
    observation_year,
    covered_country_count,
    expected_country_count,
    coverage_ratio,
    coverage_status,
    missing_country_iso_alpha_3_codes,
    freshness_status,
    is_stale
FROM mart.mart_phase2_dataset_coverage_trend
WHERE is_latest_observation_year
ORDER BY coverage_ratio ASC, dataset_code, indicator_code
LIMIT 12;

SELECT
    iso_alpha_3,
    indicator_code,
    expected_dataset_code,
    selected_dataset_code,
    dependency_status,
    expected_dataset_coverage_status,
    configured_fallback_dataset_codes,
    available_fallback_dataset_codes_for_country,
    selected_observation_year,
    diagnosis_year
FROM mart.mart_country_phase2_dependency_explainer
WHERE NOT is_indicator_present
ORDER BY iso_alpha_3, indicator_code
LIMIT 12;

SELECT
    iso_alpha_3,
    indicator_code,
    expected_dataset_code,
    latest_expected_batch_external_id,
    latest_expected_manifest_path,
    latest_expected_batch_country_indicator_raw_row_count,
    latest_expected_batch_country_indicator_staging_row_count,
    latest_expected_batch_country_indicator_blocking_qa_event_count,
    gap_stage,
    gap_status
FROM mart.mart_country_phase2_ingestion_gap_explainer
ORDER BY iso_alpha_3, indicator_code
LIMIT 12;

SELECT
    expected_dataset_code,
    missing_country_indicator_count,
    affected_country_count,
    affected_indicator_count,
    dominant_gap_stage,
    dominant_gap_status,
    fetch_scope_gap_count,
    normalization_gap_count,
    qa_blocking_gap_count,
    publication_gap_count,
    affected_country_iso_alpha_3_codes,
    affected_indicator_codes
FROM mart.mart_phase2_dataset_ingestion_gap_rollup
ORDER BY missing_country_indicator_count DESC, expected_dataset_code
LIMIT 12;

SELECT
    dataset_code,
    operator_panel_status,
    freshness_status,
    latest_publish_status,
    current_phase2_indicator_count,
    latest_gap_indicator_count,
    missing_country_indicator_count,
    dominant_gap_stage,
    dominant_gap_status,
    latest_gap_indicator_codes,
    affected_country_iso_alpha_3_codes,
    affected_indicator_codes
FROM mart.mart_phase2_dataset_operator_panel
ORDER BY
    CASE operator_panel_status
        WHEN 'failing_active_gap' THEN 0
        WHEN 'warning_coverage_gap' THEN 1
        ELSE 2
    END,
    dataset_code
LIMIT 12;

SELECT
    dataset_code,
    source_batch_key,
    batch_external_id,
    batch_status,
    pair_coverage_trend_vs_prior_batch,
    phase2_indicator_count,
    expected_phase2_indicator_count,
    phase2_country_indicator_pair_count,
    expected_phase2_country_indicator_pair_count,
    phase2_country_indicator_pair_count_change_vs_prior_batch,
    publish_status,
    published_at,
    is_latest_batch_for_dataset
FROM mart.mart_phase2_dataset_status_history
ORDER BY dataset_code, batch_recency_rank
LIMIT 16;

SELECT
    iso_alpha_3,
    country_name,
    phase2_indicator_coverage_count,
    phase2_indicator_gap_count,
    phase2_coverage_status,
    has_trade_pair,
    has_external_balance_pair,
    issue_severity,
    issue_flags,
    missing_indicator_codes,
    latest_phase2_observation_year,
    latest_published_at
FROM mart.mart_country_phase2_issues
ORDER BY phase2_indicator_gap_count DESC, latest_phase2_observation_year NULLS FIRST, iso_alpha_3
LIMIT 10;

\if :{?PHASE2_VERBOSE}
\else
\set PHASE2_VERBOSE 0
\endif
\if :PHASE2_VERBOSE
SELECT
    dataset_code,
    indicator_code,
    observation_year,
    latest_observation_year_for_indicator,
    is_latest_observation_year,
    covered_country_count,
    expected_country_count,
    missing_country_count,
    coverage_ratio,
    prior_year_coverage_ratio,
    coverage_ratio_change_vs_prior_year,
    coverage_status,
    missing_country_iso_alpha_3_codes,
    freshness_status,
    is_stale
FROM mart.mart_phase2_dataset_coverage_trend
ORDER BY dataset_code, indicator_code, observation_year DESC
LIMIT 20;

SELECT
    iso_alpha_3,
    indicator_code,
    expected_dataset_code,
    expected_priority_rank,
    expected_is_override,
    selected_dataset_code,
    selected_observation_year,
    selected_selection_method,
    expected_dataset_coverage_status,
    is_country_missing_from_expected_dataset_latest_year,
    configured_fallback_dataset_codes,
    available_fallback_dataset_codes_for_country,
    dependency_status
FROM mart.mart_country_phase2_dependency_explainer
ORDER BY iso_alpha_3, indicator_code
LIMIT 24;

SELECT
    iso_alpha_3,
    indicator_code,
    expected_dataset_code,
    latest_expected_batch_external_id,
    latest_expected_batch_loader,
    latest_expected_manifest_path,
    latest_expected_snapshot_count,
    latest_expected_batch_raw_row_count,
    latest_expected_batch_country_raw_row_count,
    latest_expected_batch_country_indicator_raw_row_count,
    latest_expected_batch_country_indicator_staging_row_count,
    latest_expected_batch_country_indicator_version_row_count,
    latest_expected_batch_country_indicator_blocking_qa_event_count,
    latest_expected_publish_status,
    gap_stage,
    gap_status
FROM mart.mart_country_phase2_ingestion_gap_explainer
ORDER BY iso_alpha_3, indicator_code
LIMIT 24;

SELECT
    expected_dataset_code,
    missing_country_indicator_count,
    affected_country_count,
    affected_indicator_count,
    affected_country_iso_alpha_3_codes,
    affected_indicator_codes,
    fetch_scope_gap_count,
    normalization_gap_count,
    qa_blocking_gap_count,
    publication_gap_count,
    no_expected_dataset_batch_history_count,
    indicator_not_present_for_country_in_latest_raw_landing_count,
    raw_landed_but_not_normalized_to_staging_count,
    blocked_by_publish_qa_count,
    publish_run_not_successful_count,
    versioned_but_not_visible_in_published_surface_count,
    dominant_gap_stage,
    dominant_gap_stage_count,
    dominant_gap_status,
    dominant_gap_status_count,
    latest_expected_batch_external_id,
    latest_expected_manifest_path,
    latest_expected_publish_status
FROM mart.mart_phase2_dataset_ingestion_gap_rollup
ORDER BY missing_country_indicator_count DESC, expected_dataset_code
LIMIT 12;

SELECT
    dataset_code,
    operator_panel_status,
    operator_attention_rank,
    freshness_status,
    latest_publish_status,
    latest_phase2_observation_year,
    latest_dataset_published_at,
    latest_complete_indicator_count,
    required_phase2_indicator_count,
    latest_indicator_coverage_ratio,
    latest_missing_country_sum,
    latest_expected_country_sum,
    latest_country_coverage_ratio,
    latest_gap_indicator_codes,
    missing_country_indicator_count,
    dominant_gap_stage,
    dominant_gap_status,
    affected_country_iso_alpha_3_codes,
    affected_indicator_codes
FROM mart.vw_phase2_dataset_operator_panel_scan
ORDER BY operator_attention_rank, dataset_code
LIMIT 12;

SELECT
    dataset_code,
    source_batch_key,
    batch_recency_rank,
    is_latest_batch_for_dataset,
    batch_status,
    batch_status_rank,
    source_released_at,
    fetched_at,
    published_at,
    publish_status,
    publish_blocking_qa_event_count,
    phase2_indicator_count,
    expected_phase2_indicator_count,
    indicator_coverage_ratio,
    phase2_country_indicator_pair_count,
    expected_phase2_country_indicator_pair_count,
    country_indicator_pair_coverage_ratio,
    phase2_country_indicator_pair_count_change_vs_prior_batch,
    pair_coverage_trend_vs_prior_batch,
    latest_phase2_observation_year_in_batch
FROM mart.vw_phase2_dataset_status_history_scan
ORDER BY dataset_code, batch_recency_rank
LIMIT 24;

SELECT
    iso_alpha_3,
    country_name,
    phase2_indicator_coverage_count,
    phase2_indicator_gap_count,
    labor_indicator_coverage_count,
    macro_trade_external_indicator_coverage_count,
    latest_phase2_observation_year,
    phase2_coverage_status,
    has_trade_pair,
    has_external_balance_pair,
    missing_indicator_codes,
    latest_published_at
FROM mart.mart_country_phase2_readiness_summary
ORDER BY phase2_indicator_gap_count DESC, iso_alpha_3
LIMIT 10;

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
