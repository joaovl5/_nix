(local {: later} {:later MiniDeps.later})

; finder (fff)
(later #(require :plugins.editor.finder))

; motion-related
; - relative line numbers only use digits 1-5
; - leap
; - spider
(later #(require :plugins.editor.motions))

; action-related
; - type annotations generation
; - pretty hover 
; - tiny code actions
(later #(require :plugins.editor.actions))

; glancy, navbuddy
(later #(require :plugins.editor.views))
