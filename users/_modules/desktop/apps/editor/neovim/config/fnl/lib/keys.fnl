(local M {})

(fn M.l [lhs]
  "Prefix lhs with <leader>."
  (.. :<leader> lhs))

(fn M.c [key]
  "Wrap key in <C-...>."
  (.. :<C- key ">"))

(fn M.a [key]
  "Wrap key in <A-...>."
  (.. :<A- key ">"))

(fn M.cmd [command]
  "Wrap command as a Vim command rhs."
  (.. :<cmd> command :<cr>))

(fn M.desc [text]
  "Return a key spec description option."
  {:desc text})

(fn M.icon [glyph ?color]
  "Return a which-key icon option."
  {:icon (if ?color
             {:icon glyph :color ?color}
             glyph)})

(fn M.m [...]
  "Return a key spec mode option."
  {:mode [...]})

(set _G.kgroups (or _G.kgroups {}))

(fn merge! [target source]
  (each [key value (pairs source)]
    (tset target key value))
  target)

(fn key-option? [value]
  (and (= (type value) :table)
       (= nil (. value 1))))

(fn group-options [...]
  (let [opts {}
        items []]
    (each [_ item (ipairs [...])]
      (if (key-option? item)
          (merge! opts item)
          (table.insert items item)))
    (values opts items)))

(fn key-spec [lhs rhs opts]
  (let [spec (merge! {1 lhs} opts)]
    (when rhs
      (tset spec 2 rhs))
    spec))

(fn M.bind [lhs ?rhs ...]
  "Return Lazy key specs."
  (let [opts {}]
    (when (key-option? ?rhs)
      (merge! opts ?rhs))
    (each [_ opt (ipairs [...])]
      (merge! opts opt))
    [(key-spec lhs (if (key-option? ?rhs) nil ?rhs) opts)]))

(fn spec-list? [item]
  (and (= (type item) :table)
       (= (type (. item 1)) :table)))

(fn copy-spec [spec]
  (let [copied {}]
    (merge! copied spec)))

(fn prepend-spec [prefix spec]
  (let [prefixed (copy-spec spec)]
    (tset prefixed 1 (.. prefix (. spec 1)))
    prefixed))

(fn add-prefixed! [specs prefix item]
  (if (spec-list? item)
      (each [_ spec (ipairs item)]
        (table.insert specs (prepend-spec prefix spec)))
      (table.insert specs (prepend-spec prefix item)))
  specs)

(fn ensure-list [value]
  (if (= (type value) :table)
      value
      [value]))

(fn filetype-in? [filetypes filetype]
  (accumulate [matches? false
               _ candidate (ipairs filetypes)
               &until matches?]
    (= candidate filetype)))

(fn with-buffer [spec bufnr]
  (let [buffered (copy-spec spec)]
    (tset buffered :buffer bufnr)
    buffered))

(fn buffer-specs [specs bufnr]
  (icollect [_ spec (ipairs specs)]
    (with-buffer spec bufnr)))

(fn apply-ft-specs! [filetypes specs bufnr]
  (when (and (_G.vim.api.nvim_buf_is_valid bufnr)
             (filetype-in? filetypes
                           (_G.vim.api.nvim_get_option_value
                             :filetype
                             {:buf bufnr})))
    ((. (require :which-key) :add) (buffer-specs specs bufnr))))

(fn apply-mode [mode spec]
  (when spec.mode
    (error (.. "with-mode cannot wrap a bind that already has mode: "
               (tostring (. spec 1)))))
  (let [moded (copy-spec spec)]
    (tset moded :mode mode)
    moded))

(fn M.specs [...]
  "Return flattened key specs."
  (let [items []]
    (each [_ item (ipairs [...])]
      (if (spec-list? item)
          (each [_ spec (ipairs item)]
            (table.insert items spec))
          (table.insert items item)))
    items))

(fn M.with-mode [mode ...]
  "Apply mode to key specs, erroring when a child already declares a mode."
  (icollect [_ spec (ipairs (M.specs ...))]
    (apply-mode mode spec)))

(fn M.register-plugin-icons! []
  "Register icon metadata collected from lazy plugin key specs."
  (when (and _G.which_key_plugin_icon_specs
             (< 0 (length _G.which_key_plugin_icon_specs)))
    ((. (require :which-key) :add) _G.which_key_plugin_icon_specs)))

(fn M.ft-keys [filetypes specs]
  "Register key specs for matching filetypes as buffer-local which-key maps."
  (let [filetypes (ensure-list filetypes)
        group (_G.vim.api.nvim_create_augroup :MyFiletypeKeys {:clear false})]
    (each [_ bufnr (ipairs (_G.vim.api.nvim_list_bufs))]
      (apply-ft-specs! filetypes specs bufnr))
    (_G.vim.api.nvim_create_autocmd
      :FileType
      {:group group
       :pattern filetypes
       :callback (fn [event]
                   (apply-ft-specs! filetypes specs event.buf))})))

(fn M.register-group! [id name prefix ...]
  "Register a which-key group."
  (let [(opts _) (group-options ...)]
    (tset _G.kgroups id {:name name :prefix prefix :opts opts})))

(fn group-spec [prefix name opts]
  (merge! {1 prefix :group name} opts))

(fn M.kgroup [id name prefix ...]
  "Register a which-key group and return its prefixed specs."
  (let [(opts items) (group-options ...)]
    (M.register-group! id name prefix opts)
    (let [specs [(group-spec prefix name opts)]]
      (each [_ item (ipairs items)]
        (add-prefixed! specs prefix item))
      specs)))

(fn M.group [id ...]
  "Prefix key specs with a registered key group."
  (let [registered (. _G.kgroups id)]
    (when (not registered)
      (error (..
               "Unknown key group: "
               id
               "\nAvailable groups: "
               (_G.vim.inspect _G.kgroups))))
    (let [specs [(group-spec registered.prefix registered.name registered.opts)]]
      (each [_ item (ipairs [...])]
        (add-prefixed! specs registered.prefix item))
      specs)))

M
