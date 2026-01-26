-- [nfnl] fnl/plugins/lsp/init.fnl
local plugins = {"config", "formatting", "misc", "languages"}
local tbl_26_ = {}
local i_27_ = 0
for _, plugin in ipairs(plugins) do
  local val_28_ = require(("plugins.lsp." .. plugin))
  if (nil ~= val_28_) then
    i_27_ = (i_27_ + 1)
    tbl_26_[i_27_] = val_28_
  else
  end
end
return tbl_26_
