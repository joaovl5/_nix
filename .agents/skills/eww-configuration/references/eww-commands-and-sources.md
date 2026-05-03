# Eww Commands and Source Map

## Command model

Official basics:

```bash
eww daemon
eww open <window_name>
```

For a separate config directory, official docs say every Eww command must include `--config /path/to/config/dir`, including `kill`, `logs`, and other commands.

Repo caveat: this repo links `users/_modules/desktop/widgets/eww/config` to `~/.config/eww`, but the actual Yuck file is under `bar/`. No launch command was found in repo search. If using the bar sub-config directly, the config directory is expected to be `~/.config/eww/bar`; verify the current CLI flag placement with `eww --help` or the existing launcher before documenting a command.

## Troubleshooting commands

Official troubleshooting flow:

```bash
eww reload
eww logs
eww state
eww debug
eww kill
eww open --debug <window_name>
eww inspector
```

Use cases:

- `eww reload`: hot reload missed a config/style change.
- `eww logs`: daemon/runtime errors.
- `eww state`: current variable values.
- `eww debug`: widget structure and debug information.
- `eww open --debug <window_name>`: additional output while opening.
- `eww inspector`: GTK debugger for CSS nodes/classes.

If a non-default config directory is used, include `--config /path/to/config/dir` consistently for all commands.

## Repo verification commands

Before assuming launch behavior, search repo files for Eww invocations. Useful patterns: `eww open`, `eww open-many`, `eww daemon`, `--config`, and `config/bar`. Use repository search tools and do not edit generated config.

Current research found only module wiring and no launch command.

After editing skill/config files in this repo, follow `AGENTS.md`:

```bash
nix fmt
git add <intended files>
prek
```

Run `nix flake check` only when Nix code changed. Do not commit without explicit permission.

## Source map

### Official Eww docs

- Overview/install/run: https://elkowar.github.io/eww/eww.html
- Configuration/Yuck: https://elkowar.github.io/eww/configuration.html
- First window: https://elkowar.github.io/eww/configuration.html#creating-your-first-window
- Window properties: https://elkowar.github.io/eww/configuration.html#defwindow-properties
- First widget: https://elkowar.github.io/eww/configuration.html#your-first-widget
- Children: https://elkowar.github.io/eww/configuration.html#rendering-children-in-your-widgets
- Variables: https://elkowar.github.io/eww/configuration.html#adding-dynamic-content
- `literal`: https://elkowar.github.io/eww/configuration.html#dynamically-generated-widgets-with-literal
- Window IDs/args: https://elkowar.github.io/eww/configuration.html#using-window-arguments-and-ids
- `for`: https://elkowar.github.io/eww/configuration.html#generating-a-list-of-widgets-from-json-using-for
- `include`: https://elkowar.github.io/eww/configuration.html#using-include
- Expressions: https://elkowar.github.io/eww/expression_language.html
- GTK theming: https://elkowar.github.io/eww/working_with_gtk.html
- Magic variables: https://elkowar.github.io/eww/magic-vars.html
- Widgets: https://elkowar.github.io/eww/widgets.html
- Troubleshooting: https://elkowar.github.io/eww/troubleshooting.html

### External docs linked by Eww

- GTK CSS overview: https://docs.gtk.org/gtk3/css-overview.html
- GTK CSS properties: https://docs.gtk.org/gtk3/css-properties.html
- GTK debugger docs are summarized in Eww's theming page.

### Current repo evidence

- `users/_modules/desktop/widgets/eww/default.nix`
- `users/_modules/desktop/widgets/eww/config/bar/eww.yuck`
- `users/_modules/desktop/widgets/eww/config/bar/eww.scss`
- `users/_modules/desktop/widgets/eww/config/bar/scripts/niri-workspaces.sh`

## Unknowns to re-check later

- The actual command or service that opens `bar`.
- Whether `.bar` is an implicit GTK class in live Eww output or dead SCSS.
- Whether a third/fourth metric fits comfortably in the current 30%-height right-side dock.
