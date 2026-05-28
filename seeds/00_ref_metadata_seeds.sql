-- Phase 1 Wave 1 metadata seeds for the new ref layer.

INSERT INTO ref.frequency (frequency_code, frequency_name) VALUES
('A', 'Annual'),
('Q', 'Quarterly'),
('M', 'Monthly')
ON CONFLICT (frequency_code) DO NOTHING;

INSERT INTO ref.unit (unit_code, unit_name, unit_category, decimal_precision_default) VALUES
('CURR_USD', 'Current US Dollars', 'currency', 2),
('CURR_USD_PER_PERSON', 'Current US Dollars per person', 'currency_per_capita', 2),
('PCT', 'Percent', 'percentage', 2),
('PERSONS', 'Persons', 'count', 0)
ON CONFLICT (unit_code) DO NOTHING;

INSERT INTO ref.source_system (source_code, source_name, publisher_type, base_url, access_method, license_notes) VALUES
('ISO3166', 'ISO 3166 Country Standard', 'standards_body', 'https://www.iso.org/iso-3166-country-codes.html', 'reference_file', 'Country identity normalization reference'),
('WB', 'World Bank Open Data', 'multilateral', 'https://api.worldbank.org/v2/', 'api', 'Phase 1 annual macro backbone'),
('IMF', 'International Monetary Fund', 'multilateral', 'https://www.imf.org/en/Data', 'api', 'Registered early for later macro arbitration posture'),
('ILO', 'International Labour Organization', 'multilateral', 'https://rplumber.ilo.org/data/', 'api', 'Registered early for later labor-market ingestion planning; keep inactive until a narrow indicator slice is validated.'),
('UN', 'United Nations', 'multilateral', 'https://comtradeplus.un.org/', 'api', 'Registered early for later trade-ingestion planning; keep inactive until the first merchandise trade slice is modeled.')
ON CONFLICT (source_code) DO NOTHING;

INSERT INTO ref.source_dataset (
    source_system_key,
    dataset_code,
    dataset_name,
    default_frequency_code,
    default_grain,
    release_cadence,
    access_path,
    ingest_access_method,
    ingest_base_endpoint,
    ingest_default_format,
    ingest_requires_auth,
    ingest_cadence_note,
    is_active_for_ingest,
    is_active
)
SELECT ss.source_system_key, s.dataset_code, s.dataset_name, s.default_frequency_code, s.default_grain, s.release_cadence, s.access_path, s.ingest_access_method, s.ingest_base_endpoint, s.ingest_default_format, s.ingest_requires_auth, s.ingest_cadence_note, s.is_active_for_ingest, s.is_active
FROM (
    VALUES
        ('ISO3166', 'ISO3166_COUNTRY', 'ISO 3166 country code list', 'A', 'country', 'ad_hoc', 'reference', 'manual_file', 'reference', 'csv', FALSE, 'Reference-only seed loaded from local curated files when needed.', FALSE, TRUE),
        ('WB', 'WDI', 'World Development Indicators', 'A', 'country-year-indicator', 'periodic', 'https://api.worldbank.org/v2/country/all/indicator', 'api', 'https://api.worldbank.org/v2/', 'json', FALSE, 'Public API; Phase 2 target is reproducible snapshot fetches for the active Phase 1 indicator slice.', TRUE, TRUE),
        ('IMF', 'IFS', 'International Financial Statistics', 'A', 'country-period-series', 'periodic', 'https://www.imf.org/en/Data', 'api', 'https://www.imf.org/external/datamapper/api/v1/', 'json', FALSE, 'Public API for the widened 2019-2023 GDP-plus-inflation arbitration proof slice; broader SDMX-style ingestion can come later.', TRUE, TRUE),
        ('IMF', 'WEO', 'World Economic Outlook', 'A', 'country-period-series', 'periodic', 'https://www.imf.org/en/Publications/WEO', 'api', 'https://www.imf.org/external/datamapper/api/v1/', 'json', FALSE, 'First narrow external-balance proof slice for annual current-account fields through IMF DataMapper.', TRUE, TRUE),
        ('ILO', 'ILOSTAT', 'ILOSTAT bulk and API labor statistics catalog', 'A', 'country-year-indicator', 'periodic', 'https://rplumber.ilo.org/data/', 'api', 'https://rplumber.ilo.org/data/', 'json', FALSE, 'First live slice validated for total unemployment rate, employment-to-population ratio, and labour force participation rate ages 15+ across the seeded country basket for 2019-2023; broader labor indicator families still need explicit slice-by-slice modeling.', TRUE, TRUE),
        ('UN', 'UN_COMTRADE_ANNUAL', 'UN Comtrade annual merchandise trade dataset', 'A', 'country-year-indicator', 'periodic', 'https://comtradeplus.un.org/TradeFlow', 'api', 'https://comtradeplus.un.org/api/Trade/', 'json', FALSE, 'First live slice validated for annual total goods exports and imports against World partner totals across 2019-2023; broader partner and product grains still need explicit modeling.', TRUE, TRUE)
) AS s(source_code, dataset_code, dataset_name, default_frequency_code, default_grain, release_cadence, access_path, ingest_access_method, ingest_base_endpoint, ingest_default_format, ingest_requires_auth, ingest_cadence_note, is_active_for_ingest, is_active)
JOIN ref.source_system ss ON ss.source_code = s.source_code
ON CONFLICT (source_system_key, dataset_code) DO NOTHING;

