#!/usr/bin/env python3
import argparse
import hashlib
import http.cookiejar
import json
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

BASE = 'https://comtradeplus.un.org'
UA = 'Mozilla/5.0'


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('--period', required=True)
    parser.add_argument('--output', required=True)
    parser.add_argument('--tradeflows', default='x,m')
    parser.add_argument('--reporters', default='all')
    parser.add_argument('--partner', default='0')
    parser.add_argument('--commodity', default='total')
    args = parser.parse_args()

    jar = http.cookiejar.CookieJar()
    opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))
    token_req = urllib.request.Request(
        BASE + '/api/Trade/GetCsrfToken',
        headers={'User-Agent': UA, 'Referer': BASE + '/TradeFlow'},
    )
    with opener.open(token_req, timeout=60) as response:
        token = json.load(response)['csrfToken']

    params = {
        'selectedProductOptionsModified': 'C',
        'selectedFrequencyOptionsModified': 'A',
        'selectedClassificationOptionsModified': 'HS',
        'selectValuePeriodsModified': args.period,
        'selectValueReportersModified': args.reporters,
        'selectValuePartnersModified': args.partner,
        'selectValueTradeflowsModified': args.tradeflows,
        'selectValueCommodityCodesModified': args.commodity,
        'selectValueCustomsCodesModified': 'c00',
        'selectValueTransportCodesModified': '0',
        'selectValueSecondPartnersModified': '0',
        'selectValueAggregateByModified': 'none',
        'selectValueBreakdownModeModified': 'classic',
        'selectValueincludeDescModified': 'True',
        'selectValuecountOnlyModified': 'False',
    }
    body = dict(params)
    body['userID'] = None
    query = urllib.parse.urlencode(params)
    url = BASE + '/api/Trade/getDataComtrade?' + query
    req = urllib.request.Request(
        url,
        data=json.dumps(body).encode('utf-8'),
        method='POST',
        headers={
            'User-Agent': UA,
            'Referer': BASE + '/TradeFlow',
            'X-Requested-With': 'XMLHttpRequest',
            'X-CSRF-TOKEN': token,
            'Content-Type': 'application/json;charset=UTF-8',
        },
    )
    with opener.open(req, timeout=120) as response:
        payload = response.read()
        status = response.status
        content_type = response.headers.get('content-type', '')

    output = Path(args.output).resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(payload)
    fetched_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace('+00:00', 'Z')
    meta = {
        'requested_url': url,
        'final_url': url,
        'output_path': str(output),
        'fetched_at': fetched_at,
        'http_status_code': status,
        'content_type': content_type,
        'file_hash_sha256': hashlib.sha256(payload).hexdigest(),
        'bytes_written': len(payload),
        'period': args.period,
        'reporters': args.reporters,
        'tradeflows': args.tradeflows,
    }
    try:
        parsed = json.loads(payload)
        meta['row_count_reported'] = parsed.get('count')
    except Exception:
        pass
    print(json.dumps(meta))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
