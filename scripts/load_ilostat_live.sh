#!/bin/bash
set -euo pipefail

DB_NAME="${DB_NAME:-country_intel}"
PSQL_CMD="${PSQL_CMD:-psql -v ON_ERROR_STOP=1}"
FETCH_HELPER="${FETCH_HELPER:-scripts/fetch_http_to_snapshot.py}"
ILOSTAT_COUNTRIES="${ILOSTAT_COUNTRIES:-}"
ILOSTAT_TIMEFROM="${ILOSTAT_TIMEFROM:-2019}"
ILOSTAT_TIMETO="${ILOSTAT_TIMETO:-2023}"
ILOSTAT_DATASET_CODE="${ILOSTAT_DATASET_CODE:-ILOSTAT}"
SNAPSHOT_ROOT="${SNAPSHOT_ROOT:-ingest/snapshots/ilostat/ILOSTAT}"
RUN_TS="${RUN_TS:-$(date -u +%Y%m%dT%H%M%SZ)}"
BATCH_EXTERNAL_ID="${BATCH_EXTERNAL_ID:-ilostat_live_${RUN_TS}}"
ILOSTAT_API_BASE="${ILOSTAT_API_BASE:-https://rplumber.ilo.org/data/indicator}"

if [[ ! -f "$FETCH_HELPER" ]]; then
    echo "Fetch helper not found: $FETCH_HELPER" >&2
    exit 1
fi

if [[ -z "$ILOSTAT_COUNTRIES" || "${ILOSTAT_COUNTRIES,,}" == "default" || "${ILOSTAT_COUNTRIES,,}" == "all" ]]; then
    ILOSTAT_COUNTRIES="$($PSQL_CMD -d "$DB_NAME" -Atqc "SELECT string_agg(iso_alpha_3, ';' ORDER BY iso_alpha_3) FROM ref.country WHERE is_active = TRUE AND COALESCE(is_aggregate, FALSE) = FALSE")"
fi

if [[ -z "$ILOSTAT_COUNTRIES" ]]; then
    echo "No ILOSTAT countries resolved. Seed ref.country first or pass ILOSTAT_COUNTRIES explicitly." >&2
    exit 1
fi

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
            echo "Cleaned up incomplete ILOSTAT snapshot run: $RUN_TS" >&2
        fi
    fi
    rm -f "$meta_tsv" "$row_csv" "$series_tsv"
    return $exit_code
}
trap cleanup EXIT

$PSQL_CMD -d "$DB_NAME" -AtF $'\t' <<SQL > "$series_tsv"
SELECT DISTINCT
    ssa.alias_code AS request_signature,
    rs.series_code AS source_series_code,
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
 AND ssa.alias_type = 'ilo_indicator_request'
 AND ssa.is_active = TRUE
WHERE d.dataset_code = '$ILOSTAT_DATASET_CODE'
ORDER BY rs.series_code;
SQL

if [[ ! -s "$series_tsv" ]]; then
    echo "No active ILOSTAT source-series request mappings found for dataset $ILOSTAT_DATASET_CODE" >&2
    exit 1
fi

printf 'snapshot_path\tcontent_type\tfile_hash_sha256\tfetched_at\thttp_status_code\tsource_url\n' > "$meta_tsv"

write_meta_row() {
    local meta_json="$1"
    META_JSON="$meta_json" python3 - "$meta_tsv" <<'PY'
import json
import os
import sys
from pathlib import Path
meta = json.loads(os.environ['META_JSON'])
out = Path(sys.argv[1])
fields = [
    meta['output_path'],
    meta.get('content_type', ''),
    meta.get('file_hash_sha256', ''),
    meta.get('fetched_at', ''),
    str(meta.get('http_status_code', '')),
    meta.get('final_url') or meta.get('requested_url', ''),
]
with out.open('a', encoding='utf-8') as handle:
    handle.write('\t'.join(value.replace('\t', ' ').replace('\n', ' ') for value in fields) + '\n')
PY
}

COUNTRY_PARAM="$(printf '%s' "$ILOSTAT_COUNTRIES" | tr ';' '+')"

while IFS=$'\t' read -r request_signature source_series_code series_name; do
    [[ -z "$request_signature" ]] && continue
    IFS='|' read -r indicator_id sex_code classif1_code <<< "$request_signature"
    if [[ -z "${indicator_id:-}" || -z "${sex_code:-}" || -z "${classif1_code:-}" ]]; then
        echo "Invalid ILOSTAT request signature for $source_series_code: $request_signature" >&2
        exit 1
    fi

    snapshot_path="$SNAPSHOT_ROOT/${RUN_TS}_${source_series_code}.json"
    url="$ILOSTAT_API_BASE?id=${indicator_id}&ref_area=${COUNTRY_PARAM}&sex=${sex_code}&classif1=${classif1_code}&timefrom=${ILOSTAT_TIMEFROM}&timeto=${ILOSTAT_TIMETO}&format=json"

    echo "Fetching ILOSTAT ${source_series_code}..."
    meta_json="$(python3 "$FETCH_HELPER" --user-agent 'Mozilla/5.0' --url "$url" --output "$snapshot_path")"
    write_meta_row "$meta_json"
    snapshot_paths+=("$snapshot_path")
