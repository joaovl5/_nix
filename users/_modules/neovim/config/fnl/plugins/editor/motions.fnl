(import-macros {: do-req : let-req : plugin : key} :./lib/init-macros)

[; relative line nums will only include digits 1 throught 5 for comfort)
 (plugin :mluders/comfy-line-numbers.nvim {:opts true})
 ; leap motions
 (plugin "https://codeberg.org/andyg/leap.nvim"
         {:dependencies [:tpope/vim-repeat]
          :config (fn []
                    (let [leap (require :leap)
                          leap_user (require :leap.user)]
                      (set leap.opts.preview
                           ; preview filter, reduce visual noise
                           (fn [ch0 ch1 ch2]
                             (not (or (ch1:match "%s")
                                      (and (ch0:match "%a") (ch1:match "%a")
                                           (ch2:match "%a"))))))
                      (set leap.opts.equivalence_classes
                           [" \t\r\n" "([{" ")]}" "'\"`"])
                      (leap_user.set_repeat_keys :<enter> :<backspace>)))})
 ; spider (improved w,e,b motions)
 (plugin :chrisgrieser/nvim-spider {:opts true})
 ; improved insert mode exp
 (plugin :sontungexpt/bim.nvim {:opts true})]
