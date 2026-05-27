-- [nfnl] fnl/plugins/keys/hydra.fnl
local resize_step = 3
local function resize(command)
  local function _1_()
    return vim.cmd((command .. resize_step))
  end
  return _1_
end
local function setup_window_resize_hydra()
  local Hydra = require("hydra")
  local function _2_()
    return nil
  end
  local function _3_()
    return nil
  end
  local function _4_()
    return nil
  end
  return Hydra({name = "Window resize", mode = {"n", "t"}, body = ";r", hint = "Resize: _H_ width-  _L_ width+  _K_ height-  _J_ height+  _<Esc>_ exit", config = {invoke_on_body = true, desc = "Resize mode", color = "red", hint = {type = "window", position = "bottom"}}, heads = {{"H", resize("vertical resize -"), {desc = "width -"}}, {"L", resize("vertical resize +"), {desc = "width +"}}, {"K", resize("resize -"), {desc = "height -"}}, {"J", resize("resize +"), {desc = "height +"}}, {"<Esc>", _2_, {exit = true, desc = "exit"}}, {"<CR>", _3_, {exit = true, desc = "exit"}}, {"q", _4_, {exit = true, desc = "exit"}}}})
end
local _5_ = require("lib.plugins")
local _6_ = require("lib.keys")
local spec_24_auto = {}
for __25_auto, attrs_26_auto in ipairs({_5_.lazy(false), _5_.config(setup_window_resize_hydra)}) do
  for key_27_auto, value_28_auto in pairs(attrs_26_auto) do
    spec_24_auto[key_27_auto] = value_28_auto
  end
end
spec_24_auto[1] = "nvimtools/hydra.nvim"
return spec_24_auto
