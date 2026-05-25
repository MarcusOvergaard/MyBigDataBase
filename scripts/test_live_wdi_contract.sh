#!/bin/bash
set -euo pipefail

DB_NAME="${DB_NAME:-country_intel}"
PSQL_CMD="${PSQL_CMD:-psql -v ON_ERROR_STOP=1}"

./scripts/load_wdi_live.sh

$PSQL_CMD -d "$DB_NAME" <<'SQL'
DO $$
DECLARE
    latest_batch_key BIGINT;
BEGIN
    SELECT sb.source_batch_key
    INTO latest_batch_key
    FROM raw.source_batch sb
    JOIN ref.source_dataset d ON d.source_dataset_key = sb.source_dataset_key
    WHERE d.dataset_code = 'WDI'
      AND sb.batch_external_id LIKE 'wdi_live_%'
    ORDER BY sb.source_batch_key DESC
    LIMIT 1;

    IF latest_batch_key IS NULL THEN
        RAISE EXCEPTION 'Live WDI contract test failed: no live WDI batch was created';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM raw.source_batch sb
        WHERE sb.source_batch_key = latest_batch_key
          AND sb.request_params_json ? 'api_indicator_codes'
          AND sb.request_params_json ? 'source_series_codes'
          AND sb.request_params_json ? 'countries'
          AND sb.request_params_json ? 'years'
    ) THEN
        RAISE EXCEPTION 'Live WDI contract test failed: latest live WDI batch is missing request lineage fields';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM raw.source_batch sb
        WHERE sb.source_batch_key = latest_batch_key
          AND sb.request_params_json -> 'api_indicator_codes' @> '["NY.GDP.MKTP.CD","NY.GDP.PCAP.CD","FP.CPI.TOTL.ZG","SP.POP.TOTL"]'::jsonb
          AND sb.request_params_json -> 'source_series_codes' @> '["NY.GDP.MKTP.CD","NY.GDP.PCAP.CD","FP.CPI.TOTL.ZG","SP.POP.TOTL"]'::jsonb
    ) THEN
        RAISE EXCEPTION 'Live WDI contract test failed: latest live WDI batch does not declare the expected indicator lineage';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM core.fact_country_indicator_version fv
        JOIN core.dim_indicator di ON di.indicator_key = fv.indicator_key
        JOIN core.dim_dataset dd ON dd.source_dataset_key = fv.source_dataset_key
        WHERE fv.source_batch_key = latest_batch_key
          AND dd.dataset_code = 'WDI'
          AND di.indicator_code IN ('GDP_CURR_USD', 'GDP_PC_CURR_USD', 'INFLATION_CPI_PCT', 'POP_TOTAL')
        GROUP BY fv.source_batch_key
        HAVING COUNT(DISTINCT di.indicator_code) = 4
    ) THEN
        RAISE EXCEPTION 'Live WDI contract test failed: latest live WDI batch did not normalize all four expected WDI indicators';
    END IF;
END;
$$;
SQL

DATASET_CODE=WDI ./scripts/check_pipeline_alerts.sh

echo "Live WDI contract test passed"
