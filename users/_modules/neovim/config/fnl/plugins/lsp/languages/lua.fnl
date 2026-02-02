(import-macros {: do-req : let-req : plugin : key} :./lib/init-macros)

[(plugin :folke/lazydev.nvim
         {:ft :lua
          :opts {:library {:path "${3rd}/luv/library" :words ["vim%.uv"]}}})]
