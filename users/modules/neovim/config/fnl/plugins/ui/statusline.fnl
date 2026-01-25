(local {: now : add : later}
       {:now MiniDeps.now :add MiniDeps.add :later MiniDeps.later})

(import-macros {: do-req : let-req} :./lib/init-macros)

(add {:source :beauwilliams/statusline.lua
      :depends [:nvim-lua/lsp-status.nvim]})

(do-req :statusline :setup {:match_colorscheme true
                            :tabline true
                            :lsp_diagnostics true
                            :ale_diagnostics false})

(fn opt-req [m]
  (let [(ok mod) (pcall require m)]
    ok))

(add :b0o/incline.nvim)
(do-req :incline :setup
        {:window {:padding 0 :margin {:horizontal 1 :vertical 0}}
         :render (fn [props]
                   (let [filename (vim.fn.fnamemodify (vim.api.nvim_buf_get_name props.buf)
                                                      ":t")
                         (ft_icon ft_color) (if (opt-req :nvim-web-devicons)
                                                (do-req :nvim-web-devicons
                                                        :get_icon_color filename)
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
                         [icon
                          " "
                          " "
                          {1 filename
                           :gui (if modified
                                    "bold,italic"
                                    "bold")}])))})

; (add :sschleemilch/slimline.nvim)
; (do-req :slimline :setup
;         {:style :fg
;          :bold true
;          :configs {:path {:hl {:primary :Label}}
;                    :git {:hl {:primary :Function}}
;                    :filetype_lsp {:hl {:primary :String}}}})
