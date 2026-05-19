(import-macros {: do-req : let-req : p! : key} :./lib/init-macros)
(local {: v/extend} (require :lib/nvim))

(fn setup_themery []
  (let [global_themes (or _G.Config.themes [])
        themes
        (accumulate [names [] _ theme (ipairs global_themes)]
          (v/extend names theme.names))]
    {: themes :livePreview true}))

(p!
  :zaldih/themery.nvim
  (lazy false)
  (keys
    (group
      :meta
      (bind :t (cmd :Themery) (desc "Themery"))))
  (opts setup_themery))
