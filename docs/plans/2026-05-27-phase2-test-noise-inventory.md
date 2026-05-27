# Phase 2 regression noise inventory

Purpose: classify the success-path output of `queries/test_phase2_starter_marts.sql` before quieting it.

Baseline command
- `make test-phase2-starter-marts-offline`
- Current state: passes, but prints 16 result sets after the `DO $$ ... $$` assertion block.

Keep as default compact proof
1. `mart.vw_phase2_source_conflict_summary`
   - Why: one compact cross-family conflict proof slice is enough for happy-path evidence.
2. `mart.vw_domain_qa_summary_phase2`
   - Why: shows dataset-level freshness, publish status, QA counts, and conflict counts.
3. `mart.mart_country_phase2_latest`
   - Why: shows the actual analyst-facing latest snapshot, including labor, inflation, trade, and external-balance fields.

Verbose/debug only
1. `mart.mart_country_labor_series_annual`
2. `mart.mart_country_inflation_series_annual`
3. `mart.vw_labor_source_conflicts`
4. `mart.vw_labor_source_conflicts_latest`
5. `mart.vw_labor_source_conflict_summary_latest`
6. `mart.vw_inflation_source_conflicts`
7. `mart.vw_inflation_source_conflicts_latest`
8. `mart.vw_inflation_source_conflict_summary_latest`
9. `mart.vw_gdp_source_conflicts`
10. `mart.vw_gdp_source_conflicts_latest`
11. `mart.vw_gdp_source_conflict_summary_latest`
12. `mart.mart_country_trade_external_panel_annual`
13. `mart.vw_trade_external_revision_history`
14. `mart.mart_country_macro_plus_external_latest`

Rationale
- These are useful when debugging a failed assertion or inspecting a specific source-arbitration case.
- They are excessive for the passing path because the `DO $$ ... $$` block already carries the hard contract assertions.
- Several pairs are redundant on success because they print both verbose and deduped variants of the same proof family.

Decision
- Default mode should print only 3 compact result sets.
- Debug mode should preserve the detailed row dumps behind a psql variable / Make target.