UPDATE ref.source_dataset sd
SET ingest_access_method = s.ingest_access_method,
    ingest_base_endpoint = s.ingest_base_endpoint,
    ingest_default_format = s.ingest_default_format,
    ingest_requires_auth = s.ingest_requires_auth,
    ingest_cadence_note = s.ingest_cadence_note,
    is_active_for_ingest = s.is_active_for_ingest
FROM (
    VALUES
        ('WDI', 'api', 'https://api.worldbank.org/v2/', 'json', FALSE, 'Public API; Phase 2 target is reproducible snapshot fetches for the active Phase 1 indicator slice.', TRUE),
        ('IFS', 'api', 'https://www.imf.org/external/datamapper/api/v1/', 'json', FALSE, 'Public API for the widened 2019-2023 GDP-plus-inflation arbitration proof slice; broader SDMX-style ingestion can come later.', TRUE),
        ('WEO', 'api', 'https://www.imf.org/external/datamapper/api/v1/', 'json', FALSE, 'First narrow external-balance proof slice for annual current-account fields through IMF DataMapper.', TRUE),
        ('ILOSTAT', 'api', 'https://rplumber.ilo.org/data/', 'json', FALSE, 'First live slice validated for total unemployment rate, employment-to-population ratio, and labour force participation rate ages 15+ across the seeded country basket for 2019-2023; broader labor indicator families still need explicit slice-by-slice modeling.', TRUE),
        ('UN_COMTRADE_ANNUAL', 'api', 'https://comtradeplus.un.org/api/Trade/', 'json', FALSE, 'First live slice validated for annual total goods exports and imports against World partner totals across 2019-2023; broader partner and product grains still need explicit modeling.', TRUE),
        ('ISO3166_COUNTRY', 'manual_file', 'reference', 'csv', FALSE, 'Reference-only seed loaded from local curated files when needed.', FALSE)
) AS s(dataset_code, ingest_access_method, ingest_base_endpoint, ingest_default_format, ingest_requires_auth, ingest_cadence_note, is_active_for_ingest)
WHERE sd.dataset_code = s.dataset_code;

