-- [nfnl] fnl/plugins/snacks/_picker.fnl
local function k(rhs)
  return {rhs, mode = {"i", "n"}}
end
local keyset = {["/"] = "toggle_focus", ["<A-j>"] = k("list_down"), ["<A-k>"] = k("list_up"), ["<CR>"] = k("confirm"), ["<A-S-k>"] = k("toggle_hidden"), ["<A-S-l>"] = k("toggle_ignored"), ["<C-h>"] = k("history_back"), ["<C-l>"] = k("history_forward"), ["<A-w>"] = k("cycle_win"), ["<A-a>"] = k("select_all"), ["<c-w>G"] = k("list_bottom"), ["<c-w>gg"] = k("list_top"), ["<c-w>h"] = k("layout_left"), ["<c-w>j"] = k("layout_bottom"), ["<c-w>k"] = k("layout_top"), ["<c-w>l"] = k("layout_right")}
local _1_
do
  local filter
  local function _2_(x, _)
    local _4_
    do
      local t_3_ = x
      if (nil ~= t_3_) then
        t_3_ = t_3_.file
      else
      end
      _4_ = t_3_
    end
    return not vim.endswith((_4_ or ""), ".lua")
  end
  filter = {filter = _2_}
  local exc = {hidden = true, include = {".env"}, exclude = {"*.lua"}, filter = filter}
  _1_ = {files = exc, grep = exc, explorer = exc, recent = {filter = filter}}
end
return {prompt = "> ", show_delay = 100, layout = {preset = "vscode", layout = {width = 0.7, row = 10, border = "none"}}, sources = _1_, matcher = {fuzzy = true, smartcase = true, cwd_bonus = true, frecency = true, history_bonus = true}, ui_select = "true", win = {input = {keys = keyset}, list = {keys = keyset}, preview = {keys = keyset}}, previewers = {diff = {style = "fancy", cmd = {"delta"}, wo = {breakindent = true, wrap = true, linebreak = true, showbreak = ""}}}}
