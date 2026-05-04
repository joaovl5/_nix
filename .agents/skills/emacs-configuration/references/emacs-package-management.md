# Emacs Package Management Reference

## straight.el bootstrap

- **Bootstrap file:** `config/core/core-packages.el` downloads the bootstrap file if missing, then loads `straight/repos/straight.el/bootstrap.el`
- **Default install path:** the same file enables `straight-use-package-by-default t`

## Aliases

```elisp
(sup 'package-name)   ; alias for straight-use-package
(use package-name ...) ; alias for use-package
```

## use-package semantics

- **Default deferral:** `use-package-always-defer t` in `config/early-init.el` keeps packages deferred until a real trigger fires
- **Load triggers:** `:hook`, `:bind`, `:commands`, and `:mode` trigger loading; `:demand t` opts out of deferral
- **`:init`:** runs at init time before package load, not as a load trigger
- **`:config`:** runs after package load
- **`:after`:** only constrains ordering, not loading
- **Install default:** with `straight-use-package-by-default t`, each `use-package` form installs through straight unless overridden

## Nix-managed packages

- **When to use Nix:** prefer it for packages that need native compilation, system libraries, or heavier build support
- **Current examples:** `org-roam` and `parinfer-rust-mode` come from `default.nix` `extraPackages`
- **Elisp form:** still declare them with `:straight nil :ensure nil`

```elisp
(use org-roam
     :straight nil
     :ensure nil
     ...)
```

## Adding a MELPA package

- **Typical form:** add a `use` form with the trigger that should load the package
- **Install behavior:** straight handles installation automatically through the default install path

```elisp
(use package-name
     :hook (some-mode . some-function)
     :bind (("C-c x" . some-command))
     :commands (some-command)
     :config
     (some-mode 1))
```

## Adding a non-MELPA package

- **Recipe path:** use `straight-use-package` with an explicit recipe
- **Existing example:** `config/core/core-keys.el` installs `golden-ratio` this way

```elisp
(straight-use-package
  '(package-name :type git :host github :repo "user/repo.el"))
```

```elisp
(straight-use-package
  '(golden-ratio :type git :host github :repo "roman/golden-ratio.el"))
```

## Adding a Nix package

- **Nix declaration:** add the package to `programs.emacs.extraPackages` in `default.nix`
- **Elisp declaration:** pair it with `:straight nil :ensure nil` so straight and package.el stay out

```nix
extraPackages = epkgs:
  with epkgs; [
    org-roam
    parinfer-rust-mode
    new-package-here
  ];
```

## Removing a package

- **Elisp cleanup:** remove the `use-package` or `sup` form from the `.el` file
- **Nix cleanup:** if the package is Nix-managed, remove it from `default.nix` `extraPackages`
- **Straight cleanup:** run `M-x straight-remove-unused-repos` interactively when orphaned repos need pruning
