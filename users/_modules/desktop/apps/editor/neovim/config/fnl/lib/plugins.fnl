(fn opt [key]
  (fn [value]
    {key value}))

(fn keys [...]
  "Return flattened Lazy key specs."
  (let [specs []]
    (each [_ item (ipairs [...])]
      (if (and (= (type item) :table) (= (type (. item 1)) :table))
          (each [_ spec (ipairs item)]
            (table.insert specs spec))
          (table.insert specs item)))
    {:keys specs}))

{:event (opt :event)
 :ft (opt :ft)
 :keys keys
 :opts (opt :opts)
 :deps (opt :dependencies)
 :prio (opt :priority)
 :priority (opt :priority)
 :version (opt :version)
 :cmd (opt :cmd)
 :lazy (opt :lazy)
 :config (opt :config)
 :init (opt :init)
 :builtin (opt :builtin)
 :main (opt :main)}
