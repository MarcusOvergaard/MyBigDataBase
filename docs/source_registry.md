# Source Registry for Authoritative Country Data Sources

## Why this document exists
The current project already has a usable Phase 1 warehouse skeleton in `/home/marcusai/MyProjects/MyBigDataBase/`, but its source model is still intentionally narrow for a fully trustworthy research-grade country analytics platform.

The repository has already moved onto a deeper Phase 1 metadata contract, and the remaining legacy references are now quarantined as explicit compatibility stubs rather than active design targets.

The active repository now includes:
- provider-level source identity in `ref.source_system`
- dataset-level identity in `ref.source_dataset`
- native series identity in `ref.source_series`
- explainable source selection rules in `ref.indicator_source_priority`
- version-history and published fact surfaces in `core.fact_country_indicator_version` and `core.fact_country_indicator_published`

What is still true is that the source model remains intentionally narrow in scope for now:
- only the first Wave 1 provider/dataset/series set is seeded
- WDI is still the active backbone for the runnable sample flow
- the current runnable loaders use local sample files rather than live API fetches
- specialist-source production ingestion is still deferred beyond the current Phase 1 sample path
- only a few historical stub files still mention `dw.fact_country_metric`, and they do so purely to redirect old paths toward the current contract

That design is fine for a toy warehouse, but it is not enough for a research-grade system where users need to know:
- which provider supplied a value
- which dataset inside that provider supplied it
- which native series code it came from
- whether a later source revision changed the value
- why one source was chosen over another for a specific metric family

This registry fixes that gap. It does two jobs:
1. it assigns authoritative sources by metric family in a way that is practical for implementation, not just theoretically nice
2. it defines the metadata additions needed to make those source decisions executable inside the warehouse

## What was weak in the earlier draft, and what is fixed here
The earlier version was directionally correct but too shallow. The weak points were:
- it named preferred sources without tying them tightly enough to the actual repository structure
- it did not clearly separate provider-level authority from dataset-level authority
- it was not explicit enough about why some broad sources are useful as backbones but weak as final authorities
- it did not connect source choices tightly enough to the concrete Phase 1 `ref` / `core` source metadata and publication design
- it did not spell out enough conflict-resolution rules for when multiple credible sources disagree

This revised version fixes those points by:
- grounding recommendations in the actual schema and seed files in the original project
- distinguishing `source_system`, `source_dataset`, and `source_series`
- making metric-family authority decisions more explicit and more defensible
- showing how source policy should affect schema, ETL, lineage, and revision tracking
- calling out where the current project structure will fail if the registry model is not deepened

## Core decision principles

### 1. Backbone coverage is not the same thing as authority
A source can be the best default backbone for broad country coverage without being the best authority for a particular domain.

Example:
- `World Bank WDI` is the best initial backbone for integrated annual country coverage across many domains
- `ILOSTAT` is still the better authority for labor metrics
- `WHO` is still the better authority for health metrics
- `UNESCO UIS` is still the better authority for education metrics

### 2. Provider-level identity is too coarse
Provider-level source identity alone is not sufficient, even though the Phase 1 contract now models it correctly in `ref.source_system`.

Why this matters:
- `IMF WEO` and `IMF IFS` serve different purposes
- `UN Data` and `UN DESA` may have different update patterns and methodological depth
- `World Bank WDI` is not the same thing as every World Bank statistical product

A trustworthy warehouse must distinguish:
- provider, for example `IMF`
- dataset/product, for example `IFS`
- native series, for example a source code for CPI inflation

### 3. Source conflict rules must be metadata-driven
If source choice is buried inside ETL scripts, the warehouse becomes fragile and unexplainable.

Source selection should instead be explainable from tables that show:
- which source has priority for a metric family
- where country-specific overrides exist
- when the rule became effective
- why the choice was made

### 4. Revision tracking is mandatory, not optional
For macro, trade, labor, and many social indicators, revised historical values are normal.

If the warehouse stores only one latest value without release context, it loses trust immediately.

## Current original-project implications
The original project in `/home/marcusai/MyProjects/MyBigDataBase/` already has the first Phase 1 source metadata spine, but it still needs expansion discipline because:
- `ref.source_system`, `ref.source_dataset`, and `ref.source_series` now distinguish provider vs dataset vs series, but only for the first seeded Phase 1 scope
- `core.fact_country_indicator_version` and `core.fact_country_indicator_published` now carry publication lineage, but release/revision depth is still only partial and will need to deepen as more specialist domains land
- `seeds/00_ref_metadata_seeds.sql` establishes the initial authority posture, but it is intentionally minimal rather than comprehensive
- the marts now sit on a much better published surface, but they will become misleading again if future work bypasses `ref.indicator_source_priority` or reintroduces ad hoc source selection logic

