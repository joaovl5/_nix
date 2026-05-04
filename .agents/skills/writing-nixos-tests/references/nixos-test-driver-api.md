# NixOS test-driver API reference

Use this when writing Python drivers for this repo's NixOS VM tests. Recheck upstream docs or source when a subtle behavior matters

## Primary sources

- **Manual:** https://nixos.org/manual/nixos/stable/index.html#sec-nixos-tests
- **Tutorial:** https://nix.dev/tutorials/nixos/integration-testing-using-virtual-machines
- **Machine source:** https://github.com/NixOS/nixpkgs/blob/master/nixos/lib/test-driver/src/test_driver/machine/__init__.py

## Key facts from upstream docs and source

- **Named machines:** `testers.runNixOSTest` exposes each named VM node as a Python machine object
- **Async start:** `machine.start()` starts a VM asynchronously and does not wait for boot completion
- **Wait for unit:** `machine.wait_for_unit(unit, timeout=900)` waits for `ActiveState=active`
- **Failure modes:** it raises on failed, inactive, or timed-out units
- **Raw execution:** `machine.execute(command, timeout=900)` returns `(status, stdout)`
- **Shell behavior:** it runs with `set -euo pipefail`
- **Detached commands:** they must close stdout because the driver waits for it
- **Must succeed:** `machine.succeed(command, timeout=None)` raises on non-zero exit and returns stdout
- **Must fail:** `machine.fail(command, timeout=None)` raises on zero exit and returns stdout
- **Retry until success:** `machine.wait_until_succeeds(command, timeout=900)` retries about once per second
- **Success condition:** it stops when the command exits zero
- **Retry until failure:** `machine.wait_until_fails(command, timeout=900)` retries about once per second
- **Failure condition:** it stops when the command exits non-zero
- **Open-port probe:** `machine.wait_for_open_port(port, addr="localhost", timeout=900)` uses `nc -z`
- **Shutdown:** `machine.shutdown()` asks the guest or container to power off and waits for shutdown
- **Network cut simulation:** `machine.block()` and `machine.unblock()` toggle the inter-VM multicast interface
- **Scope:** use them only when that interface is the intended failure mode

## Repo usage guidance

- **Use `execute()` for status checks:** reach for it when the assertion needs the exit code
- **Use `succeed()` deliberately:** use it when command success is itself part of setup or proof
- **Use `fail()` carefully:** for network-denial tests, pair it with listener preflight or log evidence
- **Prefer retries over sleeps:** use `wait_until_succeeds()` instead of arbitrary delays
- **Keep short timeouts explicit:** make the timeout visible when it is part of the behavior under test

## Citation habit

- **Cite subtle behaviors:** cite the upstream URL when you rely on a less-common method or tricky semantic
- **Do not guess:** memory of APIs is not evidence
