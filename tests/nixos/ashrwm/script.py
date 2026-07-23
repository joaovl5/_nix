"""Integration test: Ashrwm on River with two headless outputs."""

import json
from typing import TypedDict

from common import Machine, q, require_machine, succeed

_RUNTIME_DIR = "/run/ashrwm-test"
_BORDER_WIDTH = 4


class OutputState(TypedDict):
  """Logical output geometry used by the clipping assertions."""

  name: str
  x: int
  y: int
  width: int
  height: int


class WindowState(TypedDict):
  """Observable Ashrwm geometry and render state for one window."""

  app_id: str
  x: int
  y: int
  width: int
  height: int
  tag: int
  hidden: bool
  clip_box: list[int] | None


def _wait(machine: Machine, command: str, message: str) -> None:
  """Wait briefly for compositor state and retain a focused failure message."""
  try:
    machine.wait_until_succeeds(command, timeout=60)
  except Exception as exc:
    failure = f"{message}: {command}"
    raise AssertionError(failure) from exc


def _client_prefix(*, display: str, socket: str) -> str:
  """Return a command prefix for the compositor test user."""
  environment = " ".join(
    [
      f"XDG_RUNTIME_DIR={q(_RUNTIME_DIR)}",
      f"WAYLAND_DISPLAY={q(display)}",
      f"ASHRWM_SOCKET={q(socket)}",
      "HOME=/home/tester",
    ]
  )
  return f"runuser -u tester -- env {environment}"


def _wayland(
  *, machine: Machine, display: str, socket: str, command: str
) -> str:
  """Run a Wayland client as the compositor test user."""
  return succeed(
    machine,
    f"{_client_prefix(display=display, socket=socket)} {command}",
    f"Wayland client command failed: {command}",
  )


def _ashrwm(
  *,
  machine: Machine,
  display: str,
  socket: str,
  expression: str,
  json_output: bool = False,
) -> str:
  """Evaluate one expression through Ashrwm's local diagnostic socket."""
  output_option = "--json" if json_output else "--raw"
  return _wayland(
    machine=machine,
    display=display,
    socket=socket,
    command=(
      f"/run/current-system/sw/bin/ashrwm-msg {output_option} "
      f"{q(expression.strip())}"
    ),
  )


def _parse_windows(*, raw: str) -> list[WindowState]:
  """Parse and validate JSON window state emitted by ``_windows``."""
  payload = json.loads(raw)
  assert isinstance(payload, list), (
    f"Expected window list, got {payload!r}"
  )

  windows: list[WindowState] = []
  for row in payload:
    assert isinstance(row, list), f"Invalid window state row: {row!r}"
    assert len(row) == 8, f"Invalid window state row: {row!r}"
    app_id, x, y, width, height, tag, hidden, clip_box = row
    assert isinstance(app_id, str), f"Missing app ID: {row!r}"
    for value in (x, y, width, height, tag):
      assert type(value) is int, f"Invalid window geometry: {row!r}"
    assert isinstance(hidden, bool), (
      f"Missing render visibility: {row!r}"
    )
    if clip_box is not None:
      assert isinstance(clip_box, list)
      assert len(clip_box) == 4
      assert all(type(value) is int for value in clip_box)
    windows.append(
      WindowState(
        app_id=app_id,
        x=x,
        y=y,
        width=width,
        height=height,
        tag=tag,
        hidden=hidden,
        clip_box=clip_box,
      )
    )
  return windows


