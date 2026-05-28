-- [nfnl] fnl/plugins/snacks/setup.fnl
local function pick(name, ...)
  return Snacks.picker[name](...)
end
local function toggle_term(_, cmd)
  return Snacks.terminal.toggle(cmd, {})
end
local default_terminal_left_min_columns = 150
local default_terminal_left_width = 0.25
local function default_terminal_position()
  if (vim.o.columns < default_terminal_left_min_columns) then
    return "bottom"
  else
    return "left"
  end
end
local function default_terminal_win_opts()
  local position = default_terminal_position()
  local function _2_()
    if (position == "left") then
      return {width = default_terminal_left_width}
    else
      return {}
    end
  end
  return vim.tbl_extend("force", {position = position}, _2_())
end
local function default_terminal_opts()
  return {win = default_terminal_win_opts()}
end
local function apply_default_terminal_position(terminal)
  local position = default_terminal_position()
  local vertical_3f = (position == "left")
  terminal.opts.position = position
  if vertical_3f then
    terminal.opts.width = default_terminal_left_width
  else
  end
  terminal.opts.wo = (terminal.opts.wo or {})
  terminal.opts.wo.winfixheight = not vertical_3f
  terminal.opts.wo.winfixwidth = vertical_3f
  return nil
end
local function toggle_default_terminal()
  local terminal = Snacks.terminal.get(nil, {create = false})
  if terminal then
    if not terminal:valid() then
      apply_default_terminal_position(terminal)
    else
    end
    return terminal:toggle()
  else
    return Snacks.terminal.toggle(nil, default_terminal_opts())
  end
end
local tab_terminal_count = 9001
local tab_terminal_previous_tabpage = nil
local function tab_terminal_opts(_3fextra)
  return vim.tbl_deep_extend("force", {count = tab_terminal_count, win = {position = "current"}}, (_3fextra or {}))
end
local function valid_tabpage_3f(tabpage)
  return (tabpage and vim.api.nvim_tabpage_is_valid(tabpage))
end
local function focus_previous_tab()
  if valid_tabpage_3f(tab_terminal_previous_tabpage) then
    vim.api.nvim_set_current_tabpage(tab_terminal_previous_tabpage)
  else
    vim.cmd.tabprevious()
  end
  tab_terminal_previous_tabpage = nil
  return nil
end
local function focus_terminal_tab(terminal)
  local terminal_tabpage = vim.api.nvim_win_get_tabpage(terminal.win)
  local current_tabpage = vim.api.nvim_get_current_tabpage()
  if (current_tabpage == terminal_tabpage) then
    return focus_previous_tab()
  else
    tab_terminal_previous_tabpage = current_tabpage
    vim.api.nvim_set_current_tabpage(terminal_tabpage)
    terminal:focus()
    return vim.cmd.startinsert()
  end
end
local function focus_or_open_tab_term()
  local terminal = Snacks.terminal.get(nil, tab_terminal_opts({create = false}))
  if (terminal and terminal:valid()) then
    return focus_terminal_tab(terminal)
  else
    tab_terminal_previous_tabpage = vim.api.nvim_get_current_tabpage()
    vim.cmd.tabnew()
    local new_terminal
    if terminal then
      new_terminal = terminal:show()
    else
      new_terminal = Snacks.terminal.open(nil, tab_terminal_opts())
    end
    return new_terminal:focus()
  end
end
local _10_ = require("lib.plugins")
local _11_ = require("lib.keys")
local spec_24_auto = {}
local function _12_()
  return toggle_default_terminal()
end
local function _13_()
  return focus_or_open_tab_term()
end
local function _14_()
  return pick("files")
end
local function _15_()
  return pick("grep")
end
local function _16_()
  local buf_name = vim.api.nvim_buf_get_name(0)
  local buf_dir = vim.fs.dirname(buf_name)
  return pick("files", {cwd = buf_dir})
end
local function _17_()
  return toggle_term("lazygit", "lazygit")
end
local function _18_()
  return pick("command_history")
end
local function _19_()
  return pick("commands")
end
local function _20_()
  return pick("highlights")
end
local function _21_()
  return pick("icons")
end
local function _22_()
  return pick("lsp_config")
end
local function _23_()
  return pick("lsp_symbols")
end
local function _24_()
  return pick("buffers")
end
local function _25_()
  return pick("cliphist")
end
local function _26_()
  return pick("diagnostics")
end
local function _27_()
  return pick("help")
end
local function _28_()
  return pick("jumps")
end
local function _29_()
  return pick("keymaps")
end
local function _30_()
  return pick("man")
end
local function _31_()
  return pick("projects")
end
local function _32_()
  return pick("recent")
end
local function _33_()
  return pick("lsp_workspace_symbols")
end
local function _34_()
  return Snacks.scratch()
end
local function _35_()
  return Snacks.scratch.select()
end
for __25_auto, attrs_26_auto in ipairs({_10_.lazy(false), _10_.keys(_11_.bind(_11_.a("/"), _12_, _11_.desc("Terminal"), _11_.m("n", "t")), _11_.bind(_11_.a("\\"), _13_, _11_.desc("Terminal (tab)"), _11_.m("n", "t")), _11_.bind(_11_.l("<leader>"), _14_, _11_.desc("Fuzzy Files"), _11_.icon("\238\151\190 ", "yellow")), _11_.bind(_11_.l("/"), _15_, _11_.desc("Grep"), _11_.icon("\243\176\147\185 ", "yellow")), _11_.bind(_11_.l("."), _16_, _11_.desc("Fuzzy Files (buffer)"), _11_.icon("\238\151\190 ", "orange")), _11_.group("git", _11_.bind("g", _17_, _11_.desc("Lazygit"))), _11_.group("fuzzy", _11_.bind(":", _18_, _11_.desc("Command history")), _11_.bind(";", _19_, _11_.desc("Commands")), _11_.bind("H", _20_, _11_.desc("Highlights")), _11_.bind("I", _21_, _11_.desc("Icons")), _11_.bind("L", _22_, _11_.desc("LSP Config")), _11_.bind("S", _23_, _11_.desc("Symbols (buffer)")), _11_.bind("b", _24_, _11_.desc("Buffers")), _11_.bind("c", _25_, _11_.desc("Cliphist")), _11_.bind("d", _26_, _11_.desc("Diagnostics")), _11_.bind("h", _27_, _11_.desc("Help Tags")), _11_.bind("j", _28_, _11_.desc("Jumps")), _11_.bind("k", _29_, _11_.desc("Keymaps")), _11_.bind("m", _30_, _11_.desc("Man pages")), _11_.bind("p", _31_, _11_.desc("Projects")), _11_.bind("r", _32_, _11_.desc("Recent")), _11_.bind("s", _33_, _11_.desc("Symbols"))), _11_.group("buffer", _11_.bind("b", _34_, _11_.desc("Scratch")), _11_.bind("B", _35_, _11_.desc("Scratch (pick)")))), _10_.opts({bigfile = {enabled = true}, quickfile = {enabled = true}, notify = {enabled = true}, notifier = require("plugins.snacks._notifier"), terminal = {}, picker = require("plugins.snacks._picker"), dashboard = require("plugins.snacks._dashboard"), styles = require("plugins.snacks._styles"), input = {enabled = true}, image = {enabled = true}})}) do
  for key_27_auto, value_28_auto in pairs(attrs_26_auto) do
    spec_24_auto[key_27_auto] = value_28_auto
  end
end
spec_24_auto[1] = "folke/snacks.nvim"
return spec_24_auto
