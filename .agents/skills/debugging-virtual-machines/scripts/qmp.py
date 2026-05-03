#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
from __future__ import annotations

import argparse
import base64
import json
import re
import secrets
import shlex
import socket
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any, BinaryIO

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
    **{chr(code): chr(code + 32) for code in range(ord("A"), ord("Z") + 1)},
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


@dataclass(frozen=True)
class SerialResult:
    output: str
    exit_code: int | None


class QmpError(RuntimeError):
    pass


class SerialTimeoutError(RuntimeError):
    pass


class QmpClient:
    def __init__(self, socket_path: Path):
        self.socket_path = socket_path

    def execute(self, payload: dict[str, Any]) -> dict[str, Any]:
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
        json.loads(greeting.decode())
        self._write_payload(file_obj, {"execute": "qmp_capabilities"})
        response = self._read_response(file_obj)
        if "error" in response:
            raise QmpError(f"qmp_capabilities failed: {response}")

    @staticmethod
    def _write_payload(file_obj: BinaryIO, payload: dict[str, Any]) -> None:
        file_obj.write((json.dumps(payload) + "\r\n").encode())

    @staticmethod
    def _read_response(file_obj: BinaryIO) -> dict[str, Any]:
        while True:
            line = file_obj.readline()
            if not line:
                raise QmpError("QMP socket closed before a response was received")
            payload = json.loads(line.decode())
            if "return" in payload or "error" in payload:
                return payload


def derive_serial_log_path(socket_path: Path) -> Path:
    if socket_path.suffix == ".qmp":
        return socket_path.with_suffix(".serial.log")
    return socket_path.with_name(f"{socket_path.name}.serial.log")


def normalize_qcode(token: str) -> str:
    lowered = token.strip().lower()
    lowered = QCODE_ALIASES.get(lowered, lowered)
    if lowered not in ALLOWED_QCODES:
        raise ValueError(f"Unsupported key token in chord: {token!r}")
    return lowered


def chord_to_keys(chord: str) -> list[dict[str, str]]:
    tokens = [token for token in chord.split("-") if token]
    if not tokens:
        raise ValueError("Key chord cannot be empty")
    return [{"type": "qcode", "data": normalize_qcode(token)} for token in tokens]


def char_to_keys(char: str) -> list[dict[str, str]]:
    if char in BASE_KEY_CODES:
        return [{"type": "qcode", "data": BASE_KEY_CODES[char]}]
    if char in SHIFT_KEY_CODES:
        return [
            {"type": "qcode", "data": "shift"},
            {"type": "qcode", "data": SHIFT_KEY_CODES[char]},
        ]
    raise ValueError(f"Unsupported character for send-key mapping: {char!r}")


def text_to_event_keys(text: str) -> list[list[dict[str, str]]]:
    return [char_to_keys(char) for char in text]


def build_send_key_payload(
    keys: list[dict[str, str]], hold_ms: int | None = None
) -> dict[str, Any]:
    arguments: dict[str, Any] = {"keys": keys}
    if hold_ms is not None:
        arguments["hold-time"] = hold_ms
    return {"execute": "send-key", "arguments": arguments}


def marker_line(tag: str, kind: str, value: str | None = None) -> str:
    line = f"{SERIAL_MARKER_PREFIX}:{tag}:{kind}"
    if value is not None:
        line = f"{line}:{value}"
    return line


