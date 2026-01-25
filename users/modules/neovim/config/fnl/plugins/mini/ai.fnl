(local {: now : add : later}
       {:now MiniDeps.now :add MiniDeps.add :later MiniDeps.later})

(import-macros {: do-req : let-req} :./lib/init-macros)

(later (fn []
         (let-req [ai :mini.ai] ;
                  ; - make aB/iB act on around/inside buffer
                  ; - make aF/iF mean inside/around function
                  (ai.setup {:custom_textobjects {:B (MiniExtra.gen_ai_spec.buffer)}
                             :F (ai.gen_spec.treesitter {:a "@function.outer"
                                                         :i "@function.inner"})
                             :search_method :cover}))))
