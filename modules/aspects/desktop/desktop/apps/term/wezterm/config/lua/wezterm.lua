-- [nfnl] fnl/wezterm.fnl
local wez = require("wezterm")
local c = wez.config_builder()
local act = wez.action
local font_def = wez.font("Kode Mono")
local font_bold = wez.font("BigBlueTermPlus Nerd Font Mono")
local font_italic = wez.font({family = "RecMonoSmCasual Nerd Font Mono", style = "Italic"})
c.initial_cols = 120
c.initial_rows = 28
c.font_size = 17
c.font = font_def
c.font_rules = {{intensity = "Bold", font = font_bold, italic = false}, {intensity = "Normal", italic = true, font = font_italic}}
do
  local target = "Light"
  c.freetype_load_target = target
  c.freetype_render_target = target
end
c.color_scheme = "synthwave"
c.use_fancy_tab_bar = true
c.window_frame = {font = font_bold, font_size = 13}
c.window_padding = {left = 16, right = 16, top = 4, bottom = 4}
local function k(key, mods, action)
  return {key = key, mods = mods, action = action}
end
c.keys = {k("c", "ALT", act.CopyTo("Clipboard")), k("v", "ALT", act.PasteFrom("Clipboard"))}
return c
