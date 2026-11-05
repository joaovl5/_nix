"""Build complete Eww-facing calendar snapshots."""

from datetime import UTC, datetime
from zoneinfo import ZoneInfo

from lav_shell.calendar.constants import (
  MAX_FUTURE_EVENTS,
  SNAPSHOT_SCHEMA,
  TIMELINE_WIDTH,
)
from lav_shell.calendar.models import (
  CalendarEvent,
  FutureEvent,
  JsonObject,
)
from lav_shell.calendar.timeline import (
  day_bounds,
  gap_segment,
  marker_rows,
  partition_events,
  timeline_rows,
)


def future_items(*, events: list[FutureEvent]) -> list[JsonObject]:
  """Build the bounded non-timeline future-event rail."""
  items = []
  for start, text in sorted(events, key=lambda item: item[0])[
    :MAX_FUTURE_EVENTS
  ]:
    when = start.strftime("%a %d %b · %H:%M")
    items.append(
      {
        "when": when,
        "color": text.color,
        "title": text.title,
        "tooltip": "\n".join(
          part
          for part in (text.title, text.location, text.description)
          if part
        ),
      }
    )
  return items


def hidden_message(*, overlap: int) -> str:
  """Summarize bounded event omissions without exposing content."""
  if overlap == 0:
    return ""
  suffix = "event" if overlap == 1 else "events"
  return f"{overlap} overlapping {suffix} hidden"


def build_snapshot(
  *, events: list[CalendarEvent], zone: ZoneInfo
) -> JsonObject:
  """Build one complete Eww-facing snapshot for the local day."""
  today, day_start, day_end = day_bounds(zone=zone)
  timed, future = partition_events(
    events=events, day_start=day_start, day_end=day_end
  )
  rows, hidden_overlap = timeline_rows(
    events=timed, day_start=day_start, day_end=day_end
  )
  labels, ticks = marker_rows(start=day_start)
  return {
    "schema": SNAPSHOT_SCHEMA,
    "state": "ready",
    "message": hidden_message(overlap=hidden_overlap),
    "heading": today.strftime("%a %d %b"),
    "refreshed_at": int(datetime.now(tz=UTC).timestamp()),
    "timeline_width": TIMELINE_WIDTH,
    "timeline_start": int(day_start.timestamp()),
    "timeline_end": int(day_end.timestamp()),
    "labels": labels,
    "ticks": ticks,
    "lanes": rows,
    "future": future_items(events=future),
  }


def empty_snapshot(*, state: str, message: str) -> JsonObject:
  """Build a valid empty snapshot for disabled or failed states."""
  labels, ticks = [], []
  return {
    "schema": SNAPSHOT_SCHEMA,
    "state": state,
    "message": message,
    "heading": "calendar",
    "refreshed_at": 0,
    "timeline_width": TIMELINE_WIDTH,
    "timeline_start": 0,
    "timeline_end": 1,
    "labels": labels,
    "ticks": ticks,
    "lanes": [
      {"index": 0, "segments": [gap_segment(width=TIMELINE_WIDTH)]}
    ],
    "future": [],
  }
