# Network Namespaces and VPN Isolation Implementation Plan

> **For agentic workers:** REQUIRED: Use `superpowers:subagent-driven-development` for implementation. Read `.agents/skills/writing-nixos-tests/SKILL.md` before touching NixOS VM tests. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `unit.wireguard`'s VPN-Confinement usage with a repo-owned `my.network_namespaces` module and WireGuard backend, while preserving existing caller behavior and improving dual-stack port-mapping correctness.

**Architecture:** Implement a generic namespace core plus WireGuard backend. Keep `unit.wireguard.client.*` as a compatibility layer that maps to `my.network_namespaces.<name>`. Add a generic namespace-core VM test and update the WireGuard suite to prove the internal backend, including fixed IPv6 host-to-namespace port mappings.

**Tech Stack:** NixOS modules, systemd, network namespaces, WireGuard, iproute2, iptables/ip6tables, NixOS VM tests, Python test drivers.

---

## Prerequisites and branch discipline

- Base implementation on the stacked branch containing the expanded WireGuard suite and the `writing-nixos-tests` skill.
- Use a separate implementation worktree from this planning/docs branch.
- Do not change Transmission, qBittorrent, or torrent-client modules.
- Keep the `vpnconfinement` flake input temporarily if `nixarr` still follows it; stop `unit.wireguard` from using it.
- If `globals/` changes, run `nix flake update globals` per `AGENTS.md`. This plan does not expect `globals/` changes.

## Validation commands

Run in this order after implementation:

```bash
nix fmt
git add .
prek
nix build .#checks.x86_64-linux.network_namespaces
nix build .#checks.x86_64-linux.wireguard_tunnels
nix flake check --all-systems
```

Expected warnings from flake outputs/deprecations are acceptable only if exit code is zero and no new failures appear.

## Flake-backed checks only see files tracked or staged in git. After creating new module/test paths, run `git add` for those paths before any `nix eval` or `nix build` that references them. Do this even before the final all-files staging step.

## Task 1: Prepare readable tests baseline

**Files:**

- Modify: `tests/scripts/src/my_nix_tests/wireguard_tunnels.py`
- Modify: `tests/wireguard_tunnels/default.nix`
- Modify: `tests/wireguard_tunnels/relay.nix`
- Modify: `tests/wireguard_tunnels/isolated.nix`
- Modify: `tests/wireguard_tunnels/probe.nix`

- [ ] **Step 1: Read the repo-local NixOS test skill**

Read:

```text
.agents/skills/writing-nixos-tests/SKILL.md
```

- [ ] **Step 2: Add orientation comments without behavior changes**

Add brief comments that explain:

- node roles and topology;
- why the isolated node has both host and namespace WireGuard peers;
- why `probe` has primary and remote addresses;
- why listener service lists must stay synchronized with Python driver recovery logic;
- why current IPv6 host-to-namespace limitation assertions exist before replacement.

- [ ] **Step 3: Add section comments in Python driver**

In `run()`, add narrative phase comments for:

1. startup fail-closed while relay is absent;
2. relay startup/recovery;
3. relay ingress;
4. route/source assertions;
5. port mappings and known limitations;
6. open VPN ports;
7. DNS allow/deny policy;
8. mid-flight outage;
9. restart/idempotency.

- [ ] **Step 4: Avoid behavior changes**

Run:

```bash
python -m py_compile tests/scripts/src/my_nix_tests/wireguard_tunnels.py
nix build .#checks.x86_64-linux.wireguard_tunnels
```

Expected: both pass.

---

## Task 2: Add `my.network_namespaces` option skeleton

**Files:**

- Create: `users/_units/network_namespaces/default.nix`
- Modify: `users/_units/default.nix`

- [ ] **Step 1: Define core option types**

Add option types for:

- protocol enum: `tcp`, `udp`, `both`;
- IP family enum: `ipv4`, `ipv6`;
- port mapping `{ from; to; protocol; }`;
- open VPN/backend port `{ port; protocol; }`;
- DoH block endpoint `{ family; address; port; }`;
- backend enum initially containing `none` and `wireguard`;
- namespace addresses;
- DNS settings;
- service list.

