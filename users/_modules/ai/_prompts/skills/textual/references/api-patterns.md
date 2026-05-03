# Textual API Patterns

This file focuses on behavior APIs: events/messages, reactives, workers, screens, bindings/actions, testing, and content.

## App Lifecycle

```python
class MyApp(App):
    TITLE = "Title"
    SUB_TITLE = "Subtitle"
    CSS_PATH = "app.tcss"

    def compose(self) -> ComposeResult:
        yield Header()
        yield MainWidget()
        yield Footer()

    def on_mount(self) -> None:
        self.notify("Ready")

    def on_unmount(self) -> None:
        ...
```

Common app/screen/widget lifecycle hooks:

| Handler                                      | When                         |
| -------------------------------------------- | ---------------------------- |
| `compose()`                                  | Build initial child widgets  |
| `on_mount()`                                 | Node has been mounted        |
| `on_unmount()`                               | Node removed                 |
| `on_show()` / `on_hide()`                    | Visibility changes           |
| `on_resize()`                                | Size changes                 |
| `on_screen_resume()` / `on_screen_suspend()` | Screen activated/deactivated |
| `on_focus()` / `on_blur()`                   | Focus changes                |

`App.run()` starts the app and returns the value passed to `exit(result)`. `self.exit(result=None, return_code=0, message=None)` exits.

## Events and Messages

Low-level events come from `textual.events`; widget messages are nested classes on widgets.

### Input / Focus / Mouse Events

| Event                                | Useful data                                                |
| ------------------------------------ | ---------------------------------------------------------- |
| `Key`                                | `.key`, `.character`, `.name`, `.is_printable`, `.aliases` |
| `Paste`                              | `.text`                                                    |
| `Click`                              | `.x`, `.y`, `.button`, `.shift`, `.meta`, `.control`       |
| `MouseDown` / `MouseUp`              | mouse position/button/modifiers                            |
| `MouseMove`                          | mouse movement and modifiers                               |
| `MouseScrollUp` / `MouseScrollDown`  | scroll position/modifiers                                  |
| `Enter` / `Leave`                    | cursor entered/left widget                                 |
| `Focus` / `Blur`                     | widget focus changes                                       |
| `DescendantFocus` / `DescendantBlur` | descendant focus changes                                   |

### Handler Naming

```python
def on_button_pressed(self, event: Button.Pressed) -> None: ...
def on_input_changed(self, event: Input.Changed) -> None: ...
def on_data_table_row_selected(self, event: DataTable.RowSelected) -> None: ...
def on_key(self, event: events.Key) -> None: ...
```

Messages bubble up the DOM. Stop or alter propagation when needed:

```python
event.stop()
event.prevent_default()
```

### `@on` Decorator

```python
from textual import on

@on(Button.Pressed, "#yes")
def handle_yes(self) -> None:
    ...

@on(Input.Changed, "#search", value="")
def handle_empty_search(self) -> None:
    ...
```

Use `@on(message_type, selector=None, **field_filters)` for selective handlers and to avoid broad handler methods with manual branching.

### Custom Messages

```python
from textual.message import Message
from textual.widget import Widget

class ItemPicker(Widget):
    class Picked(Message):
        def __init__(self, item_id: str) -> None:
            self.item_id = item_id
            super().__init__()

    def choose(self, item_id: str) -> None:
        self.post_message(self.Picked(item_id))

class Parent(Widget):
    def on_item_picker_picked(self, event: ItemPicker.Picked) -> None:
        self.load_item(event.item_id)
```

Pattern: children emit intent; parents decide app behavior.

## Reactivity Patterns

```python
from textual.reactive import reactive, var

class WidgetState(Widget):
    count = reactive(0)
    cache_key = var("")
    rows = reactive([], recompose=True)
    size_hint = reactive(0, layout=True)
    status = reactive("idle", bindings=True)

    def validate_count(self, value: int) -> int:
        return max(0, value)

    def watch_count(self, old: int, new: int) -> None:
        ...

    def compute_is_empty(self) -> bool:
        return self.count == 0
```

| Mechanism                | Use                                            |
| ------------------------ | ---------------------------------------------- |
| `reactive(default)`      | UI state that triggers refresh                 |
| `var(default)`           | Watchable state without automatic refresh      |
| `watch_<name>(old, new)` | Side effects after change                      |
| `validate_<name>(value)` | Clamp/coerce/reject assigned value             |
| `compute_<name>()`       | Read-only computed reactive value              |
| `layout=True`            | Change requires layout recalculation           |
| `recompose=True`         | Change reruns `compose()`                      |
| `bindings=True`          | Change refreshes binding display/enabled state |
| `always_update=True`     | Watch even when old == new                     |

