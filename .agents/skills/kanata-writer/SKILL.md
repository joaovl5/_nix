---
name: kanata-writer
description: Use when editing or reviewing this repo's Kanata keyboard config under `modules/aspects/desktop/desktop/services/kanata/`, including layers, aliases, tap-hold behavior, mouse actions, live reload, and key-name syntax
---

Use this skill for repo-managed Kanata config under
`modules/aspects/desktop/desktop/services/kanata/`

## Repo scope

- **Entry point:** start at
  `modules/aspects/desktop/desktop/services/kanata/default.nix`
- **Config source:** edit
  `modules/aspects/desktop/desktop/services/kanata/config/config.kbd`
- **Linked runtime path:** `hybrid-links.links.kanata` links `./config` to
  `~/.config/kanata`
- **User service:** `kanata-internalKeyboard` runs Kanata with
  `--cfg %h/.config/kanata/config.kbd`
- **Linux plumbing:** uinput module, udev rule, and `uinput` group live in
  `default.nix`

## Rules

- **Read current shape:** inspect `default.nix` and `config/config.kbd` before
  changing behavior
- **Stay repo-local:** do not edit `~/.config/kanata`; edit the repo source
  and let hybrid-links project it
- **Load syntax reference:** use `references/kanata-cheatsheet.md` before
  touching unfamiliar actions
- **Verify semantics:** check the upstream Kanata config guide when action
  behavior or key names matter
- **Ask for feel:** timing changes such as tap-hold thresholds are subjective;
  get user feedback when intent is unclear

### Editing

- **Layer alignment:** every `deflayer` position must line up with `defsrc`;
  use whitespace to keep columns readable
- **Transparency:** use `_` when the lower layer should handle the key; use
  `XX` only for an intentional no-op
- **Aliases:** put reusable or complex actions in `defalias`, then call them
  with `@name`
- **Tap-hold care:** keep timeout changes small and explain behavior
  tradeoffs; avoid broad timing rewrites
- **Dangerous commands:** do not enable `danger-enable-cmd` or command actions
  unless explicitly requested
- **Repo service changes:** keep config changes separate from service/uinput
  changes unless both are required

## References

Load only when needed:

- **Kanata cheatsheet:** `references/kanata-cheatsheet.md` covers syntax,
  common actions, options, key names, and upstream source links

## Validation

- **Syntax confidence:** prefer an actual Kanata parser/run check over visual
  review when the binary is available
- **Service proof:** for runtime behavior, inspect the user service and Kanata
  logs instead of assuming reload success
- **Verification:**
  - For kanata-facing changes, run:

      ```sh
      kanata --check --cfg <path_to_config>.kbd
      ```

## Common mistakes

- **Generated path:** editing `~/.config/kanata/config.kbd` instead of repo
  source
- **Layer drift:** adding a source key without updating every layer row
- **Wrong arrow name:** this repo uses `rght`, not `right`, for right arrow
  output
- **Timing overfit:** changing tap-hold values without testing real typing
  behavior
- **Unsafe validation:** starting Kanata interactively without knowing how to
  stop or reload it
