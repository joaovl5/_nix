"""Integration test: WireGuard relay ingress, confinement, DNS, and fail-closed assertions."""

from __future__ import annotations

import itertools
import shlex
from typing import TYPE_CHECKING, Literal, cast

if TYPE_CHECKING:
    from collections.abc import Callable

    from nix_machine_protocol import Machine

Family = Literal["4", "6"]

LOG_ROOT = "/run/wg-test"
WG_NAMESPACE = "wg"
WG_HOST_UNIT = "wireguard-wg-host.service"
WG_NAMESPACE_UNIT = "wg.service"
WG_INTERFACE = "wg0"
WG_HOST_INTERFACE = "wg-host"

RELAY_SHARED_V4 = "192.0.2.1"
RELAY_SHARED_V6 = "fd00:1::1"
ISOLATED_SHARED_V4 = "192.0.2.2"
ISOLATED_SHARED_V6 = "fd00:1::2"
PROBE_PRIMARY_V4 = "192.0.2.3"
PROBE_PRIMARY_V6 = "fd00:1::3"
PROBE_REMOTE_V4 = "192.0.2.30"
PROBE_REMOTE_V6 = "fd00:1::30"
RELAY_WG_V4 = "11.1.0.1"
RELAY_WG_V6 = "fd11:1::1"
ISOLATED_WG_V4 = "11.1.0.11"
ISOLATED_WG_V6 = "fd11:1::11"
NAMESPACE_WG_V4 = "11.1.0.12"
NAMESPACE_WG_V6 = "fd11:1::12"

SOURCE_OBSERVER_PORT = 18081
RELAY_TCP_PORT = 18080
RELAY_UDP_PORT = 18082
RELAY_BOTH_PORT = 18084
PORTMAP_TCP_PORT = 19080
PORTMAP_UDP_PORT = 19082
PORTMAP_BOTH_PORT = 19084
NAMESPACE_PORTMAP_TCP_PORT = 28080
NAMESPACE_PORTMAP_UDP_PORT = 28082
NAMESPACE_PORTMAP_BOTH_PORT = 28084
HOST_DENIED_TCP_PORT = 19090
HOST_DENIED_UDP_PORT = 19092
NAMESPACE_DENIED_TCP_PORT = 28090
NAMESPACE_DENIED_UDP_PORT = 28092
OPEN_VPN_TCP_PORT = 55080
OPEN_VPN_UDP_PORT = 55082
OPEN_VPN_BOTH_PORT = 55084
OPEN_VPN_DENIED_TCP_PORT = 55090
OPEN_VPN_DENIED_UDP_PORT = 55092
DNS_PORT = 53
DOT_PORT = 853
DOH_PORT = 18443

DEMO_BODY = "isolated-through-wg"
DNS_SUFFIX = ".wg-test.internal"
HTTP_TIMEOUT = 4
NETWORK_TIMEOUT = 4

# Fixture service and log names under the reviewed /run/wg-test token-log contract.
PLAIN_SOURCE_SERVICES = {
    "ipv4": ("plain-demo.service", f"{LOG_ROOT}/plain-demo-source-ip"),
    "ipv6": ("plain-demo-v6.service", f"{LOG_ROOT}/plain-demo-source-ip-v6"),
}
CONFINED_SOURCE_SERVICES = {
    "ipv4": ("confined-demo.service", f"{LOG_ROOT}/confined-demo-source-ip"),
    "ipv6": ("confined-demo-v6.service", f"{LOG_ROOT}/confined-demo-source-ip-v6"),
}
REMOTE_SOURCE_OBSERVERS = {
    "ipv4": (PROBE_REMOTE_V4, "4", f"{LOG_ROOT}/observer-remote-v4.log", "remote-v4"),
    "ipv6": (PROBE_REMOTE_V6, "6", f"{LOG_ROOT}/observer-remote-v6.log", "remote-v6"),
}

TOY_LISTENER_UNITS = [
    "wg-demo.service",
    "wg-demo-v6.service",
    "relay-forward-tcp-opposite-v4.service",
    "relay-forward-tcp-opposite-v6.service",
    "relay-forward-udp-v4.service",
    "relay-forward-udp-v6.service",
    "relay-forward-udp-opposite-v4.service",
    "relay-forward-udp-opposite-v6.service",
    "relay-forward-both-tcp-v4.service",
    "relay-forward-both-tcp-v6.service",
    "relay-forward-both-udp-v4.service",
    "relay-forward-both-udp-v6.service",
    "ns-port-map-tcp-v4.service",
    "ns-port-map-tcp-opposite-v4.service",
    "ns-port-map-tcp-v6.service",
    "ns-port-map-udp-v4.service",
    "ns-port-map-udp-opposite-v4.service",
    "ns-port-map-udp-v6.service",
    "ns-port-map-both-tcp-v4.service",
    "ns-port-map-both-tcp-v6.service",
    "ns-port-map-both-udp-v4.service",
    "ns-port-map-both-udp-v6.service",
    "ns-unmapped-denied-tcp-v4.service",
    "ns-unmapped-denied-tcp-v6.service",
    "ns-unmapped-denied-udp-v4.service",
    "ns-unmapped-denied-udp-v6.service",
    "ns-open-vpn-tcp-v4.service",
    "ns-open-vpn-tcp-v6.service",
    "ns-open-vpn-udp-v4.service",
    "ns-open-vpn-udp-v6.service",
    "ns-open-vpn-both-tcp-v4.service",
    "ns-open-vpn-both-tcp-v6.service",
    "ns-open-vpn-both-udp-v4.service",
    "ns-open-vpn-both-udp-v6.service",
    "ns-open-vpn-denied-tcp-v4.service",
    "ns-open-vpn-denied-tcp-v6.service",
    "ns-open-vpn-denied-udp-v4.service",
    "ns-open-vpn-denied-udp-v6.service",
]

_TOKEN_COUNTER = itertools.count(1)


def _q(value: str) -> str:
    return shlex.quote(value)


def _require_callable(obj: object, name: str) -> Callable[..., object]:
    method = getattr(obj, name, None)
    assert callable(method), f"Machine is missing required method {name}()"
    return cast("Callable[..., object]", method)


def _start_machine(machine: "Machine") -> None:
    _require_callable(machine, "start")()


def _shutdown_machine(machine: "Machine") -> None:
    _require_callable(machine, "shutdown")()


def _wait_until_succeeds(machine: "Machine", command: str, message: str) -> None:
    try:
        machine.wait_until_succeeds(command)
    except Exception as exc:  # pragma: no cover - integration-driver surface
        raise AssertionError(f"{message}: {command}") from exc


def _succeed(machine: "Machine", command: str, message: str) -> str:
    try:
        return machine.succeed(command).strip()
    except Exception as exc:  # pragma: no cover - integration-driver surface
        raise AssertionError(f"{message}: {command}") from exc


def _fail(machine: "Machine", command: str, message: str) -> str:
    status, output = machine.execute(command)
    assert status != 0, (
        f"{message}. Command unexpectedly succeeded: {command}\n{output}"
    )
    return output.strip()


def _command_prefix(namespace: str | None = None) -> str:
    if namespace is None:
        return ""
    return f"ip netns exec {_q(namespace)} "


def _family_flag(family: Family) -> str:
    return "--ipv4" if family == "4" else "--ipv6"


def _socket_family(family: Family) -> str:
    return "AF_INET" if family == "4" else "AF_INET6"


def _literal_url(address: str, port: int, path: str = "/") -> str:
    host = f"[{address}]" if ":" in address else address
    return f"http://{host}:{port}{path}"


def _token(prefix: str) -> str:
    return f"{prefix}-{next(_TOKEN_COUNTER):04d}"


def _log_path(name: str) -> str:
    return f"{LOG_ROOT}/{name}.log"


def _clear_log(machine: "Machine", path: str) -> None:
    _succeed(machine, f": > {_q(path)}", f"Failed to clear log {path}")


def _log_has_token(machine: "Machine", path: str, token: str) -> bool:
    status, _ = machine.execute(f"grep -F {_q(token)} {_q(path)} >/dev/null")
    return status == 0


def _assert_log_has_token(
    machine: "Machine", path: str, token: str, message: str
) -> None:
    assert _log_has_token(machine, path, token), (
        f"{message}: token {token!r} missing from {path}"
    )


def _assert_log_lacks_token(
    machine: "Machine", path: str, token: str, message: str
) -> None:
    assert not _log_has_token(machine, path, token), (
        f"{message}: token {token!r} unexpectedly present in {path}"
    )


