(local M {})
(local {: v/fs-stat : v/stdpath} (require :lib/nvim))

(fn table? [value]
  (= (type value) :table))

(fn empty-table? [value]
  (and (table? value) (= (next value) nil)))

(fn lazy-spec? [value]
  (and (table? value) (or (= (type (. value 1)) :string)
                          (= (type value.dir) :string)
                          (= (type value.import) :string)
                          (= (type value.url) :string))))

(fn lazy-spec-list? [value]
  (when (and (table? value) (not (lazy-spec? value)))
    (var found false)
    (var valid true)
    (each [_ item (ipairs value)]
      (set found true)
      (when (not (lazy-spec? item))
        (set valid false)))
    (and found valid)))

(fn skipped-name? [name]
  (or (= name :index.fnl) (vim.startswith name "_")))

(fn fnl-file? [name]
  (vim.endswith name :.fnl))

(fn walk-plugin-files [dir prefix files]
  (each [name kind (vim.fs.dir dir)]
    (let [full-path (vim.fs.joinpath dir name)
          relpath (if (= prefix "")
                      name
                      (vim.fs.joinpath prefix name))]
      (if (= kind :directory)
          (when (not (skipped-name? name))
            (walk-plugin-files full-path relpath files))
          (when (and (= kind :file) (fnl-file? name) (not (skipped-name? name)))
            (table.insert files relpath))))))

(fn collect-plugin-files [root]
  (let [files []]
    (walk-plugin-files root "" files)
    (table.sort files)
    files))

(fn module-name [relpath]
  (let [stem (relpath:gsub "%.fnl$" "")
        dotted (stem:gsub "/" ".")]
    (.. :plugins. dotted)))

(fn add-plugin-module [plugins module-name exported]
  (if (lazy-spec? exported)
      (table.insert plugins exported)
      (lazy-spec-list? exported)
      (each [_ spec (ipairs exported)]
        (table.insert plugins spec))
      (or (= nil exported)
          (= false exported)
          (= true exported)
          (empty-table? exported))
      nil
      (vim.notify (.. "Ignoring non-plugin module " module-name)
                  vim.log.levels.WARN)))

(fn M.load [?opts]
  (let [opts (or ?opts {})
        root (or opts.root
                 (vim.fs.joinpath (v/stdpath :config) :fnl :plugins))
        plugins []]
    (when (v/fs-stat root)
      (each [_ relpath (ipairs (collect-plugin-files root))]
        (let [module (module-name relpath)
              exported (require module)]
          (add-plugin-module plugins module exported))))
    plugins))

M
