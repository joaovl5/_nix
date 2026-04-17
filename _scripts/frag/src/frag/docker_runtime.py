from __future__ import annotations

from collections.abc import Sequence
from pathlib import Path
import json
import re
import secrets
import os
import subprocess
import sys
import time

from frag import profiles
from frag.image_assets import ImageAssets, RuntimeSpec

_WORKSPACE_ROOT_IN_CONTAINER = "/workspace-root"
_BOOTSTRAP_TOKEN_ENV = "FRAG_BOOTSTRAP_TOKEN"
_TARGET_UID_ENV = "FRAG_TARGET_UID"
_TARGET_GID_ENV = "FRAG_TARGET_GID"
_BOOTSTRAP_TOKEN_PATH = "/state/profile/meta/bootstrap-token"


class DockerRuntimeError(RuntimeError):
    pass


class WorkspacePathError(DockerRuntimeError):
    pass


def _slugify_profile_name(name: str) -> str:
    normalized = re.sub(r"[^a-z0-9]+", "-", name.strip().lower()).strip("-")
    if not normalized:
        raise DockerRuntimeError(
            "profile name must contain at least one alphanumeric character"
        )
    return normalized


def container_name_for_profile(name: str) -> str:
    return f"frag-{_slugify_profile_name(name)}"


def _run_docker_command(
    command: Sequence[str], *, capture_output: bool
) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(
            list(command),
            check=False,
            text=True,
            capture_output=capture_output,
        )
    except FileNotFoundError as exc:
        raise DockerRuntimeError("docker executable not found") from exc


def _check_docker_result(
    result: subprocess.CompletedProcess[str],
) -> subprocess.CompletedProcess[str]:
    if result.returncode == 0:
        return result
    detail = (result.stderr or result.stdout or str(result.returncode)).strip()
    raise DockerRuntimeError(detail)


def _canonical_path(path: Path | str) -> Path:
    return Path(path).expanduser().resolve(strict=False)


def _current_process_user_option() -> str:
    return f"{os.getuid()}:{os.getgid()}"


def container_workdir_for_cwd(
    *, profile: profiles.Profile, cwd: Path | str, workspace_root: Path | str
) -> str:
    del profile
    workspace_path = _canonical_path(workspace_root)
    cwd_path = _canonical_path(cwd)
    try:
        relative = cwd_path.relative_to(workspace_path)
    except ValueError as exc:
        raise WorkspacePathError(
            f"cwd {cwd_path} is outside workspace root {workspace_path}"
        ) from exc
    if not relative.parts:
        return _WORKSPACE_ROOT_IN_CONTAINER
    return str(Path(_WORKSPACE_ROOT_IN_CONTAINER, *relative.parts).as_posix())


def _workspace_root_mount_matches(*, mounts: object, workspace_root: Path) -> bool:
    if not isinstance(mounts, list):
        return False
    for mount in mounts:
        if not isinstance(mount, dict):
            continue
        if (
            mount.get("Type") == "bind"
            and mount.get("Destination") == _WORKSPACE_ROOT_IN_CONTAINER
            and isinstance(mount.get("Source"), str)
        ):
            return _canonical_path(mount["Source"]) == workspace_root
    return False


def _container_is_running(container: object) -> bool:
    if not isinstance(container, dict):
        return False
    state = container.get("State")
    return isinstance(state, dict) and state.get("Running") is True


def _container_matches_profile(container: object, profile: profiles.Profile) -> bool:
    if not isinstance(container, dict):
        return False
    config = container.get("Config")
    if not isinstance(config, dict):
        return False
    labels = config.get("Labels")
    if not isinstance(labels, dict):
        return False

    expected_workspace_root = _canonical_path(profile.workspace_root)
    labeled_workspace_root = labels.get(profiles.LABEL_WORKSPACE_ROOT)
    return (
        labels.get(profiles.LABEL_PROFILE) == profile.name
        and labels.get(profiles.LABEL_IMAGE) == profile.image
        and labels.get(profiles.LABEL_SCHEMA_VERSION) == profiles.SCHEMA_VERSION
        and isinstance(labeled_workspace_root, str)
        and _canonical_path(labeled_workspace_root) == expected_workspace_root
        and _workspace_root_mount_matches(
            mounts=container.get("Mounts"),
            workspace_root=expected_workspace_root,
        )
    )


