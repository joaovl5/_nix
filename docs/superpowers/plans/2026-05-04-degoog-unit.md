# Degoog Unit Implementation Plan

> **For agentic workers:** REQUIRED: Use
> `superpowers:subagent-driven-development` for implementation. Steps
> use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a native Nix package and `users/_units/degoog` module
for a LAN-only Degoog search service at `search.<tld>`, with
SOPS-protected settings mutations and persistent domain blocking
state.

**Architecture:** Pin upstream Degoog with npins, package it natively
with nixpkgs `buildNpmPackage`/npm cache while using Bun for upstream
build and runtime, and run it through a systemd service with mutable
state in `/var/lib/degoog`. The unit registers a normal repo vhost
target `search`, relies on existing Traefik LAN-only behavior, writes
`DEGOOG_SETTINGS_PASSWORDS` from SOPS into `/run/degoog/env`, and
seeds first-boot settings so block-result actions are usable after
settings login.

**Tech Stack:** Nix, npins, Bun, buildNpmPackage, npm lock/cache,
systemd, SOPS, Traefik vhost declarations.

---

## Decisions and constraints

- User selected Degoog over SearXNG.
- Native Nix package only, Kaneo-style. If native packaging is
  blocked, stop and report; do not fall back to containers.
- Bun/bun2nix hook packaging was investigated first and blocked by Bun
  1.3.11 segfaulting in `bun install` from bun2nix's synthetic cache.
  User selected an npm-compatible lock/cache path while still using
  Bun for build/runtime.
- The default nixpkgs `bun` x86_64-linux asset segfaults on this host
  even for `bun --version`; use Bun's upstream
  `bun-linux-x64-baseline.zip` asset for x86_64-linux while keeping
  nixpkgs `bun` elsewhere. The baseline asset is the same Bun version
  and is pinned by hash.
- Default vhost target is `search`, giving `search.<tld>`.
- Default exposure is LAN-only through existing Traefik behavior: do
  not add `search` to public vhosts.
- Settings mutations must be protected by a SOPS-backed password via
  `DEGOOG_SETTINGS_PASSWORDS`.
- Do not enable `DEGOOG_PUBLIC_INSTANCE`; it makes server-side
  mutations unauthorized and conflicts with the domain-blocking goal.
- Do not enable Degoog on a host in this branch unless the required
  SOPS secret file is known to exist. This plan adds the package and
  reusable unit; host enablement can follow after
  `secrets/degoog.yaml` exists.
- Keep committed docs limited to this implementation plan.

## Relevant source facts

- Upstream `package.json` name/version: `degoog` `0.15.0`; scripts
  include `build = bun run build.ts` and
  `start = bun run src/server/index.ts`.
- Upstream Dockerfile builds with Bun, copies built `src`, production
  `node_modules`, and `package.json`, and installs `git`, `curl`, and
  CA certs.
- Server reads `DEGOOG_PORT`, defaulting to `4444`; Docker's `PORT`
  env is not used by source.
- Server serves static files from relative `src/`, so the runtime
  wrapper must run from a directory containing `src/public`.
- Mutable data defaults to `${cwd}/data`; set
  `DEGOOG_DATA_DIR=/var/lib/degoog`.
- Settings auth is enabled only when `DEGOOG_SETTINGS_PASSWORDS` is
  non-empty.
- Domain block UI and enforcement require persisted settings
  `domainBlockUiEnabled = "true"` and `domainBlockEnabled = "true"`.
- There is no dedicated health endpoint. Use package import checks and
  eval checks; runtime smoke can use `/api/engines`,
  `/opensearch.xml`, or `/api/search` without `q` expecting HTTP 400.
- Degoog has no upstream `package-lock.json`; commit a generated
  `packages/degoog/package-lock.json` so nixpkgs `buildNpmPackage` can
  create `node_modules` without relying on bun2nix's incomplete cache.
- Bun v1.3.11 upstream release publishes `bun-linux-x64-baseline.zip`
  with digest `sha256-q+NG9jQUVHzfazW3pkmkkMcouT0AYiYVaSORioTA5Zs=`;
  this binary runs where nixpkgs' default `bun-linux-x64.zip`
  segfaults.

## Validation commands

Run after implementation, in this order:

```bash
npins verify
nix build .#degoog
nix eval '.#packages.x86_64-linux.degoog.meta.mainProgram'
nix eval '.#nixosConfigurations.tyrant.config.my."unit.degoog".endpoint.target'
nix fmt
git add npins/sources.json input-overrides.nix packages/degoog packages/default.nix outputs/packages/default.nix users/_units/degoog users/_units/default.nix docs/superpowers/plans/2026-05-04-degoog-unit.md
prek
nix flake check --all-systems
```

