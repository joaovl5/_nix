#! /usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = [
#     "rich",
# ]
# ///

import argparse
import subprocess
from pathlib import Path

from rich import print  # pyright: ignore
from rich.console import Console  # pyright: ignore
from rich.panel import Panel  # pyright: ignore


REPOS = [
    ("git@github.com:joaovl5/_nix.git", "my_nix", "nix flake"),
    ("git@github.com:joaovl5/_secrets.git", "my_secrets", "nix secrets"),
]

console = Console()


def run_command(
    command: list[str],
    description: str,
) -> int:
    """Run a shell command and pretty-print the result.

    Returns the command's exit code.
    """

    console.rule(f"[bold cyan]{description}")
    print(f"[bold]$ {' '.join(command)}[/bold]")

    try:
        result = subprocess.run(command, check=False)
    except Exception as exc:  # pragma: no cover - defensive
        print(f"[red]Failed to run command:[/red] {exc}")
        return 1

    if result.returncode == 0:
        print("[green]OK[/green]")
    else:
        print(f"[red]Command failed with code {result.returncode}[/red]")

    return result.returncode


def ensure_dir(path: Path) -> None:
    """Ensure that a directory exists."""

    if not path.exists():
        path.mkdir(parents=True, exist_ok=True)


def chown_recursive(path: Path, user: str) -> None:
    """Recursively change ownership of a path to the given user."""

    run_command(
        [
            "chown",
            "-R",
            user,
            str(path),
        ],
        f"chown -R {user} {path}",
    )


def copy_all(
    src_dir: Path,
    dest_dir: Path,
    description: str,
    user: str,
    glob: str = "*",
) -> None:
    """Copy all files from src_dir into dest_dir, with Rich output.

    Directories inside src_dir are ignored; only regular files are copied.
    Missing source directories are reported and skipped.
    """

    console.rule(f"[bold cyan]{description}")
    print(f"From [magenta]{src_dir}[/magenta] to [magenta]{dest_dir}[/magenta]")

    if not src_dir.is_dir():
        print("[yellow]Source directory does not exist, skipping.[/yellow]")
        return

    ensure_dir(dest_dir)

    copied = 0
    for item in src_dir.glob(glob):
        if item.is_file():
            target = dest_dir / item.name
            target.write_bytes(item.read_bytes())
            print(f"[green]Copied[/green] {item} -> {target}")
            copied += 1

    if copied == 0:
        print("[yellow]No files to copy.[/yellow]")

    # Ensure destination is owned by the specified user
    chown_recursive(dest_dir, user)


def clone_repo(
    repo_uri: str, repo_description: str, target_dir: Path, user: str
) -> None:
    """Clone the a repository into <target_dir> if it does not exist, then chown it."""

    console.rule(f"[bold cyan]Cloning repository {target_dir}[/bold cyan]")

    if target_dir.exists():
        print(
            f"[yellow]Target directory {target_dir} already exists; "
            "skipping git clone.[/yellow]"
        )
    else:
        _ = run_command(
            ["git", "clone", repo_uri, str(target_dir)],
            f"git clone {repo_description}",
        )

    # Ensure repository directory is owned by the specified user
    chown_recursive(target_dir, user)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Post-install setup: clone my_nix and copy keys into base dir",
    )
    parser.add_argument(
        "base_dir",
        type=Path,
        help=(
            "Base directory where the my_nix repo and secret directories ("
            ".ssh, .age) will be created"
        ),
    )
    parser.add_argument(
        "--user",
        required=True,
        help="User that should own the created files and directories",
    )

    args = parser.parse_args()
    base_dir: Path = args.base_dir.expanduser()
    user: str = args.user

    console.print(
        Panel("Post-install setup starting", style="bold green"),
    )

    copy_all(
        Path("/root/.ssh"),
        base_dir / ".ssh",
        "Copying SSH keys",
        user=user,
        glob="id_*",
    )
    copy_all(
        Path("/root/.age"),
        base_dir / ".age",
        "Copying age keys",
        user=user,
        glob="key*",
    )

    for repo_uri, repo_dirname, repo_desc in REPOS:
        clone_repo(
            repo_uri=repo_uri,
            repo_description=repo_desc,
            target_dir=base_dir / repo_dirname,
            user=user,
        )

    console.print(Panel("Post-install setup finished", style="bold green"))


if __name__ == "__main__":
    main()
