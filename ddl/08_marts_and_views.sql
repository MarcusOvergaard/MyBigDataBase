-- Phase 1 Wave 7 marts and diagnostic views
-- These analyst-facing surfaces build from the new published/audit contract rather than the legacy dw path.

DROP VIEW IF EXISTS mart.country_latest_macro;
DROP VIEW IF EXISTS mart.mart_country_phase2_issues CASCADE;
DROP VIEW IF EXISTS mart.mart_country_phase2_readiness_summary CASCADE;
DROP VIEW IF EXISTS mart.mart_country_phase2_latest CASCADE;
DROP VIEW IF EXISTS mart.mart_country_macro_plus_external_latest CASCADE;
DROP VIEW IF EXISTS mart.mart_country_trade_external_panel_annual CASCADE;
DROP VIEW IF EXISTS mart.mart_country_inflation_series_annual CASCADE;
DROP VIEW IF EXISTS mart.vw_phase2_source_conflict_summary CASCADE;
DROP VIEW IF EXISTS mart.vw_gdp_source_conflict_summary CASCADE;
DROP VIEW IF EXISTS mart.vw_gdp_source_conflict_summary_latest CASCADE;
DROP VIEW IF EXISTS mart.vw_gdp_source_conflicts_latest CASCADE;
DROP VIEW IF EXISTS mart.vw_gdp_source_conflicts CASCADE;
DROP VIEW IF EXISTS mart.vw_inflation_source_conflict_summary CASCADE;
DROP VIEW IF EXISTS mart.vw_inflation_source_conflict_summary_latest CASCADE;
DROP VIEW IF EXISTS mart.vw_labor_source_conflict_summary CASCADE;

CREATE OR REPLACE VIEW mart.mart_country_macro_series_annual AS
SELECT
    fp.country_key,
    dc.iso_alpha_3,
    dc.country_name,
    dc.region_name,
    dc.income_group,
    fp.indicator_key,
    di.indicator_code,
    di.indicator_name,
    di.topic,
    fp.time_key,
    dt.calendar_year AS observation_year,
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
    fp.observation_version_key,
    fp.selection_method,
    fp.publication_version_key,
    fp.published_at
FROM core.fact_country_indicator_published fp
JOIN core.dim_country dc ON dc.country_key = fp.country_key
JOIN core.dim_indicator di ON di.indicator_key = fp.indicator_key
JOIN core.dim_time dt ON dt.time_key = fp.time_key
JOIN core.dim_source ds ON ds.source_system_key = fp.source_system_key
JOIN core.dim_dataset dd ON dd.source_dataset_key = fp.source_dataset_key
LEFT JOIN ref.source_series rs ON rs.source_series_key = fp.source_series_key;

CREATE OR REPLACE VIEW mart.mart_country_macro_latest AS
WITH ranked AS (
    SELECT
        ms.*,
        ROW_NUMBER() OVER (
            PARTITION BY ms.country_key, ms.indicator_key
            ORDER BY ms.observation_year DESC, ms.published_at DESC, ms.observation_version_key DESC
        ) AS recency_rank
    FROM mart.mart_country_macro_series_annual ms
)
SELECT
    r.country_key,
    r.iso_alpha_3,
    r.country_name,
    r.region_name,
    r.income_group,
    MAX(CASE WHEN r.indicator_code = 'GDP_CURR_USD' THEN r.observation_year END) AS gdp_curr_usd_year,
    MAX(CASE WHEN r.indicator_code = 'GDP_CURR_USD' THEN r.observation_value END) AS gdp_curr_usd,
    MAX(CASE WHEN r.indicator_code = 'GDP_PC_CURR_USD' THEN r.observation_year END) AS gdp_pc_curr_usd_year,
    MAX(CASE WHEN r.indicator_code = 'GDP_PC_CURR_USD' THEN r.observation_value END) AS gdp_pc_curr_usd,
    MAX(CASE WHEN r.indicator_code = 'POP_TOTAL' THEN r.observation_year END) AS pop_total_year,
    MAX(CASE WHEN r.indicator_code = 'POP_TOTAL' THEN r.observation_value END) AS pop_total,
    MAX(r.published_at) AS latest_published_at
FROM ranked r
WHERE r.recency_rank = 1
GROUP BY r.country_key, r.iso_alpha_3, r.country_name, r.region_name, r.income_group;

CREATE OR REPLACE VIEW mart.mart_country_profile_foundation AS
SELECT
    ml.country_key,
    ml.iso_alpha_3,
    ml.country_name,
    ml.region_name,
    ml.income_group,
    ml.gdp_curr_usd_year,
    ml.gdp_curr_usd,
    ml.gdp_pc_curr_usd_year,
    ml.gdp_pc_curr_usd,
    ml.pop_total_year,
    ml.pop_total,
    CASE
        WHEN ml.pop_total IS NOT NULL AND ml.pop_total <> 0 AND ml.gdp_curr_usd IS NOT NULL
            THEN ROUND((ml.gdp_curr_usd / ml.pop_total)::numeric, 2)
        ELSE NULL
    END AS derived_gdp_per_capita_from_latest,
    ml.latest_published_at
FROM mart.mart_country_macro_latest ml;

CREATE OR REPLACE VIEW mart.mart_country_labor_series_annual AS
SELECT
    ms.country_key,
    ms.iso_alpha_3,
    ms.country_name,
    ms.region_name,
    ms.income_group,
    ms.indicator_key,
    ms.indicator_code,
    ms.indicator_name,
    ms.topic,
    ms.time_key,
    ms.observation_year,
    ms.observation_value,
    ms.unit_key,
    ms.unit_code,
    ms.unit_name,
    ms.source_system_key,
    ms.source_code,
    ms.source_name,
    ms.source_dataset_key,
    ms.dataset_code,
    ms.dataset_name,
    ms.source_series_key,
    ms.series_code,
    ms.series_name,
    ms.source_batch_key,
    ms.observation_version_key,
    ms.selection_method,
    ms.publication_version_key,
    ms.published_at
FROM mart.mart_country_macro_series_annual ms
WHERE ms.indicator_code IN (
    'EMPLOYMENT_RATE_PCT',
    'LABOR_FORCE_PARTICIPATION_RATE_PCT',
    'UNEMPLOYMENT_RATE_PCT'
);

CREATE OR REPLACE VIEW mart.mart_country_inflation_series_annual AS
SELECT
    ms.country_key,
    ms.iso_alpha_3,
    ms.country_name,
    ms.region_name,
    ms.income_group,
    ms.indicator_key,
    ms.indicator_code,
    ms.indicator_name,
    ms.topic,
    ms.time_key,
    ms.observation_year,
    ms.observation_value,
    ms.unit_key,
    ms.unit_code,
    ms.unit_name,
    ms.source_system_key,
    ms.source_code,
    ms.source_name,
    ms.source_dataset_key,
    ms.dataset_code,
    ms.dataset_name,
    ms.source_series_key,
    ms.series_code,
    ms.series_name,
    ms.source_batch_key,
    ms.observation_version_key,
    ms.selection_method,
    ms.publication_version_key,
    ms.published_at
FROM mart.mart_country_macro_series_annual ms
WHERE ms.indicator_code = 'INFLATION_CPI_PCT';

CREATE OR REPLACE VIEW mart.mart_country_trade_external_panel_annual AS
WITH trade_rows AS (
    SELECT
        ms.country_key,
        ms.iso_alpha_3,
        ms.country_name,
        ms.region_name,
        ms.income_group,
        ms.indicator_key,
        ms.indicator_code,
        ms.indicator_name,
        ms.topic,
        ms.time_key,
        ms.observation_year,
        ms.observation_value,
        ms.unit_key,
        ms.unit_code,
        ms.unit_name,
        ms.source_system_key,
        ms.source_code,
        ms.source_name,
        ms.source_dataset_key,
        ms.dataset_code,
        ms.dataset_name,
        ms.source_series_key,
        ms.series_code,
        ms.series_name,
        ms.source_batch_key,
        ms.observation_version_key,
        ms.selection_method,
        ms.publication_version_key,
        ms.published_at
    FROM mart.mart_country_macro_series_annual ms
    WHERE ms.indicator_code IN (
        'TRADE_EXPORTS_CURR_USD',
        'TRADE_IMPORTS_CURR_USD',
        'CURRENT_ACCOUNT_BALANCE_CURR_USD',
        'CURRENT_ACCOUNT_BALANCE_PCT_GDP'
    )
),
trade_pairs AS (
    SELECT
        tr.country_key,
        tr.time_key,
        MAX(CASE WHEN tr.indicator_code = 'TRADE_EXPORTS_CURR_USD' THEN tr.observation_value END) AS trade_exports_curr_usd,
        MAX(CASE WHEN tr.indicator_code = 'TRADE_IMPORTS_CURR_USD' THEN tr.observation_value END) AS trade_imports_curr_usd
    FROM trade_rows tr
    GROUP BY tr.country_key, tr.time_key
)
SELECT
    tr.country_key,
    tr.iso_alpha_3,
    tr.country_name,
    tr.region_name,
    tr.income_group,
    tr.indicator_key,
    tr.indicator_code,
    tr.indicator_name,
    tr.topic,
    tr.time_key,
    tr.observation_year,
    tr.observation_value,
    tr.unit_key,
    tr.unit_code,
    tr.unit_name,
    tr.source_system_key,
    tr.source_code,
    tr.source_name,
    tr.source_dataset_key,
    tr.dataset_code,
    tr.dataset_name,
    tr.source_series_key,
    tr.series_code,
    tr.series_name,
    tr.source_batch_key,
    tr.observation_version_key,
    tr.selection_method,
    tr.publication_version_key,
    tr.published_at,
    tp.trade_exports_curr_usd,
    tp.trade_imports_curr_usd,
    CASE
        WHEN tp.trade_exports_curr_usd IS NOT NULL
         AND tp.trade_imports_curr_usd IS NOT NULL
            THEN tp.trade_exports_curr_usd - tp.trade_imports_curr_usd
        ELSE NULL
    END AS trade_balance_curr_usd,
    CASE
        WHEN tp.trade_exports_curr_usd IS NULL
          OR tp.trade_imports_curr_usd IS NULL
            THEN 'unknown'
        WHEN tp.trade_exports_curr_usd > tp.trade_imports_curr_usd
            THEN 'surplus'
        WHEN tp.trade_exports_curr_usd < tp.trade_imports_curr_usd
            THEN 'deficit'
        ELSE 'balanced'
    END AS trade_balance_direction
