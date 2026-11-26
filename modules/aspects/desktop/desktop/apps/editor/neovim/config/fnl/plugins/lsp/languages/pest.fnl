(import-macros {: p!} :./lib/init-macros)

(p! :miguelflor/pest.nvim
    (deps [:nvim-treesitter/nvim-treesitter])
    (opts {}))
