-- [nfnl] fnl/plugins/ui/notifications.fnl
local _local_1_ = require("./lib/nvim")
local v_2fautocmd = _local_1_["v/autocmd"]
local v_2fuv = _local_1_["v/uv"]
local lsp_status_width = 40
local lsp_status_timeout_ms = 1500
local spinner_frames = {"\226\163\190", "\226\163\189", "\226\163\187", "\226\162\191", "\226\161\191", "\226\163\159", "\226\163\175", "\226\163\183"}
local lsp_notification = {record = nil, message = nil, icon = 1, ["last-update"] = 0, spinning = false}
local function now_ms()
  return (v_2fuv.hrtime() / 1000000)
end
local function non_empty_3f(value)
  return (("string" == type(value)) and (0 < #value))
end
local function contains_plain_3f(value, needle)
  return (non_empty_3f(value) and (nil ~= string.find(value, needle, 1, true)))
end
local function ignored_lsp_status_3f(data, message)
  local params = (data and data.params)
  local value = (params and params.value)
  local title = (("table" == type(value)) and value.title)
  local value_message = (("table" == type(value)) and value.message)
  return (contains_plain_3f(message, "diagnostics_on_open") or contains_plain_3f(title, "diagnostics_on_open") or contains_plain_3f(value_message, "diagnostics_on_open") or contains_plain_3f(title, "diagnostics") or contains_plain_3f(value_message, "diagnostics"))
end
local function fit_line(line, width)
  local text = (line or "")
  while (vim.api.nvim_strwidth(text) > width) do
    local chars = vim.fn.strchars(text)
    if (chars <= 2) then
      text = ""
    else
      text = (vim.fn.strcharpart(text, 0, (chars - 2)) .. "\226\128\166")
    end
  end
  return (text .. string.rep(" ", math.max(0, (width - vim.api.nvim_strwidth(text)))))
end
local function render_lsp_status(bufnr, notif, highlights, config)
  require("notify.render.compact")(bufnr, notif, highlights, config)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local function _3_()
    local tbl_26_ = {}
    local i_27_ = 0
    for _, line in ipairs(lines) do
      local val_28_ = fit_line(line, lsp_status_width)
      if (nil ~= val_28_) then
        i_27_ = (i_27_ + 1)
        tbl_26_[i_27_] = val_28_
      else
      end
    end
    return tbl_26_
  end
  return vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, _3_())
end
local function set_lsp_record(record)
  lsp_notification.record = record
  return nil
end
local function notify_lsp_status_message(icon)
  local function _5_()
    return set_lsp_record(nil)
  end
  return set_lsp_record(vim.notify(lsp_notification.message, "info", {id = "lsp-status-updates", replace = lsp_notification.record, title = "LSP", icon = icon, timeout = lsp_status_timeout_ms, hide_from_history = true, render = render_lsp_status, on_close = _5_}))
end
local function update_lsp_spinner()
  if (lsp_notification.spinning and lsp_notification.record and lsp_notification.message and ((now_ms() - lsp_notification["last-update"]) < lsp_status_timeout_ms)) then
    lsp_notification.icon = ((lsp_notification.icon % #spinner_frames) + 1)
    notify_lsp_status_message(spinner_frames[lsp_notification.icon])
    return vim.defer_fn(update_lsp_spinner, 100)
  else
    lsp_notification.spinning = false
    return nil
  end
end
local function start_lsp_spinner()
  if not lsp_notification.spinning then
    lsp_notification.spinning = true
    return vim.defer_fn(update_lsp_spinner, 100)
  else
    return nil
  end
end
local function notify_lsp_status(data)
  local message = vim.lsp.status()
  if (non_empty_3f(message) and not ignored_lsp_status_3f(data, message)) then
    lsp_notification.message = message
    lsp_notification["last-update"] = now_ms()
    notify_lsp_status_message(spinner_frames[lsp_notification.icon])
    return start_lsp_spinner()
  else
    return nil
  end
end
local function setup_lsp_status_updates()
  local group = vim.api.nvim_create_augroup("lsp-notify-status-updates", {clear = true})
  local function _9_(ev)
    local data = ev.data
    local function _10_()
      return notify_lsp_status(data)
    end
    return vim.schedule(_10_)
  end
  return v_2fautocmd("LspProgress", {group = group, callback = _9_})
end
local function setup_notify()
  local notify = require("notify")
  notify.setup({render = "wrapped-compact", minimum_width = 40, stages = "static"})
  vim.notify = notify
  return nil
end
local _11_ = require("lib.plugins")
local _12_ = require("lib.keys")
local spec_24_auto = {}
for __25_auto, attrs_26_auto in ipairs({_11_.lazy(false), _11_.priority(999), _11_.keys(_12_.group("diagnostics", _12_.bind("j", _12_.cmd("Notifications"), _12_.desc("Notifications")))), _11_.config(setup_notify)}) do
  for key_27_auto, value_28_auto in pairs(attrs_26_auto) do
    spec_24_auto[key_27_auto] = value_28_auto
  end
end
spec_24_auto[1] = "rcarriga/nvim-notify"
return spec_24_auto
