-- Phase 1 Wave 1 metadata contract
-- These tables establish the dependency base for the later raw/staging/core migration.

CREATE TABLE IF NOT EXISTS ref.country (
    country_key BIGSERIAL PRIMARY KEY,
    iso_alpha_2 VARCHAR(2),
    iso_alpha_3 VARCHAR(3) NOT NULL,
    iso_numeric VARCHAR(3),
    country_name VARCHAR(100) NOT NULL,
    region_name VARCHAR(100),
    income_group VARCHAR(100),
    is_aggregate BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    valid_from DATE,
    valid_to DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_ref_country_iso_alpha_3 UNIQUE (iso_alpha_3)
);

CREATE TABLE IF NOT EXISTS ref.unit (
    unit_key BIGSERIAL PRIMARY KEY,
    unit_code VARCHAR(40) NOT NULL,
    unit_name VARCHAR(100) NOT NULL,
    unit_category VARCHAR(50) NOT NULL,
    decimal_precision_default INT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_ref_unit_code UNIQUE (unit_code)
);

CREATE TABLE IF NOT EXISTS ref.frequency (
    frequency_code VARCHAR(2) PRIMARY KEY,
    frequency_name VARCHAR(50) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS ref.source_system (
    source_system_key BIGSERIAL PRIMARY KEY,
    source_code VARCHAR(30) NOT NULL,
    source_name VARCHAR(100) NOT NULL,
    publisher_type VARCHAR(50),
    base_url VARCHAR(255),
    access_method VARCHAR(50),
    license_notes TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_ref_source_system_code UNIQUE (source_code)
);

CREATE TABLE IF NOT EXISTS ref.source_dataset (
    source_dataset_key BIGSERIAL PRIMARY KEY,
    source_system_key BIGINT NOT NULL REFERENCES ref.source_system(source_system_key),
    dataset_code VARCHAR(50) NOT NULL,
    dataset_name VARCHAR(150) NOT NULL,
    default_frequency_code VARCHAR(2) REFERENCES ref.frequency(frequency_code),
    default_grain VARCHAR(50),
    release_cadence VARCHAR(50),
    access_path VARCHAR(255),
    ingest_access_method VARCHAR(30),
    ingest_base_endpoint VARCHAR(255),
    ingest_default_format VARCHAR(20),
    ingest_requires_auth BOOLEAN NOT NULL DEFAULT FALSE,
    ingest_cadence_note TEXT,
    is_active_for_ingest BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_ref_source_dataset_code UNIQUE (source_system_key, dataset_code)
);

ALTER TABLE ref.source_dataset
    ADD COLUMN IF NOT EXISTS ingest_access_method VARCHAR(30),
    ADD COLUMN IF NOT EXISTS ingest_base_endpoint VARCHAR(255),
    ADD COLUMN IF NOT EXISTS ingest_default_format VARCHAR(20),
    ADD COLUMN IF NOT EXISTS ingest_requires_auth BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS ingest_cadence_note TEXT,
    ADD COLUMN IF NOT EXISTS is_active_for_ingest BOOLEAN NOT NULL DEFAULT FALSE;

CREATE TABLE IF NOT EXISTS ref.source_series (
    source_series_key BIGSERIAL PRIMARY KEY,
    source_dataset_key BIGINT NOT NULL REFERENCES ref.source_dataset(source_dataset_key),
    series_code VARCHAR(100) NOT NULL,
    series_name VARCHAR(255) NOT NULL,
    source_unit_text VARCHAR(100),
    source_frequency_code VARCHAR(2) REFERENCES ref.frequency(frequency_code),
    coverage_notes TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_ref_source_series_code UNIQUE (source_dataset_key, series_code)
);

CREATE TABLE IF NOT EXISTS ref.source_series_alias (
    source_series_alias_key BIGSERIAL PRIMARY KEY,
    source_series_key BIGINT NOT NULL REFERENCES ref.source_series(source_series_key),
    alias_type VARCHAR(50) NOT NULL,
    alias_code VARCHAR(100) NOT NULL,
    alias_label VARCHAR(255),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_ref_source_series_alias_scope UNIQUE (source_series_key, alias_type),
    CONSTRAINT uq_ref_source_series_alias_code UNIQUE (alias_type, alias_code)
);

CREATE TABLE IF NOT EXISTS ref.indicator (
    indicator_key BIGSERIAL PRIMARY KEY,
    indicator_code VARCHAR(50) NOT NULL,
    indicator_name VARCHAR(255) NOT NULL,
    topic VARCHAR(100) NOT NULL,
    default_unit_key BIGINT NOT NULL REFERENCES ref.unit(unit_key),
    default_frequency_code VARCHAR(2) NOT NULL REFERENCES ref.frequency(frequency_code),
    value_datatype VARCHAR(30) NOT NULL DEFAULT 'numeric',
    preferred_aggregation VARCHAR(30),
    is_phase_1 BOOLEAN NOT NULL DEFAULT FALSE,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_ref_indicator_code UNIQUE (indicator_code)
);

CREATE TABLE IF NOT EXISTS ref.validation_rule (
    validation_rule_key BIGSERIAL PRIMARY KEY,
    rule_code VARCHAR(50) NOT NULL,
    rule_name VARCHAR(150) NOT NULL,
    rule_category VARCHAR(50) NOT NULL,
    severity VARCHAR(20) NOT NULL,
    target_layer VARCHAR(30) NOT NULL,
    rule_description TEXT,
    blocks_publication BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_ref_validation_rule_code UNIQUE (rule_code),
    CONSTRAINT chk_ref_validation_rule_severity CHECK (
        severity IN ('error', 'warning', 'info')
    )
);

CREATE TABLE IF NOT EXISTS ref.indicator_source_series_map (
    indicator_source_series_map_key BIGSERIAL PRIMARY KEY,
    indicator_key BIGINT NOT NULL REFERENCES ref.indicator(indicator_key),
    source_series_key BIGINT NOT NULL REFERENCES ref.source_series(source_series_key),
    mapping_notes TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_ref_indicator_source_series_map UNIQUE (indicator_key, source_series_key)
);

CREATE TABLE IF NOT EXISTS ref.indicator_source_priority (
    indicator_source_priority_key BIGSERIAL PRIMARY KEY,
    indicator_key BIGINT NOT NULL REFERENCES ref.indicator(indicator_key),
    source_dataset_key BIGINT NOT NULL REFERENCES ref.source_dataset(source_dataset_key),
    country_key BIGINT REFERENCES ref.country(country_key),
    priority_rank INT NOT NULL,
    valid_from_year INT,
    valid_to_year INT,
    effective_from DATE,
    effective_to DATE,
    release_window_code VARCHAR(30),
    selection_rationale TEXT,
    is_override BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_ref_indicator_source_priority_years CHECK (
        valid_from_year IS NULL OR valid_to_year IS NULL OR valid_from_year <= valid_to_year
    ),
    CONSTRAINT chk_ref_indicator_source_priority_effective_dates CHECK (
        effective_from IS NULL OR effective_to IS NULL OR effective_from <= effective_to
    ),
    CONSTRAINT uq_ref_indicator_source_priority_scope UNIQUE (
        indicator_key,
        source_dataset_key,
        country_key,
        valid_from_year,
        effective_from,
        release_window_code
    )
);

CREATE INDEX IF NOT EXISTS idx_ref_indicator_source_priority_lookup
    ON ref.indicator_source_priority (indicator_key, country_key, priority_rank, valid_from_year, valid_to_year);
