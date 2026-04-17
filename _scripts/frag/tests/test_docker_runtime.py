from __future__ import annotations

import json
from pathlib import Path
import subprocess

import pytest

from frag import cli, docker_runtime, image_assets, profiles


DEMO_PROFILE = profiles.Profile(
    name="Demo Profile",
    image="python:3.14",
    workspace_root="/workspace/demo",
    volume_name="frag-profile-demo-profile",
)


class FakeImageAssets:
    def __init__(
        self,
        runtime_spec: image_assets.RuntimeSpec | None = None,
        loaded_image_ref: str = "loaded:image",
    ) -> None:
        self.runtime_spec = runtime_spec
        self.loaded_image_ref = loaded_image_ref
        self.load_calls: list[profiles.Profile] = []
        self.build_calls: list[tuple[profiles.Profile, Path]] = []

    def load_image(self, *, profile: profiles.Profile) -> str:
        self.load_calls.append(profile)
        return self.loaded_image_ref

    def build_runtime_spec(
        self, *, profile: profiles.Profile, workspace_root: Path
    ) -> image_assets.RuntimeSpec:
        self.build_calls.append((profile, workspace_root))
        if self.runtime_spec is not None:
            return self.runtime_spec
        return image_assets.RuntimeSpec(
            image_ref=self.loaded_image_ref,
            shared_mounts=(),
            start_command=("frag-bootstrap",),
        )


def test_container_name_for_profile_is_deterministic() -> None:
    assert (
        docker_runtime.container_name_for_profile("Demo Profile") == "frag-demo-profile"
    )


