(import-macros {: do-req : let-req : plugin : p! : key} :./lib/init-macros)

[; stuff
 ; (p!
 ;   :zeioth/garbage-day.nvim
 ;   (event :VeryLazy)
 ;   (opts {:wakeup_delay 500
 ;          :grace_period (* 60 10)}))
 {:dir _G.plugin_dirs.blink-pairs
  :name :blink.pairs
  :event :VeryLazy
  :opts {:mappings {:enabled true :cmdline true}
         :highlights {:enabled true
                      :cmdline true
                      :matchparen {:enabled true
                                   :cmdline true
                                   :include_surrounding false}}}}]
