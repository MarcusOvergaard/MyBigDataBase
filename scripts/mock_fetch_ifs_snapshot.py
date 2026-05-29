#!/usr/bin/env python3
import argparse
import hashlib
import json
import shutil
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / 'tests' / 'fixtures' / 'live_sources' / 'ifs'
FIXTURES = {
    'countries': ROOT / 'countries.json',
    'PCPIPCH': ROOT / 'PCPIPCH.json',
    'NGDPD': ROOT / 'NGDPD.json',
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('--url', required=True)
    parser.add_argument('--output', required=True)
    parser.add_argument('--timeout', type=int, default=60)
    parser.add_argument('--user-agent', default='')
    args = parser.parse_args()

    key = args.url.rstrip('/').split('/')[-1]
    if key not in FIXTURES:
        raise SystemExit(f'No mock fixture for URL: {args.url}')

    src = FIXTURES[key]
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
