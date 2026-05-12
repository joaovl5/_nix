(import-macros {: do-req : let-req : plugin : key} :./lib/init-macros)

(local n (require :lib/nvim))

(vim.filetype.add {:extension {:kbd :kanata}})

(local languages [:lua
                  :vimdoc
                  :markdown
                  :python
                  :javascript
                  :jsx
                  :typescript
                  :tsx
                  :fennel
                  :kanata
                  :html
                  :css
                  :scss])

(let [ts (require :nvim-treesitter.config)]
  (ts.setup {:auto_install false}))

(vim.treesitter.language.register :kanata :kanata)

(let [filetypes (accumulate [res [] _ lang (ipairs languages)]
                  (vim.list_extend res
                                   (vim.treesitter.language.get_filetypes lang)))]
  (n.autocmd :FileType
             {:pattern filetypes
              :callback (fn [ev]
                          (vim.treesitter.start ev.buf))}))

[]
