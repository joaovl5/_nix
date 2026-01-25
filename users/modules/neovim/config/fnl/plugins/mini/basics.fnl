(local {: now : add : later}
       {:now MiniDeps.now :add MiniDeps.add :later MiniDeps.later})

(import-macros {: do-req : let-req} :./lib/init-macros)

(now (fn []
       (let-req [basics :mini.basics]
                (basics.setup {:options {:basic false}
                               ; save w/ `<C-s>` and other things
                               :mappings {:basic true
                                          ; <C-hjkl> window nav
                                          :windows true
                                          ; disable <M-hjkl> insert mode nav
                                          :move_with_alt false}}))))

; local now = MiniDeps.now
;
; now(function()
;     require('mini.basics').setup {
;                                   options = { basic = false },
;                                   mappings = {
;                                               -- save w/ `<C-s>` among other things
;                                               basic = true,
;                                               -- Create `<C-hjkl>` mappings for window navigation
;                                               windows = true,
;                                               -- Disable `<M-hjkl>` mappings for navigation in Insert and Command modes
;                                               move_with_alt = false,}
;                                   ,}
;
;     end)
