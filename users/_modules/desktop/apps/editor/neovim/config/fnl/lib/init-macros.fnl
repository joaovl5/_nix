;; fennel-ls: macro-file
;; [nfnl-macro]

(fn do-req [mod key ...]
  "Require a module and immediately call a function from it.
  (do-req :telescope.builtin :find_files {:hidden true})"
  `(let [name# (require ,mod)
         fun# (. name# ,key)]
     (fun# ,...)))

(fn let-req [[name mod] expr]
  "Require a module, bind it to a name, and evaluate an expression.
  (let-req [ts :telescope.builtin] (ts.find_files {:hidden true}))"
  `(let [,name (require ,mod)]
     ,expr))

; Lazy.nvim specific

(lambda plugin [identifier ?attrs]
  "Makes a Lazy.nvim plugin spec."
  (let [attrs (or ?attrs {})]
    (doto attrs (tset 1 identifier))))

(lambda key [lhs rhs ?attrs]
  "Makes a Lazy.nvim keybind spec."
  (let [attrs (or ?attrs {})]
    (doto attrs
      (tset 1 lhs)
      (tset 2 rhs))))

(fn call? [form name]
  (and (= :table (type form)) (= name (tostring (. form 1)))))

(fn tail [form]
  (let [args []]
    (each [i value (ipairs form)]
      (when (< 1 i)
        (table.insert args value)))
    args))

(fn call-with [mod key args]
  `((. ,mod ,key) ,(unpack args)))

(fn rewrite-lhs [lhs k]
  (if (call? lhs :l)
      (call-with k :l (tail lhs))
      (call? lhs :c)
      (call-with k :c (tail lhs))
      (call? lhs :a)
      (call-with k :a (tail lhs))
      (call? lhs :m)
      (let [args (tail lhs)]
        (call-with k :m
                   (icollect [i arg (ipairs args)]
                     (if (= i 1) arg (rewrite-lhs arg k)))))
      (and (= :table (type lhs)) (not (= nil (. lhs 1))))
      (icollect [_ item (ipairs lhs)]
        (rewrite-lhs item k))
      lhs))

(fn rewrite-rhs [rhs k]
  (if (call? rhs :cmd)
      (call-with k :cmd (tail rhs))
      rhs))

(fn rewrite-opt [opt k]
  (if (call? opt :desc)
      (call-with k :desc (tail opt))
      opt))

(fn rewrite-bind [form k]
  (let [args []]
    (when (. form 2)
      (table.insert args (rewrite-lhs (. form 2) k)))
    (when (. form 3)
      (table.insert args (rewrite-rhs (. form 3) k)))
    (each [i opt (ipairs form)]
      (when (< 3 i)
        (table.insert args (rewrite-opt opt k))))
    (call-with k :bind args)))

(fn rewrite-key-form [form k]
  (if (call? form :bind)
      (rewrite-bind form k)
      form))

(fn rewrite-keys [form p k]
  (let [args []]
    (each [i value (ipairs form)]
      (when (< 1 i)
        (table.insert args (rewrite-key-form value k))))
    (call-with p :keys args)))

(fn rewrite-plugin-form [form p k]
  (if (call? form :event) (call-with p :event (tail form))
      (call? form :ft) (call-with p :ft (tail form))
      (call? form :keys) (rewrite-keys form p k)
      (call? form :opts) (call-with p :opts (tail form))
      (call? form :dependencies) (call-with p :dependencies (tail form))
      (call? form :version) (call-with p :version (tail form))
      (call? form :cmd) (call-with p :cmd (tail form))
      form))

(lambda plugin! [identifier ...]
  "Makes a Lazy.nvim plugin spec from bounded DSL forms."
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

{: do-req : let-req : plugin : plugin! : key}
