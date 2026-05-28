-- Phase 1 canonical-contract follow-through
-- This unit turns the approved canonical schema package into additive SQL surfaces on top of the landed Phase 1 path.

ALTER TABLE staging.country_observation_annual
    DROP CONSTRAINT IF EXISTS country_observation_annual_raw_row_key_fkey;

DROP VIEW IF EXISTS mart.vw_phase2_dataset_status_history_scan CASCADE;
DROP VIEW IF EXISTS mart.mart_phase2_dataset_status_history CASCADE;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'audit'
          AND table_name = 'pipeline_run'
          AND column_name = 'status_code'
          AND (
              data_type <> 'character varying'
              OR character_maximum_length IS DISTINCT FROM 30
          )
    ) THEN
        ALTER TABLE audit.pipeline_run
            ALTER COLUMN status_code TYPE VARCHAR(30);
    END IF;
END $$;

ALTER TABLE core.fact_country_indicator_version
    ADD COLUMN IF NOT EXISTS comparability_break_flag BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS comparability_break_note TEXT,
    ADD COLUMN IF NOT EXISTS selection_rule_version_ref VARCHAR(100),
    ADD COLUMN IF NOT EXISTS selection_rule_key_snapshot JSONB;

ALTER TABLE core.fact_country_indicator_published
    ADD COLUMN IF NOT EXISTS comparability_break_flag BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS comparability_break_note TEXT,
    ADD COLUMN IF NOT EXISTS source_switch_flag BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS selection_rule_version_ref VARCHAR(100);

UPDATE core.fact_country_indicator_version
SET comparability_break_flag = COALESCE(comparability_break_flag, FALSE),
    selection_rule_version_ref = COALESCE(selection_rule_version_ref, 'phase1_pre_canonical_contract_followthrough')
WHERE comparability_break_flag IS DISTINCT FROM COALESCE(comparability_break_flag, FALSE)
   OR selection_rule_version_ref IS NULL;

WITH version_rule_backfill AS (
    SELECT
        fv.observation_version_key,
        jsonb_build_object(
            'indicator_source_priority_key', isp.indicator_source_priority_key,
            'priority_rank', isp.priority_rank,
            'is_override', isp.is_override,
            'selection_rationale', isp.selection_rationale,
            'valid_from_year', isp.valid_from_year,
            'valid_to_year', isp.valid_to_year,
            'effective_from', isp.effective_from,
            'effective_to', isp.effective_to,
            'release_window_code', isp.release_window_code,
            'backfilled_by', 'ddl/10_canonical_contract_followthrough.sql'
        ) AS selection_rule_key_snapshot
    FROM core.fact_country_indicator_version fv
    LEFT JOIN LATERAL (
        SELECT isp.*
        FROM ref.indicator_source_priority isp
        WHERE isp.indicator_key = fv.indicator_key
          AND isp.source_dataset_key = fv.source_dataset_key
          AND (isp.country_key IS NULL OR isp.country_key = fv.country_key)
          AND (isp.valid_from_year IS NULL OR fv.observation_year >= isp.valid_from_year)
          AND (isp.valid_to_year IS NULL OR fv.observation_year <= isp.valid_to_year)
          AND (isp.effective_from IS NULL OR COALESCE(fv.source_released_at::date, fv.first_seen_at::date) >= isp.effective_from)
          AND (isp.effective_to IS NULL OR COALESCE(fv.source_released_at::date, fv.first_seen_at::date) <= isp.effective_to)
        ORDER BY isp.is_override DESC, isp.priority_rank ASC, isp.indicator_source_priority_key ASC
        LIMIT 1
    ) isp ON TRUE
    WHERE fv.selection_rule_key_snapshot IS NULL
)
UPDATE core.fact_country_indicator_version fv
SET selection_rule_key_snapshot = vrb.selection_rule_key_snapshot
FROM version_rule_backfill vrb
WHERE fv.observation_version_key = vrb.observation_version_key
  AND vrb.selection_rule_key_snapshot IS NOT NULL;

UPDATE core.fact_country_indicator_published
SET comparability_break_flag = COALESCE(comparability_break_flag, FALSE),
    source_switch_flag = COALESCE(source_switch_flag, FALSE),
    selection_rule_version_ref = COALESCE(selection_rule_version_ref, 'phase1_pre_canonical_contract_followthrough')
