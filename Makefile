# Makefile for country_intel project

DB_NAME ?= country_intel
DB_HOST ?= /var/run/postgresql
DB_PORT ?= 5433
DB_USER ?= marcusai
PSQL_BASE = psql -h $(DB_HOST) -p $(DB_PORT) -U $(DB_USER) -v ON_ERROR_STOP=1
PSQL = $(PSQL_BASE) -d $(DB_NAME)

export DB_NAME
export PSQL_CMD = $(PSQL_BASE)

.PHONY: init create-db ddl seed load-sample load-wdi-live load-wdi-labor-live load-ifs-live load-weo-live load-ilostat-live load-un-comtrade-live clean-ifs-stale-snapshots build-mart test check-alerts test-live-wdi-contract test-live-wdi-labor-contract test-live-ifs-contract test-live-weo-contract test-live-ilostat-contract test-live-un-comtrade-contract test-live-contracts test-live-contracts-offline test-phase2-starter-marts-offline test-phase2-starter-marts-debug repeat-load-test all

all: init

# Create the database if it doesn't exist
create-db:
	@echo "Creating database $(DB_NAME)..."
	@$(PSQL_BASE) -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname = '$(DB_NAME)'" | grep -q 1 || createdb -h $(DB_HOST) -p $(DB_PORT) -U $(DB_USER) $(DB_NAME)

# Initialize schema and load metadata
init: create-db
	@chmod +x scripts/setup_db.sh
	@./scripts/setup_db.sh

# Load sample data through the Phase 1 raw -> staging -> core -> audit -> mart path
load-sample:
	@chmod +x scripts/load_phase1_sample.sh
	@./scripts/load_phase1_sample.sh
	@chmod +x scripts/load_ifs_sample.sh
	@./scripts/load_ifs_sample.sh

# Load a narrow live WDI slice through the same Phase 1 contract
load-wdi-live:
	@chmod +x scripts/load_wdi_live.sh
	@./scripts/load_wdi_live.sh

# Load a narrow live WDI labor overlap slice through the same Phase 1 contract
load-wdi-labor-live:
	@chmod +x scripts/load_wdi_labor_live.sh
	@./scripts/load_wdi_labor_live.sh

# Load a narrow live IFS slice through the same Phase 1 contract
load-ifs-live:
	@chmod +x scripts/load_ifs_live.sh
	@./scripts/load_ifs_live.sh

# Load a narrow live WEO external-balance slice through the same warehouse contract
load-weo-live:
	@chmod +x scripts/load_weo_live.sh
	@./scripts/load_weo_live.sh

# Load a narrow live ILOSTAT unemployment slice through the same warehouse contract
load-ilostat-live:
	@chmod +x scripts/load_ilostat_live.sh
	@./scripts/load_ilostat_live.sh

# Load narrow live UN Comtrade exports/imports slices through the same warehouse contract
load-un-comtrade-live:
	@chmod +x scripts/load_un_comtrade_live.sh
	@./scripts/load_un_comtrade_live.sh

# Remove IFS snapshot files not referenced by any successful manifest
clean-ifs-stale-snapshots:
	@chmod +x scripts/cleanup_ifs_snapshots.py
	@python3 scripts/cleanup_ifs_snapshots.py


# Refresh/Build the Phase 1 marts and diagnostic views
build-mart:
	@echo "Updating Phase 1 mart/view DDL..."
	@if [ "$${QUIET_DDL:-1}" = "1" ]; then \
		PGOPTIONS="$${PGOPTIONS:+$$PGOPTIONS }-c client_min_messages=warning" $(PSQL) -q -f ddl/08_marts_and_views.sql; \
	else \
		$(PSQL) -f ddl/08_marts_and_views.sql; \
	fi


# Run Phase 1 validation queries
test:
	@echo "Running Phase 1 validation queries..."
	@$(PSQL) -f queries/test_queries.sql

# Fail if any dataset-level pipeline alerts are present
check-alerts:
	@chmod +x scripts/check_pipeline_alerts.sh
	@./scripts/check_pipeline_alerts.sh

