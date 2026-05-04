# Textual CSS Reference

Textual CSS (usually `.tcss`) resembles web CSS but targets terminal widgets, not HTML. It supports type/id/class selectors, pseudo-classes, variables, nesting, terminal-specific units, layout, and widget-specific style properties.

## Loading and Precedence

```python
class MyApp(App):
    CSS_PATH = "app.tcss"          # path or list of paths
    CSS = "Button { width: 20; }"  # inline app CSS

class MyWidget(Widget):
    DEFAULT_CSS = """
    MyWidget { height: auto; }
    """
```

- `CSS_PATH`: external `.tcss` file(s), relative to the Python module by default.
- `CSS`: inline CSS string, loaded after `CSS_PATH`.
- `DEFAULT_CSS`: widget defaults, intended to be overridden by app CSS.
- `Screen.CSS` / `Screen.CSS_PATH`: apply while the screen is active; not descendant-scoped.
- Dynamic inline style is available through `widget.styles`, but prefer TCSS for stable styling.

## Selectors

| Type             | Syntax      | Example             | Notes                        |
| ---------------- | ----------- | ------------------- | ---------------------------- |
| Universal        | `*`         | `*`                 | All widgets                  |
| Type             | `ClassName` | `Button`            | Matches class and subclasses |
| ID               | `#id`       | `#send`             | Set with `id="send"`         |
| Class            | `.name`     | `.active`           | Set with `classes="active"`  |
| Multiple classes | `.a.b`      | `.selected.error`   | AND match                    |
| Descendant       | `A B`       | `#dialog Button`    | Any depth                    |
| Child            | `A > B`     | `#sidebar > Button` | Direct children only         |
| Pseudo           | `:state`    | `Button:hover`      | State-based                  |

Common pseudo-classes: `:hover`, `:focus`, `:blur`, `:disabled`, `:enabled`, `:dark`, `:empty`, `:first-child`, `:last-child`, `:first-of-type`, `:last-of-type`, `:even`, `:odd`, `:focus-within`, `:inline`.

Specificity: IDs > classes/pseudo-classes > types. `!important` overrides normal precedence.

**Textual-specific caveat:** type selectors match subclasses. `Static { ... }` also matches `class Status(Static)`. Use a class or specific type selector when subclass matching is too broad.

## Variables

```css
$brand: #ff6600;
$panel-border: round $brand;

#panel {
  border: $panel-border;
}
```

Variables start with `$`, can reference other variables, and are used in values (not selectors). Theme variables include `$primary`, `$secondary`, `$accent`, `$background`, `$surface`, `$panel`, `$boost`, `$foreground`, `$success`, `$warning`, `$error`, `$input-cursor-foreground`, `$input-cursor-background`, `$input-selection-background`, `$input-selection-foreground`.

## Nesting

```css
#dialog {
  border: heavy $primary;

  Button {
    width: 1fr;
  }

  &.warning {
    border: heavy $warning;
  }
}
```

Without `&`, nested selectors become descendants. `&` refers to the parent selector.

## Units and Scalars

| Unit       | Example        | Meaning                              |
| ---------- | -------------- | ------------------------------------ |
| Integer    | `30`           | Terminal cells / rows                |
| Percentage | `50%`          | Percent of parent widget             |
| Fraction   | `1fr`, `2fr`   | Share remaining space proportionally |
| Viewport   | `50vw`, `50vh` | Percent of terminal dimensions       |
| Widget     | `50w`, `50h`   | Percent of available widget space    |
| Auto       | `auto`         | Size to content                      |

Spacing shorthand: `1` all sides, `1 2` vertical/horizontal, `1 2 3 4` top/right/bottom/left.

## Box Model

Outside to inside: margin -> border/outline -> padding -> content.

- Default: `box-sizing: border-box` (padding/border included in `width`/`height`).
- `box-sizing: content-box` adds padding/border around the content dimensions.
- Sibling margins overlap; padding does not.
- `outline` looks like a border but does not affect widget size.

## Layout

| Property   | Values                           | Meaning                              |
| ---------- | -------------------------------- | ------------------------------------ |
| `layout`   | `vertical`, `horizontal`, `grid` | Arrange child widgets                |
| `dock`     | `top`, `right`, `bottom`, `left` | Pin to edge and remove from flow     |
| `layers`   | names                            | Define layer order (leftmost lowest) |
| `layer`    | name                             | Assign widget to a layer             |
| `offset`   | `<x> <y>`                        | Shift after layout                   |
| `position` | `relative`, `absolute`           | Normal or absolute positioning       |

Vertical is the normal stacked layout; horizontal arranges children left-to-right; grid fills cells left-to-right/top-to-bottom.

### Grid

| Property       | Example        | Meaning                      |
| -------------- | -------------- | ---------------------------- |
| `grid-size`    | `3 2`          | 3 columns, 2 rows            |
| `grid-columns` | `1fr 2fr auto` | Column widths                |
| `grid-rows`    | `3 1fr`        | Row heights                  |
| `grid-gutter`  | `1 2`          | Vertical/horizontal cell gap |
| `column-span`  | `2`            | Widget spans 2 columns       |
| `row-span`     | `2`            | Widget spans 2 rows          |

```css
Grid {
  layout: grid;
  grid-size: 3 2;
  grid-columns: 1fr 2fr 1fr;
  grid-rows: auto 1fr;
  grid-gutter: 1 2;
}

#wide {
  column-span: 2;
}
```

