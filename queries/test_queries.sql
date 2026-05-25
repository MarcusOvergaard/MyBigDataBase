-- Phase 1 validation queries for the conformed warehouse path

-- 0. Hard assertions: fail fast if the contract regresses.
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM ref.indicator i
        WHERE i.is_phase_1 = TRUE
          AND NOT EXISTS (
              SELECT 1
              FROM ref.indicator_source_priority isp
              WHERE isp.indicator_key = i.indicator_key
          )
    ) THEN
        RAISE EXCEPTION 'Phase 1 test failed: at least one Phase 1 indicator has no source-priority rule';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM core.fact_country_indicator_published fp
        WHERE fp.source_dataset_key IS NULL
           OR fp.source_series_key IS NULL
           OR fp.observation_version_key IS NULL
    ) THEN
        RAISE EXCEPTION 'Phase 1 test failed: published fact is missing dataset/series/version lineage';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM core.fact_country_indicator_version fv
        WHERE fv.selection_rule_version_ref IS NULL
           OR fv.selection_rule_key_snapshot IS NULL
    ) THEN
        RAISE EXCEPTION 'Phase 1 test failed: version fact is missing canonical-contract rule lineage';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM core.fact_country_indicator_published fp
        WHERE fp.selection_rule_version_ref IS NULL
           OR fp.comparability_break_flag IS NULL
           OR fp.source_switch_flag IS NULL
    ) THEN
        RAISE EXCEPTION 'Phase 1 test failed: published fact is missing canonical-contract fields';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ref.indicator i
        WHERE i.is_phase_1 = TRUE
          AND NOT EXISTS (
              SELECT 1
              FROM core.fact_country_indicator_published fp
              JOIN core.dim_indicator di ON di.indicator_key = fp.indicator_key
              WHERE di.indicator_code = i.indicator_code
          )
    ) THEN
        RAISE EXCEPTION 'Phase 1 test failed: at least one seeded Phase 1 indicator is not exercised in published facts';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM core.fact_country_indicator_published fp
        JOIN core.dim_indicator di ON di.indicator_key = fp.indicator_key
        JOIN core.dim_dataset dd ON dd.source_dataset_key = fp.source_dataset_key
        WHERE di.indicator_code = 'INFLATION_CPI_PCT'
          AND dd.dataset_code = 'IFS'
    ) THEN
        RAISE EXCEPTION 'Phase 1 test failed: minimal IFS arbitration slice did not win any published inflation rows';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM core.fact_country_indicator_published fp
        JOIN core.dim_indicator di ON di.indicator_key = fp.indicator_key
        JOIN core.dim_dataset dd ON dd.source_dataset_key = fp.source_dataset_key
        WHERE di.indicator_code = 'INFLATION_CPI_PCT'
          AND dd.dataset_code = 'WDI'
          AND COALESCE(fp.selection_method, '') <> 'source_priority_override'
          AND EXISTS (
              SELECT 1
              FROM core.fact_country_indicator_version fv_ifs
              JOIN core.dim_dataset dd_ifs ON dd_ifs.source_dataset_key = fv_ifs.source_dataset_key
              WHERE fv_ifs.country_key = fp.country_key
                AND fv_ifs.indicator_key = fp.indicator_key
                AND fv_ifs.time_key = fp.time_key
                AND dd_ifs.dataset_code = 'IFS'
          )
    ) THEN
        RAISE EXCEPTION 'Phase 1 test failed: WDI published overlapping inflation row without an explicit override';
    END IF;
    IF NOT EXISTS (
        SELECT 1
        FROM core.fact_country_indicator_published fp
        JOIN core.dim_indicator di ON di.indicator_key = fp.indicator_key
        JOIN core.dim_dataset dd ON dd.source_dataset_key = fp.source_dataset_key
        WHERE di.indicator_code = 'GDP_CURR_USD'
          AND dd.dataset_code = 'IFS'
    ) THEN
        RAISE EXCEPTION 'Phase 1 test failed: minimal IFS arbitration slice did not win any published GDP rows';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM core.fact_country_indicator_published fp
        JOIN core.dim_indicator di ON di.indicator_key = fp.indicator_key
        JOIN core.dim_dataset dd ON dd.source_dataset_key = fp.source_dataset_key
        WHERE di.indicator_code = 'GDP_CURR_USD'
          AND dd.dataset_code = 'WDI'
          AND EXISTS (
              SELECT 1
              FROM core.fact_country_indicator_version fv_ifs
              JOIN core.dim_dataset dd_ifs ON dd_ifs.source_dataset_key = fv_ifs.source_dataset_key
              WHERE fv_ifs.country_key = fp.country_key
                AND fv_ifs.indicator_key = fp.indicator_key
                AND fv_ifs.time_key = fp.time_key
                AND dd_ifs.dataset_code = 'IFS'
          )
    ) THEN
        RAISE EXCEPTION 'Phase 1 test failed: WDI published GDP row despite overlapping IFS candidate for the same country-year-indicator';
    END IF;
    IF NOT EXISTS (
        SELECT 1
        FROM core.fact_country_indicator_published fp
        JOIN core.dim_country dc ON dc.country_key = fp.country_key
        JOIN core.dim_indicator di ON di.indicator_key = fp.indicator_key
        JOIN core.dim_dataset dd ON dd.source_dataset_key = fp.source_dataset_key
        WHERE dc.iso_alpha_3 = 'DEU'
          AND di.indicator_code = 'INFLATION_CPI_PCT'
          AND fp.observation_year = 2022
          AND dd.dataset_code = 'WDI'
          AND fp.selection_method = 'source_priority_override'
    ) THEN
        RAISE EXCEPTION 'Phase 1 test failed: DEU inflation override did not publish the WDI row with override selection method';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM core.fact_country_indicator_published fp
        JOIN core.dim_country dc ON dc.country_key = fp.country_key
        JOIN core.dim_indicator di ON di.indicator_key = fp.indicator_key
        JOIN core.dim_dataset dd ON dd.source_dataset_key = fp.source_dataset_key
        WHERE dc.iso_alpha_3 = 'DEU'
          AND di.indicator_code = 'INFLATION_CPI_PCT'
          AND fp.observation_year = 2021
          AND dd.dataset_code = 'IFS'
          AND fp.selection_method = 'source_priority_default'
    ) THEN
        RAISE EXCEPTION 'Phase 1 test failed: DEU inflation should revert to the global IFS default outside the 2022 override window';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM core.fact_country_indicator_published fp
        JOIN core.dim_country dc ON dc.country_key = fp.country_key
        JOIN core.dim_indicator di ON di.indicator_key = fp.indicator_key
        JOIN core.dim_dataset dd ON dd.source_dataset_key = fp.source_dataset_key
        WHERE dc.iso_alpha_3 = 'DEU'
          AND di.indicator_code = 'INFLATION_CPI_PCT'
          AND fp.observation_year = 2021
          AND dd.dataset_code = 'WDI'
    ) THEN
        RAISE EXCEPTION 'Phase 1 test failed: DEU inflation override leaked into 2021 when it should be bounded to 2022 only';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM core.fact_country_indicator_published fp
        JOIN core.dim_country dc ON dc.country_key = fp.country_key
        JOIN core.dim_indicator di ON di.indicator_key = fp.indicator_key
        JOIN core.dim_dataset dd ON dd.source_dataset_key = fp.source_dataset_key
        WHERE dc.iso_alpha_3 = 'USA'
          AND di.indicator_code = 'INFLATION_CPI_PCT'
          AND fp.observation_year = 2022
          AND dd.dataset_code = 'IFS'
    ) THEN
        RAISE EXCEPTION 'Phase 1 test failed: USA inflation should still follow the global IFS default when no country override exists';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM mart.vw_macro_source_selection_lineage v
        WHERE v.iso_alpha_3 = 'DEU'
          AND v.indicator_code = 'INFLATION_CPI_PCT'
          AND v.observation_year = 2022
          AND v.dataset_code = 'WDI'
          AND v.selection_method = 'source_priority_override'
          AND v.is_override = TRUE
          AND v.priority_rank = 1
          AND v.rule_valid_from_year = 2022
          AND v.rule_valid_to_year = 2022
    ) THEN
        RAISE EXCEPTION 'Phase 1 test failed: source-selection lineage view does not expose the DEU 2022 override fields correctly';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM mart.vw_macro_source_selection_lineage v
        WHERE v.iso_alpha_3 = 'DEU'
          AND v.indicator_code = 'INFLATION_CPI_PCT'
          AND v.observation_year = 2021
          AND v.dataset_code = 'IFS'
          AND v.selection_method = 'source_priority_default'
          AND v.is_override = FALSE
          AND v.priority_rank = 1
    ) THEN
        RAISE EXCEPTION 'Phase 1 test failed: source-selection lineage view does not expose the DEU 2021 global-default fields correctly';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM mart.vw_macro_coverage_gaps g
    ) THEN
        RAISE EXCEPTION 'Phase 1 test failed: latest-batch coverage-gap view still shows actionable unmapped or unpublished rows';
    END IF;

