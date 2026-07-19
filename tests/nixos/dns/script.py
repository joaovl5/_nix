"""Integration test: Pi-hole, OctoDNS, and Traefik stay local and deterministic."""

import json
import shlex
import urllib.parse
from typing import Protocol, runtime_checkable

from nix_machine_protocol import Machine as _MachineProtocol


@runtime_checkable
class Machine(_MachineProtocol, Protocol):
  """Runtime-checkable view of the NixOS VM driver protocol."""


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


def _require_machine(
  *, globals_dict: dict[str, object], key: str
) -> Machine:
  """Return a required VM driver object from the driver globals."""
  value = globals_dict[key]
  assert isinstance(value, Machine), (
    f"Expected Machine for {key}, got {type(value)!r}"
  )
  return value


def _q(*, value: str) -> str:
  """Shell-quote a value for guest command execution."""
  return shlex.quote(value)


def _start_all(*, driver_globals: dict[str, object]) -> None:
  """Start every VM declared by the driver when that helper is available."""
  start_all = driver_globals.get("start_all")
  if callable(start_all):
    start_all()


def _succeed(*, machine: Machine, command: str, message: str) -> str:
  """Run a command and reframe driver failures as assertion failures."""
  try:
    return machine.succeed(command).strip()
  except (
    Exception
  ) as exc:  # pragma: no cover - integration-driver surface
    raise AssertionError(f"{message}: {command}") from exc


def _fail(*, machine: Machine, command: str, message: str) -> str:
  """Run a command and assert that it fails."""
  status, output = machine.execute(command)
  # Negative-path checks must actually fail rather than succeed silently.
  assert status != 0, (
    f"{message}. Command unexpectedly succeeded: {command}\n{output}"
  )
  return output.strip()


def _wait_until_succeeds(
  *, machine: Machine, command: str, message: str
) -> None:
  """Wait for a command to start succeeding, surfacing driver errors clearly."""
  try:
    machine.wait_until_succeeds(command)
  except (
    Exception
  ) as exc:  # pragma: no cover - integration-driver surface
    raise AssertionError(f"{message}: {command}") from exc


def _systemd_property(
  *, machine: Machine, unit: str, prop: str
) -> str:
  """Read a single systemd property from the resolver VM."""
  return _succeed(
    machine=machine,
    command=f"systemctl show -P {prop} {_q(value=unit)}",
    message=f"Failed to read {prop} for {unit}",
  )


def _wait_for_successful_oneshot(
  *, machine: Machine, unit: str, require_zero_exit: bool
) -> None:
  """Wait for a oneshot unit to finish successfully."""
  _wait_until_succeeds(
    machine=machine,
    command=f'test "$(systemctl show -P ExecMainStartTimestampMonotonic {_q(value=unit)})" != 0',
    message=f"{unit} never started",
  )
  _wait_until_succeeds(
    machine=machine,
    command=f'test "$(systemctl show -P Result {_q(value=unit)})" = success',
    message=f"{unit} did not report Result=success",
  )
  if require_zero_exit:
    exec_status = _systemd_property(
      machine=machine, unit=unit, prop="ExecMainStatus"
    )
    # Setup oneshots in this suite must exit with status zero.
    assert exec_status == "0", (
      f"{unit} should exit 0 in the DNS suite, got ExecMainStatus={exec_status!r}"
    )


def _curl_json(
  *, machine: Machine, command: str, message: str
) -> object:
  """Run curl and parse the response body as JSON."""
  output = _succeed(machine=machine, command=command, message=message)
  try:
    return json.loads(output)
  except json.JSONDecodeError as exc:
    raise AssertionError(
      f"{message}: response was not JSON\n{output}"
    ) from exc


def _assert_pihole_api_auth(*, resolver: Machine) -> None:
  """Assert that Pi-hole auth works with the deterministic test password."""
  # Pi-hole keeps some informational endpoints readable even with auth enabled, so the
  # reliable proof here is that the deterministic password yields a valid authenticated SID.
  auth_payload = _curl_json(
    machine=resolver,
    command=" ".join(
      [
        "curl",
        "--silent",
        "--show-error",
        "--fail",
        "-H",
        _q(value="Content-Type: application/json"),
        "--data",
        _q(value=json.dumps({"password": PIHOLE_PASSWORD})),
        _q(value=f"{PIHOLE_API}/auth"),
      ]
    ),
    message="Pi-hole authentication request failed",
  )
  # Auth must return an object so the session payload can be inspected.
  assert isinstance(auth_payload, dict), (
    f"Pi-hole auth response should be a JSON object, got {type(auth_payload)!r}"
  )
  session = auth_payload.get("session")
  # Auth must include a nested session object.
  assert isinstance(session, dict), (
    f"Pi-hole auth response missing session: {auth_payload!r}"
  )
  sid = session.get("sid")
  # Auth must return a non-empty session id for subsequent authenticated requests.
  assert isinstance(sid, str) and sid, (
    f"Pi-hole auth response missing sid: {auth_payload!r}"
  )

  version_payload = _curl_json(
    machine=resolver,
    command=" ".join(
      [
        "curl",
        "--silent",
        "--show-error",
        "--fail",
        _q(
          value=f"{PIHOLE_API}/info/version?sid={urllib.parse.quote(sid, safe='')}"
        ),
      ]
    ),
    message="Pi-hole authenticated version request failed",
  )
  # The authenticated version endpoint must also return a JSON object.
  assert isinstance(version_payload, dict), (
    f"Pi-hole authenticated version response should be a JSON object, got {type(version_payload)!r}"
  )
  # A successful authenticated request must not report an API error.
  assert "error" not in version_payload, (
    f"Pi-hole authenticated request returned error: {version_payload!r}"
  )


