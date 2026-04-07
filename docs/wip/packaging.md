# Packaging and deployment notes

## Goal

This document captures the reusable procedure that was used to package and deploy Kaneo in this repo. It is written for future agents working on similar upstream applications.

## Start from upstream Dockerfiles

When packaging an upstream app, treat the upstream Dockerfiles as the quickest build map.

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
- the web image rewrites built assets at runtime using environment variables
- SMTP, SSO, and S3 are optional for a first boot

## Packaging checklist for upstream apps

1. Read the upstream root `package.json`, lockfile, workspace file, and Dockerfiles.
2. Read the app-local `package.json` files for the services you need to run.
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

## pnpm monorepo packaging notes

For pnpm workspaces in this repo:

- prefer nixpkgs pnpm helpers: `fetchPnpmDeps` + `pnpmConfigHook`
- pin the pnpm **major** to the upstream lockfile expectation
- mirror the upstream build order instead of inventing a different one
- favor a correct offline runtime tree over premature closure-size pruning

Kaneo-specific pattern:

- use `pnpm_10`
- use `fetcherVersion = 3`
- build:
  1. `@kaneo/email`
  2. `@kaneo/web`
  3. `@kaneo/api`

If a built runtime still needs workspace links to resolve cleanly, copy the required workspace targets into the installed runtime tree as well. Kaneo needed the relevant workspace package directories present so pnpm symlinks stayed valid.

## Runtime substitution rule

If upstream rewrites built frontend assets at runtime:

- never mutate `$out`
- copy the built assets into a writable runtime directory first
- perform substitutions there
- point the web server at that runtime copy

Kaneo follows this pattern. The package stores immutable built assets, while the systemd web service copies them into `/run/kaneo-web/html`, rewrites the `KANEO_*` placeholders there, generates nginx config, and only then starts nginx.

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

## LAN-only Traefik behavior

This repo’s Traefik LAN-only behavior is controlled centrally.

Rule:

- if a vhost target is **not** listed in `globals/dns.nix` `public_vhosts`, Traefik applies the `lan-only` middleware

So for LAN-only apps:

- add `my.vhosts` entries normally
- do **not** add the hostnames to `globals/dns.nix` `public_vhosts`

That is how Kaneo remains LAN-only.

## Shared Postgres procedure

For apps that need Postgres in this repo:

- reuse `unit.postgres`
- give each app its own DB/role/password
- keep the app-specific DB wiring in the app module
- keep the shared Postgres unit generic
- preserve the runtime password sync model
- preserve explicit TCP localhost auth; do not rely on socket fallback hacks

Kaneo follows this pattern by appending its own database entry into `my."unit.postgres".databases` when enabled.

## Secret handling notes

Repo convention is to declare secrets through the secret helpers exposed by `my.secrets`.

Practical steps:

- declare the sops secret in the unit
- make sure the referenced encrypted file already exists in the private secrets repo
- if you add new encrypted files there, update the `mysecrets` flake input afterward

Kaneo required:

- `secrets/kaneo.yaml`
  - `kaneo_auth_secret`
  - `kaneo_postgres_password`
- `secrets/postgres.yaml`
  - `admin_password`

## Service state directory pattern

For long-running services in this repo, prefer the built-in systemd directory helpers over ad-hoc writable paths when they fit the app shape:

- use `StateDirectory` for persistent writable state under `/var/lib/<name>`
- use `RuntimeDirectory` for mutable runtime-only files under `/run/<name>`
- set `HOME` to the persistent state directory when the upstream app expects a writable home-like location
- only add a custom `data_dir` option when the app genuinely needs a repo-configurable storage location beyond the standard systemd-managed directories

Kaneo follows this pattern by using:

- `StateDirectory = "kaneo"` for persistent writable state
- `RuntimeDirectory = "kaneo-web"` for mutable nginx/web-runtime files
- `HOME=/var/lib/kaneo` for both services

This keeps writable state out of the Nix store while avoiding unnecessary custom directory management.

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
- targeted `nix eval` for vhosts, service toggles, and important settings

## Kaneo-specific gotchas

- The API entrypoint defaults to port `1337`; if you need a different port, make the wrapper or service set it deliberately rather than assuming upstream already supports a generic env var.
- pnpm workspace symlinks can leave dangling targets if you copy too little of the workspace into the runtime tree.
- runtime web substitutions must happen outside the Nix store.
- enabling a unit that references new sops files will fail evaluation until those files exist in the private secrets repo or its flake input is refreshed.
