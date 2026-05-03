---
name: eww-configuration
description: Use when editing or debugging this repository's Eww/Yuck/SCSS configuration under users/_modules/desktop/widgets/eww, including bar widgets, magic variables, GTK styling, or eww commands.
---

Use this skill for repo-managed Eww config in `users/_modules/desktop/widgets/eww/`.

## Repo facts

- Nix entrypoint: `users/_modules/desktop/widgets/eww/default.nix`.
- Config is linked with `hybrid-links.links.eww.from = ./config` to `~/.config/eww`; do not edit generated `~/.config/eww` directly.
- `programs.eww.enable = true`; Home Manager adds the package. This repo also currently adds `pkgs.eww` explicitly.
- Current config files are under `config/bar/`: `eww.yuck`, `eww.scss`, and `scripts/niri-workspaces.sh`. No root `config/eww.yuck` exists, so verify the actual `eww --config ...` launch path before assuming default config-root behavior.
- Current bar tree: `bar` window -> `bar` widget -> vertical `centerbox` -> `workspaces`, `centerstuff`, `sidestuff`.
- Current data: `defpoll time/date`, `deflisten niri_workspaces`, `EWW_CPU.avg`, `EWW_RAM.used_mem_perc`, and `EWW_DISK["/"]`.

## Minimal workflow

1. Inspect `default.nix`, `config/bar/eww.yuck`, and `config/bar/eww.scss` first.
2. Change Yuck structure before SCSS selectors. Every custom widget body has one root widget.
3. Prefer built-in magic vars for system metrics. Use `deflisten` for streaming state, `defpoll` for polling fallback, `for` for JSON arrays, and `literal` only when you must render a full Yuck tree string.
4. For styling, remember GTK CSS is not browser CSS. Use `eww inspector` to inspect CSS nodes/classes.
5. After edits, follow repo checks from `AGENTS.md`: `nix fmt`, stage intended files, `prek`; run `nix flake check --all-systems` only if Nix code changed.

## SCSS + Yuck quick reference

- Add a metric with another `(metric ...)` call in `sidestuff`; verify the magic-variable shape first.
- Add a CPU metric with `:value {round(EWW_CPU.avg, 0)}`; shared `.metric` SCSS should apply by default.
- Add a style by confirming/adding `:class` in Yuck, then matching it in `eww.scss`; account for `* { all: unset; }`.
- Style `scale` through GTK nodes such as `.metric scale trough highlight`; verify with `eww inspector`.
- Add dynamic workspace/state UI through `deflisten` + JSON + `for`; keep `literal` as a last resort.
- Use `{expr}` for expression-valued attributes/content and `${expr}` inside strings.
- Debug runtime with `eww reload`, `eww logs`, `eww state`, `eww debug`, `eww open --debug`, and `eww inspector`.

Current selector checks: `.bar` is styled but not explicitly set as `:class "bar"`; `centerstuff` and `.label` are emitted but currently unstyled. Treat these as verification points, not proven bugs. If a style does not apply: confirm the Yuck `:class`, confirm a matching SCSS selector after `* { all: unset; }`, then verify the live GTK node/class/state in `eww inspector`.

## Documentation sources

- Eww overview: https://elkowar.github.io/eww/eww.html
- Configuration/Yuck: https://elkowar.github.io/eww/configuration.html
- Expressions: https://elkowar.github.io/eww/expression_language.html
- GTK/SCSS theming: https://elkowar.github.io/eww/working_with_gtk.html
- Magic variables: https://elkowar.github.io/eww/magic-vars.html
- Widgets/events: https://elkowar.github.io/eww/widgets.html
- Troubleshooting: https://elkowar.github.io/eww/troubleshooting.html

## References

Load these only when needed:

- `references/yuck-reference.md` — Yuck syntax, windows/widgets, variables, expressions, magic vars, and dynamic lists.
- `references/scss-gtk-reference.md` — GTK CSS/SCSS behavior, current selectors, inspector workflow, and styling pitfalls.
- `references/eww-commands-and-sources.md` — Eww commands, troubleshooting flow, config-dir caveats, and source URL map.

## Common mistakes

- Assuming `~/.config/eww/eww.yuck` exists; this repo currently has `~/.config/eww/bar/eww.yuck` after linking.
- Assuming `programs.eww.enable` starts a daemon or opens windows. It installs/configures Eww; launch behavior must be verified separately.
- Editing `~/.config/eww` instead of repo files.
- Adding a class in Yuck but no matching SCSS after the global reset.
- Treating GTK CSS like web CSS (`flexbox`, floats, absolute layout, CSS width/height assumptions).
- Using `literal` for lists when `for` over JSON can render the list.
- Assuming `.bar` or other SCSS selectors match live GTK nodes without checking `eww inspector`.