WHERE comparability_break_flag IS DISTINCT FROM COALESCE(comparability_break_flag, FALSE)
   OR source_switch_flag IS DISTINCT FROM COALESCE(source_switch_flag, FALSE)
   OR selection_rule_version_ref IS NULL;

CREATE INDEX IF NOT EXISTS idx_core_fact_country_indicator_version_rule_version
    ON core.fact_country_indicator_version (selection_rule_version_ref, indicator_key, country_key, time_key);

CREATE INDEX IF NOT EXISTS idx_core_fact_country_indicator_published_rule_version
    ON core.fact_country_indicator_published (selection_rule_version_ref, source_switch_flag, indicator_key, country_key, time_key);

CREATE OR REPLACE VIEW mart.vw_macro_published_with_lineage AS
SELECT
    fp.country_key,
    dc.iso_alpha_3,
    dc.country_name,
    fp.indicator_key,
    di.indicator_code,
    di.indicator_name,
    fp.time_key,
    dt.calendar_year AS observation_year,
    dt.period_label,
    fp.observation_value,
    fp.unit_key,
    di.default_unit_code AS unit_code,
    di.default_unit_name AS unit_name,
    fp.source_system_key,
    ds.source_code,
    ds.source_name,
    fp.source_dataset_key,
    dd.dataset_code,
    dd.dataset_name,
    fp.source_series_key,
    rs.series_code,
    rs.series_name,
    fp.source_batch_key,
    sb.batch_external_id,
    sb.fetched_at,
    sb.source_released_at,
    fp.observation_version_key,
    fp.selection_method,
    fp.publication_version_key,
    pv.publication_version_code,
    pv.published_at AS publication_version_published_at,
    fp.published_at,
    fp.selection_rule_version_ref,
    pv.metadata_rule_version_ref,
    fp.comparability_break_flag,
    fp.comparability_break_note,
    fp.source_switch_flag,
    fv.selection_rule_key_snapshot
FROM core.fact_country_indicator_published fp
JOIN core.dim_country dc ON dc.country_key = fp.country_key
JOIN core.dim_indicator di ON di.indicator_key = fp.indicator_key
JOIN core.dim_time dt ON dt.time_key = fp.time_key
JOIN core.dim_source ds ON ds.source_system_key = fp.source_system_key
JOIN core.dim_dataset dd ON dd.source_dataset_key = fp.source_dataset_key
JOIN raw.source_batch sb ON sb.source_batch_key = fp.source_batch_key
LEFT JOIN ref.source_series rs ON rs.source_series_key = fp.source_series_key
LEFT JOIN audit.publication_version pv ON pv.publication_version_key = fp.publication_version_key
LEFT JOIN core.fact_country_indicator_version fv ON fv.observation_version_key = fp.observation_version_key;

CREATE OR REPLACE VIEW mart.vw_macro_revision_history AS
SELECT
    re.revision_event_key,
    re.changed_at,
    re.change_type,
    dc.iso_alpha_3,
    dc.country_name,
    di.indicator_code,
    di.indicator_name,
    dt.calendar_year AS observation_year,
    re.previous_value,
    re.new_value,
    prev_v.source_batch_key AS previous_source_batch_key,
    new_v.source_batch_key AS new_source_batch_key,
    prev_ds.dataset_code AS previous_dataset_code,
    new_ds.dataset_code AS new_dataset_code,
    apr.pipeline_run_key,
    apr.status_code AS pipeline_run_status,
    re.notes,
    prev_v.selection_rule_version_ref AS previous_selection_rule_version_ref,
    new_v.selection_rule_version_ref AS new_selection_rule_version_ref,
    new_v.comparability_break_flag AS new_comparability_break_flag,
    new_v.comparability_break_note AS new_comparability_break_note
FROM audit.revision_event re
JOIN core.dim_country dc ON dc.country_key = re.country_key
JOIN core.dim_indicator di ON di.indicator_key = re.indicator_key
JOIN core.dim_time dt ON dt.time_key = re.time_key
JOIN audit.pipeline_run apr ON apr.pipeline_run_key = re.pipeline_run_key
LEFT JOIN core.fact_country_indicator_version prev_v ON prev_v.observation_version_key = re.previous_observation_version_key
LEFT JOIN core.fact_country_indicator_version new_v ON new_v.observation_version_key = re.new_observation_version_key
LEFT JOIN core.dim_dataset prev_ds ON prev_ds.source_dataset_key = prev_v.source_dataset_key
LEFT JOIN core.dim_dataset new_ds ON new_ds.source_dataset_key = new_v.source_dataset_key;

