# Server-Side Isolation / Declarative NixOS Containers Research

Date: 2026-04-28

Companion to: `docs/wip/isolation.md`

## Goal

Research server-side service isolation for this repo using declarative NixOS containers.

Desired properties:

1. Declare isolated services as NixOS configurations.
2. Expose selected container ports to the host so the existing reverse proxy can consume them.
3. Use the repo's `mylib` helpers to reduce repeated endpoint, mount, route, and container boilerplate.
4. Explore alternatives and trade-offs.

Initial hard constraint for the first pass: **do not use MicroVMs**. Appendix A reopens that constraint and researches MicroVMs as a stronger-isolation alternative.

This document is a research snapshot only. No implementation decisions are locked in yet.

## Short conclusion

The strongest server-side direction is:

- use native `containers.<name>` NixOS containers as the primary primitive
- default to `privateNetwork = true`
- assign each container a stable host/container address pair
- have host Traefik consume container HTTP endpoints through normal `my.vhosts.*.sources`
- keep raw TCP/UDP exposure in `my.tcp_routes` / `my.udp_routes`, not `my.vhosts`
- add small `mylib.units` helpers first, before introducing a larger repo-wide abstraction

The main reason is fit: native NixOS containers let each isolated service be a real NixOS module while staying declarative in the host config.

## Current repo evidence

### Host/container capability already exists

`systems/_bootstrap/host.nix` already enables host-side container support:

```nix
virtualisation = o.def {
  containers.enable = true;
  # ...
};
```

The original `docs/wip/isolation.md` also recorded that native NixOS containers are the best server-side fit, but that the repo did not yet have a framework using `containers.<name>`.

Current search confirms there is still no established native-container pattern in repo Nix code:

- no `containers.<name>` service framework
- no current `forwardPorts` / `hostAddress` / `localAddress` callsites
- no `virtualisation.oci-containers` usage
- no Arion usage

The existing container-ish helper is Docker Compose oriented:

- `_lib/units/default.nix` exposes `make_docker_unit`
- `users/_units/fxsync/default.nix` uses Docker Compose for a database helper unit

### Server reverse proxy model

The server host to anchor this design is currently `tyrant` in `globals/hosts.nix`; it enables `unit.traefik` and several long-running units.

The repo already has a useful ingress split:

1. `my.vhosts`
   - HTTP/HTTPS virtual host declarations
   - fields: `target`, `sources`
   - consumed by Traefik HTTP routers/services
   - consumed by DNS subdomain generation
2. `my.tcp_routes`
   - raw TCP Traefik route declarations
   - fields include `listen`, `upstreams`, `rule`, optional `tls`
3. `my.udp_routes`
   - raw UDP Traefik route declarations
   - fields include `listen`, `upstreams`

This matches the memory note from `memory://root/memory_summary.md` to keep `my.vhosts` HTTP-only and add separate TCP/UDP routing if needed. Current repo evidence supports it:

- `users/_units/reverse-proxy/default.nix` defines separate schemas for `my.vhosts`, `my.tcp_routes`, and `my.udp_routes`
- `users/_units/reverse-proxy/traefik/default.nix` renders HTTP backends from `my.vhosts.*.sources` as URL load balancer servers
- the same Traefik module renders TCP/UDP routes separately using raw upstream addresses
- `systems/_modules/dns/default.nix` derives DNS subdomains from `my.vhosts`, not from TCP/UDP routes

So container support should preserve this split.

### Existing HTTP endpoint helper

`_lib/units/endpoint.nix` is the key precedent:

```nix
u.endpoint {
  port = 5006;
  target = "actual";
}
```

It returns option declarations for:

- `port`
- `target`
- `sources`

The default source is currently:

```nix
["http://localhost:${toString port}"]
```

That is correct for host-local services, but wrong for a private-network container unless the service is deliberately forwarded back to a host port. A container helper should therefore override or derive `sources` for the chosen networking pattern.

### Non-HTTP precedent

Forgejo already exposes both HTTP and raw TCP:

- `my.vhosts.forgejo` for web
- `my.tcp_routes.forgejo_ssh` for SSH
- Forgejo's built-in SSH backend currently binds `127.0.0.1:4220`, and Traefik routes TCP port 22 to that upstream

That is a good model for future containerized services with more than HTTP.

## Native NixOS container facts

Native NixOS containers are systemd-nspawn containers managed by NixOS.

Useful options:

- `containers.<name>.config`
  - NixOS module/config for the guest
- `containers.<name>.specialArgs`
  - extra args passed to guest module evaluation
- `containers.<name>.autoStart`
  - start container at boot
- `containers.<name>.bindMounts`
  - bind host paths into the container
  - fields: `mountPoint`, `hostPath`, `isReadOnly`
  - default is read-only
- `containers.<name>.tmpfs`
  - mount tmpfs paths inside the guest
- `containers.<name>.privateNetwork`
  - give the container its own network namespace and veth pair
- `containers.<name>.hostAddress`
  - address on the host-side veth
- `containers.<name>.localAddress`
  - address inside the container
- `containers.<name>.hostBridge`
  - attach host-side veth to a bridge instead of using host/local address pair
- `containers.<name>.forwardPorts`
  - forward host ports to container ports
  - fields: `protocol`, `hostPort`, optional `containerPort`
- `containers.<name>.privateUsers`
  - user namespace mode; `"pick"` is the safer automatic choice
- `containers.<name>.allowedDevices`
  - device access, default empty
- `containers.<name>.additionalCapabilities`
  - extra capabilities, default empty
- `containers.<name>.ephemeral`
  - empty root filesystem on each boot/shutdown cycle

Important implementation detail from the nixpkgs module: `forwardPorts` is emitted only in the `privateNetwork` branch. Treat it as a private-network feature.