def _assert_log_has_entry(
    machine: "Machine", path: str, token: str, source: str, message: str
) -> None:
    entry = f"{token} {source}"
    status, _ = machine.execute(f"grep -Fx {_q(entry)} {_q(path)} >/dev/null")
    assert status == 0, f"{message}: entry {entry!r} missing from {path}"


def _http_get(
    machine: "Machine",
    address: str,
    port: int,
    *,
    family: Family,
    namespace: str | None = None,
    path: str = "/",
) -> str:
    url = _literal_url(address, port, path)
    return _succeed(
        machine,
        f"{_command_prefix(namespace)}curl --fail --silent --show-error {_family_flag(family)} --max-time {HTTP_TIMEOUT} {_q(url)}",
        f"HTTP GET failed for {url} on IPv{family}",
    )


def _assert_http_body(
    machine: "Machine",
    address: str,
    port: int,
    *,
    family: Family,
    expected_body: str,
    namespace: str | None = None,
    path: str = "/",
    message: str,
) -> None:
    body = _http_get(
        machine, address, port, family=family, namespace=namespace, path=path
    )
    assert body == expected_body, f"{message}: expected {expected_body!r}, got {body!r}"


def _assert_http_fails(
    machine: "Machine",
    address: str,
    port: int,
    *,
    family: Family,
    namespace: str | None = None,
    path: str = "/",
    message: str,
) -> None:
    url = _literal_url(address, port, path)
    _fail(
        machine,
        f"{_command_prefix(namespace)}curl --fail --silent --show-error {_family_flag(family)} --max-time {HTTP_TIMEOUT} {_q(url)}",
        message,
    )


def _python_network_command(
    *,
    protocol: Literal["tcp", "udp"],
    family: Family,
    address: str,
    port: int,
    token: str,
    expect_reply: bool,
) -> str:
    socket_type = "SOCK_STREAM" if protocol == "tcp" else "SOCK_DGRAM"
    script_lines = [
        "import socket, sys",
        f"protocol = {protocol!r}",
        f"family = socket.{_socket_family(family)}",
        f"sock_type = socket.{socket_type}",
        "sock = socket.socket(family, sock_type)",
        f"sock.settimeout({NETWORK_TIMEOUT})",
        f"address = {address!r}",
        f"port = {port}",
        f"payload = {(token + chr(10))!r}.encode('utf-8')",
        "try:",
        "    if protocol == 'tcp':",
        "        sock.connect((address, port))",
        "        sock.sendall(payload)",
        "    else:",
        "        sock.sendto(payload, (address, port))",
    ]
    if expect_reply:
        script_lines.extend(
            [
                "    data = sock.recv(4096) if protocol == 'tcp' else sock.recvfrom(4096)[0]",
                "    sys.stdout.write(data.decode('utf-8'))",
            ]
        )
    else:
        script_lines.append("    pass")
    script_lines.extend(
        [
            "finally:",
            "    sock.close()",
        ]
    )
    script = "\n".join(script_lines) + "\n"
    return f"python3 -c {_q(script)}"


def _tcp_roundtrip(
    machine: "Machine",
    address: str,
    port: int,
    token: str,
    *,
    family: Family,
    namespace: str | None = None,
    expect_reply: bool = True,
) -> str:
    return _succeed(
        machine,
        _command_prefix(namespace)
        + _python_network_command(
            protocol="tcp",
            family=family,
            address=address,
            port=port,
            token=token,
            expect_reply=expect_reply,
        ),
        f"TCP exchange failed for {address}:{port} on IPv{family}",
    )


def _udp_roundtrip(
    machine: "Machine",
    address: str,
    port: int,
    token: str,
    *,
    family: Family,
    namespace: str | None = None,
    expect_reply: bool = True,
) -> str:
    return _succeed(
        machine,
        _command_prefix(namespace)
        + _python_network_command(
            protocol="udp",
            family=family,
            address=address,
            port=port,
            token=token,
            expect_reply=expect_reply,
        ),
        f"UDP exchange failed for {address}:{port} on IPv{family}",
    )


def _run_service_capture(machine: "Machine", service: str, output_path: str) -> str:
    _succeed(
        machine,
        f"rm -f {_q(output_path)}",
        f"Failed to remove stale output {output_path}",
    )
    _succeed(machine, f"systemctl start {_q(service)}", f"Failed to start {service}")
    _wait_until_succeeds(
        machine, f"test -s {_q(output_path)}", f"Timed out waiting for {output_path}"
    )
    return _succeed(machine, f"cat {_q(output_path)}", f"Failed to read {output_path}")


def _assert_confined_source_observer_fail_closed(
    probe: "Machine",
    isolated: "Machine",
    *,
    label: str,
    service: str,
    output_path: str,
    observer_address: str,
    observer_family: Family,
    observer_log_path: str,
    observer_token: str,
    message: str,
    outage: str,
    output_failure: str,
    observer_failure: str,
) -> None:
    _wait_until_succeeds(
        probe,
        f"curl --fail --silent --show-error {_family_flag(observer_family)} --max-time {HTTP_TIMEOUT} {_q(_literal_url(observer_address, SOURCE_OBSERVER_PORT, f'/_preflight?token={observer_token}-preflight'))} >/dev/null",
        f"Remote source observer {label} did not become ready before {outage}",
    )
    _clear_log(probe, observer_log_path)
    _succeed(isolated, f"rm -f {_q(output_path)}", f"Failed to clear {output_path}")
    _fail(isolated, f"systemctl start {_q(service)}", message)
    status, _ = isolated.execute(f"test -s {_q(output_path)}")
    assert status != 0, output_failure
    _assert_log_lacks_token(probe, observer_log_path, observer_token, observer_failure)


def _assert_denied_listener_preflight(
    *,
    machine: "Machine",
    log_path: str,
    control_command: str,
    blocked_command: str,
    control_token: str,
    blocked_token: str,
    message: str,
    blocked_machine: "Machine" | None = None,
) -> None:
    blocked_on = machine if blocked_machine is None else blocked_machine
    _clear_log(machine, log_path)
    _succeed(machine, control_command, f"{message}: control preflight failed")
    _assert_log_has_token(
        machine, log_path, control_token, f"{message}: control token missing"
    )
    _clear_log(machine, log_path)
    _fail(blocked_on, blocked_command, f"{message}: blocked command must fail")
    _assert_log_lacks_token(
        machine, log_path, blocked_token, f"{message}: blocked token leaked"
    )


def _assert_one_way_udp_listener_limitation(
    *,
    machine: "Machine",
    log_path: str,
    control_command: str,
    blocked_command: str,
    control_token: str,
    blocked_token: str,
    message: str,
    blocked_machine: "Machine" | None = None,
) -> None:
    blocked_on = machine if blocked_machine is None else blocked_machine
    _clear_log(machine, log_path)
    _succeed(machine, control_command, f"{message}: control preflight failed")
    _assert_log_has_token(
        machine, log_path, control_token, f"{message}: control token missing"
    )
    _clear_log(machine, log_path)
    _fail(
        blocked_on,
        blocked_command,
        f"{message}: blocked UDP command must fail despite one-way delivery",
    )
    _assert_log_has_token(
        machine,
        log_path,
        blocked_token,
        f"{message}: blocked UDP token missing despite expected one-way delivery",
    )


def _dig_query(machine: "Machine", server: str, token: str, *, family: Family) -> str:
    query_name = f"{token}{DNS_SUFFIX}"
    dig_family = "-4" if family == "4" else "-6"
    qtype = "A" if family == "4" else "AAAA"
    return _succeed(
        machine,
        f"{_command_prefix(WG_NAMESPACE)}dig +short +time=2 +tries=1 {dig_family} @{_q(server)} {_q(query_name)} {qtype}",
        f"Confined dig failed against {server}",
    )


def _assert_route(
    machine: "Machine",
    address: str,
    *,
    family: Family,
    expected_present: list[str],
    expected_absent: list[str],
    message: str,
) -> None:
    command = (
        f"{_command_prefix(WG_NAMESPACE)}ip -6 route get {_q(address)}"
        if family == "6"
        else f"{_command_prefix(WG_NAMESPACE)}ip route get {_q(address)}"
    )
    route = _succeed(machine, command, f"Failed to inspect route for {address}")
    for needle in expected_present:
        assert needle in route, (
            f"{message}: expected {needle!r} in route output {route!r}"
        )
    for needle in expected_absent:
        assert needle not in route, (
            f"{message}: unexpected {needle!r} in route output {route!r}"
        )


