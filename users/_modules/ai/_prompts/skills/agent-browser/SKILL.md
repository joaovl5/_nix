---
name: agent-browser
description: Browser automation workflow for agent-browser CLI
---

Use `agent-browser` for browser automation tasks where a CLI-driven browser is appropriate.

Core workflow:

1. Open the target page with `agent-browser open <url>`.
2. Inspect the page with `agent-browser snapshot -i --json`.
3. Read refs like `@e1`, `@e2`, `@e3` from the snapshot.
4. Interact with refs using commands like `click`, `fill`, `type`, `hover`, `press`, or `get text`.
5. Re-run `snapshot -i --json` after page changes.

Prefer refs over brittle selectors whenever possible.

- Good: `agent-browser click @e2`
- Good: `agent-browser fill @e3 "test@example.com"`
- Less preferred: `agent-browser click "#submit"`

Useful commands:

- `open <url>`: navigate to a page
- `snapshot -i --json`: get interactive elements and refs in machine-readable form
- `click <sel>` / `fill <sel> <text>` / `type <sel> <text>`: primary interaction commands
- `get text <sel>` / `get title` / `get url`: inspect page state
- `wait --load networkidle`, `wait <selector>`, `wait --text "..."`: wait for page readiness
- `screenshot [path]` and `screenshot --annotate`: capture visual state; annotated screenshots map labels to refs
- `find role ...`, `find text ...`, `find label ...`: semantic locators when refs are not available yet
- `tab`, `frame`, `dialog`, `network requests`, `console`, `errors`: useful for debugging complex flows

Safety and reliability:

- Prefer `snapshot -i --json` plus refs as the default workflow.
- When page text may enter model context, use `--content-boundaries`.
- Prefer task-local `--allowed-domains` values instead of broad global allowlists.
- Use `--max-output` when output size might explode.
- Avoid `eval` unless built-in commands, refs, semantic locators, or `get` commands cannot solve the task.
- Use `wait` explicitly after navigation or actions that trigger async updates.

State and isolation:

- Use `--session <name>` for isolated concurrent browser sessions.
- Use `--session-name <name>` to auto-save and restore cookies and localStorage.
- Use `--profile <path>` when full browser state persistence matters.
- Use `--state <path>` to load a previously saved auth state.
- Keep session/profile scope local to the task when possible.

Authentication:

- If the user is already logged in via Chrome, `--auto-connect` plus `state save` can capture reusable auth state.
- Saved state files contain sensitive session data; treat them like secrets.
- Prefer header-based auth or saved state when it avoids fragile login flows.

Other useful patterns:

- `--json` is preferred for agent usage.
- Commands can be chained with `&&` when no intermediate parsing is needed.
- `batch --json` can reduce overhead for multi-step workflows.
- `--headed` is useful for debugging.
- `connect <port>` or `--cdp <port|url>` can attach to an existing Chrome session.

If unsure, start with:

```bash
agent-browser open <url>
agent-browser snapshot -i --json
```

Then choose refs from the snapshot and continue with ref-based interactions.
