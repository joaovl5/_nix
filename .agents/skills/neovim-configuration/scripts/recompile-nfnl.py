#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.13"
# dependencies = [
#     "cyclopts>=4.5.1",
# ]
# ///

from __future__ import annotations

from pathlib import Path
import subprocess

from cyclopts import App, CycloptsError

DEFAULT_ANCHOR = Path("users/_modules/desktop/apps/editor/neovim/config/flsproject.fnl")

app = App(
    name="recompile-nfnl",
    result_action="return_value",
    exit_on_error=False,
    print_error=False,
)


def _find_repo_root() -> Path:
    current = Path(__file__).resolve()
    for candidate in [current.parent, *current.parents]:
        if (candidate / "flake.nix").is_file():
            return candidate
    raise RuntimeError("Could not locate repo root from script path")


REPO_ROOT = _find_repo_root()


def _resolve_repo_path(path: Path) -> Path:
    expanded = path.expanduser()
    if expanded.is_absolute():
        return expanded
    return REPO_ROOT / expanded


def _format_command(command: list[str]) -> str:
    return " ".join(command)


def _find_nfnl_project_root(anchor: Path) -> Path:
    current = anchor.parent if anchor.is_file() else anchor
    for candidate in [current, *current.parents]:
        if (candidate / ".nfnl.fnl").is_file():
            return candidate
    raise RuntimeError(f"Could not locate .nfnl.fnl above anchor: {anchor}")


def _path_for_nvim(path: Path, base: Path) -> str:
    try:
        return str(path.relative_to(base))
    except ValueError:
        return str(path)


@app.default
def main(
    anchor: Path = DEFAULT_ANCHOR,
    nvim_bin: str = "nvim",
    keep_orphans: bool = False,
) -> int:
    """Recompile the repo's Neovim Fennel tree and optionally delete orphaned Lua."""

    resolved_anchor = _resolve_repo_path(anchor)
    if not resolved_anchor.is_file():
        print(f"Anchor Fennel file not found: {resolved_anchor}")
        return 1

    try:
        project_root = _find_nfnl_project_root(resolved_anchor)
    except RuntimeError as error:
        print(error)
        return 1

    command = [
        nvim_bin,
        "--headless",
        f"+edit {_path_for_nvim(resolved_anchor, project_root)}",
        "+NfnlCompileAllFiles",
    ]
    if keep_orphans:
        command.append("+NfnlFindOrphans")
    else:
        command.append("+NfnlDeleteOrphans")
    command.append("+qa")

    print(f"$ {_format_command(command)}")
    completed = subprocess.run(
        command,
        cwd=project_root,
        text=True,
        capture_output=True,
        check=False,
    )

    if completed.stdout:
        print(completed.stdout, end="")
    if completed.stderr:
        print(completed.stderr, end="")

    if completed.returncode != 0:
        print("nfnl recompilation failed.")
        print("Hints:")
        print("- Make sure `nvim` is the repo's configured Neovim on PATH.")
        print(
            "- Trust `users/_modules/desktop/apps/editor/neovim/config/.nfnl.fnl` once in interactive Neovim before using this script."
        )
        print(
            "- The script opens a Fennel buffer first because nfnl commands are buffer-local."
        )
        return completed.returncode

    if keep_orphans:
        print("Recompiled Fennel. Orphans were only listed, not deleted.")
    else:
        print("Recompiled Fennel and deleted orphaned generated Lua.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(app())
    except CycloptsError as error:
        print(error)
        raise SystemExit(1)
