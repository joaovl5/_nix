-- [nfnl] fnl/plugins/lsp/completions/_sources.fnl
local function transform_items_base(k_icon, k_name, _ctx, items)
  for _, item in ipairs(items) do
    item.kind_icon = k_icon
    item.kind_name = k_name
  end
  return items
end
local function transform_items(k_icon, k_name)
  local function _1_(...)
    return transform_items_base(k_icon, k_name, ...)
  end
  return _1_
end
local sources = {"conv_commit", "lsp", "path", "snippets", "buffer", "env", "git", "grep"}
local debug_sources
do
  local result = {"dap"}
  for _, source in ipairs(sources) do
    table.insert(result, source)
  end
  debug_sources = result
end
local function _2_()
  local name_1_auto = require("cmp_dap")
  local fun_2_auto = name_1_auto.is_dap_buffer
  return fun_2_auto()
end
local _3_
do
  local btypes = require("blink.cmp.types")
  _3_ = btypes.CompletionItemKind.Variable
end
local function _4_()
  return (vim.bo.filetype == "gitcommit")
end
return {default = sources, per_filetype = {["dap-repl"] = debug_sources, ["dap-view"] = debug_sources}, providers = {dap = {name = "dap", module = "blink.compat.sources", enabled = _2_}, grep = {name = "Grep", module = "blink-ripgrep", transform_items = transform_items("\238\173\190 ", "Grep"), opts = {prefix_min_len = 4, backend = {use = "gitgrep-or-ripgrep"}}}, env = {name = "Env Vars", module = "blink-cmp-env", transform_items = transform_items("\243\176\185\187 ", "Env"), opts = {item_kind = _3_, show_braces = false, show_documentation_window = false}}, git = {module = "blink-cmp-git", name = "Git", transform_items = transform_items("\243\176\138\162 ", "Git"), opts = {}}, conv_commit = {name = "Conventional Commits", module = "blink-cmp-conventional-commits", enabled = _4_, opts = {}}}}
