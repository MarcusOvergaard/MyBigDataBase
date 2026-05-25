-- Phase 1 Wave 2 conformed core dimensions
-- These dimensions build forward from the new ref contract and are shaped for the later fact slices.

CREATE TABLE IF NOT EXISTS core.dim_country (
    country_key BIGINT PRIMARY KEY REFERENCES ref.country(country_key),
    iso_alpha_3 VARCHAR(3) NOT NULL,
    country_name VARCHAR(100) NOT NULL,
    region_name VARCHAR(100),
    income_group VARCHAR(100),
    is_aggregate BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_core_dim_country_iso_alpha_3 UNIQUE (iso_alpha_3)
);

CREATE TABLE IF NOT EXISTS core.dim_source (
    source_system_key BIGINT PRIMARY KEY REFERENCES ref.source_system(source_system_key),
    source_code VARCHAR(30) NOT NULL,
    source_name VARCHAR(100) NOT NULL,
    publisher_type VARCHAR(50),
    base_url VARCHAR(255),
    access_method VARCHAR(50),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_core_dim_source_code UNIQUE (source_code)
);

CREATE TABLE IF NOT EXISTS core.dim_dataset (
    source_dataset_key BIGINT PRIMARY KEY REFERENCES ref.source_dataset(source_dataset_key),
    source_system_key BIGINT NOT NULL REFERENCES core.dim_source(source_system_key),
    dataset_code VARCHAR(50) NOT NULL,
    dataset_name VARCHAR(150) NOT NULL,
    default_frequency_code VARCHAR(2) REFERENCES ref.frequency(frequency_code),
    default_grain VARCHAR(50),
    release_cadence VARCHAR(50),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_core_dim_dataset_code UNIQUE (source_system_key, dataset_code)
);

CREATE TABLE IF NOT EXISTS core.dim_indicator (
    indicator_key BIGINT PRIMARY KEY REFERENCES ref.indicator(indicator_key),
    indicator_code VARCHAR(50) NOT NULL,
    indicator_name VARCHAR(255) NOT NULL,
    topic VARCHAR(100) NOT NULL,
    default_unit_key BIGINT NOT NULL REFERENCES ref.unit(unit_key),
    default_unit_code VARCHAR(40) NOT NULL,
    default_unit_name VARCHAR(100) NOT NULL,
    default_frequency_code VARCHAR(2) NOT NULL REFERENCES ref.frequency(frequency_code),
    value_datatype VARCHAR(30) NOT NULL,
    preferred_aggregation VARCHAR(30),
    is_phase_1 BOOLEAN NOT NULL DEFAULT FALSE,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_core_dim_indicator_code UNIQUE (indicator_code)
);

CREATE TABLE IF NOT EXISTS core.dim_time (
    time_key BIGSERIAL PRIMARY KEY,
    period_type VARCHAR(10) NOT NULL,
    calendar_year INT NOT NULL,
    quarter_number INT,
    month_number INT,
    period_start_date DATE NOT NULL,
    period_end_date DATE NOT NULL,
    period_label VARCHAR(30) NOT NULL,
    is_year_end BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_core_dim_time_period_type CHECK (period_type IN ('annual', 'quarterly', 'monthly')),
    CONSTRAINT chk_core_dim_time_period_order CHECK (period_start_date <= period_end_date),
    CONSTRAINT chk_core_dim_time_annual_shape CHECK (
        period_type <> 'annual'
        OR (quarter_number IS NULL AND month_number IS NULL)
    ),
    CONSTRAINT chk_core_dim_time_quarterly_shape CHECK (
        period_type <> 'quarterly'
        OR (quarter_number BETWEEN 1 AND 4 AND month_number IS NULL)
    ),
    CONSTRAINT chk_core_dim_time_monthly_shape CHECK (
        period_type <> 'monthly'
        OR (month_number BETWEEN 1 AND 12)
    ),
    CONSTRAINT uq_core_dim_time_period UNIQUE (period_type, calendar_year, quarter_number, month_number),
    CONSTRAINT uq_core_dim_time_period_label UNIQUE (period_label)
);

CREATE INDEX IF NOT EXISTS idx_core_dim_time_lookup
    ON core.dim_time (period_type, calendar_year, quarter_number, month_number);
