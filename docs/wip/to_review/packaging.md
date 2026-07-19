# Packaging and deployment notes

## Goal

This document captures reusable procedures for packaging and deploying
upstream applications in this repo. It is written for future agents
working on similar upstream applications. Patterns are illustrated
with Kaneo and Degoog examples.

## Start from upstream Dockerfiles

When packaging an upstream app, treat the upstream Dockerfiles as the
quickest build map.

Read them to identify:

- package manager and version expectations
- workspace layout
- build order between apps/packages
- runtime entrypoints
- healthcheck paths
- required runtime environment variables
- which dependencies are optional vs required for first boot

For Kaneo, the Dockerfiles and source established that:

- it is a pnpm workspace / turbo monorepo
- the API build depends on `@kaneo/email` being built first
- the API runtime entrypoint is `apps/api/dist/index.js`
- the API healthcheck is `/api/health`
- the web app is a Vite build served by nginx
- the web image rewrites built assets at runtime using environment
  variables
- SMTP, SSO, and S3 are optional for a first boot

## Packaging checklist for upstream apps

1. Read the upstream root `package.json`, lockfile, workspace file,
   and Dockerfiles.
2. Read the app-local `package.json` files for the services you need
   to run.
3. Read the runtime entrypoint source files to confirm:
   - ports
   - health endpoints
   - migration behavior
   - required env vars
4. Confirm whether the upstream runtime expects:
   - mutable config files
   - mutable built assets
   - a writable data directory
   - a database bootstrap step
5. Only then write the local derivation.

## JS/TS packaging strategies

### pnpm monorepo packaging

For pnpm workspaces in this repo:

- prefer nixpkgs pnpm helpers: `fetchPnpmDeps` + `pnpmConfigHook`
- pin the pnpm **major** to the upstream lockfile expectation
- mirror the upstream build order instead of inventing a different one
- favor a correct offline runtime tree over premature closure-size
  pruning

Kaneo-specific pattern:

- use `pnpm_10`
- use `fetcherVersion = 3`
- build:
  1. `@kaneo/email`
  2. `@kaneo/web`
  3. `@kaneo/api`

If a built runtime still needs workspace links to resolve cleanly,
copy the required workspace targets into the installed runtime tree as
well. Kaneo needed the relevant workspace package directories present
so pnpm symlinks stayed valid.

### Bun runtime packaging

When upstream uses Bun for building and running but ships
npm-compatible lockfiles:

- use `buildNpmPackage` with `fetchNpmDeps` for dependency fetching
- use Bun as the runtime binary in `nativeBuildInputs` and the wrapper
  entrypoint
- preserve the upstream `src/` layout under `$out/libexec/<name>`
- wrapper entrypoint: `bun run src/server/index.ts`

Degoog follows this pattern. The upstream project uses Bun exclusively
but the npm lockfile lets `buildNpmPackage` handle dependency
resolution.

### When Bun segfaults on x86_64-linux

The default nixpkgs `bun` binary segfaults on some x86_64-linux hosts
(even for `bun --version`). Fix: use Bun's upstream
`bun-linux-x64-baseline.zip` instead:

```nix
bunRuntime =
  if stdenv.hostPlatform.isLinux && stdenv.hostPlatform.isx86_64
  then
    bun.overrideAttrs (old: {
      src = fetchurl {
        url = "https://github.com/oven-sh/bun/releases/download/bun-v${old.version}/bun-linux-x64-baseline.zip";
        hash = "...";
      };
      sourceRoot = "bun-linux-x64-baseline";
    })
  else bun;
```

The global flake overlay in `outputs/channels/default.nix` already
patches `bun` for the system pkgs set, but **this does not apply to
packages built through `outputs/packages/default.nix`**, which
constructs its `pkgs` from raw `inputs.nixpkgs.legacyPackages` without
overlays. Package-level overrides are therefore necessary and
intentional.

### Lockfile generation for Bun-only upstreams

When upstream only ships a `bun.lockb` (binary Bun lockfile) but no
`package-lock.json`, you must generate one:

1. Run `npm install --package-lock-only` against the upstream source
2. Commit the resulting `package-lock.json` alongside the derivation
3. Patch `package.json` at build time to resolve `resolutions` into
   `overrides` if upstream uses non-standard fields

## Fennel/Lua packaging strategies

### Makefile-based Fennel CLIs

For small Fennel CLIs that compile to Lua:

- start from the upstream `Makefile`; fnlfmt builds by compiling
  `cli.fnl` to an executable script and compiling `fnlfmt.fnl` to
  `fnlfmt.lua`
