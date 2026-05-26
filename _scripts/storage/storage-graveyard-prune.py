#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = [
#     "cyclopts>=4.5.1",
# ]
# ///
"""Prune expired entries from the graveyard record file."""

import datetime as dt
import shutil
from pathlib import Path

from cyclopts import App, CycloptsError

RECORD_FILENAME = ".record"
RECORD_TIMESTAMP_FORMAT = "%a %b %d %H:%M:%S %Y"

app = App(
  name="storage-graveyard-prune",
  result_action="return_value",
  exit_on_error=False,
  print_error=False,
)


def parse_record_line(raw_line: str) -> tuple[dt.datetime, Path] | None:
  """Parse a graveyard record line into its timestamp and buried path."""
  try:
    removed_at_raw, _original_path, buried_path = raw_line.split("\t", 2)
    removed_at = dt.datetime.strptime(removed_at_raw, RECORD_TIMESTAMP_FORMAT)
  except ValueError:
    return None
  return removed_at, Path(buried_path)


def is_within_root(*, candidate: Path, root: Path) -> bool:
  """Return whether the candidate path stays within the graveyard root."""
  return candidate.is_relative_to(root)


def prune_empty_parents(*, path: Path, graveyard_root: Path) -> None:
  """Remove empty ancestor directories up to the graveyard root."""
  parent = path
  while parent != graveyard_root and parent.exists():
    try:
      parent.rmdir()
    except OSError:
      break
    parent = parent.parent


def remove_expired_entry(*, entry_path: Path, graveyard_root: Path) -> None:
  """Delete one expired graveyard entry and clean up empty parent directories."""
  if entry_path.is_symlink() or entry_path.is_file():
    entry_path.unlink(missing_ok=True)
  elif entry_path.is_dir():
    shutil.rmtree(entry_path, ignore_errors=True)

  prune_empty_parents(path=entry_path.parent, graveyard_root=graveyard_root)


def prune_graveyard(*, graveyard_root: Path, retention_days: int) -> None:
  """Remove expired graveyard entries and rewrite the retained record file."""
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
    if not is_within_root(
      candidate=buried_parent_resolved,
      root=graveyard_root_resolved,
    ):
      kept_lines.append(raw_line)
      continue

    if now - removed_at <= retention_window:
      kept_lines.append(raw_line)
      continue

    buried_entry = buried_parent_resolved / buried_path.name
    remove_expired_entry(
      entry_path=buried_entry,
      graveyard_root=graveyard_root_resolved,
    )

  record_path.write_text(
    "".join(f"{line}\n" for line in kept_lines), encoding="utf-8"
  )


@app.default
def main(*, graveyard_root: Path, retention_days: int) -> int:
  """Prune expired entries from the graveyard record file."""
  if retention_days < 0:
    raise SystemExit("--retention-days must be non-negative")
  prune_graveyard(
    graveyard_root=graveyard_root.expanduser(),
    retention_days=retention_days,
  )
  return 0


if __name__ == "__main__":
  try:
    raise SystemExit(app())
  except CycloptsError as error:
    print(error)
    raise SystemExit(1)
