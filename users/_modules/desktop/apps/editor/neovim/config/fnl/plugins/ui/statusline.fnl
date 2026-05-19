(import-macros {: do-req : let-req : p! : key} :./lib/init-macros)
(local {: v/$ : v/input} (require :lib/nvim))

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

(fn setup-lualine []
  (local raw-sections
         {:a
          [:mode]
          :b
          [:filename :branch]
          :c
          ["%="]
          :x [(. (require :token-count.integrations.lualine) :current_buffer)]
          :y [:filetype]
          :z [:location :progress]})
  (local raw-inactive-sections
         {:a [:filename]
          :b []
          :c []
          :x []
          :y []
          :z [:location]})
  {:options {:component_separators ""
             :section_separators ""}
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