FROM trade_rows tr
JOIN trade_pairs tp
  ON tp.country_key = tr.country_key
 AND tp.time_key = tr.time_key;

CREATE OR REPLACE VIEW mart.mart_country_phase2_series_annual AS
SELECT *
FROM mart.mart_country_labor_series_annual
UNION ALL
SELECT *
FROM mart.mart_country_inflation_series_annual
UNION ALL
SELECT
    te.country_key,
    te.iso_alpha_3,
    te.country_name,
    te.region_name,
    te.income_group,
    te.indicator_key,
    te.indicator_code,
    te.indicator_name,
    te.topic,
    te.time_key,
    te.observation_year,
    te.observation_value,
    te.unit_key,
    te.unit_code,
    te.unit_name,
    te.source_system_key,
    te.source_code,
    te.source_name,
    te.source_dataset_key,
    te.dataset_code,
    te.dataset_name,
    te.source_series_key,
    te.series_code,
    te.series_name,
    te.source_batch_key,
    te.observation_version_key,
    te.selection_method,
    te.publication_version_key,
    te.published_at
FROM mart.mart_country_trade_external_panel_annual te;

CREATE OR REPLACE VIEW mart.mart_country_macro_plus_external_latest AS
WITH ranked AS (
    SELECT
        ps.*,
        ROW_NUMBER() OVER (
            PARTITION BY ps.country_key, ps.indicator_key
            ORDER BY ps.observation_year DESC, ps.published_at DESC, ps.observation_version_key DESC
        ) AS recency_rank
    FROM mart.mart_country_phase2_series_annual ps
)
SELECT
    ml.country_key,
    ml.iso_alpha_3,
    ml.country_name,
    ml.region_name,
    ml.income_group,
    ml.gdp_curr_usd_year,
    ml.gdp_curr_usd,
    ml.gdp_pc_curr_usd_year,
    ml.gdp_pc_curr_usd,
    ml.pop_total_year,
    ml.pop_total,
    MAX(CASE WHEN r.indicator_code = 'EMPLOYMENT_RATE_PCT' THEN r.observation_year END) AS employment_rate_pct_year,
    MAX(CASE WHEN r.indicator_code = 'EMPLOYMENT_RATE_PCT' THEN r.observation_value END) AS employment_rate_pct,
    MAX(CASE WHEN r.indicator_code = 'LABOR_FORCE_PARTICIPATION_RATE_PCT' THEN r.observation_year END) AS labor_force_participation_rate_pct_year,
    MAX(CASE WHEN r.indicator_code = 'LABOR_FORCE_PARTICIPATION_RATE_PCT' THEN r.observation_value END) AS labor_force_participation_rate_pct,
    MAX(CASE WHEN r.indicator_code = 'UNEMPLOYMENT_RATE_PCT' THEN r.observation_year END) AS unemployment_rate_pct_year,
    MAX(CASE WHEN r.indicator_code = 'UNEMPLOYMENT_RATE_PCT' THEN r.observation_value END) AS unemployment_rate_pct,
    MAX(CASE WHEN r.indicator_code = 'INFLATION_CPI_PCT' THEN r.observation_year END) AS inflation_cpi_pct_year,
    MAX(CASE WHEN r.indicator_code = 'INFLATION_CPI_PCT' THEN r.observation_value END) AS inflation_cpi_pct,
    MAX(CASE WHEN r.indicator_code = 'TRADE_EXPORTS_CURR_USD' THEN r.observation_year END) AS trade_exports_curr_usd_year,
    MAX(CASE WHEN r.indicator_code = 'TRADE_EXPORTS_CURR_USD' THEN r.observation_value END) AS trade_exports_curr_usd,
    MAX(CASE WHEN r.indicator_code = 'TRADE_IMPORTS_CURR_USD' THEN r.observation_year END) AS trade_imports_curr_usd_year,
    MAX(CASE WHEN r.indicator_code = 'TRADE_IMPORTS_CURR_USD' THEN r.observation_value END) AS trade_imports_curr_usd,
    MAX(CASE WHEN r.indicator_code = 'CURRENT_ACCOUNT_BALANCE_CURR_USD' THEN r.observation_year END) AS current_account_balance_curr_usd_year,
    MAX(CASE WHEN r.indicator_code = 'CURRENT_ACCOUNT_BALANCE_CURR_USD' THEN r.observation_value END) AS current_account_balance_curr_usd,
    MAX(CASE WHEN r.indicator_code = 'CURRENT_ACCOUNT_BALANCE_PCT_GDP' THEN r.observation_year END) AS current_account_balance_pct_gdp_year,
    MAX(CASE WHEN r.indicator_code = 'CURRENT_ACCOUNT_BALANCE_PCT_GDP' THEN r.observation_value END) AS current_account_balance_pct_gdp,
    CASE
        WHEN MAX(CASE WHEN r.indicator_code = 'TRADE_EXPORTS_CURR_USD' THEN r.observation_value END) IS NOT NULL
         AND MAX(CASE WHEN r.indicator_code = 'TRADE_IMPORTS_CURR_USD' THEN r.observation_value END) IS NOT NULL
            THEN MAX(CASE WHEN r.indicator_code = 'TRADE_EXPORTS_CURR_USD' THEN r.observation_value END)
               - MAX(CASE WHEN r.indicator_code = 'TRADE_IMPORTS_CURR_USD' THEN r.observation_value END)
        ELSE NULL
    END AS trade_balance_curr_usd,
    CASE
        WHEN MAX(CASE WHEN r.indicator_code = 'TRADE_EXPORTS_CURR_USD' THEN r.observation_value END) IS NULL
          OR MAX(CASE WHEN r.indicator_code = 'TRADE_IMPORTS_CURR_USD' THEN r.observation_value END) IS NULL
            THEN 'unknown'
        WHEN MAX(CASE WHEN r.indicator_code = 'TRADE_EXPORTS_CURR_USD' THEN r.observation_value END)
           > MAX(CASE WHEN r.indicator_code = 'TRADE_IMPORTS_CURR_USD' THEN r.observation_value END)
            THEN 'surplus'
        WHEN MAX(CASE WHEN r.indicator_code = 'TRADE_EXPORTS_CURR_USD' THEN r.observation_value END)
           < MAX(CASE WHEN r.indicator_code = 'TRADE_IMPORTS_CURR_USD' THEN r.observation_value END)
            THEN 'deficit'
        ELSE 'balanced'
    END AS trade_balance_direction,
    GREATEST(ml.latest_published_at, COALESCE(MAX(r.published_at), ml.latest_published_at)) AS latest_published_at
FROM mart.mart_country_macro_latest ml
LEFT JOIN ranked r
  ON r.country_key = ml.country_key
 AND r.recency_rank = 1
GROUP BY
    ml.country_key,
    ml.iso_alpha_3,
    ml.country_name,
    ml.region_name,
    ml.income_group,
    ml.gdp_curr_usd_year,
    ml.gdp_curr_usd,
    ml.gdp_pc_curr_usd_year,
    ml.gdp_pc_curr_usd,
    ml.pop_total_year,
    ml.pop_total,
    ml.latest_published_at;

CREATE OR REPLACE VIEW mart.mart_country_phase2_latest AS
SELECT
    mpe.country_key,
    mpe.iso_alpha_3,
    mpe.country_name,
    mpe.region_name,
    mpe.income_group,
    (
        CASE WHEN mpe.employment_rate_pct_year IS NOT NULL THEN 1 ELSE 0 END
      + CASE WHEN mpe.labor_force_participation_rate_pct_year IS NOT NULL THEN 1 ELSE 0 END
      + CASE WHEN mpe.unemployment_rate_pct_year IS NOT NULL THEN 1 ELSE 0 END
      + CASE WHEN mpe.inflation_cpi_pct_year IS NOT NULL THEN 1 ELSE 0 END
      + CASE WHEN mpe.trade_exports_curr_usd_year IS NOT NULL THEN 1 ELSE 0 END
      + CASE WHEN mpe.trade_imports_curr_usd_year IS NOT NULL THEN 1 ELSE 0 END
      + CASE WHEN mpe.current_account_balance_curr_usd_year IS NOT NULL THEN 1 ELSE 0 END
      + CASE WHEN mpe.current_account_balance_pct_gdp_year IS NOT NULL THEN 1 ELSE 0 END
    ) AS phase2_indicator_coverage_count,
    NULLIF(
        GREATEST(
            COALESCE(mpe.employment_rate_pct_year, 0),
            COALESCE(mpe.labor_force_participation_rate_pct_year, 0),
            COALESCE(mpe.unemployment_rate_pct_year, 0),
            COALESCE(mpe.inflation_cpi_pct_year, 0),
            COALESCE(mpe.trade_exports_curr_usd_year, 0),
            COALESCE(mpe.trade_imports_curr_usd_year, 0),
            COALESCE(mpe.current_account_balance_curr_usd_year, 0),
            COALESCE(mpe.current_account_balance_pct_gdp_year, 0)
        ),
        0
    ) AS latest_phase2_observation_year,
    mpe.employment_rate_pct_year,
    mpe.employment_rate_pct,
    mpe.labor_force_participation_rate_pct_year,
    mpe.labor_force_participation_rate_pct,
    mpe.unemployment_rate_pct_year,
    mpe.unemployment_rate_pct,
    mpe.inflation_cpi_pct_year,
    mpe.inflation_cpi_pct,
    mpe.trade_exports_curr_usd_year,
    mpe.trade_exports_curr_usd,
    mpe.trade_imports_curr_usd_year,
    mpe.trade_imports_curr_usd,
    mpe.current_account_balance_curr_usd_year,
    mpe.current_account_balance_curr_usd,
    mpe.current_account_balance_pct_gdp_year,
    mpe.current_account_balance_pct_gdp,
    mpe.trade_balance_curr_usd,
    mpe.trade_balance_direction,
    mpe.latest_published_at