That means the source registry is no longer a proposal for a second architecture. It is guidance for extending the Phase 1 contract that already exists.

## Recommended authoritative assignments by metric family

### GDP and macro growth
**Default authority:** `World Bank WDI` for the first annual country backbone

**Why:**
- very broad country coverage
- stable annual series for cross-country comparison
- well-known country and indicator identifiers
- practical API and bulk-ingestion pattern
- good fit for the current simple star-schema starting point

**Where it is weak:**
- it is often a republishing layer, not the deepest methodological source
- release timing may lag specialist macro products
- it should not be treated as the permanent final word for every macro indicator

**Arbitration / specialist source:** `IMF IFS`, with `IMF WEO` used selectively

**Decision:**
- use `WDI` as the annual macro backbone in the original project’s first implementation phase
- use `IFS` as the comparison and override candidate when inflation or macro methodology clearly requires it
- do not use `WEO` as a default observed-statistics source unless the use case explicitly wants forecast-oriented series

### Population and demographics
**Default authority:** `World Bank WDI` for baseline annual warehouse coverage

**Why:**
- population totals are easy to integrate from WDI in the current build
- broad coverage matters more than demographic nuance in the first pass
- aligns with the current sample warehouse style

**Arbitration / specialist source:** `UN DESA` or related UN demographic systems

**Decision:**
- use `WDI` for initial population and headline demographic series in the core warehouse spine
- use `UN DESA` when the warehouse expands into deeper demographic structure, cohort detail, dependency ratios, or when demographic methodology/revision logic matters more than broad integration convenience

### Labor
**Default authority:** `ILOSTAT`

**Why:**
- labor concepts are methodology-sensitive
- labor definitions drift across sources more than many users assume
- `ILOSTAT` has the strongest domain legitimacy among the evaluated global sources
- labor should not remain a mirror-only field inside a generalist macro source model

**Fallback / comparison source:** `WDI` or `OECD`

**Decision:**
- for the current original project, `UNEMPLOYMENT_RATE` should be sourced as labor-authoritative from `ILOSTAT` once the pipeline expands beyond a minimal backbone prototype
- if the current project keeps `WDI` unemployment early for convenience, that should be explicitly labeled transitional in metadata

### Inflation
**Default authority:** `IMF IFS`

**Why:**
- inflation is a macroeconomic core measure where source discipline matters
- `IFS` is stronger than a broad development mirror for price statistics and macro release handling
- inflation often needs better methodological control than a general annual indicator registry gives by default

**Fallback / comparison source:** `WDI`, `OECD`

**Decision:**
- the original project should treat `INFLATION_CPI_PCT` as `IFS`-authoritative once the dataset registry is introduced
- `WDI` may remain useful as a broad comparison or bootstrap source, but not as the long-term inflation authority

**Implemented proof in the current repository:**
- the repository now includes minimal runnable arbitration slices for both `INFLATION_CPI_PCT` and `GDP_CURR_USD` across `WDI` and `IFS`
- `ref.indicator_source_priority` explicitly ranks `IFS` above `WDI` for those indicators
- the sample loaders intentionally create overlapping `USA 2022` and `DEU 2022` observations in both datasets
- publication now proves the rule is executable rather than aspirational: the global default lets `IFS` win where both sources exist, while `WDI` still publishes for countries or years not covered by the minimal `IFS` sample
- the repository also now proves country-specific temporal arbitration: `DEU` inflation is explicitly overridden back to `WDI` for observation year `2022`, then reverts to the global `IFS` default outside that year, showing that a country rule can intentionally beat the global default without leaking beyond its validity window

### Trade
**Default authority:** `UN Comtrade`

**Why:**
- trade is not just one scalar value, it is a structurally richer domain
- Comtrade is the leading international source for merchandise trade detail and bilateral trade flows
- using a generic macro mirror alone would undercut later trade expansion

**Fallback / comparison source:** `World Bank`, `IMF Direction of Trade`, `OECD`

**Decision:**
- the first trade-specific warehouse expansion should use `UN Comtrade` as the authority
- simplified trade measures from other sources can appear in marts, but not as the foundational trade registry authority

### Health
**Default authority:** `WHO`

