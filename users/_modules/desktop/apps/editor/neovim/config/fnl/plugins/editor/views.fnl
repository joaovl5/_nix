(import-macros {: do-req : let-req : plugin : p! : key} :./lib/init-macros)

[; glance (peek references etc)
 (plugin :dnlhc/glance.nvim {:cmd :Glance})
 (p!
   :dnhlc/glance.nvim
   (cmd :Glance)
   (keys
     (bind :gI (cmd "Glance implementations") (desc "Implementations"))
     (bind :gr (cmd "Glance references") (desc "References"))
     (bind :gd (cmd "Glance definitions") (desc "Definitions"))
     (bind :gt (cmd "Glance type_definitions") (desc "Type Definitions"))))
 ; navbuddy
 (p!
   :SmiteshP/nvim-navbuddy
   (deps [:SmiteshP/nvim-navic
          :MunifTanjim/nui.nvim
          :numToStr/Comment.nvim])
   (cmd :Navbuddy)
   (keys
     (group
       :code
       (bind :n (cmd :Navbuddy) (desc "Navbuddy"))))
   (opts {:window {:border :rounded
                   :size "60%"}
          :lsp {:auto_attach true}}))]
