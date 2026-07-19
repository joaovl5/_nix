# Namespaces

## What they are

A namespace creates an aspect library under `den.ful.<name>` and a
module argument alias.

```nix
imports = [ (inputs.den.namespace "lav" false) ];
```

This creates:

- `den.ful.lav`
- `lav` as a module arg alias
- optionally `flake.denful.lav` when exported

Modes:

```nix
inputs.den.namespace "my" false  # local only
inputs.den.namespace "my" true   # export as flake.denful.my
inputs.den.namespace "my" [ input ] # import input.flake.denful.my
```

## When to use

Use namespaces for reusable aspect libraries and project-owned
grouping.

```nix
{ lav, ... }: {
  lav.desktop.apps.editor.homeManager.programs.helix.enable = true;
}
```

Consume from entity or aggregate aspects:

```nix
{ den, lav, ... }: {
  den.aspects.lav.includes = [ lav.desktop.apps.editor ];
}
```

Keep entity aspects easy to find unless deliberately overriding entity
`aspect` fields.

## Angle brackets

Den can expose `den.lib.__findFile` for `<aspect/path>` shorthand.

```nix
{ den, ... }: {
  _module.args.__findFile = den.lib.__findFile;
}
```

Then modules that accept `__findFile` can use angle-bracket lookup.

Prefer normal attr access during migrations because it is easier to
search and refactor.

## Recipes

### Create a local namespace

```nix
{ inputs, ... }: {
  imports = [ (inputs.den.namespace "lav" false) ];
}
```

Use local namespaces for private project structure.

### Create an exported library namespace

```nix
{ inputs, ... }: {
  imports = [ (inputs.den.namespace "vix" true) ];
}
```

Vix uses exported `vix` for reusable/public aspects and local `vic`
for personal aspects.

### Move a reusable aspect into a namespace

```nix
# before
den.aspects.cli-tools.homeManager = { ... };

# after
lav.cli.tools.homeManager = { ... };
den.aspects.cli-tools.includes = [ lav.cli.tools ]; # temporary wrapper
```

Update consumers first, then remove the wrapper.

### Avoid mixing data and aspect libraries casually

If a namespace also holds plain data helpers, keep names clear so
agents do not include non-aspect values by mistake.

## Source anchors

- Den docs: `guides/namespaces.mdx`, `guides/angle-brackets.mdx`
- Den source: `nix/lib/namespace.nix`
- Vix example: `modules/den.nix`
