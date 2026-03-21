"""Nix execution helpers for the VM wrapper."""

from __future__ import annotations

from collections.abc import Callable, Mapping, Sequence
from json import JSONDecodeError
import json
from pathlib import Path
import os
from subprocess import CalledProcessError, CompletedProcess, run

from vm_wrapper.bundle import UserFacingError


RunCommand = Callable[
    [Sequence[str], Mapping[str, str] | None, Path | None, bool], CompletedProcess[str]
]
RunVmCommand = Callable[[Path, Mapping[str, str] | None], int]


def _default_run_command(
    command: Sequence[str],
    env: Mapping[str, str] | None,
    cwd: Path | None,
    check: bool,
) -> CompletedProcess[str]:
    merged_env = os.environ.copy()
    if env is not None:
        merged_env.update(env)

    return run(
        command,
        check=check,
        capture_output=True,
        text=True,
        env=merged_env,
        cwd=cwd,
    )


def _merge_env(env: Mapping[str, str] | None) -> dict[str, str]:
    merged_env = os.environ.copy()
    if env is not None:
        merged_env.update(env)

    return merged_env


def _default_run_vm_command(runner_path: Path, env: Mapping[str, str] | None) -> int:
    completed = run(
        [str(runner_path)],
        check=False,
        text=True,
        env=_merge_env(env),
    )
    return completed.returncode


def list_hosts(
    repo_root: Path, run_command: RunCommand = _default_run_command
) -> list[str]:
    try:
        completed = run_command(
            [
                "nix",
                "eval",
                "--json",
                ".#nixosConfigurations",
                "--apply",
                "builtins.attrNames",
            ],
            None,
            repo_root,
            True,
        )
    except CalledProcessError as exc:
        raise UserFacingError(
            _format_command_error("Failed to list VM hosts", exc)
        ) from exc

    try:
        hosts = json.loads(completed.stdout)
    except JSONDecodeError as exc:
        raise UserFacingError(
            "Failed to parse VM host list from nix output. Try the command again and inspect the JSON output."
        ) from exc

    if not isinstance(hosts, list) or not all(isinstance(host, str) for host in hosts):
        raise UserFacingError(
            "Failed to parse VM host list from nix output. Expected a JSON array of host names."
        )

    return hosts


def require_host(host: str, available_hosts: Sequence[str]) -> None:
    if host in available_hosts:
        return

    available = ", ".join(sorted(available_hosts)) if available_hosts else "none"
    raise UserFacingError(
        f"Unknown host '{host}'. Available nixosConfigurations: {available}."
    )


def build_vm_runner(
    repo_root: Path, host: str, run_command: RunCommand = _default_run_command
) -> Path:
    try:
        completed = run_command(
            [
                "nix",
                "build",
                f".#nixosConfigurations.{host}.config.system.build.vm",
                "--print-out-paths",
                "--no-link",
            ],
            None,
            repo_root,
            True,
        )
    except CalledProcessError as exc:
        raise UserFacingError(
            _format_command_error(f"Failed to build VM runner for host '{host}'", exc)
        ) from exc

    runner_path = completed.stdout.strip()
    if not runner_path:
        raise UserFacingError(
            f"Failed to build VM runner for host '{host}'. nix did not return a runner path."
        )

    return Path(runner_path)


def run_vm(
    runner_path: Path,
    bundle_dir: Path,
    run_command: RunVmCommand = _default_run_vm_command,
) -> int:
    return run_command(runner_path, {"VM_BUNDLE_DIR": str(bundle_dir)})


def _format_command_error(prefix: str, error: CalledProcessError) -> str:
    details = (error.stderr or error.stdout or "").strip()
    if details:
        return f"{prefix}. {details}"
    return prefix
