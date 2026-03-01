# Installer Rework Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Rework the NixOS installer to run entirely from the source machine, minimizing target-side dependencies.

**Architecture:** Step-based pipeline where each installation phase is an independent `Step` class. The source machine runs all logic locally (builds, git, sops) and issues SSH/rsync commands to the target. Commands are typed objects (`SSHCommand`, `RsyncCommand`, etc.) executed by a unified `CLI`.

**Tech Stack:** Python 3.14, attrs, cyclopts, rich, pytest. Nix tooling (nix eval/build/copy). SSH/rsync for remote operations.

**Design doc:** `docs/plans/2026-02-27-installer-rework-design.md`

**Run tests with:** `cd _installer && uv run pytest`

**Run formatter:** `nix fmt`

**Run pre-commit checks:** `prek`

---

### Task 1: Test Infrastructure Setup

**Files:**

- Modify: `_installer/pyproject.toml`
- Create: `_installer/tests/__init__.py`
- Create: `_installer/tests/unit/__init__.py`
- Create: `_installer/tests/integration/__init__.py`
- Create: `_installer/tests/fixtures/.gitkeep`
- Create: `_installer/conftest.py`

**Step 1: Add pytest dependency and config to pyproject.toml**

Add `pytest` to dev dependencies and pytest config:

```toml
[dependency-groups]
dev = ["pytest>=8.0.0"]

[tool.pytest.ini_options]
testpaths = ["tests"]
markers = [
    "manual: tests that must be run manually (not in CI)",
]
```

Append these sections to the existing `pyproject.toml`.

**Step 2: Create directory structure**

Create all `__init__.py` files and `.gitkeep`:

- `_installer/tests/__init__.py` — empty
- `_installer/tests/unit/__init__.py` — empty
- `_installer/tests/integration/__init__.py` — empty
- `_installer/tests/fixtures/.gitkeep` — empty
- `_installer/conftest.py` — empty for now

**Step 3: Verify pytest runs**

Run: `cd _installer && uv run pytest -v`

Expected: `no tests ran` with exit 0 (or 5 for "no tests collected" — both are fine)

**Step 4: Commit**

```bash
git add _installer/pyproject.toml _installer/tests/ _installer/conftest.py
git commit -m "chore(installer): add pytest infrastructure and test directories"
```

---

### Task 2: RepositoryURI Module (TDD)

**Files:**

- Create: `_installer/src/coisas/repository.py`
- Create: `_installer/tests/unit/test_repository.py`

**Step 1: Write the failing tests**

```python
# _installer/tests/unit/test_repository.py
import pytest

from coisas.repository import GitForge, RepositoryURI, URIType


class TestParse:
    """RepositoryURI.parse() correctly identifies URI types."""

    # --- LOCAL_PATH ---

    def test_absolute_path(self):
        uri = RepositoryURI.parse("/home/user/my-flake")
        assert uri.type == URIType.LOCAL_PATH
        assert uri.forge is None

    def test_relative_dot_path(self):
        uri = RepositoryURI.parse("./my-flake")
        assert uri.type == URIType.LOCAL_PATH

    def test_home_tilde_path(self):
        uri = RepositoryURI.parse("~/projects/flake")
        assert uri.type == URIType.LOCAL_PATH

    # --- GIT_FORGE ---

    def test_github(self):
        uri = RepositoryURI.parse("github:user/repo")
        assert uri.type == URIType.GIT_FORGE
        assert uri.forge == GitForge.GITHUB

    def test_gitlab(self):
        uri = RepositoryURI.parse("gitlab:user/repo")
        assert uri.type == URIType.GIT_FORGE
        assert uri.forge == GitForge.GITLAB

    def test_gitea(self):
        uri = RepositoryURI.parse("gitea:user/repo")
        assert uri.type == URIType.GIT_FORGE
        assert uri.forge == GitForge.GITEA

    # --- GIT_URL ---

    def test_git_at(self):
        uri = RepositoryURI.parse("git@github.com:user/repo.git")
        assert uri.type == URIType.GIT_URL
        assert uri.forge is None

    def test_git_ssh(self):
        uri = RepositoryURI.parse("git+ssh://git@github.com/user/repo")
        assert uri.type == URIType.GIT_URL

    def test_ssh(self):
        uri = RepositoryURI.parse("ssh://git@github.com/user/repo")
        assert uri.type == URIType.GIT_URL

    def test_https(self):
        uri = RepositoryURI.parse("https://github.com/user/repo.git")
        assert uri.type == URIType.GIT_URL

    def test_http(self):
        uri = RepositoryURI.parse("http://github.com/user/repo.git")
        assert uri.type == URIType.GIT_URL

    # --- errors ---

    def test_empty_string_raises(self):
        with pytest.raises(ValueError):
            RepositoryURI.parse("")

    def test_unknown_prefix_raises(self):
        with pytest.raises(ValueError):
            RepositoryURI.parse("ftp://example.com/repo")


class TestNeedsClone:
    def test_local_path_no_clone(self):
        uri = RepositoryURI.parse("/home/user/flake")
        assert uri.needs_clone() is False

    def test_github_needs_clone(self):
        uri = RepositoryURI.parse("github:user/repo")
        assert uri.needs_clone() is True

    def test_git_url_needs_clone(self):
        uri = RepositoryURI.parse("git@github.com:user/repo.git")
        assert uri.needs_clone() is True

    def test_https_needs_clone(self):
        uri = RepositoryURI.parse("https://github.com/user/repo.git")
        assert uri.needs_clone() is True


class TestGetURL:
    def test_local_path_returns_raw(self):
        uri = RepositoryURI.parse("/home/user/flake")
        assert uri.get_url() == "/home/user/flake"

    def test_github_to_ssh_url(self):
        uri = RepositoryURI.parse("github:user/repo")
        assert uri.get_url() == "git@github.com:user/repo.git"

    def test_gitlab_to_ssh_url(self):
        uri = RepositoryURI.parse("gitlab:user/repo")
        assert uri.get_url() == "git@gitlab.com:user/repo.git"

    def test_git_at_returns_raw(self):
        uri = RepositoryURI.parse("git@github.com:user/repo.git")
        assert uri.get_url() == "git@github.com:user/repo.git"

    def test_https_returns_raw(self):
        uri = RepositoryURI.parse("https://github.com/user/repo.git")
        assert uri.get_url() == "https://github.com/user/repo.git"

    def test_tilde_path_returns_raw(self):
        uri = RepositoryURI.parse("~/my-flake")
        assert uri.get_url() == "~/my-flake"
```

**Step 2: Run tests to verify they fail**

Run: `cd _installer && uv run pytest tests/unit/test_repository.py -v`

Expected: `ModuleNotFoundError: No module named 'coisas.repository'`

**Step 3: Implement RepositoryURI**

```python
# _installer/src/coisas/repository.py
"""Repository URI parsing for git forge, SSH, HTTPS, and local paths."""

from __future__ import annotations

from enum import Enum

from attrs import define


class URIType(Enum):
    LOCAL_PATH = "local_path"
    GIT_FORGE = "git_forge"
    GIT_URL = "git_url"


class GitForge(Enum):
    GITHUB = "github"
    GITLAB = "gitlab"
    GITEA = "gitea"


_FORGE_HOSTS: dict[GitForge, str] = {
    GitForge.GITHUB: "github.com",
    GitForge.GITLAB: "gitlab.com",
}

_FORGE_PREFIXES: dict[str, GitForge] = {
    "github:": GitForge.GITHUB,
    "gitlab:": GitForge.GITLAB,
    "gitea:": GitForge.GITEA,
}

_GIT_URL_PREFIXES = ("git@", "git+ssh://", "ssh://", "https://", "http://")
_LOCAL_PATH_PREFIXES = ("/", "./", "~/")


@define(frozen=True)
class RepositoryURI:
    raw: str
    type: URIType
    forge: GitForge | None = None

    @classmethod
    def parse(cls, raw: str) -> RepositoryURI:
        if not raw:
            raise ValueError("Repository URI cannot be empty")

        # local paths
        if any(raw.startswith(p) for p in _LOCAL_PATH_PREFIXES):
            return cls(raw=raw, type=URIType.LOCAL_PATH)

        # git forges
        for prefix, forge in _FORGE_PREFIXES.items():
            if raw.startswith(prefix):
                return cls(raw=raw, type=URIType.GIT_FORGE, forge=forge)

        # git URLs
        if any(raw.startswith(p) for p in _GIT_URL_PREFIXES):
            return cls(raw=raw, type=URIType.GIT_URL)

        raise ValueError(f"Unrecognized repository URI format: {raw!r}")

    def needs_clone(self) -> bool:
        return self.type != URIType.LOCAL_PATH

    def get_url(self) -> str:
        if self.type != URIType.GIT_FORGE:
            return self.raw

        # strip forge prefix to get "user/repo"
        for prefix in _FORGE_PREFIXES:
            if self.raw.startswith(prefix):
                user_repo = self.raw[len(prefix) :]
                break

        if self.forge and self.forge in _FORGE_HOSTS:
            host = _FORGE_HOSTS[self.forge]
            return f"git@{host}:{user_repo}.git"

        # for forges without a known host (e.g. gitea), return raw
        return self.raw
```

