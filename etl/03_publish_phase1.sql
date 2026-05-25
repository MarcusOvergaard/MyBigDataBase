-- Phase 1 fact publication logic built on top of the new staging/core/audit contract.
-- This stays deliberately narrow: version history + published surface + durable audit/publication controls.

CREATE OR REPLACE PROCEDURE etl.publish_phase1_country_indicator_facts(
    p_source_batch_key BIGINT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_pipeline_run_key BIGINT;
    v_publication_version_key BIGINT;
    v_publication_version_code TEXT;
    v_metadata_rule_version_ref TEXT := 'canonical_schema_v0_rule_contract_v1';
    v_rows_in INT := 0;
    v_rows_out INT := 0;
    v_dq_event_count INT := 0;
    v_revision_event_count INT := 0;
    v_dataset_scope_key BIGINT := NULL;
BEGIN
    IF p_source_batch_key IS NOT NULL THEN
        SELECT source_dataset_key
        INTO v_dataset_scope_key
        FROM raw.source_batch
        WHERE source_batch_key = p_source_batch_key;
    END IF;

    INSERT INTO audit.pipeline_run (
        pipeline_stage,
        source_dataset_key,
        source_batch_key,
        started_at,
        status_code,
        notes
    )
    VALUES (
        'publish',
        v_dataset_scope_key,
        p_source_batch_key,
        CURRENT_TIMESTAMP,
        'running',
        'Phase 1 publish procedure for version, published, and audit control surfaces.'
    )
    RETURNING pipeline_run_key INTO v_pipeline_run_key;

    v_publication_version_code := CONCAT(
        'phase1_pub_',
        TO_CHAR(CURRENT_TIMESTAMP, 'YYYYMMDDHH24MISSMS'),
        CASE
            WHEN p_source_batch_key IS NULL THEN '_all'
            ELSE CONCAT('_batch_', p_source_batch_key::TEXT)
        END
    );

    INSERT INTO audit.publication_version (
        publication_version_code,
        pipeline_run_key,
        published_at,
        code_version_ref,
        metadata_rule_version_ref,
        publication_notes
    )
    VALUES (
        v_publication_version_code,
        v_pipeline_run_key,
        CURRENT_TIMESTAMP,
        'phase1_repo_transition',
        v_metadata_rule_version_ref,
        'Phase 1 publish path on top of conformed version/published facts.'
    )
    RETURNING publication_version_key INTO v_publication_version_key;

    CREATE TEMP TABLE tmp_publish_scope_staging ON COMMIT DROP AS
    SELECT s.*
    FROM staging.country_observation_annual s
    WHERE p_source_batch_key IS NULL OR s.source_batch_key = p_source_batch_key;

    GET DIAGNOSTICS v_rows_in = ROW_COUNT;

    INSERT INTO audit.data_quality_event (
        pipeline_run_key,
        validation_rule_key,
        staging_row_key,
        source_batch_key,
        country_key,
        indicator_key,
        observation_year,
        severity,
        event_code,
        event_message,
        detail_json,
        blocks_publication
    )
    SELECT
        v_pipeline_run_key,
        vr.validation_rule_key,
        s.staging_row_key,
        s.source_batch_key,
        s.country_key,
        s.indicator_key,
        s.observation_year,
        vr.severity,
        vr.rule_code,
        vr.rule_name,
        jsonb_build_object(
            'mapping_status', s.mapping_status,
            'missingness_status', s.missingness_status,
            'quality_flags', s.quality_flags,
            'is_parse_error', s.is_parse_error,
            'time_key', s.time_key
        ),
        vr.blocks_publication
    FROM tmp_publish_scope_staging s
    JOIN ref.validation_rule vr
      ON vr.rule_code = CASE
            WHEN s.country_key IS NULL THEN 'STRUCT_COUNTRY_REQUIRED'
            WHEN s.indicator_key IS NULL THEN 'STRUCT_INDICATOR_REQUIRED'
            WHEN s.time_key IS NULL THEN 'STRUCT_TIME_REQUIRED'
            WHEN s.is_parse_error THEN 'SEM_VALUE_PARSE_FAILED'
            WHEN s.missingness_status = 'missing_at_source' THEN 'SEM_VALUE_MISSING'
            ELSE NULL
         END
    WHERE s.mapping_status <> 'mapped'
       OR s.missingness_status <> 'observed'
       OR s.is_parse_error = TRUE
       OR s.time_key IS NULL;

    GET DIAGNOSTICS v_dq_event_count = ROW_COUNT;

    CREATE TEMP TABLE tmp_eligible_staging ON COMMIT DROP AS
    SELECT
        s.staging_row_key,
        s.country_key,
        s.indicator_key,
        s.time_key,
        s.observation_year,
        s.observation_value,
        s.unit_key,
        s.frequency_code,
        s.source_series_key,
        s.source_dataset_key,
        s.source_batch_key,
        sb.source_released_at,
        ds.source_system_key,
        COALESCE(
            CASE WHEN isp.is_override THEN 'source_priority_override' END,
            CASE WHEN isp.priority_rank = 1 THEN 'source_priority_default' END,
            'source_priority_ranked'
        ) AS selection_method,
        jsonb_build_object(
            'indicator_source_priority_key', isp.indicator_source_priority_key,
            'priority_rank', isp.priority_rank,
            'is_override', isp.is_override,
            'selection_rationale', isp.selection_rationale,
            'valid_from_year', isp.valid_from_year,
            'valid_to_year', isp.valid_to_year,
            'effective_from', isp.effective_from,
            'effective_to', isp.effective_to,
            'release_window_code', isp.release_window_code
        ) AS selection_rule_key_snapshot,
        ROW_NUMBER() OVER (
            PARTITION BY s.country_key, s.indicator_key, s.time_key
            ORDER BY
                COALESCE(isp.is_override, FALSE) DESC,
                COALESCE(isp.priority_rank, 999999),
                COALESCE(sb.source_released_at, sb.fetched_at) DESC,
                sb.source_batch_key DESC,
                s.staging_row_key DESC
        ) AS published_rank
    FROM tmp_publish_scope_staging s
    JOIN raw.source_batch sb ON sb.source_batch_key = s.source_batch_key
    JOIN core.dim_dataset ds ON ds.source_dataset_key = s.source_dataset_key
    LEFT JOIN LATERAL (
        SELECT isp.*
        FROM ref.indicator_source_priority isp
        WHERE isp.indicator_key = s.indicator_key
          AND isp.source_dataset_key = s.source_dataset_key
          AND (isp.country_key IS NULL OR isp.country_key = s.country_key)
          AND (isp.valid_from_year IS NULL OR s.observation_year >= isp.valid_from_year)
          AND (isp.valid_to_year IS NULL OR s.observation_year <= isp.valid_to_year)
          AND (isp.effective_from IS NULL OR COALESCE(sb.source_released_at::date, sb.fetched_at::date) >= isp.effective_from)
          AND (isp.effective_to IS NULL OR COALESCE(sb.source_released_at::date, sb.fetched_at::date) <= isp.effective_to)
        ORDER BY isp.is_override DESC, isp.priority_rank ASC, isp.indicator_source_priority_key ASC
        LIMIT 1
    ) isp ON TRUE
    WHERE s.mapping_status = 'mapped'
      AND s.missingness_status = 'observed'
      AND s.is_parse_error = FALSE
      AND s.country_key IS NOT NULL
      AND s.indicator_key IS NOT NULL
      AND s.time_key IS NOT NULL
      AND s.observation_value IS NOT NULL;

    CREATE TEMP TABLE tmp_touched_keys ON COMMIT DROP AS
    SELECT DISTINCT country_key, indicator_key, time_key
    FROM tmp_eligible_staging;

    CREATE TEMP TABLE tmp_previously_published ON COMMIT DROP AS
    SELECT
        fp.country_key,
        fp.indicator_key,
        fp.time_key,
        fp.observation_version_key,
        fp.observation_value,
        fp.source_system_key,
        fp.source_dataset_key,
        fp.source_series_key,
        fp.source_batch_key
    FROM core.fact_country_indicator_published fp
    JOIN tmp_touched_keys tk
      ON tk.country_key = fp.country_key
     AND tk.indicator_key = fp.indicator_key
     AND tk.time_key = fp.time_key;

    INSERT INTO core.fact_country_indicator_version (
        country_key,
        indicator_key,
        time_key,
        source_system_key,
        source_dataset_key,
        source_series_key,
        source_batch_key,
        staging_row_key,
        observation_year,
        observation_value,
        unit_key,
        frequency_code,
        status_code,
        selection_method,
        selection_rule_version_ref,
        selection_rule_key_snapshot,
        quality_status,
        comparability_break_flag,
        comparability_break_note,
        is_latest_source_version,
        first_seen_at,
        source_released_at
    )
    SELECT
        es.country_key,
        es.indicator_key,
        es.time_key,
        es.source_system_key,
        es.source_dataset_key,
        es.source_series_key,
        es.source_batch_key,
        es.staging_row_key,
        es.observation_year,
        es.observation_value,
        es.unit_key,
        es.frequency_code,
        'published_candidate',
        es.selection_method,
        v_metadata_rule_version_ref,
        es.selection_rule_key_snapshot,
        'pass',
        FALSE,
        NULL,
        TRUE,
        CURRENT_TIMESTAMP,
        es.source_released_at
    FROM tmp_eligible_staging es
    ON CONFLICT (source_batch_key, staging_row_key) DO UPDATE
    SET country_key = EXCLUDED.country_key,
        indicator_key = EXCLUDED.indicator_key,
        time_key = EXCLUDED.time_key,
        source_system_key = EXCLUDED.source_system_key,
        source_dataset_key = EXCLUDED.source_dataset_key,
        source_series_key = EXCLUDED.source_series_key,
        observation_year = EXCLUDED.observation_year,
        observation_value = EXCLUDED.observation_value,
        unit_key = EXCLUDED.unit_key,
        frequency_code = EXCLUDED.frequency_code,
        selection_method = EXCLUDED.selection_method,
        selection_rule_version_ref = EXCLUDED.selection_rule_version_ref,
        selection_rule_key_snapshot = EXCLUDED.selection_rule_key_snapshot,
        comparability_break_flag = EXCLUDED.comparability_break_flag,
        comparability_break_note = EXCLUDED.comparability_break_note,
        source_released_at = EXCLUDED.source_released_at,
        quality_status = 'pass';

    CREATE TEMP TABLE tmp_latest_versions ON COMMIT DROP AS
    SELECT
        fv.observation_version_key,
        fv.country_key,
        fv.indicator_key,
        fv.time_key,
        fv.observation_year,
        fv.observation_value,
        fv.unit_key,
        fv.source_system_key,
        fv.source_dataset_key,
        fv.source_series_key,
        fv.source_batch_key,
        fv.selection_method,
        ROW_NUMBER() OVER (
            PARTITION BY fv.country_key, fv.indicator_key, fv.time_key
            ORDER BY
                COALESCE(isp.is_override, FALSE) DESC,
                COALESCE(isp.priority_rank, 999999),
                COALESCE(fv.source_released_at, fv.first_seen_at) DESC,
                fv.source_batch_key DESC,
                fv.observation_version_key DESC
        ) AS publish_rank
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
    JOIN tmp_touched_keys tk
      ON tk.country_key = fv.country_key
     AND tk.indicator_key = fv.indicator_key
     AND tk.time_key = fv.time_key;

    INSERT INTO core.fact_country_indicator_published (
        country_key,
        indicator_key,
        time_key,
        observation_year,
        observation_value,
        unit_key,
        source_system_key,
        source_dataset_key,
        source_series_key,
        source_batch_key,
        observation_version_key,
        selection_method,
        selection_rule_version_ref,
        comparability_break_flag,
        comparability_break_note,
        source_switch_flag,
        publication_version_key,
        published_at
    )
    SELECT
        lv.country_key,
        lv.indicator_key,
        lv.time_key,
        lv.observation_year,
        lv.observation_value,
        lv.unit_key,
        lv.source_system_key,
        lv.source_dataset_key,
        lv.source_series_key,
        lv.source_batch_key,
        lv.observation_version_key,
        lv.selection_method,
        v_metadata_rule_version_ref,
        FALSE,
        NULL,
        CASE
            WHEN pp.observation_version_key IS NULL THEN FALSE
            WHEN pp.source_system_key IS DISTINCT FROM lv.source_system_key
              OR pp.source_dataset_key IS DISTINCT FROM lv.source_dataset_key
              OR pp.source_series_key IS DISTINCT FROM lv.source_series_key THEN TRUE
            ELSE FALSE
        END,
        v_publication_version_key,
        CURRENT_TIMESTAMP
    FROM tmp_latest_versions lv
    LEFT JOIN tmp_previously_published pp
      ON pp.country_key = lv.country_key
     AND pp.indicator_key = lv.indicator_key
     AND pp.time_key = lv.time_key
    WHERE lv.publish_rank = 1
    ON CONFLICT (country_key, indicator_key, time_key) DO UPDATE
    SET observation_year = EXCLUDED.observation_year,
        observation_value = EXCLUDED.observation_value,
        unit_key = EXCLUDED.unit_key,
        source_system_key = EXCLUDED.source_system_key,
        source_dataset_key = EXCLUDED.source_dataset_key,
        source_series_key = EXCLUDED.source_series_key,
        source_batch_key = EXCLUDED.source_batch_key,
        observation_version_key = EXCLUDED.observation_version_key,
        selection_method = EXCLUDED.selection_method,
        selection_rule_version_ref = EXCLUDED.selection_rule_version_ref,
        comparability_break_flag = EXCLUDED.comparability_break_flag,
        comparability_break_note = EXCLUDED.comparability_break_note,
        source_switch_flag = EXCLUDED.source_switch_flag,
        publication_version_key = EXCLUDED.publication_version_key,
        published_at = EXCLUDED.published_at,
        updated_at = CURRENT_TIMESTAMP;

    GET DIAGNOSTICS v_rows_out = ROW_COUNT;

    INSERT INTO audit.revision_event (
        pipeline_run_key,
        previous_observation_version_key,
        new_observation_version_key,
        country_key,
        indicator_key,
        time_key,
        source_dataset_key,
        previous_value,
        new_value,
        change_type,
        changed_at,
        notes
    )
    SELECT
        v_pipeline_run_key,
        pp.observation_version_key,
        lv.observation_version_key,
        lv.country_key,
        lv.indicator_key,
        lv.time_key,
        lv.source_dataset_key,
        pp.observation_value,
        lv.observation_value,
        CASE
            WHEN pp.observation_version_key IS NULL THEN 'new_publication'
            WHEN pp.source_system_key IS DISTINCT FROM lv.source_system_key
              OR pp.source_dataset_key IS DISTINCT FROM lv.source_dataset_key
              OR pp.source_series_key IS DISTINCT FROM lv.source_series_key THEN 'source_selection_change'
            WHEN pp.observation_value IS DISTINCT FROM lv.observation_value THEN 'source_revision'
            ELSE 'source_revision'
        END,
        CURRENT_TIMESTAMP,
        'Generated by Phase 1 publish procedure.'
    FROM tmp_latest_versions lv
    LEFT JOIN tmp_previously_published pp
      ON pp.country_key = lv.country_key
     AND pp.indicator_key = lv.indicator_key
     AND pp.time_key = lv.time_key
    WHERE lv.publish_rank = 1
      AND (
            pp.observation_version_key IS NULL
         OR pp.observation_version_key IS DISTINCT FROM lv.observation_version_key
         OR pp.observation_value IS DISTINCT FROM lv.observation_value
         OR pp.source_system_key IS DISTINCT FROM lv.source_system_key
         OR pp.source_dataset_key IS DISTINCT FROM lv.source_dataset_key
         OR pp.source_series_key IS DISTINCT FROM lv.source_series_key
      );

    GET DIAGNOSTICS v_revision_event_count = ROW_COUNT;

    UPDATE core.fact_country_indicator_version fv
    SET is_latest_source_version = FALSE,
        superseded_at = COALESCE(fv.superseded_at, CURRENT_TIMESTAMP),
        status_code = CASE
            WHEN EXISTS (
                SELECT 1
                FROM core.fact_country_indicator_published fp
                WHERE fp.observation_version_key = fv.observation_version_key
            ) THEN 'published'
            ELSE 'superseded'
        END
    WHERE EXISTS (
        SELECT 1
        FROM tmp_touched_keys tk
        WHERE tk.country_key = fv.country_key
          AND tk.indicator_key = fv.indicator_key
          AND tk.time_key = fv.time_key
    )
      AND NOT EXISTS (
        SELECT 1
        FROM core.fact_country_indicator_published fp
        WHERE fp.observation_version_key = fv.observation_version_key
      );

    UPDATE core.fact_country_indicator_version fv
    SET is_latest_source_version = TRUE,
        superseded_at = NULL,
        status_code = CASE
            WHEN EXISTS (
                SELECT 1
                FROM core.fact_country_indicator_published fp
                WHERE fp.observation_version_key = fv.observation_version_key
            ) THEN 'published'
            ELSE 'published_candidate'
        END
    WHERE EXISTS (
        SELECT 1
        FROM core.fact_country_indicator_published fp
        WHERE fp.observation_version_key = fv.observation_version_key
    );

    INSERT INTO audit.dataset_freshness (
        source_dataset_key,
        latest_successful_fetch_at,
        latest_source_released_at,
        latest_published_at,
        latest_published_year,
        freshness_status,
        last_pipeline_run_key,
        last_source_batch_key,
        is_stale,
        last_error_at,
        updated_at
    )
    SELECT
        ds.source_dataset_key,
        latest_batch.fetched_at,
        latest_batch.source_released_at,
        latest_pub.latest_published_at,
        latest_pub.latest_published_year,
        CASE
            WHEN latest_pub.latest_published_at IS NULL THEN 'never_published'
            ELSE 'fresh'
        END,
        v_pipeline_run_key,
        latest_batch.source_batch_key,
        FALSE,
        NULL,
        CURRENT_TIMESTAMP
    FROM (
        SELECT DISTINCT source_dataset_key
        FROM tmp_eligible_staging
    ) ds
    LEFT JOIN LATERAL (
        SELECT sb.source_batch_key, sb.fetched_at, sb.source_released_at
        FROM raw.source_batch sb
        WHERE sb.source_dataset_key = ds.source_dataset_key
          AND sb.ingest_status IN ('loaded', 'normalized')
        ORDER BY COALESCE(sb.source_released_at, sb.fetched_at) DESC, sb.source_batch_key DESC
        LIMIT 1
    ) latest_batch ON TRUE
    LEFT JOIN LATERAL (
        SELECT MAX(fp.published_at) AS latest_published_at,
               MAX(fp.observation_year) AS latest_published_year
        FROM core.fact_country_indicator_published fp
        WHERE fp.source_dataset_key = ds.source_dataset_key
    ) latest_pub ON TRUE
    ON CONFLICT (source_dataset_key) DO UPDATE
    SET latest_successful_fetch_at = EXCLUDED.latest_successful_fetch_at,
        latest_source_released_at = EXCLUDED.latest_source_released_at,
        latest_published_at = EXCLUDED.latest_published_at,
        latest_published_year = EXCLUDED.latest_published_year,
        freshness_status = EXCLUDED.freshness_status,
        last_pipeline_run_key = EXCLUDED.last_pipeline_run_key,
        last_source_batch_key = EXCLUDED.last_source_batch_key,
        is_stale = EXCLUDED.is_stale,
        last_error_at = EXCLUDED.last_error_at,
        updated_at = CURRENT_TIMESTAMP;

    PERFORM etl.assert_phase1_publish_contract(p_source_batch_key);

    UPDATE audit.pipeline_run
    SET completed_at = CURRENT_TIMESTAMP,
        status_code = CASE
            WHEN v_dq_event_count > 0 THEN 'succeeded_with_warnings'
            ELSE 'succeeded'
        END,
        row_count_in = v_rows_in,
        row_count_out = v_rows_out,
        notes = CONCAT(
            'publication_version_key=', v_publication_version_key::TEXT,
            '; dq_events=', v_dq_event_count::TEXT,
            '; revision_events=', v_revision_event_count::TEXT,
            '; publish_guard=passed'
        )
    WHERE pipeline_run_key = v_pipeline_run_key;
EXCEPTION
    WHEN OTHERS THEN
        IF v_pipeline_run_key IS NOT NULL THEN
            UPDATE audit.pipeline_run
            SET completed_at = CURRENT_TIMESTAMP,
                status_code = 'failed',
                notes = LEFT(COALESCE(notes, '') || '; error=' || SQLERRM, 2000)
            WHERE pipeline_run_key = v_pipeline_run_key;
        END IF;
        RAISE;
END;
$$;
