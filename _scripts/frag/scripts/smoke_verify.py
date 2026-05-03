from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import time

from frag import profiles, verification

_EXPECTED_WHOAMI = "agent"
_EXPECTED_WORKSPACE_ROOT = "/workspace-root"
_SHARED_ASSET_PATH = "$HOME/.config/opencode/opencode.json"
_READ_ONLY_FAILURE_SUBSTRINGS = ("read-only", "permission denied")


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Run cleanup-safe frag smoke verification"
    )
    parser.add_argument("--frag-bin", required=True, type=Path)
    parser.add_argument("--profile-image", default="main")
    parser.add_argument("--workspace-root", type=Path, default=Path.cwd())
    return parser


def _run_timed(
    timings: dict[str, float],
    key: str,
    *command: str,
    cwd: Path | None = None,
    expect_success: bool = True,
    failure_message: str | None = None,
) -> subprocess.CompletedProcess[str]:
    started_at = time.perf_counter()
    result = subprocess.run(
        command,
        check=False,
        capture_output=True,
        text=True,
        cwd=cwd,
    )
    timings[key] = time.perf_counter() - started_at

    if expect_success:
        if result.returncode != 0:
            raise subprocess.CalledProcessError(
                result.returncode,
                command,
                output=result.stdout,
                stderr=result.stderr,
            )
        return result

    if result.returncode == 0:
        raise RuntimeError(failure_message or f"expected command to fail: {command!r}")
    return result


def _require_stdout(
    result: subprocess.CompletedProcess[str], *, expected: str, description: str
) -> None:
    actual = result.stdout.strip()
    if actual != expected:
        raise RuntimeError(
            f"expected {description} to print {expected!r}, got {actual!r}"
        )


def _require_read_only_failure(
    result: subprocess.CompletedProcess[str], *, path_description: str
) -> None:
    detail = (result.stderr or result.stdout).strip().lower()
    if not any(fragment in detail for fragment in _READ_ONLY_FAILURE_SUBSTRINGS):
        raise RuntimeError(
            f"{path_description} failed for an unexpected reason: {detail or result.returncode}"
        )


def _time_action(
    timings: dict[str, float], key: str, action: verification.CleanupCallback
) -> None:
    started_at = time.perf_counter()
    action()
    timings[key] = time.perf_counter() - started_at


