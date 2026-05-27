(import-macros {: do-req : let-req : p! : key} :./lib/init-macros)
(local {: v/input} (require :lib/nvim))

[(p!
   :mfussenegger/nvim-dap
   (opts false)
   (keys
     (group
       :debug
       (bind :s {:group "Session"})
       (bind :sn (cmd "DapNew") (desc "New Session"))
       (bind :sc (cmd "DapContinue") (desc "Continue Session"))
       (bind :b (cmd "DapToggleBreakpoint") (desc "Breakpoint"))
       (bind :j (cmd "DapStepOver") (desc "Step over"))
       (bind :l (cmd "DapStepInto") (desc "Step into"))
       (bind :r (cmd "DapToggleRepl") (desc "Repl"))))
   (config
     (fn []
       (let [dap (require :dap)]
         (set dap.adapters.pwa-node
              {:type :server
               :host :localhost
               :port "${port}"
               :executable {:command :js-debug :args ["${port}"]}})
         (set dap.configurations.typescript
              [{:type :pwa-node
                :request :launch
                :name "Launch File"
                :program "${file}"
                :cwd "${workspaceFolder}"}])
         (set dap.configurations.javascript
              [{:type :pwa-node
                :request :launch
                :name "Launch File"
                :program "${file}"
                :cwd "${workspaceFolder}"}]))))
   (deps [:rcarriga/cmp-dap
          (p! :mfussenegger/nvim-dap-python
              (config #(do-req :dap-python :setup :uv)))]))
 (p!
   :rcarriga/nvim-dap-ui
   (keys
     (group
       :debug
       (bind :e
             #(do-req :dapui :eval)
             (desc "Eval under cursor"))
       (bind :x
             #(v/input
                {:prompt "Expression to evaluate"}
                #(do-req :dapui :eval $1))
             (desc "Eval expression"))))
   (opts {})
   (deps [:mfussenegger/nvim-dap :nvim-neotest/nvim-nio]))]