def test_bootstrap_token_for_profile_generates_fresh_tokens(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    generated = iter(["fresh-token-1", "fresh-token-2"])

    monkeypatch.setattr(
        docker_runtime.secrets,
        "token_urlsafe",
        lambda nbytes=32: next(generated),
    )

    assert docker_runtime.bootstrap_token_for_profile(DEMO_PROFILE) == "fresh-token-1"
    assert docker_runtime.bootstrap_token_for_profile(DEMO_PROFILE) == "fresh-token-2"


def test_current_process_user_option_formats_uid_and_gid(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(docker_runtime.os, "getuid", lambda: 1234)
    monkeypatch.setattr(docker_runtime.os, "getgid", lambda: 5678)

    assert docker_runtime._current_process_user_option() == "1234:5678"


def test_container_workdir_for_cwd_rejects_paths_outside_workspace_root(
    tmp_path: Path,
) -> None:
    workspace_root = tmp_path / "workspace"
    workspace_root.mkdir()
    outside = tmp_path / "outside"
    outside.mkdir()

    with pytest.raises(docker_runtime.WorkspacePathError):
        docker_runtime.container_workdir_for_cwd(
            profile=DEMO_PROFILE,
            cwd=outside,
            workspace_root=workspace_root,
        )


def test_container_workdir_for_cwd_maps_workspace_relative_path(tmp_path: Path) -> None:
    workspace_root = tmp_path / "workspace"
    nested = workspace_root / "nested" / "project"
    nested.mkdir(parents=True)

    assert (
        docker_runtime.container_workdir_for_cwd(
            profile=DEMO_PROFILE,
            cwd=nested,
            workspace_root=workspace_root,
        )
        == "/workspace-root/nested/project"
    )


def test_is_container_running_inspects_exact_named_container(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    commands: list[list[str]] = []

    inspect_payload = [
        {
            "State": {"Running": True},
            "Config": {
                "Labels": {
                    profiles.LABEL_PROFILE: DEMO_PROFILE.name,
                    profiles.LABEL_IMAGE: DEMO_PROFILE.image,
                    profiles.LABEL_WORKSPACE_ROOT: DEMO_PROFILE.workspace_root,
                    profiles.LABEL_SCHEMA_VERSION: profiles.SCHEMA_VERSION,
                }
            },
            "Mounts": [
                {
                    "Type": "bind",
                    "Source": DEMO_PROFILE.workspace_root,
                    "Destination": "/workspace-root",
                }
            ],
        }
    ]

    def fake_run(
        command: list[str], **_kwargs: object
    ) -> subprocess.CompletedProcess[str]:
        commands.append(command)
        return subprocess.CompletedProcess(
            command, 0, stdout=json.dumps(inspect_payload), stderr=""
        )

    monkeypatch.setattr(docker_runtime.subprocess, "run", fake_run)

    assert docker_runtime.is_container_running(DEMO_PROFILE) is True
    assert commands == [
        [
            "docker",
            "inspect",
            "--type",
            "container",
            "frag-demo-profile",
        ]
    ]


def test_is_container_running_rejects_named_container_with_mismatched_metadata(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    commands: list[list[str]] = []

    inspect_payload = [
        {
            "State": {"Running": True},
            "Config": {
                "Labels": {
                    profiles.LABEL_PROFILE: DEMO_PROFILE.name,
                    profiles.LABEL_IMAGE: "python:3.15",
                    profiles.LABEL_WORKSPACE_ROOT: DEMO_PROFILE.workspace_root,
                    profiles.LABEL_SCHEMA_VERSION: profiles.SCHEMA_VERSION,
                }
            },
            "Mounts": [
                {
                    "Type": "bind",
                    "Source": DEMO_PROFILE.workspace_root,
                    "Destination": "/workspace-root",
                }
            ],
        }
    ]

    def fake_run(
        command: list[str], **_kwargs: object
    ) -> subprocess.CompletedProcess[str]:
        commands.append(command)
        return subprocess.CompletedProcess(
            command, 0, stdout=json.dumps(inspect_payload), stderr=""
        )

    monkeypatch.setattr(docker_runtime.subprocess, "run", fake_run)

    assert docker_runtime.is_container_running(DEMO_PROFILE) is False
    assert commands == [
        ["docker", "inspect", "--type", "container", "frag-demo-profile"]
    ]


def test_start_profile_container_removes_stale_mismatched_named_container(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    monkeypatch.setattr(docker_runtime.os, "getuid", lambda: 1000)
    monkeypatch.setattr(docker_runtime.os, "getgid", lambda: 1000)
    workspace_root = tmp_path / "workspace"
    workspace_root.mkdir()
    runtime_spec = image_assets.RuntimeSpec(
        image_ref="loaded:image",
        shared_mounts=(),
        start_command=("frag-bootstrap",),
    )
    inspect_payload = [
        {
            "State": {"Running": True},
            "Config": {
                "Labels": {
                    profiles.LABEL_PROFILE: DEMO_PROFILE.name,
                    profiles.LABEL_IMAGE: "python:3.15",
                    profiles.LABEL_WORKSPACE_ROOT: DEMO_PROFILE.workspace_root,
                    profiles.LABEL_SCHEMA_VERSION: profiles.SCHEMA_VERSION,
                }
            },
            "Mounts": [
                {
                    "Type": "bind",
                    "Source": DEMO_PROFILE.workspace_root,
                    "Destination": "/workspace-root",
                }
            ],
        }
    ]
    calls: list[list[str]] = []

    def fake_run(
        command: list[str], **_kwargs: object
    ) -> subprocess.CompletedProcess[str]:
        calls.append(command)
        if command[1:3] == ["inspect", "--type"]:
            return subprocess.CompletedProcess(
                command, 0, stdout=json.dumps(inspect_payload), stderr=""
            )
        return subprocess.CompletedProcess(
            command, 0, stdout="container-id\n", stderr=""
        )

    monkeypatch.setattr(docker_runtime.subprocess, "run", fake_run)

    docker_runtime.start_profile_container(
        profile=DEMO_PROFILE,
        workspace_root=workspace_root,
        runtime_spec=runtime_spec,
        bootstrap_token="token-123",
    )

    assert calls[:2] == [
        ["docker", "inspect", "--type", "container", "frag-demo-profile"],
        ["docker", "rm", "--force", "frag-demo-profile"],
    ]
    assert calls[2][0:5] == ["docker", "run", "--detach", "--rm", "--name"]
    assert calls[2][5] == "frag-demo-profile"


def test_start_profile_container_uses_runtime_spec_mounts_and_command(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    monkeypatch.setattr(docker_runtime.os, "getuid", lambda: 1000)
    monkeypatch.setattr(docker_runtime.os, "getgid", lambda: 1000)
    workspace_root = tmp_path / "workspace"
    workspace_root.mkdir()
    shared_root = tmp_path / "shared-home"
    for relative in [
        ".agents/skills",
        ".config/agents/skills",
        ".code/agents",
        ".code/skills",
        ".code/AGENTS.md",
        ".omp/agent/agents",
        ".omp/agent/skills",
        ".omp/agent/SYSTEM.md",
        ".config/opencode/skill",
        ".config/opencode/opencode.json",
        ".config/opencode/superpowers",
        ".config/opencode/plugins/superpowers.js",
    ]:
        target = shared_root / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        if relative.endswith((".md", ".js", ".json")):
            target.write_text("x")
        else:
            target.mkdir(exist_ok=True)

    helpers_dir = tmp_path / "libexec" / "frag"
    helpers_dir.mkdir(parents=True)
    catalog_path = tmp_path / "share" / "frag" / "catalog.json"
    catalog_path.parent.mkdir(parents=True, exist_ok=True)
    catalog_path.write_text(
        json.dumps(
            {
                "images": {
                    DEMO_PROFILE.image: {
                        "image_ref": DEMO_PROFILE.image,
                        "loader": "load-image-main",
                    }
                }
            }
        )
    )
    runtime_spec = image_assets.DirectProfileImageAssets(
        package_assets=image_assets.InstalledPackageAssets(
            shared_assets_root=shared_root,
            catalog_path=catalog_path,
            helpers_dir=helpers_dir,
        )
    ).build_runtime_spec(profile=DEMO_PROFILE, workspace_root=workspace_root)
    captured: list[list[str]] = []

    def fake_run(
        command: list[str], **_kwargs: object
    ) -> subprocess.CompletedProcess[str]:
        captured.append(command)
        if command[1:3] == ["inspect", "--type"]:
            return subprocess.CompletedProcess(
                command, 1, stdout="", stderr="Error: No such object: frag-demo-profile"
            )
        return subprocess.CompletedProcess(
            command, 0, stdout="container-id\n", stderr=""
        )

    monkeypatch.setattr(docker_runtime.subprocess, "run", fake_run)

    docker_runtime.start_profile_container(
        profile=DEMO_PROFILE,
        workspace_root=workspace_root,
        runtime_spec=runtime_spec,
        bootstrap_token="token-123",
    )

    assert captured == [
        ["docker", "inspect", "--type", "container", "frag-demo-profile"],
        [
            "docker",
            "run",
            "--detach",
            "--rm",
            "--name",
            "frag-demo-profile",
            "--label",
            f"{profiles.LABEL_PROFILE}=Demo Profile",
            "--label",
            f"{profiles.LABEL_IMAGE}=python:3.14",
            "--label",
            f"{profiles.LABEL_WORKSPACE_ROOT}={workspace_root}",
            "--label",
            f"{profiles.LABEL_SCHEMA_VERSION}={profiles.SCHEMA_VERSION}",
            "--env",
            "FRAG_TARGET_UID=1000",
            "--env",
            "FRAG_TARGET_GID=1000",
            "--env",
            "FRAG_BOOTSTRAP_TOKEN=token-123",
            "--read-only",
            "--tmpfs",
            "/home/agent",
            "--tmpfs",
            "/tmp",
            "--tmpfs",
            "/run",
            "--mount",
            "type=volume,src=frag-profile-demo-profile,dst=/state/profile,volume-nocopy",
            "--mount",
            f"type=bind,src={workspace_root},dst=/workspace-root",
            "--mount",
            f"type=bind,src={shared_root / '.agents/skills'},dst=/state/shared/agents/skills,readonly",
            "--mount",
            f"type=bind,src={shared_root / '.config/agents/skills'},dst=/state/shared/config/agents/skills,readonly",
            "--mount",
            f"type=bind,src={shared_root / '.code/agents'},dst=/state/shared/code/agents,readonly",
            "--mount",
            f"type=bind,src={shared_root / '.code/skills'},dst=/state/shared/code/skills,readonly",
            "--mount",
            f"type=bind,src={shared_root / '.code/AGENTS.md'},dst=/state/shared/code/AGENTS.md,readonly",
            "--mount",
            f"type=bind,src={shared_root / '.omp/agent/agents'},dst=/state/shared/omp/agent/agents,readonly",
            "--mount",
            f"type=bind,src={shared_root / '.omp/agent/skills'},dst=/state/shared/omp/agent/skills,readonly",
            "--mount",
            f"type=bind,src={shared_root / '.omp/agent/SYSTEM.md'},dst=/state/shared/omp/agent/SYSTEM.md,readonly",
            "--mount",
            f"type=bind,src={shared_root / '.config/opencode/skill'},dst=/state/shared/opencode/skill,readonly",
            "--mount",
            f"type=bind,src={shared_root / '.config/opencode/opencode.json'},dst=/state/shared/opencode/opencode.json,readonly",
            "--mount",
            f"type=bind,src={shared_root / '.config/opencode/superpowers'},dst=/state/shared/opencode/superpowers,readonly",
            "--mount",
            f"type=bind,src={shared_root / '.config/opencode/plugins/superpowers.js'},dst=/state/shared/opencode/plugins/superpowers.js,readonly",
            "python:3.14",
            "frag-bootstrap",
            "--profile-name",
            "Demo Profile",
            "--profile-image",
            "python:3.14",
            "--workspace-root",
            str(workspace_root),
            "--keepalive",
            "tail",
            "-f",
            "/dev/null",
        ],
    ]


def test_start_profile_container_uses_runtime_spec_start_command(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    workspace_root = tmp_path / "workspace"
    workspace_root.mkdir()
    runtime_spec = image_assets.RuntimeSpec(
        image_ref="loaded:image",
        shared_mounts=(),
        start_command=("custom-bootstrap", "--flag", "value"),
    )
    captured: list[list[str]] = []

    def fake_run(
        command: list[str], **_kwargs: object
    ) -> subprocess.CompletedProcess[str]:
        captured.append(command)
        if command[1:3] == ["inspect", "--type"]:
            return subprocess.CompletedProcess(
                command, 1, stdout="", stderr="Error: No such object: frag-demo-profile"
            )
        return subprocess.CompletedProcess(
            command, 0, stdout="container-id\n", stderr=""
        )

    monkeypatch.setattr(docker_runtime.subprocess, "run", fake_run)

    docker_runtime.start_profile_container(
        profile=DEMO_PROFILE,
        workspace_root=workspace_root,
        runtime_spec=runtime_spec,
        bootstrap_token="token-123",
    )

    assert captured[0] == [
        "docker",
        "inspect",
        "--type",
        "container",
        "frag-demo-profile",
    ]
    assert captured[1][-4:] == ["loaded:image", "custom-bootstrap", "--flag", "value"]


def test_exec_in_profile_container_uses_tty_when_stdio_is_interactive(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(docker_runtime.os, "getuid", lambda: 1000)
    monkeypatch.setattr(docker_runtime.os, "getgid", lambda: 1000)
    captured: list[list[str]] = []

    def fake_run(
        command: list[str], **_kwargs: object
    ) -> subprocess.CompletedProcess[str]:
        captured.append(command)
        return subprocess.CompletedProcess(command, 23, stdout="", stderr="")

    monkeypatch.setattr(docker_runtime.subprocess, "run", fake_run)
    monkeypatch.setattr(docker_runtime.sys.stdin, "isatty", lambda: True)
    monkeypatch.setattr(docker_runtime.sys.stdout, "isatty", lambda: True)

    result = docker_runtime.exec_in_profile_container(
        profile=DEMO_PROFILE,
        workdir="/workspace-root/nested",
        command=("bash", "-lc", "pwd"),
    )

    assert result == 23
    assert captured == [
        [
            "docker",
            "exec",
            "-it",
            "--user",
            "1000:1000",
            "-w",
            "/workspace-root/nested",
            "frag-demo-profile",
            "bash",
            "-lc",
            "pwd",
        ]
    ]


def test_exec_in_profile_container_omits_tty_when_stdio_is_not_interactive(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(docker_runtime.os, "getuid", lambda: 1000)
    monkeypatch.setattr(docker_runtime.os, "getgid", lambda: 1000)
    captured: list[list[str]] = []

    def fake_run(
        command: list[str], **_kwargs: object
    ) -> subprocess.CompletedProcess[str]:
        captured.append(command)
        return subprocess.CompletedProcess(command, 23, stdout="", stderr="")

    monkeypatch.setattr(docker_runtime.subprocess, "run", fake_run)
    monkeypatch.setattr(docker_runtime.sys.stdin, "isatty", lambda: False)
    monkeypatch.setattr(docker_runtime.sys.stdout, "isatty", lambda: False)

    result = docker_runtime.exec_in_profile_container(
        profile=DEMO_PROFILE,
        workdir="/workspace-root/nested",
        command=("bash", "-lc", "pwd"),
    )

    assert result == 23
    assert captured == [
        [
            "docker",
            "exec",
            "-i",
            "--user",
            "1000:1000",
            "-w",
            "/workspace-root/nested",
            "frag-demo-profile",
            "bash",
            "-lc",
            "pwd",
        ]
    ]


def test_wait_for_profile_bootstrap_polls_until_token_matches(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(docker_runtime.os, "getuid", lambda: 1000)
    monkeypatch.setattr(docker_runtime.os, "getgid", lambda: 1000)
    captured: list[list[str]] = []
    return_codes = iter([1, 0])
    slept: list[float] = []
    monotonic_values = iter([0.0, 0.0, 0.25])

    def fake_run(
        command: list[str], **_kwargs: object
    ) -> subprocess.CompletedProcess[str]:
        captured.append(command)
        return subprocess.CompletedProcess(
            command,
            next(return_codes),
            stdout="",
            stderr="",
        )

    monkeypatch.setattr(docker_runtime.subprocess, "run", fake_run)
    monkeypatch.setattr(docker_runtime.time, "sleep", slept.append)
    monkeypatch.setattr(
        docker_runtime.time, "monotonic", lambda: next(monotonic_values)
    )

    docker_runtime.wait_for_profile_bootstrap(
        profile=DEMO_PROFILE,
        bootstrap_token="token-123",
        timeout_seconds=1.0,
        poll_interval_seconds=0.25,
    )

    assert slept == [0.25]
    assert captured == [
        [
            "docker",
            "exec",
            "--user",
            "1000:1000",
            "-e",
            "FRAG_BOOTSTRAP_TOKEN=token-123",
            "frag-demo-profile",
            "sh",
            "-lc",
            'test -f /state/profile/meta/bootstrap-token && test "$(cat /state/profile/meta/bootstrap-token)" = "$FRAG_BOOTSTRAP_TOKEN"',
        ],
        [
            "docker",
            "exec",
            "--user",
            "1000:1000",
            "-e",
            "FRAG_BOOTSTRAP_TOKEN=token-123",
            "frag-demo-profile",
            "sh",
            "-lc",
            'test -f /state/profile/meta/bootstrap-token && test "$(cat /state/profile/meta/bootstrap-token)" = "$FRAG_BOOTSTRAP_TOKEN"',
        ],
    ]


def test_wait_for_profile_bootstrap_times_out_when_token_never_matches(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    attempts: list[list[str]] = []
    slept: list[float] = []
    monotonic_values = iter([0.0, 0.0, 0.25, 0.5])

    def fake_run(
        command: list[str], **_kwargs: object
    ) -> subprocess.CompletedProcess[str]:
        attempts.append(command)
        return subprocess.CompletedProcess(command, 1, stdout="", stderr="")

    monkeypatch.setattr(docker_runtime.subprocess, "run", fake_run)
    monkeypatch.setattr(docker_runtime.time, "sleep", slept.append)
    monkeypatch.setattr(
        docker_runtime.time, "monotonic", lambda: next(monotonic_values)
    )

    with pytest.raises(
        docker_runtime.DockerRuntimeError,
        match="timed out waiting for bootstrap readiness",
    ):
        docker_runtime.wait_for_profile_bootstrap(
            profile=DEMO_PROFILE,
            bootstrap_token="fresh-token",
            timeout_seconds=0.25,
            poll_interval_seconds=0.25,
        )

    assert slept == [0.25]
    assert len(attempts) == 2


def test_cli_enter_loads_image_starts_container_waits_then_execs(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    workspace_root = tmp_path / "workspace"
    workspace_root.mkdir()
    working_dir = workspace_root / "nested"
    working_dir.mkdir()
    runtime_spec = image_assets.RuntimeSpec(
        image_ref="loaded:image",
        shared_mounts=(),
        start_command=("frag-bootstrap",),
    )
    assets_provider = FakeImageAssets(runtime_spec=runtime_spec)
    calls: list[tuple[str, object]] = []
    runtime_profile = profiles.Profile(
        name="Demo Profile",
        image="python:3.14",
        workspace_root=str(workspace_root),
        volume_name="frag-profile-demo-profile",
    )

    monkeypatch.setattr(cli, "build_docker_backend", lambda: object())
    monkeypatch.setattr(
        cli.profiles,
        "get_profile",
        lambda _backend, name: runtime_profile if name == "Demo Profile" else None,
    )
    monkeypatch.setattr(
        cli.docker_runtime, "is_container_running", lambda profile: False
    )
    monkeypatch.setattr(
        cli,
        "build_image_assets",
        lambda: assets_provider,
        raising=False,
    )
    monkeypatch.setattr(cli, "DEFAULT_SHELL", ("bash",), raising=False)
    monkeypatch.setattr(
        cli.docker_runtime,
        "bootstrap_token_for_profile",
        lambda profile: "fresh-token-123",
    )
    monkeypatch.setattr(
        cli.docker_runtime,
        "start_profile_container",
        lambda *, profile, workspace_root, runtime_spec, bootstrap_token: calls.append(
            ("start", profile.name, workspace_root, runtime_spec, bootstrap_token)
        ),
    )
    monkeypatch.setattr(
        cli.docker_runtime,
        "wait_for_profile_bootstrap",
        lambda *, profile, bootstrap_token: calls.append(
            ("wait", profile.name, bootstrap_token)
        ),
    )
    monkeypatch.setattr(
        cli.docker_runtime,
        "container_workdir_for_cwd",
        lambda *, profile, cwd, workspace_root: (
            calls.append(("map", cwd)) or "/workspace-root/nested"
        ),
    )
    monkeypatch.setattr(
        cli.docker_runtime,
        "exec_in_profile_container",
        lambda *, profile, workdir, command: (
            calls.append(("exec", profile.name, workdir, tuple(command))) or 0
        ),
    )
    monkeypatch.chdir(working_dir)

    assert cli.handle_enter(profile="Demo Profile", command=()) == 0
    assert assets_provider.load_calls == [runtime_profile]
    assert assets_provider.build_calls == [(runtime_profile, workspace_root)]
    assert calls == [
        ("map", working_dir),
        ("start", "Demo Profile", workspace_root, runtime_spec, "fresh-token-123"),
        ("wait", "Demo Profile", "fresh-token-123"),
        ("exec", "Demo Profile", "/workspace-root/nested", ("bash",)),
    ]


def test_cli_enter_refuses_pwd_outside_workspace_root(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    workspace_root = tmp_path / "workspace"
    workspace_root.mkdir()
    outside = tmp_path / "outside"
    outside.mkdir()

    monkeypatch.setattr(cli, "build_docker_backend", lambda: object())
    monkeypatch.setattr(
        cli.profiles, "get_profile", lambda _backend, _name: DEMO_PROFILE
    )
    monkeypatch.setattr(
        cli.docker_runtime,
        "container_workdir_for_cwd",
        lambda **_kwargs: (_ for _ in ()).throw(
            docker_runtime.WorkspacePathError("bad cwd")
        ),
    )
    monkeypatch.chdir(outside)

    assert cli.handle_enter(profile="Demo Profile", command=("bash",)) == 1


def test_cli_profile_stop_stops_named_container(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(cli, "build_docker_backend", lambda: object())
    monkeypatch.setattr(
        cli.profiles, "get_profile", lambda _backend, _name: DEMO_PROFILE
    )
    stopped: list[str] = []
    monkeypatch.setattr(
        cli.docker_runtime,
        "stop_profile_container",
        lambda profile: stopped.append(profile.name),
    )

    assert cli.main(["profile", "stop", "Demo Profile"]) == 0
    assert stopped == ["Demo Profile"]
