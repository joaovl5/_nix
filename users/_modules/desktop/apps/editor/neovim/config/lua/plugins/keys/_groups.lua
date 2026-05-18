-- [nfnl] fnl/plugins/keys/_groups.fnl
local k = require("lib.keys")
k["register-group!"]("tab", "Tab", k.l("q"))
k["register-group!"]("window", "Window", k.l("w"))
k["register-group!"]("buffer", "Buffer", k.l("b"))
k["register-group!"]("fuzzy", "Fuzzy", k.l("f"))
k["register-group!"]("git", "Git", k.l("g"))
k["register-group!"]("code", "Code", k.l("c"))
k["register-group!"]("diagnostics", "Diagnostics", k.l("x"))
k["register-group!"]("trouble", "Trouble", k.l("x"))
k["register-group!"]("debug", "Debug", k.l("d"))
k["register-group!"]("ai", "CodeCompanion", k.l("a"))
return true