def _assert_service_inactive(machine: "Machine", service: str, message: str) -> None:
    output = _succeed(
        machine,
        f"systemctl show {_q(service)} --property=ActiveState,SubState,Result --value --no-pager",
        f"Failed to inspect {service}",
    )
    states = [line.strip() for line in output.splitlines() if line.strip()]
    assert states and states[0] != "active", (
        f"{message}: {service} is unexpectedly active ({states})"
    )


def _wait_for_wg_recovery(
    relay: "Machine", isolated: "Machine", probe: "Machine"
) -> None:
    relay.wait_for_unit(WG_HOST_UNIT)
    isolated.wait_for_unit(WG_HOST_UNIT)
    isolated.wait_for_unit(WG_NAMESPACE_UNIT)
    _wait_until_succeeds(
        relay,
        f"wg show {_q(WG_HOST_INTERFACE)} peers | grep -q .",
        "Relay WireGuard host interface never gained a peer",
    )
    _wait_until_succeeds(
        isolated,
        f"wg show {_q(WG_HOST_INTERFACE)} peers | grep -q .",
        "Isolated WireGuard host interface never gained a peer",
    )
    _wait_until_succeeds(
        isolated,
        f"{_command_prefix(WG_NAMESPACE)}wg show | grep -q '^peer: '",
        "WireGuard namespace never gained a peer",
    )
    for service in TOY_LISTENER_UNITS:
        _succeed(
            isolated,
            f"systemctl restart {_q(service)}",
            f"Failed to restart recovered toy listener {service}",
        )
        isolated.wait_for_unit(service)
    _wait_until_succeeds(
        probe,
        f"curl --fail --silent --show-error --ipv4 --max-time {HTTP_TIMEOUT} {_q(_literal_url(RELAY_SHARED_V4, RELAY_TCP_PORT))} >/dev/null",
        "Relay TCP ingress did not become functionally ready over IPv4",
    )
    _wait_until_succeeds(
        isolated,
        f"{_command_prefix(WG_NAMESPACE)}dig +short +time=2 +tries=1 -4 @{_q(PROBE_PRIMARY_V4)} ready{DNS_SUFFIX} >/dev/null",
        "Confined DNS did not become functionally ready over IPv4",
    )


def _assert_no_duplicate_state(
    machine: "Machine", namespace: str | None = WG_NAMESPACE
) -> None:
    if namespace is not None:
        _succeed(
            machine,
            f'test "$(ip netns list | awk \'$1 == "{namespace}" {{ count++ }} END {{ print count + 0 }}\')" -le 1',
            "Duplicate WireGuard namespace entries detected",
        )
    duplicate_ports = (
        f"{RELAY_TCP_PORT}|{RELAY_UDP_PORT}|{RELAY_BOTH_PORT}|{PORTMAP_TCP_PORT}|{PORTMAP_UDP_PORT}|"
        f"{PORTMAP_BOTH_PORT}|{NAMESPACE_PORTMAP_TCP_PORT}|{NAMESPACE_PORTMAP_UDP_PORT}|"
        f"{NAMESPACE_PORTMAP_BOTH_PORT}|{OPEN_VPN_TCP_PORT}|{OPEN_VPN_UDP_PORT}|{OPEN_VPN_BOTH_PORT}|"
        f"{HOST_DENIED_TCP_PORT}|{HOST_DENIED_UDP_PORT}|{OPEN_VPN_DENIED_TCP_PORT}|{OPEN_VPN_DENIED_UDP_PORT}|"
        f"{DNS_PORT}|{DOT_PORT}|{DOH_PORT}"
    )
    _succeed(
        machine,
        "python3 - <<'PY'\n"
        "import subprocess, sys\n"
        f"pattern = r'{duplicate_ports}'\n"
        f"namespace = {namespace!r}\n"
        "commands = ['iptables-save', 'ip6tables-save']\n"
        "has_namespace = False\n"
        "if namespace:\n"
        "    netns_output = subprocess.check_output('ip netns list', shell=True, text=True)\n"
        "    has_namespace = any(line.split() and line.split()[0] == namespace for line in netns_output.splitlines())\n"
        "if has_namespace:\n"
        "    commands.extend([\n"
        "        f'ip netns exec {namespace} iptables-save',\n"
        "        f'ip netns exec {namespace} ip6tables-save',\n"
        "    ])\n"
        "for command in commands:\n"
        "    text = subprocess.check_output(command, shell=True, text=True)\n"
        "    seen = set()\n"
        "    for line in text.splitlines():\n"
        "        if not __import__('re').search(pattern, line):\n"
        "            continue\n"
        "        if line in seen:\n"
        "            sys.stderr.write(f'duplicate firewall line: {line}\\n')\n"
        "            raise SystemExit(1)\n"
        "        seen.add(line)\n"
        "PY",
        "Duplicate firewall rules detected for WireGuard fixture ports",
    )


def _assert_startup_fail_closed(probe: "Machine", isolated: "Machine") -> None:
    isolated.wait_for_unit(WG_HOST_UNIT)
    _assert_service_inactive(
        isolated,
        WG_NAMESPACE_UNIT,
        "wg.service must fail closed while relay is initially unavailable",
    )
    plain_v4_service, plain_v4_output = PLAIN_SOURCE_SERVICES["ipv4"]
    plain_v6_service, plain_v6_output = PLAIN_SOURCE_SERVICES["ipv6"]
    assert (
        _run_service_capture(isolated, plain_v4_service, plain_v4_output)
        == ISOLATED_SHARED_V4
    ), (
        "Plain IPv4 source observer must keep using isolated shared-VLAN source while relay is down"
    )
    assert (
        _run_service_capture(isolated, plain_v6_service, plain_v6_output)
        == ISOLATED_SHARED_V6
    ), (
        "Plain IPv6 source observer must keep using isolated shared-VLAN source while relay is down"
    )
    for label, (service, output_path) in CONFINED_SOURCE_SERVICES.items():
        observer_address, observer_family, observer_log_path, observer_token = (
            REMOTE_SOURCE_OBSERVERS[label]
        )
        _assert_confined_source_observer_fail_closed(
            probe,
            isolated,
            label=label,
            service=service,
            output_path=output_path,
            observer_address=observer_address,
            observer_family=cast(Family, observer_family),
            observer_log_path=observer_log_path,
            observer_token=observer_token,
            message=f"Confined source observer {label} must not emit traffic while relay is down",
            outage="startup fail-closed check",
            output_failure=(
                f"Confined source observer {label} unexpectedly wrote {output_path} while relay was down"
            ),
            observer_failure=(
                f"Confined source observer {label} unexpectedly reached probe observer {observer_token} while relay was down"
            ),
        )
    _assert_no_duplicate_state(isolated)


def _assert_relay_baseline(probe: "Machine", isolated: "Machine") -> None:
    tcp_v4 = _token("relay-tcp4")
    tcp_v6 = _token("relay-tcp6")
    _assert_http_body(
        probe,
        RELAY_SHARED_V4,
        RELAY_TCP_PORT,
        family="4",
        expected_body=DEMO_BODY,
        path=f"/?token={tcp_v4}",
        message="Relay TCP ingress over IPv4 returned unexpected demo body",
    )
    _assert_http_body(
        probe,
        RELAY_SHARED_V6,
        RELAY_TCP_PORT,
        family="6",
        expected_body=DEMO_BODY,
        path=f"/?token={tcp_v6}",
        message="Relay TCP ingress over IPv6 returned unexpected demo body",
    )
    _assert_log_has_entry(
        isolated,
        _log_path("relay-forward-tcp-v4"),
        tcp_v4,
        RELAY_WG_V4,
        "Relay TCP IPv4 listener log missing WireGuard source",
    )
    _assert_log_has_entry(
        isolated,
        _log_path("relay-forward-tcp-v6"),
        tcp_v6,
        RELAY_WG_V6,
        "Relay TCP IPv6 listener log missing WireGuard source",
    )
    _assert_http_fails(
        probe,
        ISOLATED_WG_V4,
        RELAY_TCP_PORT,
        family="4",
        message="Probe must not reach isolated WireGuard host IPv4 directly on TCP relay port",
    )
    _assert_http_fails(
        probe,
        ISOLATED_WG_V6,
        RELAY_TCP_PORT,
        family="6",
        message="Probe must not reach isolated WireGuard host IPv6 directly on TCP relay port",
    )


