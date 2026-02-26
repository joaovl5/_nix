# pyright: reportAny=false, reportExplicitAny=false, reportUnusedCallResult=false

from pathlib import Path
from typing import Any
from unittest.mock import MagicMock, patch

import pytest
from rich.console import Console

from coisas.cli import CLI
from coisas.command import (
    RsyncCommand,
    SSHCommand,
    SSHConfig,
    ShellCommand,
    SudoCommand,
)
from coisas.repository import RepositoryURI
from installer.context import InstallerContext, InstallerError, SecretsEncryptionParams
from installer.steps import (
    CloneRepositories,
    CommitFacter,
    ConfigureSubstituters,
    DecryptKeyfile,
    GenerateInitrdSSHKeys,
    InstallSystem,
    RunDisko,
    RunFacter,
    SendKeyfile,
    UpdateFlakeLock,
    nix_build,
    nix_copy_command,
)


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
        tmp_dir=tmp_dir,
    )


def _mock_cli(return_code: int = 0) -> Any:
    cli = MagicMock(spec=CLI)
    cli.console = Console(quiet=True)
    cli.run_command = MagicMock(return_value=return_code)
    cli.info = MagicMock()
    return cli


def _get_command(cli: Any, call_index: int = -1) -> Any:
    """Extract the command kwarg from a mock cli.run_command call."""
    return cli.run_command.call_args_list[call_index][1]["command"]


def _assert_type_tree(cmd: Any, types: list[type]) -> None:
    for expected in types:
        assert isinstance(cmd, expected)
        cmd = getattr(cmd, "inner", None)


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
        step.execute(ctx, cli)
        assert cli.run_command.call_count == 2

    def test_skips_local_flake_clones_remote_secrets(self):
        ctx = _make_context(flake="/local/flake", secrets="github:user/secrets")
        cli = _mock_cli()
        step = CloneRepositories()
        step.execute(ctx, cli)
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
        SendKeyfile().execute(ctx, cli)
        assert cli.run_command.call_count == 3
        rsync_cmd = _get_command(cli, 1)
        assert isinstance(rsync_cmd, RsyncCommand)
        assert rsync_cmd.ssh_config is not None


class TestConfigureSubstituters:
    def test_never_skips(self):
        ctx = _make_context()
        assert ConfigureSubstituters().should_skip(ctx) is False

    @patch("installer.steps.subprocess.run")
    def test_evaluates_substituters_and_writes_to_target(self, mock_run: MagicMock):
        mock_run.return_value = MagicMock(
            returncode=0,
            stdout="https://cache.nixos.org https://mycache.example.com",
            stderr="",
        )
        ctx = _make_context()
        cli = _mock_cli()
        ConfigureSubstituters().execute(ctx, cli)
        # Two nix eval calls (substituters + trusted-public-keys) + one SSH write
        assert mock_run.call_count == 2  # two nix eval subprocess.run calls
        assert cli.run_command.call_count == 1  # one SSH command via cli

    @patch("installer.steps.subprocess.run")
    def test_nix_eval_failure_raises(self, mock_run: MagicMock):
        mock_run.return_value = MagicMock(returncode=1, stdout="", stderr="eval error")
        ctx = _make_context()
        cli = _mock_cli()
        with pytest.raises(InstallerError, match="nix eval failed"):
            ConfigureSubstituters().execute(ctx, cli)


