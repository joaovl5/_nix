(local {: now : add : later}
       {:now MiniDeps.now :add MiniDeps.add :later MiniDeps.later})

(import-macros {: do-req : let-req} :./lib/init-macros)

(later (fn []
         (add :lukas-reineke/indent-blankline.nvim)
         (let [ibl (require :ibl)
               hk (require :ibl.hooks)
               hl_setup hk.type.HIGHLIGHT_SETUP
               set_hl vim.api.nvim_set_hl
               bg_hl :DimDim
               hl :RainbowViolet]
           (hk.register hl_setup
                        (fn []
                          (set_hl 0 :RainbowViolet {:fg "#AB94FC"})
                          (set_hl 0 :DimDim {:fg "#303030"})))
           (ibl.setup {:indent {:highlight bg_hl :char "⋮"}
                       :scope {:highlight hl
                               :char "⋮"
                               :show_exact_scope true}}))))
