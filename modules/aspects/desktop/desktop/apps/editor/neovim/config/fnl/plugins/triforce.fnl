(import-macros {: do-req : let-req : p! : i! : key} :./lib/init-macros)
(local {: v/n : v/later} (require :lib/nvim))

(fn ln [name icon]
  {: name : icon})

[(p!
   :gisketch/triforce.nvim
   (deps [:nvzone/volt])
   (event :VeryLazy)
   (keys
     (group
       :stats
       (bind :t (cmd "Triforce profile") (desc "Profile"))
       (bind :s (cmd "Triforce stats") (desc "Stats"))
       (bind :R (cmd "Triforce reset") (desc "Reset"))))
   (opts {:icon_engine :mini
          :keymap {:show_profile nil}
          :xp_rewards {:char 4
                       :line 6
                       :save 8}
          :custom_languages
          {:fennel (ln "Fennel" " ")
           :nix (ln "Nix" " ")
           :janet (ln "Janet" "󱁸 ")}}))]
