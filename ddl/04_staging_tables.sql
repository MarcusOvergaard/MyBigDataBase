-- Phase 1 Wave 4 normalized staging contract
-- This stage builds forward from ref metadata and preserves mapping / missingness / parse outcomes.

CREATE TABLE IF NOT EXISTS staging.country_observation_annual (
    staging_row_key BIGSERIAL PRIMARY KEY,
    source_batch_key BIGINT NOT NULL REFERENCES raw.source_batch(source_batch_key),
    raw_row_key BIGINT NOT NULL,
    source_dataset_key BIGINT NOT NULL REFERENCES ref.source_dataset(source_dataset_key),
    source_series_key BIGINT REFERENCES ref.source_series(source_series_key),
    country_key BIGINT REFERENCES ref.country(country_key),
    indicator_key BIGINT REFERENCES ref.indicator(indicator_key),
    time_key BIGINT REFERENCES core.dim_time(time_key),
    observation_year INT,
    observation_value NUMERIC(20, 4),
    raw_value_text TEXT,
    unit_key BIGINT REFERENCES ref.unit(unit_key),
    frequency_code VARCHAR(2) NOT NULL REFERENCES ref.frequency(frequency_code),
    mapping_status VARCHAR(40) NOT NULL,
    missingness_status VARCHAR(40) NOT NULL,
    is_parse_error BOOLEAN NOT NULL DEFAULT FALSE,
    is_country_mapped BOOLEAN NOT NULL DEFAULT FALSE,
    is_indicator_mapped BOOLEAN NOT NULL DEFAULT FALSE,
    quality_flags TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    normalized_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_staging_country_observation_annual UNIQUE (source_batch_key, raw_row_key),
    CONSTRAINT chk_staging_country_observation_annual_mapping_status CHECK (
        mapping_status IN ('mapped', 'country_unmapped', 'indicator_unmapped', 'country_and_indicator_unmapped')
    ),
    CONSTRAINT chk_staging_country_observation_annual_missingness_status CHECK (
        missingness_status IN ('observed', 'missing_at_source', 'parse_failed')
    )
);

CREATE INDEX IF NOT EXISTS idx_staging_country_observation_annual_batch
    ON staging.country_observation_annual (source_batch_key, observation_year);

CREATE INDEX IF NOT EXISTS idx_staging_country_observation_annual_mapping
    ON staging.country_observation_annual (country_key, indicator_key, observation_year, time_key);
