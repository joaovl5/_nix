# NixOS Containers Spec

Date: 2026-05-03

Sister document to: `docs/wip/isolation_server.md`

## Purpose

Define the first implementable contract for repo-native NixOS containers.

This is not AI-specific. The same container system should support ordinary server services, shared infrastructure clients, and future always-on agents such as a 24/7 `hermes`-style agent. AI services are likely an early candidate, but the abstraction should be generic server infrastructure.

## Goals

1. Use native NixOS `containers.<name>` as the runtime primitive.
2. Expose a repo-level `my.containers.<name>` composer above units.
3. Keep units as the smallest runnable service modules.
4. Let containers declare one or more units inside the guest.
5. Optimize helpers for the primary case: one container containing one unit.
6. Preserve host-owned ingress, persistence, backups, secrets, and shared providers.
7. Support cross-container and container-to-host communication from the start.
8. Keep `my.vhosts` HTTP-only; keep raw TCP/UDP in `my.tcp_routes` / `my.udp_routes`.

## Non-goals

- Do not implement MicroVMs in this phase.
- Do not make units decide whether they run on host or in a container.
- Do not add per-unit `isolation.backend` toggles.
- Do not import all of `users/_units/default.nix` into container guests.
- Do not emit `my.vhosts`, `my.tcp_routes`, or `my.udp_routes` from inside guest units.
- Do not create one Postgres instance per app container.
- Do not make this AI-only or agent-only.

## Core model

```text
unit      = smallest runnable service module
container = composer/deployer of one or more units
host      = owner of ingress, persistence, backups, secrets, and shared providers
```

A unit configures a local service inside a NixOS system.

A container decides where that unit runs, how state is mounted, how the host reaches it, and which host/peer services it may consume.

## Public API shape

### Primary one-unit helper

The primary ergonomic path should be short:

```nix
my.containers.actual-budget = u.container.unit.actual-budget {
  id = 11;
  target = "actual";
};
```

- !NOTE I'd prefer something like this shape:
- !ANSWER Agreed on the `c` namespace; `u` should stay for units. I also agree the unit identity should be explicit instead of derived from the container attr name. I would phrase the helper as `my.containers.actual-budget = c.unit "unit.actual-budget" { ... };`, where the first argument is the unit key/module identity and the attr name remains the container name. The HTTP vhost target can stay in options or come from unit metadata; I would not overload the first argument with vhost target.

  ```nix
  /*
      elsewhere defined:
      c = my.containers
      we use this instead of 'u' because 'u' is for units (hence `my.units`)
  */
  my.containers.actual-budget = c.unit "unit.actual" {
      id = 11;
      # ...
  };

  /*
    - target moved to 2nd argument instead!
    - unit name no longer derived, this should be explicit
  */
  ```

- create a native NixOS container named `actual-budget`
- import the minimal Actual Budget unit module into the guest
- enable the unit with its conventional defaults
- derive routed networking from `id = 11`
- mount persistent state from a host-owned path
- expose the default HTTP endpoint through host-owned `my.vhosts.actual-budget`
- register host-side backups for mounted state

Narrow overrides should stay possible:

```nix
my.containers.actual-budget = u.container.unit.actual-budget {
  id = 11;
  target = "actual";

  state.data.backup.policy = "sensitive_data"; # !ASK How would, just from this, we resolve the location from the actual unit for state? How is this auto-handled?
  # !ANSWER The backup policy alone should not resolve a state location. The location comes from unit metadata, e.g. `meta.nix` declares `state.data.guest_path = "/var/lib/actual"`; the container helper derives the host path from the container/unit/state names, e.g. `/var/lib/containers/actual-budget/actual-budget/data`. This override only changes the backup policy for an already-known `state.data`; if the unit has no `state.data` metadata, it should fail evaluation.
};
```

### One-unit helper with host provider access

Database-backed apps should remain concise:

