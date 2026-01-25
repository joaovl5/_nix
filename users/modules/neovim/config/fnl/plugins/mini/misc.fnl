(local {: now : add : later}
       {:now MiniDeps.now :add MiniDeps.add :later MiniDeps.later})

(import-macros {: do-req : let-req} :./lib/init-macros)

(later (fn []
         (do-req :mini.misc :setup)
         ;; change cwd based on current file (searches file tree until root marker)
         (MiniMisc.setup_auto_root)
         ;; restore last cursor position on file open
         (MiniMisc.setup_restore_cursor)
         ;; sync term emulator bg
         (MiniMisc.setup_termbg_sync)))
