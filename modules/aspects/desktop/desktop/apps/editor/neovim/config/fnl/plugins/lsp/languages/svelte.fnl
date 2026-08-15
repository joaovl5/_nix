(import-macros {: do-req : let-req : p! : key} :./lib/init-macros)

; let g:vim_svelte_plugin_load_full_syntax = 1
(set vim.g.vim_svelte_plugin_load_full_syntax 1)
(set vim.g.vim_svelte_plugin_use_typescript 1)
(set vim.g.vim_svelte_plugin_use_less 1)
(set vim.g.vim_svelte_plugin_use_sass 1)
(set vim.g.vim_svelte_plugin_use_stylus 1)
(set vim.g.vim_svelte_plugin_use_foldexpr 1)

[(p! :leafOfTree/vim-svelte-plugin)]
