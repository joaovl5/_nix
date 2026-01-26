-- [nfnl] fnl/plugins/mini/hipatterns.fnl
local function _1_()
  local hi = require("mini.hipatterns")
  local words = MiniExtra.gen_highlighter.words
  return {highlighters = {fixme = words({"FIXME"}, "Fixme", "fixme", "MiniHipatternsFixme"), hack = words({"HACK", "Hack", "hack", "MiniHipatternsHack"}), todo = words({"TODO", "Todo", "todo", "MiniHipatternsTodo"}), note = words({"NOTE", "Note", "note", "MiniHipatternsNote"})}, hex_color = hi.gen_highlighter.hex_color()}
end
return {"nvim-mini/mini.hipatterns", dependencies = {"nvim-mini/mini.extra"}, version = "*", opts = _1_}
