"""Public calendar provider API."""

from lav_shell.calendar.command import collect_events, main
from lav_shell.calendar.constants import SNAPSHOT_SCHEMA
from lav_shell.calendar.models import (
  AllDayEvent,
  CalendarEvent,
  EventText,
  JsonObject,
  TimedEvent,
)
from lav_shell.calendar.parse import local_zone, parse_calendar
from lav_shell.calendar.snapshot import build_snapshot, empty_snapshot
from lav_shell.config import CalendarSource, load_calendar_sources
from lav_shell.errors import (
  CalendarConfigError,
  CalendarConfigMissingError,
  CalendarFetchError,
  CalendarParseError,
  CalendarUrlInvalidError,
  CalendarWidgetError,
)

__all__ = [
  "AllDayEvent",
  "CalendarConfigError",
  "CalendarConfigMissingError",
  "CalendarEvent",
  "CalendarFetchError",
  "CalendarParseError",
  "CalendarSource",
  "CalendarUrlInvalidError",
  "CalendarWidgetError",
  "EventText",
  "JsonObject",
  "SNAPSHOT_SCHEMA",
  "TimedEvent",
  "build_snapshot",
  "collect_events",
  "empty_snapshot",
  "load_calendar_sources",
  "local_zone",
  "main",
  "parse_calendar",
]
