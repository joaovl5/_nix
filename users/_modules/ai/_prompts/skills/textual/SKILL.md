---
name: textual-tui
description: Use when building Python terminal user interfaces with the Textual framework: TUI apps, widgets, Textual CSS/TCSS, DOM queries, reactivity, messages/events, key bindings, workers, screens, testing, or Rich renderables.
---

# Textual TUI Framework

Textual is a Python framework for terminal user interfaces. Treat it as a retained-mode UI framework: build a widget tree, style it with Textual CSS, move data through reactive attributes, and communicate user intent with messages/actions.

**Official docs:** https://textual.textualize.io/
**Source:** https://github.com/Textualize/textual
**Version note:** reference checked against current docs/source around Textual `v8.2.3`; verify exact signatures when version pinning matters.

## First Decision

| Task                 | Start here                                                             |
| -------------------- | ---------------------------------------------------------------------- |
| New app              | App skeleton + `compose()` + TCSS layout                               |
| Add UI               | Built-in widgets and containers first; custom widgets only when needed |
| Handle state         | `reactive`/`var`, `watch_<name>`, `compute_<name>`                     |
| Handle user intent   | `BINDINGS` + `action_*`; widget messages for controls                  |
| Slow I/O or CPU work | `@work`, `run_worker`, or thread workers with `call_from_thread()`     |
| Navigation/dialogs   | `Screen`, `ModalScreen`, `push_screen`, callbacks/dismiss              |
| Testing              | `app.run_test()` and Pilot; snapshot tests for visual regressions      |

## Minimal App

```python
from textual.app import App, ComposeResult
from textual.containers import VerticalScroll
from textual.widgets import Footer, Header, Static


class MyApp(App[None]):
    TITLE = "My App"
    SUB_TITLE = "Textual demo"
    CSS_PATH = "my_app.tcss"
    BINDINGS = [("q", "quit", "Quit"), ("d", "toggle_dark", "Dark")]

    def compose(self) -> ComposeResult:
        yield Header(show_clock=True)
        with VerticalScroll(id="content"):
            yield Static("Hello, [b]Textual[/b]!", markup=True)
        yield Footer()


if __name__ == "__main__":
    MyApp().run()
```

Run:

```bash
python my_app.py
textual run my_app.py
textual run --dev my_app.py  # with textual-dev installed; live CSS/devtools support
```

## Core Model

- Tree: `App -> Screen -> Widget -> children`; queries and CSS selectors walk this tree.
- Composition: `compose()` declares initial children with `yield` and container context managers.
- Lifecycle: `on_mount()` runs after mounting; `on_unmount()` runs when removed.
- Data flow: parents set child attributes/reactives; children emit messages upward.
- Rendering: most custom UI uses `Static.update()` or child widgets; low-level widgets implement `render()` or `render_line()`.
- Styling: prefer `.tcss` via `CSS_PATH`; use `DEFAULT_CSS` for reusable widget defaults.

## Composition, Mounting, Queries

```python
from textual.widget import Widget
from textual.widgets import Button, Static

class Panel(Widget):
    def compose(self) -> ComposeResult:
        yield Static("Ready", id="status")
        yield Button("Go", id="go", variant="primary")

    async def on_mount(self) -> None:
        await self.mount(Static("Mounted later", classes="extra"))
        status = self.query_one("#status", Static)
        status.update("Mounted")

    def disable_buttons(self) -> None:
        self.query("Button").add_class("disabled")
```

- `mount(*widgets, before=..., after=...)` and `mount_all(...)` return awaitables. Await them before querying newly mounted descendants.
- `query(selector)` returns `DOMQuery`; batch methods include `.add_class()`, `.remove_class()`, `.toggle_class()`, `.set_class()`, `.remove()`.
- `query_one("#id", Type)` returns one typed widget and raises if missing/wrong.
- Selectors use Textual CSS syntax: `Button`, `#id`, `.class`, `A B`, `A > B`, pseudo-classes.

## Reactivity

