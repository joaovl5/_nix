from __future__ import annotations

from collections.abc import Sequence
from pathlib import Path
import json
import os
import re
import secrets
import subprocess
import sys
import time

from frag import profiles
from frag.image_assets import ImageAssets, RuntimeSpec

_WORKSPACE_ROOT_IN_CONTAINER = "/workspace-root"
_BOOTSTRAP_TOKEN_ENV = "FRAG_BOOTSTRAP_TOKEN"
_TARGET_UID_ENV = "FRAG_TARGET_UID"
_TARGET_GID_ENV = "FRAG_TARGET_GID"
_TARGET_SUPPLEMENTARY_GIDS_ENV = "FRAG_TARGET_SUPPLEMENTARY_GIDS"
_BOOTSTRAP_TOKEN_PATH = "/state/profile/meta/bootstrap-token"
_BOOTSTRAP_STATUS_PATH = "/state/profile/meta/bootstrap-status.json"
_IDENTITY_OVERLAY_EXEC_PATH = "/run/frag/identity/exec"


_BOOTSTRAP_WAIT_NOT_READY_EXIT_CODE = 42
_BOOTSTRAP_WAIT_NOT_READY_SENTINEL = "frag-bootstrap-not-ready"


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


def _root_exec_user_option() -> str:
    return "0:0"


def _current_supplementary_gids(*, primary_gid: int) -> tuple[int, ...]:
    supplementary_groups: list[int] = []
    for gid in os.getgroups():
        if gid == primary_gid or gid in supplementary_groups:
            continue
        supplementary_groups.append(gid)
    return tuple(supplementary_groups)


def _supplementary_group_env_value(*, primary_gid: int) -> str:
    return ",".join(
        str(gid) for gid in _current_supplementary_gids(primary_gid=primary_gid)
    )


def _current_runtime_metadata(
    *, runtime_spec: RuntimeSpec
) -> profiles.RuntimeProfileMetadata:
    primary_gid = os.getgid()
    return profiles.RuntimeProfileMetadata(
        image_ref=runtime_spec.image_ref,
        shared_assets_identity=runtime_spec.shared_assets_identity,
        target_uid=str(os.getuid()),
        target_gid=str(primary_gid),
        supplementary_gids=_current_supplementary_gids(primary_gid=primary_gid),
    )


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


def _container_runtime_metadata_matches(
    labels: dict[str, object],
    runtime_metadata: profiles.RuntimeProfileMetadata | None,
) -> bool:
    if runtime_metadata is None:
        return True
    discovered = profiles.runtime_metadata_from_labels(labels)
    return discovered == runtime_metadata


