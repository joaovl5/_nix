# Flake to npins Migration Spec

## Goal

Move dependency source-of-truth from `flake.lock`/flake inputs to `npins/sources.json`, while preserving the repo's current flake-shaped outputs API through a thin compatibility `flake.nix` shim.

## Core decisions

- `npins/sources.json` is the dependency source of truth.
- `flake.lock` is deleted only after the npins-backed shim evaluates/checks successfully.
- `flake.nix` remains, but only as a dependency-free tooling shim.
- Root `default.nix` returns the complete output attrset directly.
- Use `denful/with-inputs` (GitHub redirects old `vic/with-inputs` references there), pinned by npins from the upstream `main` branch, to mimic flake-shaped inputs.
- Keep `flake-utils-plus` (`fup`) unchanged in the first migration.
- Do not use `npins import-flake`; initialize with `npins init`, then add audited pins manually.
- Controlled repin is acceptable if final validation passes; exact `flake.lock` revisions do not need to be preserved.
- Do not use `npins freeze`/`unfreeze` in the first migration.
- Do not preserve shallow-fetch semantics from current flake URLs.
- If `with-inputs` needs awkward per-dependency workarounds, stop and ask before proceeding.

## Non-goals

- No full de-flaking of user/operator UX in the first migration.
- No replacement of FUP in the first migration.
- No custom npins update wrapper initially; use raw `npins update <name>` commands.
- No exhaustive proactive pinning of transitive dependencies. Add transitives only when evaluation proves they are needed.
- No broad historical doc rewrite. Update live operational docs only.

## Target architecture

### Entrypoints

- `default.nix`
  - Imports `./npins`.
  - Builds flake-like `inputs` via `inputs.nix` / `input-overrides.nix` and `with-inputs`.
  - Imports local `globals` directly from `./globals`.
  - Calls the existing output builder through FUP.
  - Returns the final complete output attrset.

- `flake.nix`
  - Has no real inputs.
  - Has no lock-worthy dependency graph.
  - Re-exports `import ./default.nix` for flake-only tooling.

Conceptual shape:

```nix
# flake.nix
{
  description = "lav nixos config";
  outputs = _inputs: import ./default.nix;
}
```

### Helper files

Create these root-level files:

- `default.nix`
- `inputs.nix`
- `input-overrides.nix`
- `npins/default.nix`
- `npins/sources.json`

Keep helpers focused. Avoid a large generated/custom blob outside npins' own generated files.

### Self/input adapter wrapper

`with-inputs` is allowed to resolve flake-shaped dependencies, but the migration must not rely on upstream `with-inputs` to provide this repo's exact `inputs.self` semantics by itself.

Add a small local wrapper in `inputs.nix` that constructs the final input set as a fixed point and explicitly gives `inputs.self` all required roles:

- output-rich self: the final output attrset, so `inputs.self.packages`, `inputs.self._utils`, `inputs.self.deploy`, etc. work;
- path-like self: `outPath = toString ./.` from the checked-out repo/worktree root;
- string coercion: `__toString = self: self.outPath`, so `${inputs.self}/...` keeps working.

This is adapter glue, not a fork of `with-inputs`. If this fixed-point self wrapper cannot be implemented cleanly, that is a blocking issue and implementation must stop and ask before changing adapter strategy.

### Output context shape

Because `globals` must stop being a flake input, `outputs/` should receive a context attrset:

```nix
{ inputs, globals } @ context
```

Use `context` consistently when passing data to child output modules.

Target behavior:

- `self.inputs` exists for compatibility, but does not include `globals`.
- `inputs.globals` is intentionally removed.
- `globals` is an imported attrset, passed where needed through output/package/check/module arguments.
- `globals` is not exposed as a public final output.

## Globals policy

Current `globals` being a flake input is considered a design mistake.

Migration requirements:

- Do not add `globals` to npins.
- Do not keep `inputs.globals`.
- Import `./globals` once near the root and pass the imported attrset as `globals`.
- Refactor all current `import inputs.globals` / path-style globals consumers to use the `globals` arg directly.
- No module/package/check should need to manually import `./globals` by relative path.
- External callers using `.#inputs.globals` may break; that is intentional.

## Inputs and pins

### Naming rules

