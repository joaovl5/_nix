(import-macros {: do-req : let-req : plugin : key} :./lib/init-macros)

(plugin :akinsho/toggleterm.nvim
        {:opts {:float_opts {:border :none :width 0.9 :height 0.9}}})
