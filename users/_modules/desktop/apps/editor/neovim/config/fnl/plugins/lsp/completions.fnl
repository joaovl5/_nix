(import-macros {: do-req : let-req : plugin : key} :./lib/init-macros)

(fn setup_blink []
  (let [blink (require :blink.cmp)
        colorful_menu (require :colorful-menu)
        mini_icons (require :mini.icons)
        _icon_data (fn [ctx]
                     (mini_icons.get :lsp ctx.kind))
        _icon_hl (fn [ctx]
                   (let [[_ hl _] (_icon_data ctx)]
                     (or hl ctx.kind_hl)))
        _icon (fn [ctx]
                (let [[icon _ _] (_icon_data ctx)]
                  (.. (or icon ctx.kind_icon) ctx.icon_gap)))
        _cm_text (fn [ctx] (colorful_menu.blink_components_text ctx))
        _cm_hl (fn [ctx] (colorful_menu.blink_components_highlight ctx))
        comp_icon {:text _icon :highlight _icon_hl}
        comp_kind {:highlight _icon_hl}
        comp_label {:text _cm_text :highlight _cm_hl}]
    (blink.setup {:keymap {:preset :none
                           :<Tab> [(fn [cmp]
                                     (if (cmp.snippet_active)
                                         (cmp.accept)
                                         (cmp.select_and_accept)))
                                   :snippet_forward
                                   :fallback]
                           :<S-Tab> [:snippet_backward :fallback]
                           :<A-j> [:select_next]
                           :<A-k> [:select_prev]
                           :<C-d> [:scroll_documentation_down]
                           :<C-u> [:scroll_documentation_up]
                           :<C-k> [:show_signature :hide_signature]}
                  :appearance {:nerd_font_variant :mono}
                  :completion {:ghost_text {:enabled true}
                               :keyword {:range :full}
                               :accept {:auto_brackets {:enabled false}}
                               :list {:selection {:preselect true}}
                               :documentation {:auto_show true
                                               :auto_show_delay_ms 0
                                               :window {:border :none
                                                        :direction_priority {:menu_south [:e
                                                                                          :w
                                                                                          :s]
                                                                             :menu_north [:e
                                                                                          :w
                                                                                          :n]}}}
                               :menu {:border :none
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
                                                       {1 :label :gap 1}]}}}
                  :sources (let [sources [:lsp :path :snippets :buffer]
                                 debug_sources [:dap
                                                :lsp
                                                :path
                                                :snippets
                                                :buffer]]
                             {:default sources
                              :per_filetype {:dap-repl debug_sources
                                             :dap-view debug_sources}
                              :providers {:dap {:name :dap
                                                :module :blink.compat.sources
                                                :enabled (fn []
                                                           (do-req :cmp_dap
                                                                   :is_dap_buffer))}}})
                  :signature {:enabled true
                              :trigger {:show_on_keyword true
                                        :show_on_insert true}
                              :window {:min_width 1
                                       :max_width 200
                                       :max_height 30
                                       :border :none}}
                  :cmdline {:keymap {:preset :inherit}
                            :completion {:menu {:auto_show true}}}
                  :fuzzy {;; prioritize exact matches
                          :sorts [:exact :score :sort_text]
                          ;; prefer rust impl
                          :implementation :prefer_rust_with_warning}})))

[{:dir _G.plugin_dirs.blink-cmp
  :event :InsertEnter
  :config setup_blink
  :dependencies [(plugin :saghen/blink.compat {:lazy true})]}]
