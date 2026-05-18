{:enabled true
 :width {:min 60 :max 0.4}
 :height {:min 2 :max 0.6}
 :margin {:top 1 :right 1 :bottom 0}
 :padding true
 :gap 1
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
