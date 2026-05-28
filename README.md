# Country Intelligence Data Warehouse (country_intel)

A PostgreSQL-based data warehouse for country-level economic and social indicator analysis.

## Current implementation phase
The repository is now in a Phase 1 contract transition:
- the new warehouse layer contract is `ref` / `raw` / `staging` / `core` / `audit` / `mart`
- Wave 1 metadata foundations now live in `ref`
- the first Phase 1 raw/staging contract is now in place for WDI annual observations
- the first conformed core dimensions are now in place for country, indicator, source, dataset, and time
- the first conformed core fact surfaces are now in place for version history and the published Phase 1 annual row contract
- the first audit/publication control surfaces are now in place for run logging, QA persistence, revision tracking, publication stamping, and dataset freshness
- the first analyst-facing Phase 1 marts and diagnostic views are now in place on top of the published/audit spine
- the first Wave 8 hardening layer is now in place for critical constraints, performance indexes, and publish-guard checks
- the first canonical-contract follow-through layer is now in place for comparability-break flags, rule-version lineage, and explicit source-selection diagnostics
- only a few explicit legacy compatibility stubs remain for old file paths; the active warehouse path is now Phase 1 end to end

That means new implementation work should target the Phase 1 contract first, and the default developer workflow now exercises that path instead of the old demo ETL.

## Prerequisites
- **PostgreSQL 14+** (standard in most WSL/Linux environments)
- **Make** (usually pre-installed or `sudo apt install make`)
- **Bash**

If you're using the local Postgres instance on this machine, the default connection targets are:
- host: `/var/run/postgresql`
- port: `5433`
- user: `marcusai`

That path uses local socket auth, so no password export is normally needed.

If you want to point the repo at a Docker/TCP Postgres instead, override the Make variables, for example:
```bash
make init DB_HOST=localhost DB_PORT=5432 DB_USER=postgres
```

## Quick Start (WSL/Linux CLI)

1. **Clone/Create the project**: You are already in the project directory.
2. **Initialize the database**:
   ```bash
   make init
   ```
3. **Load Sample Data through the Phase 1 path**:
   ```bash
   make load-sample
   ```
   This now creates a `raw.source_batch`, lands WDI-style annual rows in `raw.wdi_country_indicator_annual`, loads minimal IMF IFS inflation and GDP arbitration slices into `raw.ifs_country_indicator_annual`, runs `staging.normalize_wdi_country_observation_annual(...)` for the WDI batch, and publishes through `etl.publish_phase1_country_indicator_facts(...)`.

   Important: this is currently a sample-data path, not a live API ingestion path. The repository is proving the warehouse contract and source-selection logic first by loading local sample files (`raw_files/sample_wb_data.csv` and `raw_files/sample_ifs_data.csv`). It does not yet fetch fresh rows directly from WDI or IMF during `make load-sample`.

4. **Optional: load the first narrow live WDI slice**:
   ```bash
   make load-wdi-live
   ```
   This fetches a small real WDI API slice for the active Phase 1 indicators, stores the raw JSON snapshots under `ingest/snapshots/wdi/WDI/`, records those files in `raw.source_snapshot`, lands the rows in `raw.wdi_country_indicator_annual`, and then reuses the same `raw -> staging -> core -> audit -> mart` pipeline.

5. **Optional: load the first narrow live WDI labor overlap slice**:
   ```bash
   make load-wdi-labor-live
   ```
   This fetches a deliberately tiny real WDI labor slice for `DEU` in `2022`, writes snapshot JSON plus a per-run manifest under `ingest/snapshots/wdi/WDI/`, records the evidence in `raw.source_snapshot`, lands the rows in `raw.wdi_country_indicator_annual`, and proves the labor conflict diagnostics against the preferred ILOSTAT rows using real source data end to end.

6. **Optional: load the first narrow live IFS slice**:
   ```bash
   make load-ifs-live
   ```
   This fetches a small real IMF DataMapper slice plus country metadata, stores the JSON snapshots under `ingest/snapshots/ifs/IFS/`, writes a per-run manifest there, records the snapshot files in `raw.source_snapshot`, lands the rows in `raw.ifs_country_indicator_annual`, and then reuses the same `raw -> staging -> core -> audit -> mart` pipeline. The live IFS loader now resolves its requested IMF indicator codes from warehouse metadata instead of a shell hardcode, records both API indicator codes and source-series codes in batch lineage, and deletes incomplete run snapshots if a run fails mid-flight.

7. **Optional: clean stale IFS snapshot files**:
   ```bash
   make clean-ifs-stale-snapshots
   ```
   This removes IFS snapshot JSON files under `ingest/snapshots/ifs/IFS/` that are not referenced by any successful per-run manifest.
