(import-macros {: do-req : let-req : plugin : key} :./lib/init-macros)

(fn build_parinfer [params]
  (vim.notify "Building Parinfer" vim.log.levels.INFO)
  (let [res (: (vim.system [:cargo :build :--release] {:cwd params.path}) :wait)]
    (if (= 0 res.code)
        (vim.notify "Building Parinfer done" vim.log.levels.INFO)
        (vim.notify "Building Parinfer failed" vim.log.levels.ERROR))))

[(plugin :bakpakin/fennel.vim {:ft :fennel})
 (plugin :eraserhd/parinfer-rust {:build build_parinfer})]
