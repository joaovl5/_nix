from __future__ import annotations

import argparse
from enum import StrEnum
import json
import os
from pathlib import Path
import shutil

from frag import runtime_contract, shared_assets_contract

_IDENTITY_OVERLAY_CONTRACT_PATH = Path("meta/identity-overlay.json")
_RUNTIME_IDENTITY_ROOT = Path("/run/frag/identity")
_RUNTIME_IDENTITY_CONTAINER_ROOT = Path("/run/frag/identity")
_EPHEMERAL_CACHE_HOME = Path("/tmp/frag/cache")
_NSS_WRAPPER_LIBRARY = Path("/sw/lib/libnss_wrapper.so")


_CODE_DEFAULT_CONFIG = """approval_policy = \"on-request\"
sandbox_mode = \"workspace-write\"

[mcp_servers.nixos]
command = \"mcp-nixos\"
"""

_OMP_DEFAULT_CONFIG = {
    "$schema": "https://raw.githubusercontent.com/can1357/oh-my-pi/main/packages/coding-agent/src/config/mcp-schema.json",
    "mcpServers": {
        "nixos": {
            "command": "mcp-nixos",
        }
    },
}

_REQUIRED_DIRECTORIES: tuple[Path, ...] = (
    Path("meta"),
    Path("config"),
    Path("notes"),
    Path("home"),
    Path("config/code"),
    Path("config/omp"),
    Path("config/opencode"),
)


class MappingKind(StrEnum):
    PROFILE = "profile"
    SHARED = "shared"


_PROFILE_HOME_VIEW_MAPPINGS: tuple[tuple[Path, MappingKind, Path], ...] = (
    (Path(".code/config.toml"), MappingKind.PROFILE, Path("config/code/config.toml")),
    (Path(".omp/agent/mcp.json"), MappingKind.PROFILE, Path("config/omp/mcp.json")),
)


def _shared_home_view_mappings() -> tuple[tuple[Path, MappingKind, Path], ...]:
    return tuple(
        (destination_relative, MappingKind.SHARED, state_shared_relative)
        for destination_relative, state_shared_relative in shared_assets_contract.shared_home_view_mappings()
    )


def _home_view_mappings() -> tuple[tuple[Path, MappingKind, Path], ...]:
    return (*_shared_home_view_mappings(), *_PROFILE_HOME_VIEW_MAPPINGS)


def _ensure_directory(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)
    path.chmod(0o700)


def _ensure_file(path: Path) -> None:
    _ensure_directory(path.parent)
    path.touch(exist_ok=True)
    path.chmod(0o600)


def _ensure_text_file(path: Path, contents: str) -> None:
    _ensure_directory(path.parent)
    if not path.exists() or path.stat().st_size == 0:
        path.write_text(contents)
    path.chmod(0o600)


def _write_json(path: Path, payload: dict[str, object]) -> None:
    _ensure_directory(path.parent)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
    path.chmod(0o600)


def _ensure_json_file(path: Path, payload: dict[str, object]) -> None:
    _ensure_directory(path.parent)
    if not path.exists() or path.stat().st_size == 0:
        path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
    path.chmod(0o600)


def _write_bootstrap_token(state_profile: Path, token: str) -> None:

    token_path = runtime_contract.bootstrap_token_path(state_profile)
    _ensure_directory(token_path.parent)
    token_path.write_text(f"{token}\n")
    token_path.chmod(0o600)


def _reset_bootstrap_status(state_profile: Path) -> None:
    status_path = runtime_contract.bootstrap_status_path(state_profile)
    if status_path.exists() or status_path.is_symlink():
        status_path.unlink()


def _write_bootstrap_failure(
    state_profile: Path,
    *,
    bootstrap_token: str,
    phase: str,
    message: str,
) -> None:
    _write_json(
        runtime_contract.bootstrap_status_path(state_profile),
        {
            "bootstrap_token": bootstrap_token,
            "message": message,
            "phase": phase,
            "status": "failed",
        },
    )


def _symlink_view_entry(destination: Path, source: Path) -> None:
    _ensure_directory(destination.parent)
    if destination.is_symlink() or destination.exists():
        destination.unlink()
    destination.symlink_to(source)


def _persistent_home_root(state_profile: Path) -> Path:
    return state_profile / "home"


def _ensure_home_alignment(*, home: Path, persistent_home: Path) -> None:
    if home.exists() or home.is_symlink():
        if home.resolve(strict=False) != persistent_home.resolve(strict=False):
            raise RuntimeError(
                f"home path {home} must resolve to persistent profile home {persistent_home}"
            )
        return
    _ensure_directory(home.parent)
    home.symlink_to(persistent_home)


def _ensure_ephemeral_cache(home_root: Path) -> None:
    _ensure_directory(_EPHEMERAL_CACHE_HOME)
    cache_path = home_root / ".cache"
    _symlink_view_entry(cache_path, _EPHEMERAL_CACHE_HOME)


def _remove_path_if_present(path: Path) -> None:
    if path.is_symlink() or path.is_file():
        path.unlink()
        return
    if path.is_dir():
        shutil.rmtree(path)


