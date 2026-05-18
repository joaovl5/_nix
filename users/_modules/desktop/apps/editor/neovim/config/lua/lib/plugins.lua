-- [nfnl] fnl/lib/plugins.fnl
local function opt(key)
  local function _1_(value)
    return {[key] = value}
  end
  return _1_
end
local function keys(...)
  local specs = {}
  for _, item in ipairs({...}) do
    if ((type(item) == "table") and (type(item[1]) == "table")) then
      for _0, spec in ipairs(item) do
        table.insert(specs, spec)
      end
    else
      table.insert(specs, item)
    end
  end
  return {keys = specs}
end
return {event = opt("event"), ft = opt("ft"), keys = keys, opts = opt("opts"), deps = opt("dependencies"), prio = opt("priority"), priority = opt("priority"), version = opt("version"), cmd = opt("cmd"), lazy = opt("lazy"), config = opt("config"), init = opt("init"), builtin = opt("builtin"), main = opt("main")}
