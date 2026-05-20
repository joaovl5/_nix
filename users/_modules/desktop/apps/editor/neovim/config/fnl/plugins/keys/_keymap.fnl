(import-macros {: do-req : let-req : keys!} :./lib/init-macros)

(local {: v/map : v/$ : v/n} (require :lib/nvim))

; # GENERAL
(v/map [:n] :<Esc> :<cmd>nohlsearch<CR> {:desc "Clear Search Highlights"})
(v/map [:n] :<Esc> :<cmd>nohlsearch<CR> {:desc "Clear Search Highlights"})
; disable pasting in visual selection replacing original copied value
(v/map [:x] :p "\"_dP")
; improve scrolling and autocenter cursor on some actions
(v/map [:n] :<C-d> :<C-d>zz)
(v/map [:n] :<C-u> :<C-u>zz)
(v/map [:n] :n :nzzzv)
(v/map [:n] :N :Nzzzv)
; improve visual mode indents
(v/map [:x] ">" :>gv {:noremap true})
(v/map [:x] "<" :<gv {:noremap true})

; Window manipulation
(keys!
  (group
    :action_1
    (bind :h (cmd "wincmd H") (desc "Move left"))
    (bind :j (cmd "wincmd J") (desc "Move down"))
    (bind :k (cmd "wincmd K") (desc "Move up"))
    (bind :l (cmd "wincmd L") (desc "Move right"))
    (bind :x (cmd "wincmd x") (desc "Swap current/next"))
    (bind :t (cmd "wincmd t") (desc "Break to tab"))))

(keys!
  (group
    :action_2
    (bind :c (cmd :tabnew) (desc "Create"))
    (bind :l (cmd :tabnext) (desc "Next"))
    (bind :h (cmd :tabprev) (desc "Prev"))
    (bind :d (cmd :tabclose) (desc "Close"))))

; # LEADER
; ## Tabs
(keys!
  (group :tab))

; ## Window
(keys!
  (group :window
         (bind :d (cmd :quit) (desc "Quit window"))
         (bind :D (cmd :quitall) (desc "Quit all windows"))
         (bind :w (cmd :b#) (desc "Alternate window buffers"))))

(keys!
  (bind "<leader>|" (cmd :vsplit) (desc "Split Vertical"))
  (bind "<leader>-" (cmd :split) (desc "Split Horizontal")))

; ## Buffer
(keys!
  (group :buffer))

; ## Fuzzy stuff
(keys!
  (group :fuzzy))

; ## Git
(keys!
  (group :git))

; ## Code
(keys!
  (group
    :code
    (bind :h
          (fn []
            (vim.lsp.inlay_hint.enable (not (vim.lsp.inlay_hint.is_enabled))))
          (desc "Toggle inlay hints"))
    (bind :r vim.lsp.buf.rename (desc "Rename"))
    (bind :d vim.diagnostic.open_float (desc "Diagnostic"))))

; ## Diagnostics
; (more on plugins/editor/actions.fnl)
(keys!
  (group :diagnostics))

; ## Debugging
(keys!
  (group :debug))

(keys!
  (group :ai))

(keys!
  (group :repl))

(keys!
  (group :merge))

(keys!
  (group
    :meta
    (bind
      :n
      (fn []
        (local cfg "~/.config/nvim/.nfnl.fnl")
        (v/$ (.. "NfnlCompileAllFiles " cfg))
        (v/$ (.. "NfnlDeleteOrphans " cfg))
        (v/n "Done compiled all files and deleted orphans"))
      (desc "Nfnl Refresh"))))

; ## Terminal

(v/map [:t] :<Esc><Esc> "<C-\\><C-n>" {:desc "Exit terminal mode"})