Use PascalCase for type variables per `AGENTS.md`.

- [ ] **Step 2: Define `my.network_namespaces.<name>` options**

Initial shape:

```nix
my.network_namespaces.<name> = {
  enable = true;
  backend.type = "none";
  backend.wireguard.config_file = "/run/wireguard/vpn.conf"; # used only when backend.type = "wireguard"
  backend.wireguard.interface_name = "wg0";
  addresses.host_v4 = "10.15.0.5";
  addresses.namespace_v4 = "10.15.0.1";
  addresses.host_v6 = "fd10:15::5";
  addresses.namespace_v6 = "fd10:15::1";
  dns.servers = [ ... ];
  dns.strict.enable = true;
  dns.strict.block_doh_endpoints = [ ... ];
  services = [ ... ];
  accessible_from = [ ... ];
  port_mappings = [ ... ];
  open_vpn_ports = [ ... ];
};
```

- [ ] **Step 3: Add evaluation assertions**

Assert:

- namespace name is short enough for derived interface names;
- WireGuard backend requires a config file only when `backend.type = "wireguard"`;
- IPv6 settings are complete if any IPv6 field is set;
- `from`, `to`, and `port` values are valid TCP/UDP port numbers;
- DNS strict DoH endpoints have address and port.

- [ ] **Step 4: Import module**

Add `./network_namespaces` to `users/_units/default.nix`.

- [ ] **Step 5: Stage new module paths before flake-backed eval**

Run:

```bash
git add users/_units/network_namespaces/default.nix users/_units/default.nix
```

- [ ] **Step 6: Run eval-focused check**

Run:

```bash
nix eval .#checks.x86_64-linux.formatting.drvPath
```

Expected: evaluation succeeds.

---

## Task 3: Implement generic namespace lifecycle core

**Files:**

- Modify: `users/_units/network_namespaces/default.nix`

- [ ] **Step 1: Generate namespace service**

For each enabled namespace, generate `systemd.services.<name>` with:

```nix
serviceConfig = {
  Type = "oneshot";
  RemainAfterExit = true;
  ExecStart = "...";
  ExecStopPost = "...";
};
```

The service owns `/run/netns/<name>` and `/etc/netns/<name>/resolv.conf`.

- [ ] **Step 2: Implement idempotent setup shell**

Setup script should:

- clean previous owned partial state first;
- create namespace;
- bring up loopback;
- create host<->namespace connectivity;
- assign IPv4/IPv6 host and namespace addresses;
- write resolver file;
- install DNS and mapping firewall rules;
- call backend setup hook.

- [ ] **Step 3: Implement idempotent teardown shell**

Teardown script should:

- remove owned iptables/ip6tables chains and jumps;
- remove owned interfaces/links;
- remove namespace if owned and not in use by a still-running service;
- remove `/etc/netns/<name>`;
- tolerate missing resources but fail loudly on unexpected conditions where useful.

- [ ] **Step 4: Keep rule emission centralized**

Create local Nix helper functions for:

- protocol expansion (`both` → `tcp`, `udp`);
- host DNAT mapping rules;
- namespace INPUT rules;
- DNS allow/deny rules;
- duplicate-rule-safe insertion/deletion.

Do not scatter raw iptables strings through unrelated code.

---

## Task 4: Implement service attachment

**Files:**

- Modify: `users/_units/network_namespaces/default.nix`

- [ ] **Step 1: Attach configured services**

For every service in `my.network_namespaces.<name>.services`, generate:

```nix
systemd.services.<service> = {
  bindsTo = ["<name>.service"];
  after = ["<name>.service"];
  serviceConfig = {
    NetworkNamespacePath = "/run/netns/<name>";
    BindReadOnlyPaths = [
      "/etc/netns/<name>/resolv.conf:/etc/resolv.conf:norbind"
    ];
    InaccessiblePaths = ["/run/nscd" "/run/resolvconf"];
  };
};
```

