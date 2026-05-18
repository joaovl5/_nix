-- [nfnl] fnl/plugins/themery.fnl
local _local_1_ = require("lib/nvim")
local v_2fextend = _local_1_["v/extend"]
local function _2_()
  local theme_names
  do
    local all_names = {}
    for _, theme in ipairs((_G.Config.themes or {})) do
      all_names = v_2fextend(all_names, theme.names)
    end
    theme_names = all_names
  end
  local name_1_auto = require("themery")
  local fun_2_auto = name_1_auto.setup
  return fun_2_auto({themes = theme_names, livePreview = true})
end
return {"zaldih/themery.nvim", config = _2_, lazy = false}
