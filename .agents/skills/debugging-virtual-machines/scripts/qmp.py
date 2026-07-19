#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = [
#     "attrs",
#     "cyclopts>=4.5.1",
# ]
# ///

import base64
import json
import re
import secrets
import shlex
import socket
import sys
import time
from pathlib import Path
from typing import Annotated, BinaryIO

from attrs import define
from cyclopts import App, CycloptsError, Parameter

type JsonObject = dict[str, object]
type QmpKey = dict[str, str]

QMP_ABS_MAX = 0x7FFF
SERIAL_MARKER_PREFIX = "__qmp_serial__"
ANSI_ESCAPE_RE = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")

BASE_KEY_CODES = {
  **{chr(code): chr(code) for code in range(ord("a"), ord("z") + 1)},
  **{str(number): str(number) for number in range(10)},
  " ": "spc",
  "\t": "tab",
  "\n": "ret",
  "-": "minus",
  "=": "equal",
  "/": "slash",
  "\\": "backslash",
  ";": "semicolon",
  "'": "apostrophe",
  ",": "comma",
  ".": "dot",
  "[": "leftbracket",
  "]": "rightbracket",
  "`": "grave_accent",
}
SHIFT_KEY_CODES = {
  **{
    chr(code): chr(code + 32)
    for code in range(ord("A"), ord("Z") + 1)
  },
  "_": "minus",
  "+": "equal",
  "?": "slash",
  "|": "backslash",
  ":": "semicolon",
  '"': "apostrophe",
  "<": "comma",
  ">": "dot",
  "{": "leftbracket",
  "}": "rightbracket",
  "~": "grave_accent",
  "!": "1",
  "@": "2",
  "#": "3",
  "$": "4",
  "%": "5",
  "^": "6",
  "&": "7",
  "*": "8",
  "(": "9",
  ")": "0",
}
QCODE_ALIASES = {
  "enter": "ret",
  "return": "ret",
  "esc": "esc",
  "escape": "esc",
  "space": "spc",
  "tab": "tab",
  "delete": "delete",
  "backspace": "backspace",
  "pgup": "pgup",
  "pageup": "pgup",
  "pgdn": "pgdn",
  "pagedown": "pgdn",
}
ALLOWED_QCODES = {
  "alt",
  "ctrl",
  "shift",
  "meta",
  "ret",
  "esc",
  "spc",
  "tab",
  "minus",
  "equal",
  "slash",
  "backslash",
  "semicolon",
  "apostrophe",
  "comma",
  "dot",
  "leftbracket",
  "rightbracket",
  "grave_accent",
  "up",
  "down",
  "left",
  "right",
  "home",
  "end",
  "insert",
  "delete",
  "backspace",
  "pgup",
  "pgdn",
  *(chr(code) for code in range(ord("a"), ord("z") + 1)),
  *(str(number) for number in range(10)),
  *(f"f{number}" for number in range(1, 13)),
}

app = App(
  name="qmp",
  result_action="return_value",
  exit_on_error=False,
  print_error=False,
)
mouse_app = App(name="mouse")
app.command(mouse_app)


@define(frozen=True)
class SerialResult:
  """Parsed serial output with an optional exit code."""

  output: str
  exit_code: int | None


class QmpError(RuntimeError):
  """Raised when a QMP command or response is invalid."""


class SerialTimeoutError(RuntimeError):
  """Raised when serial markers do not arrive before the timeout."""


def _require_json_object(
  *, value: object, context: str
) -> JsonObject:
  if not isinstance(value, dict):
    raise QmpError(f"{context} must be a JSON object")

  normalized: JsonObject = {}
  for key, item in value.items():
    if not isinstance(key, str):
      raise QmpError(f"{context} contains a non-string key")
    normalized[key] = item
  return normalized


def _require_json_object_list(
  *, value: object, context: str
) -> list[JsonObject]:
  if not isinstance(value, list):
    raise QmpError(f"{context} must be a JSON array")
  return [
    _require_json_object(value=item, context=context)
    for item in value
  ]


def _load_json_object(
  *, payload_text: str, context: str
) -> JsonObject:
  return _require_json_object(
    value=json.loads(payload_text),
    context=context,
  )


