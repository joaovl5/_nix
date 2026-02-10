(import-macros {: do-req : let-req : plugin : key} :./lib/init-macros)
(local {: nil?} (require :./lib/utils))

(set _G.Config.themes [{:source :nyoom-engineering/oxocarbon.nvim
                        :names [:oxocarbon]}
                       {:source :mellow-theme/mellow.nvim
                        :names [:mellow]
                        :post_add #(set vim.g.mellow_italic_comments true)}
                       {:source :embark-theme/vim :names [:embark]}
                       {:source :eldritch-theme/eldritch.nvim
                        :names [:eldritch :eldritch-dark :eldritch-minimal]}
                       {:source :serhez/teide.nvim
                        :post_add (fn []
                                    (do-req :teide :setup
                                            {:style :darker
                                             :transparent true
                                             :dim_inactive true}))
                        :names [:teide-darker :teide-dark :teide-dimmed]}
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

(icollect [_ t (ipairs _G.Config.themes)]
  (plugin t.source {:lazy false
                    :config #(when (not (nil? t.post_add))
                               t.post_add)}))
