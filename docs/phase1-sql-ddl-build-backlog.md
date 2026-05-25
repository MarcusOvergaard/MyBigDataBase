# Phase 1 SQL / DDL Build Backlog

## Purpose
This backlog turns the accepted `docs/roadmap.md` Phase 1 macro foundation into a dependency-ordered implementation sequence for repository work.

It is intentionally limited to Phase 1:
- core macro foundation only
- annual country-level grain
- WDI as the active production backbone
- ISO3166-based country normalization
- IMF IFS registered early as metadata for later macro arbitration, not as a required Phase 1 production load

## Why the current repository still keeps this backlog
The repository started from a `dw`-centric prototype, but the Phase 1 contract described here has already been landed and is now the default runnable path.

What still matters is using this backlog as traceable implementation history and as a check against drifting back toward the older layout.

Phase 1 requires:
- dataset- and series-level source metadata
- a published fact plus a version-history fact
- conformed time metadata
- explicit raw batch lineage
- explicit QA / revision / publication audit surfaces
- first published marts and first diagnostic lineage views

## Phase 1 scope boundary

### Must be in Phase 1
- `ref`, `raw`, `staging`, `core`, `audit`, and `mart` surfaces needed for annual macro publication
- metadata for countries, sources, datasets, source series, indicators, units, frequencies, validation rules, and source priority
- append-only batch lineage for WDI annual country indicators
- normalized staging with mapping outcomes and QA states
- published and version-history facts
- revision, QA, and publication audit tables
- first Phase 1 marts and diagnostic views

### Explicitly not required for Phase 1
- quarterly/monthly loads
- trade / labor / inflation specialist production ingestion
- WHO / UIS / Comtrade production loads
- country-specific official override workflows
- partitioning unless observed volume requires it
- advanced conflict views for multi-source production arbitration

## Recommended repository work units
Keep the current repo, but replace the monolithic early files with a sequenced DDL set closer to the Phase 1 architecture:

```text
ddl/
  01_schemas.sql
  02_ref_tables.sql
  03_raw_tables.sql
  04_staging_tables.sql
  05_core_dimensions.sql
  06_core_facts.sql
  07_audit_tables.sql
  08_marts_and_views.sql
  09_constraints_indexes.sql
seeds/
  01_ref_countries.sql or csv-driven load
  02_ref_metadata_seeds.sql
etl/
  01_ingest_wdi_raw.sql
  02_normalize_wdi_to_staging.sql
  03_publish_phase1_macro.sql
```

---

# Dependency-Ordered Backlog

## Wave 0 - Replace the base schema contract first

### B0.1 - Update schema bootstrap
**Implementation unit**
- `ddl/01_schemas.sql`

**Target objects**
- `create schema if not exists ref`
- `create schema if not exists raw`
- `create schema if not exists staging`
- `create schema if not exists core`
- `create schema if not exists audit`
- `create schema if not exists mart`

**Purpose**
Create the layer contract required by the roadmap. The current `dw`-centric layout is too coarse for lineage and publication controls.

**Depends on**
- none

**Acceptance criteria**
- all six schemas exist
- `dw` is no longer the target for new Phase 1 objects
- schema comments explain role boundaries

---

## Wave 1 - Build required metadata / reference tables

### B1.1 - Create `ref.country`
**Implementation unit**
- `ddl/02_ref_tables.sql`
- `seeds/01_ref_countries.sql` or CSV load

**Target object**
- `ref.country`

**Purpose**
Canonical country registry for sovereign-country analytics grain.

**Suggested minimum columns**
- `country_key`
- `iso_alpha2`
- `iso_alpha3`
- `iso_numeric`
- `country_name`
- `region_name`
- `income_group`
- `is_aggregate`
- `is_active`
- `valid_from`
- `valid_to`

**Depends on**
- B0.1

**Acceptance criteria**
- one canonical row per supported country
- aggregate pseudo-countries are excluded or explicitly flagged
- `iso_alpha3` is unique

### B1.2 - Create `ref.source_system`
**Target object**
- `ref.source_system`

**Purpose**
Provider-level identity (`World Bank`, `IMF`, `ISO3166`).

**Suggested minimum columns**
- `source_system_key`
- `source_code`
- `source_name`
- `publisher_type`
- `base_url`
- `access_method`
- `license_notes`
- `is_active`

**Depends on**
- B0.1

**Acceptance criteria**
- seeded at minimum with `WDI_BACKBONE_PROVIDER`, `IMF`, `ISO3166` or equivalent provider codes
- provider identity is separate from dataset identity

### B1.3 - Create `ref.source_dataset`
**Target object**
- `ref.source_dataset`