```python
from textual.reactive import reactive, var
from textual.widget import Widget

class Counter(Widget):
    count = reactive(0)                       # refreshes on change
    name = var("")                           # watchable, no auto-refresh
    layout_count = reactive(0, layout=True)   # also triggers layout
    items = reactive([], recompose=True)      # reruns compose() on change
    value = reactive(0, always_update=True)   # watcher runs even if equal

    def validate_count(self, value: int) -> int:
        return max(0, value)

    def watch_count(self, old: int, new: int) -> None:
        self.notify(f"count={new}")

    def compute_doubled(self) -> int:
        return self.count * 2
```

Use reactives for UI state that should trigger refresh/layout/watchers. Use plain attributes for internal data that does not affect UI. In custom `__init__`, call `super().__init__()`; if you must initialize a reactive without watchers, use `self.set_reactive(type(self).field, value)`.

**Current-version caveat:** Textual uses `compute_<name>()` methods for computed reactives; do not assume a `@computed` decorator exists.

## Events, Messages, and `@on`

Textual has low-level events (`Key`, `Click`, `Mount`, `Focus`, `Resize`, etc.) and widget messages (`Button.Pressed`, `Input.Changed`, `DataTable.RowSelected`, etc.). Handlers follow `on_<message_name>` naming.

```python
from textual import events, on
from textual.message import Message
from textual.widgets import Button
from textual.widget import Widget

class Choice(Widget):
    class Selected(Message):
        def __init__(self, value: str) -> None:
            self.value = value
            super().__init__()

    def compose(self) -> ComposeResult:
        yield Button("Yes", id="yes")
        yield Button("No", id="no")

    @on(Button.Pressed, "#yes")
    def yes(self) -> None:
        self.post_message(self.Selected("yes"))

    def on_key(self, event: events.Key) -> None:
        if event.key == "escape":
            event.stop()
```

- Messages bubble up by default; call `event.stop()` to stop propagation.
- `event.prevent_default()` prevents default/base behavior.
- `post_message()` is safe from thread workers; most UI methods are not.
- Prefer specific widget messages over broad `on_key()`/`on_click()` when possible.

## Key Bindings and Actions

```python
from textual.binding import Binding

class MyApp(App):
    BINDINGS = [
        ("q", "quit", "Quit"),
        ("ctrl+s", "save", "Save"),
        Binding("?", "help", "Help", show=True, priority=True),
        Binding("ctrl+z", "undo", "Undo", id="undo"),
    ]

    def action_save(self) -> None:
        self.notify("Saved")

    def check_action(self, action: str, parameters: tuple[object, ...]) -> bool | None:
        if action == "undo" and not self.can_undo:
            return None   # visible but disabled
        return True
```

- Action string syntax: `"quit"`, `"app.quit"`, `"set_color('red')"`.
- Bindings can live on App, Screen, or focusable Widget.
- Use `priority=True` for global shortcuts that should run before focused-widget bindings.
- Return from `check_action`: `True` enabled+visible, `False` disabled+hidden, `None` disabled+visible.
- Call `refresh_bindings()` after state changes, or use `reactive(..., bindings=True)`.
- Make custom key-focused widgets with `class MyWidget(Widget, can_focus=True): ...`.

## Workers and Timers

Use workers for slow I/O or CPU work so the UI loop remains responsive.

```python
from textual import work
from textual.worker import get_current_worker

class MyApp(App):
    @work(exclusive=True)
    async def fetch_async(self, url: str) -> None:
        async with httpx.AsyncClient() as client:
            response = await client.get(url)
        self.query_one("#output", Static).update(response.text)

    @work(thread=True, exclusive=True)
    def fetch_sync(self, url: str) -> None:
        data = urllib.request.urlopen(url).read().decode()
        if not get_current_worker().is_cancelled:
            self.call_from_thread(self.query_one("#output", Static).update, data)
```

- `@work(exclusive=True)` cancels previous same-group workers before starting a new one.
- `thread=True` is required for blocking synchronous APIs.
- Thread workers must not directly mutate UI. Use `call_from_thread()` or `post_message()`.
- Workers are tied to the DOM node where they start; removing the node cancels its workers.
- Use `set_interval(seconds, callback)` for recurring timers and `set_timer(seconds, callback)` for one-shots; timers are not workers.

