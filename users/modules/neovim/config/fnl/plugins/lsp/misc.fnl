(local {: now : add : later}
       {:now MiniDeps.now :add MiniDeps.add :later MiniDeps.later})

(import-macros {: do-req : let-req} :./lib/init-macros)

; using a personal fork due to nvim nightly switching `LspStart` to `lsp start`
; (add :joaovl5/garbage-day.nvim)
; (do-req :garbage-day :setup ;
;         ;; waits 15min before killing inactive lsp
;         {:grace_period (* 60 15)
;          ;; waits 1s to ressucitate lsp
;          :wakeup_delay :1})
