-- [nfnl] fnl/plugins/editor/motions.fnl
local _local_1_ = require("lib/nvim")
local v_2f_24 = _local_1_["v/$"]
local function treewalker(subcommand)
  local ok, err = pcall(v_2f_24, ("Treewalker " .. subcommand))
  if not ok then
    if (("string" == type(err)) and string.find(err, "Treewalker: Treesitter node not found under cursor", 1, true)) then
      return vim.notify("Treewalker: no Treesitter node under cursor", vim.log.levels.WARN)
    else
      return error(err)
    end
  else
    return nil
  end
end
local _4_
do
  local flash_exclude = {"notify", "cmp_menu", "noice", "flash_prompt", "codediff-explorer"}
  local flash_key_specs
  local function _5_()
    local name_1_auto = require("flash")
    local fun_2_auto = name_1_auto.jump
    return fun_2_auto()
  end
  local function _6_()
    local name_1_auto = require("flash")
    local fun_2_auto = name_1_auto.treesitter
    return fun_2_auto()
  end
  local function _7_()
    local name_1_auto = require("flash")
    local fun_2_auto = name_1_auto.remote
    return fun_2_auto()
  end
  flash_key_specs = {{"s", _5_, mode = {"n", "x", "o"}}, {"S", _6_, mode = {"n", "x", "o"}}, {"r", _7_, mode = {"o"}, desc = "Remote flash"}}
  local registered_flash_buffers = {}
  local flash_filetype_3f
  local function _8_(filetype)
    local matches_3f = false
    for _, excluded in ipairs(flash_exclude) do
      if matches_3f then break end
      matches_3f = (excluded == filetype)
    end
    return matches_3f
  end
  flash_filetype_3f = _8_
  local flash_excluded_buffer_3f
  local function _9_(bufnr)
    return flash_filetype_3f(vim.api.nvim_get_option_value("filetype", {buf = bufnr}))
  end
  flash_excluded_buffer_3f = _9_
  local register_flash_keys_21
  local function _10_(bufnr)
    if not registered_flash_buffers[bufnr] then
      for _, spec in ipairs(flash_key_specs) do
        vim.keymap.set(spec.mode, spec[1], spec[2], {buffer = bufnr, desc = spec.desc})
      end
      registered_flash_buffers[bufnr] = true
      return nil
    else
      return nil
    end
  end
  register_flash_keys_21 = _10_
  local delete_flash_keys_21
  local function _12_(bufnr)
    if registered_flash_buffers[bufnr] then
      for _, spec in ipairs(flash_key_specs) do
        for _0, mode in ipairs(spec.mode) do
          pcall(vim.keymap.del, mode, spec[1], {buffer = bufnr})
        end
      end
      registered_flash_buffers[bufnr] = nil
      return nil
    else
      return nil
    end
  end
  delete_flash_keys_21 = _12_
  local sync_flash_keys_21
  local function _14_(bufnr)
    if vim.api.nvim_buf_is_valid(bufnr) then
      if flash_excluded_buffer_3f(bufnr) then
        return delete_flash_keys_21(bufnr)
      else
        return register_flash_keys_21(bufnr)
      end
    else
      return nil
    end
  end
  sync_flash_keys_21 = _14_
  local _17_ = require("lib.plugins")
  local _18_ = require("lib.keys")
  local spec_24_auto = {}
  local function _20_()
    local group = vim.api.nvim_create_augroup("MyFlashKeys", {clear = true})
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      sync_flash_keys_21(bufnr)
    end
    local function _21_(event)
      return sync_flash_keys_21(event.buf)
    end
    return vim.api.nvim_create_autocmd({"BufEnter", "FileType"}, {group = group, callback = _21_})
  end
  local function _22_(...)
    local keys = "fhdjskalgrueiwoqptvnmb"
    local function _23_(win)
      return not vim.api.nvim_win_get_config(win).focusable
    end
    return {labels = keys, search = {forward = true, wrap = true, exclude = {_23_, unpack(flash_exclude)}, mode = "fuzzy", multi_window = false}, jump = {nohlsearch = true, autojump = true}, label = {distance = true, uppercase = false}, highlight = {backdrop = true}, modes = {char = {enabled = false}, treesitter = {labels = keys, highlight = {backdrop = true, matches = false}}}}
  end
  for __25_auto, attrs_26_auto in ipairs({_17_.event("BufEnter"), _17_.init(_20_), _17_.opts(_22_(...))}) do
    for key_27_auto, value_28_auto in pairs(attrs_26_auto) do
      spec_24_auto[key_27_auto] = value_28_auto
    end
  end
  spec_24_auto[1] = "folke/flash.nvim"
  _4_ = spec_24_auto
end
local _26_
do
  local _24_ = require("lib.plugins")
  local _25_ = require("lib.keys")
  local spec_24_auto = {}
  local function _27_()
    local name_1_auto = require("spider")
    local fun_2_auto = name_1_auto.motion
    return fun_2_auto("w")
  end
  local function _28_()
    local name_1_auto = require("spider")
    local fun_2_auto = name_1_auto.motion
    return fun_2_auto("e")
  end
  local function _29_()
    local name_1_auto = require("spider")
    local fun_2_auto = name_1_auto.motion
    return fun_2_auto("b")
  end
  for __25_auto, attrs_26_auto in ipairs({_24_.keys(_25_.bind("w", _27_, _25_.m("n", "x", "o")), _25_.bind("e", _28_, _25_.m("n", "x", "o")), _25_.bind("b", _29_, _25_.m("n", "x", "o"))), _24_.opts(true)}) do
    for key_27_auto, value_28_auto in pairs(attrs_26_auto) do
      spec_24_auto[key_27_auto] = value_28_auto
    end
  end
  spec_24_auto[1] = "chrisgrieser/nvim-spider"
  _26_ = spec_24_auto
end
local function _32_(...)
  local _30_ = require("lib.plugins")
  local _31_ = require("lib.keys")
  local spec_24_auto = {}
  local function _33_()
    return treewalker("Left")
  end
  local function _34_()
    return treewalker("Right")
  end
  local function _35_()
    return treewalker("Up")
  end
  local function _36_()
    return treewalker("Down")
  end
  local function _37_()
    return treewalker("SwapLeft")
  end
  local function _38_()
    return treewalker("SwapRight")
  end
  local function _39_()
    return treewalker("SwapUp")
  end
  local function _40_()
    return treewalker("SwapDown")
  end
  for __25_auto, attrs_26_auto in ipairs({_30_.cmd("Treewalker"), _30_.keys(_31_.bind("<A-[>", _33_, _31_.m("n", "x")), _31_.bind("<A-]>", _34_, _31_.m("n", "x")), _31_.bind("<A-k>", _35_, _31_.m("n", "x")), _31_.bind("<A-j>", _36_, _31_.m("n", "x")), _31_.bind("<A-S-[>", _37_, _31_.m("n", "x")), _31_.bind("<A-S-]>", _38_, _31_.m("n", "x")), _31_.bind("<A-K>", _39_, _31_.m("n", "x")), _31_.bind("<A-J>", _40_, _31_.m("n", "x"))), _30_.opts({})}) do
    for key_27_auto, value_28_auto in pairs(attrs_26_auto) do
      spec_24_auto[key_27_auto] = value_28_auto
    end
  end
  spec_24_auto[1] = "aaronik/treewalker.nvim"
  return spec_24_auto
end
return {{"mluders/comfy-line-numbers.nvim", opts = true, event = "BufEnter"}, _4_, _26_, _32_(...)}
