---
name: emacs-configuration
description: Use when editing this repo's Emacs config under users/_modules/emacs; covers straight.el package management, daemon-mode quirks, module structure, and Nix integration boundaries.
---

# Emacs Configuration

Use this when editing `users/_modules/emacs/`.
For Nix-layer changes (packages, services), also check the repo's AGENTS.md for required checks.

Below, paths are relative to `users/_modules/emacs/`.

## First rule

- Never add `lexical-binding` declarations without checking consistency across files.
- Never run `nix flake check` on changes that strictly touch `.el` files (per `config/AGENTS.md`).

## Where changes go

| What                                                  | Where                          |
| ----------------------------------------------------- | ------------------------------ |
| Package bootstrap / straight.el setup                 | `config/core/core-packages.el` |
| Fonts, theme, modeline, which-key, helpful            | `config/core/core-ui.el`       |
| Utility functions, search engines, PATH, savehist     | `config/core/core-core.el`     |
| Meow, golden-ratio, keybindings, window management    | `config/core/core-keys.el`     |
| Dirvish, Projectile, Vertico, Corfu, Consult, Embark  | `config/core/core-views.el`    |
| Flycheck, devdocs, Apheleia (formatters)              | `config/core/core-coding.el`   |
| Org-mode, org-roam, svg-tag-mode, org-download        | `config/modules/mod-org.el`    |
| parinfer-rust-mode for Lisp editing                   | `config/modules/mod-lisp.el`   |
| Pre-init: GC tuning, frame settings, deferred loading | `config/early-init.el`         |
| Entry point: requires core/_ and modules/_            | `config/init.el`               |
| Nix package list, daemon config, symlink              | `default.nix`                  |

## Package management workflow

1. **Most packages**: just use `(use package-name ...)` or `(sup 'package-name)`. straight.el fetches them automatically.
2. **Nix-managed packages**: add to `programs.emacs.extraPackages` in `default.nix`, then reference with `:straight nil :ensure nil` in the `.el` file.
3. **Non-MELPA packages**: pass a recipe to `straight-use-package`, e.g. `'(:type git :host github :repo "user/repo")`.

See `references/emacs-package-management.md` for full details.

## Nix integration

- Config directory is symlinked to `~/.config/emacs` via `hybrid-links.links.emacs` in `default.nix`.
- `exec-path-from-shell` bridges Nix's PATH into Emacs (in `core-core.el`).
- Packages requiring native compilation (e.g. `parinfer-rust-mode`, `org-roam`) come from Nix. All others come from straight.el.
- Changes to `.el` files: no `nix flake check` needed.
- Changes to `default.nix`: run `nix flake check` and rebuild.

## Common maintenance tasks

| Task                          | Where to edit                                                         |
| ----------------------------- | --------------------------------------------------------------------- |
| Add a MELPA package           | `use-package` in the appropriate `core-*.el` or `mod-*.el`            |
| Add a Nix-managed package     | `default.nix` `extraPackages` + `:straight nil` in `.el`              |
| Change keybinding             | `config/core/core-keys.el` (global) or `:bind` in the relevant module |
| Change theme or font          | `config/core/core-ui.el` (`handle-theme`, `handle-fonts`)             |
| Change modal editing behavior | `config/core/core-keys.el` (`meow-setup`)                             |
| Add a new config module       | Create `config/modules/mod-*.el`, add `(require 'mod-*)` to `init.el` |
| Change Org behavior           | `config/modules/mod-org.el`                                           |
| Change completion framework   | `config/core/core-views.el` (`handle-minibuf`, `handle-completions`)  |
| Change formatter config       | `config/core/core-coding.el` (Apheleia `apheleia-formatters`)         |
| Adjust startup performance    | `config/early-init.el` (GC threshold, deferred loading)               |

## Repo quirks

- **Daemon mode**: Emacs runs as a daemon (`services.emacs` in `default.nix`). Frame-dependent setup uses `server-after-make-frame-hook` (see `core-ui.el` which-key workaround).
- **Deferred loading**: `use-package-always-defer t` is set in `early-init.el`. Packages load lazily unless you explicitly use `:init`, `:commands`, `:bind`, or `:hook`.
- **Meow, not evil**: Modal editing uses Meow (`core-keys.el`). Don't add evil/vim keybindings.
- **Aliases**: `sup` = `straight-use-package`, `use` = `use-package` (defined in `core-packages.el`).
- **Module pattern**: Each file defines `handle-*` functions called at the end of the file, then `(provide 'feature-name)`.
- **Frame settings**: `early-init.el` sets `undecorated` and `internal-border-width` on `default-frame-alist`.
- **Custom variables**: `init.el` has `custom-set-variables` and `custom-set-faces` at the bottom. Don't duplicate these blocks.

## Quick checklist

### Before editing

- Identify the correct file from the table above.
- If adding a package, decide: straight.el (default) vs Nix (needs native compilation or system dependency).
- If editing daemon-related code, account for `server-after-make-frame-hook`.

### Before finishing

- `.el`-only changes: run `nix fmt` then `prek` (per repo AGENTS.md). No `nix flake check`.
- `default.nix` changes: run `nix fmt`, `prek`, then `nix flake check --all-systems`.
- Verify the module has `(provide 'feature-name)` at the bottom.
- Verify new modules are required in `init.el`.

## Common mistakes

- Adding a package via straight.el when it needs native compilation (use Nix instead).
- Forgetting `:straight nil :ensure nil` on Nix-managed packages (causes double-install attempts).
- Using `:init` when deferred loading means it won't run at the right time (use `:hook`, `:bind`, or `:commands` to trigger loading).
- Assuming frame is available at load time (daemon mode: use `server-after-make-frame-hook` for frame-dependent setup).
- Adding duplicate `custom-set-variables` or `custom-set-faces` blocks.
- Forgetting `(provide 'feature-name)` at the end of a new module file.

## Debugging

See `references/emacs-debugging.md` for troubleshooting techniques.