def _container_matches_profile(
    container: object,
    profile: profiles.Profile,
    *,
    runtime_metadata: profiles.RuntimeProfileMetadata | None = None,
) -> bool:
    if not isinstance(container, dict):
        return False
    config = container.get("Config")
    if not isinstance(config, dict):
        return False
    labels = config.get("Labels")
    if not isinstance(labels, dict):
        return False
    try:
        profiles.ensure_supported_schema(labels, subject="profile container")
    except profiles.ProfileError as exc:
        raise DockerRuntimeError(str(exc)) from exc

    expected_workspace_root = _canonical_path(profile.workspace_root)
    labeled_workspace_root = labels.get(profiles.LABEL_WORKSPACE_ROOT)
    return (
        labels.get(profiles.LABEL_PROFILE) == profile.name
        and labels.get(profiles.LABEL_IMAGE) == profile.image
        and isinstance(labeled_workspace_root, str)
        and _canonical_path(labeled_workspace_root) == expected_workspace_root
        and _container_runtime_metadata_matches(labels, runtime_metadata)
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
        if "no such object" in detail or "no such container" in detail:
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


def is_container_running(
    profile: profiles.Profile,
    *,
    runtime_metadata: profiles.RuntimeProfileMetadata | None = None,
) -> bool:
    return any(
        _container_is_running(container)
        and _container_matches_profile(
            container,
            profile,
            runtime_metadata=runtime_metadata,
        )
        for container in _inspect_profile_containers(profile)
    )


def _remove_conflicting_profile_container(
    profile: profiles.Profile,
    *,
    runtime_metadata: profiles.RuntimeProfileMetadata,
) -> None:
    container_name = container_name_for_profile(profile.name)
    containers = _inspect_profile_containers(profile)
    if not containers:
        return
    for container in containers:
        if not isinstance(container, dict):
            continue
        config = container.get("Config")
        if not isinstance(config, dict):
            continue
        labels = config.get("Labels")
        if not isinstance(labels, dict):
            continue
        try:
            profiles.ensure_supported_schema(labels, subject="profile container")
        except profiles.ProfileError as exc:
            raise DockerRuntimeError(str(exc)) from exc
    if any(
        _container_is_running(container)
        and _container_matches_profile(
            container,
            profile,
            runtime_metadata=runtime_metadata,
        )
        for container in containers
    ):
        return
    _check_docker_result(
        _run_docker_command(
            ["docker", "rm", "--force", container_name],
            capture_output=True,
        )
    )


def _docker_result_is_container_name_conflict(
    result: subprocess.CompletedProcess[str],
    *,
    container_name: str,
) -> bool:
    detail = (result.stderr or result.stdout or "").lower()
    return (
        result.returncode != 0
        and "conflict" in detail
        and f'"/{container_name}"' in detail
        and "already in use" in detail
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
    if not runtime_spec.shared_assets_identity.strip():
        raise DockerRuntimeError(
            f"image loader returned no shared assets identity for {profile.name!r}"
        )
    if not runtime_spec.start_command:
        raise DockerRuntimeError(
            f"image loader returned no bootstrap command for {profile.name!r}"
        )
    return RuntimeSpec(
        image_ref=image_ref,
        shared_assets_identity=runtime_spec.shared_assets_identity,
        shared_mounts=runtime_spec.shared_mounts,
        start_command=runtime_spec.start_command,
    )


def _start_command_with_runtime_metadata(*, runtime_spec: RuntimeSpec) -> list[str]:
    command = list(runtime_spec.start_command)
    if not command or command[0] != "frag-bootstrap":
        return command

    insert_at = (
        command.index("--keepalive") if "--keepalive" in command else len(command)
    )
    runtime_args: list[str] = []
    if "--image-ref" not in command:
        runtime_args.extend(["--image-ref", runtime_spec.image_ref])
    if "--shared-assets-identity" not in command:
        runtime_args.extend(
            ["--shared-assets-identity", runtime_spec.shared_assets_identity]
        )
    command[insert_at:insert_at] = runtime_args
    return command


def _build_start_container_command(
    *,
    profile: profiles.Profile,
    workspace_root: Path,
    runtime_spec: RuntimeSpec,
) -> list[str]:
    runtime_metadata = _current_runtime_metadata(runtime_spec=runtime_spec)
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
        "--label",
        f"{profiles.LABEL_RUNTIME_IMAGE_REF}={runtime_metadata.image_ref}",
        "--label",
        f"{profiles.LABEL_SHARED_ASSETS_IDENTITY}={runtime_metadata.shared_assets_identity}",
        "--label",
        f"{profiles.LABEL_TARGET_UID}={runtime_metadata.target_uid}",
        "--label",
        f"{profiles.LABEL_TARGET_GID}={runtime_metadata.target_gid}",
        "--label",
        (
            f"{profiles.LABEL_TARGET_SUPPLEMENTARY_GIDS}="
            f"{','.join(str(gid) for gid in runtime_metadata.supplementary_gids)}"
        ),
        "--workdir",
        "/",
        "--read-only",
        "--tmpfs",
        "/tmp",
        "--tmpfs",
        "/run:exec",
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
    command.extend(
        [
            runtime_spec.image_ref,
            *_start_command_with_runtime_metadata(runtime_spec=runtime_spec),
        ]
    )
    return command


def bootstrap_token_for_profile(profile: profiles.Profile) -> str:
    del profile
    return secrets.token_urlsafe(32)


def _build_bootstrap_wait_command(
    *, profile: profiles.Profile, bootstrap_token: str
) -> list[str]:
    return [
        "docker",
        "exec",
        "--user",
        _root_exec_user_option(),
        "-e",
        f"{_BOOTSTRAP_TOKEN_ENV}={bootstrap_token}",
        container_name_for_profile(profile.name),
        _IDENTITY_OVERLAY_EXEC_PATH,
        "sh",
        "-lc",
        (
            f"if ! test -f {_BOOTSTRAP_TOKEN_PATH}; then "
            f'printf "%s\\n" "{_BOOTSTRAP_WAIT_NOT_READY_SENTINEL}"; '
            f"exit {_BOOTSTRAP_WAIT_NOT_READY_EXIT_CODE}; "
            "fi; "
            f'token="$(cat {_BOOTSTRAP_TOKEN_PATH})" || exit $?; '
            'test "$token" = "$FRAG_BOOTSTRAP_TOKEN" && exit 0; '
            f'printf "%s\\n" "{_BOOTSTRAP_WAIT_NOT_READY_SENTINEL}"; '
            f"exit {_BOOTSTRAP_WAIT_NOT_READY_EXIT_CODE}"
        ),
    ]


def _build_bootstrap_status_command(*, profile: profiles.Profile) -> list[str]:
    return [
        "docker",
        "exec",
        "--user",
        _root_exec_user_option(),
        container_name_for_profile(profile.name),
        "sh",
        "-lc",
        f"test -f {_BOOTSTRAP_STATUS_PATH} && cat {_BOOTSTRAP_STATUS_PATH}",
    ]


def _parse_bootstrap_failure_detail(
    raw_status: str,
    *,
    bootstrap_token: str,
    invalid_json_message: str,
    invalid_shape_message: str = "bootstrap failed",
) -> str | None:
    try:
        payload = json.loads(raw_status)
    except json.JSONDecodeError as exc:
        raise DockerRuntimeError(invalid_json_message) from exc
    if not isinstance(payload, dict) or payload.get("status") != "failed":
        return None
    if payload.get("bootstrap_token") != bootstrap_token:
        return None
    phase = payload.get("phase")
    message = payload.get("message")
    if isinstance(phase, str) and isinstance(message, str):
        return f"{phase}: {message}"
    return invalid_shape_message


def _read_current_bootstrap_failure(
    *, profile: profiles.Profile, bootstrap_token: str
) -> str | None:
    result = _run_docker_command(
        _build_bootstrap_status_command(profile=profile),
        capture_output=True,
    )
    if result.returncode != 0 or not result.stdout.strip():
        return None
    return _parse_bootstrap_failure_detail(
        result.stdout,
        bootstrap_token=bootstrap_token,
        invalid_json_message="bootstrap status file contained invalid JSON",
    )


def _profile_volume_mountpoint(profile: profiles.Profile) -> Path | None:
    result = _run_docker_command(
        ["docker", "volume", "inspect", profile.volume_name],
        capture_output=True,
    )
    if result.returncode != 0:
        return None
    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        raise DockerRuntimeError(
            f"docker volume inspect returned invalid JSON for {profile.volume_name!r}"
        ) from exc
    if not isinstance(payload, list) or not payload:
        raise DockerRuntimeError(
            f"docker volume inspect returned unexpected JSON for {profile.volume_name!r}"
        )
    volume = payload[0]
    if not isinstance(volume, dict):
        raise DockerRuntimeError(
            f"docker volume inspect returned unexpected JSON for {profile.volume_name!r}"
        )
    mountpoint = volume.get("Mountpoint")
    if not isinstance(mountpoint, str) or not mountpoint.strip():
        raise DockerRuntimeError(
            f"docker volume inspect omitted mountpoint for {profile.volume_name!r}"
        )
    return Path(mountpoint)


def _read_persisted_bootstrap_failure(
    *, profile: profiles.Profile, bootstrap_token: str
) -> str | None:
    mountpoint = _profile_volume_mountpoint(profile)
    if mountpoint is None:
        return None
    status_path = mountpoint / "meta" / "bootstrap-status.json"
    try:
        raw_status = status_path.read_text()
    except FileNotFoundError:
        return None
    except OSError:
        # Rootless Docker volume mountpoints may be unreadable from the host even
        # while the container is healthy; fall back to in-container status/logs.
        return None
    if not raw_status.strip():
        return None
    return _parse_bootstrap_failure_detail(
        raw_status,
        bootstrap_token=bootstrap_token,
        invalid_json_message="persisted bootstrap status file contained invalid JSON",
    )


def _bootstrap_wait_result_is_retryable(
    result: subprocess.CompletedProcess[str],
) -> bool:
    detail = (result.stderr or result.stdout or "").strip()
    if (
        result.returncode == _BOOTSTRAP_WAIT_NOT_READY_EXIT_CODE
        and detail == _BOOTSTRAP_WAIT_NOT_READY_SENTINEL
    ):
        return True
    return (
        result.returncode in (126, 127)
        and _IDENTITY_OVERLAY_EXEC_PATH in detail
        and "no such file or directory" in detail
    )


def _read_container_logs(profile: profiles.Profile) -> str | None:
    result = _run_docker_command(
        ["docker", "logs", container_name_for_profile(profile.name)],
        capture_output=True,
    )
    if result.returncode != 0:
        return None
    logs = "".join(part for part in (result.stdout, result.stderr) if part).strip()
    if not logs:
        return None
    return logs


def start_profile_container(
    *,
    profile: profiles.Profile,
    workspace_root: Path | str,
    runtime_spec: RuntimeSpec,
    bootstrap_token: str,
) -> None:
    workspace_path = _canonical_path(workspace_root)
    runtime_metadata = _current_runtime_metadata(runtime_spec=runtime_spec)
    _remove_conflicting_profile_container(
        profile,
        runtime_metadata=runtime_metadata,
    )
    command = _build_start_container_command(
        profile=profile,
        workspace_root=workspace_path,
        runtime_spec=runtime_spec,
    )
    read_only_index = command.index("--read-only")
    supplementary_group_env = _supplementary_group_env_value(primary_gid=os.getgid())
    command[read_only_index:read_only_index] = [
        "--env",
        f"{_TARGET_UID_ENV}={os.getuid()}",
        "--env",
        f"{_TARGET_GID_ENV}={os.getgid()}",
        "--env",
        f"{_TARGET_SUPPLEMENTARY_GIDS_ENV}={supplementary_group_env}",
        "--env",
        f"{_BOOTSTRAP_TOKEN_ENV}={bootstrap_token}",
    ]
    start_result = _run_docker_command(command, capture_output=True)
    if _docker_result_is_container_name_conflict(
        start_result,
        container_name=container_name_for_profile(profile.name),
    ) and is_container_running(profile, runtime_metadata=runtime_metadata):
        return
    _check_docker_result(start_result)


def _read_bootstrap_timeout_detail(
    *, profile: profiles.Profile, bootstrap_token: str
) -> str | None:
    failure_detail = _read_current_bootstrap_failure(
        profile=profile,
        bootstrap_token=bootstrap_token,
    )
    if failure_detail is not None:
        return failure_detail
    failure_detail = _read_persisted_bootstrap_failure(
        profile=profile,
        bootstrap_token=bootstrap_token,
    )
    if failure_detail is not None:
        return failure_detail
    return _read_container_logs(profile)


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
        if not _bootstrap_wait_result_is_retryable(result):
            logs = _read_container_logs(profile)
            if logs is not None:
                raise DockerRuntimeError(logs)
            failure_detail = _read_current_bootstrap_failure(
                profile=profile,
                bootstrap_token=bootstrap_token,
            )
            if failure_detail is None:
                failure_detail = _read_persisted_bootstrap_failure(
                    profile=profile,
                    bootstrap_token=bootstrap_token,
                )
            if failure_detail is not None:
                raise DockerRuntimeError(failure_detail)
            detail = (result.stderr or result.stdout or str(result.returncode)).strip()
            raise DockerRuntimeError(detail)

        failure_detail = _read_current_bootstrap_failure(
            profile=profile,
            bootstrap_token=bootstrap_token,
        )
        if failure_detail is None:
            failure_detail = _read_persisted_bootstrap_failure(
                profile=profile,
                bootstrap_token=bootstrap_token,
            )
        if failure_detail is not None:
            raise DockerRuntimeError(failure_detail)
        if time.monotonic() >= deadline:
            timeout_detail = _read_bootstrap_timeout_detail(
                profile=profile,
                bootstrap_token=bootstrap_token,
            )
            if timeout_detail is not None:
                raise DockerRuntimeError(timeout_detail)
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
    result = _run_docker_command(
        [
            "docker",
            "exec",
            tty_flag,
            "--user",
            _root_exec_user_option(),
            "-w",
            workdir,
            container_name_for_profile(profile.name),
            _IDENTITY_OVERLAY_EXEC_PATH,
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
