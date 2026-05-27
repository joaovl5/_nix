from pathlib import Path

from coisas.command import (
  GitCommand,
  GitHelper,
  NixCommand,
  NixRunCommand,
  PassthroughWrapper,
  RsyncCommand,
  ShellCommand,
  SSHCommand,
  SSHConfig,
  SSHWrapper,
  SudoCommand,
  SudoWrapper,
)


class TestShellCommand:
  def test_basic(self):
    """Build a plain shell command without extra wrappers."""
    cmd = ShellCommand("ls", ["-la"])
    # Assert positional shell arguments are preserved in build output.
    assert cmd.build() == ["ls", "-la"]

  def test_with_env(self):
    """Prefix shell commands with environment assignments when requested."""
    cmd = ShellCommand("make", env={"CC": "gcc"})
    # Assert environment variables are emitted through the env prefix.
    assert cmd.build() == ["env", "CC=gcc", "make"]


class TestNixCommand:
  def test_basic(self):
    """Inject the shared experimental-feature flags into nix commands."""
    cmd = NixCommand(["eval", "nixpkgs#hello"])
    result = cmd.build()
    # Assert the nix executable and shared flags are present.
    assert result[0] == "nix"
    assert "--option" in result
    assert "experimental-features" in result
    assert "nix-command flakes" in result
    nix_idx = result.index("nix")
    # Assert user-provided arguments remain after the nix prefix and flags.
    for arg in ["eval", "nixpkgs#hello"]:
      assert arg in result[nix_idx + 1 :]

  def test_with_env(self):
    """Preserve environment overrides on nix commands."""
    cmd = NixCommand(["copy"], env={"NIX_SSHOPTS": "-i /key -p 22"})
    result = cmd.build()
    # Assert nix commands can be prefixed with env assignments.
    assert result[0] == "env"
    assert "NIX_SSHOPTS=-i /key -p 22" in result


class TestNixRunCommand:
  def test_basic(self):
    """Build a nix run command for the selected package."""
    cmd = NixRunCommand("nixpkgs#hello")
    result = cmd.build()
    # Assert the package selection is preserved in the nix run command.
    assert "nix" in result
    assert "run" in result
    assert "nixpkgs#hello" in result

  def test_with_args(self):
    """Insert the `--` separator before forwarded nix run arguments."""
    cmd = NixRunCommand("nixpkgs#sops", ["-d", "secrets.yaml"])
    result = cmd.build()
    idx = result.index("--")
    # Assert forwarded package arguments are kept after the separator.
    assert result[idx + 1 :] == ["-d", "secrets.yaml"]


class TestSudoCommand:
  def test_wraps_shell(self):
    """Prefix shell commands with sudo."""
    cmd = SudoCommand(inner=ShellCommand("nixos-install", ["--root", "/mnt"]))
    # Assert sudo is inserted before the wrapped shell command.
    assert cmd.build() == ["sudo", "nixos-install", "--root", "/mnt"]

  def test_wraps_nix_command(self):
    """Prefix nix commands with sudo without dropping nix arguments."""
    cmd = SudoCommand(inner=NixCommand(["profile", "install", "nixpkgs#git"]))
    result = cmd.build()
    # Assert sudo wraps the underlying nix command rather than replacing it.
    assert result[0] == "sudo"
    assert result[1] == "nix"


class TestGitCommand:
  def test_basic_args(self):
    """Build git commands without extra repository context."""
    cmd = GitCommand(args=["status"])
    # Assert the bare git invocation is preserved.
    assert cmd.build() == ["git", "status"]

  def test_repo_path_uses_dash_c(self):
    """Target a specific repository path with `git -C`."""
    cmd = GitCommand(args=["status"], repo_path="/tmp/repo")
    # Assert the repository path is threaded through `git -C`.
    assert cmd.build() == ["git", "-C", "/tmp/repo", "status"]

  def test_config_flags(self):
    """Emit git config overrides before the subcommand."""
    cmd = GitCommand(
      args=["commit", "-m", "test"],
      config={"user.name": "nixos-installer", "user.email": "nix@local"},
    )
    result = cmd.build()
    # Assert each config entry becomes a `-c key=value` pair.
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
    """Combine git config overrides with repository targeting."""
    cmd = GitCommand(
      args=["add", "."],
      repo_path="/tmp/repo",
      config={"user.name": "installer"},
    )
    result = cmd.build()
    # Assert config and repository targeting coexist in the rendered command.
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
    """Support environment overrides on git commands."""
    cmd = GitCommand(args=["push"], env={"GIT_SSH_COMMAND": "ssh -o Foo=bar"})
    result = cmd.build()
    # Assert git commands can be prefixed with env assignments.
    assert result == [
      "env",
      "GIT_SSH_COMMAND=ssh -o Foo=bar",
      "git",
      "push",
    ]