## Screens and Dialogs

```python
from textual.screen import ModalScreen
from textual.widgets import Button, Label
from textual.containers import Horizontal

class ConfirmScreen(ModalScreen[bool]):
    def compose(self) -> ComposeResult:
        yield Label("Continue?")
        with Horizontal():
            yield Button("Yes", id="yes", variant="success")
            yield Button("No", id="no", variant="error")

    def on_button_pressed(self, event: Button.Pressed) -> None:
        self.dismiss(event.button.id == "yes")

class MyApp(App):
    def ask(self) -> None:
        self.push_screen(ConfirmScreen(), callback=self.on_confirmed)

    def on_confirmed(self, result: bool | None) -> None:
        self.notify(f"confirmed={result}")
```

- Use `Screen` for full views and `ModalScreen[T]` for modal dialogs returning `T` via `dismiss(result)`.
- `push_screen(screen, callback=...)`, `pop_screen()`, `switch_screen(screen)`, `install_screen(screen, name)`.
- Named screens: `SCREENS = {"settings": SettingsScreen}` then `push_screen("settings")`.
- Use callbacks for screen results from normal handlers.
- `push_screen(..., wait_for_dismiss=True)` / `push_screen_wait()` are worker-oriented patterns in current Textual; do not blindly `await push_screen()` expecting a dialog result.
- Screen CSS applies while the screen is active, but is app-wide, not scoped to descendants only.

## Textual CSS Quick Reference

```css
Screen {
  layout: vertical;
}

Header {
  dock: top;
}

#sidebar {
  dock: left;
  width: 24;
  border-right: solid $primary;
}

#content {
  height: 1fr;
  overflow-y: auto;
}

.card {
  padding: 1 2;
  margin: 1;
  border: round $accent;
  background: $surface;
}

.grid-area {
  layout: grid;
  grid-size: 3 2;
  grid-columns: 1fr 2fr 1fr;
  grid-gutter: 1 2;
}

Button:hover {
  text-style: bold;
}
```

- Units: integer cells, `%`, `fr`, `vw`/`vh`, `w`/`h`, `auto`.
- Layouts: `vertical`, `horizontal`, `grid`; `dock` removes widget from flow and pins to an edge.
- Box model: margin > border > padding > content. Default `box-sizing: border-box`.
- Stacking: use `layers` and `layer`; Textual does not use browser `z-index`.
- Alignment split:
  - `align`: position child widgets inside a container.
  - `content-align`: position content inside a widget.
  - `text-align`: align text flow.
- Type selectors match subclasses too (`Static` matches custom `class X(Static)`), unlike browser CSS.

Full reference: [references/css-reference.md](references/css-reference.md).

## Built-in Widgets

Most-used imports from `textual.widgets`:

| Widget                                                     | Use                                                 |
| ---------------------------------------------------------- | --------------------------------------------------- |
| `Button`                                                   | Click action; emits `Button.Pressed`                |
| `Input`, `MaskedInput`                                     | Single-line input, validation, masks                |
| `TextArea`                                                 | Multi-line editor with optional syntax highlighting |
| `Select`, `OptionList`, `SelectionList`                    | Selection controls                                  |
| `Checkbox`, `Switch`, `RadioSet`/`RadioButton`             | Boolean/choice controls                             |
| `Static`, `Label`, `Pretty`, `Digits`                      | Display text/renderables/objects/digits             |
| `DataTable`                                                | Tabular data with cursor and selection events       |
| `Tree`, `DirectoryTree`                                    | Hierarchical data/filesystem browsing               |
| `ListView`/`ListItem`                                      | Vertical list of selectable items                   |
| `Tabs`, `TabbedContent`, `ContentSwitcher`, `Collapsible`  | Content navigation/toggling                         |
| `Markdown`, `MarkdownViewer`, `RichLog`, `Log`             | Rich text, markdown, logs                           |
| `ProgressBar`, `Sparkline`, `LoadingIndicator`             | Progress/status visuals                             |
| `Header`, `Footer`, `Toast`, `Rule`, `Link`, `Placeholder` | Common app chrome/utilities                         |

