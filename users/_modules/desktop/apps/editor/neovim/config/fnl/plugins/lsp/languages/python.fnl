(import-macros {: plugin!} :./lib/init-macros)

(plugin! :linux-cultist/venv-selector.nvim
         (dependencies [(plugin! :nvim-telescope/telescope.nvim (version "*"))])
         (ft :python)
         (keys (bind (l :cv) (cmd :VenvSelect) (desc "Pick virtual env")))
         (opts {}))
