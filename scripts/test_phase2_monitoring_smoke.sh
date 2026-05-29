#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mock_dir="$(mktemp -d)"
mock_psql="$mock_dir/mock_psql.sh"

cleanup() {
    rm -rf "$mock_dir"
}

trap cleanup EXIT

cat >"$mock_psql" <<'MOCK'
#!/bin/bash
set -euo pipefail

sql="$(cat)"
mode="${PHASE2_MONITORING_FIXTURE_MODE:-healthy}"

if [[ "$sql" == *"FROM mart.vw_phase2_dataset_operator_panel_scan;"* && "$sql" == *"datasets="* ]]; then
    if [[ "$mode" == "alert" ]]; then
        printf 'datasets=4 | failing=1 | warning=1 | healthy=2\n'
    else
        printf 'datasets=4 | failing=0 | warning=1 | healthy=3\n'
    fi
elif [[ "$sql" == *"FROM mart.vw_phase2_dataset_operator_panel_scan"* && "$sql" == *"ORDER BY operator_attention_rank, dataset_code;"* ]]; then
    cat <<'EOF'
 dataset_code | operator_panel_status  | operator_attention_rank | freshness_status | latest_publish_status | latest_indicator_coverage_ratio | latest_country_coverage_ratio | latest_gap_indicator_codes | missing_country_indicator_count | dominant_gap_stage | dominant_gap_status
--------------+------------------------+-------------------------+------------------+-----------------------+---------------------------------+-------------------------------+----------------------------+-------------------------------+--------------------+--------------------
 IFS          | warning_coverage_gap   |                       1 | fresh            | published             |                         0.9700  |                        1.0000 | CPI                        |                             0 | coverage           | warning
 WDI          | healthy                |                       2 | fresh            | published             |                         1.0000  |                        1.0000 |                            |                             0 | -                  | -
EOF
    if [[ "$mode" == "alert" ]]; then
        cat <<'EOF'
 ILOSTAT      | failing_active_gap     |                       3 | stale            | failed                |                         0.6400  |                        0.5000 | SL.UEM.TOTL.ZS            |                             6 | publication        | failed
EOF
    fi
elif [[ "$sql" == *"FROM mart.vw_phase2_dataset_status_history_scan"* && "$sql" == *"WHERE is_latest_batch_for_dataset = TRUE"* ]]; then
    cat <<'EOF'
 dataset_code | batch_status | batch_status_rank | publish_status | indicator_coverage_ratio | country_indicator_pair_coverage_ratio | pair_coverage_trend_vs_prior_batch | latest_phase2_observation_year_in_batch |      published_at
--------------+--------------+-------------------+----------------+--------------------------+----------------------------------------+------------------------------------+-----------------------------------------+------------------------
 WDI          | healthy      |                 1 | published      |                   1.0000 |                                 1.0000 |                            0.0000  |                                    2023 | 2026-05-28 01:00:00+00
EOF
elif [[ "$sql" == *"failing_active_gap="* && "$sql" == *"pipeline_alerts="* ]]; then
    if [[ "$mode" == "alert" ]]; then
        printf 'failing_active_gap=1 | pipeline_alerts=2\n'
    else
        printf 'failing_active_gap=0 | pipeline_alerts=0\n'
    fi
elif [[ "$sql" == *"WHERE operator_panel_status = 'failing_active_gap'"* && "$sql" == *"COUNT(*)"* ]]; then
    if [[ "$mode" == "alert" ]]; then
        printf '1\n'
    else
        printf '0\n'
    fi
elif [[ "$sql" == *"SELECT COUNT(*)"* && "$sql" == *"FROM mart.dataset_pipeline_alerts;"* ]]; then
    if [[ "$mode" == "alert" ]]; then
        printf '2\n'
    else
        printf '0\n'
    fi
elif [[ "$sql" == *"FROM mart.dataset_pipeline_alerts"* && "$sql" == *"ORDER BY"* ]]; then
    cat <<'EOF'
 dataset_code | alert_severity |              alert_code               | latest_batch_ingest_status | latest_pipeline_status | latest_publish_status | failed_source_batch_count_7d |     last_error_at
--------------+----------------+---------------------------------------+----------------------------+------------------------+-----------------------+------------------------------+------------------------
 ILOSTAT      | critical       | latest_pipeline_run_not_successful    | succeeded                  | failed                 | failed                |                            1 | 2026-05-28 02:00:00+00
 ILOSTAT      | high           | blocking_qa_events_in_latest_publish  | succeeded                  | failed                 | failed                |                            1 | 2026-05-28 02:00:00+00
EOF
elif [[ "$sql" == *"FROM mart.vw_phase2_dataset_operator_panel_scan"* && "$sql" == *"affected_country_iso_alpha_3_codes"* ]]; then
    cat <<'EOF'
 dataset_code | operator_panel_status | missing_country_indicator_count | dominant_gap_stage | dominant_gap_status | affected_country_iso_alpha_3_codes | affected_indicator_codes
--------------+-----------------------+---------------------------------+--------------------+---------------------+------------------------------------+-------------------------
 ILOSTAT      | failing_active_gap    |                               6 | publication        | failed              | CHN,DEU                            | SL.UEM.TOTL.ZS
EOF
else
    printf 'Unhandled mock SQL:\n%s\n' "$sql" >&2
    exit 1
fi
MOCK

chmod +x "$mock_psql"

assert_contains() {
    local haystack="$1"
    local needle="$2"
    if [[ "$haystack" != *"$needle"* ]]; then
        echo "Phase 2 monitoring smoke test failed: expected output to contain '$needle'" >&2
        echo "--- output ---" >&2
        printf '%s\n' "$haystack" >&2
        exit 1
    fi
}

report_output="$(PHASE2_MONITORING_FIXTURE_MODE=alert DB_NAME=country_intel PSQL_CMD="$mock_psql" "$repo_root/scripts/report_phase2_operator_scan.sh")"
assert_contains "$report_output" "Phase 2 operator report |"
assert_contains "$report_output" "datasets=4 | failing=1 | warning=1 | healthy=2"
assert_contains "$report_output" "Dataset operator scan"
assert_contains "$report_output" "Latest batch per dataset"
assert_contains "$report_output" "Pipeline alerts: 2"
assert_contains "$report_output" "ILOSTAT"
assert_contains "$report_output" "latest_pipeline_run_not_successful"

healthy_watchdog_output="$(PHASE2_MONITORING_FIXTURE_MODE=healthy DB_NAME=country_intel PSQL_CMD="$mock_psql" "$repo_root/scripts/check_phase2_operator_watchdog.sh")"
if [[ -n "$healthy_watchdog_output" ]]; then
    echo "Phase 2 monitoring smoke test failed: healthy watchdog should stay silent" >&2
    echo "--- output ---" >&2
    printf '%s\n' "$healthy_watchdog_output" >&2
    exit 1
fi

alert_watchdog_output="$(PHASE2_MONITORING_FIXTURE_MODE=alert DB_NAME=country_intel PSQL_CMD="$mock_psql" "$repo_root/scripts/check_phase2_operator_watchdog.sh")"
assert_contains "$alert_watchdog_output" "Phase 2 watchdog alert |"
assert_contains "$alert_watchdog_output" "failing_active_gap=1 | pipeline_alerts=2"
assert_contains "$alert_watchdog_output" "Datasets with failing active gaps"
assert_contains "$alert_watchdog_output" "Active pipeline alerts"
assert_contains "$alert_watchdog_output" "ILOSTAT"

echo "Phase 2 monitoring smoke test passed: report path, silent healthy watchdog, and alert watchdog all behaved as expected"