Full reference: [references/widgets-reference.md](references/widgets-reference.md).

## Containers

Import from `textual.containers`:

| Container                            | Layout/behavior                           |
| ------------------------------------ | ----------------------------------------- |
| `Container`                          | Basic vertical container                  |
| `Vertical`, `Horizontal`             | Fill parent in vertical/horizontal layout |
| `VerticalGroup`, `HorizontalGroup`   | Size to content                           |
| `VerticalScroll`, `HorizontalScroll` | Scroll on one axis                        |
| `ScrollableContainer`                | Scrollable container                      |
| `Grid`, `ItemGrid`                   | Grid layouts                              |
| `Center`, `Middle`, `CenterMiddle`   | Centering helpers                         |

## Testing

```python
async def test_counter():
    app = MyApp()
    async with app.run_test(size=(80, 24)) as pilot:
        await pilot.press("tab", "enter")
        await pilot.click("#increment")
        await pilot.pause()
        assert app.query_one("#count", Static).renderable == "2"
```

Pilot essentials: `press(*keys)`, `click(selector_or_widget, offset=(0, 0))`, `hover(...)`, `pause()`, `wait_for_animation()`, `resize_terminal(width, height)`, `exit(result)`.

Snapshot testing uses `pytest-textual-snapshot` and `snap_compare(...)`; update baselines with `pytest --snapshot-update`.

Full reference: [references/api-patterns.md](references/api-patterns.md).

## Rich and Content

- Widgets can render Rich renderables (`Text`, `Table`, `Syntax`, `Panel`, `Markdown`, etc.).
- `Static(..., markup=True)` supports Rich/Textual markup; set `markup=False` for literal user text.
- Prefer `textual.content.Content.from_markup("Hello [b]$name[/b]", name=user_input)` when mixing markup with user values so values are escaped.
- Markup supports actions: `[@click=app.bell]click me[/]`.

## CLI and Ecosystem

- `textual run module_or_file.py` runs an app.
- `textual run --dev ...` connects to devtools/live CSS reload when `textual-dev` is installed.
- `textual console` opens the developer console.
- `textual serve ...` / `textual-serve` can host apps in the browser; treat browser hosting as version/tooling-sensitive.
- `pytest-textual-snapshot` provides snapshot testing.

## Common Mistakes

| Mistake                                          | Fix                                                                                          |
| ------------------------------------------------ | -------------------------------------------------------------------------------------------- |
| Blocking the event loop with I/O                 | Use async APIs or `@work(thread=True)`                                                       |
| Mutating UI from a thread worker                 | Use `call_from_thread()` or `post_message()`                                                 |
| Querying immediately after `mount()`             | `await self.mount(widget)` first                                                             |
| Using `on_key()` for normal shortcuts            | Prefer `BINDINGS` + `action_*`                                                               |
| Forgetting `can_focus=True`                      | Add it to custom widgets that need key focus                                                 |
| Expecting web CSS behavior exactly               | Remember Textual-specific selectors, units, layers, and type subclass matching               |
| Confusing `align`, `content-align`, `text-align` | Use the property that matches children/content/text                                          |
| Assuming Screen CSS is scoped                    | Screen CSS applies app-wide while active                                                     |
| Using `Select.BLANK` on current Textual          | Use `Select.NULL` for blank/no selection                                                     |
| Re-rendering too much                            | Update child widgets/reactives; use `render_line()` only for high-performance custom drawing |
| Not calling `super().__init__()`                 | Always call `super()` in custom widgets/apps/screens                                         |

## Reference Files

Load these only when needed:

- [references/css-reference.md](references/css-reference.md): selectors, units, layout, style properties, dynamic classes.
- [references/widgets-reference.md](references/widgets-reference.md): built-in widgets, messages, containers, custom widget patterns.
- [references/api-patterns.md](references/api-patterns.md): events, messages, workers, screens, bindings, testing, animations, content.
