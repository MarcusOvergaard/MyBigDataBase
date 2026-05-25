#!/bin/bash
set -euo pipefail

DB_NAME="${DB_NAME:-country_intel}"
PSQL_CMD="${PSQL_CMD:-psql -v ON_ERROR_STOP=1}"
FETCH_HELPER="${FETCH_HELPER:-scripts/fetch_uncomtrade_snapshot.py}"
COMTRADE_REPORTER_MAP="${COMTRADE_REPORTER_MAP:-seeds/un_comtrade_reporter_codes.csv}"
COMTRADE_COUNTRIES="${COMTRADE_COUNTRIES:-}"
COMTRADE_PERIODS="${COMTRADE_PERIODS:-2019;2020;2021;2022;2023}"
COMTRADE_DATASET_CODE="${COMTRADE_DATASET_CODE:-UN_COMTRADE_ANNUAL}"
SNAPSHOT_ROOT="${SNAPSHOT_ROOT:-ingest/snapshots/un_comtrade/UN_COMTRADE_ANNUAL}"
RUN_TS="${RUN_TS:-$(date -u +%Y%m%dT%H%M%SZ)}"
BATCH_EXTERNAL_ID="${BATCH_EXTERNAL_ID:-un_comtrade_live_${RUN_TS}}"

if [[ ! -f "$FETCH_HELPER" ]]; then
    echo "Fetch helper not found: $FETCH_HELPER" >&2
    exit 1
fi

if [[ ! -f "$COMTRADE_REPORTER_MAP" ]]; then
    echo "UN Comtrade reporter map not found: $COMTRADE_REPORTER_MAP" >&2
    exit 1
fi

if [[ -z "$COMTRADE_COUNTRIES" || "${COMTRADE_COUNTRIES,,}" == "default" || "${COMTRADE_COUNTRIES,,}" == "all" ]]; then
    COMTRADE_COUNTRIES="$($PSQL_CMD -d "$DB_NAME" -Atqc "SELECT string_agg(iso_alpha_3, ';' ORDER BY iso_alpha_3) FROM ref.country WHERE is_active = TRUE AND COALESCE(is_aggregate, FALSE) = FALSE")"
fi

if [[ -z "$COMTRADE_COUNTRIES" ]]; then
    echo "No UN Comtrade countries resolved. Seed ref.country first or pass COMTRADE_COUNTRIES explicitly." >&2
    exit 1
fi

country_selection_tsv="$(mktemp)"

$PSQL_CMD -d "$DB_NAME" -AtF $'\t' <<SQL > "$country_selection_tsv"
WITH requested AS (
    SELECT unnest(string_to_array('$COMTRADE_COUNTRIES', ';')) AS iso_alpha_3
)
SELECT
    r.iso_alpha_3,
    c.country_name
FROM requested r
LEFT JOIN ref.country c
  ON c.iso_alpha_3 = r.iso_alpha_3
 AND c.is_active = TRUE
 AND COALESCE(c.is_aggregate, FALSE) = FALSE
ORDER BY r.iso_alpha_3;
SQL

COMTRADE_REPORTERS="$(python3 - "$country_selection_tsv" "$COMTRADE_REPORTER_MAP" <<'PY'
import csv, sys
selected_path, mapping_path = sys.argv[1], sys.argv[2]
selected_rows = list(csv.reader(open(selected_path, 'r', encoding='utf-8', newline=''), delimiter='\t'))
reporter_map = {}
with open(mapping_path, 'r', encoding='utf-8', newline='') as handle:
    for row in csv.DictReader(handle):
        reporter_map[row['iso_alpha_3']] = row['reporter_code']
missing_country_rows = [row[0] for row in selected_rows if len(row) < 2 or not row[1]]
if missing_country_rows:
    raise SystemExit('Missing active ref.country rows for: ' + ', '.join(missing_country_rows))
missing_reporters = [row[0] for row in selected_rows if row[0] not in reporter_map]
if missing_reporters:
    raise SystemExit('Missing UN Comtrade reporter codes for: ' + ', '.join(missing_reporters))
