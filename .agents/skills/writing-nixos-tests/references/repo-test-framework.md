# Repo NixOS test framework reference

Use this for repo wiring facts. Load other references for driver API semantics or assertion patterns

## Files involved

- **Flake entrypoint:** `tests/default.nix` exposes suites as flake checks
- **Wrapper definition:** `_lib/tests/default.nix` defines `mylib.tests.mk_test`
- **Suite file:** `tests/<suite>/default.nix` calls `mylib.tests.mk_test`
- **Fixture nodes:** `tests/<suite>/*.nix` holds substantial node setup
- **Python package:** `tests/scripts/` builds the `my-nix-tests` package
- **Driver module:** `tests/scripts/src/my_nix_tests/<suite>.py` contains orchestration
- **Import checks:** `tests/scripts/default.nix` registers modules through `pythonImportsCheck`

## `mylib.tests.mk_test` contract

`_lib/tests/default.nix` wraps a test with:

```nix
mylib.tests.mk_test {
  name = "example";
  python_module_name = "example";
  nodes = { ... };
}
```

The wrapper adds the repo Python package to `extraPythonPackages` and generates:

```python
from my_nix_tests.<python_module_name> import run
run(globals())
```

Keep these facts true:

- **Driver function:** the Python file defines `run(driver_globals: dict[str, object]) -> None` or an equivalent signature
- **Module contract:** `python_module_name = "example"` means `from my_nix_tests.example import run`
- **Per-suite module:** each suite needs its own module unless `python_module_name` intentionally reuses one
- **Named nodes:** read named NixOS nodes from `driver_globals`, for example `driver_globals["relay"]`
- **Import registration:** add new Python modules to `tests/scripts/default.nix` `pythonImportsCheck`

## New-suite checklist

- **Suite file:** create `tests/<suite>/default.nix`
- **Fixture files:** add `tests/<suite>/*.nix` when setup is substantial
- **Driver module:** add `tests/scripts/src/my_nix_tests/<suite>.py` defining `run(...)`
- **Import check:** register the Python import in `tests/scripts/default.nix`
- **Deterministic inputs:** materialize generated files or secrets inside the VM and keep them deterministic
- **Syntax check:** run `uv run python -m py_compile tests/scripts/src/my_nix_tests/<suite>.py`
- **Flake visibility:** stage new suite files before flake-backed `nix eval` or `nix build`
- **Targeted build:** run `nix build .#checks.x86_64-linux.<test_name>` for the suite you changed

## Minimal complex-suite template

`tests/example/default.nix`:

```nix
{mylib, ...} @ args:
mylib.tests.mk_test {
  name = "example";
  python_module_name = "example";

  nodes = {
    server = import ./server.nix args;
    client = import ./client.nix args;
  };
}
```

`tests/example/server.nix`:

```nix
_: {pkgs, ...}: let
  example_server = pkgs.writeShellScript "example-server" ''
    exec ${pkgs.python3}/bin/python -u - <<'PY'
    from http.server import BaseHTTPRequestHandler, HTTPServer

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            body = b"expected"
            self.send_response(200)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

    HTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
    PY
  '';
in {
  # Explain non-obvious topology, fixture service, ports, and why this node exists
  system.stateVersion = "25.11";
  networking.firewall.allowedTCPPorts = [8080];

  systemd.services.example-http = {
    wantedBy = ["multi-user.target"];
    serviceConfig.ExecStart = example_server;
  };
}
```

`tests/example/client.nix`:

```nix
_: {pkgs, ...}: {
  system.stateVersion = "25.11";
  environment.systemPackages = [pkgs.curl];
}
```

`tests/scripts/src/my_nix_tests/example.py`:

```python
"""Integration test: one-sentence topology and behavior contract"""

from typing import TYPE_CHECKING, cast

if TYPE_CHECKING:
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

    # 1. Wait for the service that owns the behavior and a client readiness probe
    server.wait_for_unit("example-http.service")
    client.wait_until_succeeds("command -v curl")

    # 2. Assert observable behavior with exact output, token, source, or state evidence
    client.wait_until_succeeds(f"curl --fail --silent http://server:{SERVICE_PORT}/")
    _assert_service_responds(client)
```

## Comment expectations

- **Nix fixtures:** explain non-obvious topology, secrets, addresses, firewall or NAT rules, and fixture-service purpose
- **Python drivers:** explain scenario phases, control paths for negative assertions, and known limitations
- **Placement:** keep comments close to the code that needs them
