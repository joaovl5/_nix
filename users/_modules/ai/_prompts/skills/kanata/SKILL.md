---
name: kanata-writer
description: Configuration assistant for Kanata
---

# Configuration-Specific Information

- **Configuration for Kanata is located at `~/my_nix/users/_modules/kanata/config.kbd` or at `users/_modules/kanata/config.kbd` if you are already at this folder**
- !!! No need for running checks after changing kanada configuration.

# Kanata Configuration Cheatsheet

## Syntax Basics

- **S-expression**: `(defsrc key1 key2 ...)` - lists in parentheses
- **String**: `backspace` or `"string with spaces"`
- **Whitespace**: Flexible; use spaces/tabs/newlines for formatting

## Required Configuration

```nix
(defsrc                     ; Define physical key layout (required, exactly 1)
  grv  1    2    3    4    5    6    7    8    9    0    -    =    bspc
  tab  q    w    e    r    t    y    u    i    o    p    [    ]    \
  caps a    s    d    f    g    h    j    k    l    ;    '    ret
  lsft z    x    c    v    b    n    m    ,    .    /    rsft
  lctl lmet lalt           spc            ralt rmet rctl
)

(deflayer $name ... )       ; Define layer actions (required, at least 1)
(deflayermap ($name) ...)   ; Alternative: input-output pairs
```

## Comments

```nix
;; Single line
#| Multi-line |#
```

## Force Exit

Hold `LCtl + Space + Esc` simultaneously.

## Aliases & Variables

```nix
(defalias
  cap (tap-hold 200 200 caps lctl)   ; tap=caps, hold=lctl
  @cap                                ; Use alias with @ prefix
)

(defvar
  tap-time 200
  hold-time 200
  $tap-time $hold-time                ; Variable reference with $ prefix
)
```

## Layer Actions

| Action             | Syntax                      | Description                              |
| ------------------ | --------------------------- | ---------------------------------------- |
| `layer-switch`     | `(layer-switch $layer)`     | Permanent switch to layer                |
| `layer-while-held` | `(layer-while-held $layer)` | Temp layer while key held                |
| `_`                | (underscore)                | Transparent: use action from layer below |
| `use-defsrc`       | `use-defsrc`                | Output defsrc key                        |
| `XX`               | `XX` or `✗` or `∅`          | No-op (do nothing)                       |

## Output Chords (Modifiers)

| Prefix        | Modifier            |
| ------------- | ------------------- |
| `C-`          | Left Control        |
| `RC-`         | Right Control       |
| `A-`          | Left Alt            |
| `RA-` / `AG-` | Right Alt (AltGr)   |
| `S-`          | Left Shift          |
| `RS-`         | Right Shift         |
| `M-`          | Left Meta (Win/Cmd) |
| `RM-`         | Right Meta          |

Example: `C-c`, `S-1` (= `!`), `M-tab`

## Tap-Hold Actions

```nix
(tap-hold $tap-timeout $hold-time $tap-action $hold-action)
(tap-hold-press ...)       ; Hold activates on any key press
(tap-hold-release ...)     ; Hold activates on any key press+release
(tap-hold-tap-keys ... $keys) ; Only early-tap for specific keys
(tap-hold-opposite-hand $timeout $tap $hold) ; Use with defhands
```

**Linux repeat issue workaround**: `(multi f24 (tap-hold ...))`

## defhands

```nix
(defhands
  (left  q w e r t a s d f g z x c v b)
  (right y u i o p h j k l ; n m , . /)
)
```

## One-Shot

```nix
(one-shot $timeout $action)           ; Ends on next key press
(one-shot-release $timeout $action)   ; Ends on key release
(os1 (one-shot 500 (layer-while-held nav)))
```

## Tap-Dance

```nix
(tap-dance $timeout (action1 action2 ...))
(tap-dance-eager ...)  ; Activates each action progressively
```

## Macro

```nix
(macro key1 key2 100 key3 ...)  ; 100 = 100ms delay
(macro-release-cancel ...)      ; Cancel on release
(macro-cancel-on-press ...)     ; Cancel on other key press
(macro-repeat ...)              ; Repeat while held

;; Note: 0-9 are delays in macros, use Digit0-Digit9 for key output
```

## Live Reload

```nix
lrld              ; Reload current config
(lrld-num $n)     ; Reload nth config file
lrld-prev/lrld-next (lrpv/lrnx)
```

