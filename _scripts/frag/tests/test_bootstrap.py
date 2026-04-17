from __future__ import annotations

import json
import stat
from pathlib import Path
import tomllib

import pytest

from frag import bootstrap


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


_EXPECTED_AGENT_BROWSER_CONFIG = {
    "contentBoundaries": True,
    "maxOutput": 50000,
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


def test_initialize_profile_state_creates_expected_directories_and_symlinks(
    tmp_path: Path,
) -> None:
    state_profile = tmp_path / "state" / "profile"
    state_shared = tmp_path / "state" / "shared"
    home = tmp_path / "home" / "agent"

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
        "workspace_root": "/workspace/demo",
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
    assert _mode(state_profile / "meta") == 0o700
    assert _mode(state_profile / "config") == 0o700
    assert _mode(state_profile / "notes") == 0o700

    profile_json = state_profile / "meta" / "profile.json"
    assert json.loads(profile_json.read_text()) == metadata
    assert _mode(profile_json) == 0o600

    code_config = state_profile / "config" / "code" / "config.toml"
    omp_config = state_profile / "config" / "omp" / "mcp.json"
    agent_browser_config = state_profile / "config" / "agent-browser" / "config.json"
    assert code_config.is_file()
    assert omp_config.is_file()
    assert agent_browser_config.is_file()
    assert _mode(code_config) == 0o600
    assert _mode(omp_config) == 0o600
    assert _mode(agent_browser_config) == 0o600
    assert tomllib.loads(code_config.read_text()) == _EXPECTED_CODE_CONFIG
    assert json.loads(omp_config.read_text()) == _EXPECTED_OMP_CONFIG
    assert (
        json.loads(agent_browser_config.read_text()) == _EXPECTED_AGENT_BROWSER_CONFIG
    )

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
    assert (home / ".agent-browser" / "config.json").is_symlink()
    assert (
        home / ".agent-browser" / "config.json"
    ).resolve() == agent_browser_config.resolve()


def test_initialize_profile_environment_is_idempotent_and_normalizes_permissions(
    tmp_path: Path,
) -> None:
    state_profile = tmp_path / "state" / "profile"
    state_shared = tmp_path / "state" / "shared"
    home = tmp_path / "home" / "agent"
    (state_shared / "code" / "agents").mkdir(parents=True)

    bootstrap.initialize_profile_environment(
        state_profile=state_profile,
        state_shared=state_shared,
        home=home,
        metadata={
            "profile_name": "demo",
            "profile_image": "python:3.14",
            "workspace_root": "/workspace/demo",
        },
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
    agent_browser_config = state_profile / "config" / "agent-browser" / "config.json"
    agent_browser_config.write_text(
        json.dumps({"contentBoundaries": False, "maxOutput": 123}) + "\n"
    )
    agent_browser_config.chmod(0o600)

    bootstrap.initialize_profile_environment(
        state_profile=state_profile,
        state_shared=state_shared,
        home=home,
        metadata={
            "profile_name": "demo",
            "profile_image": "python:3.14",
            "workspace_root": "/workspace/demo",
        },
    )

    assert _mode(profile_json) == 0o600
    assert _mode(state_profile / "config") == 0o700
    assert tomllib.loads(code_config.read_text()) == {
        "approval_policy": "never",
    }
    assert json.loads(omp_config.read_text()) == {
        "mcpServers": {"custom": {"command": "custom"}},
    }
    assert json.loads(agent_browser_config.read_text()) == {
        "contentBoundaries": False,
        "maxOutput": 123,
    }


def test_main_initializes_environment_and_execs_keepalive(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    state_profile = tmp_path / "state" / "profile"
    state_shared = tmp_path / "state" / "shared"
    home = tmp_path / "home" / "agent"
    (state_shared / "code" / "agents").mkdir(parents=True)

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
                "--keepalive",
                "sleep",
                "infinity",
            ]
        )

    assert excinfo.value.code == 0
    assert json.loads((state_profile / "meta" / "profile.json").read_text()) == {
        "profile_name": "demo",
        "profile_image": "python:3.14",
        "workspace_root": "/workspace/demo",
    }
    assert (state_profile / "meta" / "bootstrap-token").read_text() == "token-123\n"
    assert captured == {"program": "sleep", "args": ["sleep", "infinity"]}


def test_main_applies_target_ownership_to_profile_and_home(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    state_profile = tmp_path / "state" / "profile"
    state_shared = tmp_path / "state" / "shared"
    home = tmp_path / "home" / "agent"
    (state_shared / "code" / "agents").mkdir(parents=True)

    chown_calls: list[tuple[Path, int, int, bool]] = []

    def fake_execvp(program: str, args: list[str]) -> None:
        raise SystemExit(0)

    def fake_chown(
        path: str | Path, uid: int, gid: int, *, follow_symlinks: bool = True
    ) -> None:
        chown_calls.append((Path(path), uid, gid, follow_symlinks))

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
            ]
        )

    chowned_paths = {
        path
        for path, uid, gid, follow_symlinks in chown_calls
        if uid == 1234 and gid == 5678 and follow_symlinks is False
    }
    assert state_profile in chowned_paths
    assert state_profile / "meta" / "profile.json" in chowned_paths
    assert home in chowned_paths
    assert home / ".code" in chowned_paths
    assert home / ".code" / "config.toml" not in chowned_paths
