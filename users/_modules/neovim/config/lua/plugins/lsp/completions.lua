-- [nfnl] fnl/plugins/lsp/completions.fnl
local function build_blink(params)
  vim.notify("Building Blink", vim.log.levels.INFO)
  local res = vim.system({"cargo", "build", "--release"}, {cwd = params.path}):wait()
  if (0 == res.code) then
    return vim.notify("Building Blink done", vim.log.levels.INFO)
  else
    return vim.notify("Building Blink failed", vim.log.levels.ERROR)
  end
end
local function _get_mini_icon_data(ctx)
  local function _2_()
    local name_2_auto = require("mini.icons")
    local fun_3_auto = name_2_auto.get
    return fun_3_auto("lsp", ctx.kind)
  end
  local _local_3_ = _2_()
  local k_icon = _local_3_[1]
  local k_hl = _local_3_[2]
  local _ = _local_3_[3]
  return {k_icon, k_hl}
end
local function get_mini_icon(ctx)
  local _local_4_ = _get_mini_icon_data(ctx)
  local k_icon = _local_4_[1]
  local _ = _local_4_[2]
  return k_icon
end
local function get_mini_icon_hl(ctx)
  local _local_5_ = _get_mini_icon_data(ctx)
  local _ = _local_5_[1]
  local k_hl = _local_5_[2]
  return k_hl
end
local source_symbols = {lsp = "\240\159\147\154", path = "\240\159\147\129", snippets = "\226\156\130\239\184\143"}
local function get_source_txt(ctx)
  return source_symbols[ctx.item.source_id]
end
local _6_
do
  local def_sources = {"lazydev", "lsp", "path", "calc", "snippets", "buffer"}
  local dbg_sources = {"dap", unpack(def_sources)}
  local completion_winhl = "Normal:Normal,FloatBorder:FloatBorder,CursorLine:BlinkCmpMenuSelection,Search:None"
  local function _7_()
    local name_2_auto = require("cmp_dap")
    local fun_3_auto = name_2_auto.is_dap_buffer
    return fun_3_auto()
  end
  local function _8_(opts)
    if (opts.item and opts.item.documentation and opts.item.documentation.value) then
      local parsed
      do
        local name_2_auto = require("pretty_hover.parser")
        local fun_3_auto = name_2_auto.parse
        parsed = fun_3_auto(opts.item.documentation.value)
      end
      opts.item.documentation.value = parsed:string()
    else
    end
    return opts.default_implementation(opts)
  end
  _6_ = {keymap = {preset = "super-tab"}, signature = {enabled = true, window = {border = "none", scrollbar = false}}, sources = {default = def_sources, per_filetype = {["dap-repl"] = dbg_sources, ["dap-view"] = dbg_sources}, providers = {lazydev = {module = "lazydev.integrations.blink", score_offset = 100}, calc = {name = "calc", module = "blink.compat.source"}, dap = {name = "dap", module = "blink.compat.source", enabled = _7_}}}, appearance = {kind_icons = {Snippet = "\226\156\130\239\184\143"}}, cmdline = {completion = {menu = {auto_show = false}, ghost_text = {enabled = true}, list = {selection = {preselect = true, auto_insert = false}}}}, completion = {keyword = {range = "prefix"}, list = {selection = {preselect = true, auto_insert = true}}, accept = {auto_brackets = {enabled = true}}, menu = {min_width = 20, border = "rounded", winhighlight = completion_winhl, draw = {columns = {{"kind_icon"}, {"label"}, {"source"}}, components = {kind_icon = {text = get_mini_icon, highlight = get_mini_icon_hl}, kind = {highlight = get_mini_icon_hl}, source = {text = get_source_txt, highlight = "BlinkCmpDoc"}}}}, documentation = {auto_show = true, auto_show_delay_ms = 0, update_delay_ms = 50, window = {max_width = 200, border = "rounded"}, draw = _8_}}}
end
return {"saghen/blink.cmp", dependencies = {"rafamadriz/friendly-snippets", {"saghen/blink.compat", opts = true}}, build = build_blink, opts = _6_}
