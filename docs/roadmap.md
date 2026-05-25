# Country Analytics Warehouse Roadmap

## Purpose
This roadmap turns the current scaffold plus `docs/source_registry.md` into a practical build sequence for MyBigDataBase. It keeps the strong governance and lineage requirements from the earlier drafts, but anchors the rollout on the task's required top-level phases:
- Phase 1: core macro foundation
- Phase 2: labor / inflation / trade / external balance
- Phase 3: demographics / health / education / infrastructure

The intent is implementation guidance, not presentation. The roadmap calls out where the current schema and ETL direction will not scale unless it is corrected early.

## Main Structural Weak Spots to Fix First

### 1. Source identity is too shallow
The current direction still risks collapsing three different things into one source field:
- provider (`World Bank`, `IMF`, `ILO`)
- dataset/product (`WDI`, `IFS`, `ILOSTAT`, `UN Comtrade`)
- source-native series code

Why this matters:
- authority decisions are usually dataset- or series-level, not just provider-level
- conflict handling becomes opaque if only provider identity is stored
- lineage breaks as soon as one provider contributes multiple products

Required correction:
- implement first-class metadata for `source_system`, `source_dataset`, and `source_series`

### 2. One fact table is not enough
A single latest-value fact table will not support reliable revisions, source arbitration, or reproducibility.

Why this matters:
- researchers need a simple published surface
- operators need full source-version history
- late revisions and source swaps must remain explainable

Required correction:
- keep a published fact for the current trusted value
- keep a version-history fact for all source-batch observations

### 3. Time is under-modeled
The design is annual-first, but a hard-coded annual-only model will create rework.

Why this matters:
- sources revise older years on later releases
- publication timing and release timing are separate facts
- later phases may introduce quarterly or monthly data

Required correction:
- add a conformed time dimension now
- store observation period separately from source release date and warehouse publication timestamp
- version source-priority rules by effective date and, if needed, release window

### 4. Marts and serving views need to be explicit
The scaffold is stronger on storage layers than on user-facing analytical surfaces.

Why this matters:
- researchers need stable marts and views, not direct dependence on staging or raw tables
- lineage, QA, and revision details should be available without polluting analyst-facing marts
- domain growth becomes messy without a serving contract

Required correction:
- define analyst-facing marts and diagnostic views per phase
- ensure marts are published-only surfaces and views expose lineage / QA / revision context

### 5. Data-quality policy is still too implicit
Validation is discussed, but the rules are not yet concrete enough for publication decisions.

Why this matters:
- missing-at-source, parse failure, and blocked-by-QA cannot all become the same null
- expanding sources increases comparability risk
- publication needs explicit gates

Required correction:
- define rule categories, severity levels, and publish/block behavior
- require each domain onboarding step to register its validation coverage before production use

### 6. Source conflicts must be metadata-driven
The source registry gives the authority posture, but the runtime arbitration model still has to be made operational.

Why this matters:
- GDP, inflation, unemployment, trade, and population all have overlapping credible sources
- country-specific or time-bounded overrides are inevitable
- silent source switching destroys trust

Required correction:
- manage source precedence in effective-dated metadata tables
- preserve the selection method used for each published row
- expose overrides and rationale in reviewable lineage surfaces

### 7. Revision/versioning rules need to be formalized
Revision handling is acknowledged, but not yet defined as an operating contract.

Why this matters:
- values can change because the source revised them
- values can also change because mappings, precedence, or warehouse logic changed
- users need to distinguish those cases

Required correction:
- track source revisions, metadata-rule revisions, and warehouse publication versions separately
- publish reproducible release metadata for each warehouse publication

## Build Principles That Apply Across All Phases
- Keep `raw`, `staging`, `core`, `audit`, and `ref` as separate layers.
- Keep business indicators separate from source-native series codes.
- Register every production dataset before loading it.
- Publish only from validated published facts, never directly from staging.
- Treat revisions and missing years as normal operating conditions.
- Keep governance/setup work inside each phase instead of treating it as a separate numbered rollout.

## Core Architecture That Should Exist By The End Of Phase 1

### Required metadata and conformed dimensions
- `ref.country`
- `ref.source_system`
- `ref.source_dataset`
- `ref.source_series`
- `ref.indicator`
- `ref.unit`
- `ref.frequency`
- `ref.validation_rule`
- `ref.indicator_source_priority`
- `core.dim_country`
- `core.dim_indicator`
- `core.dim_source`
- `core.dim_dataset`
- `core.dim_time`

### Required facts
- `core.fact_country_indicator_published`
- `core.fact_country_indicator_version`

### Required operational tables
- `raw.source_batch`
- dataset-specific raw observation tables
- normalized staging observation tables
- QA event tables
- publication event and revision event tables

## Phase 1 — Core Macro Foundation

### Scope
Build the first trusted annual country-level warehouse spine around core macro indicators and the minimum platform pieces required to make that spine reliable.

