#!/bin/bash
set -euo pipefail

DB_NAME="${DB_NAME:-country_intel}"
PSQL_CMD="${PSQL_CMD:-psql -v ON_ERROR_STOP=1}"

./scripts/load_un_comtrade_live.sh

$PSQL_CMD -d "$DB_NAME" <<'SQL'
DO $$
DECLARE
    latest_batch_key BIGINT;
BEGIN
    SELECT sb.source_batch_key
    INTO latest_batch_key
    FROM raw.source_batch sb
    JOIN ref.source_dataset d ON d.source_dataset_key = sb.source_dataset_key
    WHERE d.dataset_code = 'UN_COMTRADE_ANNUAL'
      AND sb.batch_external_id LIKE 'un_comtrade_live_%'
    ORDER BY sb.source_batch_key DESC
    LIMIT 1;

    IF latest_batch_key IS NULL THEN
        RAISE EXCEPTION 'Live UN Comtrade contract test failed: no live trade batch was created';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM raw.source_batch sb
        WHERE sb.source_batch_key = latest_batch_key
          AND sb.request_params_json -> 'source_series_codes' @> '["TRADE_EXPORTS_TOTAL_WORLD","TRADE_IMPORTS_TOTAL_WORLD"]'::jsonb
          AND sb.request_params_json -> 'flow_codes' @> '["X","M"]'::jsonb
          AND sb.request_params_json -> 'periods' @> '["2021","2022"]'::jsonb
          AND COALESCE(sb.request_params_json ->> 'selected_reporters', '') <> 'all'
          AND COALESCE(sb.request_params_json ->> 'selected_reporter_iso3', '') <> ''
    ) THEN
        RAISE EXCEPTION 'Live UN Comtrade contract test failed: latest trade batch is missing expected request lineage';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM core.fact_country_indicator_published fp
        JOIN core.dim_indicator di ON di.indicator_key = fp.indicator_key
        JOIN core.dim_dataset dd ON dd.source_dataset_key = fp.source_dataset_key
        JOIN core.fact_country_indicator_version fv ON fv.observation_version_key = fp.observation_version_key
        WHERE fv.source_batch_key = latest_batch_key
          AND dd.dataset_code = 'UN_COMTRADE_ANNUAL'
          AND di.indicator_code IN ('TRADE_EXPORTS_CURR_USD', 'TRADE_IMPORTS_CURR_USD')
        GROUP BY fv.source_batch_key
        HAVING COUNT(DISTINCT di.indicator_code) = 2
    ) THEN
        RAISE EXCEPTION 'Live UN Comtrade contract test failed: latest trade batch did not publish both exports and imports';
    END IF;
END;
$$;
SQL

DATASET_CODE=UN_COMTRADE_ANNUAL ./scripts/check_pipeline_alerts.sh

echo "Live UN Comtrade trade contract test passed"
