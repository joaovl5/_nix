from collections.abc import Sequence
from inspect import signature
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest
from coisas.cli import CLI
from coisas.command import (
  Command,
  RsyncCommand,
  ShellCommand,
  SSHCommand,
  SSHConfig,
  SudoCommand,
)
from coisas.repository import RepositoryURI
from installer.app import main
from installer.context import (
  InstallerContext,
  InstallerError,
  SecretsEncryptionParams,
)
from installer.steps import (
  CloneRepositories,
  CommitFacter,
  ConfigureSubstituters,
  DecryptKeyfile,
  GenerateInitrdSSHKeys,
  Installer,
  InstallSystem,
  RunDisko,
  RunFacter,
  SendKeyfile,
  UpdateSecretsPin,
  nix_build,
  nix_copy_command,
)
from rich.console import Console


def _make_context(
  flake: str = "github:user/repo",
  secrets: str | None = "github:user/secrets",
  encryption: bool = False,
  auto_commit: bool = True,
  auto_push: bool = True,
  use_sudo: bool = True,
  tmp_dir: str = "/tmp/test",
) -> InstallerContext:
  return InstallerContext(
    flake=RepositoryURI.parse(flake),
    flake_host="testhost",
    secrets=RepositoryURI.parse(secrets) if secrets else None,
    ssh_config=SSHConfig(host="root@10.0.0.1", identity=Path("/tmp/key")),
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
    tmp_dir=tmp_dir,
  )


class MockCLI(CLI):
  """CLI test double that records installer command invocations."""

  run_command: MagicMock
  info: MagicMock


def _mock_cli(return_code: int = 0) -> MockCLI:
  cli = MockCLI(console=Console(quiet=True))
  cli.run_command = MagicMock(return_value=return_code)
  cli.info = MagicMock()
  return cli


def _get_command(cli: MockCLI, call_index: int = -1) -> Command:
  """Extract the command kwarg from a mocked cli.run_command call."""
  return cli.run_command.call_args_list[call_index][1]["command"]


def _assert_type_tree(cmd: object, types: Sequence[type[object]]) -> None:
  for expected in types:
    assert isinstance(cmd, expected)
    cmd = getattr(cmd, "inner", None)


class TestCloneRepositories:
  def test_skips_when_both_local(self):
    """Skip cloning when both repositories are already local paths."""
    ctx = _make_context(flake="/local/flake", secrets="/local/secrets")
    step = CloneRepositories()
    # Assert the step is skipped when no clone operation is required.
    assert step.should_skip(ctx) is True

  def test_skips_when_no_secrets(self):
    """Skip cloning when the flake is local and no secrets repository exists."""
    ctx = _make_context(flake="/local/flake", secrets=None)
    step = CloneRepositories()
    # Assert the missing secrets repository does not force a clone.
    assert step.should_skip(ctx) is True

  def test_does_not_skip_when_remote_flake(self):
    """Run cloning when the flake source must be fetched remotely."""
    ctx = _make_context(flake="github:user/repo")
    step = CloneRepositories()
    # Assert a remote flake source keeps the step enabled.
    assert step.should_skip(ctx) is False

  def test_clones_both_repos(self):
    """Clone both repositories when both inputs are remote."""
    ctx = _make_context()
    cli = _mock_cli()
    step = CloneRepositories()
    step.execute(ctx, cli)
    # Assert the step schedules one clone per remote repository.
    assert cli.run_command.call_count == 2

  def test_skips_local_flake_clones_remote_secrets(self):
    """Clone only the remote secrets repository when the flake is local."""
    ctx = _make_context(flake="/local/flake", secrets="github:user/secrets")
    cli = _mock_cli()
    step = CloneRepositories()
    step.execute(ctx, cli)
    # Assert only the remote secrets repository triggers a command.
    assert cli.run_command.call_count == 1


class TestDecryptKeyfile:
  def test_skips_without_encryption(self):
    """Skip decryption when disk-encryption settings are absent."""
    ctx = _make_context(encryption=False)
    # Assert the step stays disabled without encryption parameters.
    assert DecryptKeyfile().should_skip(ctx) is True

  def test_does_not_skip_with_encryption(self):
    """Run decryption when disk-encryption settings are present."""
    ctx = _make_context(encryption=True)
    # Assert the step becomes active once encryption parameters exist.
    assert DecryptKeyfile().should_skip(ctx) is False