## Mouse Actions

| Action                            | Description                                             |
| --------------------------------- | ------------------------------------------------------- |
| `mlft/mmid/mrgt`                  | Hold left/middle/right button                           |
| `mltp/mmtp/mrtp`                  | Tap left/middle/right button                            |
| `mwheel-up/down/left/right`       | Scroll                                                  |
| `(mwheel-up 50 120)`              | (interval_ms, distance)                                 |
| `movemouse-up/down/left/right`    | Move cursor                                             |
| `(movemouse-accel-up 1 1000 1 5)` | (interval, accel_time, min, max)                        |
| `setmouse $x $y`                  | Set absolute position (Windows: 0-65535, macOS: pixels) |

## Unicode

```nix
(unicode 😀)        ; Emoji
(unicode U+1F686)  ; Codepoint
(unicode "(")      ; Parenthesis need quoting
(unicode r#"""#)   ; Double quotes need raw string
```

## Switch & Fork

```nix
(fork $default-action $alt-action (key1 key2 ...))

(switch
  (condition) action break/fallthrough
  ...
)

;; Conditions: key names, (or ...), (and ...), (not ...), (key-history key recency),
;;             (key-timing recency lt/gt ms), (input real/virtual key),
;;             (layer $name), (base-layer $name)
```

## Virtual Keys

```nix
(defvirtualkeys
  name action
  ...
)

(on-press tap-vkey $vkey)    ; Press+release
(on-press press-vkey $vkey)  ; Press only
(on-release release-vkey $vkey)
(on-idle $ms tap-vkey $vkey)
(hold-for-duration $ms $vkey)
```

## Sequences (Leader Key)

```nix
(defseq name (key1 key2 ...))
(sldr)  ; Sequence leader action

;; Example:
(defseq dotcom (. S-3))
(defvirtualkeys dotcom (macro . c o m))
```

## Input Chords (v2)

```nix
(defcfg concurrent-tap-hold yes)
(defchordsv2
  (a s) action timeout release-behaviour (disabled-layers)
)
;; release-behaviour: first-release | all-released
```

## Global Overrides

```nix
(defoverrides
  (input-key) (output-key)
)

(defoverridesv2
  (input) (output) (exclude-modifiers) (exclude-layers)
)
```

## Include / Platform / Environment

```nix
(include file.kbd)

(platform (win linux macos) ...)

(environment (ENV_VAR value) ...)
```

## Templates

```nix
(deftemplate name (var1 var2) content)
(t! name param1 param2)  ; or (template-expand ...)

(if-equal $a $b true-case false-case)
(if-not-equal ...)
(if-in-list ... ...)
```

## defcfg Options

| Option                           | Description                                                  |
| -------------------------------- | ------------------------------------------------------------ |
| `process-unmapped-keys yes`      | Process keys not in defsrc                                   |
| `danger-enable-cmd yes`          | Enable cmd action                                            |
| `sequence-timeout ms`            | Sequence leader timeout (default 1000)                       |
| `sequence-input-mode`            | `visible-backspaced`/`hidden-suppressed`/`hidden-delay-type` |
| `concurrent-tap-hold yes`        | Enable for chords v2                                         |
| `delegate-to-first-layer yes`    | Transparent keys delegate to first layer                     |
| `tap-hold-require-prior-idle ms` | Prevent misfires after typing                                |
| `block-unmapped-keys yes`        | Block keys not in defsrc                                     |
| `rapid-event-delay ms`           | Event delay (default 5)                                      |

### Linux Only

```nix
linux-dev /path
linux-dev-names-include (...)
linux-dev-names-exclude (...)
linux-unicode-u-code v
linux-unicode-termination enter/space
```

### Windows Only

```nix
windows-altgr cancel-lctl-press | add-lctl-release
windows-interception-keyboard-hwids (...)
```

## Quick Reference: Key Names

- Modifiers: `lctl/rctl`, `lsft/rsft`, `lalt/ralt`, `lmet/rmet`
- Special: `spc`, `ret`, `tab`, `esc`, `bspc`, `del`
- Arrows: `left`, `right`, `up`, `down`
- Nav: `home`, `end`, `pgup`, `pgdn`
- Func: `f1`-`f12`
- Numpad: `kp0`-`kp9`, `kpdiv`, `kpmul`, `kpadd`, `kpsub`, `kpdec`

Key names from: `str_to_oscode` in kanata source.
