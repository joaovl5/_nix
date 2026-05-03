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

- `config/core/core-packages.el`: straight.el bootstrap, `use`/`sup` aliases
- `config/core/core-ui.el`: fonts, theme, modeline, helpful, and the daemon-mode `which-key` workaround
- `config/core/core-core.el`: utility functions, search engines, PATH, savehist
- `config/core/core-keys.el`: Meow, golden-ratio, keybindings, window management
- `config/core/core-views.el`: Dirvish, Projectile, Vertico, Corfu, Consult, Embark
- `config/core/core-coding.el`: Flycheck, devdocs, Apheleia
- `config/modules/mod-org.el`: Org-mode, org-roam, svg-tag-mode, org-download
- `config/modules/mod-lisp.el`: parinfer-rust-mode for Lisp editing
- `config/early-init.el`: GC tuning, frame settings, deferred loading
- `config/init.el`: entry point requiring core/_ and modules/_
- `default.nix`: Nix package list, daemon config, config symlink

## Package management workflow

1. **Most packages**: just use `(use package-name ...)` or `(sup 'package-name)`. straight.el fetches them automatically.
2. **Nix-managed packages**: add to `programs.emacs.extraPackages` in `default.nix`, then reference with `:straight nil :ensure nil` in the `.el` file.
3. **Non-MELPA packages**: pass a named recipe to `straight-use-package`, e.g. `'(package-name :type git :host github :repo "user/repo")`.

See `references/emacs-package-management.md` for full details.

## Nix integration

- Config directory is symlinked to `~/.config/emacs` via `hybrid-links.links.emacs` in `default.nix`.
- `exec-path-from-shell` bridges Nix's PATH into Emacs (in `core-core.el`).
- Packages requiring native compilation (e.g. `parinfer-rust-mode`, `org-roam`) come from Nix. All others come from straight.el.
- Changes to `.el` files: no `nix flake check` needed.
- Changes to `default.nix`: run `nix flake check` and rebuild.

## Common maintenance tasks

- Add a MELPA package: `use-package` in the appropriate `core-*.el` or `mod-*.el` file
- Add a Nix-managed package: `default.nix` `extraPackages` plus `:straight nil :ensure nil` in Lisp
- Change keybindings: `config/core/core-keys.el` (global) or `:bind` in the relevant module
- Change theme or fonts: `config/core/core-ui.el` (`handle-theme`, `handle-fonts`)
- Change modal editing behavior: `config/core/core-keys.el` (`meow-setup`)
- Add a new config module: create `config/modules/mod-*.el`, then require it from `init.el`
- Change Org behavior: `config/modules/mod-org.el`
- Change completion behavior: `config/core/core-views.el` (`handle-minibuf`, `handle-completions`)
- Change formatter config: `config/core/core-coding.el` (Apheleia `apheleia-formatters`)
- Adjust startup performance: `config/early-init.el`

## Repo quirks

- **Daemon mode**: Emacs runs as a daemon (`services.emacs` in `default.nix`). Frame-dependent setup uses `server-after-make-frame-hook`; `core-ui.el` has a `which-key` workaround for daemon-created frames.
- **Deferred loading**: `use-package-always-defer t` is set in `early-init.el`. Packages stay deferred unless something else triggers them, such as `:hook`, `:bind`, `:commands`, `:mode`, or an explicit eager load with `:demand t`. `:init` runs before load, `:config` runs after load, and `:after` only constrains ordering once loading happens.
- **Meow, not evil**: Modal editing uses Meow (`core-keys.el`). Don't add evil/vim keybindings.
- **Aliases**: `sup` = `straight-use-package`, `use` = `use-package` (defined in `core-packages.el`). `straight-use-package-by-default t` means plain `use-package` forms already install through straight.el.
- **Module pattern**: Several core UI/view/key files define `handle-*` functions and provide the feature at the end of the file, but do not assume every config file follows that exact shape.
- **Frame settings**: `early-init.el` sets `undecorated` and `internal-border-width` on `default-frame-alist`.
- **Custom variables**: `init.el` has `custom-set-variables` and `custom-set-faces` at the bottom. Don't duplicate these blocks.

## Quick checklist

### Before editing

- Identify the correct file from the list above.
- If adding a package, decide: straight.el (default) vs Nix (needs native compilation or system dependency).
- If editing daemon-related code, account for `server-after-make-frame-hook`.

### Before finishing

- `.el`-only changes: run `nix fmt` then `prek` (per repo AGENTS.md). No `nix flake check`.
- `default.nix` changes: run `nix fmt`, `prek`, then `nix flake check --all-systems`.
- Verify the module has `(provide 'feature-name)` at the bottom.
- Verify new modules are required in `init.el`.

## Common mistakes

- Adding a package via straight.el when it needs native compilation or system libraries (use Nix instead).
- Forgetting `:straight nil :ensure nil` on Nix-managed packages (causes double-install attempts).
- Expecting `:init`, `:config`, or `:after` to load a deferred package. Use a real trigger such as `:hook`, `:bind`, `:commands`, `:mode`, or `:demand t` when eager load is intentional.
- Assuming a frame is available at load time (daemon mode: use `server-after-make-frame-hook` for frame-dependent setup).
- Adding duplicate `custom-set-variables` or `custom-set-faces` blocks.
- Forgetting `(provide 'feature-name)` at the end of a new module file.

## Debugging

See `references/emacs-debugging.md` for troubleshooting techniques.
