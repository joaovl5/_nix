-- [nfnl] fnl/wezterm.fnl
local wez = require("wezterm")
local c = wez.config_builder()
local act = wez.action
c.enable_kitty_keyboard = true
c.window_close_confirmation = "NeverPrompt"
local font_def = wez.font("RecMonoSmCasual Nerd Font Mono")
c.initial_cols = 120
c.initial_rows = 28
c.font_size = 17
c.font = font_def
do
  local target = "Light"
  c.freetype_load_target = target
  c.freetype_render_target = target
end
c.use_fancy_tab_bar = true
c.window_padding = {left = 16, right = 16, top = 4, bottom = 4}
local function k(key, mods, action)
  return {key = key, mods = mods, action = action}
end
c.keys = {k("c", "ALT", act.CopyTo("Clipboard")), k("v", "ALT", act.PasteFrom("Clipboard")), k("Enter", "ALT", act.DisableDefaultAssignment), k("F11", "ALT", act.ToggleFullScreen)}
return c
