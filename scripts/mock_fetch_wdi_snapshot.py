#!/usr/bin/env python3
import argparse
import hashlib
import json
import shutil
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / 'ingest' / 'snapshots' / 'wdi' / 'WDI'
FIXTURES = {
    'NY.GDP.MKTP.CD': ROOT / '20260529T011517Z_NY_GDP_MKTP_CD.json',
    'NY.GDP.PCAP.CD': ROOT / '20260529T011517Z_NY_GDP_PCAP_CD.json',
    'FP.CPI.TOTL.ZG': ROOT / '20260529T011517Z_FP_CPI_TOTL_ZG.json',
    'SP.POP.TOTL': ROOT / '20260529T011517Z_SP_POP_TOTL.json',
    'SP.DYN.TFRT.IN': ROOT / '20260529T011517Z_SP_DYN_TFRT_IN.json',
    'SP.DYN.LE00.IN': ROOT / '20260529T011517Z_SP_DYN_LE00_IN.json',
    'SE.PRM.ENRR': ROOT / '20260529T011517Z_SE_PRM_ENRR.json',
    'EG.ELC.ACCS.ZS': ROOT / '20260529T011517Z_EG_ELC_ACCS_ZS.json',
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('--url', required=True)
    parser.add_argument('--output', required=True)
    parser.add_argument('--timeout', type=int, default=60)
    parser.add_argument('--user-agent', default='')
    args = parser.parse_args()

    marker = '/indicator/'
    if marker not in args.url:
        raise SystemExit(f'No WDI indicator found in URL: {args.url}')
    indicator_code = args.url.split(marker, 1)[1].split('?', 1)[0]
    if indicator_code not in FIXTURES:
        raise SystemExit(f'No mock fixture for WDI indicator: {indicator_code}')

    src = FIXTURES[indicator_code]
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
