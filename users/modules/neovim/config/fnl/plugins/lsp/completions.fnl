(local {: now : add : later}
       {:now MiniDeps.now :add MiniDeps.add :later MiniDeps.later})

(import-macros {: do-req : let-req} :./lib/init-macros)

(fn build_blink [params]
  (vim.notify "Building Blink" vim.log.levels.INFO)
  (let [res (: (vim.system [:cargo :build :--release] {:cwd params.path}) :wait)]
    (if (= 0 res.code)
        (vim.notify "Building Blink done" vim.log.levels.INFO)
        (vim.notify "Building Blink failed" vim.log.levels.ERROR))))

; setup blink.cmp completions
(add {:source :saghen/blink.cmp
      :depends [:rafamadriz/friendly-snippets]
      :hooks {:post_install build_blink :post_checkout build_blink}})

; colorful completion menu
(add :xzbdmw/colorful-menu.nvim)
(do-req :colorful-menu :setup {})

; blink sources
(add :saghen/blink.compat)
(do-req :blink.compat :setup {})

(fn _get_mini_icon_data [ctx]
  (local [k_icon k_hl _] (do-req :mini.icons :get :lsp ctx.kind))
  [k_icon k_hl])

(fn get_mini_icon [ctx]
  (local [k_icon _] (_get_mini_icon_data ctx))
  k_icon)

(fn get_mini_icon_hl [ctx]
  (local [_ k_hl] (_get_mini_icon_data ctx))
  k_hl)

(local source_symbols {:lsp "📚" :path "📁" :snippets "✂️"})

(fn get_source_txt [ctx]
  (. source_symbols ctx.item.source_id))

(let [def_sources [:lazydev :lsp :path :calc :snippets :buffer]
      dbg_sources [:dap (unpack def_sources)]
      cf_menu (require :colorful-menu)
      cf_text cf_menu.blink_components_text
      cf_hl cf_menu.blink_components_highlight]
  (do-req :blink-cmp :setup
          {:keymap {:preset :super-tab}
           :signature {:enabled true :window {:border :none :scrollbar false}}
           :sources {:default def_sources
                     :per_filetype {:dap-repl dbg_sources
                                    :dap-view dbg_sources}
                     :providers {:lazydev {:module :lazydev.integrations.blink
                                           :score_offset 100}
                                 :calc {:name :calc
                                        :module :blink.compat.source}
                                 :dap {:name :dap
                                       :module :blink.compat.source
                                       :enabled #(do-req :cmp_dap
                                                         :is_dap_buffer)}}}
           :appearance {:kind_icons {:Snippet "✂️"}}
           :cmdline {:completion {:menu {:auto_show false}
                                  :ghost_text {:enabled true}
                                  :list {:selection {:preselect true
                                                     :auto_insert false}}}}
           :completion {:keyword {:range :prefix}
                        :list {:selection {:preselect true :auto_insert true}}
                        :accept {:auto_brackets {:enabled true}}
                        :menu {:min_width 20
                               :border :rounded
                               :winhighlight "Normal:Normal,FloatBorder:FloatBorder,CursorLine:BlinkCmpMenuSelection,Search:None"
                               :draw {:columns [[:kind_icon]
                                                [:label]
                                                [:source]]
                                      :components {:label {:text cf_text
                                                           :highlight cf_hl}
                                                   :kind_icon {:text get_mini_icon
                                                               :highlight get_mini_icon_hl}
                                                   :kind {:highlight get_mini_icon_hl}
                                                   :source {:text get_source_txt
                                                            :highlight :BlinkCmpDoc}}}}
                        :documentation {:auto_show true
                                        :auto_show_delay_ms 0
                                        :update_delay_ms 50
                                        :window {:max_width 200
                                                 :border :rounded}
                                        :draw (fn [opts]
                                                (when (and opts.item
                                                           opts.item.documentation
                                                           opts.item.documentation.value)
                                                  (let [parsed (do-req :pretty_hover.parser
                                                                       :parse
                                                                       opts.item.documentation.value)]
                                                    (set opts.item.documentation.value
                                                         (parsed:string))))
                                                (opts.default_implementation opts))}}}))
