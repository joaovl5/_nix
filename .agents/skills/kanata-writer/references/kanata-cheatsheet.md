# Kanata Cheatsheet

Use this as a compact syntax aid after loading the Kanata skill. Verify
details against the pinned Kanata version when behavior matters.

## Sources

- **Repo config:** `users/_modules/desktop/services/kanata/config/config.kbd`
- **Repo service:** `users/_modules/desktop/services/kanata/default.nix`
- **Upstream guide:**
  <https://github.com/jtroo/kanata/blob/main/docs/config.adoc>
- **Upstream README:** <https://github.com/jtroo/kanata/blob/main/README.md>

## Syntax basics

- **S-expression:** `(defsrc key1 key2 ...)` lists forms in parentheses
- **String:** bare words like `backspace` or quoted strings like
  `"string with spaces"`
- **Whitespace:** spaces, tabs, and newlines are flexible; use them for layer
  alignment
- **Comments:** `;; single line` and `#| multi-line |#`

## Minimal structure

```lisp
(defcfg
  process-unmapped-keys yes)

(defsrc
  caps h j k l)

(deflayer default
  @cap _ _ _ _)

(defalias
  cap (tap-hold 200 200 caps lctl))
```

- **Required forms:** one `defsrc` and at least one `deflayer` or
  `deflayermap`
- **Layer shape:** each `deflayer` action aligns to the corresponding `defsrc`
  key
- **Alternative shape:** `deflayermap` uses input-output pairs instead of full
  layer rows

## Emergency stop and reload

- **Force exit:** hold `LCtl + Space + Esc` together
- **Live reload:** `lrld` reloads current config
- **Indexed reload:** `(lrld-num n)` reloads the nth config file
- **Cycle reloads:** `lrld-prev`/`lrpv` and `lrld-next`/`lrnx`

## Aliases and variables

```lisp
(defalias
  cap (tap-hold 200 200 caps lctl))

(deflayer default
  @cap)

(defvar
  tap-time 200
  hold-time 200)
```

- **Alias definition:** define as `name action` inside `defalias`
- **Alias use:** prefix with `@`, such as `@cap`
- **Variable use:** prefix with `$`, such as `$tap-time`

## Layer actions

| Action | Syntax | Use |
| --- | --- | --- |
| Switch layer | `(layer-switch name)` | Permanent layer switch |
| Hold layer | `(layer-while-held name)` | Temporary layer while key is held |
| Transparent | `_` | Fall through to lower layer |
| Source key | `use-defsrc` | Output the physical source key |
| No-op | `XX`, `✗`, or `∅` | Do nothing |

## Output chords and modifiers

| Prefix | Modifier |
| --- | --- |
| `C-` | Left Control |
| `RC-` | Right Control |
| `A-` | Left Alt |
| `RA-` / `AG-` | Right Alt / AltGr |
| `S-` | Left Shift |
| `RS-` | Right Shift |
| `M-` | Left Meta |
| `RM-` | Right Meta |

Examples: `C-c`, `S-1`, `M-tab`

## Tap-hold actions

```lisp
(tap-hold tap-timeout hold-time tap-action hold-action)
(tap-hold-press ...)
(tap-hold-release ...)
(tap-hold-tap-keys ... keys)
(tap-hold-opposite-hand timeout tap hold)
```

- **Plain tap-hold:** tap when released early, hold after timeout
- **Press variant:** hold activates on another key press
- **Release variant:** hold activates after another key press and release
- **Tap keys variant:** early tap only for specified keys
- **Opposite hand:** pair with `defhands` for hand-aware behavior
- **HACK:** for Linux repeat quirks, some configs wrap tap-hold in
  `(multi f24 ...)`; verify before using

## defhands

```lisp
(defhands
  (left  q w e r t a s d f g z x c v b)
  (right y u i o p h j k l ; n m , . /))
```

Use with hand-aware actions such as `tap-hold-opposite-hand`.

## One-shot, tap-dance, and macros

```lisp
(one-shot timeout action)
(one-shot-release timeout action)
(tap-dance timeout (action1 action2 ...))
(tap-dance-eager timeout (action1 action2 ...))
(macro key1 key2 100 key3 ...)
(macro-release-cancel ...)
(macro-cancel-on-press ...)
(macro-repeat ...)
```

- **One-shot:** action applies to the next key press
- **Tap-dance:** repeated taps choose actions in order
- **Macro delays:** numeric `0`-`9` values are delays in macros
- **Digit output:** use `Digit0`-`Digit9` when a macro should type digits

## Mouse actions

