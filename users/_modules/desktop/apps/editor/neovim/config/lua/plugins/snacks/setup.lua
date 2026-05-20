-- [nfnl] fnl/plugins/snacks/setup.fnl
local function pick(name, ...)
  return Snacks.picker[name](...)
end
local function toggle_term(_, cmd)
  return Snacks.terminal.toggle(cmd, {})
end
local _1_ = require("lib.plugins")
local _2_ = require("lib.keys")
local spec_24_auto = {}
local function _3_()
  return Snacks.terminal.toggle()
end
local function _4_()
  return pick("files")
end
local function _5_()
  return pick("grep")
end
local function _6_()
  local buf_name = vim.api.nvim_buf_get_name(0)
  local buf_dir = vim.fs.dirname(buf_name)
  return pick("files", {cwd = buf_dir})
end
local function _7_()
  return toggle_term("lazygit", "lazygit")
end
local function _8_()
  return pick("command_history")
end
local function _9_()
  return pick("buffers")
end
local function _10_()
  return pick("recent")
end
local function _11_()
  return pick("projects")
end
local function _12_()
  return pick("diagnostics")
end
local function _13_()
  return pick("help")
end
local function _14_()
  return pick("man")
end
local function _15_()
  return pick("highlights")
end
local function _16_()
  return pick("lsp_workspace_symbols")
end
local function _17_()
  return pick("lsp_symbols")
end
local function _18_()
  return Snacks.scratch()
end
local function _19_()
  return Snacks.scratch.select()
end
for __25_auto, attrs_26_auto in ipairs({_1_.lazy(false), _1_.keys(_2_.bind(_2_.a("/"), _3_, _2_.desc("Terminal"), _2_.m("n", "t")), _2_.bind(_2_.l("<leader>"), _4_, _2_.desc("Fuzzy Files"), _2_.icon("\238\151\190 ", "yellow")), _2_.bind(_2_.l("/"), _5_, _2_.desc("Grep"), _2_.icon("\243\176\147\185 ", "yellow")), _2_.bind(_2_.l("."), _6_, _2_.desc("Fuzzy Files (buffer)"), _2_.icon("\238\151\190 ", "orange")), _2_.group("git", _2_.bind("g", _7_, _2_.desc("Lazygit"))), _2_.group("fuzzy", _2_.bind(":", _8_, _2_.desc("':' history")), _2_.bind("b", _9_, _2_.desc("Buffers")), _2_.bind("r", _10_, _2_.desc("Recent")), _2_.bind("p", _11_, _2_.desc("Projects")), _2_.bind("d", _12_, _2_.desc("Diagnostics")), _2_.bind("h", _13_, _2_.desc("Help Tags")), _2_.bind("m", _14_, _2_.desc("Man pages")), _2_.bind("H", _15_, _2_.desc("Highlights")), _2_.bind("s", _16_, _2_.desc("Symbols")), _2_.bind("S", _17_, _2_.desc("Symbols (buffer)"))), _2_.group("buffer", _2_.bind("b", _18_, _2_.desc("Scratch")), _2_.bind("B", _19_, _2_.desc("Scratch (pick)")))), _1_.opts({bigfile = {enabled = true}, quickfile = {enabled = true}, notify = {enabled = true}, notifier = require("plugins.snacks._notifier"), terminal = {}, picker = require("plugins.snacks._picker"), dashboard = require("plugins.snacks._dashboard"), styles = require("plugins.snacks._styles"), input = {enabled = true}, image = {enabled = true}})}) do
  for key_27_auto, value_28_auto in pairs(attrs_26_auto) do
    spec_24_auto[key_27_auto] = value_28_auto
  end
end
spec_24_auto[1] = "folke/snacks.nvim"
return spec_24_auto