```nix
my.containers.kaneo = u.container.unit.kaneo {
  id = 12;

  endpoints.web.target = "kaneo"; # !ASK I don't understand what 'endpoints' represents in this context, and how it would implicitly map to kaneo's unit options for web and api
  # !ANSWER `endpoints` was meant as named network-facing sockets declared by unit metadata. For Kaneo, metadata would say `web` maps to the web unit option and `api` maps to the API unit option. That is probably too implicit for the current spec; for v1 we can avoid multi-endpoint helpers and keep the first proof to one default endpoint.
  endpoints.api.target = "api.kaneo";

  postgres.enable = true; # !ASK What will *exactly* this be doing?
  # !ANSWER It would mean "this container needs the host Postgres provider". Lowered effects would be: add a database/user/client grant to host `unit.postgres`, allow this container IP in Postgres auth/firewall, project the password into the guest, and set the unit's DB connection options. Agreed this can move to a future iteration.
# !NOTE Also, I believe we can plan postgres and cross-container/host-to-container comms for a future iteration, and keep focusing on the contract for now, where the core goal of 1 container = 1 unit remains.
# !ANSWER Agreed. For the current spec, Postgres and cross-container/host-provider comms should be marked as future design notes, not part of the first implementation contract. The first contract should focus on `1 container = 1 unit`.
};
```

The helper expands into container config, guest unit options, host-side Postgres grants, projected secrets, vhosts, bind mounts, and backups.

`postgres.enable = true` is helper sugar. The normalized container record should lower it to `consumes.host.postgres`.

### Underlying multi-unit schema

The underlying schema must support multiple units per container even though helpers optimize for one unit.

```nix
my.containers.some-stack = {
  enable = true;
  id = 20;

  units = {
    web = u.container.unit.some-web {
      endpoints.http.port = 8080;
    };

    worker = u.container.unit.some-worker {
      queue = "default";
    };
  };

  expose.web = { # !ASK What is exactly this and how will this work?
    # !ANSWER `expose.web` is the normalized host-ingress record. It says: take unit `web`'s endpoint named `http`, expose it as a host vhost target `some`, and have the container composer emit `my.vhosts.some-stack` or similar. In the one-unit helper this should be derived; the explicit form is only for multi-unit/multi-endpoint stacks.
    unit = "web";
    endpoint = "http";
    target = "some";
  };
};
```

This explicit form is for app stacks and unusual services. It should not be required for normal one-service containers.

## Option schema sketch

### `my.containers.<name>`

Conceptual schema:

```nix
my.containers.<name> = {
  enable = true;
  id = 11;

  units = { ... };
  expose = { ... };
  consumes = { ... }; # !ASK What does this mean?
  # !ANSWER `consumes` means declared dependencies from this container to another container or a host provider. Example: app consumes host Postgres or peer Redis. It should be future-facing for now; v1 can omit it from the active contract.
  mounts = { ... }; # !ASK What is the shape for mounts?
  # !ANSWER `mounts` are host-to-guest filesystem mappings. Minimal shape would be `mounts.<name> = { guest_path; host_path; read_only; }`, plus optional backup metadata. For the primary helper case, mounts should be generated from unit `state` metadata rather than written manually.
  secrets = { ... };

  network = {
    host_address = "10.88.11.1";
    local_address = "10.88.11.2";
    nat.enable = false;
  };

  backup.items = { ... };
};
```

Required fields for the first version:

- `enable`
- `id`
- `units`

Derived fields:

- `network.host_address`
- `network.local_address`
- host-facing `<name>.containers` entry, when supported by NixOS containers
- default state host paths
- default vhost sources

### Unit entries inside a container

A container unit entry should hold only guest-local unit options plus metadata needed by the composer.

Conceptual shape:

```nix
units.actual-budget = {
  module = users/_units/actual-budget/unit.nix;

  config = {
    my."unit.actual-budget" = {
      enable = true;
      endpoint = {
        port = 5006;
        bind = "0.0.0.0";
      };
      state.data.path = "/var/lib/actual";
    };
  };

  endpoints.web = { # !ASK I need to be ellucidated on how this works still
  # !ANSWER This is metadata for a named endpoint, not a direct unit option by itself. It says "this unit has a web HTTP endpoint on port 5006 with default vhost target actual". The helper uses it to set the guest unit's local port/bind options and to generate host `my.vhosts` when exposed. This needs clearer wording or a simpler v1 shape.
    protocol = "http";
    port = 5006;
    target = "actual";
  };

  state.data = {
    guest_path = "/var/lib/actual";
    host_path = "/var/lib/containers/actual-budget/actual-budget/data";
    read_only = false;
    backup.policy = "sensitive_data";
  };
};
```

