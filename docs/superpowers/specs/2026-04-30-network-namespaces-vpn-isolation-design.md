# Network Namespaces and VPN Isolation Design

> **For agentic workers:** REQUIRED: read `.agents/skills/writing-nixos-tests/SKILL.md` before editing NixOS VM tests for this design. Use subagent-driven development for implementation and read-only review subagents for design/implementation review loops.

**Goal:** Replace `unit.wireguard`'s direct dependency on external VPN-Confinement with a repo-owned `my.network_namespaces` abstraction, while keeping container-based VPN isolation as a longer-term workload boundary.

**Architecture:** Add a generic service-level network namespace core with WireGuard as the first backend. Keep the existing `my."unit.wireguard".client.*` public surface as a compatibility layer over the new `my.network_namespaces` module for the first cut. Prove the new module with a small generic namespace-core VM test and the existing WireGuard suite, updated to require symmetric IPv4/IPv6 port mappings.

**Tech Stack:** NixOS modules, systemd services, `NetworkNamespacePath=`, `BindReadOnlyPaths=`, `iproute2`, WireGuard, `iptables`/`ip6tables` for the first implementation, NixOS VM tests, Python test driver package under `tests/scripts`.

---

## Confirmed decisions

- Near-term direction: implement a repo-owned `my.network_namespaces` module.
- First backend: WireGuard.
- First cut should include a generic namespace core plus WireGuard backend, not a private `unit.wireguard` helper only.
- Keep `my."unit.wireguard".client.*` as a compatibility/caller-facing surface initially, mapping into `my.network_namespaces`.
- Fix IPv6 host-to-namespace `port_mappings` before replacing VPN-Confinement. Do not preserve the current IPv6 TCP/no-delivery and UDP/one-way limitations as final behavior.
- Use `iptables`/`ip6tables` first for the smallest behavior delta; defer nftables as a later backend/migration.
- DNS scope for first cut matches the current suite:
  - configured IPv4/IPv6 resolvers work;
  - raw TCP/UDP DNS/53 to unapproved endpoints is blocked;
  - TCP/UDP DoT/853 is blocked;
  - explicit configured DoH-like endpoints are blocked.
- Keep the top-level `vpnconfinement` flake input temporarily if `nixarr` still follows/needs it, but stop `unit.wireguard` from importing or using it.
- Tests should split into:
  - a small generic `my.network_namespaces` core VM test;
  - the WireGuard backend suite.
- Longer-term container track:
  - support shared VPN gateway and per-container VPN eventually;
  - prototype shared host-managed VPN gateway first.
- Transmission/qBittorrent/torrent-client work remains out of scope for this design and implementation plan.

## Memory and repo evidence

Memory (`memory://root/memory_summary.md`) recommends declarative NixOS containers for isolation and no microvms. This informs the longer-term container track only. Current repo evidence shows container support and design notes, but no established container service framework yet:

- `systems/_bootstrap/host.nix` enables container support.
- `docs/wip/isolation_server.md` discusses native private-network NixOS containers.
- Current implemented VPN isolation is still service-level namespace confinement through `unit.wireguard`.

Therefore this design uses service-level `my.network_namespaces` for the immediate dependency-removal work, and keeps containers as the next architectural track.

---

## Research summary

### VPN-Confinement dependency surface

The locked upstream VPN-Confinement input at rev `a6b2da727853886876fd1081d6bb2880752937f3` is small:

- one namespace service generator;
- one systemd integration module;
- one options module;
- shell scripts using `ip`, `iptables`/`ip6tables`, a bridge, veth pair, WireGuard, and `NetworkNamespacePath`.

This repo uses only a narrow subset:

- `vpnNamespaces.<name>`;
- `systemd.services.<name>.vpnConfinement`;
- `portMappings`;
- `openVPNPorts`;
- resolver-file binding and service attachment behavior.

