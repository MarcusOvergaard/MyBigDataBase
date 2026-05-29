-- Compact Phase 2 operator scan for routine warehouse checks.
-- Run with: make phase2-operator-scan

\pset pager off

SELECT
    COUNT(*) AS dataset_count,
    COUNT(*) FILTER (WHERE operator_panel_status = 'failing_active_gap') AS failing_dataset_count,
    COUNT(*) FILTER (WHERE operator_panel_status = 'warning_coverage_gap') AS warning_dataset_count,
    COUNT(*) FILTER (WHERE operator_panel_status = 'healthy') AS healthy_dataset_count
FROM mart.vw_phase2_dataset_operator_panel_scan;

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
ORDER BY operator_attention_rank, dataset_code;

SELECT
    dataset_code,
    source_batch_key,
    batch_external_id,
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
WHERE is_latest_batch_for_dataset = TRUE
ORDER BY batch_status_rank, dataset_code;

SELECT
    dataset_code,
    source_batch_key,
    batch_external_id,
    batch_recency_rank,
    batch_status,
    batch_status_rank,
    phase2_country_indicator_pair_count_change_vs_prior_batch,
    pair_coverage_trend_vs_prior_batch,
    indicator_coverage_ratio,
    country_indicator_pair_coverage_ratio,
    published_at
FROM mart.vw_phase2_dataset_status_history_scan
WHERE batch_status <> 'phase2_output_present'
   OR pair_coverage_trend_vs_prior_batch = 'deteriorating'
ORDER BY batch_status_rank, dataset_code, batch_recency_rank
LIMIT 16;