- [ ] **Step 2: Preserve fail-closed semantics**

Ensure services cannot start on the host network if the namespace unit is failed/missing.

- [ ] **Step 3: Keep service-level behavior generic**

Do not introduce WireGuard-specific settings into service attachment.

---

## Task 5: Implement WireGuard backend

**Files:**

- Modify: `users/_units/network_namespaces/default.nix`

- [ ] **Step 1: Parse/use generated WireGuard config**

The backend can assume `unit.wireguard` writes the config. It should configure `wg0` inside the namespace using a deterministic script. Avoid copying upstream VPN-Confinement code verbatim.

- [ ] **Step 2: Configure default routes**

Inside namespace:

- add IPv4 default route through the WireGuard interface;
- add IPv6 default route when IPv6 is configured;
- add route exceptions for `accessible_from` so approved local/probe traffic returns correctly.

- [ ] **Step 3: Implement `open_vpn_ports`**

Open configured TCP/UDP/both ports on the WireGuard interface inside the namespace.

- [ ] **Step 4: Avoid ICMP-only readiness as proof**

If any endpoint wait remains necessary for startup, tests must still prove readiness through functional traffic and DNS assertions.

---

## Task 6: Map `unit.wireguard.client` to `my.network_namespaces`

**Files:**

- Modify: `users/_units/wireguard/default.nix`
- Possibly modify: `flake.nix`
- Possibly modify: `flake.lock`

- [ ] **Step 1: Remove VPN-Confinement import from `unit.wireguard`**

Remove:

```nix
imports = _: [inputs.vpnconfinement.nixosModules.default];
```

from `unit.wireguard`.

- [ ] **Step 2: Keep generated WireGuard config**

Keep `/run/wireguard/vpn.conf` generation in `unit.wireguard` unless the new backend needs it moved.

- [ ] **Step 3: Map client options**

Map existing `opts.client` fields into:

```nix
my.network_namespaces.${opts.client.namespace} = { ... };
```

including:

- namespace name;
- addresses;
- DNS servers;
- strict DNS settings;
- services;
- accessible_from;
- port_mappings;
- open_vpn_ports;
- WireGuard config file path.

- [ ] **Step 4: Preserve reverse-path filtering behavior**

When the WireGuard client/backend is enabled, preserve the current `networking.firewall.checkReversePath = "loose"` behavior from `unit.wireguard`, or install an equivalent scoped rpfilter exemption if the implementation can prove it preserves all-traffic/default-route behavior. Keep the WireGuard all-traffic/default-route assertions covering this path.

- [ ] **Step 5: Keep flake input temporarily**

Do not remove the top-level `vpnconfinement` input if `nixarr` still follows it. It is acceptable for `unit.wireguard` to stop using it while the input remains for out-of-scope consumers.

- [ ] **Step 6: Ensure production option compatibility**

Existing host configurations using `unit.wireguard.client.*` should continue evaluating.

Run:

```bash
nix eval .#nixosConfigurations.temperance.config.my."unit.wireguard".enable
nix eval .#nixosConfigurations.tyrant.config.my."unit.wireguard".enable
```

Expected: evaluation succeeds.

---

## Task 7: Add generic namespace-core VM test

**Files:**

- Create: `tests/network_namespaces/default.nix`
- Create: `tests/network_namespaces/host.nix`
- Create: `tests/network_namespaces/probe.nix`
- Create: `tests/scripts/src/my_nix_tests/network_namespaces.py`
- Modify: `tests/scripts/default.nix`
- Modify: `tests/default.nix` if needed by current check export pattern

- [ ] **Step 1: Follow the test skill**

Read:

```text
.agents/skills/writing-nixos-tests/SKILL.md
```

- [ ] **Step 2: Build minimal topology**

Use two VMs:

- `host`: owns `my.network_namespaces.test`, namespace toy services, host-side mapping points;
- `probe`: source observer and denied listeners.

