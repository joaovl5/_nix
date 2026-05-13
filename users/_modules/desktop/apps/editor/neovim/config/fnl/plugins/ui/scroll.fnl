(import-macros {: do-req : let-req : plugin : key} :./lib/init-macros)

[; decorations in scrollbar
 (plugin :lewis6991/satellite.nvim {:event :LspAttach :opts {}})]
