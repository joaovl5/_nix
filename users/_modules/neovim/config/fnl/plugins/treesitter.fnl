(import-macros {: do-req : let-req : plugin : key} :./lib/init-macros)

(local n (require :lib/nvim))

(local languages [:lua
                  :vimdoc
                  :markdown
                  :python
                  :javascript
                  :jsx
                  :typescript
                  :tsx
                  :html
                  :css
                  :scss])

[(plugin :nvim-treesitter/nvim-treesitter
         {:lazy false
          :branch :main
          :build ":TSUpdate"
          :config (fn []
                    (let [ts (require :nvim-treesitter)]
                      (ts.setup {})
                      (ts.install languages))
                    (let [filetypes (accumulate [res [] _ lang (ipairs languages)]
                                      (vim.list_extend res
                                                       (vim.treesitter.language.get_filetypes lang)))]
                      (n.autocmd :FileType
                                 {:pattern filetypes
                                  :callback (fn [ev]
                                              (vim.treesitter.start ev.buf))})))})]
