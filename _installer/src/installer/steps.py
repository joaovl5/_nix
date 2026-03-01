"""Step protocol and installer orchestrator."""

# pyright: reportUnusedCallResult=false, reportUnusedParameter=false

from __future__ import annotations

import subprocess
import tempfile
from collections.abc import Sequence
from pathlib import Path
from typing import Protocol

import attrs
from attrs import define

from coisas.cli import CLI
from coisas.command import (
    NIX_FLAGS,
    GitCommand,
    GitHelper,
    NixCommand,
    RsyncCommand,
    ShellCommand,
    SSHConfig,
)
from installer.context import InstallerContext, InstallerError

_REMOTE_CACHE = ".cache/nix_installer"


def nix_build(flake_ref: str) -> str:
    """Build a flake ref locally, return the store path."""
    result = subprocess.run(
        ["nix", "build", *NIX_FLAGS, flake_ref, "--no-link", "--print-out-paths"],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise InstallerError(
            f"nix build failed (exit {result.returncode}): {result.stderr}"
        )
    store_path = result.stdout.strip()
    if not store_path:
        raise InstallerError("nix build produced no output path")
    return store_path


def nix_copy_command(
    ssh_config: SSHConfig,
    store_path: str,
    remote_store: str | None = None,
    substitute_on_dest: bool = False,
) -> ShellCommand:
    """Build a ShellCommand for nix copy to a remote host."""
    dest = f"ssh://{ssh_config.host}"
    if remote_store:
        from urllib.parse import quote

        dest += f"?remote-store={quote(remote_store, safe='')}"

    args = ["copy", *NIX_FLAGS, "--to", dest]
    if substitute_on_dest:
        args.append("--substitute-on-destination")
    args.append(store_path)

    return ShellCommand(
        "nix",
        args,
        env={"NIX_SSHOPTS": f"-i {ssh_config.identity} -p {ssh_config.port}"},
    )


def _nix_eval_tostring(flake_ref: str) -> str:
    """Evaluate a flake attribute with `toString` application, return stdout."""
    result = subprocess.run(
        ["nix", "eval", *NIX_FLAGS, "--apply", "toString", flake_ref],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise InstallerError(
            f"nix eval failed (exit {result.returncode}): {result.stderr}"
        )
    return result.stdout.strip().strip('"')


class Step(Protocol):
    name: str
    description: str

    def should_skip(self, context: InstallerContext) -> bool: ...
    def execute(self, context: InstallerContext, cli: CLI) -> None: ...


@define
class Installer:
    context: InstallerContext
    cli: CLI
    steps: Sequence[Step]

    def run(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            ctx = attrs.evolve(self.context, tmp_dir=tmp_dir)
            for step in self.steps:
                if step.should_skip(ctx):
                    self.cli.info(f"Skipping: {step.description}")
                    continue
                self.cli.info(f"Running: {step.description}")
                step.execute(ctx, self.cli)


@define
class CloneRepositories:
    name: str = "clone_repositories"
    description: str = "Cloning repositories"

    def should_skip(self, context: InstallerContext) -> bool:
        flake_skip = not context.flake.needs_clone()
        secrets_skip = context.secrets is None or not context.secrets.needs_clone()
        return flake_skip and secrets_skip

    def execute(self, context: InstallerContext, cli: CLI) -> None:
        if context.flake.needs_clone():
            cli.run_command(
                command=GitCommand(
                    args=[
                        "clone",
                        "--depth",
                        "1",
                        context.flake.get_url(),
                        context.flake_dir,
                    ],
                ),
                description="Cloning flake repository",
                error_msg="Failed to clone flake repository",
            )

        if context.secrets is not None and context.secrets.needs_clone():
            secrets_dir = context.secrets_dir
            assert secrets_dir is not None
            cli.run_command(
                command=GitCommand(
                    args=[
                        "clone",
                        "--depth",
                        "1",
                        context.secrets.get_url(),
                        secrets_dir,
                    ],
                ),
                description="Cloning secrets repository",
                error_msg="Failed to clone secrets repository",
            )


@define
class DecryptKeyfile:
    name: str = "decrypt_keyfile"
    description: str = "Decrypting disk encryption keyfile"

    def should_skip(self, context: InstallerContext) -> bool:
        return context.encryption_params is None

    def execute(self, context: InstallerContext, cli: CLI) -> None:
        assert context.encryption_params is not None
        secrets_dir = context.secrets_dir
        assert secrets_dir is not None

        sops_path = f"{secrets_dir}/{context.encryption_params.sops_file}"
        cli.run_command(
            command=ShellCommand(
                "sops",
                [
                    "-d",
                    "--extract",
                    context.encryption_params.sops_file_key,
                    "--output",
                    f"{context.tmp_dir}/secret.key",
                    sops_path,
                ],
                env={"SOPS_AGE_KEY_FILE": f"{Path.home()}/.age/{context.age_keyfile}"},
            ),
            description="Decrypting disk encryption keyfile with SOPS",
            error_msg="Failed to decrypt keyfile",
        )


@define
class SendKeyfile:
    name: str = "send_keyfile"
    description: str = "Sending keyfile to target"

    def should_skip(self, context: InstallerContext) -> bool:
        return context.encryption_params is None

    def execute(self, context: InstallerContext, cli: CLI) -> None:
        assert context.encryption_params is not None

        cli.run_command(
            command=context.do_ssh | ShellCommand("mkdir", ["-p", _REMOTE_CACHE]),
            description="Creating remote cache directory",
            error_msg="Failed to create remote cache directory",
        )

        cli.run_command(
            command=RsyncCommand(
                src=f"{context.tmp_dir}/secret.key",
                dest=f"{_REMOTE_CACHE}/",
                ssh_config=context.ssh_config,
            ),
            description="Sending keyfile to cache",
            error_msg="Failed to send keyfile",
        )

        cli.run_command(
            command=context.do_ssh
            | context.do_sudo
            | ShellCommand(
                "mv",
                [
                    f"~/{_REMOTE_CACHE}/secret.key",
                    context.encryption_params.keyfile_location,
                ],
            ),
            description="Moving keyfile to final location",
            error_msg="Failed to move keyfile to target",
        )


@define
class ConfigureSubstituters:
    name: str = "configure_substituters"
    description: str = "Configuring binary cache substituters on target"

    def should_skip(self, context: InstallerContext) -> bool:  # noqa: ARG002
        return False

    def execute(self, context: InstallerContext, cli: CLI) -> None:
        flake_dir = context.flake_dir
        config_base = f"{flake_dir}#nixosConfigurations.{context.flake_host}.config"

        substituters = _nix_eval_tostring(f"{config_base}.nix.settings.substituters")
        trusted_keys = _nix_eval_tostring(
            f"{config_base}.nix.settings.trusted-public-keys"
        )

        nix_conf_lines = (
            f"extra-substituters = {substituters}\n"
            f"extra-trusted-public-keys = {trusted_keys}\n"
        )

        cli.run_command(
            command=context.do_ssh
            | ShellCommand(
                "sh",
                [
                    "-c",
                    f"mkdir -p ~/.config/nix && printf '%s' '{nix_conf_lines}' >> ~/.config/nix/nix.conf",
                ],
            ),
            description="Writing substituter config to target",
            error_msg="Failed to configure substituters on target",
        )


@define
class RunDisko:
    name: str = "run_disko"
    description: str = "Building and running disko on target"

    def should_skip(self, context: InstallerContext) -> bool:  # noqa: ARG002
        return False

    def execute(self, context: InstallerContext, cli: CLI) -> None:
        flake_dir = context.flake_dir
        flake_ref = f"{flake_dir}#nixosConfigurations.{context.flake_host}.config.system.build.diskoScript"

        cli.info("Building disko script...")
        store_path = nix_build(flake_ref)
        cli.info(f"Built disko script: {store_path}")

        cli.run_command(
            command=nix_copy_command(context.ssh_config, store_path),
            description="Copying disko script to target",
            error_msg="Failed to copy disko script to target",
        )

        pipeline = context.do_ssh | context.do_sudo
        cli.run_command(
            command=pipeline | ShellCommand(store_path, []),
            description="Running disko partitioning",
            error_msg="Disko partitioning failed",
        )

        cli.run_command(
            command=pipeline | ShellCommand("nix-collect-garbage", ["-d"]),
            description="Collecting garbage after disko",
            error_msg="nix-collect-garbage failed after disko",
        )


@define
class RunFacter:
    name: str = "run_facter"
    description: str = "Building and running nixos-facter on target"

    def should_skip(self, context: InstallerContext) -> bool:  # noqa: ARG002
        return False

    def execute(self, context: InstallerContext, cli: CLI) -> None:
        cli.info("Building nixos-facter...")
        store_path = nix_build("nixpkgs#nixos-facter")
        cli.info(f"Built nixos-facter: {store_path}")

        cli.run_command(
            command=nix_copy_command(context.ssh_config, store_path),
            description="Copying nixos-facter to target",
            error_msg="Failed to copy nixos-facter to target",
        )

        pipeline = context.do_ssh | context.do_sudo
        cli.run_command(
            command=pipeline
            | ShellCommand(
                f"{store_path}/bin/nixos-facter", ["-o", "/tmp/facter.json"]
            ),
            description="Running nixos-facter",
            error_msg="nixos-facter failed",
        )

        cli.run_command(
            command=pipeline | ShellCommand("nix-collect-garbage", ["-d"]),
            description="Collecting garbage after nixos-facter",
            error_msg="nix-collect-garbage failed after nixos-facter",
        )


@define
class DownloadFacter:
    name: str = "download_facter"
    description: str = "Downloading facter config from target"

    def should_skip(self, context: InstallerContext) -> bool:  # noqa: ARG002
        return False

    def execute(self, context: InstallerContext, cli: CLI) -> None:
        secrets_dir = context.secrets_dir
        if secrets_dir is None:
            raise InstallerError("Secrets directory required for facter download")

        facter_dir = f"{secrets_dir}/facter"
        Path(facter_dir).mkdir(parents=True, exist_ok=True)

        cli.run_command(
            command=context.do_ssh | ShellCommand("mkdir", ["-p", _REMOTE_CACHE]),
            description="Creating remote cache directory",
            error_msg="Failed to create remote cache directory",
        )

        cli.run_command(
            command=context.do_ssh
            | context.do_sudo
            | ShellCommand(
                "install",
                ["-m", "644", "/tmp/facter.json", f"~/{_REMOTE_CACHE}/facter.json"],
            ),
            description="Copying facter.json to cache",
            error_msg="Failed to copy facter.json to cache",
        )

        cli.run_command(
            command=RsyncCommand(
                src=f"{_REMOTE_CACHE}/facter.json",
                dest=f"{facter_dir}/{context.flake_host}.json",
                ssh_config=context.ssh_config,
                remote_dest=False,
            ),
            description=f"Downloading facter config to {facter_dir}/{context.flake_host}.json",
            error_msg="Failed to download facter config",
        )


_GIT_INSTALLER_CONFIG = {
    "user.name": "nixos-installer",
    "user.email": "nixos-installer@local",
}


@define
class CommitFacter:
    name: str = "commit_facter"
    description: str = "Committing facter config to secrets repo"

    def should_skip(self, context: InstallerContext) -> bool:
        return not context.auto_commit

    def execute(self, context: InstallerContext, cli: CLI) -> None:
        secrets_dir = context.secrets_dir
        assert secrets_dir is not None

        git = GitHelper(config=_GIT_INSTALLER_CONFIG, repo_path=secrets_dir)
        msg = f"[my-installer][new-facter-cfg]:{context.flake_host}"

        cli.run_command(
            command=git.add(["."]),
            description="Staging facter config",
            error_msg="Failed to stage facter config",
        )

        cli.run_command(
            command=git.commit(msg),
            description="Committing facter config",
            error_msg="Failed to commit facter config",
            ok_codes=(0, 1),
        )

        if context.auto_push:
            cli.run_command(
                command=git.push(),
                description="Pushing secrets repo",
                error_msg="Failed to push secrets repo",
            )


@define
class UpdateFlakeLock:
    name: str = "update_flake_lock"
    description: str = "Updating flake lock with new secrets"

    def should_skip(self, context: InstallerContext) -> bool:
        return not context.auto_commit

    def execute(self, context: InstallerContext, cli: CLI) -> None:
        flake_dir = context.flake_dir
        git = GitHelper(config=_GIT_INSTALLER_CONFIG, repo_path=flake_dir)

        cli.run_command(
            command=NixCommand(
                [
                    "flake",
                    "update",
                    context.flake_secrets_input_name,
                    "--flake",
                    flake_dir,
                ]
            ),
            description="Updating secrets input in flake lock",
            error_msg="Failed to update flake lock",
        )

        msg = f"[my-installer][update-secrets][new-facter-cfg]:{context.flake_host}"

        cli.run_command(
            command=git.add(["flake.lock"]),
            description="Staging updated flake.lock",
            error_msg="Failed to stage flake.lock",
        )

        cli.run_command(
            command=git.commit(msg),
            description="Committing flake lock update",
            error_msg="Failed to commit flake lock update",
            ok_codes=(0, 1),
        )

        if context.auto_push:
            cli.run_command(
                command=git.push(),
                description="Pushing flake repo",
                error_msg="Failed to push flake repo",
            )


@define
class CopyKeys:
    name: str = "copy_keys"
    description: str = "Copying SSH/AGE keys to target"

    def should_skip(self, context: InstallerContext) -> bool:  # noqa: ARG002
        return False

    def execute(self, context: InstallerContext, cli: CLI) -> None:
        target_dirs = ["/mnt/root"]
        pipeline = context.do_ssh | context.do_sudo

        cli.run_command(
            command=context.do_ssh
            | ShellCommand(
                "mkdir",
                ["-p", f"{_REMOTE_CACHE}/ssh", f"{_REMOTE_CACHE}/age"],
            ),
            description="Creating remote cache directory",
            error_msg="Failed to create remote cache directory",
        )

        cli.run_command(
            command=RsyncCommand(
                src=f"{Path.home()}/.ssh/",
                dest=f"{_REMOTE_CACHE}/ssh/",
                ssh_config=context.ssh_config,
                extra_args=["--include=id_*", "--exclude=*"],
            ),
            description="Sending SSH keys to cache",
            error_msg="Failed to send SSH keys",
        )

        cli.run_command(
            command=RsyncCommand(
                src=f"{Path.home()}/.age/",
                dest=f"{_REMOTE_CACHE}/age/",
                ssh_config=context.ssh_config,
            ),
            description="Sending AGE keys to cache",
            error_msg="Failed to send AGE keys",
        )

        for target_dir in target_dirs:
            cli.run_command(
                command=pipeline
                | ShellCommand(
                    "mkdir",
                    ["-p", f"{target_dir}/.ssh", f"{target_dir}/.age"],
                ),
                description=f"Creating key directories at {target_dir}",
                error_msg=f"Failed to create key dirs at {target_dir}",
            )

            cli.run_command(
                command=pipeline
                | ShellCommand(
                    "cp",
                    ["-a", f"~/{_REMOTE_CACHE}/ssh/.", f"{target_dir}/.ssh/"],
                ),
                description=f"Copying SSH keys to {target_dir}/.ssh",
                error_msg=f"Failed to copy SSH keys to {target_dir}",
            )

            cli.run_command(
                command=pipeline
                | ShellCommand(
                    "cp",
                    ["-a", f"~/{_REMOTE_CACHE}/age/.", f"{target_dir}/.age/"],
                ),
                description=f"Copying AGE keys to {target_dir}/.age",
                error_msg=f"Failed to copy AGE keys to {target_dir}",
            )

        cli.run_command(
            command=context.do_ssh | ShellCommand("rm", ["-rf", _REMOTE_CACHE]),
            description="Cleaning up cache directory",
            error_msg="Failed to clean up cache",
        )


@define
class GenerateInitrdSSHKeys:
    name: str = "generate_initrd_ssh_keys"
    description: str = "Generating initrd SSH host keys on target"

    def should_skip(self, context: InstallerContext) -> bool:
        return not context.gen_initrd_ssh_keys

    def execute(self, context: InstallerContext, cli: CLI) -> None:
        pipeline = context.do_ssh | context.do_sudo
        initrd_key_dir = f"/mnt/{context.initrd_ssh_key_dir}"

        cli.run_command(
            command=pipeline | ShellCommand("mkdir", ["-p", initrd_key_dir]),
            description="Creating initrd secrets directory",
            error_msg="Failed to create initrd secrets directory",
        )

        cli.run_command(
            command=pipeline
            | ShellCommand(
                "ssh-keygen",
                [
                    "-t",
                    "ed25519",
                    "-N",
                    "",
                    "-f",
                    f"{initrd_key_dir}/{context.initrd_ssh_key_name}",
                ],
            ),
            description="Generating host SSH key for initrd",
            error_msg="Failed to generate initrd SSH keys",
        )


@define
class InstallSystem:
    name: str = "install_system"
    description: str = "Building and installing NixOS system"

    def should_skip(self, context: InstallerContext) -> bool:  # noqa: ARG002
        return False

    def execute(self, context: InstallerContext, cli: CLI) -> None:
        flake_dir = context.flake_dir
        flake_ref = f"{flake_dir}#nixosConfigurations.{context.flake_host}.config.system.build.toplevel"

        if context.use_sudo:
            cli.run_command(
                command=context.do_ssh
                | context.do_sudo
                | ShellCommand(
                    "sh",
                    ["-c", "mkdir -p /mnt/nix && chown -R $SUDO_USER /mnt/nix"],
                ),
                description="Granting SSH user write access to /mnt/nix",
                error_msg="Failed to chown /mnt/nix for SSH user",
            )

        cli.info("Building NixOS system closure...")
        store_path = nix_build(flake_ref)
        cli.info(f"Built closure: {store_path}")

        cli.run_command(
            command=nix_copy_command(
                context.ssh_config,
                store_path,
                remote_store="local?root=/mnt",
                substitute_on_dest=True,
            ),
            description="Copying system closure to target /mnt store",
            error_msg="Failed to copy closure to target",
        )

        cli.run_command(
            command=context.do_ssh
            | context.do_sudo
            | ShellCommand(
                "nixos-install",
                [
                    "--no-root-password",
                    "--no-channel-copy",
                    "--root",
                    "/mnt",
                    "--system",
                    store_path,
                ],
            ),
            description=f"Installing NixOS for {context.flake_host}",
            error_msg="nixos-install failed",
        )