- mirror nixpkgs when available; upstream nixpkgs packages fnlfmt with
  `stdenv.mkDerivation`, `luaPackages.fennel` in `nativeBuildInputs`,
  `lua` in `buildInputs`, and `makeFlags` setting `PREFIX=$(out)` plus
  the Fennel compiler path
- keep `meta.mainProgram` pointed at the generated executable, usually
  `fnlfmt`, even if the fork package name differs
- if adding a flake to an existing git checkout, stage `flake.nix`
  before `nix flake lock` or `nix build`; Nix evaluates the
  git-tracked source tree
- when GitHub API rate limits block `github:` flake inputs, pin
  nixpkgs through a direct archive URL temporarily or permanently

Sane fnlfmt follows this pattern as a fork-local flake:
`packages.default` builds the Makefile package, `apps.default` runs
`$out/bin/fnlfmt`, and the dev shell exposes `lua`, `fennel`, and
`fennel-ls`.

## Rust packaging strategies

### crate2nix workspace packaging

For Cargo workspaces in this repo:

- prefer `crate2nix generate` from the workspace root and commit the
  generated `Cargo.nix`
- commit `crate-hashes.json` too when upstream has git dependencies
- import the checked-in `./Cargo.nix` from `flake.nix` when you want
  evaluation without import-from-derivation surprises
- export the intended workspace member explicitly
  (`cargoNix.workspaceMembers.<name>.build`) instead of assuming
  `rootCrate.build`
- wire `packages.default`, `apps.default`, and `meta.mainProgram` to
  the real runtime binary
- give `devShells.default` the Rust toolchain, `crate2nix`, and the
  native libraries/tools the workspace actually needs
- regenerate `Cargo.nix` whenever upstream changes version, features,
  bins, or dependencies

Jcode-specific pattern:

- generate from the repo root so the root crate + workspace members
  resolve together
- package `cargoNix.workspaceMembers.jcode.build`
- expose `packages.jcode`, `packages.default`, `apps.jcode`, and
  `apps.default`
- keep a dev shell with `cargo`, `rustc`, `rustfmt`, `clippy`,
  `crate2nix`, `git`, `pkg-config`, `openssl`, `python3`, `ffmpeg`,
  `librsvg`, and on Linux `clang` + `mold`

### build.rs metadata and flake gotchas

If upstream `build.rs` reads git state or synthesizes versions:

- pass explicit env vars from the flake so the derivation does not
  need a live `.git` checkout
- for jcode this meant `JCODE_RELEASE_BUILD`, `JCODE_BUILD_SEMVER`,
  `JCODE_BUILD_GIT_HASH`, `JCODE_BUILD_GIT_DATE`,
  `JCODE_BUILD_GIT_DIRTY`, `JCODE_BUILD_GIT_TAG`, and
  `JCODE_BUILD_CHANGELOG_RAW`
- if the generated `Cargo.nix` and current `Cargo.toml` drift,
  regenerate immediately before trusting any package metadata or
  default-feature behavior

When bootstrapping a new flake in a git repo:

- `nix flake show` evaluates the git-tracked tree, not arbitrary
  untracked files
- stage `flake.nix`, `flake.lock`, and generated Nix files with
  `git add` before expecting local flake evaluation to see them

## Go CLI packaging strategies

### buildGoModule single-binary CLIs

For Go CLI apps in this repo:

- use `buildGoModule` with the upstream source pinned through `npins`
- set `subPackages` to the command package that builds the desired
  binary
- set upstream version metadata through `ldflags` when the app has a
  build-time `version` variable
- keep optional companion tools as normal PATH dependencies instead of
  hard-wiring them into the package closure unless upstream cannot
  function without them

Mardi Gras follows this pattern:

- upstream repository: `quietpublish/mardi-gras`, but the Go module
  path is still `github.com/matt-wright86/mardi-gras`; do not patch
  the module path just because it differs from the GitHub owner
- source pin: `mardi-gras-src` as a `GitRelease` at tag `v0.17.0`
- package version: strip the leading `v` for the Nix `version`, but
  pass the full tag to `-X main.version=...` so `mg --version` prints
  the upstream tag
- binary command package: `cmd/mg`, producing `bin/mg`
- install upstream man pages when present; Mardi Gras ships `mg.1`, so
  copy it to `$out/share/man/man1/mg.1`
- runtime is a local TUI/CLI only: no daemon, database, mutable
  config, or writable state is required by the package
- first-class runtime integration is with Beads (`bd list --json` when
  `bd` is on PATH); JSONL mode can read `.beads/issues.jsonl`
  directly; Gas Town (`gt`) and tmux are optional integrations
  discovered from PATH
