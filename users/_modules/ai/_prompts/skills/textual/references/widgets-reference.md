# Textual Widgets Reference

Prefer built-in widgets and containers before writing custom widgets. Most emit typed messages; handle those messages in parents with `on_<widget>_<message>` or `@on(...)`.

## App Chrome and Display

### `Header`

```python
yield Header(show_clock=True)
```

Displays title/subtitle from `App.TITLE`, `App.SUB_TITLE`, and `self.title` / `self.sub_title`. `show_clock=True` displays a clock in current Textual; do not look for old `Clock`/`DigitClock` widgets in current `textual.widgets` exports.

### `Footer`

```python
yield Footer()
```

Shows visible key bindings from `BINDINGS`. Use `show=False` on bindings that should work but not appear. Use `check_action()` and `refresh_bindings()` for dynamic enable/disable display.

### `Static` and `Label`

```python
Static("[b]Rich markup[/b]", markup=True)
Label("Simple label")
```

- `Static` displays text or Rich renderables and can be updated with `.update(renderable)`.
- `Label` is for label text; use `Static` for general content panels.
- Use `markup=False` for literal untrusted/user-provided text.

### `Pretty`, `Digits`, `Rule`, `Link`, `Placeholder`

```python
Pretty(obj)                    # pretty-print Python object
Digits("12:34")                # large terminal digits
Rule(line_style="heavy")       # horizontal rule
Link("Docs", url="https://textual.textualize.io")
Placeholder("TODO")            # layout debugging placeholder
```

## Buttons and Boolean Controls

### `Button`

```python
Button("Save", id="save", variant="primary")

@on(Button.Pressed, "#save")
def save(self, event: Button.Pressed) -> None:
    ...
```

Variants: `default`, `primary`, `success`, `warning`, `error`. Message: `Button.Pressed` with `.button`.

### `Checkbox`

```python
Checkbox("Enable", value=True)

def on_checkbox_changed(self, event: Checkbox.Changed) -> None:
    enabled = event.value
```

Message: `Checkbox.Changed`; key data includes `.value`.

### `Switch`

```python
Switch(value=False)
```

Toggle control. Message: `Switch.Changed` with `.value`.

### `RadioSet` / `RadioButton`

```python
with RadioSet(id="mode"):
    yield RadioButton("Fast", id="fast", value=True)
    yield RadioButton("Safe", id="safe")

def on_radio_set_changed(self, event: RadioSet.Changed) -> None:
    selected = event.pressed
```

Use when exactly one option should be selected.

## Text Input

### `Input`

```python
from textual.validation import Number

Input(placeholder="Name", value="", id="name")
Input(type="password", placeholder="Password")
Input(validators=[Number(minimum=0, maximum=120)])
```

Common messages:

- `Input.Changed`: input value changed.
- `Input.Submitted`: user pressed Enter.

Useful properties: `.value`, `.cursor_position`, validation state. Use Textual validators from `textual.validation` where appropriate.

### `MaskedInput`

```python
MaskedInput(template="0000-0000-0000-0000")
```

Use for structured input like codes/card-like patterns. Template characters are version-sensitive; verify exact mask syntax in docs for strict validation.

### `TextArea`

```python
TextArea("print('hello')\n", language="python")

text_area = self.query_one(TextArea)
text = text_area.text
text_area.replace("new text")
text_area.insert("more")
text_area.delete()
text_area.clear()
```

Multi-line text editor with selection, optional soft wrapping, and optional syntax highlighting. Use for editing text, logs with selection, or code-like input.

## Selection Widgets

### `Select`

```python
Select(
    [("Small", "s"), ("Medium", "m"), ("Large", "l")],
    value="m",
    allow_blank=False,
)
```

A compact dropdown. In current Textual, blank/no selection uses `Select.NULL` (not old `Select.BLANK`). Message: `Select.Changed` with `.value`.

### `OptionList`

```python
OptionList("One", "Two", "Three")
```

List of options with keyboard/mouse navigation. Supports Rich renderables. Messages include option highlighted/selected events; selected events include option index/option data depending on version.

### `SelectionList`

```python
SelectionList(
    ("Python", "py", True),
    ("Rust", "rs", False),
)
```

Multi-select list. Use for checklists/preferences. Message: `SelectionList.SelectedChanged`.

### `ListView` / `ListItem`

```python
with ListView(id="items"):
    yield ListItem(Label("First"), id="first")
    yield ListItem(Label("Second"), id="second")

def on_list_view_selected(self, event: ListView.Selected) -> None:
    item = event.item
```

Use for custom row contents, not just text options.

## Data Widgets

### `DataTable`

```python
table = DataTable(cursor_type="row")
table.add_columns("Name", "Age", "City")
table.add_row("Alice", 30, "NYC", key="alice")
table.update_cell("alice", "Age", 31)
```

Features: rows/columns, cursor navigation, cell/row selection, updates, deletion. Messages include cell/row highlighted/selected variants. Use stable keys when updating cells later.

### `Tree`

```python
tree = Tree("Root")
branch = tree.root.add("Branch", data={"id": 1})
branch.add_leaf("Leaf")
tree.root.expand()
```

Hierarchical data. Node `.data` can hold application data. Messages include node selected/expanded/collapsed.

### `DirectoryTree`

```python
DirectoryTree("~/projects")
```

Filesystem tree. Use for file pickers/browsers. Messages include file/directory selection events; selected paths are `pathlib.Path` values in current APIs.

