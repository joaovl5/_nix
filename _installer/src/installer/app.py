from pathlib import Path
from cyclopts import App
from rich.console import Console

from coisas.cli import SshCLI
from installer.install import NixOSInstaller

app = App(
    name="my installer",
)


def get_ssh_console() -> Console:
    return Console()


@app.default
def main(
    identity: Path,
    host: str,
    flake: str,
    port: int = 22,
) -> None:
    """Runs installer.

    Args:
        identity: SSH identity to use.
        host: SSH host, as in `user@example.com`.
        flake: Nix Flake to install.
        port: SSH port.
    """
    installer = NixOSInstaller(
        identity=identity,
        host=host,
        flake=flake,
        port=port,
    )
    installer.run()
