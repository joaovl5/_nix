from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

_BOOTSTRAP_TOKEN_ENV = "FRAG_BOOTSTRAP_TOKEN"
_TARGET_UID_ENV = "FRAG_TARGET_UID"
_TARGET_GID_ENV = "FRAG_TARGET_GID"
_BOOTSTRAP_TOKEN_PATH = Path("meta/bootstrap-token")


_AGENT_BROWSER_DEFAULT_CONFIG = {
    "contentBoundaries": True,
    "maxOutput": 50000,
}

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
    Path("config/code"),
    Path("config/omp"),
    Path("config/agent-browser"),
    Path("config/opencode"),
)
_REQUIRED_FILES: tuple[Path, ...] = (Path("config/agent-browser/config.json"),)


class MappingKind:
    PROFILE = "profile"
    SHARED = "shared"


_HOME_VIEW_MAPPINGS: tuple[tuple[Path, str, Path], ...] = (
    (Path(".agents/skills"), MappingKind.SHARED, Path("agents/skills")),
    (Path(".config/agents/skills"), MappingKind.SHARED, Path("config/agents/skills")),
    (Path(".code/config.toml"), MappingKind.PROFILE, Path("config/code/config.toml")),
    (Path(".code/agents"), MappingKind.SHARED, Path("code/agents")),
    (Path(".code/skills"), MappingKind.SHARED, Path("code/skills")),
    (Path(".code/AGENTS.md"), MappingKind.SHARED, Path("code/AGENTS.md")),
    (Path(".omp/agent/agents"), MappingKind.SHARED, Path("omp/agent/agents")),
    (Path(".omp/agent/skills"), MappingKind.SHARED, Path("omp/agent/skills")),
    (Path(".omp/agent/SYSTEM.md"), MappingKind.SHARED, Path("omp/agent/SYSTEM.md")),
    (Path(".omp/agent/mcp.json"), MappingKind.PROFILE, Path("config/omp/mcp.json")),
    (
        Path(".agent-browser/config.json"),
        MappingKind.PROFILE,
        Path("config/agent-browser/config.json"),
    ),
    (Path(".config/opencode/skill"), MappingKind.SHARED, Path("opencode/skill")),
    (
        Path(".config/opencode/opencode.json"),
        MappingKind.SHARED,
        Path("opencode/opencode.json"),
    ),
    (
        Path(".config/opencode/superpowers"),
        MappingKind.SHARED,
        Path("opencode/superpowers"),
    ),
    (
        Path(".config/opencode/plugins/superpowers.js"),
        MappingKind.SHARED,
        Path("opencode/plugins/superpowers.js"),
    ),
)


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
    token_path = state_profile / _BOOTSTRAP_TOKEN_PATH
    _ensure_directory(token_path.parent)
    token_path.write_text(f"{token}\n")
    token_path.chmod(0o600)


def _symlink_view_entry(destination: Path, source: Path) -> None:
    _ensure_directory(destination.parent)
    if destination.is_symlink() or destination.exists():
        destination.unlink()
    destination.symlink_to(source)


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
    for relative_file in _REQUIRED_FILES:
        _ensure_file(state_profile / relative_file)
    _ensure_text_file(
        state_profile / "config/code/config.toml",
        _CODE_DEFAULT_CONFIG,
    )
    _ensure_json_file(
        state_profile / "config/omp/mcp.json",
        _OMP_DEFAULT_CONFIG,
    )
    _write_json(state_profile / "meta/profile.json", metadata)
    _ensure_json_file(
        state_profile / "config/agent-browser/config.json",
        _AGENT_BROWSER_DEFAULT_CONFIG,
    )

    _ensure_directory(home)
    for destination_relative, mapping_kind, source_relative in _HOME_VIEW_MAPPINGS:
        root = state_profile if mapping_kind == MappingKind.PROFILE else state_shared
        _symlink_view_entry(home / destination_relative, root / source_relative)


def _requested_owner_from_env() -> tuple[int, int] | None:
    uid = os.environ.get(_TARGET_UID_ENV)
    gid = os.environ.get(_TARGET_GID_ENV)
    if uid is None and gid is None:
        return None
    if uid is None or gid is None:
        raise RuntimeError("bootstrap ownership target must set both uid and gid")
    try:
        return int(uid), int(gid)
    except ValueError as exc:
        raise RuntimeError("bootstrap ownership target must be numeric") from exc


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
    parser.add_argument("--keepalive", nargs=argparse.REMAINDER)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = _build_parser().parse_args(argv)
    state_profile = Path(args.state_profile)
    home = Path(args.home)
    initialize_profile_environment(
        state_profile=state_profile,
        state_shared=Path(args.state_shared),
        home=home,
        metadata={
            "profile_name": args.profile_name,
            "profile_image": args.profile_image,
            "workspace_root": args.workspace_root,
        },
    )
    bootstrap_token = os.environ.get(_BOOTSTRAP_TOKEN_ENV)
    if bootstrap_token:
        _write_bootstrap_token(state_profile, bootstrap_token)
    requested_owner = _requested_owner_from_env()
    if requested_owner is not None:
        uid, gid = requested_owner
        _chown_tree(state_profile, uid=uid, gid=gid)
        _chown_tree(home, uid=uid, gid=gid)
    keepalive = args.keepalive or ["sleep", "infinity"]
    os.execvp(keepalive[0], keepalive)
    return 0
