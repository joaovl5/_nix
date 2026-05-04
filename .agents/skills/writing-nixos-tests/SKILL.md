---
name: writing-nixos-tests
description: Use when adding, editing, reviewing, or debugging this repo's NixOS VM and integration tests under tests/, including Python drivers, mylib.tests.mk_test wiring, fixture nodes, network assertions, and fail-closed checks
---

Use this for repo NixOS tests in `tests/` and Python drivers in `tests/scripts/src/my_nix_tests/`. Keep repo contract details here and load references for API semantics or fuller templates

## Core principle

A good VM test states the scenario, proves the observable behavior, and shows why any negative claim is trustworthy

## First moves

- **Read repo contract:** check `tests/<suite>/default.nix`, `_lib/tests/default.nix`, `tests/scripts/`, and `tests/scripts/default.nix` before editing
- **Verify driver semantics:** load `references/nixos-test-driver-api.md` when method behavior matters
- **Keep fixtures deterministic:** use fixed ports, addresses, and keys unless randomness is the subject under test
- **Prefer toy services:** small purpose-built fixtures usually prove infra behavior more clearly than real apps
- **Remember flake visibility:** new files must be staged before flake-backed evaluation or build commands can see them

## New-suite wiring

- **Suite entrypoint:** add `tests/<suite>/default.nix` with `mylib.tests.mk_test`
- **Python module:** add `tests/scripts/src/my_nix_tests/<suite>.py` defining `run(...)`; every suite needs a module unless `python_module_name` intentionally reuses one
- **Contract:** `python_module_name = "foo"` imports `run` from `my_nix_tests.foo`
- **Import check:** register new modules in `tests/scripts/default.nix` `pythonImportsCheck`
- **Fixture files:** put substantial node setup in `tests/<suite>/*.nix`
- **Guest tools:** add required tools and packages to node fixtures explicitly
- **More detail:** load `references/repo-test-framework.md` for wrapper facts and a copyable template

## Driver shape

- **Recommended order:** constants, low-level helpers, assertion helpers, then `run()`
- **Comments:** explain non-obvious topology, control paths for negative assertions, and known limitations
- **Keep it lean:** do not add comments that only restate code

## Assertion quality

- **Positive checks:** assert exact evidence such as body, token, source, route, unit state, or written file
- **Negative checks:** use a control or preflight when feasible so absence means something
- **Known limitations:** name the limitation in a nearby comment and assertion message
- **Patterns:** load `references/assertion-patterns.md` before writing non-trivial assertions
- **Case study:** load `references/network-vpn-case-study.md` for reusable WireGuard lessons, not universal rules

## Validation

Use the narrowest command that proves the current claim first

```bash
uv run python -m py_compile tests/scripts/src/my_nix_tests/<suite>.py
nix build .#checks.x86_64-linux.<test_name>
```

Then follow `AGENTS.md` when the task calls for broader checks

## Common mistakes

- **Missing import check:** adding a driver but forgetting `pythonImportsCheck`
- **Weak denial proof:** treating `curl` failure alone as proof of a blocked path
- **Weak absence proof:** treating an empty log alone as proof that nothing arrived
- **Nondeterministic fixtures:** generating keys or ports randomly in a reproducible VM test
- **Hidden topology:** leaving important topology only in constants with no orientation
- **Unexplained limitation:** treating a known limitation as a normal pass with no inline explanation
