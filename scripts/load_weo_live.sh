#!/bin/bash
set -euo pipefail

DB_NAME="${DB_NAME:-country_intel}"
PSQL_CMD="${PSQL_CMD:-psql -v ON_ERROR_STOP=1}"
FETCH_HELPER="${FETCH_HELPER:-scripts/fetch_http_to_snapshot.py}"
WEO_COUNTRIES="${WEO_COUNTRIES:-}"
WEO_YEARS="${WEO_YEARS:-2021;2022}"
WEO_DATASET_CODE="${WEO_DATASET_CODE:-WEO}"
SNAPSHOT_ROOT="${SNAPSHOT_ROOT:-ingest/snapshots/weo/WEO}"
RUN_TS="${RUN_TS:-$(date -u +%Y%m%dT%H%M%SZ)}"
BATCH_EXTERNAL_ID="${BATCH_EXTERNAL_ID:-weo_live_${RUN_TS}}"
WEO_API_BASE="${WEO_API_BASE:-https://www.imf.org/external/datamapper/api/v1}"

if [[ ! -f "$FETCH_HELPER" ]]; then
    echo "Fetch helper not found: $FETCH_HELPER" >&2
    exit 1
fi

if [[ -z "$WEO_COUNTRIES" || "${WEO_COUNTRIES,,}" == "default" || "${WEO_COUNTRIES,,}" == "all" ]]; then
    WEO_COUNTRIES="$($PSQL_CMD -d "$DB_NAME" -Atqc "SELECT string_agg(iso_alpha_3, ';' ORDER BY iso_alpha_3) FROM ref.country WHERE is_active = TRUE AND COALESCE(is_aggregate, FALSE) = FALSE")"
fi

if [[ -z "$WEO_COUNTRIES" ]]; then
    echo "No WEO countries resolved. Seed ref.country first or pass WEO_COUNTRIES explicitly." >&2
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
            echo "Cleaned up incomplete WEO snapshot run: $RUN_TS" >&2
        fi
    fi
    rm -f "$meta_tsv" "$row_csv" "$series_tsv"
    return $exit_code
}
trap cleanup EXIT

$PSQL_CMD -d "$DB_NAME" -AtF $'\t' <<SQL > "$series_tsv"
SELECT DISTINCT
    COALESCE(ssa.alias_code, rs.series_code) AS api_indicator_code,
    rs.series_code AS source_series_code,
    rs.series_name
FROM ref.source_dataset d
JOIN ref.source_series rs
  ON rs.source_dataset_key = d.source_dataset_key
 AND rs.is_active = TRUE
JOIN ref.indicator_source_series_map ism
  ON ism.source_series_key = rs.source_series_key
 AND ism.is_active = TRUE
LEFT JOIN ref.source_series_alias ssa
  ON ssa.source_series_key = rs.source_series_key
 AND ssa.alias_type = 'imf_datamapper_indicator'
 AND ssa.is_active = TRUE
WHERE d.dataset_code = '$WEO_DATASET_CODE'
ORDER BY rs.series_code;
SQL

if [[ ! -s "$series_tsv" ]]; then
    echo "No active WEO source-series mappings found for dataset $WEO_DATASET_CODE" >&2
    exit 1
fi

mapfile -t API_INDICATORS < <(cut -f1 "$series_tsv")
series_json_payload="$(python3 - "$series_tsv" <<'PY'
import csv
import json
import sys
from pathlib import Path

rows = []
with Path(sys.argv[1]).open('r', encoding='utf-8', newline='') as handle:
    reader = csv.reader(handle, delimiter='\t')
    for api_indicator_code, source_series_code, series_name in reader:
        rows.append({
            'api_indicator_code': api_indicator_code,
            'source_series_code': source_series_code,
            'series_name': series_name,
        })

print(json.dumps({
    'api_indicator_codes': [row['api_indicator_code'] for row in rows],
    'source_series_codes': [row['source_series_code'] for row in rows],
    'series_count': len(rows),
}))
PY
)"
API_INDICATOR_CODES_JSON="$(python3 - "$series_json_payload" <<'PY'
import json, sys
print(json.dumps(json.loads(sys.argv[1])['api_indicator_codes']))
PY
)"
SOURCE_SERIES_CODES_JSON="$(python3 - "$series_json_payload" <<'PY'
import json, sys
print(json.dumps(json.loads(sys.argv[1])['source_series_codes']))
PY
)"
SERIES_COUNT="$(python3 - "$series_json_payload" <<'PY'
import json, sys
print(json.loads(sys.argv[1])['series_count'])
PY
)"

