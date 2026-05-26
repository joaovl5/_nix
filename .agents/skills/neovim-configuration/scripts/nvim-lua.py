#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = [
#     "cyclopts>=4.5.1",
# ]
# ///
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import TextIO

from cyclopts import App, CycloptsError

SCRIPT_DESCRIPTION = "Run arbitrary Lua inside the repo Neovim config."
CONFIG_PATH = Path("users/_modules/desktop/apps/editor/neovim/config")

app = App(
  name="nvim-lua",
  result_action="return_value",
  exit_on_error=False,
  print_error=False,
)


def _emit(text: str, stream: TextIO = sys.stdout) -> None:
  _ = stream.write(text)


def _find_repo_root() -> Path:
  current = Path(__file__).resolve()
  for candidate in [current.parent, *current.parents]:
    if (candidate / "flake.nix").is_file():
      return candidate
  msg = "Could not locate repo root from script path"
  raise RuntimeError(msg)


def _lua_bool(*, value: bool) -> str:
  return "true" if value else "false"


def _lua_literal(value: object) -> str:
  return json.dumps(value)


def _read_lua_source(*, file: Path | None, lua: tuple[str, ...]) -> str:
  if file is not None:
    return file.expanduser().read_text(encoding="utf-8")
  return " ".join(lua)


def _wrapped_lua_source(source: str, *, defer_ms: int, auto_quit: bool) -> str:
  body = f"""
local function __skill_body()
{source}
end

local function __skill_run()
  local ok, err = xpcall(__skill_body, debug.traceback)
  if not ok then
    vim.api.nvim_err_writeln(tostring(err))
    vim.cmd("cquit 1")
    return
  end
  if {_lua_bool(value=auto_quit)} then
    vim.cmd("qa")
  end
end
""".strip()

  if defer_ms > 0:
    return f"{body}\n\nvim.defer_fn(__skill_run, {_lua_literal(defer_ms)})\n"
  return f"{body}\n\n__skill_run()\n"


def _run_lua(
  lua_source: str,
  *,
  nvim_bin: str,
  defer_ms: int,
  auto_quit: bool,
) -> int:
  repo_root = _find_repo_root()
  config_dir = repo_root / CONFIG_PATH
  local_lua = config_dir / "local.lua"
  if not local_lua.is_file():
    _emit(f"Neovim config shim not found: {local_lua}\n", sys.stderr)
    return 1

  with tempfile.NamedTemporaryFile(
    "w", encoding="utf-8", suffix=".lua", delete=False
  ) as lua_file:
    _ = lua_file.write(
      _wrapped_lua_source(lua_source, defer_ms=defer_ms, auto_quit=auto_quit)
    )
    lua_path = Path(lua_file.name)

  command = [
    nvim_bin,
    "--headless",
    "--cmd",
    f"set rtp^={config_dir}",
    "-u",
    str(local_lua),
    f"+luafile {lua_path}",
  ]

  env = os.environ.copy()
  _ = env.setdefault("NVIM_EAGER_PLUGINS", "1")

  try:
    completed = subprocess.run(
      command,
      cwd=repo_root,
      env=env,
      text=True,
      capture_output=True,
      check=False,
    )
  finally:
    lua_path.unlink(missing_ok=True)

  if completed.stdout:
    _emit(completed.stdout)
  if completed.stderr:
    _emit(completed.stderr, sys.stderr)
  return completed.returncode


@app.default
def main(
  *lua: str,
  nvim_bin: str = "nvim",
  defer_ms: int = 0,
  no_auto_quit: bool = False,
  file: Path | None = None,
) -> int:
  """Run a Lua snippet inside the repo Neovim config."""
  if defer_ms < 0:
    raise SystemExit("--defer-ms must be >= 0")
  if file is not None and lua:
    raise SystemExit("pass either --file or Lua arguments, not both")
  if file is None and not lua:
    raise SystemExit("pass a Lua snippet or --file PATH")
  return _run_lua(
    _read_lua_source(file=file, lua=lua),
    nvim_bin=nvim_bin,
    defer_ms=defer_ms,
    auto_quit=not no_auto_quit,
  )


if __name__ == "__main__":
  try:
    raise SystemExit(app())
  except CycloptsError as error:
    print(error)
    raise SystemExit(1)
