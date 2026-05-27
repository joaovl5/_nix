-- [nfnl] fnl/lib/utils.fnl
local M = {}
M["nil?"] = function(x)
  return (nil == x)
end
M["str?"] = function(x)
  return ("string" == type(x))
end
M["num?"] = function(x)
  return ("number" == type(x))
end
M["bool?"] = function(x)
  return ("boolean" == type(x))
end
M["fn?"] = function(x)
  return ("function" == type(x))
end
M["tbl?"] = function(x)
  return ("table" == type(x))
end
M["->str"] = function(x)
  return tostring(x)
end
M["->lower"] = function(x)
  return string.lower(M["->str"](x))
end
M["->bool"] = function(x)
  if x then
    return true
  else
    return false
  end
end
M.merge = function(a, b)
  for k, v in pairs(b) do
    a[k] = v
  end
  return nil
end
return M