The public helper should construct this shape; users should rarely need to write it manually.

## Minimal unit contract

A migrated unit should split into:

```text
users/_units/<unit>/
  default.nix  # existing host wrapper / compatibility interface
  unit.nix     # minimal guest-local service module
  meta.nix     # defaults for container helpers
```

### `unit.nix`

!NOTE There seems to be the implication that we'd want a major refactor for all units to support such a shape. Is this needed for this? Still thinking about it.
!ANSWER No, a major refactor of all units is not needed. Only units we choose to containerize need a minimal guest-local module. The host `default.nix` can remain as compatibility wrapper. First target should be Actual Budget only; other units can stay unchanged until migrated.

`unit.nix` is the only unit file imported into a container guest.

It may define options like:

```nix
my."unit.actual-budget" = {
  enable = true;

  endpoint = {
    port = 5006;
    bind = "0.0.0.0";
  };

  state.data.path = "/var/lib/actual";
};
```

It emits only guest-local service config:

```nix
services.actual = {
  enable = true;
  settings = {
    dataDir = opts.state.data.path;
    port = opts.endpoint.port;
  };
};

networking.firewall.allowedTCPPorts = [opts.endpoint.port];
```

It must not emit:

- `my.vhosts`
- `my.tcp_routes`
- `my.udp_routes`
- `containers.<name>`
- host bind mounts
- host backup paths
- cross-container firewall policy
- shared provider registration

### `meta.nix`

`meta.nix` records defaults for helper generation.

Example:

```nix
{
  name = "actual-budget";
  module = ./unit.nix;

  endpoints.web = {
    protocol = "http";
    port = 5006;
    target = "actual";
  };

  state.data = {
    guest_path = "/var/lib/actual";
    backup.policy = "sensitive_data";
  };
}
```

`meta.nix` should not emit NixOS config by itself. It is data consumed by helpers.

### `default.nix`

`default.nix` keeps current host-run unit behavior working.

It may reuse `unit.nix`, but it remains responsible for host-run integration such as current `my.vhosts` declarations and host-local service assumptions.

## Container generation contract

For this input:

```nix
my.containers.actual-budget = u.container.unit.actual-budget {
  id = 11; # !NOTE I'm still not getting where this is used so far
  # !ANSWER `id` is the stable network/allocation identity. With the current proposed scheme, `id = 11` derives `hostAddress = 10.88.11.1` and `localAddress = 10.88.11.2`, and later drives assertions/firewall/provider grants. It is not about unit identity; it is about container network identity.
  target = "actual";
};
```

The composer should generate, conceptually:

```nix
containers.actual-budget = {
  autoStart = true;
  privateNetwork = true;
  privateUsers = false; # v1 default for writable bind-mounted state
  restartIfChanged = true;

  hostAddress = "10.88.11.1";
  localAddress = "10.88.11.2";

  bindMounts."/var/lib/actual" = {
    hostPath = "/var/lib/containers/actual-budget/actual-budget/data";
    isReadOnly = false;
  };

  config = { ... }: {
    imports = [
      users/_units/actual-budget/unit.nix
    ];

    my."unit.actual-budget" = {
      enable = true;
      endpoint = {
        port = 5006;
        bind = "0.0.0.0";
      };
      state.data.path = "/var/lib/actual";
    };
  };
};

my.vhosts.actual-budget = {
  target = "actual";
  sources = ["http://actual-budget.containers:5006"];
};

my.containers.actual-budget.backup.items.actual_budget_data = {
  kind = "path";
  policy = "sensitive_data";
  path.paths = [
    "/var/lib/containers/actual-budget/actual-budget/data"
  ];
};
```

