# Emacs Lisp Idiomatic Patterns

## Defining a minor mode

```elisp
(define-minor-mode my-highlight-mode
  "Highlight important things."
  :lighter " HL"
  :keymap (let ((map (make-sparse-keymap)))
            (define-key map (kbd "C-c h") #'my-highlight-toggle)
            map)
  (if my-highlight-mode
      (my-highlight--enable)
    (my-highlight--disable)))

(defun my-highlight--enable ()
  (add-hook 'post-command-hook #'my-highlight--on-change nil t)
  (my-highlight--on-change))

(defun my-highlight--disable ()
  (remove-hook 'post-command-hook #'my-highlight--on-change t)
  (remove-overlays (point-min) (point-max) 'my-highlight t))
```

- `define-minor-mode` automatically creates the toggle variable (`my-highlight-mode`).
- Use `nil t` in `add-hook` to make it buffer-local.
- Clean up hooks and overlays on disable.

## Creating a custom keymap

```elisp
(defvar my-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c a") #'my-action-a)
    (define-key map (kbd "C-c b") #'my-action-b)
    (define-key map (kbd "C-c c") #'my-action-c)
    map)
  "Keymap for `my-mode'.")
```

For prefix keymaps:

```elisp
(defvar my-prefix-map
  (let ((map (make-sparse-keymap)))
    (define-key map "a" #'my-action-a)
    (define-key map "b" #'my-action-b)
    map))

(global-set-key (kbd "C-c m") my-prefix-map)
```

## Working with overlays

```elisp
(let ((ov (make-overlay start end)))
  (overlay-put ov 'face 'highlight)
  (overlay-put ov 'priority 100)
  (overlay-put ov 'my-data t)
  (overlay-put ov 'evaporate t))
```

- `evaporate` property makes the overlay self-delete when its text is deleted.
- Query with `overlays-at`, `overlays-in`.
- Remove with `delete-overlay`.
- Filter by property: `(seq-filter (lambda (ov) (overlay-get ov 'my-data)) (overlays-at pos))`.

## Using timers

```elisp
(defvar my--timer nil)

(defun my-schedule-refresh ()
  (when my--timer (cancel-timer my--timer))
  (setq my--timer (run-with-idle-timer 0.5 nil #'my-refresh)))

(defun my-refresh ()
  (setq my--timer nil)
  (message "Refreshed!"))
```

- `run-at-time time repeat function &rest args` — absolute or relative time.
- `run-with-idle-timer secs repeat function &rest args` — run after idle.
- `run-with-timer secs repeat function &rest args` — run after delay.
- Always cancel timers when done. Store timer object for cancellation.

## Process handling

```elisp
(make-process
 :name "my-proc"
 :command (list "rg" "--json" pattern)
 :buffer "*my-proc*"
 :filter (lambda (proc output)
           (with-current-buffer (process-buffer proc)
             (insert output)))
 :sentinel (lambda (proc event)
             (when (memq (process-status proc) '(exit signal))
               (message "Process finished: %s" event)))
 :noquery t)
```

For simpler synchronous use:

```elisp
(with-temp-buffer
  (let ((status (call-process "git" nil t nil "status" "--porcelain")))
    (list status (buffer-string))))

(process-lines "git" "status" "--porcelain")
```

## Window management

```elisp
(selected-window)
(get-buffer-window buffer &optional frame)
(window-buffer window)
(switch-to-buffer buffer &optional norecord force-same-window)
(pop-to-buffer buffer &optional action norecord)
(display-buffer buffer &optional action)
```

`display-buffer` is non-destructive (doesn't change focus). `pop-to-buffer` may change focus. `switch-to-buffer` always changes focus.

```elisp
(save-selected-window
  (select-window (get-buffer-window "*scratch*"))
  (erase-buffer)
  (insert "content"))
```

## Face definition and manipulation

```elisp
(defface my-warning-face
  '((t :inherit font-lock-warning-face :underline t))
  "Face for warnings in my mode."
  :group 'my-mode)

(set-face-attribute 'my-warning-face nil :foreground "red")
(face-attribute 'my-warning-face :foreground)
```

Use `:inherit` to derive from existing faces. Check face with `facep`.

## Text properties

```elisp
(put-text-property start end 'face 'bold)
(put-text-property start end 'my-prop t)
(get-text-property pos 'my-prop)
(next-single-property-change pos 'my-prop)
(remove-text-properties start end '(my-prop nil))
```

- Properties are more efficient than overlays for large regions.
- Overlays are easier to manage for small, dynamic regions.
- Use `font-lock` for syntax highlighting instead of manual text properties.

## CL integration (`cl-lib`)

```elisp
(require 'cl-lib)

(cl-defun process (data &key verbose dry-run)
  (when verbose (message "Processing..."))
  (unless dry-run (do-work data)))

(cl-loop for x in list
         if (> x threshold)
         collect x into big
         else
         collect x into small
         finally return (list big small))

(cl-destructuring-bind (key (a b) &rest rest) data
  (list key a b rest))

(with-temp-buffer
  (let ((status (process-file "sh" nil t nil "-c" "printf 'ok'")))
    (list status (buffer-string))))
(cl-the integer (+ x y))
```

Always use `cl-lib` (prefixed) instead of deprecated `cl` (unprefixed). `cl-lib` is built into Emacs 24.3+.

## Pattern: transient state / hydra

```elisp
(defvar my-repeat-map
  (let ((map (make-sparse-keymap)))
    (define-key map "n" #'next-line)
    (define-key map "p" #'previous-line)
    map)
  "Repeat map for navigation.")

(put 'next-line 'repeat-map 'my-repeat-map)
(put 'previous-line 'repeat-map 'my-repeat-map)
```

Built-in `repeat-mode` (Emacs 28+) makes commands repeatable via a keymap attached to the command symbol.

## Pattern: async operations

```elisp
(defun my-start-search (pattern callback)
  (let ((buffer (generate-new-buffer " *my-rg*")))
    (make-process
     :name "my-rg"
     :command `("rg" "--json" ,pattern)
     :buffer buffer
     :sentinel
     (lambda (proc _event)
       (when (memq (process-status proc) '(exit signal))
         (unwind-protect
             (with-current-buffer (process-buffer proc)
               (funcall callback (buffer-string) (process-exit-status proc)))
           (kill-buffer (process-buffer proc)))))
     :noquery t)))
```

Threads are build-dependent. Check `(fboundp 'make-thread)` or `(featurep 'threads)` before relying on them. For portable async work, prefer processes, timers, or built-in async APIs such as `url-retrieve`.
