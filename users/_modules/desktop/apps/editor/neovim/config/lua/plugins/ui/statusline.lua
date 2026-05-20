-- [nfnl] fnl/plugins/ui/statusline.fnl
local _local_1_ = require("lib/nvim")
local v_2f_24 = _local_1_["v/$"]
local v_2finput = _local_1_["v/input"]
local v_2fmode = _local_1_["v/mode"]
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
local colors = {bg = "#202328", fg = "#bbc2cf", yellow = "#ECBE7B", cyan = "#008080", darkblue = "#081633", green = "#98be65", orange = "#FF8800", violet = "#a9a1e1", magenta = "#c678dd", blue = "#51afef", red = "#ec5f67"}
local mode_info = {n = {"\240\159\156\148 ", "red"}, no = {"\240\159\157\149 ", "red"}, nov = {"\240\159\157\149 ", "red"}, noV = {"\240\159\157\149 ", "red"}, ["noCTRL-V"] = {"\240\159\157\149 ", "red"}, niI = {"\240\159\156\148 ", "red"}, niR = {"\240\159\156\148 ", "red"}, niV = {"\240\159\156\148 ", "red"}, nt = {"\240\159\156\148 ", "red"}, ntT = {"\240\159\156\148 ", "red"}, i = {"\240\159\156\149 ", "green"}, ic = {"\240\159\156\149 ", "yellow"}, ix = {"\240\159\156\149 ", "yellow"}, v = {"\240\159\156\137 ", "blue"}, vs = {"\240\159\156\137 ", "blue"}, V = {"\240\159\157\147 ", "blue"}, Vs = {"\240\159\157\147 ", "blue"}, ["\22"] = {"\240\159\157\162 ", "blue"}, ["\22s"] = {"\240\159\157\162 ", "blue"}, s = {"\240\159\156\137 ", "orange"}, S = {"\240\159\157\147 ", "orange"}, ["\19"] = {"\240\159\157\162 ", "orange"}, R = {"\240\159\157\152 ", "violet"}, Rc = {"\240\159\157\152 ", "violet"}, Rx = {"\240\159\157\152 ", "violet"}, Rv = {"\240\159\157\152 ", "violet"}, Rvc = {"\240\159\157\152 ", "violet"}, Rvx = {"\240\159\157\152 ", "violet"}, c = {"\240\159\157\138 ", "magenta"}, cr = {"\240\159\157\138 ", "magenta"}, cv = {"\240\159\157\157 ", "red"}, cvr = {"\240\159\157\157 ", "red"}, ce = {"\240\159\157\157 ", "red"}, r = {"\240\159\156\185 ", "orange"}, rm = {"\240\159\156\185 ", "orange"}, ["r?"] = {"\240\159\156\185 ", "orange"}, ["!"] = {"\240\159\156\185 ", "yellow"}, t = {"\240\159\157\146 ", "yellow"}}
local function mode_column(column)
  local out = {}
  for mode, info in pairs(mode_info) do
    out[mode] = info[column]
  end
  return out
end
local mode_label = mode_column(1)
local mode_color = mode_column(2)
local function mode_value(lookup, mode, fallback)
  return (lookup[mode] or lookup[string.sub(mode, 1, 1)] or fallback)
end
local function comp_mode()
  local current_mode = v_2fmode(1)
  return mode_value(mode_label, current_mode, current_mode)
end
local function comp_mode_color()
  local current_mode = v_2fmode(1)
  return {fg = colors[mode_value(mode_color, current_mode, "fg")]}
end
local function setup_lualine()
  local raw_sections = {a = {comp(comp_mode, {color = comp_mode_color})}, b = {"filename", "branch"}, c = {"%="}, x = {comp("triforce", {level = {enabled = true, prefix = "\243\176\166\135 "}, achievements = {enabled = true, icon = "\239\130\145 "}, streak = {enabled = true, icon = "\239\129\173 "}, session_time = {enabled = true, icon = "\239\128\151 "}}), require("token-count.integrations.lualine").current_buffer}, y = {"filetype"}, z = {}}
  local raw_inactive_sections = {a = {"filename"}, b = {}, c = {}, x = {}, y = {}, z = {"location"}}
  return {options = {component_separators = "", section_separators = "", theme = {normal = {a = {fg = colors.fg, bg = colors.bg}}, inactive = {a = {fg = colors.fg, bg = colors.bg}}}}, sections = section_transform(raw_sections), inactive_sections = section_transform(raw_inactive_sections), tabline = {}, extensions = {}}
end
local _4_
do
  local _2_ = require("lib.plugins")
  local _3_ = require("lib.keys")
  local spec_24_auto = {}
  local function _7_(...)
    local _5_ = require("lib.plugins")
    local _6_ = require("lib.keys")
    local spec_24_auto0 = {}
    for __25_auto, attrs_26_auto in ipairs({_5_.opts({model = "gpt-5"})}) do
      for key_27_auto, value_28_auto in pairs(attrs_26_auto) do
        spec_24_auto0[key_27_auto] = value_28_auto
      end
    end
    spec_24_auto0[1] = "3ZsForInsomnia/token-count.nvim"
    return spec_24_auto0
  end
  for __25_auto, attrs_26_auto in ipairs({_2_.opts(setup_lualine), _2_.deps(_7_(...)), _2_.event("VeryLazy")}) do
    for key_27_auto, value_28_auto in pairs(attrs_26_auto) do
      spec_24_auto[key_27_auto] = value_28_auto
    end
  end
  spec_24_auto[1] = "nvim-lualine/lualine.nvim"
  _4_ = spec_24_auto
end
local function _10_(...)
  local _8_ = require("lib.plugins")
  local _9_ = require("lib.keys")
  local spec_24_auto = {}
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
  for __25_auto, attrs_26_auto in ipairs({_8_.event("VeryLazy"), _8_.keys(_9_.group("tab", _9_.bind("w", _9_.cmd("Tabby pick_window"), _9_.desc("Pick window")), _9_.bind("q", _9_.cmd("Tabby jump_to_tab"), _9_.desc("Jump mode")), _9_.bind("r", _11_, _9_.desc("Rename")))), _8_.opts({preset = "tab_only", option = {theme = {fill = "TabLineFill", head = "TabLine", current_tab = "TabLineSel", tab = "TabLine", win = "TabLine", tail = "TabLine"}, nerdfont = true, lualine_theme = nil, tab_name = {tab_fallback = _14_}, buf_name = {mode = "shorten"}}})}) do
    for key_27_auto, value_28_auto in pairs(attrs_26_auto) do
      spec_24_auto[key_27_auto] = value_28_auto
    end
  end
  spec_24_auto[1] = "nanozuki/tabby.nvim"
  return spec_24_auto
end
return {_4_, _10_(...)}