END;
$$;

-- 1. Direct published-fact coverage summary by dataset and indicator
SELECT
    dd.dataset_code,
    di.indicator_code,
    COUNT(*) AS published_row_count,
    MIN(fp.observation_year) AS min_observation_year,
    MAX(fp.observation_year) AS max_observation_year,
    MAX(fp.published_at) AS latest_published_at
FROM core.fact_country_indicator_published fp
JOIN core.dim_dataset dd ON dd.source_dataset_key = fp.source_dataset_key
JOIN core.dim_indicator di ON di.indicator_key = fp.indicator_key
GROUP BY dd.dataset_code, di.indicator_code
ORDER BY dd.dataset_code, di.indicator_code;

-- 2. Latest source-version publication summary
SELECT
    COUNT(*) AS latest_source_version_rows,
    COUNT(*) FILTER (WHERE fp.observation_version_key IS NOT NULL) AS published_latest_source_versions,
    COUNT(*) FILTER (WHERE fp.observation_version_key IS NULL) AS unpublished_latest_source_versions,
    COUNT(*) FILTER (WHERE fv.status_code <> 'published') AS non_published_latest_status_rows,
    MIN(dt.calendar_year) AS min_observation_year,
    MAX(dt.calendar_year) AS max_observation_year
FROM core.fact_country_indicator_version fv
JOIN core.dim_time dt ON dt.time_key = fv.time_key
LEFT JOIN core.fact_country_indicator_published fp
  ON fp.observation_version_key = fv.observation_version_key
