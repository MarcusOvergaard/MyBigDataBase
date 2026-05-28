-- Phase 1 Wave 7 marts and diagnostic views
-- These analyst-facing surfaces build from the new published/audit contract rather than the legacy dw path.

DROP VIEW IF EXISTS mart.country_latest_macro;
DROP VIEW IF EXISTS mart.vw_phase2_dataset_status_history_scan CASCADE;
DROP VIEW IF EXISTS mart.vw_phase2_dataset_operator_panel_scan CASCADE;
DROP VIEW IF EXISTS mart.mart_country_phase2_ingestion_gap_explainer CASCADE;
DROP VIEW IF EXISTS mart.mart_country_phase2_dependency_explainer CASCADE;
DROP VIEW IF EXISTS mart.mart_phase2_dataset_coverage_trend CASCADE;
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

CREATE OR REPLACE VIEW mart.mart_phase2_dataset_coverage_trend AS
WITH active_countries AS (
    SELECT
        dc.country_key,
        dc.iso_alpha_3
    FROM core.dim_country dc
    WHERE dc.is_active = TRUE
      AND COALESCE(dc.is_aggregate, FALSE) = FALSE
),
expected_country_count AS (
    SELECT COUNT(*) AS expected_country_count
    FROM active_countries
),
phase2_rows AS (
    SELECT
        fp.source_dataset_key,
        dd.dataset_code,
        dd.dataset_name,
        ds.source_code,
        ds.source_name,
        di.indicator_code,
        di.indicator_name,
        fp.observation_year,
        fp.country_key,
        fp.published_at
    FROM core.fact_country_indicator_published fp
    JOIN core.dim_dataset dd ON dd.source_dataset_key = fp.source_dataset_key
    JOIN core.dim_source ds ON ds.source_system_key = dd.source_system_key
    JOIN core.dim_indicator di ON di.indicator_key = fp.indicator_key
    WHERE dd.dataset_code IN ('IFS', 'WEO', 'ILOSTAT', 'UN_COMTRADE_ANNUAL')
      AND di.indicator_code IN (
        'EMPLOYMENT_RATE_PCT',
        'LABOR_FORCE_PARTICIPATION_RATE_PCT',
        'UNEMPLOYMENT_RATE_PCT',
        'INFLATION_CPI_PCT',
        'TRADE_EXPORTS_CURR_USD',
        'TRADE_IMPORTS_CURR_USD',
        'CURRENT_ACCOUNT_BALANCE_CURR_USD',
        'CURRENT_ACCOUNT_BALANCE_PCT_GDP'
    )
),
coverage_by_year AS (
    SELECT
        pr.source_dataset_key,
        pr.dataset_code,
        pr.dataset_name,
        pr.source_code,
        pr.source_name,
        pr.indicator_code,
        pr.indicator_name,
        pr.observation_year,
        COUNT(DISTINCT pr.country_key) AS covered_country_count,
        MAX(pr.published_at) AS latest_row_published_at
    FROM phase2_rows pr
    GROUP BY
        pr.source_dataset_key,
        pr.dataset_code,
        pr.dataset_name,
        pr.source_code,
        pr.source_name,
        pr.indicator_code,
        pr.indicator_name,
        pr.observation_year
),
missing_countries AS (
    SELECT
        cby.source_dataset_key,
        cby.indicator_code,
        cby.observation_year,
        ARRAY_AGG(ac.iso_alpha_3 ORDER BY ac.iso_alpha_3) FILTER (WHERE pr.country_key IS NULL) AS missing_country_iso_alpha_3_codes
    FROM coverage_by_year cby
    CROSS JOIN active_countries ac
    LEFT JOIN phase2_rows pr
      ON pr.source_dataset_key = cby.source_dataset_key
     AND pr.indicator_code = cby.indicator_code
     AND pr.observation_year = cby.observation_year
     AND pr.country_key = ac.country_key
    GROUP BY
        cby.source_dataset_key,
        cby.indicator_code,
        cby.observation_year
),
enriched AS (
    SELECT
        cby.source_dataset_key,
        cby.dataset_code,
        cby.dataset_name,
        cby.source_code,
        cby.source_name,
        cby.indicator_code,
        cby.indicator_name,
        cby.observation_year,
        cby.latest_row_published_at,
        ecc.expected_country_count,
        cby.covered_country_count,
        ecc.expected_country_count - cby.covered_country_count AS missing_country_count,
        ROUND((cby.covered_country_count::numeric / NULLIF(ecc.expected_country_count, 0)), 4) AS coverage_ratio,
        COALESCE(mc.missing_country_iso_alpha_3_codes, ARRAY[]::text[]) AS missing_country_iso_alpha_3_codes,
        MAX(cby.observation_year) OVER (
            PARTITION BY cby.source_dataset_key, cby.indicator_code
        ) AS latest_observation_year_for_indicator,
        LAG(cby.covered_country_count) OVER (
            PARTITION BY cby.source_dataset_key, cby.indicator_code
            ORDER BY cby.observation_year
        ) AS prior_year_covered_country_count
    FROM coverage_by_year cby
    CROSS JOIN expected_country_count ecc
    LEFT JOIN missing_countries mc
      ON mc.source_dataset_key = cby.source_dataset_key
     AND mc.indicator_code = cby.indicator_code
     AND mc.observation_year = cby.observation_year
)
SELECT
    e.source_dataset_key,
    e.dataset_code,
    e.dataset_name,
    e.source_code,
    e.source_name,
    e.indicator_code,
    e.indicator_name,
    e.observation_year,
    e.latest_observation_year_for_indicator,
    (e.observation_year = e.latest_observation_year_for_indicator) AS is_latest_observation_year,
    e.latest_observation_year_for_indicator - e.observation_year AS observation_year_lag_from_latest,
    e.expected_country_count,
    e.covered_country_count,
    e.missing_country_count,
    e.coverage_ratio,
    e.prior_year_covered_country_count,
    CASE
        WHEN e.prior_year_covered_country_count IS NULL THEN NULL
        ELSE ROUND((e.prior_year_covered_country_count::numeric / NULLIF(e.expected_country_count, 0)), 4)
    END AS prior_year_coverage_ratio,
    CASE
        WHEN e.prior_year_covered_country_count IS NULL THEN NULL
        ELSE e.covered_country_count - e.prior_year_covered_country_count
    END AS covered_country_count_change_vs_prior_year,
    CASE
        WHEN e.prior_year_covered_country_count IS NULL THEN NULL
        ELSE ROUND(
            e.coverage_ratio - (e.prior_year_covered_country_count::numeric / NULLIF(e.expected_country_count, 0)),
            4
        )
    END AS coverage_ratio_change_vs_prior_year,
    CASE
        WHEN e.covered_country_count = e.expected_country_count THEN 'complete'
        WHEN e.covered_country_count >= e.expected_country_count - 1 THEN 'country_specific_gap'
        WHEN e.coverage_ratio >= 0.8000 THEN 'broad_but_patchy'
        ELSE 'source_wide_gap'
    END AS coverage_status,
    e.missing_country_iso_alpha_3_codes,
    h.freshness_status,
    h.is_stale,
    h.latest_published_at AS dataset_latest_published_at,
    e.latest_row_published_at
