"""Persist source-bound last-good calendar snapshots privately."""

import hashlib
import json
import os
from pathlib import Path

from lav_shell.calendar.constants import SNAPSHOT_SCHEMA
from lav_shell.calendar.models import JsonObject
from lav_shell.calendar.snapshot import empty_snapshot
from lav_shell.config import CalendarSource


def source_fingerprint(*, sources: list[CalendarSource]) -> str:
  """Identify feeds and colors without retaining secret URLs."""
  digest = hashlib.sha256()
  for source in sources:
    digest.update(source.name.encode())
    digest.update(b"\0")
    digest.update(source.color.encode())
    digest.update(b"\0")
    digest.update(source.url.encode())
    digest.update(b"\0")
  return digest.hexdigest()


def cache_path() -> Path:
  """Return the private user cache path for the last good snapshot."""
  configured = os.environ.get("XDG_CACHE_HOME")
  cache_home = (
    Path(configured) if configured else Path.home() / ".cache"
  )
  return cache_home / "eww" / "calendar.json"


def load_cache(*, fingerprint: str) -> JsonObject | None:
  """Load a last-good snapshot only for the configured feeds."""
  try:
    value = json.loads(cache_path().read_text(encoding="utf-8"))
  except OSError, json.JSONDecodeError:
    return None
  if (
    not isinstance(value, dict)
    or value.get("schema") != SNAPSHOT_SCHEMA
    or value.get("source_fingerprint") != fingerprint
  ):
    return None
  snapshot = value.get("snapshot")
  if (
    not isinstance(snapshot, dict)
    or snapshot.get("schema") != SNAPSHOT_SCHEMA
  ):
    return None
  return snapshot


def write_cache(*, snapshot: JsonObject, fingerprint: str) -> None:
  """Atomically write a source-bound private snapshot when possible."""
  path = cache_path()
  temporary = path.with_suffix(".tmp")
  envelope = {
    "schema": SNAPSHOT_SCHEMA,
    "source_fingerprint": fingerprint,
    "snapshot": snapshot,
  }
  try:
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    temporary.write_text(
      json.dumps(envelope, ensure_ascii=False, separators=(",", ":")),
      encoding="utf-8",
    )
    temporary.chmod(0o600)
    temporary.replace(path)
  except OSError:
    temporary.unlink(missing_ok=True)


def stale_snapshot(*, message: str, fingerprint: str) -> JsonObject:
  """Return matching cached data as stale, or an empty error state."""
  cached = load_cache(fingerprint=fingerprint)
  if cached is None:
    return empty_snapshot(state="error", message=message)
  cached["state"] = "stale"
  cached["message"] = f"{message} · showing cached data"
  return cached