Notes:

- `npins verify` is required because `npins/sources.json` changes.
- `prek` only sees staged files; stage intended files before running
  it.
- `nix flake check --all-systems` is required because Nix code
  changes. Expected warnings about unknown outputs are acceptable only
  if exit code is zero.
- If `nix flake check --all-systems` is blocked by local
  builder/binfmt constraints, run local `nix flake check`, the focused
  `nix build .#degoog`, and the targeted `tyrant` eval above; report
  the blocker.

## Task 1: Pin upstream Degoog

**Files:**

- Modify: `npins/sources.json`
- Modify: `input-overrides.nix`
- [ ] **Step 1: Add the upstream source pin**

Run:

```bash
npins add github degoog-org degoog --name degoog-src
```

Expected: `npins/sources.json` gains a `degoog-src` pin with GitHub
owner `degoog-org` and repo `degoog`.

- [ ] **Step 2: Mark the pin as a raw source input**

In `input-overrides.nix`, add:

```nix
  degoog-src = raw_source;
```

near the other raw source pins (`kaneo-src`, `pihole6api-src`, etc.).

- [ ] **Step 3: Verify pins**

Run:

```bash
npins verify
```

Expected: verification succeeds.

- [ ] **Step 4: Commit the pin**

Run:

```bash
git add npins/sources.json input-overrides.nix
git commit -m "chore: pin degoog source"
```

---

## Task 2: Add native Degoog package

**Files:**

- Create: `packages/degoog/default.nix`
- Create: `packages/degoog/package-lock.json`
- Modify: `packages/default.nix`
- Modify: `outputs/packages/default.nix`
- [ ] **Step 1: Generate npm-compatible lockfile from the pinned
      source**

Generate `packages/degoog/package-lock.json` from the pinned upstream
source. Use the repo's pinned nixpkgs `nodejs`/`npm`, not host-global
npm, and do not edit upstream source in place. Patch npm `overrides`
from upstream `resolutions` before generating the lockfile because npm
ignores `resolutions`. Apply the same patch in the derivation
`postPatch`.

Run:

```bash
worktree=$PWD
mkdir -p "$worktree/packages/degoog"
degoog_src=$(nix eval --raw --impure --expr '(import ./inputs.nix).degoog-src.outPath')
nodejs_store=$(nix build --no-link --print-out-paths --impure --expr '(import ./inputs.nix).nixpkgs.legacyPackages.x86_64-linux.nodejs')
tmpdir=$(mktemp -d)
cp -a "$degoog_src"/. "$tmpdir"/
(
  cd "$tmpdir"
  "$nodejs_store/bin/node" -e 'const fs = require("fs"); const pkg = JSON.parse(fs.readFileSync("package.json", "utf8")); pkg.overrides = { ...(pkg.overrides || {}), ...(pkg.resolutions || {}) }; fs.writeFileSync("package.json", JSON.stringify(pkg, null, 2) + "\n");'
  "$nodejs_store/bin/npm" install --package-lock-only --ignore-scripts
  cp package-lock.json "$worktree/packages/degoog/package-lock.json"
)
```

Expected: `packages/degoog/package-lock.json` exists and pins the
dependency graph that npm will install for Degoog `0.15.0`. If npm
fails to resolve or produces a materially surprising lockfile, stop
and report the exact issue.

- [ ] **Step 2: Compute the npm dependency hash**

Run:

```bash
prefetch_npm_deps=$(nix build --no-link --print-out-paths --impure --expr '(import ./inputs.nix).nixpkgs.legacyPackages.x86_64-linux.prefetch-npm-deps')
"$prefetch_npm_deps/bin/prefetch-npm-deps" packages/degoog/package-lock.json
```

Expected: command prints a `sha256-...` hash. Use that exact hash as
`hash` in the derivation's explicit `fetchNpmDeps` call.

- [ ] **Step 3: Create the derivation**

Create `packages/degoog/default.nix` as a focused native derivation
using nixpkgs `buildNpmPackage` for dependency installation and Bun
for the upstream build/runtime.

Required shape:

```nix
{
  lib,
  buildNpmPackage,
  stdenv,
  fetchurl,
  fetchNpmDeps,
  nodejs,
  inputs,
  bun,
  makeWrapper,
  ...
}: let
  src = inputs.degoog-src.outPath;
  package_json = builtins.fromJSON (builtins.readFile "${src}/package.json");
  patch_package_json = ''
    node -e 'const fs = require("fs"); const pkg = JSON.parse(fs.readFileSync("package.json", "utf8")); pkg.overrides = { ...(pkg.overrides || {}), ...(pkg.resolutions || {}) }; fs.writeFileSync("package.json", JSON.stringify(pkg, null, 2) + "\n");'
    cp ${./package-lock.json} package-lock.json
  '';
  bun_runtime =
    if stdenv.hostPlatform.isLinux && stdenv.hostPlatform.isx86_64 then
      bun.overrideAttrs (old: {
        src = fetchurl {
          url = "https://github.com/oven-sh/bun/releases/download/bun-v${old.version}/bun-linux-x64-baseline.zip";
          hash = "sha256-q+NG9jQUVHzfazW3pkmkkMcouT0AYiYVaSORioTA5Zs=";
        };
        sourceRoot = "bun-linux-x64-baseline";
      })
    else
      bun;
in
  buildNpmPackage {
    pname = "degoog";
    version = package_json.version;
    inherit src;

    npmDeps = fetchNpmDeps {
      name = "degoog-${package_json.version}-npm-deps";
      inherit src;
      hash = "sha256-...";
      nativeBuildInputs = [nodejs];
      postPatch = patch_package_json;
    };

    postPatch = patch_package_json;

    nativeBuildInputs = [
      bun_runtime
      makeWrapper
    ];

    npmBuildScript = "build";

    installPhase = ''
      runHook preInstall
      runtime_root="$out/libexec/degoog"
      mkdir -p "$out/bin" "$runtime_root"
      cp -a package.json package-lock.json node_modules src "$runtime_root"/
      makeWrapper ${bun_runtime}/bin/bun "$out/bin/degoog" \
        --chdir "$runtime_root" \
        --add-flags "run src/server/index.ts"
      runHook postInstall
    '';

    doInstallCheck = true;
    installCheckPhase = ''
      runHook preInstallCheck
      cd "$out/libexec/degoog"
      ${bun_runtime}/bin/bun -e 'await import("hono"); await import("./src/server/utils/paths.ts"); console.log("runtime imports ok")'
      test -f src/public/app.js
      test -f src/public/settings-page.js
      test -f src/public/themes/degoog-theme/style.css
      runHook postInstallCheck
    '';

    meta = {
      description = "Self-hosted search aggregator with plugins and domain result actions";
      homepage = "https://github.com/degoog-org/degoog";
      license = lib.licenses.agpl3Only;
      mainProgram = "degoog";
      platforms = lib.platforms.linux;
    };
  }
```

Keep the runtime root immutable and preserve the `src/` layout. Do not
run `bun install` during the package build; dependency installation is
handled by `buildNpmPackage`/npm cache from the committed lockfile.

- [ ] **Step 4: Export the package locally**

In `packages/default.nix`:

```nix
  degoog = pkgs.callPackage ./degoog {inherit inputs;};
```

and include `degoog` in the returned `inherit` set.

In `outputs/packages/default.nix`, re-export `degoog` in
`packages.${DEFAULT_SYSTEM}`.

- [ ] **Step 5: Stage and build the package**

Stage new files before flake-backed builds so Nix sees the new package
directory:

```bash
git add packages/degoog/default.nix packages/degoog/package-lock.json packages/default.nix outputs/packages/default.nix
nix build .#degoog
```

Expected: package builds and install checks pass.

- [ ] **Step 6: Commit the package**

Run:

```bash
git commit -m "feat: package degoog"
```

---

## Task 3: Add `unit.degoog` module

**Files:**

- Create: `users/_units/degoog/default.nix`
- Modify: `users/_units/default.nix`
- [ ] **Step 1: Create the unit module**

Create `users/_units/degoog/default.nix` following the Kaneo/Hister
patterns.

Required module shape:

```nix
{
  mylib,
  config,
  globals,
  inputs,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) mkOption;
  local_packages = import ../../../packages {inherit pkgs inputs;};
  my = mylib.use config;
  o = my.options;
  s = my.secrets;
  u = my.units;
  inherit (globals.dns) tld;
in
  o.module "unit.degoog" (with o; {
    enable = toggle "Enable Degoog search aggregator" false;
    package = mkOption {
      description = "Degoog package to run";
      type = lib.types.package;
      default = local_packages.degoog;
    };
    endpoint = u.endpoint {
      port = 4444;
      target = "search";
    };
    default_search_language = opt "Default Degoog search language" t.str "en-US";
  }) {} (opts:
    o.when opts.enable (...))
```

- [ ] **Step 2: Add service user, vhost, backup, and secret**

Inside the enabled config:

- create system user/group `degoog`;
- register
  `my.vhosts.degoog = { inherit (opts.endpoint) target sources; };`;
