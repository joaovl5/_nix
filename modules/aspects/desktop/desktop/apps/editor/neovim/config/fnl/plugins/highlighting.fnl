(import-macros {: plugin} :./lib/init-macros)

(local {: v/autocmd : v/contains? : v/later} (require :lib/nvim))

(vim.filetype.add {:extension {:kbd :kanata}})

(v/autocmd :User
           {:pattern :TSUpdate
            :callback
            (fn []
              (tset (require :nvim-treesitter.parsers)
                    :kanata
                    {:install_info
                     {:branch :master
                      :url "https://github.com/postsolar/tree-sitter-kanata"}}))})

(vim.treesitter.language.register :kanata :kanata)

(fn start_treesitter [buf lang]
  (when (vim.api.nvim_buf_is_valid buf)
    (let [(ok err) (pcall vim.treesitter.start buf lang)]
      (when (not ok)
        (vim.notify (.. "Failed to start Tree-sitter for " lang ":\n"
                        (tostring err))
                    vim.log.levels.ERROR)))))

(fn install_and_start [ts buf lang]
  (: (ts.install lang)
     :await
     (fn [err installed]
       (if err
           (vim.notify (.. "Failed to install the Tree-sitter parser for "
                           lang
                           ".\n"
                           (tostring err))
                       vim.log.levels.ERROR)
           (when installed
             (v/later #(start_treesitter buf lang)))))))

(fn setup []
  (let [ts (require :nvim-treesitter)
        available (ts.get_available)]
    (v/autocmd :FileType
               {:callback
                (fn [ev]
                  (let [lang (vim.treesitter.language.get_lang ev.match)]
                    (when (v/contains? available lang)
                      (if (v/contains? (ts.get_installed :parsers) lang)
                          (start_treesitter ev.buf lang)
                          (install_and_start ts ev.buf lang)))))})))

[(plugin :nvim-treesitter/nvim-treesitter
         {:branch :main :build ":TSUpdate" :config setup :lazy false})
 (plugin :auipga/hmts.nvim {:branch :patch-1})
 (plugin :m-demare/hlargs.nvim {:event :VeryLazy :opts {}})]