print(','.join(reporter_map[row[0]] for row in selected_rows))
PY
)"

mkdir -p "$SNAPSHOT_ROOT"
meta_tsv="$(mktemp)"
row_csv="$(mktemp)"
series_tsv="$(mktemp)"
manifest_path="$SNAPSHOT_ROOT/${RUN_TS}_manifest.json"
run_succeeded=0
snapshot_paths=()
cleanup() {
    local exit_code=$?
    local snapshot_count=${#snapshot_paths[@]}
    if [[ "$run_succeeded" != "1" ]]; then
        for snapshot_path in "${snapshot_paths[@]}"; do
            [[ -n "$snapshot_path" ]] && rm -f "$snapshot_path"
        done
        rm -f "$manifest_path"
        if [[ $snapshot_count -gt 0 ]]; then
            echo "Cleaned up incomplete UN Comtrade snapshot run: $RUN_TS" >&2
        fi
    fi
    rm -f "$meta_tsv" "$row_csv" "$series_tsv" "$country_selection_tsv"
    return $exit_code
}
trap cleanup EXIT

$PSQL_CMD -d "$DB_NAME" -AtF $'\t' <<SQL > "$series_tsv"
SELECT DISTINCT
    ssa.alias_code AS flow_code,
    rs.series_code,
    rs.series_name
FROM ref.source_dataset d
JOIN ref.source_series rs
  ON rs.source_dataset_key = d.source_dataset_key
 AND rs.is_active = TRUE
JOIN ref.indicator_source_series_map ism
  ON ism.source_series_key = rs.source_series_key
 AND ism.is_active = TRUE
JOIN ref.source_series_alias ssa
  ON ssa.source_series_key = rs.source_series_key
 AND ssa.alias_type = 'uncomtrade_flow_code'
 AND ssa.is_active = TRUE
WHERE d.dataset_code = '$COMTRADE_DATASET_CODE'
ORDER BY ssa.alias_code;
SQL

if [[ ! -s "$series_tsv" ]]; then
    echo "No active UN Comtrade flow-code mappings found for dataset $COMTRADE_DATASET_CODE" >&2
    exit 1
fi

tradeflows="$(python3 - "$series_tsv" <<'PY'
import csv, sys
with open(sys.argv[1], 'r', encoding='utf-8', newline='') as handle:
    reader = csv.reader(handle, delimiter='\t')
    print(','.join(row[0].lower() for row in reader if row and row[0]))
PY
)"

printf 'snapshot_path\tcontent_type\tfile_hash_sha256\tfetched_at\thttp_status_code\tsource_url\tperiod\n' > "$meta_tsv"

write_meta_row() {
    local meta_json="$1"
    META_JSON="$meta_json" python3 - "$meta_tsv" <<'PY'
import json, os, sys
meta = json.loads(os.environ['META_JSON'])
fields = [
    meta['output_path'],
    meta.get('content_type', ''),
    meta.get('file_hash_sha256', ''),
    meta.get('fetched_at', ''),
    str(meta.get('http_status_code', '')),
    meta.get('final_url') or meta.get('requested_url', ''),
    meta.get('period', ''),
]
with open(sys.argv[1], 'a', encoding='utf-8') as handle:
    handle.write('\t'.join(value.replace('\t', ' ').replace('\n', ' ') for value in fields) + '\n')
PY
}

IFS=';' read -r -a periods <<< "$COMTRADE_PERIODS"
for period in "${periods[@]}"; do
    [[ -z "$period" ]] && continue
    snapshot_path="$SNAPSHOT_ROOT/${RUN_TS}_${period}.json"
    echo "Fetching UN Comtrade annual totals for ${period}..."
    meta_json="$(python3 "$FETCH_HELPER" --period "$period" --reporters "$COMTRADE_REPORTERS" --tradeflows "$tradeflows" --output "$snapshot_path")"
    write_meta_row "$meta_json"
    snapshot_paths+=("$snapshot_path")