def _parse_outputs(*, raw: str) -> list[OutputState]:
  """Parse and validate the subset of wlr-randr JSON used by the test."""
  payload = json.loads(raw)
  assert isinstance(payload, list), (
    f"Expected output list, got {payload!r}"
  )
  outputs: list[OutputState] = []
  for item in payload:
    assert isinstance(item, dict), (
      f"Expected output object, got {item!r}"
    )
    position = item.get("position")
    modes = item.get("modes")
    assert isinstance(position, dict), (
      f"Missing output position: {item!r}"
    )
    assert isinstance(modes, list), f"Missing output modes: {item!r}"
    mode = next(
      (
        candidate
        for candidate in modes
        if isinstance(candidate, dict)
        and candidate.get("current") is True
      ),
      None,
    )
    assert isinstance(mode, dict), (
      f"Missing current output mode: {item!r}"
    )
    name = item.get("name")
    x = position.get("x")
    y = position.get("y")
    width = mode.get("width")
    height = mode.get("height")
    assert isinstance(name, str), f"Invalid output name: {item!r}"
    for key, value in {
      "x": x,
      "y": y,
      "width": width,
      "height": height,
    }.items():
      assert type(value) is int, f"Invalid {key}: {item!r}"
    outputs.append(
      OutputState(name=name, x=x, y=y, width=width, height=height)
    )
  return outputs


def _windows(
  *, machine: Machine, display: str, socket: str
) -> list[WindowState]:
  """Read current Ashrwm window geometry and requested render state."""
  expression = """
    (map (fn [window]
           [(window :app-id)
            (window :x)
            (window :y)
            (window :w)
            (window :h)
            (window :tag)
            (window :render-hidden)
            (window :render-clip-box)])
         (wm :windows))
  """
  return _parse_windows(
    raw=_ashrwm(
      machine=machine,
      display=display,
      socket=socket,
      expression=expression,
      json_output=True,
    )
  )


def _start_foot(
  *, machine: Machine, display: str, index: int
) -> None:
  """Start one solid-red terminal in a transient service."""
  unit = f"ashrwm-foot-{index}"
  command = " ".join(
    [
      "systemd-run",
      "--quiet",
      f"--unit={unit}",
      "--property=User=tester",
      f"--setenv=XDG_RUNTIME_DIR={_RUNTIME_DIR}",
      f"--setenv=WAYLAND_DISPLAY={display}",
      "--setenv=HOME=/home/tester",
      "/run/current-system/sw/bin/foot",
      "-o colors.background=ff0000",
      "-o colors.foreground=ffffff",
      "-f 'DejaVu Sans Mono:size=12'",
      f"-a spill-{index}",
      f"-T spill-{index}",
      "/run/current-system/sw/bin/sleep infinity",
    ]
  )
  succeed(machine, command, f"Could not start {unit}")
  _wait(
    machine,
    f"systemctl is-active --quiet {unit}.service",
    f"{unit} did not remain active",
  )


def _red_fraction(*, machine: Machine, path: str) -> float:
  """Return the fraction of strongly red pixels in a guest screenshot."""
  output = succeed(
    machine,
    " ".join(
      [
        f"magick {q(path)}",
        "-alpha off",
        "-fx '((r>0.75)&&(g<0.25)&&(b<0.25))?1:0'",
        "-format '%[fx:mean]' info:",
      ]
    ),
    f"Could not inspect screenshot {path}",
  )
  return float(output)