**Step 4: Run tests to verify they pass**

Run: `cd _installer && uv run pytest tests/unit/test_repository.py -v`

Expected: all PASS

**Step 5: Run formatter and checks**

Run: `nix fmt && prek`

**Step 6: Commit**

```bash
git add _installer/src/coisas/repository.py _installer/tests/unit/test_repository.py
git commit -m "feat(installer): add RepositoryURI module with TDD tests"
```

---

### Task 3: GitCommand Modifications (TDD)

**Files:**

- Modify: `_installer/src/coisas/command.py:99-122` (GitCommand class)
- Create: `_installer/tests/unit/test_commands.py`

**Step 1: Write the failing tests for GitCommand changes**

```python
# _installer/tests/unit/test_commands.py
from pathlib import Path

from coisas.command import (
    GitCommand,
    NixCommand,
    NixRunCommand,
    RsyncCommand,
    ShellCommand,
    SSHCommand,
    SSHConfig,
    SudoCommand,
)


class TestGitCommand:
    def test_basic_args(self):
        cmd = GitCommand(args=["status"])
        assert cmd.build() == ["git", "status"]

    def test_repo_path_uses_dash_c(self):
        cmd = GitCommand(args=["status"], repo_path="/tmp/repo")
        assert cmd.build() == ["git", "-C", "/tmp/repo", "status"]

    def test_config_flags(self):
        cmd = GitCommand(
            args=["commit", "-m", "test"],
            config={"user.name": "nixos-installer", "user.email": "nix@local"},
        )
        result = cmd.build()
        assert result == [
            "git",
            "-c",
            "user.name=nixos-installer",
            "-c",
            "user.email=nix@local",
            "commit",
            "-m",
            "test",
        ]

    def test_config_and_repo_path(self):
        cmd = GitCommand(
            args=["add", "."],
            repo_path="/tmp/repo",
            config={"user.name": "installer"},
        )
        result = cmd.build()
        assert result == [
            "git",
            "-c",
            "user.name=installer",
            "-C",
            "/tmp/repo",
            "add",
            ".",
        ]

    def test_env_prefix(self):
        cmd = GitCommand(args=["push"], env={"GIT_SSH_COMMAND": "ssh -o Foo=bar"})
        result = cmd.build()
        assert result == [
            "env",
            "GIT_SSH_COMMAND=ssh -o Foo=bar",
            "git",
            "push",
        ]
```

**Step 2: Run tests to verify they fail**

Run: `cd _installer && uv run pytest tests/unit/test_commands.py::TestGitCommand -v`

Expected: failures on `test_repo_path_uses_dash_c` (currently produces `cd ... &&`), `test_config_flags` (no `config` field), etc.

**Step 3: Modify GitCommand**

In `_installer/src/coisas/command.py`, replace the `GitCommand` class (lines 99-122):

```python
@define
class GitCommand:
    args: list[str] = Factory(list)
    env: dict[str, str] = Factory(dict)
    repo_path: str | None = None
    config: dict[str, str] = Factory(dict)

    def render(self) -> Text:
        text = Text()
        if self.env:
            text.append_text(_render_env(self.env))
        text.append("$ ", style="dim")
        text.append("git", style="bold green")
        if self.args:
            text.append(" " + " ".join(self.args), style="dim")
        if self.repo_path:
            text.append(f"  ({self.repo_path})", style="dim italic")
        return text

    def build(self) -> list[str]:
        env = _env_prefix(self.env)
        config_args = [
            arg for k, v in self.config.items() for arg in ["-c", f"{k}={v}"]
        ]
        git = ["git"] + config_args
        if self.repo_path:
            git += ["-C", self.repo_path]
        git += self.args
        return env + git
```

**Step 4: Run tests to verify they pass**

Run: `cd _installer && uv run pytest tests/unit/test_commands.py::TestGitCommand -v`

Expected: all PASS

**Step 5: Run formatter and checks**

Run: `nix fmt && prek`

**Step 6: Commit**

```bash
git add _installer/src/coisas/command.py _installer/tests/unit/test_commands.py
git commit -m "feat(installer): update GitCommand to use git -C and per-command config"
```

---

### Task 4: SSHConfig + SSHCommand (TDD)

**Files:**

- Modify: `_installer/src/coisas/command.py` (add SSHConfig, SSHCommand at end)
- Modify: `_installer/tests/unit/test_commands.py` (add SSHCommand tests)

**Step 1: Write the failing tests**

Append to `_installer/tests/unit/test_commands.py`:

```python
class TestSSHCommand:
    def _config(self) -> SSHConfig:
        return SSHConfig(host="root@192.168.1.1", identity=Path("/tmp/id_ed25519"), port=22)

    def test_basic_build(self):
        inner = ShellCommand("ls", ["/tmp"])
        cmd = SSHCommand(inner=inner, config=self._config())
        result = cmd.build()
        assert result == [
            "ssh",
            "-i",
            "/tmp/id_ed25519",
            "-p",
            "22",
            "root@192.168.1.1",
            "--",
            "ls /tmp",
        ]

    def test_quoting_whitespace_args(self):
        """Arguments with whitespace get shlex-quoted for the remote shell."""
        inner = ShellCommand("echo", ["hello world"])
        cmd = SSHCommand(inner=inner, config=self._config())
        result = cmd.build()
        remote_str = result[-1]
        assert "echo 'hello world'" == remote_str

    def test_globs_not_quoted(self):
        """Globs and operators should not be quoted (they expand on remote)."""
        inner = ShellCommand("cp", ["/tmp/.ssh/id_*", "/root/.ssh/"])
        cmd = SSHCommand(inner=inner, config=self._config())
        remote_str = result = cmd.build()[-1]
        assert "id_*" in remote_str
        assert "'" not in remote_str or "'id_*'" not in remote_str

    def test_wraps_sudo(self):
        inner = SudoCommand(inner=ShellCommand("nixos-install", ["--root", "/mnt"]))
        cmd = SSHCommand(inner=inner, config=self._config())
        result = cmd.build()
        remote_str = result[-1]
        assert remote_str == "sudo nixos-install --root /mnt"

    def test_wraps_nix_run(self):
        inner = NixRunCommand(
            "github:nix-community/disko",
            ["--yes-wipe-all-disks", "--mode", "destroy,format,mount", "/tmp/disko.nix"],
        )
        cmd = SSHCommand(inner=inner, config=self._config())
        result = cmd.build()
        remote_str = result[-1]
        assert "nix run" in remote_str
        assert "github:nix-community/disko" in remote_str
        assert "-- --yes-wipe-all-disks" in remote_str

    def test_custom_port(self):
        config = SSHConfig(host="user@host", identity=Path("/key"), port=2222)
        cmd = SSHCommand(inner=ShellCommand("whoami"), config=config)
        result = cmd.build()
        assert "-p" in result
        assert "2222" in result
```

**Step 2: Run tests to verify they fail**

Run: `cd _installer && uv run pytest tests/unit/test_commands.py::TestSSHCommand -v`

Expected: `ImportError` — `SSHConfig` and `SSHCommand` don't exist yet.

**Step 3: Implement SSHConfig and SSHCommand**

Add to `_installer/src/coisas/command.py` (after imports, add `from pathlib import Path` and `from shlex import quote as shlex_quote`). Add before `SudoCommand`:

