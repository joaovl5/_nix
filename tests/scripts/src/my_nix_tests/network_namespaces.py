"""Integration test: backend-less service network namespaces and firewall policy."""

from __future__ import annotations

import itertools
import shlex
from typing import TYPE_CHECKING, Literal, cast

if TYPE_CHECKING:
    from collections.abc import Callable

    from nix_machine_protocol import Machine

Family = Literal["4", "6"]

LOG_ROOT = "/run/netns-test"
TEST_NAMESPACE = "test"
FAIL_NAMESPACE = "failcore"

HOST_SHARED_V4 = "192.0.44.2"
HOST_SHARED_V6 = "fd00:44::2"
PROBE_PRIMARY_V4 = "192.0.44.3"
PROBE_PRIMARY_V6 = "fd00:44::3"
PROBE_REMOTE_V4 = "192.0.44.30"
PROBE_REMOTE_V6 = "fd00:44::30"
NAMESPACE_V4 = "10.44.0.2"
NAMESPACE_V6 = "fd44:1::2"

SOURCE_OBSERVER_PORT = 18081
PORTMAP_TCP_PORT = 19080
PORTMAP_UDP_PORT = 19082
PORTMAP_BOTH_PORT = 19084
NAMESPACE_PORTMAP_TCP_PORT = 28080
NAMESPACE_PORTMAP_UDP_PORT = 28082
NAMESPACE_PORTMAP_BOTH_PORT = 28084
UNMAPPED_TCP_PORT = 19090
DNS_PORT = 53
DOT_PORT = 853
DOH_PORT = 18443

NAMESPACE_LISTENER_SERVICES = (
    "ns-tcp-v4.service",
    "ns-tcp-v6.service",
    "ns-tcp-opposite-udp-v4.service",
    "ns-tcp-opposite-udp-v6.service",
    "ns-udp-v4.service",
    "ns-udp-v6.service",
    "ns-udp-opposite-tcp-v4.service",
    "ns-udp-opposite-tcp-v6.service",
    "ns-both-tcp-v4.service",
    "ns-both-tcp-v6.service",
    "ns-both-udp-v4.service",
    "ns-both-udp-v6.service",
)

_TOKEN_COUNTER = itertools.count(1)


def _q(value: str) -> str:
    return shlex.quote(value)


def _require_callable(obj: object, name: str) -> Callable[..., object]:
    method = getattr(obj, name, None)
    assert callable(method), f"Machine is missing required method {name}()"
    return cast("Callable[..., object]", method)


def _start_all(driver_globals: dict[str, object]) -> None:
    start_all = driver_globals.get("start_all")
    if callable(start_all):
        cast("Callable[[], None]", start_all)()


def _start_namespace_listeners(host: "Machine") -> None:
    # Confined listeners are stopped by BindsTo= when the namespace unit restarts.
    # Start them explicitly before assertions that depend on host-to-namespace ingress.
    host.succeed(f"systemctl start {' '.join(NAMESPACE_LISTENER_SERVICES)}")
    for service in NAMESPACE_LISTENER_SERVICES:
        host.wait_for_unit(service)


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


def _wait_until_succeeds(machine: "Machine", command: str, message: str) -> None:
    try:
        machine.wait_until_succeeds(command)
    except Exception as exc:  # pragma: no cover - integration-driver surface
        raise AssertionError(f"{message}: {command}") from exc


def _token(prefix: str) -> str:
    return f"{prefix}-{next(_TOKEN_COUNTER)}"


def _log_path(name: str) -> str:
    return f"{LOG_ROOT}/{name}"


def _clear_log(machine: "Machine", path: str) -> None:
    machine.succeed(f"mkdir -p {_q(LOG_ROOT)} && : > {_q(path)}")


def _read_log(machine: "Machine", path: str) -> str:
    return machine.succeed(f"test -f {_q(path)} && cat {_q(path)} || true")


def _assert_log_has_entry(
    machine: "Machine", path: str, token: str, source: str, message: str
) -> None:
    log_lines = _read_log(machine, path).splitlines()
    expected = f"{token} {source}"
    assert expected in log_lines, (
        f"{message}. Missing {expected!r} in {path}:\n" + "\n".join(log_lines)
    )


def _assert_log_lacks(machine: "Machine", path: str, token: str, message: str) -> None:
    log = _read_log(machine, path)
    assert token not in log, f"{message}. Unexpected token {token!r} in {path}:\n{log}"


