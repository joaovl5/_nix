from pathlib import Path
from cyclopts import App
from rich.console import Console

from coisas.cli import SshCLI

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
    c = SshCLI(
        console=get_ssh_console(),
        host=host,
        identity=identity,
        port=port,
    )
    c.run_command(["cat", "/dev/zero"], "Testing uname -a")
    c.info("Installer scaffolding ready. No operations defined yet.")
