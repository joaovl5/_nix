(import-macros {: do-req : let-req : plugin : key} :./lib/init-macros)

[; status bar
 (plugin :nvim-lualine/lualine.nvim
         {:config (fn []
                    (do-req :lualine :setup {}))
          :event :VeryLazy})
 ; tab bar
 (plugin :nanozuki/tabby.nvim
         {:event :VeryLazy
          :keys [(key :<leader>qr
                      (fn []
                        (vim.ui.input {:prompt "Enter name for tab: "}
                                      (fn [input]
                                        (when (not= nil input)
                                          (vim.cmd (.. "Tabby rename_tab "
                                                       input))))))
                      {:desc :Rename})
                 (key :<leader>qw "<cmd>Tabby pick_window<cr>"
                      {:desc "Pick window"})
                 (key :<leader>qq "<cmd>Tabby jump_to_tab<cr>"
                      {:desc "Jump mode"})]
          :opts {:preset :tab_only
                 :option {:theme {:fill :TabLineFill
                                  :head :TabLine
                                  :current_tab :TabLineSel
                                  :tab :TabLine
                                  :win :TabLine
                                  :tail :TabLine}
                          :nerdfont true
                          :lualine_theme nil
                          :tab_name {:tab_fallback (fn [tabid]
                                                     (tabid))}
                          :buf_name {:mode :shorten}}}})]
