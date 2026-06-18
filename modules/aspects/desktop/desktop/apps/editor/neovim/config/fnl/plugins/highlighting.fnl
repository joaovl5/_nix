(import-macros {: do-req : let-req : plugin : key} :./lib/init-macros)

(local {: v/autocmd : v/extend} (require :lib/nvim))

(vim.filetype.add {:extension {:kbd :kanata}})

(local languages [; keep-sorted start
                  :css
                  :dhall
                  :fennel
                  :html
                  :javascript
                  :jsx
                  :kanata
                  :lua
                  :markdown
                  :nix
                  :python
                  :rust
                  :scss
                  :tsx
                  :typescript
                  :vimdoc])

; keep-sorted end

(let [ts (require :nvim-treesitter.config)]
  (ts.setup {:auto_install false}))

(vim.treesitter.language.register :kanata :kanata)

(let [filetypes (accumulate [res [] _ lang (ipairs languages)]
                  (v/extend res
                            (vim.treesitter.language.get_filetypes lang)))]
  (v/autocmd :FileType
             {:pattern filetypes
              :callback (fn [ev]
                          (vim.treesitter.start ev.buf))}))

[(plugin :auipga/hmts.nvim {:branch :patch-1})
 (plugin :m-demare/hlargs.nvim {:event :VeryLazy :opts {}})]
