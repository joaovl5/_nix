(import-macros {: do-req : let-req} :./lib/init-macros)

(local n (require :lib/nvim))
(require :plugins.whichkey)
(local wk (require :which-key))

(fn km [key opts what]
  (tset opts 1 key)
  (tset opts 2 what)
  opts)

(var terminals {})

(fn toggle_term [name cmd]
  "Toggles (or creates) a terminal instance by its id"
  (local {: Terminal} (require :toggleterm.terminal))
  (when (= (. terminals name) nil)
    (tset terminals name (Terminal:new {: cmd :hidden true :direction :float})))
  (: (. terminals name) :toggle))

; # GENERAL
(n.map [:n] :<Esc> :<cmd>nohlsearch<CR> {:desc "Clear Search Highlights"})
(n.map [:t] :<Esc><Esc> "<C-\\><C-n>" {:desc "Exit terminal mode"})
(n.map [:n] :<Esc> :<cmd>nohlsearch<CR> {:desc "Clear Search Highlights"})
; disable pasting in visual selection replacing original copied value
(n.map [:x] :p "\"_dP")
; improve scrolling and autocenter cursor on some actions
(n.map [:n] :<C-d> :<C-d>zz)
(n.map [:n] :<C-u> :<C-u>zz)
(n.map [:n] :n :nzzzv)
(n.map [:n] :N :Nzzzv)
; improve visual mode indents
(n.map [:x] ">" :>gv {:noremap true})
(n.map [:x] "<" :<gv {:noremap true})

; ## Motions
; flash
(n.map [:n :x :o] :s (fn [] (do-req :flash :jump)))
(n.map [:n :x :o] :S (fn [] (do-req :flash :treesitter)))
(n.map [:o] :r (fn [] (do-req :flash :remote) {:desc "Remote flash"}))
; nvim-spider
(n.map [:n :x :o] :w (fn [] (do-req :spider :motion :w)))
(n.map [:n :x :o] :e (fn [] (do-req :spider :motion :e)))
(n.map [:n :x :o] :b (fn [] (do-req :spider :motion :b)))
; treewalker
(n.map [:n :x] "<A-[>" "<cmd>Treewalker Left<cr>")
(n.map [:n :x] "<A-]>" "<cmd>Treewalker Right<cr>")
(n.map [:n :x] :<A-k> "<cmd>Treewalker Up<cr>")
(n.map [:n :x] :<A-j> "<cmd>Treewalker Down<cr>")
;; swaps
(n.map [:n :x] "<A-S-[>" "<cmd>Treewalker SwapLeft<cr>")
(n.map [:n :x] "<A-S-]>" "<cmd>Treewalker SwapRight<cr>")
(n.map [:n :x] :<A-K> "<cmd>Treewalker SwapUp<cr>")
(n.map [:n :x] :<A-J> "<cmd>Treewalker SwapDown<cr>")

; # LEADER

; ## Tabs 

(wk.add [(km :<leader>q {:group :Tab})
         (km :<leader>qc {:desc :Create} :<cmd>tabnew<CR>)
         (km :<leader>ql {:desc :Next} :<cmd>tabnext<CR>)
         (km :<leader>qh {:desc :Prev} :<cmd>tabprev<CR>)
         (km :<leader>qd {:desc :Close} :<cmd>tabclose<CR>)])

; ## Window
(wk.add [(km :<leader>w {:group :Window})
         (km :<leader>wr {:desc "Resize to default!!"}
             "<Cmd>lua MiniMisc.resize_window()<CR>")
         (km :<leader>wz {:desc "Zen mode"}
             (fn []
               (do-req :zen-mode :toggle {})))
         (km :<leader>wd {:desc "Quit window"} :<Cmd>quit<CR>)
         (km :<leader>wD {:desc "Quit all windows"} :<Cmd>quitall<CR>)
         (km :<leader>ww {:desc "Alternate window buffers"} "<Cmd>b#<CR>")
         (km :<leader>| {:desc "Split Vertical"} :<Cmd>vsplit<CR>)
         (km :<leader>- {:desc "Split Horizontal"} :<Cmd>split<CR>)])