def _assert_relay_ingress(probe: "Machine", isolated: "Machine") -> None:
    udp_v4 = _token("relay-udp4")
    udp_v6 = _token("relay-udp6")
    both_tcp_v4 = _token("relay-both-tcp4")
    both_tcp_v6 = _token("relay-both-tcp6")
    both_udp_v4 = _token("relay-both-udp4")
    both_udp_v6 = _token("relay-both-udp6")

    assert udp_v4 in _udp_roundtrip(
        probe, RELAY_SHARED_V4, RELAY_UDP_PORT, udp_v4, family="4"
    ), "Relay UDP ingress over IPv4 did not echo the expected token"
    assert udp_v6 in _udp_roundtrip(
        probe, RELAY_SHARED_V6, RELAY_UDP_PORT, udp_v6, family="6"
    ), "Relay UDP ingress over IPv6 did not echo the expected token"
    assert both_tcp_v4 in _tcp_roundtrip(
        probe, RELAY_SHARED_V4, RELAY_BOTH_PORT, both_tcp_v4, family="4"
    ), "Relay dual-protocol TCP ingress over IPv4 did not echo the expected token"
    assert both_tcp_v6 in _tcp_roundtrip(
        probe, RELAY_SHARED_V6, RELAY_BOTH_PORT, both_tcp_v6, family="6"
    ), "Relay dual-protocol TCP ingress over IPv6 did not echo the expected token"
    assert both_udp_v4 in _udp_roundtrip(
        probe, RELAY_SHARED_V4, RELAY_BOTH_PORT, both_udp_v4, family="4"
    ), "Relay dual-protocol UDP ingress over IPv4 did not echo the expected token"
    assert both_udp_v6 in _udp_roundtrip(
        probe, RELAY_SHARED_V6, RELAY_BOTH_PORT, both_udp_v6, family="6"
    ), "Relay dual-protocol UDP ingress over IPv6 did not echo the expected token"
    _assert_log_has_entry(
        isolated,
        _log_path("relay-forward-udp-v4"),
        udp_v4,
        RELAY_WG_V4,
        "Relay UDP IPv4 listener log missing WireGuard source",
    )
    _assert_log_has_entry(
        isolated,
        _log_path("relay-forward-udp-v6"),
        udp_v6,
        RELAY_WG_V6,
        "Relay UDP IPv6 listener log missing WireGuard source",
    )
    _assert_log_has_entry(
        isolated,
        _log_path("relay-forward-both-tcp-v4"),
        both_tcp_v4,
        RELAY_WG_V4,
        "Relay dual-protocol TCP IPv4 listener log missing WireGuard source",
    )
    _assert_log_has_entry(
        isolated,
        _log_path("relay-forward-both-tcp-v6"),
        both_tcp_v6,
        RELAY_WG_V6,
        "Relay dual-protocol TCP IPv6 listener log missing WireGuard source",
    )
    _assert_log_has_entry(
        isolated,
        _log_path("relay-forward-both-udp-v4"),
        both_udp_v4,
        RELAY_WG_V4,
        "Relay dual-protocol UDP IPv4 listener log missing WireGuard source",
    )
    _assert_log_has_entry(
        isolated,
        _log_path("relay-forward-both-udp-v6"),
        both_udp_v6,
        RELAY_WG_V6,
        "Relay dual-protocol UDP IPv6 listener log missing WireGuard source",
    )

    relay_tcp_udp_log = _log_path("relay-forward-tcp-opposite-v4")
    relay_udp_tcp_log = _log_path("relay-forward-udp-opposite-v4")
    relay_tcp_udp_control = _token("relay-denied-udp-control")
    relay_tcp_udp_blocked = _token("relay-denied-udp-blocked")
    relay_udp_tcp_control = _token("relay-denied-tcp-control")
    relay_udp_tcp_blocked = _token("relay-denied-tcp-blocked")

    _assert_denied_listener_preflight(
        machine=isolated,
        log_path=relay_tcp_udp_log,
        control_command=_command_prefix(None)
        + _python_network_command(
            protocol="udp",
            family="4",
            address=ISOLATED_WG_V4,
            port=RELAY_TCP_PORT,
            token=relay_tcp_udp_control,
            expect_reply=True,
        ),
        blocked_command=_command_prefix(None)
        + _python_network_command(
            protocol="udp",
            family="4",
            address=RELAY_SHARED_V4,
            port=RELAY_TCP_PORT,
            token=relay_tcp_udp_blocked,
            expect_reply=True,
        ),
        control_token=relay_tcp_udp_control,
        blocked_token=relay_tcp_udp_blocked,
        message="UDP packets must not traverse the TCP-only relay forward",
    )
    _assert_denied_listener_preflight(
        machine=isolated,
        log_path=relay_udp_tcp_log,
        control_command=_command_prefix(None)
        + _python_network_command(
            protocol="tcp",
            family="4",
            address=ISOLATED_WG_V4,
            port=RELAY_UDP_PORT,
            token=relay_udp_tcp_control,
            expect_reply=True,
        ),
        blocked_command=_command_prefix(None)
        + _python_network_command(
            protocol="tcp",
            family="4",
            address=RELAY_SHARED_V4,
            port=RELAY_UDP_PORT,
            token=relay_udp_tcp_blocked,
            expect_reply=True,
        ),
        control_token=relay_udp_tcp_control,
        blocked_token=relay_udp_tcp_blocked,
        message="TCP connections must not traverse the UDP-only relay forward",
    )
    _assert_denied_listener_preflight(
        machine=isolated,
        log_path=_log_path("relay-forward-tcp-opposite-v6"),
        control_command=_command_prefix(None)
        + _python_network_command(
            protocol="udp",
            family="6",
            address=ISOLATED_WG_V6,
            port=RELAY_TCP_PORT,
            token="relay-denied-udp-v6-control",
            expect_reply=True,
        ),
        blocked_command=_command_prefix(None)
        + _python_network_command(
            protocol="udp",
            family="6",
            address=RELAY_SHARED_V6,
            port=RELAY_TCP_PORT,
            token="relay-denied-udp-v6-blocked",
            expect_reply=True,
        ),
        control_token="relay-denied-udp-v6-control",
        blocked_token="relay-denied-udp-v6-blocked",
        message="IPv6 UDP packets must not traverse the TCP-only relay forward",
    )
    _assert_denied_listener_preflight(
        machine=isolated,
        log_path=_log_path("relay-forward-udp-opposite-v6"),
        control_command=_command_prefix(None)
        + _python_network_command(
            protocol="tcp",
            family="6",
            address=ISOLATED_WG_V6,
            port=RELAY_UDP_PORT,
            token="relay-denied-tcp-v6-control",
            expect_reply=True,
        ),
        blocked_command=_command_prefix(None)
        + _python_network_command(
            protocol="tcp",
            family="6",
            address=RELAY_SHARED_V6,
            port=RELAY_UDP_PORT,
            token="relay-denied-tcp-v6-blocked",
            expect_reply=True,
        ),
        control_token="relay-denied-tcp-v6-control",
        blocked_token="relay-denied-tcp-v6-blocked",
        message="IPv6 TCP connections must not traverse the UDP-only relay forward",
    )


def _assert_route_separation(isolated: "Machine") -> None:
    _assert_route(
        isolated,
        PROBE_PRIMARY_V4,
        family="4",
        expected_present=[PROBE_PRIMARY_V4],
        expected_absent=[WG_INTERFACE, RELAY_WG_V4, NAMESPACE_WG_V4],
        message="Probe primary IPv4 must stay on the local bridge route from the namespace",
    )
    _assert_route(
        isolated,
        PROBE_PRIMARY_V6,
        family="6",
        expected_present=[PROBE_PRIMARY_V6],
        expected_absent=[WG_INTERFACE, RELAY_WG_V6, NAMESPACE_WG_V6],
        message="Probe primary IPv6 must stay on the local bridge route from the namespace",
    )
    _assert_route(
        isolated,
        PROBE_REMOTE_V4,
        family="4",
        expected_present=[WG_INTERFACE, NAMESPACE_WG_V4],
        expected_absent=[],
        message="Probe remote IPv4 alias must route through the WireGuard/default path from the namespace",
    )
    _assert_route(
        isolated,
        PROBE_REMOTE_V6,
        family="6",
        expected_present=[WG_INTERFACE, NAMESPACE_WG_V6],
        expected_absent=[],
        message="Probe remote IPv6 alias must route through the WireGuard/default path from the namespace",
    )