class TestRunDisko:
    def test_never_skips(self):
        ctx = _make_context()
        assert RunDisko().should_skip(ctx) is False

    @patch("installer.steps.nix_build", return_value="/nix/store/abc-disko-script")
    def test_builds_disko_script_locally(self, mock_build: MagicMock):
        ctx = _make_context()
        cli = _mock_cli()
        RunDisko().execute(ctx, cli)
        mock_build.assert_called_once()
        ref = mock_build.call_args[0][0]
        assert "diskoScript" in ref
        assert ctx.flake_host in ref

    @patch("installer.steps.nix_build", return_value="/nix/store/abc-disko-script")
    def test_copies_and_runs_via_ssh(self, _mock_build: MagicMock):
        ctx = _make_context(use_sudo=True)
        cli = _mock_cli()
        RunDisko().execute(ctx, cli)
        # nix copy + ssh run + nix-collect-garbage = 3 calls
        assert cli.run_command.call_count == 3

    @patch("installer.steps.nix_build", return_value="/nix/store/abc-disko-script")
    def test_runs_store_path_on_target(self, _mock_build: MagicMock):
        ctx = _make_context(use_sudo=True)
        cli = _mock_cli()
        RunDisko().execute(ctx, cli)
        # Second call is the SSH run of the disko script
        run_cmd = _get_command(cli, 1)
        _assert_type_tree(run_cmd, [SSHCommand, SudoCommand, ShellCommand])


class TestRunFacter:
    @patch("installer.steps.nix_build", return_value="/nix/store/abc-nixos-facter")
    def test_builds_facter_locally(self, mock_build: MagicMock):
        ctx = _make_context()
        cli = _mock_cli()
        RunFacter().execute(ctx, cli)
        mock_build.assert_called_once_with("nixpkgs#nixos-facter")

    @patch("installer.steps.nix_build", return_value="/nix/store/abc-nixos-facter")
    def test_copies_and_runs_via_ssh(self, _mock_build: MagicMock):
        ctx = _make_context()
        cli = _mock_cli()
        RunFacter().execute(ctx, cli)
        # nix copy + ssh run + nix-collect-garbage = 3 calls
        assert cli.run_command.call_count == 3

    @patch("installer.steps.nix_build", return_value="/nix/store/abc-nixos-facter")
    def test_runs_facter_binary_on_target(self, _mock_build: MagicMock):
        ctx = _make_context(use_sudo=True)
        cli = _mock_cli()
        RunFacter().execute(ctx, cli)
        run_cmd = _get_command(cli, 1)
        _assert_type_tree(run_cmd, [SSHCommand, SudoCommand, ShellCommand])
        # The inner ShellCommand should reference the store path binary
        inner = run_cmd.inner.inner  # SSHCommand -> SudoCommand -> ShellCommand
        assert "nixos-facter" in inner.program or "abc-nixos-facter" in inner.program


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
        CommitFacter().execute(ctx, cli)
        # add + commit + push = 3 calls
        assert cli.run_command.call_count == 3

    def test_no_push_when_auto_push_false(self):
        ctx = _make_context(auto_commit=True, auto_push=False)
        cli = _mock_cli()
        CommitFacter().execute(ctx, cli)
        # add + commit only = 2 calls
        assert cli.run_command.call_count == 2


class TestUpdateFlakeLock:
    def test_skips_when_no_auto_commit(self):
        ctx = _make_context(auto_commit=False)
        assert UpdateFlakeLock().should_skip(ctx) is True


class TestGenerateInitrdSSHKeys:
    def test_skips_when_disabled(self):
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
        assert GenerateInitrdSSHKeys().should_skip(ctx2) is True

    def test_does_not_skip_by_default(self):
        ctx = _make_context()
        assert GenerateInitrdSSHKeys().should_skip(ctx) is False


class TestNixBuild:
    @patch("installer.steps.subprocess.run")
    def test_returns_store_path(self, mock_run: MagicMock):
        mock_run.return_value = MagicMock(
            returncode=0,
            stdout="/nix/store/abc123-nixos-system\n",
            stderr="",
        )
        result = nix_build("nixpkgs#hello")
        assert result == "/nix/store/abc123-nixos-system"
        args = mock_run.call_args[0][0]
        assert "nix" in args
        assert "build" in args
        assert "--print-out-paths" in args
        assert "--no-link" in args
        assert "nixpkgs#hello" in args

    @patch("installer.steps.subprocess.run")
    def test_raises_on_failure(self, mock_run: MagicMock):
        mock_run.return_value = MagicMock(returncode=1, stdout="", stderr="error")
        with pytest.raises(InstallerError, match="nix build failed"):
            nix_build("nixpkgs#hello")

    @patch("installer.steps.subprocess.run")
    def test_raises_on_empty_output(self, mock_run: MagicMock):
        mock_run.return_value = MagicMock(returncode=0, stdout="", stderr="")
        with pytest.raises(InstallerError, match="no output path"):
            nix_build("nixpkgs#hello")


