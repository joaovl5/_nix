(local {: now : add : later} MiniDeps)

(import-macros {: do-req : let-req} :./lib/init-macros)

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

(fn isnt_lang_installed [lang]
  (= (length (vim.api.nvim_get_runtime_file (.. :parser/ lang ".*") false)) 0))

(fn ts_update []
  (vim.notify "Updating treesitter" vim.log.levels.INFO)
  (vim.cmd :TSUpdate)
  (vim.notify "Updated treesitter" vim.log.levels.INFO))

(later (fn []
         (add {:source :nvim-treesitter/nvim-treesitter
               :checkout :main
               :hooks {:post_checkout ts_update}})
         (add {:source :nvim-treesitter/nvim-treesitter-textobjects
               :checkout :main})
         (let [ts (require :nvim-treesitter)
               to_install (vim.tbl_filter isnt_lang_installed languages)]
           ; (when (> (length to_install) 0) ;   (ts.install to_install))
           (local filetypes
                  (accumulate [res [] _ lang (ipairs languages)]
                    (vim.list_extend res
                                     (vim.treesitter.language.get_filetypes lang)))))))

; (n.autocmd :FileType
;            {:pattern filetypes
;             :callback (fn [ev]
;                         (vim.treesitter.start ev.buf))}))))
