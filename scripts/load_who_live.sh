#!/bin/bash
set -euo pipefail

DB_NAME="${DB_NAME:-country_intel}"
PSQL_CMD="${PSQL_CMD:-psql -v ON_ERROR_STOP=1}"
FETCH_HELPER="${FETCH_HELPER:-scripts/fetch_http_to_snapshot.py}"
WHO_COUNTRIES="${WHO_COUNTRIES:-DEU;USA;CHN;IND;ZAF}"
WHO_YEARS="${WHO_YEARS:-2019:2021}"
WHO_DATASET_CODE="${WHO_DATASET_CODE:-WHO_GHO}"
WHO_INDICATOR_CODE="${WHO_INDICATOR_CODE:-WHOSIS_000001}"
WHO_DIM1_CODE="${WHO_DIM1_CODE:-SEX_BTSX}"
SNAPSHOT_ROOT="${SNAPSHOT_ROOT:-ingest/snapshots/who/WHO_GHO}"
RUN_TS="${RUN_TS:-$(date -u +%Y%m%dT%H%M%SZ)}"
BATCH_EXTERNAL_ID="${BATCH_EXTERNAL_ID:-who_live_${RUN_TS}}"

if [[ ! -f "$FETCH_HELPER" ]]; then
    echo "Fetch helper not found: $FETCH_HELPER" >&2
    exit 1
fi

if [[ -z "$WHO_COUNTRIES" ]]; then
    echo "WHO_COUNTRIES cannot be empty" >&2
    exit 1
fi

IFS=':' read -r WHO_YEAR_FROM WHO_YEAR_TO <<< "$WHO_YEARS"
if [[ -z "${WHO_YEAR_FROM:-}" || -z "${WHO_YEAR_TO:-}" ]]; then
    echo "WHO_YEARS must look like 2019:2021" >&2
    exit 1
fi

mkdir -p "$SNAPSHOT_ROOT"
meta_tsv="$(mktemp)"
row_csv="$(mktemp)"
cleanup() {
    rm -f "$meta_tsv" "$row_csv"
}
trap cleanup EXIT

printf 'snapshot_path\tcontent_type\tfile_hash_sha256\tfetched_at\thttp_status_code\tsource_url\n' > "$meta_tsv"

snapshot_paths=()
IFS=';' read -r -a countries <<< "$WHO_COUNTRIES"
for country_code in "${countries[@]}"; do
    [[ -n "$country_code" ]] || continue
    snapshot_path="$SNAPSHOT_ROOT/${RUN_TS}_${country_code}_${WHO_INDICATOR_CODE}.json"
    url="https://ghoapi.azureedge.net/api/${WHO_INDICATOR_CODE}?
\$filter=SpatialDim%20eq%20%27${country_code}%27%20and%20Dim1%20eq%20%27${WHO_DIM1_CODE}%27&\$top=50"
    url="${url//$'\n'/}"

    echo "Fetching WHO ${WHO_INDICATOR_CODE} for ${country_code}..."
    meta_json="$(python3 "$FETCH_HELPER" --url "$url" --output "$snapshot_path")"

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

    snapshot_paths+=("$snapshot_path")
done

python3 - "$row_csv" "$WHO_INDICATOR_CODE" "$WHO_YEAR_FROM" "$WHO_YEAR_TO" "$WHO_DIM1_CODE" "${snapshot_paths[@]}" <<'PY'
import csv
import json
import sys
from pathlib import Path

out_path = Path(sys.argv[1])
indicator_code = sys.argv[2]
year_from = int(sys.argv[3])
year_to = int(sys.argv[4])
dim1_code = sys.argv[5]
snapshot_paths = sys.argv[6:]
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
    'dim1',
    'source_code',
]

