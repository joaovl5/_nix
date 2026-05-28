-- [nfnl] fnl/plugins/ui/setup.fnl
local name_1_auto = require("vim._core.ui2")
local fun_2_auto = name_1_auto.enable
return fun_2_auto({enable = true, msg = {targets = "msg", cmd = {height = 0.6}, dialog = {height = 0.6}, msg = {height = 0.6, timeout = 3500}, pager = {height = 2}}})
