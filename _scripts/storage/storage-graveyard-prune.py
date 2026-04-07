#!/usr/bin/env python3
"""Prune expired entries from the graveyard record file."""

from __future__ import annotations

import argparse
import datetime as dt
import shutil
from collections.abc import Sequence
from pathlib import Path

RECORD_FILENAME = ".record"
RECORD_TIMESTAMP_FORMAT = "%a %b %d %H:%M:%S %Y"


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="storage-graveyard-prune")
    parser.add_argument(
        "--graveyard-root",
        type=Path,
        required=True,
        help="Root directory containing the graveyard record and entries.",
    )
    parser.add_argument(
        "--retention-days",
        type=int,
        required=True,
        help="Days to keep graveyard entries before deleting them.",
    )
    return parser


def parse_record_line(raw_line: str) -> tuple[dt.datetime, Path] | None:
    try:
        removed_at_raw, _original_path, buried_path = raw_line.split("\t", 2)
        removed_at = dt.datetime.strptime(removed_at_raw, RECORD_TIMESTAMP_FORMAT)
    except ValueError:
        return None
    return removed_at, Path(buried_path)


def is_within_root(candidate: Path, root: Path) -> bool:
    return candidate.is_relative_to(root)


def prune_empty_parents(path: Path, graveyard_root: Path) -> None:
    parent = path
    while parent != graveyard_root and parent.exists():
        try:
            parent.rmdir()
        except OSError:
            break
        parent = parent.parent


def remove_expired_entry(entry_path: Path, graveyard_root: Path) -> None:
    if entry_path.is_symlink() or entry_path.is_file():
        entry_path.unlink(missing_ok=True)
    elif entry_path.is_dir():
        shutil.rmtree(entry_path, ignore_errors=True)

    prune_empty_parents(entry_path.parent, graveyard_root)


def prune_graveyard(graveyard_root: Path, retention_days: int) -> None:
    graveyard_root_resolved = graveyard_root.resolve(strict=False)
    record_path = graveyard_root / RECORD_FILENAME
    if not record_path.exists():
        return

    now = dt.datetime.now()
    retention_window = dt.timedelta(days=retention_days)
    kept_lines: list[str] = []

    for raw_line in record_path.read_text(encoding="utf-8").splitlines():
        if not raw_line.strip():
            continue

        parsed = parse_record_line(raw_line)
        if parsed is None:
            kept_lines.append(raw_line)
            continue

        removed_at, buried_path = parsed
        buried_parent_resolved = buried_path.parent.resolve(strict=False)
        if not is_within_root(buried_parent_resolved, graveyard_root_resolved):
            kept_lines.append(raw_line)
            continue

        if now - removed_at <= retention_window:
            kept_lines.append(raw_line)
            continue

        buried_entry = buried_parent_resolved / buried_path.name
        remove_expired_entry(buried_entry, graveyard_root_resolved)

    record_path.write_text(
        "".join(f"{line}\n" for line in kept_lines), encoding="utf-8"
    )


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    if args.retention_days < 0:
        parser.error("--retention-days must be non-negative")
    prune_graveyard(args.graveyard_root, args.retention_days)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
