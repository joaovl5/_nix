# Neovim Plugin DSL v2 Implementation Plan

> **For agentic workers:** REQUIRED: Use
> superpowers:subagent-driven-development (if subagents available) or
> superpowers:executing-plans to implement this plan. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a clearer Fennel DSL for Neovim Lazy.nvim plugin specs
and plugin-local keybinds, centered on `plugin!`, `lib.plugins`, and
`lib.keys`.

**Architecture:** Keep generated Lua untouched and make Fennel source
the source of truth. Add small runtime helper modules for composable
plugin/key constructors, then add a thin macro that rewrites
unqualified DSL helper forms inside `(plugin! ...)` into qualified
`p.*`/`k.*` helper calls. Keep the existing `plugin` and `key` macros
available unless a later migration explicitly removes them.

**Tech Stack:** Fennel, nfnl, Neovim Lazy.nvim plugin specs,
repo-local skills under `.agents/skills`.

---

## File Structure

- Modify:
  `users/_modules/desktop/apps/editor/neovim/config/fnl/lib/init-macros.fnl`
  - Keep `;; fennel-ls: macro-file` as line 1
  - Add `plugin!` macro
  - Export `plugin!` beside existing `plugin` and `key`
- Create:
  `users/_modules/desktop/apps/editor/neovim/config/fnl/lib/keys.fnl`
  - Runtime helpers for key strings and Lazy.nvim key specs: `l`, `c`,
    `a`, `cmd`, `desc`, `m`, `bind`
- Create:
  `users/_modules/desktop/apps/editor/neovim/config/fnl/lib/plugins.fnl`
  - Runtime helpers for Lazy.nvim plugin spec fields: `event`, `ft`,
    `keys`, `opts`, `dependencies`, `version`, `cmd`, plus a raw merge
    helper if useful
- Modify initially as the first real call-site:
  `users/_modules/desktop/apps/editor/neovim/config/fnl/plugins/lsp/languages/python.fnl`
  - Use `(plugin! ...)`, `(keys (bind ...))`, `(cmd ...)`,
    `(desc ...)`
  - Import runtime modules as `k` and `p` if explicit usage is needed
- Modify later, after first call-site passes: other plugin specs under
  `users/_modules/desktop/apps/editor/neovim/config/fnl/plugins/**`
  - Migrate only files intentionally selected by the implementer or
    requester
- Modify: `.agents/skills/neovim-configuration/SKILL.md`
  - Document that plugin-local binds should prefer the new
    `(keys (bind ...))` path
  - Keep the skill concise per
    `.agents/skills/skill-authoring/SKILL.md`

---

## Chunk 1: Runtime Helper Modules

### Task 1: Add `lib.keys` helpers

**Files:**

- Create:
  `users/_modules/desktop/apps/editor/neovim/config/fnl/lib/keys.fnl`
- [ ] **Step 1: Implement small key constructors**

Create helpers with docstrings where behavior could be surprising:

```fennel
(fn l [suffix]
  "Return a <leader> mapping lhs. Example: `(l :cv)` => `:<leader>cv`."
  (.. "<leader>" (tostring suffix)))

(fn c [key]
  "Return a Ctrl mapping lhs. Example: `(c :V)` => `:<C-V>`."
  (.. "<C-" (tostring key) ">"))

(fn a [key]
  "Return an Alt mapping lhs. Example: `(a :x)` => `:<A-x>`."
  (.. "<A-" (tostring key) ">"))

(fn cmd [command]
  "Return a command rhs wrapped as `<cmd>...<cr>`. Use for commands, including commands with spaces."
  (.. "<cmd>" command "<cr>"))

(fn desc [text]
  "Return a Lazy.nvim key opts table containing only `:desc`."
  {:desc text})
```

- [ ] **Step 2: Implement mode grouping helper**

`m` groups one mode or a vector of modes with one or more lhs values:

```fennel
(fn m [mode ...]
  "Return a mode-bound lhs group for `bind`. Example: `(m [:n :x :o] (l :xx) :\\x)`."
  {:__keys_kind :mode-group
   :mode mode
   :lhs [...]})
```

Use the correct Fennel vararg handling rather than assuming `...` is
already a table. Keep the marker field internal and unlikely to
collide.

- [ ] **Step 3: Implement key spec normalizer**

`bind` should accept:

```fennel
(bind lhs rhs opts...)
```

Where `lhs` is either:

```fennel
(l :xx)
[(m [:n :x :o] (l :xx) :\x)
 (m :i (c :X))]
```

The result should be a vector of Lazy.nvim key spec tables, even for
one lhs. Each emitted spec should set positional fields `1` and `2`,
merge option tables from `opts...`, and add `:mode` for mode groups.

Example expected result shape:

```fennel
(bind (l :xx) (cmd "Foo") (desc "Do thing"))
```

should return a one-level vector of Lazy key specs:

```fennel
[{1 "<leader>xx" 2 "<cmd>Foo<cr>" :desc "Do thing"}]
```

Advanced example:

```fennel
(bind [(m [:n :x :o] (l :xx) :\x)
       (m :i (c :X))]
      (cmd "FooDoThing with args")
      (desc "Does thing"))
```

should emit three key specs: two with `:mode [:n :x :o]`, one with
`:mode :i`.

- [ ] **Step 4: Export helper table**

Export:

```fennel
{: l : c : a : cmd : desc : m : bind}
```

### Task 2: Add `lib.plugins` helpers

**Files:**

- Create:
  `users/_modules/desktop/apps/editor/neovim/config/fnl/lib/plugins.fnl`

- [ ] **Step 1: Implement field constructors**

Each helper should return a small table ready to merge into a
Lazy.nvim plugin spec:

```fennel
(fn event [value] {:event value})
(fn ft [value] {:ft value})
(fn keys [...] {:keys [...]})
(fn opts [value] {:opts value})
(fn dependencies [value] {:dependencies value})
(fn version [value] {:version value})
(fn cmd [value] {:cmd value})
```

For `keys`, flatten vectors returned by `k.bind` so this works:

```fennel
(keys
  (bind (l :xx) (cmd "Foo") (desc "Do thing")))
```

and this also works:

```fennel
(keys
  (bind (l :aa) (cmd "FooA") (desc "A"))
  (bind (l :bb) (cmd "FooB") (desc "B")))
```

- [ ] **Step 2: Add table merge helper if needed**

If repeated merging is needed, either use `lib.utils.merge` or add a
tiny local helper. Avoid broad utility refactors.

- [ ] **Step 3: Export helper table**

Export at least:

```fennel
{: event : ft : keys : opts : dependencies : version : cmd}
```

---

## Chunk 2: `plugin!` Macro

### Task 3: Add `plugin!` macro expansion

**Files:**

- Modify:
  `users/_modules/desktop/apps/editor/neovim/config/fnl/lib/init-macros.fnl`

- [ ] **Step 1: Preserve existing macro API**

Do not remove or rename existing `plugin` or `key` yet. The first
change should be additive.

- [ ] **Step 2: Add shorthand rewriting rules**

Inside `(plugin! id forms...)`, support unqualified helper heads by
rewriting them to runtime helper modules:

Plugin-level forms:

```fennel
(event x)        ; p.event
(ft x)           ; p.ft
(keys ...)       ; p.keys
(opts x)         ; p.opts
(dependencies x) ; p.dependencies
(version x)      ; p.version
(cmd x)          ; p.cmd at plugin level
```

Key-level forms nested under `(keys ...)`:

```fennel
(bind ...) ; k.bind
(l x)      ; k.l
(c x)      ; k.c
(a x)      ; k.a
(m ...)    ; k.m
(desc x)   ; k.desc
(cmd x)    ; k.cmd inside bind/key context
```

