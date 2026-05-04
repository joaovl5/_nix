# Emacs Debugging Reference

## Messages buffer

- **Open log:** use `C-h e` or `M-x view-echo-area-messages`
- **Search failures:** search for error text or package names to find load failures
- **Repo note:** `M-m` in `config/core/core-keys.el` opens the echo area

## Debug on error

```elisp
(toggle-debug-on-error)   ; enable stack traces on errors
(toggle-debug-on-error)   ; disable again
```

- **Init crashes:** start Emacs with `emacs --debug-init` to get an init-time backtrace

## Feature loading

- **Feature state:** check whether a feature is loaded

```elisp
(featurep 'core-ui)         ; => t or nil
```

- **Load path:** inspect the active load path

```elisp
load-path                   ; list of directories
```

- **Feature state:** use `featurep` for provided features; package names and feature names can differ

```elisp
(featurep 'core-ui)
```

- **Straight state:** use straight's maintenance commands instead of private predicates

## straight.el troubleshooting

- **Main commands:** use straight's maintenance commands

```elisp
M-x straight-check-all
M-x straight-rebuild-all
M-x straight-remove-unused-repos
```

- **Single package:** rebuild one package when the failure is isolated

```elisp
M-x straight-rebuild-package RET package-name RET
```

## Daemon-specific issues

- **Core fact:** daemon Emacs can run frame-dependent code during init before any frame exists
- **Symptoms:** theme or font not applying, `which-key` crashing, or code working in standalone Emacs but not in daemon mode
- **Known issue:** the `which-key` crash workaround exists because of <https://github.com/justbur/emacs-which-key/issues/306>
- **Fix pattern:** use `server-after-make-frame-hook` for frame-dependent setup

```elisp
(if (daemonp)
    (add-hook 'server-after-make-frame-hook #'my-setup-function)
  (my-setup-function))
```

- **Inspect state:** check daemon and frame state directly

```elisp
(daemonp)                        ; => t if running as daemon
(frame-list)                     ; list of open frames
(selected-frame)                 ; current frame
```

## Using helpful

- **Purpose:** `helpful` gives richer help buffers, with keybindings from `config/core/core-ui.el`
- **Function help:** `C-c h f` runs `helpful-callable`
- **Variable help:** `C-c h v` runs `helpful-variable`
- **Key help:** `C-c h k` runs `helpful-key`
- **Command help:** `C-c h x` runs `helpful-command`
- **Point help:** `C-c h h` runs `helpful-at-point`
- **What it shows:** source code, docstrings, dependencies, and calling context

## Common failure patterns

- **Package missing at startup:** straight has not fetched it yet, so run `M-x straight-pull-package` or restart Emacs
- **Feature missing after config load:** `use-package-always-defer` kept it deferred, so add a real trigger like `:hook`, `:bind`, `:commands`, `:mode`, or `:demand t`
- **Theme or faces wrong after daemon connect:** the frame was unavailable at load time, so move setup to `server-after-make-frame-hook`
- **Native-comp warnings in `*Messages*`:** the `.eln` cache is missing, so restart the daemon or run `M-x native-compile-async`
- **`exec-path-from-shell` issues:** the shell environment did not propagate, so inspect `exec-path-from-shell-arguments` and shell rc files
- **`use-package` setup split wrong:** put pre-load code in `:init`, post-load code in `:config`, and use a real load trigger