class TestSSHCommand:
  def _config(self) -> SSHConfig:
    return SSHConfig(
      host="root@192.168.1.1", identity=Path("/tmp/id_ed25519")
    )

  def test_basic_build(self):
    """Wrap a shell command for remote execution over SSH."""
    inner = ShellCommand("ls", ["/tmp"])
    cmd = SSHCommand(inner=inner, config=self._config())
    result = cmd.build()
    # Assert the SSH invocation carries identity, port, host, and remote command.
    assert result == [
      "ssh",
      "-i",
      "/tmp/id_ed25519",
      "-p",
      "59222",
      "root@192.168.1.1",
      "--",
      "ls /tmp",
    ]

  def test_quoting_whitespace_args(self):
    """Quote remote arguments that contain whitespace."""
    inner = ShellCommand("echo", ["hello world"])
    cmd = SSHCommand(inner=inner, config=self._config())
    result = cmd.build()
    remote_str = result[-1]
    # Assert the remote shell string quotes whitespace-containing arguments.
    assert remote_str == "echo 'hello world'"

  def test_globs_not_quoted(self):
    """Leave remote globs unquoted so the remote shell can expand them."""
    inner = ShellCommand("cp", ["/tmp/.ssh/id_*", "/root/.ssh/"])
    cmd = SSHCommand(inner=inner, config=self._config())
    remote_str = cmd.build()[-1]
    # Assert glob characters survive quoting so the remote shell expands them.
    assert "id_*" in remote_str
    assert "'id_*'" not in remote_str

  def test_wraps_sudo(self):
    """Preserve nested sudo wrapping inside the remote shell string."""
    inner = SudoCommand(
      inner=ShellCommand("nixos-install", ["--root", "/mnt"])
    )
    cmd = SSHCommand(inner=inner, config=self._config())
    result = cmd.build()
    remote_str = result[-1]
    # Assert sudo remains part of the remote command payload.
    assert remote_str == "sudo nixos-install --root /mnt"

  def test_wraps_nix_run(self):
    """Preserve nix run argument forwarding inside the remote shell string."""
    inner = NixRunCommand(
      "github:nix-community/disko",
      [
        "--yes-wipe-all-disks",
        "--mode",
        "destroy,format,mount",
        "/tmp/disko.nix",
      ],
    )
    cmd = SSHCommand(inner=inner, config=self._config())
    result = cmd.build()
    remote_str = result[-1]
    # Assert the remote shell string still reflects the nix run package and args.
    assert "nix run" in remote_str
    assert "github:nix-community/disko" in remote_str
    assert "-- --yes-wipe-all-disks" in remote_str

  def test_custom_port(self):
    """Use the configured non-default SSH port."""
    config = SSHConfig(host="user@host", identity=Path("/key"), port=2222)
    cmd = SSHCommand(inner=ShellCommand("whoami"), config=config)
    result = cmd.build()
    # Assert the configured port is emitted in the SSH command.
    assert "-p" in result
    assert "2222" in result


class TestRsyncCommand:
  def _config(self) -> SSHConfig:
    return SSHConfig(
      host="root@192.168.1.1", identity=Path("/tmp/id_ed25519")
    )

  def test_local_rsync(self):
    """Build a local rsync command without SSH transport."""
    cmd = RsyncCommand(src="/tmp/file.json", dest="/backup/file.json")
    result = cmd.build()
    # Assert local rsync uses only source and destination paths.
    assert result == ["rsync", "-avz", "/tmp/file.json", "/backup/file.json"]

  def _get_ssh_str(self, result: list[str]) -> str:
    """Extract the ssh command string (value after -e flag)."""
    idx = result.index("-e")
    return result[idx + 1]

  def test_remote_rsync_with_ssh(self):
    """Build an rsync command that targets the remote destination over SSH."""
    cmd = RsyncCommand(
      src="/tmp/devices.json",
      dest="/tmp/disko/",
      ssh_config=self._config(),
    )
    result = cmd.build()
    ssh_str = self._get_ssh_str(result)
    # Assert rsync is configured for SSH transport and remote destination syntax.
    assert result[0] == "rsync"
    assert "-avz" in result
    assert "-e" in result
    assert result[-1] == "root@192.168.1.1:/tmp/disko/"
    assert result[-2] == "/tmp/devices.json"
    # Assert the SSH transport carries the configured identity and port.
    assert "-i" in ssh_str
    assert "/tmp/id_ed25519" in ssh_str
    assert "-p 59222" in ssh_str

  def test_remote_dest_false_prepends_host_to_src(self):
    """Treat the source as remote when `remote_dest` is disabled."""
    cmd = RsyncCommand(
      src="/tmp/facter.json",
      dest="/local/facter.json",
      ssh_config=self._config(),
      remote_dest=False,
    )
    result = cmd.build()
    # Assert the host prefix moves from destination to source.
    assert result[-2] == "root@192.168.1.1:/tmp/facter.json"
    assert result[-1] == "/local/facter.json"

  def test_extra_args(self):
    """Append caller-provided rsync flags after the default options."""
    cmd = RsyncCommand(
      src="/tmp/src/",
      dest="/tmp/dest/",
      ssh_config=self._config(),
      extra_args=["--include=id_*", "--exclude=*"],
    )
    result = cmd.build()
    # Assert additional rsync filters are preserved in the final command.
    assert "--include=id_*" in result
    assert "--exclude=*" in result

  def test_identity_path_with_spaces_quoted(self):
    """Quote SSH identity paths that contain whitespace."""
    config = SSHConfig(
      host="user@host",
      identity=Path("/path with spaces/key"),
      port=22,
    )
    cmd = RsyncCommand(src="/a", dest="/b", ssh_config=config)
    result = cmd.build()
    ssh_str = self._get_ssh_str(result)
    # Assert the embedded SSH command quotes the identity path safely.
    assert (
      "'/path with spaces/key'" in ssh_str
      or '"/path with spaces/key"' in ssh_str
    )


