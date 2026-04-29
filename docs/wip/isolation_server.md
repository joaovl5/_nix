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

Hard constraint for this research phase: **do not use MicroVMs**.

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