class TestSendKeyfile:
  def test_skips_without_encryption(self):
    """Skip key transfer when no disk-encryption keyfile is configured."""
    ctx = _make_context(encryption=False)
    # Assert the transfer step is disabled without encryption parameters.
    assert SendKeyfile().should_skip(ctx) is True

  def test_uses_rsync_with_ssh(self):
    """Send the decrypted keyfile over rsync with SSH transport."""
    ctx = _make_context(encryption=True)
    cli = _mock_cli()
    SendKeyfile().execute(ctx, cli)
    # Assert the step performs mkdir, rsync, and final move commands.
    assert cli.run_command.call_count == 3
    rsync_cmd = _get_command(cli, 1)
    # Assert the second command is the rsync transfer.
    assert isinstance(rsync_cmd, RsyncCommand)
    # Assert rsync is configured to use SSH transport.
    assert rsync_cmd.ssh_config is not None


class TestConfigureSubstituters:
  def test_never_skips(self):
    """Always configure substituters before remote builds."""
    ctx = _make_context()
    # Assert the step is always eligible to run.
    assert ConfigureSubstituters().should_skip(ctx) is False

  @patch("installer.steps.subprocess.run")
  def test_evaluates_substituters_and_writes_to_target(
    self, mock_run: MagicMock
  ):
    """Evaluate substituter settings locally before writing them remotely."""
    mock_run.return_value = MagicMock(
      returncode=0,
      stdout="https://cache.nixos.org https://mycache.example.com",
      stderr="",
    )
    ctx = _make_context()
    cli = _mock_cli()
    ConfigureSubstituters().execute(ctx, cli)
    # Assert the step evaluates both substituters and trusted keys locally.
    assert mock_run.call_count == 2
    # Assert the rendered config is written with a single remote command.
    assert cli.run_command.call_count == 1

  @patch("installer.steps.subprocess.run")
  def test_nix_eval_failure_raises(self, mock_run: MagicMock):
    """Propagate evaluation failures as installer errors."""
    mock_run.return_value = MagicMock(
      returncode=1, stdout="", stderr="eval error"
    )
    ctx = _make_context()
    cli = _mock_cli()
    # Assert a failed nix eval surfaces as an InstallerError.
    with pytest.raises(InstallerError, match="nix eval failed"):
      ConfigureSubstituters().execute(ctx, cli)


class TestRunDisko:
  def test_never_skips(self):
    """Always run Disko during installation."""
    ctx = _make_context()
    # Assert Disko is always part of the installer flow.
    assert RunDisko().should_skip(ctx) is False

  @patch(
    "installer.steps.nix_build", return_value="/nix/store/abc-disko-script"
  )
  def test_builds_disko_script_locally(self, mock_build: MagicMock):
    """Build the Disko script from the selected flake host."""
    ctx = _make_context()
    cli = _mock_cli()
    RunDisko().execute(ctx, cli)
    mock_build.assert_called_once()
    ref = mock_build.call_args[0][0]
    # Assert the build target is the Disko script attribute.
    assert "diskoScript" in ref
    # Assert the build target is scoped to the selected host.
    assert ctx.flake_host in ref

  @patch(
    "installer.steps.nix_build", return_value="/nix/store/abc-disko-script"
  )
  def test_copies_and_runs_via_ssh(self, _mock_build: MagicMock):
    """Copy the built script and execute it remotely."""
    ctx = _make_context(use_sudo=True)
    cli = _mock_cli()
    RunDisko().execute(ctx, cli)
    # Assert the step copies, runs, and garbage-collects on the target.
    assert cli.run_command.call_count == 3

  @patch(
    "installer.steps.nix_build", return_value="/nix/store/abc-disko-script"
  )
  def test_runs_store_path_on_target(self, _mock_build: MagicMock):
    """Execute the copied Disko store path through SSH and sudo."""
    ctx = _make_context(use_sudo=True)
    cli = _mock_cli()
    RunDisko().execute(ctx, cli)
    run_cmd = _get_command(cli, 1)
    # Assert the remote execution wraps the command in SSH and sudo.
    _assert_type_tree(run_cmd, [SSHCommand, SudoCommand, ShellCommand])