INSERT INTO ref.source_series (
    source_dataset_key,
    series_code,
    series_name,
    source_unit_text,
    source_frequency_code,
    coverage_notes,
    is_active
)
SELECT sd.source_dataset_key, s.series_code, s.series_name, s.source_unit_text, s.source_frequency_code, s.coverage_notes, s.is_active
FROM (
    VALUES
        ('WDI', 'NY.GDP.MKTP.CD', 'GDP (current US$)', 'current US$', 'A', 'Phase 1 required macro backbone series', TRUE),
        ('WDI', 'NY.GDP.PCAP.CD', 'GDP per capita (current US$)', 'current US$', 'A', 'Phase 1 required macro backbone series', TRUE),
        ('WDI', 'FP.CPI.TOTL.ZG', 'Inflation, consumer prices (annual %)', 'annual %', 'A', 'Phase 1 minimal annual inflation comparison series', TRUE),
        ('WDI', 'SP.POP.TOTL', 'Population, total', 'persons', 'A', 'Phase 1 required macro backbone series', TRUE),
        ('WDI', 'SL.EMP.TOTL.SP.ZS', 'Employment to population ratio, ages 15+, total (%)', 'percent', 'A', 'Narrow real overlap slice used to prove labor source-conflict diagnostics against ILOSTAT.', TRUE),
        ('WDI', 'SL.TLF.CACT.ZS', 'Labor force participation rate, ages 15+, total (%)', 'percent', 'A', 'Narrow real overlap slice used to prove labor source-conflict diagnostics against ILOSTAT.', TRUE),
        ('WDI', 'SL.UEM.TOTL.ZS', 'Unemployment, total (% of total labor force)', 'percent', 'A', 'Narrow real overlap slice used to prove labor source-conflict diagnostics against ILOSTAT.', TRUE),
        ('IFS', 'NGDP_USD', 'Nominal GDP (current US$)', 'current US$', 'A', 'Widened IMF IFS GDP authority series used for the 2019-2023 source-priority arbitration proof.', TRUE),
        ('IFS', 'PCPI_PC_PP_PT', 'Inflation, average consumer prices (annual %)', 'annual %', 'A', 'Widened IMF IFS inflation authority series used for the 2019-2023 live specialist-source slice.', TRUE),
        ('WEO', 'CURRENT_ACCOUNT_BALANCE_USD', 'Current account balance (U.S. dollars)', 'billions of current US$', 'A', 'First narrow WEO external-balance proof slice: annual current-account balance in U.S. dollars.', TRUE),
        ('WEO', 'CURRENT_ACCOUNT_BALANCE_PCT_GDP', 'Current account balance (% of GDP)', 'percent of GDP', 'A', 'First narrow WEO external-balance proof slice: annual current-account balance as a share of GDP.', TRUE),
        ('ILOSTAT', 'EMP_RATE_15PLUS_TOTAL', 'Employment-to-population ratio, total ages 15+ (%)', 'percent', 'A', 'Expanded ILOSTAT live labor slice: annual total employment-to-population ratio for ages 15+.', TRUE),
        ('ILOSTAT', 'LFPR_15PLUS_TOTAL', 'Labour force participation rate, total ages 15+ (%)', 'percent', 'A', 'Expanded ILOSTAT live labor slice: annual total labour force participation rate for ages 15+.', TRUE),
        ('ILOSTAT', 'UNE_RATE_15PLUS_TOTAL', 'Unemployment rate, total ages 15+ (%)', 'percent', 'A', 'Initial ILOSTAT live labor slice: SDG 8.5.2 annual total unemployment rate for ages 15+.', TRUE),
        ('UN_COMTRADE_ANNUAL', 'TRADE_EXPORTS_TOTAL_WORLD', 'Exports of all goods to World (US$)', 'current US$', 'A', 'Initial UN Comtrade live trade slice: annual total exports, partner World, all goods.', TRUE),
        ('UN_COMTRADE_ANNUAL', 'TRADE_IMPORTS_TOTAL_WORLD', 'Imports of all goods from World (US$)', 'current US$', 'A', 'Initial UN Comtrade live trade slice: annual total imports, partner World, all goods.', TRUE)
) AS s(dataset_code, series_code, series_name, source_unit_text, source_frequency_code, coverage_notes, is_active)
JOIN ref.source_dataset sd ON sd.dataset_code = s.dataset_code
ON CONFLICT (source_dataset_key, series_code) DO NOTHING;

