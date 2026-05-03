(import-macros {: do-req : let-req : plugin : key} :./lib/init-macros)

(fn build_parinfer [params]
  (vim.notify "Building Parinfer" vim.log.levels.INFO)
  (let [res (: (vim.system [:cargo :build :--release] {:cwd params.path}) :wait)]
    (if (= 0 res.code)
        (vim.notify "Building Parinfer done" vim.log.levels.INFO)
        (res.code)
        (vim.notify (.. "Building Parinfer failed\n\nSTDOUT: " res.stdout
                        "\n\nSTDERR: " res.stderr)
                    vim.log.levels.ERROR))))

[(plugin :eraserhd/parinfer-rust {:build build_parinfer :ft [:fennel]})]
