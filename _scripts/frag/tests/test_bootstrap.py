from __future__ import annotations

import json
import os
import shutil
import stat
from pathlib import Path
import tomllib

import pytest

from frag import bootstrap, runtime_contract

_EXPECTED_OPENCODE_CONFIG = {
    "$schema": "https://opencode.ai/config.json",
    "mcp": {
        "nixos": {
            "command": ["mcp-nixos"],
            "enabled": True,
            "type": "local",
        }
    },
    "plugin": [
        "@gotgenes/opencode-agent-identity",
        "opencode-agent-skills",
    ],
}


_EXPECTED_CODE_CONFIG = {
    "approval_policy": "on-request",
    "sandbox_mode": "workspace-write",
    "mcp_servers": {
        "nixos": {
            "command": "mcp-nixos",
        }
    },
}

_EXPECTED_OMP_CONFIG = {
    "$schema": "https://raw.githubusercontent.com/can1357/oh-my-pi/main/packages/coding-agent/src/config/mcp-schema.json",
    "mcpServers": {
        "nixos": {
            "command": "mcp-nixos",
        }
    },
}


def _mode(path: Path) -> int:
    return stat.S_IMODE(path.stat().st_mode)


def _prepare_home_view(*, state_profile: Path, home: Path) -> None:
    home.parent.mkdir(parents=True, exist_ok=True)
    home.symlink_to(state_profile / "home")


def test_initialize_profile_state_creates_expected_directories_and_symlinks(
    tmp_path: Path,
) -> None:
    state_profile = tmp_path / "state" / "profile"
    state_shared = tmp_path / "state" / "shared"
    home = tmp_path / "home" / "agent"
    _prepare_home_view(state_profile=state_profile, home=home)

    (state_shared / "code" / "agents").mkdir(parents=True)
    (state_shared / "config" / "agents" / "skills").mkdir(parents=True)
    (state_shared / "opencode" / "skill").mkdir(parents=True)
    (state_shared / "opencode" / "opencode.json").write_text(
        json.dumps(_EXPECTED_OPENCODE_CONFIG) + "\n"
    )
    (state_shared / "omp" / "agent").mkdir(parents=True)

    metadata = {
        "profile_name": "demo",
        "profile_image": "python:3.14",
        "schema_version": "2",
        "workspace_root": "/workspace/demo",
        "image_ref": "loaded:image",
        "shared_assets_identity": "shared-assets-123",
    }

    bootstrap.initialize_profile_environment(
        state_profile=state_profile,
        state_shared=state_shared,
        home=home,
        metadata=metadata,
    )

    assert (state_profile / "meta").is_dir()
    assert (state_profile / "config").is_dir()
    assert (state_profile / "notes").is_dir()
    assert (state_profile / "home").is_dir()
    assert _mode(state_profile / "meta") == 0o700
    assert _mode(state_profile / "config") == 0o700
    assert _mode(state_profile / "notes") == 0o700
    assert _mode(state_profile / "home") == 0o700

    profile_json = state_profile / "meta" / "profile.json"
    assert json.loads(profile_json.read_text()) == metadata
    assert _mode(profile_json) == 0o600

    code_config = state_profile / "config" / "code" / "config.toml"
    omp_config = state_profile / "config" / "omp" / "mcp.json"
    assert not (state_profile / "config" / "agent-browser").exists()

    assert home.is_symlink()
    assert home.resolve() == (state_profile / "home").resolve()
    assert (home / ".cache").is_symlink()
    assert (home / ".cache").readlink() == bootstrap._EPHEMERAL_CACHE_HOME
    assert not str((home / ".cache").resolve()).startswith(str(state_profile.resolve()))
    assert (home / ".code" / "config.toml").is_symlink()
    assert (home / ".code" / "config.toml").resolve() == code_config.resolve()
    assert (home / ".code" / "agents").is_symlink()
    assert (home / ".code" / "agents").resolve() == (
        state_shared / "code" / "agents"
    ).resolve()
    assert (home / ".config" / "agents" / "skills").is_symlink()
    assert (home / ".config" / "agents" / "skills").resolve() == (
        state_shared / "config" / "agents" / "skills"
    ).resolve()
    assert (home / ".config" / "opencode" / "skill").is_symlink()
    assert (home / ".config" / "opencode" / "skill").resolve() == (
        state_shared / "opencode" / "skill"
    ).resolve()
    assert (home / ".config" / "opencode" / "opencode.json").is_symlink()
    assert (home / ".config" / "opencode" / "opencode.json").resolve() == (
        state_shared / "opencode" / "opencode.json"
    ).resolve()
    assert (
        json.loads((home / ".config" / "opencode" / "opencode.json").read_text())
        == _EXPECTED_OPENCODE_CONFIG
    )
    assert (home / ".omp" / "agent" / "mcp.json").is_symlink()
    assert (home / ".omp" / "agent" / "mcp.json").resolve() == omp_config.resolve()
    assert not (home / ".agent-browser").exists()