class TestRunFacter:
  @patch(
    "installer.steps.nix_build", return_value="/nix/store/abc-nixos-facter"
  )
  def test_builds_facter_locally(self, mock_build: MagicMock):
    """Build nixos-facter from nixpkgs before remote execution."""
    ctx = _make_context()
    cli = _mock_cli()
    RunFacter().execute(ctx, cli)
    # Assert the builder targets the nixos-facter package.
    mock_build.assert_called_once_with("nixpkgs#nixos-facter")

  @patch(
    "installer.steps.nix_build", return_value="/nix/store/abc-nixos-facter"
  )
  def test_copies_and_runs_via_ssh(self, _mock_build: MagicMock):
    """Copy the built facter closure and execute it remotely."""
    ctx = _make_context()
    cli = _mock_cli()
    RunFacter().execute(ctx, cli)
    # Assert the step copies, runs, and garbage-collects on the target.
    assert cli.run_command.call_count == 3

  @patch(
    "installer.steps.nix_build", return_value="/nix/store/abc-nixos-facter"
  )
  def test_runs_facter_binary_on_target(self, _mock_build: MagicMock):
    """Run the nixos-facter binary from the copied store path."""
    ctx = _make_context(use_sudo=True)
    cli = _mock_cli()
    RunFacter().execute(ctx, cli)
    run_cmd = _get_command(cli, 1)
    # Assert the command is wrapped for remote privileged execution.
    _assert_type_tree(run_cmd, [SSHCommand, SudoCommand, ShellCommand])
    assert isinstance(run_cmd, SSHCommand)
    assert isinstance(run_cmd.inner, SudoCommand)
    assert isinstance(run_cmd.inner.inner, ShellCommand)
    inner = run_cmd.inner.inner
    # Assert the executed binary path points at the built nixos-facter output.
    assert (
      "nixos-facter" in inner.program or "abc-nixos-facter" in inner.program
    )


class TestCommitFacter:
  def test_skips_when_no_auto_commit(self):
    """Skip committing facter output when auto-commit is disabled."""
    ctx = _make_context(auto_commit=False)
    # Assert the step is disabled without auto-commit.
    assert CommitFacter().should_skip(ctx) is True

  def test_does_not_skip_when_auto_commit(self):
    """Run the commit step when auto-commit is enabled."""
    ctx = _make_context(auto_commit=True)
    # Assert enabling auto-commit keeps the step active.
    assert CommitFacter().should_skip(ctx) is False

  def test_pushes_when_auto_push(self):
    """Push the secrets repository after committing when configured."""
    ctx = _make_context(auto_commit=True, auto_push=True)
    cli = _mock_cli()
    CommitFacter().execute(ctx, cli)
    # Assert the step stages, commits, and pushes the secrets repository.
    assert cli.run_command.call_count == 3

  def test_no_push_when_auto_push_false(self):
    """Skip the push when auto-push is disabled."""
    ctx = _make_context(auto_commit=True, auto_push=False)
    cli = _mock_cli()
    CommitFacter().execute(ctx, cli)
    # Assert the step stops after staging and committing.
    assert cli.run_command.call_count == 2


