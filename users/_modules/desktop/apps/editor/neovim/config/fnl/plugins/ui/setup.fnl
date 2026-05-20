(import-macros {: do-req : let-req : p! : key} :./lib/init-macros)

(do-req
  :vim._core.ui2
  :enable
  {:enable true
   :msg {:targets :msg
         :cmd {:height 0.6}
         :dialog {:height 0.6}
         :msg {:height 0.6 :timeout 3500}
         :pager {:height 2}}})