def _prune_stale_browser_state(*, state_profile: Path, persistent_home: Path) -> None:
    for stale_path in (
        state_profile / "config" / "agent-browser",
        persistent_home / ".agent-browser",
    ):
        _remove_path_if_present(stale_path)


def _setpriv_group_option(supplementary_gids: tuple[int, ...]) -> str:
    if not supplementary_gids:
        return "--clear-groups"
    gids = ",".join(str(gid) for gid in supplementary_gids)
    return f"--groups {gids}"


def _container_root_matches_requested_owner(uid: int, gid: int) -> bool:
    try:
        uid_map = Path("/proc/self/uid_map").read_text().splitlines()
        gid_map = Path("/proc/self/gid_map").read_text().splitlines()
    except OSError:
        return False
    if not uid_map or not gid_map:
        return False

    def _parse_first_mapping(line: str) -> tuple[int, int, int] | None:
        parts = line.split()
        if len(parts) < 3:
            return None
        try:
            return int(parts[0]), int(parts[1]), int(parts[2])
        except ValueError:
            return None

    uid_mapping = _parse_first_mapping(uid_map[0])
    gid_mapping = _parse_first_mapping(gid_map[0])
    if uid_mapping is None or gid_mapping is None:
        return False

    container_uid, host_uid, uid_length = uid_mapping
    container_gid, host_gid, gid_length = gid_mapping
    return (
        container_uid == 0
        and uid_length == 1
        and host_uid == uid
        and container_gid == 0
        and gid_length == 1
        and host_gid == gid
    )


def _write_identity_overlay_contract(
    state_profile: Path,
    *,
    uid: int,
    gid: int,
    supplementary_gids: tuple[int, ...],
) -> None:
    passwd_path = _RUNTIME_IDENTITY_ROOT / "passwd"
    group_path = _RUNTIME_IDENTITY_ROOT / "group"
    exec_path = _RUNTIME_IDENTITY_ROOT / "exec"
    passwd_overlay_path = (_RUNTIME_IDENTITY_CONTAINER_ROOT / "passwd").as_posix()
    group_overlay_path = (_RUNTIME_IDENTITY_CONTAINER_ROOT / "group").as_posix()
    _ensure_directory(passwd_path.parent)
    passwd_path.parent.chmod(0o755)

    if _container_root_matches_requested_owner(uid, gid):
        passwd_contents = "agent:x:0:0:Frag Agent:/home/agent:/sw/bin/fish\n"
        group_contents = "agent:x:0:\n"
        if supplementary_gids:
            exec_command = (
                f'exec setpriv {_setpriv_group_option(supplementary_gids)} -- "$@"\n'
            )
        else:
            exec_command = 'exec "$@"\n'
    else:
        passwd_contents = (
            f"root:x:0:0:root:/root:/sw/bin/fish\n"
            f"agent:x:{uid}:{gid}:Frag Agent:/home/agent:/sw/bin/fish\n"
        )
        group_contents = f"root:x:0:\nagent:x:{gid}:\n"
        exec_command = (
            f"exec setpriv --reuid {uid} --regid {gid} "
            f'{_setpriv_group_option(supplementary_gids)} -- "$@"\n'
        )

    passwd_path.write_text(passwd_contents)
    passwd_path.chmod(0o644)
    group_path.write_text(group_contents)
    group_path.chmod(0o644)
    exec_path.write_text(
        "#!/sw/bin/sh\n"
        "set -eu\n"
        "export HOME=/home/agent\n"
        "export USER=agent\n"
        "export LOGNAME=agent\n"
        f"export NSS_WRAPPER_PASSWD={passwd_overlay_path}\n"
        f"export NSS_WRAPPER_GROUP={group_overlay_path}\n"
        f'export LD_PRELOAD="{_NSS_WRAPPER_LIBRARY}${{LD_PRELOAD:+:${{LD_PRELOAD}}}}"\n'
        f"{exec_command}"
    )
    exec_path.chmod(0o700)
    _write_json(
        state_profile / _IDENTITY_OVERLAY_CONTRACT_PATH,
        {
            "exec_path": (_RUNTIME_IDENTITY_CONTAINER_ROOT / "exec").as_posix(),
            "gid": gid,
            "group": "agent",
            "home": "/home/agent",
            "uid": uid,
            "user": "agent",
        },
    )


def initialize_profile_environment(
    *,
    state_profile: Path,
    state_shared: Path,
    home: Path,
    metadata: dict[str, str],
) -> None:
    _ensure_directory(state_profile)
    for relative_directory in _REQUIRED_DIRECTORIES:
        _ensure_directory(state_profile / relative_directory)
    _ensure_text_file(
        state_profile / "config/code/config.toml",
        _CODE_DEFAULT_CONFIG,
    )
    _ensure_json_file(
        state_profile / "config/omp/mcp.json",
        _OMP_DEFAULT_CONFIG,
    )
    _write_json(state_profile / "meta/profile.json", metadata)

    persistent_home = _persistent_home_root(state_profile)
    _ensure_home_alignment(home=home, persistent_home=persistent_home)
    _prune_stale_browser_state(
        state_profile=state_profile,
        persistent_home=persistent_home,
    )
    _ensure_ephemeral_cache(persistent_home)
    for destination_relative, mapping_kind, source_relative in _home_view_mappings():
        root = state_profile if mapping_kind == MappingKind.PROFILE else state_shared
        _symlink_view_entry(
            persistent_home / destination_relative, root / source_relative
        )


