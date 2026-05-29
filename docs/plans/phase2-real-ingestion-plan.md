# Phase 2 Real Ingestion Implementation Plan

> For Hermes: use subagent-driven-development skill to implement this plan task-by-task.

Goal: replace the current local-sample loading path with the first real API/bulk ingestion path while preserving the existing `raw -> staging -> core -> audit -> mart` warehouse contract.

Architecture: keep the current warehouse layers and add a thin ingestion edge in front of `raw`. Real loaders should fetch external data, write a reproducible local snapshot, register a `raw.source_batch`, load source-native rows into dataset-specific `raw` tables, normalize into `staging`, and publish through the existing Phase 1 procedures. Do not build a second pipeline.

Tech stack: Bash, PostgreSQL, `psql`, Python 3 standard library plus `requests` if needed, Make, local flat-file snapshots under the repo.

---

## Scope of this plan

This plan is for the first real-ingestion slice, not the full final platform.

In scope:
- first real WDI ingestion path
- first real IMF/IFS ingestion path
- reproducible local snapshot storage
- batch metadata and run logging
- failure handling and rerun safety
- validation that real-ingestion output still lands in the same marts/views

Out of scope for this slice:
- all future providers
- orchestration with Airflow/Prefect/etc.
- incremental backfill for every historical indicator
- secret management systems beyond simple env-based config if later needed
- dashboards/UI work

## Key design decisions

1. Querying should stay local.
   - Fetch first.
   - Store locally.
   - Query the warehouse later.
   - Never make analyst queries depend on live web calls.

2. Real ingestion must preserve source-native evidence.
   - Save the downloaded payload or file.
   - Record request URL, params, fetch time, and load status.
   - Make reruns auditable.

3. Start narrow.
   - First real WDI path for the current Phase 1 indicators.
   - First real IMF path only for the current arbitration indicators.
   - Do not generalize early.

4. Keep the current publication logic.
   - `staging.normalize_*`
   - `etl.publish_phase1_country_indicator_facts(...)`
   - existing marts/tests

---

## Task 1: Add explicit directories and naming for real source snapshots

Objective: create a clear place for fetched source files so ingestion becomes reproducible.

Files:
- Create: `ingest/`
- Create: `ingest/snapshots/.gitkeep`
- Create: `docs/plans/phase2-real-ingestion-plan.md` (this file)
- Modify: `README.md`

Steps:
1. Create `ingest/snapshots/` for fetched source files.
2. Add a naming rule in `README.md`, for example:
   - `ingest/snapshots/wdi/<dataset>/<YYYYMMDDTHHMMSSZ>.json`
   - `ingest/snapshots/ifs/<dataset>/<YYYYMMDDTHHMMSSZ>.json`
3. State that raw snapshots are evidence, not just temporary cache.

Verification:
- `search_files(pattern="*", target="files", path="/home/marcusai/MyProjects/MyBigDataBase/ingest")`
- expected: snapshot directories exist

---

## Task 2: Add ingestion configuration metadata to the warehouse

Objective: make runtime fetch behavior explicit instead of hiding it in scripts.

Files:
- Modify: `ddl/02_ref_tables.sql`
- Modify: `seeds/00_ref_metadata_seeds.sql`
- Modify: `README.md`
- Test: `queries/test_queries.sql`

Changes:
1. Extend source/dataset metadata to carry the minimum ingestion contract.
2. Add fields such as:
   - dataset access method (`api`, `bulk_file`, `manual_file`)
   - base endpoint or source URL
   - default file format (`json`, `csv`, `xml`)
   - cadence note
   - auth requirement flag
3. Seed WDI and IFS with current known access posture.

Suggested columns:
- on `ref.source_dataset` or a new side table such as `ref.source_dataset_ingest_config`
   - `access_method`
   - `base_endpoint`
   - `default_format`
   - `requires_auth`
   - `cadence_note`
   - `is_active_for_ingest`

Why this matters:
- avoids hard-coding too much behavior in loader scripts
- lets later sources plug into the same pattern
- makes docs and runtime configuration line up

