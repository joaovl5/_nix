# Flake to npins Migration Implementation Plan

> **For agentic workers:** REQUIRED: Use `superpowers:subagent-driven-development` (if subagents are available) or `superpowers:executing-plans` to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace flake input/lock management with `npins` while preserving the repo's current flake-like outputs through a dependency-free `flake.nix` shim.

**Architecture:** `npins/sources.json` becomes the dependency source of truth. Root `default.nix` imports npins pins, builds a flake-shaped `inputs` set through `with-inputs` plus local fixed-point self glue, imports `./globals` separately, and calls the existing FUP-backed `outputs/` tree. `flake.nix` becomes a thin wrapper over `default.nix` for `nix fmt`, `nix flake check`, deploy-rs, `nh`, and compatibility callers.

**Tech Stack:** Nix, npins, denful/with-inputs, flake-utils-plus, treefmt-nix, deploy-rs, Home Manager, Python/pytest for installer tests.

**Spec:** `docs/wip/flake_migration/spec.md`

---

## Execution rules

- Core implementation happens in a separate worktree, not this planning worktree.
- Worktree path: `~/.config/superpowers/worktrees/my_nix/wip-npins-migration`.
- Branch: `wip/npins-migration`.
- Base from current `HEAD` at implementation start.
- Incremental commits are expected in the implementation worktree.
- Do not delete `flake.lock` until the npins-backed shim evaluates/checks successfully.
- Do not build a custom adapter or patch dependency outputs without stopping to ask.
- Use targeted `git add <paths>`; avoid `git add .`.

### Per-commit validation rule

Before every implementation commit that changes Nix/config/docs files, run this sequence on that commit's intended file set:

```bash
nix fmt
git add <exact intended files for this commit>
prek
```

If `nix fmt` or `prek` modifies files, stage the hook/formatter output for the same topic and rerun `prek` before committing. This replaces any empty final `prek` run; do not rely on `prek` with no staged files as evidence.

## Chunk 1: Isolated worktree and baseline

### Task 1: Create implementation worktree

**Files:**

- No repo file changes expected.

- [ ] **Step 1: Create the worktree**

```bash
git worktree add ~/.config/superpowers/worktrees/my_nix/wip-npins-migration -b wip/npins-migration HEAD
```

Expected: worktree created at the global location.

- [ ] **Step 2: Enter the worktree**

```bash
cd ~/.config/superpowers/worktrees/my_nix/wip-npins-migration
```

- [ ] **Step 3: Verify clean baseline**

```bash
git status --short
```

Expected: no output.

- [ ] **Step 4: Run a cheap baseline evaluation**

```bash
nix eval .#supportedSystems
```

Expected: evaluates successfully, currently containing `x86_64-linux`.

- [ ] **Step 5: Commit policy checkpoint**

No commit for this task.

## Chunk 2: npins source tree and input adapter

### Task 2: Bootstrap npins pins

**Files:**

- Create: `npins/default.nix`
- Create: `npins/sources.json`

- [ ] **Step 1: Initialize npins without default nixpkgs channel**

```bash
npins init --bare
```

Expected: `npins/default.nix` and `npins/sources.json` exist, with no unwanted default `nixpkgs` channel pin.

- [ ] **Step 2: Add required support pin**

```bash
npins add --name with-inputs github denful with-inputs -b main
```

Expected: `with-inputs` appears in `npins show`.

- [ ] **Step 3: Add nixpkgs branch pins**

```bash
npins add --name stable git https://github.com/NixOS/nixpkgs -b nixos-25.11
npins add --name unstable git https://github.com/NixOS/nixpkgs -b nixos-unstable
npins add --name unstable-small git https://github.com/NixOS/nixpkgs -b nixos-unstable-small
```

Expected: three distinct nixpkgs source pins exist. Do not add a separate `nixpkgs` pin; `nixpkgs` is an adapter alias to `unstable`.

- [ ] **Step 4: Add non-nixpkgs pins from `flake.nix`**

