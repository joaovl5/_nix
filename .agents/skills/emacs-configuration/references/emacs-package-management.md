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

Due to `use-package-always-defer t` (set in `early-init.el`), all packages load lazily. To trigger loading, use one of:

- `:hook` - loads when a hook fires
- `:bind` - loads when a key is pressed
- `:commands` - loads when an interactive command is invoked
- `:init` - runs code at init time (but does NOT load the package)
- `:config` - runs after the package loads
- `:after` - loads after another package

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

| Use Nix when                               | Use straight.el when    |
| ------------------------------------------ | ----------------------- |
| Package needs native compilation (C/Rust)  | Pure Elisp packages     |
| Package needs system libraries             | Standard MELPA packages |
| Package has complex build requirements     | Simple packages         |
| `parinfer-rust-mode`, `org-roam` (emacsql) | Everything else         |

## Adding a MELPA package

```elisp
(use package-name
     :ensure t
     :hook (some-mode . some-function)
     :bind (("C-c x" . some-command))
     :config
     (some-mode 1))
```

straight.el handles installation automatically.

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

2. Reference in the `.el` file with `:straight nil :ensure nil`.

## Removing a package

1. Remove the `use-package` or `sup` call from the `.el` file.
2. If Nix-managed, remove from `default.nix` `extraPackages`.
3. Run `M-x straight-remove-unused-packages` interactively to clean up.