**Purpose**
Dataset/product-level identity required by the roadmap (`WDI`, `IFS`).

**Suggested minimum columns**
- `source_dataset_key`
- `source_system_key`
- `dataset_code`
- `dataset_name`
- `default_frequency_code`
- `default_grain`
- `release_cadence`
- `is_active`

**Depends on**
- B1.2

**Acceptance criteria**
- `WDI` exists as an active dataset row
- `IFS` exists as a registered but not-yet-loaded dataset row
- unique constraint on `(source_system_key, dataset_code)`

### B1.4 - Create `ref.source_series`
**Target object**
- `ref.source_series`

**Purpose**
Source-native series registry to avoid hiding WDI series codes inside ETL logic.

**Suggested minimum columns**
- `source_series_key`
- `source_dataset_key`
- `series_code`
- `series_name`
- `source_unit_text`
- `source_frequency_code`
- `coverage_notes`
- `is_active`

**Depends on**
- B1.3

**Acceptance criteria**
- Phase 1 WDI series are seeded for GDP, GDP per capita, and population
- optional adjacent indicators added only if intentionally kept in Phase 1
- unique constraint on `(source_dataset_key, series_code)`

### B1.5 - Create `ref.unit`
**Target object**
- `ref.unit`

**Purpose**
Controlled reporting units for published indicators.

**Depends on**
- B0.1

**Acceptance criteria**
- units exist for at least `current_usd`, `persons`, `current_usd_per_person`, and any intentionally retained Phase 1 adjacent metrics

### B1.6 - Create `ref.frequency`
**Target object**
- `ref.frequency`

**Purpose**
Controlled frequency vocabulary.

**Depends on**
- B0.1

**Acceptance criteria**
- at minimum includes `A` / annual
- can register `Q` and `M` now without loading them

### B1.7 - Create `ref.indicator`
**Target object**
- `ref.indicator`

**Purpose**
Business indicator registry separate from source-native codes.

**Suggested minimum Phase 1 indicators**
- `GDP_CURR_USD`
- `GDP_PC_CURR_USD`
- `POP_TOTAL`

**Optional only if intentionally kept inside Phase 1 foundation**
- `GDP_REAL_GROWTH_PCT`
- `CPI_INFLATION_ANNUAL_PCT`
- `UNEMPLOYMENT_TOTAL_PCT`
- `LIFE_EXPECTANCY_TOTAL_YRS`

**Depends on**
- B1.5
- B1.6

**Acceptance criteria**
- one source-neutral row per analyst-facing indicator
- Phase 1 indicators flagged explicitly
- no direct reuse of upstream WDI codes as business primary keys unless also mapped separately

### B1.8 - Create `ref.validation_rule`
**Target object**
- `ref.validation_rule`

**Purpose**
Catalog of publication-gate rules required by the roadmap.

**Suggested minimum columns**
- `validation_rule_key`
- `rule_code`
- `rule_name`
- `rule_category`
- `severity`
- `target_layer`
- `rule_description`
- `blocks_publication`
- `is_active`

**Depends on**
- B0.1

**Acceptance criteria**
- seeded for structural, referential, semantic, and temporal rule families
- severity values support `error`, `warning`, `info`

### B1.9 - Create `ref.indicator_source_priority`
**Target object**
- `ref.indicator_source_priority`

**Purpose**
Metadata-driven source selection contract for published facts.

**Suggested minimum columns**
- `indicator_source_priority_key`
- `indicator_key`
- `source_dataset_key`
- `country_key` nullable
- `priority_rank`
- `valid_from_year`
- `valid_to_year`
- `effective_from`
- `effective_to`
- `release_window_code`
- `selection_rationale`
- `is_override`

**Depends on**
- B1.1
- B1.3
- B1.7

**Acceptance criteria**
- every Phase 1 indicator has at least one active rule
- WDI defaults exist for the active production indicators
- no overlapping active rules for the same indicator/country/year scope at the same rank

---

## Wave 2 - Build conformed core dimensions

### B2.1 - Create `core.dim_country`
**Implementation unit**
- `ddl/05_core_dimensions.sql`

**Target object**
- `core.dim_country`

**Purpose**
Analyst-facing conformed country dimension sourced from `ref.country`.

**Depends on**
- B1.1

**Acceptance criteria**
- `country_key` is stable and aligned to `ref.country`
- only supported Phase 1 country rows publish

### B2.2 - Create `core.dim_indicator`
**Target object**
- `core.dim_indicator`

**Purpose**
Analyst-facing indicator dimension for business definitions.