WHERE fv.is_latest_source_version = TRUE;

-- 3. Latest published macro foundation values by country
SELECT
    iso_alpha_3,
    country_name,
    gdp_curr_usd_year,
    gdp_curr_usd,
    gdp_pc_curr_usd_year,
    gdp_pc_curr_usd,
    pop_total_year,
    pop_total,
    latest_published_at
FROM mart.mart_country_macro_latest
ORDER BY country_name;

-- 3b. Arbitration proof for contested WDI-vs-IFS indicators: compact summary plus the explicit override rows.
SELECT
    di.indicator_code,
    dd.dataset_code,
    COUNT(*) AS published_row_count,
    COUNT(*) FILTER (WHERE fp.selection_method = 'source_priority_default') AS default_selection_count,
    COUNT(*) FILTER (WHERE fp.selection_method = 'source_priority_ranked') AS ranked_selection_count,
    COUNT(*) FILTER (WHERE fp.selection_method = 'source_priority_override') AS override_selection_count
FROM core.fact_country_indicator_published fp
JOIN core.dim_indicator di ON di.indicator_key = fp.indicator_key
JOIN core.dim_dataset dd ON dd.source_dataset_key = fp.source_dataset_key
WHERE di.indicator_code IN ('INFLATION_CPI_PCT', 'GDP_CURR_USD')
GROUP BY di.indicator_code, dd.dataset_code
ORDER BY di.indicator_code, dd.dataset_code;

