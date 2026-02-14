-- [nfnl] fnl/keymaps.fnl
local n = require("lib/nvim")
require("plugins.whichkey")
local wk = require("which-key")
local function km(key, opts, what)
  opts[1] = key
  opts[2] = what
  return opts
end
local function toggle_term(_, cmd)
  return Snacks.terminal.toggle(cmd, {})
end
n.map({"n"}, "<Esc>", "<cmd>nohlsearch<CR>", {desc = "Clear Search Highlights"})
n.map({"t"}, "<Esc><Esc>", "<C-\\><C-n>", {desc = "Exit terminal mode"})
n.map({"n"}, "<Esc>", "<cmd>nohlsearch<CR>", {desc = "Clear Search Highlights"})
n.map({"x"}, "p", "\"_dP")
n.map({"n"}, "<C-d>", "<C-d>zz")
n.map({"n"}, "<C-u>", "<C-u>zz")
n.map({"n"}, "n", "nzzzv")
n.map({"n"}, "N", "Nzzzv")
n.map({"x"}, ">", ">gv", {noremap = true})
n.map({"x"}, "<", "<gv", {noremap = true})
local function _1_()
  local name_2_auto = require("flash")
  local fun_3_auto = name_2_auto.jump
  return fun_3_auto()
end
n.map({"n", "x", "o"}, "s", _1_)
local function _2_()
  local name_2_auto = require("flash")
  local fun_3_auto = name_2_auto.treesitter
  return fun_3_auto()
end
n.map({"n", "x", "o"}, "S", _2_)
local function _3_()
  do
    local name_2_auto = require("flash")
    local fun_3_auto = name_2_auto.remote
    fun_3_auto()
  end
  return {desc = "Remote flash"}
end
n.map({"o"}, "r", _3_)
local function _4_()
  local name_2_auto = require("spider")
  local fun_3_auto = name_2_auto.motion
  return fun_3_auto("w")
end
n.map({"n", "x", "o"}, "w", _4_)
local function _5_()
  local name_2_auto = require("spider")
  local fun_3_auto = name_2_auto.motion
  return fun_3_auto("e")
end
n.map({"n", "x", "o"}, "e", _5_)
local function _6_()
  local name_2_auto = require("spider")
  local fun_3_auto = name_2_auto.motion
  return fun_3_auto("b")
end
n.map({"n", "x", "o"}, "b", _6_)
n.map({"n", "x"}, "<A-[>", "<cmd>Treewalker Left<cr>")
n.map({"n", "x"}, "<A-]>", "<cmd>Treewalker Right<cr>")
n.map({"n", "x"}, "<A-k>", "<cmd>Treewalker Up<cr>")
n.map({"n", "x"}, "<A-j>", "<cmd>Treewalker Down<cr>")
n.map({"n", "x"}, "<A-S-[>", "<cmd>Treewalker SwapLeft<cr>")
n.map({"n", "x"}, "<A-S-]>", "<cmd>Treewalker SwapRight<cr>")
n.map({"n", "x"}, "<A-K>", "<cmd>Treewalker SwapUp<cr>")
n.map({"n", "x"}, "<A-J>", "<cmd>Treewalker SwapDown<cr>")
wk.add({km("<leader>q", {group = "Tab"}), km("<leader>qc", {desc = "Create"}, "<cmd>tabnew<CR>"), km("<leader>ql", {desc = "Next"}, "<cmd>tabnext<CR>"), km("<leader>qh", {desc = "Prev"}, "<cmd>tabprev<CR>"), km("<leader>qd", {desc = "Close"}, "<cmd>tabclose<CR>")})
local function _7_()
  local name_2_auto = require("zen-mode")
  local fun_3_auto = name_2_auto.toggle
  return fun_3_auto({})
