(fn event [value]
  "Return an event plugin option."
  {:event value})

(fn ft [value]
  "Return a filetype plugin option."
  {:ft value})

(fn keys [...]
  "Return flattened Lazy key specs."
  (let [specs []]
    (each [_ item (ipairs [...])]
      (if (and (= (type item) :table) (= (type (. item 1)) :table))
          (each [_ spec (ipairs item)]
            (table.insert specs spec))
          (table.insert specs item)))
    {:keys specs}))

(fn opts [value]
  "Return plugin opts."
  {:opts value})

(fn dependencies [value]
  "Return plugin dependencies."
  {:dependencies value})

(fn version [value]
  "Return a plugin version constraint."
  {:version value})

(fn cmd [value]
  "Return a plugin command trigger."
  {:cmd value})

{: event : ft : keys : opts : dependencies : version : cmd}