def _inspect_profile_containers(profile: profiles.Profile) -> list[object]:
    container_name = container_name_for_profile(profile.name)
    inspect_result = _run_docker_command(
        ["docker", "inspect", "--type", "container", container_name],
        capture_output=True,
    )
    if inspect_result.returncode != 0:
        detail = (inspect_result.stderr or inspect_result.stdout or "").lower()
        if "no such object" in detail:
            return []
        _check_docker_result(inspect_result)

    try:
        containers = json.loads(inspect_result.stdout)
    except json.JSONDecodeError as exc:
        raise DockerRuntimeError(
            f"docker inspect returned invalid JSON for {container_name!r}"
        ) from exc
    if not isinstance(containers, list):
        raise DockerRuntimeError(
            f"docker inspect returned unexpected JSON for {container_name!r}"
        )
    return containers


def is_container_running(profile: profiles.Profile) -> bool:
    return any(
        _container_is_running(container)
        and _container_matches_profile(container, profile)
        for container in _inspect_profile_containers(profile)
    )


def _remove_conflicting_profile_container(profile: profiles.Profile) -> None:
    container_name = container_name_for_profile(profile.name)
    containers = _inspect_profile_containers(profile)
    if not containers:
        return
    if any(_container_matches_profile(container, profile) for container in containers):
        return
    _check_docker_result(
        _run_docker_command(
            ["docker", "rm", "--force", container_name],
            capture_output=True,
        )
    )


def load_profile_image(profile: profiles.Profile, image_assets: ImageAssets) -> str:
    image_ref = image_assets.load_image(profile=profile).strip()
    if not image_ref:
        raise DockerRuntimeError(
            f"image loader returned an empty image reference for {profile.name!r}"
        )
    return image_ref


def resolve_runtime_spec(
    profile: profiles.Profile,
    workspace_root: Path | str,
    image_assets: ImageAssets,
    *,
    loaded_image_ref: str | None = None,
) -> RuntimeSpec:
    workspace_path = _canonical_path(workspace_root)
    runtime_spec = image_assets.build_runtime_spec(
        profile=profile,
        workspace_root=workspace_path,
    )
    image_ref = loaded_image_ref or runtime_spec.image_ref.strip()
    if not image_ref:
        raise DockerRuntimeError(
            f"image loader returned an empty image reference for {profile.name!r}"
        )
    if not runtime_spec.start_command:
        raise DockerRuntimeError(
            f"image loader returned no bootstrap command for {profile.name!r}"
        )
    return RuntimeSpec(
        image_ref=image_ref,
        shared_mounts=runtime_spec.shared_mounts,
        start_command=runtime_spec.start_command,
    )


def _build_start_container_command(
    *,
    profile: profiles.Profile,
    workspace_root: Path,
    runtime_spec: RuntimeSpec,
) -> list[str]:
    command = [
        "docker",
        "run",
        "--detach",
        "--rm",
        "--name",
        container_name_for_profile(profile.name),
        "--label",
        f"{profiles.LABEL_PROFILE}={profile.name}",
        "--label",
        f"{profiles.LABEL_IMAGE}={profile.image}",
        "--label",
        f"{profiles.LABEL_WORKSPACE_ROOT}={workspace_root}",
        "--label",
        f"{profiles.LABEL_SCHEMA_VERSION}={profiles.SCHEMA_VERSION}",
        "--read-only",
        "--tmpfs",
        "/home/agent",
        "--tmpfs",
        "/tmp",
        "--tmpfs",
        "/run",
        "--mount",
        f"type=volume,src={profile.volume_name},dst=/state/profile,volume-nocopy",
        "--mount",
        f"type=bind,src={workspace_root},dst={_WORKSPACE_ROOT_IN_CONTAINER}",
    ]
    for mount in runtime_spec.shared_mounts:
        command.extend(
            [
                "--mount",
                f"type=bind,src={mount.source},dst={mount.destination},readonly",
            ]
        )
    command.extend([runtime_spec.image_ref, *runtime_spec.start_command])
    return command