INSERT INTO ref.source_series_alias (
    source_series_key,
    alias_type,
    alias_code,
    alias_label,
    is_active
)
SELECT rs.source_series_key, a.alias_type, a.alias_code, a.alias_label, a.is_active
FROM (
    VALUES
        ('WDI', 'SL.EMP.TOTL.SP.ZS', 'wb_indicator_code', 'SL.EMP.TOTL.SP.ZS', 'World Bank API code for employment to population ratio, ages 15+, total.', TRUE),
        ('WDI', 'SL.TLF.CACT.ZS', 'wb_indicator_code', 'SL.TLF.CACT.ZS', 'World Bank API code for labor force participation rate, ages 15+, total.', TRUE),
        ('WDI', 'SL.UEM.TOTL.ZS', 'wb_indicator_code', 'SL.UEM.TOTL.ZS', 'World Bank API code for total unemployment rate.', TRUE),
        ('IFS', 'NGDP_USD', 'imf_datamapper_indicator', 'NGDPD', 'IMF DataMapper API code for Nominal GDP (current US$)', TRUE),
        ('IFS', 'PCPI_PC_PP_PT', 'imf_datamapper_indicator', 'PCPIPCH', 'IMF DataMapper API code for Inflation, average consumer prices (annual %)', TRUE),
        ('WEO', 'CURRENT_ACCOUNT_BALANCE_USD', 'imf_datamapper_indicator', 'BCA', 'IMF DataMapper API code for current account balance in U.S. dollars.', TRUE),
        ('WEO', 'CURRENT_ACCOUNT_BALANCE_PCT_GDP', 'imf_datamapper_indicator', 'BCA_NGDPD', 'IMF DataMapper API code for current account balance as a share of GDP.', TRUE),
        ('ILOSTAT', 'EMP_RATE_15PLUS_TOTAL', 'ilo_indicator_request', 'EMP_DWAP_SEX_AGE_RT_A|SEX_T|AGE_YTHADULT_YGE15', 'ILOSTAT API request signature for annual total employment-to-population ratio ages 15+.', TRUE),
        ('ILOSTAT', 'LFPR_15PLUS_TOTAL', 'ilo_indicator_request', 'EAP_DWAP_SEX_AGE_RT_A|SEX_T|AGE_YTHADULT_YGE15', 'ILOSTAT API request signature for annual total labour force participation rate ages 15+.', TRUE),
        ('ILOSTAT', 'UNE_RATE_15PLUS_TOTAL', 'ilo_indicator_request', 'SDG_0852_SEX_AGE_RT_A|SEX_T|AGE_YTHADULT_YGE15', 'ILOSTAT API request signature for annual total unemployment rate ages 15+.', TRUE),
        ('UN_COMTRADE_ANNUAL', 'TRADE_EXPORTS_TOTAL_WORLD', 'uncomtrade_flow_code', 'X', 'UN Comtrade flow code for annual total exports to World.', TRUE),
        ('UN_COMTRADE_ANNUAL', 'TRADE_IMPORTS_TOTAL_WORLD', 'uncomtrade_flow_code', 'M', 'UN Comtrade flow code for annual total imports from World.', TRUE)
) AS a(dataset_code, series_code, alias_type, alias_code, alias_label, is_active)
JOIN ref.source_dataset sd ON sd.dataset_code = a.dataset_code
JOIN ref.source_series rs
  ON rs.source_dataset_key = sd.source_dataset_key
 AND rs.series_code = a.series_code
ON CONFLICT (source_series_key, alias_type) DO UPDATE
SET alias_code = EXCLUDED.alias_code,
    alias_label = EXCLUDED.alias_label,
    is_active = EXCLUDED.is_active;

