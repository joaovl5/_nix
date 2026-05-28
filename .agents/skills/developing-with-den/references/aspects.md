# Aspects

## What they are

Aspects are Den behavior units. They combine one or more Nix class modules
with an include graph.

```nix
den.aspects.editor = {
  nixos.environment.systemPackages = [ pkgs.helix ];
  homeManager.programs.helix.enable = true;
};
```

Class configs can be attrsets or module functions:

```nix
den.aspects.foo.nixos = { config, pkgs, lib, ... }: {
  services.openssh.enable = true;
};
```

Context-aware aspects are plain functions over Den context:

```nix
den.aspects.hostname = { host, ... }: {
  nixos.networking.hostName = host.hostName;
};
```

## Includes

`includes` forms the aspect DAG. Use real references, policies, or parametric
functions.

```nix
den.aspects.workstation.includes = [
  den.aspects.base
  ({ host, ... }: lib.optionalAttrs (host ? gpu) {
    includes = [ den.aspects.hardware.${host.gpu} ];
  })
];
```

Including aspect `A` includes `A`'s own class configs and `A.includes`. It
does not automatically include arbitrary child aspect keys.

## Child aspects and `._`

Child aspects can be direct nested keys:

```nix
den.aspects.tools.editors.homeManager.programs.helix.enable = true;
```

or `provides` children:

```nix
den.aspects.tools.provides.editors.homeManager.programs.helix.enable = true;
```

Den forwards `provides` children, so `den.aspects.tools.editors` resolves.

`A._` is a synthetic aspect that includes all immediate regular child aspects
of `A`:

```nix
den.aspects.user.includes = [ den.aspects.tools._ ];
```

`A._` skips structural keys, class keys, registered quirk keys, Den internals,
forwarded `provides` children, and grandchildren.

Use nested `._` for grandchildren:

```nix
den.aspects.user.includes = [ den.aspects.tools.editors._ ];
```

Upstream PR #536 added this behavior; issue #537 tracks documentation.

## Recipes

### Include a precise child

Use explicit child references when only some children should apply.

```nix
den.aspects.host.includes = [
  den.aspects.server.units.backup
  den.aspects.server.units.fail2ban
];
```

### Include every child in a group

Use `._` only when every immediate child is intended.

```nix
den.aspects.desktop.includes = [ den.aspects.desktop.apps.core._ ];
```

Avoid this for host unit selection unless all units should apply.

### Split a flat aspect safely

Keep a wrapper while references move.

```nix
# new implementation
den.aspects.base.options.nixos = { ... };

# temporary compatibility
den.aspects.base-options.includes = [ den.aspects.base.options ];
```

Remove the wrapper only after searches and targeted evals prove no references
remain.

### Preserve host behavior during refactors

For host-affecting aspect changes, compare or eval the affected outputs:

```bash
nix eval --raw .#nixosConfigurations.lavpc.config.system.build.toplevel.drvPath
nix eval --raw .#nixosConfigurations.tyrant.config.system.build.toplevel.drvPath
```

For deployment-sensitive changes, explicitly check service enablement paths
instead of relying on structure alone.

## Source anchors

- Den docs: `explanation/aspects.mdx`, `guides/configure-aspects.mdx`
- Den source: `nix/lib/aspects/types.nix`,
  `nix/lib/aspects/fx/aspect/normalize.nix`,
  `nix/lib/aspects/fx/key-classification.nix`
- Den tests: `templates/ci/modules/features/include-children.nix`