Use deterministic IPv4/IPv6 addresses and ports. The successful core namespace under test should use `backend.type = "none"` so lifecycle, resolver policy, service attachment, and host-to-namespace mappings are tested without WireGuard setup.

- [ ] **Step 3: Test service attachment**

Assert a confined toy service runs inside the namespace and sees namespace resolver/routes.

- [ ] **Step 4: Test strict DNS policy**

Add a toy resolver/listener on `probe`, configure it as the allowed resolver, and assert:

- configured resolver lookup succeeds through `/etc/netns/<name>/resolv.conf`;
- unapproved TCP/UDP 53 destinations are denied with listener preflight + blocked-token absence;
- TCP/UDP 853 destinations are denied with listener preflight + blocked-token absence;
- explicit test DoH endpoints from `dns.strict.block_doh_endpoints` are denied with listener preflight + blocked-token absence.

Do not claim generic DoH blocking beyond the configured test endpoints.

- [ ] **Step 5: Test core fail-closed behavior**

Force the namespace unit unavailable or failed, then assert:

- the confined toy service does not start on the host network;
- the service does not emit traffic to a preflighted `probe` observer;
- no observed traffic uses a host fallback source address;
- restarting the namespace restores confined behavior and the expected namespace source evidence.

- [ ] **Step 6: Test port mappings**

Assert IPv4 and IPv6 host-to-namespace mappings work for:

- TCP;
- UDP;
- `both` over TCP;
- `both` over UDP.

Assert wrong protocols and unmapped ports fail with listener preflight + blocked-token absence.

- [ ] **Step 7: Test restart/idempotency**

Restart the namespace service multiple times and assert:

- mappings still work;
- services recover;
- no duplicate namespace entries;
- no duplicate relevant firewall/NAT rules.

- [ ] **Step 8: Test partial-startup cleanup**

Add a controlled backend-less failure case that uses `backend.type = "none"`, creates core-owned state, fails before the namespace becomes active, and then recovers cleanly. Do not use a WireGuard missing-config failure in `tests/network_namespaces`; WireGuard backend cleanup belongs in the WireGuard suite. The exact injection mechanism may be chosen during implementation, but it must remain core-only and must not add a production-facing failure-injection API.

Assert after the failed start:

- the failed namespace has no `/run/netns/<failed-name>` entry;
- no owned veth/bridge links remain for the failed namespace;
- no owned firewall chains or jumps remain for the failed namespace;
- fixing the failure and starting again produces exactly one working namespace.

- [ ] **Step 9: Register Python module**

Add `my_nix_tests.network_namespaces` to `tests/scripts/default.nix`.

- [ ] **Step 10: Stage new test paths before flake-backed build**

Run:

```bash
git add tests/network_namespaces tests/scripts/src/my_nix_tests/network_namespaces.py tests/scripts/default.nix tests/default.nix
```

- [ ] **Step 11: Validate**

Run:

```bash
python -m py_compile tests/scripts/src/my_nix_tests/network_namespaces.py
nix build .#checks.x86_64-linux.network_namespaces
```

Expected: both pass.

---

## Task 8: Update WireGuard suite for internal backend

**Files:**

- Modify: `tests/wireguard_tunnels/default.nix`
- Modify: `tests/wireguard_tunnels/relay.nix`
- Modify: `tests/wireguard_tunnels/isolated.nix`
- Modify: `tests/wireguard_tunnels/probe.nix`
- Modify: `tests/scripts/src/my_nix_tests/wireguard_tunnels.py`

- [ ] **Step 1: Remove direct VPN-Confinement imports from fixtures**

Fixtures should use `unit.wireguard` and `my.network_namespaces`, not `inputs.vpnconfinement.nixosModules.default`.

- [ ] **Step 2: Update IPv6 host-to-namespace expectations**

Replace current limitation assertions with passing assertions for:

- IPv6 TCP host mapping;
- IPv6 UDP host mapping;
- IPv6 both/TCP host mapping;
- IPv6 both/UDP host mapping.

