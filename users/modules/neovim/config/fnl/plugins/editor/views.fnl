(import-macros {: do-req : let-req : plugin : key} :./lib/init-macros)

[; glance (peek references etc)
 (plugin :dnlhc/glance.nvim)
 ; navbuddy
 (plugin :SmiteshP/nvim-navbuddy
         {:dependencies [:SmiteshP/nvim-navic
                         :MunifTanjim/nui.nvim
                         :numToStr/Comment.nvim]
          :opts {:window {:border :rounded :size "60%"}
                 :lsp {:auto_attach true}}})]