### Domain coverage
Phase 1 should center on:
- GDP
- GDP per capita
- population
- core macro context needed to support those series cleanly

This phase may carry a small number of adjacent foundation indicators only if they are necessary for the initial country panel shape, but it should not try to become the full social-sector or external-sector warehouse.

### Platform work required inside Phase 1
- create the conformed source / indicator / time metadata model
- create append-only raw ingestion with batch lineage
- create normalized staging with explicit mapping outcomes
- create published and version-history fact tables
- define publication gates and revision logging
- create first analyst-facing macro marts and first diagnostic lineage views

### Recommended source posture in Phase 1
- `WDI` as the practical annual backbone for initial broad country coverage
- `ISO3166` for country identity normalization
- `IMF IFS` registered early as the intended arbitration path for macro indicators that later need stronger source discipline

### Phase 1 marts
#### `mart_country_macro_latest`
One row per country with the latest published Phase 1 macro foundation indicators.

#### `mart_country_macro_series_annual`
Long-format annual macro series for longitudinal analysis.

#### `mart_country_profile_foundation`
Wide country profile mart with the first-phase macro foundation fields for quick comparison.

### Phase 1 diagnostic views
#### `vw_macro_published_with_lineage`
Published values plus source system, dataset, series, batch, release date, and selection reason.

#### `vw_macro_revision_history`
Historical changes for each country / indicator / year.

#### `vw_macro_coverage_gaps`
Coverage gaps separated into absent-at-source, parse failure, and QA-blocked states.

#### `vw_dataset_freshness_status`
Latest successful fetch, latest published period, freshness status, and failure flags.

### Phase 1 exit criteria
- published annual macro foundation values are traceable to source batch, dataset, and source series
- a published fact and version-history fact both exist
- at least one macro mart and one lineage/revision view are available from published data
- source precedence is stored in metadata, not ETL code

## Phase 2 — Labor / Inflation / Trade / External Balance

### Scope
Expand from the macro foundation into the first specialist economic domains where source discipline and comparability become much more sensitive.

### Domain coverage
Phase 2 should explicitly include:
- labor
- inflation
- trade
- external balance

This is the right phase to deepen the economic warehouse beyond a generalist backbone and begin using specialist authority where needed.

### What changes in the data model during Phase 2
- extend the indicator registry for labor, prices, trade, and external-sector measures
- register the specialist datasets and source-series mappings needed for these domains
- strengthen source-priority rules for indicators that now have real overlap across providers
- add domain-specific QA logic for rate measures, trade measures, and external-balance consistency checks

### Recommended source posture in Phase 2
- labor: transition to `ILOSTAT` as the intended authority posture
- inflation: promote `IMF IFS` to the primary authority posture
- trade: use `UN Comtrade` as the foundational trade authority posture
- external balance: use IMF or other explicitly registered macro-financial datasets according to indicator-level authority rules

### Phase 2 marts
#### `mart_country_labor_series_annual`
Long-format published labor series with unemployment and related labor indicators.

#### `mart_country_inflation_series_annual`
Published inflation series with source and quality fields.

#### `mart_country_trade_external_panel_annual`
Panel-style annual mart covering trade and external-balance indicators at country level.

#### `mart_country_macro_plus_external_latest`
Wide latest snapshot combining Phase 1 macro spine with key labor, inflation, trade, and external-balance fields.

### Phase 2 diagnostic views
#### `vw_labor_source_conflicts`
Competing labor observations and the rule used to select the published row.

#### `vw_inflation_source_conflicts`
Inflation overlap between backbone and specialist macro sources.

#### `vw_trade_external_revision_history`
Trade and external-balance revisions across source batches and warehouse publications.

#### `vw_domain_qa_summary_phase2`
Dataset- and indicator-level QA outcomes for the Phase 2 domains.

### Phase 2 exit criteria
- labor, inflation, trade, and external-balance indicators publish through the same lineage-aware model as Phase 1
- specialist authority posture is implemented in metadata rather than analyst-side conventions
- domain marts exist for labor, inflation, and trade/external analysis
- conflict and revision views expose where source overlap exists and how it was resolved

## Phase 3 — Demographics / Health / Education / Infrastructure

### Scope
Extend the platform into broader social and development domains while preserving the same governance, lineage, and publication discipline established earlier.

### Domain coverage
Phase 3 should explicitly include:
- demographics
- health
- education
- infrastructure

This phase should broaden subject coverage, not relax standards.

### What changes in the data model during Phase 3
- expand the indicator registry for demographic, health, education, and infrastructure measures
- add dataset and source-series registrations for the specialist domain sources
- extend validation rules for demographic plausibility, social indicators, and infrastructure coverage gaps
- widen published marts while keeping each new domain on the same versioned publication model

### Recommended source posture in Phase 3
- demographics: `WDI` for continuity where appropriate, with `UN DESA` for deeper demographic authority
- health: `WHO` as the intended authority posture
- education: `UNESCO UIS` as the intended authority posture
- infrastructure: use explicitly registered domain sources according to indicator-level authority and coverage rules

