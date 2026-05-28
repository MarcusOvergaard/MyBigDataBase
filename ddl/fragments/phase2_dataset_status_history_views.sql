-- Shared Phase 2 dataset status-history view definitions.
CREATE OR REPLACE VIEW mart.mart_phase2_dataset_status_history AS
WITH phase2_indicator_contract AS (
    SELECT
        sd.source_dataset_key,
        sd.dataset_code,
        COUNT(DISTINCT i.indicator_key) AS expected_phase2_indicator_count
    FROM ref.source_dataset sd
    JOIN ref.source_series rs
      ON rs.source_dataset_key = sd.source_dataset_key
     AND rs.is_active = TRUE
    JOIN ref.indicator_source_series_map ism
      ON ism.source_series_key = rs.source_series_key
     AND ism.is_active = TRUE
    JOIN ref.indicator i
      ON i.indicator_key = ism.indicator_key
    WHERE sd.dataset_code IN ('IFS', 'WEO', 'ILOSTAT', 'UN_COMTRADE_ANNUAL')
      AND i.indicator_code IN (
        'EMPLOYMENT_RATE_PCT',
        'LABOR_FORCE_PARTICIPATION_RATE_PCT',
        'UNEMPLOYMENT_RATE_PCT',
        'INFLATION_CPI_PCT',
        'TRADE_EXPORTS_CURR_USD',
        'TRADE_IMPORTS_CURR_USD',
        'CURRENT_ACCOUNT_BALANCE_CURR_USD',
        'CURRENT_ACCOUNT_BALANCE_PCT_GDP'
      )
    GROUP BY sd.source_dataset_key, sd.dataset_code
),
expected_country_count AS (
    SELECT COUNT(*) AS expected_country_count
    FROM core.dim_country dc
    WHERE dc.is_active = TRUE
      AND COALESCE(dc.is_aggregate, FALSE) = FALSE
),
phase2_batch_versions AS (
    SELECT
        fv.source_dataset_key,
        fv.source_batch_key,
        COUNT(*) AS phase2_version_row_count,
        COUNT(DISTINCT fv.indicator_key) AS phase2_indicator_count,
        COUNT(DISTINCT (fv.country_key, fv.indicator_key)) AS phase2_country_indicator_pair_count,
        MAX(dt.calendar_year) AS latest_phase2_observation_year_in_batch
    FROM core.fact_country_indicator_version fv
    JOIN core.dim_indicator di ON di.indicator_key = fv.indicator_key
    JOIN core.dim_time dt ON dt.time_key = fv.time_key
    JOIN core.dim_dataset dd ON dd.source_dataset_key = fv.source_dataset_key
    WHERE dd.dataset_code IN ('IFS', 'WEO', 'ILOSTAT', 'UN_COMTRADE_ANNUAL')
      AND di.indicator_code IN (
        'EMPLOYMENT_RATE_PCT',
        'LABOR_FORCE_PARTICIPATION_RATE_PCT',
        'UNEMPLOYMENT_RATE_PCT',
        'INFLATION_CPI_PCT',
        'TRADE_EXPORTS_CURR_USD',
        'TRADE_IMPORTS_CURR_USD',
        'CURRENT_ACCOUNT_BALANCE_CURR_USD',
        'CURRENT_ACCOUNT_BALANCE_PCT_GDP'
      )
    GROUP BY fv.source_dataset_key, fv.source_batch_key
),
publish_runs AS (
    SELECT DISTINCT ON (apr.source_batch_key)
        apr.source_dataset_key,
        apr.source_batch_key,
        apr.pipeline_run_key,
        apr.started_at,
        apr.completed_at,
        apr.status_code AS publish_status,
        apr.row_count_in,
        apr.row_count_out,
        apr.notes,
        pv.publication_version_key,
        pv.publication_version_code,
        pv.published_at,
        COALESCE(dq.total_dq_event_count, 0) AS publish_total_dq_event_count,
        COALESCE(dq.blocking_qa_event_count, 0) AS publish_blocking_qa_event_count
    FROM audit.pipeline_run apr
    LEFT JOIN audit.publication_version pv ON pv.pipeline_run_key = apr.pipeline_run_key
    LEFT JOIN (
        SELECT
            dqe.pipeline_run_key,
            COUNT(*) AS total_dq_event_count,
            COUNT(*) FILTER (WHERE dqe.blocks_publication = TRUE) AS blocking_qa_event_count
        FROM audit.data_quality_event dqe
        GROUP BY dqe.pipeline_run_key
    ) dq ON dq.pipeline_run_key = apr.pipeline_run_key
    WHERE apr.pipeline_stage = 'publish'
      AND apr.source_dataset_key IS NOT NULL
      AND apr.source_batch_key IS NOT NULL
    ORDER BY apr.source_batch_key, apr.started_at DESC, apr.pipeline_run_key DESC
),
base AS (
    SELECT
        sd.source_dataset_key,
        sd.dataset_code,
        sd.dataset_name,
        ss.source_code,
        ss.source_name,
        sb.source_batch_key,
        sb.batch_external_id,
        sb.request_uri,
        sb.fetched_at,
        sb.source_released_at,
        sb.ingest_status,
        sb.row_count_reported,
        sb.created_at,
        pic.expected_phase2_indicator_count,
        ecc.expected_country_count,
        pic.expected_phase2_indicator_count * ecc.expected_country_count AS expected_phase2_country_indicator_pair_count,
        COALESCE(pbv.phase2_version_row_count, 0) AS phase2_version_row_count,
        COALESCE(pbv.phase2_indicator_count, 0) AS phase2_indicator_count,
        COALESCE(pbv.phase2_country_indicator_pair_count, 0) AS phase2_country_indicator_pair_count,
        pbv.latest_phase2_observation_year_in_batch,
        pr.pipeline_run_key AS publish_run_key,
        pr.publication_version_key,
        pr.publication_version_code,
        pr.started_at AS publish_started_at,
        pr.completed_at AS publish_completed_at,
        pr.publish_status,
        pr.row_count_in AS publish_row_count_in,
        pr.row_count_out AS publish_row_count_out,
        pr.published_at,
        pr.publish_total_dq_event_count,
        pr.publish_blocking_qa_event_count,
        pr.notes AS publish_notes
    FROM raw.source_batch sb
    JOIN ref.source_dataset sd ON sd.source_dataset_key = sb.source_dataset_key
    JOIN ref.source_system ss ON ss.source_system_key = sd.source_system_key
    JOIN phase2_indicator_contract pic ON pic.source_dataset_key = sd.source_dataset_key
    CROSS JOIN expected_country_count ecc
    LEFT JOIN phase2_batch_versions pbv
      ON pbv.source_dataset_key = sb.source_dataset_key
     AND pbv.source_batch_key = sb.source_batch_key
    LEFT JOIN publish_runs pr
      ON pr.source_dataset_key = sb.source_dataset_key
     AND pr.source_batch_key = sb.source_batch_key
),
ranked AS (
    SELECT
        b.*,
        ROW_NUMBER() OVER (
            PARTITION BY b.source_dataset_key
            ORDER BY COALESCE(b.source_released_at, b.fetched_at) DESC, b.source_batch_key DESC
        ) AS batch_recency_rank,
        LAG(b.phase2_version_row_count) OVER (
            PARTITION BY b.source_dataset_key
            ORDER BY COALESCE(b.source_released_at, b.fetched_at), b.source_batch_key
        ) AS prior_phase2_version_row_count,
        LAG(b.phase2_country_indicator_pair_count) OVER (
            PARTITION BY b.source_dataset_key
            ORDER BY COALESCE(b.source_released_at, b.fetched_at), b.source_batch_key
        ) AS prior_phase2_country_indicator_pair_count
    FROM base b
)
SELECT
    r.source_dataset_key,
    r.dataset_code,
    r.dataset_name,
    r.source_code,
    r.source_name,
    r.source_batch_key,
    r.batch_external_id,
    r.request_uri,
    r.fetched_at,
    r.source_released_at,
    r.ingest_status,
    r.row_count_reported,
    r.created_at,
    r.publish_run_key,
    r.publication_version_key,
    r.publication_version_code,
    r.publish_started_at,
    r.publish_completed_at,
    r.publish_status,
    r.publish_row_count_in,
    r.publish_row_count_out,
    r.published_at,
    r.publish_total_dq_event_count,
    r.publish_blocking_qa_event_count,
    r.publish_notes,
    r.expected_phase2_indicator_count,
    r.expected_country_count,
    r.expected_phase2_country_indicator_pair_count,
    r.phase2_version_row_count,
    r.phase2_indicator_count,
    r.phase2_country_indicator_pair_count,
    r.latest_phase2_observation_year_in_batch,
    r.batch_recency_rank,
    (r.batch_recency_rank = 1) AS is_latest_batch_for_dataset,
    r.prior_phase2_version_row_count,
    r.phase2_version_row_count - COALESCE(r.prior_phase2_version_row_count, 0) AS phase2_version_row_count_change_vs_prior_batch,
    r.prior_phase2_country_indicator_pair_count,
    r.phase2_country_indicator_pair_count - COALESCE(r.prior_phase2_country_indicator_pair_count, 0) AS phase2_country_indicator_pair_count_change_vs_prior_batch,
    CASE
        WHEN r.prior_phase2_country_indicator_pair_count IS NULL THEN NULL
        WHEN r.phase2_country_indicator_pair_count > r.prior_phase2_country_indicator_pair_count THEN 'improving'
        WHEN r.phase2_country_indicator_pair_count < r.prior_phase2_country_indicator_pair_count THEN 'deteriorating'
        ELSE 'flat'
    END AS pair_coverage_trend_vs_prior_batch,
    CASE
        WHEN r.publish_run_key IS NULL THEN 'not_published'
        WHEN r.publish_status NOT IN ('succeeded', 'succeeded_with_warnings') THEN 'publish_failed'
        WHEN r.phase2_version_row_count = 0 THEN 'no_phase2_output'
        WHEN r.phase2_indicator_count < r.expected_phase2_indicator_count THEN 'partial_indicator_coverage'
        WHEN r.phase2_country_indicator_pair_count < r.expected_phase2_country_indicator_pair_count THEN 'partial_country_coverage'
        ELSE 'phase2_output_present'
    END AS batch_status