**Why:**
- health indicators have more methodological nuance than the current starter schema captures
- `WHO` is the best specialist authority among the requested sources
- this is especially true once the warehouse goes beyond headline life expectancy

**Fallback / comparison source:** `WDI`

**Decision:**
- `LIFE_EXPECTANCY_BIRTH_TOTAL` can remain in a `WDI`-backbone phase for convenience
- health-family authority should still be assigned to `WHO` for the long-term source registry

### Education
**Default authority:** `UNESCO UIS`

**Why:**
- education indicators need stronger domain metadata than broad development mirrors usually provide
- `UIS` is the best specialist international education source in the required evaluation set

**Fallback / comparison source:** `WDI`, `OECD`

**Decision:**
- education-family authority should be `UIS`
- if the original project later adds education metrics, source metadata should make clear when a value is a `WDI` mirror versus a `UIS`-authoritative publication

### Additional future specialist domains
#### Agriculture and food systems
**Authority:** `FAOSTAT`

Use when agriculture, food security, agricultural production, land use, or food-related environmental indicators are introduced.

#### Financial conditions and credit
**Authority:** `BIS`, with selective `ECB` use for euro-area detail

Use for future financial-system expansion, not for the current core country indicator spine.

## Detailed evaluation of requested sources

### 1. World Bank WDI
- **Provider name:** World Bank
- **Dataset / product focus:** World Development Indicators
- **Website:** `https://data.worldbank.org/`
- **API endpoint:** `https://api.worldbank.org/v2/`
- **Metric families covered:** macro, population, selected health, selected education, development indicators, infrastructure, environment
- **Geographic coverage:** near-global sovereign-country coverage plus aggregates
- **Update cadence:** periodic annual refreshes, varies by underlying source stream
- **Machine-ingestion method:** stable public API and bulk downloads
- **Authority / reliability notes:** best integrated backbone source for first-pass annual warehouse coverage; not always the methodological authority for specialist domains
- **Implementation verdict:** indispensable as the initial coverage backbone for the current project, but should not remain the implicit authority for every metric family

### 2. IMF
- **Provider name:** International Monetary Fund
- **Dataset / product focus:** especially `IFS`, selectively `WEO`
- **Website:** `https://www.imf.org/en/Data`
- **API endpoint:** dataset-specific IMF and SDMX endpoints
- **Metric families covered:** inflation, macro, monetary, financial, balance-of-payments, fiscal
- **Geographic coverage:** broad global macro-financial scope
- **Update cadence:** dataset-specific, often stronger than general annual mirrors
- **Machine-ingestion method:** SDMX/API, more dataset-specific handling than WDI
- **Authority / reliability notes:** very strong macro and price-statistics authority, but users must distinguish observed-statistics datasets from forecast-oriented datasets
- **Implementation verdict:** should become the authority for inflation and the main arbitration layer for macro indicators once the original project grows beyond its seed stage
- **Current repository proof:** the first narrow external-balance proof now uses `WEO` for annual current-account balance in U.S. dollars and current-account balance as a share of GDP; this is intentionally a small observed external-balance slice, not a blanket claim that `WEO` should replace `IFS` as the default macro authority

### 3. OECD
- **Provider name:** Organisation for Economic Co-operation and Development
- **Website:** `https://data-explorer.oecd.org/`
- **API endpoint:** OECD SDMX / JSON-stat style endpoints
- **Metric families covered:** macro, labor, education, productivity, social indicators, trade
- **Geographic coverage:** strongest for OECD members and partners, not a full global backbone
- **Update cadence:** regular, dataset-specific
- **Machine-ingestion method:** API/SDMX and extracts
- **Authority / reliability notes:** very strong harmonized source where country coverage fits, but not the global default for this warehouse’s country-universe needs
- **Implementation verdict:** keep as comparison and enrichment source, not primary global authority

### 4. UN Data / UN DESA
- **Provider name:** United Nations data systems and demographic products
- **Website:** `https://data.un.org/`
- **API endpoint:** UNData API and dataset-specific downloads
- **Metric families covered:** population, demographics, social indicators, selected macro statistics
- **Geographic coverage:** global
- **Update cadence:** dataset-dependent
- **Machine-ingestion method:** API where supported, otherwise download-driven
- **Authority / reliability notes:** important for demographic authority and UN-system legitimacy; less operationally uniform than WDI
- **Implementation verdict:** use as demographic specialist authority rather than the first integrated backbone

