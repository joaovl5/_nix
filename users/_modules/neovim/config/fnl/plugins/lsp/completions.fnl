(import-macros {: do-req : let-req : plugin : key} :./lib/init-macros)

(local n (require :lib/nvim))

[(plugin :ms-jpq/coq_nvim
         {:lazy false
          :branch :coq
          :build :COQdeps
          :init (fn []
                  (vim.api.nvim_set_keymap :i :<Esc>
                                           "pumvisible() ? \"\\<C-e><Esc>\" : \"\\<Esc>\""
                                           {:expr true :silent true})
                  (vim.api.nvim_set_keymap :i :<C-c>
                                           "pumvisible() ? \"\\<C-e><C-c>\" : \"\\<C-c>\""
                                           {:expr true :silent true})
                  (vim.api.nvim_set_keymap :i :<BS>
                                           "pumvisible() ? \"\\<C-e><BS>\" : \"\\<BS>\""
                                           {:expr true :silent true})
                  (vim.api.nvim_set_keymap :i :<Tab>
                                           "pumvisible() ? (complete_info().selected == -1 ? \"\\<C-n>\" : \"\\<C-y>\") : \"\\<Tab>\""
                                           {:expr true :silent true})
                  (vim.api.nvim_set_keymap :i :<A-j>
                                           "pumvisible() ? \"\\<C-n>\" : \"\\<A-j>\""
                                           {:expr true :silent true})
                  (vim.api.nvim_set_keymap :i :<A-k>
                                           "pumvisible() ? \"\\<C-p>\" : \"\\<A-k>\""
                                           {:expr true :silent true})
                  (set vim.g.coq_settings
                       {:auto_start :shut-up
                        :keymap.recommended false
                        :keymap.bigger_preview nil
                        :keymap.jump_to_mark nil
                        :keymap.pre_select true
                        :completion.always true
                        :display.preview.border :solid}))})]