FROM mart.mart_country_macro_plus_external_latest mpe;

CREATE OR REPLACE VIEW mart.mart_country_phase2_readiness_summary AS
SELECT
    c.country_key,
    c.iso_alpha_3,
    c.country_name,
    c.region_name,
    c.income_group,
    c.phase2_indicator_coverage_count,
    8 - c.phase2_indicator_coverage_count AS phase2_indicator_gap_count,
    (
        CASE WHEN c.employment_rate_pct_year IS NOT NULL THEN 1 ELSE 0 END
      + CASE WHEN c.labor_force_participation_rate_pct_year IS NOT NULL THEN 1 ELSE 0 END
      + CASE WHEN c.unemployment_rate_pct_year IS NOT NULL THEN 1 ELSE 0 END
    ) AS labor_indicator_coverage_count,
    (
        CASE WHEN c.inflation_cpi_pct_year IS NOT NULL THEN 1 ELSE 0 END
      + CASE WHEN c.trade_exports_curr_usd_year IS NOT NULL THEN 1 ELSE 0 END
      + CASE WHEN c.trade_imports_curr_usd_year IS NOT NULL THEN 1 ELSE 0 END
      + CASE WHEN c.current_account_balance_curr_usd_year IS NOT NULL THEN 1 ELSE 0 END
      + CASE WHEN c.current_account_balance_pct_gdp_year IS NOT NULL THEN 1 ELSE 0 END
    ) AS macro_trade_external_indicator_coverage_count,
    c.latest_phase2_observation_year,
    CASE
        WHEN c.phase2_indicator_coverage_count = 8 THEN 'complete'
        WHEN c.phase2_indicator_coverage_count >= 6 THEN 'mostly_complete'
        WHEN c.phase2_indicator_coverage_count >= 1 THEN 'partial'
        ELSE 'empty'
    END AS phase2_coverage_status,
    (c.trade_exports_curr_usd_year IS NOT NULL AND c.trade_imports_curr_usd_year IS NOT NULL) AS has_trade_pair,
    (c.current_account_balance_curr_usd_year IS NOT NULL AND c.current_account_balance_pct_gdp_year IS NOT NULL) AS has_external_balance_pair,
    ARRAY_REMOVE(ARRAY[
        CASE WHEN c.employment_rate_pct_year IS NULL THEN 'EMPLOYMENT_RATE_PCT' END,
        CASE WHEN c.labor_force_participation_rate_pct_year IS NULL THEN 'LABOR_FORCE_PARTICIPATION_RATE_PCT' END,
        CASE WHEN c.unemployment_rate_pct_year IS NULL THEN 'UNEMPLOYMENT_RATE_PCT' END,
        CASE WHEN c.inflation_cpi_pct_year IS NULL THEN 'INFLATION_CPI_PCT' END,
        CASE WHEN c.trade_exports_curr_usd_year IS NULL THEN 'TRADE_EXPORTS_CURR_USD' END,
        CASE WHEN c.trade_imports_curr_usd_year IS NULL THEN 'TRADE_IMPORTS_CURR_USD' END,
        CASE WHEN c.current_account_balance_curr_usd_year IS NULL THEN 'CURRENT_ACCOUNT_BALANCE_CURR_USD' END,
        CASE WHEN c.current_account_balance_pct_gdp_year IS NULL THEN 'CURRENT_ACCOUNT_BALANCE_PCT_GDP' END
    ], NULL) AS missing_indicator_codes,
    c.latest_published_at
FROM mart.mart_country_phase2_latest c;

CREATE OR REPLACE VIEW mart.mart_country_phase2_issues AS
SELECT
    rs.country_key,
    rs.iso_alpha_3,
    rs.country_name,
    rs.region_name,
    rs.income_group,
    rs.phase2_indicator_coverage_count,
    rs.phase2_indicator_gap_count,
    rs.labor_indicator_coverage_count,
    rs.macro_trade_external_indicator_coverage_count,
    rs.latest_phase2_observation_year,
    rs.phase2_coverage_status,
    rs.has_trade_pair,
    rs.has_external_balance_pair,
    rs.missing_indicator_codes,
    CASE
        WHEN rs.phase2_indicator_gap_count >= 3 THEN 'high'
        WHEN rs.phase2_indicator_gap_count >= 1 THEN 'medium'
        WHEN NOT rs.has_trade_pair OR NOT rs.has_external_balance_pair THEN 'medium'
        ELSE 'low'
    END AS issue_severity,
    ARRAY_REMOVE(ARRAY[
        CASE WHEN rs.phase2_indicator_gap_count > 0 THEN 'coverage_gap' END,
        CASE WHEN rs.latest_phase2_observation_year IS NULL THEN 'no_phase2_data' END,
        CASE WHEN rs.latest_phase2_observation_year IS NOT NULL AND rs.latest_phase2_observation_year < 2022 THEN 'stale_latest_year' END,
        CASE WHEN NOT rs.has_trade_pair THEN 'missing_trade_pair' END,
        CASE WHEN NOT rs.has_external_balance_pair THEN 'missing_external_balance_pair' END
    ], NULL) AS issue_flags,
    rs.latest_published_at
FROM mart.mart_country_phase2_readiness_summary rs
WHERE rs.phase2_coverage_status <> 'complete'
   OR rs.latest_phase2_observation_year IS NULL
   OR rs.latest_phase2_observation_year < 2022
   OR NOT rs.has_trade_pair
   OR NOT rs.has_external_balance_pair;

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

CREATE OR REPLACE VIEW mart.vw_macro_coverage_gaps AS
WITH latest_dataset_batch AS (
    SELECT
        source_dataset_key,
        MAX(source_batch_key) AS source_batch_key
    FROM raw.source_batch
    GROUP BY source_dataset_key
)
SELECT
    s.country_key,
    COALESCE(dc.iso_alpha_3, 'UNMAPPED') AS iso_alpha_3,
    COALESCE(dc.country_name, 'Unmapped country') AS country_name,
    s.indicator_key,
    COALESCE(di.indicator_code, 'UNMAPPED') AS indicator_code,
    COALESCE(di.indicator_name, 'Unmapped indicator') AS indicator_name,
    s.time_key,
    s.observation_year,
    CASE
        WHEN s.country_key IS NULL OR s.indicator_key IS NULL THEN 'mapping_gap'
        WHEN s.missingness_status = 'missing_at_source' THEN 'absent_at_source'
        WHEN s.is_parse_error OR s.missingness_status = 'parse_failed' THEN 'parse_failure'
        WHEN EXISTS (
            SELECT 1
            FROM audit.data_quality_event dqe
            WHERE dqe.staging_row_key = s.staging_row_key
              AND dqe.blocks_publication = TRUE
        ) THEN 'qa_blocked'
        ELSE 'not_published'
    END AS gap_reason,
    s.mapping_status,
    s.missingness_status,
    s.quality_flags,
    COUNT(dqe.data_quality_event_key) FILTER (WHERE dqe.blocks_publication = TRUE) AS blocking_event_count,
    ARRAY_REMOVE(ARRAY_AGG(DISTINCT dqe.event_code), NULL) AS qa_event_codes,
    s.source_batch_key,
    s.source_dataset_key,
    s.source_series_key
FROM staging.country_observation_annual s
JOIN latest_dataset_batch ldb
  ON ldb.source_dataset_key = s.source_dataset_key
 AND ldb.source_batch_key = s.source_batch_key
LEFT JOIN core.dim_country dc ON dc.country_key = s.country_key
LEFT JOIN core.dim_indicator di ON di.indicator_key = s.indicator_key
LEFT JOIN audit.data_quality_event dqe ON dqe.staging_row_key = s.staging_row_key
WHERE NOT EXISTS (
    SELECT 1
    FROM core.fact_country_indicator_published fp
    WHERE fp.country_key = s.country_key
      AND fp.indicator_key = s.indicator_key
      AND fp.time_key = s.time_key
)
GROUP BY
    s.country_key,
    dc.iso_alpha_3,
    dc.country_name,
    s.indicator_key,
    di.indicator_code,
    di.indicator_name,
    s.time_key,
    s.observation_year,
    s.mapping_status,
    s.missingness_status,
    s.quality_flags,
    s.is_parse_error,
    s.staging_row_key,
    s.source_batch_key,
    s.source_dataset_key,
    s.source_series_key;

CREATE OR REPLACE VIEW mart.vw_dataset_freshness_status AS
SELECT
    df.source_dataset_key,
    dd.dataset_code,
    dd.dataset_name,
    ds.source_code,
    ds.source_name,
    df.latest_successful_fetch_at,
    df.latest_source_released_at,
    df.latest_published_at,
    df.latest_published_year,
    df.freshness_status,
    df.is_stale,
    df.last_error_at,
    df.last_pipeline_run_key,
    apr.status_code AS last_pipeline_run_status,
    df.last_source_batch_key
