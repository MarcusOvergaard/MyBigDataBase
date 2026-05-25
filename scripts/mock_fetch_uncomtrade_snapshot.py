#!/usr/bin/env python3
import argparse
import hashlib
import json
import shutil
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / 'tests' / 'fixtures' / 'live_sources' / 'un_comtrade'
FIXTURES = {
    '2019': ROOT / '2019.json',
    '2020': ROOT / '2020.json',
    '2021': ROOT / '2021.json',
    '2022': ROOT / '2022.json',
    '2023': ROOT / '2023.json',
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('--period', required=True)
    parser.add_argument('--output', required=True)
    parser.add_argument('--tradeflows', default='x,m')
    parser.add_argument('--reporters', default='all')
    parser.add_argument('--partner', default='0')
    parser.add_argument('--commodity', default='total')
    args = parser.parse_args()

    if args.period not in FIXTURES:
        raise SystemExit(f'No mock fixture for period: {args.period}')

    src = FIXTURES[args.period]
    dst = Path(args.output).resolve()
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(src, dst)
    body = dst.read_bytes()
    payload = json.loads(body)
    fetched_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace('+00:00', 'Z')
    url = f'https://comtradeplus.un.org/api/Trade/getDataComtrade?period={args.period}&tradeflows={args.tradeflows}'
    print(json.dumps({
        'requested_url': url,
        'final_url': url,
        'output_path': str(dst),
        'fetched_at': fetched_at,
        'http_status_code': 200,
        'content_type': 'text/plain; charset=utf-8',
        'file_hash_sha256': hashlib.sha256(body).hexdigest(),
        'bytes_written': len(body),
        'period': args.period,
        'tradeflows': args.tradeflows,
        'row_count_reported': payload.get('count'),
    }))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