def bootstrap_token_for_profile(profile: profiles.Profile) -> str:
    del profile
    return secrets.token_urlsafe(32)


def _build_bootstrap_wait_command(
    *, profile: profiles.Profile, bootstrap_token: str
) -> list[str]:
    user_option = _current_process_user_option()
    return [
        "docker",
        "exec",
        "--user",
        user_option,
        "-e",
        f"{_BOOTSTRAP_TOKEN_ENV}={bootstrap_token}",
        container_name_for_profile(profile.name),
        "sh",
        "-lc",
        f'test -f {_BOOTSTRAP_TOKEN_PATH} && test "$(cat {_BOOTSTRAP_TOKEN_PATH})" = "$FRAG_BOOTSTRAP_TOKEN"',
    ]


def start_profile_container(
    *,
    profile: profiles.Profile,
    workspace_root: Path | str,
    runtime_spec: RuntimeSpec,
    bootstrap_token: str,
) -> None:
    workspace_path = _canonical_path(workspace_root)
    _remove_conflicting_profile_container(profile)
    command = _build_start_container_command(
        profile=profile,
        workspace_root=workspace_path,
        runtime_spec=runtime_spec,
    )
    read_only_index = command.index("--read-only")
    command[read_only_index:read_only_index] = [
        "--env",
        f"{_TARGET_UID_ENV}={os.getuid()}",
        "--env",
        f"{_TARGET_GID_ENV}={os.getgid()}",
        "--env",
        f"{_BOOTSTRAP_TOKEN_ENV}={bootstrap_token}",
    ]
    _check_docker_result(_run_docker_command(command, capture_output=True))


def wait_for_profile_bootstrap(
    *,
    profile: profiles.Profile,
    bootstrap_token: str,
    timeout_seconds: float = 10.0,
    poll_interval_seconds: float = 0.25,
) -> None:
    command = _build_bootstrap_wait_command(
        profile=profile,
        bootstrap_token=bootstrap_token,
    )
    deadline = time.monotonic() + timeout_seconds
    while True:
        result = _run_docker_command(command, capture_output=True)
        if result.returncode == 0:
            return
        if result.returncode != 1:
            detail = (result.stderr or result.stdout or str(result.returncode)).strip()
            raise DockerRuntimeError(detail)
        if time.monotonic() >= deadline:
            raise DockerRuntimeError(
                f"timed out waiting for bootstrap readiness for {profile.name!r}"
            )
        time.sleep(poll_interval_seconds)


def _should_allocate_tty() -> bool:
    return sys.stdin.isatty() and sys.stdout.isatty()


def exec_in_profile_container(
    *, profile: profiles.Profile, workdir: str, command: Sequence[str]
) -> int:
    tty_flag = "-it" if _should_allocate_tty() else "-i"
    user_option = _current_process_user_option()
    result = _run_docker_command(
        [
            "docker",
            "exec",
            tty_flag,
            "--user",
            user_option,
            "-w",
            workdir,
            container_name_for_profile(profile.name),
            *command,
        ],
        capture_output=False,
    )
    return result.returncode


def stop_profile_container(profile: profiles.Profile) -> None:
    _check_docker_result(
        _run_docker_command(
            ["docker", "stop", container_name_for_profile(profile.name)],
            capture_output=True,
        )
    )
