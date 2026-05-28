# Entities and schema

## What they are

Entities declare what exists. Den has built-in host, user, and home entities.

```nix
den.hosts.x86_64-linux.lavpc = { ...; };
den.hosts.x86_64-linux.lavpc.users.lav = { ...; };
den.homes.x86_64-linux."lav@lavpc" = { ...; };
```

Each entity has an aspect, usually `den.aspects.<name>` by default, and
resolves through Den's pipeline.

## Schema

`den.schema.<kind>` defines typed metadata and defaults for all entities of a
kind.

```nix
den.schema.host = { lib, ... }: {
  options.units = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [];
  };
};
```

Aspects read schema values from Den context:

```nix
den.aspects.host-units.includes = [
  ({ den, host, ... }: {
    includes = map (unit: den.aspects.server.units.${unit}) host.units;
  })
];
```

Use schema for entity metadata, not final OS module interfaces.

Good schema candidates:

- host facts such as IPs, SSH ports, fast/local connection flags
- host feature lists such as selected unit names
- user metadata such as display name, email, and default classes
- includes or policies that should apply to every entity of a kind

## Strict mode

Den has `den.lib.strict` to reject undeclared freeform entity attrs.

```nix
den.schema.host = den.lib.strict;
```

Use it only after the schema is stable; it is too rigid during exploratory
migrations.

## Recipes

### Add typed host metadata

```nix
{ lib, ... }: {
  den.schema.host = { lib, ... }: {
    options.fastConnection = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };
}
```

Then set it on hosts:

```nix
den.hosts.x86_64-linux.lavpc.fastConnection = true;
```

### Move a NixOS option into schema

Only move values whose source of truth is the entity, not the module fixpoint.

1. Add schema option and host values
2. Read from `{ host, ... }` in the relevant aspect
3. Keep the old `config.my.*` bridge if other modules still read it
4. Remove the old option after searches and targeted evals prove it is unused

### Default all users into Home Manager

```nix
den.schema.user.config.classes = lib.mkDefault [ "homeManager" ];
```

Vix uses this pattern in `modules/schema.nix`.

### Activate a default for all hosts

```nix
den.schema.host.includes = [ den.aspects.some-host-default ];
```

Use this for entity-kind pointcuts. Use `den.default.includes` only when the
concern truly applies across entity kinds.

## Source anchors

- Den docs: `reference/schema.mdx`, `explanation/entities.mdx`,
  `guides/declare-hosts.mdx`
- Den source: `modules/options.nix`, `nix/lib/strict.nix`
- Den tests: `templates/ci/modules/features/strict.nix`
- Vix examples: `modules/schema.nix`, `modules/hosts.nix`
