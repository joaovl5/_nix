# Installer Rework Design

## Rationale

- Minimize operations on the target machine (fewer dependencies, less compute)
- Maximize leveraging existing local tooling
- Support local flake copies for rapid iteration without Git dependency

## Execution Model

The Python installer process runs **exclusively on the source machine**. Remote operations happen through SSH commands and rsync transfers. No Python code runs on the target.

---

## 1. Command Layer (`coisas/command.py`)

### Existing (kept)

- `Command` protocol, `ShellCommand`, `NixCommand`, `SudoCommand`, `_NIX_FLAGS`
- `NixRunCommand` — still needed for remote steps where tools aren't in PATH (disko via `nix run github:nix-community/disko`, facter via `nix run nixpkgs#nixos-facter`)

### Modified

**`GitCommand`** — `repo_path` now uses `git -C <path>` instead of `cd <path> && git`. This makes it work correctly with both local subprocess execution and SSH remote execution. New optional `config: dict[str, str]` field for per-command git config via `-c key=value` flags (used for committer identity without polluting global config).

```python
@define
class GitCommand:
    args: list[str] = Factory(list)
    env: dict[str, str] = Factory(dict)
    repo_path: str | None = None
    config: dict[str, str] = Factory(dict)  # per-command -c key=value

    def build(self) -> list[str]:
        env = _env_prefix(self.env)
        config_args = [arg for k, v in self.config.items() for arg in ["-c", f"{k}={v}"]]
        git = ["git"] + config_args
        if self.repo_path:
            git += ["-C", self.repo_path]
        git += self.args
        return env + git
```

### New additions

**`SSHConfig`** — frozen attrs class holding `host: str`, `identity: Path`, `port: int = 22`. Created once, shared across all remote commands.

**`SSHCommand`** — wraps any `Command` for remote execution.

- `render()`: `[ssh user@host] $ inner_command` (yellow prefix)
- `build()`: `["ssh", "-i", key, "-p", port, host, "--", "remote_cmd_string"]`
- **SSH quoting**: preserves the quoting logic from the current `SshCLI._build_ssh_command()` — quotes arguments containing whitespace with `shlex.quote()`, leaves globs/operators unquoted so they expand on the remote shell.

**`RsyncCommand`** — file transfer command with optional `SSHConfig`.

- `render()`: shows `rsync src -> dest` with SSH prefix when remote
- `build()`: `["rsync", "-avz", *extra_args, "-e", ssh_cmd, src, dest]`
- Uses `shlex.quote()` for identity path in the SSH command string (matching current `SshCLI._rsync_base()`)

**Composition**: `SSHCommand(inner=SudoCommand(inner=NixRunCommand(...)))` — sudo runs on the remote, SSH wraps the whole thing.

---

## 2. Repository URI (`coisas/repository.py`)

Project-agnostic module for parsing repository references.

```python
class URIType(Enum):
    LOCAL_PATH = "local_path"
    GIT_FORGE = "git_forge"
    GIT_URL = "git_url"

class GitForge(Enum):
    GITHUB = "github"
    GITLAB = "gitlab"
    GITEA = "gitea"

class RepositoryURI:
    raw: str
    type: URIType
    forge: GitForge | None  # only for GIT_FORGE type

    @classmethod
    def parse(cls, raw: str) -> RepositoryURI

    def needs_clone(self) -> bool
    def get_url(self) -> str
```

**Parsing rules**:

- `/`, `./`, `~` prefix → `LOCAL_PATH`
- `github:`, `gitlab:`, `gitea:` prefix → `GIT_FORGE` with corresponding forge
- `git@`, `git+ssh://`, `ssh://` prefix → `GIT_URL`
- `https://`, `http://` prefix → `GIT_URL`

Forge-to-URL mapping is a dict (`{"github": "github.com", "gitlab": "gitlab.com", ...}`), extensible.

Both `flake` and `secrets` parameters use this type.

---

## 3. CLI Rework (`coisas/cli.py`)

- **Keep `CLI`** as the single executor. It runs any `Command` uniformly — calls `build()` and executes via subprocess.
- **Keep** `panel_session()`, `run_command()`, Rich Live panel rendering.
- **Delete `SshCLI`** — replaced by `SSHCommand` and `RsyncCommand` at the command level.
- **Remove raw list-of-strings execution** — everything goes through `Command` objects.

---

## 4. Step Pipeline (`installer/steps.py`)

### Step Protocol

