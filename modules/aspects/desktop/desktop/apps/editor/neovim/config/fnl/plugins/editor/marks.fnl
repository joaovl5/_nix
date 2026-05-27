(import-macros {: do-req : let-req : p! : key} :./lib/init-macros)

[(p!
   :fnune/recall.nvim
   (keys
     (group
       :marks
       (bind :t (cmd "RecallToggle") (desc "Toggle mark"))
       (bind :l (cmd "RecallNext") (desc "Next mark"))
       (bind :h (cmd "RecallPrevious") (desc "Prev mark"))
       (bind :c (cmd "RecallClear") (desc "Clear all mark"))
       (bind
         ":f"
         #(do-req :recall.snacks :pick)
         (desc "Pick marks"))))
   (opts
     {:sign ""}))]