- Preserve current input names where they remain real inputs.
- Exception: `globals` is intentionally removed from inputs.
- `nixpkgs` remains an adapter alias to the `unstable` source pin, not a separate npins pin.
- npins source names should match current flake input names whenever there is a real source pin.
- Branch-following roots without explicit refs must use lock-observed branch names, not guessed `main`/`master` names.
- `stable`, `unstable`, and `unstable-small` should be GitHub branch pins for `NixOS/nixpkgs`.

### Root input inventory

| Current input         | Current source/ref style                       | Current shape   | Target treatment                                                                                           |
| --------------------- | ---------------------------------------------- | --------------- | ---------------------------------------------------------------------------------------------------------- |
| `emacs-bleeding-edge` | `github:nix-community/emacs-overlay`           | flake           | npins source + flake-shaped input; `nixpkgs` follows alias                                                 |
| `stable`              | `NixOS/nixpkgs`, `nixos-25.11`                 | flake           | npins GitHub branch pin                                                                                    |
| `unstable`            | `NixOS/nixpkgs`, `nixos-unstable`              | flake           | npins GitHub branch pin                                                                                    |
| `unstable-small`      | `NixOS/nixpkgs`, `nixos-unstable-small`        | flake           | npins GitHub branch pin                                                                                    |
| `nixpkgs`             | follows `unstable`                             | alias           | no npins pin; adapter alias to `unstable`                                                                  |
| `nur`                 | `nix-community/NUR`                            | flake           | npins source + flake-shaped input                                                                          |
| `hm`                  | `nix-community/home-manager`                   | flake           | npins source + flake-shaped input                                                                          |
| `fup`                 | `gytis-ivaskevicius/flake-utils-plus`          | flake           | npins source + flake-shaped input; keep FUP                                                                |
| `disko`               | `nix-community/disko`                          | flake           | npins source + flake-shaped input                                                                          |
| `deploy-rs`           | `serokell/deploy-rs`                           | flake           | npins source + flake-shaped input                                                                          |
| `sops-nix`            | `Mic92/sops-nix`                               | flake           | npins source + flake-shaped input                                                                          |
| `microvm`             | `microvm-nix/microvm.nix`                      | flake           | npins source + flake-shaped input                                                                          |
| `mysecrets`           | `git@github.com:joaovl5/__secrets.git`, `main` | raw source      | npins git source pin                                                                                       |
| `globals`             | `path:./globals`                               | raw path input  | remove from inputs; import local `./globals` as `globals`                                                  |
| `treefmt-nix`         | `numtide/treefmt-nix`                          | flake           | npins source + flake-shaped input                                                                          |
| `all-systems`         | `nix-systems/default`                          | flake/path-like | npins source; preserve importable path behavior                                                            |
| `optnix`              | sourcehut `~watersucks/optnix`                 | flake           | npins source + flake-shaped input                                                                          |
| `musnix`              | `musnix/musnix`                                | flake           | npins source + flake-shaped input                                                                          |
| `zjstatus`            | `dj95/zjstatus`                                | flake           | npins source + flake-shaped input                                                                          |
| `nixcord`             | `FlameFlag/nixcord`                            | flake           | npins source + flake-shaped input                                                                          |
| `hyprland-plugins`    | `hyprwm/hyprland-plugins`                      | flake           | npins source + flake-shaped input                                                                          |
| `niri`                | `sodiboo/niri-flake`                           | flake           | npins source + flake-shaped input; preserve `nixpkgs` and `nixpkgs-stable` follows to root `nixpkgs` alias |
| `hexecute`            | `ThatOtherAndrew/Hexecute`                     | flake           | npins source + flake-shaped input                                                                          |
| `whisper-overlay`     | `joaovl5/whisper-overlay`                      | flake           | npins source + flake-shaped input                                                                          |
| `fenix`               | `nix-community/fenix`                          | flake           | npins source + flake-shaped input                                                                          |
| `nix-flatpak`         | `gmodena/nix-flatpak`, `v0.7.0`                | flake           | npins tag/ref pin                                                                                          |
| `nixos-dns`           | `Janik-Haag/nixos-dns`                         | flake           | npins source + flake-shaped input; preserve `nixpkgs` and `treefmt-nix` follows                            |
| `octodns-pihole-src`  | `roosnic1/octodns-pihole`                      | raw source      | npins raw source pin                                                                                       |
| `pihole6api-src`      | `sbarbett/pihole6api`                          | raw source      | npins raw source pin                                                                                       |
| `kaneo-src`           | `usekaneo/kaneo`                               | raw source      | npins raw source pin; preserve used metadata such as `outPath`/`shortRev` if still referenced              |
| `hister`              | `asciimoo/hister`                              | flake           | npins source + flake-shaped input                                                                          |
| `atticd`              | `zhaofengli/attic`                             | flake           | npins source + flake-shaped input                                                                          |
| `nixarr`              | `nix-media-server/nixarr`                      | flake           | npins source + flake-shaped input; add transitives only if eval requires                                   |
| `anthropic-skills`    | `anthropics/skills`                            | raw source      | npins raw source pin                                                                                       |
| `llm-agents`          | `numtide/llm-agents.nix`                       | flake           | npins source + flake-shaped input; preserve `nixpkgs` and `treefmt-nix` follows                            |
| `superpowers`         | `obra/superpowers`, `main`                     | raw source      | npins raw source pin                                                                                       |

