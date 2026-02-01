(import-macros {: do-req : let-req : plugin : key} :./lib/init-macros)

; type annotations generator
[(plugin :danymat/neogen
         {:opts {:enabled true
                 :languages {:python {:template {:annotation_convention :google_docstrings}}}}})
 ; pretty hover
 (plugin :Fildo7525/pretty_hover
         {:opts {:border :single}
          :wrap true
          :multi_server true
          :max_width nil
          :max_height nil})
 ; tiny code actions
 (plugin :rachartier/tiny-code-action.nvim
         {:dependencies [:nvim-lua/plenary.nvim]
          :opts {:backend :delta
                 :picker :telescope
                 :resolve_timeout 100
                 :notify {:enabled true :on_empty true}
                 :backend_opts {:header_lines_to_remove 4
                                :args [:--line-numbers]}}})
 ; interactive search+replace
 (plugin :MagicDuck/grug-far.nvim {:opts {}})]