Use `npins add --name <input> ...` for each real source input from the spec's root input table, excluding `globals` and alias-only `nixpkgs`.

Required names:

```text
emacs-bleeding-edge nur hm fup disko deploy-rs sops-nix microvm mysecrets treefmt-nix all-systems optnix musnix zjstatus nixcord hyprland-plugins niri hexecute whisper-overlay fenix nix-flatpak nixos-dns octodns-pihole-src pihole6api-src kaneo-src hister atticd nixarr anthropic-skills llm-agents superpowers
```

Rules:

- Use explicit refs from `flake.nix` where present, e.g. `nix-flatpak` `v0.7.0`, `mysecrets` `main`, `superpowers` `main`.
- For roots without explicit refs, use the lock-observed branch name from current `flake.lock` before deletion.
- Use normal npins pins; do not preserve `shallow=1` semantics.
- Do not add transitive pins unless evaluation later proves they are required.

- [ ] **Step 5: Verify pins**

```bash
npins show
npins verify
```

Expected: all pins verify.

- [ ] **Step 6: Stage and commit npins bootstrap**

```bash
git add npins/default.nix npins/sources.json
git commit -m "feat(npins): add source pins"
```

Expected: commit succeeds.

### Task 3: Add npins-backed input adapter

**Files:**

- Create: `default.nix`
- Create: `inputs.nix`
- Create: `input-overrides.nix`
- Modify: `flake.nix`

- [ ] **Step 1: Write `input-overrides.nix` follows graph**

Encode current root follows relationships from `flake.nix`.

Must include:

```nix
{
  nixpkgs.follows = "unstable";

  emacs-bleeding-edge.inputs.nixpkgs.follows = "nixpkgs";
  nur.inputs.nixpkgs.follows = "nixpkgs";
  hm.inputs.nixpkgs.follows = "nixpkgs";
  disko.inputs.nixpkgs.follows = "nixpkgs";
  deploy-rs.inputs.nixpkgs.follows = "nixpkgs";
  sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  microvm.inputs.nixpkgs.follows = "nixpkgs";
  treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
  optnix.inputs.nixpkgs.follows = "nixpkgs";
  musnix.inputs.nixpkgs.follows = "nixpkgs";
  zjstatus.inputs.nixpkgs.follows = "nixpkgs";
  nixcord.inputs.nixpkgs.follows = "nixpkgs";
  hyprland-plugins.inputs.nixpkgs.follows = "nixpkgs";
  niri.inputs.nixpkgs.follows = "nixpkgs";
  niri.inputs.nixpkgs-stable.follows = "nixpkgs";
  hexecute.inputs.nixpkgs.follows = "nixpkgs";
  whisper-overlay.inputs.nixpkgs.follows = "nixpkgs";
  fenix.inputs.nixpkgs.follows = "nixpkgs";
  nixos-dns.inputs.nixpkgs.follows = "nixpkgs";
  nixos-dns.inputs.treefmt-nix.follows = "treefmt-nix";
  hister.inputs.nixpkgs.follows = "nixpkgs";
  atticd.inputs.nixpkgs.follows = "nixpkgs";
  nixarr.inputs.nixpkgs.follows = "nixpkgs";
  nixarr.inputs.treefmt-nix.follows = "treefmt-nix";
  llm-agents.inputs.nixpkgs.follows = "nixpkgs";
  llm-agents.inputs.treefmt-nix.follows = "treefmt-nix";
}
```

Expected: `globals` is absent; raw source inputs are not forced to be flakes.

- [ ] **Step 2: Write `inputs.nix`**

Responsibilities:

- import `sources = import ./npins`;
- import `with-inputs` from `sources.with-inputs`;
- apply `input-overrides.nix`;
- expose current input names, except `globals`;
- alias `nixpkgs` to `unstable`;
- preserve flake-shaped inputs via `with-inputs`;
- preserve raw source pins as path/source-like attrs;
- implement the local fixed-point `inputs.self` wrapper.

Required `inputs.self` behavior:

```nix
# Pseudocode shape, not exact implementation:
self = final_outputs // {
  outPath = toString ./.;
  __toString = self: self.outPath;
};
```

If this cannot be implemented cleanly with `with-inputs`, stop and ask.

- [ ] **Step 3: Write root `default.nix`**

Responsibilities:

- import `inputs.nix`;
- import `globals = import ./globals`;
- pass `{ inputs, globals } @ context` into `./outputs`;
- call `inputs.fup.lib.mkFlake` around the existing output config;
- return final complete output attrset directly.

- [ ] **Step 4: Replace `flake.nix` with thin shim**

Target shape:

```nix
{
  description = "lav nixos config";

  outputs = _inputs: import ./default.nix;
}
```

No `inputs` attrset should remain in `flake.nix` after this step.

- [ ] **Step 5: Stage adapter files**

```bash
git add default.nix inputs.nix input-overrides.nix flake.nix
```

Do not delete `flake.lock` yet.

- [ ] **Step 6: Run adapter smoke evals**

```bash
nix eval -f default.nix supportedSystems
nix eval .#supportedSystems
nix eval .#inputs.self.outPath
```

Expected: all evaluate through both non-flake and thin-flake entrypoints.

- [ ] **Step 7: Commit adapter**

```bash
git commit -m "feat(npins): add flake-compatible input adapter"
```

## Chunk 3: outputs context and globals refactor

### Task 4: Pass `{ inputs, globals } @ context` through outputs

**Files:**

- Modify: `outputs/default.nix`
- Modify: `outputs/channels/default.nix`
- Modify: `outputs/hosts/default.nix`
- Modify: `outputs/packages/default.nix`
- Modify: `outputs/apps/default.nix`
- Modify: `outputs/deploy/default.nix`
- Modify: `outputs/checks/default.nix`

- [ ] **Step 1: Change `outputs/default.nix` signature**

Change from accepting raw `inputs` to accepting:

```nix
{ inputs, globals } @ context:
```

Pass `context` to child output modules unless a child truly only needs `inputs`.

- [ ] **Step 2: Update child output module signatures**

For child modules, prefer:

```nix
{ inputs, globals } @ context:
```

Use `inputs` where old input behavior is required and `globals` where globals data is required.

- [ ] **Step 3: Preserve output attrs**

Ensure these attrs still exist:

```text
self inputs supportedSystems
_channels.overlays
channels.stable channels.unstable channels.unstable-small
_utils.hosts.shared_modules
_utils.hosts.mk_extra_args
hostDefaults hosts
packages.x86_64-linux
apps.x86_64-linux.vm
formatter
checks.x86_64-linux
deploy
```

- [ ] **Step 4: Add `globals` to host/test extra args**

Update `_utils.hosts.mk_extra_args` in `outputs/hosts/default.nix` so NixOS/Home Manager modules and tests receive `globals` directly.

- [ ] **Step 5: Run context smoke eval**

```bash
nix eval .#_utils.hosts.mk_extra_args --apply 'f: builtins.hasAttr "globals" (f { pkgs = (import .#inputs.nixpkgs { system = "x86_64-linux"; }); })'
```

If this exact expression is awkward because of Nix limitations, replace it with an equivalent `nix eval --expr` that proves `mk_extra_args` includes `globals`.

- [ ] **Step 6: Stage and commit output context changes**

```bash
git add outputs/default.nix outputs/channels/default.nix outputs/hosts/default.nix outputs/packages/default.nix outputs/apps/default.nix outputs/deploy/default.nix outputs/checks/default.nix
git commit -m "refactor(outputs): pass npins input context"
```

### Task 5: Refactor globals consumers

**Files:**