def _assert_source_observers(isolated: "Machine") -> None:
    plain_v4_service, plain_v4_output = PLAIN_SOURCE_SERVICES["ipv4"]
    plain_v6_service, plain_v6_output = PLAIN_SOURCE_SERVICES["ipv6"]
    confined_v4_service, confined_v4_output = CONFINED_SOURCE_SERVICES["ipv4"]
    confined_v6_service, confined_v6_output = CONFINED_SOURCE_SERVICES["ipv6"]

    assert (
        _run_service_capture(isolated, plain_v4_service, plain_v4_output)
        == ISOLATED_SHARED_V4
    ), "Plain IPv4 source observer must see the isolated shared-VLAN source"
    assert (
        _run_service_capture(isolated, plain_v6_service, plain_v6_output)
        == ISOLATED_SHARED_V6
    ), "Plain IPv6 source observer must see the isolated shared-VLAN source"
    assert (
        _run_service_capture(isolated, confined_v4_service, confined_v4_output)
        == RELAY_SHARED_V4
    ), "Confined IPv4 source observer must see the relay shared-VLAN source"
    assert (
        _run_service_capture(isolated, confined_v6_service, confined_v6_output)
        == RELAY_SHARED_V6
    ), "Confined IPv6 source observer must see the relay shared-VLAN source"


def _assert_port_mappings(probe: "Machine", isolated: "Machine") -> None:
    tcp4 = _token("portmap-tcp4")
    tcp6 = _token("portmap-tcp6")
    udp4 = _token("portmap-udp4")
    udp6 = _token("portmap-udp6")
    both_tcp4 = _token("portmap-both-tcp4")
    both_tcp6 = _token("portmap-both-tcp6")
    both_udp4 = _token("portmap-both-udp4")
    both_udp6 = _token("portmap-both-udp6")

    assert tcp4 in _tcp_roundtrip(
        probe, ISOLATED_SHARED_V4, PORTMAP_TCP_PORT, tcp4, family="4"
    ), "Namespace TCP port mapping over IPv4 did not echo the expected token"
    _assert_log_has_entry(
        isolated,
        _log_path("namespace-port-map-tcp-v4"),
        tcp4,
        PROBE_PRIMARY_V4,
        "Namespace TCP IPv4 port-mapping listener log missing probe source",
    )
    _assert_denied_listener_preflight(
        machine=isolated,
        log_path=_log_path("namespace-port-map-tcp-v6"),
        control_command=_command_prefix(WG_NAMESPACE)
        + _python_network_command(
            protocol="tcp",
            family="6",
            address=NAMESPACE_WG_V6,
            port=NAMESPACE_PORTMAP_TCP_PORT,
            token=f"{tcp6}-control",
            expect_reply=True,
        ),
        blocked_command=_python_network_command(
            protocol="tcp",
            family="6",
            address=ISOLATED_SHARED_V6,
            port=PORTMAP_TCP_PORT,
            token=tcp6,
            expect_reply=True,
        ),
        control_token=f"{tcp6}-control",
        blocked_token=tcp6,
        message="IPv6 host-to-namespace TCP port mapping is a documented current VPN-Confinement bridge limitation",
        blocked_machine=probe,
    )
    assert udp4 in _udp_roundtrip(
        probe, ISOLATED_SHARED_V4, PORTMAP_UDP_PORT, udp4, family="4"
    ), "Namespace UDP port mapping over IPv4 did not echo the expected token"
    _assert_log_has_entry(
        isolated,
        _log_path("namespace-port-map-udp-v4"),
        udp4,
        PROBE_PRIMARY_V4,
        "Namespace UDP IPv4 port-mapping listener log missing probe source",
    )
    _assert_one_way_udp_listener_limitation(
        machine=isolated,
        log_path=_log_path("namespace-port-map-udp-v6"),
        control_command=_command_prefix(WG_NAMESPACE)
        + _python_network_command(
            protocol="udp",
            family="6",
            address=NAMESPACE_WG_V6,
            port=NAMESPACE_PORTMAP_UDP_PORT,
            token=f"{udp6}-control",
            expect_reply=True,
        ),
        blocked_command=_python_network_command(
            protocol="udp",
            family="6",
            address=ISOLATED_SHARED_V6,
            port=PORTMAP_UDP_PORT,
            token=udp6,
            expect_reply=True,
        ),
        control_token=f"{udp6}-control",
        blocked_token=udp6,
        message="IPv6 host-to-namespace UDP port mapping is a documented current VPN-Confinement one-way delivery limitation",
        blocked_machine=probe,
    )
    assert both_tcp4 in _tcp_roundtrip(
        probe, ISOLATED_SHARED_V4, PORTMAP_BOTH_PORT, both_tcp4, family="4"
    ), (
        "Namespace dual-protocol TCP port mapping over IPv4 did not echo the expected token"
    )
    _assert_log_has_entry(
        isolated,
        _log_path("namespace-port-map-both-tcp-v4"),
        both_tcp4,
        PROBE_PRIMARY_V4,
        "Namespace dual-protocol TCP IPv4 port-mapping listener log missing probe source",
    )
    _assert_denied_listener_preflight(
        machine=isolated,
        log_path=_log_path("namespace-port-map-both-tcp-v6"),
        control_command=_command_prefix(WG_NAMESPACE)
        + _python_network_command(
            protocol="tcp",
            family="6",
            address=NAMESPACE_WG_V6,
            port=NAMESPACE_PORTMAP_BOTH_PORT,
            token=f"{both_tcp6}-control",
            expect_reply=True,
        ),
        blocked_command=_python_network_command(
            protocol="tcp",
            family="6",
            address=ISOLATED_SHARED_V6,
            port=PORTMAP_BOTH_PORT,
            token=both_tcp6,
            expect_reply=True,
        ),
        control_token=f"{both_tcp6}-control",
        blocked_token=both_tcp6,
        message="IPv6 host-to-namespace both/TCP port mapping is a documented current VPN-Confinement bridge limitation",
        blocked_machine=probe,
    )
    assert both_udp4 in _udp_roundtrip(
        probe, ISOLATED_SHARED_V4, PORTMAP_BOTH_PORT, both_udp4, family="4"
    ), (
        "Namespace dual-protocol UDP port mapping over IPv4 did not echo the expected token"
    )
    _assert_log_has_entry(
        isolated,
        _log_path("namespace-port-map-both-udp-v4"),
        both_udp4,
        PROBE_PRIMARY_V4,
        "Namespace dual-protocol UDP IPv4 port-mapping listener log missing probe source",
    )
    _assert_one_way_udp_listener_limitation(
        machine=isolated,
        log_path=_log_path("namespace-port-map-both-udp-v6"),
        control_command=_command_prefix(WG_NAMESPACE)
        + _python_network_command(
            protocol="udp",
            family="6",
            address=NAMESPACE_WG_V6,
            port=NAMESPACE_PORTMAP_BOTH_PORT,
            token=f"{both_udp6}-control",
            expect_reply=True,
        ),
        blocked_command=_python_network_command(
            protocol="udp",
            family="6",
            address=ISOLATED_SHARED_V6,
            port=PORTMAP_BOTH_PORT,
            token=both_udp6,
            expect_reply=True,
        ),
        control_token=f"{both_udp6}-control",
        blocked_token=both_udp6,
        message="IPv6 host-to-namespace both/UDP port mapping is a documented current VPN-Confinement one-way delivery limitation",
        blocked_machine=probe,
    )

    tcp_opposite_log = _log_path("namespace-port-map-tcp-opposite-v4")
    udp_opposite_log = _log_path("namespace-port-map-udp-opposite-v4")
    tcp_opposite_control = _token("portmap-opposite-udp-control")
    tcp_opposite_blocked = _token("portmap-opposite-udp-blocked")
    udp_opposite_control = _token("portmap-opposite-tcp-control")
    udp_opposite_blocked = _token("portmap-opposite-tcp-blocked")

    _assert_denied_listener_preflight(
        machine=isolated,
        log_path=tcp_opposite_log,
        control_command=_command_prefix(WG_NAMESPACE)
        + _python_network_command(
            protocol="udp",
            family="4",
            address=NAMESPACE_WG_V4,
            port=NAMESPACE_PORTMAP_TCP_PORT,
            token=tcp_opposite_control,
            expect_reply=True,
        ),
        blocked_command=_command_prefix(None)
        + _python_network_command(
            protocol="udp",
            family="4",
            address=ISOLATED_SHARED_V4,
            port=PORTMAP_TCP_PORT,
            token=tcp_opposite_blocked,
            expect_reply=True,
        ),
        control_token=tcp_opposite_control,
        blocked_token=tcp_opposite_blocked,
        message="UDP packets must not traverse the TCP-only host-to-namespace port mapping",
        blocked_machine=probe,
    )
    _assert_denied_listener_preflight(
        machine=isolated,
        log_path=udp_opposite_log,
        control_command=_command_prefix(WG_NAMESPACE)
        + _python_network_command(
            protocol="tcp",
            family="4",
            address=NAMESPACE_WG_V4,
            port=NAMESPACE_PORTMAP_UDP_PORT,
            token=udp_opposite_control,
            expect_reply=True,
        ),
        blocked_command=_command_prefix(None)
        + _python_network_command(
            protocol="tcp",
            family="4",
            address=ISOLATED_SHARED_V4,
            port=PORTMAP_UDP_PORT,
            token=udp_opposite_blocked,
            expect_reply=True,
        ),
        control_token=udp_opposite_control,
        blocked_token=udp_opposite_blocked,
        message="TCP connections must not traverse the UDP-only host-to-namespace port mapping",
        blocked_machine=probe,
    )

    tcp_denied_log = _log_path("namespace-unmapped-denied-tcp-v4")
    udp_denied_log = _log_path("namespace-unmapped-denied-udp-v4")
    tcp_control = _token("portmap-denied-tcp-control")
    tcp_blocked = _token("portmap-denied-tcp-blocked")
    udp_control = _token("portmap-denied-udp-control")
    udp_blocked = _token("portmap-denied-udp-blocked")

    _assert_denied_listener_preflight(
        machine=isolated,
        log_path=tcp_denied_log,
        control_command=_command_prefix(WG_NAMESPACE)
        + _python_network_command(
            protocol="tcp",
            family="4",
            address=NAMESPACE_WG_V4,
            port=NAMESPACE_DENIED_TCP_PORT,
            token=tcp_control,
            expect_reply=True,
        ),
        blocked_command=_command_prefix(None)
        + _python_network_command(
            protocol="tcp",
            family="4",
            address=ISOLATED_SHARED_V4,
            port=HOST_DENIED_TCP_PORT,
            token=tcp_blocked,
            expect_reply=True,
        ),
        control_token=tcp_control,
        blocked_token=tcp_blocked,
        message="Unmapped TCP host port must fail without leaking to the namespace listener",
        blocked_machine=probe,
    )
    _assert_denied_listener_preflight(
        machine=isolated,
        log_path=udp_denied_log,
        control_command=_command_prefix(WG_NAMESPACE)
        + _python_network_command(
            protocol="udp",
            family="4",
            address=NAMESPACE_WG_V4,
            port=NAMESPACE_DENIED_UDP_PORT,
            token=udp_control,
            expect_reply=True,
        ),
        blocked_command=_command_prefix(None)
        + _python_network_command(
            protocol="udp",
            family="4",
            address=ISOLATED_SHARED_V4,
            port=HOST_DENIED_UDP_PORT,
            token=udp_blocked,
            expect_reply=True,
        ),
        control_token=udp_control,
        blocked_token=udp_blocked,
        message="Unmapped UDP host port must fail without leaking to the namespace listener",
        blocked_machine=probe,
    )


