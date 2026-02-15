-- [nfnl] fnl/plugins/lsp/config.fnl
local n = require("lib/nvim")
local function set_python_path(path)
  local clients = vim.lsp.get_clients({bufnr = vim.api.nvim_get_current_buf(), name = "basedpyright"})
  for _, client in ipairs(clients) do
    if (nil ~= client.settings) then
      client.settings.python = vim.tbl_deep_extend("force", (client.settings.python or {}), {pythonPath = path})
    else
      client.config.settings = vim.tbl_deep_extend("force", (client.config.settings or {}), {python = {pythonPath = path}})
    end
    client.notify("workspace/didChangeConfiguration", {settings = nil})
  end
  return nil
end
local function populate_diagnostics(client, bufnr)
  local name_2_auto = require("workspace-diagnostics")
  local fun_3_auto = name_2_auto.populate_workspace_diagnostics
  return fun_3_auto(client, bufnr)
end
local function do_basedpyright_attach(client, bufnr)
  local function _2_()
    return client:exec_cmd({command = "basedpyright.organizeimports", arguments = {[vim.uri_from_bufnr] = bufnr}})
  end
  n.usercmd(bufnr, "LspPyrightOrganizeImports", {desc = "Organize Imports"}, _2_)
  n.usercmd(bufnr, "LspPyrightSetPythonPath", {desc = "Set Python Path", nargs = 1, complete = "file"}, set_python_path)
  return populate_diagnostics(client, bufnr)
end
local function get_fennel_root_dir(bufnr, on_dir)
  local fname = vim.api.nvim_buf_get_name(bufnr)
  local has_fls_cfg
  local function _3_(_241)
    return ("file" == (vim.uv.fs_stat(vim.fs.joinpath(_241, "flsproject.fnl")) or {}).type)
  end
  has_fls_cfg = _3_
  return on_dir((vim.iter(vim.fs.parents(fname)):find(has_fls_cfg) or vim.fs.root(0, ".git")))
end
local function mk_lsp()
  local schemastore = require("schemastore")
  local blink = require("blink.cmp")
  local servers
  local _4_
  do
    local nixos_hostname = "lavpc"
    _4_ = ("(builtins.getFlake (builtins.toString ./.)).nixosConfigurations." .. nixos_hostname .. ".options")
  end
  servers = {basedpyright = {on_attach = do_basedpyright_attach, settings = {basedpyright = {analysis = {autoSearchPaths = true, useLibraryCodeForTypes = true, typeCheckingMode = "recommended", diagnosticMode = "workspace", reportExplicitAny = false, reportUnknownParameterType = false}}}}, ruff = {server_capabilities = {hoverProvider = false}}, lua_ls = {cmd = {"lua-language-server"}, settings = {Lua = {completion = {callSnippet = "Replace"}}}}, fennel_ls = {cmd = {"fennel-ls"}, single_file_support = true, root_dir = get_fennel_root_dir}, jsonls = {cmd = {"jsonls"}, settings = {json = {schemas = schemastore.json.schemas()}}}, nixd = {cmd = {"nixd"}, settings = {nixd = {nixpkgs = {expr = "import <nixpkgs> {}"}, formatting = {command = {"alejandra"}}, options = {["home-manager"] = {expr = "(builtins.getFlake (builtins.toString ./.)).nixosConfigurations.<name>.options.home-manager.users.type.getSubOptions []"}, nixos = {expr = _4_}}}}}, marksman = {cmd = {"marksman"}}, stylua = {cmd = {"stylua"}}, yamlls = {cmd = {"yaml-language-server"}}, ["nil"] = {cmd = {"nil"}, filetypes = {"nix"}, root_markers = {"flake.nix", ".git"}, settings = {["nil"] = {nix = {flake = {autoArchive = true, autoEvalInputs = true, nixpkgsInputName = "nixpkgs"}}}}}}
  for server, config in pairs(servers) do
    vim.lsp.config(server, config)
    vim.lsp.config(server, blink.get_lsp_capabilities())
    vim.lsp.config(server, {on_attach = populate_diagnostics})
    vim.lsp.enable(server)
  end
  return nil
end
local function _5_()
  local nu = require("null-ls").builtins
  local no
  local function _6_(_241)
    return require(("none-ls." .. _241))
  end
  no = _6_
  return {sources = {nu.diagnostics.gitleaks, nu.diagnostics.proselint, nu.hover.dictionary, nu.diagnostics.hadolint, nu.hover.printenv, nu.diagnostics.fish, nu.formatting.alejandra, nu.diagnostics.statix, nu.code_actions.statix, nu.diagnostics.deadnix, nu.formatting.prettierd, no("formatting.jq"), no("diagnostics.eslint_d"), no("code_actions.eslint_d")}}
end
return {{"nvimtools/none-ls.nvim", dependencies = {"nvim-lua/plenary.nvim", "nvimtools/none-ls-extras.nvim"}, event = "VeryLazy", opts = _5_}, {"neovim/nvim-lspconfig", config = mk_lsp, event = "VeryLazy", dependencies = {"b0o/schemastore.nvim", {"artemave/workspace-diagnostics.nvim", event = "LspAttach", opts = {}}}}}