class QmpClient:
  """Issue one QMP command per connection."""

  def __init__(self, socket_path: Path):
    self.socket_path = socket_path

  def execute(self, payload: JsonObject) -> JsonObject:
    """Send a payload and return the first QMP response frame."""
    client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    client.connect(str(self.socket_path))
    try:
      file_obj = client.makefile("rwb", buffering=0)
      self._handshake(file_obj)
      self._write_payload(file_obj, payload)
      return self._read_response(file_obj)
    finally:
      client.close()

  def _handshake(self, file_obj: BinaryIO) -> None:
    greeting = file_obj.readline()
    if not greeting:
      raise QmpError("No QMP greeting received")
    _ = json.loads(greeting.decode())
    self._write_payload(file_obj, {"execute": "qmp_capabilities"})
    response = self._read_response(file_obj)
    if "error" in response:
      raise QmpError(f"qmp_capabilities failed: {response}")

  @staticmethod
  def _write_payload(file_obj: BinaryIO, payload: JsonObject) -> None:
    file_obj.write((json.dumps(payload) + "\r\n").encode())

  @staticmethod
  def _read_response(file_obj: BinaryIO) -> JsonObject:
    while True:
      line = file_obj.readline()
      if not line:
        raise QmpError(
          "QMP socket closed before a response was received"
        )
      payload = _load_json_object(
        payload_text=line.decode(),
        context="QMP response",
      )
      if "return" in payload or "error" in payload:
        return payload


@define(frozen=True)
class QmpSession:
  """Shared command context derived from the CLI socket path."""

  socket_path: Path
  client: QmpClient


InjectedSession = Annotated[
  QmpSession, Parameter(parse=False, show=False)
]


def derive_serial_log_path(socket_path: Path) -> Path:
  """Derive the default serial log path from a QMP socket path."""
  if socket_path.suffix == ".qmp":
    return socket_path.with_suffix(".serial.log")
  return socket_path.with_name(f"{socket_path.name}.serial.log")


def normalize_qcode(token: str) -> str:
  """Normalize one human key token into a QMP qcode."""
  lowered = token.strip().lower()
  lowered = QCODE_ALIASES.get(lowered, lowered)
  if lowered not in ALLOWED_QCODES:
    raise ValueError(f"Unsupported key token in chord: {token!r}")
  return lowered


def chord_to_keys(chord: str) -> list[QmpKey]:
  """Convert a chord like ctrl-alt-f9 into send-key qcodes."""
  tokens = [token for token in chord.split("-") if token]
  if not tokens:
    raise ValueError("Key chord cannot be empty")
  return [
    {"type": "qcode", "data": normalize_qcode(token)}
    for token in tokens
  ]


def char_to_keys(char: str) -> list[QmpKey]:
  """Map one character into the qcodes needed to type it."""
  if char in BASE_KEY_CODES:
    return [{"type": "qcode", "data": BASE_KEY_CODES[char]}]
  if char in SHIFT_KEY_CODES:
    return [
      {"type": "qcode", "data": "shift"},
      {"type": "qcode", "data": SHIFT_KEY_CODES[char]},
    ]
  raise ValueError(
    f"Unsupported character for send-key mapping: {char!r}"
  )


def text_to_event_keys(text: str) -> list[list[QmpKey]]:
  """Convert text into per-character QMP send-key events."""
  return [char_to_keys(char) for char in text]


def build_send_key_payload(
  *, keys: list[QmpKey], hold_ms: int | None = None
) -> JsonObject:
  """Build a QMP send-key payload."""
  arguments: JsonObject = {"keys": keys}
  if hold_ms is not None:
    arguments["hold-time"] = hold_ms
  return {"execute": "send-key", "arguments": arguments}


def marker_line(
  *, tag: str, kind: str, value: str | None = None
) -> str:
  """Build one serial marker line for begin, status, or end markers."""
  line = f"{SERIAL_MARKER_PREFIX}:{tag}:{kind}"
  if value is not None:
    line = f"{line}:{value}"
  return line


