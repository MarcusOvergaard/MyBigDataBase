-- Country-specific source-priority override proof for Phase 1.
-- Demonstrates that a country override can intentionally beat the global default.

DELETE FROM ref.indicator_source_priority isp
USING ref.indicator i, ref.source_dataset d, ref.country c
WHERE isp.indicator_key = i.indicator_key
  AND isp.source_dataset_key = d.source_dataset_key
  AND isp.country_key = c.country_key
  AND i.indicator_code = 'INFLATION_CPI_PCT'
  AND d.dataset_code = 'WDI'
  AND c.iso_alpha_3 = 'DEU'
  AND isp.valid_from_year = 2022
  AND isp.effective_from = DATE '2026-01-01'
  AND isp.release_window_code = 'default';

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
SELECT i.indicator_key, d.source_dataset_key, c.country_key, 1, 2022, 2022, DATE '2026-01-01', NULL, 'default',
       'Germany override proof: prefer WDI inflation over the global IFS default only for observation year 2022 so the temporal override window is exercised explicitly.',
       TRUE
FROM ref.indicator i
JOIN ref.source_dataset d ON d.dataset_code = 'WDI'
JOIN ref.country c ON c.iso_alpha_3 = 'DEU'
WHERE i.indicator_code = 'INFLATION_CPI_PCT';
