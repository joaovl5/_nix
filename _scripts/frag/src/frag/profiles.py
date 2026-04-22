from __future__ import annotations

from dataclasses import dataclass
import json
from pathlib import Path
import re
import subprocess
from collections.abc import Mapping, Sequence
from typing import Protocol

from frag import docker_invoke
from frag.exceptions import LegacySchemaError

LABEL_PROFILE = "frag.profile"
LABEL_IMAGE = "frag.image"
LABEL_WORKSPACE_ROOT = "frag.workspace_root"
LABEL_SCHEMA_VERSION = "frag.schema_version"
LABEL_RUNTIME_IMAGE_REF = "frag.runtime_image_ref"
LABEL_SHARED_ASSETS_IDENTITY = "frag.shared_assets_identity"
LABEL_TARGET_UID = "frag.target_uid"
LABEL_TARGET_GID = "frag.target_gid"
LABEL_TARGET_SUPPLEMENTARY_GIDS = "frag.target_supplementary_gids"
SCHEMA_VERSION = "2"
_VOLUME_PREFIX = "frag-profile-"
_REQUIRED_STABLE_LABELS = (
    LABEL_PROFILE,
    LABEL_IMAGE,
    LABEL_WORKSPACE_ROOT,
    LABEL_SCHEMA_VERSION,
)


class DockerBackend(Protocol):
    def create_volume(self, name: str, labels: dict[str, str]) -> None: ...

    def list_volumes(self) -> list[dict[str, object]]: ...

    def remove_volume(self, name: str) -> None: ...

    def is_profile_running(self, profile_name: str) -> bool: ...


class ProfileError(RuntimeError):
    pass


class DockerBackendError(ProfileError):
    pass


class ProfileNameCollisionError(ProfileError):
    pass


class ProfileInUseError(ProfileError):
    pass


class ProfileNotFoundError(ProfileError):
    pass


class InvalidProfileNameError(ProfileError):
    pass


@dataclass(frozen=True)
class Profile:
    name: str
    image: str
    workspace_root: str
    volume_name: str


@dataclass(frozen=True)
class RuntimeProfileMetadata:
    image_ref: str
    shared_assets_identity: str
    target_uid: str
    target_gid: str
    supplementary_gids: tuple[int, ...] = ()


def _run_docker_command(command: Sequence[str]) -> subprocess.CompletedProcess[str]:
    return docker_invoke.run_docker_command(
        command,
        capture_output=True,
        missing_binary_error=DockerBackendError,
        nonzero_error=DockerBackendError,
        runner=subprocess.run,
    )


class DockerCliBackend:
    def create_volume(self, name: str, labels: dict[str, str]) -> None:
        command = ["docker", "volume", "create"]
        for key, value in labels.items():
            command.extend(["--label", f"{key}={value}"])
        command.append(name)
        _run_docker_command(command)

    def list_volumes(self) -> list[dict[str, object]]:
        ls_result = _run_docker_command(
            [
                "docker",
                "volume",
                "ls",
                "--filter",
                f"label={LABEL_SCHEMA_VERSION}",
                "--format",
                "{{.Name}}",
            ]
        )
        volume_names = [line for line in ls_result.stdout.splitlines() if line]
        if not volume_names:
            return []
        inspect_result = _run_docker_command(
            ["docker", "volume", "inspect", *volume_names]
        )
        volumes = json.loads(inspect_result.stdout)
        return [
            {
                "name": volume["Name"],
                "labels": volume.get("Labels") or {},
            }
            for volume in volumes
        ]

    def remove_volume(self, name: str) -> None:
        _run_docker_command(["docker", "volume", "rm", name])

    def is_profile_running(self, profile_name: str) -> bool:
        result = _run_docker_command(
            [
                "docker",
                "ps",
                "--filter",
                f"label={LABEL_PROFILE}={profile_name}",
                "--format",
                "{{.ID}}",
            ]
        )
        return bool(result.stdout.strip())