Other useful behavior:

- the host gets generated names like `<name>.containers` when `localAddress` is set
- container names must not contain underscores
- on older kernels, private-network container names had stricter length concerns because interface names derive from container names
- private-network containers need host NAT if they need outbound Internet access
- NetworkManager should not manage `ve-*` / `vb-*` container interfaces; nixpkgs has handling for this

Security caveat:

Native NixOS containers are shared-kernel containers, not VM isolation. The NixOS manual warns they are not perfectly isolated from the host. This makes them good for service compartmentalization, not for hostile multi-tenant workloads.

## Networking approaches

### Approach A: private veth + direct Traefik upstreams

Shape:

```nix
containers.actual = {
  autoStart = true;
  privateNetwork = true;
  hostAddress = "10.88.0.1";
  localAddress = "10.88.0.11";
  privateUsers = "pick";

  config = { ... }: {
    services.actual = {
      enable = true;
      settings.port = 5006;
    };

    networking.firewall.allowedTCPPorts = [5006];
  };
};

my.vhosts.actual-budget = {
  target = "actual";
  sources = ["http://actual.containers:5006"];
};
```

This is the recommended default.

Pros:

- best fit for host Traefik: it already accepts HTTP backend URLs
- avoids allocating high host ports for every service
- keeps service ports inside the container network namespace
- preserves `my.vhosts` unchanged
- makes TCP/UDP route upstreams straightforward: `actual.containers:<port>` or `<localAddress>:<port>`

Cons:

- requires stable container IP allocation
- requires each containerized service to bind to the container interface, not only `127.0.0.1`
- requires thinking about container outbound NAT if the service needs Internet access
- debugging requires checking both host and guest firewalls

Best fit:

- normal HTTP services behind Traefik
- services where direct host port exposure is not needed
- the default repo abstraction

### Approach B: private network + `forwardPorts`

Shape:

```nix
containers.actual = {
  autoStart = true;
  privateNetwork = true;
  hostAddress = "10.88.0.1";
  localAddress = "10.88.0.11";

  forwardPorts = [
    {
      protocol = "tcp";
      hostPort = 15006;
      containerPort = 5006;
    }
  ];
};

my.vhosts.actual-budget = {
  target = "actual";
  sources = ["http://127.0.0.1:15006"];
};
```

Pros:

- keeps Traefik pointed at host-side sockets
- avoids teaching all callsites about container addresses
- can be useful when a host-local consumer must use a host port

Cons:

- consumes host port namespace
- address/bind behavior for forwarded ports needs verification before relying on loopback-only semantics
- easier to accidentally create direct non-Traefik access if firewall assumptions are wrong
- still requires `privateNetwork = true`

Best fit:

- transitional migrations
- services with host-local consumers that cannot easily target container IPs
- one-off ports that really should exist on the host

### Approach C: shared host network namespace

Shape:

```nix
containers.actual = {
  autoStart = true;
  privateNetwork = false;

  config = { ... }: {
    services.actual.settings.port = 5006;
  };
};
```

Pros:

- smallest networking diff from current host services
- `u.endpoint`'s default `localhost` source can remain valid if the guest service binds the expected host-visible socket
- fewer moving parts for first experiments

Cons:

- weaker network isolation
- port collisions with host services are likely
- container can bind host interfaces/ports
- less aligned with the isolation goal

Best fit:

- very small trusted transitional experiments only

I would not make this the default abstraction.

### Approach D: host bridge / LAN-addressed containers

Shape:

```nix
containers.actual = {
  privateNetwork = true;
  hostBridge = "br0";
  localAddress = "192.168.15.50/24";
};
```

Pros:

- containers can appear as LAN peers
- useful for services that need LAN-level behavior

Cons:

- bigger networking surface
- more host/network configuration
- less desirable when the only consumer should be host Traefik
- LAN IP management becomes part of service deployment

Best fit:

- rare services that need direct LAN identity
- not the default for reverse-proxied web apps

## Service grouping approaches

### One container per service

Each application gets its own NixOS container.

Pros:

- clean failure and restart boundaries
- easiest to reason about ownership and ports
- maps well to `users/_units/<service>`
- simpler backup ownership per service

Cons:

- more IPs and containers
- shared infrastructure such as Postgres still crosses boundaries unless also moved

Best default for this repo.

### One container per app stack

App, database, and workers live in the same NixOS container.

Pros:

- stronger grouping of internal app dependencies
- fewer host-level cross-service assumptions
- local sockets inside the guest can remain private to the stack

Cons:

- duplicates infrastructure services such as Postgres
- backup model becomes more container-aware
- upgrades/migrations become per-stack

Good for apps whose database is truly app-private.

### Shared infra container plus app containers

One or more infrastructure containers provide Postgres, Redis, etc.; app containers consume them over private container networking.

Pros:

- keeps infrastructure centralized
- still isolates app processes from host

Cons:

- requires a container network/service-discovery convention
- secrets and database access cross container boundaries
- larger first implementation surface

Probably a later step, not the first prototype.

## Repo abstraction approaches

### Option 1: small pure helpers in `mylib.units.container`

Add helper functions under something like:

```text
_lib/units/container.nix
```

Export from `_lib/units/default.nix` as `container`.

Possible helpers:

```nix
u.container.http_endpoint {
  port = 5006;
  target = "actual";
  container_name = "actual";
}
```

Returns endpoint options like `u.endpoint`, but default `sources` becomes:

```nix
["http://actual.containers:5006"]
```

Other helpers:

```nix
u.container.bind_mount_rw {
  host_path = "/var/lib/actual";
  mount_point = "/var/lib/actual";
}

u.container.bind_mount_ro {
  host_path = "/etc/static-config";
  mount_point = "/etc/static-config";
}

u.container.mk_nixos_container {
  name = "actual";
  local_address = "10.88.0.11";
  host_address = "10.88.0.1";
  mounts = { ... };
  config = { pkgs, ... }: { ... };
}
```

