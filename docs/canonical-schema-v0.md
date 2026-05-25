# Canonical Schema v0

## Purpose
This document turns the approved project brief into the first executable schema contract for MyBigDataBase.

It is intentionally **additive to the landed Phase 1 path**, not a competing architecture draft.

## Repo alignment (non-negotiable)
All new implementation work stays on the existing warehouse contract:

`ref -> raw -> staging -> core -> audit -> mart`

This schema package aligns to the currently landed repo surfaces described in:
- `README.md`
- `docs/roadmap.md`
- `docs/source_registry.md`
- `ddl/02_ref_tables.sql` through `ddl/09_constraints_indexes.sql`

## Design goals
1. Keep source authority explicit and reviewable.
2. Preserve both published facts and source-version history.
3. Keep conformed country / indicator / source / dataset / time metadata first-class.
4. Make comparability breaks visible instead of silently stitching series.
5. Make source-selection overrides versioned and reproducible.
6. Stay annual-first for Phase 1 without blocking later quarterly/monthly growth.

## Contract boundary

### Already landed in repo
- `ref.source_system`, `ref.source_dataset`, `ref.source_series`
- `ref.indicator_source_priority`
- `core.dim_source`, `core.dim_dataset`, `core.dim_time`
- `core.fact_country_indicator_version`
- `core.fact_country_indicator_published`
- `audit.publication_version`, `audit.revision_event`, `audit.data_quality_event`

### This v0 schema package adds clarity on top of landed surfaces
- canonical field expectations for metadata and facts
- explicit comparability-break signaling
- explicit override-rule versioning expectations
- starter machine-readable schemas for core fact and authority-rule contracts

## Layer contract

### `ref`
Purpose: metadata and governance.

Required entities:
- `country`
- `unit`
- `frequency`
- `source_system`
- `source_dataset`
- `source_series`
- `indicator`
- `validation_rule`
- `indicator_source_priority`

Rules:
- provider, dataset, and series identity must stay separate
- authority decisions must be data-driven, not hidden in ETL
- overrides must be effective-dated and reviewable

### `raw`
Purpose: append-only source-native landing plus batch lineage.

Required entities:
- `raw.source_batch`
- dataset-specific raw payload tables

Rules:
- raw payload stays source-native
- fetch time and source release time are distinct
- checksum / request metadata retained when available

### `staging`
Purpose: normalized observations before publication.

Rules:
- explicit mapping outcomes
- explicit missingness outcomes
- source-series linkage preserved when known
- no analyst-facing publication from staging

### `core`
Purpose: conformed dimensions plus published/version-history facts.

Rules:
- `core.dim_*` is the conformed join surface
- `fact_country_indicator_version` stores all accepted source-batch observations in the canonical shape
- `fact_country_indicator_published` stores the one trusted published row per country / indicator / time
- source selection method must remain queryable

### `audit`
Purpose: publication, revision, QA, and freshness observability.

Rules:
- publication events, revision events, and QA events are durable records
- warehouse publication version must remain distinct from source release time
- source-selection changes must be distinguishable from source revisions

### `mart`
Purpose: analyst-facing published surfaces and diagnostics.

Rules:
- marts read from published + audit-backed surfaces, never raw or staging directly
- lineage and revision visibility lives in explicit diagnostics, not hidden joins

## Canonical metadata contract

### Source identity
Authority and lineage must be modeled at three levels:
- `source_system` — provider/platform (example: `WB`, `IMF`)
- `source_dataset` — product/feed (example: `WDI`, `IFS`)
- `source_series` — native series or indicator code when available

Why:
- provider-level identity is too coarse for authority decisions
- overrides often apply at dataset or series level
- reproducibility breaks if only provider identity is stored

### Time contract
Phase 1 is annual-first, but the time model must remain extensible.

Required semantics:
- observation period
- source release time
- warehouse publication time
- effective dates for source-priority rules

`core.dim_time` remains the conformed period surface.

## Source authority contract

### Default Phase 1 posture
- `WDI` is the initial annual macro/population backbone
- specialist datasets become authoritative only through explicit metadata rules
- national-official overrides are allowed only through explicit effective-dated rules

