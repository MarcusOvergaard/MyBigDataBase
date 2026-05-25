#!/bin/bash
set -euo pipefail

DB_NAME="${DB_NAME:-country_intel}"
PSQL_CMD="${PSQL_CMD:-psql -v ON_ERROR_STOP=1}"
QUIET_LOADERS="${QUIET_LOADERS:-1}"

phase1_log="$(mktemp)"
ifs_log="$(mktemp)"

cleanup() {
    rm -f "$phase1_log" "$ifs_log"
}

dump_loader_logs() {
    echo "--- load_phase1_sample.sh output ---" >&2
    cat "$phase1_log" >&2 || true
    echo "--- load_ifs_sample.sh output ---" >&2
    cat "$ifs_log" >&2 || true
}

trap cleanup EXIT

fetch_contract_metrics() {
    $PSQL_CMD -d "$DB_NAME" -tA <<'SQL'
SELECT
    (SELECT COUNT(*) FROM core.fact_country_indicator_published),
    (SELECT COUNT(*) FROM mart.vw_macro_coverage_gaps),
    (
        SELECT COUNT(*)
        FROM (
            SELECT country_key, indicator_key, time_key
            FROM core.fact_country_indicator_published
            GROUP BY 1, 2, 3
            HAVING COUNT(*) > 1
        ) duplicate_keys
    );
SQL
}

IFS='|' read -r baseline_published baseline_gap_count baseline_duplicate_count < <(fetch_contract_metrics)

if [[ "$QUIET_LOADERS" == "1" ]]; then
    ./scripts/load_phase1_sample.sh >"$phase1_log" 2>&1 || {
        echo "Repeat-load regression failed: Phase 1 sample loader failed" >&2
        dump_loader_logs
        exit 1
    }

    ./scripts/load_ifs_sample.sh >"$ifs_log" 2>&1 || {
        echo "Repeat-load regression failed: IFS sample loader failed" >&2
        dump_loader_logs
        exit 1
    }
else
    ./scripts/load_phase1_sample.sh
    ./scripts/load_ifs_sample.sh
fi

IFS='|' read -r post_published post_gap_count post_duplicate_count < <(fetch_contract_metrics)

if [[ "$post_published" != "$baseline_published" ]]; then
    echo "Repeat-load regression failed: published row count changed from $baseline_published to $post_published" >&2
    exit 1
fi

if [[ "$post_gap_count" != "0" ]]; then
    echo "Repeat-load regression failed: coverage-gap view has $post_gap_count actionable rows after rerun" >&2
    exit 1
fi

if [[ "$post_duplicate_count" != "0" ]]; then
    echo "Repeat-load regression failed: found $post_duplicate_count duplicate published natural keys after rerun" >&2
    exit 1
fi

echo "Repeat-load regression passed: published=$post_published coverage_gaps=$post_gap_count duplicate_published_keys=$post_duplicate_count"