- useful runtime flags/env: `--status`, `--path`, `--block-types` /
  `MG_BLOCK_TYPES`, `--no-animations` / `MG_NO_ANIMATIONS`,
  `--cmd-timeout` / `MG_CMD_TIMEOUT`, and `MG_DEBUG=1`

## Runtime substitution rule

If upstream rewrites built frontend assets at runtime:

- never mutate `$out`
- copy the built assets into a writable runtime directory first
- perform substitutions there
- point the web server at that runtime copy

Kaneo follows this pattern. The package stores immutable built assets,
while the systemd web service copies them into `/run/kaneo-web/html`,
rewrites the `KANEO_*` placeholders there, generates nginx config, and
only then starts nginx.

## Local package export procedure in this repo

For a new local package:

1. create `packages/<name>/default.nix`
2. export it from `packages/default.nix`
3. re-export it from `outputs/packages/default.nix`
4. verify with `nix build .#<name>`

For Kaneo this resulted in one local package, `.#kaneo`, containing:

- `bin/kaneo-api`
- `bin/kaneo-web`
- `libexec/kaneo/...` runtime tree for the API/workspace
- `share/kaneo/web/...` built frontend assets

For Degoog this resulted in `.#degoog`, containing:

- `bin/degoog` (wrapper around `bun run src/server/index.ts`)
- `libexec/degoog/...` runtime tree with upstream source and
  node_modules

For Mardi Gras this resulted in `.#mardi-gras`, containing:

- `bin/mg` (Go TUI/CLI built from `cmd/mg`)
- `share/man/man1/mg.1` from upstream `mg.1`

When adding such a local package to a Home Manager module that
otherwise uses an upstream package set like `pkgs.llm-agents`, import
`../../../../../packages` (adjusted for the module path) with `pkgs`
and `inputs`, then append the local package separately, e.g.
`local_packages."mardi-gras"`.

## Unit module procedure in this repo

For a new NixOS unit:

1. create `users/_units/<name>/default.nix`
2. import it in `users/_units/default.nix`
3. define it with `o.module "unit.<name>"`
4. use `u.endpoint` for reverse-proxied HTTP endpoints
5. register vhosts through `my.vhosts`
6. verify with targeted `nix eval` and a host toplevel build

Kaneo-specific structure:

- `unit.kaneo.web.endpoint` defaults to `kaneo:5173`
- `unit.kaneo.api.endpoint` defaults to `api.kaneo:1337`
- vhosts are registered as:
  - `kaneo.trll.ing`
  - `api.kaneo.trll.ing`

Degoog structure:

- `unit.degoog.endpoint` defaults to port 4444, target `search`
- vhost resolves to `search.<tld>`
- `degoog-prepare-env.service` creates `/run/degoog/env` from SOPS
  secret and seeds first-boot `plugin-settings.json`

## LAN-only Traefik behavior

This repo’s Traefik LAN-only behavior is controlled centrally.

Rule:

- if a vhost target is **not** listed in `globals/dns.nix`
  `public_vhosts`, Traefik applies the `lan-only` middleware

So for LAN-only apps:

- add `my.vhosts` entries normally
- do **not** add the hostnames to `globals/dns.nix` `public_vhosts`

That is how both Kaneo and Degoog remain LAN-only.

## Shared Postgres procedure

For apps that need Postgres in this repo:

- reuse `unit.postgres`
- give each app its own DB/role/password
- keep the app-specific DB wiring in the app module
- keep the shared Postgres unit generic
- preserve the runtime password sync model
- preserve explicit TCP localhost auth; do not rely on socket fallback
  hacks

Kaneo follows this pattern by appending its own database entry into
`my."unit.postgres".databases` when enabled.

Degoog does not need Postgres — it uses file-based state under
`/var/lib/degoog`.

## Secret handling notes

Repo convention is to declare secrets through the secret helpers
exposed by `my.secrets`.

Practical steps:

- declare the sops secret in the unit
- make sure the referenced encrypted file already exists in the
  private secrets repo
- if you add new encrypted files there, update the `mysecrets` flake
  input afterward

Kaneo required:

- `secrets/kaneo.yaml`
  - `kaneo_auth_secret`
  - `kaneo_postgres_password`
- `secrets/postgres.yaml`
  - `admin_password`

Degoog required:

- `secrets/degoog.yaml`
  - `degoog_settings_passwords`

**Important**: add the encrypted file to the private secrets repo and
run `npins update mysecrets` before enabling the unit on any host.
Enabling a unit that references missing sops files will fail
evaluation.

## Service state directory pattern

For long-running services in this repo, prefer the built-in systemd
directory helpers over ad-hoc writable paths when they fit the app
shape:

