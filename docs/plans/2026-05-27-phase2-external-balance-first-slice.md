# Phase 2 External-Balance First Slice Implementation Plan

> For Hermes: Use subagent-driven-development skill to implement this plan task-by-task.

Goal: land the first real external-balance slice so Phase 2 stops being labor/inflation/trade-only and starts covering the missing external-balance leg defined in the roadmap.

Architecture: keep the existing `ref -> raw -> staging -> core -> audit -> mart` contract. Do not invent a second ingestion architecture. Add one narrow IMF-backed external-balance slice using the same snapshot-backed, metadata-driven publication model already used for WDI, IFS, ILOSTAT, and UN Comtrade.

Tech Stack: PostgreSQL DDL/ETL SQL, bash loaders, Python fixture helpers, IMF DataMapper API, existing contract-test Make targets.

Current state
- `docs/roadmap.md` defines Phase 2 as labor + inflation + trade + external balance.
- The repo already has labor, inflation, and trade proof slices plus Phase 2 marts.
- `seeds/00_ref_metadata_seeds.sql` currently seeds Phase 2 labor/trade indicators but no external-balance indicator.
- `scripts/load_ifs_live.sh` already proves the repo can ingest IMF DataMapper snapshots, but it is wired to `IFS` metadata and `raw.ifs_country_indicator_annual`.
- `queries/test_phase2_starter_marts.sql` validates labor/inflation/trade surfaces but not external balance.

Target state
- The repo registers one narrow external-balance indicator family in metadata.
- The repo ingests that family from IMF DataMapper through the same warehouse contract.
- The repo exposes the published result in Phase 2 marts.
- Offline contract tests cover the new slice deterministically.

Recommended narrow first slice
- Dataset: `WEO` under the existing `IMF` source system.
- Indicator 1: current account balance in U.S. dollars.
- Indicator 2: current account balance as percent of GDP.
- DataMapper codes already verified live:
  - `BCA` = current account balance, U.S. dollars
  - `BCA_NGDPD` = current account balance, percent of GDP

Why this slice
- It fills the explicit roadmap gap without expanding into a giant balance-of-payments model.
- It uses the same IMF DataMapper surface already proven in-repo.
- It gives both an absolute and normalized measure, which makes the mart more useful immediately.

Anti-goals
- Do not redesign the whole IMF ingestion stack into a generic framework in this pass.
- Do not add quarterly/monthly cadence yet.
- Do not add a full balance-of-payments domain model.
- Do not fold WEO rows into `raw.ifs_country_indicator_annual`; keep dataset semantics clean.

Acceptance criteria
- `seeds/00_ref_metadata_seeds.sql` seeds a minimal `WEO` dataset plus the two current-account indicators and their source mappings.
- The repo has a dedicated raw landing surface for WEO annual country-indicator rows.
- A live loader and an offline fixture-backed contract test publish WEO-backed rows into `core.fact_country_indicator_published`.
- `ddl/08_marts_and_views.sql` exposes the new external-balance fields in the existing Phase 2 serving layer.
- `make init build-mart test-live-contracts-offline test-phase2-starter-marts-offline` passes.
- `README.md` describes the new slice accurately.

---

### Task 1: Register the WEO dataset and external-balance indicators

Objective: make the new slice metadata-driven before touching loader logic.

Files:
- Modify: `seeds/00_ref_metadata_seeds.sql`
- Verify against: `docs/roadmap.md`, `docs/source_registry.md`

Step 1: seed a new IMF dataset row.
- Add `WEO` under the existing `IMF` source system in the dataset seed block.
- Reuse the same IMF DataMapper base endpoint pattern already used for `IFS`.
- Keep the dataset description honest: narrow external-balance proof first, not broad WEO onboarding.

Step 2: seed the source-series rows.
Add:
- `('WEO', 'CURRENT_ACCOUNT_BALANCE_USD', ...)`
- `('WEO', 'CURRENT_ACCOUNT_BALANCE_PCT_GDP', ...)`

Step 3: seed the DataMapper aliases.
Map:
- `CURRENT_ACCOUNT_BALANCE_USD -> BCA`
- `CURRENT_ACCOUNT_BALANCE_PCT_GDP -> BCA_NGDPD`
using `alias_type = 'imf_datamapper_indicator'`.

Step 4: seed the business indicators.
Add two indicators such as:
- `CURRENT_ACCOUNT_BALANCE_CURR_USD`
- `CURRENT_ACCOUNT_BALANCE_PCT_GDP`
Use annual frequency and mark them Phase 2, not Phase 1.

