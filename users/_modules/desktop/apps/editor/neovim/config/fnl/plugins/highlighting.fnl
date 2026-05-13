(import-macros {: do-req : let-req : plugin : key} :./lib/init-macros)

(local n (require :lib/nvim))

(vim.filetype.add {:extension {:kbd :kanata}})

; keep-sorted start
(local languages [:css
                  :fennel
                  :html
                  :javascript
                  :jsx
                  :kanata
                  :lua
                  :markdown
                  :python
                  :scss
                  :tsx
                  :typescript
                  :vimdoc])

; keep-sorted end

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

[(plugin :m-demare/hlargs.nvim {:event :VeryLazy :opts {}})]
