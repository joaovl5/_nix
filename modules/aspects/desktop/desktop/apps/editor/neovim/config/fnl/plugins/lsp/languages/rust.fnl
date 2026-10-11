(import-macros {: p!} :./lib/init-macros)

(set vim.g.rustaceanvim
     {:tools {:enable_clippy true}
      :server {:lspmux {:enable true}
               :default_settings
               {:rust-analyzer
                {:checkOnSave true
                 :imports {:prefix :self
                           :granularity {:group :module}}
                 :cargo {:targetDir true
                         :buildScripts {:enable true}}
                 :procMacro {:enable true}
                 :diagnostics {:experimental {:enable true}}}}}})

[(p!
   :mrcjkb/rustaceanvim
   (lazy false)
   (version :^9))
 (p!
   :Canop/nvim-bacon
   (opts {:quickfix {:enabled true :event_trigger true}}))]
