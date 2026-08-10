"""Build complete Eww-facing calendar snapshots."""

from datetime import UTC, datetime
from zoneinfo import ZoneInfo

from lav_shell.calendar.constants import (
  MAX_ALL_DAY_EVENTS,
  MAX_FUTURE_EVENTS,
  SNAPSHOT_SCHEMA,
  TIMELINE_WIDTH,
)
from lav_shell.calendar.models import (
  AllDayEvent,
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


def all_day_items(
  *, events: list[AllDayEvent]
) -> tuple[list[JsonObject], int]:
  """Build a bounded all-day row and report hidden items."""
  visible = events[:MAX_ALL_DAY_EVENTS]
  items = [
    {
      "title": event.text.title,
      "color": event.text.color,
      "tooltip": "\n".join(
        part
        for part in (
          event.text.title,
          event.text.location,
          event.text.description,
        )
        if part
      ),
    }
    for event in visible
  ]
  return items, len(events) - len(visible)


def future_items(*, events: list[FutureEvent]) -> list[JsonObject]:
  """Build the bounded non-timeline future-event rail."""
  items = []
  for start, text, all_day in sorted(
    events, key=lambda item: item[0]
  )[:MAX_FUTURE_EVENTS]:
    when = start.strftime(
      "%a %d %b · all day" if all_day else "%a %d %b · %H:%M"
    )
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


def hidden_message(*, overlap: int, all_day: int) -> str:
  """Summarize bounded event omissions without exposing content."""
  hidden = overlap + all_day
  if hidden == 0:
    return ""
  suffix = "event" if hidden == 1 else "events"
  return f"{hidden} overlapping {suffix} hidden"


def build_snapshot(
  *, events: list[CalendarEvent], zone: ZoneInfo
) -> JsonObject:
  """Build one complete Eww-facing snapshot for the local day."""
  today, day_start, day_end = day_bounds(zone=zone)
  timed, all_day, future = partition_events(
    events=events,
    today=today,
    day_start=day_start,
    day_end=day_end,
    zone=zone,
  )
  rows, hidden_overlap = timeline_rows(
    events=timed, day_start=day_start, day_end=day_end
  )
  all_day, hidden_all_day = all_day_items(events=all_day)
  labels, ticks = marker_rows(start=day_start)
  return {
    "schema": SNAPSHOT_SCHEMA,
    "state": "ready",
    "message": hidden_message(
      overlap=hidden_overlap, all_day=hidden_all_day
    ),
    "heading": today.strftime("%a %d %b"),
    "refreshed_at": int(datetime.now(tz=UTC).timestamp()),
    "timeline_width": TIMELINE_WIDTH,
    "timeline_start": int(day_start.timestamp()),
    "timeline_end": int(day_end.timestamp()),
    "labels": labels,
    "ticks": ticks,
    "all_day": all_day,
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
    "all_day": [],
    "lanes": [
      {"index": 0, "segments": [gap_segment(width=TIMELINE_WIDTH)]}
    ],
    "future": [],
  }