FROM audit.dataset_freshness df
JOIN core.dim_dataset dd ON dd.source_dataset_key = df.source_dataset_key
JOIN core.dim_source ds ON ds.source_system_key = dd.source_system_key
LEFT JOIN audit.pipeline_run apr ON apr.pipeline_run_key = df.last_pipeline_run_key;

CREATE OR REPLACE VIEW mart.dataset_pipeline_health AS
WITH latest_source_batch AS (
    SELECT DISTINCT ON (sb.source_dataset_key)
        sb.source_dataset_key,
        sb.source_batch_key,
        sb.batch_external_id,
        sb.request_uri,
        sb.fetched_at,
        sb.source_released_at,
        sb.ingest_status,
        sb.row_count_reported,
        sb.created_at
    FROM raw.source_batch sb
    ORDER BY sb.source_dataset_key,
             COALESCE(sb.source_released_at, sb.fetched_at) DESC,
             sb.source_batch_key DESC
),
recent_batch_stats AS (
    SELECT
        sb.source_dataset_key,
        COUNT(*) AS source_batch_count_lifetime,
        COUNT(*) FILTER (
            WHERE sb.created_at >= CURRENT_TIMESTAMP - INTERVAL '7 days'
        ) AS source_batch_count_7d,
        COUNT(*) FILTER (
            WHERE sb.ingest_status = 'failed'
        ) AS failed_source_batch_count_lifetime,
        COUNT(*) FILTER (
            WHERE sb.ingest_status = 'failed'
              AND sb.created_at >= CURRENT_TIMESTAMP - INTERVAL '7 days'
        ) AS failed_source_batch_count_7d
    FROM raw.source_batch sb
    GROUP BY sb.source_dataset_key
),
latest_pipeline_run AS (
    SELECT DISTINCT ON (apr.source_dataset_key)
        apr.source_dataset_key,
        apr.pipeline_run_key,
        apr.pipeline_stage,
        apr.source_batch_key,
        apr.started_at,
        apr.completed_at,
        apr.status_code,
        apr.row_count_in,
        apr.row_count_out,
        apr.notes
    FROM audit.pipeline_run apr
    WHERE apr.source_dataset_key IS NOT NULL
    ORDER BY apr.source_dataset_key, apr.started_at DESC, apr.pipeline_run_key DESC
),
latest_publish_run AS (
    SELECT DISTINCT ON (apr.source_dataset_key)
        apr.source_dataset_key,
        apr.pipeline_run_key,
        apr.source_batch_key,
        apr.started_at,
        apr.completed_at,
        apr.status_code,
        apr.row_count_in,
        apr.row_count_out,
        apr.notes
    FROM audit.pipeline_run apr
    WHERE apr.source_dataset_key IS NOT NULL
      AND apr.pipeline_stage = 'publish'
    ORDER BY apr.source_dataset_key, apr.started_at DESC, apr.pipeline_run_key DESC
),
latest_publish_run_dq AS (
    SELECT
        dqe.pipeline_run_key,
        COUNT(*) AS total_dq_event_count,
        COUNT(*) FILTER (WHERE dqe.blocks_publication = TRUE) AS blocking_qa_event_count,
        COUNT(*) FILTER (WHERE dqe.severity = 'warning') AS warning_qa_event_count,
        COUNT(*) FILTER (WHERE dqe.severity = 'error') AS error_qa_event_count
    FROM audit.data_quality_event dqe
    GROUP BY dqe.pipeline_run_key
),
published_stats AS (
    SELECT
        fp.source_dataset_key,
        COUNT(*) AS current_published_row_count
    FROM core.fact_country_indicator_published fp
    GROUP BY fp.source_dataset_key
)
SELECT
    sd.source_dataset_key,
    sd.dataset_code,
    sd.dataset_name,
    ss.source_system_key,
    ss.source_code,
    ss.source_name,
    sd.is_active,
    sd.is_active_for_ingest,
    sd.ingest_access_method,
    sd.ingest_base_endpoint,
    df.latest_successful_fetch_at,
    df.latest_source_released_at,
    df.latest_published_at,
    df.latest_published_year,
    COALESCE(df.freshness_status, 'never_published') AS freshness_status,
    COALESCE(df.is_stale, FALSE) AS is_stale,
    df.last_error_at,
    lsb.source_batch_key AS latest_source_batch_key,
    lsb.batch_external_id AS latest_batch_external_id,
    lsb.request_uri AS latest_batch_request_uri,
    lsb.fetched_at AS latest_batch_fetched_at,
    lsb.source_released_at AS latest_batch_source_released_at,
    lsb.ingest_status AS latest_batch_ingest_status,
    lsb.row_count_reported AS latest_batch_row_count_reported,
    COALESCE(rbs.source_batch_count_lifetime, 0) AS source_batch_count_lifetime,
    COALESCE(rbs.source_batch_count_7d, 0) AS source_batch_count_7d,
    COALESCE(rbs.failed_source_batch_count_lifetime, 0) AS failed_source_batch_count_lifetime,
    COALESCE(rbs.failed_source_batch_count_7d, 0) AS failed_source_batch_count_7d,
    lpr.pipeline_run_key AS latest_pipeline_run_key,
    lpr.pipeline_stage AS latest_pipeline_stage,
    lpr.source_batch_key AS latest_pipeline_source_batch_key,
    lpr.started_at AS latest_pipeline_started_at,
    lpr.completed_at AS latest_pipeline_completed_at,
    lpr.status_code AS latest_pipeline_status,
    lpr.row_count_in AS latest_pipeline_row_count_in,
    lpr.row_count_out AS latest_pipeline_row_count_out,
    lpr.notes AS latest_pipeline_notes,
    lpp.pipeline_run_key AS latest_publish_run_key,
    lpp.source_batch_key AS latest_publish_source_batch_key,
    lpp.started_at AS latest_publish_started_at,
    lpp.completed_at AS latest_publish_completed_at,
    lpp.status_code AS latest_publish_status,
    lpp.row_count_in AS latest_publish_row_count_in,
    lpp.row_count_out AS latest_publish_row_count_out,
    lpp.notes AS latest_publish_notes,
    COALESCE(lpdq.total_dq_event_count, 0) AS latest_publish_total_dq_event_count,
    COALESCE(lpdq.blocking_qa_event_count, 0) AS latest_publish_blocking_qa_event_count,
    COALESCE(lpdq.warning_qa_event_count, 0) AS latest_publish_warning_qa_event_count,
    COALESCE(lpdq.error_qa_event_count, 0) AS latest_publish_error_qa_event_count,
    COALESCE(ps.current_published_row_count, 0) AS current_published_row_count,
    ARRAY_REMOVE(ARRAY[
        CASE
            WHEN sd.is_active_for_ingest = TRUE AND lsb.source_batch_key IS NULL
                THEN 'no_source_batch_history'
        END,
        CASE
            WHEN lsb.ingest_status = 'failed'
                THEN 'latest_batch_failed'
        END,
        CASE
            WHEN lsb.source_batch_key IS NOT NULL
             AND COALESCE(lsb.row_count_reported, 0) = 0
                THEN 'latest_batch_zero_rows'
        END,
        CASE
            WHEN sd.is_active_for_ingest = TRUE
             AND COALESCE(df.freshness_status, 'never_published') <> 'fresh'
                THEN 'freshness_not_fresh'
        END,
        CASE
            WHEN lpr.pipeline_run_key IS NOT NULL
             AND lpr.status_code NOT IN ('succeeded', 'succeeded_with_warnings')
                THEN 'latest_pipeline_run_not_successful'
        END,
        CASE
            WHEN COALESCE(lpdq.blocking_qa_event_count, 0) > 0
                THEN 'blocking_qa_events_in_latest_publish_run'
        END,
        CASE
            WHEN lsb.source_batch_key IS NOT NULL
             AND (lpp.source_batch_key IS NULL OR lsb.source_batch_key > lpp.source_batch_key)
                THEN 'latest_batch_not_published_yet'
        END,
        CASE
            WHEN lpp.pipeline_run_key IS NOT NULL
             AND lsb.row_count_reported IS NOT NULL
             AND lpp.row_count_in IS NOT NULL
             AND lsb.row_count_reported <> lpp.row_count_in
                THEN 'latest_publish_input_row_count_mismatch'
        END
    ], NULL) AS anomaly_flags
FROM ref.source_dataset sd
JOIN ref.source_system ss ON ss.source_system_key = sd.source_system_key
LEFT JOIN audit.dataset_freshness df ON df.source_dataset_key = sd.source_dataset_key
LEFT JOIN latest_source_batch lsb ON lsb.source_dataset_key = sd.source_dataset_key
LEFT JOIN recent_batch_stats rbs ON rbs.source_dataset_key = sd.source_dataset_key
LEFT JOIN latest_pipeline_run lpr ON lpr.source_dataset_key = sd.source_dataset_key
LEFT JOIN latest_publish_run lpp ON lpp.source_dataset_key = sd.source_dataset_key
LEFT JOIN latest_publish_run_dq lpdq ON lpdq.pipeline_run_key = lpp.pipeline_run_key
LEFT JOIN published_stats ps ON ps.source_dataset_key = sd.source_dataset_key;

