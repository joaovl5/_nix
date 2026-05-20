(local {: v/$ : v/autocmd : v/later} (require :lib/nvim))

(local
  opts
  {:mouse :a
   :mousescroll "ver:15,hor:6"
   :switchbuf :usetab
   :swapfile false
   :undolevels 10000
   :undofile true
   :shada "'100,<50,s10,:1000,/100,@100,h"
   :termguicolors true
   :redrawtime 10000
   :maxmempattern 20000
   :smoothscroll true
   ; confirm to save changes
   :confirm true
   ; allow hidden buffers
   :hidden true
   :errorbells false
   ; better backspace behavior
   :backspace "indent,eol,start"
   ; ## SESSION
   :sessionoptions "curdir,folds,globals,help,tabpages,terminal,winsize"
   ; ## UI
   :updatetime 500
   :timeoutlen 250
   :background :dark
   ; indentation
   :colorcolumn :+1
   ; draw max width column
   :number true
   ; draw line numbers
   :relativenumber true
   ; draw relative line numbers
   ; text indicators
   :list true
   :listchars "tab:» ,trail:·,nbsp:␣"
   :fillchars "eob: ,fold:╌"
   ; wrap
   :wrap false
   :linebreak true
   :breakindent true
   :breakindentopt "list:-1"
   ; cursor
   :cursorline true
   :cursorcolumn true
   ; crosshair
   :cursorlineopt "screenline,number"
   ; statusbar/cmdbar
   :ruler false
   ; hide coordinates
   :showmode false
   ; hide mode (we use statusbar for that)
   :signcolumn :yes
   ; always show signcolumn (less flicker)
   ; splits,windows,tabs,etc
   :splitbelow true
   :splitright true
   :splitkeep :screen
   :winborder :solid
   :winblend 0
   :pumheight 10
   :pummaxwidth 60
   :pumblend 10
   :cmdheight 0
   ; folds
   :foldlevel 99
   ; no folds by default
   :foldmethod :indent
   :foldnestmax 10
   :foldtext ""
   ; ## EDITOR
   :spelloptions :camel
   ; treats camelcase as separate words
   :virtualedit :block
   ; allows cursor to move in vblock
   ; even if there's no text
   :iskeyword "@,48-57,_,192-255,-"
   :scrolloff 10
   ; completion
   :complete ".,w,b,kspell"
   :completeopt "menuone,noselect,fuzzy,nosort"
   ; indentation
   :autoindent true
   :smartindent true
   :expandtab true
   :shiftwidth 2
   :tabstop 2
   ; formatting
   :formatlistpat "^\\s*[0-9\\-\\+\\*]\\+[\\.\\)]*\\s\\+"
   :formatoptions :rqnl1
   ; search
   :ignorecase true
   :incsearch true
   :smartcase true})

; set opts
(each [opt val (pairs opts)]
  (tset vim.opt opt val))

; clipboard os sync
(v/later (fn [] (set vim.o.clipboard :unnamedplus)))

; filetype plugins and syntax enable (faster startup)
(v/$ "filetype plugin indent on")
(when (not= 1 (vim.fn.exists :syntax_on))
  (v/$ "syntax enable"))

; setup diagnostics

(local
  diagnostic_opts
  {:severity_sort true
   :float {:border :rounded :source :if_many}
   :signs {:priority 9999
           :severity {:min :WARN :max :ERROR}
           :text (doto {}
                   (tset vim.diagnostic.severity.ERROR
                         "󰅚 ")
                   (tset vim.diagnostic.severity.WARN
                         "󰀪 ")
                   (tset vim.diagnostic.severity.INFO
                         "󰋽 ")
                   (tset vim.diagnostic.severity.HINT
                         "󰌶 "))}
   :underline {:severity [:ERROR]}
   :virtual_lines false
   :virtual_text {:source :if_many
                  :spacing 2
                  :current_line true
                  :severity [:ERROR]}
   :update_in_insert false})

(v/later (fn []
           (vim.diagnostic.config diagnostic_opts)))

(v/autocmd :FileType
           {:desc "Proper 'formatoptions'"
            :callback (fn []
                        (v/$ "setlocal formatoptions-=c formatoptions-=o"))})
