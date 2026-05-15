-- [nfnl] fnl/lib/plugins.fnl
local function event(value)
  return {event = value}
end
local function ft(value)
  return {ft = value}
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
local function opts(value)
  return {opts = value}
end
local function dependencies(value)
  return {dependencies = value}
end
local function version(value)
  return {version = value}
end
local function cmd(value)
  return {cmd = value}
end
return {event = event, ft = ft, keys = keys, opts = opts, dependencies = dependencies, version = version, cmd = cmd}