### Required authority fields
The governing rule surface must preserve:
- `indicator_key`
- `source_dataset_key`
- optional `country_key`
- `priority_rank`
- valid observation-year window
- effective date window
- release window code when needed
- `selection_rationale`
- `is_override`

### Override-rule versioning requirement
For v0, override rules must be reproducible across publications.

Minimum requirement:
- every published row must be traceable to the rule logic active at publish time
- metadata-rule version reference must be preserved via `audit.publication_version.metadata_rule_version_ref` and/or an equivalent rule snapshot mechanism

## Fact contract

## `core.fact_country_indicator_version`
Purpose: canonical history of accepted source observations.

Required identity:
- country
- indicator
- time
- source system
- source dataset
- optional source series
- source batch
- staging row

Required business fields:
- observation value
- unit
- frequency
- status code
- selection method
- quality status
- source released at
- first seen / superseded timestamps

Required behavior:
- append history; do not overwrite prior versions
- track latest source version status explicitly
- preserve enough linkage to explain source revisions and source-selection changes

### Recommended additive field expectations for the version fact
These fields are not all landed yet, but should be treated as the v0 target contract for Task 1 follow-through:
- `comparability_break_flag` BOOLEAN
- `comparability_break_note` TEXT
- `selection_rule_version_ref` VARCHAR
- `selection_rule_key_snapshot` JSONB or equivalent serialized rule trace

## `core.fact_country_indicator_published`
Purpose: one trusted published row per country / indicator / time.

Required identity:
- primary key on `(country_key, indicator_key, time_key)`

Required lineage:
- linked source system / dataset / optional series
- linked source batch
- linked version fact row
- linked publication version

Required business fields:
- observation value
- unit
- selection method
- published timestamp

### Required published-surface guarantees
- exactly one current published row per country / indicator / time
- every published row points back to one version-history row
- publication output remains reproducible for a given publication version

### Recommended additive field expectations for the published fact
- `comparability_break_flag` BOOLEAN NOT NULL DEFAULT FALSE
- `comparability_break_note` TEXT
- `source_switch_flag` BOOLEAN NOT NULL DEFAULT FALSE
- `selection_rule_version_ref` VARCHAR

## Comparability contract
Comparability breaks are normal and must not be hidden.

Examples:
- methodology changes
- rebasing
- classification changes
- source-authority changes
- country-boundary or aggregate-definition changes

Rules:
- never silently stitch incompatible series
- flag breaks explicitly in canonical facts or adjacent diagnostics
- expose the reason in a reviewable note or diagnostic view

## Revision contract
Three different changes must remain distinguishable:
1. **source revision** — source changed previously released values
2. **source selection change** — authority/override logic selected a different source
3. **warehouse publication change** — warehouse logic or metadata changed the published output

`audit.revision_event` already provides the right backbone and should remain the durable explanation surface.

## Data-quality and publication contract
Publication is allowed only when:
- mapping is complete enough for the target row
- parse outcomes are acceptable
- blocking validation rules have passed
- source selection is reproducible from metadata

Missingness must remain explicit:
- `observed`
- `missing_at_source`
- `parse_failed`
- future expansion may add more granular publication-block reasons in audit surfaces

## Starter machine-readable schema files
This v0 package ships starter schema files for:
- source authority rules
- published fact rows
- version-history fact rows
- package manifest

These are starter validation/contract artifacts, not a replacement for SQL DDL.

## Unresolved questions
1. Should comparability-break fields be stored directly on both core facts, or centralized in an adjacent review/diagnostic surface with foreign keys?
2. Should `selection_rule_version_ref` be stored directly on fact rows, or derived solely through `publication_version.metadata_rule_version_ref` plus rule snapshots?
3. When specialist overrides promote a non-WDI authority for one indicator family, should the published fact preserve both the selected source and the backbone candidate for diagnostic comparison?
4. Do we want a first-class ref table for source-selection policies beyond `ref.indicator_source_priority`, or is the current rule table sufficient for Phase 1?

## Immediate implementation guidance
Task 1 follow-through should:
1. keep the contract aligned to current landed DDL
2. propose additive fields only where they solve explicit comparability/reproducibility gaps
3. avoid introducing a parallel warehouse path
4. ensure machine-readable schemas stay synchronized with SQL changes
