# Real ingestion operator guide

This guide is for running the live-source loaders without guessing what is sample-only, where evidence files land, or what to inspect when something breaks.

## 1. Core distinction: sample mode vs API mode

Sample mode:
- uses committed local files
- good for proving the warehouse contract itself
- does not fetch from the web

Commands:
```bash
make load-sample
make test
make repeat-load-test
```

Main files:
- `scripts/load_phase1_sample.sh`
- `scripts/load_ifs_sample.sh`
- `raw_files/sample_wb_data.csv`
- `raw_files/sample_ifs_data.csv`

API mode:
- fetches live payloads from external providers
- writes local snapshot evidence under `ingest/snapshots/`
- records that evidence in `raw.source_snapshot`
- then reuses the same warehouse path: `raw -> staging -> core -> audit -> mart`

Main commands:
```bash
make load-wdi-live
make load-wdi-labor-live
make load-ifs-live
make load-weo-live
make load-ilostat-live
make load-un-comtrade-live
```

Main files:
- `scripts/load_wdi_live.sh`
- `scripts/load_wdi_labor_live.sh`
- `scripts/load_ifs_live.sh`
- `scripts/load_weo_live.sh`
- `scripts/load_ilostat_live.sh`
- `scripts/load_un_comtrade_live.sh`

## 2. Where snapshots and manifests go

Each live loader writes evidence files under `ingest/snapshots/`.

Current default roots:
- WDI backbone + WDI labor: `ingest/snapshots/wdi/WDI/`
- IFS: `ingest/snapshots/ifs/IFS/`
- WEO: `ingest/snapshots/weo/WEO/`
- ILOSTAT: `ingest/snapshots/ilostat/ILOSTAT/`
- UN Comtrade: `ingest/snapshots/un_comtrade/UN_COMTRADE_ANNUAL/`

Common runtime fields used by the live loaders:
- `RUN_TS`: UTC run timestamp like `20260528T010203Z`
- `BATCH_EXTERNAL_ID`: batch identifier persisted into warehouse lineage
- `SNAPSHOT_ROOT`: directory for evidence files

Typical file pattern:
- payload snapshots: `<SNAPSHOT_ROOT>/<RUN_TS>_...json`
- manifests: `<SNAPSHOT_ROOT>/<RUN_TS>_manifest.json`

Special case:
- `scripts/load_wdi_labor_live.sh` writes `.../<RUN_TS>_wdi_labor_manifest.json`

What matters operationally:
- snapshot JSON is the raw evidence
- manifest JSON is the run summary
- `raw.source_snapshot` is the warehouse index of those files
- `raw.source_batch` is the batch-level lineage anchor

## 3. Safe rerun rules

Safe default:
1. keep the same repo state
2. rerun the same `make load-...-live` command
3. rebuild serving surfaces if needed with `make build-mart`
4. re-run checks

Good verification bundle after loader work:
```bash
make check-alerts
make phase2-operator-report
make test-phase2-offline
```

Why reruns are mostly safe here:
- loaders create new `raw.source_batch` lineage instead of mutating analyst marts directly
- published rows flow through the existing publish path
- contract tests already check for post-run alert conditions
- some loaders write manifests so a run is inspectable after the fact
- IFS/WEO/ILOSTAT/UN Comtrade loaders are designed to clean up incomplete snapshot runs on failure rather than leave half-finished evidence behind

Practical caution:
- a rerun creates a new batch, not a magical overwrite
- if you are debugging exact lineage, capture the new `BATCH_EXTERNAL_ID`
- if you want deterministic file names for a one-off investigation, override `RUN_TS` explicitly

Example:
```bash
RUN_TS=20260528T120000Z make load-ifs-live
```

## 4. What to inspect when a fetch fails

Think in layers.

### Layer A: shell/runtime failure
Questions:
- did the loader script itself error before SQL load?
- did it fail before or after writing snapshots?

Inspect:
- terminal output from the failed `make load-...-live` command
- the relevant script under `scripts/`
- the expected `SNAPSHOT_ROOT` directory

### Layer B: raw evidence exists, but warehouse ingestion failed
Inspect first:
```sql
SELECT source_batch_key, batch_external_id, ingest_status, request_params_json, row_count_reported, fetched_at
FROM raw.source_batch
ORDER BY source_batch_key DESC
LIMIT 20;
```

Then:
```sql
SELECT source_snapshot_key, source_batch_key, file_path, http_status_code, fetched_at
FROM raw.source_snapshot
ORDER BY source_snapshot_key DESC
LIMIT 20;
```

Interpretation:
- no new `raw.source_batch` row -> the loader likely failed before batch registration
- batch row exists but no `raw.source_snapshot` rows -> fetch/manifest stage likely failed early
- snapshots exist with bad HTTP codes -> upstream/API issue or bad request parameters

### Layer C: raw landed, but normalization/publication failed
Inspect:
```sql
SELECT pipeline_run_key, pipeline_stage, run_status, started_at, finished_at, status_message
FROM audit.pipeline_run
ORDER BY pipeline_run_key DESC
LIMIT 20;
```

