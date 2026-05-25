#!/bin/bash
set -euo pipefail

DB_NAME="${DB_NAME:-country_intel}"
PSQL_CMD="${PSQL_CMD:-psql -v ON_ERROR_STOP=1}"

alert_count="$($PSQL_CMD -d "$DB_NAME" -tA <<'SQL'
SELECT COUNT(*)
FROM mart.dataset_pipeline_alerts;
SQL
)"

alert_count="${alert_count//[[:space:]]/}"

if [[ -z "$alert_count" ]]; then
    echo "Pipeline alert check failed: could not read alert count from mart.dataset_pipeline_alerts" >&2
    exit 1
fi

if [[ "$alert_count" == "0" ]]; then
    echo "Pipeline alert check passed: mart.dataset_pipeline_alerts is empty"
    exit 0
fi

echo "Pipeline alert check failed: mart.dataset_pipeline_alerts has $alert_count row(s)" >&2

echo "--- active pipeline alerts ---" >&2
$PSQL_CMD -d "$DB_NAME" <<'SQL' >&2
SELECT
    dataset_code,
    alert_severity,
    alert_code,
    alert_message,
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

exit 1