class TestUpdateSecretsPin:
  def test_skips_when_no_auto_commit(self):
    """Skip pin updates when commits are disabled entirely."""
    ctx = _make_context(auto_commit=False)
    # Assert the pin update step requires auto-commit.
    assert UpdateSecretsPin().should_skip(ctx) is True

  def test_skips_when_auto_push_disabled(self):
    """Skip pin updates until the secrets repository has been pushed."""
    ctx = _make_context(auto_commit=True, auto_push=False)
    # Assert the pin update step requires auto-push as well.
    assert UpdateSecretsPin().should_skip(ctx) is True

  def test_updates_unflake_and_stages_generated_lock(self):
    """Update the secrets pin and stage the resulting unflake change."""
    ctx = _make_context(auto_commit=True, auto_push=True)
    cli = _mock_cli()
    UpdateSecretsPin().execute(ctx, cli)

    # Assert the step runs update, add, commit, and push commands.
    assert cli.run_command.call_count == 4

    update_cmd = _get_command(cli, 0)
    # Assert the first command rewrites the secrets pin through write-unflake.
    assert isinstance(update_cmd, ShellCommand)
    assert update_cmd.build() == [
      "sh",
      "-c",
      "cd /tmp/test/flake && nix-shell . -A flake-file.sh --run 'write-unflake --backend nix --update mysecrets'",
    ]

    stage_cmd = _get_command(cli, 1)
    # Assert the updated unflake file is staged with installer git config.
    assert stage_cmd.build() == [
      "git",
      "-c",
      "user.name=nixos-installer",
      "-c",
      "user.email=nixos-installer@local",
      "-C",
      "/tmp/test/flake",
      "add",
      "unflake.nix",
    ]

  def test_installer_skip_message_mentions_manual_push(self):
    """Emit guidance when the secrets pin step is skipped."""
    ctx = _make_context(auto_commit=True, auto_push=False)
    cli = _mock_cli()
    installer = Installer(context=ctx, cli=cli, steps=[UpdateSecretsPin()])

    installer.run()

    # Assert the skip message explains that a manual push is required first.
    cli.info.assert_any_call(
      "Skipping: Updating secrets pin with unflake; push secrets first, then rerun the pin update"
    )


class TestGenerateInitrdSSHKeys:
  def test_skips_when_disabled(self):
    """Skip initrd key generation when the feature flag is off."""
    ctx = _make_context()
    ctx2 = InstallerContext(
      flake=ctx.flake,
      flake_host=ctx.flake_host,
      secrets=ctx.secrets,
      ssh_config=ctx.ssh_config,
      encryption_params=ctx.encryption_params,
      use_sudo=ctx.use_sudo,
      gen_initrd_ssh_keys=False,
    )
    # Assert disabling the feature flag skips the step.
    assert GenerateInitrdSSHKeys().should_skip(ctx2) is True

  def test_does_not_skip_by_default(self):
    """Enable initrd key generation by default."""
    ctx = _make_context()
    # Assert the default context keeps initrd key generation enabled.
    assert GenerateInitrdSSHKeys().should_skip(ctx) is False


class TestNixBuild:
  @patch("installer.steps.subprocess.run")
  def test_returns_store_path(self, mock_run: MagicMock):
    """Return the built store path when nix build succeeds."""
    mock_run.return_value = MagicMock(
      returncode=0,
      stdout="/nix/store/abc123-nixos-system\n",
      stderr="",
    )
    result = nix_build("nixpkgs#hello")
    # Assert the helper returns the stripped store path.
    assert result == "/nix/store/abc123-nixos-system"
    args = mock_run.call_args[0][0]
    # Assert the subprocess call includes the expected nix build flags.
    assert "nix" in args
    assert "build" in args
    assert "--print-out-paths" in args
    assert "--no-link" in args
    assert "nixpkgs#hello" in args

  @patch("installer.steps.subprocess.run")
  def test_raises_on_failure(self, mock_run: MagicMock):
    """Raise an installer error when nix build fails."""
    mock_run.return_value = MagicMock(returncode=1, stdout="", stderr="error")
    # Assert failing builds are converted into InstallerError.
    with pytest.raises(InstallerError, match="nix build failed"):
      nix_build("nixpkgs#hello")

  @patch("installer.steps.subprocess.run")
  def test_raises_on_empty_output(self, mock_run: MagicMock):
    """Reject successful builds that return no store path."""
    mock_run.return_value = MagicMock(returncode=0, stdout="", stderr="")
    # Assert empty build output is treated as an error.
    with pytest.raises(InstallerError, match="no output path"):
      nix_build("nixpkgs#hello")


