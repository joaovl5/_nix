-- [nfnl] fnl/lib/keys.fnl
local M = {}
M.l = function(lhs)
  return ("<leader>" .. lhs)
end
M.c = function(key)
  return ("<C-" .. key .. ">")
end
M.a = function(key)
  return ("<A-" .. key .. ">")
end
M.cmd = function(command)
  return ("<cmd>" .. command .. "<cr>")
end
M.desc = function(text)
  return {desc = text}
end
M.icon = function(glyph, _3fcolor)
  local _1_
  if _3fcolor then
    _1_ = {icon = glyph, color = _3fcolor}
  else
    _1_ = glyph
  end
  return {icon = _1_}
end
M.m = function(...)
  return {mode = {...}}
end
_G.kgroups = (_G.kgroups or {})
local function merge_21(target, source)
  for key, value in pairs(source) do
    target[key] = value
  end
  return target
end
local function key_option_3f(value)
  return ((type(value) == "table") and (nil == value[1]))
end
local function group_options(...)
  local opts = {}
  local items = {}
  for _, item in ipairs({...}) do
    if key_option_3f(item) then
      merge_21(opts, item)
    else
      table.insert(items, item)
    end
  end
  return opts, items
end
local function key_spec(lhs, rhs, opts)
  local spec = merge_21({lhs}, opts)
  if rhs then
    spec[2] = rhs
  else
  end
  return spec
end
M.bind = function(lhs, _3frhs, ...)
  local opts = {}
  if key_option_3f(_3frhs) then
    merge_21(opts, _3frhs)
  else
  end
  for _, opt in ipairs({...}) do
    merge_21(opts, opt)
  end
  local _6_
  if key_option_3f(_3frhs) then
    _6_ = nil
  else
    _6_ = _3frhs
  end
  return {key_spec(lhs, _6_, opts)}
end
local function spec_list_3f(item)
  return ((type(item) == "table") and (type(item[1]) == "table"))
end
local function copy_spec(spec)
  local copied = {}
  return merge_21(copied, spec)
end
local function prepend_spec(prefix, spec)
  local prefixed = copy_spec(spec)
  prefixed[1] = (prefix .. spec[1])
  return prefixed
end
local function add_prefixed_21(specs, prefix, item)
  if spec_list_3f(item) then
    for _, spec in ipairs(item) do
      table.insert(specs, prepend_spec(prefix, spec))
    end
  else
    table.insert(specs, prepend_spec(prefix, item))
  end
  return specs
end
local function ensure_list(value)
  if (type(value) == "table") then
    return value
  else
    return {value}
  end
end
local function filetype_in_3f(filetypes, filetype)
  local matches_3f = false
  for _, candidate in ipairs(filetypes) do
    if matches_3f then break end
    matches_3f = (candidate == filetype)
  end
  return matches_3f
end
local function with_buffer(spec, bufnr)
  local buffered = copy_spec(spec)
  buffered["buffer"] = bufnr
  return buffered
end
local function buffer_specs(specs, bufnr)
  local tbl_26_ = {}
  local i_27_ = 0
  for _, spec in ipairs(specs) do
    local val_28_ = with_buffer(spec, bufnr)
    if (nil ~= val_28_) then
      i_27_ = (i_27_ + 1)
      tbl_26_[i_27_] = val_28_
    else
    end
  end
  return tbl_26_
end
local function apply_ft_specs_21(filetypes, specs, bufnr)
  if (_G.vim.api.nvim_buf_is_valid(bufnr) and filetype_in_3f(filetypes, _G.vim.api.nvim_get_option_value("filetype", {buf = bufnr}))) then
    return require("which-key").add(buffer_specs(specs, bufnr))
  else
    return nil
  end
end
local function apply_mode(mode, spec)
  if spec.mode then
    error(("with-mode cannot wrap a bind that already has mode: " .. tostring(spec[1])))
  else
  end
  local moded = copy_spec(spec)
  moded["mode"] = mode
  return moded
end
M.specs = function(...)
  local items = {}
  for _, item in ipairs({...}) do
    if spec_list_3f(item) then
      for _0, spec in ipairs(item) do
        table.insert(items, spec)
      end
    else
      table.insert(items, item)
    end
  end
  return items
end
M["with-mode"] = function(mode, ...)
  local tbl_26_ = {}
  local i_27_ = 0
  for _, spec in ipairs(M.specs(...)) do
    local val_28_ = apply_mode(mode, spec)
    if (nil ~= val_28_) then
      i_27_ = (i_27_ + 1)
      tbl_26_[i_27_] = val_28_
    else
    end
  end
  return tbl_26_
end
M["register-plugin-icons!"] = function()
  if (_G.which_key_plugin_icon_specs and (0 < #_G.which_key_plugin_icon_specs)) then
    return require("which-key").add(_G.which_key_plugin_icon_specs)
  else
    return nil
  end
end
M["ft-keys"] = function(filetypes, specs)
  local filetypes0 = ensure_list(filetypes)
  local group = _G.vim.api.nvim_create_augroup("MyFiletypeKeys", {clear = false})
  for _, bufnr in ipairs(_G.vim.api.nvim_list_bufs()) do
    apply_ft_specs_21(filetypes0, specs, bufnr)
  end
  local function _16_(event)
    return apply_ft_specs_21(filetypes0, specs, event.buf)
  end
  return _G.vim.api.nvim_create_autocmd("FileType", {group = group, pattern = filetypes0, callback = _16_})
end
M["register-group!"] = function(id, name, prefix, ...)
  local opts, _ = group_options(...)
  _G.kgroups[id] = {name = name, prefix = prefix, opts = opts}
  return nil
end
local function group_spec(prefix, name, opts)
  return merge_21({prefix, group = name}, opts)
end
M.kgroup = function(id, name, prefix, ...)
  local opts, items = group_options(...)
  M["register-group!"](id, name, prefix, opts)
  local specs = {group_spec(prefix, name, opts)}
  for _, item in ipairs(items) do
    add_prefixed_21(specs, prefix, item)
  end
  return specs
end
M.group = function(id, ...)
  local registered = _G.kgroups[id]
  if not registered then
    error(("Unknown key group: " .. id .. "\nAvailable groups: " .. _G.vim.inspect(_G.kgroups)))
  else
  end
  local specs = {group_spec(registered.prefix, registered.name, registered.opts)}
  for _, item in ipairs({...}) do
    add_prefixed_21(specs, registered.prefix, item)
  end
  return specs
end
return M
