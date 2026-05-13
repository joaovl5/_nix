-- [nfnl] fnl/plugins/flatten.fnl
local nvim = require("lib/nvim")
local function current_snacks_terminal()
  local list_terminals
  do
    local t_1_ = Snacks
    if nil ~= t_1_ then
      t_1_ = t_1_.terminal
    else
    end
    if nil ~= t_1_ then
      t_1_ = t_1_.list
    else
    end
    list_terminals = t_1_
  end
  if list_terminals then
    local bufnr = vim.api.nvim_get_current_buf()
    local current = nil
    for _, terminal in ipairs(list_terminals()) do
      if not current and (terminal.buf == bufnr) then
        current = terminal
      else
      end
    end
    return current
  else
    return nil
  end
end
local function snacks_terminal_state(terminal)
  if
    terminal
    and terminal.buf
    and vim.api.nvim_buf_is_valid(terminal.buf)
  then
    local ok, state =
      pcall(vim.api.nvim_buf_get_var, terminal.buf, "snacks_terminal")
    if ok then
      return state
    else
      return nil
    end
  else
    return nil
  end
end
local function lazygit_terminal_3f(terminal)
  local state = snacks_terminal_state(terminal)
  return (state and ((state.cmd == "lazygit") or (state.id == "lazygit")))
end
local function hide_terminal(terminal, winnr)
  if terminal and (terminal.win ~= winnr) and terminal:valid() then
    return terminal:hide()
  else
    return nil
  end
end
local function handle_should_block(argv)
  return vim.tbl_contains(argv, "-b")
end
local function register_autocmd(bufnr)
  local callback
  local function _9_()
    return vim.api.nvim_buf_delete(bufnr)
  end
  callback = _9_
  return nvim.autocmd(
    "BufWritePost",
    { buffer = bufnr, once = true, callback = vim.schedule_wrap(callback) }
  )
end
local function flatten_setup()
  local saved_terminal = nil
  local function handle_pre_open(_)
    saved_terminal = current_snacks_terminal()
    return nil
  end
  local function handle_post_open(opts)
    local bufnr = opts.bufnr
    local winnr = opts.winnr
    local ft = opts.filetype
    if opts.is_blocking then
      hide_terminal(saved_terminal, winnr)
    else
      if lazygit_terminal_3f(saved_terminal) then
        hide_terminal(saved_terminal, winnr)
      else
      end
      if winnr and vim.api.nvim_win_is_valid(winnr) then
        vim.api.nvim_set_current_win(winnr)
      else
      end
      saved_terminal = nil
    end
    if (ft == "gitcommit") or (ft == "gitrebase") then
      return register_autocmd(bufnr)
    else
      return nil
    end
  end
  local function handle_block_end(_opts)
    local cb
    local function _14_()
      if saved_terminal then
        if saved_terminal:buf_valid() then
          saved_terminal:show()
        else
        end
        saved_terminal = nil
        return nil
      else
        return nil
      end
    end
    cb = _14_
    return vim.schedule(cb)
  end
  return {
    nest_if_no_args = true,
    nest_if_cmds = true,
    window = { open = "alternate", diff = "split", focus = "first" },
    hooks = {
      should_block = handle_should_block,
      pre_open = handle_pre_open,
      post_open = handle_post_open,
      block_end = handle_block_end,
    },
  }
end
return {
  {
    "willothy/flatten.nvim",
    opts = flatten_setup,
    priority = 1001,
    lazy = false,
  },
}
