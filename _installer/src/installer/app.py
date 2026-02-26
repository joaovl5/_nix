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
    ConfigureSubstituters,
    CopyKeys,
    DecryptKeyfile,
    DownloadFacter,
    GenerateInitrdSSHKeys,
    Installer,
    InstallSystem,
    RunDisko,
    RunFacter,
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
        ConfigureSubstituters(),
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
