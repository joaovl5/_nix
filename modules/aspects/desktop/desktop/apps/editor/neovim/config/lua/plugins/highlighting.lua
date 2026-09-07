-- [nfnl] fnl/plugins/highlighting.fnl
local _local_1_ = require("lib/nvim")
local v_2fautocmd = _local_1_["v/autocmd"]
local v_2fcontains_3f = _local_1_["v/contains?"]
local v_2flater = _local_1_["v/later"]
vim.filetype.add({extension = {kbd = "kanata"}})
local function _2_()
  require("nvim-treesitter.parsers")["kanata"] = {install_info = {branch = "master", url = "https://github.com/postsolar/tree-sitter-kanata"}}
  return nil
end
v_2fautocmd("User", {pattern = "TSUpdate", callback = _2_})
vim.treesitter.language.register("kanata", "kanata")
local function start_treesitter(buf, lang)
  if vim.api.nvim_buf_is_valid(buf) then
    local ok, err = pcall(vim.treesitter.start, buf, lang)
    if not ok then
      return vim.notify(("Failed to start Tree-sitter for " .. lang .. ":\n" .. tostring(err)), vim.log.levels.ERROR)
    else
      return nil
    end
  else
    return nil
  end
end
local function install_and_start(ts, buf, lang)
  local function _5_(err, installed)
    if err then
      return vim.notify(("Failed to install the Tree-sitter parser for " .. lang .. ".\n" .. tostring(err)), vim.log.levels.ERROR)
    else
      if installed then
        local function _6_()
          return start_treesitter(buf, lang)
        end
        return v_2flater(_6_)
      else
        return nil
      end
    end
  end
  return ts.install(lang):await(_5_)
end
local function setup()
  local ts = require("nvim-treesitter")
  local available = ts.get_available()
  local function _9_(ev)
    local lang = vim.treesitter.language.get_lang(ev.match)
    if v_2fcontains_3f(available, lang) then
      if v_2fcontains_3f(ts.get_installed("parsers"), lang) then
        return start_treesitter(ev.buf, lang)
      else
        return install_and_start(ts, ev.buf, lang)
      end
    else
      return nil
    end
  end
  return v_2fautocmd("FileType", {callback = _9_})
end
return {{"nvim-treesitter/nvim-treesitter", branch = "main", build = ":TSUpdate", config = setup, lazy = false}, {"auipga/hmts.nvim", branch = "patch-1"}, {"m-demare/hlargs.nvim", event = "VeryLazy", opts = {}}}