**Depends on**
- B1.7

**Acceptance criteria**
- dimension rows resolve cleanly from `ref.indicator`
- includes unit and frequency metadata needed by marts/views

### B2.3 - Create `core.dim_source`
**Target object**
- `core.dim_source`

**Purpose**
Analyst-facing source/provider dimension.

**Depends on**
- B1.2

**Acceptance criteria**
- separate from dataset dimension
- stable source/provider attributes available for lineage joins

### B2.4 - Create `core.dim_dataset`
**Target object**
- `core.dim_dataset`

**Purpose**
Dataset-level dimension required by roadmap lineage and arbitration guidance.

**Depends on**
- B1.3
- B2.3

**Acceptance criteria**
- `WDI` and `IFS` resolve as dimension rows
- dataset-level lineage joins are possible without parsing codes out of fact rows

### B2.5 - Create `core.dim_time`
**Target object**
- `core.dim_time`

**Purpose**
Conformed time model that separates observation period from release/publication timestamps.

**Suggested minimum columns**
- `time_key`
- `period_type`
- `calendar_year`
- `period_start_date`
- `period_end_date`
- `quarter_number` nullable
- `month_number` nullable

**Depends on**
- B0.1

**Acceptance criteria**
- annual rows exist for the supported Phase 1 year range
- annual grain does not require a fake daily `date_key`

---

## Wave 3 - Build raw ingestion surfaces

### B3.1 - Create `raw.source_batch`
**Implementation unit**
- `ddl/03_raw_tables.sql`

**Target object**
- `raw.source_batch`

**Purpose**
Append-only lineage for each extract run.

**Suggested minimum columns**
- `source_batch_key`
- `source_dataset_key`
- `batch_external_id`
- `request_uri`
- `request_params_json`
- `fetched_at`
- `source_released_at`
- `checksum_sha256`
- `ingest_status`
- `row_count_reported`

**Depends on**
- B1.3

**Acceptance criteria**
- every raw observation row can link to a batch
- repeated pulls create new batch rows rather than overwriting

### B3.2 - Create `raw.source_file`
**Target object**
- `raw.source_file`

**Purpose**
Manifest for raw files or payload artifacts.

**Depends on**
- B3.1

**Acceptance criteria**
- file name, path, checksum, and byte size are recorded when file-based loads are used

### B3.3 - Replace current raw table with dataset-specific Phase 1 raw observation table
**Target object**
- `raw.wdi_country_indicator_annual`

**Purpose**
Source-native annual observations with dataset lineage.

**Suggested minimum columns**
- `raw_row_key`
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
- `loaded_at`

**Depends on**
- B3.1

**Acceptance criteria**
- preserves raw text values and raw source identifiers
- no pre-normalization coercion required to land data

---

## Wave 4 - Build normalized staging surfaces

### B4.1 - Create `staging.country_observation_annual`
**Implementation unit**
- `ddl/04_staging_tables.sql`

**Target object**
- `staging.country_observation_annual`

**Purpose**
Normalized country-indicator-year rows before publication.

**Suggested minimum columns**
- `staging_row_key`
- `source_batch_key`
- `country_key` nullable
- `indicator_key` nullable
- `source_series_key` nullable
- `time_key`
- `observation_year`
- `observation_value`
- `unit_key`
- `frequency_code`
- `mapping_status`
- `missingness_status`
- `is_parse_error`
- `quality_flags`
- `normalized_at`

**Depends on**
- B1.1 through B1.9
- B2.5
- B3.3

**Acceptance criteria**
- country and indicator mapping outcomes are explicit
- missing-at-source and parse-failure states are distinguishable
- stage can hold unmapped rows for QA review

### B4.2 - Create `staging.country_series_candidate`
**Target object**
- `staging.country_series_candidate`

**Purpose**
Stores ranked candidate rows after applying source-priority and recency logic.

**Depends on**
- B4.1
- B1.9

**Acceptance criteria**
- multiple candidates can be ranked for the same country/indicator/year
- ranking reason is stored, not inferred later

### B4.3 - Create `staging.qa_event`
**Target object**
- `staging.qa_event`

**Purpose**
Pre-publication QA findings at row level.

**Depends on**
- B4.1
- B1.8

**Acceptance criteria**
- one QA event can tie to a row, rule, severity, and detail payload
- publication logic can filter blocking vs non-blocking issues

---

## Wave 5 - Build published/version facts

### B5.1 - Create `core.fact_country_indicator_version`
**Implementation unit**
- `ddl/06_core_facts.sql`

**Target object**
- `core.fact_country_indicator_version`

