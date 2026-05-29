# Phase 2 Marts Usability and Quiet-Test Sprint Plan

> For Hermes: Use subagent-driven-development skill to implement this plan task-by-task.

Goal: make the first proper Phase 2 serving layer easier to inspect and less obnoxious to validate by tightening mart ergonomics and replacing noisy regression output with compact proof-oriented summaries.

Architecture: keep the existing `ref -> raw -> staging -> core -> audit -> mart` contract and do not add a second reporting path. Improve the analyst-facing `mart` surfaces and the SQL regression harness that proves them. Prefer additive views, compact summaries, and deterministic assertions over giant row dumps.

Tech Stack: PostgreSQL DDL/views, SQL regression scripts, Make targets, existing live/offline contract suite.

Current state
- Phase 2 now has working labor, inflation, trade, and external-balance proof slices.
- `ddl/08_marts_and_views.sql` already exposes first-pass Phase 2 marts and conflict diagnostics.
- `queries/test_phase2_starter_marts.sql` passes, but it still prints a lot of sample rows and conflict evidence during successful runs.
- The repo proves correctness, but the operator experience is still closer to debugging output than a clean contract harness.

Target state
- Phase 2 marts expose a smaller number of obvious analyst entry points.
- Phase 2 conflict/QA views have compact summary surfaces for routine inspection.
- `make test-phase2-starter-marts-offline` passes with short, high-signal output on success.
- Detailed evidence remains available for debugging, but it is no longer the default happy-path output.

Anti-goals
- Do not redesign the warehouse architecture.
- Do not broaden source coverage in this sprint.
- Do not delete the detailed forensic views if they still serve audit/debugging use cases.
- Do not weaken assertions just to make the test output shorter.

Acceptance criteria
- `queries/test_phase2_starter_marts.sql` succeeds with materially less printed output on pass.
- The Phase 2 mart layer has at least one compact summary surface for routine conflict/QA inspection.
- `README.md` or another operator-facing doc explains the quiet-vs-detailed inspection path if needed.
- `make init build-mart test-live-contracts-offline test-phase2-starter-marts-offline` still passes.

---

### Task 1: Inventory the noisy success-path output

Objective: identify which result sets in the current regression script are useful evidence versus pure noise.

Files:
- Inspect: `queries/test_phase2_starter_marts.sql`
- Inspect: `Makefile`

Step 1: list every plain `SELECT` that prints rows after the main `DO $$ ... $$` assertion block.

Step 2: classify each printed block as one of:
- required success proof
- useful only for debugging
- redundant with another view

Step 3: write down the keep/remove/compact decision inside the sprint branch notes or commit message draft.

Step 4: verify the current baseline command.
Run: `make test-phase2-starter-marts-offline`
Expected: PASS, but with visibly noisy output.

Step 5: commit.
`git add -A`
`git commit -m "docs: capture phase2 test-noise inventory"`

### Task 2: Add compact Phase 2 summary views where the mart layer still feels too forensic

Objective: expose short analyst/operator summary surfaces without deleting the detailed lineage views.

Files:
- Modify: `ddl/08_marts_and_views.sql`
- Verify against: existing `mart.vw_labor_source_conflict_summary`, `mart.vw_domain_qa_summary_phase2`, and related Phase 2 views

Step 1: inspect whether inflation and GDP conflict summaries already have the same compact treatment labor now has.

Step 2: if missing, add compact summary views patterned after the labor summary surface, for example:
- `mart.vw_inflation_source_conflict_summary`
- `mart.vw_gdp_source_conflict_summary`

Step 3: keep the summary contract narrow:
- conflict family or scope
- country / indicator / year
- selected dataset
- spread / candidate summary text

Step 4: rebuild marts.
Run: `make build-mart`
Expected: DDL reload succeeds.

Step 5: commit.
`git add ddl/08_marts_and_views.sql`
`git commit -m "feat: add compact phase2 conflict summary views"`

### Task 3: Add a compact latest Phase 2 snapshot surface if the current mart is still awkward to scan

Objective: make the combined latest Phase 2 snapshot friendlier for quick country comparison.

Files:
- Modify: `ddl/08_marts_and_views.sql`
- Modify if needed: `queries/test_phase2_starter_marts.sql`

Step 1: inspect `mart.mart_country_macro_plus_external_latest` for usability problems:
- unclear column ordering
- missing publication/freshness signal
- missing obvious grouping of macro vs labor vs trade vs external fields

Step 2: make the smallest useful improvement.
Examples:
- reorder columns into coherent domain blocks
- add a single latest-phase2-publication timestamp if derivable cleanly
- add a thinner companion view if the current table must stay verbose for compatibility

Step 3: rebuild marts.
Run: `make build-mart`
Expected: DDL reload succeeds.

Step 4: add or update assertions in `queries/test_phase2_starter_marts.sql` only if the serving contract changed.

Step 5: commit.
`git add ddl/08_marts_and_views.sql queries/test_phase2_starter_marts.sql`
`git commit -m "feat: improve phase2 latest snapshot usability"`

### Task 4: Replace noisy happy-path row dumps with compact proof queries

Objective: keep regression evidence while making success output short.

Files:
- Modify: `queries/test_phase2_starter_marts.sql`

Step 1: keep the `DO $$ ... $$` block as the hard assertion engine.
Do not move business-critical checks out of the exception-raising block.

Step 2: replace large row-printing selects with compact summaries such as:
- counts by dataset or conflict family
- one small targeted sample per proof family
- aggregated spread/selection summaries instead of long raw row lists

Step 3: preserve at most one deliberately small evidence slice for each important overlap family:
- labor
- inflation
- GDP
- trade/external

Step 4: rerun the regression.
Run: `make test-phase2-starter-marts-offline`
Expected: PASS with substantially shorter output.

Step 5: if necessary, add an opt-in noisy mode later rather than keeping noisy default output.
Possible pattern: gate extra detail behind a psql variable or Make env var.

Step 6: commit.
`git add queries/test_phase2_starter_marts.sql`
`git commit -m "test: quiet phase2 mart regression output"`

### Task 5: Add a quiet-vs-debug operator path

Objective: make it obvious how to get terse success output by default and deeper evidence only when needed.

Files:
- Modify: `Makefile`
- Modify: `README.md`

Step 1: inspect whether the current Make target needs a second debug target or environment switch.
Options:
- keep `test-phase2-starter-marts-offline` quiet by default
- add a debug companion target such as `test-phase2-starter-marts-debug`
- or document a psql variable/env flag for verbose detail

Step 2: document the intended operator workflow in `README.md`.
State plainly:
- default command for normal regression use
- how to inspect detailed Phase 2 conflict evidence when debugging

Step 3: verify the target still works.
Run: `make test-phase2-starter-marts-offline`
Expected: PASS.

Step 4: commit.
`git add Makefile README.md`
`git commit -m "docs: explain quiet and debug phase2 mart checks"`

### Task 6: Final verification pass

Objective: prove the usability cleanup did not damage the working warehouse contract.

Files:
- No new files; verification only.

Step 1: run the Phase 2 offline contract path.
Run: `make init build-mart test-live-contracts-offline test-phase2-starter-marts-offline`
Expected: PASS.

Step 2: run the Phase 1 regression baseline.
Run: `make init load-sample build-mart test repeat-load-test`
Expected: PASS.

Step 3: inspect git status.
Run: `git status --short`
Expected: only intentional changes remain.

Step 4: commit any final cleanup.
`git add -A`
`git commit -m "chore: finish phase2 mart usability sprint"`

Step 5: push and watch CI when the user asks for it.
