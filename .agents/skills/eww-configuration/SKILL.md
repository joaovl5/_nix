---
name: eww-configuration
description: Use when editing or debugging this repo's Eww, Yuck, or GTK SCSS under `users/_modules/desktop/widgets/eww/`, including bar widgets, magic vars, selector mismatches, or Eww runtime commands
---

Use this skill for repo-managed Eww config under `users/_modules/desktop/widgets/eww/`

## Repo scope

- **Entry point:** start at `users/_modules/desktop/widgets/eww/default.nix`
- **Config root:** the module links `./config` to `~/.config/eww`, so edit repo files, not generated config
- **Active bar files:** current bar files live under `config/bar/`
- **Examples:** `eww.yuck`, `eww.scss`, and `scripts/niri-workspaces.sh` live there
- **Launch unknown:** no repo-local launch command was found
- **Verification:** prove the real `eww --config ...` and `eww open ...` flow before assuming how `bar` opens

## Working rules

- **Read order:** inspect `default.nix`, `config/bar/eww.yuck`, and `config/bar/eww.scss` first
- **Structure first:** change Yuck structure before SCSS selectors
- **Widget shape:** keep each custom widget body to one root widget
- **Data sources:** prefer magic vars for system metrics and `deflisten` for event streams
- **Polling and lists:** use `defpoll` for cheap polling, `for` for JSON lists, and `literal` only for full Yuck trees
- **GTK styling:** treat SCSS as GTK CSS, not browser CSS, and verify live nodes with `eww inspector`
- **Runtime truth:** use Eww runtime commands when styling or state disagrees with files

## References

Load these only when needed:

- **Yuck reference:** `references/yuck-reference.md` covers syntax, windows, widgets, variables, expressions, and list rendering
- **SCSS reference:** `references/scss-gtk-reference.md` covers GTK CSS behavior, current repo selectors, inspector workflow, and styling traps
- **Commands reference:** `references/eww-commands-and-sources.md` covers Eww commands, config-dir caveats, repo evidence, and source links

## Common mistakes

- **Config path:** do not assume `~/.config/eww/eww.yuck` exists
- **Current layout:** this repo keeps the live bar under `~/.config/eww/bar/`
- **Daemon assumptions:** do not assume `programs.eww.enable` starts a daemon or opens windows
- **Edit boundary:** do not edit `~/.config/eww` instead of repo files
- **Reset fallout:** do not add a Yuck class without matching SCSS after the global reset
- **CSS model:** do not treat GTK CSS like web CSS
- **Selector proof:** do not assume `.bar` is live without inspector proof
- **Unstyled classes:** `.label` is emitted by Yuck but has no matching SCSS yet
- **List rendering:** do not use `literal` for lists that `for` can render cleanly
