(import-macros {: do-req : let-req : plugin : key} :./lib/init-macros)

(fn opt-req [m]
  (let [(ok mod) (pcall require m)]
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

[(plugin :beauwilliams/statusline.lua
         {:dependencies [:nvim-lua/lsp-status.nvim]
          :opts {:match_colorscheme true
                 :tabline true
                 :lsp_diagnostics true
                 :ale_diagnostics true}})
 (plugin :b0o/incline.nvim
         {:opts {:window {:padding 0 :margin {:horizontal 1 :vertical 0}}
                 :render incline-render}})]
