# NixOS Containers Spec v2 Digest

Sister draft target: `docs/wip/nixos_containers_spec_v2.md`

This file is the pre-spec decision map used to create
`docs/wip/nixos_containers_spec_v2.md`.

## Why v2

The first spec mixed three things:

1. agreed architecture,
2. unresolved questions,
3. implementation sketches.

That made it hard to read and hard to decide what was actually
accepted.

For v2, the flow should be:

1. decide the contract in small batches,
2. write the spec only from accepted decisions,
3. keep future ideas clearly separate from v1 scope.

## Decision results used for v2

- V1 specifies normalized multi-unit containers, host-provider edges,
  and cross-container edges, but implementation may enforce them in
  stages.
- Primary helper shape:
  `my.containers.<name> = c.unit "unit.<name>" { id = ...; target = ...; };`.
- Existing `default.nix` remains the host wrapper; migrated units add
  guest-safe `unit.nix`.
- Unit metadata lives in
  `o.unit "unit.name" (with o; { ...options...; }) { ...metadata...; }`.
- Endpoints are explicit attrsets containing served socket facts only:
  `{ protocol; port; }`. Container exposure supplies host `target`.
- Multi-unit containers use a plain attrset with
  `units = { ... }; expose = [ ... ];`.
- Container IDs derive `10.88.<id>.1` host and `10.88.<id>.2` guest
  addresses.
- Writable host-mounted state uses `privateUsers = "no"` in v1;
  idmapped/userns hardening is later.
- Secrets use host-decrypted env files mounted into the guest;
  services opt into `EnvironmentFile`.

## Working anchors

These seem stable enough to keep unless you say otherwise.

### Runtime

- Use native NixOS `containers.<name>` first.
- MicroVMs stay out of this first implementation.
- Containers use `privateNetwork = true` by default.
- `forwardPorts` is not the normal ingress path.

### Layering

```text
unit      = smallest runnable service module
container = composer/deployer of one or more units
host      = owner of ingress, persistence, backups, secrets, and shared providers
```

A unit should describe how to run a service inside a NixOS system.

A container should decide:

- which unit runs inside it,
- how state is mapped,
- how the host reaches it,
- what host or peer services it may use.

### Primary use-case

The main ergonomic path is:

```text
one container = one unit
```

The underlying model may support multiple units per container, but v1
should not be optimized around that.

### Helper namespace

Use a container helper namespace named `c`, not `u.container`.

`u` remains for units.

### Host-owned ingress

`my.vhosts` remains HTTP-only.

Raw TCP/UDP remain in `my.tcp_routes` and `my.udp_routes`.

Guest units do not emit host vhosts or routes.

### Host-owned persistence and backups

Containerized state is backed by host paths.

Backups target host paths, not guest root filesystems.

### Host/shared providers

Shared Postgres and cross-container communication matter, but they do
not need to be fully specified in the first spec.

The first spec should leave a clean seam for them.

## Main unresolved seams

These are the parts that need decisions before writing
`nixos_containers_spec_v2.md`.

### 1. Public helper shape

Current candidate shape:

```nix
my.containers.actual-budget = c.unit "unit.actual-budget" {
  id = 11;
  # exposure/state overrides here
};
```

Open question: what should the first argument mean?

Possibilities:

- unit key, e.g. `"unit.actual-budget"`
- unit registry key, e.g. `"actual-budget"`
- unit + default exposure target

The current preference appears to be: explicit unit identity, not
inferred from container name.

### 2. Unit file shape

Two competing conventions:

```text
A. users/_units/<unit>/default.nix = host wrapper
   users/_units/<unit>/unit.nix    = guest-safe minimal unit
```

```text
B. users/_units/<unit>/default.nix = minimal unit
   host wrapper moves elsewhere or becomes explicit adapter
```

A is safer for existing units.

B is cleaner long-term if we are willing to change unit conventions.

### 3. Metadata location

The spec needs one way to answer:

- what endpoint(s) does this unit serve?
- what state paths does it need?
- what secrets may be projected?
- what backup defaults apply?

Possible homes:

- separate `meta.nix`, pure data;
- metadata inside the unit option declaration via something like
  `o.unit`;
- no metadata file, require each helper to know unit-specific facts.

The current discussion leaned away from redundant `name` and `module`
fields in metadata.

### 4. Endpoint meaning

The old spec used `endpoints` before defining it clearly.

A clearer split may be:

```text
unit endpoint
  "this service can listen on protocol/port X"

container exposure
  "publish that endpoint on the host as target Y"
```

Important: `target = "actual"` is not a TLD or FQDN. It is the
existing repo vhost target concept used by `my.vhosts`.

Open question: should v1 expose only one default HTTP endpoint,
avoiding general endpoint machinery until later?

### 5. Container `id`

The previous proposal used numeric `id` for network allocation.

Example formula:

```text
id = 11
host side      = 10.88.11.1
container side = 10.88.11.2

id = 12
host side      = 10.88.12.1
container side = 10.88.12.2
```

Open question: keep this formula, or use explicit addresses to make
the spec less magical?

### 6. Writable state and user namespaces

Known issue:

- `privateUsers = "pick"` is safer,
- but writable host bind mounts are simpler with
  `privateUsers = "no"`.

Open question: should v1 explicitly choose `privateUsers = "no"` for
writable-state containers, or avoid saying this in the high-level spec
until implementation?

### 7. Secrets

Avoid mounting a SOPS key into the guest as the default.

Possible first models:

- host-decrypted secret files projected into the container;
- systemd credentials projected to specific services;
- envvar sugar for units that explicitly want it.

Important nuance: after full container compromise, any secret made
available to that container is reachable. The distinction is mostly
about accidental exposure, service scoping, and operational
cleanliness.

### 8. Future communication model

Postgres, cross-container dependencies, and host providers should be
acknowledged but probably not specified deeply in v1.

Open question: should v2 contain only a short "future seam" section,
or a minimal normalized shape such as `consumes` without
implementation promises?

## Suggested question batches

Instead of asking one-by-one, ask in batches:

1. v1 scope and reading style,
2. public API shape,
3. unit metadata model,
4. endpoint/exposure model,
5. networking/id model,
6. state/secrets/security trade-offs,
7. future seams.

The next step should be a batched `ask` covering the decisions above.
After those answers, write only the accepted contract into
`docs/wip/nixos_containers_spec_v2.md`.