@dataclass(frozen=True)
class StableProfileMetadata:
    profile_name: str
    profile_image: str
    workspace_root: str
    schema_version: str = SCHEMA_VERSION

    def as_labels(self) -> dict[str, str]:
        return {
            LABEL_PROFILE: self.profile_name,
            LABEL_IMAGE: self.profile_image,
            LABEL_WORKSPACE_ROOT: self.workspace_root,
            LABEL_SCHEMA_VERSION: self.schema_version,
        }

    def as_profile_json(self) -> dict[str, str]:
        return {
            "profile_name": self.profile_name,
            "profile_image": self.profile_image,
            "schema_version": self.schema_version,
            "workspace_root": self.workspace_root,
        }


def runtime_metadata_labels(runtime_metadata: RuntimeProfileMetadata) -> dict[str, str]:
    supplementary_gids = ",".join(
        str(gid) for gid in runtime_metadata.supplementary_gids
    )
    return {
        LABEL_RUNTIME_IMAGE_REF: runtime_metadata.image_ref,
        LABEL_SHARED_ASSETS_IDENTITY: runtime_metadata.shared_assets_identity,
        LABEL_TARGET_UID: runtime_metadata.target_uid,
        LABEL_TARGET_GID: runtime_metadata.target_gid,
        LABEL_TARGET_SUPPLEMENTARY_GIDS: supplementary_gids,
    }


def runtime_metadata_from_labels(
    labels: Mapping[str, object],
) -> RuntimeProfileMetadata | None:
    image_ref = labels.get(LABEL_RUNTIME_IMAGE_REF)
    shared_assets_identity = labels.get(LABEL_SHARED_ASSETS_IDENTITY)
    target_uid = labels.get(LABEL_TARGET_UID)
    target_gid = labels.get(LABEL_TARGET_GID)
    raw_supplementary_gids = labels.get(LABEL_TARGET_SUPPLEMENTARY_GIDS)
    if not all(
        isinstance(value, str)
        for value in (
            image_ref,
            shared_assets_identity,
            target_uid,
            target_gid,
            raw_supplementary_gids,
        )
    ):
        return None
    try:
        supplementary_gids = tuple(
            int(raw_gid) for raw_gid in raw_supplementary_gids.split(",") if raw_gid
        )
    except ValueError:
        return None
    return RuntimeProfileMetadata(
        image_ref=image_ref,
        shared_assets_identity=shared_assets_identity,
        target_uid=target_uid,
        target_gid=target_gid,
        supplementary_gids=supplementary_gids,
    )


def stable_profile_metadata(profile: Profile) -> StableProfileMetadata:
    return StableProfileMetadata(
        profile_name=profile.name,
        profile_image=profile.image,
        workspace_root=profile.workspace_root,
    )


def ensure_supported_schema(labels: Mapping[str, object], *, subject: str) -> str:
    schema_version = labels.get(LABEL_SCHEMA_VERSION)
    if schema_version == "1":
        profile_name = labels.get(LABEL_PROFILE)
        profile_detail = (
            f" for {profile_name!r}" if isinstance(profile_name, str) else ""
        )
        raise LegacySchemaError(
            f"legacy schema 1 {subject}{profile_detail} is not supported; remove it and recreate the profile"
        )
    if not isinstance(schema_version, str):
        raise ProfileError(f"{subject} is missing required schema metadata")
    if schema_version != SCHEMA_VERSION:
        raise ProfileError(
            f"unsupported {subject} schema version {schema_version!r}; expected {SCHEMA_VERSION!r}"
        )
    return schema_version


def volume_name_for_profile(name: str) -> str:
    normalized = re.sub(r"[^a-z0-9]+", "-", name.strip().lower()).strip("-")
    if not normalized:
        raise InvalidProfileNameError(
            "profile name must contain at least one alphanumeric character"
        )
    return f"{_VOLUME_PREFIX}{normalized}"


