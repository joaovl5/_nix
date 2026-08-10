"""Load public lav-shell settings and private keyed secrets."""

import re
import tomllib
from pathlib import Path
from urllib.parse import urlsplit

from attrs import define
from pydantic import BaseModel, ConfigDict, Field, ValidationError

from lav_shell.errors import (
  CalendarConfigError,
  CalendarConfigMissingError,
  CalendarUrlInvalidError,
)

LAV_SHELL_CONFIG = Path.home() / ".config" / "eww" / "lav-shell.toml"
MAX_CALENDARS = 16
CALENDAR_NAME_PATTERN = re.compile(r"[a-z][a-z0-9_-]{0,31}")
COLOR_PATTERN = r"^#[0-9a-fA-F]{6}$"

type TomlObject = dict[str, object]


@define(frozen=True, slots=True)
class CalendarSource:
  """One private calendar URL with its public presentation metadata."""

  name: str
  color: str
  url: str


class GeneralConfig(BaseModel):
  """General lav-shell settings."""

  model_config = ConfigDict(extra="ignore", frozen=True)

  secrets_file: str = Field(min_length=1)


class CalendarMetadata(BaseModel):
  """Public presentation settings for one calendar."""

  model_config = ConfigDict(extra="forbid", frozen=True)

  color: str = Field(
    min_length=7, max_length=7, pattern=COLOR_PATTERN
  )


class LavShellConfig(BaseModel):
  """Public lav-shell configuration relevant to calendars."""

  model_config = ConfigDict(extra="ignore", frozen=True)

  general: GeneralConfig
  calendar: dict[str, CalendarMetadata] = Field(
    min_length=1, max_length=MAX_CALENDARS
  )


class IcalSecrets(BaseModel):
  """Private iCalendar URLs keyed by public calendar name."""

  model_config = ConfigDict(extra="ignore", frozen=True)

  ical_urls: dict[str, str]


class LavShellSecrets(BaseModel):
  """Private lav-shell configuration."""

  model_config = ConfigDict(extra="ignore", frozen=True)

  secrets: IcalSecrets


def parse_toml_file(*, path: Path) -> TomlObject:
  """Read one UTF-8 TOML object without exposing values in errors."""
  try:
    return tomllib.loads(path.read_text(encoding="utf-8"))
  except (
    OSError,
    UnicodeDecodeError,
    tomllib.TOMLDecodeError,
  ) as error:
    raise CalendarConfigError from error


def require_private_file(*, path: Path) -> None:
  """Require a secret file inaccessible to group and other users."""
  try:
    mode = path.stat().st_mode
  except OSError as error:
    raise CalendarConfigError from error
  if mode & 0o077:
    raise CalendarConfigError


def validate_url(*, url: str) -> None:
  """Require HTTPS without embedded basic-auth credentials."""
  parsed = urlsplit(url)
  if (
    parsed.scheme != "https"
    or not parsed.hostname
    or parsed.username is not None
    or parsed.password is not None
  ):
    raise CalendarUrlInvalidError


def load_calendar_sources(
  *, config_path: Path = LAV_SHELL_CONFIG
) -> list[CalendarSource]:
  """Merge public calendar metadata with keyed private URLs."""
  if not config_path.exists():
    raise CalendarConfigMissingError
  try:
    public = LavShellConfig.model_validate(
      parse_toml_file(path=config_path)
    )
  except ValidationError as error:
    raise CalendarConfigError from error

  secrets_path = Path(public.general.secrets_file).expanduser()
  if not secrets_path.is_absolute():
    secrets_path = config_path.parent / secrets_path
  require_private_file(path=secrets_path)
  try:
    private = LavShellSecrets.model_validate(
      parse_toml_file(path=secrets_path)
    )
  except ValidationError as error:
    raise CalendarConfigError from error

  sources = []
  for name, metadata in sorted(public.calendar.items()):
    if CALENDAR_NAME_PATTERN.fullmatch(name) is None:
      raise CalendarConfigError
    url = private.secrets.ical_urls.get(name, "").strip()
    if not url:
      raise CalendarConfigError
    try:
      validate_url(url=url)
    except CalendarUrlInvalidError as error:
      raise CalendarConfigError from error
    sources.append(
      CalendarSource(name=name, color=metadata.color, url=url)
    )
  return sources
