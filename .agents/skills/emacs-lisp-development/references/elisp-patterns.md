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

- **Mode variable:** `define-minor-mode` creates the toggle variable `my-highlight-mode`
- **Buffer-local hook:** use `nil t` in `add-hook` to keep the hook local to the buffer
- **Disable cleanup:** remove hooks and overlays when the mode turns off

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

- **Prefix maps:** build a sparse keymap, then bind it under a prefix key

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

- **Self-removal:** `evaporate` makes an overlay delete itself when its text is deleted
- **Queries:** use `overlays-at` and `overlays-in`
- **Removal:** use `delete-overlay`
- **Property filter:** `(seq-filter (lambda (ov) (overlay-get ov 'my-data)) (overlays-at pos))`

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

- **Absolute or relative timer:** `run-at-time time repeat function &rest args`
- **Idle timer:** `run-with-idle-timer secs repeat function &rest args`
- **Delay timer:** `run-with-timer secs repeat function &rest args`
- **Lifecycle:** keep the timer object and cancel it when done

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

- **Synchronous work:** use `call-process`, `process-file`, or `process-lines` when async adds no value

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

- **Display choices:** `display-buffer` is non-destructive, `pop-to-buffer` may move focus, and `switch-to-buffer` always does

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

- **Inheritance:** use `:inherit` to derive from existing faces
- **Predicates:** use `facep` when callers may pass an unknown face

## Text properties

```elisp
(put-text-property start end 'face 'bold)
(put-text-property start end 'my-prop t)
(get-text-property pos 'my-prop)
(next-single-property-change pos 'my-prop)
(remove-text-properties start end '(my-prop nil))
```

- **Large regions:** text properties are usually cheaper than overlays
- **Dynamic spans:** overlays are easier for small changing regions
- **Syntax highlight:** prefer `font-lock` over manual face properties

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

(cl-the integer (+ x y))
```

- **Prefix:** use `cl-lib` APIs, not deprecated unprefixed `cl`

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

- **Repeat mode:** built-in `repeat-mode` in Emacs 28+ repeats commands through a keymap on the command symbol

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

- **Threads:** build support varies, so check `(fboundp 'make-thread)` or `(featurep 'threads)` before relying on them
- **Portable async:** prefer processes, timers, or built-in async APIs like `url-retrieve`
