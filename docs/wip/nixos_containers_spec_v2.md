# NixOS Containers Spec v2

Sister document to: `docs/wip/isolation_server.md`

Decision digest: `docs/wip/nixos_containers_spec_v2_digest.md`

## Purpose

Define the repo contract for native NixOS containers.

This is not AI-specific. Future always-on agents such as a
`hermes`-style service should use the same container model as ordinary
server services.

## Design goals

- Use native NixOS `containers.<name>` as the first isolation backend.
- Keep units small: a unit knows how to run a service inside a NixOS
  system.
- Put composition above units: a container decides what units run
  together and how the host integrates them.
- Optimize the helper API for the common case: one container
  containing one unit.
- Still define the normalized shape for multi-unit containers.
- Keep ingress, persistence, backups, secret projection, and shared
  providers host-owned.
- Keep `my.vhosts` HTTP-only. TCP/UDP stay in `my.tcp_routes` and
  `my.udp_routes`.

## Non-goals

- Do not implement MicroVMs in this phase.
- Do not add per-unit isolation toggles.
- Do not make units decide whether they run on the host or inside a
  container.
- Do not import all host units into container guests.
- Do not mount a SOPS key into guests as the default secret model.
- Do not require perfect firewall enforcement on the first
  implementation, even though communication schemas are specified
  here.

## Vocabulary

```text
unit
  The smallest runnable service module.

container
  A composer/deployer for one or more units.

host
  The owner of ingress, state backing paths, backups, secret materialization, and shared providers.

endpoint
  A socket served by a unit: protocol + port.
  It does not include DNS/TLD/vhost concerns.

exposure
  A host-side publication of an endpoint.
  For HTTP, this lowers to `my.vhosts`.

provider
  A shared service consumed by containers.
  It may live on the host now and move into a container later.
```

## Primary API

Use the `c` helper namespace for containers.

`u` remains reserved for units.

Primary one-unit shape:

```nix
my.containers.actual-budget = c.unit "unit.actual-budget" {
  id = 11;
  target = "actual";
};
```

Meaning:

- create a container named `actual-budget`;
- put unit `unit.actual-budget` inside it;
- derive networking from `id = 11`;
- expose the unit's default HTTP endpoint as host vhost target
  `actual`;
- mount declared state from host-owned paths;
- register host-owned backups for mounted state.

`target` is the same concept currently used by `my.vhosts`: a vhost
target label such as `actual`, not a TLD/FQDN.

If `target` is omitted, the helper creates the container without host
HTTP exposure.

## Explicit multi-unit shape

The helper optimizes for one unit, but the normalized container shape
supports multiple units.

```nix
my.containers.some-stack = {
  enable = true;
  id = 20;

  units = {
    web = {
      unit = "unit.some-web";
      options = {
        # guest-local unit options
      };
    };

    worker = {
      unit = "unit.some-worker";
      options = {
        # guest-local unit options
      };
    };
  };

  expose = [
    {
      unit = "web";
      endpoint = "web";
      target = "some";
    }
  ];
};
```

Rules:

- `units.<alias>.unit` names the unit key.
- `units.<alias>.options` contains only guest-local unit options.
- `expose` is a list to avoid repeating the same name as both an attr
  key and a field.
- In the one-unit helper, `target = "..."` is sugar for exposing that
  unit's default HTTP endpoint.

## Unit file contract

Existing host-facing unit files keep working.

For a migrated unit:

```text
users/_units/<unit>/
  default.nix  # existing host wrapper / compatibility interface
  unit.nix     # guest-safe minimal unit module
```

`default.nix` may reuse `unit.nix`, but it remains allowed to emit
host integration such as `my.vhosts`, host-local backups, and other
current host assumptions.

`unit.nix` is the only unit module imported into a container guest.

A guest-safe unit must not emit:

- `my.vhosts`
- `my.tcp_routes`
- `my.udp_routes`
- `containers.<name>`
- host bind mounts
- host backup paths
- cross-container firewall policy
- host-provider registration

## Unit metadata contract

Unit metadata lives with the unit option declaration through `o.unit`.

Shape:

```nix
o.unit "unit.actual-budget" (with o; {
  enable = toggle "Enable Actual Budget" false;

  endpoint = {
    port = opt t.port 5006 "Port to listen on";
    bind = opt t.str "0.0.0.0" "Bind address";
  };

  state.data.path = opt t.path "/var/lib/actual" "Data directory";
}) {
  endpoints.web = {
    protocol = "http";
    port = 5006;
  };

  state.data = {
    guest_path = "/var/lib/actual";
    backup.policy = "sensitive_data";
  };
};
```

Rules:

- The first argument is the unit key.
- The second argument is the unit's option declaration.
- The third argument is read-only metadata consumed by container
  helpers.
- Endpoint metadata is an explicit attrset.
- Endpoint metadata contains served socket facts only: protocol and
  port.
- Host exposure target stays container-owned.
- Metadata must not include redundant `name` or `module` fields.

## Endpoint and exposure flow

A unit says:

```nix
endpoints.web = {
  protocol = "http";
  port = 5006;
};
```

A container says:

```nix
expose = [
  {
    unit = "main";
    endpoint = "web";
    target = "actual";
  }
];
```

The host lowers that to:

```nix
my.vhosts.actual-budget = {
  target = "actual";
  sources = ["http://actual-budget.containers:5006"];
};
```

For the primary helper:

```nix
c.unit "unit.actual-budget" {
  id = 11;
  target = "actual";
}
```

is shorthand for exposing the unit's default HTTP endpoint.