def _requested_owner_from_env() -> tuple[int, int] | None:
    uid = os.environ.get(runtime_contract.TARGET_UID_ENV)
    gid = os.environ.get(runtime_contract.TARGET_GID_ENV)
    if uid is None and gid is None:
        return None
    if uid is None or gid is None:
        raise RuntimeError("bootstrap ownership target must set both uid and gid")
    try:
        return (int(uid), int(gid))
    except ValueError as exc:
        raise RuntimeError("bootstrap ownership target must be numeric") from exc


def _requested_supplementary_gids_from_env(*, primary_gid: int) -> tuple[int, ...]:
    raw_gids = os.environ.get(runtime_contract.TARGET_SUPPLEMENTARY_GIDS_ENV, "")
    if not raw_gids.strip():
        return ()
    supplementary_gids: list[int] = []
    for raw_gid in raw_gids.split(","):
        try:
            gid = int(raw_gid.strip())
        except ValueError as exc:
            raise RuntimeError(
                "bootstrap supplementary gids must be a comma-separated numeric list"
            ) from exc
        if gid == primary_gid or gid in supplementary_gids:
            continue
        supplementary_gids.append(gid)
    return tuple(supplementary_gids)


def _chown_tree(root: Path, *, uid: int, gid: int) -> None:
    if root.is_symlink():
        return
    os.chown(root, uid, gid, follow_symlinks=False)
    for current_root, directory_names, file_names in os.walk(root):
        current_path = Path(current_root)
        for directory_name in directory_names:
            directory_path = current_path / directory_name
            if directory_path.is_symlink():
                continue
            os.chown(directory_path, uid, gid, follow_symlinks=False)
        for file_name in file_names:
            file_path = current_path / file_name
            if file_path.is_symlink():
                continue
            os.chown(file_path, uid, gid, follow_symlinks=False)


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="frag-bootstrap")
    parser.add_argument("--state-profile", default="/state/profile")
    parser.add_argument("--state-shared", default="/state/shared")
    parser.add_argument("--home", default="/home/agent")
    parser.add_argument("--profile-name", required=True)
    parser.add_argument("--profile-image", required=True)
    parser.add_argument("--workspace-root", required=True)
    parser.add_argument("--image-ref", required=True)
    parser.add_argument("--shared-assets-identity", required=True)
    parser.add_argument("--keepalive", nargs=argparse.REMAINDER)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = _build_parser().parse_args(argv)
    state_profile = Path(args.state_profile)
    home = Path(args.home)
    bootstrap_token = os.environ.get(runtime_contract.BOOTSTRAP_TOKEN_ENV, "")
    phase = "startup"
    try:
        _ensure_directory(state_profile)
        _reset_bootstrap_status(state_profile)
        phase = "initialize"
        initialize_profile_environment(
            state_profile=state_profile,
            state_shared=Path(args.state_shared),
            home=home,
            metadata={
                "profile_name": args.profile_name,
                "profile_image": args.profile_image,
                "schema_version": "2",
                "workspace_root": args.workspace_root,
                "image_ref": args.image_ref,
                "shared_assets_identity": args.shared_assets_identity,
            },
        )
        phase = "ownership"
        requested_owner = _requested_owner_from_env()
        if requested_owner is not None:
            uid, gid = requested_owner
            supplementary_gids = _requested_supplementary_gids_from_env(primary_gid=gid)
            phase = "identity"
            _write_identity_overlay_contract(
                state_profile,
                uid=uid,
                gid=gid,
                supplementary_gids=supplementary_gids,
            )
            phase = "ownership"
            _ensure_directory(_EPHEMERAL_CACHE_HOME.parent)
            _ensure_directory(_EPHEMERAL_CACHE_HOME)
            _chown_tree(state_profile, uid=uid, gid=gid)
            _chown_tree(_EPHEMERAL_CACHE_HOME.parent, uid=uid, gid=gid)
        if bootstrap_token:
            phase = "token"
            token_path = state_profile / "meta" / "bootstrap-token"
            _write_bootstrap_token(state_profile, bootstrap_token)
            if requested_owner is not None:
                uid, gid = requested_owner
                os.chown(token_path, uid, gid, follow_symlinks=False)
        keepalive = args.keepalive or ["sleep", "infinity"]
        phase = "keepalive"
        os.execvp(keepalive[0], keepalive)
    except SystemExit:
        raise
    except Exception as exc:
        _write_bootstrap_failure(
            state_profile,
            bootstrap_token=bootstrap_token,
            phase=phase,
            message=str(exc),
        )
        raise
    return 0
