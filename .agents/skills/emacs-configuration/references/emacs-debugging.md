# Emacs Debugging Reference

## _Messages_ buffer

`M-m` (bound in `core-keys.el`) opens the echo area. The `*Messages*` buffer logs all Emacs messages.

- `C-h e` or `M-x view-echo-area-messages` to open `*Messages*` directly.
- Search for error text or package names to find load failures.

## Debug on error

```elisp
(toggle-debug-on-error)   ; enable stack traces on errors
(toggle-debug-on-error)   ; disable again
```

Or start Emacs with:

```bash
emacs --debug-init
```

This shows a backtrace for any error during init.

## Feature loading

Check if a feature is loaded:

```elisp
(featurep 'core-ui)         ; => t or nil
```

Check the load path:

```elisp
load-path                   ; list of directories
```

Check if a package was loaded by straight:

```elisp
(straight--loaded-p 'package-name)   ; => t or nil
```

Check if a package is installed (registered with straight):

```elisp
(straight--installed-p 'package-name)
```

## straight.el troubleshooting

```elisp
M-x straight-check-all           ; verify all packages are correctly installed
M-x straight-rebuild-all         ; rebuild all packages from scratch
M-x straight-remove-unused-packages  ; clean up orphaned packages
M-x straight-freeze-versions     ; write lockfile
```

Rebuild a single package:

```elisp
M-x straight-rebuild-package RET package-name RET
```

## Daemon-specific issues

Emacs runs as a daemon. Frame-dependent code may fail at init time because no frame exists yet.

**Symptoms:**

- Theme or font not applying
- which-key crashes (known issue: github.com/justbur/emacs-which-key/issues/306)
- Package works in standalone Emacs but not in daemon mode

**Fix pattern** (used in `core-ui.el`):

```elisp
(if (daemonp)
    (add-hook 'server-after-make-frame-hook #'my-setup-function)
  (my-setup-function))
```

**Debugging daemon frames:**

```elisp
(daemonp)                        ; => t if running as daemon
(frame-list)                     ; list of open frames
(selected-frame)                 ; current frame
```

## Using helpful

`helpful` is installed and provides richer help buffers. Keybindings from `core-ui.el`:

| Key       | Command                               |
| --------- | ------------------------------------- |
| `C-c h f` | `helpful-callable` (functions/macros) |
| `C-c h v` | `helpful-variable`                    |
| `C-c h k` | `helpful-key`                         |
| `C-c h x` | `helpful-command`                     |
| `C-c h h` | `helpful-at-point`                    |

These show source code, docstrings, dependencies, and calling context.

## Common failure patterns

| Symptom                                              | Likely cause                                 | Fix                                                                         |
| ---------------------------------------------------- | -------------------------------------------- | --------------------------------------------------------------------------- |
| Package not found at startup                         | straight.el hasn't fetched it                | `M-x straight-pull-package` or restart Emacs                                |
| Config loads but feature missing                     | `use-package-always-defer` prevented loading | Add `:hook`, `:bind`, or `:commands` to trigger loading                     |
| Theme/faces look wrong after daemon connect          | Frame not available at load time             | Use `server-after-make-frame-hook`                                          |
| Native-comp warnings in `*Messages*`                 | Missing `.eln` cache                         | Restart daemon, or `M-x native-compile-async`                               |
| `exec-path-from-shell` issues                        | Shell env not propagated                     | Check `exec-path-from-shell-arguments` and shell rc files                   |
| Package works interactively but not in `use-package` | Deferred loading                             | Check if `:init` is used when `:config` is needed, or add a loading trigger |