Use `self.set_reactive(type(self).field, value)` in initialization when you need to avoid triggering watchers. Do not mutate mutable reactive values in place if the UI needs notification; assign a new value.

## Actions and Bindings

### Binding Forms

```python
from textual.binding import Binding

BINDINGS = [
    ("q", "quit", "Quit"),
    ("ctrl+s", "save", "Save"),
    Binding("?", "help", "Help", show=True, priority=True),
    Binding("ctrl+z", "undo", "Undo", id="undo", key_display="^Z"),
]
```

Binding fields: `key`, `action`, `description`, `show`, `priority`, `id`, `key_display`, `tooltip`, `system`, `group`.

### Action Methods

```python
def action_save(self) -> None:
    ...

def action_set_color(self, color: str) -> None:
    ...
```

Action string examples:

- `"quit"` -> `action_quit()` in current namespace.
- `"app.quit"` -> app action.
- `"screen.help"` -> screen action namespace.
- `"set_color('red')"` -> passes Python literal argument.

### Dynamic Actions

```python
def check_action(self, action: str, parameters: tuple[object, ...]) -> bool | None:
    if action == "save" and not self.dirty:
        return None   # show disabled
    if action == "delete" and not self.selection:
        return False  # hide and prevent
    return True
```

Call `refresh_bindings()` when enabling/disabling state changes, or make the state a reactive with `bindings=True`.

## Workers

### Decorator

```python
from textual import work
from textual.worker import get_current_worker

@work(exclusive=True, group="search")
async def search(self, query: str) -> None:
    results = await api.search(query)
    self.results = results

@work(thread=True, exclusive=True)
def read_file(self, path: Path) -> None:
    data = path.read_text()
    if not get_current_worker().is_cancelled:
        self.call_from_thread(self.apply_data, data)
```

| Parameter       | Default     | Meaning                               |
| --------------- | ----------- | ------------------------------------- |
| `exclusive`     | `False`     | Cancel existing workers in same group |
| `group`         | `"default"` | Group for exclusivity/cancellation    |
| `thread`        | `False`     | Run sync function in thread           |
| `name`          | `""`        | Debug name                            |
| `exit_on_error` | `True`      | Exit app if worker raises             |
| `description`   | `None`      | Human/debug description               |

### Manual Workers

```python
worker = self.run_worker(coro(), name="load", exclusive=True)
worker.cancel()
await worker.wait()
```

### Worker Rules

- Async workers can update UI from the app loop.
- Thread workers cannot safely call most Textual UI APIs directly.
- Use `self.call_from_thread(callback, *args, **kwargs)` from threads.
- `post_message()` is thread-safe.
- Check `get_current_worker().is_cancelled` in long-running work.
- Removing the DOM node that owns a worker cancels its workers.

### Worker State

```python
from textual.worker import Worker


def on_worker_state_changed(self, event: Worker.StateChanged) -> None:
    match event.worker.state:
        case Worker.State.SUCCESS:
            result = event.worker.result
        case Worker.State.ERROR:
            error = event.worker.error
        case Worker.State.CANCELLED:
            ...
```

States: `PENDING`, `RUNNING`, `SUCCESS`, `ERROR`, `CANCELLED`.

## Timers

```python
self.set_interval(1.0, self.tick)      # repeat
self.set_interval(1.0, self.tick, repeat=5)
self.set_timer(5.0, self.done)         # one-shot
```

Timers are message-pump helpers, not workers. Use for UI clocks/polling; avoid expensive callbacks.

## Screens

### Basic Screen

```python
from textual.screen import Screen, ModalScreen

class Home(Screen):
    def compose(self) -> ComposeResult:
        yield Static("Home")
```

### Stack Operations

```python
self.push_screen(Home())
self.push_screen("settings")
self.push_screen(ConfirmScreen(), callback=self.handle_result)
self.pop_screen()
self.switch_screen("home")
self.install_screen(SettingsScreen(), "settings")
self.uninstall_screen("settings")
```

### Modal Return Data

```python
class ConfirmScreen(ModalScreen[bool]):
    def on_button_pressed(self, event: Button.Pressed) -> None:
        self.dismiss(event.button.id == "yes")

class Parent(App):
    def ask(self) -> None:
        self.push_screen(ConfirmScreen(), callback=self.confirmed)

    def confirmed(self, result: bool | None) -> None:
        ...
```

