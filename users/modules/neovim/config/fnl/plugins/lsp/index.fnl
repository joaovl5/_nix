(local {: now : add : later}
       {:now MiniDeps.now :add MiniDeps.add :later MiniDeps.later})

(import-macros {: do-req : let-req} :./lib/init-macros)

(now (fn []
       ;; mason setup
       (require :plugins.lsp.mason)
       ;; completion-related
       (require :plugins.lsp.completions)
       ;; lsp-server setup
       (require :plugins.lsp.config)
       ;; formatting setup
       (require :plugins.lsp.formatting)
       ;; other setups
       (require :plugins.lsp.misc)
       ;; language-specific setups
       (require :plugins.lsp.languages.markdown)
       (require :plugins.lsp.languages.lua)
       (require :plugins.lsp.languages.fennel)
       (require :plugins.lsp.languages.typescript)
       (require :plugins.lsp.languages.python)))
