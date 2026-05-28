#!/bin/bash
set -euo pipefail

DB_NAME="${DB_NAME:-country_intel}"
PSQL_CMD="${PSQL_CMD:-psql -v ON_ERROR_STOP=1}"

./scripts/load_weo_live.sh

$PSQL_CMD -d "$DB_NAME" <<'SQL'
DO $$
DECLARE
    latest_batch_key BIGINT;
BEGIN
    SELECT sb.source_batch_key
    INTO latest_batch_key
    FROM raw.source_batch sb
    JOIN ref.source_dataset d ON d.source_dataset_key = sb.source_dataset_key
    WHERE d.dataset_code = 'WEO'
      AND sb.batch_external_id LIKE 'weo_live_%'
    ORDER BY sb.source_batch_key DESC
    LIMIT 1;

    IF latest_batch_key IS NULL THEN
        RAISE EXCEPTION 'Live WEO contract test failed: no live WEO batch was created';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM raw.source_batch sb
        WHERE sb.source_batch_key = latest_batch_key
          AND sb.request_params_json ? 'api_indicator_codes'
          AND sb.request_params_json ? 'source_series_codes'
    ) THEN
        RAISE EXCEPTION 'Live WEO contract test failed: latest live WEO batch is missing request_params_json.api_indicator_codes/source_series_codes';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM raw.source_batch sb
        WHERE sb.source_batch_key = latest_batch_key
          AND sb.request_params_json -> 'source_series_codes' @> '["CURRENT_ACCOUNT_BALANCE_PCT_GDP"]'::jsonb
    ) THEN
        RAISE EXCEPTION 'Live WEO contract test failed: latest live WEO batch does not declare the current-account-percent-of-GDP source series code';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM raw.source_batch sb
        WHERE sb.source_batch_key = latest_batch_key
          AND sb.request_params_json -> 'source_series_codes' @> '["CURRENT_ACCOUNT_BALANCE_USD"]'::jsonb
    ) THEN
        RAISE EXCEPTION 'Live WEO contract test failed: latest live WEO batch does not declare the current-account-USD source series code';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM raw.source_batch sb
        WHERE sb.source_batch_key = latest_batch_key
          AND sb.request_params_json ->> 'years' = '2019;2020;2021;2022;2023'
    ) THEN
        RAISE EXCEPTION 'Live WEO contract test failed: latest live WEO batch does not declare the widened 2019-2023 proof window';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM core.fact_country_indicator_published fp
        JOIN core.dim_indicator di ON di.indicator_key = fp.indicator_key
        JOIN core.dim_dataset dd ON dd.source_dataset_key = fp.source_dataset_key
        JOIN core.fact_country_indicator_version fv ON fv.observation_version_key = fp.observation_version_key
        WHERE fv.source_batch_key = latest_batch_key
          AND di.indicator_code = 'CURRENT_ACCOUNT_BALANCE_PCT_GDP'
          AND dd.dataset_code = 'WEO'
    ) THEN
        RAISE EXCEPTION 'Live WEO contract test failed: latest live WEO batch did not publish any WEO-backed current-account-percent-of-GDP rows';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM core.fact_country_indicator_published fp
        JOIN core.dim_indicator di ON di.indicator_key = fp.indicator_key
        JOIN core.dim_dataset dd ON dd.source_dataset_key = fp.source_dataset_key
        JOIN core.fact_country_indicator_version fv ON fv.observation_version_key = fp.observation_version_key
        WHERE fv.source_batch_key = latest_batch_key
          AND di.indicator_code = 'CURRENT_ACCOUNT_BALANCE_CURR_USD'
          AND dd.dataset_code = 'WEO'
    ) THEN
        RAISE EXCEPTION 'Live WEO contract test failed: latest live WEO batch did not publish any WEO-backed current-account-USD rows';
    END IF;
END;
$$;
SQL

DATASET_CODE=WEO ./scripts/check_pipeline_alerts.sh

echo "Live WEO external-balance contract test passed"