class TestNixCopyCommand:
  def test_basic_copy(self):
    """Build a remote nix copy command for a store path."""
    cfg = SSHConfig(host="root@10.0.0.1", identity=Path("/tmp/key"))
    cmd = nix_copy_command(ssh_config=cfg, store_path="/nix/store/abc123")
    built = cmd.build()
    # Assert the command copies to the configured SSH destination.
    assert "nix" in built
    assert "copy" in built
    assert "--to" in built
    assert "ssh://root@10.0.0.1" in built[built.index("--to") + 1]
    assert "/nix/store/abc123" in built

  def test_with_remote_store(self):
    """Encode a remote store override into the copy destination."""
    cfg = SSHConfig(host="root@10.0.0.1", identity=Path("/tmp/key"))
    cmd = nix_copy_command(
      ssh_config=cfg,
      store_path="/nix/store/abc123",
      remote_store="local?root=/mnt",
    )
    built = cmd.build()
    to_arg = built[built.index("--to") + 1]
    # Assert the destination carries the encoded remote-store query.
    assert "remote-store=" in to_arg

  def test_with_substitute_on_dest(self):
    """Request destination-side substitution when configured."""
    cfg = SSHConfig(host="root@10.0.0.1", identity=Path("/tmp/key"))
    cmd = nix_copy_command(
      ssh_config=cfg,
      store_path="/nix/store/abc123",
      substitute_on_dest=True,
    )
    built = cmd.build()
    # Assert the copy command enables destination-side substitution.
    assert "--substitute-on-destination" in built

  def test_nix_sshopts_env(self):
    """Expose SSH identity and port through NIX_SSHOPTS."""
    cfg = SSHConfig(
      host="root@10.0.0.1", identity=Path("/tmp/key"), port=2222
    )
    cmd = nix_copy_command(ssh_config=cfg, store_path="/nix/store/abc123")
    built = cmd.build()
    # Assert the environment prefix carries the SSH options for nix copy.
    assert "NIX_SSHOPTS=-i /tmp/key -p 2222" in built


class TestInstallSystem:
  def test_never_skips(self):
    """Always run the final system installation step."""
    ctx = _make_context()
    # Assert system installation remains enabled for every run.
    assert InstallSystem().should_skip(ctx) is False

  @patch(
    "installer.steps.nix_build", return_value="/nix/store/abc-nixos-system"
  )
  def test_builds_toplevel_locally(self, mock_build: MagicMock):
    """Build the selected host's toplevel system closure."""
    ctx = _make_context()
    cli = _mock_cli()
    InstallSystem().execute(ctx, cli)
    ref = mock_build.call_args[0][0]
    # Assert the built flake attribute is the system toplevel.
    assert "system.build.toplevel" in ref

  @patch(
    "installer.steps.nix_build", return_value="/nix/store/abc-nixos-system"
  )
  def test_copies_to_mnt_store(self, _mock_build: MagicMock):
    """Copy the built closure into the mounted target store."""
    ctx = _make_context(use_sudo=True)
    cli = _mock_cli()
    InstallSystem().execute(ctx, cli)
    copy_cmd = _get_command(cli, 1)
    built = copy_cmd.build()
    to_arg = built[built.index("--to") + 1]
    # Assert the copy destination points at the mounted target store.
    assert "remote-store=" in to_arg
    # Assert the command asks the destination to substitute missing paths.
    assert "--substitute-on-destination" in built

  @patch(
    "installer.steps.nix_build", return_value="/nix/store/abc-nixos-system"
  )
  def test_runs_nixos_install_via_ssh(self, _mock_build: MagicMock):
    """Run nixos-install remotely after copying the closure."""
    ctx = _make_context(use_sudo=True)
    cli = _mock_cli()
    InstallSystem().execute(ctx, cli)
    # Assert the step runs chown, copy, and nixos-install in sequence.
    assert cli.run_command.call_count == 3
    install_cmd = _get_command(cli, 2)
    # Assert nixos-install executes through SSH with sudo.
    _assert_type_tree(install_cmd, [SSHCommand, SudoCommand, ShellCommand])

  @patch(
    "installer.steps.nix_build", return_value="/nix/store/abc-nixos-system"
  )
  def test_skips_chown_when_root(self, _mock_build: MagicMock):
    """Skip the ownership fix when the remote session already has root access."""
    ctx = _make_context(use_sudo=False)
    cli = _mock_cli()
    InstallSystem().execute(ctx, cli)
    # Assert the root path omits the preparatory chown command.
    assert cli.run_command.call_count == 2


def test_main_defaults_to_port_59222():
  """Expose the expected default SSH port in the CLI entrypoint."""
  # Assert the CLI entrypoint keeps the custom installer SSH port default.
  assert signature(main).parameters["port"].default == 59222