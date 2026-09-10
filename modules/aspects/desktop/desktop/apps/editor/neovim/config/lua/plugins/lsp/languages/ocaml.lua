-- [nfnl] fnl/plugins/lsp/languages/ocaml.fnl
local _local_1_ = require("lib/nvim")
local v_2fautocmd = _local_1_["v/autocmd"]
local v_2fmap = _local_1_["v/map"]
local function hover(client, bufnr)
  local win = vim.api.nvim_get_current_win()
  local cursor = vim.api.nvim_win_get_cursor(win)
  local params = vim.lsp.util.make_position_params(win, client.offset_encoding)
  params.verbosity = 2147483647
  local function _2_(err, result)
    if ((bufnr == vim.api.nvim_get_current_buf()) and (win == vim.api.nvim_get_current_win()) and vim.deep_equal(cursor, vim.api.nvim_win_get_cursor(win))) then
      if err then
        return vim.notify(err.message, vim.log.levels.ERROR)
      elseif (not result or not result.contents) then
        return vim.notify("No information available", vim.log.levels.INFO)
      else
        local lines = vim.lsp.util.convert_input_to_markdown_lines(result.contents)
        if (0 == #lines) then
          return vim.notify("No information available", vim.log.levels.INFO)
        else
          return vim.lsp.util.open_floating_preview(lines, "markdown", {border = "none", focus_id = "ocaml_hover"})
        end
      end
    else
      return nil
    end
  end
  return client:request("ocamllsp/hoverExtended", params, _2_, bufnr)
end
local function setup()
  require("ocaml").setup({})
  local function _6_(event)
    local client = vim.lsp.get_client_by_id(event.data.client_id)
    if (client and (client.name == "ocamllsp")) then
      local function _7_()
        return hover(client, event.buf)
      end
      return v_2fmap("n", "K", _7_, {buffer = event.buf, desc = "OCaml hover (maximum verbosity)"})
    else
      return nil
    end
  end
  return v_2fautocmd("LspAttach", {group = vim.api.nvim_create_augroup("ocaml_hover", {clear = true}), callback = _6_})
end
return {{"tarides/ocaml.nvim", config = setup, lazy = false}}
