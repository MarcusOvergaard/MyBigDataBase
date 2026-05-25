# Beginner Architecture Guide for MyBigDataBase

This document explains the project in plain English.

It is written for a human who is building his first database and first star-schema warehouse.

## What this project is

This project is a country-data warehouse.

Its job is not to search the internet live every time you ask a question.
Its real job is:

1. get data from a source
2. store that data locally
3. clean it
4. decide which values to trust
5. save the trusted version
6. give you easy tables and views to query later

Simple flow:

source -> raw -> staging -> core -> audit -> mart

## The big idea

Think of the project like a small factory.

- `raw` = the loading dock and storage room
- `staging` = the prep table
- `core` = the main warehouse
- `audit` = the logbook
- `mart` = the showroom

Each part has a different job.
That separation is important because it keeps the system understandable.

## Quick visual maps

### Whole-system flow

```text
outside source
    |
    v
sample file or API fetch
    |
    v
raw
    |
    v
staging
    |
    v
core
    |
    +------> audit
    |
    v
mart
    |
    v
your SQL query
```

What this means:
- data comes in from outside
- it moves through the warehouse in steps
- `audit` watches and records what happened
- `mart` is the easier final surface for reading data

### Star-schema picture

```text
               dim_country
                    |
                    |
dim_time ---- fact_country_indicator_published ---- dim_indicator
                    |
                    |
                dim_source
                    |
                    |
                dim_dataset
```

What this means:
- the fact table is the center
- the dimensions describe the fact row
- this is why it is called a star shape

### Command-to-file flow

```text
make init
  -> Makefile
  -> scripts/setup_db.sh
  -> ddl/*.sql
  -> etl/*.sql

make load-sample
  -> Makefile
  -> scripts/load_phase1_sample.sh
  -> scripts/load_ifs_sample.sh
  -> raw tables
  -> staging procedures
  -> publish procedure

make test
  -> Makefile
  -> queries/test_queries.sql
  -> checks mart/core/audit outputs
```

What this means:
- `make` is the front door
- shell scripts and SQL files do the actual work
- the command names are short, but they trigger many files underneath

---

## 1. Source

This is where the data comes from.

Right now, the runnable project uses sample files that stand in for real external data.
Later, the plan is to add real ingestion from APIs such as World Bank WDI and IMF IFS.

Main files to inspect:
- project overview: `/home/marcusai/MyProjects/MyBigDataBase/README.md`
- source strategy: `/home/marcusai/MyProjects/MyBigDataBase/docs/source_registry.md`
- real-ingestion plan: `/home/marcusai/MyProjects/MyBigDataBase/docs/plans/phase2-real-ingestion-plan.md`
- current WDI sample file: `/home/marcusai/MyProjects/MyBigDataBase/raw_files/sample_wb_data.csv`
- current IFS sample file: `/home/marcusai/MyProjects/MyBigDataBase/raw_files/sample_ifs_data.csv`

What to understand here:
- the source is the outside world
- right now the outside world is simulated with local sample files
- later the source will be real API fetches

---

## 2. Raw

Then the project puts data into a `raw` area.

This is the storage room.
We keep the data close to how it originally arrived.
We do not try to make it pretty yet.

Why this layer exists:
- so you can keep source evidence
- so you can reload or debug later
- so you do not lose what the source originally gave you

Main files to inspect:
- raw table definitions: `/home/marcusai/MyProjects/MyBigDataBase/ddl/03_raw_tables.sql`
- WDI loader: `/home/marcusai/MyProjects/MyBigDataBase/scripts/load_phase1_sample.sh`
- IFS loader: `/home/marcusai/MyProjects/MyBigDataBase/scripts/load_ifs_sample.sh`

What to look for in those files:
- `raw.source_batch` = one record for one load event
- `raw.wdi_country_indicator_annual` = raw WDI rows
- `raw.ifs_country_indicator_annual` = raw IMF/IFS rows

Simple mental model:
- source gives you boxes
- raw is where you stack the boxes before opening and sorting them

---

## 3. Staging

Then the project cleans and translates the data in `staging`.

This is the prep table.
Here we fix formats, match country codes, align indicator names, and make rows more consistent.

Why this layer exists:
- source data is often messy
- one source may call something `USA`, another may use a different code
- values may come in as text and need to become numbers
- some rows may fail QA or mapping