done

python3 - "$row_csv" "$series_tsv" "$COMTRADE_COUNTRIES" "${snapshot_paths[@]}" <<'PY'
import csv
import json
import sys
from pathlib import Path

out_path = Path(sys.argv[1])
series_tsv = Path(sys.argv[2])
country_filter_arg = sys.argv[3]
snapshot_paths = [Path(p) for p in sys.argv[4:]]
allowed = {code.strip().upper() for code in country_filter_arg.split(';') if code.strip() and country_filter_arg.lower() != 'all'}
flow_map = {}
with series_tsv.open('r', encoding='utf-8', newline='') as handle:
    reader = csv.reader(handle, delimiter='\t')
    for flow_code, series_code, series_name in reader:
        flow_map[flow_code.upper()] = {'series_code': series_code, 'series_name': series_name}

fieldnames = [
    'country_code','country_name','indicator_code','indicator_name','year','value','obs_status','decimal','snapshot_path',
    'reporter_code','flow_code','partner_code','partner_iso','partner_desc','commodity_code','commodity_desc','customs_code','mot_code'
]
with out_path.open('w', newline='', encoding='utf-8') as handle:
    writer = csv.DictWriter(handle, fieldnames=fieldnames)
    writer.writeheader()
    for snapshot_path in snapshot_paths:
        payload = json.loads(snapshot_path.read_text(encoding='utf-8'))
        for row in payload.get('data', []):
            reporter = (row.get('reporterISO') or '').upper()
            if allowed and reporter not in allowed:
                continue
            flow = (row.get('flowCode') or '').upper()
            if flow not in flow_map:
                continue
            meta = flow_map[flow]
            writer.writerow({
                'country_code': reporter,
                'country_name': row.get('reporterDesc', '') or '',
                'indicator_code': meta['series_code'],
                'indicator_name': meta['series_name'],
                'year': row.get('period', ''),
                'value': '' if row.get('primaryValue') is None else str(row.get('primaryValue')),
                'obs_status': '',
                'decimal': '',
                'snapshot_path': str(snapshot_path.resolve()),
                'reporter_code': '' if row.get('reporterCode') is None else str(row.get('reporterCode')),
                'flow_code': flow,
                'partner_code': '' if row.get('partnerCode') is None else str(row.get('partnerCode')),
                'partner_iso': row.get('partnerISO', '') or '',
                'partner_desc': row.get('partnerDesc', '') or '',
                'commodity_code': row.get('cmdCode', '') or '',
                'commodity_desc': row.get('cmdDesc', '') or '',
                'customs_code': row.get('customsCode', '') or '',
                'mot_code': '' if row.get('motCode') is None else str(row.get('motCode')),
            })
PY

row_count_reported="$(python3 - "$row_csv" <<'PY'
import csv, sys
with open(sys.argv[1], newline='', encoding='utf-8') as handle:
    print(sum(1 for _ in csv.DictReader(handle)))
PY
)"

META_TSV="$meta_tsv" ROW_CSV="$row_csv" MANIFEST_PATH="$manifest_path" RUN_TS="$RUN_TS" BATCH_EXTERNAL_ID="$BATCH_EXTERNAL_ID" COMTRADE_COUNTRIES="$COMTRADE_COUNTRIES" COMTRADE_REPORTERS="$COMTRADE_REPORTERS" COMTRADE_PERIODS="$COMTRADE_PERIODS" COMTRADE_DATASET_CODE="$COMTRADE_DATASET_CODE" SNAPSHOT_ROOT="$SNAPSHOT_ROOT" SERIES_TSV="$series_tsv" python3 - <<'PY'
import csv, json, os
from pathlib import Path
meta_tsv = Path(os.environ['META_TSV'])
row_csv = Path(os.environ['ROW_CSV'])
manifest_path = Path(os.environ['MANIFEST_PATH'])
series_tsv = Path(os.environ['SERIES_TSV'])
with meta_tsv.open('r', encoding='utf-8', newline='') as handle:
    snapshots = list(csv.DictReader(handle, delimiter='\t'))
