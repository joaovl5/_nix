(import-macros {: do-req : let-req : plugin : key} :./lib/init-macros)

(plugin :linux-cultist/venv-selector.nvim
        {:dependencies [(plugin :nvim-telescope/telescope.nvim {:version "*"})]
         :ft :python
         :keys [(key :<leader>cv :<cmd>VenvSelect<cr>
                     {:desc "Pick virtual env"})]
         :opts {}})