def _socket_command(
    mode: str,
    address: str,
    port: int,
    token: str,
    family: Family,
    source_address: str | None = None,
) -> str:
    socket_family = "AF_INET" if family == "4" else "AF_INET6"
    code = f"""
import socket
import sys
family = socket.{socket_family}
mode, address, port, token, source_address = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4], sys.argv[5]
sock_type = socket.SOCK_STREAM if mode == "tcp" else socket.SOCK_DGRAM
sock = socket.socket(family, sock_type)
sock.settimeout(3)
if source_address != "-":
    sock.bind((source_address, 0))
if mode == "tcp":
    sock.connect((address, port))
    sock.sendall(token.encode())
    data = sock.recv(4096)
else:
    sock.sendto(token.encode(), (address, port))
    data, _ = sock.recvfrom(4096)
print(data.decode(errors="replace"))
""".strip()
    source = source_address if source_address is not None else "-"
    return f"python3 -c {_q(code)} {_q(mode)} {_q(address)} {port} {_q(token)} {_q(source)}"


def _netns(namespace: str, command: str) -> str:
    return f"ip netns exec {_q(namespace)} {command}"


def _tcp_roundtrip(
    machine: "Machine",
    address: str,
    port: int,
    token: str,
    family: Family,
    source_address: str | None = None,
) -> str:
    return _succeed(
        machine,
        _socket_command("tcp", address, port, token, family, source_address),
        f"TCP roundtrip to {address}:{port} failed",
    )


def _udp_roundtrip(
    machine: "Machine",
    address: str,
    port: int,
    token: str,
    family: Family,
    source_address: str | None = None,
) -> str:
    return _succeed(
        machine,
        _socket_command("udp", address, port, token, family, source_address),
        f"UDP roundtrip to {address}:{port} failed",
    )


def _assert_blocked_path(
    *,
    host: "Machine",
    probe: "Machine",
    mode: str,
    address: str,
    port: int,
    family: Family,
    log_name: str,
    description: str,
) -> None:
    log_path = _log_path(log_name)
    control = _token(f"control-{description}")
    blocked = _token(f"blocked-{description}")

    # Negative assertions are only meaningful after proving the listener is alive.
    _clear_log(probe, log_path)
    if mode == "tcp":
        assert control in _tcp_roundtrip(host, address, port, control, family)
    else:
        assert control in _udp_roundtrip(host, address, port, control, family)
    _assert_log_has_entry(
        probe,
        log_path,
        control,
        HOST_SHARED_V4 if family == "4" else HOST_SHARED_V6,
        f"Denied {description} listener preflight failed",
    )

    _clear_log(probe, log_path)
    blocked_command = _netns(
        TEST_NAMESPACE,
        _socket_command(mode, address, port, blocked, family),
    )
    _fail(host, f"timeout 4 {blocked_command}", f"Blocked {description} path must fail")
    _assert_log_lacks(
        probe,
        log_path,
        blocked,
        f"Blocked {description} path must not reach the denied listener",
    )


def _assert_service_attachment(host: "Machine", probe: "Machine") -> None:
    # Source-observer services are separate probe fixtures; prove they are reachable
    # before starting one-shot confined services whose only output is a curl result.
    _wait_until_succeeds(
        host,
        f"curl --fail --silent --show-error --max-time 5 "
        f"{_q(f'http://{PROBE_PRIMARY_V4}:{SOURCE_OBSERVER_PORT}/?token=observer-ready-v4')}",
        "IPv4 source observer did not become ready",
    )
    _wait_until_succeeds(
        host,
        f"curl --fail --silent --show-error --max-time 5 "
        f"{_q(f'http://[{PROBE_PRIMARY_V6}]:{SOURCE_OBSERVER_PORT}/?token=observer-ready-v6')}",
        "IPv6 source observer did not become ready",
    )
    _clear_log(probe, _log_path("observer-v4.log"))
    _clear_log(probe, _log_path("observer-v6.log"))
    host.succeed("systemctl start ns-source-v4.service ns-source-v6.service")
    source_v4 = host.succeed(f"cat {_log_path('source-v4')}").strip()
    source_v6 = host.succeed(f"cat {_log_path('source-v6')}").strip()
    assert source_v4 == NAMESPACE_V4, (
        f"IPv4 source should be namespace address, got {source_v4!r}"
    )
    assert source_v6 == NAMESPACE_V6, (
        f"IPv6 source should be namespace address, got {source_v6!r}"
    )
    _assert_log_has_entry(
        probe,
        _log_path("observer-v4.log"),
        "source-v4",
        NAMESPACE_V4,
        "Probe observer did not see namespace IPv4 source",
    )
    _assert_log_has_entry(
        probe,
        _log_path("observer-v6.log"),
        "source-v6",
        NAMESPACE_V6,
        "Probe observer did not see namespace IPv6 source",
    )


