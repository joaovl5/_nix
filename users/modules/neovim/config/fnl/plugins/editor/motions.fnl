(local {: now : add : later}
       {:now MiniDeps.now :add MiniDeps.add :later MiniDeps.later})

(import-macros {: do-req : let-req} :./lib/init-macros)

; relative line nums will only include digits 1 throught 5 for comfort)
(add :mluders/comfy-line-numbers.nvim)
(do-req :comfy-line-numbers :setup {})

; leap motions
(add {:source :ggandor/leap.nvim :depends [:tpope/vim-repeat]})
(let [leap (require :leap)
      leap_user (require :leap.user)]
  (set leap.opts.preview ; preview filter, reduce visual noise
       (fn [ch0 ch1 ch2]
         (not (or (ch1:match "%s")
                  (and (ch0:match "%a") (ch1:match "%a") (ch2:match "%a"))))))
  (set leap.opts.equivalence_classes [" \t\r\n" "([{" ")]}" "'\"`"])
  (leap_user.set_repeat_keys :<enter> :<backspace>))

; spider (improved w,e,b motions)
(add :chrisgrieser/nvim-spider)
(do-req :spider :setup {})

; improved insert mode exp
(add :sontungexpt/bim.nvim)
(do-req :bim :setup {})

; smart backspace stuff
(add :qwavies/smart-backspace.nvim)
(do-req :smart-backspace :setup {:enabled true :silent true})
