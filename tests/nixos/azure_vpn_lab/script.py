"""Integration test: Azure-like P2S IKEv2 certificate VPN with private resource access."""

import itertools

from common import (  # pyright: ignore[reportImplicitRelativeImport]
  Machine,
  fail,
  q,
  repeat_until_succeeds,
  require_machine,
  succeed,
)

GATEWAY_FQDN = "azure-vpn-gateway.test"
CLIENT_ID = "azure-vpn-client.test"
GATEWAY_PUBLIC_IP = "192.0.2.1"
CLIENT_PUBLIC_IP = "192.0.2.2"
PRIVATE_RESOURCE_IP = "198.51.100.5"
PRIVATE_RESOURCE_NAME = "private-resource.azure-vpn.test"
PRIVATE_SUBNET = "198.51.100.0/24"
P2S_POOL_PREFIX = "172.31.200."
RESOURCE_PORT = 18080
RESOURCE_LOG = "/run/azure-vpn-lab/resource.log"

_TOKEN_COUNTER = itertools.count(1)


def _token(prefix: str) -> str:
  """Return a unique token for resource listener assertions."""
  return f"{prefix}-{next(_TOKEN_COUNTER):04d}"


def _resource_url(host: str, token: str) -> str:
  """Return the HTTP URL used by the private resource fixture."""
  return f"http://{host}:{RESOURCE_PORT}/?token={token}"


def _curl_resource(machine: Machine, host: str, token: str) -> str:
  """Fetch the private resource fixture and return its token/source body."""
  return succeed(
    machine,
    "curl --fail --silent --show-error --connect-timeout 3 --max-time 6 "
    f"{q(_resource_url(host, token))}",
    f"Failed to reach private resource at {host}",
  )


def _clear_resource_log(resource: Machine) -> None:
  """Clear the private resource listener log before a token-scoped probe."""
  succeed(resource, f": > {q(RESOURCE_LOG)}", "Failed to clear resource log")


def _read_resource_log(resource: Machine) -> str:
  """Read the private resource listener log."""
  return succeed(
    resource, f"cat {q(RESOURCE_LOG)}", "Failed to read resource log"
  )


def _assert_log_has_source(
  resource: Machine, token: str, source_prefix: str, message: str
) -> None:
  """Assert that the private resource saw a token from the expected source range."""
  log = _read_resource_log(resource)
  matching_lines = [
    line for line in log.splitlines() if line.startswith(f"{token} ")
  ]
  assert matching_lines, (
    f"{message}: token {token!r} missing from resource log\n{log}"
  )
  assert any(
    line.split()[1].startswith(source_prefix) for line in matching_lines
  ), (
    f"{message}: expected source prefix {source_prefix!r}, got {matching_lines!r}"
  )


def _assert_log_lacks_token(
  resource: Machine, token: str, message: str
) -> None:
  """Assert that a denied probe never reached the private resource listener."""
  log = _read_resource_log(resource)
  assert token not in log, (
    f"{message}: token {token!r} unexpectedly present\n{log}"
  )


def _assert_resource_listener_preflight(resource: Machine) -> None:
  """Prove the private resource listener and log are working before denial checks."""
  token = _token("resource-control")
  _clear_resource_log(resource)
  body = _curl_resource(resource, PRIVATE_RESOURCE_IP, token)
  assert body == f"{token} {PRIVATE_RESOURCE_IP}", (
    f"Resource self-preflight returned unexpected body: {body!r}"
  )
  _assert_log_has_source(
    resource,
    token,
    PRIVATE_RESOURCE_IP,
    "Resource listener preflight must log local control traffic",
  )


def _assert_no_direct_private_path(
  client: Machine, resource: Machine
) -> None:
  """Assert the client cannot reach the private VNet resource without the VPN gateway."""
  token = _token("pre-vpn-denied")
  _clear_resource_log(resource)
  fail(
    client,
    "curl --fail --silent --show-error --connect-timeout 2 --max-time 4 "
    f"{q(_resource_url(PRIVATE_RESOURCE_IP, token))}",
    "Client must not have a direct non-VPN path to the private resource",
  )
  _assert_log_lacks_token(
    resource,
    token,
    "Denied pre-VPN client probe must not reach the private resource listener",
  )


def _assert_client_static_name_resolution(client: Machine) -> None:
  """Assert NixOS declarative hosts records replace ad-hoc macOS /etc/hosts edits."""
  resource_hosts = succeed(
    client,
    f"getent hosts {q(PRIVATE_RESOURCE_NAME)}",
    "Client did not resolve the private Azure resource name",
  )
  assert PRIVATE_RESOURCE_IP in resource_hosts, (
    f"Expected {PRIVATE_RESOURCE_NAME} to resolve to {PRIVATE_RESOURCE_IP}, got {resource_hosts!r}"
  )
  gateway_hosts = succeed(
    client,
    f"getent hosts {q(GATEWAY_FQDN)}",
    "Client did not resolve the Azure gateway FQDN",
  )
  assert GATEWAY_PUBLIC_IP in gateway_hosts, (
    f"Expected {GATEWAY_FQDN} to resolve to {GATEWAY_PUBLIC_IP}, got {gateway_hosts!r}"
  )