The repo already owns stricter behavior than upstream for DNS because `unit.wireguard` adds TCP/53, DoT/853, and explicit DoH endpoint blocks. Vendoring upstream unchanged would not preserve the current behavior contract.

### Why not vendor/copy VPN-Confinement

- Upstream is GPL-3.0-only; direct copying imports GPL obligations.
- The code is simple enough to reimplement cleanly from behavior and Linux primitives.
- Current tests have already exposed IPv6 port-mapping limitations that should be fixed, not inherited.

### Why not container-first immediately

Containers are the better long-term isolation boundary when a workload needs filesystem/process/user separation, but they create new repo infrastructure needs:

- naming/IP allocation;
- bind mount and secret conventions;
- backup ownership;
- reverse proxy/raw socket route integration;
- container lifecycle/logging/debugging patterns;
- tests for shared-gateway semantics.

The immediate problem is replacing the external service-level VPN-Confinement dependency. Service-level `my.network_namespaces` is the smaller behavior-preserving step.

---

## Target architecture

### Module boundary

Add a new repo module under:

```text
users/_units/network_namespaces/default.nix
```

Import it from:

```text
users/_units/default.nix
```

Expose options under:

```nix
my.network_namespaces.<name>
```

The module should own:

- named namespace service lifecycle;
- host<->namespace connectivity;
- service attachment to the namespace;
- namespace resolver file;
- DNS egress policy;
- route exceptions for local/approved sources;
- host-to-namespace port mappings;
- VPN-interface open ports;
- restart/idempotency cleanup.

`unit.wireguard.client` becomes a compatibility layer that generates WireGuard config/secrets and maps its existing options into `my.network_namespaces.<namespace>`.

### Initial option shape

The exact option names can be refined during implementation, but the first cut should preserve this conceptual split:

```nix
my.network_namespaces.<name> = {
  enable = true;

  backend = {
    # `none` creates only the namespace core: netns, host<->namespace
    # connectivity, resolver policy, service attachment, port mappings,
    # and lifecycle cleanup. The generic VM test uses this mode so core
    # behavior is not coupled to WireGuard setup.
    type = "none";

    wireguard = {
      config_file = "/run/wireguard/vpn.conf";
      interface_name = "wg0";
      # Used only when backend.type = "wireguard".
    };
  };

  addresses = {
    host_v4 = "10.15.0.5";
    namespace_v4 = "10.15.0.1";
    host_v6 = "fd10:15::5";
    namespace_v6 = "fd10:15::1";
  };

  dns = {
    servers = ["192.0.2.3" "fd00:1::3"];
    strict = {
      enable = true;
      block_doh_endpoints = [
        { family = "ipv4"; address = "192.0.2.30"; port = 18443; }
        { family = "ipv6"; address = "fd00:1::30"; port = 18443; }
      ];
    };
  };

  services = ["some-systemd-service"];

  accessible_from = ["192.0.2.3/32" "fd00:1::3/128"];

  port_mappings = [
    { from = 19080; to = 28080; protocol = "tcp"; }
    { from = 19082; to = 28082; protocol = "udp"; }
    { from = 19084; to = 28084; protocol = "both"; }
  ];

  open_vpn_ports = [
    { port = 55080; protocol = "tcp"; }
    { port = 55082; protocol = "udp"; }
    { port = 55084; protocol = "both"; }
  ];
};
```

### Backend modes

The first implementation must support two backend modes:

- `none`: no VPN interface or default VPN route. This is for the generic namespace-core VM test and for future non-VPN namespace use.
- `wireguard`: configure a WireGuard interface inside the namespace and install VPN default routes.

Backend setup must happen after core-owned namespace/link/firewall state exists so cleanup paths are exercised if backend setup fails.

### Service attachment contract

For every service listed in `services`, generate systemd settings equivalent to:

```nix
systemd.services.<service> = {
  bindsTo = ["<namespace>.service"];
  after = ["<namespace>.service"];
  serviceConfig = {
    NetworkNamespacePath = "/run/netns/<namespace>";
    BindReadOnlyPaths = [
      "/etc/netns/<namespace>/resolv.conf:/etc/resolv.conf:norbind"
    ];
    InaccessiblePaths = ["/run/nscd" "/run/resolvconf"];
  };
};
```

The generated dependency should fail closed: if the namespace unit fails or is unavailable, confined services must not silently start on the host network.

### Namespace lifecycle

Generate one systemd namespace unit per `my.network_namespaces.<name>`:

- `Type = "oneshot"`;
- `RemainAfterExit = true`;
- `ExecStart` creates and configures the namespace;
- `ExecStopPost` removes owned links, namespace state, resolver files, and firewall/NAT rules;
- startup should use traps/cleanup for partial failures;
- teardown should be idempotent and should not silently leave duplicate rules.

The service should create a named namespace visible at:

```text
/run/netns/<name>
```

This preserves debugging with `ip netns exec <name> ...` and keeps test assertions straightforward.

### Generic core responsibilities

The core should not assume WireGuard except where the backend hook requires it.

Core owns:

- namespace creation/deletion;
- loopback setup;
- host<->namespace veth/bridge or direct-veth connectivity;
- namespace resolver file creation;
- service attachment;
- port mappings;
- DNS policy;
- idempotent cleanup;
- route exceptions.

Backend owns:

- VPN interface creation/configuration;
- default route inside namespace;
- any backend-specific readiness check;
- backend-specific open-port interface.

### WireGuard backend responsibilities

The WireGuard backend should:

- read/use a generated WireGuard config file;
- create a WireGuard interface inside the namespace;
- configure IPv4 and IPv6 addresses;
- add default routes for `0.0.0.0/0` and `::/0` when configured;
- preserve route exceptions for `accessible_from`;
- preserve the current reverse-path filtering behavior needed by all-traffic/default-route WireGuard clients (`networking.firewall.checkReversePath = "loose"`) or replace it with a proven equivalent scoped exemption;
- expose `open_vpn_ports` on the WireGuard interface;
- avoid ping as the only readiness proof in tests.

`unit.wireguard` should keep owning:

- relay/server behavior;
- peer/secrets/options;
- generated `/run/wireguard/vpn.conf`;
- compatibility mapping from `client.*` into `my.network_namespaces`.

### Firewall backend

First cut: `iptables`/`ip6tables`.

Reasons:

- current tests inspect iptables/ip6tables state;
- current implementation and upstream use iptables/ip6tables;
- nftables would increase blast radius.

Design for future nftables migration by keeping rule generation small and isolated.

### IPv6 host-to-namespace port mappings

The replacement must make IPv6 host-to-namespace mappings symmetric before replacing VPN-Confinement.

Required behavior:

- TCP IPv6 host mapping succeeds and returns response;
- UDP IPv6 host mapping succeeds and returns response;
- `both` mapping succeeds over TCP and UDP;
- wrong protocol paths fail with preflighted denied-listener evidence;
- direct/unmapped paths fail.

The current WireGuard test suite should be updated from "document current VPN-Confinement limitation" to "assert fixed behavior" only after the internal backend implementation is in place.

### DNS behavior

First-cut DNS behavior should match the current suite:

- write `/etc/netns/<name>/resolv.conf` with configured servers;
- bind it into confined services as `/etc/resolv.conf`;
- hide `/run/nscd` and `/run/resolvconf` from confined services;
- allow DNS to configured resolvers;
- reject unapproved TCP/UDP 53;
- reject TCP/UDP 853;
- reject configured explicit DoH-like endpoints.

Do not claim generic DoH blocking. Generic DoH requires a different policy layer.

### Container track

Longer-term design should add a container isolation layer after the service-level replacement is stable.

Preferred prototype:

- shared host-managed VPN namespace/gateway first;
- declarative NixOS container with private networking;
- container egress routed only through the host-managed gateway;
- host-owned bind mounts for secrets/state initially;
- HTTP exposure through reverse proxy upstreams, not default `forwardPorts`;
- raw TCP/UDP through existing `my.tcp_routes`/`my.udp_routes` conventions.

Per memory (`memory://root/memory_summary.md`), do not use microvms for this direction.

---

## Tests and assurances

### New generic namespace-core VM test

Add a small suite that does not require WireGuard:

- creates one namespace;
- attaches a toy service to it;
- proves namespace resolver file is mounted and configured resolver lookups succeed;
- proves strict DNS denial for unapproved TCP/UDP 53, TCP/UDP 853, and configured explicit DoH endpoints;
- proves service source/route is namespace-specific where observable;
- proves IPv4 and IPv6 host-to-namespace port mappings work for TCP/UDP/both;
- proves wrong protocols and unmapped ports fail with preflighted listener evidence;
- proves restart/idempotency does not duplicate namespace/rules;
- proves service fails closed when namespace unit is unavailable;
- proves partial startup cleanup by forcing a controlled backend-less failure after core-owned namespace/link/rule state is created, then asserting immediately after the failed start that no failed namespace entry, owned links, or owned firewall rules remain, and finally that a subsequent clean start creates exactly one working namespace.

### WireGuard backend suite

Update/extend `wireguard_tunnels` to prove:

- existing relay ingress behavior remains;
- plain vs confined source identity remains;
- all-traffic/default-route behavior remains;
- DNS policy remains;
- startup/mid-flight fail-closed behavior remains;
- restart/idempotency remains;
- WireGuard backend setup failure cleans up namespace, interface, links, and firewall state immediately after the failed start;
- `open_vpn_ports` remain dual-stack TCP/UDP/both;
- host-to-namespace `port_mappings` now pass dual-stack TCP/UDP/both;
- current VPN-Confinement limitation assertions are removed or inverted after the internal backend fixes them.

### Readability retrofit

Before or during implementation, apply the new `.agents/skills/writing-nixos-tests/SKILL.md` guidance to touched tests:

- top-of-file topology/intent comments;
- section comments in long `run()` flows;
- comments near non-obvious Nix fixture services and route/firewall setup;
- explicit comments for known limitations until they are fixed;
- extraction of repeated service matrices when repetition hides intent.

---

## Migration strategy

1. Keep current public `unit.wireguard.client.*` options stable.
2. Add `my.network_namespaces` and tests.
3. Wire `unit.wireguard.client` to `my.network_namespaces.<namespace>`.
4. Remove `inputs.vpnconfinement.nixosModules.default` import from `unit.wireguard`.
5. Keep top-level `vpnconfinement` input temporarily if `nixarr` still follows it.
6. Run generic namespace-core and WireGuard backend VM tests.
7. Only later decide how to remove `vpnconfinement` from `flake.nix` entirely after any remaining consumer coupling is handled.

---

## Non-goals

- No Transmission/qBittorrent/torrent-client migration in this change.
- No nftables implementation in the first cut.
- No generic DoH blocking claim.
- No microvms.
- No complete container framework in the same implementation as the service-level replacement.
- No real production service migration before synthetic VM behavior is proven.

## Open risks

- Partial startup failure can leave stale namespaces, links, or firewall rules unless cleanup is carefully trapped and tested.
- Deleting a named namespace while processes still hold it can leave a namespace alive; service ordering must stop/contain consumers first.
- Ping/ICMP endpoint checks are not sufficient WireGuard readiness proofs and may reject valid endpoints; tests should rely on functional traffic evidence.
- Keeping iptables first is compatibility debt; nftables should become a planned follow-up.
- Broad `accessible_from` entries can intentionally bypass the VPN default path for return traffic; docs and tests must treat this as route-exception behavior, not an ACL.
- If implementation topology changes from bridge/veth to direct veth, option names like `bridge_address` must not lie; either keep bridge-shaped topology for compatibility or rename clearly.
