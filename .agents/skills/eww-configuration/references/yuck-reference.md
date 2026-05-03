# Yuck Reference for This Repo

Sources: official Eww configuration docs, expression docs, magic variables docs, and widgets docs.

## File model

Eww is configured in Yuck, an S-expression language, and styled with `eww.scss` or `eww.css`.

Official default layout:

```text
$XDG_CONFIG_HOME/eww/
  eww.yuck
  eww.scss
```

This repo currently stores the active bar under `users/_modules/desktop/widgets/eww/config/bar/`. Verify the actual `--config` path before running Eww commands.

Use `(include "./path/file.yuck")` to split a large Yuck file. The current repo config does not use `include`.

## Forms used most often

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

Common window fields:

- `:monitor`: index, name, `<primary>`, or JSON-array fallback string.
- `:geometry`: `:x`, `:y`, `:width`, `:height`, `:anchor`.
- X11-specific docs include `:stacking`, `:wm-ignore`, `:reserve`, `:windowtype`.
- Wayland-specific docs include `:stacking`, `:exclusive`, `:focusable`, `:namespace`.

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

Rules:

- Widget bodies contain exactly one root widget; wrap multiple children in `box` or `centerbox`.
- Required args are plain names; optional args use `?name` and default to `""`.
- Wrapper widgets can render children with `(children)` or `(children :nth 0)`.

## Attributes, expressions, and strings

- Attributes are colon-prefixed: `:class`, `:orientation`, `:onclick`.
- Use `{expr}` for expression-valued attributes/content.
- Use `${expr}` for interpolation inside strings.
- JSON access supports `object.field`, `array[0]`, and `object["field"]`.
- Safe access uses `?.` / `?.[index]`.
- Useful functions include `round`, `floor`, `ceil`, `min`, `max`, `jq`, `formattime`, and `formatbytes`.

Repo examples:

```lisp
:value {EWW_RAM.used_mem_perc}
:value {round((1 - (EWW_DISK["/"].free / EWW_DISK["/"].total)) * 100, 0)}
:active {onchange != ""}
```

## Variables

### `defvar`

Manual state. Update externally with `eww update name="new value"`.

```lisp
(defvar foo "initial value")
```

### `defpoll`

Interval shell command. Good for cheap periodic values.

```lisp
(defpoll time :interval "10s"
  "date '+%H:%M'")
```

Options documented upstream include `:initial` and `:run-while`.

### `deflisten`

Long-running command whose stdout lines update the variable. Prefer this for event streams, including workspace changes, when a reliable stream exists.

```lisp
(deflisten workspace_state :initial "[]"
  "scripts/workspaces")
```

### Magic variables

Available without imports. Most update every 2s; `EWW_TIME` updates every 1s.

Relevant shapes:

```text
EWW_RAM  = { total_mem, free_mem, total_swap, free_swap, available_mem, used_mem, used_mem_perc }
EWW_DISK = { <mount_point>: { name, total, free, used, used_perc } }
EWW_CPU  = { cores: [{ core, freq, usage }], avg }
```

`EWW_DISK` may be inaccurate on some filesystems such as btrfs and zfs. Verify value ranges before feeding a value to `scale`.

`EWW_CMD` is useful in event handlers, for example `:onclick "${EWW_CMD} update foo=bar"`.

## Lists and dynamic widgets

Prefer `for` over `literal` when rendering a JSON array:

```lisp
(defvar items "[1, 2, 3]")

(box
  (for entry in items
    (button :onclick "notify-send 'click' 'button ${entry}'"
      entry)))
```

Use `literal` only when the variable must contain a complete Yuck widget tree string:

```lisp
(defvar dynamic_yuck "(box (button 'foo') (button 'bar'))")
(literal :content dynamic_yuck)
```

Upstream warns `literal` is not very efficient; keep it as a last resort.

## Widgets used in this bar

- `centerbox`: exactly three children, laid out start/center/end in the chosen orientation.
- `box`: main container; important attrs include `:orientation`, `:spacing`, `:space-evenly`.
- `button`: child widget; `:onclick`, `:onmiddleclick`, `:onrightclick` run commands.
- `scale`: slider; uses `:min`, `:max`, `:value`, `:active`, `:onchange`, `:orientation`.
- `label` or plain string content: use `label` when you need text-specific attrs.
- `literal`: render arbitrary Yuck from a string; avoid for simple lists.

Global attrs include `:class`, `:halign`, `:valign`, `:visible`, `:active`, `:tooltip`, `:style`, and `:css`.

## Source anchors

- Configuration: https://elkowar.github.io/eww/configuration.html
- Windows: https://elkowar.github.io/eww/configuration.html#creating-your-first-window
- Widget definitions: https://elkowar.github.io/eww/configuration.html#your-first-widget
- Variables: https://elkowar.github.io/eww/configuration.html#adding-dynamic-content
- `for`: https://elkowar.github.io/eww/configuration.html#generating-a-list-of-widgets-from-json-using-for
- `literal`: https://elkowar.github.io/eww/configuration.html#dynamically-generated-widgets-with-literal
- Expressions: https://elkowar.github.io/eww/expression_language.html
- Magic vars: https://elkowar.github.io/eww/magic-vars.html
- Widgets: https://elkowar.github.io/eww/widgets.html
