#!/bin/bash
set -euo pipefail

DB_NAME="${DB_NAME:-country_intel}"
PSQL_CMD="${PSQL_CMD:-psql -v ON_ERROR_STOP=1}"

./scripts/load_who_live.sh

$PSQL_CMD -d "$DB_NAME" <<'SQL'
DO $$
DECLARE
    latest_batch_key BIGINT;
BEGIN
    SELECT sb.source_batch_key
    INTO latest_batch_key
    FROM raw.source_batch sb
    JOIN ref.source_dataset d ON d.source_dataset_key = sb.source_dataset_key
    WHERE d.dataset_code = 'WHO_GHO'
      AND sb.batch_external_id LIKE 'who_live_%'
    ORDER BY sb.source_batch_key DESC
    LIMIT 1;

    IF latest_batch_key IS NULL THEN
        RAISE EXCEPTION 'Live WHO contract test failed: no live WHO batch was created';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM raw.source_batch sb
        WHERE sb.source_batch_key = latest_batch_key
          AND sb.request_params_json ? 'api_indicator_codes'
          AND sb.request_params_json ? 'source_series_codes'
          AND sb.request_params_json ? 'countries'
          AND sb.request_params_json ? 'years'
          AND sb.request_params_json ? 'dim1_code'
    ) THEN
        RAISE EXCEPTION 'Live WHO contract test failed: latest live WHO batch is missing request lineage fields';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM raw.source_batch sb
        WHERE sb.source_batch_key = latest_batch_key
          AND sb.request_params_json -> 'api_indicator_codes' @> '["WHOSIS_000001"]'::jsonb
          AND sb.request_params_json -> 'source_series_codes' @> '["WHOSIS_000001"]'::jsonb
    ) THEN
        RAISE EXCEPTION 'Live WHO contract test failed: latest live WHO batch does not declare the expected indicator lineage';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM core.fact_country_indicator_version fv
        JOIN core.dim_indicator di ON di.indicator_key = fv.indicator_key
        JOIN core.dim_dataset dd ON dd.source_dataset_key = fv.source_dataset_key
        WHERE fv.source_batch_key = latest_batch_key
          AND dd.dataset_code = 'WHO_GHO'
          AND di.indicator_code = 'LIFE_EXPECTANCY_YEARS'
        GROUP BY fv.source_batch_key
        HAVING COUNT(*) >= 15
    ) THEN
        RAISE EXCEPTION 'Live WHO contract test failed: latest live WHO batch did not normalize the expected life-expectancy authority slice';
    END IF;
END;
$$;
SQL

DATASET_CODE=WHO_GHO ./scripts/check_pipeline_alerts.sh

echo "Live WHO contract test passed"