- Modify: `_lib/hosts/base.nix`
- Modify: `systems/_modules/dns/default.nix`
- Modify: `systems/_bootstrap/host.nix`
- Modify: `outputs/packages/octodns.nix`
- Modify: `outputs/deploy/default.nix`
- Modify: `outputs/checks/backups.nix`
- Modify: `users/_modules/browsing/librewolf/settings.nix`
- Modify: `users/_modules/cli/ssh.nix`
- Modify: `users/_units/default.nix`
- Modify: `users/_units/forgejo/default.nix`
- Modify: `users/_units/fxsync/default.nix`
- Modify: `users/_units/hister/default.nix`
- Modify: `users/_units/kaneo/default.nix`
- Modify: `users/_units/pihole/default.nix`
- Modify: `users/_units/reverse-proxy/traefik/default.nix`

- [ ] **Step 1: Replace `import inputs.globals` consumers**

Replace patterns like:

```nix
globals = import inputs.globals;
```

with direct use of the passed `globals` argument.

- [ ] **Step 2: Replace direct relative globals imports where in migration scope**

Replace direct imports such as:

```nix
import ../../globals/hosts.nix
import ../../globals/units.nix
```

with data from the passed `globals` attrset, when the file participates in the migrated output/module context.

- [ ] **Step 3: Update package imports that need globals**

Ensure package helpers like `outputs/packages/octodns.nix` receive `globals` explicitly from the output context.

- [ ] **Step 4: Search for forbidden globals patterns**

```bash
grep -R "inputs\.globals\|import .*globals" _lib outputs systems users --include='*.nix'
```

Expected: no `inputs.globals`; remaining direct `import ./globals`-style usage must be either outside scope or deliberately justified in the commit message.

- [ ] **Step 5: Run globals smoke evals**

```bash
nix eval .#nixosConfigurations.lavpc.config.my.dns.tld
nix eval .#packages.x86_64-linux.octodns.drvPath
```

Expected: both evaluate without `inputs.globals`.

- [ ] **Step 6: Stage and commit globals refactor**

```bash
git add _lib/hosts/base.nix systems/_modules/dns/default.nix systems/_bootstrap/host.nix outputs/packages/octodns.nix outputs/deploy/default.nix outputs/checks/backups.nix users/_modules/browsing/librewolf/settings.nix users/_modules/cli/ssh.nix users/_units/default.nix users/_units/forgejo/default.nix users/_units/fxsync/default.nix users/_units/hister/default.nix users/_units/kaneo/default.nix users/_units/pihole/default.nix users/_units/reverse-proxy/traefik/default.nix
git commit -m "refactor(globals): pass globals outside inputs"
```

## Chunk 4: stale inputs and naming cleanup

### Task 6: Delete stale Zen Browser module

**Files:**

- Delete: `users/_modules/zen-browser/containers.nix`
- Delete: `users/_modules/zen-browser/default.nix`
- Delete: `users/_modules/zen-browser/extensions.nix`
- Delete: `users/_modules/zen-browser/pins.nix`
- Delete: `users/_modules/zen-browser/policies.nix`
- Delete: `users/_modules/zen-browser/search.nix`
- Delete: `users/_modules/zen-browser/settings.nix`
- Delete: `users/_modules/zen-browser/spaces.nix`
- Delete: `users/_modules/zen-browser/userChrome.css`
- Delete: `users/_modules/zen-browser/xdg.nix`

- [ ] **Step 1: Delete the unimported module directory**

```bash
git rm users/_modules/zen-browser/containers.nix users/_modules/zen-browser/default.nix users/_modules/zen-browser/extensions.nix users/_modules/zen-browser/pins.nix users/_modules/zen-browser/policies.nix users/_modules/zen-browser/search.nix users/_modules/zen-browser/settings.nix users/_modules/zen-browser/spaces.nix users/_modules/zen-browser/userChrome.css users/_modules/zen-browser/xdg.nix
```

- [ ] **Step 2: Verify stale input references are gone**

```bash
grep -R "inputs\.zen-browser\|inputs\.firefox-addons\|firefox-addons\|zen-browser" users --include='*.nix'
```

Expected: no references, except possibly historical docs outside `users/`.

- [ ] **Step 3: Commit stale module deletion**

```bash
git commit -m "refactor(users): remove stale zen browser module"
```

