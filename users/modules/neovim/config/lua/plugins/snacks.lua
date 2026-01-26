-- [nfnl] fnl/plugins/snacks.fnl
local function _1_(_)
  return (vim.fn.getcmdpos() > 0)
end
return {"folke/snacks.nvim", opts = {bigfile = {enabled = true}, quickfile = {enabled = true}, notify = {enabled = true}, notifier = {enabled = true, width = {min = 50, max = 0.4}, height = {min = 1, max = 0.6}, margin = {top = 2, right = 1, bottom = 0}, padding = true, gap = 0, sort = {"level", "added"}, level = vim.log.levels.TRACE, icons = {error = "\239\129\151 ", warn = "\239\129\177 ", info = "\239\129\154 ", debug = "\239\134\136 ", trace = "\238\182\166 "}, keep = _1_, style = "minimal", top_down = true, date_format = "%R", more_format = " \226\134\147 %d lines ", refresh = 50}, input = {enabled = true}, image = {enabled = true}}}
