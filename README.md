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

5. **Optional: load the first narrow live IFS slice**:
   ```bash
   make load-ifs-live
   ```
   This fetches a small real IMF DataMapper slice plus country metadata, stores the JSON snapshots under `ingest/snapshots/ifs/IFS/`, writes a per-run manifest there, records the snapshot files in `raw.source_snapshot`, lands the rows in `raw.ifs_country_indicator_annual`, and then reuses the same `raw -> staging -> core -> audit -> mart` pipeline. The live IFS loader now resolves its requested IMF indicator codes from warehouse metadata instead of a shell hardcode, records both API indicator codes and source-series codes in batch lineage, and deletes incomplete run snapshots if a run fails mid-flight.

6. **Optional: clean stale IFS snapshot files**:
   ```bash
   make clean-ifs-stale-snapshots
   ```
   This removes IFS snapshot JSON files under `ingest/snapshots/ifs/IFS/` that are not referenced by any successful per-run manifest.
7. **Run Phase 1 validation queries**:
   ```bash
   make test
   ```
8. **Fail fast if there are active pipeline alerts**:
   ```bash
   make check-alerts
   ```
   This exits non-zero when `mart.dataset_pipeline_alerts` contains any rows, so it is suitable for CI, cron, or a simple health-check wrapper.
9. **Re-run the live WDI backbone contract check**:
   ```bash
   make test-live-wdi-contract
   ```
   This reruns the WDI backbone slice and fails if the latest live WDI batch loses its request lineage fields, drops the expected WDI indicator mappings, fails to normalize all four backbone indicators, or leaves pipeline alerts behind.
10. **Re-run the live IFS inflation contract check**:
   ```bash
   make test-live-ifs-contract
   ```
   This reruns the IFS specialist-source slice and fails if the latest live IFS batch loses its metadata-driven indicator lineage, fails to publish IFS-backed inflation rows, or leaves pipeline alerts behind.
11. **Re-run every live contract check in one shot**:
   ```bash
   make test-live-contracts
   ```
   This runs the WDI, IFS, ILOSTAT, and UN Comtrade live contract checks back to back.
12. **Re-run every live contract check against local fixtures**:
   ```bash
   make test-live-contracts-offline
   ```
   This swaps each live fetcher for a fixture-backed mock helper, so the warehouse contract can be verified without depending on external APIs.
13. **Assert the first Phase 2 labor/trade marts after the offline suite**:
   ```bash
   make test-phase2-starter-marts-offline
   ```
   This verifies that the seeded ILOSTAT unemployment and UN Comtrade exports/imports indicators populate the analyst-facing Phase 2 starter marts correctly, including the derived trade-balance fields.

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
- `ddl/08_marts_and_views.sql`: first Phase 1 marts and diagnostic views on the published/audit spine, including `mart.dataset_pipeline_health` for dataset-level operating health, `mart.dataset_pipeline_alerts` for alert-only monitoring, and the first Phase 2 starter marts for labor/trade indicators.
- `ddl/09_constraints_indexes.sql`: first Wave 8 hardening unit for constraints, indexes, and publish guards
- `ddl/10_canonical_contract_followthrough.sql`: additive canonical-contract enforcement for comparability/source-switch lineage, including `mart.vw_macro_source_selection_lineage` for flattened source-selection diagnostics
- `seeds/01_core_dimension_seeds.sql`: conformed core-dimension sync from `ref`
- `scripts/populate_core_time.sql`: annual `core.dim_time` periods for the Phase 1 year range
- `etl/01_raw_to_staging.sql`: new Phase 1 normalization procedure, including annual `core.dim_time` resolution
- `etl/03_publish_phase1.sql`: Phase 1 publish procedure with publication stamping, revision logging, QA persistence, and freshness updates

### Operational contract
- The runnable warehouse path is now the Phase 1 contract end to end: `raw -> staging -> core -> audit -> mart`.
- `etl` contains the normalization and publication procedures that support that contract.
- The current runnable loader path is sample-based. Real API ingestion is still future work that should plug into this same contract rather than create a separate path.

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
- `scripts/load_ifs_live.sh`: first narrow live IFS loader that now defaults to the canonical seeded country basket from `ref.country`, fetches JSON snapshots plus IMF country metadata, records them in `raw.source_snapshot`, and publishes through the existing Phase 1 contract.
- `scripts/load_ilostat_live.sh`: first narrow live ILOSTAT loader for annual total unemployment rate ages 15+, now defaulting to the canonical seeded country basket from `ref.country`, recorded as snapshot-backed evidence and published through the same warehouse contract.
- `scripts/load_un_comtrade_live.sh`: first narrow live UN Comtrade loader for annual total exports/imports against World partner totals, now using targeted reporter-code requests derived from the canonical seeded country basket, recorded as snapshot-backed evidence and published through the same warehouse contract.
- `scripts/check_pipeline_alerts.sh`: exits non-zero when `mart.dataset_pipeline_alerts` contains any active alerts, for CI/cron health checks.
- `queries/test_phase2_starter_marts.sql`: regression checks for the first labor/trade Phase 2 starter marts built from the seeded ILOSTAT and UN Comtrade slices.
- `scripts/fetch_http_to_snapshot.py`: reusable fetch helper for saving HTTP payloads as local evidence files.
- `scripts/fetch_uncomtrade_snapshot.py`: UN Comtrade-specific fetch helper that handles CSRF + POST query semantics and persists raw response snapshots.
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
- Current status: the warehouse structure, publication logic, QA surfaces, and analyst views are working locally with sample WDI and IFS files, and the first narrow live WDI, IFS, ILOSTAT, and UN Comtrade loaders now run end to end.
- Not done yet: production-grade source coverage across labor, trade, and other domains; the live specialist-source slices now cover the seeded canonical country basket for ILOSTAT and targeted UN Comtrade reporter requests, and the repo now exposes those published results through first-pass Phase 2 starter marts, but they are still deliberately narrow proofs rather than broad production coverage.
- Intended direction: keep onboarding new sources through the metadata registry first, then widen ILOSTAT, UN Comtrade, and later sources on top of the existing `raw -> staging -> core -> audit -> mart` path without creating a second ingestion architecture.
- Non-goal: querying the live web every time an analyst asks for a number. The intended model is still fetch first, store locally, then query the local warehouse.

## Snapshot storage for real ingestion
- Real ingestion should save fetched payloads under `ingest/snapshots/` as local evidence, not just temporary cache.
- Current placeholder directories now exist for the first real-ingestion slice:
  - `ingest/snapshots/wdi/`
  - `ingest/snapshots/ifs/`
- Recommended naming pattern:
  - `ingest/snapshots/wdi/<dataset>/<YYYYMMDDTHHMMSSZ>.json`
  - `ingest/snapshots/ifs/<dataset>/<YYYYMMDDTHHMMSSZ>.json`
- The warehouse should later link each fetched snapshot to a `raw.source_batch` row so the raw evidence, fetch metadata, and published facts stay traceable together.

## Maintenance
Default Phase 1 developer checks:
```bash
make init load-sample build-mart test repeat-load-test
```

CI now runs that same end-to-end Phase 1 contract path, including the repeat-load regression check, in `.github/workflows/phase1-contract.yml`.

The legacy compatibility commands and `mart.country_latest_macro` alias have been retired so the repo has one default execution path.
