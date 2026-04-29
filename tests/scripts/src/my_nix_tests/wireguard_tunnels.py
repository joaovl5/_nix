"""Integration test: WireGuard relay ingress and confinement assertions."""

from __future__ import annotations

import shlex
from typing import TYPE_CHECKING, cast

if TYPE_CHECKING:
    from collections.abc import Callable

    from nix_machine_protocol import Machine


_DEMO_BODY = "isolated-through-wg"
_DEMO_URL = "http://relay:18080/"
_PROBE_OBSERVER_URL = "http://probe:18081/"


def _wait_for_http(
    machine: "Machine", url: str, expected_body: str | None = None
) -> None:
    quoted_url = shlex.quote(url)
    if expected_body is None:
        machine.wait_until_succeeds(
            f"curl --fail --silent --show-error --max-time 3 {quoted_url} >/dev/null"
        )
        return

    expected = shlex.quote(expected_body)
    machine.wait_until_succeeds(
        "body=$(curl --fail --silent --show-error --max-time 3 "
        f'{quoted_url}) && test "$body" = {expected}'
    )


def _assert_command_fails(machine: "Machine", command: str, message: str) -> None:
    status, output = machine.execute(command)
    assert status != 0, (
        f"{message}. Command unexpectedly succeeded: {command}\n{output}"
    )


def _read_file(machine: "Machine", path: str) -> str:
    return machine.succeed(f"cat {shlex.quote(path)}").strip()


def _host_ip(machine: "Machine", hostname: str) -> str:
    return machine.succeed(
        f"getent ahostsv4 {shlex.quote(hostname)} | awk 'NR == 1 {{ print $1; exit }}'"
    ).strip()


def _start_and_capture_source(
    machine: "Machine", service: str, output_path: str
) -> str:
    machine.succeed(f"rm -f {shlex.quote(output_path)}")
    machine.succeed(f"systemctl start {shlex.quote(service)}")
    machine.wait_until_succeeds(f"test -s {shlex.quote(output_path)}")
    return _read_file(machine, output_path)


def run(driver_globals: dict[str, object]) -> None:
    """Run the WireGuard relay ingress and confinement assertions."""
    start_all = driver_globals.get("start_all")
    if callable(start_all):
        cast("Callable[[], None]", start_all)()

    relay = cast("Machine", driver_globals["relay"])
    isolated = cast("Machine", driver_globals["isolated"])
    probe = cast("Machine", driver_globals["probe"])

    for node in (relay, isolated, probe):
        node.wait_for_unit("multi-user.target")

    relay.wait_for_unit("wireguard-wg-host.service")
    isolated.wait_for_unit("wireguard-wg-host.service")
    isolated.wait_for_unit("wg.service")

    _wait_for_http(probe, _PROBE_OBSERVER_URL)
    _wait_for_http(probe, _DEMO_URL, expected_body=_DEMO_BODY)

    _assert_command_fails(
        probe,
        "curl --fail --silent --show-error --max-time 3 http://isolated:18080/",
        "Probe must not reach isolated demo service directly on port 18080",
    )

    relay_body = probe.succeed(
        "curl --fail --silent --show-error --max-time 3 http://relay:18080/"
    ).strip()
    assert relay_body == _DEMO_BODY, (
        "Relay ingress returned unexpected demo body: "
        f"expected {_DEMO_BODY!r}, got {relay_body!r}"
    )

    isolated_ip = _host_ip(probe, "isolated")
    relay_ip = _host_ip(probe, "relay")
    assert isolated_ip, "Failed to resolve isolated IPv4 address from probe"
    assert relay_ip, "Failed to resolve relay IPv4 address from probe"

    plain_source = _start_and_capture_source(
        isolated,
        "plain-demo.service",
        "/run/plain-demo-source-ip",
    )
    confined_source = _start_and_capture_source(
        isolated,
        "confined-demo.service",
        "/run/confined-demo-source-ip",
    )

    assert plain_source == isolated_ip, (
        "Plain demo source IP must be isolated shared-VLAN IP: "
        f"expected {isolated_ip!r}, got {plain_source!r}"
    )
    assert confined_source == relay_ip, (
        "Confined demo source IP must be relay shared-VLAN IP: "
        f"expected {relay_ip!r}, got {confined_source!r}"
    )


if __name__ == "__main__":
    run(globals())
