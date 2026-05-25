# Phase 1 Audit and Publication Control Slice Notes

This slice lands the first durable `audit` control surfaces on top of the already-landed `ref`, `raw`, `staging`, and `core` contract.

## Scope landed here
- `audit.pipeline_run`
- `audit.data_quality_event`
- `audit.revision_event`
- `audit.publication_version`
- `audit.dataset_freshness`
- reproducible publication stamping from the Phase 1 publish procedure

## Small supporting hooks included
- `ref.validation_rule` plus minimal seeds so durable QA events can carry rule identity instead of only free-text messages
- foreign-key enforcement from `core.fact_country_indicator_published.publication_version_key` to `audit.publication_version`

## Intentionally not landed here
- the first mart/view layer
- broad new candidate-ranking families beyond the current staging + source-priority publish path
- richer release workflow orchestration beyond the minimum durable audit/publication controls
