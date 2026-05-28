(import-macros {: p!} :./lib/init-macros)

(local resize-step 3)

(fn resize [command]
  #(vim.cmd (.. command resize-step)))

(fn setup-window-resize-hydra []
  (let [Hydra (require :hydra)]
    (Hydra
      {:name "Window resize"
       :mode [:n :t]
       :body ";r"
       :hint "Resize: _H_ width-  _L_ width+  _K_ height-  _J_ height+  _<Esc>_ exit"
       :config {:invoke_on_body true
                :desc "Resize mode"
                :color :red
                :hint {:type :window
                       :position :bottom}}
       :heads [["H" (resize "vertical resize -") {:desc "width -"}]
               ["L" (resize "vertical resize +") {:desc "width +"}]
               ["K" (resize "resize -") {:desc "height -"}]
               ["J" (resize "resize +") {:desc "height +"}]
               ["<Esc>" #nil {:exit true :desc "exit"}]
               ["<CR>" #nil {:exit true :desc "exit"}]
               ["q" #nil {:exit true :desc "exit"}]]})))

(p! :nvimtools/hydra.nvim
    (lazy false)
    (config setup-window-resize-hydra))
