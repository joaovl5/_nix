-- [nfnl] fnl/lib/plugins.fnl
local function opt(key)
  local function _1_(value)
    return {[key] = value}
  end
  return _1_
end
_G.which_key_plugin_icon_specs = (_G.which_key_plugin_icon_specs or {})
local function copy_key(target, source, key)
  local value = source[key]
  if value then
    target[key] = value
    return nil
  else
    return nil
  end
end
local function which_key_icon_spec(spec)
  if spec.icon then
    local icon_spec = {spec[1], icon = spec.icon}
    copy_key(icon_spec, spec, "desc")
    copy_key(icon_spec, spec, "group")
    copy_key(icon_spec, spec, "mode")
    return icon_spec
  else
    return nil
  end
end
local function add_which_key_icon_spec_21(spec)
  local icon_spec = which_key_icon_spec(spec)
  if icon_spec then
    return table.insert(_G.which_key_plugin_icon_specs, icon_spec)
  else
    return nil
  end
end
local function lazy_key_spec(spec)
  local copied = {}
  for key, value in pairs(spec) do
    if (key ~= "icon") then
      copied[key] = value
    else
    end
  end
  return copied
end
local function add_lazy_key_spec_21(specs, spec)
  add_which_key_icon_spec_21(spec)
  return table.insert(specs, lazy_key_spec(spec))
end
local function keys(...)
  local specs = {}
  for _, item in ipairs({...}) do
    if ((type(item) == "table") and (type(item[1]) == "table")) then
      for _0, spec in ipairs(item) do
        add_lazy_key_spec_21(specs, spec)
      end
    else
      add_lazy_key_spec_21(specs, item)
    end
  end
  return {keys = specs}
end
return {event = opt("event"), ft = opt("ft"), keys = keys, opts = opt("opts"), deps = opt("dependencies"), prio = opt("priority"), priority = opt("priority"), version = opt("version"), enabled = opt("enabled"), cmd = opt("cmd"), lazy = opt("lazy"), config = opt("config"), init = opt("init"), builtin = opt("builtin"), main = opt("main")}