The generated guest config should include a baseline module with:

```nix
{ lib, ... }: {
  networking.useHostResolvConf = lib.mkForce false;
  services.resolved.enable = true;

  system.stateVersion = "25.11";
}
```

For routed containers, the generated guest baseline also defines the host-gateway alias used by provider configs:

```nix
networking.hosts."10.88.11.1" = ["host.containers"];
```

Each unit opens only the guest firewall ports it serves.

## User namespaces and writable state

`privateUsers = "pick"` is safer for user namespace isolation, but it complicates writable host bind mounts. The current NixOS container module idmaps its internal `/nix` bind mounts for user namespaces, but ordinary `bindMounts` are emitted as plain `--bind` / `--bind-ro`. That means a writable host state bind may not be writable from a namespaced guest without a separate ownership/idmap strategy.

First implementation rule:

- containers with writable host bind-mounted state use `privateUsers = false`
- containers with only read-only binds or fully externalized state may opt into `privateUsers = "pick"`
- idmapped writable state mounts remain a future hardening task

This is a conscious isolation trade-off for the first Actual Budget milestone. It keeps the state model simple and implementable while preserving network/process/service isolation from native containers.

## Networking contract

Use routed per-container links.

For `id = 11`:

```nix
hostAddress = "10.88.11.1";
localAddress = "10.88.11.2";
```

Rules:

- reserve `10.88.0.0/16` for first-implementation routed containers unless host networking conflicts before rollout
- every container receives a unique numeric `id` in the range `1..254`
- the host side of the veth pair is `10.88.<id>.1`
- the container side is `10.88.<id>.2`
- container names must not contain underscores
- generated HTTP sources prefer `http://<container>.containers:<port>`
- literal `localAddress` sources are allowed as fallback if generated host entries do not work as expected
- `forwardPorts` is not the default; keep it as a fallback for host-port consumers
- each guest gets `host.containers` mapped to its own `hostAddress` for host-provider access
- outbound Internet/NAT is opt-in per container

## Ingress contract

The host owns all public or LAN ingress.

HTTP:

```nix
my.vhosts.actual-budget = {
  target = "actual";
  sources = ["http://actual-budget.containers:5006"];
};
```

TCP:

```nix
my.tcp_routes.forgejo_ssh = {
  listen.port = 22;
  upstreams = ["forgejo.containers:4220"];
  rule = "HostSNI(`*`)";
};
```

UDP follows `my.udp_routes`.

Do not add TCP/UDP semantics to `my.vhosts`. DNS derivation remains based on `my.vhosts` only.

Canonical lowering rule: `expose.<name>.target` is the host vhost target. Unit endpoint metadata may provide a default target, and one-unit helpers may accept `target = "..."` as sugar, but the normalized container record should lower that into `expose.<name>.target`.

!ASK This is not clear to me, can you try explaining this in a more concise and intentional manner, with a quick comparison to how things are currently in repo to how things would be?
!ANSWER Current repo: a unit directly declares `my.vhosts.foo = { target = ...; sources = ["http://localhost:port"]; }`. Proposed container shape: the unit only declares "I serve HTTP on port X"; the container owns host ingress and lowers `target = "actual"` into `my.vhosts.actual-budget = { target = "actual"; sources = ["http://actual-budget.containers:5006"]; }`. So `target` remains the DNS/vhost name, but it is owned by the container layer, not the guest unit.

## Cross-container communication

!NOTE As aforementioned, this is not needed now (not a priority, nice to have)
!ANSWER Agreed. This should be demoted to a future iteration note. It is useful to keep the vocabulary in mind, but it should not drive the first implementation.

The schema should support declared consume/provide edges from the start.

Example:

```nix
my.containers.app = u.container.unit.app {
  id = 12;

  consumes.redis = {
    container = "redis"; # !ASK why specify container twice and not just have, say, `consumes` being an array of attrsets of the shape {container = 'container_name'; ...}
    # !ANSWER The attr key (`redis`) is a local dependency alias; `container = "redis"` is the target container. That lets a service call a dependency `cache` while the target container is named `redis`, and supports multiple dependencies to one container. A list of attrsets is also viable; attrsets are usually easier to override/merge in Nix. Since this is future work, we do not need to settle it now.
    endpoint = "redis"; # !ASK why do we need specifying endpoint here? from some text below, it seems 'endpoint' is kind of an abstraction over a port so we can derive firewall rules from (?); if so, that's nice, though this is not properly documented on this spec so far
    # !ANSWER Yes: `endpoint` is meant to name a provided port/protocol bundle on the target, so consumers do not hardcode ports. For example Redis could provide endpoint `redis` = TCP 6379. Then firewall/routing can be derived. This is underdocumented and should be deferred or clarified later.
  };
};

my.containers.redis = u.container.unit.redis {
  id = 13;
};
```

The host layer can later derive firewall policy:

```text
allow 10.88.12.2 -> 10.88.13.2:6379
```

No declared edge means no intended peer access.

The first implementation may only validate the shape and generate addresses. It should not require perfect firewall enforcement on day one, but the data model must make enforcement possible later. !NOTE agreed on that, though impl. should make it clear (through comments and etc) enforcement is still to be made
!ANSWER Agreed. If this remains in the spec as future work, implementation comments/assertions should explicitly say declared edges are documentation/validation only until firewall enforcement lands.

## Host providers

Some providers remain on the host for now. Postgres is the first important provider.

Rationale:

- we do not want one Postgres instance per app container
- we do not need to migrate Postgres into its own container immediately
- host-provider access is less isolated, but acceptable for the first phase
- the provider schema gives a migration path to a future Postgres container

Canonical normalized edge:

```nix
my.containers.kaneo = u.container.unit.kaneo {
  id = 12;

  consumes.host.postgres = { # !ASK can you ellaborate on `host.postgres` internals?
    # !ANSWER Internally, `host.postgres` would be a named provider edge to the host's `unit.postgres`. It is not a container. The provider would translate this into host-side DB/user/client auth, an allowed client address for this container, a guest DB host such as `host.containers`, and a projected password/credential. This should be future work, not v1.
    database = "kaneo";
  };
};
```

Unit-specific helpers may expose shorter sugar such as `postgres.enable = true`, but that sugar should lower to `consumes.host.postgres` before the container module emits host or guest config.

Host-side expansion:

```nix
my."unit.postgres".container_clients.kaneo = {
  address = "10.88.12.2/32";
  databases = ["kaneo"];
};
```

Guest-side unit config:

```nix
my."unit.kaneo".database = {
  host = "host.containers";
  port = 5432;
  name = "kaneo";
  user = "kaneo";
  password_file = "/run/container-secrets/postgres-password";
};
```

Postgres provider requirements:

- listen on a host address reachable from routed containers
- generate `pg_hba` entries for declared container clients only
- create or reuse database/user declarations through existing `unit.postgres` patterns
- expose only the required secret file to the guest

Generic host access should remain explicit and should use the same normalized provider edge shape:

```nix
consumes.host.postgres = {
  database = "kaneo";
};

```

Do not grant blanket host access to containers.

## State, secrets, and backups

### State

The host owns persistent state paths.

Default state path convention:

```text
/var/lib/containers/<container>/<unit>/<state-name>
```

Example bind mount:

```nix
bindMounts."/var/lib/actual" = {
  hostPath = "/var/lib/containers/actual-budget/actual-budget/data";
  isReadOnly = false;
};
```

`ephemeral = true` is only safe when all meaningful state is externalized through mounts or providers.

### Secrets

!NOTE Require more thought - sops-nix requires a SOPS key, so that has to be mounted as well, and I think there's an easier way of making container-wide secrets than relying on mounting a key to an isolated host: perhaps we could have secrets as envvars in the container-side instead of mounting the actual secret files themselves. Tell me what do you think.
!ANSWER I agree that mounting a SOPS key into the guest is the wrong default. Environment variables are simpler but weaker: they can leak through process environments, service introspection, logs, or accidental dumps. A better first shape is host-decrypted, container-specific secret material projected as files or systemd credentials (`LoadCredential`-style), without giving the guest the SOPS key and without mounting the whole secret tree. Container-wide secret projection can be a host-owned `/run/container-secrets/<container>/...` interface.

