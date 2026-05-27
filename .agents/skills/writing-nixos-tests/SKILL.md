---
name: writing-nixos-tests
description: Use when adding, editing, reviewing, or debugging this repo's NixOS VM and integration tests under tests/, including Python drivers, mylib.tests.mk_test wiring, fixture nodes, network assertions, and fail-closed checks
---

Use this for repo NixOS tests in `tests/nixos/`, shared helpers in
`tests/common/`, and wrapper details in `lib/tests/default.nix`. Keep repo
contract details here and load references for API semantics or fuller
templates

## Core principle

A good VM test states the scenario, proves the observable behavior, and shows
why any negative claim is trustworthy

## First moves

- **Read repo contract:** check `tests/nixos/<suite>/default.nix`,
  `tests/nixos/<suite>/*.nix`, `tests/nixos/<suite>/script.py`,
  `tests/common/`, `lib/tests/default.nix`, and `tests/pyproject.toml`
  before editing
- **Verify driver semantics:** load `references/nixos-test-driver-api.md` when
  method behavior matters
- **Keep fixtures deterministic:** use fixed ports, addresses, and keys unless
  randomness is the subject under test
- **Prefer toy services:** small purpose-built fixtures usually prove infra
  behavior more clearly than real apps
- **Remember flake visibility:** new files must be staged before flake-backed
  evaluation or build commands can see them

## New-suite wiring

- **Suite entrypoint:** add `tests/nixos/<suite>/default.nix` with
  `mylib.tests.mk_test`
- **Fixture files:** keep substantial node setup in
  `tests/nixos/<suite>/*.nix`
- **Python driver:** add `tests/nixos/<suite>/script.py` defining `run(...)`
- **Suite package marker:** add `tests/nixos/<suite>/__init__.py` for every
  new driver suite
- **Contract:** `python_module_name = "foo"` imports `run` from
  `nixos.foo.script`
- **Import check:** if you add a driver, update `lib/tests/default.nix`
  `pythonImportsCheck`
- **Shared helpers:** put reusable Nix or Python helpers under `tests/common/`
- **Packaging:** keep Python packaging in `tests/pyproject.toml` with
  `uv_build`
- **Guest tools:** add required tools and packages to node fixtures explicitly
- **More detail:** load `references/repo-test-framework.md` for wrapper facts
  and a copyable template

## Driver shape

- **Recommended order:** constants, low-level helpers, assertion helpers, then
  `run()`
- **Comments:** explain non-obvious topology, control paths for negative
  assertions, and known limitations
- **Keep it lean:** do not add comments that only restate code

## Assertion quality

- **Positive checks:** assert exact evidence such as body, token, source,
  route, unit state, or written file
- **Negative checks:** use a control or preflight when feasible so absence
  means something
- **Known limitations:** name the limitation in a nearby comment and assertion
  message
- **Patterns:** load `references/assertion-patterns.md` before writing
  non-trivial assertions
- **Case study:** load `references/network-vpn-case-study.md` for reusable
  WireGuard lessons, not universal rules

## Validation

Use the narrowest command that proves the current claim first

```bash
uv run --project tests python -m py_compile tests/nixos/<suite>/script.py
nix build .#checks.x86_64-linux.<test_name>
```

Then follow `AGENTS.md` when the task calls for broader checks

## Common mistakes

- **Missing import check:** adding a driver but forgetting
  `lib/tests/default.nix` `pythonImportsCheck`
- **Weak denial proof:** treating `curl` failure alone as proof of a blocked
  path
- **Weak absence proof:** treating an empty log alone as proof that nothing
  arrived
- **Nondeterministic fixtures:** generating keys or ports randomly in a
  reproducible VM test
- **Hidden topology:** leaving important topology only in constants with no
  orientation
- **Unexplained limitation:** treating a known limitation as a normal pass
  with no inline explanation