end
wk.add({km("<leader>w", {group = "Window"}), km("<leader>wr", {desc = "Resize to default!!"}, "<Cmd>lua MiniMisc.resize_window()<CR>"), km("<leader>wz", {desc = "Zen mode"}, _7_), km("<leader>wd", {desc = "Quit window"}, "<Cmd>quit<CR>"), km("<leader>wD", {desc = "Quit all windows"}, "<Cmd>quitall<CR>"), km("<leader>ww", {desc = "Alternate window buffers"}, "<Cmd>b#<CR>"), km("<leader>|", {desc = "Split Vertical"}, "<Cmd>vsplit<CR>"), km("<leader>-", {desc = "Split Horizontal"}, "<Cmd>split<CR>")})
local function _8_()
  return Snacks.scratch()
end
local function _9_()
  return Snacks.scratch.select()
end
wk.add({km("<leader>b", {group = "Buffer"}), km("<leader>bb", {desc = "Toggle scratch"}, _8_), km("<leader>bB", {desc = "Pick scratch"}, _9_), km("<leader>bd", {desc = "Delete buffer"}, "<cmd>lua MiniBufremove.delete()<CR>")})
local function _10_()
  return Snacks.picker.command_history()
end
local function _11_()
  return Snacks.picker.buffers()
end
local function _12_()
  return Snacks.picker.recent()
end
local function _13_()
  return Snacks.picker.projects()
end
local function _14_()
  return Snacks.picker.diagnostics()
end
local function _15_()
  return Snacks.picker.help()
end
local function _16_()
  return Snacks.picker.man()
end
local function _17_()
  return Snacks.picker.highlights()
end
local function _18_()
  return Snacks.picker.lsp_workspace_symbols()
end
local function _19_()
  return Snacks.picker.lsp_symbols()
end
local function _20_()
  return Snacks.picker.smart()
end
local function _21_()
  local buf_name = vim.api.nvim_buf_get_name(0)
  local buf_dir = vim.fs.dirname(buf_name)
  return Snacks.picker.files({cwd = buf_dir})
end
local function _22_()
  return Snacks.picker.grep()
end
wk.add({km("<leader>f", {group = "Fuzzy"}), km("<leader>f:", {desc = "':' history"}, _10_), km("<leader>fb", {desc = "Buffers"}, _11_), km("<leader>fr", {desc = "Recent"}, _12_), km("<leader>fp", {desc = "Projects"}, _13_), km("<leader>fd", {desc = "Diagnostics"}, _14_), km("<leader>fh", {desc = "Help Tags"}, _15_), km("<leader>fm", {desc = "Man pages"}, _16_), km("<leader>fH", {desc = "Highlights"}, _17_), km("<leader>fs", {desc = "Symbols"}, _18_), km("<leader>fS", {desc = "Symbols (buffer)"}, _19_), km("<leader><leader>", {desc = "Fuzzy Files"}, _20_), km("<leader>.", {desc = "Fuzzy Files (buffer dir)"}, _21_), km("<leader>/", {desc = "Live Grep"}, _22_), km("<leader>\\", {desc = "Zoxide"}, "<Cmd>Telescope zoxide list<CR>")})
local function _23_()
  return toggle_term("lazygit", "lazygit")
end
wk.add({km("<leader>g", {group = "Git"}), km("<leader>go", {desc = "Toggle Overlay"}, "<cmd>lua MiniDiff.toggle_overlay()<CR>"), km("<leader>gg", {desc = "Lazygit"}, _23_)})
local function _24_()
  local name_2_auto = require("tiny-code-action")
  local fun_3_auto = name_2_auto.code_action
  return fun_3_auto()
end
local function _25_()
  local name_2_auto = require("conform")
  local fun_3_auto = name_2_auto.format
  return fun_3_auto({lsp_fallback = true})
end
local function _26_()
  return vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
end
local function _27_()
  local name_2_auto = require("swenv.api")
  local fun_3_auto = name_2_auto.pick_venv
  return fun_3_auto()
