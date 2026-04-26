# SCSS and GTK Styling Reference

Sources: official Eww configuration docs, GTK theming docs, widgets docs, and linked GTK CSS docs.

## Core model

Eww styling is GTK CSS. SCSS is allowed and compiled to CSS by Eww, but GTK's CSS engine is not browser CSS.

Do not assume support for web layout features. Official Eww docs explicitly warn about unsupported animation features and layout properties such as flexbox, `float`, absolute positioning, and CSS `width`/`height` assumptions.

Use widget attributes for layout first (`:orientation`, `:halign`, `:valign`, `:hexpand`, `:vexpand`, widget width/height attrs), then use SCSS for appearance.

## Current repo style constraints

`users/_modules/desktop/eww/config/bar/eww.scss` starts with:

```scss
* {
  all: unset;
}
```

That reset is intentional but unforgiving. New widgets may look broken, tiny, or invisible until explicitly styled.

Current theme basics:

```scss
.bar {
  background-color: #000;
  border: 1px solid #2a2a2a;
  color: #b0b4bc;
  padding: 6px 3px;
  font-family: Iosevka Nerd Font;
  font-size: 18px;
}
```

Verify `.bar` with `eww inspector`; the Yuck currently does not explicitly set `:class "bar"`.

## Current selectors

```scss
.sidestuff slider
.metric scale trough highlight
.metric scale trough
.metric
.label-ram
.workspaces
.workspaces button:hover
```

Yuck currently emits these classes:

```text
centerstuff
sidestuff
workspaces
metric
label
```

Selector checklist:

- If a Yuck `:class` is new, add matching SCSS after the reset.
- If an SCSS selector has no matching Yuck class, verify it with inspector before relying on it.
- Nested selectors such as `.metric scale trough highlight` depend on GTK CSS node names, not HTML DOM nodes.
- State selectors like `:hover` should be tested on the live GTK node.

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

The existing SCSS styles the trough and highlight, so a new metric normally needs only another `(metric ...)` call. Add metric-specific classes only if the new metric needs different color, spacing, or state.

## Debug workflow

Use official Eww/GTK tools instead of guessing:

1. `eww inspector` — open GTK debugger and inspect CSS Nodes.
2. Select the widget that is not styled.
3. Confirm node names, classes, and states.
4. Adjust `eww.scss` selectors to match the actual node tree.
5. Use `eww reload` after style/config edits if hot reload misses a change.
6. If runtime state is suspect, use `eww logs`, `eww state`, and `eww debug`.

## Common styling traps

- Adding `:class "foo"` in Yuck and forgetting `.foo` in SCSS.
- Styling `.label-ram` when Yuck emits `.label`.
- Assuming `.bar` is active without inspector evidence.
- Styling `scale` like a web input instead of using GTK nodes (`scale`, `trough`, `highlight`, `slider`).
- Relying on flexbox or CSS dimensions instead of Eww/GTK layout attrs.
- Forgetting `* { all: unset; }` removed default colors, padding, borders, and fonts.

## Source anchors

- Eww config styling notes: https://elkowar.github.io/eww/configuration.html#writing-your-eww-configuration
- GTK theming: https://elkowar.github.io/eww/working_with_gtk.html#gtk-theming
- GTK debugger: https://elkowar.github.io/eww/working_with_gtk.html#gtk-debugger
- Widget global attrs: https://elkowar.github.io/eww/widgets.html#widget
- `scale`: https://elkowar.github.io/eww/widgets.html#scale
- GTK CSS overview: https://docs.gtk.org/gtk3/css-overview.html
- GTK CSS properties: https://docs.gtk.org/gtk3/css-properties.html
