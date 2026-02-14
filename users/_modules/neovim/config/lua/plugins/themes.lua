-- [nfnl] fnl/plugins/themes.fnl
local _local_1_ = require("./lib/utils")
local nil_3f = _local_1_["nil?"]
local function _2_()
  vim.g.mellow_italic_comments = true
  return nil
end
local function _3_()
  local name_2_auto = require("teide")
  local fun_3_auto = name_2_auto.setup
  return fun_3_auto({style = "darker", transparent = true, dim_inactive = true})
end
_G.Config.themes = {{source = "nyoom-engineering/oxocarbon.nvim", names = {"oxocarbon"}}, {source = "mellow-theme/mellow.nvim", names = {"mellow"}, post_add = _2_}, {source = "embark-theme/vim", names = {"embark"}}, {source = "eldritch-theme/eldritch.nvim", names = {"eldritch", "eldritch-dark", "eldritch-minimal"}}, {source = "serhez/teide.nvim", post_add = _3_, names = {"teide-darker", "teide-dark", "teide-dimmed"}}, {source = "uhs-robert/oasis.nvim", names = {"oasis-midnight", "oasis-abyss", "oasis-starlight", "oasis-desert", "oasis-sol", "oasis-canyon", "oasis-dune", "oasis-cactus", "oasis-lagoon", "oasis-twilight", "oasis-rose"}}}
local tbl_26_ = {}
local i_27_ = 0
for _, t in ipairs(_G.Config.themes) do
  local val_28_
  local function _4_()
    if not nil_3f(t.post_add) then
      return t.post_add
    else
      return nil
    end
  end
  val_28_ = {t.source, lazy = true, priority = 1000, config = _4_}
  if (nil ~= val_28_) then
    i_27_ = (i_27_ + 1)
    tbl_26_[i_27_] = val_28_
  else
  end
end
return tbl_26_