end
local function _28_()
  local name_2_auto = require("pretty_hover")
  local fun_3_auto = name_2_auto.hover
  return fun_3_auto()
end
wk.add({km("<leader>c", {group = "Code"}), km("<leader>ca", {desc = "Actions"}, _24_), km("<leader>cf", {desc = "Format"}, _25_), km("<leader>cH", {desc = "Toggle inlay hints"}, _26_), km("<leader>cr", {desc = "Rename"}, vim.lsp.buf.rename), km("<leader>cd", {desc = "Diagnostic"}, vim.diagnostic.open_float), km("<leader>cn", {desc = "Navbuddy"}, "<cmd>Navbuddy<CR>"), km("<leader>cg", {desc = "Neogen"}, "<cmd>Neogen<CR>"), km("<leader>cv", {desc = "Python switch venv"}, _27_), km("K", {desc = "Hover"}, _28_), km("gI", {desc = "Implementations"}, "<cmd>Glance implementations<CR>"), km("gr", {desc = "References"}, "<cmd>Glance references<CR>"), km("gd", {desc = "Definitions"}, "<cmd>Glance definitions<CR>"), km("gt", {desc = "Type Definitions"}, "<cmd>Glance type_definitions<CR>")})
local function _29_()
  local name_2_auto = require("neogen")
  local fun_3_auto = name_2_auto.jump_next
  return fun_3_auto()
end
n.map({"i"}, "<C-l>", _29_)
local function _30_()
  local name_2_auto = require("neogen")
  local fun_3_auto = name_2_auto.jump_prev
  return fun_3_auto()
end
n.map({"i"}, "<C-h>", _30_)
wk.add({km("<leader>m", {group = "Map"}), km("<leader>mm", {desc = "Toggle"}, "<cmd>lua MiniMap.toggle()<CR>"), km("<leader>mf", {desc = "Focus"}, "<cmd>lua MiniMap.toggle_focus()<CR>"), km("<leader>mr", {desc = "Refresh"}, "<cmd>lua MiniMap.refresh()<CR>")})
wk.add({km("<leader>_", {group = "Other"}), km("<leader>_t", {desc = "Choose themes"}, "<cmd>Themery<CR>")})
local function _31_()
  for _, client in ipairs(vim.lsp.get_clients({bufnr = vim.api.nvim_get_current_buf()})) do
    local worksp = require("workspace-diagnostics")
    worksp.populate_workspace_diagnostics(client, 0)
  end
  return nil
end
wk.add({km("<leader>x", {group = "Diagnostics"}), km("<leader>xm", {desc = "Messages (noice)"}, "<cmd>NoiceAll<CR>"), km("<leader>xM", {desc = "Messages"}, "<cmd>messages<CR>"), km("<leader>xp", {desc = "Populate diagnostics"}, _31_)})
local function _32_()
  local name_2_auto = require("dapui")
  local fun_3_auto = name_2_auto.eval
  return fun_3_auto()
end
local function _33_()
  local function _34_(input)
    local name_2_auto = require("dapui")
    local fun_3_auto = name_2_auto.eval
    return fun_3_auto(input)
  end
  return vim.ui.input({prompt = "Expression to evaluate"}, _34_)
end
local function _35_()
  local name_2_auto = require("dapui")
  local fun_3_auto = name_2_auto.toggle
  return fun_3_auto()
