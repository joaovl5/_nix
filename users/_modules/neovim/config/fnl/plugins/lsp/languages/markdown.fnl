(import-macros {: do-req : let-req : plugin : key} :./lib/init-macros)

(let [filetypes [:markdown :codecompanion]]
  (plugin :OXY2DEV/markview.nvim
          {:lazy false
           :config (fn []
                     (let [presets (require :markview.presets)]
                       (do-req :markview :setup
                               {:markdown {:headings presets.headings.slanted
                                           :tables presets.tables.rounded}})
                       (do-req :markview :setup
                               {:preview {: filetypes
                                          :icon_provider :mini
                                          :ignore_buftypes []}
                                :markdown {:list_items {:wrap true
                                                        :shift_width 2
                                                        :marker_minus {:text "≕"
                                                                       :add_padding false
                                                                       :wrap true}}}})))}))