```python
@define(frozen=True)
class SSHConfig:
    host: str
    identity: Path
    port: int = 22


def _quote_for_ssh(parts: list[str]) -> str:
    """Join command parts into a remote shell string.

    Quotes arguments containing whitespace with shlex, but leaves
    globs/operators unquoted so they expand on the remote shell.
    """
    result: list[str] = []
    for part in parts:
        if part == "" or any(ch.isspace() for ch in part):
            result.append(shlex_quote(part))
        else:
            result.append(part)
    return " ".join(result)


@define
class SSHCommand:
    inner: Command
    config: SSHConfig

    def render(self) -> Text:
        text = Text()
        text.append(f"[ssh {self.config.host}] ", style="bold yellow")
        text.append_text(self.inner.render())
        return text

    def build(self) -> list[str]:
        inner_parts = self.inner.build()
        remote_str = _quote_for_ssh(inner_parts)
        return [
            "ssh",
            "-i",
            str(self.config.identity),
            "-p",
            str(self.config.port),
            self.config.host,
            "--",
            remote_str,
        ]
```

Update `SudoCommand.inner` type hint to include `SSHCommand` is NOT needed — `SSHCommand` wraps `SudoCommand`, not the reverse. But `SSHCommand.inner` takes the generic `Command` protocol, so any command works.

Update the module's exports — add `SSHConfig`, `SSHCommand`, and `_quote_for_ssh` to the public API.

**Step 4: Run tests to verify they pass**

Run: `cd _installer && uv run pytest tests/unit/test_commands.py::TestSSHCommand -v`

Expected: all PASS

**Step 5: Run formatter and checks**

Run: `nix fmt && prek`

**Step 6: Commit**

```bash
git add _installer/src/coisas/command.py _installer/tests/unit/test_commands.py
git commit -m "feat(installer): add SSHConfig and SSHCommand with quoting logic"
```

---

### Task 5: RsyncCommand (TDD)

**Files:**

- Modify: `_installer/src/coisas/command.py` (add RsyncCommand)
- Modify: `_installer/tests/unit/test_commands.py` (add RsyncCommand tests)

**Step 1: Write the failing tests**

Append to `_installer/tests/unit/test_commands.py`:

```python
class TestRsyncCommand:
    def _config(self) -> SSHConfig:
        return SSHConfig(host="root@192.168.1.1", identity=Path("/tmp/id_ed25519"), port=22)

    def test_local_rsync(self):
        cmd = RsyncCommand(src="/tmp/file.json", dest="/backup/file.json")
        result = cmd.build()
        assert result == ["rsync", "-avz", "/tmp/file.json", "/backup/file.json"]

    def test_remote_rsync_with_ssh(self):
        cmd = RsyncCommand(
            src="/tmp/devices.json",
            dest="root@192.168.1.1:/tmp/disko/",
            ssh_config=self._config(),
        )
        result = cmd.build()
        assert "rsync" == result[0]
        assert "-avz" in result
        assert "-e" in result
        # ssh command string should contain identity and port
        ssh_idx = result.index("-e") + 1
        ssh_str = result[ssh_idx]
        assert "-i" in ssh_str
        assert "/tmp/id_ed25519" in ssh_str
        assert "-p 22" in ssh_str

    def test_extra_args(self):
        cmd = RsyncCommand(
            src="/tmp/src/",
            dest="host:/tmp/dest/",
            ssh_config=self._config(),
            extra_args=["--include=id_*", "--exclude=*"],
        )
        result = cmd.build()
        assert "--include=id_*" in result
        assert "--exclude=*" in result

    def test_identity_path_with_spaces_quoted(self):
        config = SSHConfig(
            host="user@host",
            identity=Path("/path with spaces/key"),
            port=22,
        )
        cmd = RsyncCommand(src="/a", dest="user@host:/b", ssh_config=config)
        result = cmd.build()
        ssh_idx = result.index("-e") + 1
        ssh_str = result[ssh_idx]
        # shlex-quoted path
        assert "'/path with spaces/key'" in ssh_str or '"/path with spaces/key"' in ssh_str
```

**Step 2: Run tests to verify they fail**

Run: `cd _installer && uv run pytest tests/unit/test_commands.py::TestRsyncCommand -v`

Expected: `ImportError` — `RsyncCommand` doesn't exist yet.

**Step 3: Implement RsyncCommand**

Add to `_installer/src/coisas/command.py` (after `SSHCommand`):

```python
@define
class RsyncCommand:
    src: str
    dest: str
    ssh_config: SSHConfig | None = None
    extra_args: list[str] = Factory(list)

    def render(self) -> Text:
        text = Text()
        if self.ssh_config:
            text.append(f"[ssh {self.ssh_config.host}] ", style="bold yellow")
        text.append("$ ", style="dim")
        text.append("rsync ", style="bold")
        text.append(f"{self.src} -> {self.dest}", style="dim")
        return text

    def build(self) -> list[str]:
        cmd = ["rsync", "-avz"]
        if self.extra_args:
            cmd += self.extra_args
        if self.ssh_config:
            identity = shlex_quote(str(self.ssh_config.identity))
            ssh_cmd = f"ssh -i {identity} -p {self.ssh_config.port}"
            cmd += ["-e", ssh_cmd]
        cmd += [self.src, self.dest]
        return cmd
```

**Step 4: Run tests to verify they pass**

Run: `cd _installer && uv run pytest tests/unit/test_commands.py::TestRsyncCommand -v`

Expected: all PASS

**Step 5: Run formatter and checks**

Run: `nix fmt && prek`

**Step 6: Commit**

```bash
git add _installer/src/coisas/command.py _installer/tests/unit/test_commands.py
git commit -m "feat(installer): add RsyncCommand with SSH config support"
```

---

### Task 6: Existing Command Tests

**Files:**

- Modify: `_installer/tests/unit/test_commands.py` (add tests for ShellCommand, NixCommand, NixRunCommand, SudoCommand)

**Step 1: Write tests for existing commands**

Prepend to the test classes in `_installer/tests/unit/test_commands.py`:

```python
class TestShellCommand:
    def test_basic(self):
        cmd = ShellCommand("ls", ["-la"])
        assert cmd.build() == ["ls", "-la"]

    def test_with_env(self):
        cmd = ShellCommand("make", env={"CC": "gcc"})
        assert cmd.build() == ["env", "CC=gcc", "make"]


class TestNixCommand:
    def test_basic(self):
        cmd = NixCommand(["flake", "update", "mysecrets", "--flake", "/tmp/flake"])
        result = cmd.build()
        assert result[0] == "nix"
        assert "--option" in result
        assert "experimental-features" in result
        assert "nix-command flakes" in result
        assert result[-4:] == ["flake", "update", "mysecrets", "--flake"]
        # flake path is last
        assert result[-1] == "/tmp/flake"

    def test_with_env(self):
        cmd = NixCommand(["copy"], env={"NIX_SSHOPTS": "-i /key -p 22"})
        result = cmd.build()
        assert result[0] == "env"
        assert "NIX_SSHOPTS=-i /key -p 22" in result


class TestNixRunCommand:
    def test_basic(self):
        cmd = NixRunCommand("nixpkgs#hello")
        result = cmd.build()
        assert "nix" in result
        assert "run" in result
        assert "nixpkgs#hello" in result

    def test_with_args(self):
        cmd = NixRunCommand("nixpkgs#sops", ["-d", "secrets.yaml"])
        result = cmd.build()
        assert "--" in result
        idx = result.index("--")
        assert result[idx + 1 :] == ["-d", "secrets.yaml"]


class TestSudoCommand:
    def test_wraps_shell(self):
        cmd = SudoCommand(inner=ShellCommand("nixos-install", ["--root", "/mnt"]))
        assert cmd.build() == ["sudo", "nixos-install", "--root", "/mnt"]

    def test_wraps_nix_command(self):
        cmd = SudoCommand(inner=NixCommand(["profile", "install", "nixpkgs#git"]))
        result = cmd.build()
        assert result[0] == "sudo"
        assert result[1] == "nix"
```

**Step 2: Run all command tests**

Run: `cd _installer && uv run pytest tests/unit/test_commands.py -v`

Expected: all PASS (these test existing behavior)

**Step 3: Run formatter and checks**

Run: `nix fmt && prek`

**Step 4: Commit**

```bash
git add _installer/tests/unit/test_commands.py
git commit -m "test(installer): add unit tests for all command types"
```

---

### Task 7: CLI Rework — Remove SshCLI

**Files:**

- Modify: `_installer/src/coisas/cli.py` (remove SshCLI, remove list[str] overloads from run_command)

**Step 1: Remove SshCLI and simplify CLI**

In `_installer/src/coisas/cli.py`:

1. Remove the entire `SshCLI` class (lines 446-579)
2. Remove `_resolve_command` method (line 67-72) — no longer needed
3. Remove the `list[str]` branch from `run_command` — only accept `Command` objects
4. Remove `run_local_command` — `run_command` handles everything now since commands build their own args
5. Remove `_run_command` override pattern — just use `_run_local_command` directly
6. Remove `copy_all` and `chown_recursive` — these were local file operations that won't be needed (replaced by `RsyncCommand` and `ShellCommand`)
7. Keep: `CLI`, `panel_session()`, `_stream_in_panel()`, `info()`, `_format_panel_line()`, `_format_status_line()`, `PanelWriter`, `AppendLineFn`, `SetFailedFn`, `UpdateLineFn`, `PanelWriterLike`, `_ensure_dir`

The simplified `run_command`:

```python
def run_command(
    self,
    command: Command,
    description: str,
    writer: PanelWriterLike | None = None,
) -> int:
    """Run a command and pretty-print the result.

    Returns the command's exit code.
    """
    command_line = command.render()
    executable = command.build()
    panel_title = description

    try:
        process = subprocess.Popen(
            executable,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
            universal_newlines=True,
        )
    except Exception as exc:
        if writer is not None:
            writer.append_line(f"Failed to run command: {exc}", style="red")
            writer.set_failed()
            return 1
        self.console.print(
            Panel(
                f"Failed to run command: {exc}",
                title=panel_title,
                border_style="red",
            )
        )
        return 1

    return self._stream_in_panel(
        title=panel_title,
        command_line=command_line,
        process=process,
        writer=writer,
    )
```

Also simplify `_stream_in_panel` — remove `full_command` parameter since there's no longer a "resolved" vs "original" command distinction.

**Step 2: Remove unused imports**

Remove: `shlex`, `Path`, `override` from imports (if no longer used after removing SshCLI).

**Step 3: Run formatter and checks**

Run: `nix fmt && prek`

**Step 4: Commit**

```bash
git add _installer/src/coisas/cli.py
git commit -m "refactor(installer): remove SshCLI, simplify CLI to Command-only execution"
```

---

### Task 8: InstallerContext and Step Protocol

**Files:**

- Create: `_installer/src/installer/context.py`
- Create: `_installer/src/installer/steps.py` (protocol + orchestrator only, no step implementations yet)

**Step 1: Create InstallerContext**

```python
# _installer/src/installer/context.py
"""Installer context and configuration."""

from __future__ import annotations

from attrs import define

from coisas.command import (
    GitCommand,
    NixCommand,
    NixRunCommand,
    ShellCommand,
    SSHConfig,
    SudoCommand,
)
from coisas.repository import RepositoryURI


class InstallerError(Exception):
    """Raised when an installer step fails."""

    ...


@define(frozen=True)
class SecretsEncryptionParams:
    repo_url: str
    sops_file: str
    sops_file_key: str
    keyfile_location: str


@define(frozen=True)
class InstallerContext:
    flake: RepositoryURI
    flake_host: str
    secrets: RepositoryURI | None
    ssh_config: SSHConfig
    encryption_params: SecretsEncryptionParams | None
    use_sudo: bool
    auto_commit: bool = True
    auto_push: bool = True

    # constants with sensible defaults
    flake_secrets_input_name: str = "mysecrets"
    age_keyfile: str = "key.txt"
    gen_initrd_ssh_keys: bool = True
    initrd_ssh_key_name: str = "ssh_host_ed25519_key"
    initrd_ssh_key_dir: str = "etc/secrets/initrd"

    def maybe_sudo(
        self, cmd: ShellCommand | NixCommand | NixRunCommand | GitCommand
    ) -> ShellCommand | NixCommand | NixRunCommand | GitCommand | SudoCommand:
        return SudoCommand(inner=cmd) if self.use_sudo else cmd

    def flake_dir(self, tmp_dir: str) -> str:
        """Resolved flake directory — local path or cloned location."""
        if not self.flake.needs_clone():
            return self.flake.get_url()
        return f"{tmp_dir}/flake"

    def secrets_dir(self, tmp_dir: str) -> str | None:
        """Resolved secrets directory — local path or cloned location."""
        if self.secrets is None:
            return None
        if not self.secrets.needs_clone():
            return self.secrets.get_url()
        return f"{tmp_dir}/secrets"
```

**Step 2: Create Step protocol and Installer orchestrator**

```python
# _installer/src/installer/steps.py
"""Step protocol and installer orchestrator."""

from __future__ import annotations

import tempfile
from typing import Protocol

from attrs import define

from coisas.cli import CLI

from installer.context import InstallerContext


class Step(Protocol):
    name: str
    description: str

    def should_skip(self, context: InstallerContext) -> bool: ...
    def execute(self, context: InstallerContext, cli: CLI, tmp_dir: str) -> None: ...


@define
class Installer:
    context: InstallerContext
    cli: CLI
    steps: list[Step]

    def run(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            for step in self.steps:
                if step.should_skip(self.context):
                    self.cli.info(f"Skipping: {step.description}")
                    continue
                self.cli.info(f"Running: {step.description}")
                step.execute(self.context, self.cli, tmp_dir)
```

**Step 3: Run formatter and checks**

Run: `nix fmt && prek`

**Step 4: Commit**

```bash
git add _installer/src/installer/context.py _installer/src/installer/steps.py
git commit -m "feat(installer): add InstallerContext, Step protocol, and Installer orchestrator"
```

---

### Task 9: Steps 1-3 — Clone, DecryptKeyfile, SendKeyfile

**Files:**

- Modify: `_installer/src/installer/steps.py` (add step implementations)

Refer to `_installer/src/installer/install.py` for current logic in `_clone_repositories()` (line 191), `_setup_keyfiles()` (line 212).

**Step 1: Implement CloneRepositories**

```python
@define
class CloneRepositories:
    name: str = "clone_repositories"
    description: str = "Cloning repositories"

    def should_skip(self, context: InstallerContext) -> bool:
        # skip only if BOTH don't need cloning
        flake_skip = not context.flake.needs_clone()
        secrets_skip = context.secrets is None or not context.secrets.needs_clone()
        return flake_skip and secrets_skip

    def execute(self, context: InstallerContext, cli: CLI, tmp_dir: str) -> None:
        if context.flake.needs_clone():
            rc = cli.run_command(
                command=GitCommand(
                    args=["clone", "--depth", "1", context.flake.get_url(), context.flake_dir(tmp_dir)],
                ),
                description="Cloning flake repository",
            )
            if rc != 0:
                raise InstallerError("Failed to clone flake repository")

        if context.secrets is not None and context.secrets.needs_clone():
            rc = cli.run_command(
                command=GitCommand(
                    args=["clone", "--depth", "1", context.secrets.get_url(), context.secrets_dir(tmp_dir)],
                ),
                description="Cloning secrets repository",
            )
            if rc != 0:
                raise InstallerError("Failed to clone secrets repository")
```

**Step 2: Implement DecryptKeyfile**

```python
@define
class DecryptKeyfile:
    name: str = "decrypt_keyfile"
    description: str = "Decrypting disk encryption keyfile"

    def should_skip(self, context: InstallerContext) -> bool:
        return context.encryption_params is None

    def execute(self, context: InstallerContext, cli: CLI, tmp_dir: str) -> None:
        assert context.encryption_params is not None
        secrets_dir = context.secrets_dir(tmp_dir)
        assert secrets_dir is not None

        sops_path = f"{secrets_dir}/{context.encryption_params.sops_file}"
        rc = cli.run_command(
            command=ShellCommand(
                "sops",
                [
                    "-d",
                    "--extract",
                    context.encryption_params.sops_file_key,
                    sops_path,
                    "--output",
                    f"{tmp_dir}/secret.key",
                ],
                env={"SOPS_AGE_KEY_FILE": f"{Path.home()}/.age/{context.age_keyfile}"},
            ),
            description="Decrypting disk encryption keyfile with SOPS",
        )
        if rc != 0:
            raise InstallerError("Failed to decrypt keyfile")
```

**Step 3: Implement SendKeyfile**

```python
@define
class SendKeyfile:
    name: str = "send_keyfile"
    description: str = "Sending keyfile to target"

    def should_skip(self, context: InstallerContext) -> bool:
        return context.encryption_params is None

    def execute(self, context: InstallerContext, cli: CLI, tmp_dir: str) -> None:
        assert context.encryption_params is not None

        rc = cli.run_command(
            command=RsyncCommand(
                src=f"{tmp_dir}/secret.key",
                dest=f"{context.ssh_config.host}:{context.encryption_params.keyfile_location}",
                ssh_config=context.ssh_config,
            ),
            description="Sending keyfile to target host",
        )
        if rc != 0:
            raise InstallerError("Failed to send keyfile to target")
```

