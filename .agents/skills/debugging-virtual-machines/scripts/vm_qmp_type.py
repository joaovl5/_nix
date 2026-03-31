#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import socket
import string
import time
from typing import Any

BASE_KEYS = {char: char for char in string.ascii_lowercase}
BASE_KEYS.update({str(i): str(i) for i in range(10)})
BASE_KEYS.update(
    {
        " ": "spc",
        "\t": "tab",
        "\n": "ret",
        "/": "slash",
        "\\": "backslash",
        "-": "minus",
        "=": "equal",
        ";": "semicolon",
        "'": "apostrophe",
        ",": "comma",
        ".": "dot",
        "[": "leftbracket",
        "]": "rightbracket",
        "`": "grave_accent",
    }
)

SHIFT_KEYS = {
    "_": "minus",
    "+": "equal",
    ":": "semicolon",
    '"': "apostrophe",
    "<": "comma",
    ">": "dot",
    "?": "slash",
    "{": "leftbracket",
    "}": "rightbracket",
    "|": "backslash",
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
for char in string.ascii_uppercase:
    SHIFT_KEYS[char] = char.lower()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Type text into a VM through QMP sendkey"
    )
    parser.add_argument("socket_path", help="Path to the QMP unix socket")
    parser.add_argument(
        "text", help="Text to type; include literal newline characters if needed"
    )
    parser.add_argument(
        "--delay",
        type=float,
        default=0.02,
        help="Delay in seconds between key presses (default: 0.02)",
    )
    return parser.parse_args()


def read_response(file_obj: Any) -> dict[str, Any]:
    while True:
        line = file_obj.readline()
        if not line:
            raise RuntimeError("QMP socket closed before a response was received")
        payload = json.loads(line.decode())
        if "return" in payload or "error" in payload:
            return payload


def qmp_capabilities(file_obj: Any) -> None:
    greeting = file_obj.readline()
    if not greeting:
        raise RuntimeError("No QMP greeting received")
    json.loads(greeting.decode())
    file_obj.write((json.dumps({"execute": "qmp_capabilities"}) + "\r\n").encode())
    response = read_response(file_obj)
    if "error" in response:
        raise RuntimeError(f"qmp_capabilities failed: {response}")


def send_hmp(file_obj: Any, command_line: str) -> None:
    file_obj.write(
        (
            json.dumps(
                {
                    "execute": "human-monitor-command",
                    "arguments": {"command-line": command_line},
                }
            )
            + "\r\n"
        ).encode()
    )
    response = read_response(file_obj)
    if "error" in response:
        raise RuntimeError(f"QMP HMP command failed: {response}")


def encode_key(char: str) -> str:
    if char in BASE_KEYS:
        return BASE_KEYS[char]
    if char in SHIFT_KEYS:
        return f"shift-{SHIFT_KEYS[char]}"
    raise RuntimeError(f"Unsupported character for sendkey mapping: {char!r}")


def main() -> int:
    args = parse_args()
    client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    client.connect(args.socket_path)
    try:
        file_obj = client.makefile("rwb", buffering=0)
        qmp_capabilities(file_obj)
        for char in args.text:
            send_hmp(file_obj, f"sendkey {encode_key(char)}")
            time.sleep(args.delay)
        return 0
    finally:
        client.close()


if __name__ == "__main__":
    raise SystemExit(main())
