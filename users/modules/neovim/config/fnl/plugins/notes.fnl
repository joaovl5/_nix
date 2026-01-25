(local {: now : add : later}
       {:now MiniDeps.now :add MiniDeps.add :later MiniDeps.later})

(import-macros {: do-req : let-req} :./lib/init-macros)

(later (fn []
         (add :obsidian-nvim/obsidian.nvim)
         (do-req :obsidian :setup
                 {:legacy_commands false
                  :workspaces [{:name :wiki :path "~/wiki/"}]})))
