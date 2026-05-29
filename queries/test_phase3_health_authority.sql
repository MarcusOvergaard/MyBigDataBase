DO $$
DECLARE
    latest_who_batch_key BIGINT;
    who_published_count INT;
    conflict_count INT;
    revision_count INT;
    selected_who_count INT;
BEGIN
    SELECT sb.source_batch_key
    INTO latest_who_batch_key
    FROM raw.source_batch sb
    JOIN ref.source_dataset d ON d.source_dataset_key = sb.source_dataset_key
    WHERE d.dataset_code = 'WHO_GHO'
    ORDER BY sb.source_batch_key DESC
    LIMIT 1;

    IF latest_who_batch_key IS NULL THEN
        RAISE EXCEPTION 'Phase 3 WHO authority regression failed: no WHO_GHO batch found';
    END IF;

    SELECT COUNT(*)
    INTO who_published_count
    FROM core.fact_country_indicator_version fv
    JOIN core.dim_dataset dd ON dd.source_dataset_key = fv.source_dataset_key
    JOIN core.dim_indicator di ON di.indicator_key = fv.indicator_key
    WHERE fv.source_batch_key = latest_who_batch_key
      AND dd.dataset_code = 'WHO_GHO'
      AND di.indicator_code = 'LIFE_EXPECTANCY_YEARS';

    IF who_published_count < 15 THEN
        RAISE EXCEPTION 'Phase 3 WHO authority regression failed: expected at least 15 WHO life-expectancy rows, got %', who_published_count;
    END IF;

    SELECT COUNT(*)
    INTO conflict_count
    FROM mart.vw_phase3_source_conflicts v
    WHERE v.indicator_code = 'LIFE_EXPECTANCY_YEARS'
      AND v.dataset_recency_rank = 1
      AND v.dataset_code IN ('WDI', 'WHO_GHO')
      AND v.selected_dataset_code = 'WHO_GHO';

    IF conflict_count < 5 THEN
        RAISE EXCEPTION 'Phase 3 WHO authority regression failed: expected WHO-vs-WDI life-expectancy conflicts, got % rows', conflict_count;
    END IF;

    SELECT COUNT(*)
    INTO revision_count
    FROM mart.vw_phase3_revision_history r
    WHERE r.indicator_code = 'LIFE_EXPECTANCY_YEARS'
      AND r.new_dataset_code = 'WHO_GHO'
      AND COALESCE(r.previous_dataset_code, '') = 'WDI';

    IF revision_count < 3 THEN
        RAISE EXCEPTION 'Phase 3 WHO authority regression failed: expected source-selection revisions from WDI to WHO_GHO, got %', revision_count;
    END IF;

    SELECT COUNT(*)
    INTO selected_who_count
    FROM mart.mart_country_health_series_annual h
    WHERE h.indicator_code = 'LIFE_EXPECTANCY_YEARS'
      AND h.dataset_code = 'WHO_GHO'
      AND h.iso_alpha_3 IN ('DEU', 'USA', 'CHN', 'IND', 'ZAF')
      AND h.observation_year BETWEEN 2019 AND 2021;

    IF selected_who_count < 15 THEN
        RAISE EXCEPTION 'Phase 3 WHO authority regression failed: health mart is missing WHO-selected life expectancy rows (got %)', selected_who_count;
    END IF;
END;
$$;

SELECT
    indicator_code,
    selected_dataset_code,
    COUNT(*) AS conflict_rows
FROM mart.vw_phase3_source_conflicts
WHERE indicator_code = 'LIFE_EXPECTANCY_YEARS'
  AND dataset_recency_rank = 1
GROUP BY indicator_code, selected_dataset_code
ORDER BY indicator_code, selected_dataset_code;

SELECT
    iso_alpha_3,
    observation_year,
    dataset_code,
    observation_value,
    selected_dataset_code,
    selected_observation_value
FROM mart.vw_phase3_source_conflicts
WHERE indicator_code = 'LIFE_EXPECTANCY_YEARS'
  AND iso_alpha_3 IN ('DEU', 'USA', 'CHN', 'IND', 'ZAF')
  AND dataset_recency_rank = 1
ORDER BY iso_alpha_3, observation_year, dataset_code;