INSERT INTO ref.indicator (
    indicator_code,
    indicator_name,
    topic,
    default_unit_key,
    default_frequency_code,
    value_datatype,
    preferred_aggregation,
    is_phase_1,
    description
)
SELECT i.indicator_code, i.indicator_name, i.topic, u.unit_key, i.default_frequency_code, i.value_datatype, i.preferred_aggregation, i.is_phase_1, i.description
FROM (
    VALUES
        ('GDP_CURR_USD', 'GDP (current US$)', 'macro_foundation', 'CURR_USD', 'A', 'numeric', 'latest', TRUE, 'Phase 1 macro foundation gross domestic product at current US dollars.'),
        ('GDP_PC_CURR_USD', 'GDP per capita (current US$)', 'macro_foundation', 'CURR_USD_PER_PERSON', 'A', 'numeric', 'latest', TRUE, 'Phase 1 macro foundation GDP per capita at current US dollars.'),
        ('INFLATION_CPI_PCT', 'Inflation, consumer prices (annual %)', 'macro_prices', 'PCT', 'A', 'numeric', 'latest', TRUE, 'Minimal Phase 1 inflation slice used to prove dataset-level source-priority arbitration between WDI and IMF IFS.'),
        ('POP_TOTAL', 'Population, total', 'macro_foundation', 'PERSONS', 'A', 'numeric', 'latest', TRUE, 'Phase 1 macro foundation total population indicator.'),
        ('EMPLOYMENT_RATE_PCT', 'Employment-to-population ratio, total ages 15+ (%)', 'labor_market', 'PCT', 'A', 'numeric', 'latest', FALSE, 'Expanded Phase 2 labor authority slice sourced from ILOSTAT annual total employment-to-population ratio ages 15+.'),
        ('LABOR_FORCE_PARTICIPATION_RATE_PCT', 'Labour force participation rate, total ages 15+ (%)', 'labor_market', 'PCT', 'A', 'numeric', 'latest', FALSE, 'Expanded Phase 2 labor authority slice sourced from ILOSTAT annual total labour force participation rate ages 15+.'),
        ('UNEMPLOYMENT_RATE_PCT', 'Unemployment rate, total ages 15+ (%)', 'labor_market', 'PCT', 'A', 'numeric', 'latest', FALSE, 'Initial Phase 2 labor authority slice sourced from ILOSTAT SDG 8.5.2 annual total unemployment rate ages 15+.'),
        ('TRADE_EXPORTS_CURR_USD', 'Exports of all goods to World (current US$)', 'trade', 'CURR_USD', 'A', 'numeric', 'latest', FALSE, 'Initial Phase 2 trade authority slice sourced from UN Comtrade annual total goods exports to World.'),
        ('TRADE_IMPORTS_CURR_USD', 'Imports of all goods from World (current US$)', 'trade', 'CURR_USD', 'A', 'numeric', 'latest', FALSE, 'Initial Phase 2 trade authority slice sourced from UN Comtrade annual total goods imports from World.'),
        ('CURRENT_ACCOUNT_BALANCE_CURR_USD', 'Current account balance (current US$)', 'external_balance', 'CURR_USD', 'A', 'numeric', 'latest', FALSE, 'Initial Phase 2 external-balance authority slice sourced from IMF WEO annual current-account balance.'),
        ('CURRENT_ACCOUNT_BALANCE_PCT_GDP', 'Current account balance (% of GDP)', 'external_balance', 'PCT', 'A', 'numeric', 'latest', FALSE, 'Initial Phase 2 external-balance authority slice sourced from IMF WEO annual current-account balance as a share of GDP.')
) AS i(indicator_code, indicator_name, topic, unit_code, default_frequency_code, value_datatype, preferred_aggregation, is_phase_1, description)
JOIN ref.unit u ON u.unit_code = i.unit_code
ON CONFLICT (indicator_code) DO NOTHING;

INSERT INTO ref.indicator_source_series_map (
    indicator_key,
    source_series_key,
    mapping_notes,
    is_active
)
SELECT i.indicator_key, rs.source_series_key, m.mapping_notes, m.is_active
FROM (
    VALUES
        ('GDP_CURR_USD', 'WDI', 'NY.GDP.MKTP.CD', 'WDI annual GDP backbone mapping', TRUE),
        ('GDP_CURR_USD', 'IFS', 'NGDP_USD', 'IFS GDP arbitration mapping for specialist-source overlap', TRUE),
        ('GDP_PC_CURR_USD', 'WDI', 'NY.GDP.PCAP.CD', 'WDI GDP per capita backbone mapping', TRUE),
        ('INFLATION_CPI_PCT', 'WDI', 'FP.CPI.TOTL.ZG', 'WDI inflation fallback mapping', TRUE),
        ('INFLATION_CPI_PCT', 'IFS', 'PCPI_PC_PP_PT', 'IFS inflation authority mapping for the live specialist-source slice', TRUE),
        ('POP_TOTAL', 'WDI', 'SP.POP.TOTL', 'WDI population backbone mapping', TRUE),
        ('EMPLOYMENT_RATE_PCT', 'WDI', 'SL.EMP.TOTL.SP.ZS', 'Narrow real WDI overlap mapping for labor conflict diagnostics.', TRUE),
        ('LABOR_FORCE_PARTICIPATION_RATE_PCT', 'WDI', 'SL.TLF.CACT.ZS', 'Narrow real WDI overlap mapping for labor conflict diagnostics.', TRUE),
        ('UNEMPLOYMENT_RATE_PCT', 'WDI', 'SL.UEM.TOTL.ZS', 'Narrow real WDI overlap mapping for labor conflict diagnostics.', TRUE),
        ('EMPLOYMENT_RATE_PCT', 'ILOSTAT', 'EMP_RATE_15PLUS_TOTAL', 'ILOSTAT employment-to-population authority mapping for the expanded live labor slice', TRUE),
        ('LABOR_FORCE_PARTICIPATION_RATE_PCT', 'ILOSTAT', 'LFPR_15PLUS_TOTAL', 'ILOSTAT labour-force-participation authority mapping for the expanded live labor slice', TRUE),
        ('UNEMPLOYMENT_RATE_PCT', 'ILOSTAT', 'UNE_RATE_15PLUS_TOTAL', 'ILOSTAT unemployment authority mapping for the first live labor slice', TRUE),
        ('TRADE_EXPORTS_CURR_USD', 'UN_COMTRADE_ANNUAL', 'TRADE_EXPORTS_TOTAL_WORLD', 'UN Comtrade exports authority mapping for the first live trade slice', TRUE),
        ('TRADE_IMPORTS_CURR_USD', 'UN_COMTRADE_ANNUAL', 'TRADE_IMPORTS_TOTAL_WORLD', 'UN Comtrade imports authority mapping for the first live trade slice', TRUE),
        ('CURRENT_ACCOUNT_BALANCE_CURR_USD', 'WEO', 'CURRENT_ACCOUNT_BALANCE_USD', 'WEO current-account balance authority mapping for the first external-balance slice', TRUE),
        ('CURRENT_ACCOUNT_BALANCE_PCT_GDP', 'WEO', 'CURRENT_ACCOUNT_BALANCE_PCT_GDP', 'WEO current-account-balance-percent-of-GDP authority mapping for the first external-balance slice', TRUE)
) AS m(indicator_code, dataset_code, series_code, mapping_notes, is_active)
JOIN ref.indicator i ON i.indicator_code = m.indicator_code
JOIN ref.source_dataset sd ON sd.dataset_code = m.dataset_code
JOIN ref.source_series rs
  ON rs.source_dataset_key = sd.source_dataset_key
 AND rs.series_code = m.series_code
