(import-macros {: do-req : let-req : p! : key} :./lib/init-macros)
(local {: v/$ : v/input : v/mode} (require :lib/nvim))

(fn comp [component ?opts]
  (let [opts (or ?opts {})
        out []]
    (tset out 1 component)
    (each [k v (pairs opts)]
      (tset out k v))
    out))

(fn section-transform [sections]
  (let [out {}]
    (each [k v (pairs sections)]
      (tset out (.. "lualine_" (tostring k)) v))
    out))

(local colors {:bg "#202328"
               :fg "#bbc2cf"
               :yellow "#ECBE7B"
               :cyan "#008080"
               :darkblue "#081633"
               :green "#98be65"
               :orange "#FF8800"
               :violet "#a9a1e1"
               :magenta "#c678dd"
               :blue "#51afef"
               :red "#ec5f67"})

; mode component
; Mode codes are from `:help mode()`; `v/mode 1` returns the full code.
(local mode_info
       {; Normal mode.
        :n ["🜔 " "red"]
        ; Operator-pending mode.
        :no ["🝕 " "red"]
        ; Operator-pending mode forced charwise.
        :nov ["🝕 " "red"]
        ; Operator-pending mode forced linewise.
        :noV ["🝕 " "red"]
        ; Operator-pending mode forced blockwise.
        :noCTRL-V ["🝕 " "red"]
        ; Normal through CTRL-O from Insert mode.
        :niI ["🜔 " "red"]
        ; Normal through CTRL-O from Replace mode.
        :niR ["🜔 " "red"]
        ; Normal through CTRL-O from Virtual-Replace mode.
        :niV ["🜔 " "red"]
        ; Terminal-Normal mode.
        :nt ["🜔 " "red"]
        ; Terminal-Normal through CTRL-\\ CTRL-O.
        :ntT ["🜔 " "red"]
        ; Insert mode.
        :i ["🜕 " "green"]
        ; Insert completion mode.
        :ic ["🜕 " "yellow"]
        ; Insert CTRL-X completion mode.
        :ix ["🜕 " "yellow"]
        ; Visual characterwise mode.
        :v ["🜉 " "blue"]
        ; Visual characterwise through CTRL-O from Select mode.
        :vs ["🜉 " "blue"]
        ; Visual linewise mode.
        :V ["🝓 " "blue"]
        ; Visual linewise through CTRL-O from Select mode.
        :Vs ["🝓 " "blue"]
        ; Visual blockwise mode, returned as CTRL-V.
        "\022" ["🝢 " "blue"]
        ; Visual blockwise through CTRL-O from Select mode.
        "\022s" ["🝢 " "blue"]
        ; Select characterwise mode.
        :s ["🜉 " "orange"]
        ; Select linewise mode.
        :S ["🝓 " "orange"]
        ; Select blockwise mode, returned as CTRL-S.
        "\019" ["🝢 " "orange"]
        ; Replace mode.
        :R ["🝘 " "violet"]
        ; Replace completion mode.
        :Rc ["🝘 " "violet"]
        ; Replace CTRL-X completion mode.
        :Rx ["🝘 " "violet"]
        ; Virtual Replace mode.
        :Rv ["🝘 " "violet"]
        ; Virtual Replace completion mode.
        :Rvc ["🝘 " "violet"]
        ; Virtual Replace CTRL-X completion mode.
        :Rvx ["🝘 " "violet"]
        ; Command-line editing mode.
        :c ["🝊 " "magenta"]
        ; Command-line overstrike mode.
        :cr ["🝊 " "magenta"]
        ; Vim Ex mode from gQ.
        :cv ["🝝 " "red"]
        ; Vim Ex overstrike mode.
        :cvr ["🝝 " "red"]
        ; Legacy Vim docs/presets sometimes list Normal Ex mode as `ce`; current Neovim `:help mode()` does not.
        :ce ["🝝 " "red"]
        ; Hit-enter prompt.
        :r ["🜹 " "orange"]
        ; More prompt.
        :rm ["🜹 " "orange"]
        ; Confirm query prompt.
        "r?" ["🜹 " "orange"]
        ; Shell or external command is executing.
        "!" ["🜹 " "yellow"]
        ; Terminal mode; keys go to the terminal job.
        :t ["🝒 " "yellow"]})

(fn mode-column [column]
  (let [out {}]
    (each [mode info (pairs mode_info)]
      (tset out mode (. info column)))
    out))

(local mode_label (mode-column 1))
(local mode_color (mode-column 2))

(fn mode-value [lookup mode fallback]
  (or (. lookup mode)
      (. lookup (string.sub mode 1 1))
      fallback))

(fn comp-mode []
  (let [current_mode (v/mode 1)]
    (mode-value mode_label current_mode current_mode)))

(fn comp-mode-color []
  (let [current_mode (v/mode 1)]
    {:fg (. colors (mode-value mode_color current_mode "fg"))}))

(fn setup-lualine []
  (local raw-sections
         {:a [(comp comp-mode {:color comp-mode-color})]
          :b
          [:filename :branch]
          :c
          ["%="]
          :x [(comp :triforce
                    {:level {:enabled true
                             :prefix "󰦇 "}
                     :achievements {:enabled true
                                    :icon " "}
                     :streak {:enabled true
                              :icon " "}
                     :session_time {:enabled true
                                    :icon " "}})
              (. (require :token-count.integrations.lualine) :current_buffer)]
          :y [:filetype]
          :z []})
  (local raw-inactive-sections
         {:a [:filename]
          :b []
          :c []
          :x []
          :y []
          :z [:location]})
  {:options {:component_separators ""
             :section_separators ""
             :theme {:normal {:a {:fg colors.fg :bg colors.bg}}
                     :inactive {:a {:fg colors.fg :bg colors.bg}}}}
   :sections (section-transform raw-sections)
   :inactive_sections (section-transform raw-inactive-sections)
   :tabline {}
   :extensions {}})

[; status bar
 (p! :nvim-lualine/lualine.nvim
     (opts setup-lualine)
     (deps (p! :3ZsForInsomnia/token-count.nvim
               (opts {:model "gpt-5"})))
     (event :VeryLazy))
 ; tab bar
 (p! :nanozuki/tabby.nvim
     (event :VeryLazy)
     (keys
       (group
         :tab
         (bind :w (cmd "Tabby pick_window") (desc "Pick window"))
         (bind :q (cmd "Tabby jump_to_tab") (desc "Jump mode"))
         (bind
           :r
           #(v/input {:prompt "Enter name for tab:"}
                     #(when (not= nil $1)
                        (v/$ (.. "Tabby rename_tab " $1))))
           (desc "Rename"))))
     (opts {:preset :tab_only
            :option {:theme {:fill :TabLineFill
                             :head :TabLine
                             :current_tab :TabLineSel
                             :tab :TabLine
                             :win :TabLine
                             :tail :TabLine}
                     :nerdfont true
                     :lualine_theme nil
                     :tab_name {:tab_fallback (fn [tabid]
                                                (tabid))}
                     :buf_name {:mode :shorten}}}))]