SELECT
    iso_alpha_3,
    indicator_code,
    observation_year,
    dataset_code,
    selection_method,
    is_override,
    priority_rank,
    rule_valid_from_year,
    rule_valid_to_year
FROM mart.vw_macro_source_selection_lineage
WHERE indicator_code IN ('INFLATION_CPI_PCT', 'GDP_CURR_USD')
  AND (is_override = TRUE OR iso_alpha_3 IN ('DEU', 'USA'))
ORDER BY observation_year DESC, iso_alpha_3, indicator_code, dataset_code;

-- 4. Published lineage summary
SELECT
    COUNT(*) AS published_lineage_rows,
    COUNT(DISTINCT publication_version_code) AS publication_versions,
    COUNT(*) FILTER (WHERE comparability_break_flag) AS comparability_break_rows,
    COUNT(*) FILTER (WHERE source_switch_flag) AS source_switch_rows,
    COUNT(*) FILTER (WHERE batch_external_id IS NULL OR series_code IS NULL) AS missing_lineage_fields
FROM mart.vw_macro_published_with_lineage;

-- 4b. No full dump needed; targeted arbitration rows are already shown above.

-- 5. Coverage gaps that still need mapping or QA attention
SELECT
    COUNT(*) AS coverage_gap_rows,
    COUNT(*) FILTER (WHERE gap_reason = 'absent_at_source') AS absent_at_source_rows,
    COUNT(*) FILTER (WHERE gap_reason = 'parse_failure') AS parse_failure_rows,
    COUNT(*) FILTER (WHERE gap_reason = 'qa_blocked') AS qa_blocked_rows
FROM mart.vw_macro_coverage_gaps;

-- 6. Dataset freshness and last successful publish status
SELECT
    dataset_code,
    source_code,
    latest_successful_fetch_at,
    latest_source_released_at,
    latest_published_at,
    latest_published_year,
    freshness_status,
    is_stale,
    last_pipeline_run_status,
    last_source_batch_key
FROM mart.vw_dataset_freshness_status
ORDER BY dataset_code;

-- 6b. Dataset pipeline health operating view
SELECT
    dataset_code,
    source_code,
    is_active_for_ingest,
    freshness_status,
    latest_batch_ingest_status,
    latest_batch_row_count_reported,
    latest_pipeline_status,
    latest_publish_status,
    latest_publish_blocking_qa_event_count,
    current_published_row_count,
    anomaly_flags
FROM mart.dataset_pipeline_health
ORDER BY dataset_code;

-- 6c. Alert-only operating surface for active ingest datasets
SELECT
    dataset_code,
    source_code,
    alert_severity,
    alert_code,
    alert_message,
    latest_source_batch_key,
    latest_pipeline_status,
    latest_publish_status,
    failed_source_batch_count_7d
FROM mart.dataset_pipeline_alerts
ORDER BY dataset_code, alert_severity, alert_code;

-- 7. Rows that failed publication due to blocking QA rules
SELECT
    COUNT(*) AS blocking_qa_event_rows,
    COUNT(DISTINCT dqe.event_code) AS distinct_blocking_event_codes,
    MIN(dqe.observation_year) AS min_blocked_observation_year,
    MAX(dqe.observation_year) AS max_blocked_observation_year
FROM audit.data_quality_event dqe
WHERE dqe.blocks_publication = TRUE;
