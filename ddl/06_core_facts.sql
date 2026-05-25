-- Phase 1 Wave 5 conformed core facts
-- These facts build from staged annual observations and preserve both source-version history and the published one-row contract.

CREATE TABLE IF NOT EXISTS core.fact_country_indicator_version (
    observation_version_key BIGSERIAL PRIMARY KEY,
    country_key BIGINT NOT NULL REFERENCES core.dim_country(country_key),
    indicator_key BIGINT NOT NULL REFERENCES core.dim_indicator(indicator_key),
    time_key BIGINT NOT NULL REFERENCES core.dim_time(time_key),
    source_system_key BIGINT NOT NULL REFERENCES core.dim_source(source_system_key),
    source_dataset_key BIGINT NOT NULL REFERENCES core.dim_dataset(source_dataset_key),
    source_series_key BIGINT REFERENCES ref.source_series(source_series_key),
    source_batch_key BIGINT NOT NULL REFERENCES raw.source_batch(source_batch_key),
    staging_row_key BIGINT NOT NULL REFERENCES staging.country_observation_annual(staging_row_key),
    observation_year INT NOT NULL,
    observation_value NUMERIC(20,4) NOT NULL,
    unit_key BIGINT NOT NULL REFERENCES ref.unit(unit_key),
    frequency_code VARCHAR(2) NOT NULL REFERENCES ref.frequency(frequency_code),
    status_code VARCHAR(30) NOT NULL DEFAULT 'published_candidate',
    selection_method VARCHAR(50) NOT NULL DEFAULT 'source_priority_default',
    quality_status VARCHAR(30) NOT NULL DEFAULT 'pass',
    is_latest_source_version BOOLEAN NOT NULL DEFAULT TRUE,
    first_seen_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    superseded_at TIMESTAMPTZ,
    source_released_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_core_fact_country_indicator_version_batch_row UNIQUE (source_batch_key, staging_row_key),
    CONSTRAINT chk_core_fact_country_indicator_version_status CHECK (
        status_code IN ('published_candidate', 'published', 'superseded')
    ),
    CONSTRAINT chk_core_fact_country_indicator_version_quality CHECK (
        quality_status IN ('pass', 'warning')
    ),
    CONSTRAINT chk_core_fact_country_indicator_version_superseded CHECK (
        superseded_at IS NULL OR superseded_at >= first_seen_at
    )
);

CREATE INDEX IF NOT EXISTS idx_core_fact_country_indicator_version_lookup
    ON core.fact_country_indicator_version (indicator_key, country_key, time_key, source_batch_key DESC);

CREATE TABLE IF NOT EXISTS core.fact_country_indicator_published (
    country_key BIGINT NOT NULL REFERENCES core.dim_country(country_key),
    indicator_key BIGINT NOT NULL REFERENCES core.dim_indicator(indicator_key),
    time_key BIGINT NOT NULL REFERENCES core.dim_time(time_key),
    observation_year INT NOT NULL,
    observation_value NUMERIC(20,4) NOT NULL,
    unit_key BIGINT NOT NULL REFERENCES ref.unit(unit_key),
    source_system_key BIGINT NOT NULL REFERENCES core.dim_source(source_system_key),
    source_dataset_key BIGINT NOT NULL REFERENCES core.dim_dataset(source_dataset_key),
    source_series_key BIGINT REFERENCES ref.source_series(source_series_key),
    source_batch_key BIGINT NOT NULL REFERENCES raw.source_batch(source_batch_key),
    observation_version_key BIGINT NOT NULL REFERENCES core.fact_country_indicator_version(observation_version_key),
    selection_method VARCHAR(50) NOT NULL,
    publication_version_key BIGINT,
    published_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_core_fact_country_indicator_published PRIMARY KEY (country_key, indicator_key, time_key)
);

CREATE INDEX IF NOT EXISTS idx_core_fact_country_indicator_published_lineage
    ON core.fact_country_indicator_published (source_dataset_key, source_batch_key, observation_version_key);
