(local {: now : add : later}
       {:now MiniDeps.now :add MiniDeps.add :later MiniDeps.later})

(import-macros {: do-req : let-req} :./lib/init-macros)

; reactive colors on mode/motions
(add :rasulomaroff/reactive.nvim)
(do-req :reactive :setup {:builtin {:cursorline true
                                    :cursor true
                                    :modemsg true}})

; color hex codes
(add :catgoose/nvim-colorizer.lua)
