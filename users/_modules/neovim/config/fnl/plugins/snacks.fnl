(import-macros {: do-req : let-req : plugin : key} :./lib/init-macros)

(fn k [rhs]
  {1 rhs :mode [:i :n]})

(local keyset {:/ :toggle_focus
               :<A-j> (k :list_down)
               :<A-k> (k :list_up)
               :<CR> (k :confirm)
               :<C-h> (k :history_back)
               :<C-l> (k :history_forward)
               :<A-w> (k :cycle_win)
               :<A-a> (k :select_all)
               :<c-w>G (k :list_bottom)
               :<c-w>gg (k :list_top)
               :<c-w>h (k :layout_left)
               :<c-w>j (k :layout_bottom)
               :<c-w>k (k :layout_top)
               :<c-w>l (k :layout_right)})

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
                ; terminal
                :terminal {}
                ; picker
                :picker {:prompt "> "
                         :show_delay 1000
                         :layout {:preset :vscode
                                  :layout {:width 0.7 :row 10 :border :none}}
                         :sources {:files {:exclude [:*.lua]}}
                         :matcher {:fuzzy true
                                   :smartcase true
                                   :cwd_bonus true
                                   :frecency true
                                   :history_bonus true}
                         :ui_select :true
                         :win {:input {:keys keyset}
                               :list {:keys keyset}
                               :preview {:keys keyset}}
                         :previewers {:diff {:style :fancy
                                             :cmd [:delta]
                                             :wo {:breakindent true
                                                  :wrap true
                                                  :linebreak true
                                                  :showbreak ""}}}}
                ; ui-related
                :dashboard {:preset {:header _G.header}
                            :sections [{:section :header}
                                       {:section :keys :gap 1 :padding 1}
                                       {:section :startup}]}
                :styles {:input {:border false}
                         :scratch {:border false}
                         :split {:position :bottom :height 25 :border false}
                         :float {:border true :width 0.99 :height 0.99}}
                :input {:enabled true}
                :image {:enabled true}}})