def build_serial_wrapper(*, command: str, tag: str) -> str:
  """Build the shell wrapper that emits serial markers around a command."""
  quoted_command = shlex.quote(command)
  return "\n".join(
    [
      "#!/bin/sh",
      f"begin={shlex.quote(marker_line(tag=tag, kind='begin'))}",
      f"status_prefix={shlex.quote(marker_line(tag=tag, kind='status'))}",
      f"end={shlex.quote(marker_line(tag=tag, kind='end'))}",
      "{",
      "  printf '%s\\n' \"$begin\"",
      f"  /bin/sh -lc {quoted_command}",
      "  status=$?",
      '  printf \'%s:%s\\n\' "$status_prefix" "$status"',
      "  printf '%s\\n' \"$end\"",
      '  exit "$status"',
      "} >/dev/ttyS0 2>&1",
      "",
    ]
  )


def build_serial_bootstrap_command(
  *, command: str, tag: str
) -> tuple[str, str]:
  """Encode the serial wrapper so it can be typed into the guest shell."""
  script_text = build_serial_wrapper(command=command, tag=tag)
  encoded_script = base64.b64encode(script_text.encode()).decode()
  typed_command = (
    f"/run/current-system/sw/bin/printf '%s' '{encoded_script}'"
    " | /run/current-system/sw/bin/base64 -d | /bin/sh\n"
  )
  return typed_command, script_text


def strip_ansi(text: str) -> str:
  """Strip ANSI escape sequences from serial output."""
  return ANSI_ESCAPE_RE.sub("", text)


def extract_serial_result(
  *, text: str, tag: str
) -> SerialResult | None:
  """Extract the most recent serial marker block for the given tag."""
  begin = marker_line(tag=tag, kind="begin")
  end = marker_line(tag=tag, kind="end")
  start = text.rfind(begin)
  if start == -1:
    return None
  end_index = text.find(end, start)
  if end_index == -1:
    return None
  segment = text[start + len(begin) : end_index]
  status_prefix = f"{marker_line(tag=tag, kind='status')}:"
  status_index = segment.rfind(status_prefix)
  if status_index == -1:
    return SerialResult(
      output="\n".join(line for line in segment.splitlines() if line),
      exit_code=None,
    )

  before_status = segment[:status_index]
  after_status = segment[status_index + len(status_prefix) :]
  code_text, _, after_status_line = after_status.partition("\n")
  code_text = code_text.strip()
  if not code_text:
    raise QmpError(
      f"Missing exit status in serial marker for tag {tag}"
    )

  output_segment = before_status + after_status_line
  output_lines = [
    line for line in output_segment.splitlines() if line
  ]
  return SerialResult(
    output="\n".join(output_lines),
    exit_code=int(code_text),
  )


def read_serial_text(*, serial_log: Path, offset: int) -> str:
  """Read serial log text starting at the requested byte offset."""
  try:
    with serial_log.open("rb") as handle:
      handle.seek(offset)
      return handle.read().decode("utf-8", errors="ignore")
  except FileNotFoundError:
    return ""


def wait_for_serial_result(
  *, serial_log: Path, offset: int, tag: str, timeout: float
) -> SerialResult:
  """Wait for a tagged serial result block to appear in the log."""
  deadline = time.monotonic() + timeout
  saw_file = serial_log.exists()
  while time.monotonic() < deadline:
    saw_file = saw_file or serial_log.exists()
    result = extract_serial_result(
      text=read_serial_text(serial_log=serial_log, offset=offset),
      tag=tag,
    )
    if result is not None:
      return result
    time.sleep(0.1)
  if not saw_file:
    raise SerialTimeoutError(
      f"Serial log never appeared: {serial_log}"
    )
  raise SerialTimeoutError(
    f"Timed out waiting for serial markers in {serial_log}"
  )


def extract_pull_bytes(*, payload_text: str) -> bytes:
  """Decode base64 file contents captured over serial."""
  return base64.b64decode(
    "".join(payload_text.split()), validate=True
  )


def current_serial_offset(serial_log: Path) -> int:
  """Return the current byte size of the serial log."""
  try:
    return serial_log.stat().st_size
  except FileNotFoundError:
    return 0


def require_ok(*, response: JsonObject, action: str) -> JsonObject:
  """Raise when a QMP response reports an error."""
  if "error" in response:
    raise QmpError(f"QMP {action} failed: {json.dumps(response)}")
  return response


