#!/bin/bash
set -euo pipefail

DB_NAME="${DB_NAME:-country_intel}"
PSQL_CMD="${PSQL_CMD:-psql -v ON_ERROR_STOP=1}"
FETCH_HELPER="${FETCH_HELPER:-scripts/fetch_http_to_snapshot.py}"
WDI_LABOR_COUNTRIES="${WDI_LABOR_COUNTRIES:-DEU;CHN}"
WDI_LABOR_YEARS="${WDI_LABOR_YEARS:-2019:2023}"
WDI_LABOR_DATASET_CODE="${WDI_LABOR_DATASET_CODE:-WDI}"
SNAPSHOT_ROOT="${SNAPSHOT_ROOT:-ingest/snapshots/wdi/WDI}"
RUN_TS="${RUN_TS:-$(date -u +%Y%m%dT%H%M%SZ)}"
BATCH_EXTERNAL_ID="${BATCH_EXTERNAL_ID:-wdi_labor_live_${RUN_TS}}"
WDI_PER_PAGE="${WDI_PER_PAGE:-20000}"

if [[ ! -f "$FETCH_HELPER" ]]; then
    echo "Fetch helper not found: $FETCH_HELPER" >&2
    exit 1
fi

mkdir -p "$SNAPSHOT_ROOT"
meta_tsv="$(mktemp)"
row_csv="$(mktemp)"
series_tsv="$(mktemp)"
manifest_path="$SNAPSHOT_ROOT/${RUN_TS}_wdi_labor_manifest.json"
run_succeeded=0
snapshot_paths=()
cleanup() {
    local exit_code=$?
    if [[ "$run_succeeded" != "1" ]]; then
        for snapshot_path in "${snapshot_paths[@]}"; do
            [[ -n "$snapshot_path" ]] && rm -f "$snapshot_path"
        done
        rm -f "$manifest_path"
        if [[ ${#snapshot_paths[@]} -gt 0 ]]; then
            echo "Cleaned up incomplete WDI labor snapshot run: $RUN_TS" >&2
        fi
    fi
    rm -f "$meta_tsv" "$row_csv" "$series_tsv"
    return $exit_code
}
trap cleanup EXIT

$PSQL_CMD -d "$DB_NAME" -AtF $'\t' <<SQL > "$series_tsv"
SELECT DISTINCT
    rs.series_code AS source_series_code,
    COALESCE(ssa.alias_code, rs.series_code) AS api_indicator_code,
    rs.series_name,
    i.indicator_code AS conformed_indicator_code
FROM ref.source_dataset d
JOIN ref.source_series rs
  ON rs.source_dataset_key = d.source_dataset_key
 AND rs.is_active = TRUE
JOIN ref.indicator_source_series_map ism
  ON ism.source_series_key = rs.source_series_key
 AND ism.is_active = TRUE
JOIN ref.indicator i
  ON i.indicator_key = ism.indicator_key
LEFT JOIN ref.source_series_alias ssa
  ON ssa.source_series_key = rs.source_series_key
 AND ssa.alias_type = 'wb_indicator_code'
 AND ssa.is_active = TRUE
WHERE d.dataset_code = '$WDI_LABOR_DATASET_CODE'
  AND i.indicator_code IN (
      'EMPLOYMENT_RATE_PCT',
      'LABOR_FORCE_PARTICIPATION_RATE_PCT',
      'UNEMPLOYMENT_RATE_PCT'
  )
ORDER BY rs.series_code;
SQL

if [[ ! -s "$series_tsv" ]]; then
    echo "No active WDI labor source-series mappings found for dataset $WDI_LABOR_DATASET_CODE" >&2
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

while IFS=$'\t' read -r source_series_code api_indicator_code series_name conformed_indicator_code; do
    [[ -z "$source_series_code" ]] && continue
    safe_indicator="${api_indicator_code//./_}"
    snapshot_path="$SNAPSHOT_ROOT/${RUN_TS}_${safe_indicator}.json"
    url="https://api.worldbank.org/v2/country/${WDI_LABOR_COUNTRIES}/indicator/${api_indicator_code}?format=json&date=${WDI_LABOR_YEARS}&per_page=${WDI_PER_PAGE}"

    echo "Fetching WDI labor ${api_indicator_code}..."
    meta_json="$(python3 "$FETCH_HELPER" --url "$url" --output "$snapshot_path")"
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
    for source_series_code, api_indicator_code, series_name, conformed_indicator_code in reader:
        series_lookup[api_indicator_code] = {
            'source_series_code': source_series_code,
            'series_name': series_name,
            'conformed_indicator_code': conformed_indicator_code,
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
    'api_indicator_code',
    'conformed_indicator_code',
]

with out_path.open('w', newline='', encoding='utf-8') as handle:
    writer = csv.DictWriter(handle, fieldnames=fieldnames)
    writer.writeheader()
    for snapshot_path in snapshot_paths:
        with snapshot_path.open('r', encoding='utf-8') as source_handle:
            payload = json.load(source_handle)
        rows = payload[1] if isinstance(payload, list) and len(payload) > 1 else []
        for row in rows:
            api_indicator_code = (row.get('indicator') or {}).get('id', '')
            if api_indicator_code not in series_lookup:
                continue
            meta = series_lookup[api_indicator_code]
            writer.writerow({
                'country_code': row.get('countryiso3code') or '',
                'country_name': (row.get('country') or {}).get('value', ''),
                'indicator_code': meta['source_series_code'],
                'indicator_name': meta['series_name'],
                'year': row.get('date', ''),
                'value': '' if row.get('value') is None else str(row.get('value')),
                'obs_status': row.get('obs_status', '') or '',
                'decimal': '' if row.get('decimal') is None else str(row.get('decimal')),
                'snapshot_path': str(snapshot_path.resolve()),
                'api_indicator_code': api_indicator_code,
                'conformed_indicator_code': meta['conformed_indicator_code'],
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
WDI_LABOR_COUNTRIES="$WDI_LABOR_COUNTRIES" \
WDI_LABOR_YEARS="$WDI_LABOR_YEARS" \
WDI_LABOR_DATASET_CODE="$WDI_LABOR_DATASET_CODE" \
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

with meta_tsv.open('r', encoding='utf-8', newline='') as handle:
    snapshots = list(csv.DictReader(handle, delimiter='\t'))
with row_csv.open('r', encoding='utf-8', newline='') as handle:
    rows = list(csv.DictReader(handle))
series_requests = []
with series_tsv.open('r', encoding='utf-8', newline='') as handle:
    reader = csv.reader(handle, delimiter='\t')
    for source_series_code, api_indicator_code, series_name, conformed_indicator_code in reader:
        series_requests.append({
            'source_series_code': source_series_code,
            'api_indicator_code': api_indicator_code,
            'series_name': series_name,
            'conformed_indicator_code': conformed_indicator_code,
        })
manifest = {
    'run_ts': os.environ['RUN_TS'],
    'batch_external_id': os.environ['BATCH_EXTERNAL_ID'],
    'dataset_code': os.environ['WDI_LABOR_DATASET_CODE'],
    'countries': [code for code in os.environ['WDI_LABOR_COUNTRIES'].split(';') if code],
    'years': os.environ['WDI_LABOR_YEARS'],
    'snapshot_root': os.environ['SNAPSHOT_ROOT'],
    'snapshot_count': len(snapshots),
    'row_count_reported': len(rows),
    'series_requests': series_requests,
    'snapshots': snapshots,
}
manifest_path.write_text(json.dumps(manifest, indent=2), encoding='utf-8')
PY

source_series_codes_json="$(python3 - "$series_tsv" <<'PY'
import csv
import json
import sys
with open(sys.argv[1], 'r', encoding='utf-8', newline='') as handle:
    print(json.dumps([row[0] for row in csv.reader(handle, delimiter='\t') if row]))
PY
)"

api_indicator_codes_json="$(python3 - "$series_tsv" <<'PY'
import csv
import json
import sys
with open(sys.argv[1], 'r', encoding='utf-8', newline='') as handle:
    print(json.dumps([row[1] for row in csv.reader(handle, delimiter='\t') if row]))
PY
)"

conformed_indicator_codes_json="$(python3 - "$series_tsv" <<'PY'
import csv
import json
import sys
with open(sys.argv[1], 'r', encoding='utf-8', newline='') as handle:
    print(json.dumps([row[3] for row in csv.reader(handle, delimiter='\t') if row]))
PY
)"

series_requests_json="$(python3 - "$series_tsv" <<'PY'
import csv
import json
import sys
rows = []
with open(sys.argv[1], 'r', encoding='utf-8', newline='') as handle:
    for source_series_code, api_indicator_code, series_name, conformed_indicator_code in csv.reader(handle, delimiter='\t'):
        rows.append({
            'source_series_code': source_series_code,
            'api_indicator_code': api_indicator_code,
            'series_name': series_name,
            'conformed_indicator_code': conformed_indicator_code,
        })
print(json.dumps(rows))
PY
)"

countries_json="$(WDI_LABOR_COUNTRIES="$WDI_LABOR_COUNTRIES" python3 - <<'PY'
import json, os
print(json.dumps([code for code in os.environ['WDI_LABOR_COUNTRIES'].split(';') if code]))
PY
)"

