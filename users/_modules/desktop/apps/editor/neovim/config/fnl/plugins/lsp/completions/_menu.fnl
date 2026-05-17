(fn [comp_icon comp_kind comp_label]
  {:border :none
   :min_width 30
   :scrolloff 4
   :direction_priority [:s :n]
   :auto_show true
   :auto_show_delay_ms 5
   :draw {:padding 1
          :gap 1
          :components {:label comp_label
                       :kind_icon comp_icon
                       :kind comp_kind}
          :columns [{1 :kind_icon
                     2 :kind
                     :gap 1}
                    {1 :label :gap 1}]}})
