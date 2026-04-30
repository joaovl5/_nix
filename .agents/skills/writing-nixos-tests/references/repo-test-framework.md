# Repo NixOS test framework reference

This flake wraps the NixOS VM test framework with a small repo-specific Python package convention.

## Files involved

- `tests/default.nix` exposes test suites as flake checks.
- `_lib/tests/default.nix` defines `mylib.tests.mk_test`.
- `tests/<suite>/default.nix` defines a suite and calls `mylib.tests.mk_test`.
- `tests/<suite>/*.nix` can hold node fixtures for multi-node or large setup.
- `tests/scripts/` builds the `my-nix-tests` Python package.
- `tests/scripts/src/my_nix_tests/<suite>.py` contains Python orchestration.
- `tests/scripts/default.nix` registers import checks through `pythonImportsCheck`.

## `mylib.tests.mk_test` contract

`_lib/tests/default.nix` wraps a test with:

```nix
mylib.tests.mk_test {
  name = "example";
  python_module_name = "example";
  nodes = { ... };
}
```

The wrapper adds the repo Python package to `extraPythonPackages` and generates this test script:

```python
from my_nix_tests.<python_module_name> import run
run(globals())
```

Therefore:

- the Python file must define `run(driver_globals: dict[str, object]) -> None` or equivalent;
- the module name must match `python_module_name`;
- named NixOS nodes are accessed from `driver_globals`, e.g. `driver_globals["relay"]`;
- new Python modules should be added to `tests/scripts/default.nix` `pythonImportsCheck`.

## New-suite checklist

1. Create `tests/<suite>/default.nix`.
2. Add node fixtures under `tests/<suite>/` when setup is substantial.
3. Add `tests/scripts/src/my_nix_tests/<suite>.py` when orchestration belongs in Python.
4. Register the Python import in `tests/scripts/default.nix`.
5. Ensure any generated files/secrets used by node fixtures are deterministic and materialized inside the VM.
6. Run `python -m py_compile tests/scripts/src/my_nix_tests/<suite>.py` for Python syntax.
7. Stage new suite files before any flake-backed `nix eval` or `nix build` so the git flake input sees them.
8. Run `nix build .#checks.x86_64-linux.<test_name>` for the targeted VM test.

## Minimal complex-suite template

`tests/example/default.nix`:

```nix
{mylib, ...}:
mylib.tests.mk_test {
  name = "example";
  python_module_name = "example";

  nodes = {
    server = import ./server.nix;
    client = import ./client.nix;
  };
}
```

`tests/example/server.nix`:

```nix
_: {pkgs, ...}: {
  # Explain non-obvious topology, fixture services, ports, and why this node exists.
  system.stateVersion = "25.11";
  networking.firewall.allowedTCPPorts = [8080];
  environment.systemPackages = [pkgs.curl];
}
```

`tests/scripts/src/my_nix_tests/example.py`:

```python
"""Integration test: one-sentence topology and behavior contract."""

from typing import cast

if False:
    from nix_machine_protocol import Machine

SERVICE_PORT = 8080


def _succeed(machine: "Machine", command: str) -> str:
    return machine.succeed(command).strip()


def _assert_service_responds(client: "Machine") -> None:
    body = _succeed(client, f"curl --fail --silent http://server:{SERVICE_PORT}/")
    assert body == "expected"


def run(driver_globals: dict[str, object]) -> None:
    server = cast("Machine", driver_globals["server"])
    client = cast("Machine", driver_globals["client"])

    # 1. Boot nodes and wait for the service that owns the behavior under test.
    server.wait_for_unit("multi-user.target")
    client.wait_for_unit("multi-user.target")

    # 2. Assert the observable behavior with exact output, token, source, or state evidence.
    _assert_service_responds(client)
```

## Comment expectations

- Nix fixtures should explain non-obvious topology, secrets, addresses, firewall/NAT, and fixture-service purpose.
- Python drivers should explain scenario phases, control paths for negative assertions, and known limitations.
- Keep comments close to the code that needs them. Do not create a separate scenario matrix unless the user explicitly asks.
