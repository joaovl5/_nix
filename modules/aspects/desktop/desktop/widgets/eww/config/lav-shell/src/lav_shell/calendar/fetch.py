"""Fetch bounded private iCalendar responses."""

import requests

from lav_shell.config import validate_url
from lav_shell.errors import CalendarFetchError

MAX_RESPONSE_BYTES = 5 * 1024 * 1024
REQUEST_TIMEOUT = (5, 20)


def fetch_calendar(*, url: str) -> bytes:
  """Download a bounded HTTPS response without logging its secret URL."""
  try:
    with requests.get(
      url,
      allow_redirects=False,
      headers={
        "Accept": "text/calendar",
        "User-Agent": "lav-shell-calendar/1",
      },
      stream=True,
      timeout=REQUEST_TIMEOUT,
    ) as response:
      validate_url(url=response.url)
      if response.is_redirect or response.is_permanent_redirect:
        raise CalendarFetchError
      response.raise_for_status()
      content_length = response.headers.get("Content-Length")
      if (
        content_length is not None
        and int(content_length) > MAX_RESPONSE_BYTES
      ):
        raise CalendarFetchError

      payload = bytearray()
      for chunk in response.iter_content(chunk_size=64 * 1024):
        payload.extend(chunk)
        if len(payload) > MAX_RESPONSE_BYTES:
          raise CalendarFetchError
  except (requests.RequestException, ValueError) as error:
    raise CalendarFetchError from error
  return bytes(payload)
