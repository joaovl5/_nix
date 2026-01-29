(import-macros {: do-req : let-req : plugin : key} :./lib/init-macros)

(local n (require :lib/nvim))

(local languages [:lua
                  :vimdoc
                  :markdown
                  ; :python
                  :javascript
                  :jsx
                  :typescript
                  :tsx
                  :html
                  :css
                  :scss])

(fn isnt_lang_installed [lang]
  (= (length (vim.api.nvim_get_runtime_file (.. :parser/ lang ".*") false)) 0))

[(plugin :nvim-treesitter/nvim-treesitter
         {:lazy false
          :branch :main
          :build ":TSUpdate"
          ; :dependencies [(plugin :nvim-treesitter/nvim-treesitter-textobjects
          ;                        {:branch :main})]
          :config (fn []
                    (let [ts (require :nvim-treesitter)
                          should_install false
                          to_install (vim.tbl_filter isnt_lang_installed
                                                     languages)]
                      (when (and (> (length to_install) 0) false)
                        (ts.install to_install)))
                    (let [filetypes (accumulate [res [] _ lang (ipairs languages)]
                                      (vim.list_extend res
                                                       (vim.treesitter.language.get_filetypes lang)))]
                      (n.autocmd :FileType
                                 {:pattern filetypes
                                  :callback (fn [ev]
                                              (vim.treesitter.start ev.buf))})))})]
