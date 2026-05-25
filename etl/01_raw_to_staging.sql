-- Phase 1 normalization procedure that builds from the new raw/ref contract.
CREATE OR REPLACE PROCEDURE staging.normalize_country_observation_annual(
    p_source_batch_key BIGINT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_source_batch_key IS NULL THEN
        DELETE FROM staging.country_observation_annual;
    ELSE
        DELETE FROM staging.country_observation_annual
        WHERE source_batch_key = p_source_batch_key;
    END IF;

    WITH raw_union AS (
        SELECT
            r.source_batch_key,
            r.raw_row_key,
            r.country_code_raw,
            r.indicator_code_raw,
            r.year_raw,
            r.value_raw
        FROM raw.wdi_country_indicator_annual r
        UNION ALL
        SELECT
            r.source_batch_key,
            r.raw_row_key,
            r.country_code_raw,
            r.indicator_code_raw,
            r.year_raw,
            r.value_raw
        FROM raw.ifs_country_indicator_annual r
        UNION ALL
        SELECT
            r.source_batch_key,
            r.raw_row_key,
            r.country_code_raw,
            r.indicator_code_raw,
            r.year_raw,
            r.value_raw
        FROM raw.ilostat_country_indicator_annual r
        UNION ALL
        SELECT
            r.source_batch_key,
            r.raw_row_key,
            r.country_code_raw,
            r.indicator_code_raw,
            r.year_raw,
            r.value_raw
        FROM raw.un_comtrade_country_indicator_annual r
    ),
    normalized AS (
        SELECT
            r.source_batch_key,
            r.raw_row_key,
            sb.source_dataset_key,
            rs.source_series_key,
            c.country_key,
            i.indicator_key,
            CASE
                WHEN r.year_raw ~ '^[0-9]{4}$' THEN r.year_raw::INT
                ELSE NULL
            END AS observation_year,
            dt.time_key,
            CASE
                WHEN NULLIF(BTRIM(r.value_raw), '') IS NULL THEN NULL
                WHEN BTRIM(r.value_raw) ~ '^[+-]?[0-9]+(\.[0-9]+)?$' THEN BTRIM(r.value_raw)::NUMERIC(20,4)
                ELSE NULL
            END AS observation_value,
            r.value_raw AS raw_value_text,
            i.default_unit_key AS unit_key,
            COALESCE(rs.source_frequency_code, d.default_frequency_code, 'A') AS frequency_code,
            CASE
                WHEN c.country_key IS NOT NULL AND i.indicator_key IS NOT NULL THEN 'mapped'
                WHEN c.country_key IS NULL AND i.indicator_key IS NULL THEN 'country_and_indicator_unmapped'
                WHEN c.country_key IS NULL THEN 'country_unmapped'
                ELSE 'indicator_unmapped'
            END AS mapping_status,
            CASE
                WHEN NULLIF(BTRIM(r.value_raw), '') IS NULL THEN 'missing_at_source'
                WHEN BTRIM(r.value_raw) ~ '^[+-]?[0-9]+(\.[0-9]+)?$' THEN 'observed'
                ELSE 'parse_failed'
            END AS missingness_status,
            CASE
                WHEN NULLIF(BTRIM(r.value_raw), '') IS NOT NULL
                 AND NOT (BTRIM(r.value_raw) ~ '^[+-]?[0-9]+(\.[0-9]+)?$') THEN TRUE
                ELSE FALSE
            END AS is_parse_error,
            (c.country_key IS NOT NULL) AS is_country_mapped,
            (i.indicator_key IS NOT NULL) AS is_indicator_mapped,
            ARRAY_REMOVE(ARRAY[
                CASE WHEN c.country_key IS NULL THEN 'country_unmapped' END,
                CASE WHEN rs.source_series_key IS NULL THEN 'source_series_unmapped' END,
                CASE WHEN i.indicator_key IS NULL THEN 'indicator_unmapped' END,
                CASE WHEN NULLIF(BTRIM(r.value_raw), '') IS NULL THEN 'missing_at_source' END,
                CASE
                    WHEN NULLIF(BTRIM(r.value_raw), '') IS NOT NULL
                     AND NOT (BTRIM(r.value_raw) ~ '^[+-]?[0-9]+(\.[0-9]+)?$') THEN 'parse_failed'
                END,
                CASE
                    WHEN NOT (r.year_raw ~ '^[0-9]{4}$') THEN 'invalid_year_raw'
                END
            ], NULL) AS quality_flags
        FROM raw_union r
        JOIN raw.source_batch sb ON sb.source_batch_key = r.source_batch_key
        JOIN ref.source_dataset d ON d.source_dataset_key = sb.source_dataset_key
        LEFT JOIN ref.country c ON c.iso_alpha_3 = r.country_code_raw
        LEFT JOIN ref.source_series rs
            ON rs.source_dataset_key = sb.source_dataset_key
           AND rs.series_code = r.indicator_code_raw
        LEFT JOIN ref.indicator_source_series_map ism
            ON ism.source_series_key = rs.source_series_key
           AND ism.is_active = TRUE
        LEFT JOIN ref.indicator i ON i.indicator_key = ism.indicator_key
        LEFT JOIN core.dim_time dt
            ON dt.period_type = 'annual'
           AND dt.calendar_year = CASE
                WHEN r.year_raw ~ '^[0-9]{4}$' THEN r.year_raw::INT
                ELSE NULL
           END
        WHERE p_source_batch_key IS NULL OR r.source_batch_key = p_source_batch_key
    )
    INSERT INTO staging.country_observation_annual (
        source_batch_key,
        raw_row_key,
        source_dataset_key,
        source_series_key,
        country_key,
        indicator_key,
        time_key,
        observation_year,
        observation_value,
        raw_value_text,
        unit_key,
        frequency_code,
        mapping_status,
        missingness_status,
        is_parse_error,
        is_country_mapped,
        is_indicator_mapped,
        quality_flags
    )
    SELECT
        source_batch_key,
        raw_row_key,
        source_dataset_key,
        source_series_key,
        country_key,
        indicator_key,
        time_key,
        observation_year,
        observation_value,
        raw_value_text,
        unit_key,
        frequency_code,
        mapping_status,
        missingness_status,
        is_parse_error,
        is_country_mapped,
        is_indicator_mapped,
        quality_flags
    FROM normalized;
END;
$$;


CREATE OR REPLACE PROCEDURE staging.normalize_wdi_country_observation_annual(
    p_source_batch_key BIGINT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN
    CALL staging.normalize_country_observation_annual(p_source_batch_key);
END;
$$;