**Step 4: Add required imports at top of steps.py**

```python
from pathlib import Path

from coisas.command import (
    GitCommand,
    NixCommand,
    NixRunCommand,
    RsyncCommand,
    ShellCommand,
    SSHCommand,
    SudoCommand,
)
from installer.context import InstallerContext, InstallerError
```

**Step 5: Run formatter and checks**

Run: `nix fmt && prek`

**Step 6: Commit**

```bash
git add _installer/src/installer/steps.py
git commit -m "feat(installer): add Clone, DecryptKeyfile, and SendKeyfile steps"
```

---

### Task 10: Steps 4-6 — EvaluateDisko, SendDiskoConfig, RunDisko

**Files:**

- Modify: `_installer/src/installer/steps.py`

**Step 1: Implement EvaluateDisko**

```python
_DISKO_FILTER = """\
let
  filterDeep = x:
    if builtins.isAttrs x then
      builtins.mapAttrs (_: filterDeep)
        (removeAttrs x (builtins.filter (n: builtins.substring 0 1 n == "_") (builtins.attrNames x)))
    else x;
in filterDeep\
"""


@define
class EvaluateDisko:
    name: str = "evaluate_disko"
    description: str = "Evaluating disko config from flake"

    def should_skip(self, context: InstallerContext) -> bool:
        return False

    def execute(self, context: InstallerContext, cli: CLI, tmp_dir: str) -> None:
        import json
        import subprocess

        flake_dir = context.flake_dir(tmp_dir)
        flake_ref = f"{flake_dir}#nixosConfigurations.{context.flake_host}.config.disko.devices"

        # nix eval to JSON — run directly to capture stdout
        result = subprocess.run(
            [
                "nix",
                "eval",
                *_NIX_FLAGS,
                flake_ref,
                "--json",
                "--apply",
                _DISKO_FILTER,
            ],
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            cli.console.print(f"[red]nix eval stderr:[/red]\n{result.stderr}")
            raise InstallerError(f"nix eval failed with exit code {result.returncode}")

        # validate it's valid JSON
        devices_json = result.stdout
        _ = json.loads(devices_json)

        # write files
        devices_path = Path(tmp_dir) / "devices.json"
        disko_path = Path(tmp_dir) / "disko.nix"

        devices_path.write_text(devices_json)
        disko_path.write_text(
            '{ disko.devices = builtins.fromJSON (builtins.readFile ./devices.json); }\n'
        )

        cli.info(f"Disko config written to {disko_path}")
```

Note: `_NIX_FLAGS` needs to be imported from `coisas.command`.

**Step 2: Implement SendDiskoConfig**

```python
@define
class SendDiskoConfig:
    name: str = "send_disko_config"
    description: str = "Sending disko config to target"

    def should_skip(self, context: InstallerContext) -> bool:
        return False

    def execute(self, context: InstallerContext, cli: CLI, tmp_dir: str) -> None:
        # ensure remote directory exists
        rc = cli.run_command(
            command=SSHCommand(
                inner=ShellCommand("mkdir", ["-p", "/tmp/disko"]),
                config=context.ssh_config,
            ),
            description="Creating remote disko directory",
        )
        if rc != 0:
            raise InstallerError("Failed to create remote disko directory")

        # send both files
        rc = cli.run_command(
            command=RsyncCommand(
                src=f"{tmp_dir}/devices.json",
                dest=f"{context.ssh_config.host}:/tmp/disko/",
                ssh_config=context.ssh_config,
            ),
            description="Sending devices.json",
        )
        if rc != 0:
            raise InstallerError("Failed to send devices.json")

        rc = cli.run_command(
            command=RsyncCommand(
                src=f"{tmp_dir}/disko.nix",
                dest=f"{context.ssh_config.host}:/tmp/disko/",
                ssh_config=context.ssh_config,
            ),
            description="Sending disko.nix",
        )
        if rc != 0:
            raise InstallerError("Failed to send disko.nix")
```

**Step 3: Implement RunDisko**

```python
@define
class RunDisko:
    name: str = "run_disko"
    description: str = "Running disko on target"

    def should_skip(self, context: InstallerContext) -> bool:
        return False

    def execute(self, context: InstallerContext, cli: CLI, tmp_dir: str) -> None:
        disko_cmd = NixRunCommand(
            "github:nix-community/disko",
            [
                "--yes-wipe-all-disks",
                "--mode",
                "destroy,format,mount",
                "/tmp/disko/disko.nix",
            ],
        )
        rc = cli.run_command(
            command=SSHCommand(
                inner=context.maybe_sudo(disko_cmd),
                config=context.ssh_config,
            ),
            description="Running disko partitioning",
        )
        if rc != 0:
            raise InstallerError("Disko partitioning failed")
```

**Step 4: Run formatter and checks**

Run: `nix fmt && prek`

**Step 5: Commit**

```bash
git add _installer/src/installer/steps.py
git commit -m "feat(installer): add EvaluateDisko, SendDiskoConfig, and RunDisko steps"
```

---

### Task 11: Steps 7-10 — Facter + Git Operations

**Files:**

- Modify: `_installer/src/installer/steps.py`

Refer to `_installer/src/installer/install.py` for current logic in `_handle_facter()` (line 291).

**Step 1: Implement RunFacter**

```python
@define
class RunFacter:
    name: str = "run_facter"
    description: str = "Running nixos-facter on target"

    def should_skip(self, context: InstallerContext) -> bool:
        return False

    def execute(self, context: InstallerContext, cli: CLI, tmp_dir: str) -> None:
        facter_cmd = NixRunCommand("nixpkgs#nixos-facter", ["-o", "/tmp/facter.json"])
        rc = cli.run_command(
            command=SSHCommand(
                inner=context.maybe_sudo(facter_cmd),
                config=context.ssh_config,
            ),
            description="Running nixos-facter",
        )
        if rc != 0:
            raise InstallerError("nixos-facter failed")
```

**Step 2: Implement DownloadFacter**

```python
@define
class DownloadFacter:
    name: str = "download_facter"
    description: str = "Downloading facter config from target"

    def should_skip(self, context: InstallerContext) -> bool:
        return False

    def execute(self, context: InstallerContext, cli: CLI, tmp_dir: str) -> None:
        secrets_dir = context.secrets_dir(tmp_dir)
        if secrets_dir is None:
            raise InstallerError("Secrets directory required for facter download")

        facter_dir = f"{secrets_dir}/facter"
        Path(facter_dir).mkdir(parents=True, exist_ok=True)

        rc = cli.run_command(
            command=RsyncCommand(
                src=f"{context.ssh_config.host}:/tmp/facter.json",
                dest=f"{facter_dir}/{context.flake_host}.json",
                ssh_config=context.ssh_config,
            ),
            description=f"Downloading facter config to {facter_dir}/{context.flake_host}.json",
        )
        if rc != 0:
            raise InstallerError("Failed to download facter config")
```

**Step 3: Implement CommitFacter**

```python
_GIT_INSTALLER_CONFIG = {
    "user.name": "nixos-installer",
    "user.email": "nixos-installer@local",
}


@define
class CommitFacter:
    name: str = "commit_facter"
    description: str = "Committing facter config to secrets repo"

    def should_skip(self, context: InstallerContext) -> bool:
        return not context.auto_commit

    def execute(self, context: InstallerContext, cli: CLI, tmp_dir: str) -> None:
        secrets_dir = context.secrets_dir(tmp_dir)
        assert secrets_dir is not None

        msg = f"[my-installer][new-facter-cfg]:{context.flake_host}"

        rc = cli.run_command(
            command=GitCommand(
                args=["add", "."],
                repo_path=secrets_dir,
                config=_GIT_INSTALLER_CONFIG,
            ),
            description="Staging facter config",
        )
        if rc != 0:
            raise InstallerError("Failed to stage facter config")

        rc = cli.run_command(
            command=GitCommand(
                args=["commit", "-m", msg],
                repo_path=secrets_dir,
                config=_GIT_INSTALLER_CONFIG,
            ),
            description="Committing facter config",
        )
        # rc=1 on nothing to commit is non-fatal
        if rc not in (0, 1):
            raise InstallerError("Failed to commit facter config")

        if context.auto_push:
            rc = cli.run_command(
                command=GitCommand(
                    args=["push", "-u", "origin", "HEAD"],
                    repo_path=secrets_dir,
                ),
                description="Pushing secrets repo",
            )
            if rc != 0:
                raise InstallerError("Failed to push secrets repo")
```