end
wk.add({km("<leader>d", {group = "Debug"}), km("<leader>ds", {group = "Session"}), km("<leader>dsn", {desc = "New Session"}, ":DapNew<CR>"), km("<leader>dsc", {desc = "Continue Session"}, ":DapContinue<CR>"), km("<leader>db", {desc = "Breakpoint"}, ":DapToggleBreakpoint<CR>"), km("<leader>dj", {desc = "Step over"}, ":DapStepOver<CR>"), km("<leader>dl", {desc = "Step into"}, ":DapStepInto<CR>"), km("<leader>dr", {desc = "Repl"}, ":DapToggleRepl<CR>"), km("<leader>de", {desc = "Eval under cursor"}, _32_), km("<leader>dx", {desc = "Eval expression"}, _33_), km("<leader>dd", {desc = "Toggle UI"}, _35_)})
wk.add({km("<leader>n", {group = "Notes"}), km("<leader>na", {desc = "Add note"}, ":Obsidian new<CR>"), km("<leader>nn", {desc = "Quick switch"}, ":Obsidian quick_switch<CR>"), km("<leader>n/", {desc = "Grep notes"}, ":Obsidian search<CR>"), km("<leader>nt", {desc = "Grep tags"}, ":Obsidian tags<CR>"), km("<leader>nr", {desc = "Rename"}, ":Obsidian rename<CR>"), km("<leader>nf", {desc = "Follow link"}, ":Obsidian follow_link<CR>"), km("<leader>nb", {desc = "Backlinks"}, ":Obsidian backlinks<CR>"), km("<leader>nl", {desc = "Links"}, ":Obsidian links<CR>"), km("<leader>nt", {desc = "Table of contents"}, ":Obsidian toc<CR>"), km("<leader>nP", {desc = "Paste image"}, ":Obsidian paste_img<CR>"), km("<leader>nx", {desc = "Extract into note", mode = {"v"}}, ":Obsidian extract_note<CR>"), km("<leader>na", {desc = "Link new note", mode = {"v"}}, ":Obsidian link_new<CR>"), km("<leader>nl", {desc = "Link a note", mode = {"v"}}, ":Obsidian link<CR>")})
n.map({"n", "i"}, "<A-;>", ":Obsidian toggle_checkbox<CR>")
local function _36_()
  return Snacks.terminal.toggle()
end
n.map({"n", "t"}, "<A-/>", _36_, {desc = "Toggle Terminal"})
local function _37_()
  return Snacks.terminal.toggle()
end
n.map({"n", "t"}, "<C-/>", _37_, {desc = "Toggle Terminal"})
local function _38_()
  return MiniFiles.open()
end
local function _39_()
  return MiniFiles.open(vim.api.nvim_buf_get_name(0))
end
wk.add({km("<leader>E", {desc = "Explore root"}, _38_), km("<leader>e", {desc = "Explore at file"}, _39_)})
_G.MiniFilesMappings = {close = "q", go_in = "l", go_in_plus = "L", go_out = "h", go_out_plus = "H", mark_goto = "'", mark_set = "m", reset = "<BS>", reveal_cwd = "@", show_help = "?", synchronize = "=", trim_left = "<", trim_right = ">"}
local show_dotfiles = false
local function minifiles_filter(f)
  return (show_dotfiles or vim.endswith(f.name, ".env") or not vim.startswith(f.name, "."))
end
local function toggle_hidden()
  show_dotfiles = not show_dotfiles
  return MiniFiles.refresh({content = {filter = minifiles_filter}})
end
local function set_cwd()
  local fs_entry = MiniFiles.get_fs_entry()
  local path = fs_entry.path
  if (path == nil) then
    return vim.notify("Cursor not on valid entry")
  else
    return vim.fn.chdir(vim.fs.dirname(path))
  end
end
local function open_sys()
  local fs_entry = MiniFiles.get_fs_entry()
  local path = fs_entry.path
  return vim.ui.open(path)
end
local function _41_(args)
  local buf_id = args.data.buf_id
  return wk.add({km("<leader>bh", {desc = "Toggle Hidden Files", buffer = buf_id}, toggle_hidden), km("<leader>bS", {desc = "Make focused dir CWD", buffer = buf_id}, set_cwd), km("<leader>bO", {desc = "Open w/ system handler", buffer = buf_id}, open_sys)})
end
return n.autocmd("User", {pattern = "MiniFilesBufferCreate", callback = _41_})