; ## Buffer
(wk.add [(km :<leader>b {:group :Buffer})
         (km :<leader>bb {:desc "Toggle scratch"} #(Snacks.scratch))
         (km :<leader>bB {:desc "Pick scratch"} #(Snacks.scratch.select))
         (km :<leader>bd {:desc "Delete buffer"}
             "<cmd>lua MiniBufremove.delete()<CR>")])

; ## Fuzzy stuff
(wk.add [(km :<leader>f {:group :Fuzzy})
         (km "<leader>f:" {:desc "':' history"}
             #(Snacks.picker.command_history))
         (km :<leader>fb {:desc :Buffers} #(Snacks.picker.buffers))
         (km :<leader>fr {:desc :Recent} #(Snacks.picker.recent))
         (km :<leader>fp {:desc :Projects} #(Snacks.picker.projects))
         (km :<leader>fd {:desc :Diagnostics} #(Snacks.picker.diagnostics))
         (km :<leader>fh {:desc "Help Tags"} #(Snacks.picker.help))
         (km :<leader>fm {:desc "Man pages"} #(Snacks.picker.man))
         (km :<leader>fH {:desc :Highlights} #(Snacks.picker.highlights))
         (km :<leader>fs {:desc :Symbols}
             #(Snacks.picker.lsp_workspace_symbols))
         (km :<leader>fS {:desc "Symbols (buffer)"}
             #(Snacks.picker.lsp_symbols))
         (km :<leader><leader> {:desc "Fuzzy Files"} #(Snacks.picker.smart))
         (km :<leader>. {:desc "Fuzzy Files (buffer dir)"}
             (fn []
               (let [buf_name (vim.api.nvim_buf_get_name 0)
                     buf_dir (vim.fs.dirname buf_name)]
                 (Snacks.picker.files {:cwd buf_dir}))))
         ; (km :<leader><leader> {:desc "Fuzzy Files"}
         ;     (fn [] (do-req :fff :find_files)))
         ; (km :<leader>. {:desc "Fuzzy Files (buffer dir)"}
         ;     (fn []
         ;       (let [buf_name (vim.api.nvim_buf_get_name 0)
         ;             buf_dir (vim.fs.dirname buf_name)]
         ;         (do-req :fff :find_files_in_dir buf_dir))))
         (km :<leader>/ {:desc "Live Grep"} #(Snacks.picker.grep))
         (km "<leader>\\" {:desc :Zoxide} "<Cmd>Telescope zoxide list<CR>")])

; ## Git
(wk.add [(km :<leader>g {:group :Git})
         (km :<leader>go {:desc "Toggle Overlay"}
             "<cmd>lua MiniDiff.toggle_overlay()<CR>")
         (km :<leader>gg {:desc :Lazygit}
             (fn [] (toggle_term :lazygit :lazygit)))])

; ## Code
(wk.add [(km :<leader>c {:group :Code})
         (km :<leader>ca {:desc :Actions}
             (fn [] (do-req :tiny-code-action :code_action)))
         (km :<leader>cf {:desc :Format}
             (fn [] (do-req :conform :format {:lsp_fallback true})))
         (km :<leader>cH {:desc "Toggle inlay hints"}
             (fn []
               (vim.lsp.inlay_hint.enable (not (vim.lsp.inlay_hint.is_enabled)))))
         (km :<leader>cr {:desc :Rename} vim.lsp.buf.rename)
         (km :<leader>cd {:desc :Diagnostic} vim.diagnostic.open_float)
         (km :<leader>cn {:desc :Navbuddy} :<cmd>Navbuddy<CR>)
         (km :<leader>cg {:desc :Neogen} :<cmd>Neogen<CR>)
         (km :<leader>cv {:desc "Python switch venv"}
             (fn [] (do-req :swenv.api :pick_venv)))
         (km :K {:desc :Hover} (fn [] (do-req :pretty_hover :hover)))
         (km :gI {:desc :Implementations} "<cmd>Glance implementations<CR>")
         (km :gr {:desc :References} "<cmd>Glance references<CR>")
         (km :gd {:desc :Definitions} "<cmd>Glance definitions<CR>")
         (km :gt {:desc "Type Definitions"} "<cmd>Glance type_definitions<CR>")])

(n.map [:i] :<C-l> (fn [] (do-req :neogen :jump_next)))
(n.map [:i] :<C-h> (fn [] (do-req :neogen :jump_prev)))

; ## Map
(wk.add [(km :<leader>m {:group :Map})
         (km :<leader>mm {:desc :Toggle} "<cmd>lua MiniMap.toggle()<CR>")
         (km :<leader>mf {:desc :Focus} "<cmd>lua MiniMap.toggle_focus()<CR>")
         (km :<leader>mr {:desc :Refresh} "<cmd>lua MiniMap.refresh()<CR>")])

; ## Other

(wk.add [(km :<leader>_ {:group :Other})
         (km :<leader>_t {:desc "Choose themes"} :<cmd>Themery<CR>)])

; ## Diagnostics
; (more on plugins/editor/actions.fnl)
(wk.add [(km :<leader>x {:group :Diagnostics})
         (km :<leader>xm {:desc "Messages (noice)"} :<cmd>NoiceAll<CR>)
         (km :<leader>xM {:desc :Messages} :<cmd>messages<CR>)
         (km :<leader>xp {:desc "Populate diagnostics"}
             (fn []
               (each [_ client (ipairs (vim.lsp.get_clients {:bufnr (vim.api.nvim_get_current_buf)}))]
                 (let [worksp (require :workspace-diagnostics)]
                   (worksp.populate_workspace_diagnostics client 0)))))])

; ## Notes (FIXME)
(wk.add [(km :<leader>n {:group :Notes})
         (km :<leader>na {:desc "Add note"} ":Obsidian new<CR>")
         (km :<leader>nn {:desc "Quick switch"} ":Obsidian quick_switch<CR>")
         (km :<leader>n/ {:desc "Grep notes"} ":Obsidian search<CR>")
         (km :<leader>nt {:desc "Grep tags"} ":Obsidian tags<CR>")
         (km :<leader>nr {:desc :Rename} ":Obsidian rename<CR>")
         (km :<leader>nf {:desc "Follow link"} ":Obsidian follow_link<CR>")
         (km :<leader>nb {:desc :Backlinks} ":Obsidian backlinks<CR>")
         (km :<leader>nl {:desc :Links} ":Obsidian links<CR>")
         (km :<leader>nt {:desc "Table of contents"} ":Obsidian toc<CR>")
         (km :<leader>nP {:desc "Paste image"} ":Obsidian paste_img<CR>")
         (km :<leader>nx {:desc "Extract into note" :mode [:v]}
             ":Obsidian extract_note<CR>")
         (km :<leader>na {:desc "Link new note" :mode [:v]}
             ":Obsidian link_new<CR>")
         (km :<leader>nl {:desc "Link a note" :mode [:v]} ":Obsidian link<CR>")])

(n.map [:n :i] "<A-;>" ":Obsidian toggle_checkbox<CR>")

; (km :<leader>)])

; ## Terminal

(n.map [:n :t] :<A-/> "<cmd>ToggleTerm direction=horizontal size=20 name=x<CR>"
       {:desc "Toggle Terminal"})

(n.map [:n :t] :<C-/> "<cmd>ToggleTerm direction=vertical size=60 name=y<CR>"
       {:desc "Toggle Terminal"})

; ## Explorer
(wk.add [(km :<leader>E {:desc "Explore root"}
             (fn []
               (MiniFiles.open)))
         (km :<leader>e {:desc "Explore at file"}
             (fn []
               (MiniFiles.open (vim.api.nvim_buf_get_name 0))))])

(set _G.MiniFilesMappings {:close :q
                           :go_in :l
                           :go_in_plus :L
                           :go_out :h
                           :go_out_plus :H
                           :mark_goto "'"
                           :mark_set :m
                           :reset :<BS>
                           :reveal_cwd "@"
                           :show_help "?"
                           :synchronize "="
                           :trim_left "<"
                           :trim_right ">"})

(var show_dotfiles false)

(fn minifiles_filter [f]
  (or show_dotfiles (vim.endswith f.name :.env)
      (not (vim.startswith f.name "."))))

(fn toggle_hidden []
  (set show_dotfiles (not show_dotfiles))
  (MiniFiles.refresh {:content {:filter minifiles_filter}}))

(fn set_cwd []
  (let [fs_entry (MiniFiles.get_fs_entry)
        path fs_entry.path]
    (if (= path nil)
        (vim.notify "Cursor not on valid entry")
        (vim.fn.chdir (vim.fs.dirname path)))))

(fn open_sys []
  (let [fs_entry (MiniFiles.get_fs_entry)
        path fs_entry.path]
    (vim.ui.open path)))

(n.autocmd :User {:pattern :MiniFilesBufferCreate
                  :callback (fn [args]
                              (let [buf_id args.data.buf_id]
                                (wk.add [(km :<leader>bh
                                             {:desc "Toggle Hidden Files"
                                              :buffer buf_id}
                                             toggle_hidden)
                                         (km :<leader>bS
                                             {:desc "Make focused dir CWD"
                                              :buffer buf_id}
                                             set_cwd)
                                         (km :<leader>bO
                                             {:desc "Open w/ system handler"
                                              :buffer buf_id}
                                             open_sys)])))})
