-- [nfnl] fnl/plugins/lsp/languages/markdown.fnl
local filetypes = {"markdown", "quarto", "rmd", "typst", "Avante"}
return {"OXY2DEV/markview.nvim", ft = filetypes, opts = {preview = {filetypes = filetypes, icon_provider = "mini"}}}
