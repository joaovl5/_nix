(import-macros {: do-req : let-req : plugin : key} :./lib/init-macros)

[(plugin :ms-jpq/coq_nvim
         {:lazy false
          :branch :coq
          :build :COQdeps
          :init (fn []
                  (set vim.g.coq_settings
                       {:auto_start :shut-up
                        :keymap.pre_select true
                        :display.preview.border :solid}))})]