Do not recursively rewrite arbitrary forms under `(keys ...)`. Bound
rewriting to the DSL grammar: `(keys ...)` may rewrite direct
`(bind ...)` children; `(bind lhs rhs opts...)` may rewrite lhs helper
forms, recognized RHS helper forms such as `(cmd ...)`, and option
helper forms such as `(desc ...)`; RHS functions, quoted forms,
arbitrary tables, literal strings, and unknown calls are opaque.

- [ ] **Step 3: Emit required runtime imports inside expansion**

`plugin!` should expand to a `let` that binds module tables locally,
avoiding per-plugin-file import noise:

```fennel
(let [p# (require :lib.plugins)
      k# (require :lib.keys)]
  ...)
```

Use gensyms (`#`) for introduced locals. Rewritten helper calls should
refer to those gensym locals, not global `p` or `k` names.

- [ ] **Step 4: Merge helper result tables and fallback opts**

`plugin!` should return one Lazy.nvim plugin spec table with
positional field `1` set to the plugin identifier.

It should merge:

1. helper result tables from forms like `(event :VeryLazy)`
2. any literal table forms supplied as fallback opts, preferably as
   the last argument

Do not make raw `:keys value` keyword-pair syntax the documented path.
If keyword-pair fallback is implemented, keep it secondary and
document table fallback first.

- [ ] **Step 5: Export macro**

Update final export table to include `plugin!`:

```fennel
{: do-req : let-req : plugin : key : plugin!}
```

---

## Chunk 3: First Call-Site Migration

### Task 4: Migrate Python venv-selector spec

**Files:**

- Modify:
  `users/_modules/desktop/apps/editor/neovim/config/fnl/plugins/lsp/languages/python.fnl`

- [ ] **Step 1: Update macro import**

Change the import to include `plugin!`. Keep existing imports only if
still used:

```fennel
(import-macros {: plugin!} :./lib/init-macros)
```

- [ ] **Step 2: Rewrite plugin spec using new DSL**

Target shape:

```fennel
(plugin! :linux-cultist/venv-selector.nvim
  (dependencies [(plugin! :nvim-telescope/telescope.nvim
                   (version "*"))])
  (ft :python)
  (keys
    (bind (l :cv)
          (cmd "VenvSelect")
          (desc "Pick virtual env")))
  (opts {}))
```

If `version` should preserve the old keyword value style, use
`(version :*)` only if Lazy.nvim receives the same value as before.
Otherwise keep string `"*"`.

- [ ] **Step 3: Verify generated shape by compiling and asserting
      runtime shape**

Run the Neovim nfnl wrapper from repo root:

```bash
uv run .agents/skills/neovim-configuration/scripts/recompile-nfnl.py
```

Expected: command exits 0 and reports successful compile. If generated
Lua changes, inspect only enough to confirm the Lazy spec shape; do
not hand-edit generated Lua.

- [ ] **Step 4: Run focused runtime shape assertions**

Add or run a one-off headless Neovim/Lua assertion that requires the
compiled helper modules and the migrated Python plugin module, then
checks exact table shape. The assertion must prove:

- `lib.keys.bind` returns a one-level vector of key specs
- `lib.plugins.keys` flattens multiple `bind` results into one `:keys`
  vector
- `plugins.lsp.languages.python` exports the expected Lazy spec with
  plugin id, dependency id/version, `:ft :python`, and key spec
  `{1 "<leader>cv" 2 "<cmd>VenvSelect<cr>" :desc "Pick virtual env"}`
- the advanced `(m mode lhs...)` contract emits exactly three
  one-level specs for the documented example, with correct `:mode`,
  lhs, rhs, and `:desc` fields

Prefer a short repo-local command or temporary script that can be
removed after validation. Do not rely on generated Lua inspection
alone; compile success does not execute runtime helper behavior.

---

## Chunk 4: Skill Documentation

### Task 5: Document new plugin-local keybind path

**Files:**

- Modify: `.agents/skills/neovim-configuration/SKILL.md`
- [ ] **Step 1: Follow repo-local skill-authoring guidance**

