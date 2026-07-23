# Start with the upstream defaults.
(put config :border-width 2)
(put config :outer-padding 4)
(put config :inner-padding 4)
(put config :border-sticky 0x356239)
(put config :border-normal 0x444444)
(put config :border-focused 0xffffff)

(put config :tap-to-click true)
(put config :natural-scroll false)
(put config :dwt true)
(put config :focus-follows-mouse true)

(put config :layout :tile)
(put config :main-ratio 0.60)
(put config :focus-wrap true)
(put config :float-on-top true)
(put config :new-window-position :start)

(set (config :rules)
     @[[:app-id "mpv" {:float true}]
       [:title "Picture-in-Picture" {:float true :sticky true}]])

# Keep the closest useful equivalents of the Niri bindings.
(set (config :xkb-bindings)
     @[[:grave {:mod4 true} (action/spawn ["swaync-client" "--toggle-panel"])]
       [:Return {:mod4 true} (action/spawn ["footclient"])]
       [:q {:mod4 true} (action/close)]
       [:space {:mod4 true} (action/spawn ["anyrun" "--plugins" "libapplications.so"])]
       [:a {:mod4 true} (action/spawn ["hexecute"])]
       [:n {:mod4 true} (action/spawn ["anyrun" "--plugins" "libsymbols.so"])]
       [:c {:mod4 true} (action/spawn ["anyrun" "--plugins" "librink.so"])]
       [:Delete {:mod4 true :mod1 true} (action/spawn ["anyrun" "--plugins" "libactions.so"])]
       [:h {:mod4 true} (action/focus :prev)]
       [:j {:mod4 true} (action/focus :next)]
       [:k {:mod4 true} (action/focus :prev)]
       [:l {:mod4 true} (action/focus :next)]
       [:h {:mod4 true :shift true} (action/focus-output)]
       [:l {:mod4 true :shift true} (action/focus-output)]
       [:f {:mod4 true} (action/fullscreen)]
       [:f {:mod4 true :shift true} (action/float)]
       [:equal {:mod4 true} (action/window-ratio 0.05)]
       [:minus {:mod4 true} (action/window-ratio -0.05)]
       [:z {:mod4 true :ctrl true} (action/layout :tile)]
       [:x {:mod4 true :ctrl true} (action/layout :grid)]
       [:s {:mod4 true :ctrl true} (action/layout :scroller)]
       [:c {:mod4 true :ctrl true} (action/layout :monocle)]
       [:f {:mod4 true :ctrl true} (action/layout :floating)]
       [:s {:mod4 true :shift true}
        (action/spawn ["sh" "-c" "grim -g \"$(slurp)\" - | wl-copy"])]
       [:e {:mod4 true :shift true} (action/exit-session)]
       [:Escape {:mod4 true :mod1 true :shift true :ctrl true} (action/passthrough)]])

(for i 1 10
  (let [keysym (keyword i)]
    (array/push (config :xkb-bindings) [keysym {:mod4 true} (action/focus-tag i)])
    (array/push (config :xkb-bindings) [keysym {:mod4 true :shift true} (action/set-tag i)])))

(array/push (config :xkb-bindings) [:0 {:mod4 true} (action/focus-tag 10)])
(array/push (config :xkb-bindings) [:0 {:mod4 true :shift true} (action/set-tag 10)])

(set (config :pointer-bindings)
     @[[:left {:mod4 true} (action/pointer-move)]
       [:right {:mod4 true} (action/pointer-resize)]])