def _assert_open_vpn_ports(relay: "Machine", isolated: "Machine") -> None:
    tcp4 = _token("open-vpn-tcp4")
    tcp6 = _token("open-vpn-tcp6")
    udp4 = _token("open-vpn-udp4")
    udp6 = _token("open-vpn-udp6")
    both_tcp4 = _token("open-vpn-both-tcp4")
    both_tcp6 = _token("open-vpn-both-tcp6")
    both_udp4 = _token("open-vpn-both-udp4")
    both_udp6 = _token("open-vpn-both-udp6")

    assert tcp4 in _tcp_roundtrip(
        relay, NAMESPACE_WG_V4, OPEN_VPN_TCP_PORT, tcp4, family="4"
    ), "Open VPN TCP port over IPv4 did not echo the expected token from relay"
    _assert_log_has_entry(
        isolated,
        _log_path("namespace-open-vpn-tcp-v4"),
        tcp4,
        RELAY_WG_V4,
        "Open VPN TCP IPv4 listener log missing relay WireGuard source",
    )
    assert tcp6 in _tcp_roundtrip(
        relay, NAMESPACE_WG_V6, OPEN_VPN_TCP_PORT, tcp6, family="6"
    ), "Open VPN TCP port over IPv6 did not echo the expected token from relay"
    _assert_log_has_entry(
        isolated,
        _log_path("namespace-open-vpn-tcp-v6"),
        tcp6,
        RELAY_WG_V6,
        "Open VPN TCP IPv6 listener log missing relay WireGuard source",
    )
    assert udp4 in _udp_roundtrip(
        relay, NAMESPACE_WG_V4, OPEN_VPN_UDP_PORT, udp4, family="4"
    ), "Open VPN UDP port over IPv4 did not echo the expected token from relay"
    _assert_log_has_entry(
        isolated,
        _log_path("namespace-open-vpn-udp-v4"),
        udp4,
        RELAY_WG_V4,
        "Open VPN UDP IPv4 listener log missing relay WireGuard source",
    )
    assert udp6 in _udp_roundtrip(
        relay, NAMESPACE_WG_V6, OPEN_VPN_UDP_PORT, udp6, family="6"
    ), "Open VPN UDP port over IPv6 did not echo the expected token from relay"
    _assert_log_has_entry(
        isolated,
        _log_path("namespace-open-vpn-udp-v6"),
        udp6,
        RELAY_WG_V6,
        "Open VPN UDP IPv6 listener log missing relay WireGuard source",
    )
    assert both_tcp4 in _tcp_roundtrip(
        relay, NAMESPACE_WG_V4, OPEN_VPN_BOTH_PORT, both_tcp4, family="4"
    ), (
        "Open VPN dual-protocol TCP port over IPv4 did not echo the expected token from relay"
    )
    _assert_log_has_entry(
        isolated,
        _log_path("namespace-open-vpn-both-tcp-v4"),
        both_tcp4,
        RELAY_WG_V4,
        "Open VPN dual-protocol TCP IPv4 listener log missing relay WireGuard source",
    )
    assert both_tcp6 in _tcp_roundtrip(
        relay, NAMESPACE_WG_V6, OPEN_VPN_BOTH_PORT, both_tcp6, family="6"
    ), (
        "Open VPN dual-protocol TCP port over IPv6 did not echo the expected token from relay"
    )
    _assert_log_has_entry(
        isolated,
        _log_path("namespace-open-vpn-both-tcp-v6"),
        both_tcp6,
        RELAY_WG_V6,
        "Open VPN dual-protocol TCP IPv6 listener log missing relay WireGuard source",
    )
    assert both_udp4 in _udp_roundtrip(
        relay, NAMESPACE_WG_V4, OPEN_VPN_BOTH_PORT, both_udp4, family="4"
    ), (
        "Open VPN dual-protocol UDP port over IPv4 did not echo the expected token from relay"
    )
    _assert_log_has_entry(
        isolated,
        _log_path("namespace-open-vpn-both-udp-v4"),
        both_udp4,
        RELAY_WG_V4,
        "Open VPN dual-protocol UDP IPv4 listener log missing relay WireGuard source",
    )
    assert both_udp6 in _udp_roundtrip(
        relay, NAMESPACE_WG_V6, OPEN_VPN_BOTH_PORT, both_udp6, family="6"
    ), (
        "Open VPN dual-protocol UDP port over IPv6 did not echo the expected token from relay"
    )
    _assert_log_has_entry(
        isolated,
        _log_path("namespace-open-vpn-both-udp-v6"),
        both_udp6,
        RELAY_WG_V6,
        "Open VPN dual-protocol UDP IPv6 listener log missing relay WireGuard source",
    )

    tcp_denied_log = _log_path("namespace-open-vpn-denied-tcp-v4")
    udp_denied_log = _log_path("namespace-open-vpn-denied-udp-v4")
    tcp_control = _token("open-vpn-denied-tcp-control")
    tcp_blocked = _token("open-vpn-denied-tcp-blocked")
    udp_control = _token("open-vpn-denied-udp-control")
    udp_blocked = _token("open-vpn-denied-udp-blocked")

    _assert_denied_listener_preflight(
        machine=isolated,
        log_path=tcp_denied_log,
        control_command=_command_prefix(WG_NAMESPACE)
        + _python_network_command(
            protocol="tcp",
            family="4",
            address=NAMESPACE_WG_V4,
            port=OPEN_VPN_DENIED_TCP_PORT,
            token=tcp_control,
            expect_reply=True,
        ),
        blocked_command=_command_prefix(None)
        + _python_network_command(
            protocol="tcp",
            family="4",
            address=NAMESPACE_WG_V4,
            port=OPEN_VPN_DENIED_TCP_PORT,
            token=tcp_blocked,
            expect_reply=True,
        ),
        control_token=tcp_control,
        blocked_token=tcp_blocked,
        message="Closed open-VPN TCP port must fail without reaching the namespace listener",
        blocked_machine=relay,
    )
    _assert_denied_listener_preflight(
        machine=isolated,
        log_path=udp_denied_log,
        control_command=_command_prefix(WG_NAMESPACE)
        + _python_network_command(
            protocol="udp",
            family="4",
            address=NAMESPACE_WG_V4,
            port=OPEN_VPN_DENIED_UDP_PORT,
            token=udp_control,
            expect_reply=True,
        ),
        blocked_command=_command_prefix(None)
        + _python_network_command(
            protocol="udp",
            family="4",
            address=NAMESPACE_WG_V4,
            port=OPEN_VPN_DENIED_UDP_PORT,
            token=udp_blocked,
            expect_reply=True,
        ),
        control_token=udp_control,
        blocked_token=udp_blocked,
        message="Closed open-VPN UDP port must fail without reaching the namespace listener",
        blocked_machine=relay,
    )
    _assert_denied_listener_preflight(
        machine=isolated,
        log_path=_log_path("namespace-open-vpn-denied-tcp-v6"),
        control_command=_command_prefix(WG_NAMESPACE)
        + _python_network_command(
            protocol="tcp",
            family="6",
            address=NAMESPACE_WG_V6,
            port=OPEN_VPN_DENIED_TCP_PORT,
            token="open-vpn-denied-tcp-v6-control",
            expect_reply=True,
        ),
        blocked_command=_command_prefix(None)
        + _python_network_command(
            protocol="tcp",
            family="6",
            address=NAMESPACE_WG_V6,
            port=OPEN_VPN_DENIED_TCP_PORT,
            token="open-vpn-denied-tcp-v6-blocked",
            expect_reply=True,
        ),
        control_token="open-vpn-denied-tcp-v6-control",
        blocked_token="open-vpn-denied-tcp-v6-blocked",
        message="Closed open-VPN TCP port over IPv6 must fail without reaching the namespace listener",
        blocked_machine=relay,
    )
    _assert_denied_listener_preflight(
        machine=isolated,
        log_path=_log_path("namespace-open-vpn-denied-udp-v6"),
        control_command=_command_prefix(WG_NAMESPACE)
        + _python_network_command(
            protocol="udp",
            family="6",
            address=NAMESPACE_WG_V6,
            port=OPEN_VPN_DENIED_UDP_PORT,
            token="open-vpn-denied-udp-v6-control",
            expect_reply=True,
        ),
        blocked_command=_command_prefix(None)
        + _python_network_command(
            protocol="udp",
            family="6",
            address=NAMESPACE_WG_V6,
            port=OPEN_VPN_DENIED_UDP_PORT,
            token="open-vpn-denied-udp-v6-blocked",
            expect_reply=True,
        ),
        control_token="open-vpn-denied-udp-v6-control",
        blocked_token="open-vpn-denied-udp-v6-blocked",
        message="Closed open-VPN UDP port over IPv6 must fail without reaching the namespace listener",
        blocked_machine=relay,
    )


