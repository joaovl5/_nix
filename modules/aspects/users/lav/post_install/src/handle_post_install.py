#! /usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = [
#     "cyclopts>=4.5.1",
#     "rich",
# ]
# ///

import subprocess
from pathlib import Path

from cyclopts import App, CycloptsError
from rich import print
from rich.console import Console
from rich.panel import Panel

REPOS = [
  ("git@github.com:joaovl5/_nix.git", "my_nix", "nix config"),
  ("git@github.com:joaovl5/__secrets.git", "my_secrets", "nix secrets"),
]

console = Console()
app = App(
  name="handle-post-install",
  result_action="return_value",
  exit_on_error=False,
  print_error=False,
)


def run_command(*, command: list[str], description: str) -> int:
  """Run a shell command and pretty-print the result."""
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


def chown_recursive(*, path: Path, user: str) -> None:
  """Recursively change ownership of a path to the given user."""
  _ = run_command(
    command=[
      "chown",
      "-R",
      user,
      str(path),
    ],
    description=f"chown -R {user} {path}",
  )


def copy_all(
  *,
  src_dir: Path,
  dest_dir: Path,
  description: str,
  user: str,
  glob: str = "*",
) -> None:
  """Copy regular files from one directory into another."""
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
      _ = target.write_bytes(item.read_bytes())
      print(f"[green]Copied[/green] {item} -> {target}")
      copied += 1

  if copied == 0:
    print("[yellow]No files to copy.[/yellow]")

  chown_recursive(path=dest_dir, user=user)


def clone_repo(
  *, repo_uri: str, repo_description: str, target_dir: Path, user: str
) -> None:
  """Clone a repository into the target directory when it is missing."""
  console.rule(f"[bold cyan]Cloning repository {target_dir}[/bold cyan]")

  if target_dir.exists():
    print(
      f"[yellow]Target directory {target_dir} already exists; "
      "skipping git clone.[/yellow]"
    )
  else:
    _ = run_command(
      command=["git", "clone", repo_uri, str(target_dir)],
      description=f"git clone {repo_description}",
    )

  chown_recursive(path=target_dir, user=user)


@app.default
def main(base_dir: Path, *, user: str) -> int:
  """Clone repos and copy root-owned keys into the requested base directory."""
  resolved_base_dir = base_dir.expanduser()

  console.print(
    Panel("Post-install setup starting", style="bold green"),
  )

  copy_all(
    src_dir=Path("/root/.ssh"),
    dest_dir=resolved_base_dir / ".ssh",
    description="Copying SSH keys",
    user=user,
    glob="id_*",
  )
  copy_all(
    src_dir=Path("/root/.age"),
    dest_dir=resolved_base_dir / ".age",
    description="Copying age keys",
    user=user,
    glob="key*",
  )

  for repo_uri, repo_dirname, repo_desc in REPOS:
    clone_repo(
      repo_uri=repo_uri,
      repo_description=repo_desc,
      target_dir=resolved_base_dir / repo_dirname,
      user=user,
    )

  console.print(Panel("Post-install setup finished", style="bold green"))
  return 0


if __name__ == "__main__":
  try:
    raise SystemExit(app())
  except CycloptsError as error:
    print(error)
    raise SystemExit(1)
