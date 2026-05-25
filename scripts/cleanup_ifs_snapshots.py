#!/usr/bin/env python3
import argparse
import json
import os
from pathlib import Path


def load_referenced_files(snapshot_root: Path) -> set[Path]:
    keep = set()
    for manifest_path in snapshot_root.glob("*_manifest.json"):
        with manifest_path.open("r", encoding="utf-8") as handle:
            payload = json.load(handle)
        referenced_paths = []
        for snapshot in payload.get("snapshots", []):
            output_path = snapshot.get("output_path") or snapshot.get("snapshot_path")
            if output_path:
                referenced_paths.append(Path(output_path).resolve())
        if referenced_paths and all(path.exists() for path in referenced_paths):
            keep.add(manifest_path.resolve())
            keep.update(referenced_paths)
    return keep


def main() -> int:
    parser = argparse.ArgumentParser(description="Delete stale IFS snapshot files not referenced by any manifest.")
    parser.add_argument(
        "--snapshot-root",
        default="ingest/snapshots/ifs/IFS",
        help="Directory containing IFS snapshots and manifest files.",
    )
    parser.add_argument("--dry-run", action="store_true", help="List stale files without deleting them.")
    args = parser.parse_args()

    snapshot_root = Path(args.snapshot_root).resolve()
    if not snapshot_root.exists():
        print(f"Snapshot root does not exist: {snapshot_root}")
        return 0

    keep = load_referenced_files(snapshot_root)
    candidates = sorted(
        path.resolve()
        for path in snapshot_root.iterdir()
        if path.is_file() and path.suffix in {".json", ".tsv", ".csv"}
    )
    stale = [path for path in candidates if path not in keep]

    if not stale:
        print(f"No stale snapshot files under {snapshot_root}")
        return 0

    for path in stale:
        if args.dry_run:
            print(f"STALE\t{path}")
        else:
            path.unlink(missing_ok=True)
            print(f"REMOVED\t{path}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