def _assert_dns(isolated: "Machine", probe: "Machine") -> None:
    resolv_conf = _succeed(
        isolated,
        f"cat /etc/netns/{_q(WG_NAMESPACE)}/resolv.conf",
        "Failed to read namespace resolv.conf",
    )
    assert f"nameserver {PROBE_PRIMARY_V4}" in resolv_conf, (
        "Namespace resolv.conf must contain the approved IPv4 nameserver"
    )
    assert f"nameserver {PROBE_PRIMARY_V6}" in resolv_conf, (
        "Namespace resolv.conf must contain the approved IPv6 nameserver"
    )

    approved_v4_log = _log_path("dns-approved-v4")
    approved_v6_log = _log_path("dns-approved-v6")
    positive_v4 = _token("dns-approved-ipv4")
    positive_v6 = _token("dns-approved-ipv6")
    _clear_log(probe, approved_v4_log)
    _clear_log(probe, approved_v6_log)
    assert _dig_query(isolated, PROBE_PRIMARY_V4, positive_v4, family="4"), (
        "Approved IPv4 confined dig query returned no answer"
    )
    assert _dig_query(isolated, PROBE_PRIMARY_V6, positive_v6, family="6"), (
        "Approved IPv6 confined dig query returned no answer"
    )
    _assert_log_has_token(
        probe,
        approved_v4_log,
        positive_v4,
        "Approved IPv4 DNS listener log missing query token",
    )
    _assert_log_has_token(
        probe,
        approved_v6_log,
        positive_v6,
        "Approved IPv6 DNS listener log missing query token",
    )

    denied_cases = [
        (
            _log_path("dns-leak-udp-v4"),
            _python_network_command(
                protocol="udp",
                family="4",
                address=PROBE_REMOTE_V4,
                port=DNS_PORT,
                token="dns-denied-udp4-control",
                expect_reply=True,
            ),
            _python_network_command(
                protocol="udp",
                family="4",
                address=PROBE_REMOTE_V4,
                port=DNS_PORT,
                token="dns-denied-udp4-blocked",
                expect_reply=True,
            ),
            "dns-denied-udp4-control",
            "dns-denied-udp4-blocked",
            "Raw UDP/53 to unapproved IPv4 resolver",
        ),
        (
            _log_path("dns-leak-udp-v6"),
            _python_network_command(
                protocol="udp",
                family="6",
                address=PROBE_REMOTE_V6,
                port=DNS_PORT,
                token="dns-denied-udp6-control",
                expect_reply=True,
            ),
            _python_network_command(
                protocol="udp",
                family="6",
                address=PROBE_REMOTE_V6,
                port=DNS_PORT,
                token="dns-denied-udp6-blocked",
                expect_reply=True,
            ),
            "dns-denied-udp6-control",
            "dns-denied-udp6-blocked",
            "Raw UDP/53 to unapproved IPv6 resolver",
        ),
        (
            _log_path("dns-leak-tcp-v4"),
            _python_network_command(
                protocol="tcp",
                family="4",
                address=PROBE_REMOTE_V4,
                port=DNS_PORT,
                token="dns-denied-tcp4-control",
                expect_reply=True,
            ),
            _python_network_command(
                protocol="tcp",
                family="4",
                address=PROBE_REMOTE_V4,
                port=DNS_PORT,
                token="dns-denied-tcp4-blocked",
                expect_reply=True,
            ),
            "dns-denied-tcp4-control",
            "dns-denied-tcp4-blocked",
            "Raw TCP/53 to unapproved IPv4 resolver",
        ),
        (
            _log_path("dns-leak-tcp-v6"),
            _python_network_command(
                protocol="tcp",
                family="6",
                address=PROBE_REMOTE_V6,
                port=DNS_PORT,
                token="dns-denied-tcp6-control",
                expect_reply=True,
            ),
            _python_network_command(
                protocol="tcp",
                family="6",
                address=PROBE_REMOTE_V6,
                port=DNS_PORT,
                token="dns-denied-tcp6-blocked",
                expect_reply=True,
            ),
            "dns-denied-tcp6-control",
            "dns-denied-tcp6-blocked",
            "Raw TCP/53 to unapproved IPv6 resolver",
        ),
        (
            _log_path("dot-leak-tcp-v4"),
            _python_network_command(
                protocol="tcp",
                family="4",
                address=PROBE_REMOTE_V4,
                port=DOT_PORT,
                token="dot-denied-tcp4-control",
                expect_reply=True,
            ),
            _python_network_command(
                protocol="tcp",
                family="4",
                address=PROBE_REMOTE_V4,
                port=DOT_PORT,
                token="dot-denied-tcp4-blocked",
                expect_reply=True,
            ),
            "dot-denied-tcp4-control",
            "dot-denied-tcp4-blocked",
            "TCP/853 to unapproved IPv4 DoT endpoint",
        ),
        (
            _log_path("dot-leak-tcp-v6"),
            _python_network_command(
                protocol="tcp",
                family="6",
                address=PROBE_REMOTE_V6,
                port=DOT_PORT,
                token="dot-denied-tcp6-control",
                expect_reply=True,
            ),
            _python_network_command(
                protocol="tcp",
                family="6",
                address=PROBE_REMOTE_V6,
                port=DOT_PORT,
                token="dot-denied-tcp6-blocked",
                expect_reply=True,
            ),
            "dot-denied-tcp6-control",
            "dot-denied-tcp6-blocked",
            "TCP/853 to unapproved IPv6 DoT endpoint",
        ),
        (
            _log_path("dot-leak-udp-v4"),
            _python_network_command(
                protocol="udp",
                family="4",
                address=PROBE_REMOTE_V4,
                port=DOT_PORT,
                token="dot-denied-udp4-control",
                expect_reply=True,
            ),
            _python_network_command(
                protocol="udp",
                family="4",
                address=PROBE_REMOTE_V4,
                port=DOT_PORT,
                token="dot-denied-udp4-blocked",
                expect_reply=True,
            ),
            "dot-denied-udp4-control",
            "dot-denied-udp4-blocked",
            "UDP/853 to unapproved IPv4 DoT endpoint",
        ),
        (
            _log_path("dot-leak-udp-v6"),
            _python_network_command(
                protocol="udp",
                family="6",
                address=PROBE_REMOTE_V6,
                port=DOT_PORT,
                token="dot-denied-udp6-control",
                expect_reply=True,
            ),
            _python_network_command(
                protocol="udp",
                family="6",
                address=PROBE_REMOTE_V6,
                port=DOT_PORT,
                token="dot-denied-udp6-blocked",
                expect_reply=True,
            ),
            "dot-denied-udp6-control",
            "dot-denied-udp6-blocked",
            "UDP/853 to unapproved IPv6 DoT endpoint",
        ),
    ]
    for (
        log_path,
        control_script,
        blocked_script,
        control_token,
        blocked_token,
        description,
    ) in denied_cases:
        _assert_denied_listener_preflight(
            machine=probe,
            log_path=log_path,
            control_command=control_script,
            blocked_command=_command_prefix(WG_NAMESPACE) + blocked_script,
            control_token=control_token,
            blocked_token=blocked_token,
            message=description,
            blocked_machine=isolated,
        )

    doh_v4_log = _log_path("doh-leak-v4")
    doh_v6_log = _log_path("doh-leak-v6")
    doh_v4_control = _token("doh-denied-ipv4-control")
    doh_v4_blocked = _token("doh-denied-ipv4-blocked")
    doh_v6_control = _token("doh-denied-ipv6-control")
    doh_v6_blocked = _token("doh-denied-ipv6-blocked")
    _assert_denied_listener_preflight(
        machine=probe,
        log_path=doh_v4_log,
        control_command=_python_network_command(
            protocol="tcp",
            family="4",
            address=PROBE_REMOTE_V4,
            port=DOH_PORT,
            token=doh_v4_control,
            expect_reply=True,
        ),
        blocked_command=_command_prefix(WG_NAMESPACE)
        + _python_network_command(
            protocol="tcp",
            family="4",
            address=PROBE_REMOTE_V4,
            port=DOH_PORT,
            token=doh_v4_blocked,
            expect_reply=True,
        ),
        control_token=doh_v4_control,
        blocked_token=doh_v4_blocked,
        message="DoH-like IPv4 endpoint must stay blocked from the namespace",
        blocked_machine=isolated,
    )
    _assert_denied_listener_preflight(
        machine=probe,
        log_path=doh_v6_log,
        control_command=_python_network_command(
            protocol="tcp",
            family="6",
            address=PROBE_REMOTE_V6,
            port=DOH_PORT,
            token=doh_v6_control,
            expect_reply=True,
        ),
        blocked_command=_command_prefix(WG_NAMESPACE)
        + _python_network_command(
            protocol="tcp",
            family="6",
            address=PROBE_REMOTE_V6,
            port=DOH_PORT,
            token=doh_v6_blocked,
            expect_reply=True,
        ),
        control_token=doh_v6_control,
        blocked_token=doh_v6_blocked,
        message="DoH-like IPv6 endpoint must stay blocked from the namespace",
        blocked_machine=isolated,
    )


