#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = [
#     "cyclopts>=4.5.1",
# ]
# ///

import json
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Annotated, TextIO

from cyclopts import App, CycloptsError, Parameter

SCRIPT_DESCRIPTION = "Search and print Neovim help through headless nvim."
SLASH_DELIMITER_LENGTH = 2
InjectedNvimBin = Annotated[str, Parameter(parse=False, show=False)]
InjectedWithConfig = Annotated[bool, Parameter(parse=False, show=False)]

app = App(
  name="nvim-help",
  result_action="return_value",
  exit_on_error=False,
  print_error=False,
)


def _emit(text: str, stream: TextIO = sys.stdout) -> None:
  _ = stream.write(text)


def _lua_literal(value: object) -> str:
  return json.dumps(value)


def _base_command(nvim_bin: str, *, with_config: bool) -> list[str]:
  command = [nvim_bin, "--headless"]
  if not with_config:
    command.extend(["-u", "NONE"])
  return command


def _run_lua(lua_source: str, nvim_bin: str, *, with_config: bool) -> int:
  with tempfile.NamedTemporaryFile(
    "w", encoding="utf-8", suffix=".lua", delete=False
  ) as lua_file:
    _ = lua_file.write(lua_source)
    lua_path = Path(lua_file.name)

  command = _base_command(nvim_bin, with_config=with_config)
  command.extend([f"+luafile {lua_path}", "+qa"])

  try:
    completed = subprocess.run(  # noqa: S603
      command,
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


def _strip_slash_delimiters(pattern: str) -> str:
  if (
    len(pattern) >= SLASH_DELIMITER_LENGTH
    and pattern.startswith("/")
    and pattern.endswith("/")
  ):
    return pattern[1:-1]
  return pattern


@app.command(name="search")
def _search_help(
  *pattern: str,
  case_sensitive: bool = False,
  limit: int = 40,
  _nvim_bin: InjectedNvimBin = "nvim",
  _with_config: InjectedWithConfig = False,
) -> int:
  """Search help lines with :helpgrep."""
  if not pattern:
    raise SystemExit("pass at least one pattern token")

  rendered_pattern = _strip_slash_delimiters(" ".join(pattern))
  if (
    not case_sensitive
    and r"\c" not in rendered_pattern
    and r"\C" not in rendered_pattern
  ):
    rendered_pattern = f"{rendered_pattern}\\c"

  lua_source = f"""
local pattern = {_lua_literal(rendered_pattern)}
local limit = {_lua_literal(limit)}
local ok, err = pcall(vim.api.nvim_cmd, {{
  cmd = "helpgrep",
  args = {{ pattern }},
  mods = {{ silent = true }},
}}, {{}})
if not ok then
  vim.api.nvim_err_writeln(tostring(err))
  vim.cmd("cquit 1")
end

local qf = vim.fn.getqflist()
if #qf == 0 then
  vim.api.nvim_err_writeln("No help matches: " .. pattern)
  vim.cmd("cquit 1")
end

local shown = 0
for _, item in ipairs(qf) do
  if limit > 0 and shown >= limit then
    break
  end
  shown = shown + 1
  local filename = vim.fn.bufname(item.bufnr)
  local line = item.text or ""
  io.write(string.format("%s:%d:%d: %s\\n", filename, item.lnum, item.col, line))
end

if limit > 0 and #qf > limit then
  io.write(string.format("... %d more matches\\n", #qf - limit))
end
""".strip()
  return _run_lua(lua_source, _nvim_bin, with_config=_with_config)


@app.command(name="page")
def _page_help(
  tag: str,
  *,
  context: int = 80,
  _nvim_bin: InjectedNvimBin = "nvim",
  _with_config: InjectedWithConfig = False,
) -> int:
  """Print help text around a tag."""
  lua_source = f"""
local tag = {_lua_literal(tag)}
local context = {_lua_literal(context)}
local ok, err = pcall(vim.api.nvim_cmd, {{
  cmd = "help",
  args = {{ tag }},
  mods = {{ silent = true }},
}}, {{}})
if not ok then
  vim.api.nvim_err_writeln(tostring(err))
  vim.cmd("cquit 1")
end

local buf = vim.api.nvim_get_current_buf()
local filename = vim.api.nvim_buf_get_name(buf)
local line_count = vim.api.nvim_buf_line_count(buf)
local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
local first = 0
local last = line_count

if context > 0 then
  first = math.max(0, cursor_line - context - 1)
  last = math.min(line_count, cursor_line + context)
end

io.write(string.format("%s:%d\\n", filename, cursor_line))
for index, line in ipairs(vim.api.nvim_buf_get_lines(buf, first, last, false)) do
  io.write(string.format("%d|%s\\n", first + index, line))
end
""".strip()
  return _run_lua(lua_source, _nvim_bin, with_config=_with_config)


@app.command(name="tags")
def _tag_help(
  *query: str,
  limit: int = 80,
  _nvim_bin: InjectedNvimBin = "nvim",
  _with_config: InjectedWithConfig = False,
) -> int:
  """List matching help tags."""
  if not query:
    raise SystemExit("pass at least one query token")

  rendered_query = " ".join(query)

  lua_source = f"""
local query = {_lua_literal(rendered_query)}
local limit = {_lua_literal(limit)}
local matches = vim.fn.getcompletion(query, "help")
if #matches == 0 then
  vim.api.nvim_err_writeln("No help tags: " .. query)
  vim.cmd("cquit 1")
end

for index, match in ipairs(matches) do
  if limit > 0 and index > limit then
    break
  end
  io.write(match .. "\\n")
end

if limit > 0 and #matches > limit then
  io.write(string.format("... %d more tags\\n", #matches - limit))
end
""".strip()
  return _run_lua(lua_source, _nvim_bin, with_config=_with_config)


@app.meta.default
def _run_cli(
  *tokens: Annotated[str, Parameter(show=False, allow_leading_hyphen=True)],
  nvim_bin: str = "nvim",
  with_config: bool = False,
) -> int:
  command, bound, ignored = app.parse_args(tokens)
  extra_kwargs: dict[str, object] = {}
  if "_nvim_bin" in ignored:
    extra_kwargs["_nvim_bin"] = nvim_bin
  if "_with_config" in ignored:
    extra_kwargs["_with_config"] = with_config
  return command(*bound.args, **bound.kwargs, **extra_kwargs)


if __name__ == "__main__":
  try:
    raise SystemExit(app.meta())
  except CycloptsError as error:
    print(error)
    raise SystemExit(1)
