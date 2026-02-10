from pathlib import Path
from cyclopts import App
from rich.console import Console

from coisas.cli import SshCLI
from installer.install import NixOSInstaller, SecretsEncryptionParams

app = App(
    name="my installer",
)


def get_ssh_console() -> Console:
    return Console()


@app.default
def main(
    identity: Path,
    host: str,
    flake_host: str,
    flake_disko_file: str,
    flake_repo: str = "git@github.com:joaovl5/_nix.git",
    secrets_repo: str | None = "git@github.com:joaovl5/__secrets.git",
    secrets_file_disk_encryption: str | None = "secrets/disk_encryption.yaml",
    secrets_extract_disk_encryption_key: str | None = '["servers"]["tyrant"]',
    secrets_use_disk_encryption: bool = False,
    secrets_disk_encryption_keyfile_location: str = "/tmp/secret.key",
    port: int = 22,
) -> None:
    """Runs installer.

    Args:
        identity: SSH identity to use.
        host: SSH host, as in `user@example.com`.
        flake_host: NixOS Configuration name to install, from flake.
        flake_disko_file: Disko configuration file, relative to Flake's root.
        flake_repo: Nix Flake to install.
        secrets_repo: Repository for keeping SOPS-encrypted secrets, optional.
        secrets_file_disk_encryption: File in `secrets_repo` keeping SOPS-encrypted disk_encryption keys.
        secrets_extract_disk_encryption_key: Argument value for `sops -d --extract` for getting disk_encryption key file.
        secrets_use_disk_encryption: Whether to use a keyfile and supply it for Disko.
                                     This will require the following options to be set:
                                         - `secrets_repo`
                                         - `secrets_file_disk_encryption`
                                         - `secrets_extract_disk_encryption_key`
                                         - `secrets_use_disk_encryption`
                                     This will assume the associated Disko file used is setup for Luks encryption.
        secrets_disk_encryption_keyfile_location: Place to mount the decrypted SOPS keyfile.
                                                  Should match the one on Disko's configuration.

        port: SSH port to connect to.
    """

    encryption_params: SecretsEncryptionParams | None = None
    if secrets_use_disk_encryption:
        if (
            secrets_repo is None
            or secrets_file_disk_encryption is None
            or secrets_extract_disk_encryption_key is None
        ):
            raise Exception(
                "Ensure all secrets options are set in order to use the `secrets_use_disk_encryption` flag."
            )
        encryption_params = SecretsEncryptionParams(
            repo_url=secrets_repo,
            sops_file=secrets_file_disk_encryption,
            sops_file_key=secrets_extract_disk_encryption_key,
            keyfile_location=secrets_disk_encryption_keyfile_location,
        )

    installer = NixOSInstaller(
        identity=identity,
        host=host,
        flake_host=flake_host,
        flake_disko_file=flake_disko_file,
        flake_repo=flake_repo,
        encryption_params=encryption_params,
        port=port,
    )
    installer.run()
