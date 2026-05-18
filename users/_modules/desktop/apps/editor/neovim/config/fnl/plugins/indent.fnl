(import-macros {: p! : plugin : key} :./lib/init-macros)

(p! :lukas-reineke/indent-blankline.nvim
    (main :ibl)
    (event :BufEnter)
    (opts (fn []
            (let [hk (require :ibl.hooks)
                  hl_setup hk.type.HIGHLIGHT_SETUP
                  set_hl #(vim.api.nvim_set_hl 0 $1 {:fg $2})
                  bg_hl :DimDim
                  hl :RainbowViolet]
              (hk.register hl_setup
                           (fn []
                             (set_hl :RainbowViolet "#AB94FC")
                             (set_hl :DimDim "#303030")))
              {:indent {:highlight bg_hl
                        :char "⋮"}
               :scope {:highlight hl
                       :char "⋮"
                       :show_exact_scope true}}))))
