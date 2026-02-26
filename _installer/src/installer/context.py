"""Installer context and configuration."""

from __future__ import annotations

from attrs import define

from coisas.command import (
    Command,
    CommandWrapper,
    PassthroughWrapper,
    SSHConfig,
    SSHWrapper,
    SudoCommand,
    SudoWrapper,
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
    tmp_dir: str = ""

    # constants with my defaults
    flake_secrets_input_name: str = "mysecrets"
    age_keyfile: str = "key.txt"
    gen_initrd_ssh_keys: bool = True
    initrd_ssh_key_name: str = "ssh_host_ed25519_key"
    initrd_ssh_key_dir: str = "etc/secrets/initrd"

    @property
    def do_ssh(self) -> CommandWrapper:
        return SSHWrapper(config=self.ssh_config)

    @property
    def do_sudo(self) -> CommandWrapper:
        return SudoWrapper() if self.use_sudo else PassthroughWrapper()

    def maybe_sudo(self, cmd: Command) -> Command:
        return SudoCommand(inner=cmd) if self.use_sudo else cmd

    @property
    def flake_dir(self) -> str:
        """Resolved flake directory — local path or cloned location."""
        if not self.flake.needs_clone():
            return self.flake.get_url()
        return f"{self.tmp_dir}/flake"

    @property
    def secrets_dir(self) -> str | None:
        """Resolved secrets directory — local path or cloned location."""
        if self.secrets is None:
            return None
        if not self.secrets.needs_clone():
            return self.secrets.get_url()
        return f"{self.tmp_dir}/secrets"