```sql
SELECT data_quality_event_key, severity, event_code, event_message, created_at
FROM audit.data_quality_event
ORDER BY data_quality_event_key DESC
LIMIT 20;
```

```sql
SELECT dataset_key, freshness_status, last_success_at, last_attempt_at, last_error_at
FROM audit.dataset_freshness
ORDER BY dataset_key;
```

Interpretation:
- `pipeline_run` tells you whether failure happened in normalization/publish territory
- `data_quality_event` tells you whether QA blocked publication
- `dataset_freshness` tells you whether the dataset is now stale or erroring

## 5. What to inspect when published results look wrong

Start with the compact operator surfaces instead of diving straight into raw rows.

Commands:
```bash
make phase2-operator-scan
make phase2-operator-report
make check-alerts
```

Most useful surfaces:
- `mart.vw_phase2_dataset_operator_panel_scan`
- `mart.vw_phase2_dataset_status_history_scan`
- `mart.dataset_pipeline_alerts`
- `mart.vw_dataset_freshness_status`
- `mart.mart_country_phase2_latest`

Why these matter:
- `operator_panel_scan` tells you which dataset currently needs attention
- `status_history_scan` tells you whether the latest batch deteriorated or improved
- `dataset_pipeline_alerts` gives the red-only view
- `vw_dataset_freshness_status` shows high-level fetch/publish recency
- `mart_country_phase2_latest` is the analyst-facing output surface

## 6. How to verify a live run published correctly

Fast path:
```bash
make check-alerts
make phase2-operator-report
```

Stronger path:
```bash
make test-live-contracts-offline
make test-phase2-offline
```

If you just changed one loader, use its narrower contract test when available:
```bash
make test-live-wdi-contract
make test-live-wdi-labor-contract
make test-live-ifs-contract
make test-live-weo-contract
make test-live-ilostat-contract
make test-live-un-comtrade-contract
```

SQL spot checks:
```sql
SELECT dataset_code, freshness_status, latest_publish_status, anomaly_flags
FROM mart.vw_domain_qa_summary_phase2
ORDER BY dataset_code;
```

```sql
SELECT dataset_code, operator_panel_status, latest_publish_status, latest_gap_indicator_codes
FROM mart.vw_phase2_dataset_operator_panel_scan
ORDER BY operator_attention_rank, dataset_code;
```

```sql
SELECT iso_alpha_3, country_name, latest_phase2_observation_year, phase2_indicator_coverage_count
FROM mart.mart_country_phase2_latest
ORDER BY iso_alpha_3
LIMIT 20;
```

What “good” looks like:
- the relevant dataset has a fresh or expected status
- no blocking rows appear in `mart.dataset_pipeline_alerts`
- the latest batch appears in status/history surfaces
- analyst-facing rows exist in `mart.mart_country_phase2_latest`

## 7. Recommended operator workflows

### Routine health check
```bash
make phase2-operator-watchdog
```
- silent means no active Phase 2 failure surfaced by the watchdog

### Human-readable daily check
```bash
make phase2-operator-report
```
- prints dataset summary, ranked operator scan, latest batch rows, and active pipeline alerts

### After changing monitoring wrappers
```bash
make test-phase2-monitoring-offline
```
- proves report/watchdog command wiring without depending on live DB state

### After changing Phase 2 marts or monitoring surfaces
```bash
make test-phase2-offline
```
- runs SQL regression coverage plus monitoring-wrapper smoke coverage together

## 8. Minimal mental model

Use this when you get lost:

`live API -> snapshot JSON -> raw.source_snapshot/raw.source_batch -> staging -> core published facts -> audit -> mart`

If a problem appears:
- no snapshot file -> fetch problem
- snapshot exists but no batch/snapshot row -> loader/SQL registration problem
- batch exists but pipeline failed -> normalization or publish problem
- publish succeeded but marts look wrong -> serving-layer/view problem

## 9. Main files to inspect

- project overview: `README.md`
- live loaders: `scripts/load_wdi_live.sh`, `scripts/load_wdi_labor_live.sh`, `scripts/load_ifs_live.sh`, `scripts/load_weo_live.sh`, `scripts/load_ilostat_live.sh`, `scripts/load_un_comtrade_live.sh`
- monitoring wrappers: `scripts/report_phase2_operator_scan.sh`, `scripts/check_phase2_operator_watchdog.sh`
- compact operator SQL: `queries/phase2_operator_scan.sql`
- Phase 2 regression SQL: `queries/test_phase2_starter_marts.sql`
- mart/view DDL: `ddl/08_marts_and_views.sql`
- audit/raw DDL: `ddl/03_raw_tables.sql`, `ddl/07_audit_tables.sql`

## 10. Default recovery posture

Do not invent a second path.
Stay inside the existing contract:
- fetch/store evidence locally
- register batch + snapshots
- normalize into staging
- publish through core/audit
- inspect mart surfaces last

If the repo is healthy, this path should be enough.