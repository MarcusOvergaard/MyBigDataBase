#!/bin/bash
set -e

DB_NAME="${DB_NAME:-country_intel}"
PSQL_CMD="${PSQL_CMD:-psql -v ON_ERROR_STOP=1}"
QUIET_SETUP="${QUIET_SETUP:-1}"
QUIET_PGOPTIONS="${PGOPTIONS:+$PGOPTIONS }-c client_min_messages=warning"

echo "=== Initializing country_intel Database ==="

run_psql_file() {
    local file_path="$1"
    if [ "$QUIET_SETUP" = "1" ]; then
        PGOPTIONS="$QUIET_PGOPTIONS" bash -lc "$PSQL_CMD -q -d \"$DB_NAME\" -f \"$file_path\""
    else
        bash -lc "$PSQL_CMD -d \"$DB_NAME\" -f \"$file_path\""
    fi
}

run_psql_stdin() {
    if [ "$QUIET_SETUP" = "1" ]; then
        PGOPTIONS="$QUIET_PGOPTIONS" bash -lc "$PSQL_CMD -q -d \"$DB_NAME\""
    else
        bash -lc "$PSQL_CMD -d \"$DB_NAME\""
    fi
}

# 1. Create schemas for the Phase 1 contract
run_psql_file ddl/01_schemas.sql

# 2. Create Phase 1 Wave 1 reference metadata contract
run_psql_file ddl/02_ref_tables.sql

# 3. Seed Phase 1 Wave 1 metadata
run_psql_file seeds/00_ref_metadata_seeds.sql

# 4. Load canonical Phase 1 countries into ref.country

echo "Loading canonical countries into ref.country from seeds/countries.csv..."
run_psql_stdin <<EOF
    CREATE TEMP TABLE tmp_ref_countries (
        iso_alpha_2 VARCHAR(2),
        iso_alpha_3 VARCHAR(3),
        iso_numeric VARCHAR(3),
        country_name VARCHAR(100),
        region VARCHAR(100),
        income_group VARCHAR(100)
    );
    \copy tmp_ref_countries FROM 'seeds/countries.csv' WITH (FORMAT csv, HEADER true);
    INSERT INTO ref.country (
        iso_alpha_2,
        iso_alpha_3,
        iso_numeric,
        country_name,
        region_name,
        income_group,
        is_aggregate,
        is_active
    )
    SELECT iso_alpha_2, iso_alpha_3, iso_numeric, country_name, region, income_group, FALSE, TRUE
    FROM tmp_ref_countries
    ON CONFLICT (iso_alpha_3) DO UPDATE
    SET iso_alpha_2 = EXCLUDED.iso_alpha_2,
        iso_numeric = EXCLUDED.iso_numeric,
        country_name = EXCLUDED.country_name,
        region_name = EXCLUDED.region_name,
        income_group = EXCLUDED.income_group,
        is_active = TRUE;
EOF

# 4b. Apply country-specific source-priority overrides after countries exist
run_psql_file seeds/00b_indicator_source_priority_overrides.sql

# 5. Create the new Phase 1 raw layer first
run_psql_file ddl/03_raw_tables.sql

# 6. Create and seed the conformed core dimensions before staging references core.dim_time
run_psql_file ddl/05_core_dimensions.sql
run_psql_file seeds/01_core_dimension_seeds.sql
run_psql_file scripts/populate_core_time.sql

# 7. Create the Phase 1 staging contract after core.dim_time exists
run_psql_file ddl/04_staging_tables.sql

# 8. Create the first conformed core facts and audit/publication controls
run_psql_file ddl/06_core_facts.sql
run_psql_file ddl/07_audit_tables.sql

# 9. Drop mart views before canonical follow-through so reruns can safely widen dependent columns.
run_psql_stdin <<'EOF'
DROP VIEW IF EXISTS mart.dataset_pipeline_alerts CASCADE;
DROP VIEW IF EXISTS mart.dataset_pipeline_health CASCADE;
DROP VIEW IF EXISTS mart.vw_trade_external_revision_history CASCADE;
DROP VIEW IF EXISTS mart.vw_inflation_source_conflicts_latest CASCADE;
DROP VIEW IF EXISTS mart.vw_inflation_source_conflicts CASCADE;
DROP VIEW IF EXISTS mart.vw_domain_qa_summary_phase2 CASCADE;
DROP VIEW IF EXISTS mart.vw_labor_source_conflict_summary_latest CASCADE;
DROP VIEW IF EXISTS mart.vw_labor_revision_history CASCADE;
DROP VIEW IF EXISTS mart.vw_labor_source_conflicts_latest CASCADE;
DROP VIEW IF EXISTS mart.vw_labor_source_conflicts CASCADE;
DROP VIEW IF EXISTS mart.vw_macro_source_selection_lineage CASCADE;
DROP VIEW IF EXISTS mart.vw_macro_revision_history CASCADE;
DROP VIEW IF EXISTS mart.vw_macro_published_with_lineage CASCADE;
DROP VIEW IF EXISTS mart.vw_macro_coverage_gaps CASCADE;
DROP VIEW IF EXISTS mart.vw_dataset_freshness_status CASCADE;
DROP VIEW IF EXISTS mart.mart_country_phase2_latest CASCADE;
DROP VIEW IF EXISTS mart.mart_country_macro_plus_external_latest CASCADE;
DROP VIEW IF EXISTS mart.mart_country_trade_external_panel_annual CASCADE;
DROP VIEW IF EXISTS mart.mart_country_inflation_series_annual CASCADE;
DROP VIEW IF EXISTS mart.mart_country_profile_foundation CASCADE;
DROP VIEW IF EXISTS mart.mart_country_macro_series_annual CASCADE;
DROP VIEW IF EXISTS mart.mart_country_macro_latest CASCADE;
DROP VIEW IF EXISTS mart.country_latest_macro CASCADE;
EOF

# 10. Apply canonical-contract follow-through before building views that depend on those columns
run_psql_file ddl/10_canonical_contract_followthrough.sql

# 11. Create the first Phase 1 marts/views and hardening layer
run_psql_file ddl/08_marts_and_views.sql
run_psql_file ddl/09_constraints_indexes.sql

# 12. Procedures: Phase 1 raw-to-staging normalization plus Phase 1 fact publication
run_psql_file etl/03_publish_phase1.sql
run_psql_file etl/01_raw_to_staging.sql

echo "=== Database Initialization Complete ==="
