-- [nfnl] fnl/plugins/ui/statusline.fnl
local _local_1_ = require("lib/nvim")
local v_2f_24 = _local_1_["v/$"]
local v_2finput = _local_1_["v/input"]
local function comp(component, _3fopts)
  local opts = (_3fopts or {})
  local out = {}
  out[1] = component
  for k, v in pairs(opts) do
    out[k] = v
  end
  return out
end
local function section_transform(sections)
  local out = {}
  for k, v in pairs(sections) do
    out[("lualine_" .. tostring(k))] = v
  end
  return out
end
local function setup_lualine()
  local raw_sections = {a = {"mode"}, b = {"filename", "branch"}, c = {"%="}, x = {require("token-count.integrations.lualine").current_buffer}, y = {"filetype"}, z = {"location", "progress"}}
  local raw_inactive_sections = {a = {"filename"}, b = {}, c = {}, x = {}, y = {}, z = {"location"}}
  return {options = {component_separators = "", section_separators = ""}, sections = section_transform(raw_sections), inactive_sections = section_transform(raw_inactive_sections), tabline = {}, extensions = {}}
end
local _4_
do
  local _2_ = require("lib.plugins")
  local _3_ = require("lib.keys")
  local spec_23_auto = {}
  local function _7_(...)
    local _5_ = require("lib.plugins")
    local _6_ = require("lib.keys")
    local spec_23_auto0 = {}
    for __24_auto, attrs_25_auto in ipairs({_5_.opts({model = "gpt-5"})}) do
      for key_26_auto, value_27_auto in pairs(attrs_25_auto) do
        spec_23_auto0[key_26_auto] = value_27_auto
      end
    end
    spec_23_auto0[1] = "3ZsForInsomnia/token-count.nvim"
    return spec_23_auto0
  end
  for __24_auto, attrs_25_auto in ipairs({_2_.opts(setup_lualine), _2_.deps(_7_(...)), _2_.event("VeryLazy")}) do
    for key_26_auto, value_27_auto in pairs(attrs_25_auto) do
      spec_23_auto[key_26_auto] = value_27_auto
    end
  end
  spec_23_auto[1] = "nvim-lualine/lualine.nvim"
  _4_ = spec_23_auto
end
local function _10_(...)
  local _8_ = require("lib.plugins")
  local _9_ = require("lib.keys")
  local spec_23_auto = {}
  local function _11_()
    local function _12_(_2410)
      if (nil ~= _2410) then
        return v_2f_24(("Tabby rename_tab " .. _2410))
      else
        return nil
      end
    end
    return v_2finput({prompt = "Enter name for tab:"}, _12_)
  end
  local function _14_(tabid)
    return tabid()
  end
  for __24_auto, attrs_25_auto in ipairs({_8_.event("VeryLazy"), _8_.keys(_9_.group("tab", _9_.bind("w", _9_.cmd("Tabby pick_window"), _9_.desc("Pick window")), _9_.bind("q", _9_.cmd("Tabby jump_to_tab"), _9_.desc("Jump mode")), _9_.bind("r", _11_, _9_.desc("Rename")))), _8_.opts({preset = "tab_only", option = {theme = {fill = "TabLineFill", head = "TabLine", current_tab = "TabLineSel", tab = "TabLine", win = "TabLine", tail = "TabLine"}, nerdfont = true, lualine_theme = nil, tab_name = {tab_fallback = _14_}, buf_name = {mode = "shorten"}}})}) do
    for key_26_auto, value_27_auto in pairs(attrs_25_auto) do
      spec_23_auto[key_26_auto] = value_27_auto
    end
  end
  spec_23_auto[1] = "nanozuki/tabby.nvim"
  return spec_23_auto
end
return {_4_, _10_(...)}