| Action | Use |
| --- | --- |
| `mlft`, `mmid`, `mrgt` | Hold left, middle, or right mouse button |
| `mltp`, `mmtp`, `mrtp` | Tap left, middle, or right mouse button |
| `mwheel-up`, `mwheel-down` | Scroll vertically |
| `mwheel-left`, `mwheel-right` | Scroll horizontally |
| `(mwheel-up 50 120)` | Scroll with interval and distance |
| `movemouse-up`, `movemouse-down` | Move pointer |
| `(movemouse-accel-up 1 1000 1 5)` | Move pointer with acceleration |
| `setmouse x y` | Set absolute pointer position |

## Unicode

```lisp
(unicode U+1F600)
(unicode "(")
(unicode r#"""#)
```

- **Codepoints:** prefer explicit `U+...` in shared examples
- **Parentheses:** quote literal parentheses
- **Double quotes:** use raw strings for literal quotes

## Fork, switch, and conditions

```lisp
(fork default-action alt-action (key1 key2 ...))

(switch
  (condition) action break
  (condition) action fallthrough)
```

Common condition forms:

- **Boolean:** `(or ...)`, `(and ...)`, `(not ...)`
- **History:** `(key-history key recency)` and `(key-timing recency lt/gt ms)`
- **Input:** `(input real key)` or `(input virtual key)`
- **Layer:** `(layer name)` and `(base-layer name)`

## Virtual keys

```lisp
(defvirtualkeys
  name action)

(on-press tap-vkey name)
(on-press press-vkey name)
(on-release release-vkey name)
(on-idle ms tap-vkey name)
(hold-for-duration ms name)
```

- **Tap vkey:** press and release a virtual key
- **Press vkey:** press only; pair with release when needed
- **Idle vkey:** trigger after idle time

## Sequences

```lisp
(defseq dotcom (. S-3))
(defvirtualkeys dotcom (macro . c o m))

(defalias
  lead (sldr))
```

- **Sequence leader:** `sldr` starts sequence recognition
- **Timeout:** set with `sequence-timeout` in `defcfg`

## Chords v2

```lisp
(defcfg
  concurrent-tap-hold yes)

(defchordsv2
  (a s) action timeout release-behaviour (disabled-layers))
```

- **Enable first:** `concurrent-tap-hold yes`
- **Release behavior:** usually `first-release` or `all-released`

## Overrides, includes, and templates

```lisp
(defoverrides
  (input-key) (output-key))

(defoverridesv2
  (input) (output) (exclude-modifiers) (exclude-layers))

(include file.kbd)
(platform (win linux macos) ...)
(environment (ENV_VAR value) ...)

(deftemplate name (var1 var2) content)
(t! name param1 param2)
(if-equal a b true-case false-case)
(if-not-equal a b true-case false-case)
(if-in-list value (items ...) true-case false-case)
```

## defcfg options

| Option | Use |
| --- | --- |
| `process-unmapped-keys yes` | Let Kanata process keys not in `defsrc` |
| `linux-continue-if-no-devs-found yes` | Keep Linux service alive if devices are absent |
| `sequence-timeout ms` | Sequence leader timeout |
| `sequence-input-mode ...` | Visible/backspace, hidden/suppressed, or hidden/delay modes |
| `concurrent-tap-hold yes` | Required for chords v2 |
| `delegate-to-first-layer yes` | Transparent keys delegate to first layer |
| `tap-hold-require-prior-idle ms` | Reduce tap-hold misfires after typing |
| `block-unmapped-keys yes` | Block keys not in `defsrc` |
| `rapid-event-delay ms` | Event delay between rapid events |

Linux-only examples:

```lisp
linux-dev /path
linux-dev-names-include (...)
linux-dev-names-exclude (...)
linux-unicode-u-code v
linux-unicode-termination enter
```

Windows-only examples:

```lisp
windows-altgr cancel-lctl-press
windows-interception-keyboard-hwids (...)
```

## Key names

- **Modifiers:** `lctl`, `rctl`, `lsft`, `rsft`, `lalt`, `ralt`, `lmet`,
  `rmet`
- **Special:** `spc`, `ret`, `tab`, `esc`, `bspc`, `del`
- **Arrows:** `left`, `rght`, `up`, `down`
- **Navigation:** `home`, `end`, `pgup`, `pgdn`
- **Functions:** `f1` through `f12`
- **Numpad:** `kp0` through `kp9`, `kpdiv`, `kpmul`, `kpadd`, `kpsub`, `kpdec`

Use upstream key definitions when exact spelling matters.
