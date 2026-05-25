#!/usr/bin/env python3
import argparse
import hashlib
import json
import os
import sys
import urllib.request
from datetime import datetime, timezone


def main() -> int:
    parser = argparse.ArgumentParser(description="Fetch an HTTP resource and save it as a local snapshot.")
    parser.add_argument("--url", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--timeout", type=int, default=60)
    parser.add_argument("--user-agent", default="MyBigDataBase/phase2-loader")
    args = parser.parse_args()

    headers = {}
    if args.user_agent:
        headers["User-Agent"] = args.user_agent
    request = urllib.request.Request(args.url, headers=headers)
    fetched_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")

    try:
        with urllib.request.urlopen(request, timeout=args.timeout) as response:
            body = response.read()
            final_url = response.geturl()
            status_code = getattr(response, "status", response.getcode())
            content_type = response.headers.get("Content-Type", "")
    except Exception as exc:
        error_payload = {
            "requested_url": args.url,
            "output_path": os.path.abspath(args.output),
            "fetched_at": fetched_at,
            "error": str(exc),
        }
        print(json.dumps(error_payload), file=sys.stderr)
        return 1

    output_path = os.path.abspath(args.output)
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, "wb") as handle:
        handle.write(body)

    sha256 = hashlib.sha256(body).hexdigest()
    metadata = {
        "requested_url": args.url,
        "final_url": final_url,
        "output_path": output_path,
        "fetched_at": fetched_at,
        "http_status_code": status_code,
        "content_type": content_type,
        "file_hash_sha256": sha256,
        "bytes_written": len(body),
    }
    print(json.dumps(metadata))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
