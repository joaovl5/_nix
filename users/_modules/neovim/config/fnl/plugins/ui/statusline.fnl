(import-macros {: do-req : let-req : plugin : key} :./lib/init-macros)

(fn opt-req [m]
  (let [(ok _) (pcall require m)]
    ok))

(fn incline-render [props]
  (let [filename (vim.fn.fnamemodify (vim.api.nvim_buf_get_name props.buf) ":t")
        (ft_icon ft_color) (if (opt-req :nvim-web-devicons)
                               (do-req :nvim-web-devicons :get_icon_color
                                       filename)
                               [nil nil])
        modified (. vim.bo props.buf :modified)
        helpers (require :incline.helpers)
        icon (if (not= ft_icon nil)
                 {1 " "
                  2 ft_icon
                  3 " "
                  :guibg ft_color
                  :guifg (if (not= ft_color nil)
                             (helpers.contrast_color ft_color)
                             "#FF0000")}
                 [])]
    (if (= filename "")
        ["-/-"]
        [icon " " " " {1 filename :gui (if modified "bold,italic" :bold)}])))

[; status bar
 (plugin :windwp/windline.nvim
         {:config (fn []
                    (require :wlsample.evil_line))
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
                          :buf_name {:mode :shorten}}}})
 ; window/buffer bar thing
 (plugin :b0o/incline.nvim
         {:opts {:window {:padding 0 :margin {:horizontal 1 :vertical 0}}
                 :render incline-render}})]
