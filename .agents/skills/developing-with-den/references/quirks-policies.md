# Quirks and policies

## Quirks

A quirk is a registered data key. Aspects emit data on that key;
consumers receive assembled data as function args.

```nix
den.quirks.firewall.description = "Firewall port declarations";

den.aspects.nginx.firewall = { ports = [ 80 443 ]; };
den.aspects.postgres.firewall = { ports = [ 5432 ]; };

den.aspects.networking.nixos = { firewall, lib, ... }: {
  networking.firewall.allowedTCPPorts =
    lib.concatMap (f: f.ports or []) firewall;
};
```

Use quirks when many aspects produce structured data for one or more
consumers and producer order should not matter.

Quirk payloads are not typed by the quirk registry. Validate in
consumers or producer helpers.

## Pipes

Pipe policies can alter where quirk data goes.

Common stages:

- `pipe.filter`
- `pipe.transform`
- `pipe.fold`
- `pipe.append`
- `pipe.expose` for child-to-parent flow
- `pipe.collect` for sibling/cross-host collection
- `pipe.as` to rename into a derived quirk
- `pipe.to` to target specific aspects

## Policies

Policies are context functions returning effects. They model topology,
enrichment, routing, and pipe effects.

```nix
den.policies.my-policy = { host, ... }:
  let inherit (den.lib.policy) resolve; in
  [ (resolve { myFlag = true; }) ];
```

Declaring a policy is not activation. Activate via includes:

```nix
den.schema.host.includes = [ den.policies.my-policy ];
den.default.includes = [ den.policies.my-policy ];
den.aspects.some-host.includes = [ den.policies.my-policy ];
```

Use policies for topology and routing. Use aspects for behavior
grouping.

## Recipes

### Replace an internal data-bus option with a quirk

Good target: backup item collection.

```nix
den.quirks.backup-items.description = "Backup item declarations";

den.aspects.server.units.forgejo.backup-items = [
  {
    unit = "forgejo";
    source = "/var/lib/forgejo";
    policy = "critical_infra";
  }
];

den.aspects.server.units.backup.nixos = { backup-items, ... }: {
  # render jobs from backup-items
};
```

Keep old NixOS options until all producers and consumers are moved.

### Expose user data to host scope

```nix
den.quirks.prefs.description = "User preferences";

den.policies.expose-prefs = { host, user, ... }:
  let inherit (den.lib.policy) pipe; in
  [ (pipe.from "prefs" [ pipe.expose ]) ];

den.schema.host.includes = [ den.policies.expose-prefs ];
```

### Collect sibling host data

```nix
den.policies.collect-backends = { host, ... }:
  let inherit (den.lib.policy) pipe; in
  [ (pipe.from "http-backends" [
      (pipe.collect ({ host, ... }: true))
    ]) ];
```

Use this for fleet-level aggregation, not local single-host data.

### Target one consumer

```nix
den.policies.route-secrets = { host, ... }:
  let inherit (den.lib.policy) pipe; in
  [ (pipe.from "secrets" [
      (pipe.to [ den.aspects.server.units.postgres ])
    ]) ];
```

## Source anchors

- Den docs: `explanation/quirks-and-pipes.mdx`, `guides/quirks.mdx`,
  `reference/quirks.mdx`, `explanation/policies.mdx`
- Den source: `nix/lib/policy-effects.nix`,
  `nix/lib/aspects/fx/assemble-pipes.nix`