def _assert_dns_answer(
  *, probe: Machine, hostname: str, expected: str
) -> None:
  """Assert that the resolver returns exactly one A record."""
  answer = _succeed(
    machine=probe,
    command=f"dig +short @{RESOLVER_IP} {_q(value=hostname)} A",
    message=f"DNS lookup for {hostname} failed",
  )
  # Each declared host must resolve to the resolver VM and nothing else.
  assert answer.splitlines() == [expected], (
    f"DNS answer for {hostname} should be exactly {expected!r}, got {answer!r}"
  )


def _assert_missing_name(*, probe: Machine) -> None:
  """Assert that undeclared names do not resolve."""
  answer = _succeed(
    machine=probe,
    command=f"dig +short @{RESOLVER_IP} {_q(value=f'missing.{TEST_TLD}')} A",
    message="Missing-name DNS lookup failed",
  )
  # Undeclared names must return no A records.
  assert answer == "", (
    f"Undeclared hostname should not resolve, got {answer!r}"
  )


def _assert_https_route(
  *, probe: Machine, hostname: str, expected_body: str
) -> None:
  """Assert that the local TLS route serves the expected backend response."""
  _succeed(
    machine=probe,
    command=" ".join(
      [
        "openssl",
        "s_client",
        "-verify_return_error",
        "-verify_hostname",
        _q(value=hostname),
        "-servername",
        _q(value=hostname),
        "-CAfile",
        _q(value=CA_CERT_PATH),
        "-connect",
        _q(value=f"{RESOLVER_IP}:443"),
        "</dev/null >/tmp/dns-suite-openssl.log",
      ]
    ),
    message=f"TLS verification failed for {hostname}",
  )
  body = _succeed(
    machine=probe,
    command=" ".join(
      [
        "curl",
        "--silent",
        "--show-error",
        "--fail",
        "--cacert",
        _q(value=CA_CERT_PATH),
        _q(value=f"https://{hostname}/"),
      ]
    ),
    message=f"HTTPS request failed for {hostname}",
  )
  # Each HTTPS vhost must serve the exact backend body assigned to it.
  assert body == expected_body, (
    f"HTTPS body for {hostname} should be {expected_body!r}, got {body!r}"
  )


def _assert_no_cloudflare_path(*, resolver: Machine) -> None:
  """Assert that the local DNS test path stays off the Cloudflare branch."""
  # The local DNS path should materialize the local octodns-sync unit.
  assert _systemd_property(
    machine=resolver,
    unit="octodns-sync.service",
    prop="FragmentPath",
  ), "octodns-sync.service should be materialized"
  _fail(
    machine=resolver,
    command="systemctl cat octodns-sync.service | grep -q CLOUDFLARE_TOKEN",
    message="octodns-sync should not require a Cloudflare token in this VM path",
  )
  _fail(
    machine=resolver,
    command="systemctl cat traefik.service | grep -q /run/traefik/env",
    message="Traefik should not require the ACME Cloudflare env file in local TLS mode",
  )
  _succeed(
    machine=resolver,
    command="test ! -e /run/secrets/cloudflare_api_token",
    message="Cloudflare token secret should not be required in the DNS suite",
  )


def run(*, driver_globals: dict[str, object]) -> None:
  """Run DNS integration assertions."""
  resolver = _require_machine(
    globals_dict=driver_globals, key="resolver"
  )
  probe = _require_machine(globals_dict=driver_globals, key="probe")

  _start_all(driver_globals=driver_globals)

  # Phase 1: wait for the long-running fixtures that everything else depends on.
  for unit in LONG_RUNNING_UNITS:
    resolver.wait_for_unit(unit)

  # Phase 2: prove setup oneshots completed successfully instead of relying on remain-active state.
  _wait_for_successful_oneshot(
    machine=resolver,
    unit="pihole-ftl-setup.service",
    require_zero_exit=True,
  )
  resolver.wait_for_unit("octodns-sync.service")
  _wait_for_successful_oneshot(
    machine=resolver,
    unit="octodns-sync.service",
    require_zero_exit=True,
  )

  # Phase 3: prove Pi-hole API auth works with the deterministic password and local-only config.
  _assert_pihole_api_auth(resolver=resolver)

  # Phase 4: prove the declared vhosts resolve through Pi-hole/OctoDNS and undeclared names do not.
  _assert_dns_answer(
    probe=probe, hostname=ALPHA_HOST, expected=RESOLVER_IP
  )
  _assert_dns_answer(
    probe=probe, hostname=BETA_HOST, expected=RESOLVER_IP
  )
  _assert_missing_name(probe=probe)

  # Phase 5: prove Traefik serves the expected backend over verified HTTPS for each vhost.
  _assert_https_route(
    probe=probe, hostname=ALPHA_HOST, expected_body=ALPHA_BODY
  )
  _assert_https_route(
    probe=probe, hostname=BETA_HOST, expected_body=BETA_BODY
  )

  # Phase 6: prove this VM path stayed off the Cloudflare/acme branch entirely.
  _assert_no_cloudflare_path(resolver=resolver)
