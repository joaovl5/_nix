;; fennel-ls: macro-file
;; [nfnl-macro]

(local {: str? : nil?} (require :./lib/utils))

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

{: do-req : let-req : plugin : key}