Pros:

- lowest risk
- follows existing `u.endpoint` and `u.backup` style
- keeps service modules explicit
- avoids a large new option schema too early

Cons:

- more boilerplate remains at callsites
- uniqueness validation for IPs/ports is harder unless a central module is added later

Recommended first step.

### Option 2: full `my.server_containers.<name>` option module

Define a higher-level repo API:

```nix
my.server_containers.actual = {
  enable = true;
  id = 11;

  http.actual-budget = {
    target = "actual";
    port = 5006;
  };

  mounts.state = {
    host_path = "/var/lib/actual";
    mount_point = "/var/lib/actual";
    read_only = false;
  };

  config = { pkgs, ... }: {
    services.actual.enable = true;
  };
};
```

The module would emit:

- `containers.actual`
- `my.vhosts.actual-budget`
- optional `my.tcp_routes.*`
- optional `my.udp_routes.*`
- assertions for duplicate IDs, ports, names, and route entrypoints

Pros:

- most declarative and least repetitive at callsites
- can validate IP allocation centrally
- can encode preferred defaults once

Cons:

- bigger design surface
- easy to hide too much behavior
- can blur the currently clean HTTP vs TCP/UDP boundary
- harder to retrofit services with unusual needs

Good future target after one or two services prove the primitives.

### Option 3: per-unit isolation toggle

Each existing unit gains an isolation setting:

```nix
my."unit.actual-budget" = {
  enable = true;
  isolation = {
    enable = true;
    backend = "nixos-container";
    id = 11;
  };
};
```

The unit module decides whether to emit host services or guest container config.

Pros:

- easy migration path service by service
- preserves current `unit.<name>` interface
- lets each service handle its own oddities

Cons:

- every unit that supports isolation has two runtime paths
- significant duplication unless helpers are very good
- harder to enforce global uniqueness and network conventions

Good for gradual migration, but not as the first abstraction layer.

### Option 4: OCI / Arion secondary path

Use `virtualisation.oci-containers` or Arion for workloads that are already OCI/Compose-native.

Pros:

- good fit for prebuilt container images
- natural migration path for existing Compose-style services
- NixOS has declarative OCI container options for images, volumes, ports, environment, etc.

Cons:

- not a real guest NixOS config
- less aligned with this research goal
- creates a second server isolation model if used too early

Keep this as a secondary option for OCI-native workloads, not the default repo-native isolation framework.

## Proposed default container contract

A future helper should probably encode these defaults:

```nix
{
  autoStart = true;
  privateNetwork = true;
  privateUsers = "pick";
  restartIfChanged = true;

  # Explicit per-container allocation.
  hostAddress = "10.88.11.1";
  localAddress = "10.88.11.2";

  # Read-only unless explicitly writable.
  bindMounts = { };

  # Empty by default; opt in per service.
  allowedDevices = [ ];
  additionalCapabilities = [ ];
}
```

Guest baseline should include:

```nix
{ lib, ... }: {
  networking.useHostResolvConf = lib.mkForce false;
  services.resolved.enable = true;

  # Each service still opens only the ports it serves inside the guest.
  networking.firewall.allowedTCPPorts = [ ... ];

  system.stateVersion = "25.11";
}
```

Open questions:

- Should the host NAT container outbound traffic by default?
- Should `hostAddress` be one shared host-side address for all containers or one per container?
- Should helper-generated HTTP sources use `<name>.containers` or literal `localAddress`?
- Should containers receive host `mylib` through `specialArgs`, or should the helper re-import `mylib` for the guest evaluation context?

## IP allocation options

### Manual IP per container

Each service declares `localAddress` explicitly.

Pros:

- obvious and stable
- easiest to debug
- no hidden allocation logic

Cons:

- repetitive
- duplicate IPs need assertions or review discipline

### Numeric ID per container

Declare a small integer and derive IPs:

```nix
id = 11;
hostAddress = "10.88.${toString id}.1";
localAddress = "10.88.${toString id}.2";
```

This avoids assuming that duplicate host-side addresses across multiple veth pairs are safe before testing.

Pros:

- less repetition
- easy to list allocations
- central assertions can catch duplicate IDs

Cons:

- needs a real module, not only pure helpers
- the chosen subnet must be reserved and documented

This is the best medium-term model.

### Forward-ports only

Avoid stable container IPs and expose only host high ports.

Pros:

- no private subnet registry
- simple to feed current `localhost`-style sources

Cons:

- loses most of the clean container-network model
- host port namespace gets crowded
- port-forward bind semantics need testing

Useful fallback, not the default.

## State, secrets, and backups

### State

For persistent services, avoid relying on the container root filesystem as the only copy of important data.

Preferred pattern:

- host owns persistent state path
- container bind-mounts it at the service's expected path
- bind mounts default read-only unless explicitly writable
- host backup declarations target host paths

Example shape:

```nix
bindMounts."/var/lib/actual" = {
  hostPath = "/var/lib/containers/actual/state";
  isReadOnly = false;
};
```

For stateful services, `ephemeral = true` is only safe if all meaningful state is bind-mounted or externalized.

### Secrets

Two possible patterns:

1. Host-managed secret bind mounts
   - host declares SOPS secrets as today
   - container bind-mounts only the needed secret files, read-only
   - simple first-pass model
2. Guest-managed secrets
   - container imports secret modules and decrypts inside guest
   - cleaner isolation story eventually
   - needs explicit key and identity handling

First prototype should probably use host-managed read-only secret binds unless a service specifically benefits from guest-managed secrets.

### Backups