def test_initialize_profile_environment_is_idempotent_preserves_mutable_home_state_and_prunes_stale_browser_state(
    tmp_path: Path,
) -> None:
    state_profile = tmp_path / "state" / "profile"
    state_shared = tmp_path / "state" / "shared"
    home = tmp_path / "home" / "agent"
    _prepare_home_view(state_profile=state_profile, home=home)
    (state_shared / "code" / "agents").mkdir(parents=True)

    metadata = {
        "profile_name": "demo",
        "profile_image": "python:3.14",
        "schema_version": "2",
        "workspace_root": "/workspace/demo",
        "image_ref": "loaded:image",
        "shared_assets_identity": "shared-assets-123",
    }

    bootstrap.initialize_profile_environment(
        state_profile=state_profile,
        state_shared=state_shared,
        home=home,
        metadata=metadata,
    )

    profile_json = state_profile / "meta" / "profile.json"
    profile_json.chmod(0o644)
    (state_profile / "config").chmod(0o755)
    code_config = state_profile / "config" / "code" / "config.toml"
    code_config.write_text('approval_policy = "never"\n')
    code_config.chmod(0o600)
    omp_config = state_profile / "config" / "omp" / "mcp.json"
    omp_config.write_text(
        json.dumps({"mcpServers": {"custom": {"command": "custom"}}}) + "\n"
    )
    omp_config.chmod(0o600)
    persisted_file = state_profile / "home" / ".local" / "state.txt"
    persisted_file.parent.mkdir(parents=True, exist_ok=True)
    persisted_file.write_text("persist me\n")
    stale_profile_browser_state = state_profile / "config" / "agent-browser"
    stale_profile_browser_state.mkdir(parents=True)
    (stale_profile_browser_state / "session.json").write_text("{}\n")
    stale_home_browser_state = state_profile / "home" / ".agent-browser"
    stale_home_browser_state.mkdir(parents=True)
    (stale_home_browser_state / "session.json").write_text("{}\n")

    bootstrap.initialize_profile_environment(
        state_profile=state_profile,
        state_shared=state_shared,
        home=home,
        metadata=metadata,
    )

    assert _mode(profile_json) == 0o600
    assert _mode(state_profile / "config") == 0o700
    assert tomllib.loads(code_config.read_text()) == {
        "approval_policy": "never",
    }
    assert json.loads(omp_config.read_text()) == {
        "mcpServers": {"custom": {"command": "custom"}},
    }
    assert not stale_profile_browser_state.exists()
    assert not stale_home_browser_state.exists()
    assert persisted_file.read_text() == "persist me\n"
    assert (home / ".cache").is_symlink()
    assert (home / ".cache").readlink() == bootstrap._EPHEMERAL_CACHE_HOME


