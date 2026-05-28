#!/bin/bash
set -euo pipefail

DB_NAME="${DB_NAME:-country_intel}"
PSQL_CMD="${PSQL_CMD:-psql -v ON_ERROR_STOP=1}"
NOW_UTC="$(date -u +"%Y-%m-%d %H:%M:%SZ")"

critical_summary="$($PSQL_CMD -d "$DB_NAME" -tA <<'SQL'
SELECT CONCAT(
    'failing_active_gap=', COUNT(*) FILTER (WHERE operator_panel_status = 'failing_active_gap'),
    ' | pipeline_alerts=', (SELECT COUNT(*) FROM mart.dataset_pipeline_alerts)
)
FROM mart.vw_phase2_dataset_operator_panel_scan;
SQL
)"
critical_summary="$(echo "$critical_summary" | xargs)"

if [[ -z "$critical_summary" ]]; then
    echo "Phase 2 operator watchdog failed: could not read summary" >&2
    exit 1
fi

failing_count="$($PSQL_CMD -d "$DB_NAME" -tA <<'SQL'
SELECT COUNT(*)
FROM mart.vw_phase2_dataset_operator_panel_scan
WHERE operator_panel_status = 'failing_active_gap';
SQL
)"
failing_count="${failing_count//[[:space:]]/}"

alert_count="$($PSQL_CMD -d "$DB_NAME" -tA <<'SQL'
SELECT COUNT(*)
FROM mart.dataset_pipeline_alerts;
SQL
)"
alert_count="${alert_count//[[:space:]]/}"

if [[ "$failing_count" == "0" && "$alert_count" == "0" ]]; then
    exit 0
fi

echo "Phase 2 watchdog alert | $NOW_UTC"
echo "$critical_summary"
echo

if [[ "$failing_count" != "0" ]]; then
    echo "Datasets with failing active gaps"
    $PSQL_CMD -d "$DB_NAME" <<'SQL'
SELECT
    dataset_code,
    operator_panel_status,
    missing_country_indicator_count,
    COALESCE(dominant_gap_stage, '-') AS dominant_gap_stage,
    COALESCE(dominant_gap_status, '-') AS dominant_gap_status,
    affected_country_iso_alpha_3_codes,
    affected_indicator_codes
FROM mart.vw_phase2_dataset_operator_panel_scan
WHERE operator_panel_status = 'failing_active_gap'
ORDER BY operator_attention_rank, dataset_code;
SQL
    echo
fi

if [[ "$alert_count" != "0" ]]; then
    echo "Active pipeline alerts"
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