def _assert_dns_policy(host: "Machine", probe: "Machine") -> None:
    host.succeed("systemctl start ns-dns-lookup.service")
    lookup_answers = set(host.succeed(f"cat {_log_path('dns-lookup')}").splitlines())
    assert lookup_answers & {PROBE_PRIMARY_V4, PROBE_PRIMARY_V6}, (
        f"Configured namespace resolver did not resolve allowed.core-test.internal exactly: {lookup_answers!r}"
    )

    denied_cases = [
        ("tcp", PROBE_REMOTE_V4, DNS_PORT, "4", "denied-dns-tcp-v4.log", "dns-tcp-v4"),
        ("udp", PROBE_REMOTE_V4, DNS_PORT, "4", "denied-dns-udp-v4.log", "dns-udp-v4"),
        ("tcp", PROBE_REMOTE_V6, DNS_PORT, "6", "denied-dns-tcp-v6.log", "dns-tcp-v6"),
        ("udp", PROBE_REMOTE_V6, DNS_PORT, "6", "denied-dns-udp-v6.log", "dns-udp-v6"),
        ("tcp", PROBE_REMOTE_V4, DOT_PORT, "4", "denied-dot-tcp-v4.log", "dot-tcp-v4"),
        ("udp", PROBE_REMOTE_V4, DOT_PORT, "4", "denied-dot-udp-v4.log", "dot-udp-v4"),
        ("tcp", PROBE_REMOTE_V6, DOT_PORT, "6", "denied-dot-tcp-v6.log", "dot-tcp-v6"),
        ("udp", PROBE_REMOTE_V6, DOT_PORT, "6", "denied-dot-udp-v6.log", "dot-udp-v6"),
        ("tcp", PROBE_REMOTE_V4, DOH_PORT, "4", "denied-doh-tcp-v4.log", "doh-tcp-v4"),
        ("udp", PROBE_REMOTE_V4, DOH_PORT, "4", "denied-doh-udp-v4.log", "doh-udp-v4"),
        ("tcp", PROBE_REMOTE_V6, DOH_PORT, "6", "denied-doh-tcp-v6.log", "doh-tcp-v6"),
        ("udp", PROBE_REMOTE_V6, DOH_PORT, "6", "denied-doh-udp-v6.log", "doh-udp-v6"),
    ]
    for mode, address, port, family, log_name, description in denied_cases:
        _assert_blocked_path(
            host=host,
            probe=probe,
            mode=mode,
            address=address,
            port=port,
            family=cast(Family, family),
            log_name=log_name,
            description=description,
        )


