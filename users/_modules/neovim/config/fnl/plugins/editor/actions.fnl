(import-macros {: do-req : let-req : plugin : key} :./lib/init-macros)

; type annotations generator
[(plugin :danymat/neogen
         {:cmd :Neogen
          :opts {:enabled true
                 :languages {:python {:template {:annotation_convention :google_docstrings}}}}})
 ; pretty hover
 (plugin :Fildo7525/pretty_hover
         {:event :LspAttach
          :opts {:border :none
                 :wrap true
                 :multi_server true
                 :max_width nil
                 :max_height nil}})
 ; git
 (plugin :lewis6991/gitsigns.nvim
         {:opts {}
          :keys [(key :<leader>gb "<cmd>Gitsigns blame_line<cr>"
                      {:desc "Blame (line)"})
                 (key :<leader>gB "<cmd>Gitsigns blame<cr>"
                      {:desc "Blame (all)"})]})
 ; 'dev' actions / provides actions for refactoring
 (plugin :yarospace/dev-tools.nvim
         {:dependencies [(plugin :ThePrimeagen/refactoring.nvim
                                 {:dependencies [:nvim-lua/plenary.nvim]})]
          :event :VeryLazy
          :opts {:ui {:override true :group_actions true}}})
 ; code actions
 (plugin :rachartier/tiny-code-action.nvim
         {:dependencies [:nvim-lua/plenary.nvim
                         (plugin :kosayoda/nvim-lightbulb
                                 {:opts {:autocmd {:enabled true}
                                         :ignore {:clients [:ruff :dev-tools]}}})]
          :event :LspAttach
          :opts {:backend :delta
                 :picker :snacks
                 :resolve_timeout 100
                 :notify {:enabled true :on_empty true}
                 :backend_opts {:header_lines_to_remove 4
                                :args [:--line-numbers]}}})
 ; trouble - see todo/errors/etc
 (plugin :folke/trouble.nvim
         {:cmd :Trouble
          :dependencies [(plugin :folke/todo-comments.nvim
                                 {:cmd :TodoTrouble :opts {}})]
          :opts {}
          :keys [(key :<leader>xx "<cmd>Trouble diagnostics toggle<cr>"
                      {:desc "Trouble (global)"})
                 (key :<leader>xX
                      "<cmd>Trouble diagnostics toggle filter.buf=0<cr>"
                      {:desc "Trouble (buffer)"})
                 (key :<leader>xt :<cmd>TodoTrouble<cr> {:desc :TODOs})
                 (key :<leader>xl "<cmd>Trouble loclist toggle<cr>"
                      {:desc "Trouble locations"})
                 (key :<leader>xl "<cmd>Trouble qflist toggle<cr>"
                      {:desc "Quick fixes"})]})
 ; interactive search+replace
 (plugin :MagicDuck/grug-far.nvim {:cmd :GrugFar :opts {}})]