Step 5: seed indicator-to-series mappings and priority rows.
- Map both business indicators to `WEO` source series.
- Add `ref.indicator_source_priority` rows making `WEO` rank 1 for those indicators.

Step 6: verify the seed file compiles conceptually.
Run:
`make init`
Expected: seed load succeeds with no duplicate-key or missing-foreign-key errors.

Step 7: commit.
`git add seeds/00_ref_metadata_seeds.sql`
`git commit -m "feat: seed weo external-balance metadata"`

### Task 2: Add a dedicated raw landing table for WEO annual rows

Objective: preserve dataset semantics instead of shoving WEO into the IFS raw table.

Files:
- Modify: `ddl/03_raw_tables.sql`

Step 1: create `raw.weo_country_indicator_annual`.
Use the same essential columns as `raw.ifs_country_indicator_annual`:
- `source_batch_key`
- `country_code_raw`
- `country_name_raw`
- `indicator_code_raw`
- `indicator_name_raw`
- `year_raw`
- `value_raw`
- `obs_status_raw`
- `decimal_raw`
- `source_payload_json`

Step 2: add the same index posture.
Create:
- batch index
- lookup index on `(country_code_raw, indicator_code_raw, year_raw)`
- uniqueness constraint matching the existing annual-source raw-table pattern

Step 3: verify.
Run:
`make init`
Expected: DDL succeeds and the new raw table exists.

Step 4: commit.
`git add ddl/03_raw_tables.sql`
`git commit -m "feat: add weo raw annual landing table"`

### Task 3: Extend normalization so WEO rows can publish through the existing contract

Objective: let WEO rows flow into staging/core/audit/mart without building a parallel ETL path.

Files:
- Modify: `etl/01_raw_to_staging.sql`

Step 1: inspect the current annual normalization union.
The file already unions annual rows from multiple dataset-specific raw tables into the normalized staging surface.

Step 2: add the WEO branch.
- Union `raw.weo_country_indicator_annual` into the same normalized annual path used by `raw.ifs_country_indicator_annual`.
- Keep the shape identical so `etl.publish_phase1_country_indicator_facts(...)` can remain unchanged.

Step 3: verify.
Run:
`make init`
Expected: ETL DDL reload succeeds with no column-shape mismatch.

Step 4: commit.
`git add etl/01_raw_to_staging.sql`
`git commit -m "feat: normalize weo annual observations"`

### Task 4: Add a narrow WEO live loader

Objective: fetch reproducible WEO snapshots and land them in the new raw table.

Files:
- Create: `scripts/load_weo_live.sh`
- Modify: `Makefile`

Step 1: start from `scripts/load_ifs_live.sh`.
Copy the proven structure, but do not over-generalize yet.

Step 2: change the WEO-specific defaults.
Use defaults like:
- `WEO_DATASET_CODE="WEO"`
- a WEO snapshot root such as `ingest/snapshots/weo/WEO`
- a batch prefix such as `weo_live_`
- years aligned to the existing narrow proof window unless the metadata suggests otherwise

Step 3: resolve requested series from metadata.
Like the IFS loader, query active `ref.indicator_source_series_map` rows for the dataset and collect `imf_datamapper_indicator` aliases.

Step 4: fetch the verified DataMapper indicators.
The requested API indicators should resolve to:
- `BCA`
- `BCA_NGDPD`
plus the standard IMF country metadata snapshot.

Step 5: write into `raw.weo_country_indicator_annual`.
Do not insert into `raw.ifs_country_indicator_annual`.

Step 6: publish through the existing path.
After the raw insert, call:
`CALL etl.publish_phase1_country_indicator_facts(:source_batch_key);`

Step 7: add a Make target.
Add:
`load-weo-live`

Step 8: verify.
Run:
`make init load-weo-live build-mart`
Expected: a `WEO` batch is created and at least some rows publish.

Step 9: commit.
`git add scripts/load_weo_live.sh Makefile`
`git commit -m "feat: add narrow live weo external-balance loader"`

### Task 5: Add deterministic offline fixtures and a WEO contract test

Objective: make the new slice testable without depending on the live IMF API.

Files:
- Create: `scripts/mock_fetch_weo_snapshot.py`
- Create: `scripts/test_live_weo_external_balance_contract.sh`
- Create: `tests/fixtures/live_sources/weo/` fixture files if you decide to move mocks out of runtime snapshot directories
- Modify: `Makefile`