Main files to inspect:
- staging table definition: `/home/marcusai/MyProjects/MyBigDataBase/ddl/04_staging_tables.sql`
- raw-to-staging logic: `/home/marcusai/MyProjects/MyBigDataBase/etl/01_raw_to_staging.sql`

What to understand here:
- `staging` is not the final trusted truth
- it is the cleaned workbench before final publishing
- this is where a lot of ugly real-world mess gets handled

Simple mental model:
- raw is unopened groceries
- staging is washing, cutting, and sorting ingredients before cooking

---

## 4. Core

Then the project moves the trusted version into `core`.

This is the main warehouse.
These are the rows we trust and want analysts to rely on.

Why this layer exists:
- you want one stable place for trusted data
- you want dimensions like country, time, and indicator to be standardized
- you want published values and version history to be separate and understandable

Main files to inspect:
- core dimensions: `/home/marcusai/MyProjects/MyBigDataBase/ddl/05_core_dimensions.sql`
- core fact tables: `/home/marcusai/MyProjects/MyBigDataBase/ddl/06_core_facts.sql`
- publish logic: `/home/marcusai/MyProjects/MyBigDataBase/etl/03_publish_phase1.sql`

Important things in `core`:
- `core.dim_country` = the country dimension
- `core.dim_indicator` = the indicator dimension
- `core.dim_time` = the time dimension
- `core.fact_country_indicator_version` = historical versions
- `core.fact_country_indicator_published` = current trusted published rows

This is where the star-schema idea starts to matter.

Simple version of star schema:
- dimensions describe things
- facts store measured values

Here that means:
- dimensions = country, indicator, time, source, dataset
- facts = the actual indicator values for a country and year

Simple mental model:
- dimensions are labels on drawers
- facts are the items you put inside the drawers

---

## 5. Audit

Then the project records what happened in `audit`.

This is the logbook beside the factory.
It tracks operations, problems, revisions, and freshness.

Why this layer exists:
- you need to know when a load happened
- you need to know if something failed
- you need to know if a value changed later
- you need to know whether a dataset is fresh or stale

Main files to inspect:
- audit table definitions: `/home/marcusai/MyProjects/MyBigDataBase/ddl/07_audit_tables.sql`
- publish logic that writes audit records: `/home/marcusai/MyProjects/MyBigDataBase/etl/03_publish_phase1.sql`
- hardening and publish guards: `/home/marcusai/MyProjects/MyBigDataBase/ddl/09_constraints_indexes.sql`

Important things in `audit`:
- `audit.pipeline_run`
- `audit.data_quality_event`
- `audit.revision_event`
- `audit.publication_version`
- `audit.dataset_freshness`

Simple mental model:
- if `core` is the warehouse,
- `audit` is the notebook that says what arrived, what changed, and what went wrong

---

## 6. Mart

Then the project builds easy-to-use views in `mart`.

This is the showroom.
It gives simpler tables for analysis so you do not have to read the inner machinery every time.

Why this layer exists:
- analysts want easier query surfaces
- they should not need to understand every raw or staging detail
- good marts reduce repeated work

Main files to inspect:
- mart and view definitions: `/home/marcusai/MyProjects/MyBigDataBase/ddl/08_marts_and_views.sql`
- extra lineage and contract logic: `/home/marcusai/MyProjects/MyBigDataBase/ddl/10_canonical_contract_followthrough.sql`

Important views to know:
- `mart.mart_country_macro_series_annual`
- `mart.mart_country_macro_latest`
- `mart.mart_country_profile_foundation`
- `mart.vw_macro_published_with_lineage`
- `mart.vw_macro_revision_history`
- `mart.vw_macro_coverage_gaps`
- `mart.vw_dataset_freshness_status`
- `mart.vw_macro_source_selection_lineage`

Simple mental model:
- `mart` is the clean shelf in the front of the store
- `raw`, `staging`, and some of `audit` are the back room

---

## How the source-choice logic works

One of the hardest parts of this project is that two sources can both claim to have the answer.

Example:
- WDI may have inflation for a country and year
- IMF IFS may also have inflation for that same country and year

The project needs a rule for deciding which one wins.

That rule should not live only inside random script code.
It should live in metadata.

