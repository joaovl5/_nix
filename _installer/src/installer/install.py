from collections.abc import Callable, Generator
from contextlib import contextmanager
from functools import cached_property
from pathlib import Path
from uuid import uuid4
from attrs import define, field
from rich.console import Console

from coisas.cli import PanelWriter, SshCLI

# TODO move all to arguments
AGE_KEYFILE: str = "key.txt"
GEN_SSH_KEY_INITRD: bool = True
GEN_SSH_KEY_INITRD_NAME: str = "ssh_host_ed25519_key"
GEN_SSH_KEY_INITRD_DIR: str = "etc/secrets/initrd"  # without /mnt
FLAKE_SECRETS_INPUT_NAME: str = "mysecrets"


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

    @cached_property
    def _host_user(self) -> str:
        p = self._c._run_command(
            [
                "echo",
                "-n",  # necessary for not returning a new-line
                "$(whoami)",
            ]
        )
        _ = p.wait(timeout=5)
        if not p.stdout:
            raise NixOSInstallerError("Couldn't get `stdout` whilst getting $(whoami)")
        home = p.stdout.read()
        if len(home) == 0:
            raise NixOSInstallerError("$(whoami) output can't be empty")
        return home

    def _handle_disk_encryption_keys(self) -> None:
        pass

    def _ensure_dir(self, path: str, path_description: str, sudo: bool = False) -> None:
        final_cmd: list[str] = []
        if sudo:
            final_cmd.append("sudo")
        final_cmd += ["mkdir", "-v", "-p", path]
        _ = self._c.run_command(
            command=final_cmd,
            description=f"Ensuring existence of {path_description}",
        )

    def _ensure_chown(self, path: str) -> None:
        _cmd = [
            "sudo",
            "chown",
            "-R",
            f"{self._host_user}:users",  # TODO logic for getting group later
            path,
        ]
        _ = self._c.run_command(
            _cmd, description=f"Ensuring {self._host_user} owns {path}"
        )

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
        self._ensure_dir(f"{self._host_home}/{{.ssh,.age}}", "ssh/age dirs")
        _ = self._c.run_command(
            command=[
                "cp",
                "-v",
                f"{self._tmp_dir}/.ssh/id_*",
                f"{self._host_home}/.ssh",
            ],
            description="Copying SSH keys into remote host's home",
        )
        _ = self._c.run_command(
            command=["cp", "-v", f"{self._tmp_dir}/.age/*", f"{self._host_home}/.age"],
            description="Copying AGE keys into remote host's home",
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
        _disko_cmd = [
            "sudo",
            "disko",
            "--yes-wipe-all-disks",
            "--mode",
            "destroy,format,mount",
            f"{self._flake_dir}/{self.flake_disko_file}",
        ]

        _ = self._c.run_command(
            command=_disko_cmd,
            description=f"Running disko w/ `{self.flake_disko_file}`",
        )

    @contextmanager
    def _with_git(
        self,
        repo_path: str,
        push: bool = False,
    ) -> Generator[Callable[[list[str], str], None]]:
        _git = [
            "cd",
            repo_path,
            "&&",
            "git",
        ]

        with self._c.panel_session(
            title="Git commands execution",
            prelude=[
                f"Repository: {repo_path}",
            ],
        ) as writer:
            _cfg_cmd = ["git", "config", "--global"]
            self._c.run_command(
                command=[*_cfg_cmd, "user.email", "nixos-installer@local"],
                description="Setting git email",
                writer=writer,
            )
            self._c.run_command(
                command=[*_cfg_cmd, "user.name", "nixos-installer"],
                description="Setting git username",
                writer=writer,
            )

            def run_git_command(cmd: list[str], description: str) -> None:
                _ = self._c.run_command(
                    command=[*_git, *cmd],
                    description=description,
                    writer=writer,
                )

            yield run_git_command

            if push:
                run_git_command(["push", "-u"], "Pushing to origin")

    def _handle_facter(self) -> None:
        # 1) creating facter config
        _facter_target = f"{self._tmp_dir}/facter.json"
        _facter_secrets_dir = f"{self._secrets_dir}/facter"
        _facter_cmd = [
            "sudo",
            "nixos-facter",
            "-o",
            _facter_target,
        ]

        self._ensure_dir("/mnt/root", "/mnt/root", sudo=True)
        _ = self._c.run_command(
            command=_facter_cmd,
            description=f"Running nixos-facter",
        )

        # 2) adding facter config to git
        _facter_final_path = f"{_facter_secrets_dir}/{self.flake_host}.json"
        self._ensure_dir(_facter_secrets_dir, "facter directory on secrets repo")
        _ = self._c.run_command(
            command=[
                "sudo",
                "cp",
                "-v",
                _facter_target,
                # WARNING THIS AND OTHER LOGIC ASSUMES FLAKE HOST IS THE SAME AS THE MACHINE'S HOSTNAME
                _facter_final_path,
            ],
            description="Copying facter config to secrets repository",
        )
        self._ensure_chown(_facter_final_path)

        _msg = f"[my-installer][new-facter-cfg]:{self.flake_host}"
        with self._with_git(self._secrets_dir, push=True) as run_git:
            run_git(["add", "."], "Adding facter config to git")
            run_git(["commit", "-m", _msg], "Writing facter commit message")

        # 3) updating flake inputs for secrets repository
        _ = self._c.run_command(
            [
                "nix",
                "flake",
                "update",
                FLAKE_SECRETS_INPUT_NAME,
                "--flake",
                self._flake_dir,
            ],
            description="Updating secrets input on flake",
        )

        _msg = f"[my-installer][update-secrets][new-facter-cfg]:{self.flake_host}"
        with self._with_git(self._flake_dir, push=True) as run_git:
            run_git(["add", "."], "Adding updated lockfile to git")
            run_git(["commit", "-m", _msg], "Writing update commit message")

    def _handle_copy_keys(self) -> None:
        dirs_glob = "{.ssh,.age}"
        target_dirs = [
            "/mnt/root",
            "/root",
        ]
        _cp = ["sudo", "cp", "-v"]
        with self._c.panel_session(
            title="Copying SSH/AGE keys",
            prelude=[
                "Target directories:",
                *[f"-> {x}/{dirs_glob}" for x in target_dirs],
            ],
        ) as writer:
            for target_dir in target_dirs:
                target_glob = f"{target_dir}/{dirs_glob}"
                self._ensure_dir(
                    target_glob, f"ssh/age dirs at {target_dir}", sudo=True
                )
                _ = self._c.run_command(
                    command=[*_cp, f"{self._tmp_dir}/.ssh/id_*", f"{target_dir}/.ssh"],
                    description="Copying SSH keys",
                    writer=writer,
                )
                _ = self._c.run_command(
                    command=[*_cp, f"{self._tmp_dir}/.age/*", f"{target_dir}/.age"],
                    description="Copying AGE keys",
                    writer=writer,
                )

    def _handle_gen_ssh_keys(self) -> None:
        if GEN_SSH_KEY_INITRD:
            initrd_key_dir = f"/mnt/{GEN_SSH_KEY_INITRD_DIR}"
            self._ensure_dir(
                path=initrd_key_dir,
                path_description="initrd secrets directory",
                sudo=True,
            )
            _ = self._c.run_command(
                command=[
                    "sudo",
                    "ssh-keygen",
                    "-t",
                    "ed25519",
                    "-N",
                    "",
                    "-f",
                    f"{initrd_key_dir}/{GEN_SSH_KEY_INITRD_NAME}",
                ],
                description="Generating host ssh key for initrd",
            )

    def _handle_install(self) -> None:
        _install_cmd = [
            "sudo",
            "nixos-install",
            "--no-root-password",
            "--cores",
            "0",
            "--root",
            "/mnt",
            "--flake",
            f"{self._flake_dir}#{self.flake_host}",
        ]

        _ = self._c.run_command(
            command=_install_cmd,
            description=f"Installing NixOS for `{self.flake_host}`",
        )

    def run(self) -> None:
        # - assumes user has root privileges

        self._handle_keys()
        self._clone_repositories()
        self._setup_keyfiles()
        self._handle_disko()
        self._handle_facter()
        self._handle_copy_keys()
        self._handle_gen_ssh_keys()
        self._handle_install()
        # !!!!!!!! TODO !!!!!!!!!!
        # !! COPY KEYS TO /root/*** FOR POST INSTALL SERVICE
        # clone repositories
        # handle disko
        # handle nixos-install
        pass