CREATE OR REPLACE VIEW mart.dataset_pipeline_alerts AS
WITH expanded AS (
    SELECT
        h.source_dataset_key,
        h.dataset_code,
        h.dataset_name,
        h.source_code,
        h.source_name,
        h.freshness_status,
        h.is_stale,
        h.latest_source_batch_key,
        h.latest_batch_external_id,
        h.latest_batch_fetched_at,
        h.latest_batch_ingest_status,
        h.latest_batch_row_count_reported,
        h.latest_pipeline_run_key,
        h.latest_pipeline_status,
        h.latest_publish_run_key,
        h.latest_publish_status,
        h.latest_publish_blocking_qa_event_count,
        h.failed_source_batch_count_7d,
        h.last_error_at,
        alert.flag AS alert_code
    FROM mart.dataset_pipeline_health h
    CROSS JOIN LATERAL unnest(h.anomaly_flags) AS alert(flag)
    WHERE h.is_active_for_ingest = TRUE
),
scored AS (
    SELECT
        e.*,
        CASE e.alert_code
            WHEN 'latest_batch_failed' THEN 'critical'
            WHEN 'blocking_qa_events_in_latest_publish_run' THEN 'critical'
            WHEN 'latest_pipeline_run_not_successful' THEN 'critical'
            WHEN 'latest_batch_not_published_yet' THEN 'warning'
            WHEN 'latest_batch_zero_rows' THEN 'warning'
            WHEN 'freshness_not_fresh' THEN 'warning'
            WHEN 'latest_publish_input_row_count_mismatch' THEN 'warning'
            WHEN 'no_source_batch_history' THEN 'warning'
            ELSE 'info'
        END AS alert_severity,
        CASE e.alert_code
            WHEN 'latest_batch_failed' THEN 'Latest source batch finished in failed status.'
            WHEN 'blocking_qa_events_in_latest_publish_run' THEN 'Latest publish run produced blocking QA events.'
            WHEN 'latest_pipeline_run_not_successful' THEN 'Latest pipeline run did not finish successfully.'
            WHEN 'latest_batch_not_published_yet' THEN 'Latest source batch exists but no publish run has consumed it yet.'
            WHEN 'latest_batch_zero_rows' THEN 'Latest source batch reported zero rows.'
            WHEN 'freshness_not_fresh' THEN 'Dataset freshness status is not fresh.'
            WHEN 'latest_publish_input_row_count_mismatch' THEN 'Latest publish input row count does not match the source batch row count.'
            WHEN 'no_source_batch_history' THEN 'Dataset is active for ingest but has no source batch history.'
            ELSE 'Unclassified pipeline alert.'
        END AS alert_message
    FROM expanded e
)
SELECT
    s.source_dataset_key,
    s.dataset_code,
    s.dataset_name,
    s.source_code,
    s.source_name,
    s.alert_severity,
    s.alert_code,
    s.alert_message,
    s.freshness_status,
    s.is_stale,
    s.latest_source_batch_key,
    s.latest_batch_external_id,
    s.latest_batch_fetched_at,
    s.latest_batch_ingest_status,
    s.latest_batch_row_count_reported,
    s.latest_pipeline_run_key,
    s.latest_pipeline_status,
    s.latest_publish_run_key,
    s.latest_publish_status,
    s.latest_publish_blocking_qa_event_count,
    s.failed_source_batch_count_7d,
    s.last_error_at
FROM scored s
ORDER BY
    CASE s.alert_severity
        WHEN 'critical' THEN 1
        WHEN 'warning' THEN 2
        ELSE 3
    END,
    s.dataset_code,
    s.alert_code;

CREATE OR REPLACE VIEW mart.vw_labor_source_conflicts AS
WITH labor_versions AS (
    SELECT
        fv.observation_version_key,
        fv.country_key,
        dc.iso_alpha_3,
        dc.country_name,
        dc.region_name,
        dc.income_group,
        fv.indicator_key,
        di.indicator_code,
        di.indicator_name,
        fv.time_key,
        dt.calendar_year AS observation_year,
        fv.observation_value,
        fv.source_system_key,
        ds.source_code,
        ds.source_name,
        fv.source_dataset_key,
        dd.dataset_code,
        dd.dataset_name,
        fv.source_series_key,
        rs.series_code,
        rs.series_name,
        fv.source_batch_key,
        fv.source_released_at,
        fv.selection_method,
        fv.quality_status,
        fv.status_code,
        fv.is_latest_source_version,
        fv.first_seen_at,
        fv.superseded_at
    FROM core.fact_country_indicator_version fv
    JOIN core.dim_country dc ON dc.country_key = fv.country_key
    JOIN core.dim_indicator di ON di.indicator_key = fv.indicator_key
    JOIN core.dim_time dt ON dt.time_key = fv.time_key
    JOIN core.dim_source ds ON ds.source_system_key = fv.source_system_key
    JOIN core.dim_dataset dd ON dd.source_dataset_key = fv.source_dataset_key
    LEFT JOIN ref.source_series rs ON rs.source_series_key = fv.source_series_key
    WHERE di.indicator_code IN (
        'EMPLOYMENT_RATE_PCT',
        'LABOR_FORCE_PARTICIPATION_RATE_PCT',
        'UNEMPLOYMENT_RATE_PCT'
    )
),
conflicted_keys AS (
    SELECT
        country_key,
        indicator_key,
        time_key
    FROM labor_versions
    GROUP BY country_key, indicator_key, time_key
    HAVING COUNT(DISTINCT source_dataset_key) > 1
),
selected_rows AS (
    SELECT
        ranked_selected_rows.country_key,
        ranked_selected_rows.indicator_key,
        ranked_selected_rows.time_key,
        ranked_selected_rows.selected_observation_version_key,
        ranked_selected_rows.selected_dataset_code,
        ranked_selected_rows.selected_dataset_name,
        ranked_selected_rows.selected_source_code,
        ranked_selected_rows.selected_series_code,
        ranked_selected_rows.selected_observation_value,
        ranked_selected_rows.selected_selection_method,
        ranked_selected_rows.selected_priority_rank,
        ranked_selected_rows.selected_is_override,
        ranked_selected_rows.selected_selection_rationale,
        ranked_selected_rows.publication_version_code,
        ranked_selected_rows.selected_published_at
    FROM (
        SELECT
            m.country_key,
            m.indicator_key,
            m.time_key,
            m.observation_version_key AS selected_observation_version_key,
            m.dataset_code AS selected_dataset_code,
            m.dataset_name AS selected_dataset_name,
            m.source_code AS selected_source_code,
            m.series_code AS selected_series_code,
            m.observation_value AS selected_observation_value,
            m.selection_method AS selected_selection_method,
            m.priority_rank AS selected_priority_rank,
            m.is_override AS selected_is_override,
            m.selection_rationale AS selected_selection_rationale,
            m.publication_version_code,
            m.published_at AS selected_published_at,
            ROW_NUMBER() OVER (
                PARTITION BY m.country_key, m.indicator_key, m.time_key
                ORDER BY m.published_at DESC, m.publication_version_code DESC, m.observation_version_key DESC
            ) AS publication_recency_rank
        FROM mart.vw_macro_source_selection_lineage m
        WHERE m.indicator_code IN (
            'EMPLOYMENT_RATE_PCT',
            'LABOR_FORCE_PARTICIPATION_RATE_PCT',
            'UNEMPLOYMENT_RATE_PCT'
        )
    ) ranked_selected_rows
    WHERE ranked_selected_rows.publication_recency_rank = 1
)
SELECT
    lv.country_key,
    lv.iso_alpha_3,
    lv.country_name,
    lv.region_name,
    lv.income_group,
    lv.indicator_key,
    lv.indicator_code,
    lv.indicator_name,
    lv.time_key,
    lv.observation_year,
    lv.observation_version_key,
    lv.observation_value,
    lv.source_system_key,
    lv.source_code,
    lv.source_name,
    lv.source_dataset_key,
    lv.dataset_code,
    lv.dataset_name,
    lv.source_series_key,
    lv.series_code,
    lv.series_name,
    lv.source_batch_key,
    lv.source_released_at,
    lv.selection_method,
    lv.quality_status,
    lv.status_code,
    lv.is_latest_source_version,
    lv.first_seen_at,
    lv.superseded_at,
    sr.selected_observation_version_key,
    sr.selected_dataset_code,
    sr.selected_dataset_name,
    sr.selected_source_code,
    sr.selected_series_code,
    sr.selected_observation_value,
    sr.selected_selection_method,
    sr.selected_priority_rank,
    sr.selected_is_override,
    sr.selected_selection_rationale,
    sr.publication_version_code,
    sr.selected_published_at,
    (lv.observation_version_key = sr.selected_observation_version_key) AS is_selected_published_row
FROM labor_versions lv
JOIN conflicted_keys ck
  ON ck.country_key = lv.country_key
 AND ck.indicator_key = lv.indicator_key
 AND ck.time_key = lv.time_key
JOIN selected_rows sr
  ON sr.country_key = lv.country_key
 AND sr.indicator_key = lv.indicator_key
 AND sr.time_key = lv.time_key;

CREATE OR REPLACE VIEW mart.vw_labor_source_conflicts_latest AS
WITH ranked_conflicts AS (
    SELECT
        lc.*,
        ROW_NUMBER() OVER (
            PARTITION BY lc.country_key, lc.indicator_key, lc.time_key, lc.source_dataset_key
            ORDER BY COALESCE(lc.source_released_at, lc.first_seen_at) DESC,
                     lc.source_batch_key DESC,
                     lc.observation_version_key DESC
        ) AS dataset_recency_rank
    FROM mart.vw_labor_source_conflicts lc
)
SELECT
    country_key,
    iso_alpha_3,
    country_name,
    region_name,
    income_group,
    indicator_key,
    indicator_code,
    indicator_name,
    time_key,
    observation_year,
    observation_version_key,
    observation_value,
    source_system_key,
    source_code,
    source_name,
    source_dataset_key,
    dataset_code,
    dataset_name,
    source_series_key,
    series_code,
    series_name,
    source_batch_key,
    source_released_at,
    selection_method,
    quality_status,
    status_code,
    is_latest_source_version,
    first_seen_at,
    superseded_at,
    selected_observation_version_key,
    selected_dataset_code,
    selected_dataset_name,
    selected_source_code,
    selected_series_code,
    selected_observation_value,
    selected_selection_method,
    selected_priority_rank,
    selected_is_override,
    selected_selection_rationale,
    publication_version_code,
    selected_published_at,
    is_selected_published_row