- use `StateDirectory` for persistent writable state under
  `/var/lib/<name>`
- use `RuntimeDirectory` for mutable runtime-only files under
  `/run/<name>`
- set `HOME` to the persistent state directory when the upstream app
  expects a writable home-like location
- only add a custom `data_dir` option when the app genuinely needs a
  repo-configurable storage location beyond the standard
  systemd-managed directories

Kaneo follows this pattern by using:

- `StateDirectory = "kaneo"` for persistent writable state
- `RuntimeDirectory = "kaneo-web"` for mutable nginx/web-runtime files
- `HOME=/var/lib/kaneo` for both services

Degoog follows this pattern by using:

- `StateDirectory = "degoog"` for persistent writable state
- `RuntimeDirectory = "degoog"` for the env file and runtime config
- `HOME=/var/lib/degoog` for the service

This keeps writable state out of the Nix store while avoiding
unnecessary custom directory management.

## Prepare-env service pattern

When a service needs runtime-only secrets or first-boot seeding, use a
`prepare-env` oneshot service:

- declare it as `before` + `requiredBy` + `partOf` the main service
- read SOPS secret, write it to a `RuntimeDirectory` env file with
  restricted permissions
- seed first-boot config files if they don't already exist
- the main service reads the env file via `EnvironmentFile`

Degoog follows this pattern: `degoog-prepare-env.service` reads the
SOPS secret, writes `/run/degoog/env`, and seeds
`plugin-settings.json` with domain blocking enabled.

## Kaneo runtime checklist

Minimum first-pass runtime env for Kaneo:

- `KANEO_CLIENT_URL`
- `KANEO_API_URL`
- `AUTH_SECRET`
- `DATABASE_URL`
- `POSTGRES_DB`
- `POSTGRES_USER`
- `POSTGRES_PASSWORD`
- `CORS_ORIGINS`

First-pass optional items intentionally left out:

- SMTP
- SSO providers
- S3-backed uploads

## Verification order for this repo

When Nix code changes, follow the repo order from `AGENTS.md`:

1. `nix fmt`
2. `git add .`
3. `prek`
4. `nix flake check --all-systems`

Useful focused checks for packaging work:

- `nix build .#<package>`
- `nix build .#nixosConfigurations.<host>.config.system.build.toplevel`
- targeted `nix eval` for vhosts, service toggles, and important
  settings

## App-specific gotchas

### Kaneo

- The API entrypoint defaults to port `1337`; if you need a different
  port, make the wrapper or service set it deliberately rather than
  assuming upstream already supports a generic env var.
- pnpm workspace symlinks can leave dangling targets if you copy too
  little of the workspace into the runtime tree.
- runtime web substitutions must happen outside the Nix store.
- enabling a unit that references new sops files will fail evaluation
  until those files exist in the private secrets repo or its flake
  input is refreshed.

### Degoog

- Bun segfaults on some x86_64-linux hosts; the `bunRuntime` override
  in the package is required even though a global overlay exists (see
  above).
- The upstream project only ships `bun.lockb`; a `package-lock.json`
  must be generated and committed alongside the derivation.
- `resolutions` in `package.json` must be patched into `overrides` at
  build time for npm compatibility.
- `DEGOOG_PUBLIC_INSTANCE` must remain unset to keep the instance
  LAN-only.

### Mardi Gras

- upstream moved under `quietpublish`, but `go.mod` intentionally uses
  `github.com/matt-wright86/mardi-gras`; leave it alone for module
  checksum compatibility
- release tags are annotated; an `npins` `GitRelease` pin may record
  the tag object revision while fetching `refs/tags/v...`, which is
  fine
- `mg` discovers `bd`, `gt`, and tmux from PATH; prefer installing
  those companion tools in the consuming Home Manager profile instead
  of wrapping them into the binary package by default

### jcode

- the repo root is both `[package]` and `[workspace]`; package
  `workspaceMembers.jcode.build`, not the workspace-wide join
- `Cargo.nix` and `crate-hashes.json` are committed artifacts, so any
  manifest/version/feature/bin/dependency change requires regenerating
  them
- `build.rs` wants git-derived metadata and otherwise invents
  build-local version info; keep the `JCODE_BUILD_*` overrides in the
  flake
- `embeddings` is intentionally opt-in in current `Cargo.toml`; a
  stale generated `Cargo.nix` can silently pull heavier feature sets
  back into the default build
- runtime/helper paths shell out to tools like `git`, `cargo`,
  `ffmpeg`, and `rsvg-convert`; decide deliberately whether those
  belong only in the dev shell or also need runtime PATH wrapping
