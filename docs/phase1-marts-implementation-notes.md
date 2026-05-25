# Phase 1 Marts and Diagnostic Views Slice Notes

This slice lands the first analyst-facing `mart` layer on top of the already-landed `core` published facts and `audit` publication controls.

## Scope landed here
- `mart.mart_country_macro_latest`
- `mart.mart_country_macro_series_annual`
- `mart.mart_country_profile_foundation`
- `mart.vw_macro_published_with_lineage`
- `mart.vw_macro_revision_history`
- `mart.vw_macro_coverage_gaps`
- `mart.vw_dataset_freshness_status`

## Small supporting posture
No new ranking or orchestration family was added here. The marts/views attach directly to the existing `core.fact_country_indicator_published`, `core.fact_country_indicator_version`, `audit.*`, and conformed-dimension surfaces.

## Intentionally not landed here
- the later constraints/indexes/publish-guard hardening pass
- new domain expansion beyond the current Phase 1 macro foundation indicators
- any new dependency on the legacy `dw` path
