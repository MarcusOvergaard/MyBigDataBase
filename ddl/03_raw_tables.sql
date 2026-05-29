-- Phase 1 Wave 3 raw ingestion lineage contract
-- These tables land append-only WDI observations under the new raw layer.

CREATE TABLE IF NOT EXISTS raw.source_batch (
    source_batch_key BIGSERIAL PRIMARY KEY,
    source_dataset_key BIGINT NOT NULL REFERENCES ref.source_dataset(source_dataset_key),
    batch_external_id VARCHAR(100),
    request_uri TEXT,
    request_params_json JSONB,
    fetched_at TIMESTAMPTZ NOT NULL,
    source_released_at TIMESTAMPTZ,
    checksum_sha256 VARCHAR(64),
    ingest_status VARCHAR(30) NOT NULL,
    row_count_reported INT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_raw_source_batch_status CHECK (
        ingest_status IN ('queued', 'loaded', 'normalized', 'failed')
    )
);

CREATE INDEX IF NOT EXISTS idx_raw_source_batch_dataset_fetched_at
    ON raw.source_batch (source_dataset_key, fetched_at DESC);

CREATE TABLE IF NOT EXISTS raw.source_snapshot (
    source_snapshot_key BIGSERIAL PRIMARY KEY,
    source_batch_key BIGINT NOT NULL REFERENCES raw.source_batch(source_batch_key) ON DELETE CASCADE,
    snapshot_path TEXT NOT NULL,
    content_type VARCHAR(100),
    file_hash_sha256 VARCHAR(64),
    fetched_at TIMESTAMPTZ NOT NULL,
    http_status_code INT,
    source_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_raw_source_snapshot_path UNIQUE (snapshot_path)
);

CREATE INDEX IF NOT EXISTS idx_raw_source_snapshot_batch
    ON raw.source_snapshot (source_batch_key);

CREATE INDEX IF NOT EXISTS idx_raw_source_snapshot_fetched_at
    ON raw.source_snapshot (fetched_at DESC);

CREATE TABLE IF NOT EXISTS raw.wdi_country_indicator_annual (
    raw_row_key BIGSERIAL PRIMARY KEY,
    source_batch_key BIGINT NOT NULL REFERENCES raw.source_batch(source_batch_key),
    country_code_raw VARCHAR(20),
    country_name_raw VARCHAR(150),
    indicator_code_raw VARCHAR(100),
    indicator_name_raw VARCHAR(255),
    year_raw VARCHAR(10) NOT NULL,
    value_raw TEXT,
    obs_status_raw VARCHAR(30),
    decimal_raw VARCHAR(10),
    source_payload_json JSONB,
    loaded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_raw_wdi_country_indicator_annual UNIQUE (
        source_batch_key,
        country_code_raw,
        indicator_code_raw,
        year_raw
    )
);

CREATE INDEX IF NOT EXISTS idx_raw_wdi_country_indicator_annual_batch
    ON raw.wdi_country_indicator_annual (source_batch_key);

CREATE INDEX IF NOT EXISTS idx_raw_wdi_country_indicator_annual_lookup
    ON raw.wdi_country_indicator_annual (country_code_raw, indicator_code_raw, year_raw);

CREATE TABLE IF NOT EXISTS raw.ifs_country_indicator_annual (
    raw_row_key BIGSERIAL PRIMARY KEY,
    source_batch_key BIGINT NOT NULL REFERENCES raw.source_batch(source_batch_key),
    country_code_raw VARCHAR(20),
    country_name_raw VARCHAR(150),
    indicator_code_raw VARCHAR(100),
    indicator_name_raw VARCHAR(255),
    year_raw VARCHAR(10) NOT NULL,
    value_raw TEXT,
    obs_status_raw VARCHAR(30),
    decimal_raw VARCHAR(10),
    source_payload_json JSONB,
    loaded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_raw_ifs_country_indicator_annual UNIQUE (
        source_batch_key,
        country_code_raw,
        indicator_code_raw,
        year_raw
    )
);

CREATE INDEX IF NOT EXISTS idx_raw_ifs_country_indicator_annual_batch
    ON raw.ifs_country_indicator_annual (source_batch_key);

CREATE INDEX IF NOT EXISTS idx_raw_ifs_country_indicator_annual_lookup
    ON raw.ifs_country_indicator_annual (country_code_raw, indicator_code_raw, year_raw);

