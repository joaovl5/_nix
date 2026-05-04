---
name: emacs-configuration
description: Use when editing this repo's Emacs config under users/_modules/desktop/apps/editor/emacs
---

# Emacs Configuration

Use this when editing `users/_modules/desktop/apps/editor/emacs/`

For Nix-layer changes like packages or services, also check the repo's AGENTS.md for required checks

Below, paths are relative to `users/_modules/desktop/apps/editor/emacs/`

## First checks

- **Lexical binding:** prefer adding `lexical-binding` unless it would change existing behavior

## Layout

- **Entry point:** `default.nix` manages packages, daemon config, and the dynamic config symlink
- **Startup files:** `config/early-init.el` handles early performance and visual setup, `config/init.el` is the main entrypoint
- **Core files:** `config/core/` holds shared building blocks like packages, UI, keys, views, and coding helpers
- **Modules:** `config/modules/` holds focused modules like `mod-org.el` and `mod-lisp.el`

## Package workflow

- **Default forms:** use `(use package-name ...)` or `(sup 'package-name)` for most packages
- **Custom recipes:** use `straight-use-package` when the package needs an explicit recipe
- **Nix-managed packages:** add them to `programs.emacs.extraPackages` in `default.nix`, then pair the Elisp form with `:straight nil :ensure nil`
- **Load truth:** deferred packages need a real trigger like `:hook`, `:bind`, `:commands`, `:mode`, or `:demand t`; `:after` only orders
- **Reference:** see `references/emacs-package-management.md` for load semantics and add or remove flows

## Common edits

- **Keybindings:** edit `config/core/core-keys.el` for global keys or use `:bind` in the relevant module
- **Theme or fonts:** edit `config/core/core-ui.el`, especially `handle-theme` and `handle-fonts`
- **Modal editing:** edit `config/core/core-keys.el`, especially `meow-setup`
- **New module:** add `config/modules/mod-*.el` and require it from `config/init.el`
- **Org behavior:** edit `config/modules/mod-org.el`
- **Completion behavior:** edit `config/core/core-views.el`, especially `handle-minibuf` and `handle-completions`
- **Formatter config:** edit `config/core/core-coding.el`, especially Apheleia `apheleia-formatters`
- **Startup performance:** edit `config/early-init.el`

## Repo quirks

- **Daemon mode:** this config runs Emacs as a daemon via `services.emacs` in `default.nix`
- **Frame setup:** use `server-after-make-frame-hook` for frame-dependent work; `core-ui.el` already carries a `which-key` workaround for daemon-created frames
- **Deferred loading:** `use-package-always-defer t` is set in `config/early-init.el`, so `:init`, `:config`, and `:after` do not load a package by themselves
- **Modal stack:** this config uses Meow in `core-keys.el`, not Evil
- **Aliases:** `use` means `use-package`, `sup` means `straight-use-package`

## Common mistakes

- **Double install:** forgetting `:straight nil :ensure nil` on Nix-managed packages makes straight and package.el compete
- **Missing wire-up:** new modules still need `(provide 'feature-name)` and a matching require in `config/init.el`
- **Custom blocks:** avoid duplicate `custom-set-variables` or `custom-set-faces` blocks

## References

- **Package management:** `references/emacs-package-management.md`
- **Debugging:** `references/emacs-debugging.md`