### Task 7: Rename repo/hybrid-link location options

**Files:**

- Modify: `_modules/options.nix`
- Modify: `users/_modules/cli/nix-tools.nix`
- Modify: `users/lav.nix`
- Modify: `home/_modules/hybrid-links/default.nix`
- Delete: `users/_scripts/symlinks.fish`
- Modify: `docs/wip/isolation.md`

- [ ] **Step 1: Rename `my.nix.flake_location`**

In `_modules/options.nix`:

- rename option `flake_location` -> `repo_location`;
- update description to repo/thin-shim wording;
- do not add compatibility alias.

- [ ] **Step 2: Update repo location call sites**

Update call sites from `cfg.flake_location` to `cfg.repo_location`.

Known call sites:

```text
users/_modules/cli/nix-tools.nix
users/lav.nix
```

- [ ] **Step 3: Rename hybrid-links options**

In `home/_modules/hybrid-links/default.nix`:

- `flake_root` -> `source_root`
- `flake_path` -> `source_path`
- update local variable names and assertion messages;
- do not add aliases.

- [ ] **Step 4: Update hybrid-links caller**

In `users/lav.nix`:

```nix
hybrid-links.source_root = inputs.self.outPath;
hybrid-links.source_path = cfg.repo_location;
```

- [ ] **Step 5: Delete deprecated symlink script**

```bash
git rm users/_scripts/symlinks.fish
```

- [ ] **Step 6: Update doc reference**

In `docs/wip/isolation.md`, replace old `hybrid-links.flake_root` / `flake_path` references with `source_root` / `source_path`.

- [ ] **Step 7: Search for stale names**

```bash
grep -R "flake_location\|flake_root\|flake_path" _modules users home docs/wip --exclude='plan.md' --exclude='spec.md'
```

Expected: no live config references. Historical docs may be left only if deliberately out of scope.

- [ ] **Step 8: Commit rename cleanup**

```bash
git add _modules/options.nix users/_modules/cli/nix-tools.nix users/lav.nix home/_modules/hybrid-links/default.nix docs/wip/isolation.md
git commit -m "refactor(config): rename flake location options"
```

## Chunk 5: tooling and operational docs

### Task 8: Update flake-era tooling to npins workflow

**Files:**

- Modify: `users/_modules/cli/nix-tools.nix`
- Modify: `_scripts/update.fish`
- Modify: `outputs/checks/treefmt/config.nix`
- Modify: `AGENTS.md`
- Modify: `docs/wip/deployment.md`

- [ ] **Step 1: Replace flake-edit with npins**

In `users/_modules/cli/nix-tools.nix`:

- remove `flake-edit` from `home.packages`;
- add `npins` near other Nix tooling;
- keep `programs.nh.flake` behavior, but point it at `cfg.repo_location` after Task 7;
- keep bare deploy aliases as repo-root commands.

- [ ] **Step 2: Remove lock-update behavior from update script**

In `_scripts/update.fish`, remove `--update` from `nh os switch`.

Keep script name and non-Nix app updates.

- [ ] **Step 3: Update treefmt config**

In `outputs/checks/treefmt/config.nix`:

- remove `flake-edit.enable = true`;
- change `projectRootFile` from `"flake.nix"` to `"npins/sources.json"`.

If treefmt does not accept a nested `projectRootFile`, stop and ask before choosing a different marker.

- [ ] **Step 4: Update AGENTS.md**

Required guidance:

- `npins/sources.json` is source of truth;
- `flake.nix` is a thin tooling shim;
- `globals/` changes do not require pin updates;
- `mysecrets` pin updates use `npins update mysecrets`;
- run `npins verify` when `npins/`, `inputs.nix`, or `input-overrides.nix` changes;
- keep `nix fmt`, staged `prek`, and flake checks via the shim;
- document all-systems environment-blocker fallback.

- [ ] **Step 5: Update deployment doc live guidance**

In `docs/wip/deployment.md`:

