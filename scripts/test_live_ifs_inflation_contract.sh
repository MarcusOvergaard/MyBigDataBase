#!/bin/bash
set -euo pipefail

DB_NAME="${DB_NAME:-country_intel}"
PSQL_CMD="${PSQL_CMD:-psql -v ON_ERROR_STOP=1}"

./scripts/load_ifs_live.sh

$PSQL_CMD -d "$DB_NAME" <<'SQL'
DO $$
DECLARE
    latest_batch_key BIGINT;
BEGIN
    SELECT sb.source_batch_key
    INTO latest_batch_key
    FROM raw.source_batch sb
    JOIN ref.source_dataset d ON d.source_dataset_key = sb.source_dataset_key
    WHERE d.dataset_code = 'IFS'
      AND sb.batch_external_id LIKE 'ifs_live_%'
    ORDER BY sb.source_batch_key DESC
    LIMIT 1;

    IF latest_batch_key IS NULL THEN
        RAISE EXCEPTION 'Live IFS contract test failed: no live IFS batch was created';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM raw.source_batch sb
        WHERE sb.source_batch_key = latest_batch_key
          AND sb.request_params_json ? 'api_indicator_codes'
          AND sb.request_params_json ? 'source_series_codes'
    ) THEN
        RAISE EXCEPTION 'Live IFS contract test failed: latest live IFS batch is missing request_params_json.api_indicator_codes/source_series_codes';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM raw.source_batch sb
        WHERE sb.source_batch_key = latest_batch_key
          AND sb.request_params_json -> 'source_series_codes' @> '["PCPI_PC_PP_PT"]'::jsonb
    ) THEN
        RAISE EXCEPTION 'Live IFS contract test failed: latest live IFS batch does not declare the CPI source series code';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM raw.source_batch sb
        WHERE sb.source_batch_key = latest_batch_key
          AND sb.request_params_json -> 'source_series_codes' @> '["NGDP_USD"]'::jsonb
    ) THEN
        RAISE EXCEPTION 'Live IFS contract test failed: latest live IFS batch does not declare the GDP source series code';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM core.fact_country_indicator_published fp
        JOIN core.dim_indicator di ON di.indicator_key = fp.indicator_key
        JOIN core.dim_dataset dd ON dd.source_dataset_key = fp.source_dataset_key
        JOIN core.fact_country_indicator_version fv ON fv.observation_version_key = fp.observation_version_key
        WHERE fv.source_batch_key = latest_batch_key
          AND di.indicator_code = 'INFLATION_CPI_PCT'
          AND dd.dataset_code = 'IFS'
    ) THEN
        RAISE EXCEPTION 'Live IFS contract test failed: latest live IFS batch did not publish any IFS-backed inflation rows';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM core.fact_country_indicator_published fp
        JOIN core.dim_indicator di ON di.indicator_key = fp.indicator_key
        JOIN core.dim_dataset dd ON dd.source_dataset_key = fp.source_dataset_key
        JOIN core.fact_country_indicator_version fv ON fv.observation_version_key = fp.observation_version_key
        WHERE fv.source_batch_key = latest_batch_key
          AND di.indicator_code = 'GDP_CURR_USD'
          AND dd.dataset_code = 'IFS'
    ) THEN
        RAISE EXCEPTION 'Live IFS contract test failed: latest live IFS batch did not publish any IFS-backed GDP rows';
    END IF;
END;
$$;
SQL

DATASET_CODE=IFS ./scripts/check_pipeline_alerts.sh

echo "Live IFS macro arbitration contract test passed"
