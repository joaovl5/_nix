(fn [comp_icon comp_kind]
  {:border :none
   :min_width 40
   :scrolloff 6
   :direction_priority [:s :n]
   :auto_show true
   :auto_show_delay_ms 0
   :draw {:padding 0
          :gap 1
          :components {:kind_icon comp_icon
                       :kind comp_kind}
          :columns [{1 :kind_icon
                     2 :kind
                     :gap 1}
                    {1 :label :gap 1}]}})
