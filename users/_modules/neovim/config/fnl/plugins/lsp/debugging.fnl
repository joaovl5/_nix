(import-macros {: do-req : let-req : plugin : key} :./lib/init-macros)

[(plugin :mfussenegger/nvim-dap
         {:opts false
          :dependencies [(plugin :mfussenegger/nvim-dap-python
                                 {:config #(do-req :dap-python :setup :uv)})
                         :rcarriga/cmp-dap]})
 (plugin :rcarriga/nvim-dap-ui
         {:opts {}
          :dependencies [:mfussenegger/nvim-dap :nvim-neotest/nvim-nio]})]