printf 'snapshot_path\tcontent_type\tfile_hash_sha256\tfetched_at\thttp_status_code\tsource_url\n' > "$meta_tsv"

write_meta_row() {
    local meta_json="$1"
    META_JSON="$meta_json" python3 - "$meta_tsv" <<'PY'
import json
import os
import sys
from pathlib import Path
meta = json.loads(os.environ["META_JSON"])
out = Path(sys.argv[1])
fields = [
    meta["output_path"],
    meta.get("content_type", ""),
    meta.get("file_hash_sha256", ""),
    meta.get("fetched_at", ""),
    str(meta.get("http_status_code", "")),
    meta.get("final_url") or meta.get("requested_url", ""),
]
with out.open("a", encoding="utf-8") as handle:
    handle.write("\t".join(value.replace("\t", " ").replace("\n", " ") for value in fields) + "\n")
PY
}

countries_snapshot="$SNAPSHOT_ROOT/${RUN_TS}_countries.json"
echo "Fetching IMF country metadata..."
countries_meta_json="$(python3 "$FETCH_HELPER" --user-agent '' --url "$WEO_API_BASE/countries" --output "$countries_snapshot")"
write_meta_row "$countries_meta_json"
snapshot_paths+=("$countries_snapshot")

for api_indicator_code in "${API_INDICATORS[@]}"; do
    snapshot_path="$SNAPSHOT_ROOT/${RUN_TS}_${api_indicator_code}.json"
    url="$WEO_API_BASE/${api_indicator_code}"
    echo "Fetching IMF WEO ${api_indicator_code}..."
    meta_json="$(python3 "$FETCH_HELPER" --user-agent '' --url "$url" --output "$snapshot_path")"
    write_meta_row "$meta_json"
    snapshot_paths+=("$snapshot_path")
done

python3 - "$row_csv" "$countries_snapshot" "$WEO_COUNTRIES" "$WEO_YEARS" "$series_tsv" "${snapshot_paths[@]:1}" <<'PY'
import csv
import json
import sys
from pathlib import Path

out_path = Path(sys.argv[1])
countries_snapshot = Path(sys.argv[2])
country_filter = {code.strip() for code in sys.argv[3].split(';') if code.strip()}
year_filter = {year.strip() for year in sys.argv[4].split(';') if year.strip()}
series_tsv = Path(sys.argv[5])
indicator_snapshots = [Path(p) for p in sys.argv[6:]]

series_lookup = {}
with series_tsv.open('r', encoding='utf-8', newline='') as handle:
    reader = csv.reader(handle, delimiter='\t')
    for api_indicator_code, source_series_code, series_name in reader:
        series_lookup[api_indicator_code] = {
            'source_series_code': source_series_code,
            'series_name': series_name,
        }

with countries_snapshot.open('r', encoding='utf-8') as handle:
    countries_payload = json.load(handle)
country_names = {
    code: details.get('label', code)
    for code, details in countries_payload.get('countries', {}).items()
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
]