class TestCommandWrappers:
  def _config(self) -> SSHConfig:
    return SSHConfig(
      host="root@192.168.1.1", identity=Path("/tmp/id_ed25519")
    )

  def test_ssh_wrapper(self):
    """Wrap commands with SSH transport."""
    wrapper = SSHWrapper(config=self._config())
    cmd = wrapper.wrap(ShellCommand("ls"))
    # Assert the SSH wrapper preserves the configured remote host.
    assert isinstance(cmd, SSHCommand)
    assert cmd.config.host == "root@192.168.1.1"

  def test_sudo_wrapper(self):
    """Wrap commands with sudo."""
    wrapper = SudoWrapper()
    cmd = wrapper.wrap(ShellCommand("ls"))
    # Assert the sudo wrapper prefixes the command with sudo.
    assert isinstance(cmd, SudoCommand)
    assert cmd.build() == ["sudo", "ls"]

  def test_passthrough_wrapper(self):
    """Return the original command unchanged."""
    wrapper = PassthroughWrapper()
    inner = ShellCommand("ls")
    cmd = wrapper.wrap(inner)
    # Assert the passthrough wrapper leaves the original object intact.
    assert cmd is inner

  def test_composed_ssh_sudo(self):
    """Compose SSH and sudo wrappers in order."""
    composed = SSHWrapper(config=self._config()) | SudoWrapper()
    cmd = composed.wrap(ShellCommand("ls"))
    # Assert the composed wrapper nests sudo inside SSH.
    assert isinstance(cmd, SSHCommand)
    assert isinstance(cmd.inner, SudoCommand)

  def test_composed_ssh_passthrough(self):
    """Compose SSH with a passthrough wrapper without adding sudo."""
    composed = SSHWrapper(config=self._config()) | PassthroughWrapper()
    cmd = composed.wrap(ShellCommand("ls"))
    # Assert passthrough composition leaves the inner command unwrapped.
    assert isinstance(cmd, SSHCommand)
    assert not isinstance(cmd.inner, SudoCommand)

  def test_pipe_to_command(self):
    """Pipe composed wrappers directly into a command."""
    cmd = (
      SSHWrapper(config=self._config()) | SudoWrapper() | ShellCommand("ls")
    )
    # Assert piping produces the same nested wrapper structure as manual wrap.
    assert isinstance(cmd, SSHCommand)
    assert isinstance(cmd.inner, SudoCommand)
    assert isinstance(cmd.inner.inner, ShellCommand)

  def test_pipe_single_to_command(self):
    """Pipe a single wrapper directly into a command."""
    cmd = SudoWrapper() | ShellCommand("ls")
    # Assert piping one wrapper still returns the wrapped command instance.
    assert isinstance(cmd, SudoCommand)
    assert isinstance(cmd.inner, ShellCommand)


class TestGitHelper:
  def _helper(self) -> GitHelper:
    return GitHelper(
      config={"user.name": "test", "user.email": "test@local"},
      repo_path="/tmp/repo",
    )

  def test_add(self):
    """Build a git add command rooted at the helper repository."""
    cmd = self._helper().add([".", "extra.txt"])
    result = cmd.build()
    # Assert git add uses the helper's configured repository path.
    assert isinstance(cmd, GitCommand)
    assert "-C" in result
    assert "/tmp/repo" in result
    assert "add" in result
    assert "." in result
    assert "extra.txt" in result

  def test_commit(self):
    """Build a git commit command with helper config overrides."""
    cmd = self._helper().commit("test message")
    result = cmd.build()
    # Assert git commit includes the message and helper identity settings.
    assert "commit" in result
    assert "-m" in result
    assert "test message" in result
    assert "user.name=test" in result

  def test_push(self):
    """Build a git push command with the default remote and ref."""
    cmd = self._helper().push()
    result = cmd.build()
    # Assert git push uses the expected upstream defaults.
    assert "push" in result
    assert "-u" in result
    assert "origin" in result
    assert "HEAD" in result
