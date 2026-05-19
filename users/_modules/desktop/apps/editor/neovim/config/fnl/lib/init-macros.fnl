;; fennel-ls: macro-file
;; [nfnl-macro]
(local M {})

(fn M.do-req [mod key ...]
  "Require a module and immediately call a function from it.
  (do-req :telescope.builtin :find_files {:hidden true})"
  `(let [name# (require ,mod)
         fun# (. name# ,key)]
     (fun# ,...)))

(fn M.let-req [[name mod] expr]
  "Require a module, bind it to a name, and evaluate an expression.
  (let-req [ts :telescope.builtin] (ts.find_files {:hidden true}))"
  `(let [,name (require ,mod)]
     ,expr))

; Lazy.nvim specific

(λ M.plugin [identifier ?attrs]
  "Makes a Lazy.nvim plugin spec."
  (let [attrs (or ?attrs {})]
    (doto attrs (tset 1 identifier))))

(λ M.key [lhs rhs ?attrs]
  "Makes a Lazy.nvim keybind spec."
  (let [attrs (or ?attrs {})]
    (doto attrs
      (tset 1 lhs)
      (tset 2 rhs))))

(fn call-name [form]
  "Return the string head of a call form, or nil for non-calls."
  (when (and (= :table (type form)) (not (= nil (. form 1))))
    (tostring (. form 1))))

(fn call? [form name]
  "Return true if form is a call whose head symbol matches name.
  Example: in `(event :VeryLazy)`, the head symbol is `event`, so
  `(call? form :event)` returns true."
  (= name (call-name form)))

(fn module-forms [mod]
  "Return exported helper names from a module as a lookup table."
  (let [forms {}]
    (each [name _ (pairs (require mod))]
      (tset forms (tostring name) true))
    forms))

(local plugin-forms (module-forms :lib.plugins))
(local key-forms (module-forms :lib.keys))

(fn tail [form]
  "Return call args after the head symbol as a dense vector.
  Example: `(tail (event :VeryLazy))` returns `[:VeryLazy]`."
  (let [args []]
    (each [i value (ipairs form)]
      (when (< 1 i)
        (table.insert args value)))
    args))

(fn call-with [mod key args]
  "Build AST call to key on module symbol mod with args.
  Example: `(call-with p :event [:VeryLazy])` emits `((. p :event) :VeryLazy)`."
  `((. ,mod ,key) ,(unpack args)))

(fn form-in? [forms form]
  (let [name (call-name form)]
    (and name (. forms name))))

(fn rewrite-key-value [value k]
  "Rewrite key helper forms in bounded DSL positions to lib.keys calls.
  Examples: `(l :cv)` becomes `(k.l :cv)`, `(cmd \"Foo\")` becomes
  `(k.cmd \"Foo\")`, and `(m :n :x)` becomes `(k.m :n :x)`."
  (if (form-in? key-forms value)
      (call-with k (call-name value) (tail value))
      value))

(fn rewrite-bind [form k]
  "Rewrite a `(bind lhs rhs opts...)` form to a lib.keys bind call."
  (let [args []]
    (each [i value (ipairs form)]
      (when (< 1 i)
        (table.insert args (rewrite-key-value value k))))
    (call-with k :bind args)))

(fn rewrite-key-item [form k]
  (if (call? form :bind)
      (rewrite-bind form k)
      (call? form "with-mode")
      (let [args [(. form 2)]]
        (each [i value (ipairs form)]
          (when (< 2 i)
            (table.insert args (rewrite-key-item value k))))
        (call-with k "with-mode" args))
      (call? form :group)
      (let [args []]
        (each [i value (ipairs form)]
          (when (< 1 i)
            (table.insert args
                          (if (= i 2)
                              value
                              (rewrite-key-item value k)))))
        (call-with k :group args))
      (rewrite-key-value form k)))

(fn rewrite-keys [form p k]
  "Rewrite a `(keys ...)` form to a lib.plugins keys call.
  Example: `(keys (bind ...))` becomes `(p.keys (k.bind ...))`."
  (let [args []]
    (each [i value (ipairs form)]
      (when (< 1 i)
        (table.insert args (rewrite-key-item value k))))
    (call-with p :keys args)))

(λ M.kgroup! [id name prefix ...]
  "Register a which-key group and add its rewritten binds through which-key."
  (let [k (gensym)
        wk (gensym)
        args [id name (rewrite-key-value prefix k)]]
    (each [_ form (ipairs [...])]
      (table.insert args (rewrite-key-item form k)))
    `(let [,k (require :lib.keys)
           ,wk (require :which-key)]
       ,(call-with wk :add [(call-with k :kgroup args)]))))

(λ M.keys! [...]
  "Add rewritten key binds through which-key without registering a group."
  (let [k (gensym)
        wk (gensym)
        args []]
    (each [_ form (ipairs [...])]
      (table.insert args (rewrite-key-item form k)))
    `(let [,k (require :lib.keys)
           ,wk (require :which-key)]
       ,(call-with wk :add [(call-with k :specs args)]))))

(λ M.ft-keys! [filetypes ...]
  "Add rewritten key binds through which-key for matching filetypes only."
  (let [k (gensym)
        args []]
    (each [_ form (ipairs [...])]
      (table.insert args (rewrite-key-item form k)))
    `(let [,k (require :lib.keys)]
       ,(call-with k :ft-keys [filetypes (call-with k :specs args)]))))

(fn rewrite-plugin-form [form p k]
  "Rewrite plugin-level DSL forms to lib.plugins calls.
  Examples: `(event :VeryLazy)` becomes `(p.event :VeryLazy)`,
  `(opts {})` becomes `(p.opts {})`, and `(keys ...)` is delegated to key rewriting."
  (if (call? form :keys) (rewrite-keys form p k)
      (form-in? plugin-forms form) (call-with p (call-name form) (tail form))
      form))

(λ M.p! [identifier ...]
  "Makes a Lazy.nvim plugin spec from bounded DSL forms.
  Example:
  `(p! :foo/bar
     (event :VeryLazy)
     (keys (bind (l :xx) (cmd \"Foo\") (desc \"Do thing\") (m :n :x)))
     (opts {}))`
  Rewrites exported plugin helpers like `(event ...)`, `(keys ...)`, and `(opts ...)`,
  plus exported key helpers inside `(keys ...)`, then merges helper result tables."
  (let [p (gensym)
        k (gensym)
        attrs (icollect [_ form (ipairs [...])]
                (rewrite-plugin-form form p k))]
    `(let [,p (require :lib.plugins)
           ,k (require :lib.keys)
           spec# {}]
       (each [_# attrs# (ipairs [,(unpack attrs)])]
         (each [key# value# (pairs attrs#)]
           (tset spec# key# value#)))
       (tset spec# 1 ,identifier)
       spec#)))

M