**Purpose**
Full source-batch history for every Phase 1 observation version.

**Suggested minimum columns**
- `observation_version_key`
- `country_key`
- `indicator_key`
- `time_key`
- `source_system_key`
- `source_dataset_key`
- `source_series_key`
- `source_batch_key`
- `observation_value`
- `status_code`
- `is_latest_source_version`
- `first_seen_at`
- `superseded_at`
- `source_released_at`

**Depends on**
- B2.1 through B2.5
- B4.1

**Acceptance criteria**
- repeated pulls of the same source/year can coexist as distinct versions
- prior source versions are preserved after revision
- unique constraint prevents duplicate same-batch duplicates

### B5.2 - Create `core.fact_country_indicator_published`
**Target object**
- `core.fact_country_indicator_published`

**Purpose**
Trusted one-row-per-country/indicator/year Phase 1 published surface.

**Suggested minimum columns**
- `country_key`
- `indicator_key`
- `time_key`
- `observation_year`
- `observation_value`
- `unit_key`
- `source_system_key`
- `source_dataset_key`
- `source_series_key`
- `source_batch_key`
- `selection_method`
- `publication_version_key`
- `published_at`

**Depends on**
- B5.1
- B4.2
- B4.3

**Acceptance criteria**
- primary key or unique key on `(country_key, indicator_key, time_key)`
- only QA-passing candidate rows publish
- each published row explains which source selection method produced it

---

## Wave 6 - Build audit / revision / publication tables

### B6.1 - Create `audit.pipeline_run`
**Implementation unit**
- `ddl/07_audit_tables.sql`

**Target object**
- `audit.pipeline_run`

**Purpose**
Execution log for ingest, normalize, validate, and publish stages.

**Depends on**
- B0.1

**Acceptance criteria**
- each pipeline stage can log start/end/status and row counts

### B6.2 - Create `audit.data_quality_event`
**Target object**
- `audit.data_quality_event`

**Purpose**
Persistent QA log required by roadmap DQ outputs.

**Depends on**
- B6.1
- B1.8
- B4.3

**Acceptance criteria**
- blocking and warning events are queryable by run, rule, table, and indicator

### B6.3 - Create `audit.revision_event`
**Target object**
- `audit.revision_event`

**Purpose**
Explicit record of changed historical values across source batches.

**Depends on**
- B5.1
- B6.1

**Acceptance criteria**
- stores previous vs new values and batch references
- supports `vw_macro_revision_history`

### B6.4 - Create `audit.publication_version`
**Target object**
- `audit.publication_version`

**Purpose**
Warehouse publication contract required by roadmap versioning guidance.

**Suggested minimum columns**
- `publication_version_key`
- `publication_version_code`
- `published_at`
- `code_version_ref`
- `metadata_rule_version_ref`
- `publication_notes`

**Depends on**
- B6.1

**Acceptance criteria**
- each publish run can stamp rows in `core.fact_country_indicator_published`
- publication metadata supports reproducibility

### B6.5 - Create `audit.dataset_freshness`
**Target object**
- `audit.dataset_freshness`

**Purpose**
Supports required freshness diagnostic view.

**Depends on**
- B3.1
- B6.1

**Acceptance criteria**
- latest successful fetch, latest published period, freshness status, and failure flag are queryable per dataset

---

## Wave 7 - Build first analyst-facing Phase 1 marts and views

### B7.1 - Create `mart.mart_country_macro_latest`
**Implementation unit**
- `ddl/08_marts_and_views.sql`

**Purpose**
Wide latest snapshot per country for Phase 1 indicators.

**Depends on**
- B5.2

**Acceptance criteria**
- sourced only from `core.fact_country_indicator_published`
- one row per country
- includes latest published year per indicator set

### B7.2 - Create `mart.mart_country_macro_series_annual`
**Purpose**
Long-format annual macro panel for longitudinal analysis.

**Depends on**
- B5.2
- B2.1
- B2.2
- B2.5

**Acceptance criteria**
- one row per country/indicator/year
- includes source/dataset keys or join-ready references

### B7.3 - Create `mart.mart_country_profile_foundation`
**Purpose**
Country profile view with core foundation metrics for quick comparison.

**Depends on**
- B7.1

**Acceptance criteria**
- wide presentation surface for the intentionally retained Phase 1 indicator set

### B7.4 - Create `mart.vw_macro_published_with_lineage`
**Purpose**
Published values plus provider, dataset, series, batch, and selection metadata.

**Depends on**
- B5.2
- B2.3
- B2.4
- B3.1

**Acceptance criteria**
- each published row is traceable without reading ETL code

