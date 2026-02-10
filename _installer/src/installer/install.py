from functools import cached_property
from pathlib import Path
from uuid import uuid4
from attrs import define, field
from rich.console import Console

from coisas.cli import SshCLI

# TODO move to argument
AGE_KEYFILE: str = "key.txt"


def get_ssh_console() -> Console:
    return Console()


class NixOSInstallerError(Exception): ...


@define
class SecretsEncryptionParams:
    repo_url: str
    sops_file: str
    sops_file_key: str
    keyfile_location: str


@define
class NixOSInstaller:
    identity: Path
    host: str
    flake_host: str
    flake_repo: str
    flake_disko_file: str
    encryption_params: SecretsEncryptionParams | None = None
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

    @property
    def _flake_dir(self) -> str:
        return f"{self._tmp_dir}/flake"

    @property
    def _secrets_dir(self) -> str:
        if not self.encryption_params:
            raise NixOSInstallerError(
                "Attempted to get `_secrets_dir` without defining encryption_params"
            )
        return f"{self._tmp_dir}/secrets"

    @cached_property
    def _host_home(self) -> str:
        p = self._c._run_command(
            [
                "echo",
                "-n",  # necessary for not returning a new-line
                "$HOME",
            ]
        )
        _ = p.wait(timeout=5)
        if not p.stdout:
            raise NixOSInstallerError("Couldn't get `stdout` whilst getting $HOME")
        home = p.stdout.read()
        if len(home) == 0:
            raise NixOSInstallerError("Home can't be empty")
        return home

    def _handle_disk_encryption_keys(self) -> None:
        pass

    def _handle_keys(self) -> None:
        # for now, leaves hardcoded to copy user's ssh/age keys
        # TODO create dynamic key gen system

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
        _ = self._c.run_command(
            ["mkdir", "-p", f"{self._host_home}/{{.ssh,.age}}"],
            description="Ensuring ssh/age dirs exist",
        )
        _ = self._c.run_command(
            command=["mv", f"{self._tmp_dir}/.ssh/id_*", f"{self._host_home}/.ssh"],
            description="Moving SSH keys into remote host's home",
        )
        _ = self._c.run_command(
            command=["mv", f"{self._tmp_dir}/.age/*", f"{self._host_home}/.age"],
            description="Moving AGE into remote host's home",
        )

    def _clone_repositories(self) -> None:
        _git_clone = [
            "env",
            "GIT_SSH_COMMAND=ssh -o StrictHostKeyChecking=accept-new",
            "git",
            "clone",
            "--depth",
            "1",
        ]
        _ = self._c.run_command(
            command=[
                *_git_clone,
                f"{self.flake_repo}",
                self._flake_dir,
            ],
            description="Cloning Flake repository",
        )
        if self.encryption_params:
            _ = self._c.run_command(
                command=[
                    *_git_clone,
                    self.encryption_params.repo_url,
                    self._secrets_dir,
                ],
                description="Cloning Secrets repository",
            )

    def _setup_keyfiles(self) -> None:
        # sets-up disk encryption keyfile if necessary
        # assumes age keys already at `.age/key.txt`
        if not self.encryption_params:
            return

        _nix_sops_cmd = [
            "nix-shell",
            "-p",
            "sops",
        ]
        sops_run_cmd = (
            f'SOPS_AGE_KEY_FILE="$HOME/.age/{AGE_KEYFILE}" '
            f"sops -d --extract '{self.encryption_params.sops_file_key}' "
            f"{self._secrets_dir}/{self.encryption_params.sops_file} "
            f"> {self.encryption_params.keyfile_location}"
        )
        _ = self._c.run_command(
            command=[
                *_nix_sops_cmd,
                "--run",
                sops_run_cmd,
            ],
            description="Decrypting disk keyfile into temporary location for Disko",
        )

    def _handle_disko(self) -> None:
        _nix_disko_cmd = [
            "sudo",
            "disko",
            "--yes-wipe-all-disks",
            "--mode",
            "destroy,format,mount",
            f"{self._flake_dir}/{self.flake_disko_file}",
        ]

        _ = self._c.run_command(
            command=_nix_disko_cmd,
            description=f"Running disko w/ `{self.flake_disko_file}`",
        )

    def run(self) -> None:
        # - assumes user has root privileges

        self._handle_keys()
        self._clone_repositories()
        self._setup_keyfiles()
        self._handle_disko()
        # clone repositories
        # handle disko
        # handle nixos-install
        pass
