-- [nfnl] fnl/plugins/ui/colors.fnl
local n = require("lib/nvim")
local semantic_token_links = {
	["@variable.typescript"] = "Identifier",
	["@lsp.type.variable.typescript"] = "Identifier",
	["@lsp.typemod.variable.declaration.typescript"] = "Identifier",
	["@lsp.typemod.variable.local.typescript"] = "Identifier",
	["@lsp.typemod.variable.readonly.typescript"] = "Identifier",
	["@lsp.type.variable"] = "@variable",
	["@lsp.type.member"] = "@variable.member",
	["@lsp.typemod.variable.declaration"] = "@lsp.type.variable",
	["@lsp.typemod.variable.local"] = "@lsp.type.variable",
	["@lsp.typemod.variable.readonly"] = "@lsp.type.variable",
	["@lsp.typemod.function.declaration"] = "@lsp.type.function",
	["@lsp.typemod.parameter.declaration"] = "@lsp.type.parameter",
	["@lsp.typemod.member.defaultLibrary"] = "@lsp.type.member",
	["@lsp.typemod.property.declaration"] = "@lsp.type.property",
}
local function apply_semantic_token_links()
	for group, target in pairs(semantic_token_links) do
		vim.api.nvim_set_hl(0, group, { link = target })
	end
end
local function _1_()
	apply_semantic_token_links()
	return n.autocmd("ColorScheme", { callback = apply_semantic_token_links })
end
return { "rasulomaroff/reactive.nvim", builtin = { cursorline = true, cursor = true, modemsg = true }, config = _1_ }
