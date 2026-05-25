(import-macros {: do-req : let-req : plugin : key} :./lib/init-macros)
(local {: v/autocmd} (require :lib/nvim))

(local js-ts-filetypes [:javascript
                        :javascriptreact
                        :javascript.jsx
                        :typescript
                        :typescriptreact
                        :typescript.tsx])

[(plugin
   :pmizio/typescript-tools.nvim
   {:dependencies [:nvim-lua/plenary.nvim :neovim/nvim-lspconfig]
    :lazy true
    :init #(v/autocmd :FileType
                      {:pattern js-ts-filetypes
                       :once true
                       :callback (fn [ev]
                                   (vim.api.nvim_buf_call ev.buf
                                                          #(do-req :lazy
                                                                   :load
                                                                   {:plugins [:typescript-tools.nvim]})))})
    :opts {}})
 (plugin
   :folke/ts-comments.nvim
   {:opts {} :event :VeryLazy})]
