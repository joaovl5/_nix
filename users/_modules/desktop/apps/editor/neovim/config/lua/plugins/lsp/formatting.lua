-- [nfnl] fnl/plugins/lsp/formatting.fnl
local formatters = {alejandra = {command = "alejandra"}, jandent = {command = "jindt", stdin = true}, kdlfmt = {command = "kdlfmt", args = {"format", "--kdl-version", "v1", "--stdin"}}, nix_fmt = {command = "nix", args = {"fmt"}}, prettierd = {command = "prettierd"}, sane_fnlfmt = {command = "fnlfmt", args = {"-"}}}
local default_formatters_by_ft = {["*"] = {"keep-sorted"}, _ = {"trim_whitespace", "trim_newlines", "squeeze_blanks"}, dockerfile = {"dockerfmt"}, fennel = {"sane_fnlfmt"}, fish = {"fish_indent"}, handlebars = {"prettierd"}, janet = {"jandent", "squeeze_blanks"}, javascript = {"prettierd"}, json = {"jsonfmt"}, kdl = {"kdlfmt"}, kulala = {"kulala-fmt"}, lua = {"stylua"}, markdown = {"rumdl"}, nix = {"alejandra"}, python = {"ruff_fix", "ruff_format", "ruff_organize_imports"}, rust = {"rust_fmt"}, sh = {"shfmt"}, sql = {"sqruff"}, toml = {"taplo"}, typescript = {"prettierd"}, typescriptreact = {"prettierd"}, yaml = {"yamlfmt"}}
local function get_project_formatters_by_ft(bufnr)
  local ok, neoconf = pcall(require, "neoconf")
  if ok then
    return neoconf.get("formatter.filetypes", {}, {buffer = bufnr, ["local"] = true, global = false})
  else
    return {}
  end
end
local function resolve_formatters_for_ft(bufnr, filetype)
  local project_map = get_project_formatters_by_ft(bufnr)
  local override = project_map[filetype]
  if vim.islist(override) then
    return override
  else
    return default_formatters_by_ft[filetype]
  end
end
local formatters_by_ft
do
  local ft_keys = vim.tbl_keys(default_formatters_by_ft)
  local tbl_21_ = {}
  for _, ft in ipairs(ft_keys) do
    local k_22_, v_23_
    local function _3_(_241)
      return resolve_formatters_for_ft(_241, ft)
    end
    k_22_, v_23_ = ft, _3_
    if ((k_22_ ~= nil) and (v_23_ ~= nil)) then
      tbl_21_[k_22_] = v_23_
    else
    end
  end
  formatters_by_ft = tbl_21_
end
local _5_ = require("lib.plugins")
local _6_ = require("lib.keys")
local spec_21_auto = {}
local function _7_()
  local name_1_auto = require("conform")
  local fun_2_auto = name_1_auto.format
  return fun_2_auto()
end
for __22_auto, attrs_23_auto in ipairs({_5_.deps({"folke/neoconf.nvim"}), _5_.event("BufEnter"), _5_.keys(_6_.group("code", _6_.bind("f", _7_, _6_.desc("Format")))), _5_.opts({formatters = formatters, formatters_by_ft = formatters_by_ft, format_on_save = {timeout_ms = 3000, lsp_format = "fallback"}})}) do
  for key_24_auto, value_25_auto in pairs(attrs_23_auto) do
    spec_21_auto[key_24_auto] = value_25_auto
  end
end
spec_21_auto[1] = "stevearc/conform.nvim"
return spec_21_auto
