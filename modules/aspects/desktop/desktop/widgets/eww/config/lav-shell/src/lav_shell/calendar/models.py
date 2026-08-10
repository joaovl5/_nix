"""Typed calendar occurrences and Eww-facing data shapes."""

from datetime import date, datetime

from attrs import define


type JsonObject = dict[str, object]


@define(frozen=True, slots=True)
class EventText:
  """Bounded text displayed for one calendar event."""

  title: str
  location: str
  description: str
  color: str


@define(frozen=True, slots=True)
class TimedEvent:
  """One timezone-aware timed calendar occurrence."""

  start: datetime
  end: datetime
  text: EventText


@define(frozen=True, slots=True)
class AllDayEvent:
  """One all-day calendar occurrence with an exclusive end date."""

  start: date
  end: date
  text: EventText


type CalendarEvent = TimedEvent | AllDayEvent
type PlacedEvent = tuple[datetime, datetime, EventText]
type FutureEvent = tuple[datetime, EventText, bool]
