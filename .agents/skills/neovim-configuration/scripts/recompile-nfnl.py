#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = [
#     "cyclopts>=4.5.1",
# ]
# ///

import os
import subprocess
import tempfile
import textwrap
from pathlib import Path

from cyclopts import App, CycloptsError

DEFAULT_ANCHOR = Path(
  "modules/aspects/desktop/desktop/apps/editor/neovim/config/flsproject.fnl"
)

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
  raise RuntimeError(
    f"Could not locate .nfnl.fnl above anchor: {anchor}"
  )


def _path_for_nvim(path: Path, base: Path) -> str:
  try:
    return str(path.relative_to(base))
  except ValueError:
    return str(path)


def _default_nfnl_rtp() -> Path:
  return Path.home() / ".local/share/nvim/lazy/nfnl"


def _nfnl_lua_script(keep_orphans: bool) -> str:
  return textwrap.dedent(
    f"""
        local keep_orphans = {str(keep_orphans).lower()}

        local function fail(message)
          print(message)
          vim.cmd("cquit 1")
        end

        local function print_compile_summary(results)
          local counts = {{}}
          for _, result in ipairs(results) do
            local status = result.status or "unknown"
            counts[status] = (counts[status] or 0) + 1
          end

          local parts = {{}}
          for status, count in pairs(counts) do
            table.insert(parts, status .. "=" .. count)
          end
          table.sort(parts)
          print("nfnl compile results: " .. table.concat(parts, ", "))
        end

        local allowed_statuses = {{
          ok = true,
          ["macros-are-not-compiled"] = true,
          ["nfnl-config-is-not-compiled"] = true,
        }}

        local api = require("nfnl.api")
        local compile_ok, results = pcall(api["compile-all-files"], vim.fn.getcwd())
        if not compile_ok then
          fail("nfnl compile-all-files errored:\\n" .. tostring(results))
        end

        if type(results) ~= "table" or next(results) == nil then
          fail("nfnl compile-all-files returned no results; check .nfnl.fnl trust/config")
        end

        print_compile_summary(results)

        local failures = {{}}
        for _, result in ipairs(results) do
          if not allowed_statuses[result.status] then
            table.insert(failures, result)
          end
        end

        if #failures > 0 then
          print("nfnl compilation failed:")
          for _, result in ipairs(failures) do
            local source = result["source-path"] or "<unknown source>"
            local status = result.status or "unknown"
            print("- " .. status .. ": " .. source)
            if result.error then
              print(result.error)
            end
            if result["destination-path"] then
              print("  destination: " .. result["destination-path"])
            end
          end
          vim.cmd("cquit 1")
        end

        local config_ok, loaded = pcall(require("nfnl.config")["find-and-load"], vim.fn.getcwd())
        if not config_ok then
          fail("nfnl config load errored:\\n" .. tostring(loaded))
        end

        if type(loaded) ~= "table" or not loaded.config then
          fail("nfnl config did not load; check .nfnl.fnl trust/config")
        end

        local gc = require("nfnl.gc")
        local orphan_ok, orphans = pcall(gc["find-orphan-lua-files"], {{
          ["root-dir"] = loaded["root-dir"],
          cfg = loaded.cfg,
        }})
        if not orphan_ok then
          fail("nfnl orphan scan errored:\\n" .. tostring(orphans))
        end

        if #orphans == 0 then
          print("No orphan files detected.")
        elseif keep_orphans then
          print("Orphan files detected:")
          for _, path in ipairs(orphans) do
            print(" - " .. path)
          end
        else
          print("Deleting orphan files:")
          for _, path in ipairs(orphans) do
            print(" - " .. path)
            local remove_ok, error = os.remove(path)
            if not remove_ok then
              fail("Failed to delete orphan " .. path .. ": " .. tostring(error))
            end
          end
        end
        """
  ).strip()


@app.default
def main(
  anchor: Path = DEFAULT_ANCHOR,
  nvim_bin: str = "nvim",
  keep_orphans: bool = False,
  nfnl_rtp: Path | None = None,
) -> int:
  """Recompile the repo's Neovim Fennel tree and optionally delete orphaned Lua."""
  resolved_anchor = _resolve_repo_path(anchor)
  resolved_nfnl_rtp = (nfnl_rtp or _default_nfnl_rtp()).expanduser()
  if not resolved_anchor.is_file():
    print(f"Anchor Fennel file not found: {resolved_anchor}")
    return 1

  if not resolved_nfnl_rtp.is_dir():
    print(f"nfnl runtimepath not found: {resolved_nfnl_rtp}")
    print(
      "Hint: pass --nfnl-rtp PATH if nfnl is installed elsewhere."
    )
    return 1

  try:
    project_root = _find_nfnl_project_root(resolved_anchor)
  except RuntimeError as error:
    print(error)
    return 1

  with tempfile.NamedTemporaryFile(
    "w", encoding="utf-8", suffix=".lua", delete=False
  ) as lua_file:
    lua_file.write(_nfnl_lua_script(keep_orphans))
    lua_script = Path(lua_file.name)

  command = [
    nvim_bin,
    "--headless",
    "-u",
    "NONE",
    "--cmd",
    f"set rtp^={resolved_nfnl_rtp}",
    f"+edit {_path_for_nvim(resolved_anchor, project_root)}",
    f"+luafile {lua_script}",
    "+qa",
  ]

  with tempfile.TemporaryDirectory(
    prefix="nfnl-config-home-"
  ) as config_home:
    print(
      f"$ XDG_CONFIG_HOME={config_home} {_format_command(command)}"
    )
    env = os.environ.copy()
    env["XDG_CONFIG_HOME"] = config_home
    try:
      completed = subprocess.run(
        command,
        cwd=project_root,
        env=env,
        text=True,
        capture_output=True,
        check=False,
      )
    finally:
      lua_script.unlink(missing_ok=True)

  if completed.stdout:
    print(completed.stdout, end="")
    if not completed.stdout.endswith("\n"):
      print()
  if completed.stderr:
    print(completed.stderr, end="")
    if not completed.stderr.endswith("\n"):
      print()

  if completed.returncode != 0:
    print("nfnl recompilation failed.")
    print("Hints:")
    print(
      "- Make sure `nvim` is the repo's configured Neovim on PATH."
    )
    print(
      "- Trust `modules/aspects/desktop/desktop/apps/editor/neovim/config/.nfnl.fnl` once in interactive Neovim before using this script."
    )
    print(
      "- The script opens a Fennel buffer first so nfnl and its filetype hooks are loaded."
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
