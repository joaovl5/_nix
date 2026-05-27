(import-macros {: do-req : let-req : plugin : key} :./lib/init-macros)

(fn get_blink_config [comp_icon comp_kind]
  (let [documentation (require :plugins.lsp.completions._documentation)
        keymap (require :plugins.lsp.completions._keymap)
        kind_icons (require :plugins.lsp.completions._icons)
        menu (require :plugins.lsp.completions._menu)
        signature (require :plugins.lsp.completions._signature)
        sources (require :plugins.lsp.completions._sources)]
    {:keymap keymap
     :appearance {:nerd_font_variant :mono
                  :kind_icons kind_icons}
     :completion {:ghost_text {:enabled false}
                  :keyword {:range :full}
                  :accept {:auto_brackets {:enabled false}}
                  :list {:selection {:preselect true}
                         :max_items 250}
                  :documentation documentation
                  :menu (menu comp_icon comp_kind)}
     :sources sources
     :signature signature
     :cmdline {:keymap {:preset :inherit}
               :sources [:buffer :cmdline]
               :completion {:menu {:auto_show true}}}
     :fuzzy {;; prioritize exact matches
             :sorts [:exact
                     :score
                     :sort_text]
             ;; prefer rust impl
             :implementation :prefer_rust_with_warning}}))

(fn setup_blink []
  (let [blink (require :blink.cmp)
        mini_icons (require :mini.icons)
        _icon_data (fn [ctx]
                     (mini_icons.get :lsp ctx.kind))
        _icon_hl (fn [ctx]
                   (let [[_ hl _] (_icon_data ctx)]
                     (or hl ctx.kind_hl)))
        _icon (fn [ctx]
                (let [[icon _ _] (_icon_data ctx)]
                  (.. (or icon ctx.kind_icon) ctx.icon_gap)))
        comp_icon {:text _icon :highlight _icon_hl}
        comp_kind {:highlight _icon_hl}]
    (blink.setup (get_blink_config comp_icon comp_kind))))

[{:dir _G.plugin_dirs.blink-cmp
  :event :InsertEnter
  :config setup_blink
  :dependencies [(plugin
                   :saghen/blink.compat
                   {:lazy true})
                 (plugin
                   :mikavilpas/blink-ripgrep.nvim
                   {:version :*})
                 :saghen/blink.lib
                 :bydlw98/blink-cmp-env
                 :Kaiser-Yang/blink-cmp-git
                 :disrupted/blink-cmp-conventional-commits]}]