def test_main_initializes_environment_clears_stale_status_and_execs_keepalive(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    state_profile = tmp_path / "state" / "profile"
    state_shared = tmp_path / "state" / "shared"
    home = tmp_path / "home" / "agent"
    _prepare_home_view(state_profile=state_profile, home=home)
    (state_shared / "code" / "agents").mkdir(parents=True)
    stale_status = state_profile / "meta" / "bootstrap-status.json"
    stale_status.parent.mkdir(parents=True)
    stale_status.write_text('{"status":"failed"}\n')

    captured: dict[str, object] = {}

    def fake_execvp(program: str, args: list[str]) -> None:
        captured["program"] = program
        captured["args"] = args
        raise SystemExit(0)

    monkeypatch.setattr(bootstrap.os, "execvp", fake_execvp)
    monkeypatch.setenv("FRAG_BOOTSTRAP_TOKEN", "token-123")

    with pytest.raises(SystemExit) as excinfo:
        bootstrap.main(
            [
                "--state-profile",
                str(state_profile),
                "--state-shared",
                str(state_shared),
                "--home",
                str(home),
                "--profile-name",
                "demo",
                "--profile-image",
                "python:3.14",
                "--workspace-root",
                "/workspace/demo",
                "--image-ref",
                "loaded:image",
                "--shared-assets-identity",
                "shared-assets-123",
                "--keepalive",
                "sleep",
                "infinity",
            ]
        )

    assert excinfo.value.code == 0
    assert json.loads((state_profile / "meta" / "profile.json").read_text()) == {
        "profile_name": "demo",
        "profile_image": "python:3.14",
        "schema_version": "2",
        "workspace_root": "/workspace/demo",
        "image_ref": "loaded:image",
        "shared_assets_identity": "shared-assets-123",
    }
    assert (state_profile / "meta" / "bootstrap-token").read_text() == "token-123\n"
    assert not stale_status.exists()
    assert captured == {"program": "sleep", "args": ["sleep", "infinity"]}


def test_main_writes_token_scoped_bootstrap_failure_status(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    state_profile = tmp_path / "state" / "profile"
    state_shared = tmp_path / "state" / "shared"
    home = tmp_path / "home" / "agent"
    _prepare_home_view(state_profile=state_profile, home=home)
    (state_shared / "code" / "agents").mkdir(parents=True)
    status_path = state_profile / "meta" / "bootstrap-status.json"
    status_path.parent.mkdir(parents=True)
    status_path.write_text('{"status":"stale","bootstrap_token":"old-token"}\n')

    monkeypatch.setenv("FRAG_BOOTSTRAP_TOKEN", "token-456")
    monkeypatch.setenv("FRAG_TARGET_UID", "1234")

    with pytest.raises(RuntimeError, match="must set both uid and gid"):
        bootstrap.main(
            [
                "--state-profile",
                str(state_profile),
                "--state-shared",
                str(state_shared),
                "--home",
                str(home),
                "--profile-name",
                "demo",
                "--profile-image",
                "python:3.14",
                "--workspace-root",
                "/workspace/demo",
                "--image-ref",
                "loaded:image",
                "--shared-assets-identity",
                "shared-assets-123",
            ]
        )

    assert json.loads(status_path.read_text()) == {
        "bootstrap_token": "token-456",
        "message": "bootstrap ownership target must set both uid and gid",
        "phase": "ownership",
        "status": "failed",
    }


def test_main_applies_target_ownership_to_profile_and_home(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    state_profile = tmp_path / "state" / "profile"
    state_shared = tmp_path / "state" / "shared"
    home = tmp_path / "home" / "agent"
    runtime_identity_root = tmp_path / "run" / "frag" / "identity"
    _prepare_home_view(state_profile=state_profile, home=home)
    (state_shared / "code" / "agents").mkdir(parents=True)

    chown_calls: list[tuple[Path, int, int, bool]] = []

    def fake_execvp(program: str, args: list[str]) -> None:
        raise SystemExit(0)

    def fake_chown(
        path: str | Path, uid: int, gid: int, *, follow_symlinks: bool = True
    ) -> None:
        chown_calls.append((Path(path), uid, gid, follow_symlinks))

    monkeypatch.setattr(bootstrap, "_RUNTIME_IDENTITY_ROOT", runtime_identity_root)
    monkeypatch.setattr(bootstrap.os, "execvp", fake_execvp)
    monkeypatch.setattr(bootstrap.os, "chown", fake_chown)
    monkeypatch.setenv("FRAG_BOOTSTRAP_TOKEN", "token-123")
    monkeypatch.setenv("FRAG_TARGET_UID", "1234")
    monkeypatch.setenv("FRAG_TARGET_GID", "5678")
    monkeypatch.setenv("FRAG_TARGET_SUPPLEMENTARY_GIDS", "2001,2002")

    with pytest.raises(SystemExit):
        bootstrap.main(
            [
                "--state-profile",
                str(state_profile),
                "--state-shared",
                str(state_shared),
                "--home",
                str(home),
                "--profile-name",
                "demo",
                "--profile-image",
                "python:3.14",
                "--workspace-root",
                "/workspace/demo",
                "--image-ref",
                "loaded:image",
                "--shared-assets-identity",
                "shared-assets-123",
            ]
        )

    chowned_paths = {
        path
        for path, uid, gid, follow_symlinks in chown_calls
        if uid == 1234 and gid == 5678 and follow_symlinks is False
    }
    assert state_profile in chowned_paths
    assert state_profile / "meta" / "profile.json" in chowned_paths
    assert state_profile / "home" in chowned_paths
    assert state_profile / "home" / ".code" in chowned_paths
    assert state_profile / "home" / ".code" / "config.toml" not in chowned_paths
    assert runtime_identity_root not in chowned_paths
    assert runtime_identity_root / "exec" not in chowned_paths
    assert runtime_identity_root / "passwd" not in chowned_paths
    assert runtime_identity_root / "group" not in chowned_paths
    assert state_profile / "meta" / "bootstrap-token" in chowned_paths
    assert (state_profile / "meta" / "bootstrap-token").read_text() == "token-123\n"


def test_main_does_not_chown_persistent_home_separately(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    state_profile = tmp_path / "state" / "profile"
    state_shared = tmp_path / "state" / "shared"
    home = tmp_path / "home" / "agent"
    ephemeral_cache = tmp_path / "tmp" / "frag" / "cache"
    runtime_identity_root = tmp_path / "run" / "frag" / "identity"
    _prepare_home_view(state_profile=state_profile, home=home)
    (state_shared / "code" / "agents").mkdir(parents=True)

    chown_tree_roots: list[tuple[Path, int, int]] = []

    def fake_execvp(program: str, args: list[str]) -> None:
        raise SystemExit(0)

    def fake_chown_tree(root: Path, *, uid: int, gid: int) -> None:
        chown_tree_roots.append((root, uid, gid))

    monkeypatch.setattr(bootstrap, "_EPHEMERAL_CACHE_HOME", ephemeral_cache)
    monkeypatch.setattr(bootstrap, "_RUNTIME_IDENTITY_ROOT", runtime_identity_root)
    monkeypatch.setattr(bootstrap.os, "execvp", fake_execvp)
    monkeypatch.setattr(bootstrap.os, "chown", lambda *_args, **_kwargs: None)
    monkeypatch.setattr(bootstrap, "_chown_tree", fake_chown_tree)
    monkeypatch.setenv("FRAG_TARGET_UID", "1234")
    monkeypatch.setenv("FRAG_TARGET_GID", "5678")

    with pytest.raises(SystemExit):
        bootstrap.main(
            [
                "--state-profile",
                str(state_profile),
                "--state-shared",
                str(state_shared),
                "--home",
                str(home),
                "--profile-name",
                "demo",
                "--profile-image",
                "python:3.14",
                "--workspace-root",
                "/workspace/demo",
                "--image-ref",
                "loaded:image",
                "--shared-assets-identity",
                "shared-assets-123",
            ]
        )

    assert chown_tree_roots == [
        (state_profile, 1234, 5678),
        (ephemeral_cache.parent, 1234, 5678),
    ]


def test_main_applies_target_ownership_to_ephemeral_cache_root(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    state_profile = tmp_path / "state" / "profile"
    state_shared = tmp_path / "state" / "shared"
    home = tmp_path / "home" / "agent"
    _prepare_home_view(state_profile=state_profile, home=home)
    (state_shared / "code" / "agents").mkdir(parents=True)

    ephemeral_cache = tmp_path / "tmp" / "frag" / "cache"
    runtime_identity_root = tmp_path / "run" / "frag" / "identity"
    chown_calls: list[tuple[Path, int, int, bool]] = []

    def fake_execvp(program: str, args: list[str]) -> None:
        raise SystemExit(0)

    def fake_chown(
        path: str | Path, uid: int, gid: int, *, follow_symlinks: bool = True
    ) -> None:
        chown_calls.append((Path(path), uid, gid, follow_symlinks))

    monkeypatch.setattr(bootstrap, "_EPHEMERAL_CACHE_HOME", ephemeral_cache)
    monkeypatch.setattr(bootstrap, "_RUNTIME_IDENTITY_ROOT", runtime_identity_root)
    monkeypatch.setattr(bootstrap.os, "execvp", fake_execvp)
    monkeypatch.setattr(bootstrap.os, "chown", fake_chown)
    monkeypatch.setenv("FRAG_TARGET_UID", "1234")
    monkeypatch.setenv("FRAG_TARGET_GID", "5678")

    with pytest.raises(SystemExit):
        bootstrap.main(
            [
                "--state-profile",
                str(state_profile),
                "--state-shared",
                str(state_shared),
                "--home",
                str(home),
                "--profile-name",
                "demo",
                "--profile-image",
                "python:3.14",
                "--workspace-root",
                "/workspace/demo",
                "--image-ref",
                "loaded:image",
                "--shared-assets-identity",
                "shared-assets-123",
            ]
        )

    chowned_paths = {
        path
        for path, uid, gid, follow_symlinks in chown_calls
        if uid == 1234 and gid == 5678 and follow_symlinks is False
    }
    assert ephemeral_cache.parent in chowned_paths
    assert ephemeral_cache in chowned_paths
    assert (home / ".cache").readlink() == ephemeral_cache


def test_main_recursively_repairs_profile_when_existing_profile_roots_match_requested_owner(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    state_profile = tmp_path / "state" / "profile"
    state_shared = tmp_path / "state" / "shared"
    home = tmp_path / "home" / "agent"
    ephemeral_cache = tmp_path / "tmp" / "frag" / "cache"
    runtime_identity_root = tmp_path / "run" / "frag" / "identity"
    _prepare_home_view(state_profile=state_profile, home=home)
    (state_shared / "code" / "agents").mkdir(parents=True)

    bootstrap.initialize_profile_environment(
        state_profile=state_profile,
        state_shared=state_shared,
        home=home,
        metadata={
            "profile_name": "demo",
            "profile_image": "python:3.14",
            "schema_version": "2",
            "workspace_root": "/workspace/demo",
            "image_ref": "loaded:image",
            "shared_assets_identity": "shared-assets-123",
        },
    )
    shutil.rmtree(state_profile / "home")

    chown_tree_roots: list[tuple[Path, int, int]] = []

    def fake_execvp(program: str, args: list[str]) -> None:
        raise SystemExit(0)

    def fake_chown_tree(root: Path, *, uid: int, gid: int) -> None:
        chown_tree_roots.append((root, uid, gid))

    target_uid = os.getuid()
    target_gid = os.getgid()

    monkeypatch.setattr(bootstrap, "_EPHEMERAL_CACHE_HOME", ephemeral_cache)
    monkeypatch.setattr(bootstrap, "_RUNTIME_IDENTITY_ROOT", runtime_identity_root)
    monkeypatch.setattr(bootstrap.os, "execvp", fake_execvp)
    monkeypatch.setattr(bootstrap.os, "chown", lambda *_args, **_kwargs: None)
    monkeypatch.setattr(bootstrap, "_chown_tree", fake_chown_tree)
    monkeypatch.setenv("FRAG_TARGET_UID", str(target_uid))
    monkeypatch.setenv("FRAG_TARGET_GID", str(target_gid))

    with pytest.raises(SystemExit):
        bootstrap.main(
            [
                "--state-profile",
                str(state_profile),
                "--state-shared",
                str(state_shared),
                "--home",
                str(home),
                "--profile-name",
                "demo",
                "--profile-image",
                "python:3.14",
                "--workspace-root",
                "/workspace/demo",
                "--image-ref",
                "loaded:image",
                "--shared-assets-identity",
                "shared-assets-123",
            ]
        )

    assert chown_tree_roots == [
        (state_profile, target_uid, target_gid),
        (ephemeral_cache.parent, target_uid, target_gid),
    ]


def test_write_identity_overlay_contract_activates_passwd_group_overlay(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    state_profile = tmp_path / "state" / "profile"
    runtime_identity_root = tmp_path / "run" / "frag" / "identity"

    monkeypatch.setattr(bootstrap, "_RUNTIME_IDENTITY_ROOT", runtime_identity_root)
    bootstrap._write_identity_overlay_contract(
        state_profile, uid=1234, gid=5678, supplementary_gids=(2001, 2002)
    )

    exec_script = (runtime_identity_root / "exec").read_text()
    passwd_text = (runtime_identity_root / "passwd").read_text()
    assert exec_script.startswith("#!/sw/bin/sh\n")
    assert "export NSS_WRAPPER_PASSWD=/run/frag/identity/passwd" in exec_script
    assert "export NSS_WRAPPER_GROUP=/run/frag/identity/group" in exec_script
    assert 'export LD_PRELOAD="/sw/lib/libnss_wrapper.so' in exec_script
    assert 'setpriv --reuid 1234 --regid 5678 --groups 2001,2002 -- "$@"' in exec_script
    assert "--clear-groups" not in exec_script
    assert "/sw/bin/fish" in passwd_text


def test_container_root_matches_requested_owner_for_rootless_maps(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    uid_map = tmp_path / "proc" / "self" / "uid_map"
    gid_map = tmp_path / "proc" / "self" / "gid_map"
    uid_map.parent.mkdir(parents=True)
    uid_map.write_text(
        "         0       1000          1\n         1     100000      65536\n"
    )
    gid_map.write_text(
        "         0        100          1\n         1     100000      65536\n"
    )

    def fake_path(pathlike: str | Path) -> Path:
        requested = Path(pathlike)
        if requested == Path("/proc/self/uid_map"):
            return uid_map
        if requested == Path("/proc/self/gid_map"):
            return gid_map
        return requested

    monkeypatch.setattr(bootstrap, "Path", fake_path)

    assert bootstrap._container_root_matches_requested_owner(1000, 100) is True
    assert bootstrap._container_root_matches_requested_owner(1234, 100) is False


def test_requested_owner_from_env_rejects_non_numeric_values(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv(runtime_contract.TARGET_UID_ENV, "nope")
    monkeypatch.setenv(runtime_contract.TARGET_GID_ENV, "5678")

    with pytest.raises(
        RuntimeError,
        match="bootstrap ownership target must be numeric",
    ):
        bootstrap._requested_owner_from_env()


def test_requested_supplementary_gids_from_env_returns_empty_for_blank(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv(runtime_contract.TARGET_SUPPLEMENTARY_GIDS_ENV, "   ")

    assert bootstrap._requested_supplementary_gids_from_env(primary_gid=5678) == ()


def test_requested_supplementary_gids_from_env_skips_primary_and_duplicates(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv(
        runtime_contract.TARGET_SUPPLEMENTARY_GIDS_ENV,
        " 2001, 5678,2002,2001, 2002 ",
    )

    assert bootstrap._requested_supplementary_gids_from_env(primary_gid=5678) == (
        2001,
        2002,
    )


def test_requested_supplementary_gids_from_env_rejects_non_numeric_values(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv(runtime_contract.TARGET_SUPPLEMENTARY_GIDS_ENV, "2001,nope")

    with pytest.raises(
        RuntimeError,
        match="bootstrap supplementary gids must be a comma-separated numeric list",
    ):
        bootstrap._requested_supplementary_gids_from_env(primary_gid=5678)


def test_chown_tree_skips_symlinks_during_recursive_walk(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    root = tmp_path / "tree"
    real_dir = root / "real-dir"
    real_file = real_dir / "file.txt"
    symlinked_dir = root / "dir-link"
    symlinked_file = root / "file-link"
    root.mkdir()
    real_dir.mkdir()
    real_file.write_text("payload\n")
    symlinked_dir.symlink_to(real_dir, target_is_directory=True)
    symlinked_file.symlink_to(real_file)
    chown_calls: list[tuple[Path, int, int, bool]] = []

    def fake_chown(
        path: str | Path, uid: int, gid: int, *, follow_symlinks: bool = True
    ) -> None:
        chown_calls.append((Path(path), uid, gid, follow_symlinks))

    monkeypatch.setattr(bootstrap.os, "chown", fake_chown)

    bootstrap._chown_tree(root, uid=1234, gid=5678)

    chowned_paths = {
        path
        for path, uid, gid, follow_symlinks in chown_calls
        if uid == 1234 and gid == 5678 and follow_symlinks is False
    }
    assert root in chowned_paths
    assert real_dir in chowned_paths
    assert real_file in chowned_paths
    assert symlinked_dir not in chowned_paths
    assert symlinked_file not in chowned_paths


def test_write_identity_overlay_contract_uses_container_root_for_rootless_owner(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    state_profile = tmp_path / "state" / "profile"
    runtime_identity_root = tmp_path / "run" / "frag" / "identity"

    monkeypatch.setattr(bootstrap, "_RUNTIME_IDENTITY_ROOT", runtime_identity_root)
    monkeypatch.setattr(
        bootstrap,
        "_container_root_matches_requested_owner",
        lambda uid, gid: (uid, gid) == (1234, 5678),
    )
    bootstrap._write_identity_overlay_contract(
        state_profile, uid=1234, gid=5678, supplementary_gids=()
    )

    exec_script = (runtime_identity_root / "exec").read_text()
    passwd_text = (runtime_identity_root / "passwd").read_text()

    assert "setpriv" not in exec_script
    assert exec_script.rstrip().endswith('exec "$@"')
    assert "agent:x:0:0:Frag Agent:/home/agent:/sw/bin/fish" in passwd_text


def test_write_identity_overlay_contract_rootless_owner_keeps_supplementary_groups(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    state_profile = tmp_path / "state" / "profile"
    runtime_identity_root = tmp_path / "run" / "frag" / "identity"

    monkeypatch.setattr(bootstrap, "_RUNTIME_IDENTITY_ROOT", runtime_identity_root)
    monkeypatch.setattr(
        bootstrap,
        "_container_root_matches_requested_owner",
        lambda uid, gid: (uid, gid) == (1234, 5678),
    )
    bootstrap._write_identity_overlay_contract(
        state_profile, uid=1234, gid=5678, supplementary_gids=(2001, 2002)
    )

    exec_script = (runtime_identity_root / "exec").read_text()

    assert 'setpriv --groups 2001,2002 -- "$@"' in exec_script
    assert exec_script.rstrip().endswith('setpriv --groups 2001,2002 -- "$@"')


def test_write_identity_overlay_contract_keeps_overlay_root_owned_but_readable(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    state_profile = tmp_path / "state" / "profile"
    runtime_identity_root = tmp_path / "run" / "frag" / "identity"

    monkeypatch.setattr(bootstrap, "_RUNTIME_IDENTITY_ROOT", runtime_identity_root)
    bootstrap._write_identity_overlay_contract(
        state_profile, uid=1234, gid=5678, supplementary_gids=()
    )

    passwd_path = runtime_identity_root / "passwd"
    group_path = runtime_identity_root / "group"
    exec_path = runtime_identity_root / "exec"

    assert _mode(runtime_identity_root) == 0o755
    assert _mode(passwd_path) == 0o644
    assert _mode(group_path) == 0o644
    assert _mode(exec_path) == 0o700