**Step 4: Implement UpdateFlakeLock**

```python
@define
class UpdateFlakeLock:
    name: str = "update_flake_lock"
    description: str = "Updating flake lock with new secrets"

    def should_skip(self, context: InstallerContext) -> bool:
        return not context.auto_commit

    def execute(self, context: InstallerContext, cli: CLI, tmp_dir: str) -> None:
        flake_dir = context.flake_dir(tmp_dir)

        rc = cli.run_command(
            command=NixCommand([
                "flake",
                "update",
                context.flake_secrets_input_name,
                "--flake",
                flake_dir,
            ]),
            description="Updating secrets input in flake lock",
        )
        if rc != 0:
            raise InstallerError("Failed to update flake lock")

        msg = f"[my-installer][update-secrets][new-facter-cfg]:{context.flake_host}"

        rc = cli.run_command(
            command=GitCommand(
                args=["add", "flake.lock"],
                repo_path=flake_dir,
                config=_GIT_INSTALLER_CONFIG,
            ),
            description="Staging updated flake.lock",
        )
        if rc != 0:
            raise InstallerError("Failed to stage flake.lock")

        rc = cli.run_command(
            command=GitCommand(
                args=["commit", "-m", msg],
                repo_path=flake_dir,
                config=_GIT_INSTALLER_CONFIG,
            ),
            description="Committing flake lock update",
        )
        if rc not in (0, 1):
            raise InstallerError("Failed to commit flake lock update")

        if context.auto_push:
            rc = cli.run_command(
                command=GitCommand(
                    args=["push", "-u", "origin", "HEAD"],
                    repo_path=flake_dir,
                ),
                description="Pushing flake repo",
            )
            if rc != 0:
                raise InstallerError("Failed to push flake repo")
```

**Step 5: Run formatter and checks**

Run: `nix fmt && prek`

**Step 6: Commit**

```bash
git add _installer/src/installer/steps.py
git commit -m "feat(installer): add RunFacter, DownloadFacter, CommitFacter, UpdateFlakeLock steps"
```

---

### Task 12: Steps 11-13 — CopyKeys, GenerateInitrdSSHKeys, InstallSystem

**Files:**

- Modify: `_installer/src/installer/steps.py`

**Step 1: Implement CopyKeys**

```python
@define
class CopyKeys:
    name: str = "copy_keys"
    description: str = "Copying SSH/AGE keys to target"

    def should_skip(self, context: InstallerContext) -> bool:
        return False

    def execute(self, context: InstallerContext, cli: CLI, tmp_dir: str) -> None:
        target_dirs = ["/mnt/root"]
        host = context.ssh_config.host

        for target_dir in target_dirs:
            # ensure .ssh and .age dirs
            rc = cli.run_command(
                command=SSHCommand(
                    inner=context.maybe_sudo(
                        ShellCommand("mkdir", ["-p", f"{target_dir}/.ssh", f"{target_dir}/.age"])
                    ),
                    config=context.ssh_config,
                ),
                description=f"Creating key directories at {target_dir}",
            )
            if rc != 0:
                raise InstallerError(f"Failed to create key dirs at {target_dir}")

            # upload SSH keys
            rc = cli.run_command(
                command=RsyncCommand(
                    src=f"{Path.home()}/.ssh/",
                    dest=f"{host}:{target_dir}/.ssh/",
                    ssh_config=context.ssh_config,
                    extra_args=["--include=id_*", "--exclude=*"],
                ),
                description=f"Copying SSH keys to {target_dir}/.ssh",
            )
            if rc != 0:
                raise InstallerError(f"Failed to copy SSH keys to {target_dir}")

            # upload AGE keys
            rc = cli.run_command(
                command=RsyncCommand(
                    src=f"{Path.home()}/.age/",
                    dest=f"{host}:{target_dir}/.age/",
                    ssh_config=context.ssh_config,
                ),
                description=f"Copying AGE keys to {target_dir}/.age",
            )
            if rc != 0:
                raise InstallerError(f"Failed to copy AGE keys to {target_dir}")
```

**Step 2: Implement GenerateInitrdSSHKeys**

```python
@define
class GenerateInitrdSSHKeys:
    name: str = "generate_initrd_ssh_keys"
    description: str = "Generating initrd SSH host keys on target"

    def should_skip(self, context: InstallerContext) -> bool:
        return not context.gen_initrd_ssh_keys

    def execute(self, context: InstallerContext, cli: CLI, tmp_dir: str) -> None:
        initrd_key_dir = f"/mnt/{context.initrd_ssh_key_dir}"

        rc = cli.run_command(
            command=SSHCommand(
                inner=context.maybe_sudo(
                    ShellCommand("mkdir", ["-p", initrd_key_dir])
                ),
                config=context.ssh_config,
            ),
            description="Creating initrd secrets directory",
        )
        if rc != 0:
            raise InstallerError("Failed to create initrd secrets directory")

        rc = cli.run_command(
            command=SSHCommand(
                inner=context.maybe_sudo(
                    ShellCommand(
                        "ssh-keygen",
                        [
                            "-t", "ed25519",
                            "-N", "",
                            "-f", f"{initrd_key_dir}/{context.initrd_ssh_key_name}",
                        ],
                    )
                ),
                config=context.ssh_config,
            ),
            description="Generating host SSH key for initrd",
        )
        if rc != 0:
            raise InstallerError("Failed to generate initrd SSH keys")
```

**Step 3: Implement InstallSystem**

```python
@define
class InstallSystem:
    name: str = "install_system"
    description: str = "Building and installing NixOS system"

    def should_skip(self, context: InstallerContext) -> bool:
        return False

    def execute(self, context: InstallerContext, cli: CLI, tmp_dir: str) -> None:
        import subprocess

        flake_dir = context.flake_dir(tmp_dir)
        flake_ref = f"{flake_dir}#nixosConfigurations.{context.flake_host}.config.system.build.toplevel"

        # 1. Build system closure locally
        cli.info("Building NixOS system closure...")
        result = subprocess.run(
            ["nix", "build", *_NIX_FLAGS, flake_ref, "--no-link", "--print-out-paths"],
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            cli.console.print(f"[red]nix build stderr:[/red]\n{result.stderr}")
            raise InstallerError(f"nix build failed with exit code {result.returncode}")

        store_path = result.stdout.strip()
        if not store_path:
            raise InstallerError("nix build produced no output path")
        cli.info(f"Built closure: {store_path}")

        # 2. Copy closure to target
        ssh_opts = f"-i {context.ssh_config.identity} -p {context.ssh_config.port}"
        rc = cli.run_command(
            command=NixCommand(
                [
                    "copy",
                    "--to",
                    f"ssh://{context.ssh_config.host}",
                    store_path,
                ],
                env={"NIX_SSHOPTS": ssh_opts},
            ),
            description="Copying system closure to target",
        )
        if rc != 0:
            raise InstallerError("Failed to copy closure to target")

        # 3. Install on target
        rc = cli.run_command(
            command=SSHCommand(
                inner=context.maybe_sudo(
                    ShellCommand(
                        "nixos-install",
                        [
                            "--no-root-password",
                            "--root",
                            "/mnt",
                            "--system",
                            store_path,
                        ],
                    )
                ),
                config=context.ssh_config,
            ),
            description=f"Installing NixOS for {context.flake_host}",
        )
        if rc != 0:
            raise InstallerError("nixos-install failed")
```

**Step 4: Run formatter and checks**

Run: `nix fmt && prek`

**Step 5: Commit**

```bash
git add _installer/src/installer/steps.py
git commit -m "feat(installer): add CopyKeys, GenerateInitrdSSHKeys, and InstallSystem steps"
```

---

### Task 13: App Entry Point Rework

**Files:**

- Modify: `_installer/src/installer/app.py`
- Delete (after this task): `_installer/src/installer/install.py`

**Step 1: Rewrite app.py**

