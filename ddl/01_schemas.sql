-- Phase 1 schema contract bootstrap
-- New implementation work should land in ref/raw/staging/core/audit/mart.
-- The repo now has a single operational warehouse path built on the Phase 1 contract.

CREATE SCHEMA IF NOT EXISTS ref;
CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS core;
CREATE SCHEMA IF NOT EXISTS audit;
CREATE SCHEMA IF NOT EXISTS mart;
CREATE SCHEMA IF NOT EXISTS etl;

COMMENT ON SCHEMA ref IS 'Reference and governance metadata for the Phase 1 warehouse contract.';
COMMENT ON SCHEMA raw IS 'Append-only landing zone for source-native extracts and batch lineage.';
COMMENT ON SCHEMA staging IS 'Normalization layer for mapped and quality-checked observations before publish.';
COMMENT ON SCHEMA core IS 'Curated conformed dimensions and published/versioned warehouse facts.';
COMMENT ON SCHEMA audit IS 'Operational lineage, validation, revision, and publication audit surfaces.';
COMMENT ON SCHEMA mart IS 'Analyst-facing marts and diagnostic views built from published warehouse data.';
COMMENT ON SCHEMA etl IS 'Procedures and helper routines used by ingestion and publication jobs.';