def query_mice(client: QmpClient) -> list[JsonObject]:
  """Return the parsed query-mice response payload."""
  response = require_ok(
    response=client.execute({"execute": "query-mice"}),
    action="query-mice",
  )
  mice = response.get("return")
  return _require_json_object_list(
    value=mice, context="query-mice return"
  )


def ensure_current_absolute_mouse(
  *, mice: list[JsonObject]
) -> JsonObject:
  """Return the active absolute mouse device or raise."""
  for mouse in mice:
    if mouse.get("current") and mouse.get("absolute"):
      return mouse
  raise QmpError(
    "No current absolute mouse reported by query-mice; cannot use move-abs"
  )


def validate_abs_coordinate(*, value: int, axis: str) -> None:
  """Validate one absolute pointer coordinate."""
  if not 0 <= value <= QMP_ABS_MAX:
    raise ValueError(
      f"Absolute {axis} coordinate must be in 0..{QMP_ABS_MAX}"
    )


def mouse_move_abs_payload(*, x: int, y: int) -> JsonObject:
  """Build a QMP payload for absolute mouse movement."""
  validate_abs_coordinate(value=x, axis="x")
  validate_abs_coordinate(value=y, axis="y")
  return {
    "execute": "input-send-event",
    "arguments": {
      "events": [
        {"type": "abs", "data": {"axis": "x", "value": x}},
        {"type": "abs", "data": {"axis": "y", "value": y}},
      ]
    },
  }


def mouse_move_rel_payload(*, dx: int, dy: int) -> JsonObject:
  """Build a QMP payload for relative mouse movement."""
  return {
    "execute": "input-send-event",
    "arguments": {
      "events": [
        {"type": "rel", "data": {"axis": "x", "value": dx}},
        {"type": "rel", "data": {"axis": "y", "value": dy}},
      ]
    },
  }


def normalize_button(button: str) -> str:
  """Normalize and validate a mouse button name."""
  lowered = button.lower()
  if lowered not in {"left", "middle", "right"}:
    raise ValueError(f"Unsupported mouse button: {button!r}")
  return lowered


def mouse_button_payload(*, button: str, down: bool) -> JsonObject:
  """Build a QMP payload for mouse button state changes."""
  return {
    "execute": "input-send-event",
    "arguments": {
      "events": [
        {
          "type": "btn",
          "data": {"button": normalize_button(button), "down": down},
        }
      ]
    },
  }


def mouse_wheel_payload(*, direction: str) -> JsonObject:
  """Build a QMP payload for one wheel tick."""
  if direction not in {"up", "down"}:
    raise ValueError(f"Unsupported wheel direction: {direction!r}")
  button = "wheel-up" if direction == "up" else "wheel-down"
  return {
    "execute": "input-send-event",
    "arguments": {
      "events": [
        {"type": "btn", "data": {"button": button, "down": True}},
        {"type": "btn", "data": {"button": button, "down": False}},
      ]
    },
  }


def build_screendump_payload(
  *,
  output: Path,
  image_format: str | None,
  device: str | None,
  head: int | None,
) -> JsonObject:
  """Build a screendump payload."""
  arguments: JsonObject = {"filename": str(output)}
  if image_format is not None:
    arguments["format"] = image_format
  if device is not None:
    arguments["device"] = device
  if head is not None:
    arguments["head"] = head
  return {"execute": "screendump", "arguments": arguments}


def run_type_command(
  *, client: QmpClient, text: str, delay: float
) -> None:
  """Type text into the guest with per-character send-key events."""
  for keys in text_to_event_keys(text):
    require_ok(
      response=client.execute(build_send_key_payload(keys=keys)),
      action="send-key",
    )
    if delay:
      time.sleep(delay)


def run_serial_command(
  *,
  client: QmpClient,
  guest_command: str,
  serial_log: Path,
  timeout: float,
  delay: float,
  keep_ansi: bool,
) -> int:
  """Run a guest shell command and stream its serial output."""
  tag = secrets.token_hex(8)
  offset = current_serial_offset(serial_log)
  typed_command, _ = build_serial_bootstrap_command(
    command=guest_command,
    tag=tag,
  )
  run_type_command(client=client, text=typed_command, delay=delay)
  result = wait_for_serial_result(
    serial_log=serial_log,
    offset=offset,
    tag=tag,
    timeout=timeout,
  )
  output = result.output if keep_ansi else strip_ansi(result.output)
  if output:
    sys.stdout.write(output)
    if not output.endswith("\n"):
      sys.stdout.write("\n")
  if result.exit_code is None:
    raise QmpError(
      f"Missing serial exit status marker in {serial_log}"
    )
  return result.exit_code


