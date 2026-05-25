-- Phase 1 Wave 8 hardening: constraints, indexes, and publish guards
-- This unit tightens the publication contract on top of the landed Phase 1 ref/raw/staging/core/audit/mart spine.

CREATE UNIQUE INDEX IF NOT EXISTS uq_ref_country_iso_alpha_3_active
    ON ref.country (iso_alpha_3);

CREATE UNIQUE INDEX IF NOT EXISTS uq_ref_source_dataset_code_active
    ON ref.source_dataset (source_system_key, dataset_code);

CREATE UNIQUE INDEX IF NOT EXISTS uq_ref_source_series_code_active
    ON ref.source_series (source_dataset_key, series_code);

CREATE UNIQUE INDEX IF NOT EXISTS uq_core_fact_country_indicator_published_active_key
    ON core.fact_country_indicator_published (country_key, indicator_key, time_key);

CREATE UNIQUE INDEX IF NOT EXISTS uq_core_fact_country_indicator_version_scope
    ON core.fact_country_indicator_version (country_key, indicator_key, time_key, source_dataset_key, source_batch_key, staging_row_key);

CREATE INDEX IF NOT EXISTS idx_core_fact_country_indicator_published_query
    ON core.fact_country_indicator_published (indicator_key, country_key, time_key);

CREATE INDEX IF NOT EXISTS idx_core_fact_country_indicator_version_query
    ON core.fact_country_indicator_version (indicator_key, country_key, time_key, source_batch_key DESC);

CREATE INDEX IF NOT EXISTS idx_staging_country_observation_annual_publish_lookup
    ON staging.country_observation_annual (source_batch_key, indicator_key, country_key, observation_year, time_key);

CREATE INDEX IF NOT EXISTS idx_audit_revision_event_year_lookup
    ON audit.revision_event (indicator_key, country_key, time_key, changed_at DESC);

CREATE OR REPLACE FUNCTION etl.assert_phase1_publish_contract(
    p_source_batch_key BIGINT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM core.fact_country_indicator_published fp
        WHERE fp.country_key IS NULL
           OR fp.indicator_key IS NULL
           OR fp.time_key IS NULL
    ) THEN
        RAISE EXCEPTION 'Phase 1 publish guard failed: published business key contains nulls';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM core.fact_country_indicator_published fp
        LEFT JOIN core.dim_dataset dd ON dd.source_dataset_key = fp.source_dataset_key
        WHERE fp.source_dataset_key IS NULL
           OR dd.source_dataset_key IS NULL
           OR fp.source_series_key IS NULL
    ) THEN
        RAISE EXCEPTION 'Phase 1 publish guard failed: published row is missing dataset/series lineage';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM core.fact_country_indicator_published fp
        LEFT JOIN ref.validation_rule vr
          ON vr.rule_code IN (
                'STRUCT_COUNTRY_REQUIRED',
                'STRUCT_INDICATOR_REQUIRED',
                'STRUCT_TIME_REQUIRED',
                'SEM_VALUE_PARSE_FAILED'
             )
         AND vr.is_active = TRUE
        GROUP BY fp.country_key, fp.indicator_key, fp.time_key
        HAVING COUNT(vr.validation_rule_key) < 4
    ) THEN
        RAISE EXCEPTION 'Phase 1 publish guard failed: active validation rule set is incomplete';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ref.indicator i
        WHERE i.is_phase_1 = TRUE
          AND NOT EXISTS (
              SELECT 1
              FROM ref.indicator_source_priority isp
              WHERE isp.indicator_key = i.indicator_key
          )
    ) THEN
        RAISE EXCEPTION 'Phase 1 publish guard failed: Phase 1 indicator is missing source priority';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM staging.country_observation_annual s
        JOIN audit.data_quality_event dqe ON dqe.staging_row_key = s.staging_row_key AND dqe.blocks_publication = TRUE
        JOIN core.fact_country_indicator_published fp
          ON fp.country_key = s.country_key
         AND fp.indicator_key = s.indicator_key
         AND fp.time_key = s.time_key
        WHERE (p_source_batch_key IS NULL OR s.source_batch_key = p_source_batch_key)
    ) THEN
        RAISE EXCEPTION 'Phase 1 publish guard failed: blocking QA row reached published facts';
    END IF;
END;
$$;
