-- [nfnl] fnl/plugins/themery.fnl
local _local_1_ = require("lib/nvim")
local v_2fextend = _local_1_["v/extend"]
local function setup_themery()
  local global_themes = (_G.Config.themes or {})
  local themes
  do
    local names = {}
    for _, theme in ipairs(global_themes) do
      names = v_2fextend(names, theme.names)
    end
    themes = names
  end
  return {themes = themes, livePreview = true}
end
local _2_ = require("lib.plugins")
local _3_ = require("lib.keys")
local spec_23_auto = {}
for __24_auto, attrs_25_auto in ipairs({_2_.lazy(false), _2_.keys(_3_.group("meta", _3_.bind("t", _3_.cmd("Themery"), _3_.desc("Themery")))), _2_.opts(setup_themery)}) do
  for key_26_auto, value_27_auto in pairs(attrs_25_auto) do
    spec_23_auto[key_26_auto] = value_27_auto
  end
end
spec_23_auto[1] = "zaldih/themery.nvim"
return spec_23_auto
