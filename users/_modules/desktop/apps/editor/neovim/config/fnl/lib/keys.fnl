(fn l [lhs]
  "Prefix lhs with <leader>."
  (.. :<leader> lhs))

(fn c [key]
  "Wrap key in <C-...>."
  (.. :<C- key ">"))

(fn a [key]
  "Wrap key in <A-...>."
  (.. :<A- key ">"))

(fn cmd [command]
  "Wrap command as a Vim command rhs."
  (.. :<cmd> command :<cr>))

(fn desc [text]
  "Return a key spec description option."
  {:desc text})

(fn m [mode ...]
  "Group one or more lhs values under mode."
  {:__keys-kind :mode-group : mode :lhs [...]})

(fn merge! [target source]
  (each [key value (pairs source)]
    (tset target key value))
  target)

(fn grouped? [lhs]
  (and (= (type lhs) :table) (= lhs.__keys-kind :mode-group)))

(fn key-spec [lhs rhs opts ?mode]
  (let [spec (merge! {1 lhs 2 rhs} opts)]
    (when ?mode
      (tset spec :mode ?mode))
    spec))

(fn bind [lhs rhs ...]
  "Return Lazy key specs, expanding mode groups."
  (let [opts {}
        specs []]
    (each [_ opt (ipairs [...])]
      (merge! opts opt))
    (if (grouped? lhs)
        (each [_ grouped-lhs (ipairs lhs.lhs)]
          (table.insert specs (key-spec grouped-lhs rhs opts lhs.mode)))
        (and (= (type lhs) :table) (grouped? (. lhs 1)))
        (each [_ group (ipairs lhs)]
          (each [_ grouped-lhs (ipairs group.lhs)]
            (table.insert specs (key-spec grouped-lhs rhs opts group.mode))))
        (table.insert specs (key-spec lhs rhs opts)))
    specs))

{: l : c : a : cmd : desc : m : bind}
