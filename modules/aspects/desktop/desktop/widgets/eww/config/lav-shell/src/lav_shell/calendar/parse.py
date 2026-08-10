"""Parse and normalize bounded iCalendar occurrences."""

import os
from datetime import UTC, date, datetime, time, timedelta
from pathlib import Path
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

import recurring_ical_events
from icalendar import Calendar
from icalendar import Event as ICalEvent

from lav_shell.calendar.constants import (
  MAX_EXPANDED_EVENTS,
  POLL_HORIZON_DAYS,
)
from lav_shell.calendar.models import (
  AllDayEvent,
  CalendarEvent,
  EventText,
  TimedEvent,
)
from lav_shell.errors import CalendarParseError


def local_zone() -> ZoneInfo:
  """Resolve the system IANA timezone, falling back safely to UTC."""
  candidates = [os.environ.get("TZ", "")]
  localtime = Path("/etc/localtime")
  try:
    resolved = localtime.resolve().as_posix()
  except OSError:
    resolved = ""
  if "/zoneinfo/" in resolved:
    candidates.append(resolved.partition("/zoneinfo/")[2])

  for name in candidates:
    if not name:
      continue
    try:
      return ZoneInfo(name)
    except ZoneInfoNotFoundError:
      continue
  return ZoneInfo("UTC")


def bounded_text(
  value: object, *, limit: int, default: str = ""
) -> str:
  """Convert one iCalendar property to compact bounded plain text."""
  if value is None:
    return default
  text = " ".join(str(value).replace("\x00", "").split())
  return text[:limit] or default


def event_text(*, event: ICalEvent, color: str) -> EventText:
  """Extract only bounded presentation fields from one event."""
  return EventText(
    title=bounded_text(
      event.get("SUMMARY"), limit=160, default="(untitled)"
    ),
    location=bounded_text(event.get("LOCATION"), limit=200),
    description=bounded_text(event.get("DESCRIPTION"), limit=500),
    color=color,
  )


def decoded_property(*, event: ICalEvent, name: str) -> object | None:
  """Decode an optional iCalendar property."""
  if event.get(name) is None:
    return None
  return event.decoded(name)


def zoned_datetime(*, value: datetime, zone: ZoneInfo) -> datetime:
  """Interpret floating times locally and convert aware times for display."""
  if value.tzinfo is None:
    return value.replace(tzinfo=zone)
  return value.astimezone(zone)


def timed_event(
  *, event: ICalEvent, start: datetime, zone: ZoneInfo, color: str
) -> TimedEvent:
  """Normalize a timed event and require an explicit later end."""
  raw_end = decoded_property(event=event, name="DTEND")
  if not isinstance(raw_end, datetime):
    raise CalendarParseError
  normalized_start = zoned_datetime(value=start, zone=zone)
  normalized_end = zoned_datetime(value=raw_end, zone=zone)
  if normalized_end.astimezone(UTC) <= normalized_start.astimezone(
    UTC
  ):
    raise CalendarParseError
  return TimedEvent(
    start=normalized_start,
    end=normalized_end,
    text=event_text(event=event, color=color),
  )


def all_day_event(
  *, event: ICalEvent, start: date, color: str
) -> AllDayEvent:
  """Normalize an all-day event using RFC 5545's exclusive end date."""
  raw_end = decoded_property(event=event, name="DTEND")
  if raw_end is None:
    end = start + timedelta(days=1)
  elif isinstance(raw_end, date) and not isinstance(
    raw_end, datetime
  ):
    end = raw_end
  else:
    raise CalendarParseError
  if end <= start:
    raise CalendarParseError
  return AllDayEvent(
    start=start,
    end=end,
    text=event_text(event=event, color=color),
  )


def normalize_event(
  *, event: ICalEvent, zone: ZoneInfo, color: str
) -> CalendarEvent | None:
  """Normalize one expanded occurrence or discard a cancellation."""
  status = bounded_text(event.get("STATUS"), limit=32).upper()
  if status == "CANCELLED":
    return None
  raw_start = decoded_property(event=event, name="DTSTART")
  if isinstance(raw_start, datetime):
    return timed_event(
      event=event, start=raw_start, zone=zone, color=color
    )
  if isinstance(raw_start, date):
    return all_day_event(event=event, start=raw_start, color=color)
  raise CalendarParseError


def parse_calendar(
  *, payload: bytes, zone: ZoneInfo, color: str
) -> list[CalendarEvent]:
  """Parse and expand a bounded window of recurring calendar events."""
  try:
    calendar = Calendar.from_ical(payload)
    today = datetime.now(tz=zone).date()
    window_start = datetime.combine(today, time.min, tzinfo=zone)
    window_end = datetime.combine(
      today + timedelta(days=POLL_HORIZON_DAYS + 1),
      time.min,
      tzinfo=zone,
    )
    occurrences = recurring_ical_events.of(calendar).between(
      window_start, window_end
    )
  except (KeyError, TypeError, ValueError, OverflowError) as error:
    raise CalendarParseError from error

  if len(occurrences) > MAX_EXPANDED_EVENTS:
    raise CalendarParseError
  events: list[CalendarEvent] = []
  for occurrence in occurrences:
    normalized = normalize_event(
      event=occurrence, zone=zone, color=color
    )
    if normalized is not None:
      events.append(normalized)
  return events