```python
# _installer/src/installer/app.py
from pathlib import Path

from cyclopts import App
from rich.console import Console

from coisas.cli import CLI
from coisas.command import SSHConfig
from coisas.repository import RepositoryURI
from installer.context import InstallerContext, SecretsEncryptionParams
from installer.steps import (
    CloneRepositories,
    CommitFacter,
    CopyKeys,
    DecryptKeyfile,
    DownloadFacter,
    EvaluateDisko,
    GenerateInitrdSSHKeys,
    InstallSystem,
    Installer,
    RunDisko,
    RunFacter,
    SendDiskoConfig,
    SendKeyfile,
    UpdateFlakeLock,
)

app = App(
    name="my installer",
)


@app.default
def main(
    identity: Path,
    host: str,
    flake_host: str,
    flake: str = "git@github.com:joaovl5/_nix.git",
    secrets: str | None = "git@github.com:joaovl5/__secrets.git",
    secrets_file_disk_encryption: str | None = "secrets/disk_encryption.yaml",
    secrets_extract_disk_encryption_key: str | None = '["servers"]["tyrant"]',
    secrets_use_disk_encryption: bool = False,
    secrets_disk_encryption_keyfile_location: str = "/tmp/secret.key",
    use_sudo: bool = True,
    port: int = 22,
    auto_commit: bool = True,
    auto_push: bool = True,
) -> None:
    """Runs NixOS installer.

    Args:
        identity: SSH identity file to use.
        host: SSH host, as in `user@example.com`.
        flake_host: NixOS Configuration name to install, from flake.
        flake: Nix Flake source. Accepts local path, github:user/repo, or git URL.
        secrets: Secrets repository source. Same format as flake. Optional.
        secrets_file_disk_encryption: File in secrets repo with SOPS-encrypted disk keys.
        secrets_extract_disk_encryption_key: sops --extract key path for disk encryption.
        secrets_use_disk_encryption: Whether to use a keyfile for Disko.
        secrets_disk_encryption_keyfile_location: Where to place the decrypted keyfile.
        use_sudo: Prepend sudo to rootful commands. Disable if root on target.
        port: SSH port to connect to.
        auto_commit: Auto-commit facter and flake lock changes.
        auto_push: Auto-push after committing (requires auto_commit).
    """
    flake_uri = RepositoryURI.parse(flake)
    secrets_uri = RepositoryURI.parse(secrets) if secrets else None

    encryption_params: SecretsEncryptionParams | None = None
    if secrets_use_disk_encryption:
        if (
            secrets is None
            or secrets_file_disk_encryption is None
            or secrets_extract_disk_encryption_key is None
        ):
            raise SystemExit(
                "Error: all secrets options must be set when using disk encryption."
            )
        encryption_params = SecretsEncryptionParams(
            repo_url=secrets,
            sops_file=secrets_file_disk_encryption,
            sops_file_key=secrets_extract_disk_encryption_key,
            keyfile_location=secrets_disk_encryption_keyfile_location,
        )

    ssh_config = SSHConfig(host=host, identity=identity, port=port)

    context = InstallerContext(
        flake=flake_uri,
        flake_host=flake_host,
        secrets=secrets_uri,
        ssh_config=ssh_config,
        encryption_params=encryption_params,
        use_sudo=use_sudo,
        auto_commit=auto_commit,
        auto_push=auto_push,
    )

    cli = CLI(console=Console())
    cli.info(f"Prepared installer for [bold yellow]{host}:{port}[/bold yellow]")

    steps = [
        CloneRepositories(),
        DecryptKeyfile(),
        SendKeyfile(),
        EvaluateDisko(),
        SendDiskoConfig(),
        RunDisko(),
        RunFacter(),
        DownloadFacter(),
        CommitFacter(),
        UpdateFlakeLock(),
        CopyKeys(),
        GenerateInitrdSSHKeys(),
        InstallSystem(),
    ]

    installer = Installer(context=context, cli=cli, steps=steps)

    try:
        installer.run()
    except Exception as e:
        cli.console.print(f"[bold red]Installation failed:[/bold red] {e}")
        raise SystemExit(1)
```

**Step 2: Delete install.py**

Remove `_installer/src/installer/install.py` — fully replaced by `context.py` + `steps.py`.

**Step 3: Update `_installer/src/installer/__init__.py`**

Ensure it exports `app`:

```python
from installer.app import app

__all__ = ["app"]
```

**Step 4: Run formatter and checks**

Run: `nix fmt && prek`

**Step 5: Commit**

```bash
git add _installer/src/installer/app.py _installer/src/installer/__init__.py
git rm _installer/src/installer/install.py
git commit -m "feat(installer): rewrite app entry point, remove old install.py"
```

---

### Task 14: Step Unit Tests (Mocked CLI)

**Files:**

- Create: `_installer/tests/unit/test_steps.py`

**Step 1: Create mock CLI helper and write tests**

```python
# _installer/tests/unit/test_steps.py
from pathlib import Path
from unittest.mock import MagicMock

import pytest
from rich.console import Console

from coisas.cli import CLI
from coisas.command import (
    GitCommand,
    NixCommand,
    NixRunCommand,
    RsyncCommand,
    SSHCommand,
    SSHConfig,
    ShellCommand,
    SudoCommand,
)
from coisas.repository import RepositoryURI
from installer.context import InstallerContext, SecretsEncryptionParams
from installer.steps import (
    CloneRepositories,
    CommitFacter,
    CopyKeys,
    DecryptKeyfile,
    GenerateInitrdSSHKeys,
    RunDisko,
    RunFacter,
    SendKeyfile,
    UpdateFlakeLock,
)


def _make_context(
    flake: str = "github:user/repo",
    secrets: str | None = "github:user/secrets",
    encryption: bool = False,
    auto_commit: bool = True,
    auto_push: bool = True,
    use_sudo: bool = True,
) -> InstallerContext:
    return InstallerContext(
        flake=RepositoryURI.parse(flake),
        flake_host="testhost",
        secrets=RepositoryURI.parse(secrets) if secrets else None,
        ssh_config=SSHConfig(host="root@10.0.0.1", identity=Path("/tmp/key"), port=22),
        encryption_params=SecretsEncryptionParams(
            repo_url="git@github.com:user/secrets.git",
            sops_file="secrets/disk.yaml",
            sops_file_key='["key"]',
            keyfile_location="/tmp/secret.key",
        )
        if encryption
        else None,
        use_sudo=use_sudo,
        auto_commit=auto_commit,
        auto_push=auto_push,
    )


def _mock_cli(return_code: int = 0) -> CLI:
    cli = CLI(console=Console(quiet=True))
    cli.run_command = MagicMock(return_value=return_code)
    return cli


class TestCloneRepositories:
    def test_skips_when_both_local(self):
        ctx = _make_context(flake="/local/flake", secrets="/local/secrets")
        step = CloneRepositories()
        assert step.should_skip(ctx) is True

    def test_skips_when_no_secrets(self):
        ctx = _make_context(flake="/local/flake", secrets=None)
        step = CloneRepositories()
        assert step.should_skip(ctx) is True

    def test_does_not_skip_when_remote_flake(self):
        ctx = _make_context(flake="github:user/repo")
        step = CloneRepositories()
        assert step.should_skip(ctx) is False

    def test_clones_both_repos(self):
        ctx = _make_context()
        cli = _mock_cli()
        step = CloneRepositories()
        step.execute(ctx, cli, "/tmp/test")
        assert cli.run_command.call_count == 2

    def test_skips_local_flake_clones_remote_secrets(self):
        ctx = _make_context(flake="/local/flake", secrets="github:user/secrets")
        cli = _mock_cli()
        step = CloneRepositories()
        step.execute(ctx, cli, "/tmp/test")
        assert cli.run_command.call_count == 1


class TestDecryptKeyfile:
    def test_skips_without_encryption(self):
        ctx = _make_context(encryption=False)
        assert DecryptKeyfile().should_skip(ctx) is True

    def test_does_not_skip_with_encryption(self):
        ctx = _make_context(encryption=True)
        assert DecryptKeyfile().should_skip(ctx) is False


class TestSendKeyfile:
    def test_skips_without_encryption(self):
        ctx = _make_context(encryption=False)
        assert SendKeyfile().should_skip(ctx) is True

    def test_uses_rsync_with_ssh(self):
        ctx = _make_context(encryption=True)
        cli = _mock_cli()
        SendKeyfile().execute(ctx, cli, "/tmp/test")
        cmd = cli.run_command.call_args[1]["command"]
        assert isinstance(cmd, RsyncCommand)
        assert cmd.ssh_config is not None


class TestRunDisko:
    def test_never_skips(self):
        ctx = _make_context()
        assert RunDisko().should_skip(ctx) is False

    def test_runs_via_ssh_with_sudo(self):
        ctx = _make_context(use_sudo=True)
        cli = _mock_cli()
        RunDisko().execute(ctx, cli, "/tmp/test")
        cmd = cli.run_command.call_args[1]["command"]
        assert isinstance(cmd, SSHCommand)
        assert isinstance(cmd.inner, SudoCommand)
        assert isinstance(cmd.inner.inner, NixRunCommand)

    def test_runs_without_sudo(self):
        ctx = _make_context(use_sudo=False)
        cli = _mock_cli()
        RunDisko().execute(ctx, cli, "/tmp/test")
        cmd = cli.run_command.call_args[1]["command"]
        assert isinstance(cmd, SSHCommand)
        assert isinstance(cmd.inner, NixRunCommand)


class TestRunFacter:
    def test_uses_ssh_nix_run(self):
        ctx = _make_context()
        cli = _mock_cli()
        RunFacter().execute(ctx, cli, "/tmp/test")
        cmd = cli.run_command.call_args[1]["command"]
        assert isinstance(cmd, SSHCommand)


class TestCommitFacter:
    def test_skips_when_no_auto_commit(self):
        ctx = _make_context(auto_commit=False)
        assert CommitFacter().should_skip(ctx) is True

    def test_does_not_skip_when_auto_commit(self):
        ctx = _make_context(auto_commit=True)
        assert CommitFacter().should_skip(ctx) is False

    def test_pushes_when_auto_push(self):
        ctx = _make_context(auto_commit=True, auto_push=True)
        cli = _mock_cli()
        CommitFacter().execute(ctx, cli, "/tmp/test")
        # add + commit + push = 3 calls
        assert cli.run_command.call_count == 3

    def test_no_push_when_auto_push_false(self):
        ctx = _make_context(auto_commit=True, auto_push=False)
        cli = _mock_cli()
        CommitFacter().execute(ctx, cli, "/tmp/test")
        # add + commit only = 2 calls
        assert cli.run_command.call_count == 2


class TestUpdateFlakeLock:
    def test_skips_when_no_auto_commit(self):
        ctx = _make_context(auto_commit=False)
        assert UpdateFlakeLock().should_skip(ctx) is True


class TestGenerateInitrdSSHKeys:
    def test_skips_when_disabled(self):
        ctx = _make_context()
        # override with evolve-like approach — create new context
        ctx2 = InstallerContext(
            flake=ctx.flake,
            flake_host=ctx.flake_host,
            secrets=ctx.secrets,
            ssh_config=ctx.ssh_config,
            encryption_params=ctx.encryption_params,
            use_sudo=ctx.use_sudo,
            gen_initrd_ssh_keys=False,
        )
        assert GenerateInitrdSSHKeys().should_skip(ctx2) is True

    def test_does_not_skip_by_default(self):
        ctx = _make_context()
        assert GenerateInitrdSSHKeys().should_skip(ctx) is False
```