done < "$series_tsv"

python3 - "$row_csv" "$series_tsv" "${snapshot_paths[@]}" <<'PY'
import csv
import json
import sys
from pathlib import Path

out_path = Path(sys.argv[1])
series_tsv = Path(sys.argv[2])
snapshot_paths = [Path(p) for p in sys.argv[3:]]
series_lookup = {}
with series_tsv.open('r', encoding='utf-8', newline='') as handle:
    reader = csv.reader(handle, delimiter='\t')
    for request_signature, source_series_code, series_name in reader:
        indicator_id, sex_code, classif1_code = request_signature.split('|')
        series_lookup[source_series_code] = {
            'request_signature': request_signature,
            'indicator_id': indicator_id,
            'sex_code': sex_code,
            'classif1_code': classif1_code,
            'series_name': series_name,
        }

fieldnames = [
    'country_code',
    'country_name',
    'indicator_code',
    'indicator_name',
    'year',
    'value',
    'obs_status',
    'decimal',
    'snapshot_path',
    'api_indicator_id',
    'sex',
    'classif1',
    'source_code',
    'note_source',
]

with out_path.open('w', newline='', encoding='utf-8') as handle:
    writer = csv.DictWriter(handle, fieldnames=fieldnames)
    writer.writeheader()
    for snapshot_path in snapshot_paths:
        source_series_code = snapshot_path.stem.split('_', 1)[1]
        meta = series_lookup[source_series_code]
        with snapshot_path.open('r', encoding='utf-8') as source_handle:
            payload = json.load(source_handle)
        for row in payload:
            writer.writerow({
                'country_code': row.get('ref_area', ''),
                'country_name': '',
                'indicator_code': source_series_code,
                'indicator_name': meta['series_name'],
                'year': row.get('time', ''),
                'value': '' if row.get('obs_value') is None else str(row.get('obs_value')),
                'obs_status': row.get('obs_status', '') or '',
                'decimal': '',
                'snapshot_path': str(snapshot_path.resolve()),
                'api_indicator_id': meta['indicator_id'],
                'sex': row.get('sex', '') or meta['sex_code'],
                'classif1': row.get('classif1', '') or meta['classif1_code'],
                'source_code': row.get('source', '') or '',
                'note_source': row.get('note_source', '') or '',
            })
PY

row_count_reported="$(python3 - "$row_csv" <<'PY'
import csv
import sys
with open(sys.argv[1], newline='', encoding='utf-8') as handle:
    print(sum(1 for _ in csv.DictReader(handle)))
PY
)"

META_TSV="$meta_tsv" \
ROW_CSV="$row_csv" \
MANIFEST_PATH="$manifest_path" \
RUN_TS="$RUN_TS" \
BATCH_EXTERNAL_ID="$BATCH_EXTERNAL_ID" \
ILOSTAT_COUNTRIES="$ILOSTAT_COUNTRIES" \
ILOSTAT_TIMEFROM="$ILOSTAT_TIMEFROM" \
ILOSTAT_TIMETO="$ILOSTAT_TIMETO" \
ILOSTAT_DATASET_CODE="$ILOSTAT_DATASET_CODE" \
SNAPSHOT_ROOT="$SNAPSHOT_ROOT" \
SERIES_TSV="$series_tsv" \
python3 - <<'PY'
import csv
import json
import os
from pathlib import Path

meta_tsv = Path(os.environ['META_TSV'])
row_csv = Path(os.environ['ROW_CSV'])
manifest_path = Path(os.environ['MANIFEST_PATH'])
series_tsv = Path(os.environ['SERIES_TSV'])

snapshots = []
with meta_tsv.open('r', encoding='utf-8', newline='') as handle:
    reader = csv.DictReader(handle, delimiter='\t')
    snapshots = list(reader)

rows = []
with row_csv.open('r', encoding='utf-8', newline='') as handle:
    reader = csv.DictReader(handle)
    rows = list(reader)

series_requests = []
with series_tsv.open('r', encoding='utf-8', newline='') as handle:
    reader = csv.reader(handle, delimiter='\t')
    for request_signature, source_series_code, series_name in reader:
        indicator_id, sex_code, classif1_code = request_signature.split('|')
        series_requests.append({
            'source_series_code': source_series_code,
            'series_name': series_name,
            'api_indicator_id': indicator_id,
            'sex': sex_code,
            'classif1': classif1_code,
        })

manifest = {
    'run_ts': os.environ['RUN_TS'],
    'batch_external_id': os.environ['BATCH_EXTERNAL_ID'],
    'dataset_code': os.environ['ILOSTAT_DATASET_CODE'],
    'countries': [code for code in os.environ['ILOSTAT_COUNTRIES'].split(';') if code],
    'timefrom': os.environ['ILOSTAT_TIMEFROM'],
    'timeto': os.environ['ILOSTAT_TIMETO'],
    'snapshot_root': os.environ['SNAPSHOT_ROOT'],
    'snapshot_count': len(snapshots),
    'row_count_reported': len(rows),
    'series_requests': series_requests,
    'snapshots': snapshots,
}
manifest_path.write_text(json.dumps(manifest, indent=2), encoding='utf-8')
PY