## Navigation and Content Switching

### `Tabs` and `TabbedContent`

```python
from textual.widgets import TabbedContent, TabPane

with TabbedContent(initial="settings"):
    with TabPane("Home", id="home"):
        yield Static("Home")
    with TabPane("Settings", id="settings"):
        yield Static("Settings")

self.query_one(TabbedContent).active = "home"
```

`TabbedContent` combines tabs with `ContentSwitcher`; only the active pane is visible. Messages include tab activated/disabled/enabled variants.

### `ContentSwitcher`

```python
with ContentSwitcher(initial="one"):
    yield Static("One", id="one")
    yield Static("Two", id="two")

self.query_one(ContentSwitcher).current = "two"
```

Use when you want switchable panels without visible tabs.

### `Collapsible`

```python
Collapsible(Static("Hidden details"), title="Details", collapsed=True)
```

Use for expandable sections.

## Markdown and Logs

### `Markdown` / `MarkdownViewer`

```python
Markdown("# Heading\n\nBody")
MarkdownViewer(markdown_text)
```

`Markdown` renders markdown content. `MarkdownViewer` adds navigation/table-of-contents behavior and is better for documents.

### `Log` / `RichLog`

```python
log = RichLog(markup=True, wrap=True)
log.write("[b]started[/b]")
log.write(rich_table)

plain = Log()
plain.write_line("line")
```

`RichLog` accepts Rich renderables. Writes may render after size/layout is known, so tests may need `await pilot.pause()`.

## Progress and Visual Status

### `ProgressBar`

```python
bar = ProgressBar(total=100, show_eta=True)
bar.update(progress=42)
bar.advance(1)
```

Use for determinate progress. Messages include changed/completed events.

### `Sparkline`

```python
Sparkline([1, 2, 5, 3, 8, 4])
```

Compact visual trend of numeric values.

### `LoadingIndicator`

```python
LoadingIndicator()
widget.loading = True  # many widgets support loading state/styling
```

Use for indeterminate background work.

### `Toast`

Usually create via `self.notify("message")` instead of mounting directly.

## Containers

Import from `textual.containers`.

| Container             | Layout               | Scroll | Typical use                |
| --------------------- | -------------------- | ------ | -------------------------- |
| `Container`           | vertical/default     | no     | Generic wrapper            |
| `Vertical`            | vertical             | no     | Fill parent vertically     |
| `VerticalGroup`       | vertical             | no     | Size to content            |
| `VerticalScroll`      | vertical             | y      | Main scrollable page       |
| `Horizontal`          | horizontal           | no     | Toolbar/row/sidebar layout |
| `HorizontalGroup`     | horizontal           | no     | Size to content row        |
| `HorizontalScroll`    | horizontal           | x      | Wide rows/tables/cards     |
| `ScrollableContainer` | vertical             | both   | Scrollable region          |
| `Grid`                | grid                 | no     | Explicit grid layout       |
| `ItemGrid`            | grid                 | no     | Repeating item cards       |
| `Center`              | horizontal centering | no     | Center child horizontally  |
| `Middle`              | vertical centering   | no     | Center child vertically    |
| `CenterMiddle`        | both                 | no     | Full centering             |

## Custom Widget Patterns

### Static-Based Widget

Most custom display widgets can subclass `Static`.

```python
class StatusDisplay(Static):
    DEFAULT_CSS = """
    StatusDisplay {
        height: 3;
        padding: 1 2;
        border: round $primary;
    }
    """

    def set_status(self, message: str) -> None:
        self.update(message)
```

### Composite Widget

Use `Widget` with `compose()` when a reusable component has children.

```python
class SearchBar(Widget):
    DEFAULT_CSS = """
    SearchBar { layout: horizontal; height: auto; }
    SearchBar Input { width: 1fr; }
    """

    class SearchRequested(Message):
        def __init__(self, query: str) -> None:
            self.query = query
            super().__init__()

    def compose(self) -> ComposeResult:
        yield Input(placeholder="Search...", id="query")
        yield Button("Go", id="go", variant="primary")

    def on_input_submitted(self, event: Input.Submitted) -> None:
        self.post_message(self.SearchRequested(event.value))

    @on(Button.Pressed, "#go")
    def go(self) -> None:
        self.post_message(self.SearchRequested(self.query_one("#query", Input).value))
```

### Focusable Widget

```python
class Counter(Static, can_focus=True):
    BINDINGS = [("up,k", "change(1)", "+"), ("down,j", "change(-1)", "-")]
    count = reactive(0)

    def render(self) -> str:
        return f"Count: {self.count}"

    def action_change(self, delta: int) -> None:
        self.count += delta
```

### High-Performance Drawing

For large custom renderables, prefer Textual's line API (`render_line`) over re-rendering a huge Rich object. Verify current `render_line` signatures in the docs/source for your Textual version before implementing; this is an advanced path.

## Widget Design Rules

- Expose state as reactives only when UI should respond to changes.
- Emit custom messages for user intent; avoid children directly mutating parent internals.
- Put reusable default styling in `DEFAULT_CSS`; app-specific styling in app `.tcss`.
- Keep `compose()` declarative; do dynamic insertion with `mount()`/`remove()` in handlers/workers.
- Prefer built-in messages (`Button.Pressed`, `Input.Submitted`) over low-level mouse/key events.
- Use stable `id` values for widgets queried by tests or event decorators.