### Support/transitive pins

Do not add support/transitive pins preemptively except the adapter itself.

| Support input         | Why it may be needed                                          | Policy                                                               |
| --------------------- | ------------------------------------------------------------- | -------------------------------------------------------------------- |
| `with-inputs`         | Required adapter                                              | Add up front as npins source from `denful/with-inputs` branch `main` |
| `flake-utils`         | FUP transitive input                                          | Add only if evaluating `fup` through `with-inputs` requires it       |
| `vpnconfinement`      | Current tests reference `inputs.nixarr.inputs.vpnconfinement` | Add only if evaluating `wireguard_tunnels`/nixarr requires it        |
| Other transitive deps | Hidden in current `flake.lock`                                | Ignore until eval fails                                              |

## Output/API compatibility requirements

Preserve the current repo's major output surfaces:

- `nixosConfigurations`: `lavpc`, `tyrant`, `temperance`, `iso`
- `packages.x86_64-linux`: `build_iso`, `kaneo`, `octodns-pihole`, `pihole6api`, `vm_launcher`, `octodns`
- `apps.x86_64-linux.vm`
- `apps.<system>.format`
- `formatter`
- `checks.x86_64-linux`, including formatting, backups, tests, and deploy-rs checks
- `deploy`
- internal attrs only where current repo code/checks rely on them, especially `_channels.overlays`, `_utils.hosts.*`, and `inputs`

Preserve these input-shape behaviors:

- `inputs.self.outPath` points to the checked-out repo/worktree root.
- `inputs.self` is path-like enough for `${inputs.self}/...` interpolation.
- `inputs.self` is output-rich enough for `inputs.self._utils`, `inputs.self.packages`, etc.
- `inputs.nixpkgs` exposes flake attrs such as `legacyPackages` and remains importable as a path.
- `all-systems` remains importable as a path.
- Raw source pins expose only the metadata actually referenced by repo code after audit.

Validation must include explicit probes for both sides of `inputs.self`: output access (`inputs.self._utils` / `inputs.self.packages`) and path coercion (`${inputs.self}` in host module paths).

## Tooling and workflow changes

### Keep via thin shim

The thin `flake.nix` shim should keep these working:

- `nix fmt`
- `nix flake check`
- `deploy-rs`
- current `nh` flake UX, mostly unchanged
- editor/test compatibility consumers that use `builtins.getFlake`, unless they are explicitly obsolete

### Remove or update flake-era lock tooling

- Delete `flake.lock` after npins-backed validation passes.
- Remove `flake-edit` from packages/tooling.
- Remove `flake-edit.enable` from treefmt config.
- Remove workflows that run `nix flake update ...` for pin updates.
- Install/provide `npins` in the existing CLI tooling location.
- `_scripts/update.fish` should remain an update/rebuild helper, but Nix pin bumps should be explicit `npins update <name>` commands rather than `nh --update`/flake update behavior.

### Naming cleanup

- Rename `my.nix.flake_location` to `my.nix.repo_location`.
- Do not keep a backwards-compatible alias.
- Rename hybrid-links options:
  - `hybrid-links.flake_root` -> `hybrid-links.source_root`
  - `hybrid-links.flake_path` -> `hybrid-links.source_path`
- Do not keep backwards-compatible aliases.
- Remove deprecated `users/_scripts/symlinks.fish`.
- Update `docs/wip/isolation.md` references to the renamed hybrid-links options.

## Installer/post-install requirements

