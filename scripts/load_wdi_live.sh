#!/bin/bash
set -euo pipefail

DB_NAME="${DB_NAME:-country_intel}"
PSQL_CMD="${PSQL_CMD:-psql -v ON_ERROR_STOP=1}"
FETCH_HELPER="${FETCH_HELPER:-scripts/fetch_http_to_snapshot.py}"
WDI_COUNTRIES="${WDI_COUNTRIES:-}"
WDI_YEARS="${WDI_YEARS:-2021:2022}"
WDI_DATASET_CODE="${WDI_DATASET_CODE:-WDI}"
SNAPSHOT_ROOT="${SNAPSHOT_ROOT:-ingest/snapshots/wdi/WDI}"
RUN_TS="${RUN_TS:-$(date -u +%Y%m%dT%H%M%SZ)}"
BATCH_EXTERNAL_ID="${BATCH_EXTERNAL_ID:-wdi_live_${RUN_TS}}"
WDI_PER_PAGE="${WDI_PER_PAGE:-20000}"

INDICATORS=(
  "NY.GDP.MKTP.CD"
  "NY.GDP.PCAP.CD"
  "FP.CPI.TOTL.ZG"
  "SP.POP.TOTL"
)

if [[ ! -f "$FETCH_HELPER" ]]; then
    echo "Fetch helper not found: $FETCH_HELPER" >&2
    exit 1
fi

if [[ -z "$WDI_COUNTRIES" || "${WDI_COUNTRIES,,}" == "default" || "${WDI_COUNTRIES,,}" == "all" ]]; then
    WDI_COUNTRIES="$($PSQL_CMD -d "$DB_NAME" -Atqc "SELECT string_agg(iso_alpha_3, ';' ORDER BY iso_alpha_3) FROM ref.country WHERE is_active = TRUE AND COALESCE(is_aggregate, FALSE) = FALSE")"
fi

if [[ -z "$WDI_COUNTRIES" ]]; then
    echo "No WDI countries resolved. Seed ref.country first or pass WDI_COUNTRIES explicitly." >&2
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

for indicator_code in "${INDICATORS[@]}"; do
    safe_indicator="${indicator_code//./_}"
    snapshot_path="$SNAPSHOT_ROOT/${RUN_TS}_${safe_indicator}.json"
    url="https://api.worldbank.org/v2/country/${WDI_COUNTRIES}/indicator/${indicator_code}?format=json&date=${WDI_YEARS}&per_page=${WDI_PER_PAGE}"

    echo "Fetching WDI ${indicator_code}..."
    meta_json="$(python3 "$FETCH_HELPER" --url "$url" --output "$snapshot_path")"

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

    snapshot_paths+=("$snapshot_path")
done

python3 - "$row_csv" "${snapshot_paths[@]}" <<'PY'
import csv
import json
import sys
from pathlib import Path

out_path = Path(sys.argv[1])
snapshot_paths = sys.argv[2:]
fieldnames = [
    "country_code",
    "country_name",
    "indicator_code",
    "indicator_name",
    "year",
    "value",
    "obs_status",
    "decimal",
    "snapshot_path",
]

with out_path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=fieldnames)
    writer.writeheader()
    for snapshot_path in snapshot_paths:
        with open(snapshot_path, "r", encoding="utf-8") as source_handle:
            payload = json.load(source_handle)
        rows = payload[1] if isinstance(payload, list) and len(payload) > 1 else []
        for row in rows:
            writer.writerow({
                "country_code": row.get("countryiso3code") or "",
                "country_name": (row.get("country") or {}).get("value", ""),
                "indicator_code": (row.get("indicator") or {}).get("id", ""),
                "indicator_name": (row.get("indicator") or {}).get("value", ""),
                "year": row.get("date", ""),
                "value": "" if row.get("value") is None else str(row.get("value")),
                "obs_status": row.get("obs_status", "") or "",
                "decimal": "" if row.get("decimal") is None else str(row.get("decimal")),
                "snapshot_path": str(Path(snapshot_path).resolve()),
            })
PY

row_count_reported="$(python3 - "$row_csv" <<'PY'
import csv
import sys
with open(sys.argv[1], newline='', encoding='utf-8') as handle:
    print(sum(1 for _ in csv.DictReader(handle)))
PY
)"

export BATCH_EXTERNAL_ID WDI_COUNTRIES WDI_YEARS WDI_DATASET_CODE SNAPSHOT_ROOT row_count_reported meta_tsv row_csv

echo "=== Loading live WDI slice into $DB_NAME ==="

$PSQL_CMD \
    -d "$DB_NAME" <<SQL
CREATE TEMP TABLE tmp_wdi_snapshot_meta (
    snapshot_path TEXT,
    content_type TEXT,
    file_hash_sha256 TEXT,
    fetched_at TIMESTAMPTZ,
    http_status_code INT,
    source_url TEXT
);

\copy tmp_wdi_snapshot_meta FROM '$meta_tsv' WITH (FORMAT csv, DELIMITER E'\t', HEADER true);

CREATE TEMP TABLE tmp_wdi_live_rows (
    country_code TEXT,
    country_name TEXT,
    indicator_code TEXT,
    indicator_name TEXT,
    year TEXT,
    value TEXT,
    obs_status TEXT,
    decimal TEXT,
    snapshot_path TEXT
);

\copy tmp_wdi_live_rows FROM '$row_csv' WITH (FORMAT csv, HEADER true);

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
            'loader', 'scripts/load_wdi_live.sh',
            'countries', '$WDI_COUNTRIES',
            'years', '$WDI_YEARS',
            'dataset_code', '$WDI_DATASET_CODE',
            'snapshot_root', '$SNAPSHOT_ROOT',
            'indicators', jsonb_build_array('NY.GDP.MKTP.CD', 'NY.GDP.PCAP.CD', 'FP.CPI.TOTL.ZG', 'SP.POP.TOTL'),
            'api_indicator_codes', jsonb_build_array('NY.GDP.MKTP.CD', 'NY.GDP.PCAP.CD', 'FP.CPI.TOTL.ZG', 'SP.POP.TOTL'),
            'source_series_codes', jsonb_build_array('NY.GDP.MKTP.CD', 'NY.GDP.PCAP.CD', 'FP.CPI.TOTL.ZG', 'SP.POP.TOTL')
        ),
        COALESCE((SELECT MAX(fetched_at) FROM tmp_wdi_snapshot_meta), CURRENT_TIMESTAMP),
        NULL,
        'queued',
        $row_count_reported
    FROM ref.source_dataset d
    WHERE d.dataset_code = '$WDI_DATASET_CODE'
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
FROM tmp_wdi_snapshot_meta
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
        'loader', 'scripts/load_wdi_live.sh',
        'snapshot_path', snapshot_path,
        'ingestion_type', 'live_api_snapshot'
    )
FROM tmp_wdi_live_rows;

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

echo "=== Live WDI load complete ==="