- add `npins verify` to live verification snippets;
- remove/replace `nix flake update globals` workaround;
- leave historical `flake.lock` mentions untouched.

- [ ] **Step 6: Stage and commit tooling docs**

```bash
git add users/_modules/cli/nix-tools.nix _scripts/update.fish outputs/checks/treefmt/config.nix AGENTS.md docs/wip/deployment.md
git commit -m "chore(npins): update tooling workflow"
```

## Chunk 6: installer and post-install migration

### Task 9: Replace installer flake-lock update step

**Files:**

- Modify: `_installer/src/installer/steps.py`
- Modify: `_installer/src/installer/app.py`
- Modify: `_installer/tests/unit/test_commands.py`
- Modify: `_installer/tests/unit/test_steps.py`

- [ ] **Step 1: Rename/replace `UpdateFlakeLock`**

Replace the lock update step with a step named around npins, e.g. `UpdateSecretsPin`.

New behavior:

- if `auto_push = false`, skip/disable the npins update and tell user to push secrets first;
- otherwise run `npins update mysecrets` in the config repo path;
- stage only `npins/sources.json`.

- [ ] **Step 2: Use selected command style**

The accepted milestone-1 implementation is a shell command equivalent to:

```bash
cd <flake_dir> && npins update mysecrets
```

Keep this localized to the installer step. Do not introduce a broad command framework unless necessary.

- [ ] **Step 3: Preserve step ordering**

Ensure the new pin update step still runs after `CommitFacter()` in `_installer/src/installer/app.py`.

- [ ] **Step 4: Update installer tests**

Replace test expectations for:

- `NixCommand(["flake", "update", ...])`;
- `UpdateFlakeLock`;
- staging `flake.lock`.

Expected new assertions:

- npins update command is used;
- `npins/sources.json` is staged;
- `auto_push=false` skips/disables repin with a user-facing instruction.

- [ ] **Step 5: Run installer tests**

```bash
cd _installer
uv run pytest
```

Expected: all non-manual installer tests pass.

- [ ] **Step 6: Commit installer migration**

```bash
git add _installer/src/installer/steps.py _installer/src/installer/app.py _installer/tests/unit/test_commands.py _installer/tests/unit/test_steps.py
git commit -m "refactor(installer): update secrets pin with npins"
```

### Task 10: Update post-install labels and secret repo target

**Files:**

- Modify: `users/_services/post_install/src/handle_post_install.py`

- [ ] **Step 1: Rename user-facing repo label**

Change `"nix flake"` to neutral wording such as `"nix config"`.

- [ ] **Step 2: Fix secrets repo mismatch**

Change the post-install secrets repo target from `_secrets.git` to `__secrets.git`, matching current `mysecrets`.

- [ ] **Step 3: Commit post-install cleanup**

```bash
git add users/_services/post_install/src/handle_post_install.py
git commit -m "fix(post-install): align nix config labels"
```

## Chunk 7: compatibility checks and final flake.lock removal

### Task 11: Run npins-backed compatibility probes

**Files:**

- No file changes expected unless probes expose required fixes.

- [ ] **Step 1: Verify pins**

```bash
npins verify
```

Expected: success.

- [ ] **Step 2: Verify non-flake and flake entrypoints**

```bash
nix eval -f default.nix supportedSystems
nix eval .#supportedSystems
nix eval .#inputs.self.outPath
nix eval .#inputs.self._utils.hosts.shared_modules --apply builtins.length
```

Expected: all evaluate.

- [ ] **Step 3: Verify no forbidden input attrs remain**

```bash
nix eval .#inputs.globals
```

Expected: failure because `inputs.globals` is intentionally removed.

- [ ] **Step 4: Verify package/app compatibility**

```bash
nix build .#packages.x86_64-linux.build_iso
nix build .#packages.x86_64-linux.kaneo
nix build .#packages.x86_64-linux.octodns-pihole
nix build .#packages.x86_64-linux.pihole6api
nix build .#packages.x86_64-linux.vm_launcher
nix build .#packages.x86_64-linux.octodns
nix eval .#apps.x86_64-linux.vm.program
```

