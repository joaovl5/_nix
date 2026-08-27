(import-macros {: do-req : let-req : plugin : p! : key}
               :./lib/init-macros)

(local devdocs (require :plugins.editor._devdocs))

; type annotations generator
[(p! :danymat/neogen
     (cmd :Neogen)
     (keys
       (bind (c :l) #(do-req :neogen :jump_next) (m :i))
       (bind (c :h) #(do-req :neogen :jump_prev) (m :i))
       (group
         :code
         (bind :g (cmd :Neogen) (desc "Neogen"))))
     (opts {:enabled true
            :languages
            {:python {:template
                      {:annotation_convention :google_docstrings}}}}))
 (p! :nitaicharan/devdocs.nvim
     (deps [:nvim-lua/plenary.nvim
            :folke/snacks.nvim
            :xieyonn/spinner.nvim])
     (keys
       (bind :J
             #(devdocs.cursor_lookup)
             (desc "Devdocs (Cursor)"))
       (bind :J
             #(devdocs.selection_lookup)
             (desc "Devdocs (Selection)")
             (m :x))
       (group
         :fuzzy
         (bind :E
               #(devdocs.ui_call :show)
               (desc "Devdocs (Browse)")))
       (group
         :code
         (bind :i
               #(devdocs.install_for_filetype)
               (desc "Devdocs Install (Filetype)"))
         (bind :I
               #(devdocs.install_browse)
               (desc "Devdocs Install (Browse)"))
         (bind :A
               #(devdocs.install_all)
               (desc "Devdocs Install (All)"))))
     (opts {}))
 ; pretty hover
 (p! :Fildo7525/pretty_hover
     (event :LspAttach)
     (keys
       (bind :K #(do-req :pretty_hover :hover) (desc :Hover)))
     (opts {:border :none
            :wrap true
            :multi_server true
            :max_width nil
            :max_height nil}))
 ; code actions
 (p! :rachartier/tiny-code-action.nvim
     (deps [:nvim-lua/plenary.nvim])
     (event :LspAttach)
     (keys
       (group :code
              (bind :a
                    #(do-req :tiny-code-action :code_action)
                    (desc "Actions"))))
     (opts {:backend :delta
            :picker :snacks
            :resolve_timeout 100
            :notify {:enabled true :on_empty true}
            :backend_opts {:delta {:header_lines_to_remove 4
                                   :args [:--line-numbers]}}}))
 ; trouble - see todo/errors/etc
 (p! :folke/trouble.nvim
     (event :VeryLazy)
     (deps [(plugin :folke/todo-comments.nvim
                    {:cmd :TodoTrouble :opts {}})])
     (opts {})
     (keys (group :diagnostics
                  (bind :x
                        (cmd "Trouble diagnostics toggle")
                        (desc "Trouble"))
                  (bind :X
                        (cmd "Trouble diagnostics toggle filter.buf=0")
                        (desc "Trouble (Buffer)"))
                  (bind :t
                        (cmd "TodoTrouble")
                        (desc "TODOs"))
                  (bind :l
                        (cmd "Trouble loclist toggle")
                        (desc "Locations"))
                  (bind :q
                        (cmd "Trouble qflist toggle")
                        (desc "Quick fixes")))))
 ; interactive search+replace
 (plugin :MagicDuck/grug-far.nvim {:cmd :GrugFar :opts {}})]