def _assert_rendered_azure_identity_config(client: Machine) -> None:
  """Assert the module renders swanctl from runtime secret paths."""
  root_config = succeed(
    client,
    "cat /etc/swanctl/swanctl.conf",
    "Failed to read root swanctl config",
  )
  assert "include /run/azure-vpn/swanctl.conf" in root_config, (
    f"Root swanctl config does not include runtime Azure VPN config\n{root_config}"
  )

  rendered = succeed(
    client,
    "cat /run/azure-vpn/swanctl.conf",
    "Failed to read rendered Azure VPN swanctl config",
  )
  expected_fragments = [
    "version = 2",
    f"remote_addrs = {GATEWAY_FQDN}",
    "vips = 0.0.0.0",
    f"id = {CLIENT_ID}",
    f"id = {GATEWAY_FQDN}",
    f"remote_ts = {PRIVATE_SUBNET}",
    "esp_proposals = aes256gcm16",
    "start_action = start",
  ]
  for fragment in expected_fragments:
    assert fragment in rendered, (
      f"Missing swanctl fragment {fragment!r}\n{rendered}"
    )


def _initiate_or_observe_tunnel(client: Machine) -> None:
  """Ensure the client has an active CHILD_SA after the responder is available."""
  repeat_until_succeeds(
    client,
    "swanctl --list-sas | grep -F 'azure-vnet' || swanctl --initiate --child azure-vnet",
    "Azure VPN CHILD_SA did not establish",
  )


def _assert_tunnel_state(client: Machine, gateway: Machine) -> None:
  """Assert IKE/CHILD SAs, virtual IP, and kernel XFRM state are present."""
  for machine, role in [(client, "client"), (gateway, "gateway")]:
    sas = succeed(
      machine, "swanctl --list-sas", f"Failed to list SAs on {role}"
    )
    assert "azure-p2s" in sas and "ESTABLISHED" in sas, (
      f"{role} does not show an established azure-p2s IKE_SA\n{sas}"
    )
    assert "azure-vnet" in sas, (
      f"{role} does not show azure-vnet CHILD_SA\n{sas}"
    )
    assert "AES_GCM_16-256" in sas or "AES_GCM_16" in sas, (
      f"{role} SA output does not show AES-GCM negotiation\n{sas}"
    )

  vip_output = succeed(
    client,
    f"ip -4 addr show | grep -F {q(P2S_POOL_PREFIX)}",
    "Client did not receive an Azure-like P2S virtual IP",
  )
  assert P2S_POOL_PREFIX in vip_output, (
    f"Unexpected virtual IP output: {vip_output!r}"
  )

  route_output = succeed(
    client,
    f"ip route get {q(PRIVATE_RESOURCE_IP)}",
    "Client could not compute a route to the private resource",
  )
  assert P2S_POOL_PREFIX in route_output, (
    f"Client route to private resource does not use the P2S virtual IP\n{route_output}"
  )

  for machine, role in [(client, "client"), (gateway, "gateway")]:
    xfrm_state = succeed(
      machine, "ip xfrm state", f"Failed to inspect xfrm state on {role}"
    )
    assert (
      GATEWAY_PUBLIC_IP in xfrm_state and CLIENT_PUBLIC_IP in xfrm_state
    ), (
      f"{role} xfrm state lacks expected public tunnel endpoints\n{xfrm_state}"
    )
    xfrm_policy = succeed(
      machine, "ip xfrm policy", f"Failed to inspect xfrm policy on {role}"
    )
    assert (
      PRIVATE_SUBNET in xfrm_policy or PRIVATE_RESOURCE_IP in xfrm_policy
    ), (
      f"{role} xfrm policy lacks protected private subnet evidence\n{xfrm_policy}"
    )


def _assert_private_resource_over_vpn(
  client: Machine, resource: Machine
) -> None:
  """Assert named private resource traffic crosses the VPN and uses the client VIP."""
  token = _token("vpn-resource")
  _clear_resource_log(resource)
  body = _curl_resource(client, PRIVATE_RESOURCE_NAME, token)
  assert body.startswith(f"{token} {P2S_POOL_PREFIX}"), (
    f"Private resource saw unexpected VPN response body: {body!r}"
  )
  _assert_log_has_source(
    resource,
    token,
    P2S_POOL_PREFIX,
    "Private resource must see the client P2S virtual IP as source",
  )


def _assert_restart_keeps_vpn_recoverable(
  client: Machine, resource: Machine
) -> None:
  """Assert client-side strongSwan restart recovers functional VPN traffic."""
  succeed(
    client,
    "systemctl restart strongswan-swanctl.service",
    "Failed to restart client VPN",
  )
  client.wait_for_unit("strongswan-swanctl.service")
  _initiate_or_observe_tunnel(client)
  _assert_private_resource_over_vpn(client, resource)


def run(*, driver_globals: dict[str, object]) -> None:
  """Run Azure VPN lab assertions."""
  gateway = require_machine(driver_globals, "gateway")
  client = require_machine(driver_globals, "client")
  resource = require_machine(driver_globals, "resource")

  # Start the private resource and client first to prove there is no direct VNet path
  # before the Azure-like VPN gateway responder exists.
  resource.start()
  client.start()
  resource.wait_for_unit("azure-private-resource.service")
  client.wait_for_unit("strongswan-swanctl.service")

  _assert_client_static_name_resolution(client)
  _assert_rendered_azure_identity_config(client)
  _assert_resource_listener_preflight(resource)
  _assert_no_direct_private_path(client, resource)

  gateway.start()
  gateway.wait_for_unit("strongswan-swanctl.service")
  _initiate_or_observe_tunnel(client)
  _assert_tunnel_state(client, gateway)
  _assert_private_resource_over_vpn(client, resource)
  _assert_restart_keeps_vpn_recoverable(client, resource)
