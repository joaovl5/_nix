(local {: now : add : later}
       {:now MiniDeps.now :add MiniDeps.add :later MiniDeps.later})

(import-macros {: do-req : let-req} :./lib/init-macros)

(set _G.Config.themes [{:source :nyoom-engineering/oxocarbon.nvim
                        :names [:oxocarbon]}
                       {:source :mellow-theme/mellow.nvim
                        :names [:mellow]
                        :post_add #(set vim.g.mellow_italic_comments true)}
                       {:source :embark-theme/vim :names [:embark]}
                       {:source :eldritch-theme/eldritch.nvim
                        :names [:eldritch :eldritch-dark :eldritch-minimal]}
                       {:source :uhs-robert/oasis.nvim
                        :names [:oasis-midnight
                                :oasis-abyss
                                :oasis-starlight
                                :oasis-desert
                                :oasis-sol
                                :oasis-canyon
                                :oasis-dune
                                :oasis-cactus
                                :oasis-lagoon
                                :oasis-twilight
                                :oasis-rose]}])

(now (fn []
       (each [_ theme (ipairs _G.Config.themes)]
         (add theme.source)
         (when (not= theme.post_add nil)
           (theme.post_add)))))
