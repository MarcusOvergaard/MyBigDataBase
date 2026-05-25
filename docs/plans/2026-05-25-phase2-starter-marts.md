# Phase 2 Starter Marts Implementation Plan

> For Hermes: Use subagent-driven-development skill to implement this plan task-by-task.

Goal: turn the already-working narrow ILOSTAT and UN Comtrade proof slices into the first analyst-facing Phase 2 serving surfaces, plus regression checks and repo hygiene that keep them stable.

Architecture: do not add a new ingestion path. Reuse the existing `ref -> raw -> staging -> core -> audit -> mart` contract and expose the already-published labor/trade indicators through new `mart` views. Keep runtime fetch snapshots out of git, and verify the new marts with deterministic offline contract runs.

Tech Stack: PostgreSQL SQL DDL/views, bash/Make, GitHub Actions, existing offline fixture loaders.

Current state:
- Live/offline loaders already publish `UNEMPLOYMENT_RATE_PCT`, `TRADE_EXPORTS_CURR_USD`, and `TRADE_IMPORTS_CURR_USD`.
- Those indicators exist in metadata and publish successfully into `core.fact_country_indicator_published`.
- CI verifies the narrow offline live-contract suite, but there is no dedicated analyst-facing Phase 2 mart layer yet.
- Runtime snapshot files appear as untracked repo noise because there is no `.gitignore`.

Target state:
- The repo has explicit Phase 2 starter marts built from published facts.
- There is a deterministic SQL regression check for those marts after offline contract loads.
- CI exercises that regression check.
- Runtime snapshots stay out of git by default.

What stays unchanged:
- Existing raw/staging/core/audit contract.
- Existing live/offline loader semantics.
- Existing indicator authority choices (`ILOSTAT` for unemployment, `UN Comtrade` for trade).

Anti-goals:
- Do not widen source coverage beyond the already-seeded narrow ILOSTAT/UN Comtrade slices.
- Do not add a new source or dataset in this pass.
- Do not introduce materialized views or a second serving architecture.

Acceptance criteria:
- `ddl/08_marts_and_views.sql` exposes a Phase 2 annual series view and a latest-profile view.
- The latest profile view includes unemployment, exports, imports, and a derived trade-balance field.
- `make init build-mart test-live-contracts-offline test-phase2-starter-marts-offline` passes locally.
- `.github/workflows/phase1-contract.yml` runs the new Phase 2 starter regression after the offline suite.
- `git status` no longer shows runtime snapshot JSON files by default.

---

### Task 1: Ignore runtime snapshot artifacts

Objective: keep ad hoc fetch evidence out of git while preserving the directory structure.

Files:
- Create: `.gitignore`

Step 1: Add ignore rules for runtime snapshot payloads.
- Ignore `ingest/snapshots/**` contents.
- Re-include `.gitkeep` files so directories can stay committed if needed.

Step 2: Add minimal comments explaining why.

Step 3: Verify.
Run:
`git status --short`
Expected: previously untracked snapshot JSON/manifests disappear from status.

Step 4: Commit.
`git add .gitignore`
`git commit -m "chore: ignore runtime ingestion snapshots"`

### Task 2: Add Phase 2 starter analyst-facing marts

Objective: expose the existing labor/trade published facts through explicit serving views.

Files:
- Modify: `ddl/08_marts_and_views.sql`

Step 1: Add a long-format annual serving view for the seeded Phase 2 indicators.
Name: `mart.mart_country_phase2_series_annual`
Indicators:
- `UNEMPLOYMENT_RATE_PCT`
- `TRADE_EXPORTS_CURR_USD`
- `TRADE_IMPORTS_CURR_USD`

Step 2: Add a latest-profile view.
Name: `mart.mart_country_phase2_latest`
Required fields:
- country identity columns
- unemployment latest year/value
- exports latest year/value
- imports latest year/value
- derived `trade_balance_curr_usd`
- derived `trade_balance_direction`
- `latest_published_at`

Step 3: Keep derivations simple.
- Trade balance = exports - imports when both are present.
- Direction = `surplus`, `deficit`, `balanced`, or `unknown`.

Step 4: Verify.
Run:
`make init build-mart test-live-contracts-offline`
Then:
`psql -d country_intel -c "SELECT * FROM mart.mart_country_phase2_latest LIMIT 5;"`
Expected: rows with unemployment/trade fields populated for the seeded country basket.

Step 5: Commit.
`git add ddl/08_marts_and_views.sql`
`git commit -m "feat: add phase2 starter marts"`

### Task 3: Add deterministic SQL regression checks for the new marts

Objective: prove the new marts are populated and internally coherent after offline contract loads.

Files:
- Create: `queries/test_phase2_starter_marts.sql`
- Modify: `Makefile`

Step 1: Create SQL assertions that fail loudly when the marts regress.
Checks should include:
- Phase 2 annual series view contains all three seeded Phase 2 indicators.
- Latest view has at least one row.
- Latest view has non-null unemployment values.
- Latest view has non-null exports/imports values.
- `trade_balance_curr_usd = trade_exports_curr_usd - trade_imports_curr_usd` when both exist.
- `trade_balance_direction` matches the sign of the derived balance.

Step 2: Add a Make target.
Name: `test-phase2-starter-marts-offline`
Command:
`$(PSQL) -f queries/test_phase2_starter_marts.sql`

Step 3: Verify.
Run:
`make init build-mart test-live-contracts-offline test-phase2-starter-marts-offline`
Expected: PASS with no SQL exceptions.

Step 4: Commit.
`git add Makefile queries/test_phase2_starter_marts.sql`
`git commit -m "test: add phase2 starter mart regression checks"`

### Task 4: Add CI coverage for the new regression

Objective: make GitHub catch future breakage automatically.

Files:
- Modify: `.github/workflows/phase1-contract.yml`

Step 1: extend the offline-contract job.
After `test-live-contracts-offline`, run `test-phase2-starter-marts-offline` in the same initialized database.

Step 2: Verify locally by running the same Make command the workflow will run.
Run:
`make init build-mart test-live-contracts-offline test-phase2-starter-marts-offline`
Expected: PASS.

Step 3: Commit.
`git add .github/workflows/phase1-contract.yml`
`git commit -m "ci: verify phase2 starter marts offline"`

### Task 5: Update repo docs to reflect the new serving surface

Objective: stop README drift and make the next contributor aware of the new Phase 2 starter layer.

Files:
- Modify: `README.md`

Step 1: document the new Make target.
- Add `make test-phase2-starter-marts-offline` to the quick-start/testing section.

Step 2: document the new views.
- Mention `mart.mart_country_phase2_series_annual`
- Mention `mart.mart_country_phase2_latest`

Step 3: verify docs mention the real behavior, not aspirations.

Step 4: Commit.
`git add README.md`
`git commit -m "docs: document phase2 starter marts"`

### Task 6: Final verification pass

Objective: prove the full repo state is coherent before stopping.

Files:
- No new files; verification only.

Step 1: Run the full local verification sequence.
`make init load-sample build-mart test repeat-load-test`
`make init build-mart test-live-contracts-offline test-phase2-starter-marts-offline`

Step 2: Inspect git status.
`git status --short`
Expected: only intentional tracked changes remain.

Step 3: Push and watch CI.
`git push`
`gh run list --limit 5`

Step 4: If green, the Phase 2 starter serving layer is complete for this narrow-slice milestone.