CREATE OR REPLACE VIEW mart.vw_macro_source_selection_lineage AS
SELECT
    fp.country_key,
    dc.iso_alpha_3,
    dc.country_name,
    fp.indicator_key,
    di.indicator_code,
    di.indicator_name,
    fp.time_key,
    dt.calendar_year AS observation_year,
    fp.observation_value,
    fp.source_system_key,
    ds.source_code,
    fp.source_dataset_key,
    dd.dataset_code,
    dd.dataset_name,
    fp.source_series_key,
    rs.series_code,
    rs.series_name,
    fp.selection_method,
    fp.selection_rule_version_ref,
    fp.source_switch_flag,
    fp.comparability_break_flag,
    fp.comparability_break_note,
    COALESCE((fv.selection_rule_key_snapshot ->> 'indicator_source_priority_key')::BIGINT, NULL) AS indicator_source_priority_key,
    COALESCE((fv.selection_rule_key_snapshot ->> 'priority_rank')::INT, NULL) AS priority_rank,
    COALESCE((fv.selection_rule_key_snapshot ->> 'is_override')::BOOLEAN, FALSE) AS is_override,
    fv.selection_rule_key_snapshot ->> 'selection_rationale' AS selection_rationale,
    COALESCE((fv.selection_rule_key_snapshot ->> 'valid_from_year')::INT, NULL) AS rule_valid_from_year,
    COALESCE((fv.selection_rule_key_snapshot ->> 'valid_to_year')::INT, NULL) AS rule_valid_to_year,
    COALESCE((fv.selection_rule_key_snapshot ->> 'effective_from')::DATE, NULL) AS rule_effective_from,
    COALESCE((fv.selection_rule_key_snapshot ->> 'effective_to')::DATE, NULL) AS rule_effective_to,
    fv.selection_rule_key_snapshot ->> 'release_window_code' AS rule_release_window_code,
    fv.selection_rule_key_snapshot,
    pv.publication_version_code,
    pv.metadata_rule_version_ref,
    fp.observation_version_key,
    fp.published_at
FROM core.fact_country_indicator_published fp
JOIN core.dim_country dc ON dc.country_key = fp.country_key
JOIN core.dim_indicator di ON di.indicator_key = fp.indicator_key
JOIN core.dim_time dt ON dt.time_key = fp.time_key
JOIN core.dim_source ds ON ds.source_system_key = fp.source_system_key
JOIN core.dim_dataset dd ON dd.source_dataset_key = fp.source_dataset_key
LEFT JOIN ref.source_series rs ON rs.source_series_key = fp.source_series_key
LEFT JOIN core.fact_country_indicator_version fv ON fv.observation_version_key = fp.observation_version_key
LEFT JOIN audit.publication_version pv ON pv.publication_version_key = fp.publication_version_key;

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
    ) THEN
        RAISE EXCEPTION 'Phase 1 publish guard failed: published row is missing required dataset lineage';
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

    IF EXISTS (
        SELECT 1
        FROM core.fact_country_indicator_published fp
        LEFT JOIN audit.publication_version pv ON pv.publication_version_key = fp.publication_version_key
        WHERE fp.selection_rule_version_ref IS NULL
           OR pv.publication_version_key IS NULL
           OR pv.metadata_rule_version_ref IS NULL
           OR fp.selection_rule_version_ref <> pv.metadata_rule_version_ref
    ) THEN
        RAISE EXCEPTION 'Phase 1 publish guard failed: published row is missing queryable rule-version lineage';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM core.fact_country_indicator_published fp
        WHERE fp.comparability_break_flag = TRUE
          AND COALESCE(NULLIF(BTRIM(fp.comparability_break_note), ''), '') = ''
    ) THEN
        RAISE EXCEPTION 'Phase 1 publish guard failed: comparability break flag requires an explanatory note';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM core.fact_country_indicator_published fp
        WHERE fp.source_switch_flag = TRUE
          AND NOT EXISTS (
              SELECT 1
              FROM audit.revision_event re
              WHERE re.new_observation_version_key = fp.observation_version_key
                AND re.change_type = 'source_selection_change'
          )
    ) THEN
        RAISE EXCEPTION 'Phase 1 publish guard failed: source-switch flag is not backed by a source-selection revision event';
    END IF;
END;
$$;

-- Recreate the shared Phase 2 status-history views after widening audit.pipeline_run.status_code; \ir anchors the path to this script.
\ir fragments/phase2_dataset_status_history_views.sql