8. **Run Phase 1 validation queries**:
   ```bash
   make test
   ```
9. **Fail fast if there are active pipeline alerts**:
   ```bash
   make check-alerts
   ```
   This exits non-zero when `mart.dataset_pipeline_alerts` contains any rows, so it is suitable for CI, cron, or a simple health-check wrapper.
10. **Re-run the live WDI backbone contract check**:
   ```bash
   make test-live-wdi-contract
   ```
   This reruns the WDI backbone slice and fails if the latest live WDI batch loses its request lineage fields, drops the expected WDI indicator mappings, fails to normalize all four backbone indicators, or leaves pipeline alerts behind.
11. **Re-run the live WDI labor overlap contract check**:
   ```bash
   make test-live-wdi-labor-contract
   ```
   This reruns the narrow WDI labor overlap slice and fails if the latest live WDI labor batch loses its labor-series lineage arrays, stops normalizing the three overlap indicators, or leaves pipeline alerts behind.

12. **Re-run the live IFS macro arbitration contract check**:
   ```bash
   make test-live-ifs-contract
   ```
   This reruns the IFS specialist-source slice and fails if the latest live IFS batch loses its metadata-driven indicator lineage, stops declaring the GDP/CPI source-series codes in `request_params_json`, fails to publish IFS-backed inflation or GDP rows, or leaves pipeline alerts behind.

13. **Re-run the live WEO external-balance contract check**:
   ```bash
   make test-live-weo-contract
   ```
   This reruns the WEO external-balance slice and fails if the latest live WEO batch loses its metadata-driven indicator lineage, stops declaring the current-account source-series codes in `request_params_json`, fails to publish WEO-backed current-account rows, or leaves pipeline alerts behind.

14. **Re-run every live contract check in one shot**:
   ```bash
   make test-live-contracts
   ```
   This runs the WDI backbone, WDI labor overlap, IFS, WEO, ILOSTAT, and UN Comtrade live contract checks back to back.

15. **Re-run every live contract check against local fixtures**:
   ```bash
   make test-live-contracts-offline
   ```
   This swaps each live fetcher for a committed fixture-backed mock helper under `tests/fixtures/live_sources/`, so the warehouse contract can be verified without depending on external APIs.

16. **Assert the first Phase 2 inflation, labor, trade, external-balance, QA, and combined latest marts after the offline suite**:
   ```bash
   make test-phase2-starter-marts-offline
   ```
   This now keeps the success-path output compact: it prints a cross-family Phase 2 conflict summary, the dataset-level QA/freshness summary, a compact `mart.mart_phase2_dataset_coverage_trend` latest-year scan so source-wide versus country-specific gaps show up immediately, a compact `mart.mart_country_phase2_dependency_explainer` scan so missing indicators point back to their expected dataset plus configured fallback options, a compact `mart.mart_country_phase2_ingestion_gap_explainer` scan so missing country-indicator pairs can be traced to the latest source batch / manifest / raw-versus-staging counts / QA-versus-publication stage, a dataset-level `mart.mart_phase2_dataset_ingestion_gap_rollup` scan so operators can see which source is currently failing at fetch scope versus normalization versus QA versus publication without drilling into country rows, a thinner `mart.vw_phase2_dataset_operator_panel_scan` surface that ranks dataset attention and compresses latest indicator/country coverage into one line per source, a thinner `mart.vw_phase2_dataset_status_history_scan` surface that ranks batch severity and shows batch-to-batch coverage movement without the forensic clutter, and a compact `mart.mart_country_phase2_issues` scan so weak countries surface with readiness flags, coverage gaps, and trade/external completeness hints.

17. **Run the compact Phase 2 operator scan directly when you want the current dataset/batch picture without the full regression harness**:
   ```bash
   make phase2-operator-scan
   ```
   This uses `queries/phase2_operator_scan.sql` to print a one-row dataset-status count summary, the ranked per-dataset operator scan, the latest batch row per dataset, and a short list of deteriorating or non-healthy batch-history rows.

18. **Run the compact Phase 2 operator report when you want the scan plus pipeline-alert context in one command**:
   ```bash
   make phase2-operator-report
   ```
   This wraps `scripts/report_phase2_operator_scan.sh` and prints: the dataset-status summary line, the ranked dataset operator scan, the latest batch row per dataset, and any active `mart.dataset_pipeline_alerts` rows.

