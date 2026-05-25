-- Phase 1 Wave 6 audit and publication control tables
-- These tables give the publish path durable run, QA, revision, publication, and freshness control surfaces.

CREATE TABLE IF NOT EXISTS audit.pipeline_run (
    pipeline_run_key BIGSERIAL PRIMARY KEY,
    pipeline_stage VARCHAR(30) NOT NULL,
    source_dataset_key BIGINT REFERENCES ref.source_dataset(source_dataset_key),
    source_batch_key BIGINT REFERENCES raw.source_batch(source_batch_key),
    started_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMPTZ,
    status_code VARCHAR(30) NOT NULL,
    row_count_in INT,
    row_count_out INT,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_audit_pipeline_run_stage CHECK (
        pipeline_stage IN ('ingest', 'normalize', 'validate', 'publish')
    ),
    CONSTRAINT chk_audit_pipeline_run_status CHECK (
        status_code IN ('running', 'succeeded', 'failed', 'succeeded_with_warnings')
    )
);

CREATE INDEX IF NOT EXISTS idx_audit_pipeline_run_lookup
    ON audit.pipeline_run (pipeline_stage, started_at DESC);

CREATE TABLE IF NOT EXISTS audit.publication_version (
    publication_version_key BIGSERIAL PRIMARY KEY,
    publication_version_code VARCHAR(100) NOT NULL,
    pipeline_run_key BIGINT NOT NULL REFERENCES audit.pipeline_run(pipeline_run_key),
    published_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    code_version_ref VARCHAR(100),
    metadata_rule_version_ref VARCHAR(100),
    publication_notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_audit_publication_version_code UNIQUE (publication_version_code)
);

CREATE TABLE IF NOT EXISTS audit.data_quality_event (
    data_quality_event_key BIGSERIAL PRIMARY KEY,
    pipeline_run_key BIGINT NOT NULL REFERENCES audit.pipeline_run(pipeline_run_key),
    validation_rule_key BIGINT REFERENCES ref.validation_rule(validation_rule_key),
    staging_row_key BIGINT REFERENCES staging.country_observation_annual(staging_row_key),
    source_batch_key BIGINT REFERENCES raw.source_batch(source_batch_key),
    country_key BIGINT REFERENCES ref.country(country_key),
    indicator_key BIGINT REFERENCES ref.indicator(indicator_key),
    observation_year INT,
    severity VARCHAR(20) NOT NULL,
    event_code VARCHAR(50) NOT NULL,
    event_message TEXT NOT NULL,
    detail_json JSONB,
    blocks_publication BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_audit_data_quality_event_severity CHECK (
        severity IN ('error', 'warning', 'info')
    )
);

CREATE INDEX IF NOT EXISTS idx_audit_data_quality_event_lookup
    ON audit.data_quality_event (pipeline_run_key, severity, indicator_key, country_key, observation_year);

CREATE TABLE IF NOT EXISTS audit.revision_event (
    revision_event_key BIGSERIAL PRIMARY KEY,
    pipeline_run_key BIGINT NOT NULL REFERENCES audit.pipeline_run(pipeline_run_key),
    previous_observation_version_key BIGINT REFERENCES core.fact_country_indicator_version(observation_version_key),
    new_observation_version_key BIGINT NOT NULL REFERENCES core.fact_country_indicator_version(observation_version_key),
    country_key BIGINT NOT NULL REFERENCES core.dim_country(country_key),
    indicator_key BIGINT NOT NULL REFERENCES core.dim_indicator(indicator_key),
    time_key BIGINT NOT NULL REFERENCES core.dim_time(time_key),
    source_dataset_key BIGINT NOT NULL REFERENCES core.dim_dataset(source_dataset_key),
    previous_value NUMERIC(20,4),
    new_value NUMERIC(20,4) NOT NULL,
    change_type VARCHAR(30) NOT NULL,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    notes TEXT,
    CONSTRAINT chk_audit_revision_event_change_type CHECK (
        change_type IN ('new_publication', 'source_revision', 'source_selection_change')
    )
);

CREATE INDEX IF NOT EXISTS idx_audit_revision_event_lookup
    ON audit.revision_event (indicator_key, country_key, time_key, changed_at DESC);

CREATE TABLE IF NOT EXISTS audit.dataset_freshness (
    source_dataset_key BIGINT PRIMARY KEY REFERENCES ref.source_dataset(source_dataset_key),
    latest_successful_fetch_at TIMESTAMPTZ,
    latest_source_released_at TIMESTAMPTZ,
    latest_published_at TIMESTAMPTZ,
    latest_published_year INT,
    freshness_status VARCHAR(20) NOT NULL,
    last_pipeline_run_key BIGINT REFERENCES audit.pipeline_run(pipeline_run_key),
    last_source_batch_key BIGINT REFERENCES raw.source_batch(source_batch_key),
    is_stale BOOLEAN NOT NULL DEFAULT FALSE,
    last_error_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_audit_dataset_freshness_status CHECK (
        freshness_status IN ('fresh', 'stale', 'never_published', 'load_failed')
    )
);

CREATE INDEX IF NOT EXISTS idx_audit_dataset_freshness_status
    ON audit.dataset_freshness (freshness_status, latest_published_at DESC);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_core_fact_country_indicator_published_publication_version'
    ) THEN
        ALTER TABLE core.fact_country_indicator_published
        ADD CONSTRAINT fk_core_fact_country_indicator_published_publication_version
        FOREIGN KEY (publication_version_key)
        REFERENCES audit.publication_version(publication_version_key);
    END IF;
END;
$$;
