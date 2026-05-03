(import-macros {: do-req : let-req : plugin : key} :./lib/init-macros)

(plugin :nvim-mini/mini.map
        {:version "*"
         :opts #(let-req [map :mini.map] ;; use braille dots
                         ;; use search_matches, mini.diff hunks, diagnostics
                         {:symbols {:encode (map.gen_encode_symbols.dot :4x2)}
                          :integrations [(map.gen_integration.builtin_search)
                                         (map.gen_integration.diff)
                                         (map.gen_integration.diagnostic)]})})