def build_serial_wrapper(command: str, tag: str) -> str:
    quoted_command = shlex.quote(command)
    return "\n".join(
        [
            "#!/bin/sh",
            f"begin={shlex.quote(marker_line(tag, 'begin'))}",
            f"status_prefix={shlex.quote(marker_line(tag, 'status'))}",
            f"end={shlex.quote(marker_line(tag, 'end'))}",
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


def build_serial_bootstrap_command(command: str, tag: str) -> tuple[str, str]:
    script_text = build_serial_wrapper(command, tag)
    encoded_script = base64.b64encode(script_text.encode()).decode()
    typed_command = (
        f"/run/current-system/sw/bin/printf '%s' '{encoded_script}'"
        " | /run/current-system/sw/bin/base64 -d | /bin/sh\n"
    )
    return typed_command, script_text


def strip_ansi(text: str) -> str:
    return ANSI_ESCAPE_RE.sub("", text)


def extract_serial_result(text: str, tag: str) -> SerialResult | None:
    begin = marker_line(tag, "begin")
    end = marker_line(tag, "end")
    start = text.rfind(begin)
    if start == -1:
        return None
    end_index = text.find(end, start)
    if end_index == -1:
        return None
    segment = text[start + len(begin) : end_index]
    status_prefix = f"{marker_line(tag, 'status')}:"
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
        raise QmpError(f"Missing exit status in serial marker for tag {tag}")

    output_segment = before_status + after_status_line
    output_lines = [line for line in output_segment.splitlines() if line]
    return SerialResult(output="\n".join(output_lines), exit_code=int(code_text))


def read_serial_text(serial_log: Path, offset: int) -> str:
    try:
        with serial_log.open("rb") as handle:
            handle.seek(offset)
            return handle.read().decode("utf-8", errors="ignore")
    except FileNotFoundError:
        return ""


def wait_for_serial_result(
    serial_log: Path, offset: int, tag: str, timeout: float
) -> SerialResult:
    deadline = time.monotonic() + timeout
    saw_file = serial_log.exists()
    while time.monotonic() < deadline:
        saw_file = saw_file or serial_log.exists()
        result = extract_serial_result(read_serial_text(serial_log, offset), tag)
        if result is not None:
            return result
        time.sleep(0.1)
    if not saw_file:
        raise SerialTimeoutError(f"Serial log never appeared: {serial_log}")
    raise SerialTimeoutError(f"Timed out waiting for serial markers in {serial_log}")


def extract_pull_bytes(payload_text: str) -> bytes:
    return base64.b64decode("".join(payload_text.split()), validate=True)


def current_serial_offset(serial_log: Path) -> int:
    try:
        return serial_log.stat().st_size
    except FileNotFoundError:
        return 0


def require_ok(response: dict[str, Any], action: str) -> dict[str, Any]:
    if "error" in response:
        raise QmpError(f"QMP {action} failed: {json.dumps(response)}")
    return response


def query_mice(client: QmpClient) -> list[dict[str, Any]]:
    response = require_ok(client.execute({"execute": "query-mice"}), "query-mice")
    mice = response.get("return")
    if not isinstance(mice, list):
        raise QmpError(f"Unexpected query-mice response: {response}")
    return mice


def ensure_current_absolute_mouse(mice: list[dict[str, Any]]) -> dict[str, Any]:
    for mouse in mice:
        if mouse.get("current") and mouse.get("absolute"):
            return mouse
    raise QmpError(
        "No current absolute mouse reported by query-mice; cannot use move-abs"
    )


def validate_abs_coordinate(value: int, axis: str) -> None:
    if not 0 <= value <= QMP_ABS_MAX:
        raise ValueError(f"Absolute {axis} coordinate must be in 0..{QMP_ABS_MAX}")


def mouse_move_abs_payload(x: int, y: int) -> dict[str, Any]:
    validate_abs_coordinate(x, "x")
    validate_abs_coordinate(y, "y")
    return {
        "execute": "input-send-event",
        "arguments": {
            "events": [
                {"type": "abs", "data": {"axis": "x", "value": x}},
                {"type": "abs", "data": {"axis": "y", "value": y}},
            ]
        },
    }


def mouse_move_rel_payload(dx: int, dy: int) -> dict[str, Any]:
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
    lowered = button.lower()
    if lowered not in {"left", "middle", "right"}:
        raise ValueError(f"Unsupported mouse button: {button!r}")
    return lowered


def mouse_button_payload(button: str, down: bool) -> dict[str, Any]:
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


def mouse_wheel_payload(direction: str) -> dict[str, Any]:
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
    output: Path, image_format: str | None, device: str | None, head: int | None
) -> dict[str, Any]:
    arguments: dict[str, Any] = {"filename": str(output)}
    if image_format is not None:
        arguments["format"] = image_format
    if device is not None:
        arguments["device"] = device
    if head is not None:
        arguments["head"] = head
    return {"execute": "screendump", "arguments": arguments}


def run_type_command(client: QmpClient, text: str, delay: float) -> None:
    for keys in text_to_event_keys(text):
        require_ok(client.execute(build_send_key_payload(keys)), "send-key")
        if delay:
            time.sleep(delay)


def run_serial_command(
    client: QmpClient,
    guest_command: str,
    serial_log: Path,
    timeout: float,
    delay: float,
    keep_ansi: bool,
) -> int:
    tag = secrets.token_hex(8)
    offset = current_serial_offset(serial_log)
    typed_command, _ = build_serial_bootstrap_command(guest_command, tag)
    run_type_command(client, typed_command, delay)
    result = wait_for_serial_result(serial_log, offset, tag, timeout)
    output = result.output if keep_ansi else strip_ansi(result.output)
    if output:
        sys.stdout.write(output)
        if not output.endswith("\n"):
            sys.stdout.write("\n")
    if result.exit_code is None:
        raise QmpError(f"Missing serial exit status marker in {serial_log}")
    return result.exit_code


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="QMP helper for live VM debugging")
    parser.add_argument("socket_path", help="Path to the QMP unix socket")
    subparsers = parser.add_subparsers(dest="command", required=True)

    key_parser = subparsers.add_parser("key", help="Send a key chord with QMP send-key")
    key_parser.add_argument("chord", help="Key chord such as ctrl-alt-f9")
    key_parser.add_argument(
        "--hold-ms", type=int, default=None, help="Hold time in milliseconds"
    )

    type_parser = subparsers.add_parser("type", help="Type text with QMP send-key")
    type_parser.add_argument(
        "text", help="Text to type; include literal newlines when needed"
    )
    type_parser.add_argument(
        "--delay", type=float, default=0.02, help="Delay in seconds between characters"
    )

    mouse_parser = subparsers.add_parser("mouse", help="Mouse operations")
    mouse_subparsers = mouse_parser.add_subparsers(dest="mouse_command", required=True)
    mouse_subparsers.add_parser("info", help="Show query-mice output")
    mouse_abs_parser = mouse_subparsers.add_parser(
        "move-abs", help="Move absolute pointer coordinates"
    )
    mouse_abs_parser.add_argument("x", type=int)
    mouse_abs_parser.add_argument("y", type=int)
    mouse_rel_parser = mouse_subparsers.add_parser(
        "move-rel", help="Move relative pointer coordinates"
    )
    mouse_rel_parser.add_argument("dx", type=int)
    mouse_rel_parser.add_argument("dy", type=int)
    mouse_down_parser = mouse_subparsers.add_parser("down", help="Press a mouse button")
    mouse_down_parser.add_argument("button")
    mouse_up_parser = mouse_subparsers.add_parser("up", help="Release a mouse button")
    mouse_up_parser.add_argument("button")
    mouse_click_parser = mouse_subparsers.add_parser(
        "click", help="Click a mouse button"
    )
    mouse_click_parser.add_argument("button")
    mouse_wheel_parser = mouse_subparsers.add_parser("wheel", help="Send wheel events")
    mouse_wheel_parser.add_argument("direction", choices=["up", "down"])
    mouse_wheel_parser.add_argument("--steps", type=int, default=1)

    screendump_parser = subparsers.add_parser("screendump", help="Capture a screendump")
    screendump_parser.add_argument("output")
    screendump_parser.add_argument(
        "--format", dest="image_format", choices=["ppm", "png"], default=None
    )
    screendump_parser.add_argument("--device", default=None)
    screendump_parser.add_argument("--head", type=int, default=None)

    serial_parser = subparsers.add_parser(
        "serial", help="Run a guest shell command and capture ttyS0 output"
    )
    serial_parser.add_argument("guest_command")
    serial_parser.add_argument("--serial-log", default=None)
    serial_parser.add_argument("--timeout", type=float, default=60.0)
    serial_parser.add_argument("--delay", type=float, default=0.02)
    serial_parser.add_argument("--keep-ansi", action="store_true")

    pull_parser = subparsers.add_parser(
        "pull", help="Copy a readable guest file over serial/base64"
    )
    pull_parser.add_argument("guest_path")
    pull_parser.add_argument("output_path")
    pull_parser.add_argument("--serial-log", default=None)
    pull_parser.add_argument("--timeout", type=float, default=60.0)
    pull_parser.add_argument("--delay", type=float, default=0.02)

    hmp_parser = subparsers.add_parser(
        "hmp", help="Escape hatch for human-monitor-command"
    )
    hmp_parser.add_argument("hmp_command")

    raw_parser = subparsers.add_parser("raw", help="Escape hatch for raw QMP JSON")
    raw_parser.add_argument("json_payload")
    return parser.parse_args()