19. **Run the silent Phase 2 watchdog when you only want output for real failures**:
   ```bash
   make phase2-operator-watchdog
   ```
   This wraps `scripts/check_phase2_operator_watchdog.sh` and stays silent when there are no `failing_active_gap` datasets and no active `mart.dataset_pipeline_alerts` rows. It is suitable for higher-frequency cron checks.

20. **Verify the current real-ingestion live state without resetting the database**:
   ```bash
   make verify-real-ingestion-live-state
   ```
   This runs the human-readable Phase 2 operator report first and then fails non-zero if `mart.dataset_pipeline_alerts` still contains active alerts.

21. **Run the offline smoke test for the compact Phase 2 monitoring wrappers when you want to prove the command wiring still behaves correctly without depending on live database state**:
   ```bash
   make test-phase2-monitoring-offline
   ```
   This uses `scripts/test_phase2_monitoring_smoke.sh` with a fixture-backed mock `psql` shim to verify three paths: the compact report output, the silent healthy watchdog path, and the alert-emitting watchdog path.

22. **Run the compact offline Phase 2 regression bundle when you want both the SQL mart checks and the monitoring-wrapper smoke tests in one command**:
   ```bash
   make test-phase2-offline
   ```
   This chains `make test-phase2-starter-marts-offline` and `make test-phase2-monitoring-offline` so the Phase 2 serving surfaces and the operator-monitoring entrypoints stay covered together.

   If you need the old row-dump surfaces for debugging source arbitration or revision history, run:
   ```bash
   make test-phase2-starter-marts-debug
   ```

## Schema Architecture

### Phase 1 target contract
- `ref`: Reference and governance metadata for countries, source systems, datasets, dataset-native series, source-series aliases, indicator-to-series mappings, indicators, and source-priority rules.
- `raw`: Entry point for source-native files/API payloads and batch lineage.
- `staging`: Cleansed and standardized observations used before publication.
- `core`: Curated published/versioned warehouse tables and conformed dimensions.
- `audit`: Validation, revision, publication, and pipeline-run observability.
- `mart`: Analyst-facing marts and diagnostic views built from published data, including flattened source-selection lineage for arbitration inspection.

### Phase 1 surfaces now landed
- `ddl/03_raw_tables.sql`: `raw.source_batch`, `raw.source_snapshot`, and dataset-specific raw observation tables
- `ddl/04_staging_tables.sql`: `staging.country_observation_annual`
- `ddl/05_core_dimensions.sql`: `core.dim_country`, `core.dim_indicator`, `core.dim_source`, `core.dim_dataset`, and `core.dim_time`
- `ddl/06_core_facts.sql`: `core.fact_country_indicator_version` and `core.fact_country_indicator_published`
- `ddl/07_audit_tables.sql`: `audit.pipeline_run`, `audit.data_quality_event`, `audit.revision_event`, `audit.publication_version`, and `audit.dataset_freshness`
- `ddl/08_marts_and_views.sql`: first Phase 1 marts and diagnostic views on the published/audit spine, including `mart.dataset_pipeline_health` for dataset-level operating health, `mart.dataset_pipeline_alerts` for alert-only monitoring, the first proper labor/inflation/trade/external-balance Phase 2 marts, the combined macro-plus-external latest snapshot, a thinner `mart.mart_country_phase2_latest` operator surface plus `mart.mart_country_phase2_readiness_summary`, `mart.mart_country_phase2_issues`, `mart.mart_country_phase2_dependency_explainer`, `mart.mart_country_phase2_ingestion_gap_explainer`, `mart.mart_phase2_dataset_ingestion_gap_rollup`, `mart.mart_phase2_dataset_operator_panel`, the compact `mart.vw_phase2_dataset_operator_panel_scan` / `mart.vw_phase2_dataset_status_history_scan` entry points for one-glance dataset monitoring, and labor/inflation/trade diagnostic views, including compact labor/inflation/GDP conflict summary entry points for routine inspection.
- `ddl/09_constraints_indexes.sql`: first Wave 8 hardening unit for constraints, indexes, and publish guards
- `ddl/10_canonical_contract_followthrough.sql`: additive canonical-contract enforcement for comparability/source-switch lineage, including `mart.vw_macro_source_selection_lineage` for flattened source-selection diagnostics
- `seeds/01_core_dimension_seeds.sql`: conformed core-dimension sync from `ref`
- `scripts/populate_core_time.sql`: annual `core.dim_time` periods for the Phase 1 year range
- `etl/01_raw_to_staging.sql`: new Phase 1 normalization procedure, including annual `core.dim_time` resolution
- `etl/03_publish_phase1.sql`: Phase 1 publish procedure with publication stamping, revision logging, QA persistence, and freshness updates