Step 1: create committed fixture payloads.
The fixture set should include:
- country metadata payload
- `BCA` payload
- `BCA_NGDPD` payload

Step 2: implement the mock fetch helper.
Mirror the pattern in `scripts/mock_fetch_ifs_snapshot.py`, but point it at WEO fixtures.

Step 3: write the contract assertions.
The contract test should fail if:
- no `WEO` batch is created
- `request_params_json` lacks `api_indicator_codes` or `source_series_codes`
- `BCA` is missing from the batch request lineage
- `BCA_NGDPD` is missing from the batch request lineage
- no `WEO`-backed current-account rows publish
- pipeline alerts remain for the dataset

Step 4: add Make targets.
Add:
- `test-live-weo-contract`
- include it in `test-live-contracts`
- include the fixture-backed form in `test-live-contracts-offline`

Step 5: verify.
Run:
`make init build-mart test-live-contracts-offline`
Expected: WEO contract passes alongside the existing WDI/IFS/ILOSTAT/UN Comtrade checks.

Step 6: commit.
`git add scripts/mock_fetch_weo_snapshot.py scripts/test_live_weo_external_balance_contract.sh Makefile tests/fixtures/live_sources/weo`
`git commit -m "test: add weo external-balance contract coverage"`

### Task 6: Expose external balance in the Phase 2 serving layer

Objective: make the new slice visible to analysts instead of leaving it buried in published facts.

Files:
- Modify: `ddl/08_marts_and_views.sql`
- Modify: `queries/test_phase2_starter_marts.sql`

Step 1: extend the Phase 2 annual series mart.
Add the two new indicators to the Phase 2 series surface so they appear in:
- `mart.mart_country_phase2_series_annual`
- `mart.mart_country_trade_external_panel_annual`

Step 2: extend the latest combined mart.
Add at least:
- `current_account_balance_curr_usd`
- `current_account_balance_curr_usd_year`
- `current_account_balance_pct_gdp`
- `current_account_balance_pct_gdp_year`
- `external_balance_latest_published_at` or fold into the current latest publication stamp if that is cleaner

Step 3: keep derivation logic modest.
Do not add a huge external-balance diagnostic family yet. This milestone is about serving the first published rows.

Step 4: expand regression checks.
Update `queries/test_phase2_starter_marts.sql` to assert:
- the new indicators appear in the Phase 2 annual series view
- the trade/external panel contains them
- the combined latest mart exposes non-null external-balance fields for at least one country

Step 5: verify.
Run:
`make init build-mart test-live-contracts-offline test-phase2-starter-marts-offline`
Expected: all assertions pass.

Step 6: commit.
`git add ddl/08_marts_and_views.sql queries/test_phase2_starter_marts.sql`
`git commit -m "feat: expose external balance in phase2 marts"`

### Task 7: Update repo docs

Objective: keep the repo description aligned with reality.

Files:
- Modify: `README.md`
- Modify: `docs/source_registry.md`

Step 1: update README quick-start/testing text.
Document:
- `make load-weo-live`
- `make test-live-weo-contract`
- the fact that Phase 2 now includes the first external-balance proof slice

Step 2: update architecture/current-status text.
Replace any wording that implies Phase 2 is only labor/inflation/trade.

Step 3: update source-registry wording.
State explicitly that the first external-balance proof uses `WEO` for current-account fields while broader macro-financial authority posture remains future work.

Step 4: verify docs are factual, not aspirational.

Step 5: commit.
`git add README.md docs/source_registry.md`
`git commit -m "docs: document weo external-balance slice"`

### Task 8: Final verification pass

Objective: prove the repo still works end to end after the new slice lands.

Files:
- No new files; verification only.

Step 1: run the sample-regression baseline.
`make init load-sample build-mart test repeat-load-test`
Expected: existing Phase 1/sample contract still passes.

Step 2: run the expanded offline live-contract suite.
`make init build-mart test-live-contracts-offline test-phase2-starter-marts-offline`
Expected: all live-contract checks, including WEO, pass offline.

Step 3: run the live WEO proof if credentials/network posture permits.
`make init load-weo-live build-mart`
Expected: WEO batch publishes external-balance rows through the normal contract.

Step 4: inspect git status.
`git status --short`
Expected: only intentional tracked changes remain.

Step 5: push and watch CI.
`git push`
`gh run list --limit 5`

Step 6: stop only when CI reflects the new WEO-backed external-balance slice cleanly.
