(import-macros {: do-req : let-req : plugin : key} :./lib/init-macros)

(let [filetypes [:markdown :quarto :rmd :typst :Avante]]
  (plugin :OXY2DEV/markview.nvim
          {:ft filetypes :opts {:preview {: filetypes :icon_provider :mini}}}))