Current `o.module` automatically adds `backup.items` under every unit option tree, and the backup unit already collects those declarations.

Containerized units should keep backup declarations host-side at first:

- path backups target host bind-mount paths
- database dumps connect through container IP/port or use a container-aware command wrapper
- avoid requiring the backup system to inspect container root filesystems directly

If a full app stack moves its database inside the container, the dump helpers may need a container-aware host/port option.

## Service migration notes

### Actual Budget

Good first candidate:

- simple HTTP app
- current endpoint is `actual:5006`
- current state path is straightforward
- fewer protocol complications than Forgejo or Pi-hole

Things to check:

- bind address inside guest
- state bind mount path
- vhost source rewrite to `actual.containers:5006`

### Forgejo

Useful later because it exercises HTTP + TCP.

Things to check:

- web HTTP source can become container HTTP source
- SSH route should remain `my.tcp_routes`, with upstream changed to container address
- built-in SSH listener must bind inside guest in a way Traefik can reach

### Pi-hole

Not a first candidate.

Reasons:

- DNS/DHCP behavior is network-sensitive
- it already opens DNS/DHCP/web firewall paths
- it may need LAN-specific semantics rather than simple Traefik HTTP proxying

### Nixarr / media stack

Potentially valuable, but too large for first proof.

Reasons:

- multiple endpoints
- potential storage and device concerns
- may intersect with VPN namespace behavior

## Recommended next implementation path

1. Add pure helper functions under `mylib.units.container`.
2. Keep service modules explicit: they still declare `my.vhosts`, `my.tcp_routes`, and `my.udp_routes` intentionally.
3. Prototype one HTTP-only service using native `containers.<name>` with private networking.
4. Prefer `my.vhosts.*.sources = ["http://<name>.containers:<port>"]` if host resolution works as expected; fall back to literal `localAddress` only if needed.
5. Add assertions only after the first prototype clarifies the shape:
   - no duplicate container IDs/IPs
   - no underscores in container names
   - no duplicated forwarded host ports
   - no TCP/UDP route emission with empty upstreams
6. After the first service works, decide whether to stay with pure helpers or graduate to `my.server_containers.<name>`.

Verification for future implementation should follow repo procedure:

- `nix fmt`
- stage changed files before `prek`
- `prek`
- targeted `nix eval` / host toplevel build
- `nix flake check --all-systems` only when appropriate for Nix code changes and when the broader check cost is acceptable

## Appendix A: MicroVMs as a server isolation backend

Date: 2026-05-03

This appendix reconsiders the original no-MicroVM constraint. It does not replace the native-container research above; it asks whether MicroVMs can be a clean repo-supported server isolation tier and what decisions are still open.

### Short answer

Yes, MicroVMs can be used cleanly in this repo, but not as a drop-in replacement for the native `containers.<name>` plan.

They become clean if the repo gives them a dedicated contract:

- a shared guest baseline module
- explicit TAP/routed networking
- stable IP/MAC/interface allocation
- explicit Traefik sources pointing at guest addresses
- state declared as volumes or shares
- secrets and logs handled deliberately
- host-side backup declarations that understand where state lives

They are not clean if the repo only copies the current `microvms/postgres/default.nix` sample. That sample proves the input works, but it does not define networking, persistence, firewall rules, ingress, backups, or secrets.

The practical conclusion is: keep native NixOS containers as the simpler default, and treat MicroVMs as a stronger-isolation tier for selected services where the extra operational cost is justified.

### What MicroVMs add over NixOS containers

| Dimension              | Native NixOS containers                                          | MicroVMs                                                                                 |
| ---------------------- | ---------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| Isolation boundary     | Shared host kernel through systemd-nspawn/container primitives   | Separate guest kernel behind a hypervisor                                                |
| NixOS guest config     | Direct `containers.<name>.config`                                | Direct NixOS config through `microvm.vms.<name>.config` or `nixosConfigurations.<guest>` |
| Operational weight     | Lower                                                            | Higher: VM boot, fixed RAM, hypervisor process, guest networking                         |
| Network model          | NixOS container veth/namespace with `hostAddress`/`localAddress` | TAP, bridge, macvtap, or hypervisor user networking                                      |
| Host reverse proxy fit | Very direct through container IP/hostname or host forwards       | Direct if guest has stable host-routable IP; otherwise needs forwarding                  |
| State model            | Bind mounts, tmpfs, container root                               | Read-only root plus volumes or host shares                                               |
| Best use               | Normal trusted service compartmentalization                      | Higher-risk/high-value services or stronger fault/security boundary                      |

MicroVMs reduce the shared-kernel attack surface that native containers retain. The trade-off is more lifecycle, networking, storage, and resource management.

### Current repo MicroVM state

The repo already has MicroVM capability, but not yet a server framework.

Verified repo facts:

- `flake.nix` declares the `microvm` input and makes it follow repo `nixpkgs`.
- `flake.lock` pins `microvm-nix/microvm.nix` at revision `2f2f62fdfdca2750e3399f66bd03986ab967e5ca`.
- `outputs/hosts/default.nix` imports `microvm.nixosModules.host` through `HYPERVISOR_HOST_MODULES`. This is included for `lavpc`, `tyrant`, and `temperance`; `iso` does not receive it.
- `_modules/vm.nix` is a generic `virtualisation.vmVariant` profile. It is not the MicroVM server framework.
- `microvms/postgres/default.nix` is the only guest sample. It hardcodes `microvm.hypervisor = "cloud-hypervisor"`, shares `/nix/store` read-only through `virtiofs`, and enables PostgreSQL. It does not declare guest networking, state, firewall, ingress, secrets, or backups.

So the repo is one layer ahead of zero: host capability exists, but clean service isolation would still need a repo API.

### microvm.nix facts relevant here

`microvm.nix` supports two main workflows:

1. **Fully declarative MicroVMs**
   - host declares `microvm.vms.<name>.config`
   - the MicroVM is built with the host NixOS configuration
   - this is closest to `containers.<name>.config`
   - default for `microvm.vms.<name>.restartIfChanged` is true when `config` is used
   - downside: host rebuilds become larger/slower because VM systems are included
2. **Declarative deployment / imperative update**
   - host declares `microvm.vms.<name>.flake` and optional `updateFlake`
   - initial deployment is host-declarative under `/var/lib/microvms`
   - later updates use `microvm -u <name>` or deploy helpers
   - downside: lifecycle is less purely tied to host rebuilds

The host module provides:

- `/var/lib/microvms` state directory
- `microvm@.service` for running guests
- `microvms.target` for autostarted guests
- TAP/MACVTAP setup services
- `microvm-virtiofsd@.service` for `virtiofs` shares
- PCI prep services for passthrough
- `microvm.vms`, `microvm.autostart`, `microvm.stateDir`, and host timeout/readiness options

Guest-level options important for server services include:

- `microvm.hypervisor`
- `microvm.vcpu`
- `microvm.mem`
- `microvm.interfaces`
- `microvm.shares`
- `microvm.volumes`
- `microvm.devices`
- `microvm.forwardPorts` for QEMU user networking only
- `microvm.storeOnDisk`
- `microvm.writableStoreOverlay`
- `microvm.machineId`
- `microvm.registerWithMachined`

### Hypervisor choice

`microvm.nix` supports several hypervisors. For this repo, the meaningful first choices are probably `qemu`, `cloud-hypervisor`, and maybe `firecracker` later.

| Hypervisor                          | Why consider it                                                                                 | Caveats                                                                                                          | Fit here                                                                                    |
| ----------------------------------- | ----------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| `qemu`                              | Most flexible, supports 9p/virtiofs, user networking/port forwarding, broad debugging ecosystem | Larger/older C codebase; more knobs                                                                              | Best first prototype unless there is a strong reason to prefer Rust hypervisors immediately |
| `cloud-hypervisor`                  | Rust, MicroVM-focused, already used by repo sample                                              | No 9p shares; smaller feature/debugging surface than QEMU                                                        | Good second candidate or default once storage/networking pattern is proven                  |
| `firecracker`                       | Strong isolation story and production MicroVM reputation                                        | No 9p/virtiofs shares; state/store model must use block devices/images; less convenient for repo-first iteration | Possible hardened tier, not first prototype                                                 |
| `kvmtool` / `stratovirt` / `alioth` | Lightweight alternatives                                                                        | No virtiofs and/or no control socket according to upstream table                                                 | Not first choices                                                                           |
| `vfkit`                             | macOS support                                                                                   | macOS-only and no TAP/bridge networking                                                                          | Not relevant for `tyrant` server path                                                       |

Recommended first decision: use `qemu` for the first server prototype, even if the desired long-term hypervisor is `cloud-hypervisor` or `firecracker`. QEMU gives the most escape hatches while the repo API is still unsettled.

### Networking options for MicroVM services

The reverse proxy contract should stay the same as the main document:

- HTTP services register `my.vhosts.<name>.sources`
- raw TCP uses `my.tcp_routes`
- raw UDP uses `my.udp_routes`

This keeps the memory/repo rule intact: `my.vhosts` remains HTTP-only, and protocol routing remains explicit.

#### Option A: routed TAP per MicroVM

Each MicroVM gets a TAP interface and a stable host-routed address. Traefik on the host points directly at the guest IP.

Example shape:

```nix
microvm.vms.actual = {
  pkgs = pkgs;
  specialArgs = {
    inherit inputs mylib;
  };

  config = { lib, pkgs, ... }: {
    networking.hostName = "actual";

    microvm = {
      hypervisor = "qemu";
      mem = 1024;
      vcpu = 2;
      interfaces = [
        {
          type = "tap";
          id = "vm-actual";
          mac = "02:00:00:00:11:02";
        }
      ];
      shares = [
        {
          tag = "ro-store";
          source = "/nix/store";
          mountPoint = "/nix/.ro-store";
          proto = "virtiofs";
          readOnly = true;
        }
      ];
    };

    systemd.network.enable = true;
    systemd.network.networks."10-eth" = {
      matchConfig.MACAddress = "02:00:00:00:11:02";
      address = ["10.88.11.2/32"];
      routes = [
        {
          Destination = "10.88.11.1/32";
          GatewayOnLink = true;
        }
        {
          Destination = "0.0.0.0/0";
          Gateway = "10.88.11.1";
          GatewayOnLink = true;
        }
      ];
      networkConfig.DNS = ["10.88.11.1"];
    };

    networking.firewall.allowedTCPPorts = [5006];
  };
};

my.vhosts.actual-budget = {
  target = "actual";
  sources = ["http://10.88.11.2:5006"];
};
```

The guest-side network shape is shown here; a real implementation must also generate matching host-side route/interface config for `vm-actual`.

Pros:

- strongest clean fit for host Traefik
- no host high-port namespace for HTTP services
- avoids putting guests on a shared L2 bridge
- gives each MicroVM a clear identity and route
- maps well to a future numeric ID registry

Cons:

- most networking boilerplate
- needs host-side systemd-networkd or equivalent route setup
- requires a central IP/MAC/TAP allocation convention
- guest services must bind to reachable guest interfaces, not only loopback

This is the recommended MicroVM networking model if MicroVMs become a real server tier.

#### Option B: host-internal bridge + NAT

The host creates an internal bridge, MicroVM TAP interfaces attach to it, and guests use static IPs or DHCP. Host NAT provides outbound connectivity.

Pros:

- documented upstream pattern
- easy mental model
- simpler than per-interface host routes
- good enough for many private host-only service networks

