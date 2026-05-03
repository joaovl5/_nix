# Network/VPN case study: WireGuard integration suite

This reference captures lessons from this repo's WireGuard integration suite. Generalize assertion-quality patterns; do not turn every networking detail into a universal rule.

## Scenario shape

The WireGuard suite uses three VMs:

- `relay`: public/shared-network relay plus WireGuard host peer.
- `isolated`: host peer plus a separate namespace/client peer.
- `probe`: external observer, DNS server, and leak-listener host.

The suite tests:

- relay ingress over TCP, UDP, and `both`;
- plain versus confined source identities;
- all-traffic/default-route behavior;
- DNS allow/deny behavior;
- host-to-namespace `port_mappings`;
- `open_vpn_ports` reachable via the VPN interface;
- startup and mid-flight fail-closed behavior;
- restart/idempotency;
- IPv6 host-to-namespace TCP, UDP, and `both` port mappings with listener source-address evidence.

## Lessons worth generalizing

- Use deterministic topology: fixed keys, fixed addresses, fixed ports.
- Use toy services when testing infrastructure behavior.
- Make every negative assertion prove its listener/control path first.
- Assert source identity when routing/NAT/confinement is the behavior.
- Use per-attempt tokens for network tests to avoid stale-log false positives.
- Document known limitations inline where they are asserted.
- Recovery tests should re-prove the important behavior after restart, not just inspect unit state.

## WireGuard-specific caveats

- `port_mappings` and `open_vpn_ports` are distinct concepts.
  - `port_mappings`: host/shared-network ingress DNAT into the namespace.
  - `open_vpn_ports`: inbound traffic arriving via the WireGuard interface.
- `accessible_from` is route-exception behavior, not merely an allowlist.
- DNS isolation has multiple layers: namespace resolver file, resolver socket hiding, firewall policy, and explicit blocked endpoints.
- ICMP/ping can be useful as a startup gate but is not sufficient readiness proof for WireGuard traffic.
- IPv6 host-to-namespace mappings must be tested as first-class supported behavior:
  - TCP, UDP, and dual-protocol mappings should echo through the mapped host address.
  - The listener log should prove the expected source address, not just command success.
  - If a node has multiple IPv6 fixture addresses, bind the test client source explicitly so leak-sentinel addresses do not accidentally exercise a different route.

## Useful source docs

- WireGuard network namespace pattern: https://www.wireguard.com/netns/
- Linux network namespaces: https://www.man7.org/linux/man-pages/man7/network_namespaces.7.html
- `ip-netns(8)`: https://man7.org/linux/man-pages/man8/ip-netns.8.html
- systemd `NetworkNamespacePath=`: https://www.freedesktop.org/software/systemd/man/latest/systemd.exec.html#NetworkNamespacePath=
- NixOS containers module source: https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/virtualisation/nixos-containers.nix
- VPN-Confinement upstream: https://github.com/Maroka-chan/VPN-Confinement
