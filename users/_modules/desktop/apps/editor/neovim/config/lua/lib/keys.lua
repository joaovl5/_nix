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
  local _3_
  if key_option_3f(_3frhs) then
    _3_ = nil
  else
    _3_ = _3frhs
  end
  return {key_spec(lhs, _3_, opts)}
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
M["register-group!"] = function(id, name, prefix)
  _G.kgroups[id] = {name = name, prefix = prefix}
  return nil
end
M.kgroup = function(id, name, prefix, ...)
  M["register-group!"](id, name, prefix)
  local specs = {{prefix, group = name}}
  for _, item in ipairs({...}) do
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
  local specs = {{registered.prefix, group = registered.name}}
  for _, item in ipairs({...}) do
    add_prefixed_21(specs, registered.prefix, item)
  end
  return specs
end
return M
