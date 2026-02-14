(import-macros {: do-req : let-req : plugin : key} :./lib/init-macros)

[; relative line nums will only include digits 1 throught 5 for comfort)
 (plugin :mluders/comfy-line-numbers.nvim {:opts true})
 ; flash
 (plugin :folke/flash.nvim
         {:event :VeryLazy
          :opts {:labels :fhdjskalgrueiwoqptvnmb
                 :search {:multi_window false
                          :forward true
                          :wrap true
                          :mode :exact}
                 :jump {:nohlsearch true :autojump true}
                 :label {:uppercase false
                         :distance true
                         :rainbow {:enabled true :shade 5}}
                 :highlight {:backdrop true}
                 :modes {:treesitter {:labels :fhdjskalgrueiwoqptvnmb
                                      :highlight {:backdrop true
                                                  :matches false}}}}})
 ; spider (improved w,e,b motions)
 (plugin :chrisgrieser/nvim-spider {:opts true})
 ; monkey-like crazyness
 (plugin :aaronik/treewalker.nvim {:opts {}})
 ; improved insert mode exp
 (plugin :sontungexpt/bim.nvim {:opts true})]