Cons:

- shared L2 segment between VMs
- compromised guests can attempt ARP/NDP/DHCP/link-local mischief unless filtered
- still needs bridge and address management

Good fallback if routed TAP is too much for the first implementation.

#### Option C: QEMU user networking + `microvm.forwardPorts`

The MicroVM uses hypervisor user networking and forwards a host port to the guest service.

Example shape:

```nix
microvm = {
  hypervisor = "qemu";
  interfaces = [
    {
      type = "user";
      id = "usernet";
      mac = "02:00:00:00:11:02";
    }
  ];
  forwardPorts = [
    {
      from = "host";
      proto = "tcp";
      host.port = 15006;
      guest.port = 5006;
    }
  ];
};

my.vhosts.actual-budget.sources = ["http://127.0.0.1:15006"];
```

Pros:

- least host networking setup
- useful for quick smoke tests
- easy to adapt existing `localhost` endpoint assumptions

Cons:

- QEMU-specific for forwarding
- host port namespace returns
- less explicit service identity
- weaker production shape than TAP/routed networking

This is a prototype fallback, not the clean server architecture.

#### Option D: LAN bridge / macvtap

The MicroVM becomes a peer on the LAN, either through a bridge attached to the physical NIC or MACVTAP.

Pros:

- useful for services that need LAN identity
- can avoid host Traefik for selected protocols

Cons:

- larger network exposure
- external IP/MAC/DHCP planning required
- less desirable for services intended to be consumed only by host Traefik

Keep this for exceptional services, not default web apps.

### State model

MicroVM roots are intended to be read-only, with persistent state externalized. This is good for clarity but forces an early storage decision.

Main choices:

1. **Host shares**
   - `microvm.shares` mounts a host directory through 9p or virtiofs
   - easiest for host-side backups and inspection
   - `virtiofs` is usually preferred over 9p for performance
   - hypervisor support matters: for example, `firecracker` lacks 9p/virtiofs support
2. **Block volumes**
   - `microvm.volumes` attaches image files as disks
   - better fit for databases or filesystems needing normal block semantics
   - less transparent to host backup tooling unless backed up as an image or dumped from inside the guest
3. **Guest-managed remote state**
   - app stores data in a DB or remote service outside the MicroVM
   - can simplify VM replacement
   - pushes isolation problem to the external dependency

Recommended first-pass policy:

- use a read-only `/nix/store` share for build/closure efficiency when the chosen hypervisor supports it
- use explicit host shares for simple app state that the existing backup system should see
- use volumes for databases only when the backup story is a service-level dump, not raw file backup
- avoid `microvm.writableStoreOverlay` for normal server services unless the guest must build Nix derivations at runtime

### Secrets model

MicroVM secrets need a more deliberate answer than native containers because the guest has its own boot/lifecycle.

Possible approaches:

1. **Host-managed read-only secret shares**
   - host decrypts secrets as today
   - only selected files are shared into the guest
   - easiest first implementation
   - caveat: upstream FAQ notes that virtiofs-shared sops-nix `/run/secrets` can disappear on host update unless mitigated, and updated secrets still require guest restart/reload
2. **Guest-managed sops-nix**
   - the MicroVM imports the secrets module and decrypts inside the guest
   - cleaner VM autonomy
   - requires deciding the guest's age/GPG key story and where keys live
3. **Service-specific secret injection**
   - systemd credentials, env files, or app-specific config material generated at boot
   - can be clean, but needs per-service conventions

Recommended first prototype: host-managed read-only secret shares for non-critical secrets, with the limitation documented. Do not silently share the whole host secret tree.

### Backups

Current repo backup conventions are host-oriented. MicroVMs can preserve that, but only if state placement is explicit.

Recommended backup contract:

- host backup declarations remain under the owning unit
- host shares are backed up by their host paths
- volume-backed databases must define a dump job, not rely on raw image backup by default
- guest-only state is not acceptable unless the backup module has a VM-aware collection path
- if logs matter, share guest journals intentionally rather than expecting host journald to include them automatically

For database services, a dump over guest IP or a guest-side timer that writes to a host share is cleaner than backing up live disk images.

### Logging and operations

Useful upstream features:

- `microvm.machineId` can make guest journald identity stable
- guest `/var/log/journal` can be shared to the host through `virtiofs`
- `microvm.registerWithMachined` can expose VMs through `machinectl` for supported operations
- `microvm.deploy.installOnHost`, `sshSwitch`, and `rebuild` exist for SSH-oriented deployment workflows

Repo implications:

- first implementation should define how to inspect guest logs from the host
- health checks should test the guest service over the same path Traefik uses
- updates need a clear rule: host rebuild restarts guest, or VM update is managed separately
- resource budgets should be explicit: `microvm.mem` and `microvm.vcpu` are part of the service contract

### Suggested repo API shape

MicroVM helpers should mirror the native-container helper direction but stay separate to avoid mixing semantics.

Possible helper namespace:

```nix
u.microvm = {
  mk_vm = { name, id, config, ... }: { ... };
  http_endpoint = { name, port, target ? name, ... }: { ... };
  tap_interface = { name, id, ... }: { ... };
  routed_network = { id, ... }: { ... };
  share_ro = { tag, source, mount_point, ... }: { ... };
  share_rw = { tag, source, mount_point, ... }: { ... };
  volume = { image, mount_point, size, ... }: { ... };
};
```

Keep route registration explicit at first:

```nix
my.vhosts.actual-budget = cfg.endpoint;
my.tcp_routes.forgejo_ssh = { ... };
```

Avoid a first version that auto-emits `my.vhosts` from `u.microvm.mk_vm`. Hidden route emission would make it too easy to blur the existing HTTP/TCP/UDP split.

