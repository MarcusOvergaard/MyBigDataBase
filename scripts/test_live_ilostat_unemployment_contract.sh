#!/bin/bash
set -euo pipefail

DB_NAME="${DB_NAME:-country_intel}"
PSQL_CMD="${PSQL_CMD:-psql -v ON_ERROR_STOP=1}"

./scripts/load_ilostat_live.sh

$PSQL_CMD -d "$DB_NAME" <<'SQL'
DO $$
DECLARE
    latest_batch_key BIGINT;
BEGIN
    SELECT sb.source_batch_key
    INTO latest_batch_key
    FROM raw.source_batch sb
    JOIN ref.source_dataset d ON d.source_dataset_key = sb.source_dataset_key
    WHERE d.dataset_code = 'ILOSTAT'
      AND sb.batch_external_id LIKE 'ilostat_live_%'
    ORDER BY sb.source_batch_key DESC
    LIMIT 1;

    IF latest_batch_key IS NULL THEN
        RAISE EXCEPTION 'Live ILOSTAT contract test failed: no live ILOSTAT batch was created';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM raw.source_batch sb
        WHERE sb.source_batch_key = latest_batch_key
          AND sb.request_params_json ? 'api_indicator_ids'
          AND sb.request_params_json ? 'source_series_codes'
          AND sb.request_params_json ? 'series_requests'
    ) THEN
        RAISE EXCEPTION 'Live ILOSTAT contract test failed: latest live ILOSTAT batch is missing request lineage arrays';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM raw.source_batch sb
        WHERE sb.source_batch_key = latest_batch_key
          AND sb.request_params_json -> 'source_series_codes' @> '["UNE_RATE_15PLUS_TOTAL"]'::jsonb
          AND sb.request_params_json -> 'api_indicator_ids' @> '["SDG_0852_SEX_AGE_RT_A"]'::jsonb
          AND sb.request_params_json ->> 'timefrom' = '2019'
          AND sb.request_params_json ->> 'timeto' = '2023'
    ) THEN
        RAISE EXCEPTION 'Live ILOSTAT contract test failed: latest live ILOSTAT batch does not declare the widened unemployment request mapping';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM core.fact_country_indicator_published fp
        JOIN core.dim_indicator di ON di.indicator_key = fp.indicator_key
        JOIN core.dim_dataset dd ON dd.source_dataset_key = fp.source_dataset_key
        JOIN core.fact_country_indicator_version fv ON fv.observation_version_key = fp.observation_version_key
        WHERE fv.source_batch_key = latest_batch_key
          AND di.indicator_code = 'UNEMPLOYMENT_RATE_PCT'
          AND dd.dataset_code = 'ILOSTAT'
    ) THEN
        RAISE EXCEPTION 'Live ILOSTAT contract test failed: latest live ILOSTAT batch did not publish unemployment rows';
    END IF;
END;
$$;
SQL

DATASET_CODE=ILOSTAT ./scripts/check_pipeline_alerts.sh

echo "Live ILOSTAT unemployment contract test passed"
