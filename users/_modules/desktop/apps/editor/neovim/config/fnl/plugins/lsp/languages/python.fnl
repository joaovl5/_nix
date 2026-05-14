(import-macros {: p!} :./lib/init-macros)

(p! :linux-cultist/venv-selector.nvim
    (deps [(p! :nvim-telescope/telescope.nvim (version "*"))]) ;
    (ft :python)
    (keys (bind (l :cv) (cmd :VenvSelect) (desc "Pick virtual env"))) ;
    (opts {}))