def _assert_midflight_outage(
    relay: "Machine", isolated: "Machine", probe: "Machine"
) -> None:
    _shutdown_machine(relay)
    for label, (service, output_path) in CONFINED_SOURCE_SERVICES.items():
        observer_address, observer_family, observer_log_path, observer_token = (
            REMOTE_SOURCE_OBSERVERS[label]
        )
        _assert_confined_source_observer_fail_closed(
            probe,
            isolated,
            label=label,
            service=service,
            output_path=output_path,
            observer_address=observer_address,
            observer_family=cast(Family, observer_family),
            observer_log_path=observer_log_path,
            observer_token=observer_token,
            message=f"Confined source observer {label} must fail closed during relay outage",
            outage="mid-flight outage check",
            output_failure=(
                f"Confined source observer {label} unexpectedly wrote {output_path} during relay outage"
            ),
            observer_failure=(
                f"Confined source observer {label} unexpectedly reached probe observer {observer_token} during relay outage"
            ),
        )
    _assert_http_fails(
        probe,
        RELAY_SHARED_V4,
        RELAY_TCP_PORT,
        family="4",
        message="Relay TCP ingress must fail closed during relay outage",
    )
    _assert_http_fails(
        probe,
        RELAY_SHARED_V6,
        RELAY_TCP_PORT,
        family="6",
        message="Relay TCP ingress must fail closed during relay outage",
    )
    _start_machine(relay)
    relay.wait_for_unit("multi-user.target")
    _wait_for_wg_recovery(relay, isolated, probe)
    _assert_relay_baseline(probe, isolated)
    _assert_source_observers(isolated)


def _restart_service(machine: "Machine", service: str) -> None:
    _succeed(
        machine, f"systemctl restart {_q(service)}", f"Failed to restart {service}"
    )
    machine.wait_for_unit(service)


def _assert_restart_idempotency(
    relay: "Machine", isolated: "Machine", probe: "Machine"
) -> None:
    _restart_service(relay, WG_HOST_UNIT)
    _restart_service(isolated, WG_HOST_UNIT)
    _restart_service(isolated, WG_NAMESPACE_UNIT)
    _restart_service(isolated, WG_NAMESPACE_UNIT)
    for service in TOY_LISTENER_UNITS:
        _restart_service(isolated, service)
    _wait_for_wg_recovery(relay, isolated, probe)
    _assert_no_duplicate_state(isolated)
    _assert_no_duplicate_state(relay, namespace=None)
    _assert_relay_baseline(probe, isolated)
    _assert_source_observers(isolated)
    _assert_port_mappings(probe, isolated)
    _assert_open_vpn_ports(relay, isolated)
    _assert_dns(isolated, probe)


def run(driver_globals: dict[str, object]) -> None:
    """Run the reviewed WireGuard relay ingress and confinement assertions."""
    relay = cast("Machine", driver_globals["relay"])
    isolated = cast("Machine", driver_globals["isolated"])
    probe = cast("Machine", driver_globals["probe"])

    _start_machine(probe)
    _start_machine(isolated)

    probe.wait_for_unit("multi-user.target")
    isolated.wait_for_unit("multi-user.target")
    _assert_startup_fail_closed(probe, isolated)

    _start_machine(relay)
    relay.wait_for_unit("multi-user.target")
    _succeed(
        isolated,
        f"systemctl reset-failed {_q(WG_NAMESPACE_UNIT)}",
        "Failed to reset failed namespace service",
    )
    _succeed(
        isolated,
        f"systemctl restart {_q(WG_NAMESPACE_UNIT)}",
        "Failed to restart namespace service after relay start",
    )
    _wait_for_wg_recovery(relay, isolated, probe)

    _assert_relay_baseline(probe, isolated)
    _assert_relay_ingress(probe, isolated)
    _assert_route_separation(isolated)
    _assert_source_observers(isolated)
    _assert_port_mappings(probe, isolated)
    _assert_open_vpn_ports(relay, isolated)
    _assert_dns(isolated, probe)
    _assert_midflight_outage(relay, isolated, probe)
    _assert_restart_idempotency(relay, isolated, probe)


if __name__ == "__main__":
    run(globals())