Keep wrong-protocol and unmapped negative assertions.

- [ ] **Step 3: Preserve non-DNS behavior**

Keep assertions for:

- relay ingress;
- plain vs confined source;
- all-traffic/default-route;
- fail-closed startup;
- mid-flight outage;
- restart/idempotency;
- open VPN ports.

- [ ] **Step 4: Preserve strict DNS behavior**

Keep or strengthen assertions for the approved DNS scope:

- configured resolver success through the namespace resolver file;
- unapproved TCP/UDP 53 denial with listener/source preflight where feasible;
- TCP/UDP 853 denial with listener/source preflight where feasible;
- explicit configured DoH endpoint denial with listener/source preflight where feasible.

Do not add or imply generic DoH blocking beyond configured test endpoints.

- [ ] **Step 5: Test WireGuard backend setup-failure cleanup**

Add a WireGuard-specific failure case outside `tests/network_namespaces` that forces backend setup to fail after core-owned state exists, for example by using an invalid or missing WireGuard config path in a dedicated failure namespace.

Assert immediately after the failed start:

- the failed namespace has no `/run/netns/<failed-wg-name>` entry;
- no backend-created WireGuard interface remains;
- no owned veth/bridge links remain for the failed namespace;
- no owned firewall chains or jumps remain for the failed namespace;
- fixing the failure and starting again produces exactly one working WireGuard-backed namespace.

- [ ] **Step 6: Update comments**

Remove comments that describe VPN-Confinement limitations after they are fixed. Add comments explaining the internal backend behavior where non-obvious.

- [ ] **Step 7: Validate**

Run:

```bash
python -m py_compile tests/scripts/src/my_nix_tests/wireguard_tunnels.py
nix build .#checks.x86_64-linux.wireguard_tunnels
```

Expected: both pass.

---

## Task 9: Review loop

**Files:**

- All files changed in Tasks 1-8.

- [ ] **Step 1: Dispatch architecture reviewer**

Review:

- `users/_units/network_namespaces/default.nix`;
- `users/_units/wireguard/default.nix`;
- `flake.nix`/`flake.lock` if changed.

Questions:

- Is the module boundary clean?
- Is service attachment fail-closed?
- Are WireGuard details isolated to backend code?
- Is future nftables migration possible?

- [ ] **Step 2: Dispatch test meaningfulness reviewer**

Review:

- `tests/network_namespaces/*`;
- `tests/wireguard_tunnels/*`;
- both Python drivers.

Questions:

- Are assertions meaningful?
- Are negative assertions preflighted?
- Are IPv6 port mappings actually proven fixed?
- Are comments/readability aligned with the new skill?

- [ ] **Step 3: Dispatch reliability/fail-closed reviewer**

Questions:

- Can partial startup leave stale state?
- Are restarts idempotent?
- Do fail-closed tests prove no fallback route/source?
- Do DNS assertions cover the promised first-cut scope?

- [ ] **Step 4: Fix findings and rerun reviewers**

Do not proceed with open Important/Critical findings.

---

## Task 10: Final validation

Run:

```bash
nix fmt
git add .
prek
nix build .#checks.x86_64-linux.network_namespaces
nix build .#checks.x86_64-linux.wireguard_tunnels
nix flake check --all-systems
```

Expected: all exit zero.

If `nix flake check --all-systems` fails outside scope, report exact failure and do not hide it.

---

## Task 11: Commit policy

After all reviews and validation pass:

- create one monolithic commit in the implementation worktree;
- do not merge;
- do not push;
- stop for manual review.

Suggested commit message:

```text
feat: internalize vpn network namespaces
```

---

## Deferred follow-ups

- nftables backend for `my.network_namespaces`.
- Shared-gateway NixOS container prototype.
- Per-container WireGuard identity model.
- Full removal of `vpnconfinement` flake input after all remaining consumers/couplings are addressed.
- Real-service migrations, including torrent clients, after synthetic behavior is proven.
