#!/bin/bash
set -euo pipefail

DB_NAME="${DB_NAME:-country_intel}"
PSQL_CMD="${PSQL_CMD:-psql -v ON_ERROR_STOP=1}"
NOW_UTC="$(date -u +"%Y-%m-%d %H:%M:%SZ")"

summary_line="$($PSQL_CMD -d "$DB_NAME" -tA <<'SQL'
SELECT CONCAT(
    'datasets=', COUNT(*),
    ' | failing=', COUNT(*) FILTER (WHERE operator_panel_status = 'failing_active_gap'),
    ' | warning=', COUNT(*) FILTER (WHERE operator_panel_status = 'warning_coverage_gap'),
    ' | healthy=', COUNT(*) FILTER (WHERE operator_panel_status = 'healthy')
)
FROM mart.vw_phase2_dataset_operator_panel_scan;
SQL
)"
summary_line="$(echo "$summary_line" | xargs)"

if [[ -z "$summary_line" ]]; then
    echo "Phase 2 monitoring report failed: could not read dataset summary" >&2
    exit 1
fi

echo "Phase 2 operator report | $NOW_UTC"
echo "$summary_line"
echo

echo "Dataset operator scan"
$PSQL_CMD -d "$DB_NAME" <<'SQL'
SELECT
    dataset_code,
    operator_panel_status,
    operator_attention_rank,
    freshness_status,
    latest_publish_status,
    latest_indicator_coverage_ratio,
    latest_country_coverage_ratio,
    latest_gap_indicator_codes,
    missing_country_indicator_count,
    COALESCE(dominant_gap_stage, '-') AS dominant_gap_stage,
    COALESCE(dominant_gap_status, '-') AS dominant_gap_status
FROM mart.vw_phase2_dataset_operator_panel_scan
ORDER BY operator_attention_rank, dataset_code;
SQL

echo

echo "Latest batch per dataset"
$PSQL_CMD -d "$DB_NAME" <<'SQL'
SELECT
    dataset_code,
    batch_status,
    batch_status_rank,
    publish_status,
    indicator_coverage_ratio,
    country_indicator_pair_coverage_ratio,
    pair_coverage_trend_vs_prior_batch,
    latest_phase2_observation_year_in_batch,
    published_at
FROM mart.vw_phase2_dataset_status_history_scan
WHERE is_latest_batch_for_dataset = TRUE
ORDER BY batch_status_rank, dataset_code;
SQL

echo
alert_count="$($PSQL_CMD -d "$DB_NAME" -tA <<'SQL'
SELECT COUNT(*)
FROM mart.dataset_pipeline_alerts;
SQL
)"
alert_count="${alert_count//[[:space:]]/}"

if [[ -z "$alert_count" ]]; then
    echo "Phase 2 monitoring report failed: could not read pipeline alert count" >&2
    exit 1
fi

if [[ "$alert_count" == "0" ]]; then
    echo "Pipeline alerts: none"
else
    echo "Pipeline alerts: $alert_count"
    $PSQL_CMD -d "$DB_NAME" <<'SQL'
SELECT
    dataset_code,
    alert_severity,
    alert_code,
    latest_batch_ingest_status,
    latest_pipeline_status,
    latest_publish_status,
    failed_source_batch_count_7d,
    last_error_at
FROM mart.dataset_pipeline_alerts
ORDER BY
    dataset_code,
    CASE alert_severity
        WHEN 'critical' THEN 1
        WHEN 'high' THEN 2
        WHEN 'medium' THEN 3
        ELSE 4
    END,
    alert_code;
SQL
fi