export BATCH_EXTERNAL_ID WDI_LABOR_COUNTRIES WDI_LABOR_YEARS WDI_LABOR_DATASET_CODE SNAPSHOT_ROOT row_count_reported meta_tsv row_csv source_series_codes_json api_indicator_codes_json conformed_indicator_codes_json series_requests_json countries_json manifest_path

echo "=== Loading live WDI labor slice into $DB_NAME ==="

$PSQL_CMD -d "$DB_NAME" <<SQL
CREATE TEMP TABLE tmp_wdi_labor_snapshot_meta (
    snapshot_path TEXT,
    content_type TEXT,
    file_hash_sha256 TEXT,
    fetched_at TIMESTAMPTZ,
    http_status_code INT,
    source_url TEXT
);

\\copy tmp_wdi_labor_snapshot_meta FROM '$meta_tsv' WITH (FORMAT csv, DELIMITER E'\t', HEADER true);

CREATE TEMP TABLE tmp_wdi_labor_live_rows (
    country_code TEXT,
    country_name TEXT,
    indicator_code TEXT,
    indicator_name TEXT,
    year TEXT,
    value TEXT,
    obs_status TEXT,
    decimal TEXT,
    snapshot_path TEXT,
    api_indicator_code TEXT,
    conformed_indicator_code TEXT
);