FROM enriched e
JOIN mart.dataset_pipeline_health h ON h.source_dataset_key = e.source_dataset_key;

CREATE OR REPLACE VIEW mart.mart_country_phase2_dependency_explainer AS
WITH phase2_indicator_catalog AS (
    SELECT
        di.indicator_key,
        di.indicator_code,
        di.indicator_name
    FROM core.dim_indicator di
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
),
country_indicator_grid AS (
    SELECT
        rs.country_key,
        rs.iso_alpha_3,
        rs.country_name,
        rs.region_name,
        rs.income_group,
        rs.phase2_indicator_coverage_count,
        rs.phase2_indicator_gap_count,
        rs.phase2_coverage_status,
        rs.latest_phase2_observation_year,
        rs.latest_published_at,
        pic.indicator_key,
        pic.indicator_code,
        pic.indicator_name
    FROM mart.mart_country_phase2_readiness_summary rs
    CROSS JOIN phase2_indicator_catalog pic
),
latest_selected_rows AS (
    SELECT
        ps.country_key,
        ps.indicator_key,
        ps.source_dataset_key,
        ps.dataset_code,
        ps.dataset_name,
        ps.source_code,
        ps.source_name,
        ps.observation_year,
        ps.observation_value,
        ps.selection_method,
        ps.published_at,
        ROW_NUMBER() OVER (
            PARTITION BY ps.country_key, ps.indicator_key
            ORDER BY ps.observation_year DESC, ps.published_at DESC, ps.observation_version_key DESC
        ) AS recency_rank
    FROM mart.mart_country_phase2_series_annual ps
),
selected_rows AS (
    SELECT
        lsr.country_key,
        lsr.indicator_key,
        lsr.source_dataset_key,
        lsr.dataset_code,
        lsr.dataset_name,
        lsr.source_code,
        lsr.source_name,
        lsr.observation_year,
        lsr.observation_value,
        lsr.selection_method,
        lsr.published_at
    FROM latest_selected_rows lsr
    WHERE lsr.recency_rank = 1
),
diagnosis_base AS (
    SELECT
        cig.country_key,
        cig.iso_alpha_3,
        cig.country_name,
        cig.region_name,
        cig.income_group,
        cig.phase2_indicator_coverage_count,
        cig.phase2_indicator_gap_count,
        cig.phase2_coverage_status,
        cig.latest_phase2_observation_year,
        cig.latest_published_at,
        cig.indicator_key,
        cig.indicator_code,
        cig.indicator_name,
        sr.source_dataset_key AS selected_source_dataset_key,
        sr.dataset_code AS selected_dataset_code,
        sr.dataset_name AS selected_dataset_name,
        sr.source_code AS selected_source_code,
        sr.source_name AS selected_source_name,
        sr.observation_year AS selected_observation_year,
        sr.observation_value AS selected_observation_value,
        sr.selection_method AS selected_selection_method,
        sr.published_at AS selected_published_at,
        COALESCE(sr.observation_year, cig.latest_phase2_observation_year) AS diagnosis_year
    FROM country_indicator_grid cig
    LEFT JOIN selected_rows sr
      ON sr.country_key = cig.country_key
     AND sr.indicator_key = cig.indicator_key
),
applicable_rules AS (
    SELECT
        db.country_key,
        db.indicator_key,
        isp.source_dataset_key,
        dd.dataset_code,
        dd.dataset_name,
        ss.source_code,
        ss.source_name,
        isp.priority_rank,
        isp.is_override,
        isp.selection_rationale,
        ROW_NUMBER() OVER (
            PARTITION BY db.country_key, db.indicator_key
            ORDER BY
                CASE WHEN isp.country_key = db.country_key THEN 0 ELSE 1 END,
                CASE
                    WHEN db.diagnosis_year IS NULL
                     AND (isp.valid_from_year IS NOT NULL OR isp.valid_to_year IS NOT NULL)
                        THEN 1
                    ELSE 0
                END,
                isp.is_override DESC,
                isp.priority_rank ASC,
                isp.indicator_source_priority_key ASC
        ) AS applicable_rule_rank
    FROM diagnosis_base db
    JOIN ref.indicator_source_priority isp
      ON isp.indicator_key = db.indicator_key
    JOIN ref.source_dataset dd ON dd.source_dataset_key = isp.source_dataset_key
    JOIN ref.source_system ss ON ss.source_system_key = dd.source_system_key
    WHERE (isp.country_key IS NULL OR isp.country_key = db.country_key)
      AND (db.diagnosis_year IS NULL OR isp.valid_from_year IS NULL OR db.diagnosis_year >= isp.valid_from_year)
      AND (db.diagnosis_year IS NULL OR isp.valid_to_year IS NULL OR db.diagnosis_year <= isp.valid_to_year)
),
expected_rules AS (
    SELECT
        ar.country_key,
        ar.indicator_key,
        ar.source_dataset_key AS expected_source_dataset_key,
        ar.dataset_code AS expected_dataset_code,
        ar.dataset_name AS expected_dataset_name,
        ar.source_code AS expected_source_code,
        ar.source_name AS expected_source_name,
        ar.priority_rank AS expected_priority_rank,
        ar.is_override AS expected_is_override,
        ar.selection_rationale AS expected_selection_rationale
    FROM applicable_rules ar
    WHERE ar.applicable_rule_rank = 1
),
configured_fallback_datasets AS (
    SELECT
        fallback_rows.country_key,
        fallback_rows.indicator_key,
        ARRAY_AGG(fallback_rows.dataset_code ORDER BY fallback_rows.priority_rank, fallback_rows.dataset_code) AS configured_fallback_dataset_codes,
        COUNT(*) AS configured_fallback_dataset_count
    FROM (
        SELECT DISTINCT
            ar.country_key,
            ar.indicator_key,
            ar.dataset_code,
            ar.priority_rank
        FROM applicable_rules ar
        JOIN expected_rules er
          ON er.country_key = ar.country_key
         AND er.indicator_key = ar.indicator_key
        WHERE ar.applicable_rule_rank > 1
          AND ar.source_dataset_key <> er.expected_source_dataset_key
    ) fallback_rows
    GROUP BY fallback_rows.country_key, fallback_rows.indicator_key
),
country_fallback_history AS (
    SELECT
        history_rows.country_key,
        history_rows.indicator_key,
        ARRAY_AGG(history_rows.dataset_code ORDER BY history_rows.latest_observation_year DESC, history_rows.dataset_code) AS available_fallback_dataset_codes_for_country,
        COUNT(*) AS available_fallback_dataset_count_for_country,
        MAX(history_rows.latest_observation_year) AS latest_fallback_observation_year_for_country
    FROM (
        SELECT
            ps.country_key,
            ps.indicator_key,
            ps.dataset_code,
            MAX(ps.observation_year) AS latest_observation_year
        FROM mart.mart_country_phase2_series_annual ps
        GROUP BY ps.country_key, ps.indicator_key, ps.dataset_code
    ) history_rows
    JOIN expected_rules er
      ON er.country_key = history_rows.country_key
     AND er.indicator_key = history_rows.indicator_key
    WHERE history_rows.dataset_code <> er.expected_dataset_code
    GROUP BY history_rows.country_key, history_rows.indicator_key
)
SELECT
    db.country_key,
    db.iso_alpha_3,
    db.country_name,
    db.region_name,
    db.income_group,
    db.phase2_indicator_coverage_count,
    db.phase2_indicator_gap_count,
    db.phase2_coverage_status,
    CASE
        WHEN db.phase2_indicator_gap_count >= 3 THEN 'high'
        WHEN db.phase2_indicator_gap_count >= 1 THEN 'medium'
        ELSE 'low'
    END AS country_issue_severity,
    db.indicator_key,
    db.indicator_code,
    db.indicator_name,
    db.diagnosis_year,
    er.expected_source_dataset_key,
    er.expected_dataset_code,
    er.expected_dataset_name,
    er.expected_source_code,
    er.expected_source_name,
    er.expected_priority_rank,
    er.expected_is_override,
    er.expected_selection_rationale,
    db.selected_source_dataset_key,
    db.selected_dataset_code,
    db.selected_dataset_name,
    db.selected_source_code,
    db.selected_source_name,
    db.selected_observation_year,
    db.selected_observation_value,
    db.selected_selection_method,
    db.selected_published_at,
    (db.selected_observation_year IS NOT NULL) AS is_indicator_present,
    (db.selected_source_dataset_key = er.expected_source_dataset_key) AS is_covered_by_expected_dataset,
    dt.latest_observation_year_for_indicator AS expected_dataset_latest_observation_year,
    dt.covered_country_count AS expected_dataset_covered_country_count,
    dt.expected_country_count AS expected_dataset_expected_country_count,
    dt.missing_country_count AS expected_dataset_missing_country_count,
    dt.coverage_ratio AS expected_dataset_coverage_ratio,
    dt.coverage_status AS expected_dataset_coverage_status,
    dt.missing_country_iso_alpha_3_codes AS expected_dataset_missing_country_iso_alpha_3_codes,
    (db.iso_alpha_3 = ANY(COALESCE(dt.missing_country_iso_alpha_3_codes, ARRAY[]::text[]))) AS is_country_missing_from_expected_dataset_latest_year,
    COALESCE(cfd.configured_fallback_dataset_codes, ARRAY[]::text[]) AS configured_fallback_dataset_codes,
    COALESCE(cfd.configured_fallback_dataset_count, 0) AS configured_fallback_dataset_count,
    COALESCE(cfh.available_fallback_dataset_codes_for_country, ARRAY[]::text[]) AS available_fallback_dataset_codes_for_country,
    COALESCE(cfh.available_fallback_dataset_count_for_country, 0) AS available_fallback_dataset_count_for_country,
    cfh.latest_fallback_observation_year_for_country,
    CASE
        WHEN db.selected_observation_year IS NOT NULL
         AND db.selected_source_dataset_key = er.expected_source_dataset_key
            THEN 'covered_by_expected_dataset'
        WHEN db.selected_observation_year IS NOT NULL
         AND db.selected_source_dataset_key <> er.expected_source_dataset_key
            THEN 'covered_by_fallback_dataset'
        WHEN dt.coverage_status = 'complete'
            THEN 'missing_despite_complete_expected_dataset'
        WHEN dt.coverage_status = 'country_specific_gap'
         AND db.iso_alpha_3 = ANY(COALESCE(dt.missing_country_iso_alpha_3_codes, ARRAY[]::text[]))
            THEN 'missing_country_from_expected_dataset'
        WHEN dt.coverage_status IN ('broad_but_patchy', 'source_wide_gap')
            THEN 'missing_from_patchy_expected_dataset'
        WHEN COALESCE(cfh.available_fallback_dataset_count_for_country, 0) > 0
            THEN 'missing_with_country_fallback_history'
        WHEN COALESCE(cfd.configured_fallback_dataset_count, 0) > 0
            THEN 'missing_without_country_fallback_history'
        ELSE 'missing_without_configured_fallback'
    END AS dependency_status,
    db.latest_published_at
