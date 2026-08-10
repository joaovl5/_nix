"""Build bounded daily timeline geometry from normalized events."""

from datetime import UTC, date, datetime, time, timedelta
from zoneinfo import ZoneInfo

from lav_shell.calendar.constants import (
  MAX_LANES,
  MIN_VISIBLE_LABEL_CHARS,
  TIMELINE_WIDTH,
)
from lav_shell.calendar.models import (
  AllDayEvent,
  CalendarEvent,
  EventText,
  FutureEvent,
  JsonObject,
  PlacedEvent,
  TimedEvent,
)


def day_bounds(*, zone: ZoneInfo) -> tuple[date, datetime, datetime]:
  """Return a 12-hour window beginning at the current half hour."""
  now = datetime.now(tz=zone)
  start = now.replace(
    minute=(now.minute // 30) * 30, second=0, microsecond=0
  )
  return now.date(), start, start + timedelta(hours=12)


def partition_events(
  *,
  events: list[CalendarEvent],
  today: date,
  day_start: datetime,
  day_end: datetime,
  zone: ZoneInfo,
) -> tuple[list[PlacedEvent], list[AllDayEvent], list[FutureEvent]]:
  """Partition occurrences into today's rows and the future rail."""
  timed_today: list[PlacedEvent] = []
  all_day_today: list[AllDayEvent] = []
  future: list[FutureEvent] = []
  for event in events:
    match event:
      case TimedEvent(start, end, text):
        if end > day_start and start < day_end:
          timed_today.append(
            (max(start, day_start), min(end, day_end), text)
          )
        elif start >= day_end:
          future.append((start, text, False))
      case AllDayEvent(start, end, text):
        if start <= today < end:
          all_day_today.append(event)
        elif start > today:
          future.append(
            (
              datetime.combine(start, time.min, tzinfo=zone),
              text,
              True,
            )
          )
  return timed_today, all_day_today, future


def place_lanes(
  *, events: list[PlacedEvent]
) -> list[list[PlacedEvent]]:
  """Assign intersecting events to the first non-overlapping lane."""
  lanes: list[list[PlacedEvent]] = []
  lane_ends: list[datetime] = []
  for event in sorted(events, key=lambda item: (item[0], item[1])):
    start, end, _text = event
    lane_index = next(
      (
        index
        for index, lane_end in enumerate(lane_ends)
        if lane_end <= start
      ),
      None,
    )
    if lane_index is None:
      lanes.append([event])
      lane_ends.append(end)
    else:
      lanes[lane_index].append(event)
      lane_ends[lane_index] = end
  return lanes


def pixel_at(
  *, instant: datetime, day_start: datetime, day_end: datetime
) -> int:
  """Map an instant to a stable pixel boundary, including DST days."""
  utc_start = day_start.astimezone(UTC)
  day_seconds = (day_end.astimezone(UTC) - utc_start).total_seconds()
  elapsed = (instant.astimezone(UTC) - utc_start).total_seconds()
  return round(elapsed * TIMELINE_WIDTH / day_seconds)


def tooltip_for(
  *, text: EventText, start: datetime, end: datetime
) -> str:
  """Build bounded plain tooltip text for a timed event."""
  lines = [f"{start:%H:%M}-{end:%H:%M}  {text.title}"]
  if text.location:
    lines.append(text.location)
  if text.description:
    lines.append(text.description)
  return "\n".join(lines)


def gap_segment(*, width: int) -> JsonObject:
  """Create one inert timeline spacer."""
  return {
    "kind": "gap",
    "color": "",
    "width_px": width,
    "short_title": "",
    "label_chars": 0,
    "tooltip": "",
  }


def event_segment(
  *, event: PlacedEvent, start_px: int, end_px: int
) -> JsonObject:
  """Create one exact-width event segment."""
  start, end, text = event
  width = end_px - start_px
  label_chars = max(0, (width - 8) // 7)
  return {
    "kind": "event",
    "color": text.color,
    "width_px": width,
    "short_title": text.title[:label_chars]
    if label_chars >= MIN_VISIBLE_LABEL_CHARS
    else "",
    "label_chars": label_chars,
    "tooltip": tooltip_for(text=text, start=start, end=end),
  }


def lane_segments(
  *, lane: list[PlacedEvent], day_start: datetime, day_end: datetime
) -> list[JsonObject]:
  """Convert one lane to gap and event segments spanning the track."""
  segments: list[JsonObject] = []
  cursor = 0
  for index, event in enumerate(lane):
    start, end, _text = event
    raw_start = pixel_at(
      instant=start, day_start=day_start, day_end=day_end
    )
    raw_end = pixel_at(
      instant=end, day_start=day_start, day_end=day_end
    )
    remaining = len(lane) - index - 1
    latest_end = TIMELINE_WIDTH - remaining
    start_px = max(cursor, min(raw_start, latest_end - 1))
    end_px = min(latest_end, max(start_px + 1, raw_end))
    if start_px > cursor:
      segments.append(gap_segment(width=start_px - cursor))
    segments.append(
      event_segment(event=event, start_px=start_px, end_px=end_px)
    )
    cursor = end_px
  if cursor < TIMELINE_WIDTH:
    segments.append(gap_segment(width=TIMELINE_WIDTH - cursor))
  return segments


def timeline_rows(
  *, events: list[PlacedEvent], day_start: datetime, day_end: datetime
) -> tuple[list[JsonObject], int]:
  """Create bounded overlap lanes and report hidden events."""
  lanes = place_lanes(events=events)
  hidden = sum(len(lane) for lane in lanes[MAX_LANES:])
  visible_lanes = lanes[:MAX_LANES] or [[]]
  rows = [
    {
      "index": index,
      "segments": lane_segments(
        lane=lane, day_start=day_start, day_end=day_end
      ),
    }
    for index, lane in enumerate(visible_lanes)
  ]
  return rows, hidden


def marker_rows(
  *, start: datetime
) -> tuple[list[JsonObject], list[JsonObject]]:
  """Build 12 hours of aligned 30-minute labels and 15-minute ticks."""
  labels = []
  for index in range(24):
    left = round(index * TIMELINE_WIDTH / 24)
    right = round((index + 1) * TIMELINE_WIDTH / 24)
    instant = start + timedelta(minutes=index * 30)
    labels.append(
      {
        "text": instant.strftime("%H:%M"),
        "width_px": right - left,
      }
    )
  ticks = []
  for index in range(48):
    left = round(index * TIMELINE_WIDTH / 48)
    right = round((index + 1) * TIMELINE_WIDTH / 48)
    ticks.append({"major": index % 2 == 0, "width_px": right - left})
  return labels, ticks
