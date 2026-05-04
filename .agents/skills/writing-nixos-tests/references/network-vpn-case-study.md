# Network and VPN case study: WireGuard integration suite

This reference captures reusable lessons from this repo's WireGuard suite. Treat these as patterns to adapt, not universal networking rules

## Scenario shape

- **VM roles:** the suite uses three VMs
  - **Relay:** public or shared-network relay plus the host-side WireGuard peer
  - **Isolated:** host peer plus a separate namespace or client peer
  - **Probe:** external observer, DNS server, and leak-listener host

- **Coverage:**
  - **Ingress paths:** relay ingress over TCP, UDP, and `both`
  - **Source identity:** plain versus confined source addresses
  - **Default route behavior:** all-traffic and default-route cases
  - **DNS controls:** allow and deny behavior
  - **Port mapping:** host-to-namespace `port_mappings`
  - **VPN ingress:** `open_vpn_ports` reachable over the WireGuard interface
  - **Fail-closed checks:** startup and mid-flight failure cases
  - **Restart checks:** restart and idempotency behavior
  - **IPv6 support:** host-to-namespace TCP, UDP, and `both` mappings
  - **Source proof:** listener evidence should confirm the source address

## Lessons worth generalizing

- **Deterministic topology:** use fixed keys, addresses, and ports
- **Toy services help:** prefer small fixtures when testing infrastructure behavior
- **Preflight negatives:** prove the listener or control path before relying on absence
- **Source matters:** assert source identity when routing, NAT, or confinement is under test
- **Fresh tokens:** use per-attempt tokens to avoid stale-log false positives
- **State limitations plainly:** document known limitations inline where they are asserted
- **Recovery must re-prove behavior:** after restart, recheck the important path instead of only unit state

## WireGuard-specific caveats

- **Distinct ingress concepts:** `port_mappings` and `open_vpn_ports` are different behaviors
  - **`port_mappings`:** host or shared-network ingress DNATs into the namespace
  - **`open_vpn_ports`:** inbound traffic arrives over the WireGuard interface
- **Route exceptions:** `accessible_from` is route-exception behavior, not just an allowlist
- **Layered DNS isolation:** resolver file choice, socket hiding, firewall policy, and blocked endpoints can all matter
- **Ping is weak readiness:** using ICMP can help as a startup gate
  - **Proof:** it is not enough evidence for WireGuard traffic
- **IPv6 is first-class here:** test TCP, UDP, and dual-protocol mappings when the suite claims them
- **Source proof still required:** listener logs should prove the expected source address
- **Bind explicit IPv6 sources:** if a node has multiple fixture addresses, bind the client source explicitly
  - **Reason:** that keeps leak-sentinel addresses from taking a different route

## Useful source docs

- **WireGuard netns pattern:** https://www.wireguard.com/netns/
- **Network namespaces:** https://www.man7.org/linux/man-pages/man7/network_namespaces.7.html
- **`ip-netns(8)`:** https://man7.org/linux/man-pages/man8/ip-netns.8.html
- **`NetworkNamespacePath=`:** https://www.freedesktop.org/software/systemd/man/latest/systemd.exec.html#NetworkNamespacePath=
- **Containers module source:** https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/virtualisation/nixos-containers.nix
- **VPN-Confinement upstream:** https://github.com/Maroka-chan/VPN-Confinement