with out_path.open('w', newline='', encoding='utf-8') as handle:
    writer = csv.DictWriter(handle, fieldnames=fieldnames)
    writer.writeheader()

    for snapshot_path in indicator_snapshots:
        with snapshot_path.open('r', encoding='utf-8') as source_handle:
            payload = json.load(source_handle)
        values = payload.get('values', {})
        if not values:
            continue
        api_indicator_code = next(iter(values))
        source_series = series_lookup.get(api_indicator_code)
        if source_series is None:
            raise RuntimeError(f'No source-series mapping found for API indicator {api_indicator_code}')
        countries = values[api_indicator_code]
        for country_code, years in countries.items():
            if country_filter and country_code not in country_filter:
                continue
            for year, value in years.items():
                if year_filter and year not in year_filter:
                    continue
                writer.writerow({
                    'country_code': country_code,
                    'country_name': country_names.get(country_code, country_code),
                    'indicator_code': source_series['source_series_code'],
                    'indicator_name': source_series['series_name'],
                    'year': year,
                    'value': '' if value is None else (
                        str(float(value) * 1000000000)
                        if api_indicator_code == 'BCA'
                        else str(value)
                    ),
                    'obs_status': '',
                    'decimal': '',
                    'snapshot_path': str(snapshot_path.resolve()),
                    'api_indicator_code': api_indicator_code,
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
WEO_COUNTRIES="$WEO_COUNTRIES" \
WEO_YEARS="$WEO_YEARS" \
WEO_DATASET_CODE="$WEO_DATASET_CODE" \
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
    row_count = sum(1 for _ in csv.DictReader(handle))

series = []
with series_tsv.open('r', encoding='utf-8', newline='') as handle:
    reader = csv.reader(handle, delimiter='\t')
    for api_indicator_code, source_series_code, series_name in reader:
        series.append({
            'api_indicator_code': api_indicator_code,
            'source_series_code': source_series_code,
            'series_name': series_name,
        })

manifest = {
    'run_ts': os.environ['RUN_TS'],
    'batch_external_id': os.environ['BATCH_EXTERNAL_ID'],
    'dataset_code': os.environ['WEO_DATASET_CODE'],
    'countries': [code for code in os.environ['WEO_COUNTRIES'].split(';') if code],
    'years': [year for year in os.environ['WEO_YEARS'].split(';') if year],
    'snapshot_root': os.path.abspath(os.environ['SNAPSHOT_ROOT']),
    'row_count_reported': row_count,
    'requested_series': series,
    'snapshots': snapshots,
}

manifest_path.write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
PY

echo "=== Loading live WEO slice into $DB_NAME ==="

$PSQL_CMD -d "$DB_NAME" <<SQL
CREATE TEMP TABLE tmp_weo_snapshot_meta (
    snapshot_path TEXT,
    content_type TEXT,
    file_hash_sha256 TEXT,
    fetched_at TIMESTAMPTZ,
    http_status_code INT,
    source_url TEXT
);

\copy tmp_weo_snapshot_meta FROM '$meta_tsv' WITH (FORMAT csv, DELIMITER E'\t', HEADER true);

CREATE TEMP TABLE tmp_weo_live_rows (
    country_code TEXT,
    country_name TEXT,
    indicator_code TEXT,
    indicator_name TEXT,
    year TEXT,
    value TEXT,
    obs_status TEXT,
    decimal TEXT,
    snapshot_path TEXT,
    api_indicator_code TEXT
);

\copy tmp_weo_live_rows FROM '$row_csv' WITH (FORMAT csv, HEADER true);

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
            'loader', 'scripts/load_weo_live.sh',
            'countries', '$WEO_COUNTRIES',
            'years', '$WEO_YEARS',
            'dataset_code', '$WEO_DATASET_CODE',
            'snapshot_root', '$SNAPSHOT_ROOT',
            'api_indicator_codes', '$API_INDICATOR_CODES_JSON'::jsonb,
            'source_series_codes', '$SOURCE_SERIES_CODES_JSON'::jsonb,
            'series_count', $SERIES_COUNT
        ),
        COALESCE((SELECT MAX(fetched_at) FROM tmp_weo_snapshot_meta), CURRENT_TIMESTAMP),
        NULL,
        'queued',
        $row_count_reported
    FROM ref.source_dataset d
    WHERE d.dataset_code = '$WEO_DATASET_CODE'
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
FROM tmp_weo_snapshot_meta
ON CONFLICT (snapshot_path) DO NOTHING;

INSERT INTO raw.weo_country_indicator_annual (
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
        'loader', 'scripts/load_weo_live.sh',
        'snapshot_path', snapshot_path,
        'ingestion_type', 'live_api_snapshot',
        'source_indicator_code', api_indicator_code
    )
FROM tmp_weo_live_rows;

UPDATE raw.source_batch
SET row_count_reported = (
        SELECT COUNT(*)
        FROM raw.weo_country_indicator_annual
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

echo "=== Live WEO load complete ==="
