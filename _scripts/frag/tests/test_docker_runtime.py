from __future__ import annotations

import json
from pathlib import Path
import subprocess

import pytest

from frag import cli, docker_runtime, image_assets, profiles, runtime_contract


DEMO_PROFILE = profiles.Profile(
    name="Demo Profile",
    image="python:3.14",
    workspace_root="/workspace/demo",
    volume_name="frag-profile-demo-profile",
)


BOOTSTRAP_WAIT_NOT_READY_EXIT_CODE = 42
BOOTSTRAP_WAIT_NOT_READY_SENTINEL = "frag-bootstrap-not-ready"
BOOTSTRAP_WAIT_STATUS_AVAILABLE_EXIT_CODE = 43


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
            shared_assets_identity="shared-assets-123",
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


def test_is_container_running_treats_no_such_container_as_not_running(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    commands: list[list[str]] = []

    def fake_run(
        command: list[str], **_kwargs: object
    ) -> subprocess.CompletedProcess[str]:
        commands.append(command)
        return subprocess.CompletedProcess(
            command,
            1,
            stdout="",
            stderr="Error response from daemon: No such container: frag-demo-profile",
        )

    monkeypatch.setattr(docker_runtime.subprocess, "run", fake_run)

    assert docker_runtime.is_container_running(DEMO_PROFILE) is False
    assert commands == [
        ["docker", "inspect", "--type", "container", "frag-demo-profile"]
    ]


def test_is_container_running_rejects_named_container_with_mismatched_runtime_metadata(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    workspace_root = tmp_path / "workspace"
    workspace_root.mkdir()

    commands: list[list[str]] = []

    inspect_payload = [
        {
            "State": {"Running": True},
            "Config": {
                "Labels": {
                    profiles.LABEL_PROFILE: DEMO_PROFILE.name,
                    profiles.LABEL_IMAGE: DEMO_PROFILE.image,
                    profiles.LABEL_WORKSPACE_ROOT: str(workspace_root),
                    profiles.LABEL_SCHEMA_VERSION: profiles.SCHEMA_VERSION,
                    profiles.LABEL_TARGET_UID: "1000",
                    profiles.LABEL_TARGET_GID: "1000",
                    profiles.LABEL_RUNTIME_IMAGE_REF: "loaded:other",
                    profiles.LABEL_SHARED_ASSETS_IDENTITY: "shared-assets-123",
                }
            },
            "Mounts": [
                {
                    "Type": "bind",
                    "Source": str(workspace_root),
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

    runtime_profile = profiles.Profile(
        name=DEMO_PROFILE.name,
        image=DEMO_PROFILE.image,
        workspace_root=str(workspace_root),
        volume_name=DEMO_PROFILE.volume_name,
    )

    assert (
        docker_runtime.is_container_running(
            runtime_profile,
            runtime_metadata=profiles.RuntimeProfileMetadata(
                image_ref="loaded:image",
                shared_assets_identity="shared-assets-123",
                target_uid="1000",
                target_gid="1000",
            ),
        )
        is False
    )
    assert commands == [
        ["docker", "inspect", "--type", "container", "frag-demo-profile"]
    ]


def test_start_profile_container_removes_matching_stopped_named_container(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    monkeypatch.setattr(docker_runtime.os, "getuid", lambda: 1000)
    monkeypatch.setattr(docker_runtime.os, "getgid", lambda: 1000)
    workspace_root = tmp_path / "workspace"
    workspace_root.mkdir()
    inspect_payload = [
        {
            "State": {"Running": False},
            "Config": {
                "Labels": {
                    profiles.LABEL_PROFILE: DEMO_PROFILE.name,
                    profiles.LABEL_IMAGE: DEMO_PROFILE.image,
                    profiles.LABEL_WORKSPACE_ROOT: str(workspace_root),
                    profiles.LABEL_SCHEMA_VERSION: profiles.SCHEMA_VERSION,
                    profiles.LABEL_RUNTIME_IMAGE_REF: "loaded:image",
                    profiles.LABEL_SHARED_ASSETS_IDENTITY: "shared-assets-123",
                    profiles.LABEL_TARGET_UID: "1000",
                    profiles.LABEL_TARGET_GID: "1000",
                    profiles.LABEL_TARGET_SUPPLEMENTARY_GIDS: "",
                }
            },
            "Mounts": [
                {
                    "Type": "bind",
                    "Source": str(workspace_root),
                    "Destination": "/workspace-root",
                }
            ],
        }
    ]
    runtime_spec = image_assets.RuntimeSpec(
        image_ref="loaded:image",
        shared_assets_identity="shared-assets-123",
        shared_mounts=(),
        start_command=("frag-bootstrap",),
    )
    calls: list[list[str]] = []

    def fake_run(
        command: list[str], **_kwargs: object
    ) -> subprocess.CompletedProcess[str]:
        calls.append(command)
        if command[1:3] == ["inspect", "--type"]:
            return subprocess.CompletedProcess(
                command, 0, stdout=json.dumps(inspect_payload), stderr=""
            )
        if (
            command[1:2] == ["run"]
            and ["docker", "rm", "--force", "frag-demo-profile"] not in calls
        ):
            return subprocess.CompletedProcess(
                command,
                125,
                stdout="",
                stderr='docker: Error response from daemon: Conflict. The container name "/frag-demo-profile" is already in use.',
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


def test_start_profile_container_reuses_matching_container_created_during_run_race(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    monkeypatch.setattr(docker_runtime.os, "getuid", lambda: 1000)
    monkeypatch.setattr(docker_runtime.os, "getgid", lambda: 1000)
    monkeypatch.setattr(docker_runtime.os, "getgroups", lambda: [])
    workspace_root = tmp_path / "workspace"
    workspace_root.mkdir()
    runtime_spec = image_assets.RuntimeSpec(
        image_ref="loaded:image",
        shared_assets_identity="shared-assets-123",
        shared_mounts=(),
        start_command=("frag-bootstrap",),
    )
    matching_running_payload = [
        {
            "State": {"Running": True},
            "Config": {
                "Labels": {
                    profiles.LABEL_PROFILE: DEMO_PROFILE.name,
                    profiles.LABEL_IMAGE: DEMO_PROFILE.image,
                    profiles.LABEL_WORKSPACE_ROOT: DEMO_PROFILE.workspace_root,
                    profiles.LABEL_SCHEMA_VERSION: profiles.SCHEMA_VERSION,
                    profiles.LABEL_RUNTIME_IMAGE_REF: "loaded:image",
                    profiles.LABEL_SHARED_ASSETS_IDENTITY: "shared-assets-123",
                    profiles.LABEL_TARGET_UID: "1000",
                    profiles.LABEL_TARGET_GID: "1000",
                    profiles.LABEL_TARGET_SUPPLEMENTARY_GIDS: "",
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
    inspect_calls = 0

    def fake_run(
        command: list[str], **_kwargs: object
    ) -> subprocess.CompletedProcess[str]:
        nonlocal inspect_calls
        calls.append(command)
        if command[1:3] == ["inspect", "--type"]:
            inspect_calls += 1
            if inspect_calls == 1:
                return subprocess.CompletedProcess(
                    command,
                    1,
                    stdout="",
                    stderr="Error: No such object: frag-demo-profile",
                )
            return subprocess.CompletedProcess(
                command, 0, stdout=json.dumps(matching_running_payload), stderr=""
            )
        if command[1:2] == ["run"]:
            return subprocess.CompletedProcess(
                command,
                125,
                stdout="",
                stderr='docker: Error response from daemon: Conflict. The container name "/frag-demo-profile" is already in use.',
            )
        pytest.fail(f"unexpected docker call: {command}")

    monkeypatch.setattr(docker_runtime.subprocess, "run", fake_run)

    docker_runtime.start_profile_container(
        profile=DEMO_PROFILE,
        workspace_root=workspace_root,
        runtime_spec=runtime_spec,
        bootstrap_token="token-123",
    )

    assert calls == [
        ["docker", "inspect", "--type", "container", "frag-demo-profile"],
        calls[1],
        ["docker", "inspect", "--type", "container", "frag-demo-profile"],
    ]
    assert calls[1][0:5] == ["docker", "run", "--detach", "--rm", "--name"]
    assert calls[1][5] == "frag-demo-profile"
    assert ["docker", "rm", "--force", "frag-demo-profile"] not in calls


def test_start_profile_container_recreates_schema_2_container_when_runtime_metadata_drifts(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    monkeypatch.setattr(docker_runtime.os, "getuid", lambda: 1000)
    monkeypatch.setattr(docker_runtime.os, "getgid", lambda: 1000)
    workspace_root = tmp_path / "workspace"
    workspace_root.mkdir()
    inspect_payload = [
        {
            "State": {"Running": False},
            "Config": {
                "Labels": {
                    profiles.LABEL_PROFILE: DEMO_PROFILE.name,
                    profiles.LABEL_IMAGE: DEMO_PROFILE.image,
                    profiles.LABEL_WORKSPACE_ROOT: str(workspace_root),
                    profiles.LABEL_SCHEMA_VERSION: profiles.SCHEMA_VERSION,
                    profiles.LABEL_RUNTIME_IMAGE_REF: "stale:image",
                    profiles.LABEL_SHARED_ASSETS_IDENTITY: "shared-assets-123",
                    profiles.LABEL_TARGET_UID: "1000",
                    profiles.LABEL_TARGET_GID: "1000",
                    profiles.LABEL_TARGET_SUPPLEMENTARY_GIDS: "",
                }
            },
            "Mounts": [
                {
                    "Type": "bind",
                    "Source": str(workspace_root),
                    "Destination": "/workspace-root",
                }
            ],
        }
    ]
    runtime_spec = image_assets.RuntimeSpec(
        image_ref="loaded:image",
        shared_assets_identity="shared-assets-123",
        shared_mounts=(),
        start_command=("frag-bootstrap",),
    )
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


def test_start_profile_container_refuses_legacy_schema_named_container(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    monkeypatch.setattr(docker_runtime.os, "getuid", lambda: 1000)
    monkeypatch.setattr(docker_runtime.os, "getgid", lambda: 1000)
    workspace_root = tmp_path / "workspace"
    workspace_root.mkdir()
    inspect_payload = [
        {
            "State": {"Running": False},
            "Config": {
                "Labels": {
                    profiles.LABEL_PROFILE: DEMO_PROFILE.name,
                    profiles.LABEL_IMAGE: DEMO_PROFILE.image,
                    profiles.LABEL_WORKSPACE_ROOT: str(workspace_root),
                    profiles.LABEL_SCHEMA_VERSION: "1",
                }
            },
            "Mounts": [
                {
                    "Type": "bind",
                    "Source": str(workspace_root),
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
        pytest.fail(f"unexpected docker call: {command}")

    monkeypatch.setattr(docker_runtime.subprocess, "run", fake_run)

    with pytest.raises(
        docker_runtime.DockerRuntimeError,
        match="legacy schema 1 profile container",
    ):
        docker_runtime.start_profile_container(
            profile=DEMO_PROFILE,
            workspace_root=workspace_root,
            runtime_spec=image_assets.RuntimeSpec(
                image_ref="loaded:image",
                shared_assets_identity="shared-assets-123",
                shared_mounts=(),
                start_command=("frag-bootstrap",),
            ),
            bootstrap_token="token-123",
        )

    assert calls == [["docker", "inspect", "--type", "container", "frag-demo-profile"]]


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
        shared_assets_identity="shared-assets-123",
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
    monkeypatch.setattr(
        docker_runtime.os, "getgroups", lambda: [1000, 2001, 2002, 2001]
    )
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
                        "shared_assets_identity": "shared-assets-123",
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
            "--label",
            f"{profiles.LABEL_RUNTIME_IMAGE_REF}={runtime_spec.image_ref}",
            "--label",
            f"{profiles.LABEL_SHARED_ASSETS_IDENTITY}={runtime_spec.shared_assets_identity}",
            "--label",
            f"{profiles.LABEL_TARGET_UID}=1000",
            "--label",
            f"{profiles.LABEL_TARGET_GID}=1000",
            "--label",
            f"{profiles.LABEL_TARGET_SUPPLEMENTARY_GIDS}=2001,2002",
            "--workdir",
            "/",
            "--env",
            "FRAG_TARGET_UID=1000",
            "--env",
            "FRAG_TARGET_GID=1000",
            "--env",
            "FRAG_TARGET_SUPPLEMENTARY_GIDS=2001,2002",
            "--env",
            "FRAG_PROFILE_NAME=Demo Profile",
            "--env",
            "FRAG_BOOTSTRAP_TOKEN=token-123",
            "--read-only",
            "--tmpfs",
            "/tmp",
            "--tmpfs",
            "/run:exec",
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
            "--image-ref",
            runtime_spec.image_ref,
            "--shared-assets-identity",
            runtime_spec.shared_assets_identity,
            "--keepalive",
            "tail",
            "-f",
            "/dev/null",
        ],
    ]
    run_command = captured[1]
    assert "/home/agent" not in run_command


def test_start_profile_container_uses_runtime_spec_start_command(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    workspace_root = tmp_path / "workspace"
    workspace_root.mkdir()
    runtime_spec = image_assets.RuntimeSpec(
        image_ref="loaded:image",
        shared_assets_identity="shared-assets-123",
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
            "0:0",
            "-w",
            "/workspace-root/nested",
            "frag-demo-profile",
            docker_runtime._IDENTITY_OVERLAY_EXEC_PATH,
            "bash",
            "-lc",
            "pwd",
        ]
    ]


def test_exec_in_profile_container_omits_tty_when_stdio_is_not_interactive(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
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
            "0:0",
            "-w",
            "/workspace-root/nested",
            "frag-demo-profile",
            docker_runtime._IDENTITY_OVERLAY_EXEC_PATH,
            "bash",
            "-lc",
            "pwd",
        ]
    ]


def test_build_bootstrap_wait_command_executes_shell_directly_as_root() -> None:
    command = docker_runtime._build_bootstrap_wait_command(
        profile=DEMO_PROFILE,
        bootstrap_token="token-123",
    )

    assert command[:7] == [
        "docker",
        "exec",
        "--user",
        "0:0",
        "-e",
        f"{runtime_contract.BOOTSTRAP_TOKEN_ENV}=token-123",
        docker_runtime.container_name_for_profile(DEMO_PROFILE.name),
    ]
    assert command[7:9] == ["sh", "-lc"]
    assert docker_runtime._IDENTITY_OVERLAY_EXEC_PATH not in command


def test_wait_for_profile_bootstrap_polls_until_token_matches(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    captured: list[list[str]] = []
    return_codes = iter([BOOTSTRAP_WAIT_NOT_READY_EXIT_CODE, 0])
    slept: list[float] = []
    monotonic_values = iter([0.0, 0.0, 0.25])

    def fake_run(
        command: list[str], **_kwargs: object
    ) -> subprocess.CompletedProcess[str]:
        captured.append(command)
        if command[:2] == ["docker", "exec"]:
            return subprocess.CompletedProcess(
                command,
                next(return_codes),
                stdout=BOOTSTRAP_WAIT_NOT_READY_SENTINEL,
                stderr="",
            )
        return subprocess.CompletedProcess(command, 1, stdout="", stderr="")

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

    wait_attempts = [
        command for command in captured if command[:2] == ["docker", "exec"]
    ]
    assert slept == [0.25]
    assert len(wait_attempts) == 2
    assert all(
        runtime_contract.BOOTSTRAP_STATUS_CONTAINER_PATH in command[-1]
        for command in wait_attempts
    )
    assert all(
        docker_runtime._IDENTITY_OVERLAY_EXEC_PATH not in command
        for command in wait_attempts
    )


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
        if command[:2] == ["docker", "exec"]:
            return subprocess.CompletedProcess(
                command,
                BOOTSTRAP_WAIT_NOT_READY_EXIT_CODE,
                stdout=BOOTSTRAP_WAIT_NOT_READY_SENTINEL,
                stderr="",
            )
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

    wait_attempts = [
        command for command in attempts if command[:2] == ["docker", "exec"]
    ]
    retry_probe_attempts = [command for command in wait_attempts if "-e" in command]
    timeout_status_attempts = [
        command for command in wait_attempts if "-e" not in command
    ]
    assert slept == [0.25]
    assert len(retry_probe_attempts) == 2
    assert len(timeout_status_attempts) == 1


def test_wait_for_profile_bootstrap_prefers_container_logs_before_generic_timeout(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    attempts: list[list[str]] = []
    slept: list[float] = []
    monotonic_values = iter([0.0, 0.0, 0.25, 0.5])

    def fake_run(
        command: list[str], **_kwargs: object
    ) -> subprocess.CompletedProcess[str]:
        attempts.append(command)
        if command[:2] == ["docker", "exec"]:
            return subprocess.CompletedProcess(
                command,
                BOOTSTRAP_WAIT_NOT_READY_EXIT_CODE,
                stdout=BOOTSTRAP_WAIT_NOT_READY_SENTINEL,
                stderr="",
            )
        if command[1:2] == ["logs"]:
            return subprocess.CompletedProcess(
                command,
                0,
                stdout="bootstrap crashed\ntraceback line\n",
                stderr="",
            )
        return subprocess.CompletedProcess(command, 1, stdout="", stderr="")

    monkeypatch.setattr(docker_runtime.subprocess, "run", fake_run)
    monkeypatch.setattr(docker_runtime.time, "sleep", slept.append)
    monkeypatch.setattr(
        docker_runtime.time, "monotonic", lambda: next(monotonic_values)
    )

    with pytest.raises(
        docker_runtime.DockerRuntimeError,
        match="bootstrap crashed\\ntraceback line",
    ):
        docker_runtime.wait_for_profile_bootstrap(
            profile=DEMO_PROFILE,
            bootstrap_token="fresh-token",
            timeout_seconds=0.25,
            poll_interval_seconds=0.25,
        )

    assert slept == [0.25]
    assert [
        "docker",
        "logs",
        docker_runtime.container_name_for_profile(DEMO_PROFILE.name),
    ] in attempts


def test_bootstrap_wait_result_is_not_retryable_for_missing_identity_wrapper() -> None:
    result = subprocess.CompletedProcess(
        ["docker", "exec"],
        127,
        stdout="",
        stderr=f"stat {docker_runtime._IDENTITY_OVERLAY_EXEC_PATH}: no such file or directory",
    )

    assert docker_runtime._bootstrap_wait_result_is_retryable(result) is False


def test_wait_for_profile_bootstrap_reports_current_token_failure_status(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    attempts: list[list[str]] = []

    def fake_run(
        command: list[str], **_kwargs: object
    ) -> subprocess.CompletedProcess[str]:
        attempts.append(command)
        return subprocess.CompletedProcess(
            command,
            BOOTSTRAP_WAIT_STATUS_AVAILABLE_EXIT_CODE,
            stdout=json.dumps(
                {
                    "status": "failed",
                    "bootstrap_token": "token-123",
                    "phase": "identity",
                    "message": "overlay activation failed",
                }
            ),
            stderr="",
        )

    monkeypatch.setattr(docker_runtime.subprocess, "run", fake_run)

    with pytest.raises(
        docker_runtime.DockerRuntimeError,
        match="identity: overlay activation failed",
    ):
        docker_runtime.wait_for_profile_bootstrap(
            profile=DEMO_PROFILE,
            bootstrap_token="token-123",
            timeout_seconds=1.0,
            poll_interval_seconds=0.25,
        )

    wait_attempts = [
        command for command in attempts if command[:2] == ["docker", "exec"]
    ]
    assert len(wait_attempts) == 1


def test_wait_for_profile_bootstrap_retries_when_probe_reports_stale_failure_status(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    attempts: list[list[str]] = []
    probe_results = iter(
        [
            subprocess.CompletedProcess(
                ["docker", "exec"],
                BOOTSTRAP_WAIT_STATUS_AVAILABLE_EXIT_CODE,
                stdout=json.dumps(
                    {
                        "status": "failed",
                        "bootstrap_token": "stale-token",
                        "phase": "identity",
                        "message": "overlay activation failed",
                    }
                ),
                stderr="",
            ),
            subprocess.CompletedProcess(["docker", "exec"], 0, stdout="", stderr=""),
        ]
    )
    slept: list[float] = []
    monotonic_values = iter([0.0, 0.0, 0.25])

    def fake_run(
        command: list[str], **_kwargs: object
    ) -> subprocess.CompletedProcess[str]:
        attempts.append(command)
        if command[:2] == ["docker", "exec"]:
            result = next(probe_results)
            return subprocess.CompletedProcess(
                command,
                result.returncode,
                stdout=result.stdout,
                stderr=result.stderr,
            )
        return subprocess.CompletedProcess(command, 1, stdout="", stderr="")

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

    wait_attempts = [
        command for command in attempts if command[:2] == ["docker", "exec"]
    ]
    assert slept == [0.25]
    assert len(wait_attempts) == 2


def test_read_persisted_bootstrap_failure_ignores_unreadable_volume_file(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    monkeypatch.setattr(
        docker_runtime,
        "_profile_volume_mountpoint",
        lambda _profile: tmp_path / "profile-volume",
    )
    monkeypatch.setattr(
        docker_runtime.Path,
        "read_text",
        lambda self: (_ for _ in ()).throw(PermissionError("denied")),
    )

    assert (
        docker_runtime._read_persisted_bootstrap_failure(
            profile=DEMO_PROFILE,
            bootstrap_token="token-123",
        )
        is None
    )


def test_read_bootstrap_failure_detail_checks_current_then_persisted_then_logs(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    calls: list[str] = []

    def fake_current(*, profile: profiles.Profile, bootstrap_token: str) -> str | None:
        assert profile is DEMO_PROFILE
        assert bootstrap_token == "token-123"
        calls.append("current")
        return "current detail"

    def fake_persisted(
        *, profile: profiles.Profile, bootstrap_token: str
    ) -> str | None:
        calls.append("persisted")
        return "persisted detail"

    def fake_logs(profile: profiles.Profile) -> str | None:
        calls.append("logs")
        return "logs detail"

    monkeypatch.setattr(docker_runtime, "_read_current_bootstrap_failure", fake_current)
    monkeypatch.setattr(
        docker_runtime, "_read_persisted_bootstrap_failure", fake_persisted
    )
    monkeypatch.setattr(docker_runtime, "_read_container_logs", fake_logs)

    assert (
        docker_runtime._read_bootstrap_failure_detail(
            profile=DEMO_PROFILE,
            bootstrap_token="token-123",
            include_logs=True,
        )
        == "current detail"
    )
    assert calls == ["current"]


def test_read_bootstrap_failure_detail_can_prefer_logs(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    calls: list[str] = []

    def fake_current(*, profile: profiles.Profile, bootstrap_token: str) -> str | None:
        calls.append("current")
        return "current detail"

    def fake_persisted(
        *, profile: profiles.Profile, bootstrap_token: str
    ) -> str | None:
        calls.append("persisted")
        return "persisted detail"

    def fake_logs(profile: profiles.Profile) -> str | None:
        assert profile is DEMO_PROFILE
        calls.append("logs")
        return "logs detail"

    monkeypatch.setattr(docker_runtime, "_read_current_bootstrap_failure", fake_current)
    monkeypatch.setattr(
        docker_runtime, "_read_persisted_bootstrap_failure", fake_persisted
    )
    monkeypatch.setattr(docker_runtime, "_read_container_logs", fake_logs)

    assert (
        docker_runtime._read_bootstrap_failure_detail(
            profile=DEMO_PROFILE,
            bootstrap_token="token-123",
            include_logs=True,
            prefer_logs=True,
        )
        == "logs detail"
    )
    assert calls == ["logs"]


def test_wait_for_profile_bootstrap_reports_persisted_current_token_failure_after_container_exit(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    attempts: list[list[str]] = []
    volume_root = tmp_path / "profile-volume"
    status_path = volume_root / "meta" / "bootstrap-status.json"
    status_path.parent.mkdir(parents=True)
    status_path.write_text(
        json.dumps(
            {
                "status": "failed",
                "bootstrap_token": "token-123",
                "phase": "identity",
                "message": "overlay activation failed",
            }
        )
    )

    def fake_run(
        command: list[str], **_kwargs: object
    ) -> subprocess.CompletedProcess[str]:
        attempts.append(command)
        if command[1:3] == ["volume", "inspect"]:
            return subprocess.CompletedProcess(
                command,
                0,
                stdout=json.dumps([{"Mountpoint": str(volume_root)}]),
                stderr="",
            )
        return subprocess.CompletedProcess(
            command,
            1,
            stdout="",
            stderr="Error: No such object: frag-demo-profile",
        )

    monkeypatch.setattr(docker_runtime.subprocess, "run", fake_run)

    with pytest.raises(
        docker_runtime.DockerRuntimeError,
        match="identity: overlay activation failed",
    ):
        docker_runtime.wait_for_profile_bootstrap(
            profile=DEMO_PROFILE,
            bootstrap_token="token-123",
            timeout_seconds=1.0,
            poll_interval_seconds=0.25,
        )

    assert ["docker", "volume", "inspect", DEMO_PROFILE.volume_name] in attempts


def test_wait_for_profile_bootstrap_prefers_logs_before_persisted_status_after_exit(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    attempts: list[list[str]] = []
    volume_root = tmp_path / "profile-volume"
    status_path = volume_root / "meta" / "bootstrap-status.json"
    status_path.parent.mkdir(parents=True)
    status_path.write_text(
        json.dumps(
            {
                "status": "failed",
                "bootstrap_token": "token-123",
                "phase": "identity",
                "message": "overlay activation failed",
            }
        )
    )

    def fake_run(
        command: list[str], **_kwargs: object
    ) -> subprocess.CompletedProcess[str]:
        attempts.append(command)
        if command[1:3] == ["volume", "inspect"]:
            return subprocess.CompletedProcess(
                command,
                0,
                stdout=json.dumps([{"Mountpoint": str(volume_root)}]),
                stderr="",
            )
        if command[1:2] == ["logs"]:
            return subprocess.CompletedProcess(
                command,
                0,
                stdout="bootstrap crashed\ntraceback line\n",
                stderr="",
            )
        return subprocess.CompletedProcess(
            command,
            1,
            stdout="",
            stderr="Error: No such object: frag-demo-profile",
        )

    monkeypatch.setattr(docker_runtime.subprocess, "run", fake_run)

    with pytest.raises(
        docker_runtime.DockerRuntimeError,
        match="bootstrap crashed\\ntraceback line",
    ):
        docker_runtime.wait_for_profile_bootstrap(
            profile=DEMO_PROFILE,
            bootstrap_token="token-123",
            timeout_seconds=1.0,
            poll_interval_seconds=0.25,
        )

    assert [
        "docker",
        "logs",
        docker_runtime.container_name_for_profile(DEMO_PROFILE.name),
    ] in attempts
    assert ["docker", "volume", "inspect", DEMO_PROFILE.volume_name] not in attempts


def test_wait_for_profile_bootstrap_reports_exited_container_logs_without_status(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    attempts: list[list[str]] = []
    volume_root = tmp_path / "profile-volume"
    volume_root.mkdir()

    def fake_run(
        command: list[str], **_kwargs: object
    ) -> subprocess.CompletedProcess[str]:
        attempts.append(command)
        if command[1:3] == ["volume", "inspect"]:
            return subprocess.CompletedProcess(
                command,
                0,
                stdout=json.dumps([{"Mountpoint": str(volume_root)}]),
                stderr="",
            )
        if command[1:2] == ["logs"]:
            return subprocess.CompletedProcess(
                command,
                0,
                stdout="bootstrap crashed\ntraceback line\n",
                stderr="",
            )
        return subprocess.CompletedProcess(
            command,
            1,
            stdout="",
            stderr="Error: No such object: frag-demo-profile",
        )

    monkeypatch.setattr(docker_runtime.subprocess, "run", fake_run)

    with pytest.raises(
        docker_runtime.DockerRuntimeError,
        match="bootstrap crashed\\ntraceback line",
    ):
        docker_runtime.wait_for_profile_bootstrap(
            profile=DEMO_PROFILE,
            bootstrap_token="token-123",
            timeout_seconds=1.0,
            poll_interval_seconds=0.25,
        )

    assert [
        "docker",
        "logs",
        docker_runtime.container_name_for_profile(DEMO_PROFILE.name),
    ] in attempts
    assert ["docker", "volume", "inspect", DEMO_PROFILE.volume_name] not in attempts


def test_wait_for_profile_bootstrap_reports_gone_container_without_status(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    attempts: list[list[str]] = []
    slept: list[float] = []
    volume_root = tmp_path / "profile-volume"
    volume_root.mkdir()

    def fake_run(
        command: list[str], **_kwargs: object
    ) -> subprocess.CompletedProcess[str]:
        attempts.append(command)
        if command[1:3] == ["volume", "inspect"]:
            return subprocess.CompletedProcess(
                command,
                0,
                stdout=json.dumps([{"Mountpoint": str(volume_root)}]),
                stderr="",
            )
        if command[1:2] == ["logs"]:
            return subprocess.CompletedProcess(
                command,
                1,
                stdout="",
                stderr="Error: No such object: frag-demo-profile",
            )
        return subprocess.CompletedProcess(
            command,
            1,
            stdout="",
            stderr="Error: No such object: frag-demo-profile",
        )

    monkeypatch.setattr(docker_runtime.subprocess, "run", fake_run)
    monkeypatch.setattr(docker_runtime.time, "sleep", slept.append)

    with pytest.raises(
        docker_runtime.DockerRuntimeError,
        match="Error: No such object: frag-demo-profile",
    ):
        docker_runtime.wait_for_profile_bootstrap(
            profile=DEMO_PROFILE,
            bootstrap_token="token-123",
            timeout_seconds=1.0,
            poll_interval_seconds=0.25,
        )

    assert ["docker", "volume", "inspect", DEMO_PROFILE.volume_name] in attempts
    assert [
        "docker",
        "logs",
        docker_runtime.container_name_for_profile(DEMO_PROFILE.name),
    ] in attempts
    assert slept == []


def test_wait_for_profile_bootstrap_reports_gone_container_without_status_for_no_such_container(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    attempts: list[list[str]] = []
    slept: list[float] = []
    volume_root = tmp_path / "profile-volume"
    volume_root.mkdir()

    def fake_run(
        command: list[str], **_kwargs: object
    ) -> subprocess.CompletedProcess[str]:
        attempts.append(command)
        if command[1:3] == ["volume", "inspect"]:
            return subprocess.CompletedProcess(
                command,
                0,
                stdout=json.dumps([{"Mountpoint": str(volume_root)}]),
                stderr="",
            )
        if command[1:2] == ["logs"]:
            return subprocess.CompletedProcess(
                command,
                1,
                stdout="",
                stderr="Error response from daemon: No such container: frag-demo-profile",
            )
        return subprocess.CompletedProcess(
            command,
            1,
            stdout="",
            stderr="Error response from daemon: No such container: frag-demo-profile",
        )

    monkeypatch.setattr(docker_runtime.subprocess, "run", fake_run)
    monkeypatch.setattr(docker_runtime.time, "sleep", slept.append)

    with pytest.raises(
        docker_runtime.DockerRuntimeError,
        match="Error response from daemon: No such container: frag-demo-profile",
    ):
        docker_runtime.wait_for_profile_bootstrap(
            profile=DEMO_PROFILE,
            bootstrap_token="token-123",
            timeout_seconds=1.0,
            poll_interval_seconds=0.25,
        )

    assert slept == []
    assert [
        "docker",
        "logs",
        docker_runtime.container_name_for_profile(DEMO_PROFILE.name),
    ] in attempts


@pytest.mark.skip(
    reason="Deferred: startup failure/timeout cleanup semantics are not exposed in docker_runtime within tight Chunk 1 runtime-test scope; cover container/volume cleanup behavior in a later task.",
)
def test_wait_for_profile_bootstrap_defers_startup_cleanup_semantics() -> None:
    """Explicitly track the untested cleanup-semantics gap for a follow-up task."""

    pass


@pytest.mark.parametrize(
    ("mutate_labels", "mount_source"),
    [
        pytest.param(
            lambda labels: labels.__setitem__(
                profiles.LABEL_RUNTIME_IMAGE_REF, "stale:image"
            ),
            None,
            id="image-ref",
        ),
        pytest.param(
            lambda labels: labels.__setitem__(
                profiles.LABEL_SHARED_ASSETS_IDENTITY, "stale-assets"
            ),
            None,
            id="shared-assets",
        ),
        pytest.param(
            lambda labels: labels.__setitem__(profiles.LABEL_PROFILE, "Other Profile"),
            None,
            id="profile-name",
        ),
        pytest.param(
            lambda labels: None,
            "/other-workspace",
            id="workspace-bind",
        ),
    ],
)
def test_is_container_running_requires_strict_schema_2_runtime_metadata_match(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
    mutate_labels: callable,
    mount_source: str | None,
) -> None:
    workspace_root = tmp_path / "workspace"
    workspace_root.mkdir()
    labels = {
        profiles.LABEL_PROFILE: DEMO_PROFILE.name,
        profiles.LABEL_IMAGE: DEMO_PROFILE.image,
        profiles.LABEL_WORKSPACE_ROOT: str(workspace_root),
        profiles.LABEL_SCHEMA_VERSION: profiles.SCHEMA_VERSION,
        profiles.LABEL_RUNTIME_IMAGE_REF: "loaded:image",
        profiles.LABEL_SHARED_ASSETS_IDENTITY: "shared-assets-123",
        profiles.LABEL_TARGET_UID: "1000",
        profiles.LABEL_TARGET_GID: "1000",
        profiles.LABEL_TARGET_SUPPLEMENTARY_GIDS: "2001,2002",
    }
    mutate_labels(labels)
    inspect_payload = [
        {
            "State": {"Running": True},
            "Config": {"Labels": labels},
            "Mounts": [
                {
                    "Type": "bind",
                    "Source": mount_source or str(workspace_root),
                    "Destination": "/workspace-root",
                }
            ],
        }
    ]

    def fake_run(
        command: list[str], **_kwargs: object
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.CompletedProcess(
            command, 0, stdout=json.dumps(inspect_payload), stderr=""
        )

    monkeypatch.setattr(docker_runtime.subprocess, "run", fake_run)

    runtime_profile = profiles.Profile(
        name=DEMO_PROFILE.name,
        image=DEMO_PROFILE.image,
        workspace_root=str(workspace_root),
        volume_name=DEMO_PROFILE.volume_name,
    )

    assert (
        docker_runtime.is_container_running(
            runtime_profile,
            runtime_metadata=profiles.RuntimeProfileMetadata(
                image_ref="loaded:image",
                shared_assets_identity="shared-assets-123",
                target_uid="1000",
                target_gid="1000",
                supplementary_gids=(2001, 2002),
            ),
        )
        is False
    )


def test_is_container_running_refuses_legacy_schema_1_named_container(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    inspect_payload = [
        {
            "State": {"Running": True},
            "Config": {
                "Labels": {
                    profiles.LABEL_PROFILE: DEMO_PROFILE.name,
                    profiles.LABEL_IMAGE: DEMO_PROFILE.image,
                    profiles.LABEL_WORKSPACE_ROOT: DEMO_PROFILE.workspace_root,
                    profiles.LABEL_SCHEMA_VERSION: "1",
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
        return subprocess.CompletedProcess(
            command, 0, stdout=json.dumps(inspect_payload), stderr=""
        )

    monkeypatch.setattr(docker_runtime.subprocess, "run", fake_run)

    with pytest.raises(
        docker_runtime.DockerRuntimeError,
        match="legacy schema 1 profile container",
    ):
        docker_runtime.is_container_running(
            DEMO_PROFILE,
            runtime_metadata=profiles.RuntimeProfileMetadata(
                image_ref="loaded:image",
                shared_assets_identity="shared-assets-123",
                target_uid="1000",
                target_gid="1000",
                supplementary_gids=(),
            ),
        )


def test_is_container_running_rejects_named_container_with_mismatched_identity_metadata(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    workspace_root = tmp_path / "workspace"
    workspace_root.mkdir()

    inspect_payload = [
        {
            "State": {"Running": True},
            "Config": {
                "Labels": {
                    profiles.LABEL_PROFILE: DEMO_PROFILE.name,
                    profiles.LABEL_IMAGE: DEMO_PROFILE.image,
                    profiles.LABEL_WORKSPACE_ROOT: str(workspace_root),
                    profiles.LABEL_SCHEMA_VERSION: profiles.SCHEMA_VERSION,
                    profiles.LABEL_RUNTIME_IMAGE_REF: "loaded:image",
                    profiles.LABEL_SHARED_ASSETS_IDENTITY: "shared-assets-123",
                    profiles.LABEL_TARGET_UID: "1000",
                    profiles.LABEL_TARGET_GID: "1000",
                    profiles.LABEL_TARGET_SUPPLEMENTARY_GIDS: "2001,2002",
                }
            },
            "Mounts": [
                {
                    "Type": "bind",
                    "Source": str(workspace_root),
                    "Destination": "/workspace-root",
                }
            ],
        }
    ]

    def fake_run(
        command: list[str], **_kwargs: object
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.CompletedProcess(
            command, 0, stdout=json.dumps(inspect_payload), stderr=""
        )

    monkeypatch.setattr(docker_runtime.subprocess, "run", fake_run)

    runtime_profile = profiles.Profile(
        name=DEMO_PROFILE.name,
        image=DEMO_PROFILE.image,
        workspace_root=str(workspace_root),
        volume_name=DEMO_PROFILE.volume_name,
    )

    assert (
        docker_runtime.is_container_running(
            runtime_profile,
            runtime_metadata=profiles.RuntimeProfileMetadata(
                image_ref="loaded:image",
                shared_assets_identity="shared-assets-123",
                target_uid="1000",
                target_gid="1000",
                supplementary_gids=(3001, 3002),
            ),
        )
        is False
    )


def test_cli_enter_requires_runtime_metadata_for_container_reuse(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    workspace_root = tmp_path / "workspace"
    workspace_root.mkdir()
    working_dir = workspace_root / "nested"
    working_dir.mkdir()
    runtime_spec = image_assets.RuntimeSpec(
        image_ref="loaded:image",
        shared_assets_identity="shared-assets-123",
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
    monkeypatch.setattr(
        cli.os, "getgroups", lambda: [cli.os.getgid(), 2001, 2002, 2001]
    )
    expected_metadata = profiles.RuntimeProfileMetadata(
        image_ref="loaded:image",
        shared_assets_identity="shared-assets-123",
        target_uid=str(cli.os.getuid()),
        target_gid=str(cli.os.getgid()),
        supplementary_gids=(2001, 2002),
    )

    monkeypatch.setattr(cli, "build_docker_backend", lambda: object())
    monkeypatch.setattr(
        cli.profiles,
        "get_profile",
        lambda _backend, name: runtime_profile if name == "Demo Profile" else None,
    )
    monkeypatch.setattr(
        cli.docker_runtime,
        "container_workdir_for_cwd",
        lambda *, profile, cwd, workspace_root: (
            calls.append(("map", cwd)) or "/workspace-root/nested"
        ),
    )
    monkeypatch.setattr(cli, "build_image_assets", lambda: assets_provider)

    def fake_is_container_running(
        profile: profiles.Profile,
        *,
        runtime_metadata: profiles.RuntimeProfileMetadata | None = None,
    ) -> bool:
        calls.append(("reuse", runtime_metadata))
        return runtime_metadata == expected_metadata

    monkeypatch.setattr(
        cli.docker_runtime,
        "is_container_running",
        fake_is_container_running,
    )
    monkeypatch.setattr(
        cli.docker_runtime,
        "start_profile_container",
        lambda **_kwargs: pytest.fail("container startup should not be reached"),
    )
    monkeypatch.setattr(
        cli.docker_runtime,
        "wait_for_profile_bootstrap",
        lambda **_kwargs: pytest.fail("bootstrap wait should not be reached"),
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
    assert assets_provider.load_calls == []
    assert assets_provider.build_calls == [(runtime_profile, workspace_root)]
    assert calls == [
        ("map", working_dir),
        ("reuse", expected_metadata),
        ("exec", "Demo Profile", "/workspace-root/nested", ("fish",)),
    ]


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
        shared_assets_identity="shared-assets-123",
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
        cli.docker_runtime,
        "is_container_running",
        lambda profile, *, runtime_metadata=None: False,
    )
    monkeypatch.setattr(
        cli,
        "build_image_assets",
        lambda: assets_provider,
        raising=False,
    )
    monkeypatch.setattr(cli, "DEFAULT_SHELL", ("fish",), raising=False)
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
    assert assets_provider.build_calls == [
        (runtime_profile, workspace_root),
        (runtime_profile, workspace_root),
    ]
    assert calls == [
        ("map", working_dir),
        ("start", "Demo Profile", workspace_root, runtime_spec, "fresh-token-123"),
        ("wait", "Demo Profile", "fresh-token-123"),
        ("exec", "Demo Profile", "/workspace-root/nested", ("fish",)),
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

    with pytest.raises(docker_runtime.WorkspacePathError, match="bad cwd"):
        cli.handle_enter(profile="Demo Profile", command=("fish",))


def test_stop_profile_container_stops_named_container(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    captured: list[list[str]] = []

    def fake_run(
        command: list[str], **_kwargs: object
    ) -> subprocess.CompletedProcess[str]:
        captured.append(command)
        return subprocess.CompletedProcess(command, 0, stdout="stopped\n", stderr="")

    monkeypatch.setattr(docker_runtime.subprocess, "run", fake_run)

    docker_runtime.stop_profile_container(DEMO_PROFILE)

    assert captured == [["docker", "stop", "frag-demo-profile"]]


def test_stop_profile_container_surfaces_docker_stop_failures(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def fake_run(
        command: list[str], **_kwargs: object
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.CompletedProcess(
            command, 1, stdout="", stderr="permission denied"
        )

    monkeypatch.setattr(docker_runtime.subprocess, "run", fake_run)

    with pytest.raises(docker_runtime.DockerRuntimeError, match="permission denied"):
        docker_runtime.stop_profile_container(DEMO_PROFILE)


@pytest.mark.parametrize(
    ("stdin_tty", "stdout_tty", "expected"),
    [
        pytest.param(True, True, True, id="both-interactive"),
        pytest.param(True, False, False, id="stdout-only-non-interactive"),
        pytest.param(False, True, False, id="stdin-only-non-interactive"),
        pytest.param(False, False, False, id="neither-interactive"),
    ],
)
def test_should_allocate_tty_requires_both_streams_to_be_interactive(
    monkeypatch: pytest.MonkeyPatch,
    stdin_tty: bool,
    stdout_tty: bool,
    expected: bool,
) -> None:
    monkeypatch.setattr(docker_runtime.sys.stdin, "isatty", lambda: stdin_tty)
    monkeypatch.setattr(docker_runtime.sys.stdout, "isatty", lambda: stdout_tty)

    assert docker_runtime._should_allocate_tty() is expected


def test_resolve_runtime_spec_prefers_loaded_image_reference(
    tmp_path: Path,
) -> None:
    workspace_root = tmp_path / "workspace"
    workspace_root.mkdir()
    runtime_spec = image_assets.RuntimeSpec(
        image_ref="runtime:image",
        shared_assets_identity="shared-assets-123",
        shared_mounts=(),
        start_command=("frag-bootstrap",),
    )
    assets_provider = FakeImageAssets(runtime_spec=runtime_spec)

    resolved = docker_runtime.resolve_runtime_spec(
        DEMO_PROFILE,
        workspace_root,
        assets_provider,
        loaded_image_ref="loaded:image",
    )

    assert resolved == image_assets.RuntimeSpec(
        image_ref="loaded:image",
        shared_assets_identity="shared-assets-123",
        shared_mounts=(),
        start_command=("frag-bootstrap",),
    )
    assert assets_provider.build_calls == [(DEMO_PROFILE, workspace_root.resolve())]


@pytest.mark.parametrize(
    ("runtime_spec", "loaded_image_ref", "message"),
    [
        pytest.param(
            image_assets.RuntimeSpec(
                image_ref="   ",
                shared_assets_identity="shared-assets-123",
                shared_mounts=(),
                start_command=("frag-bootstrap",),
            ),
            None,
            "image loader returned an empty image reference",
            id="empty-runtime-image-ref",
        ),
        pytest.param(
            image_assets.RuntimeSpec(
                image_ref="runtime:image",
                shared_assets_identity="   ",
                shared_mounts=(),
                start_command=("frag-bootstrap",),
            ),
            None,
            "image loader returned no shared assets identity",
            id="missing-shared-assets-identity",
        ),
        pytest.param(
            image_assets.RuntimeSpec(
                image_ref="runtime:image",
                shared_assets_identity="shared-assets-123",
                shared_mounts=(),
                start_command=(),
            ),
            None,
            "image loader returned no bootstrap command",
            id="missing-start-command",
        ),
    ],
)
def test_resolve_runtime_spec_rejects_invalid_runtime_spec(
    tmp_path: Path,
    runtime_spec: image_assets.RuntimeSpec,
    loaded_image_ref: str | None,
    message: str,
) -> None:
    workspace_root = tmp_path / "workspace"
    workspace_root.mkdir()
    assets_provider = FakeImageAssets(runtime_spec=runtime_spec)

    with pytest.raises(docker_runtime.DockerRuntimeError, match=message):
        docker_runtime.resolve_runtime_spec(
            DEMO_PROFILE,
            workspace_root,
            assets_provider,
            loaded_image_ref=loaded_image_ref,
        )


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