A later full module could be:

```nix
my.microvms.actual = {
  enable = true;
  id = 11;
  hypervisor = "qemu";
  mem = 1024;
  vcpu = 2;

  http.actual-budget = {
    port = 5006;
    target = "actual";
  };

  shares.state = {
    source = "/var/lib/microvms/actual/state";
    mount_point = "/var/lib/actual";
    read_only = false;
  };

  config = { pkgs, ... }: {
    services.actual.enable = true;
  };
};
```

That later module could add assertions for:

- duplicate IDs
- duplicate IPs
- duplicate MACs
- invalid TAP names
- unsupported hypervisor/share combinations
- missing backup declaration for writable state
- accidental TCP/UDP route registration through `my.vhosts`

### Candidate first services

#### Actual Budget

Best low-risk MicroVM prototype.

Why:

- HTTP-only from the host perspective
- simple reverse proxy shape
- likely straightforward persistent state
- less protocol complexity than Forgejo or Pi-hole

What it would prove:

- MicroVM build through host config
- TAP/routed networking
- Traefik to guest IP
- host-visible state share
- backup path for shared state

#### Forgejo

Good second candidate, not first.

Why:

- exercises HTTP plus raw TCP SSH
- high-value service where stronger isolation may be worthwhile

Risks:

- SSH routing and clone URLs must be handled carefully
- state/database/runner integration is larger

#### PostgreSQL

The repo already has a skeletal sample, but it is not a good first production candidate by itself.

Why:

- database state/backup semantics are the hard part
- direct Traefik ingress is irrelevant
- service consumers would need network/secrets changes

It is useful as a build/evaluation example, not as a service-isolation template yet.

#### Pi-hole / DNS services

Not a first candidate.

Why:

- DNS/DHCP/LAN behavior is network-sensitive
- may require LAN identity or privileged networking
- mistakes affect the whole network

### Proposed MicroVM prototype path

If MicroVMs are selected for a prototype, use this path:

1. Keep the native-container recommendation intact as the simple default.
2. Add MicroVM helpers separately under `mylib.units.microvm` or `mylib.units.vm` after naming is decided.
3. Start with one HTTP-only service, probably Actual Budget.
4. Use fully declarative `microvm.vms.<name>.config` for the prototype.
5. Use `qemu` first for flexibility.
6. Use TAP networking with either routed /32 addresses or an internal host bridge.
7. Point `my.vhosts.*.sources` at the guest IP and service port.
8. Put all state in a declared host share or declared volume with a backup plan.
9. Use host-managed read-only secret shares only for explicitly selected files.
10. Add logs/health checks to the acceptance criteria.
11. Only after the prototype works, decide whether to move to `cloud-hypervisor` or a stricter hypervisor.

Prototype acceptance criteria:

- host config evaluates
- MicroVM runner builds
- `microvm@<name>.service` starts
- guest has expected IP address
- host can reach `http://<guest-ip>:<port>`
- Traefik routes through `my.vhosts` to the guest backend
- state survives guest restart
- backup declaration covers the state path or dump artifact
- logs are inspectable from the host

### Decisions to make

1. **Role of MicroVMs**
   - replace native containers for server isolation
   - or act as a stronger-isolation tier for selected services
2. **First service**
   - low-risk HTTP service such as Actual Budget
   - or high-value service such as Forgejo
3. **Hypervisor default**
   - `qemu` for flexibility
   - `cloud-hypervisor` for a Rust MicroVM-focused runtime
   - `firecracker` later for a stricter model with more storage constraints
4. **Networking model**
   - routed TAP
   - internal bridge + NAT
   - QEMU user networking/forwarded ports for prototypes only
   - LAN bridge/macvtap for exceptional services
5. **Address registry**
   - manual IP/MAC/TAP declarations
   - numeric ID deriving IP/MAC/interface names
   - central `my.microvms` module with assertions
6. **Lifecycle model**
   - fully declarative host rebuilds
   - declarative deployment plus `microvm -u`
   - SSH deploy/switch scripts
7. **State model**
   - host shares for inspectable state
   - block volumes for database-like state
   - remote/external state
8. **Secrets model**
   - host-managed read-only secret shares
   - guest-managed sops-nix
   - systemd credentials or service-specific injection
9. **Backup model**
   - host path backup
   - guest service dumps
   - image-level backup
10. **Observability model**
    - shared journald
    - guest SSH
    - `machinectl` registration
    - service-level metrics/log shipping
11. **Helper API boundary**
    - small `u.microvm.*` helpers
    - full `my.microvms.<name>` module
    - per-unit isolation toggles

### Deferred questions for review

These are intentionally deferred because they are not blocking for the research appendix.

1. Should MicroVMs become the preferred server isolation path, or only a stronger-isolation tier for selected services?
2. Which service should be the first MicroVM prototype: Actual Budget, Forgejo, PostgreSQL, or something else?
3. For `tyrant`, are you comfortable introducing host-routed TAP/systemd-networkd-style VM networking, or should the first prototype use an internal bridge?
4. Do you prefer `qemu` first for flexibility, or `cloud-hypervisor` first because the repo sample already uses it?
5. Should persistent state favor host-visible shares for backup simplicity, or block volumes for stronger VM filesystem separation?
6. Should secrets be host-decrypted and shared read-only first, or should MicroVM guests get their own sops-nix key story from day one?
7. Should MicroVM updates be tied to host rebuilds, or should guests have a separate `microvm -u` / SSH deploy lifecycle?
8. Do you want the eventual helper to stay explicit (`u.microvm.*`) or grow into a central `my.microvms.<name>` option module with assertions?

## Source index

### Repo sources