## Alignment

| Property                   | Applies to                                | Values                                               |
| -------------------------- | ----------------------------------------- | ---------------------------------------------------- |
| `align`                    | Child widget placement inside a container | `<horizontal> <vertical>`                            |
| `align-horizontal`         | Child placement horizontal axis           | `left`, `center`, `right`                            |
| `align-vertical`           | Child placement vertical axis             | `top`, `middle`, `bottom`                            |
| `content-align`            | Content inside a widget                   | `<horizontal> <vertical>`                            |
| `content-align-horizontal` | Content horizontal axis                   | `left`, `center`, `right`                            |
| `content-align-vertical`   | Content vertical axis                     | `top`, `middle`, `bottom`                            |
| `text-align`               | Text flow                                 | `left`, `center`, `right`, `justify` where supported |

Use `align` to move widgets, `content-align` to move widget content, and `text-align` to align lines of text.

## Dimensions and Spacing

| Property                   | Values                                    |
| -------------------------- | ----------------------------------------- |
| `width`, `height`          | scalar (`20`, `1fr`, `50%`, `auto`, etc.) |
| `min-width`, `max-width`   | scalar                                    |
| `min-height`, `max-height` | scalar                                    |
| `margin`                   | spacing shorthand                         |
| `padding`                  | spacing shorthand                         |

`height: 1fr` is the usual way to let a content area fill remaining space between docked/header/footer widgets.

## Display, Visibility, Overflow

| Property                   | Values                                | Effect                          |
| -------------------------- | ------------------------------------- | ------------------------------- |
| `display`                  | `block`, `none`                       | `none` removes from layout      |
| `visibility`               | `visible`, `hidden`                   | hidden but still reserves space |
| `opacity`                  | `0.0` to `1.0`                        | Transparency                    |
| `overflow`                 | `visible`, `hidden`, `scroll`, `auto` | Both axes                       |
| `overflow-x`, `overflow-y` | same                                  | Per-axis                        |

Default overflow varies by widget/container. Use `overflow-y: auto` for scrollable content, or use `VerticalScroll` / `ScrollableContainer`.

## Borders and Outlines

```css
.card {
  border: round $primary;
  border-title: "Title";
  border-subtitle: "Subtitle";
  outline: solid $accent;
}
```

Border styles include `solid`, `heavy`, `wide`, `tall`, `round`, `double`, `dashed`, `dotted`, `hkey`, `vkey`, `inner`, `outer`, `blank`, `hidden`, `none`, `top`.

Directional borders: `border-top`, `border-right`, `border-bottom`, `border-left`.

Title/subtitle styling: `border-title-color`, `border-title-background`, `border-title-style`, `border-title-align`, and matching `border-subtitle-*` properties.

## Colors and Text

Color formats: named colors (`darkblue`), hex (`#9932cc`, `#9932cc7f`), `rgb(...)`, `rgba(...)`, `hsl(...)`.

| Property          | Values                                                                          |
| ----------------- | ------------------------------------------------------------------------------- |
| `color`           | foreground color                                                                |
| `background`      | background color                                                                |
| `background-tint` | `<color> <percentage>`                                                          |
| `tint`            | `<color> <percentage>` overlay                                                  |
| `text-style`      | `bold`, `italic`, `underline`, `dim`, `strike`, `reverse` (combine with spaces) |
| `text-wrap`       | `wrap`, `nowrap`, `ellipsis`                                                    |
| `text-overflow`   | `ellipsis`, `clip`, `fold`                                                      |
| `text-opacity`    | `0.0` to `1.0`                                                                  |

## Scrollbars

| Property                                                    | Purpose                           |
| ----------------------------------------------------------- | --------------------------------- |
| `scrollbar-size`                                            | Width/height of scrollbars        |
| `scrollbar-visibility`                                      | `auto`, `always`, `never`, `hide` |
| `scrollbar-gutter`                                          | `auto`, `stable`                  |
| `scrollbar-color`                                           | Thumb color                       |
| `scrollbar-background`                                      | Track color                       |
| `scrollbar-color-active`, `scrollbar-color-hover`           | Thumb interactive states          |
| `scrollbar-background-active`, `scrollbar-background-hover` | Track interactive states          |
| `scrollbar-corner-color`                                    | Corner color                      |

## Links and Miscellaneous

| Property                                   | Purpose                                                          |
| ------------------------------------------ | ---------------------------------------------------------------- |
| `link-color`, `link-color-hover`           | Link foreground                                                  |
| `link-background`, `link-background-hover` | Link background                                                  |
| `link-style`, `link-style-hover`           | Link text style                                                  |
| `hatch`                                    | Pattern fill (`<character> <color>`)                             |
| `keyline`                                  | Thin line color                                                  |
| `pointer`                                  | Mouse pointer style (`default`, `pointer`, `text`, `move`, etc.) |

## Runtime Classes

```python
widget.add_class("active")
widget.remove_class("active")
widget.toggle_class("active")
widget.set_class(condition, "active")
widget.has_class("active")

self.query(".item").add_class("dim")
```

Changing classes triggers style recomputation. Prefer classes over mutating many inline style properties.

## Style Animation

```python
widget.styles.animate("opacity", 0.0, duration=0.25)
widget.styles.animate("offset", (10, 0), duration=0.4, easing="out_back")
```

Use animations sparingly in terminal apps; tests may need `await pilot.wait_for_animation()`.
