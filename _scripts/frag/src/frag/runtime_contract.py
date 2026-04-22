from __future__ import annotations

import os
from pathlib import Path

from frag import profiles
from frag.image_assets import RuntimeSpec

BOOTSTRAP_TOKEN_ENV = "FRAG_BOOTSTRAP_TOKEN"
TARGET_UID_ENV = "FRAG_TARGET_UID"
TARGET_GID_ENV = "FRAG_TARGET_GID"
TARGET_SUPPLEMENTARY_GIDS_ENV = "FRAG_TARGET_SUPPLEMENTARY_GIDS"
BOOTSTRAP_TOKEN_RELATIVE_PATH = Path("meta/bootstrap-token")
BOOTSTRAP_STATUS_RELATIVE_PATH = Path("meta/bootstrap-status.json")
BOOTSTRAP_TOKEN_CONTAINER_PATH = "/state/profile/meta/bootstrap-token"
BOOTSTRAP_STATUS_CONTAINER_PATH = "/state/profile/meta/bootstrap-status.json"


def canonical_path(path: Path | str) -> Path:
    return Path(path).expanduser().resolve(strict=False)


def current_supplementary_gids(*, primary_gid: int) -> tuple[int, ...]:
    supplementary_groups: list[int] = []
    for gid in os.getgroups():
        if gid == primary_gid or gid in supplementary_groups:
            continue
        supplementary_groups.append(gid)
    return tuple(supplementary_groups)


def current_runtime_metadata(
    *, runtime_spec: RuntimeSpec
) -> profiles.RuntimeProfileMetadata:
    primary_gid = os.getgid()
    return profiles.RuntimeProfileMetadata(
        image_ref=runtime_spec.image_ref,
        shared_assets_identity=runtime_spec.shared_assets_identity,
        target_uid=str(os.getuid()),
        target_gid=str(primary_gid),
        supplementary_gids=current_supplementary_gids(primary_gid=primary_gid),
    )


def bootstrap_token_path(state_profile: Path | str) -> Path:
    return Path(state_profile) / BOOTSTRAP_TOKEN_RELATIVE_PATH


def bootstrap_status_path(state_profile: Path | str) -> Path:
    return Path(state_profile) / BOOTSTRAP_STATUS_RELATIVE_PATH