with row_csv.open('r', encoding='utf-8', newline='') as handle:
    rows = list(csv.DictReader(handle))
series = []
with series_tsv.open('r', encoding='utf-8', newline='') as handle:
    for flow_code, series_code, series_name in csv.reader(handle, delimiter='\t'):
        series.append({'flow_code': flow_code, 'source_series_code': series_code, 'series_name': series_name})
manifest = {
    'run_ts': os.environ['RUN_TS'],
    'batch_external_id': os.environ['BATCH_EXTERNAL_ID'],
    'dataset_code': os.environ['COMTRADE_DATASET_CODE'],
    'countries': [code for code in os.environ['COMTRADE_COUNTRIES'].split(';') if code],
    'reporter_codes': [code for code in os.environ['COMTRADE_REPORTERS'].split(',') if code],
    'periods': [period for period in os.environ['COMTRADE_PERIODS'].split(';') if period],
    'snapshot_root': os.environ['SNAPSHOT_ROOT'],
    'snapshot_count': len(snapshots),
    'row_count_reported': len(rows),
    'series': series,
    'snapshots': snapshots,
}
manifest_path.write_text(json.dumps(manifest, indent=2), encoding='utf-8')
PY

source_series_codes_json="$(python3 - "$series_tsv" <<'PY'
import csv, json, sys
with open(sys.argv[1], 'r', encoding='utf-8', newline='') as handle:
    print(json.dumps([row[1] for row in csv.reader(handle, delimiter='\t')]))
PY
)"
flow_codes_json="$(python3 - "$series_tsv" <<'PY'
import csv, json, sys
with open(sys.argv[1], 'r', encoding='utf-8', newline='') as handle:
    print(json.dumps([row[0] for row in csv.reader(handle, delimiter='\t')]))
PY
)"
periods_json="$(python3 - "$COMTRADE_PERIODS" <<'PY'
import json, sys
print(json.dumps([p for p in sys.argv[1].split(';') if p]))
PY
)"

export BATCH_EXTERNAL_ID COMTRADE_COUNTRIES COMTRADE_REPORTERS COMTRADE_PERIODS COMTRADE_DATASET_CODE SNAPSHOT_ROOT row_count_reported meta_tsv row_csv source_series_codes_json flow_codes_json periods_json tradeflows

echo "=== Loading live UN Comtrade slice into $DB_NAME ==="

$PSQL_CMD -d "$DB_NAME" <<SQL
CREATE TEMP TABLE tmp_un_comtrade_snapshot_meta (
    snapshot_path TEXT,
    content_type TEXT,
    file_hash_sha256 TEXT,
    fetched_at TIMESTAMPTZ,
    http_status_code INT,
    source_url TEXT,
    period TEXT
);

\copy tmp_un_comtrade_snapshot_meta FROM '$meta_tsv' WITH (FORMAT csv, DELIMITER E'\t', HEADER true);

CREATE TEMP TABLE tmp_un_comtrade_live_rows (
    country_code TEXT,
    country_name TEXT,
    indicator_code TEXT,
    indicator_name TEXT,
    year TEXT,
    value TEXT,
    obs_status TEXT,
    decimal TEXT,
    snapshot_path TEXT,
    reporter_code TEXT,
    flow_code TEXT,
    partner_code TEXT,
    partner_iso TEXT,
    partner_desc TEXT,
    commodity_code TEXT,
    commodity_desc TEXT,
    customs_code TEXT,
    mot_code TEXT
);

\copy tmp_un_comtrade_live_rows FROM '$row_csv' WITH (FORMAT csv, HEADER true);

