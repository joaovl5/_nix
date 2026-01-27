(import-macros {: do-req : let-req : plugin : key} :./lib/init-macros)

(plugin :rasulomaroff/reactive.nvim
        {:builtin {:cursorline true :cursor true :modemsg true}})
