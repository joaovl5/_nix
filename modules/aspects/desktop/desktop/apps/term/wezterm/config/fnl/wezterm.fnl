(local wez (require :wezterm))
(local c (wez.config_builder))
(local act wez.action)

(local font_def (wez.font "Kode Mono"))
(local font_bold (wez.font "BigBlueTermPlus Nerd Font Mono"))
(local font_italic (wez.font
                     {:family "RecMonoSmCasual Nerd Font Mono"
                      :style :Italic}))

(set c.initial_cols 120)
(set c.initial_rows 28)

(set c.font_size 17)
(set c.font font_def)
(set c.font_rules
     [{:intensity :Bold
       :italic false
       :font font_bold}
      {:intensity :Normal
       :italic true
       :font font_italic}])

(let [target :Light]
  (set c.freetype_load_target target)
  (set c.freetype_render_target target))

; appearance
(set c.color_scheme "synthwave")
(set c.use_fancy_tab_bar true)
(set c.window_frame
     {:font font_bold
      :font_size 13})

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
      (k :v :ALT (act.PasteFrom :Clipboard))])

c