def serial_log_from_args(
  *, socket_path: Path, override: str | None
) -> Path:
  """Resolve the serial log path from CLI options."""
  return (
    Path(override)
    if override is not None
    else derive_serial_log_path(socket_path)
  )


def _session_from_socket_path(*, socket_path: Path) -> QmpSession:
  return QmpSession(
    socket_path=socket_path, client=QmpClient(socket_path)
  )


@app.command(name="key")
def _key_command(
  chord: str,
  *,
  hold_ms: int | None = None,
  _session: InjectedSession,
) -> int:
  """Send a key chord with QMP send-key."""
  response = require_ok(
    response=_session.client.execute(
      build_send_key_payload(
        keys=chord_to_keys(chord), hold_ms=hold_ms
      )
    ),
    action="send-key",
  )
  print(json.dumps(response))
  return 0


@app.command(name="type")
def _type_command(
  text: str,
  *,
  delay: float = 0.02,
  _session: InjectedSession,
) -> int:
  """Type text with QMP send-key."""
  run_type_command(client=_session.client, text=text, delay=delay)
  return 0


@mouse_app.command(name="info")
def _mouse_info(*, _session: InjectedSession) -> int:
  """Show query-mice output."""
  print(
    json.dumps(query_mice(_session.client), indent=2, sort_keys=True)
  )
  return 0


@mouse_app.command(name="move-abs")
def _mouse_move_abs(
  x: int,
  y: int,
  *,
  _session: InjectedSession,
) -> int:
  """Move absolute pointer coordinates."""
  ensure_current_absolute_mouse(mice=query_mice(_session.client))
  response = require_ok(
    response=_session.client.execute(
      mouse_move_abs_payload(x=x, y=y)
    ),
    action="input-send-event",
  )
  print(json.dumps(response))
  return 0


@mouse_app.command(name="move-rel")
def _mouse_move_rel(
  dx: int,
  dy: int,
  *,
  _session: InjectedSession,
) -> int:
  """Move relative pointer coordinates."""
  response = require_ok(
    response=_session.client.execute(
      mouse_move_rel_payload(dx=dx, dy=dy)
    ),
    action="input-send-event",
  )
  print(json.dumps(response))
  return 0


@mouse_app.command(name="down")
def _mouse_down(button: str, *, _session: InjectedSession) -> int:
  """Press a mouse button."""
  response = require_ok(
    response=_session.client.execute(
      mouse_button_payload(button=button, down=True)
    ),
    action="input-send-event",
  )
  print(json.dumps(response))
  return 0


@mouse_app.command(name="up")
def _mouse_up(button: str, *, _session: InjectedSession) -> int:
  """Release a mouse button."""
  response = require_ok(
    response=_session.client.execute(
      mouse_button_payload(button=button, down=False)
    ),
    action="input-send-event",
  )
  print(json.dumps(response))
  return 0


@mouse_app.command(name="click")
def _mouse_click(button: str, *, _session: InjectedSession) -> int:
  """Click a mouse button."""
  require_ok(
    response=_session.client.execute(
      mouse_button_payload(button=button, down=True)
    ),
    action="input-send-event",
  )
  response = require_ok(
    response=_session.client.execute(
      mouse_button_payload(button=button, down=False)
    ),
    action="input-send-event",
  )
  print(json.dumps(response))
  return 0


@mouse_app.command(name="wheel")
def _mouse_wheel(
  direction: str,
  *,
  steps: int = 1,
  _session: InjectedSession,
) -> int:
  """Send wheel events."""
  if steps < 1:
    raise ValueError("--steps must be at least 1")
  response: JsonObject | None = None
  for _ in range(steps):
    response = require_ok(
      response=_session.client.execute(
        mouse_wheel_payload(direction=direction)
      ),
      action="input-send-event",
    )
  print(json.dumps(response or {"return": {}}))
  return 0


