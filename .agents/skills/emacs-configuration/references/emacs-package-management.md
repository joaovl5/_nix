# Emacs Package Management Reference

## straight.el bootstrap

Defined in `config/core/core-packages.el`:

1. Downloads straight.el bootstrap from GitHub if not present.
2. Loads `straight/repos/straight.el/bootstrap.el`.
3. Sets `straight-use-package-by-default t` so `use-package` automatically installs via straight.

## Aliases

```elisp
(sup 'package-name)   ; alias for straight-use-package
(use package-name ...) ; alias for use-package
```

## use-package integration

`straight-use-package-by-default t` means every `use-package` declaration fetches the package via straight.el unless overridden.

Due to `use-package-always-defer t` (set in `early-init.el`), packages stay deferred until something triggers them.

Common load triggers here:

- `:hook` - loads when a hook fires
- `:bind` - loads when a bound key is used
- `:commands` - loads when an interactive command is invoked
- `:mode` - loads when visiting matching files
- `:demand t` - opts out of deferral and loads eagerly

Sequencing keywords:

- `:init` - runs at init time before package load
- `:config` - runs after the package loads
- `:after` - constrains ordering relative to other packages; it does not load a deferred package by itself

## Nix-managed packages

Packages that need native compilation or system libraries come from Nix. Currently:

- `org-roam` - in `default.nix` `extraPackages`
- `parinfer-rust-mode` - in `default.nix` `extraPackages`

In the `.el` file, reference them with:

```elisp
(use org-roam
     :straight nil    ; don't fetch via straight.el
     :ensure nil      ; don't install via package.el
     ...)
```

### When to use Nix vs straight.el

Use Nix when:

- package needs native compilation (C/Rust)
- package needs system libraries
- package has complex build requirements
- examples here: `parinfer-rust-mode`, `org-roam` (emacsql)

Use straight.el for pure Elisp and standard MELPA packages.

## Adding a MELPA package

```elisp
(use package-name
     :hook (some-mode . some-function)
     :bind (("C-c x" . some-command))
     :commands (some-command)
     :config
     (some-mode 1))
```

straight.el handles installation automatically because `straight-use-package-by-default t` is enabled in `core-packages.el`.

## Adding a non-MELPA package (GitHub recipe)

```elisp
(straight-use-package
  '(package-name :type git :host github :repo "user/repo.el"))
```

Example from the config (`core-keys.el`):

```elisp
(straight-use-package
  '(golden-ratio :type git :host github :repo "roman/golden-ratio.el"))
```

## Adding to Nix

1. Add to `programs.emacs.extraPackages` in `default.nix`:

```nix
extraPackages = epkgs:
  with epkgs; [
    org-roam
    parinfer-rust-mode
    new-package-here
  ];
```

2. Reference it in Lisp with `:straight nil :ensure nil` so straight.el and package.el both stay out of the way.

## Removing a package

1. Remove the `use-package` or `sup` call from the `.el` file.
2. If Nix-managed, remove from `default.nix` `extraPackages`.
3. Run `M-x straight-remove-unused-packages` interactively to clean up.