### 5. ILOSTAT
- **Provider name:** International Labour Organization
- **Website:** `https://ilostat.ilo.org/`
- **API endpoint:** `https://rplumber.ilo.org/data/` and related services
- **Metric families covered:** unemployment, employment, labor force, wages, working conditions
- **Geographic coverage:** broad international labor coverage
- **Update cadence:** regular, dataset-specific
- **Machine-ingestion method:** API and downloadable flat files
- **Authority / reliability notes:** strongest labor specialist source in the required evaluation set
- **Implementation verdict:** labor authority should sit here, not in a generic source mirror

### 6. WHO
- **Provider name:** World Health Organization
- **Website:** `https://www.who.int/data`
- **API endpoint:** product-specific data services and downloadable files
- **Metric families covered:** mortality, life expectancy, health systems, public health, disease burden
- **Geographic coverage:** broad global scope
- **Update cadence:** indicator-dependent
- **Machine-ingestion method:** downloadable files and selected APIs
- **Authority / reliability notes:** strongest health specialist authority in the evaluation set
- **Implementation verdict:** assign health-family authority here, even when the earliest warehouse slice temporarily uses WDI mirrors

### 7. UNESCO UIS
- **Provider name:** UNESCO Institute for Statistics
- **Website:** `https://uis.unesco.org/`
- **API endpoint:** product-dependent API/bulk access
- **Metric families covered:** education attainment, enrollment, literacy, education finance
- **Geographic coverage:** broad international coverage
- **Update cadence:** annual or product-dependent
- **Machine-ingestion method:** API and/or bulk files depending on dataset
- **Authority / reliability notes:** strongest education specialist authority in the required set
- **Implementation verdict:** assign education-family authority here

### 8. FAOSTAT
- **Provider name:** Food and Agriculture Organization
- **Website:** `https://www.fao.org/faostat/`
- **API endpoint:** product-specific API/bulk access
- **Metric families covered:** agriculture, land use, food systems, agricultural emissions
- **Geographic coverage:** global
- **Update cadence:** dataset-dependent
- **Machine-ingestion method:** API and bulk extracts
- **Authority / reliability notes:** strong specialist authority for future agriculture/food domains
- **Implementation verdict:** not a current core default, but important for future expansion

### 9. BIS
- **Provider name:** Bank for International Settlements
- **Website:** `https://www.bis.org/`
- **API endpoint:** BIS statistical APIs / SDMX endpoints
- **Metric families covered:** banking, credit, property prices, debt securities, financial conditions
- **Geographic coverage:** broad but not universal
- **Update cadence:** regular, often quarterly
- **Machine-ingestion method:** API/SDMX and downloads
- **Authority / reliability notes:** strong financial specialist authority, not needed for the current minimal cross-domain registry but valuable later
- **Implementation verdict:** defer until financial-system expansion

### 10. UN Comtrade
- **Provider name:** United Nations Comtrade
- **Website:** `https://comtradeplus.un.org/`
- **API endpoint:** Comtrade API and bulk download services
- **Metric families covered:** merchandise trade flows, bilateral trade, product-level trade
- **Geographic coverage:** broad global trade coverage
- **Update cadence:** frequent, dataset-dependent
- **Machine-ingestion method:** API and bulk files, quota-aware ingestion required
- **Authority / reliability notes:** strongest international trade-detail authority in the requested source set
- **Implementation verdict:** trade-family authority should sit here

### 11. ECB Data Portal
- **Provider name:** European Central Bank
- **Website:** `https://data.ecb.europa.eu/`
- **API endpoint:** ECB SDMX APIs
- **Metric families covered:** euro-area monetary, financial, exchange-rate, and selected macro indicators
- **Geographic coverage:** region-specific, not global
- **Update cadence:** regular official releases
- **Machine-ingestion method:** SDMX/API
- **Authority / reliability notes:** excellent regional official source, but not suitable as the warehouse’s global default backbone
- **Implementation verdict:** use only when euro-area-specific detail is required

### 12. Official national statistics offices and central banks
- **Provider name:** country-specific, varies by jurisdiction
- **Website/API:** country-specific
- **Metric families covered:** all, depending on country
- **Geographic coverage:** country-specific only
- **Update cadence:** highly variable
- **Machine-ingestion method:** mixed, often inconsistent
- **Authority / reliability notes:** legally authoritative inside a country, but weak as a cross-country default due to inconsistent standards and pipelines
- **Implementation verdict:** use only as explicit country overrides or gap-fill exceptions with recorded justification

## Recommended operational source-priority model

