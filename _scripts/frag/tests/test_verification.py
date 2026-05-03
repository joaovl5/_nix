from __future__ import annotations

import importlib.util
import json
import subprocess
import sys
from pathlib import Path
from types import ModuleType

import pytest

from frag import profiles, verification


def test_create_verification_artifacts_uses_clear_namespace(tmp_path: Path) -> None:
    artifacts = verification.create_verification_artifacts(
        purpose="smoke",
        workspace_root=tmp_path,
        token_factory=lambda: "abc12345",
    )

    assert artifacts.label == "frag-verify-smoke-abc12345"
    assert artifacts.profile_name == "frag-verify-smoke-abc12345"
    assert artifacts.workspace_path == tmp_path / "frag-verify-smoke-abc12345"


def test_cleanup_runs_when_verification_step_fails() -> None:
    events: list[str] = []
    harness = verification.CleanupHarness()
    harness.register("workspace", lambda: events.append("workspace"))
    harness.register("profile", lambda: events.append("profile"))
    harness.register("container", lambda: events.append("container"))

    with pytest.raises(RuntimeError, match="verification failed"):
        with harness:
            events.append("body")
            raise RuntimeError("verification failed")

    assert events == ["body", "container", "profile", "workspace"]


def test_cleanup_tolerates_already_missing_resources(tmp_path: Path) -> None:
    harness = verification.CleanupHarness()
    workspace_path = tmp_path / "workspace"

    harness.register(
        "profile",
        lambda: (_ for _ in ()).throw(profiles.ProfileNotFoundError("gone-profile")),
    )
    harness.register(
        "container",
        lambda: (_ for _ in ()).throw(
            subprocess.CalledProcessError(
                1,
                ["docker", "stop", "gone-container"],
                stderr="Error response from daemon: No such container: gone-container",
            )
        ),
    )
    harness.register(
        "workspace",
        lambda: verification.remove_workspace_if_present(workspace_path=workspace_path),
    )

    harness.run_cleanup()


def test_cleanup_does_not_swallow_missing_executable_errors() -> None:
    harness = verification.CleanupHarness()
    harness.register(
        "container",
        lambda: (_ for _ in ()).throw(
            FileNotFoundError(2, "No such file or directory", "docker")
        ),
    )

    with pytest.raises(FileNotFoundError, match="docker"):
        harness.run_cleanup()


class TransientVolumeInUseOnRemoveBackend:
    def __init__(self) -> None:
        self.removed_volumes: list[str] = []
        self.remove_attempts = 0

    def create_volume(self, name: str, labels: dict[str, str]) -> None:
        raise AssertionError(f"unexpected create_volume({name!r}, {labels!r})")

    def list_volumes(self) -> list[dict[str, object]]:
        return [
            {
                "name": "frag-profile-racy-profile",
                "labels": {
                    profiles.LABEL_PROFILE: "racy-profile",
                    profiles.LABEL_IMAGE: "loaded:image",
                    profiles.LABEL_WORKSPACE_ROOT: "/tmp/workspace",
                    profiles.LABEL_SCHEMA_VERSION: profiles.SCHEMA_VERSION,
                },
            }
        ]

    def remove_volume(self, name: str) -> None:
        self.removed_volumes.append(name)
        self.remove_attempts += 1
        if self.remove_attempts == 1:
            raise profiles.DockerBackendError(
                f"Error response from daemon: remove {name}: volume is in use - [container-id]"
            )

    def is_profile_running(self, profile_name: str) -> bool:
        return False


def test_remove_profile_retries_transient_volume_in_use_cleanup_race() -> None:
    backend = TransientVolumeInUseOnRemoveBackend()

    verification.remove_profile_if_present(
        docker_backend=backend,
        profile_name="racy-profile",
    )

    assert backend.removed_volumes == [
        "frag-profile-racy-profile",
        "frag-profile-racy-profile",
    ]
    assert backend.remove_attempts == 2


