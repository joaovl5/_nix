from __future__ import annotations

from dataclasses import dataclass
import json
from pathlib import Path
import re
import subprocess
from collections.abc import Sequence
from typing import Protocol

LABEL_PROFILE = "frag.profile"
LABEL_IMAGE = "frag.image"
LABEL_WORKSPACE_ROOT = "frag.workspace_root"
LABEL_SCHEMA_VERSION = "frag.schema_version"
SCHEMA_VERSION = "1"
_VOLUME_PREFIX = "frag-profile-"
_REQUIRED_LABELS = (
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


def _run_docker_command(command: Sequence[str]) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(command, check=True, capture_output=True, text=True)
    except FileNotFoundError as exc:
        raise DockerBackendError("docker executable not found") from exc
    except subprocess.CalledProcessError as exc:
        detail = (exc.stderr or exc.stdout or str(exc)).strip()
        raise DockerBackendError(detail) from exc


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


def volume_name_for_profile(name: str) -> str:
    normalized = re.sub(r"[^a-z0-9]+", "-", name.strip().lower()).strip("-")
    if not normalized:
        raise InvalidProfileNameError(
            "profile name must contain at least one alphanumeric character"
        )
    return f"{_VOLUME_PREFIX}{normalized}"


def _profile_labels(profile: Profile) -> dict[str, str]:
    return {
        LABEL_PROFILE: profile.name,
        LABEL_IMAGE: profile.image,
        LABEL_WORKSPACE_ROOT: profile.workspace_root,
        LABEL_SCHEMA_VERSION: SCHEMA_VERSION,
    }


def canonicalize_workspace_root(workspace_root: str) -> str:
    return str(Path(workspace_root).expanduser().resolve(strict=False))


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
    for existing_profile in list_profiles(docker_backend):
        if existing_profile.name == profile.name:
            if existing_profile == profile:
                return existing_profile
            raise ProfileNameCollisionError(f"profile {name!r} already exists")
        if existing_profile.volume_name == normalized_volume_name:
            raise ProfileNameCollisionError(
                f"profile name {name!r} conflicts with existing profile {existing_profile.name!r}"
            )

    docker_backend.create_volume(
        profile.volume_name,
        labels=_profile_labels(profile),
    )
    return profile


def list_profiles(docker_backend: DockerBackend) -> list[Profile]:
    profiles_found: list[Profile] = []
    for volume in docker_backend.list_volumes():
        labels = volume.get("labels")
        if not isinstance(labels, dict):
            continue
        if any(label not in labels for label in _REQUIRED_LABELS):
            continue
        if labels[LABEL_SCHEMA_VERSION] != SCHEMA_VERSION:
            continue
        profiles_found.append(
            Profile(
                name=str(labels[LABEL_PROFILE]),
                image=str(labels[LABEL_IMAGE]),
                workspace_root=str(labels[LABEL_WORKSPACE_ROOT]),
                volume_name=str(volume["name"]),
            )
        )
    return sorted(profiles_found, key=lambda profile: profile.name)


def get_profile(docker_backend: DockerBackend, name: str) -> Profile | None:
    for profile in list_profiles(docker_backend):
        if profile.name == name:
            return profile
    return None


def remove_profile(docker_backend: DockerBackend, name: str) -> None:
    profile = get_profile(docker_backend, name)
    if profile is None:
        raise ProfileNotFoundError(name)
    if docker_backend.is_profile_running(profile.name):
        raise ProfileInUseError(name)
    docker_backend.remove_volume(profile.volume_name)