- `docs/wip/isolation.md`
- `docs/wip/packaging.md`
- `AGENTS.md`
- `_lib/default.nix`
- `_lib/base.nix`
- `_lib/options/default.nix`
- `_lib/units/default.nix`
- `_lib/units/endpoint.nix`
- `_lib/units/_backup/types.nix`
- `flake.nix`
- `flake.lock`
- `outputs/hosts/default.nix`
- `_modules/vm.nix`
- `microvms/postgres/default.nix`
- `systems/_bootstrap/host.nix`
- `systems/_bootstrap/server.nix`
- `systems/_modules/dns/default.nix`
- `users/_units/default.nix`
- `users/_units/reverse-proxy/default.nix`
- `users/_units/reverse-proxy/traefik/default.nix`
- `users/_units/actual-budget/default.nix`
- `users/_units/forgejo/default.nix`
- `users/_units/fxsync/default.nix`
- `users/_units/pihole/default.nix`
- `globals/hosts.nix`
- `globals/dns.nix`

### External references

- NixOS manual, containers chapter: https://nixos.org/manual/nixos/stable/#ch-containers
- NixOS wiki, NixOS Containers: https://wiki.nixos.org/wiki/NixOS_Containers
- NixOS manual mirror, declarative containers: https://nlewo.github.io/nixos-manual-sphinx/administration/declarative-containers.xml.html
- NixOS manual mirror, container networking: https://nlewo.github.io/nixos-manual-sphinx/administration/container-networking.xml.html
- `containers.<name>.config`: https://search.nixos.org/options?show=containers.%3Cname%3E.config
- `containers.<name>.bindMounts`: https://search.nixos.org/options?show=containers.%3Cname%3E.bindMounts
- `containers.<name>.forwardPorts`: https://search.nixos.org/options?show=containers.%3Cname%3E.forwardPorts
- `containers.<name>.privateNetwork`: https://search.nixos.org/options?show=containers.%3Cname%3E.privateNetwork
- `containers.<name>.hostAddress`: https://search.nixos.org/options?show=containers.%3Cname%3E.hostAddress
- `containers.<name>.localAddress`: https://search.nixos.org/options?show=containers.%3Cname%3E.localAddress
- `containers.<name>.autoStart`: https://search.nixos.org/options?show=containers.%3Cname%3E.autoStart
- `containers.<name>.ephemeral`: https://search.nixos.org/options?show=containers.%3Cname%3E.ephemeral
- `containers.<name>.privateUsers`: https://search.nixos.org/options?show=containers.%3Cname%3E.privateUsers
- `containers.<name>.allowedDevices`: https://search.nixos.org/options?show=containers.%3Cname%3E.allowedDevices
- `containers.<name>.additionalCapabilities`: https://search.nixos.org/options?show=containers.%3Cname%3E.additionalCapabilities
- nixpkgs native container module: https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/virtualisation/nixos-containers.nix
- systemd-nspawn man page: https://man7.org/linux/man-pages/man1/systemd-nspawn.1.html
- machinectl man page: https://man7.org/linux/man-pages/man1/machinectl.1.html
- NixOS OCI containers options: https://search.nixos.org/options?query=virtualisation.oci-containers
- Arion docs: https://docs.hercules-ci.com/arion/
- microvm.nix README at pinned repo revision: https://raw.githubusercontent.com/microvm-nix/microvm.nix/2f2f62fdfdca2750e3399f66bd03986ab967e5ca/README.md
- microvm.nix handbook intro: https://raw.githubusercontent.com/microvm-nix/microvm.nix/master/doc/src/intro.md
- microvm.nix declaring MicroVMs: https://raw.githubusercontent.com/microvm-nix/microvm.nix/master/doc/src/declaring.md
- microvm.nix declarative MicroVMs: https://raw.githubusercontent.com/microvm-nix/microvm.nix/master/doc/src/declarative.md
- microvm.nix host preparation: https://raw.githubusercontent.com/microvm-nix/microvm.nix/master/doc/src/host.md
- microvm.nix host systemd services: https://raw.githubusercontent.com/microvm-nix/microvm.nix/master/doc/src/host-systemd.md
- microvm.nix options overview: https://raw.githubusercontent.com/microvm-nix/microvm.nix/master/doc/src/options.md
- microvm.nix options source: https://raw.githubusercontent.com/microvm-nix/microvm.nix/master/nixos-modules/microvm/options.nix
- microvm.nix host options source: https://raw.githubusercontent.com/microvm-nix/microvm.nix/master/nixos-modules/host/options.nix
- microvm.nix network interfaces: https://raw.githubusercontent.com/microvm-nix/microvm.nix/master/doc/src/interfaces.md
- microvm.nix simple network setup: https://raw.githubusercontent.com/microvm-nix/microvm.nix/master/doc/src/simple-network.md
- microvm.nix advanced network setup: https://raw.githubusercontent.com/microvm-nix/microvm.nix/master/doc/src/advanced-network.md
- microvm.nix routed network setup: https://raw.githubusercontent.com/microvm-nix/microvm.nix/master/doc/src/routed-network.md
- microvm.nix shares: https://raw.githubusercontent.com/microvm-nix/microvm.nix/master/doc/src/shares.md
- microvm.nix device passthrough: https://raw.githubusercontent.com/microvm-nix/microvm.nix/master/doc/src/devices.md
- microvm.nix output options: https://raw.githubusercontent.com/microvm-nix/microvm.nix/master/doc/src/output-options.md
- microvm.nix command workflow: https://raw.githubusercontent.com/microvm-nix/microvm.nix/master/doc/src/microvm-command.md
- microvm.nix SSH deploy workflow: https://raw.githubusercontent.com/microvm-nix/microvm.nix/master/doc/src/ssh-deploy.md
- microvm.nix FAQ: https://raw.githubusercontent.com/microvm-nix/microvm.nix/master/doc/src/faq.md
