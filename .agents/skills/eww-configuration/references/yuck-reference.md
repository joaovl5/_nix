# Yuck Reference for This Repo

Sources: official Eww configuration, expression, magic variable, and widget docs

## File model

- **Language split:** use Yuck for structure and `eww.scss` or `eww.css` for styling
- **Official layout:** docs show one config dir with `eww.yuck` and `eww.scss`
- **Repo caveat:** this repo keeps the active bar under `users/_modules/desktop/widgets/eww/config/bar/`, so prove the real `--config` target before running commands
- **Includes:** use `(include "./path/file.yuck")` to split config, but current repo files do not use it

```text
$XDG_CONFIG_HOME/eww/
  eww.yuck
  eww.scss
```

## Common forms

### Window

```lisp
(defwindow bar
  :monitor 0
  :windowtype "dock"
  :geometry (geometry :x "0%"
                      :y "0%"
                      :width "10px"
                      :height "50%"
                      :anchor "right center")
  (bar))
```

- **Window fields:** common ones are `:monitor`, `:geometry`, `:windowtype`, and platform-specific stacking or focus flags
- **Geometry:** `:geometry` combines `:x`, `:y`, `:width`, `:height`, and `:anchor`

### Widget

```lisp
(defwidget metric [label value onchange]
  (box :orientation "v"
       :class "metric"
    (box :class "label" label)
    (scale :min 0
           :max 101
           :active {onchange != ""}
           :value value
           :onchange onchange)))
```

- **One root:** widget bodies render exactly one root widget, so wrap sibling children in `box` or `centerbox`
- **Arguments:** required args are plain names, optional args use `?name` and default to `""`
- **Children:** wrapper widgets can render children with `(children)` or `(children :nth 0)`

## Attributes and expressions

- **Attributes:** use colon-prefixed attrs such as `:class`, `:orientation`, and `:onclick`
- **Expressions:** use `{expr}` for expression-valued attrs or text
- **Interpolation:** use `${expr}` only inside strings
- **JSON access:** use `object.field`, `array[0]`, `object["field"]`, and safe access with `?.` or `?.[index]`
- **Useful functions:** common helpers include `round`, `floor`, `ceil`, `min`, `max`, `jq`, `formattime`, and `formatbytes`

Repo examples:

```lisp
:value {EWW_RAM.used_mem_perc}
:value {round((1 - (EWW_DISK["/"].free / EWW_DISK["/"].total)) * 100, 0)}
:active {onchange != ""}
```

## Variables

- **`defvar`:** manual state updated externally with `eww update name="new value"`
- **`defpoll`:** interval shell command for cheap periodic values
- **`deflisten`:** long-running command whose stdout lines update the variable, usually best for event streams
- **Magic vars:** available without imports, most update every 2s, and `EWW_TIME` updates every 1s

```lisp
(defvar foo "initial value")

(defpoll time :interval "10s"
  "date '+%H:%M'")

(deflisten workspace_state :initial "[]"
  "bash scripts/niri-workspaces.sh")
```

Relevant shapes:

```text
EWW_RAM  = { total_mem, free_mem, total_swap, free_swap, available_mem, used_mem, used_mem_perc }
EWW_DISK = { <mount_point>: { name, total, free, used, used_perc } }
EWW_CPU  = { cores: [{ core, freq, usage }], avg }
```

- **Disk caveat:** `EWW_DISK` can misreport some filesystems such as btrfs or zfs, so verify ranges before feeding a value to `scale`
- **Command helper:** `EWW_CMD` is useful inside handlers such as `:onclick "${EWW_CMD} update foo=bar"`

## Lists and dynamic widgets

- **Prefer `for`:** use it when rendering JSON arrays into repeated widgets
- **Avoid `literal`:** keep it for variables that must contain a full Yuck widget tree string
- **Performance:** upstream warns `literal` is not very efficient

```lisp
(defvar items "[1, 2, 3]")

(box
  (for entry in items
    (button :onclick "notify-send 'click' 'button ${entry}'"
      entry)))
```

```lisp
(defvar dynamic_yuck "(box (button 'foo') (button 'bar'))")
(literal :content dynamic_yuck)
```

## Widgets used in this bar

- **Containers:** `centerbox` lays out start, center, and end children, while `box` is the main general container
- **Interactive bits:** `button` handles click actions and `scale` handles ranged values
- **Text:** this bar uses bare text inside `box.label`, so add `(label ...)` only when text needs label-specific attrs
- **Dynamic trees:** `literal` can render arbitrary Yuck from a string, but avoid it for simple lists
- **Global attrs:** common ones include `:class`, `:halign`, `:valign`, `:visible`, `:active`, `:tooltip`, `:style`, and `:css`

## Source anchors

- **Configuration:** https://elkowar.github.io/eww/configuration.html
- **Windows:** https://elkowar.github.io/eww/configuration.html#creating-your-first-window
- **Widget definitions:** https://elkowar.github.io/eww/configuration.html#your-first-widget
- **Variables:** https://elkowar.github.io/eww/configuration.html#adding-dynamic-content
- **`for`:** https://elkowar.github.io/eww/configuration.html#generating-a-list-of-widgets-from-json-using-for
- **`literal`:** https://elkowar.github.io/eww/configuration.html#dynamically-generated-widgets-with-literal
- **Expressions:** https://elkowar.github.io/eww/expression_language.html
- **Magic vars:** https://elkowar.github.io/eww/magic-vars.html
- **Widgets:** https://elkowar.github.io/eww/widgets.html