### Operational contract
- The runnable warehouse path is now the Phase 1 contract end to end: `raw -> staging -> core -> audit -> mart`.
- `etl` contains the normalization and publication procedures that support that contract.
- The repo now supports both sample loaders and the first live API-backed loaders, and future ingestion work should keep plugging into this same contract rather than create a separate path.

## Key Files
- `ddl/01_schemas.sql`: Phase 1 layer bootstrap.
- `ddl/02_ref_tables.sql`: Wave 1 metadata contract in `ref`.
- `ddl/03_raw_tables.sql`: Phase 1 raw lineage surfaces, including source batches and snapshot evidence.
- `ddl/04_staging_tables.sql`: Phase 1 normalized staging surface.
- `ddl/05_core_dimensions.sql`: first conformed core dimensions.
- `ddl/06_core_facts.sql`: first conformed core fact surfaces.
- `ddl/07_audit_tables.sql`: first audit/publication control surfaces.
- `ddl/08_marts_and_views.sql`: first analyst-facing marts and diagnostic views.
- `ddl/09_constraints_indexes.sql`: first hardening layer for the Phase 1 contract.
- `ddl/10_canonical_contract_followthrough.sql`: canonical-contract follow-through for comparability and rule-version enforcement.
- `seeds/00_ref_metadata_seeds.sql`: Wave 1 metadata seeds.
- `seeds/01_core_dimension_seeds.sql`: core dimension sync from `ref`.
- `scripts/populate_core_time.sql`: Phase 1 annual conformed time rows.
- `etl/01_raw_to_staging.sql`: Phase 1 raw -> staging normalization.
- `etl/03_publish_phase1.sql`: Phase 1 staging -> core fact publication plus publish-guard enforcement.
- `scripts/load_phase1_sample.sh`: default runnable sample loader for the Phase 1 raw/staging/core/audit/mart contract.
- `scripts/load_wdi_live.sh`: first narrow live WDI loader that now defaults to the canonical seeded country basket from `ref.country`, fetches JSON snapshots, records them in `raw.source_snapshot`, and publishes through the existing Phase 1 contract.
- `scripts/load_wdi_labor_live.sh`: tiny real WDI labor fallback loader for `DEU` + `CHN` across `2019-2023`, with snapshot evidence, per-run manifest output, and metadata-driven labor-series lineage used both to prove labor source conflicts against ILOSTAT and to cover the repaired `CHN` labor-force-participation fallback path.
- `scripts/load_ifs_live.sh`: first narrow live IFS loader that now defaults to the canonical seeded country basket from `ref.country`, fetches JSON snapshots plus IMF country metadata, records them in `raw.source_snapshot`, and publishes through the existing Phase 1 contract, including the tiny real GDP-plus-inflation overlap proof used for source-priority diagnostics.
- `scripts/load_weo_live.sh`: first live WEO loader that defaults to the canonical seeded country basket from `ref.country` across the widened 2019-2023 proof window, fetches IMF country metadata plus the current-account balance and current-account-percent-of-GDP DataMapper snapshots, records them in `raw.source_snapshot`, and publishes through the same warehouse contract.
- `scripts/load_ilostat_live.sh`: first live ILOSTAT loader for annual total unemployment rate, employment-to-population ratio, and labour force participation rate ages 15+, now defaulting to the canonical seeded country basket from `ref.country` across the widened 2019-2023 proof window, recorded as snapshot-backed evidence and published through the same warehouse contract.
- `scripts/load_un_comtrade_live.sh`: first live UN Comtrade loader for annual total exports/imports against World partner totals, now using targeted reporter-code requests derived from the canonical seeded country basket across the widened 2019-2023 proof window, recorded as snapshot-backed evidence and published through the same warehouse contract.
- `scripts/check_pipeline_alerts.sh`: exits non-zero when `mart.dataset_pipeline_alerts` contains any active alerts, for CI/cron health checks.
- `queries/test_phase2_starter_marts.sql`: regression checks for the first proper labor mart, the inflation/trade/external-balance Phase 2 marts, the compact Phase 2 readiness/issues/latest snapshots, the dataset-level coverage trend surface, the country-to-dataset dependency explainer surface, the new ingestion-gap explainer surface that attributes missing rows to fetch scope vs normalization vs QA vs publication, the dataset-level ingestion-gap rollup that collapses those breaks by expected source, the per-dataset operator panel that merges freshness plus coverage and active-gap status, the new per-batch dataset-status history mart for deterioration/improvement tracking, and the verbose/deduped conflict diagnostics, with the noisy row dumps now gated behind `PHASE2_VERBOSE=1`.
- `queries/phase2_operator_scan.sql`: compact operational query entrypoint for the ranked Phase 2 dataset operator scan plus the latest and deteriorating batch-history scan.
- `scripts/report_phase2_operator_scan.sh`: compact operational report wrapper for the Phase 2 dataset operator scan plus current pipeline alerts, suitable for cron delivery.
- `scripts/check_phase2_operator_watchdog.sh`: silent-on-healthy watchdog wrapper that emits only when Phase 2 has active failing gaps or pipeline alerts.
- `scripts/test_phase2_monitoring_smoke.sh`: fixture-backed smoke test for the Phase 2 report/watchdog wrappers, including healthy and alert watchdog branches.
- `scripts/fetch_http_to_snapshot.py`: reusable fetch helper for saving HTTP payloads as local evidence files.
- `scripts/fetch_uncomtrade_snapshot.py`: UN Comtrade-specific fetch helper that handles CSRF + POST query semantics and persists raw response snapshots.
- `docs/real-ingestion-operator-guide.md`: practical runbook for live-loader operation, snapshot/manifest locations, reruns, failure triage, and published-result verification.
- `queries/`: SQL scripts for analysis.

