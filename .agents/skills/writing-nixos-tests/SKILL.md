---
name: writing-nixos-tests
description: Use when adding, editing, reviewing, or debugging this repository's NixOS VM/integration tests under tests/, including Python test drivers, Nix node fixtures, mylib.tests.mk_test wiring, network assertions, fail-closed checks, and readable test comments.
---

Use this skill for repo-managed NixOS integration tests in `tests/` and Python drivers in `tests/scripts/src/my_nix_tests/`.

## Core principle

A NixOS integration test must tell a future maintainer what scenario it models, what evidence proves the behavior, and why every negative assertion is trustworthy.

## Mandatory quick checklist

Before editing or claiming a NixOS integration test is complete:

1. Read the relevant existing suite and this repo's test framework.
   - Test entrypoints: `tests/<suite>/default.nix`.
   - Python package: `tests/scripts/`.
   - Helper wrapper: `_lib/tests/default.nix`.
   - Import registration: `tests/scripts/default.nix` `pythonImportsCheck`.
2. Verify NixOS test-driver APIs from references when needed. Do not guess method semantics from memory.
3. Keep fixtures deterministic.
   - Use fixed ports, fixed addresses, fixed keys/secrets for tests unless randomness is the behavior under test.
   - Materialize secrets explicitly in VM fixtures.
4. Put a brief topology/intent comment at the top of complex suites.
   - This is not a scenario matrix; it is orientation for node roles, address families, peers, and why the test exists.
5. Organize complex Python drivers in this order:
   - constants and fixture contracts;
   - low-level helpers;
   - assertion helpers;
   - `run()` orchestration.
6. Use narrative comments heavily when behavior is non-obvious.
   - Comment complex Nix fixtures and Python assertions.
   - Prefer section comments in `run()` for scenario phases.
   - Do not comment obvious syntax.
7. Make assertions evidence-based.
   - Positive assertions must prove the expected endpoint, source, body, token, state, or route.
   - Negative assertions need a positive control/preflight when feasible.
   - Log absence alone is weak unless the listener was proven alive first.
8. Document current limitations inline.
   - If a test asserts a known flaw or limitation, add a nearby narrative comment and an explicit assertion message naming the limitation.
9. Prefer test-local toy services for infrastructure behavior.
   - Do not use real consumer applications when a small systemd unit, Python listener, or shell probe proves the infrastructure contract more directly.
10. Validate narrowly first, then follow repo checks.
    - Syntax/import checks for Python drivers.
    - Targeted `nix build .#checks.<system>.<test_name>` for the VM test.
    - Then follow `AGENTS.md`: `nix fmt`, `git add .`, `prek`, and `nix flake check --all-systems` when Nix code changed.

## Repo wiring checklist

When adding a new VM/integration test:

1. Add `tests/<suite>/default.nix` using `mylib.tests.mk_test`.
2. Put node fixtures beside it when the suite has multiple nodes or substantial setup.
3. Add or update `tests/scripts/src/my_nix_tests/<suite>.py` when orchestration is more than a simple inline script.
4. Register the Python module in `tests/scripts/default.nix` `pythonImportsCheck`.
5. Ensure `python_module_name` in `mk_test` matches the module imported by the generated test script.
6. Add packages/tools to node fixtures explicitly; do not rely on host tools.
7. Stage new files before using flake-backed checks, because untracked files are invisible to a git flake input.

## Readability rules

### Comments

Use comments for:

- node roles and topology contracts;
- why a fixture service exists;
- why a route, firewall rule, or secret is present;
- why a negative assertion has a specific control path;
- current limitations intentionally asserted by the test;
- recovery/idempotency behavior that would otherwise look redundant.

Avoid comments that merely restate a line of code.

### Names and sections

- Name constants after their role, not just their value: `PROBE_REMOTE_V4`, not `IP_2`.
- Name toy services after the behavior they prove: `source-observer`, `denied-listener`, `open-vpn-port`.
- Use section banners in long drivers so `run()` reads like a scenario narrative.
- Prefer small helper functions over copy-pasted command strings when the behavior repeats.

### Extraction

Extract repeated Nix fixture declarations into data tables plus small builders when repetition hides the scenario. Keep the table readable; do not over-abstract one-off setup.

## Assertion quality rules

### Positive assertions

A command succeeding is usually not enough. Prefer assertions that also prove one of:

- exact response body;
- exact source address observed by the peer;
- exact token in the expected listener log;
- route output contains and excludes expected interfaces/addresses;
- systemd unit state and output file contents;
- firewall/rule state when idempotency is under test.

### Negative assertions

For blocked paths, use this pattern when feasible:

1. Send a unique control token over an allowed/control path.
2. Assert the listener log contains that token.
3. Clear the listener log.
4. Send a unique blocked token over the blocked path.
5. Assert the blocked command fails or times out.
6. Assert the listener log does not contain the blocked token.

If the expected current limitation is one-way delivery, adjust step 6 explicitly: assert the blocked command fails and the blocked token does appear, with a comment and message naming the limitation.

## Validation commands

Use the narrowest command that proves the current claim before running broader checks.

```bash
python -m py_compile tests/scripts/src/my_nix_tests/<suite>.py
nix build .#checks.x86_64-linux.<test_name>
```

After implementation, run the repo-required checks from `AGENTS.md` in order. If Nix code changed, include `nix flake check --all-systems`.

## External references

Load these when needed:

- `references/nixos-test-driver-api.md` — official and source-verified NixOS test-driver API notes.
- `references/repo-test-framework.md` — this flake's `mylib.tests.mk_test` and Python package wiring.
- `references/assertion-patterns.md` — positive/negative assertion templates and common mistakes.
- `references/network-vpn-case-study.md` — WireGuard-derived networking lessons to reuse as references, not as universal requirements.

## Common mistakes

- Adding a Python driver but forgetting `tests/scripts/default.nix` `pythonImportsCheck`.
- Trusting `curl` success/failure without checking source identity or listener evidence.
- Asserting log absence without proving the listener was alive first.
- Generating keys or ports nondeterministically in a reproducible VM test.
- Leaving topology encoded only in constants with no narrative orientation.
- Adding real applications where toy services would prove the infrastructure more simply.
- Treating a known limitation as a normal pass without an inline explanation.
- Forgetting that untracked files are invisible to flake checks.