def _assert_port_mappings(probe: "Machine", host: "Machine") -> None:
    cases = [
        (
            "tcp",
            HOST_SHARED_V4,
            PORTMAP_TCP_PORT,
            "4",
            "portmap-tcp-v4.log",
            PROBE_PRIMARY_V4,
        ),
        (
            "tcp",
            HOST_SHARED_V6,
            PORTMAP_TCP_PORT,
            "6",
            "portmap-tcp-v6.log",
            PROBE_PRIMARY_V6,
        ),
        (
            "udp",
            HOST_SHARED_V4,
            PORTMAP_UDP_PORT,
            "4",
            "portmap-udp-v4.log",
            PROBE_PRIMARY_V4,
        ),
        (
            "udp",
            HOST_SHARED_V6,
            PORTMAP_UDP_PORT,
            "6",
            "portmap-udp-v6.log",
            PROBE_PRIMARY_V6,
        ),
        (
            "tcp",
            HOST_SHARED_V4,
            PORTMAP_BOTH_PORT,
            "4",
            "portmap-both-tcp-v4.log",
            PROBE_PRIMARY_V4,
        ),
        (
            "tcp",
            HOST_SHARED_V6,
            PORTMAP_BOTH_PORT,
            "6",
            "portmap-both-tcp-v6.log",
            PROBE_PRIMARY_V6,
        ),
        (
            "udp",
            HOST_SHARED_V4,
            PORTMAP_BOTH_PORT,
            "4",
            "portmap-both-udp-v4.log",
            PROBE_PRIMARY_V4,
        ),
        (
            "udp",
            HOST_SHARED_V6,
            PORTMAP_BOTH_PORT,
            "6",
            "portmap-both-udp-v6.log",
            PROBE_PRIMARY_V6,
        ),
    ]
    for mode, address, port, family, log_name, expected_source in cases:
        token = _token(f"portmap-{mode}-{family}")
        result = (
            _tcp_roundtrip(
                probe, address, port, token, cast(Family, family), expected_source
            )
            if mode == "tcp"
            else _udp_roundtrip(
                probe, address, port, token, cast(Family, family), expected_source
            )
        )
        assert token in result, (
            f"{mode}/{family} port mapping did not echo token {token!r}"
        )
        _assert_log_has_entry(
            host,
            _log_path(log_name),
            token,
            expected_source,
            f"Namespace listener did not log expected source for {mode}/{family} mapping",
        )

    wrong_protocol_cases = [
        (
            "udp",
            HOST_SHARED_V4,
            PORTMAP_TCP_PORT,
            "4",
            NAMESPACE_V4,
            NAMESPACE_PORTMAP_TCP_PORT,
            "portmap-tcp-opposite-udp-v4.log",
            "UDP to TCP-only IPv4 mapping must fail",
        ),
        (
            "udp",
            HOST_SHARED_V6,
            PORTMAP_TCP_PORT,
            "6",
            NAMESPACE_V6,
            NAMESPACE_PORTMAP_TCP_PORT,
            "portmap-tcp-opposite-udp-v6.log",
            "UDP to TCP-only IPv6 mapping must fail",
        ),
        (
            "tcp",
            HOST_SHARED_V4,
            PORTMAP_UDP_PORT,
            "4",
            NAMESPACE_V4,
            NAMESPACE_PORTMAP_UDP_PORT,
            "portmap-udp-opposite-tcp-v4.log",
            "TCP to UDP-only IPv4 mapping must fail",
        ),
        (
            "tcp",
            HOST_SHARED_V6,
            PORTMAP_UDP_PORT,
            "6",
            NAMESPACE_V6,
            NAMESPACE_PORTMAP_UDP_PORT,
            "portmap-udp-opposite-tcp-v6.log",
            "TCP to UDP-only IPv6 mapping must fail",
        ),
    ]
    for (
        mode,
        host_address,
        host_port,
        family,
        ns_address,
        ns_port,
        log_name,
        message,
    ) in wrong_protocol_cases:
        log_path = _log_path(log_name)
        control = _token(f"wrong-proto-control-{family}-{mode}")
        blocked = _token(f"wrong-proto-blocked-{family}-{mode}")
        _clear_log(host, log_path)
        _succeed(
            host,
            _netns(
                TEST_NAMESPACE,
                _socket_command(
                    mode, ns_address, ns_port, control, cast(Family, family)
                ),
            ),
            f"Opposite-protocol sentinel preflight failed for {message}",
        )
        _assert_log_has_entry(
            host,
            log_path,
            control,
            ns_address,
            f"Opposite-protocol sentinel did not log preflight for {message}",
        )
        _clear_log(host, log_path)
        _fail(
            probe,
            _socket_command(
                mode, host_address, host_port, blocked, cast(Family, family)
            ),
            message,
        )
        _assert_log_lacks(
            host,
            log_path,
            blocked,
            f"{message} without reaching the opposite-protocol namespace listener",
        )

    unmapped = _token("unmapped")
    _fail(
        probe,
        _socket_command("tcp", HOST_SHARED_V4, UNMAPPED_TCP_PORT, unmapped, "4"),
        "Unmapped host port must fail",
    )


def _assert_fail_closed(host: "Machine", probe: "Machine") -> None:
    token = _token("fail-closed-preflight")
    log_path = _log_path("observer-v4.log")
    _clear_log(probe, log_path)
    preflight_source = _succeed(
        host,
        f"curl --fail --silent --show-error --max-time 5 "
        f"{_q(f'http://{PROBE_PRIMARY_V4}:{SOURCE_OBSERVER_PORT}/?token={token}')}",
        "Observer HTTP preflight failed before fail-closed check",
    )
    assert preflight_source == HOST_SHARED_V4, (
        f"Observer preflight source mismatch: expected {HOST_SHARED_V4}, got {preflight_source!r}"
    )
    _assert_log_has_entry(
        probe,
        log_path,
        token,
        HOST_SHARED_V4,
        "Observer preflight from host network failed before fail-closed check",
    )

    host.succeed("systemctl stop test.service")
    host.succeed("systemctl set-environment MY_NETWORK_NAMESPACES_FAIL_AFTER_CORE=test")
    _clear_log(probe, log_path)
    _fail(
        host,
        "systemctl start ns-source-v4.service",
        "Confined service must not start on host network while namespace setup fails",
    )
    host.succeed("systemctl unset-environment MY_NETWORK_NAMESPACES_FAIL_AFTER_CORE")
    _assert_log_lacks(
        probe,
        log_path,
        "source-v4",
        "Confined service leaked traffic while namespace setup failed",
    )

    host.succeed("systemctl reset-failed test.service ns-source-v4.service || true")
    host.succeed("systemctl start test.service")
    host.wait_for_unit("test.service")
    _start_namespace_listeners(host)
    host.succeed("systemctl start ns-source-v4.service")
    source = host.succeed(f"cat {_log_path('source-v4')}").strip()
    assert source == NAMESPACE_V4, f"Recovered service source mismatch: {source!r}"


