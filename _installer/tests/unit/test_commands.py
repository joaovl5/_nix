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
        # user args appear after nix and flags
        nix_idx = result.index("nix")
        for arg in ["flake", "update", "mysecrets", "--flake", "/tmp/flake"]:
            assert arg in result[nix_idx + 1 :]

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


class TestSSHCommand:
    def _config(self) -> SSHConfig:
        return SSHConfig(
            host="root@192.168.1.1", identity=Path("/tmp/id_ed25519"), port=22
        )

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
        assert remote_str == "echo 'hello world'"

    def test_globs_not_quoted(self):
        """Globs and operators should not be quoted (they expand on remote)."""
        inner = ShellCommand("cp", ["/tmp/.ssh/id_*", "/root/.ssh/"])
        cmd = SSHCommand(inner=inner, config=self._config())
        remote_str = cmd.build()[-1]
        assert "id_*" in remote_str
        assert "'id_*'" not in remote_str

    def test_wraps_sudo(self):
        inner = SudoCommand(inner=ShellCommand("nixos-install", ["--root", "/mnt"]))
        cmd = SSHCommand(inner=inner, config=self._config())
        result = cmd.build()
        remote_str = result[-1]
        assert remote_str == "sudo nixos-install --root /mnt"

    def test_wraps_nix_run(self):
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
        assert "nix run" in remote_str
        assert "github:nix-community/disko" in remote_str
        assert "-- --yes-wipe-all-disks" in remote_str

    def test_custom_port(self):
        config = SSHConfig(host="user@host", identity=Path("/key"), port=2222)
        cmd = SSHCommand(inner=ShellCommand("whoami"), config=config)
        result = cmd.build()
        assert "-p" in result
        assert "2222" in result


class TestRsyncCommand:
    def _config(self) -> SSHConfig:
        return SSHConfig(
            host="root@192.168.1.1", identity=Path("/tmp/id_ed25519"), port=22
        )

    def test_local_rsync(self):
        cmd = RsyncCommand(src="/tmp/file.json", dest="/backup/file.json")
        result = cmd.build()
        assert result == ["rsync", "-avz", "/tmp/file.json", "/backup/file.json"]

    def _get_ssh_str(self, result: list[str]) -> str:
        """Extract the ssh command string (value after -e flag)."""
        idx = result.index("-e")
        return result[idx + 1]

    def test_remote_rsync_with_ssh(self):
        cmd = RsyncCommand(
            src="/tmp/devices.json",
            dest="/tmp/disko/",
            ssh_config=self._config(),
        )
        result = cmd.build()
        assert result[0] == "rsync"
        assert "-avz" in result
        assert "-e" in result
        # host prepended to dest
        assert result[-1] == "root@192.168.1.1:/tmp/disko/"
        assert result[-2] == "/tmp/devices.json"
        # ssh command string should contain identity and port
        ssh_str = self._get_ssh_str(result)
        assert "-i" in ssh_str
        assert "/tmp/id_ed25519" in ssh_str
        assert "-p 22" in ssh_str

    def test_remote_dest_false_prepends_host_to_src(self):
        cmd = RsyncCommand(
            src="/tmp/facter.json",
            dest="/local/facter.json",
            ssh_config=self._config(),
            remote_dest=False,
        )
        result = cmd.build()
        assert result[-2] == "root@192.168.1.1:/tmp/facter.json"
        assert result[-1] == "/local/facter.json"

    def test_extra_args(self):
        cmd = RsyncCommand(
            src="/tmp/src/",
            dest="/tmp/dest/",
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
        cmd = RsyncCommand(src="/a", dest="/b", ssh_config=config)
        result = cmd.build()
        ssh_str = self._get_ssh_str(result)
        # shlex-quoted path
        assert (
            "'/path with spaces/key'" in ssh_str or '"/path with spaces/key"' in ssh_str
        )


class TestCommandWrappers:
    def _config(self) -> SSHConfig:
        return SSHConfig(
            host="root@192.168.1.1", identity=Path("/tmp/id_ed25519"), port=22
        )

    def test_ssh_wrapper(self):
        wrapper = SSHWrapper(config=self._config())
        cmd = wrapper.wrap(ShellCommand("ls"))
        assert isinstance(cmd, SSHCommand)
        assert cmd.config.host == "root@192.168.1.1"

    def test_sudo_wrapper(self):
        wrapper = SudoWrapper()
        cmd = wrapper.wrap(ShellCommand("ls"))
        assert isinstance(cmd, SudoCommand)
        assert cmd.build() == ["sudo", "ls"]

    def test_passthrough_wrapper(self):
        wrapper = PassthroughWrapper()
        inner = ShellCommand("ls")
        cmd = wrapper.wrap(inner)
        assert cmd is inner

    def test_composed_ssh_sudo(self):
        composed = SSHWrapper(config=self._config()) | SudoWrapper()
        cmd = composed.wrap(ShellCommand("ls"))
        assert isinstance(cmd, SSHCommand)
        assert isinstance(cmd.inner, SudoCommand)

    def test_composed_ssh_passthrough(self):
        composed = SSHWrapper(config=self._config()) | PassthroughWrapper()
        cmd = composed.wrap(ShellCommand("ls"))
        assert isinstance(cmd, SSHCommand)
        # passthrough means inner is the raw command, not SudoCommand
        assert not isinstance(cmd.inner, SudoCommand)

    def test_pipe_to_command(self):
        cmd = SSHWrapper(config=self._config()) | SudoWrapper() | ShellCommand("ls")
        assert isinstance(cmd, SSHCommand)
        assert isinstance(cmd.inner, SudoCommand)
        assert isinstance(cmd.inner.inner, ShellCommand)

    def test_pipe_single_to_command(self):
        cmd = SudoWrapper() | ShellCommand("ls")
        assert isinstance(cmd, SudoCommand)
        assert isinstance(cmd.inner, ShellCommand)


class TestGitHelper:
    def _helper(self) -> GitHelper:
        return GitHelper(
            config={"user.name": "test", "user.email": "test@local"},
            repo_path="/tmp/repo",
        )

    def test_add(self):
        cmd = self._helper().add([".", "extra.txt"])
        assert isinstance(cmd, GitCommand)
        result = cmd.build()
        assert "-C" in result
        assert "/tmp/repo" in result
        assert "add" in result
        assert "." in result
        assert "extra.txt" in result

    def test_commit(self):
        cmd = self._helper().commit("test message")
        result = cmd.build()
        assert "commit" in result
        assert "-m" in result
        assert "test message" in result
        assert "user.name=test" in result

    def test_push(self):
        cmd = self._helper().push()
        result = cmd.build()
        assert "push" in result
        assert "-u" in result
        assert "origin" in result
        assert "HEAD" in result