# Re-run the live WDI backbone slice and assert lineage/publication fields stay intact
# Override FETCH_HELPER for offline fixture-backed runs if needed.
test-live-wdi-contract:
	@chmod +x scripts/test_live_wdi_contract.sh
	@./scripts/test_live_wdi_contract.sh

# Re-run the live WDI labor overlap slice and assert lineage/normalization fields stay intact
# Override FETCH_HELPER for offline fixture-backed runs if needed.
test-live-wdi-labor-contract:
	@chmod +x scripts/test_live_wdi_labor_contract.sh
	@./scripts/test_live_wdi_labor_contract.sh

# Re-run the live IFS macro arbitration slice and assert lineage/arbitration fields stay intact
# Covers both inflation and GDP overlap proofs. Override FETCH_HELPER for offline fixture-backed runs if needed.
test-live-ifs-contract:
	@chmod +x scripts/test_live_ifs_inflation_contract.sh
	@./scripts/test_live_ifs_inflation_contract.sh

# Re-run the live WEO external-balance slice and assert lineage/publication fields stay intact
# Override FETCH_HELPER for offline fixture-backed runs if needed.
test-live-weo-contract:
	@chmod +x scripts/test_live_weo_external_balance_contract.sh
	@./scripts/test_live_weo_external_balance_contract.sh

# Re-run the live ILOSTAT labor slice and assert lineage/publication fields stay intact
# Override FETCH_HELPER for offline fixture-backed runs if needed.
test-live-ilostat-contract:
	@chmod +x scripts/test_live_ilostat_labor_contract.sh
	@./scripts/test_live_ilostat_labor_contract.sh

# Re-run the live UN Comtrade exports/imports slice and assert lineage/publication fields stay intact
# Override FETCH_HELPER for offline fixture-backed runs if needed.
test-live-un-comtrade-contract:
	@chmod +x scripts/test_live_un_comtrade_contract.sh
	@./scripts/test_live_un_comtrade_contract.sh

# Re-run all live contract checks in one shot
# Override FETCH_HELPER for offline fixture-backed runs if needed.
test-live-contracts: test-live-wdi-contract test-live-wdi-labor-contract test-live-ifs-contract test-live-weo-contract test-live-ilostat-contract test-live-un-comtrade-contract

# Re-run all live contract checks against local fixtures instead of external APIs
test-live-contracts-offline:
	@FETCH_HELPER=scripts/mock_fetch_wdi_snapshot.py ./scripts/test_live_wdi_contract.sh
	@FETCH_HELPER=scripts/mock_fetch_wdi_labor_snapshot.py ./scripts/test_live_wdi_labor_contract.sh
	@FETCH_HELPER=scripts/mock_fetch_ifs_snapshot.py ./scripts/test_live_ifs_inflation_contract.sh
	@FETCH_HELPER=scripts/mock_fetch_weo_snapshot.py ./scripts/test_live_weo_external_balance_contract.sh
	@FETCH_HELPER=scripts/mock_fetch_ilostat_snapshot.py ./scripts/test_live_ilostat_labor_contract.sh
	@FETCH_HELPER=scripts/mock_fetch_uncomtrade_snapshot.py ./scripts/test_live_un_comtrade_contract.sh

# Assert the first analyst-facing Phase 2 labor/trade marts after the offline live-contract suite
test-phase2-starter-marts-offline:
	@echo "Running Phase 2 starter mart regression queries..."
	@$(PSQL) -f queries/test_phase2_starter_marts.sql

# Re-run the Phase 2 starter mart regression with verbose debug result sets enabled
test-phase2-starter-marts-debug:
	@echo "Running Phase 2 starter mart regression queries in verbose debug mode..."
	@$(PSQL) -v PHASE2_VERBOSE=1 -f queries/test_phase2_starter_marts.sql

# Re-run the sample loaders and assert the published contract stays stable
repeat-load-test:
	@chmod +x scripts/test_repeat_load_regression.sh
	@./scripts/test_repeat_load_regression.sh
