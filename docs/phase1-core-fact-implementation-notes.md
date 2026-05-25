# Phase 1 Core Fact Slice Notes

This slice lands the first conformed `core` facts on top of the already-landed `ref`, `raw`, `staging`, and `core.dim_*` contract.

## Scope landed here
- `core.fact_country_indicator_version`
- `core.fact_country_indicator_published`
- annual staging resolution onto `core.dim_time`
- narrow publish procedure for the fact path only

## Intentionally not landed here
- the broader audit publication/revision table family
- marts/views built on the new published facts
- broad candidate/QA table families beyond the mapping and missingness states already carried by `staging.country_observation_annual`

## Minimal structural posture
This slice stays narrow by using the existing `staging.country_observation_annual` quality/mapping fields as the publish gate and `ref.indicator_source_priority` as the selection contract, instead of adding a larger candidate/QA surface now.
