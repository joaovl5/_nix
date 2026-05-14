;; define leader key first to avoid conflicts
(set vim.g.mapleader " ")
(set vim.g.maplocalleader " ")

(vim.loader.enable)

(local uv (or vim.uv vim.loop))
(local lazypath (.. (vim.fn.stdpath :data) :/lazy/lazy.nvim))

(when (not (uv.fs_stat lazypath))
  (let [lazyrepo "https://github.com/folke/lazy.nvim.git"
        out (vim.fn.system [:git
                            :clone
                            "--filter=blob:none"
                            :--branch=stable
                            lazyrepo
                            lazypath])]
    (when (not= vim.v.shell_error 0)
      (vim.api.nvim_echo [["Failed to clone lazy.nvim:\n" :ErrorMsg]
                          [out :WarningMsg]
                          ["\nPress any key to exit..."]]
                         true {})
      (vim.fn.getchar)
      (os.exit 1))))

(vim.opt.rtp:prepend lazypath)

(set _G.Config {})
(set _G.dd (fn [...]
             (Snacks.debug.inspect ...)))

(set _G.bt (fn []
             (Snacks.debug.backtrace)))

(if (= (vim.fn.has :nvim-0.11) 1)
    (set vim._print (fn [_ ...]
                      (dd ...)))
    (set vim.print dd))

(let [plugin-loader (require :lib.plugin-loader)
      plugins [(doto {:lazy false :priority 1000}
                 (tset 1 :Olical/nfnl))]]
  (vim.list_extend plugins (plugin-loader.load))
  ((. (require :lazy) :setup) plugins
                              {:ui {:border :rounded}
                               :performance {:rtp {:reset false}}}))

(require :options)
