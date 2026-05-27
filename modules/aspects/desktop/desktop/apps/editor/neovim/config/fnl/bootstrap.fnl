;; define leader key first to avoid conflicts
(set vim.g.mapleader " ")
(set vim.g.maplocalleader " ")

(import-macros {: p!} :./lib/init-macros)

(vim.loader.enable)

(local {: v/contains?
        : v/echo
        : v/env
        : v/extend
        : v/fs-stat
        : v/getchar
        : v/has?
        : v/rtp-prepend
        : v/stdpath
        : v/sys} (require :lib/nvim))

(local {: str? : tbl? : ->lower} (require :lib.utils))
(local lazypath (.. (v/stdpath :data) :/lazy/lazy.nvim))

(when (not (v/fs-stat lazypath))
  (let [lazyrepo "https://github.com/folke/lazy.nvim.git"
        out (v/sys [:git
                    :clone
                    "--filter=blob:none"
                    :--branch=stable
                    lazyrepo
                    lazypath])]
    (when (not= vim.v.shell_error 0)
      (v/echo [["Failed to clone lazy.nvim:\n"
                :ErrorMsg
                [out :WarningMsg]
                ["\nPress any key to exit..."]]
               true
               {}])
      (v/getchar)
      (os.exit 1))))

(v/rtp-prepend lazypath)

(set _G.Config {})
(set _G.dd (fn [...]
             (Snacks.debug.inspect ...)))

(set _G.bt (fn []
             (Snacks.debug.backtrace)))

(if (v/has? :nvim-0.11)
    (set vim._print (fn [_ ...]
                      (_G.dd ...)))
    (set vim.print _G.dd))

(fn single-spec? [value]
  (and (tbl? value)
       (or (str? (. value 1))
           (str? value.dir)
           (str? value.import)
           (str? value.url))
       (= (. value 2) nil)))

(fn child-specs [value]
  (if (not (tbl? value)) []
      (single-spec? value) [value]
      value))

(fn make-eager-spec [spec]
  (when (tbl? spec)
    (set spec.lazy false)
    (each [_ child (ipairs (child-specs spec.dependencies))]
      (make-eager-spec child))
    (each [_ child (ipairs (child-specs spec.specs))]
      (make-eager-spec child)))
  spec)

(fn make-eager-plugins [plugins]
  (each [_ spec (ipairs plugins)]
    (make-eager-spec spec))
  plugins)

(fn truthy-env? [value]
  (v/contains? ["1" "true" "yes"] (->lower (or value ""))))

(fn eager-plugins? []
  (truthy-env? (v/env :NVIM_EAGER_PLUGINS)))

(require :plugins.keys._groups)

(let [plugin-loader (require :lib.plugin-loader)
      plugins [(p! :Olical/nfnl
                   (lazy false)
                   {:priority 1000})]]
  (v/extend plugins (plugin-loader.load))
  (when (eager-plugins?)
    (make-eager-plugins plugins))
  ((. (require :lazy) :setup) plugins
                              {:ui {:border :rounded}
                               :performance {:rtp {:reset false}}}))

(require :options)
