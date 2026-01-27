-- [nfnl] fnl/plugins/mini/map.fnl
local function _1_()
  local map = require("mini.map")
  return {symbols = {encode = map.gen_encode_symbols.dot("4x2")}, integrations = {map.gen_integration.builtin_search(), map.gen_integration.diff(), map.gen_integration.diagnostic()}}
end
return {"nvim-mini/mini.map", version = "*", opts = _1_}
