# Classes

## What they are

Classes are Nix module evaluation domains. Common built-ins:

- `nixos`
- `homeManager`
- `darwin`

Aspects provide class-owned configs:

```nix
den.aspects.foo.nixos = { ... };
den.aspects.foo.homeManager = { ... };
```

Do not confuse class with entity kind:

- **entity kind:** `host`, `user`, `home`
- **class:** `nixos`, `homeManager`, `darwin`

Entity kinds drive Den context and policies. Classes decide which module
system evaluates final config.

## Custom classes

Den supports `den.classes` for custom evaluation domains and forwarding.

Use custom classes when you truly need a new module evaluation target. Do not
use them for ordinary grouping; use aspects, schema, namespaces, or quirks
first.

## Forwarding

Forwarding maps class content into another class. Vix uses forwarded Home
Manager classes so modules can express platform-specific HM config and forward
it into `homeManager`.

This is powerful but easy to overfit. Prefer normal `homeManager` modules
unless there is a clear cross-platform class boundary.

## Recipes

### Add normal NixOS/Home Manager config

Use class keys directly:

```nix
den.aspects.cli = {
  nixos.programs.fish.enable = true;
  homeManager.programs.starship.enable = true;
};
```

### Avoid custom classes for simple platform checks

Prefer module-level checks first:

```nix
den.aspects.tools.homeManager = { pkgs, lib, ... }: {
  home.packages = lib.optionals pkgs.stdenv.isLinux [ pkgs.xclip ];
};
```

### Reach for custom classes only with a real domain

Use custom classes when a feature has its own evaluator, output path, or needs
explicit forwarding into another module system.

## Source anchors

- Den docs: `guides/custom-classes.mdx`, `explanation/class-modules.mdx`
- Den source: `modules/options.nix`, class handling under `nix/lib/aspects/`
- Vix example: `modules/vic/classes.nix`
