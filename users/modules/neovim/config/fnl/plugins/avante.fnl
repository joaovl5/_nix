(local {: now : add : later}
       {:now MiniDeps.now :add MiniDeps.add :later MiniDeps.later})

(import-macros {: do-req : let-req} :./lib/init-macros)

(later (fn []
         (add {:source :yetone/avante.nvim
               :monitor :main
               :depends [:nvim-lua/plenary.nvim
                         :MunifTanjim/nui.nvim
                         :echasnovski/mini.icons
                         :HakonHarnes/img-clip.nvim]
               :hooks {:post_checkout (fn [] (vim.cmd :make))}})
         (do-req :img-clip :setup)
         (do-req :avante :setup
                 {:provider :openai
                  :providers {:claude {:model :claude-sonnet-4-5-20250929}
                              :openai {:model :gpt-5.1}}
                  :behavior {}
                  :selector {:provider :telescope :provider_opts {}}})))
