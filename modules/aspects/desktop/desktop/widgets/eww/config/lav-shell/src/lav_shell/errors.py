"""Errors shared by lav-shell configuration and data providers."""


class LavShellError(Exception):
  """Base error for failures safe to expose as bounded UI states."""


class CalendarWidgetError(LavShellError):
  """Base calendar widget error."""


class CalendarConfigError(CalendarWidgetError):
  """The lav-shell calendar configuration is invalid."""


class CalendarConfigMissingError(CalendarConfigError):
  """The public lav-shell configuration is absent."""


class CalendarUrlInvalidError(CalendarWidgetError):
  """A configured or redirected calendar URL is unsafe."""


class CalendarFetchError(CalendarWidgetError):
  """A calendar feed could not be fetched safely."""


class CalendarParseError(CalendarWidgetError):
  """A calendar feed could not be parsed within its bounds."""
