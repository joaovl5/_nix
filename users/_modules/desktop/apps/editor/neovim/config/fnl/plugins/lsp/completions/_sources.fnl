(import-macros {: do-req} :./lib/init-macros)

(fn transform_items_base [k_icon k_name _ctx items]
  (each [_ item (ipairs items)]
    (set item.kind_icon k_icon)
    (set item.kind_name k_name))
  items)

(fn transform_items [k_icon k_name]
  (partial transform_items_base k_icon k_name))

(let [sources [:conv_commit
               :lsp
               :path
               :snippets
               :buffer
               :env
               :git
               :grep]
      debug_sources (let [result [:dap]]
                      (each [_ source (ipairs sources)]
                        (table.insert result source))
                      result)]
  {:default sources
   :per_filetype {:dap-repl debug_sources
                  :dap-view debug_sources}
   :providers
   {:dap {:name :dap
          :module :blink.compat.sources
          :enabled (fn []
                     (do-req :cmp_dap
                             :is_dap_buffer))}
    :grep {:name :Grep
           :module :blink-ripgrep
           :transform_items (transform_items " " :Grep)
           :opts {:prefix_min_len 4
                  :backend {:use :gitgrep-or-ripgrep}}}
    :env {:name "Env Vars"
          :module :blink-cmp-env
          :transform_items (transform_items "󰹻 " :Env)
          :opts {:item_kind (let [btypes (require :blink.cmp.types)]
                              btypes.CompletionItemKind.Variable)
                 :show_braces false
                 :show_documentation_window false}}
    :git {:module :blink-cmp-git
          :name :Git
          :transform_items (transform_items "󰊢 " :Git)
          :opts {}}
    :conv_commit {:name "Conventional Commits"
                  :module :blink-cmp-conventional-commits
                  :enabled (fn []
                             (= vim.bo.filetype :gitcommit))
                  :opts {}}}})
