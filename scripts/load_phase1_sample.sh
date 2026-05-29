#!/bin/bash
set -euo pipefail

DB_NAME="${DB_NAME:-country_intel}"
PSQL_CMD="${PSQL_CMD:-psql -v ON_ERROR_STOP=1}"
SAMPLE_CSV="${SAMPLE_CSV:-raw_files/sample_wb_data.csv}"
BATCH_EXTERNAL_ID="${BATCH_EXTERNAL_ID:-sample_wb_data_csv}"

if [[ ! -f "$SAMPLE_CSV" ]]; then
    echo "Sample file not found: $SAMPLE_CSV" >&2
    exit 1
fi

echo "=== Loading Phase 1 sample data into $DB_NAME ==="

$PSQL_CMD -d "$DB_NAME" <<SQL
CREATE TEMP TABLE tmp_wdi_sample (
    country_code TEXT,
    year TEXT,
    gdp_usd TEXT,
    gdp_real_growth_pct TEXT,
    inflation_cpi_pct TEXT,
    population TEXT,
    fertility TEXT,
    life_expectancy TEXT,
    school_enrollment_primary_pct TEXT,
    access_to_electricity_pct TEXT
);

\\copy tmp_wdi_sample FROM '$SAMPLE_CSV' WITH (FORMAT csv, HEADER true);

WITH inserted_batch AS (
    INSERT INTO raw.source_batch (
        source_dataset_key,
        batch_external_id,
        request_uri,
        request_params_json,
        fetched_at,
        source_released_at,
        ingest_status,
        row_count_reported
    )
    SELECT
        d.source_dataset_key,
        '$BATCH_EXTERNAL_ID',
        'local://raw_files/sample_wb_data.csv',
        jsonb_build_object('loader', 'scripts/load_phase1_sample.sh', 'sample_file', '$SAMPLE_CSV'),
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP,
        'queued',
        NULL
    FROM ref.source_dataset d
    WHERE d.dataset_code = 'WDI'
    RETURNING source_batch_key
)
SELECT source_batch_key FROM inserted_batch \gset

INSERT INTO raw.wdi_country_indicator_annual (
    source_batch_key,
    country_code_raw,
    country_name_raw,
    indicator_code_raw,
    indicator_name_raw,
    year_raw,
    value_raw,
    obs_status_raw,
    decimal_raw,
    source_payload_json
)
SELECT
    :source_batch_key,
    s.country_code,
    NULL,
    v.indicator_code_raw,
    v.indicator_name_raw,
    s.year,
    v.value_raw,
    NULL,
    NULL,
    jsonb_build_object(
        'sample_file', '$SAMPLE_CSV',
        'country_code', s.country_code,
        'year', s.year,
        'measure_column', v.measure_column
    )
FROM tmp_wdi_sample s
CROSS JOIN LATERAL (
    VALUES
        ('NY.GDP.MKTP.CD', 'GDP (current US$)', s.gdp_usd, 'gdp_usd'),
        (
            'NY.GDP.PCAP.CD',
            'GDP per capita (current US$)',
            CASE
                WHEN NULLIF(BTRIM(s.gdp_usd), '') IS NOT NULL
                 AND NULLIF(BTRIM(s.population), '') IS NOT NULL
                 AND BTRIM(s.gdp_usd) ~ '^[+-]?[0-9]+(\.[0-9]+)?$'
                 AND BTRIM(s.population) ~ '^[+-]?[0-9]+(\.[0-9]+)?$'
                 AND BTRIM(s.population)::NUMERIC <> 0
                    THEN ROUND((BTRIM(s.gdp_usd)::NUMERIC / BTRIM(s.population)::NUMERIC), 4)::TEXT
                ELSE NULL
            END,
            'derived_gdp_per_capita'
        ),
        ('FP.CPI.TOTL.ZG', 'Inflation, consumer prices (annual %)', s.inflation_cpi_pct, 'inflation_cpi_pct'),
        ('SP.POP.TOTL', 'Population, total', s.population, 'population'),
        ('SP.DYN.TFRT.IN', 'Fertility rate, total (births per woman)', s.fertility, 'fertility'),
        ('SP.DYN.LE00.IN', 'Life expectancy at birth, total (years)', s.life_expectancy, 'life_expectancy'),
        ('SE.PRM.ENRR', 'School enrollment, primary (% gross)', s.school_enrollment_primary_pct, 'school_enrollment_primary_pct'),
        ('EG.ELC.ACCS.ZS', 'Access to electricity (% of population)', s.access_to_electricity_pct, 'access_to_electricity_pct')
) AS v(indicator_code_raw, indicator_name_raw, value_raw, measure_column);

UPDATE raw.source_batch
SET row_count_reported = (
        SELECT COUNT(*)
        FROM raw.wdi_country_indicator_annual
        WHERE source_batch_key = :source_batch_key
    ),
    ingest_status = 'loaded'
WHERE source_batch_key = :source_batch_key;

CALL staging.normalize_wdi_country_observation_annual(:source_batch_key);

UPDATE raw.source_batch
SET ingest_status = 'normalized'
WHERE source_batch_key = :source_batch_key;

CALL etl.publish_phase1_country_indicator_facts(:source_batch_key);
SQL

echo "=== Phase 1 sample load complete ==="
