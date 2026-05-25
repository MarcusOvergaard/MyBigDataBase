-- Phase 1 Wave 2 conformed core-dimension seeds sourced from ref.

INSERT INTO core.dim_country (
    country_key,
    iso_alpha_3,
    country_name,
    region_name,
    income_group,
    is_aggregate,
    is_active
)
SELECT
    c.country_key,
    c.iso_alpha_3,
    c.country_name,
    c.region_name,
    c.income_group,
    c.is_aggregate,
    c.is_active
FROM ref.country c
ON CONFLICT (country_key) DO UPDATE
SET iso_alpha_3 = EXCLUDED.iso_alpha_3,
    country_name = EXCLUDED.country_name,
    region_name = EXCLUDED.region_name,
    income_group = EXCLUDED.income_group,
    is_aggregate = EXCLUDED.is_aggregate,
    is_active = EXCLUDED.is_active,
    updated_at = CURRENT_TIMESTAMP;

INSERT INTO core.dim_source (
    source_system_key,
    source_code,
    source_name,
    publisher_type,
    base_url,
    access_method,
    is_active
)
SELECT
    s.source_system_key,
    s.source_code,
    s.source_name,
    s.publisher_type,
    s.base_url,
    s.access_method,
    s.is_active
FROM ref.source_system s
ON CONFLICT (source_system_key) DO UPDATE
SET source_code = EXCLUDED.source_code,
    source_name = EXCLUDED.source_name,
    publisher_type = EXCLUDED.publisher_type,
    base_url = EXCLUDED.base_url,
    access_method = EXCLUDED.access_method,
    is_active = EXCLUDED.is_active;

INSERT INTO core.dim_dataset (
    source_dataset_key,
    source_system_key,
    dataset_code,
    dataset_name,
    default_frequency_code,
    default_grain,
    release_cadence,
    is_active
)
SELECT
    d.source_dataset_key,
    d.source_system_key,
    d.dataset_code,
    d.dataset_name,
    d.default_frequency_code,
    d.default_grain,
    d.release_cadence,
    d.is_active
FROM ref.source_dataset d
ON CONFLICT (source_dataset_key) DO UPDATE
SET source_system_key = EXCLUDED.source_system_key,
    dataset_code = EXCLUDED.dataset_code,
    dataset_name = EXCLUDED.dataset_name,
    default_frequency_code = EXCLUDED.default_frequency_code,
    default_grain = EXCLUDED.default_grain,
    release_cadence = EXCLUDED.release_cadence,
    is_active = EXCLUDED.is_active;

INSERT INTO core.dim_indicator (
    indicator_key,
    indicator_code,
    indicator_name,
    topic,
    default_unit_key,
    default_unit_code,
    default_unit_name,
    default_frequency_code,
    value_datatype,
    preferred_aggregation,
    is_phase_1,
    description
)
SELECT
    i.indicator_key,
    i.indicator_code,
    i.indicator_name,
    i.topic,
    i.default_unit_key,
    u.unit_code,
    u.unit_name,
    i.default_frequency_code,
    i.value_datatype,
    i.preferred_aggregation,
    i.is_phase_1,
    i.description
FROM ref.indicator i
JOIN ref.unit u ON u.unit_key = i.default_unit_key
ON CONFLICT (indicator_key) DO UPDATE
SET indicator_code = EXCLUDED.indicator_code,
    indicator_name = EXCLUDED.indicator_name,
    topic = EXCLUDED.topic,
    default_unit_key = EXCLUDED.default_unit_key,
    default_unit_code = EXCLUDED.default_unit_code,
    default_unit_name = EXCLUDED.default_unit_name,
    default_frequency_code = EXCLUDED.default_frequency_code,
    value_datatype = EXCLUDED.value_datatype,
    preferred_aggregation = EXCLUDED.preferred_aggregation,
    is_phase_1 = EXCLUDED.is_phase_1,
    description = EXCLUDED.description,
    updated_at = CURRENT_TIMESTAMP;
