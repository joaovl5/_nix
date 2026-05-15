-- [nfnl] fnl/lib/utils.fnl
local function nil_3f(x)
  return (nil == x)
end
local function str_3f(x)
  return ("string" == type(x))
end
local function num_3f(x)
  return ("number" == type(x))
end
local function bool_3f(x)
  return ("boolean" == type(x))
end
local function fn_3f(x)
  return ("function" == type(x))
end
local function tbl_3f(x)
  return ("table" == type(x))
end
local function __3estr(x)
  return tostring(x)
end
local function __3ebool(x)
  if x then
    return true
  else
    return false
  end
end
local function merge(a, b)
  for k, v in pairs(b) do
    a[k] = v
  end
  return nil
end
return {["nil?"] = nil_3f, ["str?"] = str_3f, ["num?"] = num_3f, ["bool?"] = bool_3f, ["fn?"] = fn_3f, ["tbl?"] = tbl_3f, ["->str"] = __3estr, ["->bool"] = __3ebool, merge = merge}
