(import-macros {: do-req : let-req : plugin : key} :./lib/init-macros)

(plugin :nvim-mini/mini.pairs {:version "*" :opts {:modes {:command true}}})