### Phase-1 operational default in the original project
For the current repository skeleton, the most practical path is:
1. `WDI` for baseline macro and demographic annual coverage
2. `IMF IFS` for inflation authority and macro arbitration
3. `IMF WEO` selectively for the first narrow external-balance current-account slice
4. `ILOSTAT` for labor authority
5. `WHO` for health authority
6. `UNESCO UIS` for education authority
7. `UN Comtrade` for trade authority
8. `UN DESA` for deeper demographic arbitration and expansion
9. `OECD`, `BIS`, `ECB`, `FAOSTAT` as specialist comparison/expansion sources
10. country-specific official sources only by exception rule

### Conflict-resolution rules
When multiple credible sources exist for the same analyst-facing metric:
- prefer the registered authority for that metric family unless there is a documented exception
- prefer observed-statistics products over forecast products unless the metric explicitly calls for forecasts
- if a national official source overrides the default international source, record effective dates and justification
- never replace history silently; preserve prior published values and record the new source selection event

## Concrete schema alignment required in the original project
The big architectural shift is already done. The important work now is to keep this document aligned with the active Phase 1 contract instead of describing a parallel `dw` redesign.

### 1. Keep source modeling centered on the landed `ref` metadata spine
The active repository already uses:
- `ref.source_system`
- `ref.source_dataset`
- `ref.source_series`
- `ref.indicator_source_priority`

That is the right abstraction boundary for future source-registry expansion.

### 2. Keep provenance and publication logic centered on the landed `core` facts
The active repository already uses:
- `core.fact_country_indicator_version` for source-version history
- `core.fact_country_indicator_published` for the one-row published contract

Future release-date and revision deepening should extend those tables and their publication procedures, not revive `dw.fact_country_metric` as a competing path.

### 3. Keep authority rules effective-dated and metadata-driven
Metric-family authority changes over time. The warehouse must continue expressing:
- source priority by indicator
- optional country override
- start and end dates for the rule
- rationale / justification notes

The landed `ref.indicator_source_priority` table is the correct place for that logic.

## SQL-oriented alignment notes for the original project
The repository already contains the core Phase 1 objects needed for this registry direction:
- `ref.source_system`
- `ref.source_dataset`
- `ref.source_series`
- `ref.indicator_source_priority`
- `core.fact_country_indicator_version`
- `core.fact_country_indicator_published`

So the next SQL work should focus on extending those objects where needed, not inventing a second schema family.

## Recommended seed posture for the original project
The current `seeds/00_ref_metadata_seeds.sql` should expand from the initial Wave 1 posture toward a broader structured seed set like:
- `WB` -> dataset `WDI`
- `IMF` -> datasets `IFS` and optionally `WEO`
- `ILO` -> dataset `ILOSTAT_MAIN`
- `WHO` -> dataset `GHO`
- `UIS` -> dataset `UIS_EDU`
- `UNCOMTRADE` -> dataset `COMTRADE_GOODS`
- `UNDESA` -> dataset `UNDESA_POP`

This is important because the current source seed model is too generic to carry authority decisions safely.

## Immediate implementation recommendations
1. Keep `WDI` as the current practical backbone for early annual country coverage.
2. Do not leave `UNEMPLOYMENT_RATE` permanently sourced from a generic backbone if labor analysis matters.
3. Promote `IMF IFS` to the intended inflation authority before the project treats inflation as production-trustworthy.
4. Add dataset and series metadata before Phase 2 domain expansion, not after.
5. Extend the fact model with release and revision fields before large-scale source mixing begins.
6. Keep national official sources as explicit exception rules, not silent substitutions.

## Verification target for sync back to the original project
When this task is finalized, the original project should not just reference this registry conceptually. It should actually contain the updated file in:
- `/home/marcusai/MyProjects/MyBigDataBase/docs/source_registry.md`

That sync matters because the revised task definition explicitly requires the original project to be updated, not just this detached workspace.

## Bottom line
For MyBigDataBase, the correct practical posture is:
- use `World Bank WDI` as the initial integrated annual backbone
- use `IMF IFS` as the inflation authority and macro arbitration layer
- use `ILOSTAT`, `WHO`, `UNESCO UIS`, and `UN Comtrade` as specialist domain authorities
- use `UN DESA`, `OECD`, `BIS`, `ECB`, and national official sources selectively and explicitly
- deepen the original project schema so source authority is represented at provider, dataset, and series levels with revision-aware lineage

Without those additions, the current project can still run as a demo warehouse, but it will not be a trustworthy research-grade source-governed platform.