FROM ranked_conflicts
WHERE dataset_recency_rank = 1;

CREATE OR REPLACE VIEW mart.vw_labor_source_conflict_summary_latest AS
SELECT
    country_key,
    iso_alpha_3,
    country_name,
    region_name,
    income_group,
    indicator_key,
    indicator_code,
    indicator_name,
    time_key,
    observation_year,
    COUNT(*) AS competing_dataset_count,
    MAX(selected_dataset_code) AS selected_dataset_code,
    MAX(selected_dataset_name) AS selected_dataset_name,
    MAX(selected_source_code) AS selected_source_code,
    MAX(selected_series_code) AS selected_series_code,
    MAX(selected_observation_value) AS selected_observation_value,
    MAX(selected_selection_method) AS selected_selection_method,
    MAX(selected_priority_rank) AS selected_priority_rank,
    BOOL_OR(selected_is_override) AS selected_is_override,
    MAX(selected_selection_rationale) AS selected_selection_rationale,
    MAX(publication_version_code) AS publication_version_code,
    MAX(selected_published_at) AS selected_published_at,
    MIN(observation_value) AS min_conflicting_value,
    MAX(observation_value) AS max_conflicting_value,
    MAX(observation_value) - MIN(observation_value) AS conflicting_value_spread,
    STRING_AGG(
        dataset_code || '=' || observation_value::TEXT || CASE WHEN is_selected_published_row THEN ' [selected]' ELSE '' END,
        ' | '
        ORDER BY dataset_code
    ) AS candidate_dataset_values
FROM mart.vw_labor_source_conflicts_latest
GROUP BY
    country_key,
    iso_alpha_3,
    country_name,
    region_name,
    income_group,
    indicator_key,
    indicator_code,
    indicator_name,
    time_key,
    observation_year;

CREATE OR REPLACE VIEW mart.vw_labor_source_conflict_summary AS
SELECT *
FROM mart.vw_labor_source_conflict_summary_latest;

CREATE OR REPLACE VIEW mart.vw_labor_revision_history AS
SELECT
    mrh.revision_event_key,
    mrh.changed_at,
    mrh.change_type,
    mrh.iso_alpha_3,
    mrh.country_name,
    mrh.indicator_code,
    mrh.indicator_name,
    mrh.observation_year,
    mrh.previous_value,
    mrh.new_value,
    mrh.previous_source_batch_key,
    mrh.new_source_batch_key,
    mrh.previous_dataset_code,
    mrh.new_dataset_code,
    mrh.pipeline_run_key,
    mrh.pipeline_run_status,
    mrh.notes,
    mrh.previous_selection_rule_version_ref,
    mrh.new_selection_rule_version_ref,
    mrh.new_comparability_break_flag,
    mrh.new_comparability_break_note
FROM mart.vw_macro_revision_history mrh
WHERE mrh.indicator_code IN (
    'EMPLOYMENT_RATE_PCT',
    'LABOR_FORCE_PARTICIPATION_RATE_PCT',
    'UNEMPLOYMENT_RATE_PCT'
);

CREATE OR REPLACE VIEW mart.vw_inflation_source_conflicts AS
WITH inflation_versions AS (
    SELECT
        fv.observation_version_key,
        fv.country_key,
        dc.iso_alpha_3,
        dc.country_name,
        dc.region_name,
        dc.income_group,
        fv.indicator_key,
        di.indicator_code,
        di.indicator_name,
        fv.time_key,
        dt.calendar_year AS observation_year,
        fv.observation_value,
        fv.source_system_key,
        ds.source_code,
        ds.source_name,
        fv.source_dataset_key,
        dd.dataset_code,
        dd.dataset_name,
        fv.source_series_key,
        rs.series_code,
        rs.series_name,
        fv.source_batch_key,
        fv.source_released_at,
        fv.selection_method,
        fv.quality_status,
        fv.status_code,
        fv.is_latest_source_version,
        fv.first_seen_at,
        fv.superseded_at
    FROM core.fact_country_indicator_version fv
    JOIN core.dim_country dc ON dc.country_key = fv.country_key
    JOIN core.dim_indicator di ON di.indicator_key = fv.indicator_key
    JOIN core.dim_time dt ON dt.time_key = fv.time_key
    JOIN core.dim_source ds ON ds.source_system_key = fv.source_system_key
    JOIN core.dim_dataset dd ON dd.source_dataset_key = fv.source_dataset_key
    LEFT JOIN ref.source_series rs ON rs.source_series_key = fv.source_series_key
    WHERE di.indicator_code = 'INFLATION_CPI_PCT'
),
conflicted_keys AS (
    SELECT
        country_key,
        indicator_key,
        time_key
    FROM inflation_versions
    GROUP BY country_key, indicator_key, time_key
    HAVING COUNT(DISTINCT source_dataset_key) > 1
),
selected_rows AS (
    SELECT
        ranked_selected_rows.country_key,
        ranked_selected_rows.indicator_key,
        ranked_selected_rows.time_key,
        ranked_selected_rows.selected_observation_version_key,
        ranked_selected_rows.selected_dataset_code,
        ranked_selected_rows.selected_dataset_name,
        ranked_selected_rows.selected_source_code,
        ranked_selected_rows.selected_series_code,
        ranked_selected_rows.selected_observation_value,
        ranked_selected_rows.selected_selection_method,
        ranked_selected_rows.selected_priority_rank,
        ranked_selected_rows.selected_is_override,
        ranked_selected_rows.selected_selection_rationale,
        ranked_selected_rows.publication_version_code,
        ranked_selected_rows.selected_published_at
    FROM (
        SELECT
            m.country_key,
            m.indicator_key,
            m.time_key,
            m.observation_version_key AS selected_observation_version_key,
            m.dataset_code AS selected_dataset_code,
            m.dataset_name AS selected_dataset_name,
            m.source_code AS selected_source_code,
            m.series_code AS selected_series_code,
            m.observation_value AS selected_observation_value,
            m.selection_method AS selected_selection_method,
            m.priority_rank AS selected_priority_rank,
            m.is_override AS selected_is_override,
            m.selection_rationale AS selected_selection_rationale,
            m.publication_version_code,
            m.published_at AS selected_published_at,
            ROW_NUMBER() OVER (
                PARTITION BY m.country_key, m.indicator_key, m.time_key
                ORDER BY m.published_at DESC, m.publication_version_code DESC, m.observation_version_key DESC
            ) AS publication_recency_rank
        FROM mart.vw_macro_source_selection_lineage m
        WHERE m.indicator_code = 'INFLATION_CPI_PCT'
    ) ranked_selected_rows
    WHERE ranked_selected_rows.publication_recency_rank = 1
)
SELECT
    iv.country_key,
    iv.iso_alpha_3,
    iv.country_name,
    iv.region_name,
    iv.income_group,
    iv.indicator_key,
    iv.indicator_code,
    iv.indicator_name,
    iv.time_key,
    iv.observation_year,
    iv.observation_version_key,
    iv.observation_value,
    iv.source_system_key,
    iv.source_code,
    iv.source_name,
    iv.source_dataset_key,
    iv.dataset_code,
    iv.dataset_name,
    iv.source_series_key,
    iv.series_code,
    iv.series_name,
    iv.source_batch_key,
    iv.source_released_at,
    iv.selection_method,
    iv.quality_status,
    iv.status_code,
    iv.is_latest_source_version,
    iv.first_seen_at,
    iv.superseded_at,
    sr.selected_observation_version_key,
    sr.selected_dataset_code,
    sr.selected_dataset_name,
    sr.selected_source_code,
    sr.selected_series_code,
    sr.selected_observation_value,
    sr.selected_selection_method,
    sr.selected_priority_rank,
    sr.selected_is_override,
    sr.selected_selection_rationale,
    sr.publication_version_code,
    sr.selected_published_at,
    (iv.observation_version_key = sr.selected_observation_version_key) AS is_selected_published_row
FROM inflation_versions iv
JOIN conflicted_keys ck
  ON ck.country_key = iv.country_key
 AND ck.indicator_key = iv.indicator_key
 AND ck.time_key = iv.time_key
JOIN selected_rows sr
  ON sr.country_key = iv.country_key
 AND sr.indicator_key = iv.indicator_key
 AND sr.time_key = iv.time_key;

CREATE OR REPLACE VIEW mart.vw_inflation_source_conflicts_latest AS
WITH ranked_conflicts AS (
    SELECT
        ic.*,
        ROW_NUMBER() OVER (
            PARTITION BY ic.country_key, ic.indicator_key, ic.time_key, ic.source_dataset_key
            ORDER BY COALESCE(ic.source_released_at, ic.first_seen_at) DESC,
                     ic.source_batch_key DESC,
                     ic.observation_version_key DESC
        ) AS dataset_recency_rank
    FROM mart.vw_inflation_source_conflicts ic
)
SELECT
    country_key,
    iso_alpha_3,
    country_name,
    region_name,
    income_group,
    indicator_key,
    indicator_code,
    indicator_name,
    time_key,
    observation_year,
    observation_version_key,
    observation_value,
    source_system_key,
    source_code,
    source_name,
    source_dataset_key,
    dataset_code,
    dataset_name,
    source_series_key,
    series_code,
    series_name,
    source_batch_key,
    source_released_at,
    selection_method,
    quality_status,
    status_code,
    is_latest_source_version,
    first_seen_at,
    superseded_at,
    selected_observation_version_key,
    selected_dataset_code,
    selected_dataset_name,
    selected_source_code,
    selected_series_code,
    selected_observation_value,
    selected_selection_method,
    selected_priority_rank,
    selected_is_override,
    selected_selection_rationale,
    publication_version_code,
    selected_published_at,
    is_selected_published_row