### Phase 3 marts
#### `mart_country_demographics_series_annual`
Published demographic series for longitudinal analysis.

#### `mart_country_health_series_annual`
Published health indicators with source and quality metadata.

#### `mart_country_education_series_annual`
Published education indicators with lineage-ready keys.

#### `mart_country_infrastructure_latest`
Latest infrastructure-focused country snapshot.

#### `mart_country_development_profile_latest`
Wide latest mart that combines macro, external, demographic, health, education, and infrastructure foundations.

### Phase 3 diagnostic views
#### `vw_demographic_health_education_conflicts`
Shows overlapping candidate values and the active authority/precedence rule.

#### `vw_social_infrastructure_coverage_gaps`
Coverage status by country, indicator, and domain.

#### `vw_phase3_revision_history`
Revision history for demographic, health, education, and infrastructure observations.

### Phase 3 exit criteria
- each new domain has registered indicators, datasets, source-series mappings, and validation rules
- each domain has at least one analyst-facing mart and one diagnostic view
- published development-profile marts can be assembled without querying staging or raw tables

## Cross-Cutting Data-Quality Rules

### Rule categories
#### Structural
- required source payload fields must be present
- batch identifiers and published primary keys must be unique
- published marts must not contain duplicate country / indicator / period rows

#### Referential
- country codes must resolve to one canonical country row
- each published indicator must resolve to one business definition
- promoted observations must map to registered datasets and, where required, registered source series
- units and frequencies must resolve to controlled vocabularies

#### Semantic
- population cannot be negative
- rate measures such as unemployment and inflation must stay within configured plausibility bands
- GDP and trade measures must not show impossible scale changes without review
- life expectancy and similar bounded measures must remain in plausible human ranges

#### Temporal
- observation periods must fall within supported ranges
- future periods require explicit approval, not silent acceptance
- revision timestamps cannot predate source-batch fetch timestamps
- effective-dated source-priority rules must not overlap ambiguously for the same scope

### Severity model
- `error`: blocks publication
- `warning`: publishes with a visible quality flag and audit event
- `info`: recorded for observability only

### Required DQ outputs
- row-level QA events in `audit`
- dataset-level scorecards by run
- coverage-gap summaries by country and indicator
- anomaly and revision summaries in publication notes

## Source-Conflict Rules

### Default precedence order
1. prefer the registered authority for the indicator or domain
2. prefer observed-statistics datasets over forecast-oriented datasets unless the indicator explicitly allows forecasts
3. prefer the higher-priority active rule for the period and publication window
4. if an approved country-specific official override exists, use it only within its explicit scope
5. if ties remain, prefer the more recent authoritative release with documented rationale

### Required conflict metadata
- indicator or indicator-family scope
- country scope if any
- period scope if any
- effective dates
- release-window scope if needed
- priority rank
- rationale
- override flag

### Operational rules
- never silently replace one source with another in published history
- log the selection method used for every published row
- preserve competing candidate observations in version-history or conflict views
- when authority posture changes, publish a new warehouse version and release note

## Revision and Versioning Guidance

### Distinguish three kinds of change
#### Source revision
The upstream provider republishes a changed value for an already seen observation.

Required handling:
- append a new observation version
- retain the prior source version
- log a revision event

#### Metadata-rule revision
Mappings, source precedence, or authority posture change.

Required handling:
- version the rule set
- republish affected outputs under a new warehouse publication version
- record rationale and affected scope

#### Transformation revision
Normalization, derivation, or QA logic changes.

Required handling:
- version the transformation or pipeline release
- make publication runs reproducible against that code/config version
- identify whether published changes came from warehouse logic rather than upstream source change

### Publication version contract
Each publication should record:
- publication version identifier
- publication timestamp
- code/config version reference
- metadata-rule version reference
- included dataset batches
- summary of major revisions and source-policy changes

## What Should Wait Until After Phase 3
These are valid future directions, but they should not replace the required three-phase rollout:
- quarterly and monthly extensions
- financial-conditions expansion via BIS/ECB
- agriculture / food systems
- emissions / energy
- government finance / debt beyond the initial external-balance scope

## Recommended Build Sequence
1. Revise the metadata model and fact pattern inside the Phase 1 build, not later.
2. Publish the Phase 1 macro foundation with lineage, revision history, and first marts/views.
3. Expand into Phase 2 labor / inflation / trade / external balance using specialist authority and stronger conflict rules.
4. Expand into Phase 3 demographics / health / education / infrastructure using the same published-fact and QA model.
5. Only after those three phases are stable should broader frequency or domain expansion begin.

## Delivery Summary
The roadmap should be judged successful if it does two things at once:
- it preserves the task's required Phase 1 / 2 / 3 rollout shape
- it fixes the structural trust gaps early enough that later domain expansion does not collapse under weak lineage, weak source identity, implicit QA, or non-reproducible revisions