series_requests_json="$(python3 - "$series_tsv" <<'PY'
import csv
import json
import sys
from pathlib import Path
rows = []
with Path(sys.argv[1]).open('r', encoding='utf-8', newline='') as handle:
    reader = csv.reader(handle, delimiter='\t')
    for request_signature, source_series_code, series_name in reader:
        indicator_id, sex_code, classif1_code = request_signature.split('|')
        rows.append({
            'source_series_code': source_series_code,
            'series_name': series_name,
            'api_indicator_id': indicator_id,
            'sex': sex_code,
            'classif1': classif1_code,
        })
print(json.dumps(rows))
PY
)"
api_indicator_ids_json="$(python3 - "$series_requests_json" <<'PY'
import json, sys
print(json.dumps([row['api_indicator_id'] for row in json.loads(sys.argv[1])]))
PY
)"
source_series_codes_json="$(python3 - "$series_requests_json" <<'PY'
import json, sys
print(json.dumps([row['source_series_code'] for row in json.loads(sys.argv[1])]))
PY
)"
sex_filters_json="$(python3 - "$series_requests_json" <<'PY'
import json, sys
print(json.dumps(sorted({row['sex'] for row in json.loads(sys.argv[1])})))
PY
)"
classif1_filters_json="$(python3 - "$series_requests_json" <<'PY'
import json, sys
print(json.dumps(sorted({row['classif1'] for row in json.loads(sys.argv[1])})))
PY
)"

export BATCH_EXTERNAL_ID ILOSTAT_COUNTRIES ILOSTAT_TIMEFROM ILOSTAT_TIMETO ILOSTAT_DATASET_CODE SNAPSHOT_ROOT row_count_reported meta_tsv row_csv api_indicator_ids_json source_series_codes_json sex_filters_json classif1_filters_json series_requests_json

echo "=== Loading live ILOSTAT slice into $DB_NAME ==="

$PSQL_CMD -d "$DB_NAME" <<SQL
CREATE TEMP TABLE tmp_ilostat_snapshot_meta (
    snapshot_path TEXT,
    content_type TEXT,
    file_hash_sha256 TEXT,
    fetched_at TIMESTAMPTZ,
    http_status_code INT,
    source_url TEXT
);

\copy tmp_ilostat_snapshot_meta FROM '$meta_tsv' WITH (FORMAT csv, DELIMITER E'\t', HEADER true);

CREATE TEMP TABLE tmp_ilostat_live_rows (
    country_code TEXT,
    country_name TEXT,
    indicator_code TEXT,
    indicator_name TEXT,
    year TEXT,
    value TEXT,
    obs_status TEXT,
    decimal TEXT,
    snapshot_path TEXT,
    api_indicator_id TEXT,
    sex TEXT,
    classif1 TEXT,
    source_code TEXT,
    note_source TEXT
);

\copy tmp_ilostat_live_rows FROM '$row_csv' WITH (FORMAT csv, HEADER true);

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
            'loader', 'scripts/load_ilostat_live.sh',
            'countries', '$ILOSTAT_COUNTRIES',
            'timefrom', '$ILOSTAT_TIMEFROM',
            'timeto', '$ILOSTAT_TIMETO',
            'dataset_code', '$ILOSTAT_DATASET_CODE',
            'snapshot_root', '$SNAPSHOT_ROOT',
            'api_indicator_ids', '$api_indicator_ids_json'::jsonb,
            'source_series_codes', '$source_series_codes_json'::jsonb,
            'sex_filters', '$sex_filters_json'::jsonb,
            'classif1_filters', '$classif1_filters_json'::jsonb,
            'series_requests', '$series_requests_json'::jsonb
        ),
        COALESCE((SELECT MAX(fetched_at) FROM tmp_ilostat_snapshot_meta), CURRENT_TIMESTAMP),
        COALESCE((SELECT MAX(fetched_at) FROM tmp_ilostat_snapshot_meta), CURRENT_TIMESTAMP),
        'queued',
        $row_count_reported
    FROM ref.source_dataset d
    WHERE d.dataset_code = '$ILOSTAT_DATASET_CODE'
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
FROM tmp_ilostat_snapshot_meta
ON CONFLICT (snapshot_path) DO NOTHING;

INSERT INTO raw.ilostat_country_indicator_annual (
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
    NULLIF(obs_status, ''),
    NULLIF(decimal, ''),
    jsonb_build_object(
        'loader', 'scripts/load_ilostat_live.sh',
        'snapshot_path', snapshot_path,
        'ingestion_type', 'live_api_snapshot',
        'api_indicator_id', api_indicator_id,
        'sex', sex,
        'classif1', classif1,
        'source_code', NULLIF(source_code, ''),
        'note_source', NULLIF(note_source, '')
    )
FROM tmp_ilostat_live_rows;

UPDATE raw.source_batch
SET row_count_reported = (
        SELECT COUNT(*)
        FROM raw.ilostat_country_indicator_annual
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

echo "=== Live ILOSTAT load complete ==="