TCP and UDP endpoints use the same endpoint idea, but they do not
lower through `my.vhosts`.

## Network identity

Each container has a numeric `id`.

The first address formula is:

```text
id = 11
host side      = 10.88.11.1
container side = 10.88.11.2

id = 12
host side      = 10.88.12.1
container side = 10.88.12.2
```

Rules:

- reserve `10.88.0.0/16` for this container network unless rollout
  finds a conflict;
- every container gets one unique numeric `id`;
- the host side is `10.88.<id>.1`;
- the container side is `10.88.<id>.2`;
- container names must not contain underscores;
- `privateNetwork = true` is the default;
- `forwardPorts` is not the default ingress path;
- `host.containers` resolves inside the guest to that container's
  host-side address;
- outbound Internet/NAT is opt-in.

## State and backups

The host owns persistent state backing paths.

Default host path convention:

```text
/var/lib/containers/<container>/<unit>/<state-name>
```

Example:

```text
guest path: /var/lib/actual
host path:  /var/lib/containers/actual-budget/actual-budget/data
```

Backups are host-owned.

A container state declaration lowers to backup config for the host
path, not the guest path.

Rules:

- path backups target host bind-mount paths;
- backup policy defaults may come from unit metadata;
- container declarations may override backup policy;
- backup tooling should not inspect container root filesystems
  directly.

## User namespaces and writable state

`privateUsers = "pick"` is safer, but writable host bind mounts are
simpler without user namespaces.

First implementation rule:

- containers with writable host bind-mounted state use
  `privateUsers = "no"`;
- containers with only read-only binds or fully externalized state may
  opt into `privateUsers = "pick"`;
- idmapped writable state mounts are future hardening.

This is a deliberate first-phase trade-off.

## Secrets and environment variables

The first secret interface is environment variables.

Concrete mechanism:

- the host decrypts or obtains secret values;
- the host writes a container-specific env file outside the Nix store;
- that env file is mounted read-only into the guest;
- unit services opt into it through `EnvironmentFile` or equivalent
  service-local config.

Do not mount a SOPS key into the guest by default.

Do not put secret values directly in Nix-generated config.

A full container compromise can read any secret exposed to that
container. The env-file model is about operational simplicity and
avoiding guest-side SOPS key management, not about making exposed
secrets unreadable after compromise.

## Host providers

Host providers are specified as part of the v1 schema, even if
implementation arrives in stages.

A host provider is a host-owned shared service consumed by a
container.

Postgres is the first provider shape:

```nix
my.containers.kaneo = c.unit "unit.kaneo" {
  id = 12;
  target = "kaneo";

  consumes.host.postgres = {
    database = "kaneo";
    env = "DATABASE_URL";
  };
};
```

Meaning:

- the container needs access to host Postgres;
- the requested database is `kaneo`;
- the unit receives the connection string through env var
  `DATABASE_URL`;
- the host provider decides how to create users, grants, passwords,
  and `pg_hba` entries.

No container gets blanket host access from this declaration.

## Cross-container communication

Cross-container communication is specified as a schema now, but
firewall enforcement may arrive later.

A container can consume another container's endpoint:

```nix
my.containers.app = c.unit "unit.app" {
  id = 12;
  target = "app";

  consumes.containers.redis = {
    endpoint = "redis";
  };
};

my.containers.redis = c.unit "unit.redis" {
  id = 13;
};
```

Rules:

- `consumes.containers.redis` targets container `redis` by default;
- use `container = "..."` only when the local dependency name differs
  from the target container name;
- `endpoint` names a provided endpoint on the target container;
- consumers should not hardcode peer ports;
- the schema must preserve enough data to generate firewall rules
  later.

Example with alias:

```nix
consumes.containers.cache = {
  container = "redis";
  endpoint = "redis";
};
```

## Generation contract

The container layer must be able to lower accepted declarations into:

- `containers.<name>`;
- generated private-network addresses;
- guest imports of only the selected `unit.nix` files;
- guest unit options;
- host bind mounts for state;
- host-owned backup declarations;
- host-owned env files for secrets/provider credentials;
- HTTP `my.vhosts` for HTTP exposures;
- TCP/UDP routes for non-HTTP exposures;
- host-provider client records;
- future cross-container firewall rules.

The spec defines the data contract. The first implementation may
validate some communication declarations before enforcing all of them.

## Agent services

AI/agent workloads are normal units.

Example:

```nix
my.containers.hermes = c.unit "unit.hermes" {
  id = 30;
  target = "hermes";

  consumes.host.postgres = {
    database = "hermes";
    env = "DATABASE_URL";
  };
};
```

Agent-specific concerns belong to the unit:

- prompt/config paths;
- work directories;
- memory/state paths;
- browser/tool state;
- model/provider credentials;
- optional control endpoint.

The container layer only sees units, endpoints, state, secrets,
exposures, and provider edges.

## First proof

Use Actual Budget as the first proof.

Acceptance criteria:

- the primary helper can declare `my.containers.actual-budget`;
- the container uses `privateNetwork = true`;
- addresses derive from `id`;
- only Actual Budget's `unit.nix` is imported into the guest;
- the default HTTP endpoint is exposed through host Traefik;
- state is host-backed and survives container restart;
- backups target the host state path;
- writable state works with the chosen `privateUsers` mode.

## Deferred details

These are intentionally not settled by this spec:

- exact import path for the `c` helper namespace;
- exact source-reference syntax for env secrets;
- exact firewall implementation for declared communication edges;
- exact TCP/UDP route helper syntax;
- future idmapped writable mounts with `privateUsers = "pick"`.