with out_path.open('w', newline='', encoding='utf-8') as handle:
    writer = csv.DictWriter(handle, fieldnames=fieldnames)
    writer.writeheader()
    for snapshot_path in snapshot_paths:
        payload = json.loads(Path(snapshot_path).read_text(encoding='utf-8'))
        for row in payload.get('value', []):
            year = row.get('TimeDim')
            if not isinstance(year, int) or year < year_from or year > year_to:
                continue
            if row.get('Dim1') != dim1_code:
                continue
            writer.writerow({
                'country_code': row.get('SpatialDim', ''),
                'country_name': row.get('SpatialDimType', '') or row.get('ParentLocation', ''),
                'indicator_code': indicator_code,
                'indicator_name': row.get('Indicator', indicator_code),
                'year': str(year),
                'value': '' if row.get('NumericValue') is None else str(row.get('NumericValue')),
                'obs_status': row.get('Comments', '') or '',
                'decimal': '',
                'snapshot_path': str(Path(snapshot_path).resolve()),
                'dim1': row.get('Dim1', ''),
                'source_code': row.get('SpatialDimType', '') or '',
            })
PY

row_count_reported="$(python3 - "$row_csv" <<'PY'
import csv
import sys
with open(sys.argv[1], newline='', encoding='utf-8') as handle:
    print(sum(1 for _ in csv.DictReader(handle)))
PY
)"

export BATCH_EXTERNAL_ID WHO_COUNTRIES WHO_YEARS WHO_DATASET_CODE WHO_INDICATOR_CODE WHO_DIM1_CODE SNAPSHOT_ROOT row_count_reported meta_tsv row_csv

echo "=== Loading live WHO slice into $DB_NAME ==="

$PSQL_CMD -d "$DB_NAME" <<SQL
CREATE TEMP TABLE tmp_who_snapshot_meta (
    snapshot_path TEXT,
    content_type TEXT,
    file_hash_sha256 TEXT,
    fetched_at TIMESTAMPTZ,
    http_status_code INT,
    source_url TEXT
);

\copy tmp_who_snapshot_meta FROM '$meta_tsv' WITH (FORMAT csv, DELIMITER E'\t', HEADER true);

CREATE TEMP TABLE tmp_who_live_rows (
    country_code TEXT,
    country_name TEXT,
    indicator_code TEXT,
    indicator_name TEXT,
    year TEXT,
    value TEXT,
    obs_status TEXT,
    decimal TEXT,
    snapshot_path TEXT,
    dim1 TEXT,
    source_code TEXT
);

\copy tmp_who_live_rows FROM '$row_csv' WITH (FORMAT csv, HEADER true);

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
            'loader', 'scripts/load_who_live.sh',
            'countries', '$WHO_COUNTRIES',
            'years', '$WHO_YEARS',
            'dataset_code', '$WHO_DATASET_CODE',
            'snapshot_root', '$SNAPSHOT_ROOT',
            'api_indicator_codes', jsonb_build_array('$WHO_INDICATOR_CODE'),
            'source_series_codes', jsonb_build_array('$WHO_INDICATOR_CODE'),
            'dim1_code', '$WHO_DIM1_CODE'
        ),
        COALESCE((SELECT MAX(fetched_at) FROM tmp_who_snapshot_meta), CURRENT_TIMESTAMP),
        NULL,
        'queued',
        $row_count_reported
    FROM ref.source_dataset d
    WHERE d.dataset_code = '$WHO_DATASET_CODE'
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
FROM tmp_who_snapshot_meta
ON CONFLICT (snapshot_path) DO NOTHING;

INSERT INTO raw.who_country_indicator_annual (
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
        'loader', 'scripts/load_who_live.sh',
        'snapshot_path', snapshot_path,
        'ingestion_type', 'live_api_snapshot',
        'dim1', NULLIF(dim1, ''),
        'source_code', NULLIF(source_code, '')
    )
FROM tmp_who_live_rows;

UPDATE raw.source_batch
SET row_count_reported = (
        SELECT COUNT(*)
        FROM raw.who_country_indicator_annual
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

echo "=== Live WHO load complete ==="