def _assert_restart_idempotency(host: "Machine", probe: "Machine") -> None:
    for _ in range(3):
        host.succeed("systemctl restart test.service")
        host.wait_for_unit("test.service")
        _start_namespace_listeners(host)
    _assert_port_mappings(probe, host)

    netns_count = host.succeed("ip netns list | grep -c '^test '").strip()
    assert netns_count == "1", f"Expected one test namespace entry, got {netns_count}"
    nat_jumps = host.succeed(
        "iptables -t nat -S PREROUTING | grep -c 'MYNS-test-NAT'"
    ).strip()
    assert nat_jumps == "1", f"Expected one IPv4 NAT jump, got {nat_jumps}"
    fwd_jumps = host.succeed("iptables -S FORWARD | grep -c 'MYNS-test-FWD'").strip()
    assert fwd_jumps == "2", f"Expected two IPv4 FORWARD jumps (-i/-o), got {fwd_jumps}"
    nat6_jumps = host.succeed(
        "ip6tables -t nat -S PREROUTING | grep -c 'MYNS-test-NAT'"
    ).strip()
    assert nat6_jumps == "1", f"Expected one IPv6 NAT jump, got {nat6_jumps}"


def _assert_partial_startup_cleanup(host: "Machine") -> None:
    host.succeed("systemctl stop failcore.service")
    host.succeed(
        "systemctl set-environment MY_NETWORK_NAMESPACES_FAIL_AFTER_CORE=failcore"
    )
    _fail(
        host,
        "systemctl start failcore.service",
        "Controlled failcore startup must fail after core state exists",
    )
    host.succeed("systemctl unset-environment MY_NETWORK_NAMESPACES_FAIL_AFTER_CORE")

    host.succeed("! ip netns list | grep -q '^failcore '")
    host.succeed("! ip link show nnh-failcore")
    host.succeed("! iptables -S | grep -q 'MYNS-failcore'")
    host.succeed("! iptables -t nat -S | grep -q 'MYNS-failcore'")
    host.succeed("! ip6tables -S | grep -q 'MYNS-failcore'")
    host.succeed("! ip6tables -t nat -S | grep -q 'MYNS-failcore'")

    host.succeed("systemctl start failcore.service")
    host.wait_for_unit("failcore.service")
    netns_count = host.succeed("ip netns list | grep -c '^failcore '").strip()
    assert netns_count == "1", (
        f"Expected one recovered failcore namespace, got {netns_count}"
    )


def run(driver_globals: dict[str, object]) -> None:
    """Run network_namespaces integration assertions."""
    _start_all(driver_globals)
    host = cast("Machine", driver_globals["host"])
    probe = cast("Machine", driver_globals["probe"])

    host.wait_for_unit("multi-user.target")
    probe.wait_for_unit("multi-user.target")
    host.wait_for_unit("test.service")
    host.wait_for_unit("failcore.service")

    # 1. Service attachment proves systemd services actually run inside the namespace.
    _assert_service_attachment(host, probe)

    # 2. DNS checks prove the resolver mount works and strict DNS blocks are meaningful.
    _assert_dns_policy(host, probe)

    # 3. Port mappings prove IPv4/IPv6 TCP, UDP, and mixed-protocol host ingress.
    _assert_port_mappings(probe, host)

    # 4. Fail-closed behavior ensures unavailable namespaces do not fall back to host networking.
    _assert_fail_closed(host, probe)

    # 5. Restart/idempotency checks make repeated setup safe and non-duplicating.
    _assert_restart_idempotency(host, probe)

    # 6. Controlled partial failure proves cleanup runs before the next successful start.
    _assert_partial_startup_cleanup(host)