## Adding New Data
1. Register the source system, dataset, and series in `ref` before loading it.
2. Create a `raw.source_batch` row for the extract.
3. Land the source-native payload in `raw`.
4. Normalize and validate it in `staging`.
5. Resolve annual observations onto the conformed `core.dim_*` layer, including `core.dim_time`.
6. Publish version/published fact rows through the Phase 1 core fact path.
7. Stamp those published rows through `audit.publication_version` and persist QA/revision/freshness controls in `audit`.
8. Query analyst-facing marts/views from the new `mart` layer on top of the published/audit spine.
9. Enforce the Phase 1 publication contract through the hardening layer (`ddl/09_constraints_indexes.sql` + publish guards).
10. Keep future work aligned to the Phase 1 contract instead of reintroducing a parallel warehouse path.

## Current status vs future goal
- Current status: the warehouse structure, publication logic, QA surfaces, and analyst views are working locally with sample WDI and IFS files, and the first live WDI backbone, WDI labor overlap, IFS, WEO, ILOSTAT, and UN Comtrade loaders now run end to end.
- Not done yet: production-grade source coverage across labor, trade, external balance, and other domains; the live specialist-source slices now cover the seeded canonical country basket through a widened 2019-2023 proof window for ILOSTAT, WEO, and UN Comtrade, and the repo exposes those published results through first-pass Phase 2 starter marts, but they are still deliberately narrow proofs rather than broad production coverage.
- Intended direction: keep onboarding new sources through the metadata registry first, then widen ILOSTAT, WEO, UN Comtrade, and later sources on top of the existing `raw -> staging -> core -> audit -> mart` path without creating a second ingestion architecture.
- Non-goal: querying the live web every time an analyst asks for a number. The intended model is still fetch first, store locally, then query the local warehouse.

## Snapshot storage for real ingestion
- Real ingestion should save fetched payloads under `ingest/snapshots/` as local evidence, not just temporary cache.
- Current placeholder directories now exist for the first real-ingestion slice:
  - `ingest/snapshots/wdi/`
  - `ingest/snapshots/ifs/`
  - `ingest/snapshots/weo/`
- Recommended naming pattern:
  - `ingest/snapshots/wdi/<dataset>/<YYYYMMDDTHHMMSSZ>.json`
  - `ingest/snapshots/ifs/<dataset>/<YYYYMMDDTHHMMSSZ>.json`
- The warehouse now links each fetched snapshot to a `raw.source_batch` row through `raw.source_snapshot`, so the raw evidence, fetch metadata, and published facts stay traceable together.

## Real ingestion operator guide
- If you want the practical runbook for live loaders, failure triage, reruns, snapshot locations, and published-result verification, read `docs/real-ingestion-operator-guide.md`.
- That guide is the fastest way to re-orient yourself on sample mode vs API mode and which tables/views to inspect first when a live run misbehaves.

## Maintenance
Default Phase 1 developer checks:
```bash
make init load-sample build-mart test repeat-load-test
```

CI now runs that same end-to-end Phase 1 contract path, including the repeat-load regression check, in `.github/workflows/phase1-contract.yml`.

Default offline real-ingestion proof bundle:
```bash
make test-real-ingestion-offline
```

That one command re-initializes the local warehouse schema, reruns every fixture-backed live contract, and then runs the compact Phase 2 SQL plus monitoring-wrapper regressions.

The legacy compatibility commands and `mart.country_latest_macro` alias have been retired so the repo has one default execution path.