First-pass model: host-managed read-only secret bind mounts.

Rules:

- project only explicitly requested secret files into the guest
- do not bind the whole host secret tree
- keep guest-managed secrets as a later option if a service benefits from it

Example guest path:

```text
/run/container-secrets/postgres-password
```

### Backups

Backups for containerized units are host-owned. !ASK to make sure I got this right: `my.containers` derives declared backups into host-scoped config, through the mapped filesystem of the container?
!ANSWER Yes. `my.containers` should lower backup declarations into host-scoped backup config that points at the host path backing the bind mount. Example: guest sees `/var/lib/actual`, host backs it with `/var/lib/containers/actual-budget/actual-budget/data`, and backup targets the host path.

Rules:

- path backups target host bind-mount paths
- host-provider databases use the provider backup/dump model
- future containerized databases should write dumps to host-mounted state or expose a declared dump path
- backup tooling should not inspect container root filesystems directly

## AI / agent services

The container system must remain generic, but always-on agents are expected users.

A future `hermes`-style 24/7 agent should be modeled as a normal unit/container pair:

```nix
my.containers.hermes = u.container.unit.hermes {
  id = 30;

  endpoints.web.target = "hermes";

  state.memory.backup.policy = "sensitive_data";

  consumes.host.postgres = true;
};
```

Agent-specific concerns should be unit metadata or unit options, not special container concepts:

- work directories
- prompt/config mounts
- memory/state paths
- browser or tool state
- provider secrets
- optional web control endpoint
- resource limits

The container layer should only care that Hermes is a unit with endpoints, state, secrets, and provider edges.

## Helper namespace

Use a small helper namespace under `my.units` / `mylib.units` style:

```nix
u.container = { # !NOTE As noted previously, `u.container` is wrong, `u` stands for units. We should have a `c` namespace.
  # !ANSWER Agreed. Use a `c` namespace for container helpers. `u` should remain the units namespace.
  mk = { name, id, units, expose ? {}, consumes ? {}, ... }: { ... };

  state = { guest_path, backup ? null, read_only ? false, ... }: { ... };

  endpoint = {
    port,
    target,
    protocol ? "http",
    bind ? "0.0.0.0",
    ...
  }: { ... };

  postgres_client = { database ? null, ... }: { ... };

  unit = {
    actual-budget = { id, target ? "actual", ... }: { ... };
    kaneo = { id, ... }: { ... };
    hermes = { id, ... }: { ... };
  };
};
```

## Assertions

Add assertions early for:

- duplicate
  - container IDs
  - derived host addresses
  - derived local addresses
  - HTTP `target` values across `my.vhosts`
- invalid container names, including underscores
- duplicate HTTP `target` values across `my.vhosts`
- `expose.<name>` references to missing units/endpoints
- host-provider clients without matching provider support
- writable state entries without a host path or generated host path

Later assertions:

- no undeclared cross-container firewall edges
- no provider edge to disabled provider
- no secrets projected into guests without explicit declaration
- no container outbound Internet access unless enabled

## First milestone

Actual Budget should be the first proof.

Acceptance criteria:

- Nix evaluation succeeds.
- Host build succeeds for the target server.
- Generated container uses `privateNetwork = true`.
- Container addresses derive from `id`.
- Container imports only the minimal Actual Budget unit module.
- Actual Budget responds through host Traefik.
- Persistent state survives container restart.
- Backup declarations point at host state paths.
- Writable state works with the chosen `privateUsers` mode.

## Open decisions

- Exact names for helper namespace and generic/multi-unit helper constructors.
- Whether `meta.nix` should be pure data or a function receiving `pkgs`, `lib`, and `mylib`.
- Exact provider schema for Postgres and future host providers.
- Whether the first implementation should generate firewall rules or only validate declared communication edges.
- Longer-term strategy for idmapped writable bind mounts with `privateUsers = "pick"`.
