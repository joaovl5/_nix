(import-macros {: do-req : let-req : plugin : key} :./lib/init-macros)

[{:dir _G.plugin_dirs.blink-pairs
  :name :blink.pairs
  :event :VeryLazy
  :opts {:mappings {:enabled true :cmdline true}
         :highlights {:enabled true
                      :cmdline true
                      :matchparen {:enabled true
                                   :cmdline true
                                   :include_surrounding false}}}}]
