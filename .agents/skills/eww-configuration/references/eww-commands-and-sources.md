# Eww Commands and Source Map

## Command model

Official basics:

```bash
eww daemon
eww open <window_name>
```

- **Config flag:** official docs say every Eww command should include `--config /path/to/config/dir` when using a non-default config dir
- **Repo caveat:** this repo links `users/_modules/desktop/widgets/eww/config` to `~/.config/eww`
- **Live file:** the live Yuck file still sits under `bar/`
- **Launch unknown:** no repo-local launcher or service command was found
- **Verification:** prove the real `bar` launch command with `eww --help`, the running service, or current launcher before documenting commands

## Troubleshooting commands

```bash
eww reload
eww logs
eww state
eww debug
eww kill
eww open --debug <window_name>
eww inspector
```

- **`eww reload`:** use when hot reload missed a config or style change
- **`eww logs`:** use for daemon and runtime errors
- **`eww state`:** use to inspect current variable values
- **`eww debug`:** use for widget structure and debug data
- **`eww open --debug`:** use for extra output while opening a window
- **`eww inspector`:** use for GTK node and class inspection
- **Config consistency:** if a non-default config dir is in play, keep `--config /path/to/config/dir` on every command

## Repo verification

- **Search first:** before assuming launch behavior, search repo files for `eww open`, `eww open-many`, and `eww daemon`
- **Config evidence:** also search for `--config` and `config/bar`
- **Current evidence:** repo search found module wiring and config files, but no launch command
- **Edit boundary:** change repo sources, not generated Eww config

## Source map

### Official Eww docs

- **Overview and run model:** https://elkowar.github.io/eww/eww.html
- **Configuration and Yuck:** https://elkowar.github.io/eww/configuration.html
- **First window:** https://elkowar.github.io/eww/configuration.html#creating-your-first-window
- **Window properties:** https://elkowar.github.io/eww/configuration.html#defwindow-properties
- **First widget:** https://elkowar.github.io/eww/configuration.html#your-first-widget
- **Children:** https://elkowar.github.io/eww/configuration.html#rendering-children-in-your-widgets
- **Variables:** https://elkowar.github.io/eww/configuration.html#adding-dynamic-content
- **`literal`:** https://elkowar.github.io/eww/configuration.html#dynamically-generated-widgets-with-literal
- **Window IDs and args:** https://elkowar.github.io/eww/configuration.html#using-window-arguments-and-ids
- **`for`:** https://elkowar.github.io/eww/configuration.html#generating-a-list-of-widgets-from-json-using-for
- **`include`:** https://elkowar.github.io/eww/configuration.html#using-include
- **Expressions:** https://elkowar.github.io/eww/expression_language.html
- **GTK theming:** https://elkowar.github.io/eww/working_with_gtk.html
- **Magic vars:** https://elkowar.github.io/eww/magic-vars.html
- **Widgets:** https://elkowar.github.io/eww/widgets.html
- **Troubleshooting:** https://elkowar.github.io/eww/troubleshooting.html

### External docs linked by Eww

- **GTK CSS overview:** https://docs.gtk.org/gtk3/css-overview.html
- **GTK CSS properties:** https://docs.gtk.org/gtk3/css-properties.html

### Current repo evidence

- **Module entry:** `users/_modules/desktop/widgets/eww/default.nix`
- **Bar Yuck:** `users/_modules/desktop/widgets/eww/config/bar/eww.yuck`
- **Bar SCSS:** `users/_modules/desktop/widgets/eww/config/bar/eww.scss`
- **Workspace script:** `users/_modules/desktop/widgets/eww/config/bar/scripts/niri-workspaces.sh`

## Unknowns to re-check later

- **Launch command:** the actual command or service that opens `bar`
- **`.bar` selector:** whether `.bar` is a live GTK class or dead SCSS
- **Bar growth:** whether a third or fourth metric still fits the current right-side dock cleanly