def canonicalize_workspace_root(workspace_root: str) -> str:
    try:
        resolved = Path(workspace_root).expanduser().resolve(strict=True)
    except FileNotFoundError as exc:
        raise ProfileError("workspace root must be an existing directory") from exc
    if not resolved.is_dir():
        raise ProfileError("workspace root must be an existing directory")
    return str(resolved)


def _iter_profile_volumes(
    docker_backend: DockerBackend,
) -> Sequence[tuple[str, Mapping[str, object]]]:
    profile_volumes: list[tuple[str, Mapping[str, object]]] = []
    for volume in docker_backend.list_volumes():
        volume_name = volume.get("name")
        labels = volume.get("labels")
        if not isinstance(volume_name, str) or not isinstance(labels, dict):
            continue
        if LABEL_PROFILE not in labels:
            continue
        profile_volumes.append((volume_name, labels))
    return profile_volumes


def _profile_from_volume(
    *, volume_name: str, labels: Mapping[str, object]
) -> Profile | None:
    if any(label not in labels for label in _REQUIRED_STABLE_LABELS):
        return None
    return Profile(
        name=str(labels[LABEL_PROFILE]),
        image=str(labels[LABEL_IMAGE]),
        workspace_root=str(labels[LABEL_WORKSPACE_ROOT]),
        volume_name=volume_name,
    )


def create_profile(
    docker_backend: DockerBackend,
    *,
    name: str,
    image: str,
    workspace_root: str,
) -> Profile:
    normalized_volume_name = volume_name_for_profile(name)
    profile = Profile(
        name=name,
        image=image,
        workspace_root=canonicalize_workspace_root(workspace_root),
        volume_name=normalized_volume_name,
    )
    for volume_name, labels in _iter_profile_volumes(docker_backend):
        same_name = labels.get(LABEL_PROFILE) == profile.name
        same_volume = volume_name == normalized_volume_name
        if not (same_name or same_volume):
            continue
        ensure_supported_schema(labels, subject="profile volume")
        existing_profile = _profile_from_volume(volume_name=volume_name, labels=labels)
        if existing_profile is None:
            continue
        if existing_profile.name == profile.name:
            if existing_profile == profile:
                return existing_profile
            raise ProfileNameCollisionError(f"profile {name!r} already exists")
        raise ProfileNameCollisionError(
            f"profile name {name!r} conflicts with existing profile {existing_profile.name!r}"
        )

    docker_backend.create_volume(
        profile.volume_name,
        labels=stable_profile_metadata(profile).as_labels(),
    )
    return profile


def list_profiles(docker_backend: DockerBackend) -> list[Profile]:
    profiles_found: list[Profile] = []
    for volume_name, labels in _iter_profile_volumes(docker_backend):
        # Ignore unrelated unsupported volumes so healthy profiles remain usable.
        if labels.get(LABEL_SCHEMA_VERSION) != SCHEMA_VERSION:
            continue
        profile = _profile_from_volume(volume_name=volume_name, labels=labels)
        if profile is None:
            continue
        profiles_found.append(profile)
    return sorted(profiles_found, key=lambda profile: profile.name)


def get_profile(docker_backend: DockerBackend, name: str) -> Profile | None:
    for volume_name, labels in _iter_profile_volumes(docker_backend):
        if labels.get(LABEL_PROFILE) != name:
            continue
        ensure_supported_schema(labels, subject="profile volume")
        profile = _profile_from_volume(volume_name=volume_name, labels=labels)
        if profile is None:
            continue
        return profile
    return None


def remove_profile(docker_backend: DockerBackend, name: str) -> None:
    profile = get_profile(docker_backend, name)
    if profile is None:
        raise ProfileNotFoundError(name)
    if docker_backend.is_profile_running(profile.name):
        raise ProfileInUseError(name)
    docker_backend.remove_volume(profile.volume_name)
