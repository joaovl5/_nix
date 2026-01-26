(import-macros {: do-req : let-req : plugin : key} :./lib/init-macros)

(plugin :nvim-mini/mini.diff {:version "*" :opts {:options {:wrap_goto true}}})
