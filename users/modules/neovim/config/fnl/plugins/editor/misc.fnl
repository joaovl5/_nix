(import-macros {: do-req : let-req : plugin : key} :./lib/init-macros)

[; autosaves
 (plugin :okuuva/auto-save.nvim
         {:version "*"
          :event :VeryLazy
          :opts {:trigger_events {}}
          :keys [(key "\\a" :<cmd>ASToggle<cr> {:desc "Toggle autosave"})]})]