def run(*, driver_globals: dict[str, object]) -> None:  # noqa: PLR0915
  """Exercise one linear Ashrwm startup, layout, and clipping scenario."""
  start_all = driver_globals.get("start_all")
  if callable(start_all):
    start_all()

  machine = require_machine(driver_globals, "machine")
  machine.wait_for_unit("multi-user.target")
  machine.wait_for_unit("ashrwm-test.service")

  _wait(
    machine,
    (
      f"for socket in {_RUNTIME_DIR}/wayland-*; do "
      'test -S "$socket" && exit 0; done; exit 1'
    ),
    "River did not create a Wayland socket",
  )
  display = succeed(
    machine,
    (
      f"for socket in {_RUNTIME_DIR}/wayland-*; do "
      'if test -S "$socket"; then basename "$socket"; break; fi; done'
    ),
    "Could not identify River's Wayland display",
  )
  socket = f"{_RUNTIME_DIR}/ashrwm-{display}"
  _wait(
    machine,
    f"test -S {q(socket)}",
    "Ashrwm did not create its diagnostic socket",
  )
  assert (
    _ashrwm(
      machine=machine,
      display=display,
      socket=socket,
      expression="(= (length (wm :outputs)) 2)",
    )
    == "true"
  ), "Ashrwm did not register both headless outputs"

  initial_outputs = _parse_outputs(
    raw=_wayland(
      machine=machine,
      display=display,
      socket=socket,
      command="wlr-randr --json",
    )
  )
  names = sorted(output["name"] for output in initial_outputs)
  assert len(names) == 2, (
    f"Expected two outputs, got {initial_outputs!r}"
  )
  primary_name, secondary_name = names

  _wayland(
    machine=machine,
    display=display,
    socket=socket,
    command=(
      f"wlr-randr --output {q(primary_name)} "
      "--custom-mode 900x700@60Hz --pos 0,0 "
      f"--output {q(secondary_name)} "
      "--custom-mode 700x500@60Hz --pos 900,100"
    ),
  )
  configured_outputs = _parse_outputs(
    raw=_wayland(
      machine=machine,
      display=display,
      socket=socket,
      command="wlr-randr --json",
    )
  )
  outputs_by_name = {
    output["name"]: output for output in configured_outputs
  }
  primary = outputs_by_name[primary_name]
  secondary = outputs_by_name[secondary_name]
  assert primary == OutputState(
    name=primary_name, x=0, y=0, width=900, height=700
  ), f"Unexpected primary geometry: {primary!r}"
  assert secondary == OutputState(
    name=secondary_name, x=900, y=100, width=700, height=500
  ), f"Unexpected secondary geometry: {secondary!r}"

  focused_primary = _ashrwm(
    machine=machine,
    display=display,
    socket=socket,
    expression="""
      (let [seat (first (wm :seats))
            output (find |(= 0 ($ :x)) (wm :outputs))]
        (if (and seat output)
          (do (seat/focus-output seat output) true)
          false))
    """,
  )
  assert focused_primary == "true", (
    "Could not focus the primary output"
  )

  for index in range(1, 4):
    _start_foot(machine=machine, display=display, index=index)
    expected_count = index
    expression = f"(= (length (wm :windows)) {expected_count})"
    prefix = _client_prefix(display=display, socket=socket)
    _wait(
      machine,
      (
        f'test "$({prefix} /run/current-system/sw/bin/ashrwm-msg '
        f'--raw {q(expression)})" = true'
      ),
      f"Ashrwm did not finish rendering {expected_count} windows",
    )

  windows = _windows(machine=machine, display=display, socket=socket)
  assert len(windows) == 3
  tags = {window["tag"] for window in windows}
  assert len(tags) == 1, windows
  tag = tags.pop()

  def overlaps_output(
    window: WindowState, output: OutputState
  ) -> bool:
    outer_left = window["x"] - _BORDER_WIDTH
    outer_top = window["y"] - _BORDER_WIDTH
    outer_right = window["x"] + window["width"] + _BORDER_WIDTH
    outer_bottom = window["y"] + window["height"] + _BORDER_WIDTH
    return (
      outer_right > output["x"]
      and outer_left < output["x"] + output["width"]
      and outer_bottom > output["y"]
      and outer_top < output["y"] + output["height"]
    )

  partial = [
    window
    for window in windows
    if overlaps_output(window, primary)
    and window["x"] + window["width"] + _BORDER_WIDTH
    > primary["x"] + primary["width"]
  ]
  outside = [
    window
    for window in windows
    if not overlaps_output(window, primary)
  ]
  assert partial, (
    f"Test did not produce a partially overflowing window: {windows!r}"
  )
  assert outside, (
    f"Test did not produce a fully overflowing window: {windows!r}"
  )
  assert any(
    overlaps_output(window, secondary) for window in partial
  ), (
    f"Overflow geometry did not reach the secondary output: {windows!r}"
  )

  for window in partial:
    expected_clip = [
      primary["x"] - window["x"],
      primary["y"] - window["y"],
      primary["width"],
      primary["height"],
    ]
    assert not window["hidden"], window
    assert window["clip_box"] == expected_clip, (
      f"Wrong partial clip request: {window!r}"
    )
  for window in outside:
    assert window["hidden"], (
      f"Outside window remained visible: {window!r}"
    )
    assert window["clip_box"] is None, window

  _wayland(
    machine=machine,
    display=display,
    socket=socket,
    command=f"grim -o {q(primary_name)} {_RUNTIME_DIR}/primary.png",
  )
  _wayland(
    machine=machine,
    display=display,
    socket=socket,
    command=f"grim -o {q(secondary_name)} {_RUNTIME_DIR}/secondary.png",
  )
  primary_red = _red_fraction(
    machine=machine, path=f"{_RUNTIME_DIR}/primary.png"
  )
  secondary_red = _red_fraction(
    machine=machine, path=f"{_RUNTIME_DIR}/secondary.png"
  )
  assert primary_red > 0.25, (
    f"Primary screenshot did not prove red clients rendered: {primary_red}"
  )
  assert secondary_red < 0.001, (
    f"Scroller clients leaked onto the secondary output: {secondary_red}"
  )

  tile_result = _ashrwm(
    machine=machine,
    display=display,
    socket=socket,
    expression=f"""
      (let [output (find |(($ :tags) {tag}) (wm :outputs))]
        ((action/layout :tile) @{{:focused-output output}} nil)
        ((config :layouts) {tag}))
    """,
  )
  assert tile_result == ":tile", (
    f"Could not select tile layout: {tile_result!r}"
  )
  _wayland(
    machine=machine,
    display=display,
    socket=socket,
    command=f"wlr-randr --output {q(primary_name)} --pos 1,0",
  )
  _wayland(
    machine=machine,
    display=display,
    socket=socket,
    command=f"wlr-randr --output {q(primary_name)} --pos 0,0",
  )
  prefix = _client_prefix(display=display, socket=socket)
  _wait(
    machine,
    (
      f'test "$({prefix} /run/current-system/sw/bin/ashrwm-msg --raw '
      f'{q("(not (find |($ :render-clip-box) (wm :windows)))")})" = true'
    ),
    "Tile transition did not clear scroller clip state",
  )
  tiled_windows = _windows(
    machine=machine, display=display, socket=socket
  )
  assert all(window["clip_box"] is None for window in tiled_windows)
  assert all(not window["hidden"] for window in tiled_windows)

  invalid_result = _ashrwm(
    machine=machine,
    display=display,
    socket=socket,
    expression="""
      (let [[ok err] (protect (action/layout :scroll))]
        (and (not ok)
             (not (not (string/find "invalid layout" err)))))
    """,
  )
  assert invalid_result == "true", (
    f"Invalid layout did not report a useful error: {invalid_result!r}"
  )
  retained_layout = _ashrwm(
    machine=machine,
    display=display,
    socket=socket,
    expression=f"((config :layouts) {tag})",
  )
  assert retained_layout == ":tile", (
    f"Invalid layout replaced the working layout: {retained_layout!r}"
  )
  config_path = "/etc/ashrwm/config.janet"
  config_backup = f"{_RUNTIME_DIR}/valid-config.janet"
  invalid_config = (
    "(put config :layout :scroll)\n"
    "(put (config :layouts) 99 :scroll)\n"
  )
  succeed(
    machine,
    (
      f"mv {q(config_path)} {q(config_backup)} && "
      f"printf %s {q(invalid_config)} > {q(config_path)}"
    ),
    "Could not install the invalid config fixture",
  )
  reload_result = _ashrwm(
    machine=machine,
    display=display,
    socket=socket,
    expression=f"""
      (do
        (put config :layout :tile)
        ((action/config nil "{config_path}"))
        (and (= (config :layout) :tile)
             (= ((config :layouts) {tag}) :tile)
             (nil? ((config :layouts) 99))))
    """,
  )
  succeed(
    machine,
    f"rm -f {q(config_path)} && mv {q(config_backup)} {q(config_path)}",
    "Could not restore the valid config fixture",
  )
  assert reload_result.splitlines()[-1] == "true", (
    f"Invalid config replaced valid layout state: {reload_result!r}"
  )

  assert (
    _ashrwm(
      machine=machine,
      display=display,
      socket=socket,
      expression="(do (each layout valid-layouts (action/layout layout)) true)",
    )
    == "true"
  ), "A documented Ashrwm layout was rejected"
