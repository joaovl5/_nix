# SCSS and GTK Styling Reference

Sources: official Eww styling docs, widget docs, and linked GTK CSS docs

## Core model

- **GTK CSS:** styling uses GTK CSS even when the file is written as SCSS
- **Layout limits:** do not assume browser features such as flexbox, floats, or absolute positioning
- **Sizing caveat:** normal CSS width and height behavior also does not apply here
- **Layout first:** prefer widget attrs such as `:orientation`, `:halign`, `:valign`, `:hexpand`, and `:vexpand`
- **Before styling:** fix layout with widget attrs before styling around layout problems

## Current repo constraints

- **Reset rule:** `users/_modules/desktop/widgets/eww/config/bar/eww.scss` starts with `* { all: unset; }`
- **Consequence:** new widgets can look invisible or tiny until color, spacing, borders, and fonts are styled again
- **Selector proof:** check `.bar` with `eww inspector` before treating it as live
- **Caveat:** current Yuck does not set `:class "bar"`, so `.bar` may be live through runtime GTK behavior or may be dead SCSS

Current theme sample:

```scss
.bar {
  background-color: #000;
  border: 1px solid #2a2a2a;
  color: #b0b4bc;
  padding: 12px 4px;
  font-family: Kode Mono;
  font-size: 15.5px;
}
```

## Current selectors

```scss
.sidestuff slider
.metric scale trough highlight
.metric scale trough
.metric
.workspaces
.workspace-list
.workspace-button
.workspace-button.active
.workspace-button.focused
.workspace-button.urgent
.workspace-button.empty
.workspace-button:hover
```

Yuck currently emits these classes:

```text
centerstuff
sidestuff
workspaces
workspace-list workspace-list-secondary
workspace-list workspace-list-primary
workspace-button plus active/focused/urgent/empty state classes
metric
label
```

- **Match both sides:** if Yuck adds a class, add matching SCSS after the reset
- **Treat gaps as unknowns:** if SCSS names a class with no matching Yuck class, prove it with inspector first
- **GTK nodes:** nested selectors such as `.metric scale trough highlight` follow GTK node names
- **Not DOM:** they do not follow HTML DOM structure
- **State checks:** test selectors such as `:hover` against the live GTK node

## Styling a metric

The reusable `metric` widget emits:

```text
box.metric
  box.label
  scale
    trough
      highlight
      slider
```

- **Default reuse:** a new metric usually needs only another `(metric ...)` call
- **Why:** the shared trough and highlight selectors already exist
- **Extra classes:** add metric-specific classes only when color, spacing, or state must differ

## Debug workflow

- **Inspect first:** open `eww inspector` and inspect CSS Nodes for the widget that looks wrong
- **Confirm truth:** check node names, classes, and states before changing selectors
- **Adjust selectors:** update `eww.scss` to match the actual GTK tree
- **Reload when needed:** use `eww reload` if hot reload missed a style or config change
- **Check runtime state:** use `eww logs`, `eww state`, and `eww debug` when files and live state disagree

## Common styling traps

- **Missing class:** adding `:class "foo"` in Yuck and forgetting `.foo` in SCSS
- **Dead selector risk:** assuming `.bar` is active without inspector evidence
- **Unstyled helper class:** assuming helper classes such as `.label` are styled when no SCSS matches them
- **GTK nodes:** do not style `scale` like a web input
- **Use instead:** target GTK nodes such as `scale`, `trough`, `highlight`, and `slider`
- **Layout habits:** do not rely on browser layout habits instead of Eww or GTK layout attrs
- **Reset memory:** do not forget that `* { all: unset; }` removed defaults

## Source anchors

- **Eww config styling notes:** https://elkowar.github.io/eww/configuration.html#writing-your-eww-configuration
- **GTK theming:** https://elkowar.github.io/eww/working_with_gtk.html#gtk-theming
- **GTK debugger:** https://elkowar.github.io/eww/working_with_gtk.html#gtk-debugger
- **Widget global attrs:** https://elkowar.github.io/eww/widgets.html#widget
- **`scale`:** https://elkowar.github.io/eww/widgets.html#scale
- **GTK CSS overview:** https://docs.gtk.org/gtk3/css-overview.html
- **GTK CSS properties:** https://docs.gtk.org/gtk3/css-properties.html
