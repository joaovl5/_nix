-- [nfnl] fnl/plugins/ui/statusline.fnl
local function opt_req(m)
  local ok, mod = pcall(require, m)
  return ok
end
local function incline_render(props)
  local filename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(props.buf), ":t")
  local ft_icon, ft_color
  if opt_req("nvim-web-devicons") then
    local name_2_auto = require("nvim-web-devicons")
    local fun_3_auto = name_2_auto.get_icon_color
    ft_icon, ft_color = fun_3_auto(filename)
  else
    ft_icon, ft_color = {nil, nil}
  end
  local modified = vim.bo[props.buf].modified
  local helpers = require("incline.helpers")
  local icon
  if (ft_icon ~= nil) then
    local _2_
    if (ft_color ~= nil) then
      _2_ = helpers.contrast_color(ft_color)
    else
      _2_ = "#FF0000"
    end
    icon = {" ", ft_icon, " ", guibg = ft_color, guifg = _2_}
  else
    icon = {}
  end
  if (filename == "") then
    return {"-/-"}
  else
    local _5_
    if modified then
      _5_ = "bold,italic"
    else
      _5_ = "bold"
    end
    return {icon, " ", " ", {filename, gui = _5_}}
  end
end
return {{"beauwilliams/statusline.lua", dependencies = {"nvim-lua/lsp-status.nvim"}, opts = {match_colorscheme = true, tabline = true, lsp_diagnostics = true, ale_diagnostics = true}}, {"b0o/incline.nvim", opts = {window = {padding = 0, margin = {horizontal = 1, vertical = 0}}, render = incline_render}}}
