(local {: now : add : later}
       {:now MiniDeps.now :add MiniDeps.add :later MiniDeps.later})

(import-macros {: do-req : let-req} :./lib/init-macros)

(later (fn []
         (let-req [map :mini.map] ;
                  ;; use braille dots
                  ;; use search_matches, mini.diff hunks, diagnostics
                  (map.setup {:symbols {:encode (map.gen_encode_symbols.dot :4x2)}
                              :integrations [(map.gen_integration.builtin_search)
                                             (map.gen_integration.diff)
                                             (map.gen_integration.diagnostic)]}))))