def main(argv: list[str] | None = None) -> int:
    args = _build_parser().parse_args(argv)
    docker_backend = profiles.DockerCliBackend()
    artifacts = verification.create_verification_artifacts(
        purpose="smoke",
        workspace_root=args.workspace_root,
    )

    with verification.CleanupHarness() as cleanup:
        cleanup.register(
            "workspace",
            lambda: verification.remove_workspace_if_present(
                workspace_path=artifacts.workspace_path
            ),
        )
        cleanup.register(
            "profile",
            lambda: verification.remove_profile_if_present(
                docker_backend=docker_backend,
                profile_name=artifacts.profile_name,
            ),
        )
        cleanup.register(
            "container",
            lambda: verification.stop_profile_container_if_present(
                profile_name=artifacts.profile_name
            ),
        )

        artifacts.workspace_path.mkdir(parents=True, exist_ok=False)
        (artifacts.workspace_path / "smoke.txt").write_text("frag smoke verification\n")
        workspace_gid = artifacts.workspace_path.stat().st_gid

        frag_bin = str(args.frag_bin.expanduser().resolve(strict=False))
        timings: dict[str, float] = {}

        _run_timed(
            timings,
            "profile_new_seconds",
            frag_bin,
            "profile",
            "new",
            "--name",
            artifacts.profile_name,
            "--image",
            args.profile_image,
            "--workspace-root",
            str(artifacts.workspace_path),
        )

        listed_profiles = _run_timed(
            timings,
            "profile_list_seconds",
            frag_bin,
            "profile",
            "list",
        )
        if artifacts.profile_name not in listed_profiles.stdout:
            raise RuntimeError(
                f"missing verification profile {artifacts.profile_name!r}"
            )

        enter_whoami = _run_timed(
            timings,
            "enter_whoami_seconds",
            frag_bin,
            "enter",
            "--profile",
            artifacts.profile_name,
            "--",
            "whoami",
            cwd=artifacts.workspace_path,
        )
        _require_stdout(
            enter_whoami,
            expected=_EXPECTED_WHOAMI,
            description="enter whoami",
        )

        enter_pwd = _run_timed(
            timings,
            "enter_pwd_seconds",
            frag_bin,
            "enter",
            "--profile",
            artifacts.profile_name,
            "--",
            "pwd",
            cwd=artifacts.workspace_path,
        )
        _require_stdout(
            enter_pwd,
            expected=_EXPECTED_WORKSPACE_ROOT,
            description="enter pwd",
        )
        _run_timed(
            timings,
            "workspace_write_seconds",
            frag_bin,
            "enter",
            "--profile",
            artifacts.profile_name,
            "--",
            "sh",
            "-lc",
            'printf "workspace smoke\\n" > smoke-workspace-write.txt',
            cwd=artifacts.workspace_path,
        )

        workspace_write_path = artifacts.workspace_path / "smoke-workspace-write.txt"
        stat_result = workspace_write_path.stat()
        if stat_result.st_uid != os.getuid() or stat_result.st_gid != workspace_gid:
            raise RuntimeError(
                "workspace write did not preserve host ownership: "
                f"expected uid/gid {os.getuid()}:{workspace_gid}, "
                f"got {stat_result.st_uid}:{stat_result.st_gid}"
            )

        _run_timed(
            timings,
            "omp_help_seconds",
            frag_bin,
            "enter",
            "--profile",
            artifacts.profile_name,
            "--",
            "omp",
            "--help",
            cwd=artifacts.workspace_path,
        )

        home_marker = f"frag-home-marker-{artifacts.label}"
        _run_timed(
            timings,
            "home_write_seconds",
            frag_bin,
            "enter",
            "--profile",
            artifacts.profile_name,
            "--",
            "sh",
            "-lc",
            f'printf "{home_marker}" > "$HOME/.frag-smoke-home"',
            cwd=artifacts.workspace_path,
        )
        shared_asset_write = _run_timed(
            timings,
            "shared_asset_write_rejected_seconds",
            frag_bin,
            "enter",
            "--profile",
            artifacts.profile_name,
            "--",
            "sh",
            "-lc",
            f'test -f "{_SHARED_ASSET_PATH}" && '
            f'printf "blocked" >> "{_SHARED_ASSET_PATH}"',
            cwd=artifacts.workspace_path,
            expect_success=False,
            failure_message="expected shared asset write to fail",
        )
        _require_read_only_failure(
            shared_asset_write,
            path_description="shared asset write",
        )

        _time_action(
            timings,
            "stop_container_seconds",
            lambda: verification.stop_profile_container_if_present(
                profile_name=artifacts.profile_name
            ),
        )
        _run_timed(
            timings,
            "restart_persistence_check_seconds",
            frag_bin,
            "enter",
            "--profile",
            artifacts.profile_name,
            "--",
            "sh",
            "-lc",
            f'test "$(cat "$HOME/.frag-smoke-home")" = "{home_marker}"',
            cwd=artifacts.workspace_path,
        )

        timings["fresh_cold_start_seconds"] = (
            timings["profile_new_seconds"] + timings["enter_whoami_seconds"]
        )
        timings["reuse_seconds"] = (
            timings["enter_pwd_seconds"]
            + timings["workspace_write_seconds"]
            + timings["omp_help_seconds"]
            + timings["shared_asset_write_rejected_seconds"]
        )
        timings["restart_reentry_seconds"] = (
            timings["stop_container_seconds"]
            + timings["restart_persistence_check_seconds"]
        )
        print(f"timing_summary={json.dumps(timings, sort_keys=True)}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
