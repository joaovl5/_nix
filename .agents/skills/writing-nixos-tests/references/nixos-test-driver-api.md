# NixOS test-driver API reference

Use this reference when writing Python drivers for this repo's NixOS VM tests. Verify details against upstream when behavior matters.

## Primary sources

- NixOS manual, NixOS Tests: https://nixos.org/manual/nixos/stable/index.html#sec-nixos-tests
- nix.dev integration-test tutorial: https://nix.dev/tutorials/nixos/integration-testing-using-virtual-machines
- Nixpkgs test-driver machine source: https://github.com/NixOS/nixpkgs/blob/master/nixos/lib/test-driver/src/test_driver/machine/__init__.py

## Key facts from upstream docs/source

- `testers.runNixOSTest` defines named VM nodes and a Python `testScript`; each named node is available as a Python machine object.
- `machine.start()` starts a VM asynchronously; it does not wait for boot completion.
- `machine.wait_for_unit(unit, timeout=900)` waits for systemd `ActiveState=active` and raises on failed/inactive states or timeout.
- `machine.execute(command, timeout=900)` returns `(status, stdout)`. Commands run with `set -euo pipefail`; it waits for stdout to close, so detached commands must close stdout.
- `machine.succeed(command, timeout=None)` raises if the command exits non-zero and returns stdout.
- `machine.fail(command, timeout=None)` raises if the command exits zero and returns stdout.
- `machine.wait_until_succeeds(command, timeout=900)` retries once per second until the command exits zero.
- `machine.wait_until_fails(command, timeout=900)` retries once per second until the command exits non-zero.
- `machine.wait_for_open_port(port, addr="localhost", timeout=900)` checks TCP listeners with `nc -z`.
- `machine.shutdown()` asks the guest/container to power off and waits for shutdown.
- `machine.block()`/`machine.unblock()` simulate unplugging/restoring the VM's multicast network interface used for inter-VM traffic; use only when that is the intended failure mode.

## Repo usage guidance

- Use `execute()` when the test needs the status code for a custom assertion.
- Use `succeed()` only when command success itself is part of the assertion or setup.
- Use `fail()` only when a failing command is expected and sufficient; for network-denial tests, add listener preflight/log evidence too.
- Prefer `wait_until_succeeds()` over arbitrary sleeps.
- Keep timeouts explicit when a short network timeout is part of the assertion.

## Citation habit

If you rely on a less-common method or subtle behavior, cite the upstream source URL in the plan or comment. Do not guess API semantics from memory.