def _load_smoke_verify_module() -> ModuleType:
    script_path = Path(__file__).resolve().parent.parent / "scripts" / "smoke_verify.py"
    spec = importlib.util.spec_from_file_location("frag_smoke_verify_test", script_path)
    assert spec is not None
    assert spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def _stub_smoke_cleanup_callbacks(
    monkeypatch: pytest.MonkeyPatch,
    smoke_verify: ModuleType,
) -> list[tuple[str, str]]:
    cleanup_calls: list[tuple[str, str]] = []

    monkeypatch.setattr(
        smoke_verify.verification,
        "remove_workspace_if_present",
        lambda *, workspace_path: cleanup_calls.append(
            ("workspace", str(workspace_path))
        ),
    )
    monkeypatch.setattr(
        smoke_verify.verification,
        "remove_profile_if_present",
        lambda *, docker_backend, profile_name: cleanup_calls.append(
            ("profile", profile_name)
        ),
    )
    monkeypatch.setattr(
        smoke_verify.verification,
        "stop_profile_container_if_present",
        lambda *, profile_name: cleanup_calls.append(("container", profile_name)),
    )

    return cleanup_calls


def test_smoke_verify_parser_defaults_to_main_profile_image() -> None:
    smoke_verify = _load_smoke_verify_module()
    parser = smoke_verify._build_parser()
    default_args = parser.parse_args(["--frag-bin", "./result/bin/frag"])

    assert default_args.profile_image == "main"

    explicit_args = parser.parse_args(
        [
            "--frag-bin",
            "./result/bin/frag",
            "--profile-image",
            "custom",
        ]
    )
    assert explicit_args.profile_image == "custom"


