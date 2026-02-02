(import-macros {: do-req : let-req : plugin : key} :./lib/init-macros)

(plugin :nvim-mini/mini.bufremove {:version "*" :opts {:silent true}})