**Step 2: Run tests**

Run: `cd _installer && uv run pytest tests/unit/test_steps.py -v`

Expected: all PASS

**Step 3: Run formatter and checks**

Run: `nix fmt && prek`

**Step 4: Commit**

```bash
git add _installer/tests/unit/test_steps.py
git commit -m "test(installer): add unit tests for all steps with mocked CLI"
```

---

### Task 15: Integration Test Fixtures + Disko Eval Test

**Files:**

- Create: `_installer/tests/fixtures/test_flake/flake.nix`
- Create: `_installer/tests/fixtures/test_flake/disko.nix`
- Create: `_installer/tests/integration/test_evaluate_disko.py`
- Create: remaining integration test placeholders

**Step 1: Create minimal test flake**

This flake needs to be a valid NixOS configuration with disko devices. Create `_installer/tests/fixtures/test_flake/flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, disko, ... }: {
    nixosConfigurations.test-host = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        disko.nixosModules.disko
        ./disko.nix
        {
          # minimal config to make evaluation work
          boot.loader.grub.devices = [ "/dev/vda" ];
          fileSystems."/" = { device = "/dev/vda1"; fsType = "ext4"; };
          system.stateVersion = "24.11";
        }
      ];
    };
  };
}
```

Create `_installer/tests/fixtures/test_flake/disko.nix`:

```nix
{
  disko.devices = {
    disk.main = {
      type = "disk";
      device = "/dev/vda";
      content = {
        type = "gpt";
        partitions = {
          boot = {
            size = "512M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
            };
          };
          root = {
            size = "100%";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
            };
          };
        };
      };
    };
  };
}
```

**Step 2: Create the integration test**

```python
# _installer/tests/integration/test_evaluate_disko.py
"""Integration test for disko config evaluation.

MANUAL TEST — run with: pytest -m manual tests/integration/test_evaluate_disko.py -v

WARNING: The disko --dry-run test expects disko to be installed.
         Review output carefully before running non-dry-run disko.
"""

import json
import subprocess
from pathlib import Path

import pytest

# path to the test flake fixture
FIXTURE_DIR = Path(__file__).parent.parent / "fixtures" / "test_flake"

_NIX_FLAGS = ["--option", "experimental-features", "nix-command flakes"]

_DISKO_FILTER = """\
let
  filterDeep = x:
    if builtins.isAttrs x then
      builtins.mapAttrs (_: filterDeep)
        (removeAttrs x (builtins.filter (n: builtins.substring 0 1 n == "_") (builtins.attrNames x)))
    else x;
in filterDeep\
"""


@pytest.mark.manual
class TestEvaluateDisko:
    def test_nix_eval_produces_valid_json(self):
        """nix eval extracts disko devices as valid JSON."""
        flake_ref = f"{FIXTURE_DIR}#nixosConfigurations.test-host.config.disko.devices"

        result = subprocess.run(
            ["nix", "eval", *_NIX_FLAGS, flake_ref, "--json", "--apply", _DISKO_FILTER],
            capture_output=True,
            text=True,
        )

        assert result.returncode == 0, f"nix eval failed:\n{result.stderr}"

        devices = json.loads(result.stdout)
        assert "disk" in devices
        assert "main" in devices["disk"]

    def test_disko_dry_run_accepts_generated_config(self, tmp_path):
        """disko --dry-run accepts the generated nix file."""
        flake_ref = f"{FIXTURE_DIR}#nixosConfigurations.test-host.config.disko.devices"

        # eval
        result = subprocess.run(
            ["nix", "eval", *_NIX_FLAGS, flake_ref, "--json", "--apply", _DISKO_FILTER],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0, f"nix eval failed:\n{result.stderr}"

        # write files
        (tmp_path / "devices.json").write_text(result.stdout)
        (tmp_path / "disko.nix").write_text(
            '{ disko.devices = builtins.fromJSON (builtins.readFile ./devices.json); }\n'
        )

        # dry-run disko
        disko_result = subprocess.run(
            [
                "nix",
                "run",
                *_NIX_FLAGS,
                "github:nix-community/disko",
                "--",
                "--dry-run",
                "--mode",
                "destroy,format,mount",
                str(tmp_path / "disko.nix"),
            ],
            capture_output=True,
            text=True,
        )

        assert disko_result.returncode == 0, (
            f"disko --dry-run failed:\n{disko_result.stderr}\n{disko_result.stdout}"
        )
```

**Step 3: Create placeholder integration test files**

Create empty placeholder files (each with a module docstring only):

For each of: `test_build_system.py`, `test_commit_facter.py`, `test_clone_repositories.py`, `test_decrypt_keyfile.py`, `test_send_keyfile.py`, `test_send_disko_config.py`, `test_run_disko.py`, `test_run_facter.py`, `test_download_facter.py`, `test_update_flake_lock.py`, `test_copy_keys.py`, `test_generate_initrd_keys.py`, `test_install_system.py`:

```python
"""Placeholder integration test for <step_name>."""
```

**Step 4: Verify unit tests still pass (no regressions)**

Run: `cd _installer && uv run pytest tests/unit/ -v`

Expected: all PASS

**Step 5: Run formatter and checks**

Run: `nix fmt && prek`

**Step 6: Commit**

```bash
git add _installer/tests/
git commit -m "test(installer): add integration test for disko eval and test fixtures"
```

---

### Task 16: Final Verification

**Step 1: Run all unit tests**

Run: `cd _installer && uv run pytest tests/unit/ -v`

Expected: all PASS

**Step 2: Run formatter and pre-commit**

Run: `nix fmt && prek`

Expected: clean

**Step 3: Run flake check**

Run: `nix flake check --all-systems`

Expected: pass

**Step 4: Final commit if any formatting changes**

```bash
git add -A && git commit -m "style(installer): format"
```

(Only if `nix fmt` changed anything)
