(import-macros {: p!} :./lib/init-macros)

(set vim.g.rustaceanvim
     {:tools {:enable_clippy true}
      :server {:lspmux {:enable true}
               :default_settings
               {:rust-analyzer
                {:checkOnSave true
                 :cargo {:targetDir true
                         :buildScripts {:enable true}}
                 :procMacro {:enable true}}}}})

[(p!
   :mrcjkb/rustaceanvim
   (lazy false)
   (version :^9))]