Expected: all succeed.

- [ ] **Step 5: Verify all host toplevel builds**

```bash
nix build .#nixosConfigurations.lavpc.config.system.build.toplevel
nix build .#nixosConfigurations.tyrant.config.system.build.toplevel
nix build .#nixosConfigurations.temperance.config.system.build.toplevel
nix build .#nixosConfigurations.iso.config.system.build.toplevel
```

Expected: all build.

- [ ] **Step 6: Verify checks**

```bash
nix build .#checks.x86_64-linux.formatting
nix build .#checks.x86_64-linux.backups_eval
nix build .#checks.x86_64-linux.backup_local
nix build .#checks.x86_64-linux.backup_promotion
nix build .#checks.x86_64-linux.vm_bundle_contract
nix build .#checks.x86_64-linux.wireguard_tunnels
```

If `wireguard_tunnels` fails because `inputs.nixarr.inputs.vpnconfinement` is missing, add the minimal npins support pin and input override needed for that dependency, then re-run this check.

- [ ] **Step 7: Run affected Frag compatibility tests**

```bash
pytest _scripts/frag/tests/test_image_assets.py
```

Expected: tests pass or skip only for documented runtime prerequisites such as Docker/Nix availability.

- [ ] **Step 8: Run local flake check before lock deletion**

```bash
nix flake check
```

Expected: passes through the npins-backed shim while `flake.lock` still exists. Only proceed to Task 12 after this check passes.

### Task 12: Delete `flake.lock`

**Files:**

- Delete: `flake.lock`

- [ ] **Step 1: Delete lock file after Task 11 probes and local `nix flake check` pass**

```bash
git rm flake.lock
```

- [ ] **Step 2: Re-run key shim checks without `flake.lock`**

```bash
npins verify
nix eval .#supportedSystems
nix eval .#inputs.self.outPath
nix build .#checks.x86_64-linux.formatting
```

Expected: all succeed and no `flake.lock` is recreated as a required source of truth.

- [ ] **Step 3: Commit lock removal**

```bash
git commit -m "chore(npins): remove flake lock"
```

## Chunk 8: final validation and cleanup

### Task 13: Run standard repo validation

**Files:**

- No file changes expected unless formatters modify files.

- [ ] **Step 1: Run final formatter check**

```bash
nix fmt
```

Expected: succeeds and leaves no uncommitted changes. If files change, stage exact files, run `prek` per the per-commit validation rule, and commit them as a final formatting commit.

- [ ] **Step 2: Confirm per-commit pre-commit coverage**

Review this plan's implementation commits. Every commit that changed Nix/config/docs files must have run the per-commit validation rule (`nix fmt` -> targeted `git add` -> `prek`) before commit. If any commit missed it, create a corrective staged validation commit or stop and report the gap.

- [ ] **Step 3: Run local flake check through shim**

```bash
nix flake check
```

Expected: passes through the npins-backed shim after `flake.lock` deletion.

- [ ] **Step 4: Try all-systems flake check**

```bash
nix flake check --all-systems
```

Expected: passes if builders/binfmt are available.

If blocked by local builder/binfmt/environment constraints, record the exact blocker and rely on:

- successful `nix flake check`;
- successful targeted host/package/app/check matrix from Task 11;
- successful installer and Frag tests.

- [ ] **Step 5: Final status check**

```bash
git status --short
```

Expected: clean working tree.

### Task 14: Final implementation report

**Files:**

- No file changes.

- [ ] **Step 1: Summarize commits**

```bash
git log --oneline --decorate --max-count=20
```

- [ ] **Step 2: Summarize validation evidence**

Report:

- `npins verify` result;
- `nix fmt` result;
- `prek` result;
- `nix flake check` result;
- `nix flake check --all-systems` result or documented blocker;
- targeted host/package/check build results;
- installer test result;
- Frag test result;
- final `git status --short` result.

Expected: no completion claim without fresh command evidence.