Verification:
- rerun `make init`
- query the new metadata rows with `psql`
- expected: WDI and IFS ingest metadata present

---

## Task 3: Add a snapshot manifest table

Objective: track the exact downloaded file behind each batch.

Files:
- Modify: `ddl/03_raw_tables.sql`
- Modify: `ddl/07_audit_tables.sql` if you prefer audit ownership instead
- Modify: `scripts/setup_db.sh`
- Test: `queries/test_queries.sql`

Changes:
1. Add a table for fetched source artifacts, for example `raw.source_snapshot`.
2. Minimum fields:
   - `source_snapshot_key`
   - `source_batch_key`
   - `snapshot_path`
   - `content_type`
   - `file_hash`
   - `fetched_at`
   - `http_status_code`
   - `source_url`
3. Link each real batch to one or more local snapshot files.

Verification:
- `make init`
- confirm table exists
- later real-load runs should populate it

---

## Task 4: Add a shared Python fetch helper for external sources

Objective: stop writing brittle ad hoc curl/bash fetch logic.

Files:
- Create: `ingest/fetch_utils.py`
- Create: `ingest/__init__.py`
- Modify: `README.md`

Implementation:
1. Create a small helper module with functions like:
   - `fetch_json(url, params=None, headers=None, timeout=60)`
   - `write_snapshot(provider, dataset_code, payload_text)`
   - `sha256_file(path)`
2. Return structured metadata needed by loaders:
   - local path
   - file hash
   - fetched timestamp
   - status code
   - final URL
3. Keep it minimal. No framework.

Verification:
- `python3 -m py_compile ingest/fetch_utils.py`
- expected: no syntax errors

---

## Task 5: Build the first real WDI loader

Objective: replace the current WDI sample loader with an optional real-fetch path for the same indicators.

Files:
- Create: `scripts/load_wdi_api_sample.py`
- Modify: `scripts/load_phase1_sample.sh`
- Modify: `README.md`
- Test: `queries/test_queries.sql`

Implementation outline:
1. Fetch the current Phase 1 WDI indicators for the existing sample country set.
2. Save the raw API payload under `ingest/snapshots/wdi/...`.
3. Insert a `raw.source_batch` row with:
   - request URL
   - request params
   - fetched timestamp
   - release timestamp if available
   - ingest status transitions
4. Parse the payload into `raw.wdi_country_indicator_annual`.
5. Reuse the existing normalization and publish procedures.

Important constraint:
- keep the current local sample loader available as a fallback
- add a switch such as `LOAD_MODE=sample|api`

Verification:
- `LOAD_MODE=api ./scripts/load_phase1_sample.sh`
- expected: rows land in `raw.wdi_country_indicator_annual`
- expected: downstream publish still succeeds

---

## Task 6: Build the first real IMF/IFS loader

Objective: add a real IMF path for the minimal arbitration indicators already modeled.

Files:
- Create: `scripts/load_ifs_api_sample.py`
- Modify: `scripts/load_ifs_sample.sh`
- Modify: `README.md`
- Test: `queries/test_queries.sql`

Implementation outline:
1. Fetch only the current arbitration slice first.
2. Save the raw response to `ingest/snapshots/ifs/...`.
3. Insert batch + snapshot metadata.
4. Parse into `raw.ifs_country_indicator_annual`.
5. Reuse existing normalization and publish procedures.

Important constraint:
- stay narrow: only current countries/indicators needed to prove arbitration with real external data

Verification:
- `LOAD_MODE=api ./scripts/load_ifs_sample.sh`
- expected: rows land in `raw.ifs_country_indicator_annual`
- expected: arbitration still produces valid published rows

---

## Task 7: Add idempotent batch guards

Objective: make reruns safe so real ingestion does not duplicate raw loads blindly.

Files:
- Modify: `ddl/03_raw_tables.sql`
- Modify: `scripts/load_phase1_sample.sh`
- Modify: `scripts/load_ifs_sample.sh`
- Test: `scripts/test_repeat_load_regression.sh`

