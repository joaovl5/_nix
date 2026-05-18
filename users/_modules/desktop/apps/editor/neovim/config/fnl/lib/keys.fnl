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

(fn M.specs [...]
  "Return flattened key specs."
  (let [items []]
    (each [_ item (ipairs [...])]
      (if (spec-list? item)
          (each [_ spec (ipairs item)]
            (table.insert items spec))
          (table.insert items item)))
    items))

(fn M.register-group! [id name prefix]
  "Register a which-key group."
  (tset _G.kgroups id {:name name :prefix prefix}))


(fn M.kgroup [id name prefix ...]
  "Register a which-key group and return its prefixed specs."
  (M.register-group! id name prefix)
  (let [specs [{1 prefix :group name}]]
    (each [_ item (ipairs [...])]
      (add-prefixed! specs prefix item))
    specs))

(fn M.group [id ...]
  "Prefix key specs with a registered key group."
  (let [registered (. _G.kgroups id)]
    (when (not registered)
      (error (..
               "Unknown key group: "
               id
               "\nAvailable groups: "
               (_G.vim.inspect _G.kgroups))))
    (let [specs [{1 registered.prefix :group registered.name}]]
      (each [_ item (ipairs [...])]
        (add-prefixed! specs registered.prefix item))
      specs)))

M
