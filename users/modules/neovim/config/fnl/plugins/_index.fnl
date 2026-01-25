(local plugins [:snacks
                :mini.basics
                :mini.bufremove
                :mini.icons
                :mini.misc
                :mini.extra
                :mini.hipatterns
                :mini.files
                :mini.ai
                :mini.git
                :mini.map
                :mini.pairs
                :mini.pick
                :mini.trailspace
                :telescope
                :indent
                :treesitter
                :lsp.index
                :editor.index
                :ui.index
                :whichkey
                :themes
                :themery
                :terminal
                :avante
                :store
                :remote
                :notes])

(each [_ plugin (ipairs plugins)]
  (require (.. :plugins. plugin)))