FROM diagnosis_base db
JOIN expected_rules er
  ON er.country_key = db.country_key
 AND er.indicator_key = db.indicator_key
LEFT JOIN mart.mart_phase2_dataset_coverage_trend dt
  ON dt.source_dataset_key = er.expected_source_dataset_key
 AND dt.indicator_code = db.indicator_code
 AND dt.is_latest_observation_year = TRUE
LEFT JOIN configured_fallback_datasets cfd
  ON cfd.country_key = db.country_key
 AND cfd.indicator_key = db.indicator_key
LEFT JOIN country_fallback_history cfh
  ON cfh.country_key = db.country_key
 AND cfh.indicator_key = db.indicator_key;

CREATE OR REPLACE VIEW mart.mart_country_phase2_ingestion_gap_explainer AS
WITH missing_dependencies AS (
    SELECT
        de.country_key,
        de.iso_alpha_3,
        de.country_name,
        de.region_name,
        de.income_group,
        de.country_issue_severity,
        de.phase2_indicator_coverage_count,
        de.phase2_indicator_gap_count,
        de.phase2_coverage_status,
        de.indicator_key,
        de.indicator_code,
        de.indicator_name,
        de.diagnosis_year,
        de.expected_source_dataset_key,
        de.expected_dataset_code,
        de.expected_dataset_name,
        de.expected_source_code,
        de.expected_source_name,
        de.expected_priority_rank,
        de.expected_is_override,
        de.expected_selection_rationale,
        de.expected_dataset_latest_observation_year,
        de.expected_dataset_covered_country_count,
        de.expected_dataset_expected_country_count,
        de.expected_dataset_missing_country_count,
        de.expected_dataset_coverage_ratio,
        de.expected_dataset_coverage_status,
        de.expected_dataset_missing_country_iso_alpha_3_codes,
        de.dependency_status,
        de.latest_published_at
    FROM mart.mart_country_phase2_dependency_explainer de
    WHERE de.is_indicator_present = FALSE
),
latest_expected_batch AS (
    SELECT DISTINCT ON (sb.source_dataset_key)
        sb.source_dataset_key,
        sb.source_batch_key,
        sb.batch_external_id,
        sb.request_uri,
        sb.request_params_json,
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
snapshot_stats AS (
    SELECT
        ss.source_batch_key,
        COUNT(*) AS snapshot_count,
        COUNT(*) FILTER (WHERE COALESCE(ss.http_status_code, 200) >= 400) AS failed_snapshot_count,
        MIN(ss.fetched_at) AS first_snapshot_fetched_at,
        MAX(ss.fetched_at) AS latest_snapshot_fetched_at
    FROM raw.source_snapshot ss
    GROUP BY ss.source_batch_key
),
raw_indicator_lookup AS (
    SELECT
        rs.source_dataset_key,
        rs.series_code AS raw_indicator_code,
        issm.indicator_key
    FROM ref.source_series rs
    JOIN ref.indicator_source_series_map issm
      ON issm.source_series_key = rs.source_series_key
    WHERE rs.is_active = TRUE
      AND issm.is_active = TRUE

    UNION

    SELECT
        rs.source_dataset_key,
        rsa.alias_code AS raw_indicator_code,
        issm.indicator_key
    FROM ref.source_series rs
    JOIN ref.source_series_alias rsa
      ON rsa.source_series_key = rs.source_series_key
    JOIN ref.indicator_source_series_map issm
      ON issm.source_series_key = rs.source_series_key
    WHERE rs.is_active = TRUE
      AND rsa.is_active = TRUE
      AND issm.is_active = TRUE
),
raw_union AS (
    SELECT source_batch_key, country_code_raw, indicator_code_raw, year_raw
    FROM raw.wdi_country_indicator_annual

    UNION ALL

    SELECT source_batch_key, country_code_raw, indicator_code_raw, year_raw
    FROM raw.ifs_country_indicator_annual

    UNION ALL

    SELECT source_batch_key, country_code_raw, indicator_code_raw, year_raw
    FROM raw.weo_country_indicator_annual

    UNION ALL

    SELECT source_batch_key, country_code_raw, indicator_code_raw, year_raw
    FROM raw.ilostat_country_indicator_annual

    UNION ALL

    SELECT source_batch_key, country_code_raw, indicator_code_raw, year_raw
    FROM raw.un_comtrade_country_indicator_annual
),
raw_enriched AS (
    SELECT DISTINCT
        ru.source_batch_key,
        c.country_key,
        ril.indicator_key,
        NULLIF(ru.year_raw, '')::INT AS observation_year
    FROM raw_union ru
    JOIN raw.source_batch sb ON sb.source_batch_key = ru.source_batch_key
    LEFT JOIN ref.country c ON c.iso_alpha_3 = ru.country_code_raw
    LEFT JOIN raw_indicator_lookup ril
      ON ril.source_dataset_key = sb.source_dataset_key
     AND ril.raw_indicator_code = ru.indicator_code_raw
    WHERE NULLIF(ru.year_raw, '') ~ '^[0-9]{4}$'
),
raw_batch_counts AS (
    SELECT
        re.source_batch_key,
        COUNT(*) AS raw_row_count
    FROM raw_enriched re
    GROUP BY re.source_batch_key
),
raw_batch_country_counts AS (
    SELECT
        re.source_batch_key,
        re.country_key,
        COUNT(*) AS raw_row_count
    FROM raw_enriched re
    WHERE re.country_key IS NOT NULL
    GROUP BY re.source_batch_key, re.country_key
),
raw_batch_country_indicator_counts AS (
    SELECT
        re.source_batch_key,
        re.country_key,
        re.indicator_key,
        COUNT(*) AS raw_row_count,
        ARRAY_AGG(DISTINCT re.observation_year ORDER BY re.observation_year) AS raw_observation_years
    FROM raw_enriched re
    WHERE re.country_key IS NOT NULL
      AND re.indicator_key IS NOT NULL
    GROUP BY re.source_batch_key, re.country_key, re.indicator_key
),
staging_batch_counts AS (
    SELECT
        s.source_batch_key,
        COUNT(*) AS staging_row_count
    FROM staging.country_observation_annual s
    GROUP BY s.source_batch_key
),
staging_batch_country_counts AS (
    SELECT
        s.source_batch_key,
        s.country_key,
        COUNT(*) AS staging_row_count
    FROM staging.country_observation_annual s
    WHERE s.country_key IS NOT NULL
    GROUP BY s.source_batch_key, s.country_key
),
staging_batch_country_indicator_counts AS (
    SELECT
        s.source_batch_key,
        s.country_key,
        s.indicator_key,
        COUNT(*) AS staging_row_count,
        ARRAY_AGG(DISTINCT s.observation_year ORDER BY s.observation_year) AS staging_observation_years
    FROM staging.country_observation_annual s
    WHERE s.country_key IS NOT NULL
      AND s.indicator_key IS NOT NULL
    GROUP BY s.source_batch_key, s.country_key, s.indicator_key
),
version_batch_counts AS (
    SELECT
        fv.source_batch_key,
        COUNT(*) AS version_row_count
    FROM core.fact_country_indicator_version fv
    GROUP BY fv.source_batch_key
),
version_batch_country_indicator_counts AS (
    SELECT
        fv.source_batch_key,
        fv.country_key,
        fv.indicator_key,
        COUNT(*) AS version_row_count,
        ARRAY_AGG(DISTINCT fv.observation_year ORDER BY fv.observation_year) AS version_observation_years
    FROM core.fact_country_indicator_version fv
    GROUP BY fv.source_batch_key, fv.country_key, fv.indicator_key
),
latest_publish_run_by_batch AS (
    SELECT DISTINCT ON (apr.source_batch_key)
        apr.source_batch_key,
        apr.pipeline_run_key,
        apr.started_at,
        apr.completed_at,
        apr.status_code,
        apr.row_count_in,
        apr.row_count_out,
        apr.notes
    FROM audit.pipeline_run apr
    WHERE apr.pipeline_stage = 'publish'
      AND apr.source_batch_key IS NOT NULL
    ORDER BY apr.source_batch_key, apr.started_at DESC, apr.pipeline_run_key DESC
),
batch_country_indicator_dq_counts AS (
    SELECT
        dqe.source_batch_key,
        dqe.country_key,
        dqe.indicator_key,
        COUNT(*) AS dq_event_count,
        COUNT(*) FILTER (WHERE dqe.blocks_publication = TRUE) AS blocking_qa_event_count,
        COUNT(*) FILTER (WHERE dqe.severity = 'warning') AS warning_qa_event_count,
        COUNT(*) FILTER (WHERE dqe.severity = 'error') AS error_qa_event_count
    FROM audit.data_quality_event dqe
    WHERE dqe.source_batch_key IS NOT NULL
      AND dqe.country_key IS NOT NULL
      AND dqe.indicator_key IS NOT NULL
    GROUP BY dqe.source_batch_key, dqe.country_key, dqe.indicator_key
),
current_expected_dataset_published_counts AS (
    SELECT
        fp.source_dataset_key,
        fp.country_key,
        fp.indicator_key,
        COUNT(*) AS current_published_row_count,
        MAX(fp.observation_year) AS latest_published_observation_year
    FROM core.fact_country_indicator_published fp
    GROUP BY fp.source_dataset_key, fp.country_key, fp.indicator_key
)
SELECT
    md.country_key,
    md.iso_alpha_3,
    md.country_name,
    md.region_name,
    md.income_group,
    md.country_issue_severity,
    md.phase2_indicator_coverage_count,
    md.phase2_indicator_gap_count,
    md.phase2_coverage_status,
    md.indicator_key,
    md.indicator_code,
    md.indicator_name,
    md.diagnosis_year,
    md.expected_source_dataset_key,
    md.expected_dataset_code,
    md.expected_dataset_name,
    md.expected_source_code,
    md.expected_source_name,
    md.expected_priority_rank,
    md.expected_is_override,
    md.expected_selection_rationale,
    md.dependency_status,
    md.expected_dataset_latest_observation_year,
    md.expected_dataset_covered_country_count,
    md.expected_dataset_expected_country_count,
    md.expected_dataset_missing_country_count,
    md.expected_dataset_coverage_ratio,
    md.expected_dataset_coverage_status,
    md.expected_dataset_missing_country_iso_alpha_3_codes,
    leb.source_batch_key AS latest_expected_source_batch_key,
    leb.batch_external_id AS latest_expected_batch_external_id,
    leb.request_uri AS latest_expected_batch_request_uri,
    leb.fetched_at AS latest_expected_batch_fetched_at,
    leb.source_released_at AS latest_expected_batch_source_released_at,
    leb.ingest_status AS latest_expected_batch_ingest_status,
    leb.row_count_reported AS latest_expected_batch_row_count_reported,
    leb.request_params_json ->> 'loader' AS latest_expected_batch_loader,
    leb.request_params_json ->> 'snapshot_root' AS latest_expected_snapshot_root,
    CASE
        WHEN leb.source_batch_key IS NULL THEN NULL
        WHEN leb.request_params_json ->> 'snapshot_root' IS NULL THEN NULL
        WHEN leb.request_params_json ->> 'loader' = 'scripts/load_wdi_live.sh' THEN NULL
        ELSE (leb.request_params_json ->> 'snapshot_root') || '/' || regexp_replace(leb.batch_external_id, '^.*_live_', '') || '_manifest.json'
    END AS latest_expected_manifest_path,
    COALESCE(ss.snapshot_count, 0) AS latest_expected_snapshot_count,
    COALESCE(ss.failed_snapshot_count, 0) AS latest_expected_failed_snapshot_count,
    ss.first_snapshot_fetched_at AS latest_expected_first_snapshot_fetched_at,
    ss.latest_snapshot_fetched_at AS latest_expected_last_snapshot_fetched_at,
    COALESCE(rbc.raw_row_count, 0) AS latest_expected_batch_raw_row_count,
    COALESCE(sbc.staging_row_count, 0) AS latest_expected_batch_staging_row_count,
    COALESCE(vbc.version_row_count, 0) AS latest_expected_batch_version_row_count,
    lpr.pipeline_run_key AS latest_expected_publish_run_key,
    lpr.started_at AS latest_expected_publish_started_at,
    lpr.completed_at AS latest_expected_publish_completed_at,
    lpr.status_code AS latest_expected_publish_status,
    lpr.row_count_in AS latest_expected_publish_row_count_in,
    lpr.row_count_out AS latest_expected_publish_row_count_out,
    lpr.notes AS latest_expected_publish_notes,
    COALESCE(rbcc.raw_row_count, 0) AS latest_expected_batch_country_raw_row_count,
    COALESCE(rbci.raw_row_count, 0) AS latest_expected_batch_country_indicator_raw_row_count,
    rbci.raw_observation_years AS latest_expected_batch_country_indicator_raw_observation_years,
    COALESCE(sbcc.staging_row_count, 0) AS latest_expected_batch_country_staging_row_count,
    COALESCE(sbci.staging_row_count, 0) AS latest_expected_batch_country_indicator_staging_row_count,
    sbci.staging_observation_years AS latest_expected_batch_country_indicator_staging_observation_years,
    COALESCE(vbci.version_row_count, 0) AS latest_expected_batch_country_indicator_version_row_count,
    vbci.version_observation_years AS latest_expected_batch_country_indicator_version_observation_years,
    COALESCE(dqc.dq_event_count, 0) AS latest_expected_batch_country_indicator_dq_event_count,
    COALESCE(dqc.blocking_qa_event_count, 0) AS latest_expected_batch_country_indicator_blocking_qa_event_count,
    COALESCE(dqc.warning_qa_event_count, 0) AS latest_expected_batch_country_indicator_warning_qa_event_count,
    COALESCE(dqc.error_qa_event_count, 0) AS latest_expected_batch_country_indicator_error_qa_event_count,
    COALESCE(cepc.current_published_row_count, 0) AS current_expected_dataset_country_indicator_published_row_count,
    cepc.latest_published_observation_year AS current_expected_dataset_latest_published_observation_year,
    CASE
        WHEN leb.source_batch_key IS NULL THEN 'fetch_scope'
        WHEN COALESCE(dqc.blocking_qa_event_count, 0) > 0 THEN 'qa_blocking'
        WHEN COALESCE(vbci.version_row_count, 0) > 0 AND COALESCE(cepc.current_published_row_count, 0) = 0 THEN 'publication'
        WHEN COALESCE(sbci.staging_row_count, 0) > 0 AND COALESCE(vbci.version_row_count, 0) = 0 THEN 'normalization'
        WHEN COALESCE(rbci.raw_row_count, 0) > 0 AND COALESCE(sbci.staging_row_count, 0) = 0 THEN 'normalization'
        ELSE 'fetch_scope'
    END AS gap_stage,
    CASE
        WHEN leb.source_batch_key IS NULL THEN 'no_expected_dataset_batch_history'
        WHEN COALESCE(ss.snapshot_count, 0) = 0 THEN 'missing_snapshot_evidence_for_latest_batch'
        WHEN COALESCE(rbci.raw_row_count, 0) = 0 AND COALESCE(rbcc.raw_row_count, 0) = 0 THEN 'country_not_present_in_latest_raw_landing'
        WHEN COALESCE(rbci.raw_row_count, 0) = 0 THEN 'indicator_not_present_for_country_in_latest_raw_landing'
        WHEN COALESCE(sbci.staging_row_count, 0) = 0 THEN 'raw_landed_but_not_normalized_to_staging'
        WHEN COALESCE(dqc.blocking_qa_event_count, 0) > 0 THEN 'blocked_by_publish_qa'
        WHEN COALESCE(vbci.version_row_count, 0) = 0 THEN 'staged_but_not_versioned'
        WHEN COALESCE(cepc.current_published_row_count, 0) = 0
         AND COALESCE(lpr.status_code, 'missing') NOT IN ('succeeded', 'succeeded_with_warnings')
            THEN 'publish_run_not_successful'
        WHEN COALESCE(cepc.current_published_row_count, 0) = 0 THEN 'versioned_but_not_visible_in_published_surface'
        ELSE 'gap_resolved_elsewhere'
    END AS gap_status,
    CASE
        WHEN leb.source_batch_key IS NULL THEN 'No source_batch exists yet for the expected dataset.'
        WHEN COALESCE(ss.snapshot_count, 0) = 0 THEN 'The latest expected batch has no raw.source_snapshot evidence rows.'
        WHEN COALESCE(rbci.raw_row_count, 0) = 0 AND COALESCE(rbcc.raw_row_count, 0) = 0 THEN 'The latest expected batch never landed this country in raw rows, so the gap begins at fetch scope.'
        WHEN COALESCE(rbci.raw_row_count, 0) = 0 THEN 'The latest expected batch landed this country, but not this indicator, in raw rows.'
        WHEN COALESCE(sbci.staging_row_count, 0) = 0 THEN 'Raw rows exist for this country-indicator, but nothing survived into staging.'
        WHEN COALESCE(dqc.blocking_qa_event_count, 0) > 0 THEN 'Staged rows exist, but blocking QA events prevented publication.'
        WHEN COALESCE(vbci.version_row_count, 0) = 0 THEN 'Staged rows exist, but no version rows were materialized for publication.'
        WHEN COALESCE(cepc.current_published_row_count, 0) = 0
         AND COALESCE(lpr.status_code, 'missing') NOT IN ('succeeded', 'succeeded_with_warnings')
            THEN 'Version rows exist, but the latest publish run was not successful.'
        WHEN COALESCE(cepc.current_published_row_count, 0) = 0 THEN 'Version rows exist, but no current published row remains visible for the expected dataset.'
        ELSE 'The gap no longer appears unresolved in the expected dataset.'
    END AS gap_summary,
    md.latest_published_at
FROM missing_dependencies md
LEFT JOIN latest_expected_batch leb
  ON leb.source_dataset_key = md.expected_source_dataset_key
LEFT JOIN snapshot_stats ss
  ON ss.source_batch_key = leb.source_batch_key
LEFT JOIN raw_batch_counts rbc
  ON rbc.source_batch_key = leb.source_batch_key
LEFT JOIN staging_batch_counts sbc
  ON sbc.source_batch_key = leb.source_batch_key
LEFT JOIN version_batch_counts vbc
  ON vbc.source_batch_key = leb.source_batch_key
LEFT JOIN latest_publish_run_by_batch lpr
  ON lpr.source_batch_key = leb.source_batch_key
LEFT JOIN raw_batch_country_counts rbcc
  ON rbcc.source_batch_key = leb.source_batch_key
 AND rbcc.country_key = md.country_key
LEFT JOIN raw_batch_country_indicator_counts rbci
  ON rbci.source_batch_key = leb.source_batch_key
 AND rbci.country_key = md.country_key
 AND rbci.indicator_key = md.indicator_key
LEFT JOIN staging_batch_country_counts sbcc
  ON sbcc.source_batch_key = leb.source_batch_key
 AND sbcc.country_key = md.country_key
LEFT JOIN staging_batch_country_indicator_counts sbci
  ON sbci.source_batch_key = leb.source_batch_key
 AND sbci.country_key = md.country_key
 AND sbci.indicator_key = md.indicator_key
LEFT JOIN version_batch_country_indicator_counts vbci
  ON vbci.source_batch_key = leb.source_batch_key
 AND vbci.country_key = md.country_key
 AND vbci.indicator_key = md.indicator_key
LEFT JOIN batch_country_indicator_dq_counts dqc
  ON dqc.source_batch_key = leb.source_batch_key
 AND dqc.country_key = md.country_key
 AND dqc.indicator_key = md.indicator_key
LEFT JOIN current_expected_dataset_published_counts cepc
  ON cepc.source_dataset_key = md.expected_source_dataset_key
 AND cepc.country_key = md.country_key
 AND cepc.indicator_key = md.indicator_key;

CREATE OR REPLACE VIEW mart.mart_phase2_dataset_ingestion_gap_rollup AS
WITH gap_rows AS (
    SELECT
        ig.expected_source_dataset_key,
        ig.expected_dataset_code,
        ig.expected_dataset_name,
        ig.expected_source_code,
        ig.expected_source_name,
        ig.iso_alpha_3,
        ig.indicator_code,
        ig.gap_stage,
        ig.gap_status,
        ig.latest_expected_batch_external_id,
        ig.latest_expected_manifest_path,
        ig.latest_expected_batch_fetched_at,
        ig.latest_expected_batch_source_released_at,
        ig.latest_expected_publish_status
    FROM mart.mart_country_phase2_ingestion_gap_explainer ig
),
stage_counts AS (
    SELECT
        gr.expected_source_dataset_key,
        gr.gap_stage,
        COUNT(*) AS gap_stage_count,
        ROW_NUMBER() OVER (
            PARTITION BY gr.expected_source_dataset_key
            ORDER BY COUNT(*) DESC, gr.gap_stage ASC
        ) AS gap_stage_rank
    FROM gap_rows gr
    GROUP BY gr.expected_source_dataset_key, gr.gap_stage
),
status_counts AS (
    SELECT
        gr.expected_source_dataset_key,
        gr.gap_status,
        COUNT(*) AS gap_status_count,
        ROW_NUMBER() OVER (
            PARTITION BY gr.expected_source_dataset_key
            ORDER BY COUNT(*) DESC, gr.gap_status ASC
        ) AS gap_status_rank
    FROM gap_rows gr
    GROUP BY gr.expected_source_dataset_key, gr.gap_status
)
SELECT
    gr.expected_source_dataset_key,
    gr.expected_dataset_code,
    gr.expected_dataset_name,
    gr.expected_source_code,
    gr.expected_source_name,
    COUNT(*) AS missing_country_indicator_count,
    COUNT(DISTINCT gr.iso_alpha_3) AS affected_country_count,
    COUNT(DISTINCT gr.indicator_code) AS affected_indicator_count,
    ARRAY_AGG(DISTINCT gr.iso_alpha_3 ORDER BY gr.iso_alpha_3) AS affected_country_iso_alpha_3_codes,
    ARRAY_AGG(DISTINCT gr.indicator_code ORDER BY gr.indicator_code) AS affected_indicator_codes,
    COUNT(*) FILTER (WHERE gr.gap_stage = 'fetch_scope') AS fetch_scope_gap_count,
    COUNT(*) FILTER (WHERE gr.gap_stage = 'normalization') AS normalization_gap_count,
    COUNT(*) FILTER (WHERE gr.gap_stage = 'qa_blocking') AS qa_blocking_gap_count,
    COUNT(*) FILTER (WHERE gr.gap_stage = 'publication') AS publication_gap_count,
    COUNT(*) FILTER (WHERE gr.gap_status = 'no_expected_dataset_batch_history') AS no_expected_dataset_batch_history_count,
    COUNT(*) FILTER (WHERE gr.gap_status = 'missing_snapshot_evidence_for_latest_batch') AS missing_snapshot_evidence_for_latest_batch_count,
    COUNT(*) FILTER (WHERE gr.gap_status = 'country_not_present_in_latest_raw_landing') AS country_not_present_in_latest_raw_landing_count,
    COUNT(*) FILTER (WHERE gr.gap_status = 'indicator_not_present_for_country_in_latest_raw_landing') AS indicator_not_present_for_country_in_latest_raw_landing_count,
    COUNT(*) FILTER (WHERE gr.gap_status = 'raw_landed_but_not_normalized_to_staging') AS raw_landed_but_not_normalized_to_staging_count,
    COUNT(*) FILTER (WHERE gr.gap_status = 'blocked_by_publish_qa') AS blocked_by_publish_qa_count,
    COUNT(*) FILTER (WHERE gr.gap_status = 'staged_but_not_versioned') AS staged_but_not_versioned_count,
    COUNT(*) FILTER (WHERE gr.gap_status = 'publish_run_not_successful') AS publish_run_not_successful_count,
    COUNT(*) FILTER (WHERE gr.gap_status = 'versioned_but_not_visible_in_published_surface') AS versioned_but_not_visible_in_published_surface_count,
    COUNT(*) FILTER (WHERE gr.gap_status = 'gap_resolved_elsewhere') AS gap_resolved_elsewhere_count,
    MAX(CASE WHEN sc.gap_stage_rank = 1 THEN sc.gap_stage END) AS dominant_gap_stage,
    MAX(CASE WHEN sc.gap_stage_rank = 1 THEN sc.gap_stage_count END) AS dominant_gap_stage_count,
    MAX(CASE WHEN stc.gap_status_rank = 1 THEN stc.gap_status END) AS dominant_gap_status,
    MAX(CASE WHEN stc.gap_status_rank = 1 THEN stc.gap_status_count END) AS dominant_gap_status_count,
    MAX(gr.latest_expected_batch_external_id) AS latest_expected_batch_external_id,
    MAX(gr.latest_expected_manifest_path) AS latest_expected_manifest_path,
    MAX(gr.latest_expected_batch_fetched_at) AS latest_expected_batch_fetched_at,
    MAX(gr.latest_expected_batch_source_released_at) AS latest_expected_batch_source_released_at,
    MAX(gr.latest_expected_publish_status) AS latest_expected_publish_status
FROM gap_rows gr
LEFT JOIN stage_counts sc
  ON sc.expected_source_dataset_key = gr.expected_source_dataset_key
LEFT JOIN status_counts stc
  ON stc.expected_source_dataset_key = gr.expected_source_dataset_key
GROUP BY
    gr.expected_source_dataset_key,
    gr.expected_dataset_code,
    gr.expected_dataset_name,
    gr.expected_source_code,
    gr.expected_source_name;

CREATE OR REPLACE VIEW mart.mart_phase2_dataset_operator_panel AS
WITH latest_coverage AS (
    SELECT
        dt.source_dataset_key,
        COUNT(*) AS latest_indicator_count,
        COUNT(*) FILTER (WHERE dt.coverage_status = 'complete') AS latest_complete_indicator_count,
        COUNT(*) FILTER (WHERE dt.coverage_status <> 'complete') AS latest_gap_indicator_count,
        SUM(dt.covered_country_count) AS latest_covered_country_sum,
        SUM(dt.expected_country_count) AS latest_expected_country_sum,
        SUM(dt.missing_country_count) AS latest_missing_country_sum,
        ROUND(AVG(dt.coverage_ratio), 4) AS latest_avg_coverage_ratio,
        MAX(dt.observation_year) AS latest_phase2_observation_year,
        MAX(dt.dataset_latest_published_at) AS latest_dataset_published_at,
        ARRAY_AGG(dt.indicator_code ORDER BY dt.indicator_code)
            FILTER (WHERE dt.coverage_status <> 'complete') AS latest_gap_indicator_codes
    FROM mart.mart_phase2_dataset_coverage_trend dt
    WHERE dt.is_latest_observation_year = TRUE
    GROUP BY dt.source_dataset_key
),
phase2_indicator_catalog AS (
    SELECT
        sd.source_dataset_key,
        COUNT(DISTINCT i.indicator_key) AS required_phase2_indicator_count
    FROM ref.source_dataset sd
    JOIN ref.source_series rs
      ON rs.source_dataset_key = sd.source_dataset_key
     AND rs.is_active = TRUE
    JOIN ref.indicator_source_series_map ism
      ON ism.source_series_key = rs.source_series_key
     AND ism.is_active = TRUE
    JOIN core.dim_indicator i
      ON i.indicator_key = ism.indicator_key
    WHERE sd.dataset_code IN ('IFS', 'WEO', 'ILOSTAT', 'UN_COMTRADE_ANNUAL')
      AND i.indicator_code IN (
        'EMPLOYMENT_RATE_PCT',
        'LABOR_FORCE_PARTICIPATION_RATE_PCT',
        'UNEMPLOYMENT_RATE_PCT',
        'INFLATION_CPI_PCT',
        'TRADE_EXPORTS_CURR_USD',
        'TRADE_IMPORTS_CURR_USD',
        'CURRENT_ACCOUNT_BALANCE_CURR_USD',
        'CURRENT_ACCOUNT_BALANCE_PCT_GDP'
    )
    GROUP BY sd.source_dataset_key
)
SELECT
    q.source_dataset_key,
    q.dataset_code,
    q.dataset_name,
    q.source_code,
    q.source_name,
    q.freshness_status,
    q.is_stale,
    q.latest_successful_fetch_at,
    q.latest_source_released_at,
    q.latest_published_at,
    q.latest_publish_status,
    q.latest_publish_total_dq_event_count,
    q.latest_publish_blocking_qa_event_count,
    q.current_phase2_published_row_count,
    q.current_phase2_indicator_count,
    q.current_conflict_key_count,
    q.current_conflict_dataset_row_count,
    q.current_selected_conflict_key_count,
    q.latest_conflict_observation_year,
    pic.required_phase2_indicator_count,
    lc.latest_indicator_count,
    lc.latest_complete_indicator_count,
    lc.latest_gap_indicator_count,
    lc.latest_covered_country_sum,
    lc.latest_expected_country_sum,
    lc.latest_missing_country_sum,
    lc.latest_avg_coverage_ratio,
    lc.latest_phase2_observation_year,
    lc.latest_dataset_published_at,
    COALESCE(lc.latest_gap_indicator_codes, ARRAY[]::text[]) AS latest_gap_indicator_codes,
    (COALESCE(lc.latest_gap_indicator_count, 0) > 0) AS has_latest_coverage_gap,
    COALESCE(igr.missing_country_indicator_count, 0) AS missing_country_indicator_count,
    COALESCE(igr.affected_country_count, 0) AS affected_country_count,
    COALESCE(igr.affected_indicator_count, 0) AS affected_indicator_count,
    COALESCE(igr.affected_country_iso_alpha_3_codes, ARRAY[]::varchar[]) AS affected_country_iso_alpha_3_codes,
    COALESCE(igr.affected_indicator_codes, ARRAY[]::varchar[]) AS affected_indicator_codes,
    COALESCE(igr.fetch_scope_gap_count, 0) AS fetch_scope_gap_count,
    COALESCE(igr.normalization_gap_count, 0) AS normalization_gap_count,
    COALESCE(igr.qa_blocking_gap_count, 0) AS qa_blocking_gap_count,
    COALESCE(igr.publication_gap_count, 0) AS publication_gap_count,
    COALESCE(igr.no_expected_dataset_batch_history_count, 0) AS no_expected_dataset_batch_history_count,
    COALESCE(igr.missing_snapshot_evidence_for_latest_batch_count, 0) AS missing_snapshot_evidence_for_latest_batch_count,
    COALESCE(igr.country_not_present_in_latest_raw_landing_count, 0) AS country_not_present_in_latest_raw_landing_count,
    COALESCE(igr.indicator_not_present_for_country_in_latest_raw_landing_count, 0) AS indicator_not_present_for_country_in_latest_raw_landing_count,
    COALESCE(igr.raw_landed_but_not_normalized_to_staging_count, 0) AS raw_landed_but_not_normalized_to_staging_count,
    COALESCE(igr.blocked_by_publish_qa_count, 0) AS blocked_by_publish_qa_count,
    COALESCE(igr.staged_but_not_versioned_count, 0) AS staged_but_not_versioned_count,
    COALESCE(igr.publish_run_not_successful_count, 0) AS publish_run_not_successful_count,
    COALESCE(igr.versioned_but_not_visible_in_published_surface_count, 0) AS versioned_but_not_visible_in_published_surface_count,
    COALESCE(igr.gap_resolved_elsewhere_count, 0) AS gap_resolved_elsewhere_count,
    igr.dominant_gap_stage,
    igr.dominant_gap_status,
    CASE
        WHEN COALESCE(igr.missing_country_indicator_count, 0) > 0 THEN 'failing_active_gap'
        WHEN COALESCE(lc.latest_gap_indicator_count, 0) > 0 THEN 'warning_coverage_gap'
        ELSE 'healthy'
    END AS operator_panel_status,
    q.anomaly_flags
FROM mart.vw_domain_qa_summary_phase2 q
LEFT JOIN phase2_indicator_catalog pic
  ON pic.source_dataset_key = q.source_dataset_key
LEFT JOIN mart.mart_phase2_dataset_ingestion_gap_rollup igr
  ON igr.expected_source_dataset_key = q.source_dataset_key
LEFT JOIN latest_coverage lc
  ON lc.source_dataset_key = q.source_dataset_key;

CREATE OR REPLACE VIEW mart.vw_phase2_dataset_operator_panel_scan AS
SELECT
    op.source_dataset_key,
    op.dataset_code,
    op.dataset_name,
    op.source_code,
    op.source_name,
    op.operator_panel_status,
    CASE op.operator_panel_status
        WHEN 'failing_active_gap' THEN 1
        WHEN 'warning_coverage_gap' THEN 2
        ELSE 3
    END AS operator_attention_rank,
    op.freshness_status,
    op.latest_publish_status,
    op.latest_phase2_observation_year,
    op.latest_dataset_published_at,
    op.current_phase2_indicator_count,
    op.required_phase2_indicator_count,
    op.latest_complete_indicator_count,
    op.latest_gap_indicator_count,
    ROUND(
        op.latest_indicator_count::numeric / NULLIF(op.required_phase2_indicator_count, 0),
        4
    ) AS latest_indicator_coverage_ratio,
    op.latest_covered_country_sum,
    op.latest_expected_country_sum,
    op.latest_missing_country_sum,
    ROUND(
        (op.latest_expected_country_sum - op.latest_missing_country_sum)::numeric
        / NULLIF(op.latest_expected_country_sum, 0),
        4
    ) AS latest_country_coverage_ratio,
    op.latest_gap_indicator_codes,
    op.missing_country_indicator_count,
    op.affected_country_count,
    op.affected_indicator_count,
    op.dominant_gap_stage,
    op.dominant_gap_status,
    op.affected_country_iso_alpha_3_codes,
    op.affected_indicator_codes
FROM mart.mart_phase2_dataset_operator_panel op;

-- Keep the shared Phase 2 status-history views in one file; \ir anchors the path to this script.
\ir fragments/phase2_dataset_status_history_views.sql