def test_smoke_verify_runs_checks_and_prints_timing_summary(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    smoke_verify = _load_smoke_verify_module()
    caller_cwd = tmp_path / "caller"
    caller_cwd.mkdir()
    monkeypatch.chdir(caller_cwd)

    artifacts = verification.VerificationArtifacts(
        label="frag-verify-smoke-abc12345",
        profile_name="frag-verify-smoke-abc12345",
        workspace_path=tmp_path / "verification-root" / "frag-verify-smoke-abc12345",
    )
    monkeypatch.setattr(
        smoke_verify.verification,
        "create_verification_artifacts",
        lambda **_kwargs: artifacts,
    )
    cleanup_calls = _stub_smoke_cleanup_callbacks(
        monkeypatch,
        smoke_verify,
    )

    perf_samples = iter(float(value) for value in range(20))
    monkeypatch.setattr(
        smoke_verify.time,
        "perf_counter",
        lambda: next(perf_samples),
    )

    calls: list[dict[str, object]] = []
    home_marker: dict[str, str] = {}

    def fake_run(
        command: tuple[str, ...] | list[str], **kwargs: object
    ) -> subprocess.CompletedProcess[str]:
        command_tuple = tuple(command)
        calls.append({"command": command_tuple, "cwd": kwargs.get("cwd")})

        if command_tuple[1:3] == ("profile", "list"):
            return subprocess.CompletedProcess(
                args=command_tuple,
                returncode=0,
                stdout=f"{artifacts.profile_name}\n",
                stderr="",
            )

        if command_tuple[1] != "enter":
            return subprocess.CompletedProcess(
                args=command_tuple, returncode=0, stdout="", stderr=""
            )

        if command_tuple[-1] == "whoami":
            return subprocess.CompletedProcess(
                args=command_tuple, returncode=0, stdout="agent\n", stderr=""
            )
        if command_tuple[-1] == "pwd":
            return subprocess.CompletedProcess(
                args=command_tuple,
                returncode=0,
                stdout="/workspace-root\n",
                stderr="",
            )
        if command_tuple[-2:] == ("omp", "--help"):
            return subprocess.CompletedProcess(
                args=command_tuple, returncode=0, stdout="usage: omp\n", stderr=""
            )

        shell_snippet = command_tuple[-1]
        if shell_snippet == 'printf "workspace smoke\\n" > smoke-workspace-write.txt':
            workspace_file = artifacts.workspace_path / "smoke-workspace-write.txt"
            workspace_file.write_text("workspace smoke\n")
            return subprocess.CompletedProcess(
                args=command_tuple, returncode=0, stdout="", stderr=""
            )
        if (
            shell_snippet.startswith('printf "frag-home-marker-')
            and ' > "$HOME/.frag-smoke-home"' in shell_snippet
        ):
            home_marker["value"] = shell_snippet.split('"')[1]
            return subprocess.CompletedProcess(
                args=command_tuple, returncode=0, stdout="", stderr=""
            )
        if shell_snippet.startswith(
            'test "$(cat "$HOME/.frag-smoke-home")" = "'
        ) and shell_snippet.endswith('"'):
            expected = shell_snippet.rsplit('"', 2)[1]
            return subprocess.CompletedProcess(
                args=command_tuple,
                returncode=0 if home_marker.get("value") == expected else 1,
                stdout="",
                stderr="",
            )
        if shell_snippet == (
            'test -f "$HOME/.config/opencode/opencode.json" && '
            'printf "blocked" >> "$HOME/.config/opencode/opencode.json"'
        ):
            return subprocess.CompletedProcess(
                args=command_tuple,
                returncode=1,
                stdout="",
                stderr="Read-only file system",
            )

        raise AssertionError(f"unexpected command: {command_tuple!r}")

    monkeypatch.setattr(smoke_verify.subprocess, "run", fake_run)

    assert (
        smoke_verify.main(
            [
                "--frag-bin",
                "./result/bin/frag",
                "--workspace-root",
                str(tmp_path / "verification-root"),
            ]
        )
        == 0
    )

    enter_calls = [call for call in calls if call["command"][1] == "enter"]
    assert {call["cwd"] for call in enter_calls} == {artifacts.workspace_path}
    assert cleanup_calls == [
        ("container", artifacts.profile_name),
        ("container", artifacts.profile_name),
        ("profile", artifacts.profile_name),
        ("workspace", str(artifacts.workspace_path)),
    ]

    captured = capsys.readouterr()
    summary = json.loads(captured.out.strip().split("timing_summary=", maxsplit=1)[1])
    assert summary == {
        "enter_pwd_seconds": 1.0,
        "enter_whoami_seconds": 1.0,
        "fresh_cold_start_seconds": 2.0,
        "home_write_seconds": 1.0,
        "omp_help_seconds": 1.0,
        "profile_list_seconds": 1.0,
        "profile_new_seconds": 1.0,
        "restart_persistence_check_seconds": 1.0,
        "restart_reentry_seconds": 2.0,
        "reuse_seconds": 4.0,
        "shared_asset_write_rejected_seconds": 1.0,
        "stop_container_seconds": 1.0,
        "workspace_write_seconds": 1.0,
    }


def test_smoke_verify_resolves_relative_frag_bin_before_workspace_scoped_enters(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    smoke_verify = _load_smoke_verify_module()
    caller_cwd = tmp_path / "caller"
    caller_cwd.mkdir()
    monkeypatch.chdir(caller_cwd)

    expected_frag_bin = (caller_cwd / "result" / "bin" / "frag").resolve()

    artifacts = verification.VerificationArtifacts(
        label="frag-verify-smoke-abc12345",
        profile_name="frag-verify-smoke-abc12345",
        workspace_path=tmp_path / "verification-root" / "frag-verify-smoke-abc12345",
    )
    monkeypatch.setattr(
        smoke_verify.verification,
        "create_verification_artifacts",
        lambda **_kwargs: artifacts,
    )
    cleanup_calls = _stub_smoke_cleanup_callbacks(
        monkeypatch,
        smoke_verify,
    )
    monkeypatch.setattr(smoke_verify.time, "perf_counter", lambda: 0.0)

    home_marker: dict[str, str] = {}
    calls: list[dict[str, object]] = []

    def fake_run(
        command: tuple[str, ...] | list[str], **kwargs: object
    ) -> subprocess.CompletedProcess[str]:
        command_tuple = tuple(command)
        calls.append({"command": command_tuple, "cwd": kwargs.get("cwd")})
        if kwargs.get("cwd") == artifacts.workspace_path and command_tuple[0] != str(
            expected_frag_bin
        ):
            raise FileNotFoundError(
                f"expected resolved frag binary {expected_frag_bin}, got {command_tuple[0]}"
            )

        if command_tuple[1:3] == ("profile", "list"):
            return subprocess.CompletedProcess(
                args=command_tuple,
                returncode=0,
                stdout=f"{artifacts.profile_name}\n",
                stderr="",
            )
        if command_tuple[1] != "enter":
            return subprocess.CompletedProcess(
                args=command_tuple, returncode=0, stdout="", stderr=""
            )
        if command_tuple[-1] == "whoami":
            return subprocess.CompletedProcess(
                args=command_tuple, returncode=0, stdout="agent\n", stderr=""
            )
        if command_tuple[-1] == "pwd":
            return subprocess.CompletedProcess(
                args=command_tuple,
                returncode=0,
                stdout="/workspace-root\n",
                stderr="",
            )
        if command_tuple[-2:] == ("omp", "--help"):
            return subprocess.CompletedProcess(
                args=command_tuple, returncode=0, stdout="usage: omp\n", stderr=""
            )

        shell_snippet = command_tuple[-1]
        if shell_snippet == 'printf "workspace smoke\\n" > smoke-workspace-write.txt':
            (artifacts.workspace_path / "smoke-workspace-write.txt").write_text(
                "workspace smoke\n"
            )
            return subprocess.CompletedProcess(
                args=command_tuple, returncode=0, stdout="", stderr=""
            )
        if (
            shell_snippet.startswith('printf "frag-home-marker-')
            and ' > "$HOME/.frag-smoke-home"' in shell_snippet
        ):
            home_marker["value"] = shell_snippet.split('"')[1]
            return subprocess.CompletedProcess(
                args=command_tuple, returncode=0, stdout="", stderr=""
            )
        if shell_snippet.startswith(
            'test "$(cat "$HOME/.frag-smoke-home")" = "'
        ) and shell_snippet.endswith('"'):
            expected = shell_snippet.rsplit('"', 2)[1]
            return subprocess.CompletedProcess(
                args=command_tuple,
                returncode=0 if home_marker.get("value") == expected else 1,
                stdout="",
                stderr="",
            )
        if shell_snippet == (
            'test -f "$HOME/.config/opencode/opencode.json" && '
            'printf "blocked" >> "$HOME/.config/opencode/opencode.json"'
        ):
            return subprocess.CompletedProcess(
                args=command_tuple,
                returncode=1,
                stdout="",
                stderr="Read-only file system",
            )

        raise AssertionError(f"unexpected command: {command_tuple!r}")

    monkeypatch.setattr(smoke_verify.subprocess, "run", fake_run)

    assert (
        smoke_verify.main(
            [
                "--frag-bin",
                "./result/bin/frag",
                "--workspace-root",
                str(tmp_path / "verification-root"),
            ]
        )
        == 0
    )

    enter_calls = [call for call in calls if call["command"][1] == "enter"]
    assert enter_calls
    assert {call["command"][0] for call in enter_calls} == {str(expected_frag_bin)}
    assert cleanup_calls == [
        ("container", artifacts.profile_name),
        ("container", artifacts.profile_name),
        ("profile", artifacts.profile_name),
        ("workspace", str(artifacts.workspace_path)),
    ]


def test_smoke_verify_accepts_workspace_write_with_workspace_directory_gid(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    smoke_verify = _load_smoke_verify_module()

    artifacts = verification.VerificationArtifacts(
        label="frag-verify-smoke-abc12345",
        profile_name="frag-verify-smoke-abc12345",
        workspace_path=tmp_path / "verification-root" / "frag-verify-smoke-abc12345",
    )
    monkeypatch.setattr(
        smoke_verify.verification,
        "create_verification_artifacts",
        lambda **_kwargs: artifacts,
    )
    monkeypatch.setattr(
        smoke_verify.verification,
        "remove_workspace_if_present",
        lambda **_kwargs: None,
    )
    monkeypatch.setattr(
        smoke_verify.verification,
        "remove_profile_if_present",
        lambda **_kwargs: None,
    )
    monkeypatch.setattr(
        smoke_verify.verification,
        "stop_profile_container_if_present",
        lambda **_kwargs: None,
    )
    monkeypatch.setattr(smoke_verify.time, "perf_counter", lambda: 0.0)
    monkeypatch.setattr(
        smoke_verify.os,
        "getgid",
        lambda: tmp_path.stat().st_gid + 1,
    )

    home_marker: dict[str, str] = {}

    def fake_run(
        command: tuple[str, ...] | list[str], **kwargs: object
    ) -> subprocess.CompletedProcess[str]:
        del kwargs
        command_tuple = tuple(command)
        if command_tuple[1:3] == ("profile", "list"):
            return subprocess.CompletedProcess(
                args=command_tuple,
                returncode=0,
                stdout=f"{artifacts.profile_name}\n",
                stderr="",
            )
        if command_tuple[-1] == "whoami":
            return subprocess.CompletedProcess(
                args=command_tuple, returncode=0, stdout="agent\n", stderr=""
            )
        if command_tuple[-1] == "pwd":
            return subprocess.CompletedProcess(
                args=command_tuple,
                returncode=0,
                stdout="/workspace-root\n",
                stderr="",
            )
        if command_tuple[-2:] == ("omp", "--help"):
            return subprocess.CompletedProcess(
                args=command_tuple, returncode=0, stdout="usage: omp\n", stderr=""
            )

        shell_snippet = command_tuple[-1]
        if shell_snippet == 'printf "workspace smoke\\n" > smoke-workspace-write.txt':
            (artifacts.workspace_path / "smoke-workspace-write.txt").write_text(
                "workspace smoke\n"
            )
            return subprocess.CompletedProcess(
                args=command_tuple, returncode=0, stdout="", stderr=""
            )
        if (
            shell_snippet.startswith('printf "frag-home-marker-')
            and ' > "$HOME/.frag-smoke-home"' in shell_snippet
        ):
            home_marker["value"] = shell_snippet.split('"')[1]
            return subprocess.CompletedProcess(
                args=command_tuple, returncode=0, stdout="", stderr=""
            )
        if shell_snippet.startswith(
            'test "$(cat "$HOME/.frag-smoke-home")" = "'
        ) and shell_snippet.endswith('"'):
            expected = shell_snippet.rsplit('"', 2)[1]
            return subprocess.CompletedProcess(
                args=command_tuple,
                returncode=0 if home_marker.get("value") == expected else 1,
                stdout="",
                stderr="",
            )
        if shell_snippet == (
            'test -f "$HOME/.config/opencode/opencode.json" && '
            'printf "blocked" >> "$HOME/.config/opencode/opencode.json"'
        ):
            return subprocess.CompletedProcess(
                args=command_tuple,
                returncode=1,
                stdout="",
                stderr="Read-only file system",
            )

        return subprocess.CompletedProcess(
            args=command_tuple, returncode=0, stdout="", stderr=""
        )

    monkeypatch.setattr(smoke_verify.subprocess, "run", fake_run)

    assert (
        smoke_verify.main(
            [
                "--frag-bin",
                str(tmp_path / "frag"),
                "--workspace-root",
                str(tmp_path / "verification-root"),
            ]
        )
        == 0
    )


@pytest.mark.parametrize(
    ("command_name", "stdout", "match"),
    [
        ("whoami", "root\n", "expected enter whoami to print 'agent'"),
        (
            "pwd",
            "/tmp/outside-workspace\n",
            "expected enter pwd to print '/workspace-root'",
        ),
    ],
)
def test_smoke_verify_rejects_unexpected_enter_stdout(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    command_name: str,
    stdout: str,
    match: str,
) -> None:
    smoke_verify = _load_smoke_verify_module()

    artifacts = verification.VerificationArtifacts(
        label="frag-verify-smoke-abc12345",
        profile_name="frag-verify-smoke-abc12345",
        workspace_path=tmp_path / "verification-root" / "frag-verify-smoke-abc12345",
    )
    monkeypatch.setattr(
        smoke_verify.verification,
        "create_verification_artifacts",
        lambda **_kwargs: artifacts,
    )
    monkeypatch.setattr(
        smoke_verify.verification,
        "remove_workspace_if_present",
        lambda **_kwargs: None,
    )
    monkeypatch.setattr(
        smoke_verify.verification,
        "remove_profile_if_present",
        lambda **_kwargs: None,
    )
    monkeypatch.setattr(
        smoke_verify.verification,
        "stop_profile_container_if_present",
        lambda **_kwargs: None,
    )
    monkeypatch.setattr(smoke_verify.time, "perf_counter", lambda: 0.0)

    def fake_run(
        command: tuple[str, ...] | list[str], **kwargs: object
    ) -> subprocess.CompletedProcess[str]:
        del kwargs
        command_tuple = tuple(command)
        if command_tuple[1:3] == ("profile", "list"):
            return subprocess.CompletedProcess(
                args=command_tuple,
                returncode=0,
                stdout=f"{artifacts.profile_name}\n",
                stderr="",
            )
        if command_tuple[-1] == "whoami":
            return subprocess.CompletedProcess(
                args=command_tuple,
                returncode=0,
                stdout=stdout if command_name == "whoami" else "agent\n",
                stderr="",
            )
        if command_tuple[-1] == "pwd":
            return subprocess.CompletedProcess(
                args=command_tuple,
                returncode=0,
                stdout=stdout if command_name == "pwd" else "/workspace-root\n",
                stderr="",
            )
        return subprocess.CompletedProcess(
            args=command_tuple, returncode=0, stdout="", stderr=""
        )

    monkeypatch.setattr(smoke_verify.subprocess, "run", fake_run)

    with pytest.raises(RuntimeError, match=match):
        smoke_verify.main(
            [
                "--frag-bin",
                str(tmp_path / "frag"),
                "--workspace-root",
                str(tmp_path / "verification-root"),
            ]
        )


def test_smoke_verify_rejects_shared_asset_failure_without_read_only_evidence(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    smoke_verify = _load_smoke_verify_module()

    artifacts = verification.VerificationArtifacts(
        label="frag-verify-smoke-abc12345",
        profile_name="frag-verify-smoke-abc12345",
        workspace_path=tmp_path / "verification-root" / "frag-verify-smoke-abc12345",
    )
    monkeypatch.setattr(
        smoke_verify.verification,
        "create_verification_artifacts",
        lambda **_kwargs: artifacts,
    )
    monkeypatch.setattr(
        smoke_verify.verification,
        "remove_workspace_if_present",
        lambda **_kwargs: None,
    )
    monkeypatch.setattr(
        smoke_verify.verification,
        "remove_profile_if_present",
        lambda **_kwargs: None,
    )
    monkeypatch.setattr(
        smoke_verify.verification,
        "stop_profile_container_if_present",
        lambda **_kwargs: None,
    )
    monkeypatch.setattr(smoke_verify.time, "perf_counter", lambda: 0.0)

    def fake_run(
        command: tuple[str, ...] | list[str], **kwargs: object
    ) -> subprocess.CompletedProcess[str]:
        del kwargs
        command_tuple = tuple(command)
        if command_tuple[1:3] == ("profile", "list"):
            return subprocess.CompletedProcess(
                args=command_tuple,
                returncode=0,
                stdout=f"{artifacts.profile_name}\n",
                stderr="",
            )
        if command_tuple[-1] == "whoami":
            return subprocess.CompletedProcess(
                args=command_tuple,
                returncode=0,
                stdout="agent\n",
                stderr="",
            )
        if command_tuple[-1] == "pwd":
            return subprocess.CompletedProcess(
                args=command_tuple,
                returncode=0,
                stdout="/workspace-root\n",
                stderr="",
            )
        if (
            command_tuple[-1]
            == 'printf "workspace smoke\\n" > smoke-workspace-write.txt'
        ):
            (artifacts.workspace_path / "smoke-workspace-write.txt").write_text(
                "workspace smoke\n"
            )
            return subprocess.CompletedProcess(
                args=command_tuple, returncode=0, stdout="", stderr=""
            )
        if (
            command_tuple[-1] == 'test -f "$HOME/.config/opencode/opencode.json" && '
            'printf "blocked" >> "$HOME/.config/opencode/opencode.json"'
        ):
            return subprocess.CompletedProcess(
                args=command_tuple,
                returncode=1,
                stdout="",
                stderr="No space left on device",
            )
        return subprocess.CompletedProcess(
            args=command_tuple, returncode=0, stdout="", stderr=""
        )

    monkeypatch.setattr(smoke_verify.subprocess, "run", fake_run)

    with pytest.raises(
        RuntimeError, match="shared asset write failed for an unexpected reason"
    ):
        smoke_verify.main(
            [
                "--frag-bin",
                str(tmp_path / "frag"),
                "--workspace-root",
                str(tmp_path / "verification-root"),
            ]
        )


def test_smoke_verify_rejects_shared_asset_write_that_unexpectedly_succeeds(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    smoke_verify = _load_smoke_verify_module()

    artifacts = verification.VerificationArtifacts(
        label="frag-verify-smoke-abc12345",
        profile_name="frag-verify-smoke-abc12345",
        workspace_path=tmp_path / "verification-root" / "frag-verify-smoke-abc12345",
    )
    monkeypatch.setattr(
        smoke_verify.verification,
        "create_verification_artifacts",
        lambda **_kwargs: artifacts,
    )
    monkeypatch.setattr(
        smoke_verify.verification,
        "remove_workspace_if_present",
        lambda **_kwargs: None,
    )
    monkeypatch.setattr(
        smoke_verify.verification,
        "remove_profile_if_present",
        lambda **_kwargs: None,
    )
    monkeypatch.setattr(
        smoke_verify.verification,
        "stop_profile_container_if_present",
        lambda **_kwargs: None,
    )
    monkeypatch.setattr(smoke_verify.time, "perf_counter", lambda: 0.0)

    def fake_run(
        command: tuple[str, ...] | list[str], **kwargs: object
    ) -> subprocess.CompletedProcess[str]:
        command_tuple = tuple(command)
        if command_tuple[1:3] == ("profile", "list"):
            return subprocess.CompletedProcess(
                args=command_tuple,
                returncode=0,
                stdout=f"{artifacts.profile_name}\n",
                stderr="",
            )
        if command_tuple[-1] == "whoami":
            return subprocess.CompletedProcess(
                args=command_tuple, returncode=0, stdout="agent\n", stderr=""
            )
        if command_tuple[-1] == "pwd":
            return subprocess.CompletedProcess(
                args=command_tuple,
                returncode=0,
                stdout="/workspace-root\n",
                stderr="",
            )
        if (
            command_tuple[-1]
            == 'printf "workspace smoke\\n" > smoke-workspace-write.txt'
        ):
            (artifacts.workspace_path / "smoke-workspace-write.txt").write_text(
                "workspace smoke\n"
            )
        return subprocess.CompletedProcess(
            args=command_tuple, returncode=0, stdout="", stderr=""
        )

    monkeypatch.setattr(smoke_verify.subprocess, "run", fake_run)

    with pytest.raises(RuntimeError, match="shared asset write to fail"):
        smoke_verify.main(
            [
                "--frag-bin",
                str(tmp_path / "frag"),
                "--workspace-root",
                str(tmp_path / "verification-root"),
            ]
        )
