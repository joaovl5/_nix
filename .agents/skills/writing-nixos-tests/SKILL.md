---
name: writing-nixos-tests
description: Use when adding, editing, reviewing, or debugging this repository's NixOS VM/integration tests under tests/, including Python test drivers, Nix node fixtures, mylib.tests.mk_test wiring, network assertions, fail-closed checks, and readable test comments.
---

Use this for repo-managed NixOS integration tests in `tests/` and Python drivers in `tests/scripts/src/my_nix_tests/`. This is repo-specific guidance, not a general NixOS test manual.

## Core principle

A VM test must explain the scenario it models, the evidence that proves behavior, and why negative assertions are trustworthy.

## First moves

Before editing or declaring a test complete:

- Read the relevant existing suite and the repo framework:
  - `tests/<suite>/default.nix`;
  - `_lib/tests/default.nix`;
  - `tests/scripts/`;
  - `tests/scripts/default.nix` `pythonImportsCheck`.
- Verify NixOS test-driver API details from `references/nixos-test-driver-api.md` when behavior matters; do not guess method semantics.
- Use deterministic fixtures: fixed ports, fixed addresses, fixed keys/secrets unless randomness is the behavior under test.
- Prefer test-local toy services over real applications when they prove the infrastructure contract more directly.
- Stage new files before flake-backed checks; untracked files are invisible to git flake inputs.

## New-suite wiring

When adding a VM/integration suite:

- Add `tests/<suite>/default.nix` using `mylib.tests.mk_test`.
- Put substantial node setup beside it as `tests/<suite>/*.nix`.
- Add `tests/scripts/src/my_nix_tests/<suite>.py` defining `run(...)`; every `mk_test` suite needs a Python module unless `python_module_name` intentionally reuses an existing one.
- Register that Python module in `tests/scripts/default.nix` `pythonImportsCheck`.
- Ensure `python_module_name` matches the imported Python module.
- Add tools/packages to VM fixtures explicitly; do not rely on host tools.

See `references/repo-test-framework.md` for the exact wrapper contract and template.

## Driver shape

For complex Python drivers, keep this order:

- constants and fixture contracts;
- low-level helpers;
- assertion helpers;
- `run()` orchestration.

Use brief comments for non-obvious topology, fixture services, control paths for negative assertions, and known limitations. Avoid comments that only restate code.

## Assertion quality

- Positive assertions should prove exact behavior: response body, source address, token, route, unit state, output file, or rule state.
- Negative assertions need a positive control/preflight when feasible. Log absence alone is weak unless the listener was proven alive first.
- If a test asserts a known limitation, add a nearby comment and assertion message naming that limitation.

Load `references/assertion-patterns.md` for templates before writing non-trivial positive/negative assertions. Load `references/network-vpn-case-study.md` for WireGuard-derived lessons, not universal requirements.

## Validation

Use the narrowest command that proves the current claim before broader checks:

```bash
python -m py_compile tests/scripts/src/my_nix_tests/<suite>.py
nix build .#checks.x86_64-linux.<test_name>
```

Then follow repo checks from `AGENTS.md`: `nix fmt`, `git add .`, `prek`, and `nix flake check --all-systems` when Nix code changed.

## Common mistakes

- Adding a Python driver but forgetting `pythonImportsCheck`.
- Trusting `curl` success/failure without source identity or listener evidence.
- Asserting log absence without proving the listener was alive first.
- Generating keys or ports nondeterministically in a reproducible VM test.
- Leaving topology encoded only in constants with no narrative orientation.
- Treating a known limitation as a normal pass without inline explanation.