FROM ranked r;

CREATE OR REPLACE VIEW mart.vw_phase2_dataset_status_history_scan AS
SELECT
    h.source_dataset_key,
    h.dataset_code,
    h.dataset_name,
    h.source_code,
    h.source_name,
    h.source_batch_key,
    h.batch_external_id,
    h.batch_recency_rank,
    h.is_latest_batch_for_dataset,
    h.batch_status,
    CASE h.batch_status
        WHEN 'publish_failed' THEN 1
        WHEN 'not_published' THEN 2
        WHEN 'no_phase2_output' THEN 3
        WHEN 'partial_indicator_coverage' THEN 4
        WHEN 'partial_country_coverage' THEN 5
        ELSE 6
    END AS batch_status_rank,
    h.source_released_at,
    h.fetched_at,
    h.published_at,
    h.publish_status,
    h.publish_blocking_qa_event_count,
    h.phase2_indicator_count,
    h.expected_phase2_indicator_count,
    ROUND(
        h.phase2_indicator_count::numeric / NULLIF(h.expected_phase2_indicator_count, 0),
        4
    ) AS indicator_coverage_ratio,
    h.phase2_country_indicator_pair_count,
    h.expected_phase2_country_indicator_pair_count,
    ROUND(
        h.phase2_country_indicator_pair_count::numeric
        / NULLIF(h.expected_phase2_country_indicator_pair_count, 0),
        4
    ) AS country_indicator_pair_coverage_ratio,
    h.phase2_country_indicator_pair_count_change_vs_prior_batch,
    h.pair_coverage_trend_vs_prior_batch,
    h.latest_phase2_observation_year_in_batch
FROM mart.mart_phase2_dataset_status_history h;
