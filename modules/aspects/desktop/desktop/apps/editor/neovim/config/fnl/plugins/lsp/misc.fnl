(import-macros {: do-req : let-req : plugin : p! : key} :./lib/init-macros)

(local {: v/autocmd} (require :lib/nvim))

(fn clear-unmatched-highlight []
  (vim.api.nvim_set_hl 0 :BlinkPairsUnmatched {}))

[; stuff
 ; (p!
 ;   :zeioth/garbage-day.nvim
 ;   (event :VeryLazy)
 ;   (opts {:wakeup_delay 500
 ;          :grace_period (* 60 10)}))
 {:dir _G.plugin_dirs.blink-pairs
  :name :blink.pairs
  :event :VeryLazy
  :config (fn [_ opts]
            ((. (require :blink.pairs) :setup) opts)
            (clear-unmatched-highlight)
            (v/autocmd :ColorScheme {:callback clear-unmatched-highlight}))
  :opts {:mappings {:enabled true :cmdline true}
         :highlights {:enabled true
                      :cmdline true
                      :matchparen {:enabled true
                                   :cmdline true
                                   :include_surrounding false}}}}]
