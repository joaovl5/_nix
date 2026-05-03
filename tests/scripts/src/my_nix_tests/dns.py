"""Integration test: Pi-hole, OctoDNS, and Traefik stay local and deterministic."""

from __future__ import annotations

import json
import shlex
import urllib.parse
from typing import TYPE_CHECKING, cast

if TYPE_CHECKING:
    from collections.abc import Callable

    from nix_machine_protocol import Machine

RESOLVER_IP = "192.0.2.2"
TEST_TLD = "vm.test"
PIHOLE_PASSWORD = "dns-suite-password"
PIHOLE_API = "http://127.0.0.1:1111/api"
CA_CERT_PATH = "/etc/dns-test/ca.pem"

ALPHA_HOST = f"alpha.{TEST_TLD}"
BETA_HOST = f"beta.{TEST_TLD}"
ALPHA_BODY = "dns-suite-alpha-body"
BETA_BODY = "dns-suite-beta-body"

LONG_RUNNING_UNITS = (
    "pihole-ftl.service",
    "traefik.service",
    "dns-test-fixture.service",
    "dns-backend-alpha.service",
    "dns-backend-beta.service",
)


def _q(value: str) -> str:
    return shlex.quote(value)


def _start_all(driver_globals: dict[str, object]) -> None:
    start_all = driver_globals.get("start_all")
    if callable(start_all):
        cast("Callable[[], None]", start_all)()


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


def _systemd_property(machine: "Machine", unit: str, prop: str) -> str:
    return _succeed(
        machine,
        f"systemctl show -P {prop} {_q(unit)}",
        f"Failed to read {prop} for {unit}",
    )


def _wait_for_successful_oneshot(
    machine: "Machine", unit: str, *, require_zero_exit: bool
) -> None:
    _wait_until_succeeds(
        machine,
        f'test "$(systemctl show -P ExecMainStartTimestampMonotonic {_q(unit)})" != 0',
        f"{unit} never started",
    )
    _wait_until_succeeds(
        machine,
        f'test "$(systemctl show -P Result {_q(unit)})" = success',
        f"{unit} did not report Result=success",
    )
    if require_zero_exit:
        exec_status = _systemd_property(machine, unit, "ExecMainStatus")
        assert exec_status == "0", (
            f"{unit} should exit 0 in the DNS suite, got ExecMainStatus={exec_status!r}"
        )


def _curl_json(machine: "Machine", command: str, message: str) -> object:
    output = _succeed(machine, command, message)
    try:
        return json.loads(output)
    except json.JSONDecodeError as exc:
        raise AssertionError(f"{message}: response was not JSON\n{output}") from exc


def _assert_pihole_api_auth(resolver: "Machine") -> None:
    # Pi-hole keeps some informational endpoints readable even with auth enabled, so the
    # reliable proof here is that the deterministic password yields a valid authenticated SID.
    auth_payload = _curl_json(
        resolver,
        " ".join(
            [
                "curl",
                "--silent",
                "--show-error",
                "--fail",
                "-H",
                _q("Content-Type: application/json"),
                "--data",
                _q(json.dumps({"password": PIHOLE_PASSWORD})),
                _q(f"{PIHOLE_API}/auth"),
            ]
        ),
        "Pi-hole authentication request failed",
    )
    assert isinstance(auth_payload, dict), (
        f"Pi-hole auth response should be a JSON object, got {type(auth_payload)!r}"
    )
    session = auth_payload.get("session")
    assert isinstance(session, dict), (
        f"Pi-hole auth response missing session: {auth_payload!r}"
    )
    sid = session.get("sid")
    assert isinstance(sid, str) and sid, (
        f"Pi-hole auth response missing sid: {auth_payload!r}"
    )

    version_payload = _curl_json(
        resolver,
        " ".join(
            [
                "curl",
                "--silent",
                "--show-error",
                "--fail",
                _q(f"{PIHOLE_API}/info/version?sid={urllib.parse.quote(sid, safe='')}"),
            ]
        ),
        "Pi-hole authenticated version request failed",
    )
    assert isinstance(version_payload, dict), (
        f"Pi-hole authenticated version response should be a JSON object, got {type(version_payload)!r}"
    )
    assert "error" not in version_payload, (
        f"Pi-hole authenticated request returned error: {version_payload!r}"
    )