- Replace installer lock update step with an npins pin update step for `mysecrets`.
- The step should run `npins update mysecrets` in the config repo path.
- It should stage/write only `npins/sources.json`.
- If installer `auto_push = false`, skip/disable `npins update mysecrets` and tell the user to push secrets first, then run the pin update.
- Preserve installer flake-ref build/eval calls that intentionally use the thin shim.
- Update installer unit tests that mention `UpdateFlakeLock`, `NixCommand(["flake", "update", ...])`, or staging `flake.lock`.
- Update `users/_services/post_install/src/handle_post_install.py` user-facing label from `nix flake` to source-of-truth-neutral wording.
- Fix the `_secrets.git` vs `__secrets.git` mismatch to match the current `mysecrets` target.
- Keep installer fixture flakes if they test external flake support.

## Missing/stale input cleanup

Current code references `inputs.zen-browser` and `inputs.firefox-addons`, but current `flake.nix`/`flake.lock` do not define them.

Decision:

- Delete `users/_modules/zen-browser/` during migration.
- Do not add `zen-browser` or `firefox-addons` inputs.

## Documentation requirements

Update live operational guidance only:

- `AGENTS.md`
  - State `npins/sources.json` is dependency source of truth.
  - State `flake.nix` is a thin tooling shim.
  - Remove `nix flake update globals` guidance.
  - Add `npins verify` when `npins/`, `inputs.nix`, or `input-overrides.nix` changes.
  - Keep `nix fmt`, staged `prek`, and flake checks through the shim.
  - Document accepted fallback if `nix flake check --all-systems` is environment-blocked.

- `docs/wip/deployment.md`
  - Add `npins verify` to live verification snippets.
  - Remove/replace the `nix flake update globals` workaround.
  - Do not rewrite historical `flake.lock` mentions.

- `docs/wip/isolation.md`
  - Update renamed hybrid-links option names.

## Validation requirements

Implementation must include validation for:

- `npins verify` before Nix builds/checks when pin/helper files changed.
- `nix fmt`.
- staged `prek`.
- `nix flake check` through the shim.
- `nix flake check --all-systems` when environment allows.
- If `--all-systems` is environment-blocked, document the blocker and run local-system flake check plus the targeted matrix below.
- Full host toplevel builds for `lavpc`, `tyrant`, `temperance`, and `iso`.
- Listed package/app builds/evals:
  - `packages.x86_64-linux.build_iso`
  - `packages.x86_64-linux.kaneo`
  - `packages.x86_64-linux.octodns-pihole`
  - `packages.x86_64-linux.pihole6api`
  - `packages.x86_64-linux.vm_launcher`
  - `packages.x86_64-linux.octodns`
  - `apps.x86_64-linux.vm.program`
- Checks:
  - formatting check
  - backup checks
  - NixOS tests
  - deploy-rs checks
  - `wireguard_tunnels` as nested-input compatibility probe
- Input compatibility probes:
  - `inputs.self.outPath`
  - `${inputs.self}` path interpolation through host module paths
  - local imported `globals` consumers
  - raw `*-src` consumers
  - `inputs.nixarr.inputs.vpnconfinement` if evaluation requires the transitive pin
- Python installer tests: all `_installer` tests.
- Affected Frag compatibility tests in `_scripts/frag/tests/test_image_assets.py`.

## Worktree and commit policy for implementation

- Planning files are written in the current worktree.
- Core migration implementation must happen in a separate worktree.
- Worktree location: `~/.config/superpowers/worktrees/my_nix/wip-npins-migration`.
- Branch name: `wip/npins-migration`.
- Base from current `HEAD` at implementation start.
- Incremental commits are allowed and expected inside the implementation worktree.
- Stage files as needed before flake-based checks so git-flake source filtering sees new files.
- Do not delete `flake.lock` until npins-backed shim checks pass.

## Blocking criteria

Stop and ask before proceeding if:

- `with-inputs` cannot provide the required flake-like input shape without awkward patches.
- A required dependency needs a per-dependency workaround beyond explicit npins pin/follows configuration.
- The thin shim cannot satisfy deploy-rs, `nix fmt`, or `nix flake check` without reintroducing real flake inputs.
- Removing `inputs.globals` causes broad architectural churn beyond refactoring current globals consumers to `globals`.
- Validation requires expensive or unavailable infrastructure not covered by the accepted all-systems fallback.