@app.command(name="screendump")
def _screendump_command(
  output: Path,
  *,
  image_format: str | None = None,
  device: str | None = None,
  head: int | None = None,
  _session: InjectedSession,
) -> int:
  """Capture a screendump."""
  response = require_ok(
    response=_session.client.execute(
      build_screendump_payload(
        output=output,
        image_format=image_format,
        device=device,
        head=head,
      )
    ),
    action="screendump",
  )
  print(json.dumps(response))
  return 0


@app.command(name="serial")
def _serial_command(
  guest_command: str,
  *,
  serial_log: str | None = None,
  timeout: float = 60.0,
  delay: float = 0.02,
  keep_ansi: bool = False,
  _session: InjectedSession,
) -> int:
  """Run a guest shell command and capture ttyS0 output."""
  return run_serial_command(
    client=_session.client,
    guest_command=guest_command,
    serial_log=serial_log_from_args(
      socket_path=_session.socket_path,
      override=serial_log,
    ),
    timeout=timeout,
    delay=delay,
    keep_ansi=keep_ansi,
  )


@app.command(name="pull")
def _pull_command(
  guest_path: str,
  output_path: Path,
  *,
  serial_log: str | None = None,
  timeout: float = 60.0,
  delay: float = 0.02,
  _session: InjectedSession,
) -> int:
  """Copy a readable guest file over serial/base64."""
  resolved_serial_log = serial_log_from_args(
    socket_path=_session.socket_path,
    override=serial_log,
  )
  tag = secrets.token_hex(8)
  offset = current_serial_offset(resolved_serial_log)
  guest_command = (
    "if [ -r "
    + shlex.quote(guest_path)
    + " ]; then /run/current-system/sw/bin/base64 -w0 -- "
    + shlex.quote(guest_path)
    + "; else printf 'File not readable: %s\\n' "
    + shlex.quote(guest_path)
    + "; exit 1; fi"
  )
  typed_command, _ = build_serial_bootstrap_command(
    command=guest_command,
    tag=tag,
  )
  run_type_command(
    client=_session.client,
    text=typed_command,
    delay=delay,
  )
  result = wait_for_serial_result(
    serial_log=resolved_serial_log,
    offset=offset,
    tag=tag,
    timeout=timeout,
  )
  if result.exit_code is None:
    raise QmpError(
      f"Missing serial exit status marker in {resolved_serial_log}"
    )
  if result.exit_code != 0:
    output = strip_ansi(result.output)
    if output:
      sys.stdout.write(output)
      if not output.endswith("\n"):
        sys.stdout.write("\n")
    return result.exit_code

  output_path.parent.mkdir(parents=True, exist_ok=True)
  output_path.write_bytes(
    extract_pull_bytes(payload_text=result.output)
  )
  print(output_path)
  return 0


@app.command(name="hmp")
def _hmp_command(
  hmp_command: str, *, _session: InjectedSession
) -> int:
  """Escape hatch for human-monitor-command."""
  response = require_ok(
    response=_session.client.execute(
      {
        "execute": "human-monitor-command",
        "arguments": {"command-line": hmp_command},
      }
    ),
    action="human-monitor-command",
  )
  print(json.dumps(response))
  return 0


@app.command(name="raw")
def _raw_command(
  json_payload: str, *, _session: InjectedSession
) -> int:
  """Escape hatch for raw QMP JSON."""
  payload = _load_json_object(
    payload_text=json_payload,
    context="raw payload",
  )
  response = _session.client.execute(payload)
  print(json.dumps(response))
  return 0 if "error" not in response else 1


@app.meta.default
def _run_cli(
  socket_path: Path,
  *tokens: Annotated[
    str, Parameter(show=False, allow_leading_hyphen=True)
  ],
) -> int:
  """Launch the QMP CLI with a shared socket path."""
  session = _session_from_socket_path(socket_path=socket_path)
  command, bound, ignored = app.parse_args(tokens)
  extra_kwargs: JsonObject = {}
  if "_session" in ignored:
    extra_kwargs["_session"] = session
  return command(*bound.args, **bound.kwargs, **extra_kwargs)


if __name__ == "__main__":
  try:
    raise SystemExit(app.meta())
  except CycloptsError as error:
    print(error)
    raise SystemExit(1)