def _assert_dns_answer(probe: "Machine", hostname: str, expected: str) -> None:
    answer = _succeed(
        probe,
        f"dig +short @{RESOLVER_IP} {_q(hostname)} A",
        f"DNS lookup for {hostname} failed",
    )
    assert answer.splitlines() == [expected], (
        f"DNS answer for {hostname} should be exactly {expected!r}, got {answer!r}"
    )


def _assert_missing_name(probe: "Machine") -> None:
    answer = _succeed(
        probe,
        f"dig +short @{RESOLVER_IP} {_q(f'missing.{TEST_TLD}')} A",
        "Missing-name DNS lookup failed",
    )
    assert answer == "", f"Undeclared hostname should not resolve, got {answer!r}"


def _assert_https_route(probe: "Machine", hostname: str, expected_body: str) -> None:
    _succeed(
        probe,
        " ".join(
            [
                "openssl",
                "s_client",
                "-verify_return_error",
                "-verify_hostname",
                _q(hostname),
                "-servername",
                _q(hostname),
                "-CAfile",
                _q(CA_CERT_PATH),
                "-connect",
                _q(f"{RESOLVER_IP}:443"),
                "</dev/null >/tmp/dns-suite-openssl.log",
            ]
        ),
        f"TLS verification failed for {hostname}",
    )
    body = _succeed(
        probe,
        " ".join(
            [
                "curl",
                "--silent",
                "--show-error",
                "--fail",
                "--cacert",
                _q(CA_CERT_PATH),
                _q(f"https://{hostname}/"),
            ]
        ),
        f"HTTPS request failed for {hostname}",
    )
    assert body == expected_body, (
        f"HTTPS body for {hostname} should be {expected_body!r}, got {body!r}"
    )


def _assert_no_cloudflare_path(resolver: "Machine") -> None:
    assert _systemd_property(resolver, "octodns-sync.service", "FragmentPath"), (
        "octodns-sync.service should be materialized"
    )
    _fail(
        resolver,
        "systemctl cat octodns-sync.service | grep -q CLOUDFLARE_TOKEN",
        "octodns-sync should not require a Cloudflare token in this VM path",
    )
    _fail(
        resolver,
        "systemctl cat traefik.service | grep -q /run/traefik/env",
        "Traefik should not require the ACME Cloudflare env file in local TLS mode",
    )
    _succeed(
        resolver,
        "test ! -e /run/secrets/cloudflare_api_token",
        "Cloudflare token secret should not be required in the DNS suite",
    )


def run(driver_globals: dict[str, object]) -> None:
    resolver = cast("Machine", driver_globals["resolver"])
    probe = cast("Machine", driver_globals["probe"])

    _start_all(driver_globals)

    # Phase 1: wait for the long-running fixtures that everything else depends on.
    for unit in LONG_RUNNING_UNITS:
        resolver.wait_for_unit(unit)

    # Phase 2: prove setup oneshots completed successfully instead of relying on remain-active state.
    _wait_for_successful_oneshot(
        resolver,
        "pihole-ftl-setup.service",
        require_zero_exit=True,
    )
    resolver.wait_for_unit("octodns-sync.service")
    _wait_for_successful_oneshot(
        resolver,
        "octodns-sync.service",
        require_zero_exit=True,
    )

    # Phase 3: prove Pi-hole API auth works with the deterministic password and local-only config.
    _assert_pihole_api_auth(resolver)

    # Phase 4: prove the declared vhosts resolve through Pi-hole/OctoDNS and undeclared names do not.
    _assert_dns_answer(probe, ALPHA_HOST, RESOLVER_IP)
    _assert_dns_answer(probe, BETA_HOST, RESOLVER_IP)
    _assert_missing_name(probe)

    # Phase 5: prove Traefik serves the expected backend over verified HTTPS for each vhost.
    _assert_https_route(probe, ALPHA_HOST, ALPHA_BODY)
    _assert_https_route(probe, BETA_HOST, BETA_BODY)

    # Phase 6: prove this VM path stayed off the Cloudflare/acme branch entirely.
    _assert_no_cloudflare_path(resolver)
