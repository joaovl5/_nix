(import-macros {: do-req : let-req : plugin : p! : key} :./lib/init-macros)
(local {: v/$} (require :lib/nvim))


(fn treewalker [subcommand]
  (let [(ok err) (pcall v/$ (.. "Treewalker " subcommand))]
    (when (not ok)
      (if (and (= :string (type err))
               (string.find err
                            "Treewalker: Treesitter node not found under cursor"
                            1
                            true))
          (vim.notify "Treewalker: no Treesitter node under cursor"
                      vim.log.levels.WARN)
          (error err)))))


[; relative line nums will only include digits 1 throught 5 for comfort)
 (plugin :mluders/comfy-line-numbers.nvim {:opts true :event :BufEnter})
 ; flash
 (p! :folke/flash.nvim
     (event :BufEnter)
     (keys
      (bind :s
            (fn [] (do-req :flash :jump))
            (m :n :x :o))
      (bind :S
            (fn [] (do-req :flash :treesitter))
            (m :n :x :o))
      (bind :r
            (fn [] (do-req :flash :remote))
            (m :o)
            (desc "Remote flash")))
     (opts
       (let [keys :fhdjskalgrueiwoqptvnmb]
         {:labels keys
          :search {:multi_window false
                   :forward true
                   :wrap true
                   :mode :fuzzy}
          :jump {:nohlsearch true :autojump true}
          :label {:uppercase false :distance true}
          :highlight {:backdrop true}
          :modes {:treesitter {:labels keys
                               :highlight {:backdrop true
                                           :matches false}}}})))
 ; spider (improved w,e,b motions)
 (p! :chrisgrieser/nvim-spider
     (keys
      (bind :w
            (fn [] (do-req :spider :motion :w))
            (m :n :x :o))
      (bind :e
            (fn [] (do-req :spider :motion :e))
            (m :n :x :o))
      (bind :b
            (fn [] (do-req :spider :motion :b))
            (m :n :x :o)))
     (opts true))
 ; monkey-like crazyness
 (p! :aaronik/treewalker.nvim
     (cmd :Treewalker)
     (keys
      (bind "<A-[>" (fn [] (treewalker :Left)) (m :n :x))
      (bind "<A-]>" (fn [] (treewalker :Right)) (m :n :x))
      (bind :<A-k> (fn [] (treewalker :Up)) (m :n :x))
      (bind :<A-j> (fn [] (treewalker :Down)) (m :n :x))
      (bind "<A-S-[>" (fn [] (treewalker :SwapLeft)) (m :n :x))
      (bind "<A-S-]>" (fn [] (treewalker :SwapRight)) (m :n :x))
      (bind :<A-K> (fn [] (treewalker :SwapUp)) (m :n :x))
      (bind :<A-J> (fn [] (treewalker :SwapDown)) (m :n :x)))
     (opts {}))]
