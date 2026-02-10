from pathlib import Path
from uuid import uuid4
from attrs import define, field
from rich.console import Console

from coisas.cli import SshCLI


def get_ssh_console() -> Console:
    return Console()


@define
class NixOSInstaller:
    identity: Path
    host: str
    flake: str
    port: int = 22
    _console: Console = field(init=False)
    _c: SshCLI = field(init=False)
    # temporary dir at destination for housing files
    _tmp_dir: str = field(init=False)

    @property
    def _ssh_conn_info(self) -> str:
        return f"[bold yellow]{self.host}:{self.port}[/bold yellow]"

    def __attrs_post_init__(self) -> None:
        self._console = get_ssh_console()
        self._tmp_dir = f"/tmp/{uuid4().hex}"
        self._c = SshCLI(
            console=self._console,
            host=self.host,
            identity=self.identity,
            port=self.port,
        )
        self._c.info(f"Prepared NixOSInstaller for {self._ssh_conn_info}")

    def _get_home(self) -> str:
        pass

    def _handle_keys(self) -> None:
        # for now, leaves hardcoded to copy user's ssh/age keys

        # use a tmp dir at destination to avoid
        # permission errors w/ rsync, then move later
        _ = self._c.upload(
            src_dir=Path.home() / ".ssh/",
            dest_dir=f"{self._tmp_dir}/.ssh",
            glob="id_*",
            description="Copying SSH keys on remote host",
        )
        _ = self._c.upload(
            src_dir=Path.home() / ".age/",
            dest_dir=f"{self._tmp_dir}/.age",
            description="Copying AGE keys on remote host",
        )

        # move keys

    def run(self) -> None:
        # - assumes user has root privileges

        # handle keys
        self._handle_keys()
        # handle disko
        # handle nixos-install
        pass
