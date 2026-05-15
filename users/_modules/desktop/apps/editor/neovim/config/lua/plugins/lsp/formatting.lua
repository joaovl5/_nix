-- [nfnl] fnl/plugins/lsp/formatting.fnl
local formatters = {alejandra = {command = "alejandra"}, fnlfmt = {command = "fnlfmt"}, kdlfmt = {command = "kdlfmt", args = {"format", "--kdl-version", "v1", "--stdin"}}, nix_fmt = {command = "nix", args = {"fmt"}}, prettierd = {command = "prettierd"}}
local default_formatters_by_ft = {["*"] = {"keep-sorted"}, _ = {"trim_whitespace", "trim_newlines", "squeeze_blanks"}, dockerfile = {"dockerfmt"}, fennel = {"fnlfmt"}, fish = {"fish_indent"}, handlebars = {"prettierd"}, javascript = {"prettierd"}, json = {"jsonfmt"}, kdl = {"kdlfmt"}, kulala = {"kulala-fmt"}, lua = {"stylua"}, markdown = {"rumdl"}, nix = {"alejandra"}, python = {"ruff_fix", "ruff_format", "ruff_organize_imports"}, rust = {"rust_fmt"}, sh = {"shfmt"}, sql = {"sqruff"}, toml = {"taplo"}, typescript = {"prettierd"}, typescriptreact = {"prettierd"}, yaml = {"yamlfmt"}}
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
return {"stevearc/conform.nvim", dependencies = {"folke/neoconf.nvim"}, opts = {formatters = formatters, formatters_by_ft = formatters_by_ft, format_on_save = {timeout_ms = 3000, lsp_format = "fallback"}}}
