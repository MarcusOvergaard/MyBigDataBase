#!/bin/bash
set -euo pipefail

DB_NAME="${DB_NAME:-country_intel}"
PSQL_CMD="${PSQL_CMD:-psql -v ON_ERROR_STOP=1}"

./scripts/load_wdi_labor_live.sh

$PSQL_CMD -d "$DB_NAME" <<'SQL'
DO $$
DECLARE
    latest_batch_key BIGINT;
    normalized_indicator_count INT;
BEGIN
    SELECT sb.source_batch_key
    INTO latest_batch_key
    FROM raw.source_batch sb
    JOIN ref.source_dataset d ON d.source_dataset_key = sb.source_dataset_key
    WHERE d.dataset_code = 'WDI'
      AND sb.batch_external_id LIKE 'wdi_labor_live_%'
    ORDER BY sb.source_batch_key DESC
    LIMIT 1;

    IF latest_batch_key IS NULL THEN
        RAISE EXCEPTION 'Live WDI labor contract test failed: no live WDI labor batch was created';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM raw.source_batch sb
        WHERE sb.source_batch_key = latest_batch_key
          AND sb.request_params_json ? 'api_indicator_codes'
          AND sb.request_params_json ? 'source_series_codes'
          AND sb.request_params_json ? 'conformed_indicator_codes'
          AND sb.request_params_json ? 'series_requests'
          AND sb.request_params_json ? 'country_basket'
    ) THEN
        RAISE EXCEPTION 'Live WDI labor contract test failed: latest WDI labor batch is missing request lineage arrays';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM raw.source_batch sb
        WHERE sb.source_batch_key = latest_batch_key
          AND sb.request_params_json -> 'api_indicator_codes' @> '["SL.EMP.TOTL.SP.ZS","SL.TLF.CACT.ZS","SL.UEM.TOTL.ZS"]'::jsonb
          AND sb.request_params_json -> 'source_series_codes' @> '["SL.EMP.TOTL.SP.ZS","SL.TLF.CACT.ZS","SL.UEM.TOTL.ZS"]'::jsonb
          AND sb.request_params_json -> 'conformed_indicator_codes' @> '["EMPLOYMENT_RATE_PCT","LABOR_FORCE_PARTICIPATION_RATE_PCT","UNEMPLOYMENT_RATE_PCT"]'::jsonb
          AND sb.request_params_json -> 'country_basket' @> '["DEU","CHN"]'::jsonb
          AND sb.request_params_json ->> 'years' = '2019:2023'
          AND jsonb_array_length(sb.request_params_json -> 'country_basket') = 2
          AND jsonb_array_length(sb.request_params_json -> 'series_requests') = 3
    ) THEN
        RAISE EXCEPTION 'Live WDI labor contract test failed: latest WDI labor batch does not declare the expected widened labor fallback lineage';
    END IF;

    SELECT COUNT(DISTINCT di.indicator_code)
    INTO normalized_indicator_count
    FROM core.fact_country_indicator_version fv
    JOIN core.dim_indicator di ON di.indicator_key = fv.indicator_key
    JOIN core.dim_dataset dd ON dd.source_dataset_key = fv.source_dataset_key
    WHERE fv.source_batch_key = latest_batch_key
      AND dd.dataset_code = 'WDI'
      AND di.indicator_code IN (
          'EMPLOYMENT_RATE_PCT',
          'LABOR_FORCE_PARTICIPATION_RATE_PCT',
          'UNEMPLOYMENT_RATE_PCT'
      );

    IF normalized_indicator_count <> 3 THEN
        RAISE EXCEPTION 'Live WDI labor contract test failed: latest WDI labor batch normalized % of 3 expected labor indicators', normalized_indicator_count;
    END IF;
END;
$$;
SQL

DATASET_CODE=WDI ./scripts/check_pipeline_alerts.sh

echo "Live WDI labor contract test passed"
