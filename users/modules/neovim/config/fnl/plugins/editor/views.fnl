(local {: now : add : later}
       {:now MiniDeps.now :add MiniDeps.add :later MiniDeps.later})

(import-macros {: do-req : let-req} :./lib/init-macros)

; glance (peek references etc)
(add :dnlhc/glance.nvim)

; navbuddy
(add {:source :SmiteshP/nvim-navbuddy
      :depends [:SmiteshP/nvim-navic
                :MunifTanjim/nui.nvim
                :numToStr/Comment.nvim]})

(do-req :nvim-navbuddy :setup
        {:window {:border :rounded :size "60%"} :lsp {:auto_attach true}})