class TestNixCopyCommand:
    def test_basic_copy(self):
        cfg = SSHConfig(host="root@10.0.0.1", identity=Path("/tmp/key"), port=22)
        cmd = nix_copy_command(cfg, "/nix/store/abc123")
        built = cmd.build()
        assert "nix" in built
        assert "copy" in built
        assert "--to" in built
        assert "ssh://root@10.0.0.1" in built[built.index("--to") + 1]
        assert "/nix/store/abc123" in built

    def test_with_remote_store(self):
        cfg = SSHConfig(host="root@10.0.0.1", identity=Path("/tmp/key"), port=22)
        cmd = nix_copy_command(cfg, "/nix/store/abc123", remote_store="local?root=/mnt")
        built = cmd.build()
        to_arg = built[built.index("--to") + 1]
        assert "remote-store=" in to_arg

    def test_with_substitute_on_dest(self):
        cfg = SSHConfig(host="root@10.0.0.1", identity=Path("/tmp/key"), port=22)
        cmd = nix_copy_command(cfg, "/nix/store/abc123", substitute_on_dest=True)
        built = cmd.build()
        assert "--substitute-on-destination" in built

    def test_nix_sshopts_env(self):
        cfg = SSHConfig(host="root@10.0.0.1", identity=Path("/tmp/key"), port=2222)
        cmd = nix_copy_command(cfg, "/nix/store/abc123")
        built = cmd.build()
        # env prefix should contain NIX_SSHOPTS
        assert "NIX_SSHOPTS=-i /tmp/key -p 2222" in built


class TestInstallSystem:
    def test_never_skips(self):
        ctx = _make_context()
        assert InstallSystem().should_skip(ctx) is False

    @patch("installer.steps.nix_build", return_value="/nix/store/abc-nixos-system")
    def test_builds_toplevel_locally(self, mock_build: MagicMock):
        ctx = _make_context()
        cli = _mock_cli()
        InstallSystem().execute(ctx, cli)
        ref = mock_build.call_args[0][0]
        assert "system.build.toplevel" in ref

    @patch("installer.steps.nix_build", return_value="/nix/store/abc-nixos-system")
    def test_copies_to_mnt_store(self, _mock_build: MagicMock):
        ctx = _make_context(use_sudo=True)
        cli = _mock_cli()
        InstallSystem().execute(ctx, cli)
        # chown (index 0) + nix copy (index 1) + nixos-install (index 2)
        copy_cmd = _get_command(cli, 1)
        built = copy_cmd.build()
        to_arg = built[built.index("--to") + 1]
        assert "remote-store=" in to_arg
        assert "--substitute-on-destination" in built

    @patch("installer.steps.nix_build", return_value="/nix/store/abc-nixos-system")
    def test_runs_nixos_install_via_ssh(self, _mock_build: MagicMock):
        ctx = _make_context(use_sudo=True)
        cli = _mock_cli()
        InstallSystem().execute(ctx, cli)
        # chown + nix copy + nixos-install = 3 calls
        assert cli.run_command.call_count == 3
        install_cmd = _get_command(cli, 2)
        _assert_type_tree(install_cmd, [SSHCommand, SudoCommand, ShellCommand])

    @patch("installer.steps.nix_build", return_value="/nix/store/abc-nixos-system")
    def test_skips_chown_when_root(self, _mock_build: MagicMock):
        ctx = _make_context(use_sudo=False)
        cli = _mock_cli()
        InstallSystem().execute(ctx, cli)
        # no chown — nix copy + nixos-install = 2 calls
        assert cli.run_command.call_count == 2
