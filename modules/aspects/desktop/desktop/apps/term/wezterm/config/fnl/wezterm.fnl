(local wez (require :wezterm))
(local c (wez.config_builder))
(local act wez.action)

(set c.enable_kitty_keyboard true)
(set c.window_close_confirmation "NeverPrompt")

(local font_def (wez.font "RecMonoSmCasual Nerd Font Mono"))

(set c.initial_cols 120)
(set c.initial_rows 28)

(set c.font_size 17)
(set c.font font_def)

(let [target :Light]
  (set c.freetype_load_target target)
  (set c.freetype_render_target target))

; appearance
; (set c.color_scheme "synthwave")
(set c.use_fancy_tab_bar true)

(set c.window_padding
     {:left 16
      :right 16
      :top 4
      :bottom 4})

; keys
(fn k [key mods action]
  {: key : mods : action})

(set c.keys
     [(k :c :ALT (act.CopyTo :Clipboard))
      (k :v :ALT (act.PasteFrom :Clipboard))
      (k :Enter :ALT act.DisableDefaultAssignment)
      (k :F11 :ALT act.ToggleFullScreen)])

c
