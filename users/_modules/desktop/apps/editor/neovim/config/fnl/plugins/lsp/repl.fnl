(import-macros {: p!} :./lib/init-macros)
(fn init_conjure []
  (set vim.g.conjure#mapping#prefix ","))

(init_conjure)

[(p!
   :Olical/conjure
   (lazy false)
   (keys
     (bind (c "e") (cmd "ConjureEval") (m :n :v) (desc "Evaluate code"))
     (group
       :repl
       (bind :l (cmd "ConjureLogVSplit") (desc "Show logs"))
       (bind :o (cmd "ConjureEvalCurrentForm") (desc "Eval current form"))
       (bind :r (cmd "ConjureEvalRootForm") (desc "Eval root form"))))
   (deps
     (p! ; do later
         :PaterJason/cmp-conjure
         (event :VeryLazy))))]
