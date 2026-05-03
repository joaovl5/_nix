from __future__ import annotations

import sys

from rich.console import Console
from rich.markup import escape


def _stderr_console() -> Console:
    return Console(file=sys.stderr, stderr=True)


def _render_stderr(*, style: str, message: str) -> None:
    _stderr_console().print(f"[{style}]{escape(message)}[/{style}]")


def render_status(message: str) -> None:
    _render_stderr(style="cyan", message=message)


def render_warning(message: str) -> None:
    _render_stderr(style="yellow", message=message)


def render_error(message: str) -> None:
    _render_stderr(style="bold red", message=message)


def render_no_profile_selected() -> None:
    render_warning("No frag profile selected.")


def render_no_workspace(message: str) -> None:
    render_error(message)


def render_legacy_schema_refusal(message: str) -> None:
    render_error(message)
