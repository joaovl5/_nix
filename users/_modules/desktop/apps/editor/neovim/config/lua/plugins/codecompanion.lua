-- [nfnl] fnl/plugins/codecompanion.fnl
local _local_1_ = require("lib/nvim")
local v_2fstdpath = _local_1_["v/stdpath"]
local v_2fcwd = _local_1_["v/cwd"]
local function setup_cc()
  local models = {base = "minimax/minimax-m2.7"}
  local interactions
  do
    local adap
    local function _2_(_241)
      return {adapter = _241}
    end
    adap = _2_
    interactions = {chat = {adapter = "openrouter", model = models.base, tools = {opts = {auto_submit_errors = true}}}, inline = adap("openrouter"), cmd = adap("openrouter"), background = adap("openrouter")}
  end
  local extensions
  local function _3_(_241)
    return (_241.cwd == v_2fcwd())
  end
  extensions = {spinner = {}, history = {enabled = true, dir_to_save = (v_2fstdpath("data") .. "/codecompanion_chats.json"), opts = {expiration_days = 7, chat_filter = _3_}}}
  local adapters
  local function _4_()
    local name_1_auto = require("codecompanion.adapters")
    local fun_2_auto = name_1_auto.extend
    return fun_2_auto("openai_compatible", {env = {api_key = "OPENROUTER_API_KEY", url = "https://openrouter.ai/api"}, name = "openrouter", formatted_name = "Openrouter API"})
  end
  adapters = {http = {openrouter = _4_}}
  return {interactions = interactions, extensions = extensions, adapters = adapters}
end
local _5_ = require("lib.plugins")
local _6_ = require("lib.keys")
local spec_21_auto = {}
for __22_auto, attrs_23_auto in ipairs({_5_.version("^18.0.0"), _5_.deps({"nvim-lua/plenary.nvim", "nvim-treesitter/nvim-treesitter", "ravitemer/codecompanion-history.nvim", "franco-ruggeri/codecompanion-spinner.nvim"}), _5_.keys(_6_.group("ai", _6_.bind("a", _6_.cmd("CodeCompanionActions"), _6_.desc("Actions"), _6_.m("n", "v")), _6_.bind("c", _6_.cmd("CodeCompanionChat Toggle"), _6_.desc("Chat"), _6_.m("n", "v")), _6_.bind("r", _6_.cmd("CodeCompanionCmd"), _6_.desc("Run command"), _6_.m("n", "v")), _6_.bind("l", _6_.cmd("CodeCompanion"), _6_.desc("Inline Assist"), _6_.m("n", "v")))), _5_.opts(setup_cc)}) do
  for key_24_auto, value_25_auto in pairs(attrs_23_auto) do
    spec_21_auto[key_24_auto] = value_25_auto
  end
end
spec_21_auto[1] = "olimorris/codecompanion.nvim"
return spec_21_auto