Before editing, read `.agents/skills/skill-authoring/SKILL.md`. Keep
the change concise and operational.

- [ ] **Step 2: Add a short plugin keybind rule**

Add a small section or bullets saying plugin-local keybinds should
prefer:

```fennel
(plugin! :foo/bar
  (keys
    (bind (l :xx)
          (cmd "SomeCommand")
          (desc "Do thing"))))
```

Mention advanced mode/lhs grouping:

```fennel
(bind [(m [:n :x :o] (l :xx) :\x)
       (m :i (c :X))]
      (cmd "SomeCommand with args")
      (desc "Do thing"))
```

Keep examples short; if this section grows, move examples into a
skill-relative reference file.

---

## Chunk 5: Verification and Cleanup

### Task 6: Run focused verification

**Files:**

- Relevant changed Fennel source files
- `.agents/skills/neovim-configuration/SKILL.md`
- [ ] **Step 1: Recompile Neovim Fennel**

Run:

```bash
uv run .agents/skills/neovim-configuration/scripts/recompile-nfnl.py
```

Expected: exits 0.

- [ ] **Step 2: Format repository files**

Run:

```bash
nix fmt
```

Expected: exits 0.

- [ ] **Step 3: Stage exact intended files for `prek`**

Run `git status --short`, then stage only intended files. Include
generated Lua files produced by the recompile wrapper because they are
tracked runtime outputs, but never hand-edit them. Example:

```bash
git add \
  users/_modules/desktop/apps/editor/neovim/config/fnl/lib/init-macros.fnl \
  users/_modules/desktop/apps/editor/neovim/config/fnl/lib/keys.fnl \
  users/_modules/desktop/apps/editor/neovim/config/fnl/lib/plugins.fnl \
  users/_modules/desktop/apps/editor/neovim/config/fnl/plugins/lsp/languages/python.fnl \
  .agents/skills/neovim-configuration/SKILL.md \
  users/_modules/desktop/apps/editor/neovim/config/lua/lib/keys.lua \
  users/_modules/desktop/apps/editor/neovim/config/lua/lib/plugins.lua \
  users/_modules/desktop/apps/editor/neovim/config/lua/plugins/lsp/languages/python.lua
```

Do not run `git commit` unless the user explicitly permits it.

- [ ] **Step 4: Run pre-commit hooks**

Run:

```bash
prek
```

Expected: exits 0. `prek` only checks staged files.

- [ ] **Step 5: Decide whether `nix flake check --all-systems` is
      needed**

No Nix files are planned to change, so do not run
`nix flake check --all-systems` unless implementation unexpectedly
touches Nix code.

### Task 7: Optional broader migration

**Files:**

- Only plugin files explicitly selected under
  `users/_modules/desktop/apps/editor/neovim/config/fnl/plugins/**`

- [ ] **Step 1: Search current key macro call-sites**

Use repository search for `(key` and inspect matches. Do not migrate
everything automatically unless requested.

- [ ] **Step 2: Migrate one small cluster at a time**

For each selected plugin file, replace plugin-local key specs with
`(keys (bind ...))`. Keep global keymap code out of scope unless
specifically requested.

- [ ] **Step 3: Recompile after each cluster**

Run the nfnl recompile wrapper after each cluster to catch macro
expansion issues early.

---

## Notes and Risks

- The new DSL intentionally favors helper forms over deriving behavior
  from keywords or strings.
- `(cmd "...")` is required for command rhs values, including commands
  with spaces.
- Plain strings remain literal rhs values.
- The `plugin!` macro should be additive first; removing old
  `plugin`/`key` can be a separate cleanup after call-sites migrate.
- If shorthand rewriting inside `plugin!` becomes too complex, fall
  back to explicit module calls like `(p.keys (k.bind ...))`; this is
  less ergonomic but keeps behavior simple and testable.
- Generated Lua under
  `users/_modules/desktop/apps/editor/neovim/config/lua/**` must never
  be edited by hand.