```python
class Step(Protocol):
    name: str
    description: str

    def should_skip(self, context: InstallerContext) -> bool: ...
    def execute(self, context: InstallerContext, cli: CLI, tmp_dir: str) -> None: ...
```

### InstallerContext (`installer/context.py`)

```python
@define(frozen=True)
class InstallerContext:
    flake: RepositoryURI
    flake_host: str
    secrets: RepositoryURI | None
    ssh_config: SSHConfig
    encryption_params: SecretsEncryptionParams | None
    use_sudo: bool
    auto_commit: bool = True         # --no-auto-commit to disable
    auto_push: bool = True           # --no-auto-push to disable

    # constants (with sensible defaults, overridable from CLI)
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

No `tmp_dir` — the temporary directory context manager wraps the orchestrator's `run()`, and the path is passed to `step.execute()`.

### Orchestrator

```python
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

On failure: `step.execute()` raises `InstallerError` on actual command failures, which stops the pipeline immediately and exits with an error message. Non-fatal conditions (e.g., `git commit` returning non-zero when there's nothing to commit) are handled within the step logic — the step checks the return code and only raises if it's a genuine error.

### Steps (ordered)

| #   | Step                    | Location                     | Skippable                                 |
| --- | ----------------------- | ---------------------------- | ----------------------------------------- |
| 1   | `CloneRepositories`     | Local (git)                  | Skips repos with `needs_clone() == False` |
| 2   | `DecryptKeyfile`        | Local (sops)                 | Yes — no encryption params                |
| 3   | `SendKeyfile`           | Remote (rsync)               | Yes — no encryption params                |
| 4   | `EvaluateDisko`         | Local (nix eval)             | No                                        |
| 5   | `SendDiskoConfig`       | Remote (rsync)               | No                                        |
| 6   | `RunDisko`              | Remote (ssh + nix run)       | No                                        |
| 7   | `RunFacter`             | Remote (ssh + nix run)       | No                                        |
| 8   | `DownloadFacter`        | Local (rsync)                | No                                        |
| 9   | `CommitFacter`          | Local (git)                  | `auto_commit == False`                    |
| 10  | `UpdateFlakeLock`       | Local (nix)                  | `auto_commit == False`                    |
| 11  | `CopyKeys`              | Remote (rsync)               | No                                        |
| 12  | `GenerateInitrdSSHKeys` | Remote (ssh)                 | `gen_initrd_ssh_keys == False`            |
| 13  | `InstallSystem`         | Local build + remote install | No                                        |

**Commit/push behavior**:

- `CommitFacter` commits the facter JSON to the secrets repo and optionally pushes. Skipped entirely when `auto_commit == False`.
- `UpdateFlakeLock` runs `nix flake update <secrets_input>`, commits the updated lockfile to the flake repo, and optionally pushes. Skipped entirely when `auto_commit == False`.
- Push within each step is controlled by `auto_push`. When `auto_push == False`, commits are made but not pushed.
- Git operations use per-command config for committer identity: `git -c user.name=nixos-installer -c user.email=nixos-installer@local commit ...`

**Remote steps**: Steps 6 (`RunDisko`) and 7 (`RunFacter`) use `NixRunCommand` via `SSHCommand` to run tools on the target (e.g., `nix run github:nix-community/disko -- ...`). The target only needs `nix` available (standard on NixOS ISOs), and since these commands operate on standalone files (not flake references), they don't trigger flake input fetches.

---

## 5. Disko Config Evaluation (Step 4)

Extracts disko device config from the flake, producing a standalone `.nix` file.

**Process**:

1. Run `nix eval <flake_dir>#nixosConfigurations.<host>.config.disko.devices --json --apply '<filter>'`

   The flake directory is resolved via `context.flake_dir(tmp_dir)`.

   The filter recursively removes underscore-prefixed attributes (e.g., `_packages`) that contain functions and can't be serialized:

   ```nix
   let
     filterDeep = x:
       if builtins.isAttrs x then
         builtins.mapAttrs (_: filterDeep)
           (removeAttrs x (builtins.filter (n: builtins.substring 0 1 n == "_") (builtins.attrNames x)))
       else x;
   in filterDeep
   ```

2. Write JSON output to `<tmp_dir>/devices.json`

3. Generate wrapper Nix file at `<tmp_dir>/disko.nix`:

   ```nix
   { disko.devices = builtins.fromJSON (builtins.readFile ./devices.json); }
   ```

4. Both files must be in the same directory (the wrapper uses `./devices.json` relative path). Sent together to target via `RsyncCommand` to a shared remote location (e.g., `/tmp/disko/`).

---

## 6. System Install (Step 13)

Single step handling build, transfer, and install:

1. **Build** (local): `nix build <flake_dir>#nixosConfigurations.<host>.config.system.build.toplevel --no-link --print-out-paths`

   Flake directory resolved via `context.flake_dir(tmp_dir)`.

2. **Transfer**: `nix copy --to ssh://user@host <store-path>`

   `nix copy` uses its own SSH, not the installer's. SSH options are passed via the `NIX_SSHOPTS` environment variable: `NIX_SSHOPTS="-i /path/to/identity -p PORT"`. This is set as an env var on the `NixCommand`.

3. **Install** (remote via SSH): `nixos-install --no-root-password --root /mnt --system <store-path>`

Store path is a local variable within the step. Assumes same architecture between source and target (cross-arch deferred to future work).

---

## 7. App Entry Point (`installer/app.py`)

**Parameter changes**:

- `flake_repo: str` → `flake: str` (any `RepositoryURI` format)
- `secrets_repo: str | None` → `secrets: str | None` (same)
- New: `--no-auto-commit` flag (default: auto-commit enabled)
- New: `--no-auto-push` flag (default: auto-push enabled)

Parses URIs, constructs `InstallerContext`, builds step list, creates `Installer`, calls `run()`.

---

## 8. Testing

### Structure

```
_installer/tests/
  unit/
    test_repository.py           # RepositoryURI parsing + get_url()
    test_commands.py              # Command.build() for all types
    test_steps.py                 # Step execution with mocked CLI.run_command()
  integration/
    test_evaluate_disko.py        # manual: nix eval + disko --dry-run
    test_build_system.py          # placeholder
    test_commit_facter.py         # placeholder
    test_clone_repositories.py    # placeholder
    test_decrypt_keyfile.py       # placeholder
    test_send_keyfile.py          # placeholder
    test_send_disko_config.py     # placeholder
    test_run_disko.py             # placeholder
    test_run_facter.py            # placeholder
    test_download_facter.py       # placeholder
    test_update_flake_lock.py     # placeholder
    test_copy_keys.py             # placeholder
    test_generate_initrd_keys.py  # placeholder
    test_install_system.py        # placeholder
  fixtures/
    test_flake/                   # minimal flake with disko config
```

### Unit tests (no mocking)

- `RepositoryURI.parse()` — all format branches, edge cases, forge detection, `https://` URLs
- `RepositoryURI.get_url()` — forge-to-URL conversion, local path passthrough
- `Command.build()` — every command type produces correct argument lists
- `SSHCommand` — quoting logic, composition with `SudoCommand`/`NixRunCommand`
- `RsyncCommand` — with and without SSH config
- `GitCommand` — `-C` path, `-c` config flags

### Step tests (mocked `CLI.run_command()` only)

- Each step test verifies correct sequence of `Command` objects produced
- Test `should_skip()` logic for conditional steps
- Test context variations (with/without encryption, local vs remote repos)
- Test `auto_commit`/`auto_push` flag behavior on git steps
- Test non-fatal return codes (e.g., git commit with nothing to commit)

### Integration tests

- Marked `@pytest.mark.manual` — excluded from normal pytest runs, run with `pytest -m manual`
- **`test_evaluate_disko`**: eval a minimal test flake's disko config, verify valid JSON output, run `disko --dry-run` against generated config (expects disko installed on host)
- **`test_build_system`**: build a minimal NixOS config, verify store path produced
- **`test_commit_facter`**: init temp git repo, run step with dummy facter JSON, verify commit

---

## 9. Future Work (placeholder)

**nixos-anywhere integration**: Optional `--pre-install-kexec` flag for kexec into NixOS installer and key copy. Deactivated by default. No implementation in this rework.

**Cross-architecture builds**: `--build-on auto|local|remote` flag. Default to local same-arch builds. Remote build support for when source and target architectures differ.

---

## File Layout

```
_installer/src/
  coisas/
    __init__.py
    cli.py                  # CLI only (SshCLI removed)
    command.py              # existing + SSHConfig, SSHCommand, RsyncCommand
    repository.py           # RepositoryURI (new)
  installer/
    __init__.py
    app.py                  # cyclopts entry (updated params)
    context.py              # InstallerContext (new)
    steps.py                # Step protocol + all step classes (new)
                            # install.py deleted — replaced by steps.py + context.py
```