ON CONFLICT (indicator_key, source_series_key) DO UPDATE
SET mapping_notes = EXCLUDED.mapping_notes,
    is_active = EXCLUDED.is_active;

INSERT INTO ref.validation_rule (
    rule_code,
    rule_name,
    rule_category,
    severity,
    target_layer,
    rule_description,
    blocks_publication,
    is_active
)
VALUES
    ('STRUCT_COUNTRY_REQUIRED', 'Country mapping required for publication', 'referential', 'error', 'staging', 'Country mapping must resolve before a row can publish.', TRUE, TRUE),
    ('STRUCT_INDICATOR_REQUIRED', 'Indicator mapping required for publication', 'referential', 'error', 'staging', 'Indicator mapping must resolve before a row can publish.', TRUE, TRUE),
    ('STRUCT_TIME_REQUIRED', 'Time resolution required for publication', 'structural', 'error', 'staging', 'Annual observations must resolve onto core.dim_time before publication.', TRUE, TRUE),
    ('SEM_VALUE_PARSE_FAILED', 'Observation value parse failed', 'semantic', 'error', 'staging', 'Source value text could not be coerced into the numeric Phase 1 observation contract.', TRUE, TRUE),
    ('SEM_VALUE_MISSING', 'Observation value missing at source', 'semantic', 'warning', 'staging', 'Source delivered a missing value for the requested annual observation.', FALSE, TRUE)
ON CONFLICT (rule_code) DO NOTHING;

DELETE FROM ref.indicator_source_priority isp
USING ref.indicator i, ref.source_dataset d
WHERE isp.indicator_key = i.indicator_key
  AND isp.source_dataset_key = d.source_dataset_key
  AND isp.country_key IS NULL
  AND isp.valid_from_year IS NULL
  AND isp.effective_from = DATE '2026-01-01'
  AND isp.release_window_code = 'default'
  AND (
      (i.indicator_code = 'GDP_CURR_USD' AND d.dataset_code IN ('WDI', 'IFS'))
      OR (i.indicator_code = 'GDP_PC_CURR_USD' AND d.dataset_code = 'WDI')
      OR (i.indicator_code = 'INFLATION_CPI_PCT' AND d.dataset_code IN ('WDI', 'IFS'))
      OR (i.indicator_code = 'POP_TOTAL' AND d.dataset_code = 'WDI')
      OR (i.indicator_code = 'EMPLOYMENT_RATE_PCT' AND d.dataset_code IN ('ILOSTAT', 'WDI'))
      OR (i.indicator_code = 'LABOR_FORCE_PARTICIPATION_RATE_PCT' AND d.dataset_code IN ('ILOSTAT', 'WDI'))
      OR (i.indicator_code = 'UNEMPLOYMENT_RATE_PCT' AND d.dataset_code IN ('ILOSTAT', 'WDI'))
      OR (i.indicator_code = 'TRADE_EXPORTS_CURR_USD' AND d.dataset_code = 'UN_COMTRADE_ANNUAL')
      OR (i.indicator_code = 'TRADE_IMPORTS_CURR_USD' AND d.dataset_code = 'UN_COMTRADE_ANNUAL')
      OR (i.indicator_code = 'CURRENT_ACCOUNT_BALANCE_CURR_USD' AND d.dataset_code = 'WEO')
      OR (i.indicator_code = 'CURRENT_ACCOUNT_BALANCE_PCT_GDP' AND d.dataset_code = 'WEO')
  );