CREATE TABLE IF NOT EXISTS raw.weo_country_indicator_annual (
    raw_row_key BIGSERIAL PRIMARY KEY,
    source_batch_key BIGINT NOT NULL REFERENCES raw.source_batch(source_batch_key),
    country_code_raw VARCHAR(20),
    country_name_raw VARCHAR(150),
    indicator_code_raw VARCHAR(100),
    indicator_name_raw VARCHAR(255),
    year_raw VARCHAR(10) NOT NULL,
    value_raw TEXT,
    obs_status_raw VARCHAR(30),
    decimal_raw VARCHAR(10),
    source_payload_json JSONB,
    loaded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_raw_weo_country_indicator_annual UNIQUE (
        source_batch_key,
        country_code_raw,
        indicator_code_raw,
        year_raw
    )
);

CREATE INDEX IF NOT EXISTS idx_raw_weo_country_indicator_annual_batch
    ON raw.weo_country_indicator_annual (source_batch_key);

CREATE INDEX IF NOT EXISTS idx_raw_weo_country_indicator_annual_lookup
    ON raw.weo_country_indicator_annual (country_code_raw, indicator_code_raw, year_raw);

CREATE TABLE IF NOT EXISTS raw.ilostat_country_indicator_annual (
    raw_row_key BIGSERIAL PRIMARY KEY,
    source_batch_key BIGINT NOT NULL REFERENCES raw.source_batch(source_batch_key),
    country_code_raw VARCHAR(20),
    country_name_raw VARCHAR(150),
    indicator_code_raw VARCHAR(100),
    indicator_name_raw VARCHAR(255),
    year_raw VARCHAR(10) NOT NULL,
    value_raw TEXT,
    obs_status_raw VARCHAR(30),
    decimal_raw VARCHAR(10),
    source_payload_json JSONB,
    loaded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_raw_ilostat_country_indicator_annual UNIQUE (
        source_batch_key,
        country_code_raw,
        indicator_code_raw,
        year_raw
    )
);

CREATE INDEX IF NOT EXISTS idx_raw_ilostat_country_indicator_annual_batch
    ON raw.ilostat_country_indicator_annual (source_batch_key);

CREATE INDEX IF NOT EXISTS idx_raw_ilostat_country_indicator_annual_lookup
    ON raw.ilostat_country_indicator_annual (country_code_raw, indicator_code_raw, year_raw);

CREATE TABLE IF NOT EXISTS raw.who_country_indicator_annual (
    raw_row_key BIGSERIAL PRIMARY KEY,
    source_batch_key BIGINT NOT NULL REFERENCES raw.source_batch(source_batch_key),
    country_code_raw VARCHAR(20),
    country_name_raw VARCHAR(150),
    indicator_code_raw VARCHAR(100),
    indicator_name_raw VARCHAR(255),
    year_raw VARCHAR(10) NOT NULL,
    value_raw TEXT,
    obs_status_raw VARCHAR(30),
    decimal_raw VARCHAR(10),
    source_payload_json JSONB,
    loaded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_raw_who_country_indicator_annual UNIQUE (
        source_batch_key,
        country_code_raw,
        indicator_code_raw,
        year_raw
    )
);

CREATE INDEX IF NOT EXISTS idx_raw_who_country_indicator_annual_batch
    ON raw.who_country_indicator_annual (source_batch_key);

CREATE INDEX IF NOT EXISTS idx_raw_who_country_indicator_annual_lookup
    ON raw.who_country_indicator_annual (country_code_raw, indicator_code_raw, year_raw);

CREATE TABLE IF NOT EXISTS raw.un_comtrade_country_indicator_annual (
    raw_row_key BIGSERIAL PRIMARY KEY,
    source_batch_key BIGINT NOT NULL REFERENCES raw.source_batch(source_batch_key),
    country_code_raw VARCHAR(20),
    country_name_raw VARCHAR(150),
    indicator_code_raw VARCHAR(100),
    indicator_name_raw VARCHAR(255),
    year_raw VARCHAR(10) NOT NULL,
    value_raw TEXT,
    obs_status_raw VARCHAR(30),
    decimal_raw VARCHAR(10),
    source_payload_json JSONB,
    loaded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_raw_un_comtrade_country_indicator_annual UNIQUE (
        source_batch_key,
        country_code_raw,
        indicator_code_raw,
        year_raw
    )
);

CREATE INDEX IF NOT EXISTS idx_raw_un_comtrade_country_indicator_annual_batch
    ON raw.un_comtrade_country_indicator_annual (source_batch_key);

CREATE INDEX IF NOT EXISTS idx_raw_un_comtrade_country_indicator_annual_lookup
    ON raw.un_comtrade_country_indicator_annual (country_code_raw, indicator_code_raw, year_raw);
