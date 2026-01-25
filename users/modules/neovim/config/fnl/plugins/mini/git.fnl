(local {: now : add : later}
       {:now MiniDeps.now :add MiniDeps.add :later MiniDeps.later})

(import-macros {: do-req : let-req} :./lib/init-macros)

(later (fn []
         (let-req [diff :mini.diff] (diff.setup {}))
         (let-req [git :mini.git] (git.setup {}))))
