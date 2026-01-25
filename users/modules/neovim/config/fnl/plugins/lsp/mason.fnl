(local {: now : add : later}
       {:now MiniDeps.now :add MiniDeps.add :later MiniDeps.later})

(import-macros {: do-req : let-req} :./lib/init-macros)

(add :mason-org/mason.nvim)
(do-req :mason :setup {})

(add :mason-org/mason-lspconfig.nvim)
(do-req :mason-lspconfig :setup {})

(add :WhoIsSethDaniel/mason-tool-installer.nvim)
(do-req :mason-tool-installer :setup {})
