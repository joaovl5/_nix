-- [nfnl] fnl/lib/keys.fnl
local function l(lhs)
  return ("<leader>" .. lhs)
end
local function c(key)
  return ("<C-" .. key .. ">")
end
local function a(key)
  return ("<A-" .. key .. ">")
end
local function cmd(command)
  return ("<cmd>" .. command .. "<cr>")
end
local function desc(text)
  return {desc = text}
end
local function m(mode, ...)
  return {["__keys-kind"] = "mode-group", mode = mode, lhs = {...}}
end
local function merge_21(target, source)
  for key, value in pairs(source) do
    target[key] = value
  end
  return target
end
local function grouped_3f(lhs)
  return ((type(lhs) == "table") and (lhs["__keys-kind"] == "mode-group"))
end
local function key_spec(lhs, rhs, opts, _3fmode)
  local spec = merge_21({lhs, rhs}, opts)
  if _3fmode then
    spec["mode"] = _3fmode
  else
  end
  return spec
end
local function bind(lhs, rhs, ...)
  local opts = {}
  local specs = {}
  for _, opt in ipairs({...}) do
    merge_21(opts, opt)
  end
  if grouped_3f(lhs) then
    for _, grouped_lhs in ipairs(lhs.lhs) do
      table.insert(specs, key_spec(grouped_lhs, rhs, opts, lhs.mode))
    end
  elseif ((type(lhs) == "table") and grouped_3f(lhs[1])) then
    for _, group in ipairs(lhs) do
      for _0, grouped_lhs in ipairs(group.lhs) do
        table.insert(specs, key_spec(grouped_lhs, rhs, opts, group.mode))
      end
    end
  else
    table.insert(specs, key_spec(lhs, rhs, opts))
  end
  return specs
end
return {l = l, c = c, a = a, cmd = cmd, desc = desc, m = m, bind = bind}