FROM ranked_conflicts
WHERE dataset_recency_rank = 1;

CREATE OR REPLACE VIEW mart.vw_inflation_source_conflict_summary_latest AS
SELECT
    country_key,
    iso_alpha_3,
    country_name,
    region_name,
    income_group,
    indicator_key,
    indicator_code,
    indicator_name,
    time_key,
    observation_year,
    COUNT(*) AS competing_dataset_count,
    MAX(selected_dataset_code) AS selected_dataset_code,
    MAX(selected_dataset_name) AS selected_dataset_name,
    MAX(selected_source_code) AS selected_source_code,
    MAX(selected_series_code) AS selected_series_code,
    MAX(selected_observation_value) AS selected_observation_value,
    MAX(selected_selection_method) AS selected_selection_method,
    MAX(selected_priority_rank) AS selected_priority_rank,
    BOOL_OR(selected_is_override) AS selected_is_override,
    MAX(selected_selection_rationale) AS selected_selection_rationale,
    MAX(publication_version_code) AS publication_version_code,
    MAX(selected_published_at) AS selected_published_at,
    MIN(observation_value) AS min_conflicting_value,
    MAX(observation_value) AS max_conflicting_value,
    MAX(observation_value) - MIN(observation_value) AS conflicting_value_spread,
    STRING_AGG(
        dataset_code || '=' || observation_value::TEXT || CASE WHEN is_selected_published_row THEN ' [selected]' ELSE '' END,
        ' | '
        ORDER BY dataset_code
    ) AS candidate_dataset_values
FROM mart.vw_inflation_source_conflicts_latest
GROUP BY
    country_key,
    iso_alpha_3,
    country_name,
    region_name,
    income_group,
    indicator_key,
    indicator_code,
    indicator_name,
    time_key,
    observation_year;

CREATE OR REPLACE VIEW mart.vw_inflation_source_conflict_summary AS
SELECT *
FROM mart.vw_inflation_source_conflict_summary_latest;

CREATE OR REPLACE VIEW mart.vw_gdp_source_conflicts AS
WITH gdp_versions AS (
    SELECT
        fv.observation_version_key,
        fv.country_key,
        dc.iso_alpha_3,
        dc.country_name,
        dc.region_name,
        dc.income_group,
        fv.indicator_key,
        di.indicator_code,
        di.indicator_name,
        fv.time_key,
        dt.calendar_year AS observation_year,
        fv.observation_value,
        fv.source_system_key,
        ds.source_code,
        ds.source_name,
        fv.source_dataset_key,
        dd.dataset_code,
        dd.dataset_name,
        fv.source_series_key,
        rs.series_code,
        rs.series_name,
        fv.source_batch_key,
        fv.source_released_at,
        fv.selection_method,
        fv.quality_status,
        fv.status_code,
        fv.is_latest_source_version,
        fv.first_seen_at,
        fv.superseded_at
    FROM core.fact_country_indicator_version fv
    JOIN core.dim_country dc ON dc.country_key = fv.country_key
    JOIN core.dim_indicator di ON di.indicator_key = fv.indicator_key
    JOIN core.dim_time dt ON dt.time_key = fv.time_key
    JOIN core.dim_source ds ON ds.source_system_key = fv.source_system_key
    JOIN core.dim_dataset dd ON dd.source_dataset_key = fv.source_dataset_key
    LEFT JOIN ref.source_series rs ON rs.source_series_key = fv.source_series_key
    WHERE di.indicator_code = 'GDP_CURR_USD'
),
conflicted_keys AS (
    SELECT
        country_key,
        indicator_key,
        time_key
    FROM gdp_versions
    GROUP BY country_key, indicator_key, time_key
    HAVING COUNT(DISTINCT source_dataset_key) > 1
),
selected_rows AS (
    SELECT
        ranked_selected_rows.country_key,
        ranked_selected_rows.indicator_key,
        ranked_selected_rows.time_key,
        ranked_selected_rows.selected_observation_version_key,
        ranked_selected_rows.selected_dataset_code,
        ranked_selected_rows.selected_dataset_name,
        ranked_selected_rows.selected_source_code,
        ranked_selected_rows.selected_series_code,
        ranked_selected_rows.selected_observation_value,
        ranked_selected_rows.selected_selection_method,
        ranked_selected_rows.selected_priority_rank,
        ranked_selected_rows.selected_is_override,
        ranked_selected_rows.selected_selection_rationale,
        ranked_selected_rows.publication_version_code,
        ranked_selected_rows.selected_published_at
    FROM (
        SELECT
            m.country_key,
            m.indicator_key,
            m.time_key,
            m.observation_version_key AS selected_observation_version_key,
            m.dataset_code AS selected_dataset_code,
            m.dataset_name AS selected_dataset_name,
            m.source_code AS selected_source_code,
            m.series_code AS selected_series_code,
            m.observation_value AS selected_observation_value,
            m.selection_method AS selected_selection_method,
            m.priority_rank AS selected_priority_rank,
            m.is_override AS selected_is_override,
            m.selection_rationale AS selected_selection_rationale,
            m.publication_version_code,
            m.published_at AS selected_published_at,
            ROW_NUMBER() OVER (
                PARTITION BY m.country_key, m.indicator_key, m.time_key
                ORDER BY m.published_at DESC, m.publication_version_code DESC, m.observation_version_key DESC
            ) AS publication_recency_rank
        FROM mart.vw_macro_source_selection_lineage m
        WHERE m.indicator_code = 'GDP_CURR_USD'
    ) ranked_selected_rows
    WHERE ranked_selected_rows.publication_recency_rank = 1
)
SELECT
    gv.country_key,
    gv.iso_alpha_3,
    gv.country_name,
    gv.region_name,
    gv.income_group,
    gv.indicator_key,
    gv.indicator_code,
    gv.indicator_name,
    gv.time_key,
    gv.observation_year,
    gv.observation_version_key,
    gv.observation_value,
    gv.source_system_key,
    gv.source_code,
    gv.source_name,
    gv.source_dataset_key,
    gv.dataset_code,
    gv.dataset_name,
    gv.source_series_key,
    gv.series_code,
    gv.series_name,
    gv.source_batch_key,
    gv.source_released_at,
    gv.selection_method,
    gv.quality_status,
    gv.status_code,
    gv.is_latest_source_version,
    gv.first_seen_at,
    gv.superseded_at,
    sr.selected_observation_version_key,
    sr.selected_dataset_code,
    sr.selected_dataset_name,
    sr.selected_source_code,
    sr.selected_series_code,
    sr.selected_observation_value,
    sr.selected_selection_method,
    sr.selected_priority_rank,
    sr.selected_is_override,
    sr.selected_selection_rationale,
    sr.publication_version_code,
    sr.selected_published_at,
    (gv.observation_version_key = sr.selected_observation_version_key) AS is_selected_published_row
FROM gdp_versions gv
JOIN conflicted_keys ck
  ON ck.country_key = gv.country_key
 AND ck.indicator_key = gv.indicator_key
 AND ck.time_key = gv.time_key
JOIN selected_rows sr
  ON sr.country_key = gv.country_key
 AND sr.indicator_key = gv.indicator_key
 AND sr.time_key = gv.time_key;

CREATE OR REPLACE VIEW mart.vw_gdp_source_conflicts_latest AS
WITH ranked_conflicts AS (
    SELECT
        gc.*,
        ROW_NUMBER() OVER (
            PARTITION BY gc.country_key, gc.indicator_key, gc.time_key, gc.source_dataset_key
            ORDER BY COALESCE(gc.source_released_at, gc.first_seen_at) DESC,
                     gc.source_batch_key DESC,
                     gc.observation_version_key DESC
        ) AS dataset_recency_rank
    FROM mart.vw_gdp_source_conflicts gc
)
SELECT
    country_key,
    iso_alpha_3,
    country_name,
    region_name,
    income_group,
    indicator_key,
    indicator_code,
    indicator_name,
    time_key,
    observation_year,
    observation_version_key,
    observation_value,
    source_system_key,
    source_code,
    source_name,
    source_dataset_key,
    dataset_code,
    dataset_name,
    source_series_key,
    series_code,
    series_name,
    source_batch_key,
    source_released_at,
    selection_method,
    quality_status,
    status_code,
    is_latest_source_version,
    first_seen_at,
    superseded_at,
    selected_observation_version_key,
    selected_dataset_code,
    selected_dataset_name,
    selected_source_code,
    selected_series_code,
    selected_observation_value,
    selected_selection_method,
    selected_priority_rank,
    selected_is_override,
    selected_selection_rationale,
    publication_version_code,
    selected_published_at,
    is_selected_published_row
FROM ranked_conflicts
WHERE dataset_recency_rank = 1;