- back up `/var/lib/degoog` as `my."unit.degoog".backup.items.state`
  with policy `sensitive_data`;
- declare SOPS secret `degoog_settings_passwords` from
  `${s.dir}/degoog.yaml`, key `degoog_settings_passwords`, owned by
  `degoog` group.

Secret declaration pattern:

```nix
sops.secrets.degoog_settings_passwords = s.mk_secret "${s.dir}/degoog.yaml" "degoog_settings_passwords" {
  owner = user;
  inherit group;
};
```

- [ ] **Step 3: Prepare runtime environment file**

Add a oneshot `degoog-prepare-env.service` before/requiredBy
`degoog.service` that:

- creates `/run/degoog`;
- reads `${s.secret_path "degoog_settings_passwords"}`;
- fails if the secret is empty;
- writes `/run/degoog/env` with:

```text
DEGOOG_SETTINGS_PASSWORDS=<secret contents>
```

Use restrictive permissions, following
`users/_units/hister/default.nix`.

- [ ] **Step 4: Seed first-boot domain block settings**

Add an `ExecStartPre` script or a oneshot preparation step that
creates `/var/lib/degoog/plugin-settings.json` only when the file is
absent.

Seed JSON:

```json
{
  "degoog-settings": {
    "domainBlockEnabled": "true",
    "domainBlockUiEnabled": "true"
  }
}
```

Do not overwrite an existing settings file; users must keep mutable
preferences. Create the file as `degoog:degoog` with a writable owner
mode (for example `0640`), or run the seed script as `User = "degoog"`
/ `Group = "degoog"`. A root-owned seeded settings file would break
later settings/domain-action writes.

- [ ] **Step 5: Define `degoog.service`**

Service requirements:

- `wantedBy = ["multi-user.target"]`;
- `after = ["network-online.target" "degoog-prepare-env.service"]` and
  `wants = ["network-online.target"]`;
- `requires = ["degoog-prepare-env.service"]`;
- `path = [ pkgs.git pkgs.curl pkgs.cacert ]` so the extension store
  and curl transport can run;
- environment:
  - `HOME = "/var/lib/degoog"`;
  - `LOG_LEVEL = "info"`;
  - `DEGOOG_PORT = toString opts.endpoint.port`;
  - `DEGOOG_DATA_DIR = "/var/lib/degoog"`;
  - `DEGOOG_DEFAULT_SEARCH_LANGUAGE = opts.default_search_language`;
- `EnvironmentFile = "/run/degoog/env"`;
- `StateDirectory = "degoog"`;
- `RuntimeDirectory = "degoog"`;
- `User = "degoog"`; `Group = "degoog"`;
- `WorkingDirectory = "${opts.package}/libexec/degoog"`;
- `ExecStart = "${opts.package}/bin/degoog"`;
- `Restart = "on-failure"`; `RestartSec = "5s"`.
- [ ] **Step 6: Import the unit**

Add `./degoog` to `users/_units/default.nix` imports.

- [ ] **Step 7: Run eval checks without enabling a host**

Run:

```bash
git add users/_units/degoog/default.nix users/_units/default.nix
nix eval '.#nixosConfigurations.tyrant.config.my."unit.degoog".endpoint.target'
```

Expected: result is `"search"`.

- [ ] **Step 8: Commit the unit**

Run:

```bash
git add users/_units/degoog/default.nix users/_units/default.nix
git commit -m "feat: add degoog unit"
```

---

## Task 4: Final verification and polish

**Files:**

- Modify only files required by formatter/linter.
- [ ] **Step 1: Run required checks**

Run the full validation command list from this plan:

```bash
npins verify
nix build .#degoog
nix eval '.#packages.x86_64-linux.degoog.meta.mainProgram'
nix eval '.#nixosConfigurations.tyrant.config.my."unit.degoog".endpoint.target'
nix fmt
git add npins/sources.json input-overrides.nix packages/degoog packages/default.nix outputs/packages/default.nix users/_units/degoog users/_units/default.nix docs/superpowers/plans/2026-05-04-degoog-unit.md
prek
nix flake check --all-systems
```

Expected: all commands exit 0, except allowed flake-output warnings
with zero exit.

- [ ] **Step 2: Inspect final diff**

Run:

```bash
git status --short
git diff --stat HEAD~3..HEAD
```

Expected: only intended Degoog pin/package/unit/plan files are changed
or committed.

- [ ] **Step 3: Final commit for formatting fixes if needed**

If `nix fmt` or `prek` changed files after Task 3, commit only those
intended changes:

```bash
git add <formatted-files>
git commit -m "style: format degoog unit"
```

Skip this commit if there are no new changes.
