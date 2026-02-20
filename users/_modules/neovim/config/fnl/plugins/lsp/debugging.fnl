(import-macros {: do-req : let-req : plugin : key} :./lib/init-macros)

[(plugin :mfussenegger/nvim-dap
         {:opts false
          :config (fn []
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
                             :cwd "${workspaceFolder}"}])))
          :dependencies [(plugin :mfussenegger/nvim-dap-python
                                 {:config #(do-req :dap-python :setup :uv)})
                         :rcarriga/cmp-dap]})
 (plugin :rcarriga/nvim-dap-ui
         {:opts {}
          :dependencies [:mfussenegger/nvim-dap :nvim-neotest/nvim-nio]})]
