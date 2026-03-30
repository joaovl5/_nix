#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import socket
from pathlib import Path
from typing import Any


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Minimal QMP helper for live VM debugging"
    )
    parser.add_argument("socket_path", help="Path to the QMP unix socket")
    parser.add_argument(
        "action",
        choices=["hmp", "sendkey", "screendump", "raw"],
        help="Operation to perform",
    )
    parser.add_argument(
        "value",
        help="HMP command, sendkey chord, screendump path, or raw JSON payload",
    )
    parser.add_argument(
        "--pretty",
        action="store_true",
        help="Pretty-print JSON responses",
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


def qmp_execute(socket_path: str, payload: dict[str, Any]) -> dict[str, Any]:
    client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    client.connect(socket_path)
    try:
        file_obj = client.makefile("rwb", buffering=0)
        greeting = file_obj.readline()
        if not greeting:
            raise RuntimeError("No QMP greeting received")
        json.loads(greeting.decode())

        file_obj.write((json.dumps({"execute": "qmp_capabilities"}) + "\r\n").encode())
        capabilities_response = read_response(file_obj)
        if "error" in capabilities_response:
            raise RuntimeError(f"qmp_capabilities failed: {capabilities_response}")

        file_obj.write((json.dumps(payload) + "\r\n").encode())
        return read_response(file_obj)
    finally:
        client.close()


def build_payload(action: str, value: str) -> dict[str, Any]:
    if action == "hmp":
        return {
            "execute": "human-monitor-command",
            "arguments": {"command-line": value},
        }
    if action == "sendkey":
        return {
            "execute": "human-monitor-command",
            "arguments": {"command-line": f"sendkey {value}"},
        }
    if action == "screendump":
        destination = str(Path(value))
        return {"execute": "screendump", "arguments": {"filename": destination}}
    if action == "raw":
        payload = json.loads(value)
        if not isinstance(payload, dict):
            raise RuntimeError("raw payload must decode to a JSON object")
        return payload
    raise RuntimeError(f"Unsupported action: {action}")


def main() -> int:
    args = parse_args()
    payload = build_payload(args.action, args.value)
    response = qmp_execute(args.socket_path, payload)
    if args.pretty:
        print(json.dumps(response, indent=2, sort_keys=True))
    else:
        print(json.dumps(response))
    return 0 if "error" not in response else 1


if __name__ == "__main__":
    raise SystemExit(main())
