(import-macros {: do-req : let-req : plugin : key} :./lib/init-macros)

[; git
 (plugin :lewis6991/gitsigns.nvim
         {:opts {}
          :event :VeryLazy
          :keys [(key :<leader>gb "<cmd>Gitsigns blame_line<cr>"
                      {:desc "Blame (line)"})
                 (key :<leader>gB "<cmd>Gitsigns blame<cr>"
                      {:desc "Blame (all)"})]})]
