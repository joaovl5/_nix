(import-macros {: p!} :./lib/init-macros)

(p! :Owen-Dechow/videre.nvim
    (cmd :Videre)
    (deps [:Owen-Dechow/graph_view_yaml_parser
           :Owen-Dechow/graph_view_toml_parser
           :a-usr/xml2lua.nvim])
    (opts {:simple_statusline false
           :editor_type :split}))
