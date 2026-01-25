(local {: now : add : later}
       {:now MiniDeps.now :add MiniDeps.add :later MiniDeps.later})

(import-macros {: do-req : let-req} :./lib/init-macros)

; type annotations generator
(add :danymat/neogen)
(do-req :neogen :setup
        {:enabled true
         :languages {:python {:template {:annotation_convention :google_docstrings}}}})

; pretty hover 
(add :Fildo7525/pretty_hover)
(do-req :pretty_hover :setup {:border :single
                              :wrap true
                              :multi_server true
                              :max_width nil
                              :max_height nil})

; tiny code actions
(add {:source :rachartier/tiny-code-action.nvim
      :depends [:nvim-lua/plenary.nvim]})

(do-req :tiny-code-action :setup
        {:backend :delta
         :picker :telescope
         :resolve_timeout 100
         :notify {:enabled true :on_empty true}
         :backend_opts {:header_lines_to_remove 4 :args [:--line-numbers]}})
