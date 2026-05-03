(import-macros {: do-req : let-req : plugin : key} :./lib/init-macros)

(local n (require :lib/nvim))

(local semantic-token-links
       {"@variable.typescript" :Identifier
        "@lsp.type.variable.typescript" :Identifier
        "@lsp.typemod.variable.declaration.typescript" :Identifier
        "@lsp.typemod.variable.local.typescript" :Identifier
        "@lsp.typemod.variable.readonly.typescript" :Identifier
        "@lsp.type.variable" "@variable"
        "@lsp.type.member" "@variable.member"
        "@lsp.typemod.variable.declaration" "@lsp.type.variable"
        "@lsp.typemod.variable.local" "@lsp.type.variable"
        "@lsp.typemod.variable.readonly" "@lsp.type.variable"
        "@lsp.typemod.function.declaration" "@lsp.type.function"
        "@lsp.typemod.parameter.declaration" "@lsp.type.parameter"
        "@lsp.typemod.member.defaultLibrary" "@lsp.type.member"
        "@lsp.typemod.property.declaration" "@lsp.type.property"})

(fn apply-semantic-token-links []
  (each [group target (pairs semantic-token-links)]
    (vim.api.nvim_set_hl 0 group {:link target})))

(plugin :rasulomaroff/reactive.nvim
        {:builtin {:cursorline true :cursor true :modemsg true}
         :config (fn []
                   (apply-semantic-token-links)
                   (n.autocmd :ColorScheme
                              {:callback apply-semantic-token-links}))})