### B7.5 - Create `mart.vw_macro_revision_history`
**Purpose**
Human-readable revision history by country/indicator/year.

**Depends on**
- B6.3
- B5.1

**Acceptance criteria**
- shows old value, new value, revision timestamps, and batch lineage

### B7.6 - Create `mart.vw_macro_coverage_gaps`
**Purpose**
Coverage-gap diagnostics split into absent-at-source, parse failure, and QA-blocked.

**Depends on**
- B4.1
- B4.3

**Acceptance criteria**
- gap reasons are explicit and queryable by country/indicator/year

### B7.7 - Create `mart.vw_dataset_freshness_status`
**Purpose**
Freshness and last-load status for Phase 1 datasets.

**Depends on**
- B6.5

**Acceptance criteria**
- dataset freshness is visible without reading pipeline logs

---

## Wave 8 - Add constraints, indexes, and publish guards

### B8.1 - Add critical uniqueness / FK constraints
**Implementation unit**
- `ddl/09_constraints_indexes.sql`

**Required constraints**
- unique `ref.country.iso_alpha3`
- unique `ref.source_dataset (source_system_key, dataset_code)`
- unique `ref.source_series (source_dataset_key, series_code)`
- unique active business key for `core.fact_country_indicator_published`
- unique version key scope for `core.fact_country_indicator_version`

**Depends on**
- prior waves

**Acceptance criteria**
- duplicate published business keys cannot be inserted
- required lineage FKs resolve cleanly

### B8.2 - Add Phase 1 performance indexes
**Recommended indexes**
- published fact on `(indicator_key, country_key, time_key)`
- version fact on `(indicator_key, country_key, time_key, source_batch_key desc)`
- staging on `(source_batch_key, indicator_key, country_key, observation_year)`
- revision events on `(indicator_key, country_key, observation_year)`

**Depends on**
- prior waves

**Acceptance criteria**
- marts/views can resolve latest and historical rows without full scans at Phase 1 scale

### B8.3 - Add publish-gate SQL assertions
**Purpose**
Enforce Phase 1 publication contract before published fact refresh.

**Suggested assertions**
- no duplicate published business keys
- no published row without source dataset/series lineage
- all published rows tie to an active validation rule set
- all Phase 1 indicators have active source-priority rules

**Depends on**
- prior waves

**Acceptance criteria**
- publish procedure fails fast when contract is violated

---

# Must-Build-First vs Later-Within-Phase-1

## Must-build-first
These are mandatory before Phase 1 can honestly claim roadmap alignment:
- B0.1
- B1.1 through B1.9
- B2.1 through B2.5
- B3.1 and B3.3
- B4.1 through B4.3
- B5.1 and B5.2
- B6.1 through B6.4
- B7.1, B7.4, B7.5, B7.6
- B8.1 and B8.3

## Later but still valid inside Phase 1 if capacity allows
These improve operability but can follow the first publishable spine:
- B3.2 `raw.source_file` when loads are API-native rather than file-heavy
- B6.5 `audit.dataset_freshness`
- B7.2 `mart_country_macro_series_annual` if `fact_country_indicator_published` already serves long-format users initially
- B7.3 `mart_country_profile_foundation`
- B7.7 `vw_dataset_freshness_status`
- B8.2 additional performance indexes beyond the minimum uniqueness/index set

# Traceability to the accepted roadmap

| Roadmap Phase 1 requirement | Backlog coverage |
|---|---|
| conformed source / indicator / time metadata model | B1.2-B1.9, B2.2-B2.5 |
| append-only raw ingestion with batch lineage | B3.1-B3.3 |
| normalized staging with mapping outcomes | B4.1-B4.3 |
| published and version-history facts | B5.1-B5.2 |
| publication gates and revision logging | B6.1-B6.4, B8.3 |
| first macro marts and lineage/revision views | B7.1-B7.7 |

# Status of this backlog
The implementation sequence above is no longer a proposed migration plan. The repo now runs through that Phase 1 contract successfully via `make init load-sample build-mart test repeat-load-test`.

# Immediate next repository sprint
1. Remove or quarantine stale documentation that still reads like the `dw` migration is unfinished.
2. Expand the minimal metadata seeds and source registry so more than the current Wave 1 sample scope is represented cleanly.
3. Deepen release/revision handling only where specialist-source onboarding actually needs it, instead of reopening parallel architecture work.
4. Start the next real ingestion slice on top of the current contract rather than adding more scaffolding around the sample path.

# Done signal for this backlog
This backlog is complete when a repository engineer can start Phase 1 implementation directly from these work units without re-planning object order, naming, or minimum acceptance checks.