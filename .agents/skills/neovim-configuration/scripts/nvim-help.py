#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.13"
# dependencies = []
# ///
from __future__ import annotations

import argparse
import json
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import TextIO

SCRIPT_DESCRIPTION = "Search and print Neovim help through headless nvim."
SLASH_DELIMITER_LENGTH = 2


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


def _search_help(args: argparse.Namespace) -> int:
  pattern = _strip_slash_delimiters(" ".join(args.pattern))
  if not args.case_sensitive and r"\c" not in pattern and r"\C" not in pattern:
    pattern = f"{pattern}\\c"

  lua_source = f"""
local pattern = {_lua_literal(pattern)}
local limit = {_lua_literal(args.limit)}
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
  return _run_lua(lua_source, args.nvim_bin, with_config=args.with_config)


def _page_help(args: argparse.Namespace) -> int:
  lua_source = f"""
local tag = {_lua_literal(args.tag)}
local context = {_lua_literal(args.context)}
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
  return _run_lua(lua_source, args.nvim_bin, with_config=args.with_config)


def _tag_help(args: argparse.Namespace) -> int:
  query = " ".join(args.query)

  lua_source = f"""
local query = {_lua_literal(query)}
local limit = {_lua_literal(args.limit)}
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
  return _run_lua(lua_source, args.nvim_bin, with_config=args.with_config)


def _build_parser() -> argparse.ArgumentParser:
  parser = argparse.ArgumentParser(description=SCRIPT_DESCRIPTION)
  _ = parser.add_argument("--nvim-bin", default="nvim", help="Neovim binary to run")
  _ = parser.add_argument(
    "--with-config",
    action="store_true",
    help="load the user's config and plugin docs instead of isolated core docs",
  )

  subparsers = parser.add_subparsers(dest="command", required=True)

  search = subparsers.add_parser(
    "search",
    help="search help lines with :helpgrep",
    description="Search help lines with :helpgrep. Patterns are Vim regexps.",
  )
  _ = search.add_argument(
    "pattern",
    nargs="+",
    help="search phrase or Vim regexp; slash delimiters are optional and stripped",
  )
  _ = search.add_argument(
    "--case-sensitive",
    action="store_true",
    help="do not append \\c for case-insensitive helpgrep",
  )
  _ = search.add_argument(
    "--limit",
    type=int,
    default=40,
    help="maximum matches to print; 0 prints all",
  )
  search.set_defaults(handler=_search_help)

  page = subparsers.add_parser(
    "page",
    help="print help text around a tag",
    description="Open :help {tag} and print lines around the jumped-to tag.",
  )
  _ = page.add_argument("tag", help="help tag, e.g. :vertical, 'splitright', windows")
  _ = page.add_argument(
    "--context",
    type=int,
    default=80,
    help="lines before/after the tag; 0 prints the whole help buffer",
  )
  page.set_defaults(handler=_page_help)

  tags = subparsers.add_parser(
    "tags",
    help="complete help tags for a query",
    description="List help tags via getcompletion({query}, 'help').",
  )
  _ = tags.add_argument("query", nargs="+", help="tag prefix or query")
  _ = tags.add_argument(
    "--limit",
    type=int,
    default=80,
    help="maximum tags to print; 0 prints all",
  )
  tags.set_defaults(handler=_tag_help)

  return parser


def _main() -> int:
  parser = _build_parser()
  args = parser.parse_args()
  return args.handler(args)


if __name__ == "__main__":
  raise SystemExit(_main())
