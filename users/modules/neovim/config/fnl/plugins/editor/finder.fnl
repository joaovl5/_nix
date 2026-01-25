(local {: now : add : later}
       {:now MiniDeps.now :add MiniDeps.add :later MiniDeps.later})

(import-macros {: do-req : let-req} :./lib/init-macros)

(fn build_fff [params]
  (vim.notify "Building FFF" vim.log.levels.INFO)
  (let [res (: (vim.system [:cargo :build :--release] {:cwd params.path}) :wait)]
    (if (= 0 res.code)
        (vim.notify "Building FFF done" vim.log.levels.INFO)
        (vim.notify "Building FFF failed" vim.log.levels.ERROR))))

(add {:source :dmtrKovalenko/fff.nvim
      :hooks {:post_install build_fff :post_checkout build_fff}})

(do-req :fff :setup {:prompt "🌟 "
                     :title "FILES FIND FILES"
                     :max_results 50
                     :max_threads 8
                     :layout {:height 0.8
                              :width 0.8
                              :prompt_position :bottom
                              :preview_position :right
                              :preview_size :0.6}})

(later (fn []
         (set vim.o.termguicolors true)))
