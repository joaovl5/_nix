(import-macros {: do-req : let-req : plugin : key} :./lib/init-macros)
(local n (require :lib/nvim))

(plugin :nvim-mini/mini.files
        {:version "*"
         :opts {:windows {:preview true
                          :width_focus 40
                          :width_nofocus 30
                          :max_number 3}}
         :mappings _G.MiniFilesMappings
         ; autocmd for window customization
         :init #(n.autocmd :User
                           {:pattern :MiniFilesWindowOpen
                            :callback (fn [args]
                                        (let [win_id args.data.win_id
                                              config (vim.api.nvim_win_get_config win_id)]
                                          (set config.border :solid)
                                          (set config.title_pos :center)
                                          (vim.api.nvim_win_set_config win_id
                                                                       config)))})})
