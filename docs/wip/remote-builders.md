# Remote builders and `nix flake check --all-systems`

## Current problem summary

`nix flake check --all-systems` is not workable on this host with the current published checks.
The flake advertises checks for systems that this machine cannot build locally, and there are no
remote builders configured to cover the missing platforms.

The practical rule is simple: if a flake keeps a system in `checks`, `--all-systems` requires that
system to be buildable somewhere. If even one published system lacks capability, the command fails.

## Repo evidence

- `outputs/default.nix` declares `supportedSystems = ["x86_64-linux"]`.
- `outputs/checks/default.nix` originally fanned out checks over `import all-systems` via
  `nixpkgs.legacyPackages.${system}`.
- The published checks were therefore broader than the repo’s currently supported main architecture.
- `tests/default.nix` gates NixOS tests only on `pkgs.stdenv.isLinux`, so Linux VM tests appear for
  both `x86_64-linux` and `aarch64-linux` whenever those systems are published.
- `systems/_modules/nix.nix` contains `boot.binfmt.emulatedSystems = ["aarch64-linux"]` on
  x86_64-linux NixOS hosts, which is useful context but only a module-level intent, not current
  runtime state.

## Runtime evidence on this host

Observed on the current machine:

- `system=x86_64-linux`
- `builders=` is empty
- `extra-platforms=` does **not** include `aarch64-linux`
- `/proc/sys/fs/binfmt_misc/` is empty

Direct dry-run evidence collected during the investigation:

- `nix build .#checks.aarch64-linux.backup_promotion --dry-run` fails because an
  `aarch64-linux` builder is required.
- `nix build .#checks.aarch64-darwin.formatting --dry-run` fails because an
  `aarch64-darwin` builder is required.
- `nix eval --json .#checks --apply builtins.attrNames` previously returned
  `aarch64-darwin`, `aarch64-linux`, `x86_64-darwin`, and `x86_64-linux`.

## Why `--all-systems` currently fails

`--all-systems` does not magically make unsupported systems buildable. It asks Nix to evaluate and
build every published system-specific check.

That means:

- published Linux checks need either a native Linux builder or working emulation support
- published Darwin checks need Darwin-capable builders
- if a system remains in `checks`, the build path for that system must exist somewhere

On this host, that capability is missing for the non-local systems still present in the published
checks. Local x86_64-linux builds are not enough to satisfy the full published matrix.

## Options considered

### 1. Native remote builders

This is the real long-term solution.

Pros:

- covers the exact target system
- works for both Linux and Darwin
- matches what `--all-systems` actually needs

Cons:

- requires actual builder machines
- requires SSH / trust / substitution configuration
- is not already set up here

### 2. Local binfmt emulation

This is only a partial solution.

Pros:

- can help with some foreign Linux systems such as `aarch64-linux`
- may reduce the need for a dedicated native Linux builder in some cases

Cons:

- not active on this host right now
- does not solve Darwin at all
- is not equivalent to a native remote builder
- can only cover the emulated Linux architectures that are explicitly registered

### 3. Narrow or gate published checks

This is the safest immediate option and the one used here.

Pros:

- keeps published checks aligned with the repo’s currently supported main architecture
- avoids advertising systems that cannot be built on this host
- preserves the existing x86_64-linux behavior

Cons:

- does not make `--all-systems` universally workable
- defers cross-system coverage until builder capacity exists

## Recommendation for future implementation

Keep the published `checks` narrowed to `x86_64-linux` until the builder story is real.
When broader coverage is needed again, reintroduce it only together with actual capability for every
non-local system that remains in `checks`.

Recommended order of operations:

1. Decide which systems should remain published in `checks`.
2. Provision native remote builders for each non-local system in that set.
3. Treat binfmt emulation as a helper for Linux-only coverage, not as a replacement for remote
   builders.
4. If Darwin checks stay published, add Darwin-capable builders; binfmt will not cover them.

The key operational constraint is unchanged: full `nix flake check --all-systems` requires build
capability for every non-local system that the flake continues to publish.

## Official sources

- Nix `flake check` manual: <https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-flake-check.html>
- Nix distributed builds docs: <https://releases.nixos.org/nix/nix-2.22.2/manual/advanced-topics/distributed-builds.html>
- NixOS `boot.binfmt.emulatedSystems` docs: <https://nixos.org/manual/nixos/stable/options.html#opt-boot.binfmt.emulatedSystems>

These sources all point to the same conclusion: `--all-systems` is only practical when the flake’s
published systems line up with actual builder availability.
