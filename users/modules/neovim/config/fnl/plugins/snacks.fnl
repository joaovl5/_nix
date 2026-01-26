(import-macros {: do-req : let-req : plugin : key} :./lib/init-macros)

(plugin :folke/snacks.nvim
        {:opts {; optimize big file views
                :bigfile {:enabled true}
                ; loads files faster
                :quickfile {:enabled true}
                ; notifications
                :notify {:enabled true}
                :notifier {:enabled true
                           :width {:min 50 :max 0.4}
                           :height {:min 1 :max 0.6}
                           :margin {:top 2 :right 1 :bottom 0}
                           :padding true
                           :gap 0
                           :sort [:level :added]
                           :level vim.log.levels.TRACE
                           :icons {:error " "
                                   :warn " "
                                   :info " "
                                   :debug " "
                                   :trace " "}
                           :keep (fn [_]
                                   (> (vim.fn.getcmdpos) 0))
                           :style :minimal
                           :top_down true
                           :date_format "%R"
                           :more_format " ↓ %d lines "
                           :refresh 50}
                ; ui-related
                :input {:enabled true}
                :image {:enabled true}}})
