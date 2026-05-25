# Phase 2 Coverage Broadening Implementation Plan

> For Hermes: implement directly in the existing repo without creating a new ingestion path.

Goal: widen the first ILOSTAT and UN Comtrade proof slices so they cover a more useful annual history window, keep the offline contract suite deterministic, and remove the GitHub Actions Node 20 deprecation warning.

Architecture: keep the same metadata-driven `ref -> raw -> staging -> core -> audit -> mart` flow. Broaden coverage by widening default time/period windows and by replacing brittle runtime-snapshot-backed mocks with committed fixture files dedicated to offline contract tests.

Tech stack: bash loaders, Python fixture helpers, PostgreSQL SQL contract tests, GitHub Actions.

Current state
- ILOSTAT loader defaults to 2021-2022.
- UN Comtrade loader defaults to 2021-2022.
- Offline mocks read fixture files from `ingest/snapshots/...`, which is now intentionally ignored for runtime output.
- Workflow still uses `actions/checkout@v4`, which triggers the Node 20 deprecation warning.

Target state
- ILOSTAT default slice covers 2019-2023.
- UN Comtrade default slice covers 2019-2023.
- Offline mocks read committed fixture files under `tests/fixtures/live_sources/...`.
- Contract tests assert the widened request lineage.
- GitHub Actions uses a non-Node-20 checkout action version.

Anti-goals
- Do not add a new provider.
- Do not redesign the schema.
- Do not claim full production trade/labor coverage; this is still a narrow proof slice, just wider in history.

Acceptance criteria
- `make init build-mart test-live-contracts-offline test-phase2-starter-marts-offline` passes locally.
- `make init load-sample build-mart test repeat-load-test` still passes locally.
- README and metadata seed notes describe the widened 2019-2023 proof window accurately.
- GitHub Actions warning about `actions/checkout@v4` disappears after push.