\\copy tmp_wdi_labor_live_rows FROM '$row_csv' WITH (FORMAT csv, HEADER true);

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
            'loader', 'scripts/load_wdi_labor_live.sh',
            'countries', '$WDI_LABOR_COUNTRIES',
            'years', '$WDI_LABOR_YEARS',
            'dataset_code', '$WDI_LABOR_DATASET_CODE',
            'snapshot_root', '$SNAPSHOT_ROOT',
            'source_series_codes', '$source_series_codes_json'::jsonb,
            'api_indicator_codes', '$api_indicator_codes_json'::jsonb,
            'conformed_indicator_codes', '$conformed_indicator_codes_json'::jsonb,
            'series_requests', '$series_requests_json'::jsonb,
            'country_basket', '$countries_json'::jsonb,
            'manifest_path', '$manifest_path'
        ),
        COALESCE((SELECT MAX(fetched_at) FROM tmp_wdi_labor_snapshot_meta), CURRENT_TIMESTAMP),
        NULL,
        'queued',
        $row_count_reported
    FROM ref.source_dataset d
    WHERE d.dataset_code = '$WDI_LABOR_DATASET_CODE'
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
FROM tmp_wdi_labor_snapshot_meta
ON CONFLICT (snapshot_path) DO NOTHING;

INSERT INTO raw.wdi_country_indicator_annual (
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
        'loader', 'scripts/load_wdi_labor_live.sh',
        'snapshot_path', snapshot_path,
        'api_indicator_code', api_indicator_code,
        'conformed_indicator_code', conformed_indicator_code,
        'ingestion_type', 'live_api_snapshot'
    )
FROM tmp_wdi_labor_live_rows;

UPDATE raw.source_batch
SET row_count_reported = (
        SELECT COUNT(*)
        FROM raw.wdi_country_indicator_annual
        WHERE source_batch_key = :source_batch_key
    ),
    ingest_status = 'loaded'
WHERE source_batch_key = :source_batch_key;

CALL staging.normalize_wdi_country_observation_annual(:source_batch_key);

UPDATE raw.source_batch
SET ingest_status = 'normalized'
WHERE source_batch_key = :source_batch_key;

CALL etl.publish_phase1_country_indicator_facts(:source_batch_key);
SQL

run_succeeded=1

echo "=== Live WDI labor load complete ==="
