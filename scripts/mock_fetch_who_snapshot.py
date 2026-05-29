#!/usr/bin/env python3
import argparse
import hashlib
import json
import re
import shutil
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parent.parent / 'tests' / 'fixtures' / 'live_sources' / 'who'
FIXTURES = {
    'DEU': ROOT / 'DEU_WHOSIS_000001.json',
    'USA': ROOT / 'USA_WHOSIS_000001.json',
    'CHN': ROOT / 'CHN_WHOSIS_000001.json',
    'IND': ROOT / 'IND_WHOSIS_000001.json',
    'ZAF': ROOT / 'ZAF_WHOSIS_000001.json',
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('--url', required=True)
    parser.add_argument('--output', required=True)
    parser.add_argument('--timeout', type=int, default=60)
    parser.add_argument('--user-agent', default='')
    args = parser.parse_args()

    decoded_url = unquote(args.url)
    match = re.search(r"SpatialDim eq '([A-Z]{3})'", decoded_url)
    if not match:
        raise SystemExit(f'No WHO country code found in URL: {args.url}')
    country_code = match.group(1)
    if country_code not in FIXTURES:
        raise SystemExit(f'No mock fixture for WHO country: {country_code}')

    src = FIXTURES[country_code]
    dst = Path(args.output).resolve()
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(src, dst)
    body = dst.read_bytes()
    fetched_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace('+00:00', 'Z')
    print(json.dumps({
        'requested_url': args.url,
        'final_url': args.url,
        'output_path': str(dst),
        'fetched_at': fetched_at,
        'http_status_code': 200,
        'content_type': 'application/json',
        'file_hash_sha256': hashlib.sha256(body).hexdigest(),
        'bytes_written': len(body),
    }))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