INSERT INTO ref.indicator_source_priority (
    indicator_key,
    source_dataset_key,
    country_key,
    priority_rank,
    valid_from_year,
    valid_to_year,
    effective_from,
    effective_to,
    release_window_code,
    selection_rationale,
    is_override
)
SELECT i.indicator_key, d.source_dataset_key, NULL, p.priority_rank, NULL, NULL, DATE '2026-01-01', NULL, 'default', p.selection_rationale, FALSE
FROM (
    VALUES
        ('GDP_CURR_USD', 'IFS', 1, 'IMF IFS is the preferred authority for the minimal GDP source-selection proof.'),
        ('GDP_CURR_USD', 'WDI', 2, 'WDI remains the broad-coverage fallback GDP series when the minimal IMF IFS sample does not cover a country-year.'),
        ('GDP_PC_CURR_USD', 'WDI', 1, 'Phase 1 production backbone uses WDI for broad annual country coverage.'),
        ('INFLATION_CPI_PCT', 'IFS', 1, 'IMF IFS is the preferred authority for the minimal inflation source-selection proof.'),
        ('INFLATION_CPI_PCT', 'WDI', 2, 'WDI remains the broad-coverage fallback inflation series when the minimal IMF IFS sample does not cover a country-year.'),
        ('POP_TOTAL', 'WDI', 1, 'Phase 1 production backbone uses WDI for broad annual country coverage.'),
        ('EMPLOYMENT_RATE_PCT', 'ILOSTAT', 1, 'ILOSTAT is the preferred authority for the first employment-to-population labor slice.'),
        ('EMPLOYMENT_RATE_PCT', 'WDI', 2, 'WDI is a narrow real overlap slice used to prove labor source-conflict diagnostics when ILOSTAT also covers the same country-year.'),
        ('LABOR_FORCE_PARTICIPATION_RATE_PCT', 'ILOSTAT', 1, 'ILOSTAT is the preferred authority for the first labour-force-participation labor slice.'),
        ('LABOR_FORCE_PARTICIPATION_RATE_PCT', 'WDI', 2, 'WDI is a narrow real overlap slice used to prove labor source-conflict diagnostics when ILOSTAT also covers the same country-year.'),
        ('UNEMPLOYMENT_RATE_PCT', 'ILOSTAT', 1, 'ILOSTAT is the preferred authority for the first unemployment-rate labor slice.'),
        ('UNEMPLOYMENT_RATE_PCT', 'WDI', 2, 'WDI is a narrow real overlap slice used to prove labor source-conflict diagnostics when ILOSTAT also covers the same country-year.'),
        ('TRADE_EXPORTS_CURR_USD', 'UN_COMTRADE_ANNUAL', 1, 'UN Comtrade is the preferred authority for the first total-exports trade slice.'),
        ('TRADE_IMPORTS_CURR_USD', 'UN_COMTRADE_ANNUAL', 1, 'UN Comtrade is the preferred authority for the first total-imports trade slice.'),
        ('CURRENT_ACCOUNT_BALANCE_CURR_USD', 'WEO', 1, 'IMF WEO is the preferred authority for the first current-account-balance external-balance slice.'),
        ('CURRENT_ACCOUNT_BALANCE_PCT_GDP', 'WEO', 1, 'IMF WEO is the preferred authority for the first current-account-balance-percent-of-GDP external-balance slice.')
) AS p(indicator_code, dataset_code, priority_rank, selection_rationale)
JOIN ref.indicator i ON i.indicator_code = p.indicator_code
JOIN ref.source_dataset d ON d.dataset_code = p.dataset_code;