Use callbacks from normal event handlers. In current Textual, `push_screen(..., wait_for_dismiss=True)` / `push_screen_wait()` are worker-oriented; verify context before awaiting dialog results.

### Modes

```python
class MyApp(App):
    MODES = {
        "main": MainScreen,
        "edit": EditScreen,
    }

    def action_edit(self) -> None:
        self.switch_mode("edit")
```

Modes maintain separate screen stacks. Use for major app modes, not small dialogs.

## Testing with Pilot

```python
async def test_app():
    app = MyApp()
    async with app.run_test(size=(80, 24), tooltips=False, notifications=False) as pilot:
        await pilot.press("tab", "enter")
        await pilot.click("#submit")
        await pilot.hover("#help")
        await pilot.pause()
        await pilot.wait_for_animation()
        await pilot.resize_terminal(100, 40)
        assert app.query_one("#status", Static).renderable == "Done"
```

Pilot methods commonly used:

| Method                                              | Purpose                                         |
| --------------------------------------------------- | ----------------------------------------------- |
| `press(*keys)`                                      | Simulate key presses                            |
| `type(text)`                                        | Type text (when available in installed version) |
| `click(widget_or_selector=None, offset=(0,0), ...)` | Mouse click                                     |
| `hover(...)`                                        | Mouse hover                                     |
| `pause()`                                           | Let messages/tasks settle                       |
| `wait_for_animation()`                              | Wait for running animations                     |
| `resize_terminal(width, height)`                    | Test responsive layout                          |
| `exit(result=None)`                                 | Exit app under test                             |

Always `await pilot.pause()` after actions that trigger async messages, workers, timers, or deferred rendering.

## Snapshot Testing

With `pytest-textual-snapshot`:

```python
def test_ui(snap_compare):
    assert snap_compare("app.py")


def test_with_keys(snap_compare):
    assert snap_compare("app.py", press=["tab", "enter"])


def test_with_pilot(snap_compare):
    async def setup(pilot):
        await pilot.click("#submit")
        await pilot.pause()

    assert snap_compare("app.py", run_before=setup)
```

First run should fail until baseline exists. Update baselines with `pytest --snapshot-update`. Keep terminal size deterministic.

## Animation

```python
widget.styles.animate("opacity", 0.0, duration=0.25)
widget.styles.animate("offset", (10, 0), duration=0.4, easing="out_back")
widget.styles.animate("opacity", 1.0, duration=0.2, delay=0.1, on_complete=self.done)
```

Use `duration` or `speed`; `easing` defaults to a cubic ease. Tests should wait for animations.

## Rich, Markup, and Content

### Rich Renderables

Any Rich renderable can be returned from `render()` or passed to display widgets/logs: `Text`, `Table`, `Syntax`, `Tree`, `Markdown`, `Panel`, etc.

### Markup

```python
Static("[b]bold[/] [#ff0000]red[/] [$accent]accent[/]", markup=True)
Static(user_text, markup=False)
```

Common tags: `[b]`, `[i]`, `[u]`, `[dim]`, `[s]`, `[r]`, foreground colors, `[on blue]`, theme variables. Actions and links:

```python
Static("[@click=app.bell]click[/]")
Static("[link='https://textual.textualize.io']docs[/]")
```

### `Content`

```python
from textual.content import Content

content = Content.from_markup("Hello [b]$name[/b]", name=user_input)
content = content.stylize(0, 5, "italic")
```

Use `Content.from_markup(..., name=value)` to safely escape interpolated values.

## Notifications

```python
self.notify("Saved")
self.notify("Failed", severity="error", timeout=5)
```

Use notifications for transient feedback rather than manually mounting `Toast` widgets.

## Debugging and Devtools

- Install `textual-dev` for the `textual` CLI/devtools package.
- Run with `textual run --dev app.py` for development support and live CSS reload where supported.
- Use `textual console` for the dev console.
- Use stable IDs/classes to make CSS and tests easier to inspect.
- If a click test fails, remember hit-testing is real: an overlaying widget may receive the click instead.

## Version-Sensitive Caveats

- Current Textual docs/source around v8.2.3 use `Select.NULL`; older examples may mention `Select.BLANK`.
- Python 3.8 support was dropped in Textual 6.3.0.
- Devtools were split into the separate `textual-dev` package in older 0.x releases; current CLI availability depends on installed packages.
- Threaded `@work` functions require `thread=True`.
- Screen CSS applies app-wide while the screen is active.
