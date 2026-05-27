(fn opt [key]
  (fn [value]
    {key value}))

(set _G.which_key_plugin_icon_specs (or _G.which_key_plugin_icon_specs []))

(fn copy-key [target source key]
  (let [value (. source key)]
    (when value
      (tset target key value))))

(fn which-key-icon-spec [spec]
  (when spec.icon
    (let [icon-spec {1 (. spec 1) :icon spec.icon}]
      (copy-key icon-spec spec :desc)
      (copy-key icon-spec spec :group)
      (copy-key icon-spec spec :mode)
      icon-spec)))

(fn add-which-key-icon-spec! [spec]
  (let [icon-spec (which-key-icon-spec spec)]
    (when icon-spec
      (table.insert _G.which_key_plugin_icon_specs icon-spec))))

(fn lazy-key-spec [spec]
  "Return a lazy.nvim-safe key spec, dropping which-key-only fields."
  (let [copied {}]
    (each [key value (pairs spec)]
      (when (not= key :icon)
        (tset copied key value)))
    copied))

(fn add-lazy-key-spec! [specs spec]
  (add-which-key-icon-spec! spec)
  (table.insert specs (lazy-key-spec spec)))

(fn keys [...]
  "Return flattened Lazy key specs."
  (let [specs []]
    (each [_ item (ipairs [...])]
      (if (and (= (type item) :table) (= (type (. item 1)) :table))
          (each [_ spec (ipairs item)]
            (add-lazy-key-spec! specs spec))
          (add-lazy-key-spec! specs item)))
    {:keys specs}))

{:event (opt :event)
 :ft (opt :ft)
 :keys keys
 :opts (opt :opts)
 :deps (opt :dependencies)
 :prio (opt :priority)
 :priority (opt :priority)
 :version (opt :version)
 :enabled (opt :enabled)
 :cmd (opt :cmd)
 :lazy (opt :lazy)
 :config (opt :config)
 :init (opt :init)
 :builtin (opt :builtin)
 :main (opt :main)}
