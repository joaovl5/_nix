from __future__ import annotations

from collections.abc import Callable, Sequence
import subprocess
from typing import TypeVar

ErrorT = TypeVar("ErrorT", bound=Exception)


def command_error_detail(result: subprocess.CompletedProcess[str]) -> str:
    return (result.stderr or result.stdout or str(result.returncode)).strip()


def require_success(
    result: subprocess.CompletedProcess[str], *, error_type: type[ErrorT]
) -> subprocess.CompletedProcess[str]:
    if result.returncode == 0:
        return result
    raise error_type(command_error_detail(result))


def run_docker_command(
    command: Sequence[str],
    *,
    capture_output: bool,
    missing_binary_error: type[ErrorT],
    nonzero_error: type[ErrorT] | None = None,
    runner: Callable[..., subprocess.CompletedProcess[str]] | None = None,
) -> subprocess.CompletedProcess[str]:
    command_runner = subprocess.run if runner is None else runner
    try:
        result = command_runner(
            list(command),
            check=False,
            text=True,
            capture_output=capture_output,
        )
    except FileNotFoundError as exc:
        raise missing_binary_error("docker executable not found") from exc
    if nonzero_error is not None:
        return require_success(result, error_type=nonzero_error)
    return result
