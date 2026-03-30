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

DEFAULT_VM_CPU = 4
DEFAULT_VM_RAM = 6192


def _vm_launcher_from_build_output(host: str, output_path: Path) -> Path:
    """Resolve the executable path inside a VM build output.

    NixOS `config.system.build.vm` can currently evaluate to either:
    - a direct executable script, or
    - a directory containing `bin/run-<host>-vm`.
    """

    if output_path.is_file():
        return output_path

    if output_path.is_dir():
        preferred = output_path / "bin" / f"run-{host}-vm"
        if preferred.is_file():
            return preferred

        bin_dir = output_path / "bin"
        if not bin_dir.is_dir():
            raise UserFacingError(
                "Failed to resolve VM runner path: vm build output has no `bin` directory."
            )

        candidates = sorted(
            path
            for path in bin_dir.iterdir()
            if path.is_file()
            and path.name.startswith("run-")
            and path.name.endswith("-vm")
        )

        if len(candidates) == 1:
            return candidates[0]

        if len(candidates) == 0:
            raise UserFacingError(
                "Failed to resolve VM runner path: no `run-<host>-vm` script found in"
                f" {bin_dir}."
            )

        raise UserFacingError(
            "Failed to resolve VM runner path: multiple candidates found in"
            f" {bin_dir}: {', '.join(path.name for path in candidates)}"
        )

    raise UserFacingError(
        f"Failed to resolve VM runner path: unexpected output at {output_path}."
    )


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


def _with_qemu_overrides(
    env: Mapping[str, str] | None, *, cpu: int, ram: int
) -> dict[str, str]:
    merged_env = dict(env or {})
    qemu_opts = os.environ.get("QEMU_OPTS", "")

    override_opts = ""
    if cpu != DEFAULT_VM_CPU or ram != DEFAULT_VM_RAM:
        override_opts = f"-m {ram} -smp {cpu}"

    combined_opts = " ".join(opt for opt in [qemu_opts, override_opts] if opt).strip()
    if combined_opts:
        merged_env["QEMU_OPTS"] = combined_opts

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

    vm_output_path = Path(runner_path)
    return _vm_launcher_from_build_output(host=host, output_path=vm_output_path)


def run_vm(
    runner_path: Path,
    bundle_dir: Path,
    cpu: int,
    ram: int,
    run_command: RunVmCommand = _default_run_vm_command,
) -> int:
    return run_command(
        runner_path,
        _with_qemu_overrides(
            {"VM_BUNDLE_DIR": str(bundle_dir)},
            cpu=cpu,
            ram=ram,
        ),
    )


def _format_command_error(prefix: str, error: CalledProcessError) -> str:
    details = (error.stderr or error.stdout or "").strip()
    if details:
        return f"{prefix}. {details}"
    return prefix