WITH inserted_batch AS (
    INSERT INTO raw.source_batch (
        source_dataset_key,
        batch_external_id,
        request_uri,
        request_params_json,
        fetched_at,
        source_released_at,
        ingest_status,
        row_count_reported
    )
    SELECT
        d.source_dataset_key,
        '$BATCH_EXTERNAL_ID',
        d.ingest_base_endpoint,
        jsonb_build_object(
            'loader', 'scripts/load_un_comtrade_live.sh',
            'countries', '$COMTRADE_COUNTRIES',
            'periods', '$periods_json'::jsonb,
            'dataset_code', '$COMTRADE_DATASET_CODE',
            'snapshot_root', '$SNAPSHOT_ROOT',
            'selected_reporters', '$COMTRADE_REPORTERS',
            'selected_reporter_iso3', '$COMTRADE_COUNTRIES',
            'selected_partner', '0',
            'selected_tradeflows', '$tradeflows',
            'selected_commodity_code', 'total',
            'selected_customs_code', 'c00',
            'selected_transport_code', '0',
            'source_series_codes', '$source_series_codes_json'::jsonb,
            'flow_codes', '$flow_codes_json'::jsonb
        ),
        COALESCE((SELECT MAX(fetched_at) FROM tmp_un_comtrade_snapshot_meta), CURRENT_TIMESTAMP),
        COALESCE((SELECT MAX(fetched_at) FROM tmp_un_comtrade_snapshot_meta), CURRENT_TIMESTAMP),
        'queued',
        $row_count_reported
    FROM ref.source_dataset d
    WHERE d.dataset_code = '$COMTRADE_DATASET_CODE'
    RETURNING source_batch_key
)
SELECT source_batch_key FROM inserted_batch \gset

INSERT INTO raw.source_snapshot (
    source_batch_key,
    snapshot_path,
    content_type,
    file_hash_sha256,
    fetched_at,
    http_status_code,
    source_url
)
SELECT
    :source_batch_key,
    snapshot_path,
    NULLIF(content_type, ''),
    NULLIF(file_hash_sha256, ''),
    fetched_at,
    http_status_code,
    NULLIF(source_url, '')
FROM tmp_un_comtrade_snapshot_meta
ON CONFLICT (snapshot_path) DO NOTHING;

INSERT INTO raw.un_comtrade_country_indicator_annual (
    source_batch_key,
    country_code_raw,
    country_name_raw,
    indicator_code_raw,
    indicator_name_raw,
    year_raw,
    value_raw,
    obs_status_raw,
    decimal_raw,
    source_payload_json
)
SELECT
    :source_batch_key,
    country_code,
    NULLIF(country_name, ''),
    indicator_code,
    indicator_name,
    year,
    NULLIF(value, ''),
    NULL,
    NULL,
    jsonb_build_object(
        'loader', 'scripts/load_un_comtrade_live.sh',
        'snapshot_path', snapshot_path,
        'ingestion_type', 'live_api_snapshot',
        'reporter_code', NULLIF(reporter_code, ''),
        'flow_code', NULLIF(flow_code, ''),
        'partner_code', NULLIF(partner_code, ''),
        'partner_iso', NULLIF(partner_iso, ''),
        'partner_desc', NULLIF(partner_desc, ''),
        'commodity_code', NULLIF(commodity_code, ''),
        'commodity_desc', NULLIF(commodity_desc, ''),
        'customs_code', NULLIF(customs_code, ''),
        'mot_code', NULLIF(mot_code, '')
    )
FROM tmp_un_comtrade_live_rows;

UPDATE raw.source_batch
SET row_count_reported = (
        SELECT COUNT(*)
        FROM raw.un_comtrade_country_indicator_annual
        WHERE source_batch_key = :source_batch_key
    ),
    ingest_status = 'loaded'
WHERE source_batch_key = :source_batch_key;

CALL staging.normalize_country_observation_annual(:source_batch_key);

UPDATE raw.source_batch
SET ingest_status = 'normalized'
WHERE source_batch_key = :source_batch_key;

CALL etl.publish_phase1_country_indicator_facts(:source_batch_key);
SQL

run_succeeded=1

echo "=== Live UN Comtrade load complete ==="
