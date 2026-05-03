from __future__ import annotations

import subprocess

import pytest

from frag import docker_invoke, profiles
from frag.exceptions import DockerRuntimeError


def test_run_docker_command_raises_selected_missing_binary_error(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def raise_missing_binary(*_args: object, **_kwargs: object) -> object:
        raise FileNotFoundError("docker")

    monkeypatch.setattr(docker_invoke.subprocess, "run", raise_missing_binary)

    with pytest.raises(
        profiles.DockerBackendError, match="docker executable not found"
    ):
        docker_invoke.run_docker_command(
            ["docker", "ps"],
            capture_output=True,
            missing_binary_error=profiles.DockerBackendError,
        )


def test_run_docker_command_preserves_nonzero_results_when_requested(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def fake_run(
        command: list[str], **_kwargs: object
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.CompletedProcess(
            command, 23, stdout="", stderr="permission denied"
        )

    monkeypatch.setattr(docker_invoke.subprocess, "run", fake_run)

    result = docker_invoke.run_docker_command(
        ["docker", "stop", "frag-demo-profile"],
        capture_output=True,
        missing_binary_error=DockerRuntimeError,
    )

    assert result.returncode == 23
    assert result.stderr == "permission denied"


def test_require_success_raises_selected_error_with_stderr_detail() -> None:
    result = subprocess.CompletedProcess(
        ["docker", "stop", "frag-demo-profile"],
        1,
        stdout="",
        stderr="permission denied",
    )

    with pytest.raises(DockerRuntimeError, match="permission denied"):
        docker_invoke.require_success(result, error_type=DockerRuntimeError)


def test_require_success_falls_back_to_stdout_then_returncode() -> None:
    stdout_only = subprocess.CompletedProcess(
        ["docker", "ps"], 12, stdout="bad output", stderr=""
    )
    with pytest.raises(DockerRuntimeError, match="bad output"):
        docker_invoke.require_success(stdout_only, error_type=DockerRuntimeError)

    empty_output = subprocess.CompletedProcess(
        ["docker", "ps"], 27, stdout="", stderr=""
    )
    with pytest.raises(DockerRuntimeError, match="27"):
        docker_invoke.require_success(empty_output, error_type=DockerRuntimeError)
