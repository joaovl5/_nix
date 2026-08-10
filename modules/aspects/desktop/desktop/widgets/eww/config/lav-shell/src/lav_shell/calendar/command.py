"""Run the calendar-state provider consumed by Eww."""

import json
import sys
from zoneinfo import ZoneInfo

from lav_shell.calendar.cache import (
  source_fingerprint,
  stale_snapshot,
  write_cache,
)
from lav_shell.calendar.constants import MAX_EXPANDED_EVENTS
from lav_shell.calendar.fetch import fetch_calendar
from lav_shell.calendar.models import CalendarEvent, JsonObject
from lav_shell.calendar.parse import local_zone, parse_calendar
from lav_shell.calendar.snapshot import build_snapshot, empty_snapshot
from lav_shell.config import CalendarSource, load_calendar_sources
from lav_shell.errors import (
  CalendarConfigError,
  CalendarConfigMissingError,
  CalendarFetchError,
  CalendarParseError,
  CalendarUrlInvalidError,
)


def emit(*, snapshot: JsonObject) -> None:
  """Emit exactly one compact JSON line for Eww defpoll."""
  sys.stdout.write(
    f"{json.dumps(snapshot, ensure_ascii=False, separators=(',', ':'))}\n"
  )


def collect_events(
  *, sources: list[CalendarSource], zone: ZoneInfo
) -> list[CalendarEvent]:
  """Fetch configured feeds and enforce one aggregate occurrence bound."""
  events: list[CalendarEvent] = []
  for source in sources:
    payload = fetch_calendar(url=source.url)
    events.extend(
      parse_calendar(payload=payload, zone=zone, color=source.color)
    )
    if len(events) > MAX_EXPANDED_EVENTS:
      raise CalendarParseError
  return events


def main() -> None:
  """Fetch, normalize, cache, and emit the calendar state."""
  try:
    sources = load_calendar_sources()
  except CalendarConfigMissingError:
    emit(
      snapshot=empty_snapshot(
        state="disabled", message="configure lav-shell.toml"
      )
    )
    return
  except CalendarConfigError:
    emit(
      snapshot=empty_snapshot(
        state="error", message="calendar configuration is invalid"
      )
    )
    return

  fingerprint = source_fingerprint(sources=sources)
  zone = local_zone()
  try:
    events = collect_events(sources=sources, zone=zone)
  except CalendarFetchError, CalendarUrlInvalidError:
    emit(
      snapshot=stale_snapshot(
        message="calendar refresh failed", fingerprint=fingerprint
      )
    )
    return
  except CalendarParseError:
    emit(
      snapshot=stale_snapshot(
        message="calendar feed is invalid", fingerprint=fingerprint
      )
    )
    return

  snapshot = build_snapshot(events=events, zone=zone)
  write_cache(snapshot=snapshot, fingerprint=fingerprint)
  emit(snapshot=snapshot)
