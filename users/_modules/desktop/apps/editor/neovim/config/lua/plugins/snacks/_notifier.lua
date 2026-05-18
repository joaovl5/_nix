-- [nfnl] fnl/plugins/snacks/_notifier.fnl
local function _1_(_)
  return (vim.fn.getcmdpos() > 0)
end
return {enabled = true, width = {min = 60, max = 0.4}, height = {min = 2, max = 0.6}, margin = {top = 1, right = 1, bottom = 0}, padding = true, gap = 1, sort = {"level", "added"}, level = vim.log.levels.TRACE, icons = {error = "\239\129\151 ", warn = "\239\129\177 ", info = "\239\129\154 ", debug = "\239\134\136 ", trace = "\238\182\166 "}, keep = _1_, style = "minimal", top_down = true, date_format = "%R", more_format = " \226\134\147 %d lines ", refresh = 50}