Main files to inspect:
- source-priority metadata: `/home/marcusai/MyProjects/MyBigDataBase/ddl/02_ref_tables.sql`
- source-priority seeds and overrides: `/home/marcusai/MyProjects/MyBigDataBase/seeds/00_ref_metadata_seeds.sql`
- country/time-specific overrides: `/home/marcusai/MyProjects/MyBigDataBase/seeds/00b_indicator_source_priority_overrides.sql`
- publish logic: `/home/marcusai/MyProjects/MyBigDataBase/etl/03_publish_phase1.sql`

Simple version:
- if two sources overlap,
- the database checks the priority rules,
- then publishes the winner,
- and keeps enough lineage to explain why

That is a major reason this is a warehouse and not just a pile of CSV files.

---

## What the current runnable commands do

Main files to inspect:
- command entrypoint: `/home/marcusai/MyProjects/MyBigDataBase/Makefile`
- setup script: `/home/marcusai/MyProjects/MyBigDataBase/scripts/setup_db.sh`
- repeat-load regression: `/home/marcusai/MyProjects/MyBigDataBase/scripts/test_repeat_load_regression.sh`
- validation queries: `/home/marcusai/MyProjects/MyBigDataBase/queries/test_queries.sql`

Main commands:

- `make init`
  - creates schemas, tables, and procedures

- `make load-sample`
  - loads the local sample WDI and IFS files
  - pushes them through the pipeline

- `make build-mart`
  - rebuilds the analyst-facing views

- `make test`
  - runs validation queries against the database

- `make repeat-load-test`
  - checks that rerunning loads does not break the published contract

---

## What is true right now

Right now the project is:
- a working local warehouse
- sample-data driven
- not yet a real live-ingestion system
- already able to store, clean, publish, and query country data locally

That means:
- you are not querying the web live when you query Postgres
- you are querying your own stored warehouse tables

---

## What Phase 2 is supposed to add

Phase 2 is supposed to turn the sample-loading idea into real ingestion.

That means:
- calling real APIs or downloads
- saving local snapshots of what was fetched
- loading those snapshots into `raw`
- keeping the rest of the same pipeline

Main files to inspect:
- Phase 2 plan: `/home/marcusai/MyProjects/MyBigDataBase/docs/plans/phase2-real-ingestion-plan.md`
- roadmap: `/home/marcusai/MyProjects/MyBigDataBase/docs/roadmap.md`

Important design rule:
- we should add real ingestion in front of the current pipeline
- we should not replace the whole pipeline

So the future should be:
real API fetch -> local snapshot -> raw -> staging -> core -> audit -> mart

---

## If you want to learn this project in the best order

Read in this order:

1. `/home/marcusai/MyProjects/MyBigDataBase/README.md`
2. `/home/marcusai/MyProjects/MyBigDataBase/Makefile`
3. `/home/marcusai/MyProjects/MyBigDataBase/scripts/setup_db.sh`
4. `/home/marcusai/MyProjects/MyBigDataBase/scripts/load_phase1_sample.sh`
5. `/home/marcusai/MyProjects/MyBigDataBase/scripts/load_ifs_sample.sh`
6. `/home/marcusai/MyProjects/MyBigDataBase/ddl/03_raw_tables.sql`
7. `/home/marcusai/MyProjects/MyBigDataBase/ddl/04_staging_tables.sql`
8. `/home/marcusai/MyProjects/MyBigDataBase/ddl/05_core_dimensions.sql`
9. `/home/marcusai/MyProjects/MyBigDataBase/ddl/06_core_facts.sql`
10. `/home/marcusai/MyProjects/MyBigDataBase/ddl/07_audit_tables.sql`
11. `/home/marcusai/MyProjects/MyBigDataBase/ddl/08_marts_and_views.sql`
12. `/home/marcusai/MyProjects/MyBigDataBase/etl/01_raw_to_staging.sql`
13. `/home/marcusai/MyProjects/MyBigDataBase/etl/03_publish_phase1.sql`
14. `/home/marcusai/MyProjects/MyBigDataBase/queries/test_queries.sql`

---

## Final simple summary

This project is building a trustworthy country-data warehouse.

Its job is:
- bring data in
- keep the original evidence
- clean it
- choose the trusted version
- record what happened
- give easy tables for analysis

That is the whole machine in one sentence.