-- Populate core.dim_time with annual periods for Phase 1, plus future-ready period typing.
INSERT INTO core.dim_time (
    period_type,
    calendar_year,
    quarter_number,
    month_number,
    period_start_date,
    period_end_date,
    period_label,
    is_year_end
)
SELECT
    'annual' AS period_type,
    year_value AS calendar_year,
    NULL AS quarter_number,
    NULL AS month_number,
    make_date(year_value, 1, 1) AS period_start_date,
    make_date(year_value, 12, 31) AS period_end_date,
    year_value::TEXT AS period_label,
    TRUE AS is_year_end
FROM generate_series(1960, 2035) AS year_value
ON CONFLICT (period_label) DO NOTHING;