CREATE OR REPLACE VIEW mart.vw_gdp_source_conflict_summary_latest AS
SELECT
    country_key,
    iso_alpha_3,
    country_name,
    region_name,
    income_group,
    indicator_key,
    indicator_code,
    indicator_name,
    time_key,
    observation_year,
    COUNT(*) AS competing_dataset_count,
    MAX(selected_dataset_code) AS selected_dataset_code,
    MAX(selected_dataset_name) AS selected_dataset_name,
    MAX(selected_source_code) AS selected_source_code,
    MAX(selected_series_code) AS selected_series_code,
    MAX(selected_observation_value) AS selected_observation_value,
    MAX(selected_selection_method) AS selected_selection_method,
    MAX(selected_priority_rank) AS selected_priority_rank,
    BOOL_OR(selected_is_override) AS selected_is_override,
    MAX(selected_selection_rationale) AS selected_selection_rationale,
    MAX(publication_version_code) AS publication_version_code,
    MAX(selected_published_at) AS selected_published_at,
    MIN(observation_value) AS min_conflicting_value,
    MAX(observation_value) AS max_conflicting_value,
    MAX(observation_value) - MIN(observation_value) AS conflicting_value_spread,
    STRING_AGG(
        dataset_code || '=' || observation_value::TEXT || CASE WHEN is_selected_published_row THEN ' [selected]' ELSE '' END,
        ' | '
        ORDER BY dataset_code
    ) AS candidate_dataset_values
FROM mart.vw_gdp_source_conflicts_latest
GROUP BY
    country_key,
    iso_alpha_3,
    country_name,
    region_name,
    income_group,
    indicator_key,
    indicator_code,
    indicator_name,
    time_key,
    observation_year;

CREATE OR REPLACE VIEW mart.vw_gdp_source_conflict_summary AS
SELECT *
FROM mart.vw_gdp_source_conflict_summary_latest;

CREATE OR REPLACE VIEW mart.vw_phase2_source_conflict_summary AS
SELECT
    'labor'::text AS conflict_family,
    'Phase 2 labor overlap proof'::text AS conflict_scope,
    l.country_key,
    l.iso_alpha_3,
    l.country_name,
    l.region_name,
    l.income_group,
    l.indicator_key,
    l.indicator_code,
    l.indicator_name,
    l.time_key,
    l.observation_year,
    l.competing_dataset_count,
    l.selected_dataset_code,
    l.selected_dataset_name,
    l.selected_source_code,
    l.selected_series_code,
    l.selected_observation_value,
    l.selected_selection_method,
    l.selected_priority_rank,
    l.selected_is_override,
    l.selected_selection_rationale,
    l.publication_version_code,
    l.selected_published_at,
    l.min_conflicting_value,
    l.max_conflicting_value,
    l.conflicting_value_spread,
    l.candidate_dataset_values
FROM mart.vw_labor_source_conflict_summary l
UNION ALL
SELECT
    'inflation'::text AS conflict_family,
    'IFS-vs-WDI inflation overlap proof'::text AS conflict_scope,
    i.country_key,
    i.iso_alpha_3,
    i.country_name,
    i.region_name,
    i.income_group,
    i.indicator_key,
    i.indicator_code,
    i.indicator_name,
    i.time_key,
    i.observation_year,
    i.competing_dataset_count,
    i.selected_dataset_code,
    i.selected_dataset_name,
    i.selected_source_code,
    i.selected_series_code,
    i.selected_observation_value,
    i.selected_selection_method,
    i.selected_priority_rank,
    i.selected_is_override,
    i.selected_selection_rationale,
    i.publication_version_code,
    i.selected_published_at,
    i.min_conflicting_value,
    i.max_conflicting_value,
    i.conflicting_value_spread,
    i.candidate_dataset_values
FROM mart.vw_inflation_source_conflict_summary i
UNION ALL
SELECT
    'gdp'::text AS conflict_family,
    'IFS-vs-WDI GDP overlap proof'::text AS conflict_scope,
    g.country_key,
    g.iso_alpha_3,
    g.country_name,
    g.region_name,
    g.income_group,
    g.indicator_key,
    g.indicator_code,
    g.indicator_name,
    g.time_key,
    g.observation_year,
    g.competing_dataset_count,
    g.selected_dataset_code,
    g.selected_dataset_name,
    g.selected_source_code,
    g.selected_series_code,
    g.selected_observation_value,
    g.selected_selection_method,
    g.selected_priority_rank,
    g.selected_is_override,
    g.selected_selection_rationale,
    g.publication_version_code,
    g.selected_published_at,
    g.min_conflicting_value,
    g.max_conflicting_value,
    g.conflicting_value_spread,
    g.candidate_dataset_values
FROM mart.vw_gdp_source_conflict_summary g;

CREATE OR REPLACE VIEW mart.vw_trade_external_revision_history AS
SELECT
    mrh.revision_event_key,
    mrh.changed_at,
    mrh.change_type,
    mrh.iso_alpha_3,
    mrh.country_name,
    mrh.indicator_code,
    mrh.indicator_name,
    mrh.observation_year,
    mrh.previous_value,
    mrh.new_value,
    mrh.previous_source_batch_key,
    mrh.new_source_batch_key,
    mrh.previous_dataset_code,
    mrh.new_dataset_code,
    mrh.pipeline_run_key,
    mrh.pipeline_run_status,
    mrh.notes,
    mrh.previous_selection_rule_version_ref,
    mrh.new_selection_rule_version_ref,
    mrh.new_comparability_break_flag,
    mrh.new_comparability_break_note
FROM mart.vw_macro_revision_history mrh
WHERE mrh.indicator_code IN (
    'TRADE_EXPORTS_CURR_USD',
    'TRADE_IMPORTS_CURR_USD',
    'CURRENT_ACCOUNT_BALANCE_CURR_USD',
    'CURRENT_ACCOUNT_BALANCE_PCT_GDP'
);

CREATE OR REPLACE VIEW mart.vw_domain_qa_summary_phase2 AS
WITH phase2_datasets AS (
    SELECT
        sd.source_dataset_key,
        sd.dataset_code,
        sd.dataset_name,
        ss.source_code,
        ss.source_name
    FROM ref.source_dataset sd
    JOIN ref.source_system ss ON ss.source_system_key = sd.source_system_key
    WHERE sd.dataset_code IN ('IFS', 'WEO', 'ILOSTAT', 'UN_COMTRADE_ANNUAL')
),
phase2_indicator_stats AS (
    SELECT
        fp.source_dataset_key,
        COUNT(*) AS current_phase2_published_row_count,
        COUNT(DISTINCT fp.indicator_key) AS current_phase2_indicator_count,
        MIN(fp.observation_year) AS min_phase2_observation_year,
        MAX(fp.observation_year) AS max_phase2_observation_year
    FROM core.fact_country_indicator_published fp
    JOIN core.dim_indicator di ON di.indicator_key = fp.indicator_key
    WHERE di.indicator_code IN (
        'EMPLOYMENT_RATE_PCT',
        'LABOR_FORCE_PARTICIPATION_RATE_PCT',
        'UNEMPLOYMENT_RATE_PCT',
        'INFLATION_CPI_PCT',
        'TRADE_EXPORTS_CURR_USD',
        'TRADE_IMPORTS_CURR_USD',
        'CURRENT_ACCOUNT_BALANCE_CURR_USD',
        'CURRENT_ACCOUNT_BALANCE_PCT_GDP'
    )
    GROUP BY fp.source_dataset_key
),
phase2_conflict_participation AS (
    SELECT
        conflict_rows.source_dataset_key,
        COUNT(DISTINCT (conflict_rows.country_key, conflict_rows.indicator_key, conflict_rows.time_key)) AS current_conflict_key_count,
        COUNT(*) AS current_conflict_dataset_row_count,
        COUNT(*) FILTER (WHERE conflict_rows.is_selected_published_row) AS current_selected_conflict_key_count,
        MAX(conflict_rows.observation_year) AS latest_conflict_observation_year
    FROM (
        SELECT source_dataset_key, country_key, indicator_key, time_key, observation_year, is_selected_published_row
        FROM mart.vw_labor_source_conflicts_latest
        UNION ALL
        SELECT source_dataset_key, country_key, indicator_key, time_key, observation_year, is_selected_published_row
        FROM mart.vw_inflation_source_conflicts_latest
        UNION ALL
        SELECT source_dataset_key, country_key, indicator_key, time_key, observation_year, is_selected_published_row
        FROM mart.vw_gdp_source_conflicts_latest
    ) conflict_rows
    GROUP BY conflict_rows.source_dataset_key
)
SELECT
    pd.source_dataset_key,
    pd.dataset_code,
    pd.dataset_name,
    pd.source_code,
    pd.source_name,
    h.freshness_status,
    h.is_stale,
    h.latest_successful_fetch_at,
    h.latest_source_released_at,
    h.latest_published_at,
    h.latest_published_year,
    h.latest_source_batch_key,
    h.latest_batch_external_id,
    h.latest_batch_fetched_at,
    h.latest_batch_ingest_status,
    h.latest_batch_row_count_reported,
    h.latest_pipeline_run_key,
    h.latest_pipeline_status,
    h.latest_publish_run_key,
    h.latest_publish_status,
    h.latest_publish_total_dq_event_count,
    h.latest_publish_blocking_qa_event_count,
    h.latest_publish_warning_qa_event_count,
    h.latest_publish_error_qa_event_count,
    COALESCE(ps.current_phase2_published_row_count, 0) AS current_phase2_published_row_count,
    COALESCE(ps.current_phase2_indicator_count, 0) AS current_phase2_indicator_count,
    ps.min_phase2_observation_year,
    ps.max_phase2_observation_year,
    COALESCE(cp.current_conflict_key_count, 0) AS current_conflict_key_count,
    COALESCE(cp.current_conflict_dataset_row_count, 0) AS current_conflict_dataset_row_count,
    COALESCE(cp.current_selected_conflict_key_count, 0) AS current_selected_conflict_key_count,
    cp.latest_conflict_observation_year,
    h.anomaly_flags
FROM phase2_datasets pd
JOIN mart.dataset_pipeline_health h ON h.source_dataset_key = pd.source_dataset_key
LEFT JOIN phase2_indicator_stats ps ON ps.source_dataset_key = pd.source_dataset_key
LEFT JOIN phase2_conflict_participation cp ON cp.source_dataset_key = pd.source_dataset_key;