def serial_log_from_args(socket_path: Path, override: str | None) -> Path:
    return (
        Path(override) if override is not None else derive_serial_log_path(socket_path)
    )


def main() -> int:
    args = parse_args()
    socket_path = Path(args.socket_path)
    client = QmpClient(socket_path)

    if args.command == "key":
        response = require_ok(
            client.execute(
                build_send_key_payload(chord_to_keys(args.chord), args.hold_ms)
            ),
            "send-key",
        )
        print(json.dumps(response))
        return 0
    if args.command == "type":
        run_type_command(client, args.text, args.delay)
        return 0
    if args.command == "mouse":
        if args.mouse_command == "info":
            print(json.dumps(query_mice(client), indent=2, sort_keys=True))
            return 0
        if args.mouse_command == "move-abs":
            ensure_current_absolute_mouse(query_mice(client))
            response = require_ok(
                client.execute(mouse_move_abs_payload(args.x, args.y)),
                "input-send-event",
            )
            print(json.dumps(response))
            return 0
        if args.mouse_command == "move-rel":
            response = require_ok(
                client.execute(mouse_move_rel_payload(args.dx, args.dy)),
                "input-send-event",
            )
            print(json.dumps(response))
            return 0
        if args.mouse_command == "down":
            response = require_ok(
                client.execute(mouse_button_payload(args.button, True)),
                "input-send-event",
            )
            print(json.dumps(response))
            return 0
        if args.mouse_command == "up":
            response = require_ok(
                client.execute(mouse_button_payload(args.button, False)),
                "input-send-event",
            )
            print(json.dumps(response))
            return 0
        if args.mouse_command == "click":
            require_ok(
                client.execute(mouse_button_payload(args.button, True)),
                "input-send-event",
            )
            response = require_ok(
                client.execute(mouse_button_payload(args.button, False)),
                "input-send-event",
            )
            print(json.dumps(response))
            return 0
        if args.mouse_command == "wheel":
            if args.steps < 1:
                raise ValueError("--steps must be at least 1")
            response: dict[str, Any] | None = None
            for _ in range(args.steps):
                response = require_ok(
                    client.execute(mouse_wheel_payload(args.direction)),
                    "input-send-event",
                )
            print(json.dumps(response or {"return": {}}))
            return 0
    if args.command == "screendump":
        response = require_ok(
            client.execute(
                build_screendump_payload(
                    Path(args.output), args.image_format, args.device, args.head
                )
            ),
            "screendump",
        )
        print(json.dumps(response))
        return 0
    if args.command == "serial":
        serial_log = serial_log_from_args(socket_path, args.serial_log)
        return run_serial_command(
            client,
            args.guest_command,
            serial_log,
            args.timeout,
            args.delay,
            args.keep_ansi,
        )
    if args.command == "pull":
        serial_log = serial_log_from_args(socket_path, args.serial_log)
        tag = secrets.token_hex(8)
        offset = current_serial_offset(serial_log)
        guest_command = (
            "if [ -r "
            + shlex.quote(args.guest_path)
            + " ]; then /run/current-system/sw/bin/base64 -w0 -- "
            + shlex.quote(args.guest_path)
            + "; else printf 'File not readable: %s\\n' "
            + shlex.quote(args.guest_path)
            + "; exit 1; fi"
        )
        typed_command, _ = build_serial_bootstrap_command(guest_command, tag)
        run_type_command(client, typed_command, args.delay)
        result = wait_for_serial_result(serial_log, offset, tag, args.timeout)
        if result.exit_code is None:
            raise QmpError(f"Missing serial exit status marker in {serial_log}")
        if result.exit_code != 0:
            output = strip_ansi(result.output)
            if output:
                sys.stdout.write(output)
                if not output.endswith("\n"):
                    sys.stdout.write("\n")
            return result.exit_code
        output_path = Path(args.output_path)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_bytes(extract_pull_bytes(result.output))
        print(output_path)
        return 0
    if args.command == "hmp":
        response = require_ok(
            client.execute(
                {
                    "execute": "human-monitor-command",
                    "arguments": {"command-line": args.hmp_command},
                }
            ),
            "human-monitor-command",
        )
        print(json.dumps(response))
        return 0
    if args.command == "raw":
        payload = json.loads(args.json_payload)
        if not isinstance(payload, dict):
            raise ValueError("raw payload must decode to a JSON object")
        response = client.execute(payload)
        print(json.dumps(response))
        return 0 if "error" not in response else 1
    raise AssertionError(f"Unhandled command: {args.command}")


if __name__ == "__main__":
    raise SystemExit(main())