Implementation:
1. Decide the uniqueness rule for a source batch, for example:
   - dataset + external request signature + fetched timestamp bucket
   - or dataset + snapshot hash
2. Reject or skip exact duplicate loads.
3. Preserve append-only behavior where appropriate, but avoid accidental duplicate rows for the same fetched artifact.

Verification:
- run the same real loader twice
- expected: either a clean skip or a clean deduplicated load path
- `make repeat-load-test` still passes

---

## Task 8: Add ingestion-failure logging and partial-failure states

Objective: make external-source failures visible and recoverable.

Files:
- Modify: `ddl/07_audit_tables.sql`
- Modify: `scripts/load_phase1_sample.sh`
- Modify: `scripts/load_ifs_sample.sh`
- Modify: `queries/test_queries.sql`

Implementation:
1. On HTTP or parse failure, record:
   - failed status
   - error text or code
   - fetch timestamp
2. Ensure failed loads do not publish partial junk.
3. Make `audit.dataset_freshness` reflect bad fetches clearly.

Verification:
- run loader against an invalid URL in a controlled test mode
- expected: batch marked failed, no publish, error visible

---

## Task 9: Add dedicated make targets for real ingestion

Objective: make the real path obvious and easy to run.

Files:
- Modify: `Makefile`
- Modify: `README.md`

Targets to add:
- `make load-wdi-live`
- `make load-ifs-live`
- keep sample and live entrypoints explicit rather than hiding them behind one overloaded alias

Rule:
- keep `make load-sample` for local canned data
- make the live path explicit, not magical

Verification:
- `make load-wdi-live`
- `make load-ifs-live`
- expected: commands are discoverable and documented

---

## Task 10: Extend validation queries for real-ingestion evidence

Objective: prove that live-fetched rows still satisfy the warehouse contract.

Files:
- Modify: `queries/test_queries.sql`

Add checks for:
- batch exists for each live load
- snapshot manifest row exists
- request URL/request params are populated
- snapshot hash present
- no unpublished latest rows after successful load
- arbitration still works

Verification:
- `make test`
- expected: existing assertions still pass and new ingestion-evidence checks pass

---

## Task 11: Write a small operator guide

Objective: make the first real-ingestion path understandable to future-you.

Files:
- Create: `docs/real-ingestion-operator-guide.md`
- Modify: `README.md`

Guide should explain:
- sample mode vs API mode
- where snapshots are stored
- how to rerun safely
- what tables to inspect when a fetch fails
- how to verify published results

Verification:
- read-through test: a new person should be able to run the live path without guessing

---

## Task 12: Final end-to-end verification

Objective: prove the repo still works after adding real ingestion.

Files:
- no new files required

Run:
- `make init`
- `make load-sample`
- `make test`
- `make repeat-load-test`
- `make load-wdi-live`
- `make load-ifs-live`
- `make build-mart test`

Expected:
- sample path still works
- real path works
- marts still populate
- source selection still works
- reruns are safe
- docs match reality

---

## Recommended implementation order

1. Task 1: snapshot directories
2. Task 2: ingest metadata
3. Task 3: snapshot manifest table
4. Task 4: shared fetch helper
5. Task 5: real WDI loader
6. Task 6: real IMF loader
7. Task 7: idempotent rerun guards
8. Task 8: failure logging
9. Task 9: make targets
10. Task 10: validation checks
11. Task 11: operator guide
12. Task 12: final verification

## Acceptance criteria

This Phase 2 slice is done when:
- the repo can fetch real WDI data into the existing warehouse path
- the repo can fetch the narrow real IMF arbitration slice into the same path
- fetched payloads are stored locally and linked to source batches
- analyst queries still read from local warehouse tables, not live web calls
- reruns do not silently duplicate data
- failures are visible in audit/freshness surfaces
- docs clearly distinguish sample mode from real-ingestion mode

## Anti-goals

Do not:
- rewrite the core warehouse contract
- introduce a second ETL architecture
- make marts depend on live API calls
- overgeneralize to every future provider before WDI and IMF work cleanly
- bury runtime assumptions in undocumented bash glue
