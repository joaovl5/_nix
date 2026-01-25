(local {: now : add : later}
       {:now MiniDeps.now :add MiniDeps.add :later MiniDeps.later})

(import-macros {: do-req : let-req} :./lib/init-macros)

(fn build_parinfer [params]
  (vim.notify "Building Parinfer" vim.log.levels.INFO)
  (let [res (: (vim.system [:cargo :build :--release] {:cwd params.path}) :wait)]
    (if (= 0 res.code)
        (vim.notify "Building Parinfer done" vim.log.levels.INFO)
        (vim.notify "Building Parinfer failed" vim.log.levels.ERROR))))

(add :bakpakin/fennel.vim)
; (add :m15a/vim-fennel-syntax)
(add {:source :eraserhd/parinfer-rust
      :hooks {:post_install build_parinfer :post_checkout build_parinfer}})
